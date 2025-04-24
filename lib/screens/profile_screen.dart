//profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../api_key.dart';

/// ProfileScreen
///
/// A screen that displays and allows editing of user profile information
/// including profile picture, display name, and password.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Firebase service instances
  final FirebaseAuth _auth = FirebaseAuth.instance;           // Authentication service
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;  // Database service
  final FirebaseStorage _storage = FirebaseStorage.instance;  // Storage service for profile images

  // User profile data
  String _name = '';              // User's display name
  String _email = '';             // User's email address
  String _profileImageUrl = '';   // URL to user's profile picture

  /// Shows dialog for changing password
  ///
  /// Displays a dialog with fields for current and new password.
  /// After validation, updates the user's password in Firebase Auth.
  Future<void> _changePassword() async {
    final _oldPasswordController = TextEditingController();   // Controls current password input
    final _newPasswordController = TextEditingController();   // Controls new password input
    bool _isPasswordVisible = false;                          // Toggle for password visibility

    // Show dialog to get password inputs
    bool? shouldChange = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current password field
                TextField(
                  controller: _oldPasswordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "Current Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // New password field
                TextField(
                  controller: _newPasswordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "New Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              // Cancel button
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context, false),
              ),
              // Save button
              TextButton(
                child: Text('Save'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          );
        });
      },
    );

    // Process password change if user confirmed and provided both passwords
    if (shouldChange == true &&
        _oldPasswordController.text.isNotEmpty &&
        _newPasswordController.text.isNotEmpty) {
      try {
        // Get current user and create credential for reauthentication
        User? user = _auth.currentUser;
        AuthCredential credential = EmailAuthProvider.credential(
          email: user?.email ?? '',
          password: _oldPasswordController.text,
        );

        // Reauthenticate user to verify current password
        await user?.reauthenticateWithCredential(credential);

        // Update password with the new one
        await user?.updatePassword(_newPasswordController.text);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password updated successfully!')),
        );
      } on FirebaseAuthException catch (e) {
        // Handle specific Firebase Auth errors
        String errorMessage = 'Failed to update password.';
        if (e.code == 'wrong-password') {
          errorMessage = 'Current password is incorrect.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'New password is too weak.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        // Handle other generic errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred. Please try again.')),
        );
      }
    }

    // Clean up controllers to prevent memory leaks
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();  // Load user profile data when screen initializes
  }

  /// Loads user data from Firebase
  ///
  /// Retrieves user profile information from Firestore and
  /// updates the state to display in the UI.
  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // Fetch user document from Firestore
        DocumentSnapshot userData =
            await _firestore.collection('users').doc(user.uid).get();

        setState(() {
          // Update state with user data
          _name = userData.get('name') ?? 'No Name';
          _email = user.email ?? 'No Email';
          _profileImageUrl = userData.get('profileImageUrl') ?? '';
        });
      } catch (e) {
        print('Error loading user data: $e');
        // Create default user document if data loading fails
        await _firestore.collection('users').doc(user.uid).set({
          'name': 'User',
        });
        setState(() {
          // Set default values
          _name = 'User';
          _email = user.email ?? 'No Email';
          _profileImageUrl = '';
        });
      }
    }
  }

  /// Changes the user's profile picture
  ///
  /// Opens image picker, uploads selected image to Firebase Storage,
  /// and updates the profile image URL in Firestore.
  Future<void> _changeProfilePicture() async {
    final ImagePicker _picker = ImagePicker();
    // Pick image from gallery
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      File imageFile = File(image.path);
      User? user = _auth.currentUser;

      if (user != null) {
        try {
          // Create a reference to the storage location
          Reference storageRef =
              _storage.ref().child('profile_pictures/${user.uid}.jpg');

          // Upload image file to Firebase Storage
          UploadTask uploadTask = storageRef.putFile(imageFile);

          // Wait for upload to complete and get download URL
          TaskSnapshot taskSnapshot = await uploadTask;
          String downloadUrl = await taskSnapshot.ref.getDownloadURL();

          // Update profile image URL in Firestore
          await _firestore.collection('users').doc(user.uid).set({
            'profileImageUrl': downloadUrl,
          }, SetOptions(merge: true));

          // Update local state with new image URL
          setState(() {
            _profileImageUrl = downloadUrl;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile picture updated successfully!')),
          );
        } catch (e) {
          print('Error uploading image: $e');
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to update profile picture. Please try again.')),
          );
        }
      }
    }
  }

  /// Changes the user's display name
  ///
  /// Shows a dialog to input new name and updates it in Firestore.
  Future<void> _changeName() async {
    // Show dialog to get new name
    String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String updatedName = _name;
        return AlertDialog(
          title: Text('Change Name'),
          content: TextField(
            onChanged: (value) {
              updatedName = value;
            },
            decoration: InputDecoration(hintText: "Enter new name"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () => Navigator.pop(context, updatedName),
            ),
          ],
        );
      },
    );

    // Update name if user provided a new one
    if (newName != null && newName.isNotEmpty) {
      User? user = _auth.currentUser;
      if (user != null) {
        try {
          // Update name in Firestore
          await _firestore.collection('users').doc(user.uid).update({
            'name': newName,
          });

          // Update local state
          setState(() {
            _name = newName;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Name updated successfully!')),
          );
        } catch (e) {
          print('Error updating name: $e');
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update name. Please try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Profile picture with edit button overlay
          GestureDetector(
            onTap: _changeProfilePicture,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Profile image avatar
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _profileImageUrl.isNotEmpty
                      ? NetworkImage(_profileImageUrl) as ImageProvider
                      : NetworkImage(
                              default_icon)
                          as ImageProvider,
                  onBackgroundImageError: (exception, stackTrace) {
                    print('Error loading profile image: $exception');
                  },
                ),
                // Edit button overlay
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          // Name display with edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: _changeName,
                child: Icon(Icons.edit, size: 20),
              ),
            ],
          ),
          SizedBox(height: 20),
          // Email information card (read-only)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              leading: Icon(Icons.email),
              title: Text('Email'),
              subtitle: Text(_email),
            ),
          ),
          SizedBox(height: 10),
          // Password change card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Password'),
              subtitle: Text('Change password'),
              onTap: _changePassword,
            ),
          ),
        ],
      ),
    );
  }
}
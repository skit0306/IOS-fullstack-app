import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens//home_screen.dart';

/// SignUpPage
///
/// A screen that allows new users to create an account by providing
/// their name, email, and password. Creates user records in both
/// Firebase Authentication and Firestore database.
class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>(); // For form validation
  final _nameController = TextEditingController(); // Controls name input field
  final _emailController =
      TextEditingController(); // Controls email input field
  final _passwordController =
      TextEditingController(); // Controls password input field
  bool _isLoading = false; // Loading state for UI feedback
  String _errorMessage = ''; // Error message to display
  bool _obscurePassword = true; // Toggle for password visibility

  /// Creates a new user account and stores their data
  ///
  /// Validates the form, creates a Firebase Auth account with email/password,
  /// stores additional user information in Firestore, and navigates to the home screen.
  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Show loading indicator
        _errorMessage = ''; // Clear any previous errors
      });

      try {
        // Create user with email and password in Firebase Authentication
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Store additional user info in Firestore database
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue
              .serverTimestamp(), // Server timestamp for account creation
        });

        // Navigate to HomeScreen and clear the navigation stack
        // This prevents going back to signup screen after registration
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomeScreen()),
            (Route<dynamic> route) => false, // Remove all previous routes
          );
        }
      } on FirebaseAuthException catch (e) {
        // Handle Firebase Auth specific errors (e.g., email already in use)
        setState(() {
          _errorMessage = e.message ?? 'An error occurred during sign up';
        });
      } catch (e) {
        // Handle any other unexpected errors
        setState(() {
          _errorMessage = 'An unexpected error occurred: ${e.toString()}';
        });
      } finally {
        // Reset loading state when completed (success or failure)
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get current theme for consistent styling

    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name input field with validation
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outlined,
                        color: theme.iconTheme.color),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  style: theme.textTheme.bodyMedium,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter your name' : null,
                ),
                SizedBox(height: 16),

                // Email input field with validation
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined,
                        color: theme.iconTheme.color),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  style: theme.textTheme.bodyMedium,
                  keyboardType:
                      TextInputType.emailAddress, // Shows email keyboard
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter your email' : null,
                ),
                SizedBox(height: 16),

                // Password input field with visibility toggle and validation
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon:
                        Icon(Icons.lock_outline, color: theme.iconTheme.color),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: theme.iconTheme.color,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                              !_obscurePassword; // Toggle password visibility
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  obscureText: _obscurePassword, // Hide characters when true
                  style: theme.textTheme.bodyMedium,
                  validator: (value) => value!.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                SizedBox(height: 24),

                // Error message display (only shown when there's an error)
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Sign Up button with loading indicator
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _signUp, // Disable button when loading
                  child: _isLoading
                      ? CircularProgressIndicator(
                          color: Colors.white) // Show spinner when loading
                      : Text('Sign Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up controllers when widget is disposed to prevent memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

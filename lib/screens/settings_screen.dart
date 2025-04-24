import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:p1/theme/theme_notifier.dart';
import 'package:p1/auth/auth.dart';
import 'package:p1/screens/login_screen.dart';

/// SettingsScreen
///
/// A screen that displays application settings and preferences.
/// Allows users to toggle dark mode, view policy documents, and log out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Handles user logout
  ///
  /// Signs out the current user from Firebase Auth and navigates
  /// back to the login screen, clearing the navigation stack.
  Future<void> _logout(BuildContext context) async {
    try {
      // Sign out using the Auth service
      await Auth().signOut();

      // Navigate to login screen and remove all previous routes from stack
      // This prevents going back to protected screens after logout
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      // Handle any errors during logout
      print('Error during logout: $e');

      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the theme notifier provider to get/set theme mode
    final ThemeNotifier themeNotifier =
        Provider.of<ThemeNotifier>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Dark Mode toggle switch
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle between light and dark theme'),
            value: themeNotifier.themeMode == ThemeMode.dark,
            onChanged: (bool value) {
              setState(() {
                // Update theme mode based on switch value
                themeNotifier
                    .setTheme(value ? ThemeMode.dark : ThemeMode.light);
              });
            },
          ),

          // Privacy Policy navigation item
          ListTile(
            title: const Text('Privacy Policy'),
            subtitle: const Text('Information about data usage'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to privacy policy
              // Future implementation could open a webview or navigate to policy screen
            },
          ),

          // Terms of Service navigation item
          ListTile(
            title: const Text('Terms of Service'),
            subtitle: const Text('User agreement and conditions'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to terms of service
              // Future implementation could open a webview or navigate to terms screen
            },
          ),

          // App version display (static information)
          const ListTile(
            title: Text('App Version'),
            subtitle: Text('Current installed version'),
            trailing:
                Text('1.0.0'), // Version number should be updated with releases
          ),

          // Divider for visual separation before logout option
          const Divider(),

          // Logout option
          ListTile(
            title: const Text('Logout'),
            subtitle: const Text('Sign out of your account'),
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:p1/screens/home_screen.dart';
import '../auth/auth.dart';
import 'package:provider/provider.dart';
import '../theme/theme_notifier.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'signup_screen.dart';
import 'offline_screen.dart';

/// LoginScreen
///
/// Provides a user interface for authentication, allowing users to sign in with
/// email/password or Google, reset their password, create a new account,
/// or access the app in offline mode.
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Auth _auth = Auth(); // Authentication service
  final _formKey = GlobalKey<FormState>(); // Form validation key
  final _emailController = TextEditingController(); // Controls email input
  final _passwordController =
      TextEditingController(); // Controls password input
  String _error = ''; // Error message to display
  bool _isLoading = false; // Loading state flag
  bool _obscurePassword = true; // Toggle for password visibility

  /// Handles Google sign-in authentication flow
  ///
  /// Attempts to sign in with Google, navigates to HomeScreen on success,
  /// and displays error messages on failure.
  Future<void> _signInWithGoogle() async {
    if (_isLoading) return; // Prevent multiple sign-in attempts

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      await _auth.signInWithGoogle();
      if (mounted) {
        // Check if the widget is still in the tree
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if the widget is still in the tree
        setState(() {
          _error = 'Failed to sign in with Google: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        // Check if the widget is still in the tree
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Displays a dialog for password reset
  ///
  /// Shows an input dialog for the user's email address and
  /// sends a password reset email when submitted.
  Future<void> _showForgotPasswordDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reset Password'),
          content: TextField(
            controller: _emailController,
            decoration: InputDecoration(hintText: "Enter your email"),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Reset'),
              onPressed: () async {
                if (_emailController.text.isNotEmpty) {
                  try {
                    // Send password reset email
                    await _auth.forgotPassword(
                        email: _emailController.text.trim());
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Password reset email sent. Check your inbox.')),
                    );
                  } catch (e) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Failed to send reset email. ${e.toString()}')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Navigates to offline mode
  ///
  /// Allows users to access limited app functionality without internet connection.
  void _goToOfflineMode() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => OfflineScreen()),
    );
  }

  /// Submits the login form
  ///
  /// Validates form inputs, attempts to sign in with email/password,
  /// and handles success and error states.
  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      try {
        // Attempt sign-in with email and password
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          _error = e.message ?? 'An error occurred. Please try again.';
        });
      } catch (e) {
        setState(() {
          _error = 'An unexpected error occurred. Please try again.';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Theme toggle button
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: theme.iconTheme.color,
            ),
            onPressed: () {
              themeNotifier.setTheme(
                isDarkMode ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          // Dismiss keyboard when tapping outside input fields
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 40),
                  // Welcome header
                  Text(
                    'Welcome!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.headlineMedium?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 48),
                  // Email input field
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
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  // Password input field with visibility toggle
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline,
                          color: theme.iconTheme.color),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: theme.iconTheme.color,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
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
                    style: theme.textTheme.bodyMedium,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24),
                  // Error message display
                  if (_error.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Sign in button
                  ElevatedButton(
                    child: _isLoading
                        ? CircularProgressIndicator(
                            color: theme.colorScheme.onPrimary)
                        : Text('Sign In', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submitForm,
                  ),
                  SizedBox(height: 24),
                  // Divider for alternative sign-in methods
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Or continue with',
                            style: TextStyle(color: Colors.grey[600])),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Google sign-in button
                  SignInButton(
                    Buttons.google,
                    text: "Sign up with Google",
                    onPressed: _isLoading
                        ? () {} // Provide an empty function when loading
                        : () {
                            _signInWithGoogle();
                          },
                  ),

                  // Additional options section
                  Column(
                    children: [
                      // Sign up option
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account?"),
                          TextButton(
                            child: Text('Sign up'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) => SignUpPage()),
                              );
                            },
                          ),
                        ],
                      ),

                      // Password reset option
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Forgot Password?"),
                          TextButton(
                            child: Text('Reset'),
                            onPressed: _showForgotPasswordDialog,
                          ),
                        ],
                      ),

                      // Offline mode option
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("No network?"),
                          TextButton(
                            child: Text('Offline mode'),
                            onPressed: _goToOfflineMode,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

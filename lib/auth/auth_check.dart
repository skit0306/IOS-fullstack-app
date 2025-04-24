import 'package:flutter/material.dart';
import 'package:p1/screens/home_screen.dart';
import 'package:p1/screens/login_screen.dart';
import 'package:p1/auth/auth.dart';

/// AuthCheck widget
/// This widget serves as a router that checks if a user is authenticated or not.
class AuthCheck extends StatelessWidget {
  const AuthCheck({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to authentication state changes in real-time
    return StreamBuilder(
      // Subscribes to the auth state stream from Auth service
      stream: Auth().authStateChanges,
      builder: (context, snapshot) {
        // Check if connection to the stream is established and active
        if (snapshot.connectionState == ConnectionState.active) {
          // Extract user data from the snapshot
          final user = snapshot.data;

          // If user is null (not authenticated), show login screen
          if (user == null) {
            return LoginScreen();
          }

          // If user is authenticated, show home screen
          return HomeScreen();
        }

        // While waiting for authentication state to be determined,
        // show a loading indicator
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

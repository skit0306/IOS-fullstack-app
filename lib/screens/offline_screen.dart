import 'package:flutter/material.dart';
import 'package:p1/screens/object_detection_screen.dart';
import 'login_screen.dart';
import 'package:p1/screens/dictionary_screen.dart';

/// OfflineScreen
///
/// A screen that displays features available without internet connection.
/// Allows users to access limited functionality without signing in.
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        automaticallyImplyLeading: false, // Removes back button
        actions: [
          // Button to go back to login screen
          TextButton.icon(
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text('Sign In', style: TextStyle(color: Colors.white)),
            onPressed: () {
              // Navigate to login screen, replacing current route
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Screen title
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Offline Features',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            // Grid of offline features
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    // Object Detection feature card
                    _buildFeatureCard(
                      context,
                      'Object Detection',
                      Icons.camera_alt,
                      Colors.blue.shade700,
                      () {
                        // Navigate to Object Detection screen while keeping current route
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ObjectDetectionScreen()),
                        );
                      },
                    ),
                    // Dictionary feature card
                    _buildFeatureCard(
                      context,
                      'Dictionary',
                      Icons.book,
                      Colors.green.shade700,
                      () {
                        // Navigate to Dictionary screen while keeping current route
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DictionaryScreen()),
                        );
                      },
                    ),
                    // Sign In feature card
                    _buildFeatureCard(
                      context,
                      'Sign In',
                      Icons.login,
                      Colors.orange.shade700,
                      () {
                        // Navigate to login screen, replacing current route
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => LoginScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Info message about offline mode
            Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These features work without an internet connection. Sign in to access all features.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a feature card widget
  ///
  /// @param context - The build context
  /// @param title - The feature title to display
  /// @param icon - The icon to display
  /// @param color - Background color for the icon container
  /// @param onTap - Callback function when card is tapped
  /// @return A styled Card widget with icon and title
  Widget _buildFeatureCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular icon container with background color
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Feature title
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

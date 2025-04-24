import 'package:flutter/material.dart';
import 'listening_screen.dart';
import 'package:p1/screens/object_detection_screen.dart';
import 'text_to_speech_screen.dart';
import 'package:p1/screens/typo_exercise.dart';
import 'package:p1/screens/dictionary_screen.dart';

/// AI_Screen
///
/// This screen presents a grid of learning features accessible to the user.
/// Each feature is represented as a card with an icon and title that navigates
/// to the corresponding feature screen when tapped.
class AI_Screen extends StatelessWidget {
  const AI_Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Features'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // Grid layout with 2 columns
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: <Widget>[
            // Text to Speech feature card
            _buildFeatureCard(
              context,
              'Text to Speech',
              Icons.record_voice_over,
              Colors.blue.shade700,
              () {
                // Navigate to Text to Speech screen when tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TextToSpeechScreen()),
                );
              },
            ),
            // Listening Exercise feature card
            _buildFeatureCard(
              context,
              'Listening Exercise',
              Icons.hearing,
              Colors.green.shade700,
              () {
                // Navigate to Listening Exercise screen when tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListeningScreen()),
                );
              },
            ),
            // Object Detection feature card
            _buildFeatureCard(
              context,
              'Object Detection',
              Icons.camera_alt,
              Colors.orange.shade700,
              () {
                // Navigate to Object Detection screen when tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ObjectDetectionScreen()),
                );
              },
            ),
            // Typo Exercise feature card
            _buildFeatureCard(
              context,
              'Typo Exercise',
              Icons.spellcheck,
              Colors.purple.shade700,
              () {
                // Navigate to Typo Exercise screen when tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TyposMCQuestionScreen()),
                );
              },
            ),
            // Dictionary feature card
            _buildFeatureCard(
              context,
              'Dictionary',
              Icons.book,
              Colors.teal.shade700,
              () {
                // Navigate to Dictionary screen when tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DictionaryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a feature card with an icon and title
  /// @param context - The build context
  /// @param title - The title text to display
  /// @param icon - The icon to display
  /// @param color - Background color for the icon
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
            // Circular colored container for the icon
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
            // Feature title text
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

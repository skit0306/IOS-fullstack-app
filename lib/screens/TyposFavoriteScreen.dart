import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:p1/service/firebase_service.dart';

/// TyposFavoriteScreen
///
/// A screen that displays a user's favorite typo questions that they've saved
/// from previous exercises. Allows users to view and manage their favorites.
class TyposFavoriteScreen extends StatefulWidget {
  final String exerciseType; // Type of exercise (e.g., "typos")

  const TyposFavoriteScreen({Key? key, required this.exerciseType})
      : super(key: key);

  @override
  _TyposFavoriteScreenState createState() => _TyposFavoriteScreenState();
}

class _TyposFavoriteScreenState extends State<TyposFavoriteScreen> {
  final FirebaseService _firebaseService =
      FirebaseService(); // Firebase service for data operations
  late Future<QuerySnapshot<Map<String, dynamic>>>
      _favoritesFuture; // Future for favorite questions data

  @override
  void initState() {
    super.initState();
    _loadFavorites(); // Load favorite questions when screen initializes
  }

  /// Loads favorite questions from Firebase
  ///
  /// Retrieves the user's saved favorite questions for this exercise type
  void _loadFavorites() {
    _favoritesFuture = _firebaseService.getFavoriteQuestions(
        exerciseType: widget.exerciseType);
  }

  /// Removes a question from favorites
  ///
  /// @param favId - The ID of the favorite item to delete
  Future<void> _deleteFavorite(String favId) async {
    // Remove the item from Firebase
    await _firebaseService.removeFavoriteQuestionItem(
        exerciseType: widget.exerciseType, historyId: favId);

    // Reload favorites to update UI
    setState(() {
      _loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorite Questions'),
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          // Show loading indicator while data is being fetched
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          // Show error message if loading fails
          if (snapshot.hasError) {
            return Center(
                child: Text("Error loading favorites: ${snapshot.error}"));
          }

          final docs = snapshot.data!.docs;

          // Show message if no favorites exist
          if (docs.isEmpty) {
            return Center(child: Text("No favorites available."));
          }

          // Build list of favorite question cards
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              // Extract document data
              final doc = docs[index];
              final data = doc.data();
              final favId = doc.id;

              // Extract question fields
              final question = data["question"] ?? "";
              final options = List<String>.from(data["options"] ?? []);
              final userAnswer = data["userAnswer"];
              final correctIndex = data["correctIndex"];

              // Create dismissible card that can be swiped to delete
              return Dismissible(
                key: Key(favId),
                direction:
                    DismissDirection.endToStart, // Only swipe right to left
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Colors.red,
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _deleteFavorite(
                      favId); // Remove from favorites when dismissed
                },
                child: FavoriteQuestionCard(
                  question: question,
                  options: options,
                  userAnswer: userAnswer,
                  correctIndex: correctIndex,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// FavoriteQuestionCard
///
/// A card widget that displays a favorite question with visual feedback
/// showing the correct answer and the user's previous selection.
class FavoriteQuestionCard extends StatelessWidget {
  final String question; // Question text
  final List<String> options; // Answer options
  final dynamic userAnswer; // User's previously selected answer
  final dynamic correctIndex; // Index of the correct answer

  const FavoriteQuestionCard({
    Key? key,
    required this.question,
    required this.options,
    this.userAnswer,
    this.correctIndex,
  }) : super(key: key);

  /// Determines the background color for answer options
  ///
  /// @param optionIndex - The index of the option to color
  /// @return The background color based on correctness
  Color _getOptionColor(int optionIndex) {
    // Highlight green if the option is correct,
    // red if the user selected it incorrectly.
    if (optionIndex == correctIndex) {
      return Colors.green.shade100; // Correct answer
    } else if (userAnswer != null &&
        optionIndex == userAnswer &&
        userAnswer != correctIndex) {
      return Colors.red.shade100; // Incorrect selection
    }
    return Colors.white; // Neutral color for other options
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question text
            Text(question, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 12),

            // Display answer options with color coding
            Row(
              children: options.asMap().entries.map((entry) {
                int idx = entry.key;
                String option = entry.value;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: _getOptionColor(idx), // Color based on correctness
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        option,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 4),

            // Summary text showing user's answer and correct answer
            Text(
              "Your Answer: ${userAnswer != null && userAnswer < options.length ? options[userAnswer] : 'N/A'}    Correct: ${correctIndex != null && correctIndex < options.length ? options[correctIndex] : 'N/A'}",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

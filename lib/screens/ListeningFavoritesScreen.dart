import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:p1/service/firebase_service.dart';
import 'package:p1/service/openai_service.dart';

/// ListeningFavoritesScreen
///
/// A screen that displays a user's favorite listening exercises.
/// Users can view, redo, or delete saved exercises from their favorites list.
class ListeningFavoritesScreen extends StatefulWidget {
  final String exerciseType; // Type of exercise (e.g., "listening")

  const ListeningFavoritesScreen({Key? key, required this.exerciseType})
      : super(key: key);

  @override
  _ListeningFavoritesScreenState createState() =>
      _ListeningFavoritesScreenState();
}

class _ListeningFavoritesScreenState extends State<ListeningFavoritesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late Future<QuerySnapshot<Map<String, dynamic>>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  /// Loads favorite items from Firebase
  ///
  /// Retrieves all favorited exercises of the specified type
  void _loadFavorites() {
    _favoritesFuture = _firebaseService.getFavoriteQuestions(
        exerciseType: widget.exerciseType);
  }

  /// Removes an item from favorites
  ///
  /// @param favId - ID of the favorite item to delete
  Future<void> _deleteFavorite(String favId) async {
    await _firebaseService.removeFavoriteQuestionItem(
        exerciseType: widget.exerciseType, historyId: favId);
    setState(() {
      _loadFavorites(); // Reload the favorites list after deletion
    });
  }

  /// Shows a dialog with detailed information about the exercise
  ///
  /// @param context - The build context
  /// @param data - The exercise data containing transcript, questions, and answers
  void _viewFullRecord(BuildContext context, Map<String, dynamic> data) {
    // Get the transcript and questions from the data
    final transcript = data["transcript"] as String? ?? "";
    final questions =
        List<Question>.from((data["questions"] as List<dynamic>? ?? []).map(
      (q) => Question(
        question: q["question"] as String? ?? "",
        options: List<String>.from(q["options"] as List<dynamic>? ?? []),
        correctIndex: q["correctIndex"] as int? ?? 0,
        explanation: q["explanation"] as String? ?? "",
      ),
    ));
    final userAnswers =
        List<int?>.from(data["userAnswers"] as List<dynamic>? ?? []);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Full Record',
                    style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 16),
                // Display the transcript
                Text('Transcript:',
                    style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 8),
                Text(transcript),
                SizedBox(height: 16),
                // Display questions and answers
                Text('Questions:',
                    style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 8),
                ...questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  final userAnswer =
                      index < userAnswers.length ? userAnswers[index] : null;

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question text
                          Text(question.question,
                              style: Theme.of(context).textTheme.titleSmall),
                          SizedBox(height: 8),
                          // Answer options with color-coding
                          ...question.options
                              .asMap()
                              .entries
                              .map((optionEntry) {
                            final optionIndex = optionEntry.key;
                            final option = optionEntry.value;
                            final isSelected = userAnswer == optionIndex;
                            final isCorrect =
                                question.correctIndex == optionIndex;
                            Color? bgColor;

                            // Color-code based on correctness
                            if (isSelected) {
                              bgColor = isCorrect
                                  ? Colors.green.shade100 // Correct answer
                                  : Colors.red.shade100; // Wrong answer
                            } else if (isCorrect) {
                              bgColor =
                                  Colors.green.shade100; // Show correct answer
                            }

                            return Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              margin: EdgeInsets.only(bottom: 4),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(option),
                            );
                          }).toList(),
                          SizedBox(height: 8),
                          // Show explanation if available
                          if (question.explanation.isNotEmpty)
                            Text(
                              'Explanation: ${question.explanation}',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns to the listening screen with the exercise data for redoing
  ///
  /// @param context - The build context
  /// @param data - The exercise data to be reused
  Future<void> _redoExercise(
      BuildContext context, Map<String, dynamic> data) async {
    // Navigate back to the listening screen with the full data
    Navigator.pop(context, {
      "action": "redo",
      "transcript": data["transcript"],
      "questions": data["questions"],
      "userAnswers": null, // Reset user answers
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorite Listening Exercises'),
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
          // Build list of favorite items
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final favId = doc.id;

              // Extract transcript for preview
              final transcript = data["transcript"] as String? ?? "";
              final transcriptPreview = transcript.length > 50
                  ? "${transcript.substring(0, 50)}..."
                  : transcript;

              // Calculate user performance summary
              final questions = data["questions"] as List<dynamic>? ?? [];
              final userAnswers = data["userAnswers"] as List<dynamic>? ?? [];

              int correctCount = 0;
              for (int i = 0;
                  i < questions.length && i < userAnswers.length;
                  i++) {
                final question = questions[i] as Map<String, dynamic>;
                final userAnswer = userAnswers[i];
                if (userAnswer != null &&
                    userAnswer == question["correctIndex"]) {
                  correctCount++;
                }
              }

              final performance = questions.isEmpty
                  ? "No questions"
                  : "$correctCount/${questions.length} correct";

              // Create a dismissible card for each favorite item
              return Dismissible(
                key: Key(favId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Colors.red,
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _deleteFavorite(favId);
                },
                child: Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date and time of the exercise
                        Text(
                          _formatDate(data["timestamp"] as Timestamp?),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        // Preview of transcript
                        Text(
                          transcriptPreview,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        // Performance summary
                        Text(
                          performance,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        SizedBox(height: 12),
                        // Action buttons for viewing and redoing exercises
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                _viewFullRecord(context, data);
                              },
                              child: Text('View'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                _redoExercise(context, data);
                              },
                              child: Text('Redo'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Formats a Firestore timestamp into a readable date string
  ///
  /// @param timestamp - The Firestore timestamp to format
  /// @return A formatted date string (YYYY-MM-DD HH:MM)
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown date";
    final date = timestamp.toDate();
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}

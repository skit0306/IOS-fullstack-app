import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:p1/service/firebase_service.dart';
import 'package:p1/service/openai_service.dart';

/// ListeningHistoryScreen
///
/// Displays a history of user's listening exercises with options to
/// view details, redo exercises, add/remove favorites, and delete history items.
class ListeningHistoryScreen extends StatefulWidget {
  final String exerciseType; // Type of exercise (e.g., "listening")

  const ListeningHistoryScreen({Key? key, required this.exerciseType})
      : super(key: key);

  @override
  _ListeningHistoryScreenState createState() => _ListeningHistoryScreenState();
}

class _ListeningHistoryScreenState extends State<ListeningHistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late Future<QuerySnapshot<Map<String, dynamic>>>
      _historyFuture; // History data
  late Future<QuerySnapshot<Map<String, dynamic>>>
      _favoritesFuture; // Favorites data

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Loads history and favorites data from Firebase
  ///
  /// Fetches both the exercise history and favorites for comparison
  void _loadData() {
    _historyFuture =
        _firebaseService.getQuestionHistory(exerciseType: widget.exerciseType);
    _favoritesFuture = _firebaseService.getFavoriteQuestions(
        exerciseType: widget.exerciseType);
  }

  /// Deletes a history item from Firebase
  ///
  /// @param historyId - The ID of the history item to delete
  Future<void> _deleteHistoryItem(String historyId) async {
    await _firebaseService.deleteHistoryItem(
        exerciseType: widget.exerciseType, historyId: historyId);
    setState(() {
      _loadData(); // Reload data after deletion
    });
  }

  /// Toggles favorite status for a history item
  ///
  /// @param historyId - The ID of the history item
  /// @param historyData - The data of the history item
  /// @param isFav - Current favorite status (true if already favorited)
  Future<void> _toggleFavorite(
      String historyId, Map<String, dynamic> historyData, bool isFav) async {
    if (isFav) {
      // Remove from favorites
      await _firebaseService.removeFavoriteQuestionItem(
          exerciseType: widget.exerciseType, historyId: historyId);
    } else {
      // Add to favorites
      await _firebaseService.addFavoriteQuestionItem(
          exerciseType: widget.exerciseType,
          historyId: historyId,
          favoriteItem: historyData);
    }
    setState(() {
      _loadData(); // Reload data after toggling favorite
    });
  }

  /// Shows a dialog with detailed exercise information
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

    // Display a dialog with full record details
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
                // Transcript section
                Text('Transcript:',
                    style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 8),
                Text(transcript),
                SizedBox(height: 16),
                // Questions section
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
                          // Explanation if available
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
                // Close button
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
    // Get transcript and questions directly from history data
    // No need to generate new ones, just reuse what's in the history

    // Navigate back to the listening screen with the full data
    Navigator.pop(context, {
      "action": "redo",
      "transcript": data["transcript"],
      "questions": data["questions"],
      "userAnswers": null, // Reset user answers for a fresh attempt
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Listening History'),
      ),
      body: FutureBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
        future: Future.wait([_historyFuture, _favoritesFuture]),
        builder: (context, snapshot) {
          // Show loading indicator while data is being fetched
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          // Show error message if loading fails
          if (snapshot.hasError) {
            return Center(
                child: Text("Error loading history: ${snapshot.error}"));
          }

          final historyDocs = snapshot.data![0].docs;
          // Show message if no history exists
          if (historyDocs.isEmpty) {
            return Center(child: Text("No history available."));
          }

          // Get favorite IDs for comparison to highlight favorites
          final favDocs = snapshot.data![1].docs.map((doc) => doc.id).toSet();

          // Create a dismissible list item for each history entry
          return ListView.builder(
            itemCount: historyDocs.length,
            itemBuilder: (context, index) {
              final doc = historyDocs[index];
              final data = doc.data();
              final historyId = doc.id;

              // Extract transcript for preview
              final transcript = data["transcript"] as String? ?? "";
              final transcriptPreview = transcript.length > 50
                  ? "${transcript.substring(0, 50)}..." // Truncate long transcripts
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

              // Check if this history item is in favorites
              final isFav = favDocs.contains(historyId);

              // Create a dismissible card that can be swiped to delete
              return Dismissible(
                key: Key(historyId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Colors.red,
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _deleteHistoryItem(historyId);
                },
                child: ListeningHistoryCard(
                  transcriptPreview: transcriptPreview,
                  performance: performance,
                  timestamp: data["timestamp"] as Timestamp?,
                  isFavorite: isFav,
                  onFavoriteToggle: () {
                    _toggleFavorite(historyId, data, isFav);
                  },
                  onViewPressed: () {
                    _viewFullRecord(context, data);
                  },
                  onRedoPressed: () {
                    _redoExercise(context, data);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ListeningHistoryCard
///
/// A reusable card component for displaying listening exercise history items.
/// Shows exercise preview, performance, timestamp, and provides action buttons.
class ListeningHistoryCard extends StatelessWidget {
  final String transcriptPreview; // Preview of the transcript text
  final String performance; // Performance summary (e.g., "7/10 correct")
  final Timestamp? timestamp; // When the exercise was completed
  final bool isFavorite; // Whether this is a favorite item
  final VoidCallback onFavoriteToggle; // Action when favorite button is pressed
  final VoidCallback onViewPressed; // Action when View button is pressed
  final VoidCallback onRedoPressed; // Action when Redo button is pressed

  const ListeningHistoryCard({
    Key? key,
    required this.transcriptPreview,
    required this.performance,
    this.timestamp,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onViewPressed,
    required this.onRedoPressed,
  }) : super(key: key);

  /// Formats a Firestore timestamp into a readable date string
  ///
  /// @param timestamp - The Firestore timestamp to format
  /// @return A formatted date string (YYYY-MM-DD HH:MM)
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown date";
    final date = timestamp.toDate();
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
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
            // Header row with date and favorite toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Format and display the timestamp
                Text(
                  _formatDate(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                // Favorite toggle button
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : null,
                  ),
                  onPressed: onFavoriteToggle,
                ),
              ],
            ),
            SizedBox(height: 8),
            // Transcript preview with ellipsis for long text
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
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View full record button
                ElevatedButton(
                  onPressed: onViewPressed,
                  child: Text('View'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                SizedBox(width: 8),
                // Redo exercise button
                ElevatedButton(
                  onPressed: onRedoPressed,
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
    );
  }
}

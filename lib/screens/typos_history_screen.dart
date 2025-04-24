import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:p1/service/firebase_service.dart';

/// TyposHistoryScreen
///
/// Displays a history of all typo detection exercises completed by the user.
/// Allows viewing previous answers, toggling favorites, and deleting history items.
class TyposHistoryScreen extends StatefulWidget {
  final String exerciseType;  // Type of exercise (e.g., "typos")

  const TyposHistoryScreen({Key? key, required this.exerciseType})
      : super(key: key);

  @override
  _TyposHistoryScreenState createState() => _TyposHistoryScreenState();
}

class _TyposHistoryScreenState extends State<TyposHistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();  // Firebase service for data operations
  late Future<QuerySnapshot<Map<String, dynamic>>> _historyFuture;    // Future for history data
  late Future<QuerySnapshot<Map<String, dynamic>>> _favoritesFuture;  // Future for favorites data

  @override
  void initState() {
    super.initState();
    _loadData();  // Load data when screen initializes
  }

  /// Loads history and favorites data from Firebase
  ///
  /// Fetches both the exercise history and favorites for comparison
  void _loadData() {
    _historyFuture =
        _firebaseService.getQuestionHistory(exerciseType: widget.exerciseType);
    _favoritesFuture =
        _firebaseService.getFavoriteQuestions(exerciseType: widget.exerciseType);
  }

  /// Deletes a history item from Firebase
  ///
  /// @param historyId - The ID of the history item to delete
  Future<void> _deleteHistoryItem(String historyId) async {
    await _firebaseService.deleteHistoryItem(
        exerciseType: widget.exerciseType, historyId: historyId);
    setState(() {
      _loadData();  // Reload data after deletion
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
      _loadData();  // Reload data after toggling favorite
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Question History'),
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // First fetch history data
        future: Future.wait([_historyFuture, _favoritesFuture])
            .then((results) => results[0] as QuerySnapshot<Map<String, dynamic>>),
        builder: (context, snapshot) {
          // Show loading indicator while data is being fetched
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          // Show error message if loading fails
          if (snapshot.hasError) {
            return Center(child: Text("Error loading history: ${snapshot.error}"));
          }
          
          final historyDocs = snapshot.data!.docs;
          // Show message if no history exists
          if (historyDocs.isEmpty) {
            return Center(child: Text("No history available."));
          }
          
          // Fetch favorites data to determine which items are favorited
          return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: _favoritesFuture,
              builder: (context, favSnapshot) {
                if (favSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                // Create a set of favorite IDs for easy lookup
                final favDocs = favSnapshot.data?.docs.map((doc) => doc.id).toSet() ?? {};
                
                // Build the list of history items
                return ListView.builder(
                  itemCount: historyDocs.length,
                  itemBuilder: (context, index) {
                    final doc = historyDocs[index];
                    final data = doc.data();
                    final historyId = doc.id;
                    
                    // Extract question data
                    final question = data["question"] ?? "";
                    final options = List<String>.from(data["options"] ?? []);
                    final userAnswer = data["userAnswer"];
                    final correctIndex = data["correctIndex"];
                    final isCorrect = data["isCorrect"] as bool? ?? false;
                    final isFav = favDocs.contains(historyId);  // Check if this item is favorited

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
                      child: HistoryQuestionCard(
                        historyId: historyId,
                        question: question,
                        options: options,
                        userAnswer: userAnswer,
                        correctIndex: correctIndex,
                        isFavorite: isFav,
                        onFavoriteToggle: () {
                          _toggleFavorite(historyId, data, isFav);
                        },
                      ),
                    );
                  },
                );
              });
        },
      ),
    );
  }
}

/// HistoryQuestionCard
///
/// A card widget that displays a history snapshot for a question with 
/// two option cards and a favorite button.
class HistoryQuestionCard extends StatelessWidget {
  final String historyId;        // Unique ID of the history item
  final String question;         // Question text
  final List<String> options;    // Available answer options
  final dynamic userAnswer;      // The user's selected answer 
  final dynamic correctIndex;    // The correct answer's index
  final bool isFavorite;         // Whether this item is favorited
  final VoidCallback onFavoriteToggle;  // Callback when favorite button is pressed

  const HistoryQuestionCard({
    Key? key,
    required this.historyId,
    required this.question,
    required this.options,
    this.userAnswer,
    this.correctIndex,
    required this.isFavorite,
    required this.onFavoriteToggle,
  }) : super(key: key);

  /// Determines the background color for answer options
  ///
  /// @param optionIndex - The index of the option to color
  /// @return The background color based on correctness
  Color _getOptionColor(int optionIndex) {
    // Highlight green if the option is correct,
    // red if the user selected it incorrectly.
    if (optionIndex == correctIndex) {
      return Colors.green.shade100;  // Correct answer
    } else if (userAnswer != null &&
        optionIndex == userAnswer &&
        userAnswer != correctIndex) {
      return Colors.red.shade100;    // Incorrect selection
    }
    return Colors.white;             // Neutral color for other options
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
            // Question text with favorite toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(question,
                      style: Theme.of(context).textTheme.titleMedium),
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
                      color: _getOptionColor(idx),      // Color based on correctness
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
            // Answer summary showing user's answer and correct answer
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
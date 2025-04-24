import 'package:flutter/material.dart';
import 'package:p1/screens/TyposFavoriteScreen.dart';
import 'package:p1/service/openai_service.dart';
import 'package:p1/service/firebase_service.dart';
import 'typos_history_screen.dart';

/// TyposMCQuestionScreen
///
/// A screen that generates and displays multiple-choice questions
/// to test the user's ability to identify Chinese language typos and errors.
class TyposMCQuestionScreen extends StatefulWidget {
  @override
  _TyposMCQuestionScreenState createState() => _TyposMCQuestionScreenState();
}

class _TyposMCQuestionScreenState extends State<TyposMCQuestionScreen> {
  // Service instances
  late OpenAIService _openAIService; // For generating questions with AI
  late FirebaseService _firebaseService; // For saving results to Firebase

  // State variables
  bool _isProcessing = false; // Tracks if questions are being generated
  String _status = 'Ready!'; // Status message to display
  List<Question>? _questions; // Generated questions
  bool _submitted = false; // Whether answers have been submitted
  List<int?> _userAnswers = []; // User's selected answers

  @override
  void initState() {
    super.initState();
    // Initialize services
    _openAIService = OpenAIService();
    _firebaseService = FirebaseService();
  }

  /// Generates new multiple-choice questions about Chinese typos
  ///
  /// Uses OpenAI service to create questions that test the user's
  /// ability to identify correct and incorrect Chinese characters or phrases.
  Future<void> _generateMCQuestion() async {
    setState(() {
      _isProcessing = true; // Show loading indicator
      _status = 'Generating typos MC question...'; // Update status message
      _questions = null; // Clear any existing questions
      _submitted = false; // Reset submission state
    });

    try {
      // Generate new questions using OpenAI
      final questions = await _openAIService.generateTyposMCQuestions();
      setState(() {
        _questions = questions;
        // Initialize answer array with nulls (no selection)
        _userAnswers = List<int?>.filled(questions.length, null);
        _status = 'Question generated!'; // Update success message
      });
    } catch (e) {
      // Handle errors during question generation
      setState(() {
        _status = 'Error: $e'; // Show error message
      });
    } finally {
      // Always hide the loading indicator when done
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Submits the user's answers for scoring and saving
  ///
  /// Validates that all questions have been answered, then
  /// marks each question as correct or incorrect and saves results to Firebase.
  Future<void> _submitAnswers() async {
    // Check if all questions have been answered
    if (_userAnswers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please answer all questions before submitting.")),
      );
      return;
    }
    setState(() {
      _submitted = true;
      _status = 'Answers submitted!';
    });

    // For each question, save a history item to Firebase.
    if (_questions != null) {
      for (int i = 0; i < _questions!.length; i++) {
        final q = _questions![i];
        final userAnswer = _userAnswers[i];
        final isCorrect = userAnswer == q.correctIndex;
        final historyItem = {
          "question": q.question,
          "options": q.options,
          "userAnswer": userAnswer,
          "correctIndex": q.correctIndex,
          "isCorrect": isCorrect,
        };
        await _firebaseService.addQuestionHistoryItem(
          exerciseType: "typos",
          historyItem: historyItem,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Putonghua Typos MC Exercise'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TyposHistoryScreen(exerciseType: "typos"),
              ));
            },
          ),
          IconButton(
            icon: Icon(Icons.favorite),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TyposFavoriteScreen(exerciseType: "typos"),
              ));
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(_status),
                  SizedBox(height: 16),
                  _isProcessing
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _generateMCQuestion,
                          child: Text('Generate MC Question'),
                        ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          if (_questions != null)
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _questions!.length,
              itemBuilder: (context, index) {
                final question = _questions![index];
                return QuestionCard(
                  question: question,
                  index: index,
                  submitted: _submitted,
                  selectedAnswer: _userAnswers[index],
                  onAnswerSelected: (value) {
                    setState(() {
                      _userAnswers[index] = value;
                    });
                  },
                );
              },
            ),
          SizedBox(height: 16),
          if (_questions != null && !_submitted)
            ElevatedButton(
              onPressed: _submitAnswers,
              child: Text('Submit Answers'),
            ),
        ],
      ),
    );
  }
}

/// A card widget to display a multiple-choice question (no explanation).
class QuestionCard extends StatefulWidget {
  final Question question;
  final int index;
  final bool submitted;
  final int? selectedAnswer;
  final Function(int) onAnswerSelected;

  QuestionCard({
    required this.question,
    required this.index,
    required this.submitted,
    required this.selectedAnswer,
    required this.onAnswerSelected,
  });

  @override
  _QuestionCardState createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.question.question,
                style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 16),
            ...widget.question.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final option = entry.value;
              final isSelected = widget.selectedAnswer == idx;
              final isCorrect = widget.question.correctIndex == idx;
              Color? tileColor;
              if (widget.submitted) {
                if (isSelected) {
                  tileColor =
                      isCorrect ? Colors.green.shade100 : Colors.red.shade100;
                } else if (isCorrect) {
                  tileColor = Colors.green.shade100;
                }
              }
              return RadioListTile<int>(
                title: Text(option),
                value: idx,
                groupValue: widget.selectedAnswer,
                onChanged: widget.submitted
                    ? null
                    : (value) {
                        widget.onAnswerSelected(value!);
                      },
                tileColor: tileColor,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

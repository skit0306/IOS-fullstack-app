import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:p1/service/google_stt_service.dart';
import 'package:p1/service/openai_service.dart';
import 'package:p1/service/google_cloud_storage_api.dart';
import 'package:p1/service/transcribeLongAudio.dart';
import 'package:p1/service/convertFileToWav.dart';
import 'package:p1/service/azure_tts_service.dart';
import 'package:p1/service/firebase_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:p1/screens/ListeningFavoritesScreen.dart';
import 'package:p1/screens/ListeningHistoryScreen.dart';
import 'package:p1/widget/PerformanceUI.dart';

/// ListeningScreen
///
/// A screen for practicing Putonghua listening comprehension through
/// audio exercises with multiple-choice questions. Supports both user-uploaded
/// audio files and AI-generated listening exercises.
class ListeningScreen extends StatefulWidget {
  final Map<String, dynamic>?
      exerciseData; // Optional data for redoing exercises from history

  const ListeningScreen({Key? key, this.exerciseData}) : super(key: key);

  @override
  _MandarinListeningPageState createState() => _MandarinListeningPageState();
}

class _MandarinListeningPageState extends State<ListeningScreen> {
  // Service instances
  final GoogleSTTService _sttService = GoogleSTTService();
  late OpenAIService _openAIService;
  late FirebaseService _firebaseService;

  // State variables
  bool _isProcessing = false; // Tracks when audio is being processed
  bool _isAnalyzing = false; // Tracks when performance is being analyzed
  String _status = ''; // Current status message shown to user
  String? _transcript; // Transcription of audio content
  List<Question>? _questions; // Generated questions based on transcript
  bool _showTranscript = false; // Controls transcript visibility
  bool _submitted = false; // Whether answers have been submitted
  List<int?> _userAnswers = []; // User's selected answers
  String? _originalFilePath; // Path to the audio file

  // Scene selection state variables
  final List<String> _scenes = ['Daily', 'Travel', 'Academic', 'Business'];
  String _selectedScene = 'Daily';

  // Performance tracking variables
  bool _showPerformance = true; // Controls performance UI visibility
  Map<String, dynamic> _currentPerformance =
      {}; // User's current performance metrics
  int _totalExercisesCompleted = 0; // Total exercises user has completed
  String? _exerciseId; // Unique ID for the current exercise

  @override
  void initState() {
    super.initState();
    _initializeServices().then((_) {
      // Load performance data
      _loadPerformanceData();

      // After services are initialized, set up the exercise if needed
      if (widget.exerciseData != null) {
        _handleRedoFromHistory();
      }
    });
  }

  /// Loads user's performance data from Firebase
  ///
  /// Retrieves general performance metrics and scene-specific
  /// data for the currently selected scene.
  Future<void> _loadPerformanceData() async {
    try {
      final performance = await _firebaseService.getCurrentPerformance();
      final scenePerformance = await _firebaseService
          .getScenePerformance(_selectedScene.toLowerCase());

      setState(() {
        _currentPerformance = performance;
        _totalExercisesCompleted = performance['totalExercisesCompleted'] ?? 0;

        // Update scene-specific data if available
        if (scenePerformance != null && scenePerformance.isNotEmpty) {
          // Merge scene-specific data with current performance
          _currentPerformance = {
            ..._currentPerformance,
            'sceneScore': scenePerformance['score'],
            'sceneVocabulary': scenePerformance['vocabulary'],
          };
        }
      });
    } catch (e) {
      print('Error loading performance data: $e');
    }
  }

  /// Generates audio for a transcript using Azure TTS
  ///
  /// @param transcript - The text to convert to speech
  Future<void> _generateAudioFromTranscript(String transcript) async {
    setState(() {
      _status = 'Generating audio from transcript...';
    });

    final azureTTS = AzureTTSService(
    );

    final audioBytes = await azureTTS.textToSpeech(transcript);
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/exercise_audio.mp3';
    final audioFile = File(tempPath);
    await audioFile.writeAsBytes(audioBytes);

    setState(() {
      _originalFilePath = audioFile.path;
    });
  }

  /// Sets up an exercise based on history data
  ///
  /// Used when redoing an exercise from history.
  Future<void> _handleRedoFromHistory() async {
    setState(() {
      _status = 'Preparing exercise from history...';
    });

    // Set transcript from history data
    final transcript = widget.exerciseData!["transcript"] as String;

    // Always use the saved questions from history data
    final questionsData = widget.exerciseData!["questions"] as List<dynamic>;
    final questions = List<Question>.from(questionsData.map((q) {
      return Question(
        question: q["question"],
        options: List<String>.from(q["options"]),
        correctIndex: q["correctIndex"],
        explanation: q["explanation"] ?? "",
      );
    }));

    setState(() {
      _transcript = transcript;
      _questions = questions;
      _userAnswers = List<int?>.filled(questions.length, null);
      _submitted = false;
    });

    // Generate audio from the transcript
    await _generateAudioFromTranscript(transcript);

    setState(() {
      _status = 'Ready!';
    });
  }

  /// Initializes required services
  ///
  /// Sets up Google STT, OpenAI, and Firebase services.
  Future<void> _initializeServices() async {
    setState(() => _status = 'Initializing services...');
    try {
      await _sttService.initialize();
      _openAIService = OpenAIService();
      _firebaseService = FirebaseService();
      setState(() => _status = 'Ready to process audio');
    } catch (e) {
      setState(() => _status = 'Error initializing services: $e');
    }
  }

  /// Handles user-selected audio file processing
  ///
  /// Allows user to pick an audio file, transcribes it, and
  /// generates questions based on the content.
  Future<void> _pickAndProcessAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'wav',
          'm4a',
          'aac',
          'ogg',
          'mp4',
          'mov',
          'avi'
        ],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _status = 'No file selected');
        return;
      }
      final file = result.files.first;
      if (file.path == null) {
        setState(() => _status = 'Invalid file path');
        return;
      }
      _originalFilePath = file.path!;
      setState(() {
        _isProcessing = true;
        _status = 'Converting audio...';
      });
      String processedPath = file.path!;
      processedPath = await convertFileToWav(processedPath);
      setState(() => _status = 'Transcribing audio...');
      final gcsUri = await uploadAudioToGCS(processedPath);
      final transcript =
          await transcribeLongAudio(gcsUri, _sttService.accessToken!);
      setState(() {
        _transcript = transcript;
        _status = 'Generating questions...';
      });
      final questions =
          await _openAIService.generateQuestions(transcript, _selectedScene);
      setState(() {
        _questions = questions;
        _userAnswers = List<int?>.filled(questions.length, null);
        _submitted = false;
        _status = 'Ready!';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Generates an AI-created listening exercise
  ///
  /// Creates a personalized exercise based on user performance data,
  /// generates audio using TTS, and creates comprehension questions.
  Future<void> _generateExercise() async {
    try {
      setState(() {
        _isProcessing = true;
        _status = 'Generating exercise transcript...';
      });

      String exerciseTranscript;

      // Check if we have performance data to personalize the exercise
      if (_currentPerformance.isNotEmpty) {
        // Use personalized generation based on performance data
        exerciseTranscript =
            await _openAIService.generatePersonalizedTranscript(
          scene: _selectedScene,
          performanceData: _currentPerformance,
        );
      } else {
        // Fall back to standard generation
        exerciseTranscript =
            await _openAIService.generateExerciseTranscript(_selectedScene);
      }

      // Generate a unique exercise ID
      _exerciseId = DateTime.now().millisecondsSinceEpoch.toString();

      setState(() {
        _status = 'Generating audio from transcript...';
      });
      final azureTTS = AzureTTSService(
      );
      final audioBytes = await azureTTS.textToSpeech(exerciseTranscript);
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/exercise_audio.mp3';
      final audioFile = File(tempPath);
      await audioFile.writeAsBytes(audioBytes);
      final newAudioFilePath = audioFile.path;
      setState(() {
        _transcript = exerciseTranscript;
        _originalFilePath = newAudioFilePath;
        _status = 'Playing audio...';
      });
      final questions = await _openAIService.generateQuestions(
          exerciseTranscript, _selectedScene);
      setState(() {
        _questions = questions;
        _userAnswers = List<int?>.filled(questions.length, null);
        _submitted = false;
        _status = 'Ready!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Handles submission of user answers
  ///
  /// Analyzes user performance, saves results to Firebase,
  /// and updates the UI to show correct answers and explanations.
  Future<void> _submitAnswers() async {
    if (_userAnswers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please answer all questions before submitting.")),
      );
      return;
    }
    setState(() {
      _isAnalyzing = true;
      _status = 'Analyzing performance, please wait...';
    });
    try {
      // Increment exercise count
      _totalExercisesCompleted++;

      // Generate exercise ID if not already set
      if (_exerciseId == null) {
        _exerciseId = DateTime.now().millisecondsSinceEpoch.toString();
      }

      // Get detailed performance analysis
      final performance = await _openAIService.analyzeDetailedPerformance(
        transcript: _transcript!,
        questions: _questions!,
        userAnswers: _userAnswers,
        scene: _selectedScene,
        exerciseId: _exerciseId!,
        totalExercisesCompleted: _totalExercisesCompleted,
      );

      // Save the detailed performance data
      await _firebaseService.saveLanguagePerformance(performance);

      // Track scene-specific exercise completion
      await _firebaseService.trackSceneExercise(
        _selectedScene.toLowerCase(),
        performance.scenePerformance[_selectedScene] ??
            performance.overallScore,
      );

      // Save the exercise history to Firebase
      final historyItem = {
        "transcript": _transcript,
        "questions": _questions!
            .map((q) => {
                  "question": q.question,
                  "options": q.options,
                  "correctIndex": q.correctIndex,
                  "explanation": q.explanation,
                })
            .toList(),
        "userAnswers": _userAnswers,
        "timestamp": FieldValue.serverTimestamp(),
        "scene": _selectedScene,
        "performance": {
          "overallScore": performance.overallScore,
          "strengthAreas": performance.strengthAreas,
          "improvementAreas": performance.improvementAreas,
        },
      };

      await _firebaseService.addListeningHistoryItem(
        exerciseType: "listening",
        historyItem: historyItem,
      );

      // Update local performance data to reflect latest results
      setState(() {
        _currentPerformance = {
          'listeningScore': performance.listeningScore,
          'overallScore': performance.overallScore,
          'strengthAreas': performance.strengthAreas,
          'improvementAreas': performance.improvementAreas,
          'scenePerformance': performance.scenePerformance,
          'totalExercisesCompleted': _totalExercisesCompleted,
        };
        _submitted = true;
        _status = 'Results submitted!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error submitting results: $e';
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Putonghua Listening Practice'),
        actions: [
          // Toggle performance view
          IconButton(
            icon: Icon(
                _showPerformance ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showPerformance = !_showPerformance;
              });
            },
            tooltip: _showPerformance ? 'Hide performance' : 'Show performance',
          ),
          // Favorites button
          IconButton(
            icon: Icon(Icons.favorite),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListeningFavoritesScreen(
                    exerciseType: "listening",
                  ),
                ),
              );

              // Handle return from favorites screen with redo action
              if (result != null &&
                  result is Map<String, dynamic> &&
                  result.containsKey('action') &&
                  result['action'] == 'redo') {
                // Reset the current state and load the exercise directly from the result
                setState(() {
                  _isProcessing = true;
                  _status = 'Loading exercise from favorites...';
                  _submitted = false;
                  _showTranscript = false;
                  _originalFilePath = null;

                  // Set transcript and questions directly from result
                  _transcript = result['transcript'];

                  // Convert questions data back to Question objects
                  final questionsData = result['questions'] as List<dynamic>;
                  _questions = List<Question>.from(questionsData.map((q) {
                    return Question(
                      question: q["question"],
                      options: List<String>.from(q["options"]),
                      correctIndex: q["correctIndex"],
                      explanation: q["explanation"] ?? "",
                    );
                  }));

                  // Reset user answers
                  _userAnswers = List<int?>.filled(_questions!.length, null);
                });

                // Only generate audio from the transcript
                await _generateAudioFromTranscript(_transcript!);

                setState(() {
                  _isProcessing = false;
                  _status = 'Ready!';
                });
              }
            },
          ),
          // History button
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListeningHistoryScreen(
                    exerciseType: "listening",
                  ),
                ),
              );

              // Handle return from history screen with redo action
              if (result != null &&
                  result is Map<String, dynamic> &&
                  result.containsKey('action') &&
                  result['action'] == 'redo') {
                // Reset the current state and load the exercise directly from the result
                setState(() {
                  _isProcessing = true;
                  _status = 'Loading exercise from history...';
                  _submitted = false;
                  _showTranscript = false;
                  _originalFilePath = null;

                  // Set transcript and questions directly from result
                  _transcript = result['transcript'];

                  // Convert questions data back to Question objects
                  final questionsData = result['questions'] as List<dynamic>;
                  _questions = List<Question>.from(questionsData.map((q) {
                    return Question(
                      question: q["question"],
                      options: List<String>.from(q["options"]),
                      correctIndex: q["correctIndex"],
                      explanation: q["explanation"] ?? "",
                    );
                  }));

                  // Reset user answers
                  _userAnswers = List<int?>.filled(_questions!.length, null);
                });

                // Only generate audio from the transcript
                await _generateAudioFromTranscript(_transcript!);

                setState(() {
                  _isProcessing = false;
                  _status = 'Ready!';
                });
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.all(16),
            // Add cacheExtent to load widgets slightly outside the viewport
            cacheExtent: 1000,
            children: [
              // Performance summary card (if available and visible)
              if (_showPerformance && _currentPerformance.isNotEmpty)
                PerformanceSummaryCard(
                  performanceData: _currentPerformance,
                  onViewDetails: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PerformanceDetailScreen(
                          uid: _firebaseService.uid,
                        ),
                      ),
                    );
                  },
                ),

              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(_status),
                      SizedBox(height: 16),
                      // Scene selection dropdown.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Select Scene: "),
                          DropdownButton<String>(
                            value: _selectedScene,
                            items: _scenes
                                .map((scene) => DropdownMenuItem(
                                      child: Text(scene),
                                      value: scene,
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedScene = value!;
                                // Reload performance data for this scene
                                _loadPerformanceData();
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _isProcessing
                          ? CircularProgressIndicator()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: _pickAndProcessAudio,
                                  child: Text('Select Audio File'),
                                ),
                                ElevatedButton(
                                  onPressed: _generateExercise,
                                  child: Text('Generate'),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (_originalFilePath != null) ...[
                // Wrap the audio player in a Container with a fixed height to prevent layout shifts
                Container(
                  // Use a unique key based on the file path to ensure proper rebuilding
                  key: ValueKey(_originalFilePath),
                  child: AudioPlayerWidget(
                    filePath: _originalFilePath!,
                  ),
                ),
                SizedBox(height: 16),
              ],
              if (_transcript != null) ...[
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showTranscript = !_showTranscript;
                    });
                  },
                  child: Text(
                      _showTranscript ? 'Hide Transcript' : 'Show Transcript'),
                ),
                SizedBox(height: 8),
                if (_showTranscript)
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transcript:',
                              style: Theme.of(context).textTheme.titleLarge),
                          SizedBox(height: 8),
                          Text(_transcript!),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 16),
              ],
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
                      onAnswerSelected: (answerIndex) {
                        setState(() {
                          _userAnswers[index] = answerIndex;
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
          if (_isAnalyzing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing performance, please wait...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// AudioPlayerWidget plays the given file and provides controls for seeking and adjusting speed.
/// This widget uses AutomaticKeepAliveClientMixin to prevent it from being disposed when scrolled out of view.
class AudioPlayerWidget extends StatefulWidget {
  final String filePath;
  const AudioPlayerWidget({Key? key, required this.filePath}) : super(key: key);

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with AutomaticKeepAliveClientMixin {
  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isPlaying = false;

  /// Keeps this widget alive even when it's scrolled off screen
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  /// Sets up the audio player with the file and listeners
  Future<void> _initPlayer() async {
    try {
      await _player.setFilePath(widget.filePath);
      _duration = _player.duration ?? Duration.zero;
      setState(() {});

      // Listen to position changes
      _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
      });

      // Listen to player state changes
      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });
    } catch (e) {
      print("Error initializing audio player: $e");
    }
  }

  @override
  void didUpdateWidget(covariant AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize player if file path changes
    if (widget.filePath != oldWidget.filePath) {
      _player.setFilePath(widget.filePath).then((_) {
        if (mounted) {
          _duration = _player.duration ?? Duration.zero;
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Formats a duration as mm:ss
  ///
  /// @param d - Duration to format
  /// @return Formatted duration string
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.replay_10),
                onPressed: () {
                  final newPosition = _position - Duration(seconds: 10);
                  _player.seek(newPosition < Duration.zero
                      ? Duration.zero
                      : newPosition);
                },
              ),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (_isPlaying) {
                    _player.pause();
                  } else {
                    _player.play();
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.forward_10),
                onPressed: () {
                  final newPosition = _position + Duration(seconds: 10);
                  _player
                      .seek(newPosition > _duration ? _duration : newPosition);
                },
              ),
            ],
          ),
          Slider(
            value: _position.inMilliseconds.toDouble(),
            max: _duration.inMilliseconds > 0
                ? _duration.inMilliseconds.toDouble()
                : 1.0,
            onChanged: (value) {
              _player.seek(Duration(milliseconds: value.toInt()));
            },
          ),
          Text('${_formatDuration(_position)} / ${_formatDuration(_duration)}'),
          SizedBox(height: 8),
          Text('Playback Speed: ${_playbackSpeed.toStringAsFixed(1)}x'),
          Slider(
            value: _playbackSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: _playbackSpeed.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _playbackSpeed = value;
              });
              _player.setSpeed(value);
            },
          ),
        ],
      ),
    );
  }
}

/// A card widget to display a multiple-choice question with options.
///
/// Handles user selection and shows correct/incorrect answers after submission.
class QuestionCard extends StatefulWidget {
  final Question question; // The question data
  final int index; // Index of this question in the list
  final bool submitted; // Whether answers have been submitted
  final int? selectedAnswer; // User's selected answer index
  final Function(int) onAnswerSelected; // Callback when user selects an answer

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
            // Question text
            Text(widget.question.question,
                style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 16),
            // Answer options as radio buttons
            ...widget.question.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final option = entry.value;
              final isSelected = widget.selectedAnswer == idx;
              final isCorrect = widget.question.correctIndex == idx;

              // Set background colors for submitted answers
              Color? tileColor;
              if (widget.submitted) {
                if (isSelected) {
                  // User's selection - green if correct, red if incorrect
                  tileColor =
                      isCorrect ? Colors.green.shade100 : Colors.red.shade100;
                } else if (isCorrect) {
                  // Highlight correct answer in green
                  tileColor = Colors.green.shade100;
                }
              }

              return RadioListTile<int>(
                title: Text(option),
                value: idx,
                groupValue: widget.selectedAnswer,
                onChanged: widget.submitted
                    ? null // Disable changing after submission
                    : (value) {
                        widget.onAnswerSelected(value!);
                      },
                tileColor: tileColor,
              );
            }).toList(),

            // Show explanation after submission
            if (widget.submitted)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Text('Explanation:',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(widget.question.explanation),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Extension method for FirebaseService to handle listening exercise history
extension FirebaseServiceListeningExtension on FirebaseService {
  /// Save a listening exercise history item to Firebase.
  ///
  /// @param exerciseType - Type of exercise (e.g., "listening")
  /// @param historyItem - Exercise data to save
  Future<void> addListeningHistoryItem({
    required String exerciseType,
    required Map<String, dynamic> historyItem,
  }) async {
    await addQuestionHistoryItem(
      exerciseType: exerciseType,
      historyItem: historyItem,
    );
  }
}

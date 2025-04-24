import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:p1/models/language_performance_model.dart';
import 'package:p1/service/firebase_service.dart';
import 'dart:math' as math;

/// A widget to display the user's current performance metrics
///
/// Shows a summary card with circular indicators for listening and overall scores,
/// strengths and areas to improve, and exercise completion statistics.
class PerformanceSummaryCard extends StatelessWidget {
  final Map<String, dynamic> performanceData; // Performance metrics to display
  final VoidCallback onViewDetails; // Callback when user taps "View details"

  const PerformanceSummaryCard({
    Key? key,
    required this.performanceData,
    required this.onViewDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extract performance data from the map with fallback values
    final listeningScore = performanceData['listeningScore'] ?? 0.0;
    final overallScore = performanceData['overallScore'] ?? 0.0;
    final strengthAreas =
        List<String>.from(performanceData['strengthAreas'] ?? []);
    final improvementAreas =
        List<String>.from(performanceData['improvementAreas'] ?? []);
    final totalExercises = performanceData['totalExercisesCompleted'] ?? 0;

    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card title
            Text(
              'Your Mandarin Performance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),

            // Score indicators - circular progress for listening and overall scores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Listening score circle
                CircularPercentIndicator(
                  radius: 60.0,
                  lineWidth: 10.0,
                  percent:
                      listeningScore / 100, // Convert percentage to 0-1 range
                  center: Text('${listeningScore.toStringAsFixed(1)}%'),
                  progressColor:
                      _getColorForScore(listeningScore), // Color based on score
                  header: Text('Listening',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                // Overall score circle
                CircularPercentIndicator(
                  radius: 60.0,
                  lineWidth: 10.0,
                  percent: overallScore / 100,
                  center: Text('${overallScore.toStringAsFixed(1)}%'),
                  progressColor: _getColorForScore(overallScore),
                  header: Text('Overall',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Strengths & Improvements sections (two columns)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Strengths column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Strengths:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      // Display up to 3 strengths with green check icons
                      ...strengthAreas
                          .map((s) => Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.green, size: 16),
                                    SizedBox(width: 4),
                                    Expanded(
                                        child: Text(s,
                                            style: TextStyle(fontSize: 12))),
                                  ],
                                ),
                              ))
                          .take(3), // Only show first 3 items
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // Improvement areas column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Focus Areas:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      // Display up to 3 improvement areas with orange trend icons
                      ...improvementAreas
                          .map((s) => Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.trending_up,
                                        color: Colors.orange, size: 16),
                                    SizedBox(width: 4),
                                    Expanded(
                                        child: Text(s,
                                            style: TextStyle(fontSize: 12))),
                                  ],
                                ),
                              ))
                          .take(3), // Only show first 3 items
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Exercise count statistic
            Text('Total exercises completed: $totalExercises',
                style: TextStyle(fontStyle: FontStyle.italic)),

            SizedBox(height: 12),

            // View details button (bottom right corner)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onViewDetails,
                child: Text('View details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a color based on the score value
  ///
  /// @param score - Score value (0-100)
  /// @return Color - Green for high scores, orange for medium, red for low
  Color _getColorForScore(double score) {
    if (score >= 80) return Colors.green; // Good score (80-100)
    if (score >= 60) return Colors.orange; // Average score (60-79)
    return Colors.red; // Poor score (0-59)
  }
}

/// A detailed performance view screen
///
/// Shows comprehensive language performance metrics with multiple tabs:
/// - Overview: Latest assessment with detailed metrics
/// - Progress: Performance trends over time
/// - Scenes: Performance breakdown by conversation context
class PerformanceDetailScreen extends StatefulWidget {
  final String uid; // User ID for fetching performance data

  const PerformanceDetailScreen({Key? key, required this.uid})
      : super(key: key);

  @override
  _PerformanceDetailScreenState createState() =>
      _PerformanceDetailScreenState();
}

class _PerformanceDetailScreenState extends State<PerformanceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // Controller for tab navigation
  late FirebaseService _firebaseService; // Service for Firebase operations
  List<LanguagePerformance> _performanceHistory =
      []; // User's performance history
  bool _isLoading = true; // Loading state flag

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this); // 3 tabs: Overview, Progress, Scenes
    _firebaseService = FirebaseService();
    _loadPerformanceData(); // Load data when screen initializes
  }

  /// Loads user's performance history from Firebase
  ///
  /// Updates state with performance data and handles loading errors
  Future<void> _loadPerformanceData() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      // Fetch performance history (limited to 20 most recent records)
      final history = await _firebaseService.getPerformanceHistory(limit: 20);

      setState(() {
        _performanceHistory = history;
        _isLoading = false; // Hide loading indicator
      });
    } catch (e) {
      setState(() {
        _isLoading = false; // Hide loading indicator even on error
      });

      // Show error message if widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading performance data: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose(); // Clean up tab controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Language Performance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Overview'), // Latest performance details
            Tab(text: 'Progress'), // Progress over time
            Tab(text: 'Scenes'), // Performance by conversation scene
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // Loading indicator
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(), // Tab 1: Overview
                _buildProgressTab(), // Tab 2: Progress
                _buildScenesTab(), // Tab 3: Scenes
              ],
            ),
    );
  }

  /// Builds the Overview tab content
  ///
  /// Shows detailed metrics for the latest performance assessment
  /// including strengths, weaknesses, and detailed language metrics.
  Widget _buildOverviewTab() {
    // Show message if no data available
    if (_performanceHistory.isEmpty) {
      return Center(child: Text('No performance data available'));
    }

    // Get the most recent performance record
    final latestPerformance = _performanceHistory.first;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Latest assessment card with date, score and AI recommendation
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Latest Assessment',
                      style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 8),
                  Text('Date: ${_formatDate(latestPerformance.timestamp)}'),
                  Text(
                      'Overall Score: ${latestPerformance.overallScore.toStringAsFixed(1)}%'),
                  Text('Exercise Type: ${latestPerformance.exerciseType}'),
                  SizedBox(height: 16),
                  Text('Recommendation:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  // AI recommendation in highlighted container
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(latestPerformance.aiRecommendation),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Strength & weakness details (two equal columns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Strengths card
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Strengths',
                            style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(height: 8),
                        // List all strengths with green check icons
                        ...latestPerformance.strengthAreas.map((s) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(child: Text(s)),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Areas to improve card
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Areas to Improve',
                            style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(height: 8),
                        // List all improvement areas with orange trend icons
                        ...latestPerformance.improvementAreas
                            .map((s) => Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.trending_up,
                                          color: Colors.orange, size: 16),
                                      SizedBox(width: 8),
                                      Expanded(child: Text(s)),
                                    ],
                                  ),
                                )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Additional detailed metrics card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detailed Metrics',
                      style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 16),
                  // Tone accuracy section (for Mandarin tones)
                  Text('Pronunciation & Tones',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _buildToneAccuracyChart(latestPerformance.toneAccuracy),
                  SizedBox(height: 16),
                  // Vocabulary & comprehension metrics grid
                  Text('Vocabulary & Comprehension',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _buildMetricsGrid([
                    {
                      'label': 'Complex Sentences',
                      'value': latestPerformance.complexSentenceComprehension
                    },
                    {
                      'label': 'Idioms & Expressions',
                      'value': latestPerformance.idiomComprehension
                    },
                    {
                      'label': 'Known Words',
                      'value':
                          latestPerformance.knownVocabulary.length.toDouble()
                    },
                    {
                      'label': 'Difficult Words',
                      'value': latestPerformance.difficultVocabulary.length
                          .toDouble()
                    },
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Progress tab content
  ///
  /// Shows a performance trend chart and detailed history list
  /// with clickable items for more details.
  Widget _buildProgressTab() {
    // Show message if no data available
    if (_performanceHistory.isEmpty) {
      return Center(child: Text('No performance history available'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress chart card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Progress Over Time',
                      style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 16),
                  // Chart showing performance trend over time
                  Container(
                    height: 250,
                    child: _buildSimpleLineChart(),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Performance history section title
          Text('Performance History',
              style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),

          // History list with clickable items for details
          ListView.builder(
            shrinkWrap: true, // Make ListView work inside ScrollView
            physics: NeverScrollableScrollPhysics(), // Prevent nested scrolling
            itemCount: _performanceHistory.length,
            itemBuilder: (context, index) {
              final performance = _performanceHistory[index];
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                      '${_formatDate(performance.timestamp)} - ${performance.exerciseType}'),
                  subtitle: Text(
                      'Score: ${performance.overallScore.toStringAsFixed(1)}%'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Show dialog with details when tapped
                    _showPerformanceDetails(performance);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds the Scenes tab content
  ///
  /// Shows performance metrics broken down by conversation scene
  /// (e.g., restaurant, hospital, shopping) with trends for each scene.
  Widget _buildScenesTab() {
    // Show message if no data available
    if (_performanceHistory.isEmpty) {
      return Center(child: Text('No scene performance data available'));
    }

    // Extract and aggregate scene data from all performance records
    final scenePerformance = <String, List<double>>{};

    for (var performance in _performanceHistory) {
      performance.scenePerformance.forEach((scene, score) {
        if (!scenePerformance.containsKey(scene)) {
          scenePerformance[scene] = [];
        }
        scenePerformance[scene]!.add(score);
      });
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance by Scene',
              style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 16),

          // Scene performance cards (one for each scene)
          ...scenePerformance.entries.map((entry) {
            final scene = entry.key;
            final scores = entry.value;
            // Calculate average score for this scene
            final averageScore = scores.isNotEmpty
                ? scores.reduce((a, b) => a + b) / scores.length
                : 0.0;

            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scene name (e.g., "Restaurant", "Hospital")
                    Text(scene,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 8),
                    // Progress bar showing average score
                    LinearPercentIndicator(
                      lineHeight: 20,
                      percent: averageScore / 100,
                      center: Text('${averageScore.toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      progressColor: _getColorForScore(averageScore),
                      backgroundColor: Colors.grey.shade200,
                      barRadius: Radius.circular(10),
                      animation: true,
                      animationDuration: 1000,
                    ),
                    SizedBox(height: 8),
                    // Number of exercises for this scene
                    Text('Based on ${scores.length} exercises',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, fontSize: 12)),
                    // Show trend chart if multiple scores exist
                    if (scores.length > 1) ...[
                      SizedBox(height: 16),
                      Text('Recent Trend:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Container(
                        height: 100,
                        child: _buildSimpleSceneProgressChart(scores),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),

          // Show message if no scene data
          if (scenePerformance.isEmpty)
            Center(child: Text('No scene data available yet')),
        ],
      ),
    );
  }

  /// Formats a date as YYYY-MM-DD
  ///
  /// @param date - DateTime to format
  /// @return Formatted date string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Shows a dialog with detailed performance information
  ///
  /// @param performance - The performance record to display
  void _showPerformanceDetails(LanguagePerformance performance) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialog title and basic information
                Text('Performance Details',
                    style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 8),
                Text('Date: ${_formatDate(performance.timestamp)}'),
                Text('Exercise: ${performance.exerciseType}'),
                Text('Score: ${performance.overallScore.toStringAsFixed(1)}%'),
                SizedBox(height: 16),
                // AI recommendation with highlighted background
                Text('Recommendation:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(performance.aiRecommendation),
                ),
                SizedBox(height: 16),
                // Strengths list with bullet points
                Text('Strengths:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...performance.strengthAreas.map((s) => Padding(
                      padding: EdgeInsets.only(left: 16, top: 4),
                      child: Text('• $s'),
                    )),
                SizedBox(height: 16),
                // Areas to improve list with bullet points
                Text('Areas to Improve:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...performance.improvementAreas.map((s) => Padding(
                      padding: EdgeInsets.only(left: 16, top: 4),
                      child: Text('• $s'),
                    )),
                SizedBox(height: 24),
                // Close button
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
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

  /// Builds a simple bar chart showing progress over time
  ///
  /// @return A bar chart widget showing scores for the last 6 performance records
  Widget _buildSimpleLineChart() {
    // Extract the last 6 performance records to show
    final historyToShow = _performanceHistory.length > 6
        ? _performanceHistory.sublist(0, 6)
        : _performanceHistory;

    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: historyToShow.reversed.map((performance) {
          final score = performance.overallScore;
          final height = (score / 100) * 180; // Max height is 180

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Score percentage above bar
              Text('${score.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 10)),
              SizedBox(height: 4),
              // Bar with color based on score
              Container(
                width: 20,
                height: height,
                decoration: BoxDecoration(
                  color: _getColorForScore(score),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
              SizedBox(height: 4),
              // Date label below bar
              Text(
                _formatDateShort(performance.timestamp),
                style: TextStyle(fontSize: 10),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Formats a date as MM/DD (month/day)
  ///
  /// @param date - DateTime to format
  /// @return Short formatted date string
  String _formatDateShort(DateTime date) {
    return '${date.month}/${date.day}';
  }

  /// Builds a simple chart showing progress for a specific scene
  ///
  /// @param scores - List of score values to display
  /// @return A bar chart showing the trend for this scene
  Widget _buildSimpleSceneProgressChart(List<double> scores) {
    // Only show the last 5 scores if there are more
    if (scores.length > 5) {
      scores = scores.sublist(scores.length - 5);
    }

    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: scores.asMap().entries.map((entry) {
          final index = entry.key;
          final score = entry.value;
          final height = (score / 100) * 80; // 80 is the max height

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Bar with color based on score
                Container(
                  width: 16,
                  height: height,
                  decoration: BoxDecoration(
                    color: _getColorForScore(score),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
                SizedBox(height: 4),
                // Exercise number label (1, 2, 3, etc.)
                Text(
                  '${(index + 1)}',
                  style: TextStyle(fontSize: 9),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Builds a chart showing tone accuracy for Mandarin pronunciation
  ///
  /// @param toneAccuracy - Map of tone names to accuracy percentages
  /// @return A widget with progress bars for each tone
  Widget _buildToneAccuracyChart(Map<String, double> toneAccuracy) {
    return Column(
      children: toneAccuracy.entries.map((entry) {
        final tone = entry.key; // Tone name (e.g., "First Tone")
        final accuracy = entry.value; // Accuracy percentage

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              // Tone label on the left
              SizedBox(
                width: 60,
                child:
                    Text(tone, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              // Progress bar showing accuracy
              Expanded(
                child: LinearPercentIndicator(
                  lineHeight: 18,
                  percent: accuracy / 100,
                  center: Text(
                    '${accuracy.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      // Ensure text is readable against background
                      color: accuracy > 50 ? Colors.white : Colors.black,
                    ),
                  ),
                  progressColor: _getColorForScore(accuracy),
                  backgroundColor: Colors.grey.shade200,
                  barRadius: Radius.circular(4),
                  animation: true,
                  animationDuration: 1000,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Builds a grid of metric tiles
  ///
  /// @param metrics - List of metrics with labels and values
  /// @return A grid of metric tiles with values
  Widget _buildMetricsGrid(List<Map<String, dynamic>> metrics) {
    return GridView.builder(
      shrinkWrap: true, // Make GridView work inside ScrollView
      physics: NeverScrollableScrollPhysics(), // Prevent nested scrolling
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 tiles per row
        childAspectRatio: 2.0, // Width:height ratio
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        final label = metric['label'] as String;
        final value = metric['value'] as double;

        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(fontSize: 12)),
              SizedBox(height: 4),
              // Format as integer for word counts, percentage for others
              Text(
                label.contains('Words')
                    ? value.toInt().toString()
                    : '${value.toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Returns a color based on the score value
  ///
  /// @param score - Score value (0-100)
  /// @return Color based on the score range
  Color _getColorForScore(double score) {
    if (score >= 80) return Colors.green; // Excellent (80-100)
    if (score >= 60) return Colors.orange; // Good (60-79)
    if (score >= 40) return Colors.amber; // Average (40-59)
    return Colors.red; // Poor (0-39)
  }
}

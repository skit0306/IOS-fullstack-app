class LanguagePerformance {
  // Core proficiency metrics
  final double listeningScore; // 0-100 score measuring overall listening comprehension
  final Map<String, double> phoneticAccuracy; // Map of phoneme to accuracy score
  final Map<String, double> toneAccuracy; // Accuracy for different tone patterns
  final double speechRate; // Words per minute recognized correctly
  
  // Vocabulary metrics
  final List<String> knownVocabulary; // Words consistently understood
  final List<String> difficultVocabulary; // Words consistently misunderstood
  final Map<String, int> vocabularyExposureCount; // How many times seen/heard
  
  // Contextual understanding
  final Map<String, double> scenePerformance; // Performance by context (daily, business, etc)
  final double complexSentenceComprehension; // Understanding of complex grammar
  final double idiomComprehension; // Understanding of idioms and expressions
  
  // Historical progress
  final DateTime timestamp;
  final String exerciseId; // Reference to specific exercise
  final String exerciseType; // Type of exercise (listening, reading, etc.)
  final int totalExercisesCompleted;
  
  // Performance summary
  final double overallScore;
  final List<String> strengthAreas;
  final List<String> improvementAreas;
  final String aiRecommendation;

  LanguagePerformance({
    this.listeningScore = 0.0,
    this.phoneticAccuracy = const {},
    this.toneAccuracy = const {},
    this.speechRate = 0.0,
    this.knownVocabulary = const [],
    this.difficultVocabulary = const [],
    this.vocabularyExposureCount = const {},
    this.scenePerformance = const {},
    this.complexSentenceComprehension = 0.0,
    this.idiomComprehension = 0.0,
    required this.timestamp,
    required this.exerciseId,
    required this.exerciseType,
    this.totalExercisesCompleted = 0,
    this.overallScore = 0.0,
    this.strengthAreas = const [],
    this.improvementAreas = const [],
    this.aiRecommendation = '',
  });

  // Convert to a map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'listeningScore': listeningScore,
      'phoneticAccuracy': phoneticAccuracy,
      'toneAccuracy': toneAccuracy,
      'speechRate': speechRate,
      'knownVocabulary': knownVocabulary,
      'difficultVocabulary': difficultVocabulary,
      'vocabularyExposureCount': vocabularyExposureCount,
      'scenePerformance': scenePerformance,
      'complexSentenceComprehension': complexSentenceComprehension,
      'idiomComprehension': idiomComprehension,
      'timestamp': timestamp,
      'exerciseId': exerciseId,
      'exerciseType': exerciseType,
      'totalExercisesCompleted': totalExercisesCompleted,
      'overallScore': overallScore,
      'strengthAreas': strengthAreas,
      'improvementAreas': improvementAreas,
      'aiRecommendation': aiRecommendation,
    };
  }

  // Create from Firebase data
  factory LanguagePerformance.fromMap(Map<String, dynamic> map) {
    return LanguagePerformance(
      listeningScore: map['listeningScore'] ?? 0.0,
      phoneticAccuracy: Map<String, double>.from(map['phoneticAccuracy'] ?? {}),
      toneAccuracy: Map<String, double>.from(map['toneAccuracy'] ?? {}),
      speechRate: map['speechRate'] ?? 0.0,
      knownVocabulary: List<String>.from(map['knownVocabulary'] ?? []),
      difficultVocabulary: List<String>.from(map['difficultVocabulary'] ?? []),
      vocabularyExposureCount: Map<String, int>.from(map['vocabularyExposureCount'] ?? {}),
      scenePerformance: Map<String, double>.from(map['scenePerformance'] ?? {}),
      complexSentenceComprehension: map['complexSentenceComprehension'] ?? 0.0,
      idiomComprehension: map['idiomComprehension'] ?? 0.0,
      timestamp: map['timestamp']?.toDate() ?? DateTime.now(),
      exerciseId: map['exerciseId'] ?? '',
      exerciseType: map['exerciseType'] ?? '',
      totalExercisesCompleted: map['totalExercisesCompleted'] ?? 0,
      overallScore: map['overallScore'] ?? 0.0,
      strengthAreas: List<String>.from(map['strengthAreas'] ?? []),
      improvementAreas: List<String>.from(map['improvementAreas'] ?? []),
      aiRecommendation: map['aiRecommendation'] ?? '',
    );
  }
}
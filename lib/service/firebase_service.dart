
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/language_performance_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the current user's UID.
  String get uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User is not logged in.");
    }
    return user.uid;
  }

  /// Save a question history item for a given exercise type.
  Future<void> addQuestionHistoryItem({
    required String exerciseType,
    required Map<String, dynamic> historyItem,
  }) async {
    final collectionRef = _firestore
        .collection("users")
        .doc(uid)
        .collection("exerciseHistory")
        .doc(exerciseType)
        .collection("historyItems");
    historyItem["timestamp"] = FieldValue.serverTimestamp();
    await collectionRef.add(historyItem);
  }

  /// Retrieve question history items for a given exercise type, ordered by timestamp descending.
  Future<QuerySnapshot<Map<String, dynamic>>> getQuestionHistory({
    required String exerciseType,
  }) async {
    final collectionRef = _firestore
        .collection("users")
        .doc(uid)
        .collection("exerciseHistory")
        .doc(exerciseType)
        .collection("historyItems");
    return await collectionRef.orderBy("timestamp", descending: true).get();
  }

  /// Save or update the user's profile data (e.g. weaknesses, strengths, etc.).
  /// Update the user's vocabulary for a given scene.
  /// New vocabulary items will replace any duplicates that exist in the opposite array.
  Future<void> updateUserVocabulary({
    required String scene,
    required List<String> newStrengths,
    required List<String> newWeaknesses,
  }) async {
    DocumentReference userDocRef = _firestore.collection("users").doc(uid);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userDocRef);
      final data = snapshot.data() as Map<String, dynamic>? ?? {};

      // Retrieve existing vocabulary for the scene, or empty lists if none.
      List<dynamic> currentStrengths =
          (data['vocabulary']?[scene]?['strengths'] as List<dynamic>?) ?? [];
      List<dynamic> currentWeaknesses =
          (data['vocabulary']?[scene]?['weaknesses'] as List<dynamic>?) ?? [];

      // Remove any word from the opposite field if it is in the new list.
      currentWeaknesses = currentWeaknesses
          .where((word) => !newStrengths.contains(word))
          .toList();
      currentStrengths = currentStrengths
          .where((word) => !newWeaknesses.contains(word))
          .toList();

      // Merge and remove duplicates.
      final updatedStrengths =
          Set<String>.from([...currentStrengths, ...newStrengths]).toList();
      final updatedWeaknesses =
          Set<String>.from([...currentWeaknesses, ...newWeaknesses]).toList();

      transaction.set(
          userDocRef,
          {
            'vocabulary': {
              scene: {
                'strengths': updatedStrengths,
                'weaknesses': updatedWeaknesses,
              }
            }
          },
          SetOptions(merge: true));
    });
  }

  /// Save an exercise result for a given exercise type.
  Future<void> saveExerciseResult({
    required String exerciseType,
    required Map<String, dynamic> resultData,
  }) async {
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("exerciseResults")
        .doc(exerciseType)
        .set(resultData, SetOptions(merge: true));
  }

  /// Retrieve the user's profile data.
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile() async {
    return await _firestore.collection("users").doc(uid).get();
  }

  /// Retrieve a specific exercise result.
  Future<DocumentSnapshot<Map<String, dynamic>>> getExerciseResult(
      String exerciseType) async {
    return await _firestore
        .collection("users")
        .doc(uid)
        .collection("exerciseResults")
        .doc(exerciseType)
        .get();
  }

  /// Delete a history item from a given exercise type.
  Future<void> deleteHistoryItem({
    required String exerciseType,
    required String historyId,
  }) async {
    final docRef = _firestore
        .collection("users")
        .doc(uid)
        .collection("exerciseHistory")
        .doc(exerciseType)
        .collection("historyItems")
        .doc(historyId);
    await docRef.delete();
  }

  /// Add a favorite item for a given exercise type.
  Future<void> addFavoriteQuestionItem({
    required String exerciseType,
    required String historyId,
    required Map<String, dynamic> favoriteItem,
  }) async {
    final favRef = _firestore
        .collection("users")
        .doc(uid)
        .collection("favorites")
        .doc(exerciseType)
        .collection("favoriteItems")
        .doc(historyId); 
  
    favoriteItem["timestamp"] = FieldValue.serverTimestamp();
    await favRef.set(favoriteItem);
  }

  /// Remove a favorite item for a given exercise type.
  Future<void> removeFavoriteQuestionItem({
    required String exerciseType,
    required String historyId,
  }) async {
    final favRef = _firestore
        .collection("users")
        .doc(uid)
        .collection("favorites")
        .doc(exerciseType)
        .collection("favoriteItems")
        .doc(historyId);
    await favRef.delete();
  }

  /// Retrieve favorite items for a given exercise type.
  Future<QuerySnapshot<Map<String, dynamic>>> getFavoriteQuestions({
    required String exerciseType,
  }) async {
    final collectionRef = _firestore
        .collection("users")
        .doc(uid)
        .collection("favorites")
        .doc(exerciseType)
        .collection("favoriteItems");
    return await collectionRef.orderBy("timestamp", descending: true).get();
  }

  Future<void> saveLanguagePerformance(LanguagePerformance performance) async {
    // Save full performance record to history collection
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("performanceHistory")
        .add(performance.toMap());

    // Update user's current performance summary with the latest data
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("performance")
        .doc("performance")
        .set({
      'currentPerformance': {
        'listeningScore': performance.listeningScore,
        'overallScore': performance.overallScore,
        'lastUpdated': FieldValue.serverTimestamp(),
        'strengthAreas': performance.strengthAreas,
        'improvementAreas': performance.improvementAreas,
        'scenePerformance': performance.scenePerformance,
        'totalExercisesCompleted': performance.totalExercisesCompleted,
      }
    }, SetOptions(merge: true));
  }

  /// Get user's language performance history
  Future<List<LanguagePerformance>> getPerformanceHistory(
      {int limit = 10}) async {
    final querySnapshot = await _firestore
        .collection("users")
        .doc(uid)
        .collection("performanceHistory")
        .orderBy("timestamp", descending: true)
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) => LanguagePerformance.fromMap(doc.data()))
        .toList();
  }

  /// Get user's current performance summary
  Future<Map<String, dynamic>> getCurrentPerformance() async {
    final docSnapshot = await _firestore
        .collection("users")
        .doc(uid)
        .collection("performance")
        .doc("performance")
        .get();

    final data = docSnapshot.data() ?? {};
    return data['currentPerformance'] ?? {};
  }

  /// Get performance metrics for a specific scene
  Future<Map<String, dynamic>> getScenePerformance(String scene) async {
    final docSnapshot = await _firestore
        .collection("users")
        .doc(uid)
        .collection("performance")
        .doc("performance")
        .get();

    final data = docSnapshot.data() ?? {};
    final currentPerformance = data['currentPerformance'] ?? {};
    final scenePerformance = currentPerformance['scenePerformance'] ?? {};

    return {
      'score': scenePerformance[scene] ?? 0.0,
      'vocabulary': data['vocabulary']?[scene] ?? {},
    };
  }

  /// Track recent exercises by scene for better personalization
  Future<void> trackSceneExercise(String scene, double score) async {
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("sceneStats")
        .doc(scene)
        .set({
      'count': FieldValue.increment(1),
      'lastAccessed': FieldValue.serverTimestamp(),
      'recentScores': FieldValue.arrayUnion([score]),
    }, SetOptions(merge: true));
  }
}

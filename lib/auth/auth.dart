import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Auth class
///
/// This class handles all authentication operations including:
/// - Email and password authentication
/// - Google sign-in
/// - Password recovery
/// - User state management
class Auth {
  // Firebase authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Google sign-in instance for OAuth authentication
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Returns the currently logged in user or null if no user is logged in
  User? get currentUSer => _auth.currentUser;

  /// Stream that emits an event whenever the authentication state changes
  /// Used to listen for sign-in, sign-out, and other auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in a user with their email and password
  /// @throws FirebaseAuthException if sign-in fails
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Creates a new user account with email and password
  /// @throws FirebaseAuthException if account creation fails
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  /// Signs out the current user from both Firebase and Google accounts
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  /// Sends a password reset email to the specified email address
  Future forgotPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (err) {
      throw Exception(err.message.toString());
    } catch (err) {
      throw Exception(err.toString());
    }
  }

  /// Performs Google sign-in authentication
  ///
  /// The method follows OAuth 2.0 flow:
  /// 1. Prompts user to select a Google account
  /// 2. Gets authentication tokens
  /// 3. Creates Firebase credential from Google tokens
  /// 4. Signs in to Firebase with that credential
  ///
  /// @return UserCredential object containing user information
  /// @throws Exception if the sign-in process fails at any step
  Future<UserCredential> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    // Obtain the auth details from the request
    final GoogleSignInAuthentication? googleAuth =
        await googleUser?.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );

    // Once signed in, return the UserCredential
    return await _auth.signInWithCredential(credential);
  }
}

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'dart:convert';
import 'dart:io';

/// GoogleSTTService
///
/// Service class that handles communication with Google Cloud's Speech-to-Text API.
/// Converts Putonghua (Mandarin Chinese) audio recordings to text.
class GoogleSTTService {
  late Map<String, dynamic>
      _credentials; // Google Cloud service account credentials
  String? _accessToken; // OAuth2 access token for API authentication
  bool _isInitialized = false; // Initialization state flag

  /// Initializes the service with Google Cloud credentials
  ///
  /// Loads service account credentials from asset file and obtains
  /// an initial access token for API authentication.
  /// Must be called before using other methods.
  Future<void> initialize() async {
    try {
      // Load credentials file from assets
      final String credentialsFile = await rootBundle
          .loadString('assets/credentials/google_cloud_credentials.json');
      _credentials = jsonDecode(credentialsFile); // Parse JSON credentials

      // Get initial access token
      await _getAccessToken();
      _isInitialized = true; // Mark service as initialized
    } catch (e) {
      print('Failed to initialize STT service: $e');
      throw Exception('Failed to initialize STT service: $e');
    }
  }

  /// Obtains an OAuth2 access token from Google's authentication service
  ///
  /// Creates a signed JWT from service account credentials and exchanges it
  /// for an access token using OAuth2 JWT bearer flow.
  Future<void> _getAccessToken() async {
    try {
      // Generate signed JWT for authentication
      final jwt = _generateJWT();

      // Exchange JWT for access token
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type':
              'urn:ietf:params:oauth:grant-type:jwt-bearer', // OAuth2 JWT bearer flow
          'assertion': jwt, // The signed JWT
        },
      );

      // Process response
      if (response.statusCode == 200) {
        final tokenData = jsonDecode(response.body);
        _accessToken = tokenData['access_token']; // Extract access token
      } else {
        print('Token response: ${response.body}');
        throw Exception('Failed to get access token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get access token: $e');
    }
  }

  /// Generates a signed JWT (JSON Web Token) for authentication
  ///
  /// Creates a JWT with the necessary claims for Google Cloud API access
  /// and signs it with the service account's private key.
  ///
  /// @return Signed JWT string
  String _generateJWT() {
    final now = DateTime.now();
    final expiryTime = now.add(Duration(hours: 1)); // Token valid for 1 hour

    // Create JWT claims according to Google's requirements
    final claims = {
      'iss': _credentials['client_email'], // Issuer (service account email)
      'scope': 'https://www.googleapis.com/auth/cloud-platform', // API scope
      'aud': 'https://oauth2.googleapis.com/token', // Audience (token endpoint)
      'exp': expiryTime.millisecondsSinceEpoch ~/
          1000, // Expiration time (seconds)
      'iat': now.millisecondsSinceEpoch ~/ 1000, // Issued at time (seconds)
    };

    // Extract private key from credentials
    final privateKey = _credentials['private_key'];
    // Format key properly (replace escaped newlines with actual newlines)
    final formattedKey = privateKey.replaceAll(r'\n', '\n');

    // Sign the JWT using RSA-SHA256 algorithm
    final jwt = JWT(claims).sign(
      RSAPrivateKey(formattedKey),
      algorithm: JWTAlgorithm.RS256,
    );

    return jwt;
  }

  /// Transcribes an audio file to text using Google's Speech-to-Text API
  ///
  /// Reads an audio file from the file system, encodes it as base64,
  /// and sends it to Google's Speech API for transcription to Mandarin text.
  ///
  /// @param audioPath - Path to the audio file to transcribe
  /// @return Transcribed text in Simplified Chinese
  /// @throws Exception if service not initialized or transcription fails
  Future<String> transcribeAudio(String audioPath) async {
    // Verify service is initialized before proceeding
    if (!_isInitialized) {
      throw Exception('STT Service not initialized. Call initialize() first.');
    }

    try {
      // Check token and refresh if needed
      if (_accessToken == null) {
        await _getAccessToken();
      }

      // Read audio file and encode as base64
      final file = File(audioPath);
      final audioBytes = await file.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      // Call Google Speech-to-Text API
      final response = await http.post(
        Uri.parse('https://speech.googleapis.com/v1/speech:recognize'),
        headers: {
          'Authorization': 'Bearer $_accessToken', // Authentication header
          'Content-Type': 'application/json', // Content type
        },
        body: jsonEncode({
          'config': {
            'encoding': 'LINEAR16', // Audio encoding format
            'sampleRateHertz': 16000, // Sample rate in Hz
            'languageCode': 'zh-CN', // Mandarin Chinese language code
            'enableAutomaticPunctuation': true, // Add punctuation to results
            'model': 'default' // Speech recognition model
          },
          'audio': {'content': audioBase64} // Base64-encoded audio data
        }),
      );

      // Process API response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extract transcription text from results
        if (data['results'] != null && data['results'].isNotEmpty) {
          // Concatenate all transcription alternatives with newlines
          return data['results']
              .map((result) =>
                  result['alternatives'][0]['transcript'].toString())
              .join('\n');
        }
        return ''; // Return empty string if no results
      } else {
        // Log error response for debugging
        print('Transcription response: ${response.body}');
        throw Exception('Failed to transcribe: ${response.statusCode}');
      }
    } catch (e) {
      // Log and rethrow exceptions
      print('Transcription error: $e');
      throw Exception('Failed to transcribe audio: $e');
    }
  }

  /// Gets the current access token
  ///
  /// @return The current access token or null if not yet obtained
  String? get accessToken => _accessToken;
}

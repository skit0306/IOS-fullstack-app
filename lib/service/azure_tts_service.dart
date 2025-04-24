import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../api_key.dart';

/// AzureTTSService
///
/// Service for interacting with Microsoft Azure's Text-to-Speech API.
/// Converts text input to spoken audio in various Chinese voices.
class AzureTTSService {
  // API configuration
  final String subscriptionKey =
      'azure_tts_subscriptionKey'; // API key for authentication
  final String region = azure_tts_region; // Azure region (e.g., 'eastus')

  // Base URL for Azure Cognitive Services API
  String get _baseUrl => 'https://$region.api.cognitive.microsoft.com/';

  // Authentication token caching
  String? _accessToken; // Cached access token
  DateTime? _tokenExpiry; // Expiration time of the token

  /// Default constructor
  AzureTTSService();

  /// Obtains an access token from Azure for API authentication
  ///
  /// Returns a cached token if available and not expired, otherwise
  /// makes a request to Azure to get a new token.
  ///
  /// @return A valid access token as a String
  /// @throws Exception if token request fails
  Future<String> _getAccessToken() async {
    // Check if we have a valid cached token
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!; // Return cached token if still valid
    }

    // Request new token from Azure
    final response = await http.post(
      Uri.parse('${_baseUrl}sts/v1.0/issueToken'),
      headers: {
        'Ocp-Apim-Subscription-Key':
            subscriptionKey, // API key for authentication
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );

    // Handle response
    if (response.statusCode == 200) {
      _accessToken = response.body; // Store the new token

      // Set token expiry to 9 minutes (tokens are valid for 10 minutes,
      // we use 9 to be safe)
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 9));

      return _accessToken!;
    } else {
      throw Exception('Failed to get access token: ${response.statusCode}');
    }
  }

  /// Converts text to speech using Azure TTS API
  ///
  /// Takes input text and returns it as audio data in MP3 format.
  ///
  /// @param text - The text to convert to speech
  /// @param voice - The voice model to use (default: zh-CN-XiaoxiaoNeural)
  /// @return Raw audio data as Uint8List
  /// @throws Exception if the API request fails
  Future<Uint8List> textToSpeech(String text,
      {String voice = 'zh-CN-XiaoxiaoNeural'}) async {
    // Get authentication token
    final accessToken = await _getAccessToken();

    // Azure TTS endpoint URL
    final endpoint =
        'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';

    // Create SSML (Speech Synthesis Markup Language) document
    // This is the XML format that the TTS API requires
    final ssml = '''
<?xml version="1.0" encoding="UTF-8"?>
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-CN">
    <voice xml:lang="zh-CN" name="$voice">
        $text
    </voice>
</speak>''';

    // Make API request to convert text to speech
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $accessToken', // Token for authentication
        'Content-Type': 'application/ssml+xml', // Input format (SSML)
        'X-Microsoft-OutputFormat':
            'audio-16khz-128kbitrate-mono-mp3', // Output format (MP3)
        'User-Agent': 'flutter_app', // Identify our application
      },
      body: ssml, // Send the SSML document
    );

    // Handle the response
    if (response.statusCode == 200) {
      return response.bodyBytes; // Return raw audio bytes on success
    } else {
      // Log error details for debugging
      print('Error response: ${response.body}');
      print('SSML sent: $ssml');

      // Throw exception with detailed error information
      throw Exception(
          'Failed to convert text to speech: ${response.statusCode} - ${response.body}');
    }
  }
}

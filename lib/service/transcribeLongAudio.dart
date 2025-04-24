import 'dart:convert';
import 'package:http/http.dart' as http;

/// Transcribes a long audio file stored in Google Cloud Storage
///
/// Uses Google's Speech-to-Text API's asynchronous recognition for longer audio files.
/// This method is designed for audio files that exceed the ~1 minute limit of synchronous recognition.
///
/// @param gcsUri - Google Cloud Storage URI where the audio file is stored (gs://bucket/object)
/// @param accessToken - Valid OAuth2 access token for Google Cloud authentication
/// @return The transcribed text as a string
/// @throws Exception if transcription fails
Future<String> transcribeLongAudio(String gcsUri, String accessToken) async {
  // Construct the request body with the GCS URI and speech recognition configuration
  final requestBody = jsonEncode({
    'config': {
      'encoding': 'LINEAR16', // Audio encoding format (16-bit PCM)
      'sampleRateHertz': 16000, // Audio sample rate in hertz
      'languageCode': 'zh-CN', // Language code for Mandarin Chinese
      'enableAutomaticPunctuation': true, // Add punctuation to transcription
      'model': 'default' // Speech recognition model to use
    },
    'audio': {'uri': gcsUri} // GCS URI pointing to the audio file
  });

  // Call the longrunningrecognize endpoint to start the asynchronous operation
  final response = await http.post(
    Uri.parse('https://speech.googleapis.com/v1/speech:longrunningrecognize'),
    headers: {
      'Authorization':
          'Bearer $accessToken', // Authentication header with token
      'Content-Type': 'application/json', // Content type of request body
    },
    body: requestBody, // The JSON request payload
  );

  // Check if the operation was successfully started
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final operationName = data['name']; // Get the long-running operation name

    // Now poll the operation until it completes and returns results
    return await _pollOperation(operationName, accessToken);
  } else {
    // Log error details for debugging
    print('Long Running Recognition response: ${response.body}');
    throw Exception('Failed to transcribe: ${response.statusCode}');
  }
}

/// Polls a long-running operation until it completes
///
/// Repeatedly checks the status of an asynchronous Google API operation
/// and retrieves the result when it's complete.
///
/// @param operationName - The name/ID of the operation to poll
/// @param accessToken - Valid OAuth2 access token for Google Cloud authentication
/// @return The transcription result when complete
/// @throws Exception if polling fails or operation returns an error
Future<String> _pollOperation(String operationName, String accessToken) async {
  // Poll every few seconds until the operation is done
  while (true) {
    // Send GET request to check operation status
    final opResponse = await http.get(
      Uri.parse('https://speech.googleapis.com/v1/operations/$operationName'),
      headers: {
        'Authorization': 'Bearer $accessToken', // Authentication header
        'Content-Type': 'application/json', // Content type
      },
    );

    // Parse the operation status response
    final opData = jsonDecode(opResponse.body);

    // Check if the operation has completed
    if (opData['done'] == true) {
      // If operation contains a response, it was successful
      if (opData.containsKey('response')) {
        // Extract and combine all transcript segments
        final results = opData['response']['results'] as List<dynamic>;

        // Concatenate all transcript alternatives (usually just one per segment)
        final transcript = results
            .map((result) => result['alternatives'][0]['transcript'])
            .join('\n');

        return transcript; // Return the complete transcription
      } else {
        // If there's no response but operation is done, it failed
        throw Exception('Transcription failed: ${opData.toString()}');
      }
    }

    // Wait before checking again to avoid excessive API requests
    await Future.delayed(Duration(seconds: 5)); // Poll every 5 seconds
  }
}

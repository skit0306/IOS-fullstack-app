import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:p1/service/tensorflow_service.dart';
import 'package:p1/service/cedict_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:p1/service/azure_tts_service.dart';

/// ObjectDetectionScreen
///
/// A screen that allows users to take or select photos and identify objects
/// in the images. The app uses TensorFlow for object detection and provides
/// Chinese translations for the detected objects, with text-to-speech capabilities.
class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  // Service instances
  final TensorflowService _tensorflowService =
      TensorflowService(); // Machine learning model service
  final CedictService _cedictService =
      CedictService(); // Chinese-English dictionary service
  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio playback service
  late AzureTTSService _ttsService; // Text-to-speech service
  final ImagePicker _picker = ImagePicker(); // Image selection service

  // State variables
  String? _imagePath; // Path to the selected image
  List<dynamic>? _recognitions; // Detected objects in the image
  bool _isLoading = false; // Loading state indicator
  String? _errorMessage; // Error message to display
  Map<String, CedictEntry?> _translations =
      {}; // Dictionary entries for detected objects

  @override
  void initState() {
    super.initState();
    _initializeServices(); // Initialize all required services
  }

  /// Initializes TensorFlow model, dictionary, and TTS services
  ///
  /// Sets up all required services for object detection, translation,
  /// and audio playback. Shows loading state during initialization.
  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Initialize Azure Text-to-Speech service with API credentials
      _ttsService = AzureTTSService(
      );

      // Load TensorFlow model and Chinese dictionary in parallel
      await Future.wait([
        _tensorflowService.loadModel(),
        _cedictService.loadDictionary(),
      ]);
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to initialize services: $e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Handles image selection from camera or gallery
  ///
  /// @param source - The source of the image (camera or gallery)
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _imagePath = image.path;
        _recognitions = null; // Clear previous detection results
        _translations.clear(); // Clear previous translations
        _errorMessage = null; // Clear any previous errors
      });
      _detectObjects(); // Process the new image
    }
  }

  /// Detects objects in the selected image and translates labels
  ///
  /// Uses TensorFlow to identify objects and looks up Chinese translations
  /// for each detected object label.
  Future<void> _detectObjects() async {
    if (_imagePath != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _recognitions = null; // Clear previous results
        _translations.clear(); // Clear previous translations
      });

      try {
        // Process image with TensorFlow model
        final recognitions =
            await _tensorflowService.detectObjectsOnImage(_imagePath!);

        // Handle case where no objects were detected
        if (recognitions.isEmpty) {
          setState(() {
            _errorMessage = "No objects could be identified in the image.";
            _recognitions = []; // Ensure it's an empty list
            _isLoading = false;
          });
          return; // Exit the function
        }

        // Look up translations for each recognized object
        final translations = <String, CedictEntry?>{};
        for (var recognition in recognitions) {
          // Ensure the label exists and is a string before cleaning
          var label = recognition['label']?.toString();
          if (label != null) {
            label = cleanLabel(label); // Remove confidence percentage
            final results = _cedictService.lookup(label);
            translations[label] = results.isNotEmpty ? results.first : null;
          }
        }

        setState(() {
          _recognitions = recognitions;
          _translations = translations;
        });
      } catch (e) {
        // Handle errors from object detection or translation lookup
        setState(() {
          _errorMessage = "Error during processing: $e";
          _recognitions = []; // Ensure empty list on error
        });
      } finally {
        // This always runs, whether try succeeded or failed
        if (mounted) {
          // Check if widget is still mounted before calling setState
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// Pronounces the given text using text-to-speech
  ///
  /// @param text - The text to be spoken (typically an object label)
  Future<void> _speakText(String text) async {
    try {
      // Convert text to speech using Azure service
      final audioData = await _ttsService.textToSpeech(text);

      // Play the generated audio
      await _audioPlayer.setAudioSource(BytesAudioSource(audioData));
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  /// Removes confidence percentage from object labels
  ///
  /// @param label - The raw label from TensorFlow (e.g., "person (95%)")
  /// @return The cleaned label without confidence information (e.g., "person")
  String cleanLabel(String label) {
    // Remove percentage and parentheses if present
    int percentIndex = label.indexOf(' (');
    if (percentIndex != -1) {
      return label.substring(0, percentIndex).trim();
    }
    return label.trim();
  }

  @override
  void dispose() {
    // Clean up resources when the widget is disposed
    _tensorflowService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection'),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading indicator
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            // Error message display
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            // Image and detection results
            else if (_imagePath != null) ...[
              // Display the selected image
              Image.file(
                File(_imagePath!),
                height: 300,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              // Display detected objects with translations
              if (_recognitions != null && _recognitions!.isNotEmpty)
                Column(
                  children: _recognitions!.map((result) {
                    final label = cleanLabel(result['label'].toString());
                    final translation = _translations[label];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Object label with pronunciation button
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.volume_up),
                                  onPressed: () => _speakText(label),
                                ),
                              ],
                            ),
                            // Translation information if available
                            if (translation != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Pinyin: ${translation.pinyin}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...translation.definitions.map((def) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text('• $def'),
                                  )),
                            ] else
                              const Text(
                                'No translation found',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
            const SizedBox(height: 20),
            // Image selection buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick Image'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// BytesAudioSource
///
/// A custom audio source implementation for the just_audio package
/// that plays audio from an in-memory byte buffer.
class BytesAudioSource extends StreamAudioSource {
  final List<int> _buffer; // Raw audio data bytes

  BytesAudioSource(List<int> buffer) : _buffer = buffer;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0; // Default to start of buffer if not specified
    end ??= _buffer.length; // Default to end of buffer if not specified

    return StreamAudioResponse(
      sourceLength: _buffer.length, // Total length of the audio data
      contentLength: end - start, // Length of the requested segment
      offset: start, // Starting position in the buffer
      stream: Stream.value(_buffer.sublist(start, end)), // Stream of audio data
      contentType: 'audio/mpeg', // MIME type of the audio
    );
  }
}

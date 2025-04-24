// tensorflow_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// TensorflowService
///
/// A singleton service that handles object detection using TensorFlow Lite.
/// Loads a MobileNet v2 model and performs inference on images to identify objects.
class TensorflowService {
  // Singleton instance
  static final TensorflowService _tensorflowService =
      TensorflowService._internal();

  // Factory constructor returns the singleton instance
  factory TensorflowService() {
    return _tensorflowService;
  }

  // Private constructor for singleton pattern
  TensorflowService._internal();

  // Model resources
  Interpreter? _interpreter; // TensorFlow Lite interpreter instance
  List<String>? _labels; // Class labels for detection results

  /// Loads the TensorFlow model and labels from assets
  ///
  /// Initializes the TensorFlow interpreter with the MobileNet v2 model
  /// and loads class labels from a text file. Avoids reloading if already loaded.
  ///
  /// @throws Exception if model or labels cannot be loaded
  Future<void> loadModel() async {
    // Avoid reloading if already loaded
    if (_interpreter != null && _labels != null) {
      print('Model and labels already loaded.');
      return;
    }
    try {
      // Load the TensorFlow Lite model from assets
      _interpreter = await Interpreter.fromAsset('assets/mobilenet_v2.tflite');
      print('Model loaded successfully');

      // Load and parse the labels file
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData
          .split('\n') // Split by newline
          .map((label) => label.trim()) // Trim whitespace
          .where((label) => label.isNotEmpty) // Filter out empty lines
          .toList();
      print('Labels loaded successfully: ${_labels!.length} labels loaded');
    } catch (e) {
      print('Error loading model or labels: $e');
      rethrow;
    }
  }

  /// Detects objects in an image file
  ///
  /// Processes an image through the MobileNet model to identify objects,
  /// returning a list of detected items with confidence scores.
  ///
  /// @param imagePath - Path to the image file to analyze
  /// @return List of detection results with labels and confidence scores
  Future<List<dynamic>> detectObjectsOnImage(String imagePath) async {
    // Check if model and labels are loaded
    if (_interpreter == null || _labels == null) {
      print('Error: Model or labels not loaded');
      await loadModel(); // Attempt to load if not loaded
      if (_interpreter == null || _labels == null) {
        print('Error: Failed to load model/labels');
        return []; // Return empty list if loading failed
      }
    }

    try {
      // Load and decode the image file
      final imageData = File(imagePath).readAsBytesSync();
      final image = img.decodeImage(imageData);
      if (image == null) {
        print('Error: Could not decode image at path: $imagePath');
        return []; // Return empty list if image is invalid
      }

      // Resize image to 224x224 (MobileNet input size)
      final resizedImage = img.copyResize(image, width: 224, height: 224);
      var input = List.filled(1 * 224 * 224 * 3, 0.0); // Array for RGB values
      var inputIndex = 0;

      // Normalize image data to [-1, 1] range
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          var pixel = resizedImage.getPixel(x, y);
          input[inputIndex++] = (pixel.r - 127.5) / 127.5; // Normalize red
          input[inputIndex++] = (pixel.g - 127.5) / 127.5; // Normalize green
          input[inputIndex++] = (pixel.b - 127.5) / 127.5; // Normalize blue
        }
      }

      // Convert to Float32List for TensorFlow
      final inputArray = Float32List.fromList(input);
      final inputShape = [
        1,
        224,
        224,
        3
      ]; // BHWC format (batch, height, width, channels)

      // Prepare output buffer
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      var outputBuffer = List.generate(
          outputShape[0], (_) => List.filled(outputShape[1], 0.0),
          growable: false);

      // Run inference
      _interpreter!.run(
        inputArray.reshape(inputShape),
        outputBuffer,
      );

      // Process results
      var probabilities = outputBuffer[0]; // First batch result
      var results = <Map<String, dynamic>>[];

      // Filter results with confidence > 0.1
      for (var i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > 0.1) {
          // Only keep results above threshold
          if (i < _labels!.length) {
            // Add label and confidence to results
            results.add({
              'label': _labels![i],
              'confidence': probabilities[i],
            });
          } else {
            print(
                "Warning: Prediction index $i out of bounds for labels list (${_labels!.length})");
          }
        }
      }

      // Sort results by confidence (highest first)
      results.sort((a, b) =>
          (b['confidence'] as double).compareTo(a['confidence'] as double));

      // Take top 5 results
      final topResults = results.take(5).toList();

      // Return results if found
      if (topResults.isNotEmpty) {
        print('Detection results (threshold > 0.1): $topResults');
        return topResults;
      } else {
        print('No results met the 0.1 confidence threshold.');
        return []; // Return empty list if no objects detected
      }
    } catch (e) {
      // Log and handle any errors during processing
      print('Error running model inference: $e');
      print('Stack trace: ${StackTrace.current}');
      return []; // Return empty list on error
    }
  }

  /// Releases resources used by the TensorFlow interpreter
  ///
  /// Should be called when the service is no longer needed
  /// to free memory and resources.
  void dispose() {
    _interpreter?.close(); // Close the interpreter
    _interpreter = null; // Clear references
    _labels = null;
    print('TensorflowService disposed');
  }
}

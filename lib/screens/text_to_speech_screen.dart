import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:p1/service/azure_tts_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// TextToSpeechScreen
///
/// A screen that allows users to enter Chinese text and convert it to speech.
/// Offers multiple voice options and playback controls.
class TextToSpeechScreen extends StatefulWidget {
  const TextToSpeechScreen({super.key});

  @override
  State<TextToSpeechScreen> createState() => _TextToSpeechScreenState();
}

class _TextToSpeechScreenState extends State<TextToSpeechScreen> {
  final TextEditingController _textController =
      TextEditingController(); // Controls text input
  bool _isProcessing = false; // Flag for processing state
  late AzureTTSService _ttsService; // Text-to-speech service
  String _currentVoice = 'zh-CN-XiaoxiaoNeural'; // Selected voice model
  String? _audioFilePath; // Path to generated audio file

  @override
  void initState() {
    super.initState();
    _initializeTTS(); // Initialize the text-to-speech service
  }

  /// Initializes the Azure TTS service with API key and region
  void _initializeTTS() {
    _ttsService = AzureTTSService(
    );
  }

  /// Generates speech from the entered text
  ///
  /// Calls the Azure TTS service to convert text to speech, then
  /// saves the resulting audio data to a temporary file for playback.
  Future<void> _generateSpeech() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessing = true); // Show processing indicator

    try {
      // Generate speech audio data using Azure TTS
      final audioData = await _ttsService.textToSpeech(
        text,
        voice: _currentVoice, // Use selected voice model
      );

      // Save audio to a temporary file for playback
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/tts_audio.mp3';
      final audioFile = File(tempPath);
      await audioFile.writeAsBytes(audioData);

      setState(() {
        _audioFilePath = audioFile.path; // Update path to enable playback
        _isProcessing = false; // Hide processing indicator
      });
    } catch (e) {
      if (mounted) {
        // Show error message if speech generation fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating audio: $e')),
        );
        setState(() => _isProcessing = false); // Hide processing indicator
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside text field
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Text to Speech'),
          actions: [
            // Voice selection dropdown
            PopupMenuButton<String>(
              onSelected: (voice) {
                setState(() {
                  _currentVoice = voice; // Update selected voice
                  _audioFilePath =
                      null; // Clear existing audio when voice changes
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                // Different Chinese voice options with descriptions
                const PopupMenuItem<String>(
                  value: 'zh-CN-XiaoxiaoNeural',
                  child: Text('Xiaoxiao, Female, Warm'),
                ),
                const PopupMenuItem<String>(
                  value: 'zh-CN-YunxiNeural',
                  child: Text('Yunxi, Male, Clear'),
                ),
                const PopupMenuItem<String>(
                  value: 'zh-CN-XiaoyiNeural',
                  child: Text('Xiaoyi, Female, Gentle'),
                ),
                const PopupMenuItem<String>(
                  value: 'zh-CN-YunyangNeural',
                  child: Text('Yunyang, Male, Strong'),
                ),
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Text input field
                TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Enter text in Putonghua',
                    border: OutlineInputBorder(),
                    hintText: 'Type your text here...',
                  ),
                  maxLines: 5,
                  onChanged: (text) {
                    // Clear existing audio when text changes
                    setState(() {
                      if (_audioFilePath != null) {
                        _audioFilePath = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),
                // Generate speech button
                ElevatedButton.icon(
                  onPressed:
                      _textController.text.trim().isEmpty || _isProcessing
                          ? null // Disable button when empty or processing
                          : _generateSpeech, // Generate speech when clicked
                  icon: Icon(
                    _isProcessing
                        ? Icons
                            .hourglass_empty // Show hourglass when processing
                        : Icons.record_voice_over, // Show voice icon otherwise
                    color: _textController.text.trim().isEmpty || _isProcessing
                        ? Colors.grey // Grey when disabled
                        : Colors.white, // White when enabled
                  ),
                  label: Text(
                    _isProcessing ? 'Generating...' : 'Generate Speech',
                    style: TextStyle(
                      color:
                          _textController.text.trim().isEmpty || _isProcessing
                              ? Colors.grey // Grey when disabled
                              : Colors.white, // White when enabled
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: _textController.text.trim().isEmpty ||
                            _isProcessing
                        ? Colors.grey.shade300 // Grey background when disabled
                        : Theme.of(context)
                            .primaryColor, // Theme color when enabled
                  ),
                ),
                // Helper text when input is empty
                if (_textController.text.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Please enter some text to speak',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),
                // Audio player widget (only shown when audio is available)
                if (_audioFilePath != null) ...[
                  Container(
                    // Use a unique key based on the file path to ensure proper rebuilding
                    key: ValueKey(_audioFilePath),
                    child: AudioPlayerWidget(
                      filePath: _audioFilePath!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose(); // Clean up controller when widget is disposed
    super.dispose();
  }
}

/// AudioPlayerWidget
///
/// A widget that plays audio files and provides playback controls like
/// play/pause, seeking, and speed adjustment.
/// Uses AutomaticKeepAliveClientMixin to prevent it from being disposed when scrolled out of view.
class AudioPlayerWidget extends StatefulWidget {
  final String filePath; // Path to the audio file to play

  const AudioPlayerWidget({Key? key, required this.filePath}) : super(key: key);

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with AutomaticKeepAliveClientMixin {
  late AudioPlayer _player; // Audio player instance
  Duration _duration = Duration.zero; // Total duration of audio
  Duration _position = Duration.zero; // Current playback position
  double _playbackSpeed = 1.0; // Playback speed multiplier
  bool _isPlaying = false; // Playing state flag

  @override
  bool get wantKeepAlive =>
      true; // Keep this widget alive when scrolled out of view

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer(); // Initialize player with audio file
  }

  /// Initializes the audio player with the file and sets up listeners
  Future<void> _initPlayer() async {
    try {
      // Load audio file into player
      await _player.setFilePath(widget.filePath);
      _duration = _player.duration ?? Duration.zero;
      setState(() {});

      // Listen to position changes to update the slider
      _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
      });

      // Listen to player state changes to update play/pause button
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
    // Update audio source if file path changes
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
    _player.dispose(); // Clean up player resources
    super.dispose();
  }

  /// Formats a Duration into a readable MM:SS string
  ///
  /// @param d - The Duration to format
  /// @return A formatted time string (MM:SS)
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
          // Playback control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Skip backward 10 seconds button
              IconButton(
                icon: Icon(Icons.replay_10),
                onPressed: () {
                  final newPosition = _position - Duration(seconds: 10);
                  _player.seek(newPosition < Duration.zero
                      ? Duration.zero
                      : newPosition);
                },
              ),
              // Play/Pause toggle button
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
              // Skip forward 10 seconds button
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
          // Playback position slider
          Slider(
            value: _position.inMilliseconds.toDouble(),
            max: _duration.inMilliseconds > 0
                ? _duration.inMilliseconds.toDouble()
                : 1.0,
            onChanged: (value) {
              _player.seek(Duration(milliseconds: value.toInt()));
            },
          ),
          // Position and duration text display
          Text('${_formatDuration(_position)} / ${_formatDuration(_duration)}'),
          SizedBox(height: 8),
          // Playback speed control
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

/// BytesAudioSource
///
/// A custom implementation of StreamAudioSource for playing audio directly from memory.
/// Used by the TTS service to play audio data before saving it to a file.
class BytesAudioSource extends StreamAudioSource {
  final List<int> _buffer; // The audio data as a byte array

  BytesAudioSource(List<int> buffer) : _buffer = buffer;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0; // Default to start of buffer if not specified
    end ??= _buffer.length; // Default to end of buffer if not specified

    return StreamAudioResponse(
      sourceLength: _buffer.length, // Total length of audio data
      contentLength: end - start, // Length of requested segment
      offset: start, // Starting position in buffer
      stream: Stream.value(_buffer.sublist(start, end)), // Audio data stream
      contentType: 'audio/mpeg', // MIME type of audio
    );
  }
}

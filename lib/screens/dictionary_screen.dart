import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:p1/service/cedict_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:p1/service/azure_tts_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_drawing/path_drawing.dart';

/// GraphicsData
///
/// A model class for Chinese character stroke data loaded from the graphics.txt file.
/// Contains the character, SVG path data for strokes, and median points for animation.
class GraphicsData {
  final String character; // The Chinese character
  final List<String> strokes; // SVG path data for each stroke
  final List<dynamic> medians; // Points defining the median path of each stroke

  GraphicsData({
    required this.character,
    required this.strokes,
    required this.medians,
  });

  /// Creates a GraphicsData instance from a JSON map
  factory GraphicsData.fromJson(Map<String, dynamic> json) {
    return GraphicsData(
      character: json['character'],
      strokes: List<String>.from(json['strokes'] ?? []),
      medians: json['medians'] ?? [],
    );
  }
}

/// Loads stroke order graphics data from the assets file
///
/// Parses the graphics.txt file which contains JSON data for each character
/// and builds a map with characters as keys and GraphicsData as values.
/// @return A map of character to GraphicsData objects
Future<Map<String, GraphicsData>> loadGraphicsMap() async {
  final Map<String, GraphicsData> graphicsMap = {};
  String graphicsString =
      await rootBundle.loadString('assets/hanzi-strokes/graphics.txt');
  List<String> lines = graphicsString.split('\n');
  for (var line in lines.where((l) => l.trim().isNotEmpty)) {
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(line);
      final data = GraphicsData.fromJson(jsonMap);
      graphicsMap[data.character] = data;
    } catch (e) {
      print("Error parsing graphics line: $e");
    }
  }
  return graphicsMap;
}

/// --------------------------------------------------------------------------
/// Stroke Order Animation Widget (draws strokes fully and then animates medians)
/// --------------------------------------------------------------------------

/// StrokeOrderAnimation
///
/// A widget that animates the stroke order of Chinese characters.
/// Shows how a character is written by sequentially drawing strokes.
class StrokeOrderAnimation extends StatefulWidget {
  final List<String> strokes; // SVG path data for all strokes
  final List<dynamic> medians; // Median point data for all strokes

  const StrokeOrderAnimation({
    Key? key,
    required this.strokes,
    required this.medians,
  }) : super(key: key);

  @override
  _StrokeOrderAnimationState createState() => _StrokeOrderAnimationState();
}

class _StrokeOrderAnimationState extends State<StrokeOrderAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int currentStroke = 0; // Index of the stroke being animated

  @override
  void initState() {
    super.initState();
    // Configure animation controller with duration and completion listener
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener((status) {
        // When current stroke animation completes, move to next stroke
        if (status == AnimationStatus.completed) {
          setState(() {
            currentStroke++;
            if (currentStroke < widget.strokes.length) {
              _controller.forward(from: 0.0);
            }
          });
        }
      });
    // Start animation if there are strokes to animate
    if (widget.strokes.isNotEmpty) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant StrokeOrderAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset animation if the character data changes
    if (oldWidget.strokes != widget.strokes ||
        oldWidget.medians != widget.medians) {
      currentStroke = 0;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(300, 300),
          painter: StrokePainter(
            strokes: widget.strokes,
            medians: widget.medians,
            currentStroke: currentStroke,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

/// StrokePainter
///
/// CustomPainter implementation that draws Chinese character strokes.
/// Handles drawing the stroke outlines and animating the median paths.
class StrokePainter extends CustomPainter {
  final List<String> strokes; // SVG data for all strokes
  final List<dynamic> medians; // Median data for all strokes
  final int currentStroke; // Index of current stroke being animated
  final double progress; // Animation progress (0.0 to 1.0)

  StrokePainter({
    required this.strokes,
    required this.medians,
    required this.currentStroke,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Set up paint objects for the stroke outlines and median lines
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Increase medianPaint stroke width to fill the stroke
    final medianPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20 // increased from 2 to 4
      ..strokeCap = StrokeCap.round; // round caps for smoother appearance

    // Apply transformation to match the SVG coordinate system
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    canvas.scale(1, -1); // Flip Y axis (SVG has Y pointing down)
    canvas.translate(0, -900); // Offset to position correctly

    // Draw all strokes fully (outlines)
    for (int i = 0; i < strokes.length; i++) {
      try {
        Path path = parseSvgPathData(strokes[i]);
        canvas.drawPath(path, strokePaint);
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // Draw medians for completed strokes
    for (int i = 0; i < min(currentStroke, medians.length); i++) {
      Path medianPath = _buildMedianPath(medians[i]);
      canvas.drawPath(medianPath, medianPaint);
    }

    // Animate the current stroke's median
    if (currentStroke < medians.length) {
      Path fullMedianPath = _buildMedianPath(medians[currentStroke]);
      Path animatedMedian = extractPathUntil(fullMedianPath, progress);
      canvas.drawPath(animatedMedian, medianPaint);
    }

    canvas.restore();
  }

  /// Extracts a portion of a path based on the percentage
  ///
  /// @param path - The full path to extract from
  /// @param percent - The percentage (0.0 to 1.0) of the path to extract
  /// @return A new path representing the subpath
  Path extractPathUntil(Path path, double percent) {
    final PathMetrics metrics = path.computeMetrics();
    final Path extracted = Path();
    for (final metric in metrics) {
      final double len = metric.length * percent;
      extracted.addPath(metric.extractPath(0, len), Offset.zero);
    }
    return extracted;
  }

  /// Builds a Path from median data points
  ///
  /// @param medianData - List of points defining the median path
  /// @return A Path object connecting all the points
  Path _buildMedianPath(dynamic medianData) {
    final Path path = Path();
    if (medianData is List && medianData.isNotEmpty) {
      bool first = true;
      for (var point in medianData) {
        if (point is List && point.length >= 2) {
          double x = (point[0] as num).toDouble();
          double y = (point[1] as num).toDouble();
          if (first) {
            path.moveTo(x, y);
            first = false;
          } else {
            path.lineTo(x, y);
          }
        }
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.strokes != strokes ||
        oldDelegate.medians != medians;
  }
}

/// --------------------------------------------------------------------------
/// Dictionary Screen Implementation
/// --------------------------------------------------------------------------

/// DictionaryScreen
///
/// A screen where users can look up Chinese words to see their definitions,
/// pronunciation, and stroke order animations for single characters.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _controller = TextEditingController();
  final CedictService _cedictService = CedictService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AzureTTSService _ttsService;
  List<CedictEntry> _results = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  String? _error;

  // A map of graphics data keyed by the character
  Map<String, GraphicsData> _graphicsMap = {};

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initializes the dictionary and TTS services
  Future<void> _initializeServices() async {
    _ttsService = AzureTTSService(
    );
    // Load dictionary and graphics concurrently
    await Future.wait([
      _loadDictionary(),
      _loadGraphicsData(),
    ]);
  }

  /// Loads the Chinese-English dictionary data
  Future<void> _loadDictionary() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      await _cedictService.loadDictionary();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Loads character stroke data for animations
  Future<void> _loadGraphicsData() async {
    try {
      _graphicsMap = await loadGraphicsMap();
    } catch (e) {
      print("Error loading graphics data: $e");
    }
  }

  /// Performs a dictionary lookup for the given text
  ///
  /// @param text - The Chinese word to look up
  void _search(String? text) {
    if (text == null || text.isEmpty) return;
    setState(() {
      _results = _cedictService.lookup(text);
    });
  }

  /// Uses text-to-speech to pronounce the given text
  ///
  /// @param text - The Chinese text to pronounce
  Future<void> _speakText(String text) async {
    try {
      final audioData = await _ttsService.textToSpeech(text);
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

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Word Dictionary')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error message if dictionary loading failed
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Word Dictionary')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading dictionary: $_error'),
              ElevatedButton(
                onPressed: _loadDictionary,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Word Dictionary')),
      body: Column(
        children: [
          // Search field and button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'Enter Simplified Chinese Word',
                      hintText: 'Type here...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _results = []);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _search(_controller.text),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          // Results list plus an extra item at the bottom for the stroke drawing
          Expanded(
            child: _results.isNotEmpty
                ? ListView.builder(
                    itemCount: _results.length + 1,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      // Display dictionary entries
                      if (index < _results.length) {
                        final entry = _results[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${entry.simplified} (${entry.traditional})',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.volume_up),
                                      onPressed: () =>
                                          _speakText(entry.simplified),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Pinyin: ${entry.pinyin}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...entry.definitions.map((def) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text('• $def'),
                                    )),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // Extra item: display stroke drawing for single characters
                        final firstEntry = _results.first;
                        // Only show stroke animation for single characters
                        if (firstEntry.simplified.length == 1 &&
                            _graphicsMap.containsKey(firstEntry.simplified)) {
                          final graphics = _graphicsMap[firstEntry.simplified]!;
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: StrokeOrderAnimation(
                                strokes: graphics.strokes,
                                medians: graphics.medians,
                              ),
                            ),
                          );
                        } else {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'Stroke data available for single characters only.',
                                style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  )
                : const Center(child: Text('No results found.')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
    start ??= 0;
    end ??= _buffer.length;
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}

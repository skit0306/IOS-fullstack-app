import 'dart:convert';
import 'package:flutter/services.dart';

/// CedictEntry
///
/// Represents a single dictionary entry from the CC-CEDICT Chinese-English dictionary.
/// Contains traditional and simplified Chinese characters, pinyin pronunciation,
/// and English definitions.
class CedictEntry {
  final String traditional; // Traditional Chinese character(s)
  final String simplified; // Simplified Chinese character(s)
  final String pinyin; // Pinyin pronunciation with tone marks
  final List<String> definitions; // English definitions

  CedictEntry({
    required this.traditional,
    required this.simplified,
    required this.pinyin,
    required this.definitions,
  });

  /// Creates a CedictEntry from a dictionary line
  ///
  /// Parses a line from the CC-CEDICT format into a structured entry
  /// Example format: "中國 中国 [zhong1 guo2] /China/Middle Kingdom/"
  ///
  /// @param line - A line from the CC-CEDICT dictionary file
  /// @return CedictEntry object or null if parsing fails
  static CedictEntry? fromLine(String line) {
    // Skip empty lines and comments (lines starting with #)
    if (line.isEmpty || line.startsWith('#')) return null;

    try {
      // Split the line by forward slashes to separate definitions
      final parts = line.split('/');
      if (parts.length < 2) return null;

      // Extract definitions (everything between slashes after the first part)
      final definitions = parts
          .sublist(1)
          .where((d) => d.isNotEmpty) // Filter out empty definitions
          .map((d) => d.trim()) // Remove extra whitespace
          .toList();

      // Parse the first part which contains characters and pinyin
      final firstPart = parts[0].trim();
      // Use regex to extract traditional, simplified, and pinyin
      // Format: "traditional simplified [pinyin]"
      final matches =
          RegExp(r'(\S+)\s+(\S+)\s+\[(.*?)\]').firstMatch(firstPart);

      if (matches == null) return null;

      // Create and return a new entry
      return CedictEntry(
        traditional: matches[1]!, // First capture group: traditional characters
        simplified: matches[2]!, // Second capture group: simplified characters
        pinyin: matches[3]!, // Third capture group: pinyin (between brackets)
        definitions: definitions, // Definitions extracted earlier
      );
    } catch (e) {
      // Log parsing errors for debugging
      print('Error parsing line: $line');
      print('Error: $e');
      return null;
    }
  }
}

/// CedictService
///
/// Service for loading and accessing CC-CEDICT Chinese-English dictionary data.
/// Provides methods to lookup words by simplified characters.
class CedictService {
  Map<String, List<CedictEntry>> _simplifiedIndex =
      {}; // Index for fast lookup by simplified characters
  List<CedictEntry> _allEntries = []; // List of all dictionary entries
  bool _isLoaded = false; // Flag indicating if dictionary is loaded

  /// Loads the CC-CEDICT dictionary from assets
  ///
  /// Parses the dictionary file and builds indexes for efficient lookup.
  /// Only loads once; subsequent calls return immediately if already loaded.
  Future<void> loadDictionary() async {
    // Skip loading if already loaded
    if (_isLoaded) return;

    try {
      // Load the dictionary file from assets
      final String data =
          await rootBundle.loadString('lib/assets/cedict_ts.u8');

      // Split the file into lines
      final lines = const LineSplitter().convert(data);

      // Process each line in the dictionary
      for (var line in lines) {
        // Parse the line into a dictionary entry
        final entry = CedictEntry.fromLine(line);
        if (entry != null) {
          // Add to simplified character index for fast lookup
          _simplifiedIndex.putIfAbsent(entry.simplified, () => []).add(entry);
          // Add to the list of all entries
          _allEntries.add(entry);
        }
      }

      // Mark as loaded when complete
      _isLoaded = true;
    } catch (e) {
      // Log loading errors and rethrow for caller to handle
      print('Error loading dictionary: $e');
      rethrow;
    }
  }

  /// Looks up a simplified Chinese word or character in the dictionary
  ///
  /// @param simplified - The simplified Chinese word/character to look up
  /// @return A list of matching dictionary entries (empty if no matches)
  List<CedictEntry> lookup(String simplified) {
    if (simplified.isEmpty) return []; // Return empty list for empty input
    return _simplifiedIndex[simplified] ??
        []; // Return matches or empty list if none
  }

  /// Gets all dictionary entries
  ///
  /// @return The complete list of all dictionary entries
  List<CedictEntry> getAllEntries() {
    return _allEntries;
  }

  /// Checks if the dictionary is loaded
  ///
  /// @return true if the dictionary has been successfully loaded
  bool get isLoaded => _isLoaded;
}

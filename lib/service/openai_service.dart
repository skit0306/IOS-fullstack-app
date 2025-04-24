//openai_service gen with scene
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/language_performance_model.dart';
import '../api_key.dart';

class Question {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  Question({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    String fix(String? s) => s != null ? utf8.decode(latin1.encode(s)) : '';
    return Question(
      question: fix(json['question'] as String?),
      options: List<String>.from(
          (json['options'] as List<dynamic>).map((e) => fix(e as String?))),
      correctIndex: json['correctIndex'] as int,
      explanation: fix(json['explanation'] as String?) ?? '',
    );
  }
}

class OpenAIService {
  final String apiKey =
      openAI_apiKey;
  final String endpoint =
      openAI_endpoint; 

  OpenAIService();

  Future<String> generateExerciseTranscript(String scene) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
        body: jsonEncode({
          'messages': [
            {
              'role': 'system',
              'content':
                  '''You are a creative assistant. Generate a detailed Mandarin transcript for a listening exercise set in a $scene scenario. The transcript should be long enough (at least 1 minute of spoken content) and include context-specific vocabulary that reflects $scene situations. The transcript should not be too long (most 2 minutes of spoken content). Output only the transcript text without any extra formatting.
                  The transcript please do not use dialogue form.
                  '''
            }
          ],
          'max_tokens': 4000
        }),
      );

      if (response.statusCode == 200) {
        final decodedResponse =
            utf8.decode(response.bodyBytes, allowMalformed: true);
        final data = jsonDecode(decodedResponse);
        final transcriptText = data['choices'][0]['message']['content'];
        return transcriptText.trim();
      } else {
        throw Exception(
            'Failed to generate transcript: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating transcript: $e');
      throw Exception('Failed to generate exercise transcript: $e');
    }
  }

  Future<List<Question>> generateTyposMCQuestions() async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
        body: jsonEncode({
          'messages': [
            {
              'role': 'system',
              'content': '''
You are a helpful assistant that generates Mandarin typos detection multiple-choice questions. Each question should be a sentence with one blank (indicated by __) where a word is missing. Provide two options (A and B), where one option is the correct word that fits the blank and the other is a common typo or plausible mistake. Ensure that the two options are always distinct from each other. Generate exactly 5 questions. Return a JSON array with exactly 5 question objects. Each object must have exactly these keys:
"question": The sentence with the blank.
"options": An array of 2 distinct strings representing the options.
"correctIndex": An integer (0 or 1) indicating the correct option.
"explanation": An empty string.

For example, a valid output could be:
[
  {
    "question": "爸爸最喜欢吃 __，我们就迁就他的口味吧﹗",
    "options": ["火锅", "火窝"],
    "correctIndex": 0,
    "explanation": ""
  },
  {
    "question": "今天午餐我们吃 __，别点错了哦﹗",
    "options": ["面条", "面铙"],
    "correctIndex": 0,
    "explanation": ""
  },
  ... (3 more questions)
]

Output only the JSON array without any additional text.
            '''
            }
          ],
          'max_tokens': 4000,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final questionsText = data['choices'][0]['message']['content'];
        return _parseQuestions(questionsText);
      } else {
        throw Exception(
            'Failed to generate typos MC questions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating typos MC questions: $e');
    }
  }

  Future<List<Question>> generateQuestions(
      String transcript, String scene) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
        body: jsonEncode({
          'messages': [
            {
              'role': 'system',
              'content':
                  '''You are a helpful assistant that generates listening comprehension questions from a given transcript set in a $scene scenario. Based on the length and complexity of the transcript, generate an appropriate number of multiple-choice questions with 4 options each that test understanding of key points, vocabulary, and context relevant to $scene.'''
            },
            {
              'role': 'user',
              'content': '''Transcript: $transcript

Based on the transcript and its $scene context, generate an appropriate number of multiple-choice questions with 4 options each that test understanding of key points, vocabulary, and context. Return only a valid JSON array where each element has the following structure:

{
  "question": "问题",
  "options": ["选项A", "选项B", "选项C", "选项D"],
  "correctIndex": 0,
  "explanation": "解释"
}

Output ONLY the JSON array without any additional text, headings, or markdown formatting.'''
            }
          ],
          'max_tokens': 4000
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final questionsText = data['choices'][0]['message']['content'];
        return _parseQuestions(questionsText);
      } else {
        throw Exception('Failed to generate questions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating questions: $e');
      throw Exception('Failed to generate questions: $e');
    }
  }

  List<Question> _parseQuestions(String questionsText) {
    try {
      String cleaned = questionsText
          .replaceAll(RegExp(r'```json'), '')
          .replaceAll(RegExp(r'```'), '')
          .trim();

      int startIndex = cleaned.indexOf('[');
      int endIndex = cleaned.lastIndexOf(']');
      if (startIndex == -1 || endIndex == -1) {
        throw Exception("Could not find a JSON array in the response.");
      }

      String jsonStr = cleaned.substring(startIndex, endIndex + 1);
      final List<dynamic> rawQuestions = jsonDecode(jsonStr);
      return rawQuestions.map((q) => Question.fromJson(q)).toList();
    } catch (e) {
      print('Error parsing questions: $e');
      throw Exception('Failed to parse questions: $e');
    }
  }

  Future<Map<String, dynamic>> analyzePerformance({
    required String transcript,
    required List<Question> questions,
    required List<int?> userAnswers,
  }) async {
    String prompt =
        "Analyze the following listening exercise performance in detail.\n\n";
    prompt += "Scene: The exercise is set in a specific context.\n";
    prompt += "Transcript:\n$transcript\n\n";
    prompt += "For each question below, examine the following:\n";
    prompt += "- Question text\n";
    prompt += "- Available options\n";
    prompt += "- Correct answer (as given in the explanation)\n";
    prompt += "- User's selected answer\n\n";
    prompt +=
        "Based on this, identify key vocabulary words that the user understands well (strengths) and those the user struggles with (weaknesses) in the context of this scene. Do not simply mark correct answers as strengths; analyze the language details.\n\n";
    prompt +=
        "Return only a valid JSON object with exactly two keys: \"strengths\" and \"weaknesses\", each being a list of vocabulary words.";

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final userAns = userAnswers[i];
      prompt += "\nQuestion ${i + 1}:\n";
      prompt += "Text: ${q.question}\n";
      prompt += "Options: ${q.options.join(', ')}\n";
      prompt += "Correct: ${q.options[q.correctIndex]}\n";
      prompt += "Explanation: ${q.explanation}\n";
      prompt +=
          "User Answer: ${userAns != null ? q.options[userAns] : 'Not answered'}\n";
    }

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
      },
      body: jsonEncode({
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert performance analyst and language specialist.'
          },
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 1000,
      }),
    );
    if (response.statusCode == 200) {
      final decodedResponse =
          utf8.decode(response.bodyBytes, allowMalformed: true);
      final data = jsonDecode(decodedResponse);
      final rawAnalysis = data['choices'][0]['message']['content'] as String;
      String cleaned = rawAnalysis
          .replaceAll(RegExp(r'```json'), '')
          .replaceAll(RegExp(r'```'), '')
          .trim();
      try {
        final analysisData = jsonDecode(cleaned);
        return Map<String, dynamic>.from(analysisData);
      } catch (e) {
        return {
          "strengths": [],
          "weaknesses": [cleaned]
        };
      }
    } else {
      throw Exception('Failed to analyze performance: ${response.statusCode}');
    }
  }

  Future<LanguagePerformance> analyzeDetailedPerformance({
    required String transcript,
    required List<Question> questions,
    required List<int?> userAnswers,
    required String scene,
    required String exerciseId,
    required int totalExercisesCompleted,
  }) async {
    String prompt = """
Analyze the following Mandarin listening exercise performance in detail.

Scene: $scene
Transcript: $transcript

Questions and Answers:
""";

    // Add all questions and user answers to the prompt
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final userAns = userAnswers[i];
      final isCorrect = userAns == q.correctIndex;
      prompt += """
Question ${i + 1}: ${q.question}
Options: ${q.options.join(', ')}
Correct: ${q.options[q.correctIndex]}
User Answer: ${userAns != null ? q.options[userAns] : 'Not answered'} (${isCorrect ? 'Correct' : 'Incorrect'})
Explanation: ${q.explanation}
""";
    }

    prompt += """
Provide a comprehensive language assessment by analyzing the following aspects:

1. Calculate an overall listening score (0-100).
2. Identify specific phonetic patterns the user understands well vs. struggles with.
3. Evaluate tonal comprehension patterns (e.g., difficulty with 3rd tone).
4. Assess vocabulary knowledge, listing specific words mastered and struggling with.
5. Evaluate comprehension of complex sentence structures.
6. Assess understanding of idioms and expressions if present.
7. Provide scene-specific performance score (0-100).
8. List 3-5 strength areas in bullet points.
9. List 3-5 improvement areas in bullet points.
10. Provide a personalized recommendation for next steps in learning.

Return the analysis as a valid JSON object with the following structure:
{
  "listeningScore": 75.5,
  "phoneticAccuracy": {"zh": 90.0, "ch": 85.5, "sh": 60.0},
  "toneAccuracy": {"1st": 95.0, "2nd": 90.0, "3rd": 70.0, "4th": 85.0},
  "knownVocabulary": ["你好", "谢谢"],
  "difficultVocabulary": ["认为", "经济"],
  "complexSentenceComprehension": 65.0,
  "idiomComprehension": 50.0,
  "scenePerformance": {"$scene": 72.5},
  "overallScore": 70.0,
  "strengthAreas": ["Basic greetings", "Simple questions"],
  "improvementAreas": ["Business terminology", "Complex clauses"],
  "aiRecommendation": "Focus on business vocabulary and third tone practice"
}

Remember to be accurate, objective, and helpful in your assessment.
""";

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
      },
      body: jsonEncode({
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert Mandarin language assessment specialist with extensive experience in linguistic analysis.'
          },
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 2000,
      }),
    );

    if (response.statusCode == 200) {
      final decodedResponse =
          utf8.decode(response.bodyBytes, allowMalformed: true);
      final data = jsonDecode(decodedResponse);
      final analysisText = data['choices'][0]['message']['content'];

      // Extract the JSON object from the response
      final RegExp jsonRegex = RegExp(r'({[\s\S]*})');
      final match = jsonRegex.firstMatch(analysisText);

      if (match != null) {
        final jsonStr = match.group(1);
        final analysisData = jsonDecode(jsonStr!);

        // Create a LanguagePerformance object from the analysis
        return LanguagePerformance(
          listeningScore: analysisData['listeningScore'] ?? 0.0,
          phoneticAccuracy:
              Map<String, double>.from(analysisData['phoneticAccuracy'] ?? {}),
          toneAccuracy:
              Map<String, double>.from(analysisData['toneAccuracy'] ?? {}),
          knownVocabulary:
              List<String>.from(analysisData['knownVocabulary'] ?? []),
          difficultVocabulary:
              List<String>.from(analysisData['difficultVocabulary'] ?? []),
          complexSentenceComprehension:
              analysisData['complexSentenceComprehension'] ?? 0.0,
          idiomComprehension: analysisData['idiomComprehension'] ?? 0.0,
          scenePerformance:
              Map<String, double>.from(analysisData['scenePerformance'] ?? {}),
          timestamp: DateTime.now(),
          exerciseId: exerciseId,
          exerciseType: 'listening',
          totalExercisesCompleted: totalExercisesCompleted,
          overallScore: analysisData['overallScore'] ?? 0.0,
          strengthAreas: List<String>.from(analysisData['strengthAreas'] ?? []),
          improvementAreas:
              List<String>.from(analysisData['improvementAreas'] ?? []),
          aiRecommendation: analysisData['aiRecommendation'] ?? '',
        );
      } else {
        throw Exception('Failed to extract JSON from analysis response');
      }
    } else {
      throw Exception('Failed to analyze performance: ${response.statusCode}');
    }
  }

  /// Generate personalized exercise based on user performance history
  Future<String> generatePersonalizedTranscript({
    required String scene,
    required Map<String, dynamic> performanceData,
  }) async {
    // Create a prompt that uses performance data to guide generation
    String prompt = """
Generate a personalized Mandarin listening exercise transcript for a user with the following performance profile:

Scene: $scene
Overall listening score: ${performanceData['listeningScore'] ?? 'Unknown'}
Strength areas: ${performanceData['strengthAreas']?.join(', ') ?? 'Unknown'}
Improvement areas: ${performanceData['improvementAreas']?.join(', ') ?? 'Unknown'}

Create a transcript that:
1. Builds on the user's established strengths: ${performanceData['strengthAreas']?.join(', ') ?? 'basic vocabulary'}
2. Gradually introduces elements from improvement areas: ${performanceData['improvementAreas']?.join(', ') ?? 'more complex grammar'}
3. Contains appropriate vocabulary for a $scene context
4. Is challenging but achievable based on the user's current level
5. Is natural and conversational in style
6. Is approximately 1-2 minutes of spoken content in length

Return only the transcript text without any additional commentary or formatting.
""";

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
      },
      body: jsonEncode({
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert Mandarin language teacher who creates personalized learning materials.'
          },
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 4000,
      }),
    );

    if (response.statusCode == 200) {
      final decodedResponse =
          utf8.decode(response.bodyBytes, allowMalformed: true);
      final data = jsonDecode(decodedResponse);
      final transcript = data['choices'][0]['message']['content'];
      return transcript.trim();
    } else {
      throw Exception(
          'Failed to generate personalized transcript: ${response.statusCode}');
    }
  }

  Future<String> chat(
      String userMessage, List<Map<String, String>> conversationHistory) async {
    final systemPrompt = {
      'role': 'system',
      'content': '''
You are a helpful Putonghua tutor with a conversational teaching style. 
    '''
    };

    final hasSystemPrompt =
        conversationHistory.any((msg) => msg['role'] == 'system');
    if (!hasSystemPrompt) {
      conversationHistory.insert(0, systemPrompt);
    }

    // Add user message to conversation
    conversationHistory.add({'role': 'user', 'content': userMessage});

    // Send request to API
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'api-key': apiKey,
      },
      body: jsonEncode({
        'messages': conversationHistory,
        'max_tokens': 1000,
      }),
    );

    if (response.statusCode == 200) {
      final decodedResponse =
          utf8.decode(response.bodyBytes, allowMalformed: true);
      final data = jsonDecode(decodedResponse);
      final reply = data['choices'][0]['message']['content'];

      conversationHistory.add({'role': 'assistant', 'content': reply});

      return reply;
    } else {
      throw Exception("Error generating chat response: ${response.statusCode}");
    }
  }
}

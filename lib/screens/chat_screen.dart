import 'package:flutter/material.dart';
import 'package:p1/service/openai_service.dart';
import 'dart:convert';

/// ChatScreen
///
/// A chat interface for interacting with a virtual Putonghua tutor.
/// This screen manages the conversation between the user and the AI tutor,
/// sending messages to OpenAI's API and displaying responses.
class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Controller for the text input field
  final TextEditingController _textController = TextEditingController();
  // Controller for the scrollable chat view
  final ScrollController _scrollController = ScrollController();
  // Stores the entire conversation history
  final List<Map<String, String>> _conversationHistory = [];
  // Service for communicating with OpenAI API
  final OpenAIService _openAIService = OpenAIService();
  // Loading state flag for displaying progress indicator
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with a welcome message
    _addAssistantMessage(
        "你好！我是你的普通话老师。很高兴认识你！我可以帮你练习中文，解答问题，或者聊一些有趣的话题。\n\nHello! I'm your Putonghua tutor. I'm here to help you practice Chinese, answer your questions, or chat about interesting topics. What would you like to talk about today?");
  }

  /// Adds an AI assistant message to the conversation
  ///
  /// @param message - The text content of the assistant's response
  void _addAssistantMessage(String message) {
    setState(() {
      _conversationHistory.add({"role": "assistant", "content": message});
    });
    _scrollToBottom();
  }

  /// Sends user message to the AI and handles the response
  ///
  /// @param message - User's message text to be sent
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      // Add user message to conversation history
      _conversationHistory.add({"role": "user", "content": message});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      // Create a copy of the conversation history for the API call
      final List<Map<String, String>> historyForAPI =
          List.from(_conversationHistory);

      // Add system message with adaptive instructions
      historyForAPI.insert(0, {
        'role': 'system',
        'content': '''
You are a helpful Putonghua tutor with a conversational style.
Analyze the user's input for grammar or vocabulary mistakes.
Offer corrections when appropriate, and provide explanations in both Putonghua and English.
Give examples or alternative phrasings to help them improve.
Respond in Putonghua and English.
Adapt your response complexity to match the user's demonstrated ability level.
If the user writes in simple Putonghua or English, respond with simpler Putonghua.
If the user writes more complex Putonghua, you can use more advanced vocabulary and grammar.

IMPORTANT: After providing any corrections or explanations, continue the conversation naturally by:
1. Asking a follow-up question related to the topic the user mentioned
2. Sharing a relevant cultural insight or tip
3. Suggesting a way to practice the concept just discussed
4. Extending the conversation in a natural, tutor-like way

Always end your response with something that encourages continued conversation.

Always Respond both in Putonghua and English.
'''
      });

      // Send conversation to OpenAI API and receive response
      final response = await _openAIService.chat(message, historyForAPI);

      setState(() {
        // Add AI response to conversation history
        _conversationHistory.add({"role": "assistant", "content": response});
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        // Handle errors by displaying them in chat
        _conversationHistory.add({"role": "assistant", "content": "Error: $e"});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  /// Scrolls the chat view to the bottom to show newest messages
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Putonghua Tutor'),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping empty space
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // Chat messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _conversationHistory.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_conversationHistory[index]);
                },
              ),
            ),
            // Loading indicator shown when waiting for AI response
            if (_isLoading) const LinearProgressIndicator(),
            // Message input field and send button
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  /// Creates a message bubble for chat display
  ///
  /// @param message - The message data containing role and content
  /// @return A styled message bubble widget with appropriate colors and layout
  Widget _buildMessageBubble(Map<String, String> message) {
    final isUser = message["role"] == "user";
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Choose colors based on theme
    final userBubbleColor = isDark
        ? Color(0xFF2C5282) // Darker blue for dark mode
        : Colors.blue[100]; // Light blue for light mode

    final assistantBubbleColor = isDark
        ? Color(0xFF2D3748) // Dark gray for dark mode
        : Colors.grey[200]; // Light gray for light mode

    // Avatar colors that stand out in both themes
    final userAvatarColor = isDark ? Colors.blue[400] : Colors.blue[600];

    final assistantAvatarColor = isDark ? Colors.green[400] : Colors.green[600];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assistant avatar - only shown for assistant messages
          if (!isUser)
            CircleAvatar(
              backgroundColor: assistantAvatarColor,
              child: const Icon(Icons.school, color: Colors.white),
            ),
          const SizedBox(width: 8),
          // Message bubble with formatted content
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? userBubbleColor : assistantBubbleColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildMessageContent(message["content"]!),
            ),
          ),
          const SizedBox(width: 8),
          // User avatar - only shown for user messages
          if (isUser)
            CircleAvatar(
              backgroundColor: userAvatarColor,
              child: const Icon(Icons.person, color: Colors.white),
            ),
        ],
      ),
    );
  }

  /// Formats message content with highlighting for corrections and examples
  ///
  /// @param content - The raw text content of the message
  /// @return A RichText widget with formatted text spans
  Widget _buildMessageContent(String content) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Always use white text in dark mode, dark text in light mode
    final normalTextColor = isDark
        ? Colors.white // White text for dark mode
        : Colors.black87; // Dark text for light mode

    final highlightColor = isDark
        ? Colors.pink[300]! // Brighter pink for dark mode
        : Colors.red[700]!; // Deeper red for light mode

    final exampleColor = isDark
        ? Colors.cyan[300]! // Bright cyan for dark mode
        : Colors.blue[700]!; // Deep blue for light mode

    // Split content by Chinese and non-Chinese sections for better formatting
    final List<TextSpan> spans = [];

    // Process the message content to highlight corrections and explanations
    if (content.contains("Correction:") || content.contains("纠正:")) {
      // Split by sentences or sections
      final sections = content.split(RegExp(r'(?<=。|！|？|\n)'));

      for (var section in sections) {
        if (section.trim().isEmpty) continue;

        // Apply styling based on section content
        if (section.contains("Correction:") || section.contains("纠正:")) {
          // Highlight corrections with bold red/pink text
          spans.add(TextSpan(
            text: "$section\n",
            style: TextStyle(
              color: highlightColor,
              fontWeight: FontWeight.bold,
            ),
          ));
        } else if (section.contains("Example:") || section.contains("例子:")) {
          // Highlight examples with italic blue/cyan text
          spans.add(TextSpan(
            text: "$section\n",
            style: TextStyle(
              color: exampleColor,
              fontStyle: FontStyle.italic,
            ),
          ));
        } else {
          // Normal text for regular content
          spans.add(TextSpan(
            text: "$section\n",
            style: TextStyle(color: normalTextColor),
          ));
        }
      }
    } else {
      // For regular messages without corrections
      spans.add(TextSpan(
        text: content,
        style: TextStyle(color: normalTextColor),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// Creates the message input area at the bottom of the screen
  ///
  /// @return A styled container with text field and send button
  Widget _buildMessageInput() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Choose input field background color based on theme
    final inputBackgroundColor = isDark
        ? Color(0xFF1A202C) // Very dark gray for dark mode
        : Colors.grey[100]; // Light gray for light mode

    // Choose container background color based on theme
    final containerBackgroundColor = isDark
        ? theme.scaffoldBackgroundColor // Use scaffold background in dark mode
        : Colors.white; // White for light mode

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: containerBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            offset: const Offset(0, -3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          // Expandable text input field
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: "Ask your tutor in Putonghua or English...",
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: inputBackgroundColor,
                // Ensure hint text is visible in both modes
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (text) => _sendMessage(text),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

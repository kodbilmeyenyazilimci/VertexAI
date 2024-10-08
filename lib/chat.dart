import 'package:ai/info.dart';
import 'package:ai/premium.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'account.dart';

// Message class representing user and model messages
class Message {
  final String text;
  final bool isUserMessage;
  Message({required this.text, required this.isUserMessage});
}

class ChatScreen extends StatefulWidget {
  final String? conversationID;
  final String? conversationTitle;

  const ChatScreen({super.key, this.conversationID, this.conversationTitle});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> messages = []; // To store conversation messages
  final TextEditingController _controller = TextEditingController(); // To handle input field text
  bool isModelLoaded = false; // To track if the model is loaded
  bool isWaitingForResponse = false; // Track if awaiting model's response
  List<String> modelResponses = []; // Model responses are collected here
  Timer? responseTimer; // Timer to handle delayed response
  int responseIndex = 0; // Index to track the model's response
  final uuid = Uuid(); // UUID to generate unique conversation IDs
  String? conversationID; // Conversation ID for current chat
  String? conversationTitle; // Title for the current conversation
  static const MethodChannel llamaChannel = MethodChannel('com.vertex.ai/llama');

  bool _isSendButtonVisible = false; // To show or hide the send button
  double suggestionsOpacity = 1.0; // Opacity for suggestions display
  double additionalSuggestionsOpacity = 1.0; // Opacity for extra suggestions
  double logoOpacity = 1.0; // Opacity for logo
  late final ScrollController _scrollController = ScrollController(); // To handle message list scrolling

  final List<String> suggestions = [
    "👋 Merhaba", "😊 Nasılsın?", "🆘 Bana yardım edebilir misin?",
    "🌦️ Bugün hava nasıl?", "🍕 En sevdiğin yemek nedir?",
    "⚽ Futbol sever misin?", "🎵 Hangi müzikleri dinlersin?",
    "🏖️ Tatilde nereye gitmek istersin?"
  ];

  final List<String> additionalSuggestions = [
    "📚 Hangi kitabı okuyorsun?", "🎬 En son hangi filmi izledin?",
    "🏞️ Doğayı sever misin?", "🖼️ Hangi sanat dalıyla ilgileniyorsun?",
    "👩‍🍳 Yemek yapmayı sever misin?", "🚴‍♂️ Spor yapar mısın?",
    "🌍 Seyahat etmeyi sever misin?", "🤖 Gelecek hakkında ne düşünüyorsun?"
  ];

  // Initialization: Load model, set up message handler, load previous messages if any
  @override
  void initState() {
    super.initState();
    loadModel(); // Loads the AI model
    llamaChannel.setMethodCallHandler(_methodCallHandler); // Sets method channel for native communication
    if (widget.conversationID != null) {
      _loadPreviousMessages(widget.conversationID!); // Load past messages if available
    }
  }

  // Load model configuration and invoke native method to load it
  Future<void> loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    final modelPath = prefs.getString('selected_model_path');
    llamaChannel.invokeMethod('loadModel', {'path': modelPath});
  }

  // MethodCall handler to receive and respond to messages from the model
  Future<void> _methodCallHandler(MethodCall call) async {
    if (call.method == 'onMessageResponse') {
      _onMessageResponse(call.arguments as String); // Process response tokens from model
    } else if (call.method == 'onMessageComplete') {
      _finalizeResponse(); // Finalize and show the full model response
    } else if (call.method == 'onModelLoaded') {
      setState(() => isModelLoaded = true); // Set model loaded state
    }
  }

  // Handling tokenized message response from model
  void _onMessageResponse(String token) {
    setState(() {
      if (modelResponses.length <= responseIndex) {
        modelResponses.add(token); // Add first token
      } else {
        modelResponses[responseIndex] += token; // Append tokens to the current response
      }
    });
    _startResponseTimeout(); // Start or reset the timer for model's response
  }

  // Starts a timer to handle response completion
  void _startResponseTimeout() {
    responseTimer?.cancel(); // Cancel any existing timer
    responseTimer = Timer(const Duration(seconds: 5), _finalizeResponse); // Call _finalizeResponse after 5 seconds
  }

// Finalize and display the model's response in the chat
  void _finalizeResponse() {
    if (modelResponses.isNotEmpty) {
      setState(() {
        messages.add(Message(text: modelResponses.join(" "), isUserMessage: false)); // Add model's response to chat
        responseIndex++;
        modelResponses.clear(); // Clear response buffer
      });

      if (conversationID == null && messages.isNotEmpty) {
        conversationID = uuid.v4(); // Generate conversation ID
        conversationTitle = messages.first.text; // First message becomes the title
        _saveConversationTitle(conversationTitle!); // Save conversation title
      }

      _saveMessageToConversation(messages.last.text, false); // Save the model's response
    }

    responseTimer?.cancel(); // Stop the timer
    setState(() {
      isWaitingForResponse = false; // Set waiting state to false
      // Don't clear the message bubble here, just retain the text
    });
  }

  // Loads previous messages from storage using conversation ID
  Future<void> _loadPreviousMessages(String conversationID) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? messagesList = prefs.getStringList(conversationID);

    if (messagesList != null) {
      for (String message in messagesList) {
        bool isUserMessage = message.startsWith("User: ");
        messages.add(Message(text: message.substring(message.indexOf(": ") + 2), isUserMessage: isUserMessage));
      }
      setState(() {}); // Refresh UI
    }
  }

  // Saves the conversation title
  Future<void> _saveConversationTitle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_conversation_title', title); // Save conversation title
  }

  // Saves individual messages to the conversation
  Future<void> _saveMessageToConversation(String message, bool isUserMessage) async {
    final prefs = await SharedPreferences.getInstance();

    if (conversationID == null && messages.isNotEmpty) {
      conversationID = uuid.v4(); // Create conversation ID if missing
      conversationTitle = messages.first.text; // Set first message as title
      await prefs.setString('current_conversation_id', conversationID!);

      final List<String>? conversations = prefs.getStringList('conversations') ?? [];
      conversations?.add(conversationTitle!); // Add conversation title to list
      await prefs.setStringList('conversations', conversations!);
    }

    final List<String> conversationMessages = prefs.getStringList(conversationID!) ?? [];
    conversationMessages.add(isUserMessage ? "User: $message" : "Model: $message");
    await prefs.setStringList(conversationID!, conversationMessages);
  }

  // Handles sending the message
  void _sendMessage([String? textFromButton]) {
    String text = textFromButton ?? _controller.text.trim();

    if (text.isNotEmpty) {
      setState(() {
        messages.add(Message(text: text, isUserMessage: true)); // Add user's message to list
        _controller.clear(); // Clear input field
        isWaitingForResponse = true; // Set waiting for response
        _isSendButtonVisible = false; // Hide send button
        modelResponses.clear(); // Clear previous model responses
        responseIndex = 0; // Reset response index
      });

      if (messages.length == 1) {
        _saveConversation(text); // Save conversation if it's the first message
      }

      llamaChannel.invokeMethod('sendMessage', {'message': text}); // Send message to model
      _startResponseTimeout(); // Start response timeout timer
      _fadeOutSuggestionsAndLogo(); // Fade out UI elements
    }
  }

  // Fades out the suggestions and logo after sending a message
  void _fadeOutSuggestionsAndLogo() {
    setState(() {
      suggestionsOpacity = 0.0; // Fade out suggestions
      additionalSuggestionsOpacity = 0.0; // Fade out additional suggestions
      logoOpacity = 0.0; // Fade out logo
    });
  }

  // Handles text input changes to show/hide send button
  void _onTextChanged(String text) {
    setState(() => _isSendButtonVisible = text.isNotEmpty && !isWaitingForResponse);
  }

  // Handle suggestion tap to send the suggestion as a message
  void _onSuggestionTap(String suggestion) => _sendMessage(suggestion);

  // Save the conversation with a given name
  Future<void> _saveConversation(String conversationName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> conversations = prefs.getStringList('conversations') ?? [];

    if (conversations.contains(conversationName)) return; // Prevent duplicate conversations

    conversations.add(conversationName);
    await prefs.setStringList('conversations', conversations);
  }

  // Build method: creates UI elements for chat screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context), // Build custom app bar
      body: Stack(
        children: [
          Container(color: const Color(0xFF141414)), // Background color
          _buildLogo(), // Show the logo
          Column(
            children: <Widget>[
              Expanded(child: _buildMessagesList()), // Display the message list
              _buildAdditionalSuggestionsBar(), // Display additional suggestions
              _buildSuggestionsBar(), // Display main suggestions
              _buildInputField(), // Display input field
            ],
          ),
        ],
      ),
    );
  }

  // Build AppBar with premium button and navigation to Account and Info
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      toolbarHeight: 60,
      backgroundColor: const Color(0xFF141414),
      leading: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onPressed: () => _navigateToScreen(context, const InformationScreen(), const Offset(-1.0, 0.0)), // Left slide transition
      ),
      title: Center(child: _buildPremiumButton(context)), // Centered premium button
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 5.0),
          child: GestureDetector(
            onTap: () => _navigateToScreen(context, const AccountScreen(), const Offset(1.0, 0.0)), // Right slide transition
            child: Image.asset('assets/profile.png', height: 30, width: 36),
          ),
        ),
      ],
    );
  }

  // Navigate to another screen with a slide transition
  void _navigateToScreen(BuildContext context, Widget screen, Offset offset) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, __, child) {
          var offsetAnimation = animation.drive(
            Tween(begin: offset, end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOut)),
          );
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  // Build premium button in the AppBar
  Widget _buildPremiumButton(BuildContext context) {
    return TextButton(
      onPressed: () => _navigateToPremiumScreen(context),
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFF2d2f2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      ),
      child: const Text(
        "Vertex Premium",
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  // Navigate to the PremiumScreen
  void _navigateToPremiumScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PremiumScreen()), // Default animation
    );
  }

  // Build the animated logo displayed at the top
  Widget _buildLogo() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: logoOpacity,
        duration: const Duration(milliseconds: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 160),
          child: Column(
            children: [
              Image.asset('assets/vertexailogodarkwhite.png', height: 80),
              const SizedBox(height: 16),
              Text(
                'problemler çözümsüz \n            kalamaz.',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build the list of messages
  Widget _buildMessagesList() {
    return ListView.builder(
      itemCount: messages.length + (modelResponses.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && modelResponses.isNotEmpty) {
          return _buildModelResponse(); // Display model response
        } else {
          return _buildMessageTile(messages[index]); // Display regular message
        }
      },
    );
  }

  // Build a single message tile
  Widget _buildMessageTile(Message message) {
    return ListTile(
      title: Align(
        alignment: message.isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: message.isUserMessage ? const Color(0xFF292a2c) : const Color(0xFF00b7bdc9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(message.text, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

// Display the ongoing model response in the chat
  Widget _buildModelResponse() {
    return ListTile(
      title: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFdadee6), // Modelin yanıt baloncuğu
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(modelResponses.join(" "), style: const TextStyle(color: Colors.black)),
        ),
      ),
    );
  }


  // Build the additional suggestions bar
  Widget _buildAdditionalSuggestionsBar() {
    return AnimatedOpacity(
      opacity: additionalSuggestionsOpacity,
      duration: const Duration(milliseconds: 400),
      child: additionalSuggestionsOpacity > 0.0
          ? _buildSuggestionsRow(additionalSuggestions)
          : Container(),
    );
  }

  // Build the main suggestions bar
  Widget _buildSuggestionsBar() {
    return AnimatedOpacity(
      opacity: suggestionsOpacity,
      duration: const Duration(milliseconds: 400),
      child: suggestionsOpacity > 0.0 ? _buildSuggestionsRow(suggestions) : Container(),
    );
  }

  // Build a row of suggestion buttons
  Widget _buildSuggestionsRow(List<String> suggestions) {
    return SizedBox(
      height: 50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions.map(_buildSuggestionButton).toList(),
        ),
      ),
    );
  }

  // Build individual suggestion button
  Widget _buildSuggestionButton(String suggestion) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () => _onSuggestionTap(suggestion), // Send suggestion as a message
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF292a2c),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(suggestion, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  // Build input field for user to type messages
  Widget _buildInputField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: isModelLoaded
          ? TextField(
        controller: _controller,
        maxLength: 1000,
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Mesajınızı yazın...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: const OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(4),
          ),
          suffixIcon: AnimatedOpacity(
            opacity: _isSendButtonVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white),
              onPressed: _isSendButtonVisible ? _sendMessage : null,
            ),
          ),
        ),
        onChanged: _onTextChanged,
        onSubmitted: (text) {
          if (!isWaitingForResponse) _sendMessage();
        },
        enabled: !isWaitingForResponse, // Disable input when waiting for model response
      )
          : const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Konuşmak için bir model seçmen gerek, ayarlar ekranından yapabilirsin!',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the input controller
    responseTimer?.cancel(); // Cancel the response timer
    _scrollController.dispose(); // Dispose of the scroll controller
    super.dispose();
  }
}

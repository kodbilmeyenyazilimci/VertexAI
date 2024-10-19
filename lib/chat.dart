import 'package:ai/info.dart';
import 'package:ai/premium.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'account.dart';
import 'main.dart';

// Message class representing user and model messages
class Message {
  String text; // Made mutable to allow updates
  final bool isUserMessage;
  Message({required this.text, required this.isUserMessage});
}

class ChatScreen extends StatefulWidget {
  String? conversationID;
  String? conversationTitle;

  ChatScreen({Key? key, this.conversationID, this.conversationTitle}) : super(key: key);

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  List<Message> messages = []; // To store conversation messages
  final TextEditingController _controller = TextEditingController(); // To handle input field text
  bool isModelLoaded = false; // To track if the model is loaded
  bool isWaitingForResponse = false; // Track if awaiting model's response
  Timer? responseTimer; // Timer to handle delayed response
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
    "👋 Merhaba",
    "😊 Nasılsın?",
    "🆘 Bana yardım edebilir misin?",
    "🌦️ Bugün hava nasıl?",
    "🍕 En sevdiğin yemek nedir?",
    "⚽ Futbol sever misin?",
    "🎵 Hangi müzikleri dinlersin?",
    "🏖️ Tatilde nereye gitmek istersin?"
  ];

  final List<String> additionalSuggestions = [
    "📚 Hangi kitabı okuyorsun?",
    "🎬 En son hangi filmi izledin?",
    "🏞️ Doğayı sever misin?",
    "🖼️ Hangi sanat dalıyla ilgileniyorsun?",
    "👩‍🍳 Yemek yapmayı sever misin?",
    "🚴‍♂️ Spor yapar mısın?",
    "🌍 Seyahat etmeyi sever misin?",
    "🤖 Gelecek hakkında ne düşünüyorsun?"
  ];

  // For the suggestions bar (bottom panel)
  late final ScrollController _suggestionsScrollController;
  late final AnimationController _suggestionsAnimationController;

  // For the additional suggestions bar (top panel)
  late final ScrollController _additionalSuggestionsScrollController;
  late final AnimationController _additionalSuggestionsAnimationController;

  // For screen transitions
  late final AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  // Initialization: Load model, set up message handler, load previous messages if any
  @override
  void initState() {
    super.initState();
    loadModel(); // Loads the AI model
    llamaChannel.setMethodCallHandler(_methodCallHandler); // Sets method channel for native communication
    if (widget.conversationID != null) {
      _loadPreviousMessages(widget.conversationID!); // Load past messages if available
      conversationID = widget.conversationID;
      conversationTitle = widget.conversationTitle;
    }

    // Initialize scroll controllers
    _suggestionsScrollController = ScrollController();
    _additionalSuggestionsScrollController = ScrollController();

    // Initialize animation controllers with increased duration for slower animation
    _suggestionsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(() {
      if (_suggestionsScrollController.hasClients) {
        _suggestionsScrollController.jumpTo(
          _suggestionsAnimationController.value *
              _suggestionsScrollController.position.maxScrollExtent,
        );
      }
    });

    // For the bottom panel, scroll left to right (value from 0 to 1)
    _suggestionsAnimationController.repeat();

    _additionalSuggestionsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(() {
      if (_additionalSuggestionsScrollController.hasClients) {
        _additionalSuggestionsScrollController.jumpTo(
          _additionalSuggestionsAnimationController.value *
              _additionalSuggestionsScrollController.position.maxScrollExtent,
        );
      }
    });

    // For the top panel, scroll left to right (value from 0 to 1)
    _additionalSuggestionsAnimationController.repeat();

    // Initialize fade animation for screen transitions
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    );

    _fadeAnimationController.forward();
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

  // Ensure that _onMessageResponse properly updates the last message
  void _onMessageResponse(String token) {
    if (isWaitingForResponse && messages.isNotEmpty && !messages.last.isUserMessage) {
      setState(() {
        messages.last.text += token; // Append token to the last message
      });
      _startResponseTimeout(); // Start or reset the timer for model's response
      _scrollToBottom(); // Scroll to show the ongoing response
    }
  }

  // Starts a timer to handle response completion
  void _startResponseTimeout() {
    responseTimer?.cancel(); // Cancel any existing timer
    responseTimer = Timer(const Duration(seconds: 5), _finalizeResponse); // Call _finalizeResponse after 5 seconds
  }

  // Finalize and display the model's response in the chat
  void _finalizeResponse() {
    if (isWaitingForResponse && messages.isNotEmpty && !messages.last.isUserMessage) {
      setState(() {
        isWaitingForResponse = false; // Set waiting state to false
      });

      String fullResponse = messages.last.text;

      // No need to set conversationID here; it's already set in _sendMessage

      _saveMessageToConversation(fullResponse, false); // Save the model's response
      _scrollToBottom(); // Scroll to show the new message
    }

    responseTimer?.cancel(); // Stop the timer
  }

  // Loads previous messages from storage using conversation ID
  Future<void> _loadPreviousMessages(String conversationID) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? messagesList = prefs.getStringList(conversationID);

    if (messagesList != null) {
      for (String message in messagesList) {
        bool isUserMessage = message.startsWith("User: ");
        messages.add(Message(
          text: message.substring(message.indexOf(": ") + 2),
          isUserMessage: isUserMessage,
        ));
      }

      // After loading messages, check if messages list is not empty
      if (messages.isNotEmpty) {
        // Hide the suggestion panels and background
        setState(() {
          suggestionsOpacity = 0.0;
          additionalSuggestionsOpacity = 0.0;
          logoOpacity = 0.0;
        });
        _suggestionsAnimationController.stop();
        _additionalSuggestionsAnimationController.stop();
      }
    }
    setState(() {}); // Refresh UI
    _scrollToBottom(); // Scroll to show loaded messages
  }

  // Saves the conversation title
  Future<void> _saveConversationTitle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_conversation_title', title); // Save conversation title
  }

  // Saves individual messages to the conversation
  Future<void> _saveMessageToConversation(String message, bool isUserMessage) async {
    final prefs = await SharedPreferences.getInstance();

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

        // Add an empty model message to receive tokens
        messages.add(Message(text: "", isUserMessage: false)); // Add empty model response
      });

      if (conversationID == null) {
        conversationID = uuid.v4(); // Generate conversation ID
        conversationTitle = text; // Use the user's first message as the title
        _saveConversationTitle(conversationTitle!); // Save conversation title
        _saveConversation(conversationTitle!); // Save conversation immediately

        // Notify the MenuScreen to reload conversations
        mainScreenKey.currentState?.menuScreenKey.currentState?.reloadConversations();
      }

      // Save the user's message
      _saveMessageToConversation(text, true);

      llamaChannel.invokeMethod('sendMessage', {'message': text}); // Send message to model
      _startResponseTimeout(); // Start response timeout timer
      _fadeOutSuggestionsAndLogo(); // Fade out UI elements
      _scrollToBottom(); // Scroll to show the new message
    }
  }

  // Updated resetConversation to reset to initial state with suggestions and background visible
  void resetConversation() {
    setState(() {
      messages.clear();
      conversationID = null;
      conversationTitle = null;
      widget.conversationID = null;
      widget.conversationTitle = null;
      suggestionsOpacity = 1.0;
      additionalSuggestionsOpacity = 1.0;
      logoOpacity = 1.0;
      isWaitingForResponse = false;
      _isSendButtonVisible = false;
    });
    _suggestionsAnimationController.repeat();
    _additionalSuggestionsAnimationController.repeat();
  }

  // Fades out the suggestions and logo after sending a message
  void _fadeOutSuggestionsAndLogo() {
    setState(() {
      suggestionsOpacity = 0.0; // Fade out suggestions
      additionalSuggestionsOpacity = 0.0; // Fade out additional suggestions
      logoOpacity = 0.0; // Fade out logo
    });
    _suggestionsAnimationController.stop();
    _additionalSuggestionsAnimationController.stop();
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

    String conversationEntry = '$conversationID:$conversationName';

    // Prevent duplicate conversations
    if (conversations.any((c) => c.startsWith('$conversationID:'))) return;

    conversations.add(conversationEntry);
    await prefs.setStringList('conversations', conversations);
  }

  // Load conversation when navigating from history
  void loadConversation(String conversationID, String conversationTitle) {
    setState(() {
      widget.conversationID = conversationID;
      widget.conversationTitle = conversationTitle;
      this.conversationID = conversationID;
      this.conversationTitle = conversationTitle;
      messages.clear();
      suggestionsOpacity = 0.0;
      additionalSuggestionsOpacity = 0.0;
      logoOpacity = 0.0;
      _suggestionsAnimationController.stop();
      _additionalSuggestionsAnimationController.stop();
    });
    _loadPreviousMessages(conversationID);
  }

  // Update conversation title when edited from MenuScreen
  void updateConversationTitle(String newTitle) {
    setState(() {
      conversationTitle = newTitle;
    });
  }

  // Build method: creates UI elements for chat screen
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
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
      ),
    );
  }

// AppBar içinde ekran geçişlerini çağırırken yönü belirt
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      toolbarHeight: 60,
      backgroundColor: const Color(0xFF141414),
      leading: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onPressed: () => _navigateToScreen(context, InformationScreen(), isLeftToRight: true), // Soldan sağa
      ),
      title: Center(child: _buildPremiumButton(context)), // Ortalanmış premium butonu
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 5.0),
          child: GestureDetector(
            onTap: () => _navigateToScreen(context, AccountScreen(), isLeftToRight: false), // Sağdan sola
            child: Image.asset('assets/profile.png', height: 30, width: 36),
          ),
        ),
      ],
    );
  }

// Tek bir fonksiyonla ekran geçişi yapıp yönü belirle
  void _navigateToScreen(BuildContext context, Widget screen, {required bool isLeftToRight}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          Offset begin = isLeftToRight ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
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

  // Navigate to the PremiumScreen with fade transition
  void _navigateToPremiumScreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => PremiumScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  // Modify the _buildLogo method to remove the Positioned widget since it's now inside a Stack
  Widget _buildLogo() {
    return Center(
      child: AnimatedOpacity(
        opacity: logoOpacity,
        duration: const Duration(milliseconds: 200), // Reduced duration
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
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return _buildMessageTile(messages[index]); // Display regular message
      },
    );
  }

  // Build a single message tile with long-press copy functionality
  Widget _buildMessageTile(Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: GestureDetector(
        onLongPressStart: (details) {
          _showMessageOptions(context, details.globalPosition, message);
        },
        child: Align(
          alignment: message.isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: message.isUserMessage ? const Color(0xFF292a2c) : const Color(0xFFdadee6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isUserMessage ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Method to show message options (Copy)
  void _showMessageOptions(BuildContext context, Offset tapPosition, Message message) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40), // Menü pozisyonu
        Offset.zero & overlay.size, // Overlay boyutu
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0), // Köşeleri yuvarla
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF202020), // Arka plan rengini değiştir
              borderRadius: BorderRadius.circular(8.0), // Köşeleri yuvarla
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: const [
                Icon(Icons.copy, color: Colors.white), // Kopyalama ikonu
                SizedBox(width: 10), // İkon ve metin arasında boşluk
                Text(
                  'Kopyala',
                  style: TextStyle(color: Colors.white), // Metin rengi beyaz
                ),
              ],
            ),
          ),
        ),
        // Gelecekte daha fazla seçenek eklemek isterseniz, buraya ekleyebilirsiniz
      ],
      elevation: 0.0, // Gölgeyi kaldır
      color: Colors.transparent, // Menü arka planını şeffaf yap
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: message.text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj panoya kopyalandı')),
        );
      }
    });
  }


  // Build the additional suggestions bar
  Widget _buildAdditionalSuggestionsBar() {
    return AnimatedOpacity(
      opacity: additionalSuggestionsOpacity,
      duration: const Duration(milliseconds: 200), // Reduced duration
      child: additionalSuggestionsOpacity > 0.0
          ? _buildSuggestionsRow(additionalSuggestions, _additionalSuggestionsScrollController, isTopPanel: true)
          : const SizedBox.shrink(),
    );
  }

  // Build the main suggestions bar
  Widget _buildSuggestionsBar() {
    return AnimatedOpacity(
      opacity: suggestionsOpacity,
      duration: const Duration(milliseconds: 200), // Reduced duration
      child: suggestionsOpacity > 0.0
          ? _buildSuggestionsRow(suggestions, _suggestionsScrollController)
          : const SizedBox.shrink(),
    );
  }

  // Build a row of suggestion buttons with enhanced gesture detection
  Widget _buildSuggestionsRow(List<String> suggestions, ScrollController scrollController,
      {bool isTopPanel = false}) {
    return SizedBox(
      height: 50,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          // Pause animations when user interacts with the panel
          _pauseAnimations();
          return true;
        },
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: suggestions.map(_buildSuggestionButton).toList(),
          ),
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

  // Scroll to the bottom of the ListView
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Pause both suggestion animations
  void _pauseAnimations() {
    if (_suggestionsAnimationController.isAnimating) {
      _suggestionsAnimationController.stop();
    }
    if (_additionalSuggestionsAnimationController.isAnimating) {
      _additionalSuggestionsAnimationController.stop();
    }
    setState(() {
      suggestionsOpacity = 1.0; // Optionally, you can adjust opacity if needed
      additionalSuggestionsOpacity = 1.0; // Optionally, you can adjust opacity if needed
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the input controller
    responseTimer?.cancel(); // Cancel the response timer
    _scrollController.dispose(); // Dispose of the scroll controller

    _suggestionsAnimationController.dispose();
    _additionalSuggestionsAnimationController.dispose();
    _suggestionsScrollController.dispose();
    _additionalSuggestionsScrollController.dispose();

    _fadeAnimationController.dispose(); // Dispose of the fade animation controller

    super.dispose();
  }
}

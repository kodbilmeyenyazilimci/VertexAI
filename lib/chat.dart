// chat.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'account.dart';
import 'data.dart';
import 'main.dart';
import 'menu.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Localization package
import 'api.dart'; // Import ApiService
import 'package:flutter_markdown/flutter_markdown.dart'; // For rendering markdown
import 'premium.dart';
import 'theme.dart'; // Import ThemeProvider
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Represents user and model messages
class Message {
  String text; // Mutable text
  final bool isUserMessage;
  Message({required this.text, required this.isUserMessage});
}

// Represents model information
class ModelInfo {
  final String title;
  final String description;
  final String imagePath;
  final String size;
  final String ram;
  final String producer;
  final String path;

  ModelInfo({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.size,
    required this.ram,
    required this.producer,
    required this.path,
  });
}

class ChatScreen extends StatefulWidget {
  String? conversationID;
  String? conversationTitle;

  // New parameters to receive model information
  final String? modelTitle;
  final String? modelDescription;
  final String? modelImagePath;
  final String? modelSize;
  final String? modelRam;
  final String? modelProducer;
  final String? modelPath;

  ChatScreen({
    Key? key,
    this.conversationID,
    this.conversationTitle,
    this.modelTitle,
    this.modelDescription,
    this.modelImagePath,
    this.modelSize,
    this.modelRam,
    this.modelProducer,
    this.modelPath,
  }) : super(key: key);

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  List<Message> messages = []; // Stores conversation messages
  final TextEditingController _controller =
  TextEditingController(); // Manages input text
  bool isModelLoaded = false; // Tracks if the model is loaded
  bool isWaitingForResponse =
  false; // Tracks if waiting for model's response
  Timer? responseTimer; // Timer to manage delayed responses
  final uuid = Uuid(); // Generates unique conversation IDs
  String? conversationID; // Current conversation ID
  String? conversationTitle; // Current conversation title
  late AnimationController _modelAnimationController;
  final Duration _modelAnimationDuration = const Duration(milliseconds: 500);
  final int _modelAnimationDelay = 100; // milliseconds delay between each item
  static const MethodChannel llamaChannel =
  MethodChannel('com.vertex.ai/llama');

  bool _isSendButtonVisible = false; // Controls send button visibility
  final ScrollController _scrollController =
  ScrollController(); // Controls message list scrolling

  // Model information variables
  String? modelTitle;
  String? modelDescription;
  String? modelImagePath;
  String? modelSize;
  String? modelRam;
  String? modelProducer;
  String? modelPath;

  bool isModelSelected = false; // Tracks if a model is selected

  List<ModelInfo> _allModels = []; // List of all models
  List<ModelInfo> _filteredModels = []; // Models filtered by search
  String _searchQuery = '';

  final ApiService apiService = ApiService(); // ApiService instance

  // New flag: responseStopped
  bool responseStopped = false;

  // Variables for inappropriate message warning
  bool _showInappropriateMessageWarning = false;

  // Animation variables for inappropriate message warning
  late AnimationController _warningAnimationController;
  late Animation<Offset> _warningSlideAnimation;
  late Animation<double> _warningFadeAnimation;

  void reloadModels() {
    setState(() {
      _loadModels();
    });
  }

  // Initialization: Load model, set up message handler, load previous messages
  @override
  void initState() {
    super.initState();

    // Retrieve model information from widget
    modelTitle = widget.modelTitle;
    modelDescription = widget.modelDescription;
    modelImagePath = widget.modelImagePath;
    modelSize = widget.modelSize;
    modelRam = widget.modelRam;
    modelProducer = widget.modelProducer;
    modelPath = widget.modelPath;

    // Initialize model animation controller
    _modelAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Initialize the AnimationController for the warning notification
    _warningAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Define the slide animation
    _warningSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),  // Alt kısımdan başlayarak yukarı doğru hareket
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _warningAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Define the fade animation
    _warningFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _warningAnimationController,
        curve: Curves.easeIn,
      ),
    );

    if (isServerSideModel(modelTitle)) {
      isModelSelected = true;
      isModelLoaded = true; // Server-side models are always loaded via API
    } else if (modelPath != null && modelPath!.isNotEmpty) {
      isModelSelected = true;
      loadModel(); // Load AI model
    } else {
      isModelSelected = false;
      _loadModels();
    }

    llamaChannel
        .setMethodCallHandler(_methodCallHandler); // Set method channel handler

    if (widget.conversationID != null) {
      _loadPreviousMessages(widget.conversationID!); // Load previous messages
      conversationID = widget.conversationID;
      conversationTitle = widget.conversationTitle;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isModelSelected) {
        _modelAnimationController.forward();
      }
    });
  }

  Future<void> _loadModels() async {
    _allModels.clear();

    final prefs = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> allModels = ModelData.models(context);

    for (var model in allModels) {
      String title = model['title']!;
      final isDownloaded = prefs.getBool('is_downloaded_$title') ?? false;
      if (isDownloaded) {
        String modelFilePath = await _getModelFilePath(title);
        _allModels.add(ModelInfo(
          title: title,
          description: model['description']!,
          imagePath: model['image']!,
          size: model['size']!,
          ram: model['ram']!,
          producer: model['producer']!,
          path: modelFilePath, // Set correct path
        ));
      }
    }

    // Add server-side models to the list
    _allModels.add(ModelInfo(
      title: 'Gemini',
      description: 'Gemini AI Model',
      imagePath: 'assets/gemini.png',
      size: '',
      ram: '',
      producer: 'Google',
      path: 'gemini',
    ));

    // Add Llama3.2 model to the list
    _allModels.add(ModelInfo(
      title: 'Llama3.2',
      description: 'Llama3.2 AI Model',
      imagePath: 'assets/llama.png', // Update with actual image path
      size: '', // Size not applicable
      ram: '', // RAM not applicable
      producer: 'Meta', // Producer of Llama
      path: 'llama3.2', // Placeholder path as 'llama3.2'
    ));

    // Add Hermes model to the list
    _allModels.add(ModelInfo(
      title: 'Hermes',
      description: 'Hermes 3 AI Model',
      imagePath: 'assets/hermes.png', // Placeholder image path
      size: '', // Size not applicable
      ram: '', // RAM not applicable
      producer: 'Nous Research', // Producer of Hermes
      path: 'hermes', // Placeholder path
    ));

    // Initialize filtered models
    _filteredModels = List.from(_allModels);

    setState(() {});

    // Update animation controller
    _initializeModelAnimationController();
  }

  void _initializeModelAnimationController() {
    _modelAnimationController.dispose();
    _modelAnimationController = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: _filteredModels.length * _modelAnimationDelay +
              _modelAnimationDuration.inMilliseconds),
    );
    _modelAnimationController.forward();
  }

  // Load model configuration and invoke local method to load the model
  Future<void> loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedModelPath = modelPath ?? prefs.getString('selected_model_path');
    if (selectedModelPath != null && selectedModelPath.isNotEmpty) {
      try {
        llamaChannel.invokeMethod('loadModel', {'path': selectedModelPath});
        setState(() {
          isModelLoaded = true; // Indicate that the model is loaded
        });
      } catch (e) {
        print('Error loading model: $e');
        setState(() {
          isModelLoaded = false;
        });
      }
    } else {
      // Model not selected
      setState(() {
        isModelLoaded = false;
      });
    }
  }

  // MethodCall handler to receive and respond to messages from the model
  Future<void> _methodCallHandler(MethodCall call) async {
    if (call.method == 'onMessageResponse') {
      if (isLocalModel(modelTitle)) {
        // Yerel model, veriyi String olarak işleyelim
        _onMessageResponse(call.arguments as String);
      } else if (isServerSideModel(modelTitle)) {
        // Sunucu taraflı model, veriyi UTF8 olarak işleyelim
        final data = call.arguments;
        String decodedMessage;
        if (data is Uint8List) {
          decodedMessage = utf8.decode(data);
        } else if (data is String) {
          decodedMessage = data;
        } else {
          decodedMessage = '';
        }
        _onMessageResponse(decodedMessage);
      }
    } else if (call.method == 'onMessageComplete') {
      _finalizeResponse(); // Yanıt tamamlandığında işlem sonlandır
    } else if (call.method == 'onModelLoaded') {
      setState(() => isModelLoaded = true); // Modelin yüklendiğini belirt
    }
  }

  // Yerel model olup olmadığını kontrol eden fonksiyon
  bool isLocalModel(String? modelTitle) {
    // Model server-side modellerden biri değilse yerel model kabul edilir
    return !isServerSideModel(modelTitle);
  }

  // Sunucu taraflı model olup olmadığını kontrol eden fonksiyon
  bool isServerSideModel(String? modelTitle) {
    return modelTitle == 'Gemini' || modelTitle == 'Llama3.2' || modelTitle == 'Hermes';
  }

  Future<String> _getModelFilePath(String title) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String filesDirectoryPath = appDocDir.path;
    String sanitizedTitle = title.replaceAll(' ', '_');
    return path.join(filesDirectoryPath, '$sanitizedTitle.gguf');
  }

  // Process tokens from the model by updating the last message
  void _onMessageResponse(String token) {
    if (isWaitingForResponse &&
        messages.isNotEmpty &&
        !messages.last.isUserMessage) {
      setState(() {
        messages.last.text += token; // Append token to last message
      });
      _startResponseTimeout(); // Start or reset response timeout

      if (_isUserAtBottom()) {
        _scrollToBottom();
      }
    }
  }

  // Start a timer to finalize response after a delay
  void _startResponseTimeout() {
    responseTimer?.cancel(); // Cancel existing timer
    responseTimer =
        Timer(const Duration(seconds: 5), _finalizeResponse); // 5 sec delay
  }

  // Finalize and display the model's response
  void _finalizeResponse() {
    if (isWaitingForResponse &&
        messages.isNotEmpty &&
        !messages.last.isUserMessage) {
      setState(() {
        // Trim trailing spaces
        messages.last.text = messages.last.text.trimRight();
        isWaitingForResponse = false;
      });

      String fullResponse = messages.last.text;

      // Save the response to conversation
      _saveMessageToConversation(fullResponse, false);

      _scrollToBottom(forceScroll: true);
    }

    responseTimer?.cancel();
  }

  // Load previous messages using conversation ID
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
    }
    setState(() {}); // Refresh UI
    _scrollToBottom(forceScroll: true); // Scroll to show loaded messages
  }

  // Save conversation title
  Future<void> _saveConversationTitle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_conversation_title', title); // Save title
  }

  // Save individual messages to the conversation
  Future<void> _saveMessageToConversation(
      String message, bool isUserMessage) async {
    final prefs = await SharedPreferences.getInstance();

    if (conversationID == null) return; // Ensure conversationID is set

    if (isUserMessage) {
      final List<String> conversationMessages =
          prefs.getStringList(conversationID!) ?? [];
      conversationMessages.add("User: $message");
      await prefs.setStringList(conversationID!, conversationMessages);
    } else {
      // Save model response
      final List<String> conversationMessages =
          prefs.getStringList(conversationID!) ?? [];
      conversationMessages.add("Model: $message");
      await prefs.setStringList(conversationID!, conversationMessages);
    }
  }

  // Load a selected conversation
  void loadConversation(ConversationData conversationData) {
    setState(() {
      widget.conversationID = conversationData.conversationID;
      widget.conversationTitle = conversationData.conversationTitle;
      conversationID = conversationData.conversationID;
      conversationTitle = conversationData.conversationTitle;
      modelTitle = conversationData.modelTitle;
      modelImagePath = conversationData.modelImagePath;
      isModelSelected = true;
      isModelLoaded = isServerSideModel(modelTitle) ? true : false;
      messages.clear();
      responseStopped = false; // Reset the flag
    });
    _loadPreviousMessages(conversationData.conversationID);
    if (isServerSideModel(modelTitle)) {
      setState(() {
        isModelLoaded = true;
      });
    } else {
      loadModel(); // Load the selected model
    }
  }

  // Update the conversation title
  void updateConversationTitle(String newTitle) {
    setState(() {
      conversationTitle = newTitle;
    });
  }

  // Update model data and reset the conversation
  void updateModelData({
    String? title,
    String? description,
    String? imagePath,
    String? size,
    String? ram,
    String? producer,
    String? path,
    required bool isServerSide,
  }) {
    setState(() {
      modelTitle = title ?? modelTitle;
      modelDescription = description ?? modelDescription;
      modelImagePath = imagePath ?? modelImagePath;
      modelSize = size ?? modelSize;
      modelRam = ram ?? modelRam;
      modelProducer = producer ?? modelProducer;
      modelPath = path ?? modelPath;
      isModelSelected = true;

      if (isServerSideModel(modelTitle)) {
        isModelLoaded = true;
      } else {
        isModelLoaded = false;
        // Load the new model
        loadModel();
      }

      // Reset the conversation
      resetConversation();
    });
  }

  // Handle model selection
  void _selectModel(ModelInfo model) {
    setState(() {
      modelTitle = model.title;
      modelDescription = model.description;
      modelImagePath = model.imagePath;
      modelSize = model.size;
      modelRam = model.ram;
      modelProducer = model.producer;
      modelPath = model.path;

      isModelSelected = true;
    });

    if (isServerSideModel(modelTitle)) {
      setState(() {
        isModelLoaded = true; // Server-side models are loaded via API
      });
    } else {
      // Load the selected model
      loadModel();
    }
  }

  // Reset the conversation to initial state
  void resetConversation() {
    setState(() {
      messages.clear();
      conversationID = null;
      conversationTitle = null;
      widget.conversationID = null;
      widget.conversationTitle = null;
      isWaitingForResponse = false;
      _isSendButtonVisible = false;
      responseStopped = false; // Reset the flag
    });
  }

  // Save the conversation details
  Future<void> _saveConversation(String conversationName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> conversations = prefs.getStringList('conversations') ?? [];

    String conversationEntry =
        '$conversationID|$conversationName|$modelTitle|$modelImagePath|$modelDescription|$modelSize|$modelRam|$modelProducer|$modelPath';

    // Prevent saving duplicate conversations
    if (conversations.any((c) => c.startsWith('$conversationID|'))) return;

    conversations.add(conversationEntry);
    await prefs.setStringList('conversations', conversations);
  }

  // Check if the user is at the bottom of the scroll view
  bool _isUserAtBottom() {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return (maxScroll - currentScroll) <=
        50; // Consider within 50 pixels from the bottom
  }

  // Scroll function
  void _scrollToBottom({bool forceScroll = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (forceScroll || _isUserAtBottom()) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  // Manage input text changes to show/hide send button
  void _onTextChanged(String text) {
    setState(() =>
    _isSendButtonVisible = text.isNotEmpty && !isWaitingForResponse);
  }

  // Manage message sending
  void _sendMessage([String? textFromButton]) async {
    String text = textFromButton ?? _controller.text.trim();

    if (text.isNotEmpty) {
      // Check if the message is appropriate
      if (!_isMessageAppropriate(text)) {
        // Show the inappropriate message warning
        _showInappropriateMessageWarning;
        return; // Do not proceed with sending the message
      }

      setState(() {
        messages.add(
            Message(text: text, isUserMessage: true)); // Add user message
        _controller.clear(); // Clear input field
        isWaitingForResponse = true; // Set waiting status
        _isSendButtonVisible = false; // Hide send button

        // Add empty model message to receive tokens
        messages.add(Message(text: "", isUserMessage: false)); // Placeholder
      });

      if (conversationID == null) {
        conversationID = uuid.v4(); // Generate conversation ID
        conversationTitle = text; // Use first message as title
        _saveConversationTitle(conversationTitle!); // Save title
        _saveConversation(conversationTitle!); // Save conversation immediately

        // Notify MenuScreen to reload conversations
        mainScreenKey.currentState?.menuScreenKey.currentState
            ?.reloadConversations();
      }

      // Save user's message
      _saveMessageToConversation(text, true);

      if (modelTitle == 'Gemini') {
        // Use ApiService to get response from Gemini API
        try {
          String response = await apiService.getGeminiResponse(text);

          // Display response with typewriter effect
          _typeWriterEffect(response);
        } catch (e) {
          // Handle errors
          setState(() {
            isWaitingForResponse = false;
            if (messages.isNotEmpty && !messages.last.isUserMessage) {
              messages.last.text = 'Error: $e';
            } else {
              messages.add(Message(text: 'Error: $e', isUserMessage: false));
            }
          });
        }
      } else if (modelTitle == 'Llama3.2') {
        // Use ApiService to get response from Llama3.2 API
        try {
          String response = await apiService.getLlamaResponse(text);

          // Display response with typewriter effect
          _typeWriterEffect(response);
        } catch (e) {
          // Handle errors
          setState(() {
            isWaitingForResponse = false;
            if (messages.isNotEmpty && !messages.last.isUserMessage) {
              messages.last.text = 'Error: $e';
            } else {
              messages.add(Message(text: 'Error: $e', isUserMessage: false));
            }
          });
        }
      } else if (modelTitle == 'Hermes') {
        // Get response from Hermes API
        try {
          String response = await apiService.getHermesResponse(text);
          _typeWriterEffect(response);
        } catch (e) {
          // Handle errors
          setState(() {
            isWaitingForResponse = false;
            if (messages.isNotEmpty && !messages.last.isUserMessage) {
              messages.last.text = 'Error: $e';
            } else {
              messages.add(Message(text: 'Error: $e', isUserMessage: false));
            }
          });
        }
      } else {
        // Existing code for other models (if any)
        llamaChannel.invokeMethod(
            'sendMessage', {'message': text}); // Send message to model
        _startResponseTimeout(); // Start response timer
        _scrollToBottom(forceScroll: true); // Scroll to show new message
      }
    }
  }

  // Function to stop the ongoing response
  void _stopResponse() {
    if (isWaitingForResponse) {
      setState(() {
        responseStopped = true; // Set the flag to indicate stopping
        isWaitingForResponse = false; // Update the waiting status
        _isSendButtonVisible =
            _controller.text.isNotEmpty; // Update send button visibility
      });
      responseTimer?.cancel();
      _finalizeResponse();
    }
  }

  // Typewriter effect for API responses
  Future<void> _typeWriterEffect(String fullText) async {
    int index = 0;
    String buffer = '';
    const int batchSize = 5; // Number of characters to add each time
    const int delayDuration = 50; // Delay duration in milliseconds

    while (index < fullText.length &&
        isWaitingForResponse &&
        !responseStopped) {
      int endIndex = index + batchSize;
      if (endIndex > fullText.length) endIndex = fullText.length;
      buffer = fullText.substring(index, endIndex);
      index = endIndex;

      setState(() {
        if (messages.isNotEmpty && !messages.last.isUserMessage) {
          messages.last.text += buffer;
        }
      });

      if (_isUserAtBottom()) {
        _scrollToBottom();
      }

      await Future.delayed(Duration(milliseconds: delayDuration));
    }

    setState(() {
      isWaitingForResponse = false;
    });

    // Save the response
    _saveMessageToConversation(messages.last.text, false);

    responseStopped = false; // Reset the flag
    _scrollToBottom(forceScroll: true); // Scroll to bottom after completion
  }

  // Check if the message is appropriate
// Check if the message is appropriate
  bool _isMessageAppropriate(String text) {
    List<String> inappropriateWords = [
      'seks',
      'sikiş',
      'porno',
      'yarak',
      'pussy',
      'yarrak',
      'salak',
      'aptal',
      'orospu',
      'göt',
      'intihar',
      'ölmek',
      'çocuk pornosu',
      'sex',
      'amk',
      'motherfucker',
      'fuck',
      'porn',
      'child porn',
      'suicide',
      'sik',
      'siksem',
      'sikmek',
      'sakso',
      'blowjob',
      'handjob',
      'asshole'
    ];

    // Normalize the input text
    final lowerText = text.toLowerCase();

    for (var word in inappropriateWords) {
      // Create a regex pattern with word boundaries
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b');
      if (pattern.hasMatch(lowerText)) {
        setState(() {
          _showInappropriateMessageWarning = true; // Show warning
        });
        _warningAnimationController.forward(); // Start the animation

        // Hide the warning after 3 seconds
        Future.delayed(Duration(seconds: 3), () {
          setState(() {
            _showInappropriateMessageWarning = false;
          });
          _warningAnimationController.reverse(); // Reverse the animation
        });

        return false; // Message is inappropriate
      }
    }
    return true; // Message is appropriate
  }

  // Build method: Creates chat or model selection screen
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; // Access localization
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
    return Scaffold(
      appBar:
      _buildAppBar(context, localizations, _isDarkTheme), // Custom app bar
      body: Stack(
        children: [
          Container(
            color: _isDarkTheme
                ? const Color(0xFF090909)
                : Colors.white, // Background color adjusted
            child: Column(
              children: [
                // AnimatedSwitcher applies only to the changing content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    // Ensure same size by using Expanded
                    child: isModelSelected
                        ? Container(
                      key: const ValueKey('chat'),
                      child: _buildChatScreen(
                          localizations, _isDarkTheme),
                    )
                        : Container(
                      key: const ValueKey('selection'),
                      child: _buildModelSelectionScreen(
                          localizations, _isDarkTheme),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Warning notification for inappropriate messages
          // Warning notification for inappropriate messages
          if (_showInappropriateMessageWarning)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.09, // Alt kısımdan biraz yukarıda
              left: MediaQuery.of(context).size.width * 0.1,
              right: MediaQuery.of(context).size.width * 0.1,
              child: SlideTransition(
                position: _warningSlideAnimation,
                child: FadeTransition(
                  opacity: _warningFadeAnimation,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 20.0),
                      decoration: BoxDecoration(
                        color: Colors.red, // Red background
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          localizations.inappropriateMessageWarning,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // White text
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build the model selection screen
  Widget _buildModelSelectionScreen(
      AppLocalizations localizations, bool _isDarkTheme) {
    return _allModels.isNotEmpty
        ? Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildSearchBar(localizations, _isDarkTheme),
        ),
        // Models grid or "No results found" message
        Expanded(
          child: _filteredModels.isNotEmpty
              ? GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 models per row
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.75, // Adjust as needed
            ),
            itemCount: _filteredModels.length,
            itemBuilder: (context, index) {
              final model = _filteredModels[index];

              // Calculate animation interval
              final start = index *
                  _modelAnimationDelay /
                  _modelAnimationController
                      .duration!.inMilliseconds;
              final end = start +
                  _modelAnimationDuration.inMilliseconds /
                      _modelAnimationController
                          .duration!.inMilliseconds;
              final animation = Tween<double>(begin: 0, end: 1)
                  .animate(
                CurvedAnimation(
                  parent: _modelAnimationController,
                  curve:
                  Interval(start, end, curve: Curves.easeIn),
                ),
              );

              String imagePath = model.imagePath;

              return FadeTransition(
                opacity: animation,
                child: GestureDetector(
                  onTap: () {
                    _selectModel(model);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isDarkTheme
                          ? const Color(0xFF1B1B1B)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(2, 2),
                        ),
                      ],
                      border: Border.all(
                          color: _isDarkTheme
                              ? Colors.grey[700]!
                              : Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius:
                            BorderRadius.circular(8.0),
                            child: Image.asset(
                              imagePath,
                              height: 80,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          model.title,
                          style: TextStyle(
                            color: _isDarkTheme
                                ? Colors.white
                                : Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          model.producer,
                          style: TextStyle(
                            color: _isDarkTheme
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
              : Center(
            child: Text(
              localizations.noMatchingModels,
              style: TextStyle(
                  color: _isDarkTheme
                      ? Colors.white70
                      : Colors.black54),
            ),
          ),
        ),
      ],
    )
        : Center(
      child: Text(
        localizations.noModelsDownloaded,
        style: TextStyle(
            color: _isDarkTheme ? Colors.white70 : Colors.black54),
      ),
    );
  }

  // Build the search bar
  Widget _buildSearchBar(
      AppLocalizations localizations, bool _isDarkTheme) {
    return TextField(
      decoration: InputDecoration(
        hintText: localizations.searchHint,
        hintStyle:
        TextStyle(color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600]),
        prefixIcon: Icon(Icons.search,
            color: _isDarkTheme ? Colors.white : Colors.black),
        filled: true,
        fillColor: _isDarkTheme ? Colors.grey[900] : Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
          BorderSide(color: _isDarkTheme ? Colors.white : Colors.black),
        ),
        contentPadding: EdgeInsets.zero,
      ),
      style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black),
      onChanged: (value) {
        setState(() {
          _searchQuery = value.toLowerCase();
          _filteredModels = _allModels.where((model) {
            return model.title.toLowerCase().startsWith(_searchQuery);
          }).toList();

          // Update animation controller
          _initializeModelAnimationController();
        });
      },
    );
  }

  // Build the chat screen
  Widget _buildChatScreen(
      AppLocalizations localizations, bool _isDarkTheme) {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (modelImagePath != null)
                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(15.0), // Soften edges
                      child: Image.asset(
                        modelImagePath!,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (modelTitle != null)
                    Text(
                      modelTitle!,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        color:
                        _isDarkTheme ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          )
              : _buildMessagesList(_isDarkTheme),
        ),
        _buildInputField(localizations, _isDarkTheme),
      ],
    );
  }

  // Build the AppBar
  AppBar _buildAppBar(BuildContext context,
      AppLocalizations localizations, bool _isDarkTheme) {
    return AppBar(
      toolbarHeight: 60,
      backgroundColor:
      _isDarkTheme ? const Color(0xFF090909) : Colors.white,
      centerTitle: true,
      leading: isModelSelected
          ? IconButton(
        icon: Icon(Icons.arrow_back,
            color: _isDarkTheme ? Colors.white : Colors.black),
        onPressed: () {
          setState(() {
            isModelSelected = false;
            modelTitle = null;
            modelDescription = null;
            modelImagePath = null;
            modelSize = null;
            modelRam = null;
            modelProducer = null;
            modelPath = null;
            isModelLoaded = false;
            resetConversation();
          });
        },
      )
          : IconButton(
        icon: Container(
          decoration: BoxDecoration(
            color:
            _isDarkTheme ? Colors.grey[900] : Colors.grey[300],
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(Icons.auto_awesome,
                color:
                _isDarkTheme ? Colors.white : Colors.black,
                size: 24),
          ),
        ),
        onPressed: () => _navigateToPremiumScreen(context),
      ),
      title: isModelSelected
          ? Text(
        conversationTitle ?? modelTitle ?? '',
        style: TextStyle(
            color: _isDarkTheme ? Colors.white : Colors.black),
      )
          : Text(
        localizations.appTitle,
        style: GoogleFonts.afacad(
          color: _isDarkTheme ? Colors.white : Colors.black,
          fontSize: 32,
        ),
      ), // Centered Vertex AI title with stylish font
      actions: <Widget>[
        IconButton(
          icon: Container(
            decoration: BoxDecoration(
              color: _isDarkTheme ? Colors.grey[900] : Colors.grey[300],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.person,
                  color: _isDarkTheme ? Colors.white : Colors.black,
                  size: 24),
            ),
          ),
          onPressed: () => _navigateToScreen(
            context,
            AccountScreen(),
            isLeftToRight: false, // From right to left
          ),
        ),
      ],
    );
  }

  // Navigate to a specified screen with transition
  void _navigateToScreen(BuildContext context, Widget screen,
      {required bool isLeftToRight}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          Offset begin =
          isLeftToRight ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Navigate to the Premium screen
  void _navigateToPremiumScreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => PremiumScreen(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0); // Starts from left
          const end = Offset.zero; // Original position
          const curve = Curves.ease;

          var tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Build the messages list
  Widget _buildMessagesList(bool _isDarkTheme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return _buildMessageTile(messages[index], _isDarkTheme); // Display message
      },
    );
  }

  // Build a single message tile with copy functionality and model image
  Widget _buildMessageTile(Message message, bool _isDarkTheme) {
    if (message.isUserMessage) {
      // User messages
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: GestureDetector(
          onLongPressStart: (details) {
            _showMessageOptions(context, details.globalPosition, message.text);
          },
          child: Align(
            alignment: Alignment.centerRight,
            child: Transform.translate(
              offset: const Offset(-5, 0),
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDarkTheme
                      ? const Color(0xFF292a2c)
                      : Colors.grey[200], // Adjusted
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color:
                    _isDarkTheme ? Colors.white : Colors.black, // Adjusted
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // AI messages
      return AIMessageTile(
        text: message.text,
        imagePath: modelImagePath ?? '',
        isDarkTheme: _isDarkTheme, // Pass the theme
      );
    }
  }

  // Show message options like copy on long press with fade-in effect
  void _showMessageOptions(
      BuildContext context, Offset tapPosition, String messageText) async {
    final localizations = AppLocalizations.of(context)!;
    final _isDarkTheme =
        Provider.of<ThemeProvider>(context, listen: false).isDarkTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    const menuWidth = 150.0; // Menu width

    // Adjust the position if there's not enough space on the right
    Offset adjustedPosition = tapPosition;
    if (tapPosition.dx + menuWidth > screenWidth) {
      adjustedPosition = Offset(screenWidth - menuWidth - 16.0, tapPosition.dy);
    }

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        adjustedPosition.dx,
        adjustedPosition.dy,
        adjustedPosition.dx + menuWidth,
        adjustedPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy,
                  color: _isDarkTheme ? Colors.white : Colors.black),
              const SizedBox(width: 10),
              Text(
                localizations.copy,
                style: TextStyle(
                    color: _isDarkTheme ? Colors.white : Colors.black),
              ),
            ],
          ),
        ),
      ],
      elevation: 8.0,
      color: _isDarkTheme ? const Color(0xFF202020) : Colors.grey[200],
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: messageText));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.messageCopied)),
        );
      }
    });
  }

  // Build the input field for user messages
  Widget _buildInputField(
      AppLocalizations localizations, bool _isDarkTheme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: isModelLoaded
          ? TextField(
        controller: _controller,
        maxLength: 1000,
        decoration: InputDecoration(
          filled: true,
          fillColor: _isDarkTheme
              ? const Color(0xFF1B1B1B)
              : Colors.grey[200], // Adjusted
          counterText: '',
          hintText: localizations.messageHint,
          hintStyle: TextStyle(
              color: _isDarkTheme ? Colors.grey[500] : Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: _isDarkTheme ? Colors.white : Colors.black),
            borderRadius: BorderRadius.circular(10),
          ),
          suffixIcon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder:
                (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: isWaitingForResponse
                ? IconButton(
              key: const ValueKey('stopButton'),
              icon: Icon(
                Icons.stop,
                color: _isDarkTheme
                    ? Colors.white
                    : Colors.black, // Changed from red to white
                size: 24,
              ),
              onPressed: _stopResponse,
            )
                : _isSendButtonVisible
                ? IconButton(
              key: const ValueKey('sendButton'),
              icon: Icon(
                Icons.arrow_upward,
                color: _isDarkTheme
                    ? Colors.white
                    : Colors.black, // Adjusted
                size: 22,
              ),
              onPressed:
              _isSendButtonVisible ? _sendMessage : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            )
                : const SizedBox(
              key: ValueKey('empty'),
            ),
          ),
        ),
        style: TextStyle(
            color: _isDarkTheme ? Colors.white : Colors.black),
        onChanged: _onTextChanged,
        onSubmitted: (text) {
          if (!isWaitingForResponse) _sendMessage();
        },
        enabled: true, // Allow composing message even when waiting
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          localizations.modelLoading,
          style: TextStyle(
              color: _isDarkTheme ? Colors.grey : Colors.black54),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // Release input controller
    responseTimer?.cancel(); // Cancel response timer
    _scrollController.dispose(); // Release scroll controller
    _modelAnimationController.dispose(); // Release animation controller
    _warningAnimationController.dispose();
    super.dispose();
  }
}

// Updated AIMessageTile Widget
class AIMessageTile extends StatefulWidget {
  final String text;
  final String imagePath;
  final bool isDarkTheme;

  const AIMessageTile(
      {Key? key,
        required this.text,
        required this.imagePath,
        required this.isDarkTheme})
      : super(key: key);

  @override
  _AIMessageTileState createState() => _AIMessageTileState();
}

class _AIMessageTileState extends State<AIMessageTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500), // Fade-in duration
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward(); // Start animation
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String imagePath = widget.imagePath;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // More padding
      child: GestureDetector(
        onLongPressStart: (details) {
          _showMessageOptions(context, details.globalPosition, widget.text);
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _animation,
                child: imagePath.isNotEmpty
                    ? Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: ClipRRect(
                    borderRadius:
                    BorderRadius.circular(15.0), // Soften edges
                    child: Image.asset(
                      imagePath,
                      width: 30, // Smaller size
                      height: 30,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                    : Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: widget.isDarkTheme
                        ? Colors.grey[700]
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Icon(
                    Icons.person,
                    color: widget.isDarkTheme
                        ? Colors.white
                        : Colors.black,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: MarkdownBody(
                  data: widget.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color:
                      widget.isDarkTheme ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                    code: TextStyle(
                      color: widget.isDarkTheme
                          ? Colors.orange
                          : Colors.orange[800],
                      backgroundColor: widget.isDarkTheme
                          ? Colors.black54
                          : Colors.grey[300],
                    ),
                    blockquote: TextStyle(
                      color: widget.isDarkTheme
                          ? Colors.white70
                          : Colors.black87,
                      fontStyle: FontStyle.italic,
                    ),
                    strong: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    em: const TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show message options (Copy) with fade-in effect
  void _showMessageOptions(
      BuildContext context, Offset tapPosition, String messageText) async {
    final localizations = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    const menuWidth = 150.0; // Menu width

    // Adjust the position if there's not enough space on the right
    Offset adjustedPosition = tapPosition;
    if (tapPosition.dx + menuWidth > screenWidth) {
      adjustedPosition = Offset(screenWidth - menuWidth - 16.0, tapPosition.dy);
    }

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        adjustedPosition.dx,
        adjustedPosition.dy,
        adjustedPosition.dx + menuWidth,
        adjustedPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy,
                  color: widget.isDarkTheme ? Colors.white : Colors.black),
              const SizedBox(width: 10),
              Text(
                localizations.copy,
                style: TextStyle(
                    color:
                    widget.isDarkTheme ? Colors.white : Colors.black),
              ),
            ],
          ),
        ),
      ],
      elevation: 8.0,
      color: widget.isDarkTheme ? const Color(0xFF202020) : Colors.grey[200],
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: messageText));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.messageCopied)),
        );
      }
    });
  }
}
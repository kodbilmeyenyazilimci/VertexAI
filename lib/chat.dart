// chat.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';
import 'account.dart';
import 'data.dart';
import 'main.dart';
import 'menu.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Localization package
import 'api.dart'; // Import ApiService
import 'notifications.dart';
import 'premium.dart';
import 'theme.dart'; // Import ThemeProvider
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart'; // For checking internet connection
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart'; // Import for internet connection checking
import 'package:flutter_math_fork/flutter_math.dart'; // Import for LaTeX rendering
import 'system_info.dart';


// Represents user and model messages
class Message {
  String text; // Mutable text
  final bool isUserMessage;
  bool shouldFadeOut; // New field for fade out animation
  Message(
      {required this.text,
        required this.isUserMessage,
        this.shouldFadeOut = false});
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
    super.key,
    this.conversationID,
    this.conversationTitle,
    this.modelTitle,
    this.modelDescription,
    this.modelImagePath,
    this.modelSize,
    this.modelRam,
    this.modelProducer,
    this.modelPath,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  List<Message> messages = []; // Stores conversation messages
  final TextEditingController _controller =
  TextEditingController(); // Manages input text
  bool isModelLoaded = false; // Tracks if the model is loaded
  bool isWaitingForResponse = false; // Tracks if waiting for model's response
  Timer? responseTimer; // Timer to manage delayed responses
  final uuid = const Uuid(); // Generates unique conversation IDs
  String? conversationID; // Current conversation ID
  String? conversationTitle; // Current conversation title
  late AnimationController _modelAnimationController;
  final Duration _modelAnimationDuration = const Duration(milliseconds: 500);
  final int _modelAnimationDelay = 100; // milliseconds delay between each item
  static const MethodChannel llamaChannel = MethodChannel('com.vertex.ai/llama');
  bool _hasSavedMessage = false;
  final FocusNode _textFieldFocusNode = FocusNode(); // Initialize FocusNode

  bool _isSendButtonVisible = false; // Controls send button visibility
  final ScrollController _scrollController =
  ScrollController(); // Controls message list scrolling
  SystemInfoData? _systemInfo;
  bool isStorageSufficient = true; // Tracks storage sufficiency
  static const int requiredSizeMB = 1024; // 1GB in MB

  // Model information variables
  String? modelTitle;
  String? modelDescription;
  String? modelImagePath;
  String? modelSize;
  String? modelRam;
  String? modelProducer;
  String? modelPath;

  bool isModelSelected = false; // Tracks if a model is selected

  final List<ModelInfo> _allModels = []; // List of all models
  List<ModelInfo> _filteredModels = []; // Models filtered by search
  String _searchQuery = '';

  late ApiService apiService;
  bool _isApiServiceInitialized = false; // Tracks if ApiService is initialized

  // Added variables for input field height
  double _inputFieldHeight = 0.0;
  final GlobalKey _inputFieldKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isApiServiceInitialized) {
      final localizations = AppLocalizations.of(context)!;
      apiService = ApiService(localizations: localizations);
      _isApiServiceInitialized = true;
    }
  }

  // New flag: responseStopped
  bool responseStopped = false;

  // Variables for inappropriate message warning
  bool _showInappropriateMessageWarning = false;

  // Animation variables for inappropriate message warning
  late AnimationController _warningAnimationController;
  late Animation<Offset> _warningSlideAnimation;
  late Animation<double> _warningFadeAnimation;

  // Variable to control the visibility of the scroll-down button
  bool _showScrollDownButton = false;

  // New variable to track internet connection
  bool hasInternetConnection = true;
  late StreamSubscription<InternetStatus> _internetSubscription;

  void reloadModels() {
    setState(() {
      _loadModels();
    });
  }

  // Initialization: Load model, set up message handler, load previous messages
  @override
  void initState() {
    super.initState();
    _fetchSystemInfo();

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
      duration: Duration(
          milliseconds: _filteredModels.length * _modelAnimationDelay +
              _modelAnimationDuration.inMilliseconds),
    );

    // Initialize the AnimationController for the warning notification
    _warningAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Define the slide animation
    _warningSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0), // Starts from below
      end: const Offset(0, 0), // Slides up to original position
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

    // Add listener to handle when reverse animation completes
    _warningAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _showInappropriateMessageWarning = false;
        });
      }
    });

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

    llamaChannel.setMethodCallHandler(_methodCallHandler); // Set method channel handler

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

    // Add scroll listener for the scroll-down button
    _scrollController.addListener(_scrollListener);

    // Initialize internet connection listener
    _internetSubscription =
        InternetConnection().onStatusChange.listen((status) {
          final hasConnection = status == InternetStatus.connected;
          setState(() {
            hasInternetConnection = hasConnection;
            // Any UI updates needed
          });
        });
  }

  /// **New Method to Fetch System Information**
  Future<void> _fetchSystemInfo() async {
    try {
      SystemInfoData info = await SystemInfoProvider.fetchSystemInfo();
      setState(() {
        _systemInfo = info;
        // Assuming freeStorage is in MB
        isStorageSufficient = _systemInfo!.freeStorage >= requiredSizeMB;
      });
    } catch (e) {
      print("Error fetching system info: $e");
      setState(() {
        isStorageSufficient = false; // Assume insufficient if error occurs
      });
    }
  }


  // Scroll listener to control the visibility of the scroll-down button
  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    if (!_isUserAtBottom() && messages.length > 1) {
      if (!_showScrollDownButton) {
        setState(() {
          _showScrollDownButton = true;
        });
      }
    } else {
      if (_showScrollDownButton) {
        setState(() {
          _showScrollDownButton = false;
        });
      }
    }
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
    final selectedModelPath =
        modelPath ?? prefs.getString('selected_model_path');
    if (selectedModelPath != null && selectedModelPath.isNotEmpty) {
      try {
        await llamaChannel
            .invokeMethod('loadModel', {'path': selectedModelPath});
        setState(() {
          isModelLoaded = true; // Indicate that the model is loaded
        });
        // Model yüklendikten sonra klavyeyi açmak için odaklan
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(_textFieldFocusNode);
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
        _onMessageResponse(call.arguments as String);
      } else if (isServerSideModel(modelTitle)) {
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
      _stopResponse(); // Finalize when response is complete
    } else if (call.method == 'onModelLoaded') {
      setState(() => isModelLoaded = true); // Indicate model is loaded
    }
  }

  // Check if it's a local model
  bool isLocalModel(String? modelTitle) {
    // Assume non-server-side models are local
    return !isServerSideModel(modelTitle);
  }

  // Check if it's a server-side model
  bool isServerSideModel(String? modelTitle) {
    return modelTitle == 'Gemini' ||
        modelTitle == 'Llama3.2' ||
        modelTitle == 'Hermes';
  }

  Future<String> _getModelFilePath(String title) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String filesDirectoryPath = appDocDir.path;
    String sanitizedTitle = title.replaceAll(' ', '_');
    return path.join(filesDirectoryPath, '$sanitizedTitle.gguf');
  }

  // Process tokens from the model by updating the last message
  void _onMessageResponse(String token) {
    // If canceled, ignore the response
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
        Timer(const Duration(seconds: 5), _stopResponse); // 5 sec delay
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

    // Schedule scrolling to bottom after a short delay to ensure UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom(forceScroll: true);
      });
    });
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
      isModelLoaded = conversationData.isModelAvailable
          ? isServerSideModel(modelTitle)
          ? true
          : false
          : false;
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
      // Model yüklendikten sonra klavyeyi açmak için odaklan
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_textFieldFocusNode);
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
        20; // Reduced threshold to 20 pixels
  }

  // Scroll function
  Future<void> _scrollToBottom({bool forceScroll = false}) async {
    if (!_scrollController.hasClients) return;
    if (forceScroll || !_isUserAtBottom()) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
            milliseconds: 300), // Increased duration for smoother scroll
        curve: Curves.easeOut,
      );
      // After scrolling, ensure the button is hidden
      if (forceScroll) {
        setState(() {
          _showScrollDownButton = false;
        });
      }
    }
  }

  // Manage input text changes to show/hide send button
  void _onTextChanged(String text) {
    setState(() => _isSendButtonVisible = text.isNotEmpty && !isWaitingForResponse);
  }

  // Manage message sending
  void _sendMessage([String? textFromButton]) async {
    String text = textFromButton ?? _controller.text.trim();

    if (text.isNotEmpty) {
      // Check if the message is appropriate
      if (!_isMessageAppropriate(text)) {
        // Do not proceed with sending the message
        return;
      }

      setState(() {
        messages.add(Message(text: text, isUserMessage: true)); // Add user message
        _controller.clear(); // Clear input field
        isWaitingForResponse = true; // Set waiting status
        _isSendButtonVisible = false; // Hide send button
        responseStopped = false; // <-- Reset the flag here
        _hasSavedMessage = false;
        if (isServerSideModel(modelTitle)) {
          final localizations =
          AppLocalizations.of(context)!; // Localization access
          messages.add(Message(
              text: localizations.thinking,
              isUserMessage: false)); // Localized text
        } else {
          messages.add(Message(
              text: "", isUserMessage: false)); // Placeholder for AI response
        }
      });

      if (conversationID == null) {
        conversationID = uuid.v4(); // Generate conversation ID
        // Truncate the conversation title to 40 characters if necessary
        conversationTitle = text.length > 40 ? text.substring(0, 40) : text;
        _saveConversationTitle(conversationTitle!); // Save title
        _saveConversation(conversationTitle!); // Save conversation immediately

        // Notify MenuScreen to reload conversations
        mainScreenKey.currentState?.menuScreenKey.currentState
            ?.reloadConversations();
      }

      // Save user's message
      _saveMessageToConversation(text, true);
      _scrollToBottom();
      if (isServerSideModel(modelTitle)) {
        // Use ApiService to get response from server-side models
        try {
          String response;
          if (modelTitle == 'Gemini') {
            response = await apiService.getGeminiResponse(text);
          } else if (modelTitle == 'Llama3.2') {
            response = await apiService.getLlamaResponse(text);
          } else if (modelTitle == 'Hermes') {
            response = await apiService.getHermesResponse(text);
          } else {
            response = '';
          }

          // Clear "Thinking..." message
          setState(() {
            messages.last.text = '';
          });

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
      } else if (modelTitle == 'Gemini') {
        // Existing code for other server-side models (if any)
        // This block might be redundant now, since server-side models are handled above
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
  Future<void> _stopResponse() async {
    if (isWaitingForResponse) {
      setState(() {
        responseStopped = true; // Set the flag to stop the response
        isWaitingForResponse = false; // Update the waiting status
        _isSendButtonVisible =
            _controller.text.isNotEmpty; // Update send button visibility
      });
      responseTimer?.cancel();

      // Save the incomplete response
      if (messages.isNotEmpty &&
          !messages.last.isUserMessage &&
          !_hasSavedMessage) {
        // Check if the last message is not just the "Thinking" placeholder
        final lastMessageText = messages.last.text.trim();
        if (lastMessageText.isNotEmpty &&
            lastMessageText != AppLocalizations.of(context)!.thinking) {
          await _saveMessageToConversation(messages.last.text, false);
          setState(() {
            _hasSavedMessage = true; // Message saved
          });
        } else {
          // Instead of removing the incomplete "Thinking" message,
          // set shouldFadeOut to true
          setState(() {
            messages.last.shouldFadeOut = true;
          });
        }
      }
    }
  }

  // Typewriter effect for API responses
  Future<void> _typeWriterEffect(String fullText) async {
    List<String> words = fullText.split(' ');
    int index = 0;

    while (index < words.length &&
        isWaitingForResponse &&
        !responseStopped) {
      if (!mounted) return;

      setState(() {
        if (messages.isNotEmpty && !messages.last.isUserMessage) {
          messages.last.text += (index > 0 ? ' ' : '') + words[index];
        }
      });

      if (_isUserAtBottom()) {
        _scrollToBottom();
      }

      // *** Changed delay from 500ms to 42ms for overlapping animations ***
      await Future.delayed(const Duration(milliseconds: 42));
      index++;
    }

    if (!_hasSavedMessage) {
      if (!mounted) return;
      setState(() {
        isWaitingForResponse = false;
      });
      await _saveMessageToConversation(messages.last.text, false);
      setState(() {
        _hasSavedMessage = true;
      });
      _scrollToBottom(forceScroll: true);
    }
  }

  // Check if the message is appropriate
  bool _isMessageAppropriate(String text) {
    List<String> inappropriateWords = [      'seks',      'sikiş',      'porno',      'yarak',      'pussy',      'yarrak',      'salak',      'aptal',      'orospu',      'göt',      'intihar',      'ölmek',      'çocuk pornosu',      'sex',      'amk',      'motherfucker',      'fuck',      'porn',      'child porn',      'suicide',      'sik',      'siksem',      'sikmek',      'sakso',      'blowjob',      'handjob',      'asshole'    ];

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
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _warningAnimationController.reverse(); // Reverse the animation
          }
        });

        return false; // Message is inappropriate
      }
    }
    return true; // Message is appropriate
  }

  // Build method: Creates chat or model selection screen
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; // Localization access
    final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    // Measure the input field height
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox = _inputFieldKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final height = renderBox.size.height;
        if (_inputFieldHeight != height) {
          setState(() {
            _inputFieldHeight = height;
          });
        }
      }
    });

    return Scaffold(
      appBar: _buildAppBar(context, localizations, isDarkTheme),
      body: Stack(
        children: [
          // Main content: Keeps the existing background color
          Container(
            color: isDarkTheme ? const Color(0xFF090909) : Colors.white,
            child: Column(
              children: [
                // Message list or model selection
                Expanded(
                  child: AnimatedSwitcher(
                    duration:
                    const Duration(milliseconds: 150), // Shortened duration
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: isModelSelected
                        ? Container(
                      key: const ValueKey('chat'),
                      child: _buildChatScreen(localizations, isDarkTheme),
                    )
                        : Container(
                      key: const ValueKey('selection'),
                      child: _buildModelSelectionScreen(
                          localizations, isDarkTheme),
                    ),
                  ),
                ),
                // Input field
                _buildInputField(localizations, isDarkTheme),
              ],
            ),
          ),
          // Scroll Down Button (Only visible in Chat Screen and when conditions met)
          if (isModelSelected && messages.length > 1)
            Positioned(
              bottom: _inputFieldHeight + 16.0, // Adjust position based on input field height
              left: 0, // Aligns button horizontally to center
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedOpacity(
                    opacity: _showScrollDownButton ? 1.0 : 0.0,
                    duration:
                    const Duration(milliseconds: 200), // Shortened duration
                    child: GestureDetector(
                      onTap: () async {
                        // Start fading out
                        setState(() {
                          _showScrollDownButton = false;
                        });
                        // Start scrolling
                        await _scrollToBottom(forceScroll: true);
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color:
                          isDarkTheme ? Color(0xFF161616) : Color(0xFFE9E9E9),
                          borderRadius:
                          BorderRadius.circular(12), // Rounded edges
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_downward,
                          color: isDarkTheme ? Colors.white : Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Inappropriate message warning (Overlay)
          if (_showInappropriateMessageWarning)
            Positioned(
              bottom: _inputFieldHeight + 80, // Adjusted position
              left: 16,
              right: 16,
              child: SlideTransition(
                position: _warningSlideAnimation,
                child: FadeTransition(
                  opacity: _warningFadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 20.0),
                    decoration: BoxDecoration(
                      color: isDarkTheme
                          ? Colors.red[700] // Dark theme red
                          : Colors.red, // Light theme red
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            localizations.inappropriateMessageWarning,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // White text
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // New method to show internet required notification using NotificationService
  void _showInternetRequiredNotification() {
    final localizations = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkTheme = themeProvider.isDarkTheme;

    final notificationService =
    Provider.of<NotificationService>(context, listen: false);

    notificationService.showCustomNotification(
      message: localizations.internetRequired,
      backgroundColor: isDarkTheme ? Colors.red[700]! : Colors.red,
      textColor: Colors.white,
      icon: Icons.wifi_off, // Icon indicating no internet
      beginOffset: const Offset(0, 1.0),
      endOffset: const Offset(0, 0),
      bottomOffset: 80.0, // Adjust based on your UI
      fontSize: 12.0,
      maxWidth: 380.0, // Adjust as needed
      width: 360.0, // Optional: set a fixed width
      duration: const Duration(seconds: 2),
    );
  }

  // Build the model selection screen
  Widget _buildModelSelectionScreen(
      AppLocalizations localizations, bool isDarkTheme) {
    return _allModels.isNotEmpty
        ? Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildSearchBar(localizations, isDarkTheme),
        ),
        // Models grid or "No results found" message
        Expanded(
          child: _filteredModels.isNotEmpty
              ? GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
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
              final animation =
              Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: _modelAnimationController,
                  curve:
                  Interval(start, end, curve: Curves.easeIn),
                ),
              );

              String imagePath = model.imagePath;

              // Determine if the model is a server-side model
              bool isServerSide = isServerSideModel(model.title);

              // Determine if the button should be disabled
              bool isDisabled =
                  !hasInternetConnection && isServerSide;

              return FadeTransition(
                opacity: animation,
                child: GestureDetector(
                  onTap: () {
                    if (isDisabled) {
                      _showInternetRequiredNotification(); // Show custom notification
                    } else {
                      _selectModel(model);
                      // Scroll to bottom when a model is selected
                      _scrollToBottom(forceScroll: true);
                    }
                  },
                  child: Opacity(
                    opacity: isDisabled ? 0.5 : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkTheme
                            ? const Color(0xFF1B1B1B)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(2, 2),
                          ),
                        ],
                        border: Border.all(
                            color: isDarkTheme
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
                              color: isDarkTheme
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
                              color: isDarkTheme
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
                ),
              );
            },
          )
              : Center(
            child: Text(
              localizations.noMatchingModels,
              style: TextStyle(
                  color: isDarkTheme
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
            color: isDarkTheme ? Colors.white70 : Colors.black54),
      ),
    );
  }

  // Build the search bar
  Widget _buildSearchBar(
      AppLocalizations localizations, bool isDarkTheme) {
    return TextField(
      cursorColor: isDarkTheme ? Colors.white : Colors.black,
      decoration: InputDecoration(
        hintText: localizations.searchHint,
        hintStyle:
        TextStyle(color: isDarkTheme ? Colors.grey[400] : Colors.grey[600]),
        prefixIcon:
        Icon(Icons.search, color: isDarkTheme ? Colors.white : Colors.black),
        filled: true,
        fillColor: isDarkTheme ? Colors.grey[900] : Colors.grey[200],
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
          BorderSide(color: isDarkTheme ? Colors.white : Colors.black),
        ),
        contentPadding: EdgeInsets.zero,
      ),
      style: TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
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
      AppLocalizations localizations, bool isDarkTheme) {
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
                        width: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (modelTitle != null)
                    Text(
                      modelTitle!,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        color: isDarkTheme ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          )
              : _buildMessagesList(isDarkTheme),
        ),
      ],
    );
  }

  // Build the AppBar
  AppBar _buildAppBar(BuildContext context,
      AppLocalizations localizations, bool isDarkTheme) {
    return AppBar(
      toolbarHeight: 60,
      backgroundColor: isDarkTheme ? const Color(0xFF090909) : Colors.white,
      centerTitle: true,
      scrolledUnderElevation: 0,
      leading: isModelSelected
          ? IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: isDarkTheme ? Colors.white : Colors.black,
        ),
        onPressed: () async {
          if (isWaitingForResponse) {
            await _stopResponse(); // Stop and save the response
          }
          // Reset model selection
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
          });
          resetConversation(); // Clear messages and reset state
        },
      )
          : IconButton(
        icon: Container(
          decoration: BoxDecoration(
            color: isDarkTheme ? Colors.grey[900] : Colors.grey[300],
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(Icons.auto_awesome,
                color: isDarkTheme ? Colors.white : Colors.black,
                size: 24),
          ),
        ),
        onPressed: () => _navigateToScreen(context, const PremiumScreen(),
            direction: const Offset(0.0, 1.0)),
      ),
      title: isModelSelected
          ? FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          modelTitle ?? '',
          style:
          TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
        ),
      )
          : Text(
        localizations.appTitle,
        style: GoogleFonts.afacad(
          color: isDarkTheme ? Colors.white : Colors.black,
          fontSize: 32,
        ),
      ), // Centered Vertex AI title with stylish font
      actions: <Widget>[
        IconButton(
          icon: Container(
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey[900] : Colors.grey[300],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.person,
                  color: isDarkTheme ? Colors.white : Colors.black, size: 24),
            ),
          ),
          onPressed: () => _navigateToScreen(context, const AccountScreen(),
              direction: const Offset(1.0, 0.0)),
        ),
      ],
    );
  }

  void _navigateToScreen(BuildContext context, Widget screen,
      {required Offset direction}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(begin: direction, end: end)
              .chain(CurveTween(curve: curve));

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
  Widget _buildMessagesList(bool isDarkTheme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return _buildMessageTile(
            messages[index], isDarkTheme); // Display message
      },
    );
  }

  // Build a single message tile with copy functionality and model image
  Widget _buildMessageTile(Message message, bool isDarkTheme) {
    if (message.isUserMessage) {
      // User messages
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: GestureDetector(
              onLongPressStart: (details) {
                _showMessageOptions(
                    context, details.globalPosition, message.text);
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
                      color: isDarkTheme
                          ? const Color(0xFF141414)
                          : Colors.grey[200], // Adjusted
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: isDarkTheme
                            ? Colors.white
                            : Colors.black, // Adjusted
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Add a 10-pixel space between consecutive user messages
          const SizedBox(height: 10),
        ],
      );
    } else {
      // Regular AI message tile
      return AIMessageTile(
        text: message.text,
        imagePath: modelImagePath ?? '',
        isDarkTheme: isDarkTheme, // Pass the theme
        shouldFadeOut: message.shouldFadeOut, // Pass the fade out flag
        onFadeOutComplete: () {
          // Remove the message from the messages list
          setState(() {
            messages.remove(message);
          });
        },
      );
    }
  }

  // Show message options like copy on long press with fade-in effect
  void _showMessageOptions(
      BuildContext context, Offset tapPosition, String messageText) async {
    final localizations = AppLocalizations.of(context)!;
    final isDarkTheme =
        Provider.of<ThemeProvider>(context, listen: false).isDarkTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    const menuWidth = 150.0; // Menu width

    // Adjust the position if there's not enough space on the right
    Offset adjustedPosition = tapPosition;
    if (tapPosition.dx + menuWidth > screenWidth) {
      adjustedPosition =
          Offset(screenWidth - menuWidth - 16.0, tapPosition.dy);
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
                  color: isDarkTheme ? Colors.white : Colors.black),
              const SizedBox(width: 10),
              Text(
                localizations.copy,
                style:
                TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
              ),
            ],
          ),
        ),
      ],
      elevation: 8.0,
      color: isDarkTheme ? const Color(0xFF202020) : Colors.grey[200],
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: messageText));
      }
    });
  }

  // Build the input field for user messages
  Widget _buildInputField(AppLocalizations localizations, bool isDarkTheme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: isModelSelected
          ? (isModelLoaded
          ? ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 150, // Approximately 6 lines height (24*6=144)
        ),
        child: Container(
          key: _inputFieldKey, // Assign the key here
          child: TextField(
            cursorColor: isDarkTheme ? Colors.white : Colors.black,
            focusNode: _textFieldFocusNode, // Assign FocusNode here
            controller: _controller,
            maxLength: 2000,
            minLines: 1, // Minimum 1 line
            maxLines: 6, // Maximum 6 lines
            keyboardType: TextInputType.multiline, // Multi-line keyboard
            textInputAction: TextInputAction.newline, // Support adding new lines
            decoration: InputDecoration(
              filled: true,
              fillColor: isDarkTheme
                  ? const Color(0xFF161616)
                  : Colors.grey[300], // Slightly darker background
              counterText: '',
              hintText: localizations.messageHint,
              hintStyle: TextStyle(
                  color: isDarkTheme
                      ? Colors.grey[500]
                      : Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15), // Softer edges
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15), // Softer edges
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color:
                    isDarkTheme ? Colors.white : Colors.black),
                borderRadius:
                BorderRadius.circular(15), // Softer edges
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 16.0, horizontal: 16.0),
              suffixIcon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder:
                    (Widget child, Animation<double> animation) {
                  return ScaleTransition(
                      scale: animation, child: child);
                },
                child: isWaitingForResponse
                    ? IconButton(
                  key: const ValueKey('stopButton'),
                  icon: Icon(
                    Icons.stop,
                    color: isDarkTheme
                        ? Colors.white
                        : Colors.black, // Adjusted for theme
                    size: 24,
                  ),
                  onPressed: _stopResponse,
                )
                    : _isSendButtonVisible
                    ? IconButton(
                  key: const ValueKey('sendButton'),
                  icon: Icon(
                    Icons.arrow_upward,
                    color: _isSendButtonEnabled
                        ? (isDarkTheme
                        ? Colors.white
                        : Colors.black)
                        : (isDarkTheme
                        ? Colors.grey
                        : Colors.grey[400]), // Adjusted
                    size: 22,
                  ),
                  onPressed:
                  _isSendButtonEnabled ? _sendMessage : null,
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
                color: isDarkTheme ? Colors.white : Colors.black),
            onChanged: _onTextChanged,
            onSubmitted: (text) {
              if (_isSendButtonEnabled) _sendMessage();
            },
            enabled: true, // Allow composing message even when waiting
          ),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          localizations.modelLoading,
          style: TextStyle(
              color:
              isDarkTheme ? Colors.white70 : Colors.black54),
        ),
      ))
          : const SizedBox
          .shrink(), // Show nothing when no model is selected
    );
  }

  // Getter to determine if send button should be enabled
  bool get _isSendButtonEnabled {
    if (!_isSendButtonVisible) return false;
    if (isWaitingForResponse) return false;
    if (isServerSideModel(modelTitle) && !hasInternetConnection) return false;
    if (!isStorageSufficient) return false; // **Check for Storage Sufficiency**
    return true;
  }

  @override
  void dispose() {
    _controller.dispose(); // Release input controller
    responseTimer?.cancel(); // Cancel response timer
    _scrollController.removeListener(_scrollListener); // Remove scroll listener
    _scrollController.dispose(); // Release scroll controller
    _modelAnimationController.dispose(); // Release animation controller
    _warningAnimationController.dispose();
    llamaChannel.setMethodCallHandler(null); // Remove method call handler
    _internetSubscription.cancel(); // Cancel internet connection listener
    _textFieldFocusNode.dispose(); // Dispose FocusNode to free resources
    super.dispose();
  }
}

class AIMessageTile extends StatefulWidget {
  final String text;
  final String imagePath;
  final bool isDarkTheme;
  final bool shouldFadeOut;
  final VoidCallback? onFadeOutComplete;

  const AIMessageTile({
    Key? key,
    required this.text,
    required this.imagePath,
    required this.isDarkTheme,
    required this.shouldFadeOut,
    this.onFadeOutComplete,
  }) : super(key: key);

  @override
  _AIMessageTileState createState() => _AIMessageTileState();
}

class _AIMessageTileState extends State<AIMessageTile>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isFadingOut = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration:
      const Duration(milliseconds: 500), // Fade-in and fade-out duration
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);

    // Start fade-in animation
    _fadeController.forward();

    // Fade-out animation completion callback
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _isFadingOut) {
        if (widget.onFadeOutComplete != null) {
          widget.onFadeOutComplete!();
        }
      }
    });
  }

  @override
  void didUpdateWidget(AIMessageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldFadeOut && !_isFadingOut) {
      _isFadingOut = true;
      // Reverse the animation for fade-out
      _fadeController.reverse();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Function to parse text and identify markdown and LaTeX expressions
  List<InlineSpan> _parseText(String text, bool isDarkTheme) {
    List<InlineSpan> spans = [];

    // Regex patterns to identify various markdown and LaTeX expressions
    final latexPattern =
        r'(\\\[.*?\\\]|\\\(.*?\\\)|\$\$.*?\$\$|\$.*?\$|\\begin\{.*?\}.*?\\end\{.*?\})';
    final codeBlockPattern = r'(```[\s\S]*?```|`[^`]+`)';
    final markdownPattern =
        r'(\*\*\*.*?\*\*\*|___.*?___|\*\*.*?\*\*|__.*?__|\*.*?\*|_.*?_|~~.*?~~)';
    final combinedPattern =
        '($latexPattern|$codeBlockPattern|$markdownPattern)';

    RegExp regex = RegExp(combinedPattern, multiLine: true);
    Iterable<RegExpMatch> matches = regex.allMatches(text);

    int currentIndex = 0;

    for (var match in matches) {
      if (match.start > currentIndex) {
        // Add normal text before the matched expression
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: TextStyle(
            color: isDarkTheme ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        ));
      }

      String matchText = match.group(0)!;

      InlineSpan span;

      if (RegExp(latexPattern, multiLine: true).hasMatch(matchText)) {
        // LaTeX expression
        String latex = matchText;

        // Remove \begin{...} and \end{...} if present
        latex = latex.replaceAllMapped(
            RegExp(r'\\begin\{.*?\}'), (m) => '');
        latex = latex.replaceAllMapped(
            RegExp(r'\\end\{.*?\}'), (m) => '');

        // Remove surrounding delimiters
        if ((latex.startsWith('\$\$') && latex.endsWith('\$\$')) ||
            (latex.startsWith('\\[') && latex.endsWith('\\]'))) {
          // Block LaTeX
          latex = latex.substring(2, latex.length - 2);
        } else if ((latex.startsWith('\$') && latex.endsWith('\$')) ||
            (latex.startsWith('\\(') && latex.endsWith('\\)'))) {
          // Inline LaTeX
          latex = latex.substring(1, latex.length - 1);
        }

        // Render LaTeX
        span = WidgetSpan(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Math.tex(
              latex,
              textStyle: TextStyle(
                color: isDarkTheme ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ),
        );
      } else if (matchText.startsWith('```') && matchText.endsWith('```')) {
        // Code block
        String content = matchText.substring(3, matchText.length - 3);
        span = TextSpan(
          text: content,
          style: TextStyle(
            color: isDarkTheme ? Colors.orange : Colors.brown,
            fontSize: 16,
            fontFamily: 'monospace',
            backgroundColor:
            isDarkTheme ? Colors.grey[800] : Colors.grey[300],
          ),
        );
      } else if (matchText.startsWith('***') && matchText.endsWith('***')) {
        // Bold Italic
        String content = matchText.substring(3, matchText.length - 3);
        span = TextSpan(
          text: content,
          style: TextStyle(
            color: isDarkTheme ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        );
      } else if (matchText.startsWith('___') && matchText.endsWith('___')) {
        // Bold Italic
        String content = matchText.substring(3, matchText.length - 3);
        span = TextSpan(
          text: content,
          style: TextStyle(
            color: isDarkTheme ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        );
      } else if ((matchText.startsWith('**') && matchText.endsWith('**')) ||
          (matchText.startsWith('__') && matchText.endsWith('__'))) {
        // Bold
        String content = matchText.substring(2, matchText.length - 2);
        span = TextSpan(
          text: content,
          style: TextStyle(
            color: isDarkTheme ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
      } else if ((matchText.startsWith('*') && matchText.endsWith('*')) ||
          (matchText.startsWith('_') && matchText.endsWith('_'))) {
        // Italic
        String content = matchText.substring(1, matchText.length - 1);
        span = TextSpan(
          text: content,
          style: TextStyle(
            color: isDarkTheme ? Colors.white : Colors.black,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        );
      } else if (matchText.startsWith('~~') && matchText.endsWith('~~')) {
        // Strikethrough
        String content = matchText.substring(2, matchText.length - 2);
        span = TextSpan(
          text: content,
          style: TextStyle(
            color: isDarkTheme ? Colors.white : Colors.black,
            fontSize: 16,
            decoration: TextDecoration.lineThrough,
          ),
        );
      } else if (matchText.startsWith('`') && matchText.endsWith('`')) {
        // Inline code
        String content = matchText.substring(1, matchText.length - 1);
        span = TextSpan(
          text: content,
          style: TextStyle(
            color: isDarkTheme ? Colors.orange : Colors.brown,
            fontSize: 16,
            fontFamily: 'monospace',
            backgroundColor:
            isDarkTheme ? Colors.grey[800] : Colors.grey[300],
          ),
        );
      } else {
        // Plain text
        span = TextSpan(
          text: matchText,
          style: TextStyle(
            color: isDarkTheme ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        );
      }

      spans.add(span);

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      // Add any remaining normal text after the last match
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: TextStyle(
          color: isDarkTheme ? Colors.white : Colors.black,
          fontSize: 16,
        ),
      ));
    }

    return spans;
  }

  // Function to show message options like copy on long press
  void _showMessageOptions(BuildContext context, Offset tapPosition,
      String messageText) async {
    final localizations = AppLocalizations.of(context)!;
    final isDarkTheme =
        Provider.of<ThemeProvider>(context, listen: false).isDarkTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    const menuWidth = 150.0;

    // Adjust the position if there's not enough space on the right
    Offset adjustedPosition = tapPosition;
    if (tapPosition.dx + menuWidth > screenWidth) {
      adjustedPosition =
          Offset(screenWidth - menuWidth - 16.0, tapPosition.dy);
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
                  color: isDarkTheme ? Colors.white : Colors.black),
              const SizedBox(width: 10),
              Text(
                localizations.copy,
                style:
                TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
              ),
            ],
          ),
        ),
      ],
      elevation: 8.0,
      color: isDarkTheme ? const Color(0xFF202020) : Colors.grey[200],
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: messageText));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onLongPressStart: (details) {
          _showMessageOptions(context, details.globalPosition, widget.text);
        },
        child: Padding(
          padding:
          const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Model's Image
              widget.imagePath.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: Image.asset(
                  widget.imagePath,
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
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
                  color:
                  widget.isDarkTheme ? Colors.white : Colors.black,
                  size: 16,
                ),
              ),
              const SizedBox(width: 16.0),
              // Message Content
              Expanded(
                child: widget.text == localizations.thinking
                    ? Shimmer.fromColors(
                  baseColor:
                  widget.isDarkTheme ? Colors.white : Colors.black,
                  highlightColor: widget.isDarkTheme
                      ? Colors.grey[400]!
                      : Colors.grey[300]!,
                  child: Text(
                    localizations.thinking,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkTheme
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                )
                    : RichText(
                  text: TextSpan(
                    children:
                    _parseText(widget.text, widget.isDarkTheme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
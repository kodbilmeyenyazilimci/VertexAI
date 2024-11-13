// menu.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts import
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';
import 'main.dart'; // To access mainScreenKey
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import localization
import 'package:provider/provider.dart'; // Import Provider
import 'theme.dart'; // Import ThemeProvider

class ConversationData {
  final String conversationID;
  String conversationTitle;
  final String modelTitle;
  final String modelImagePath;
  final String modelDescription;
  final String modelSize;
  final String modelRam;
  final String modelProducer;
  final String modelPath;
  final bool isModelAvailable; // Indicates if the model is available

  ConversationData({
    required this.conversationID,
    required this.conversationTitle,
    required this.modelTitle,
    required this.modelImagePath,
    required this.modelDescription,
    required this.modelSize,
    required this.modelRam,
    required this.modelProducer,
    required this.modelPath,
    required this.isModelAvailable,
  });
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  MenuScreenState createState() => MenuScreenState();
}

class MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<ConversationData> _conversationsData = []; // List of conversations
  final List<bool> _fadeInFlags = []; // Fade-in state for each conversation
  bool _isLoading = true; // Loading state
  bool _fadeOutLoadingAnimation = false; // Trigger for fade-out loading animation

  late final AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadConversations(); // Load conversations when the widget is created

    // Initialize fade animation
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    );

    _fadeAnimationController.forward();
  }

  // Function to load conversations from SharedPreferences
  Future<void> _loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? conversations = prefs.getStringList('conversations');
    if (conversations != null) {
      for (int i = 0; i < conversations.length; i++) {
        String conversationEntry = conversations[i];
        List<String> parts = conversationEntry.split('|');
        if (parts.length >= 9) {
          String convID = parts[0];
          String convTitle = parts[1];
          String modelTitle = parts[2];
          String modelImagePath = parts[3];
          String modelDescription = parts[4];
          String modelSize = parts[5];
          String modelRam = parts[6];
          String modelProducer = parts[7];
          String modelPath = parts[8];

          // Check if the model is available
          bool isModelAvailable = await _isModelAvailable(modelTitle);

          _conversationsData.add(ConversationData(
            conversationID: convID,
            conversationTitle: convTitle,
            modelTitle: modelTitle,
            modelImagePath: modelImagePath,
            modelDescription: modelDescription,
            modelSize: modelSize,
            modelRam: modelRam,
            modelProducer: modelProducer,
            modelPath: modelPath,
            isModelAvailable: isModelAvailable,
          ));
          _fadeInFlags.add(false); // Initially, all conversations are not faded in
          // Add each item to the animated list
          _listKey.currentState?.insertItem(i,
              duration: const Duration(milliseconds: 300));
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }
    setState(() {
      _isLoading = false;
    });
    _triggerFadeInEffect();
    _triggerFadeOutLoadingAnimation(); // Trigger fade-out of loading animation
  }

  // Function to check if a model is available
  Future<bool> _isModelAvailable(String modelTitle) async {
    // Get the list of models
    List<Map<String, dynamic>> models = ModelData.models(context);

    // Find the model by title
    Map<String, dynamic>? model = models.firstWhere(
          (model) => model['title'] == modelTitle,
      orElse: () => {},
    );

    // If model not found, consider it unavailable
    if (model == null || model.isEmpty) return false;

    // If the model is server-side, consider it available
    if (model['isServerSide'] == true) return true;

    // If the model is local, check if it's downloaded
    final prefs = await SharedPreferences.getInstance();
    final isDownloaded = prefs.getBool('is_downloaded_$modelTitle') ?? false;
    return isDownloaded;
  }

  // Function to reload conversations when notified from ChatScreen
  Future<void> reloadConversations() async {
    setState(() {
      _isLoading = true;
    });
    _conversationsData.clear();
    _fadeInFlags.clear();
    await _loadConversations();
  }

  // Function to trigger fade-in effect for all conversations
  Future<void> _triggerFadeInEffect() async {
    for (int i = 0; i < _conversationsData.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _fadeInFlags[i] = true;
        });
      }
    }
  }

  // Function to trigger fade-out effect for the loading animation
  Future<void> _triggerFadeOutLoadingAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _fadeOutLoadingAnimation = true;
      });
    }
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to delete a conversation
  Future<void> _deleteConversation(BuildContext context, int index) async {
    if (_listKey.currentState == null ||
        index < 0 ||
        index >= _conversationsData.length) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Capture data before deletion
    final ConversationData deletedConversationData = _conversationsData[index];
    final bool deletedFadeInFlag = _fadeInFlags[index];

    // Remove from SharedPreferences
    List<String> conversations = prefs.getStringList('conversations') ?? [];
    if (index < conversations.length) {
      conversations.removeAt(index);
      await prefs.setStringList('conversations', conversations); // Update SharedPreferences
    }

    // Remove associated messages
    await prefs.remove(deletedConversationData.conversationID);

    // Remove from AnimatedList with animation
    _listKey.currentState?.removeItem(
      index,
          (context, animation) => _buildConversationTile(
        deletedConversationData,
        index,
        animation,
        fadeInFlag: deletedFadeInFlag,
      ),
      duration: const Duration(milliseconds: 300),
    );

    // Remove from local lists
    _conversationsData.removeAt(index);
    _fadeInFlags.removeAt(index);

    // If the deleted conversation is currently open in ChatScreen, reset it
    if (mainScreenKey.currentState?.chatScreenKey.currentState
        ?.conversationID ==
        deletedConversationData.conversationID) {
      mainScreenKey.currentState?.chatScreenKey.currentState
          ?.resetConversation();
    }

    // Wait for the removal animation to complete
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {});
    }
  }

  // Function to edit a conversation's title
  Future<void> _editConversation(
      BuildContext context, int index, String newTitle) async {
    if (index < 0 || index >= _conversationsData.length) return;

    final prefs = await SharedPreferences.getInstance();
    _conversationsData[index].conversationTitle = newTitle; // Update local list

    List<String> conversations = prefs.getStringList('conversations') ?? [];
    if (index < conversations.length) {
      String conversationID = _conversationsData[index].conversationID;
      String modelTitle = _conversationsData[index].modelTitle;
      String modelImagePath = _conversationsData[index].modelImagePath;
      String modelDescription = _conversationsData[index].modelDescription;
      String modelSize = _conversationsData[index].modelSize;
      String modelRam = _conversationsData[index].modelRam;
      String modelProducer = _conversationsData[index].modelProducer;
      String modelPath = _conversationsData[index].modelPath;

      String newEntry =
          '$conversationID|$newTitle|$modelTitle|$modelImagePath|$modelDescription|$modelSize|$modelRam|$modelProducer|$modelPath';
      conversations[index] = newEntry; // Update the entry
      await prefs.setStringList('conversations', conversations); // Update SharedPreferences
    }

    // If the conversation is currently open in ChatScreen, update its title
    if (mainScreenKey.currentState?.chatScreenKey.currentState?.conversationID ==
        _conversationsData[index].conversationID) {
      mainScreenKey.currentState?.chatScreenKey.currentState
          ?.updateConversationTitle(newTitle);
    }

    setState(() {});

    // **Bildirim kaldırıldı**
    /*
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.conversationUpdated),
        backgroundColor: const Color(0xFF2d2f2e),
      ),
    );
    */
  }

  // Function to build a conversation tile with animations
  Widget _buildConversationTile(ConversationData conversationData, int index,
      Animation<double> animation,
      {bool fadeInFlag = true}) {
    return SizeTransition(
      sizeFactor: animation, // Control the size of the tile with animation
      child: AnimatedOpacity(
        opacity: fadeInFlag ? 1.0 : 0.0, // Control opacity for fade-in effect
        duration: const Duration(milliseconds: 200),
        child: ConversationTile(
          key: ValueKey(conversationData.conversationID),
          conversationData: conversationData,
          onDelete: () {
            if (index >= 0 && index < _conversationsData.length) {
              _deleteConversation(context, index);
            }
          },
          onEdit: (newTitle) {
            if (index >= 0 && index < _conversationsData.length) {
              _editConversation(context, index, newTitle);
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose(); // Dispose the fade animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () {
          // Hide any active SnackBar when tapping anywhere on the screen
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              localizations.conversationsTitle,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _isDarkTheme ? Colors.white : Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor:
            _isDarkTheme ? const Color(0xFF090909) : Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.add,
                    color: _isDarkTheme ? Colors.white : Colors.black),
                onPressed: () {
                  // Navigate to the ChatScreen directly
                  mainScreenKey.currentState?.onItemTapped(0);
                  // Hide any active SnackBar
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ],
          ),
          backgroundColor: _isDarkTheme ? const Color(0xFF090909) : Colors.white,
          body: _isLoading
              ? Center(
            child: AnimatedOpacity(
              opacity: _fadeOutLoadingAnimation ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child:
              const FadeTransitionWidget(), // Loading animation
            ),
          )
              : _conversationsData.isEmpty
              ? Center(
            child: Text(
              localizations.noConversationsMessage,
              style: TextStyle(
                color: _isDarkTheme ? Colors.white : Colors.black,
                fontSize: 24,
              ),
            ),
          )
              : AnimatedList(
            key: _listKey,
            initialItemCount: _conversationsData.length,
            itemBuilder: (context, index, animation) {
              if (index < 0 || index >= _conversationsData.length) {
                return const SizedBox.shrink();
              }
              return _buildConversationTile(
                  _conversationsData[index], index, animation);
            },
          ),
        ),
      ),
    );
  }
}

class FadeTransitionWidget extends StatefulWidget {
  const FadeTransitionWidget({Key? key}) : super(key: key);

  @override
  _FadeTransitionWidgetState createState() => _FadeTransitionWidgetState();
}

class _FadeTransitionWidgetState extends State<FadeTransitionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..repeat(reverse: true);

    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
    return FadeTransition(
      opacity: _animation,
      child: Image.asset(
        _isDarkTheme
            ? 'assets/vertexailogodarkwhite.png'
            : 'assets/vertexailogo.png',
        width: 100,
        height: 100,
      ),
    );
  }
}

class ConversationTile extends StatefulWidget {
  final ConversationData conversationData; // Conversation data
  final VoidCallback onDelete; // Callback to delete conversation
  final ValueChanged<String> onEdit; // Callback to edit conversation

  const ConversationTile({
    super.key,
    required this.conversationData,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile>
    with SingleTickerProviderStateMixin {
  bool _isVisible = true; // Controls the visibility of the tile

  late AnimationController _dialogAnimationController;
  late Animation<double> _dialogAnimation;

  @override
  void initState() {
    super.initState();

    // Dialog animation controller
    _dialogAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _dialogAnimation = CurvedAnimation(
      parent: _dialogAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _dialogAnimationController.dispose(); // Dispose the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
    double opacityValue = _isVisible
        ? (widget.conversationData.isModelAvailable ? 1.0 : 0.5)
        : 0.0;

    return AnimatedOpacity(
      opacity: opacityValue,
      duration: const Duration(milliseconds: 200),
      child: ListTile(
        leading: widget.conversationData.modelImagePath.isNotEmpty
            ? Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: AssetImage(widget.conversationData.modelImagePath),
              fit: BoxFit.cover,
            ),
          ),
        )
            : null,
        title: Text(
          widget.conversationData.conversationTitle,
          style: GoogleFonts.poppins(
            color: _isDarkTheme ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500, // Using Poppins font
          ),
        ),
        subtitle: Text(
          widget.conversationData.modelTitle,
          style: GoogleFonts.poppins(
            color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconButton(
                Icons.edit,
                _isDarkTheme ? Colors.white : Colors.black,
                    () => _showEditDialog(context)),
            _buildIconButton(Icons.delete, Colors.red, () {
              _deleteWithAnimation(); // Start delete animation
            }),
          ],
        ),
        onTap: widget.conversationData.isModelAvailable
            ? () {
          _navigateToChatScreen(context, widget.conversationData);
        }
            : null,
      ),
    );
  }

  void _deleteWithAnimation() {
    setState(() {
      _isVisible = false; // Fade out the tile
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        widget.onDelete(); // Perform deletion after fade out
      }
    });
  }

  void _navigateToChatScreen(
      BuildContext context, ConversationData conversationData) {
    // Navigate to ChatScreen and load the conversation
    mainScreenKey.currentState?.openConversation(conversationData);
  }

  Widget _buildIconButton(
      IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        splashColor: Colors.grey,
        highlightColor: Colors.transparent,
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final TextEditingController controller =
    TextEditingController(text: widget.conversationData.conversationTitle);

    _dialogAnimationController.forward();

    showDialog(
      context: context,
      builder: (context) {
        final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
        return FadeTransition(
          opacity: _dialogAnimation,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            backgroundColor:
            _isDarkTheme ? const Color(0xFF2D2F2E) : Colors.grey[200],
            title: Text(
              AppLocalizations.of(context)!.editConversationTitle,
              style: TextStyle(
                color: _isDarkTheme ? Colors.white : Colors.black,
              ),
            ),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.newTitle,
                labelStyle: TextStyle(
                  color: _isDarkTheme ? Colors.white : Colors.black,
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: _isDarkTheme ? Colors.white : Colors.black),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: _isDarkTheme ? Colors.white : Colors.black),
                ),
              ),
              style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black),
              cursorColor: _isDarkTheme ? Colors.white : Colors.black,
              onTap: () {
                controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: controller.text.length));
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _dialogAnimationController.reset();
                },
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: TextStyle(
                      color: _isDarkTheme ? Colors.white : Colors.black),
                ),
              ),
              TextButton(
                onPressed: () async {
                  String newText = controller.text.trim();
                  if (newText.isEmpty) {
                    return;
                  }

                  Navigator.of(context).pop();
                  _dialogAnimationController.reset();
                  widget.onEdit(newText);
                },
                child: Text(
                  AppLocalizations.of(context)!.save,
                  style: TextStyle(
                      color: _isDarkTheme ? Colors.white : Colors.black),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _dialogAnimationController.reset();
    });
  }
}
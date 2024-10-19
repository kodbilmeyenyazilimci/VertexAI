import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:shared_preferences/shared_preferences.dart';
import 'chat.dart'; // Ensure you have this import to access ChatScreen
import 'main.dart'; // Import main.dart to access mainScreenKey

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  MenuScreenState createState() => MenuScreenState();
}

class MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<String> _conversations = []; // Maintain local state of conversations
  final List<String> _conversationIDs = []; // Store conversation IDs
  final List<bool> _fadeInFlags = []; // Track fade-in state of each conversation
  bool _isLoading = true; // To track loading state
  bool _fadeOutLoadingAnimation = false; // To trigger fade-out of loading animation

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
        List<String> parts = conversationEntry.split(':');
        if (parts.length >= 2) {
          String convID = parts[0];
          String convTitle = parts.sublist(1).join(':'); // Handle titles with colons
          _conversations.add(convTitle);
          _conversationIDs.add(convID);
          _fadeInFlags.add(false); // Initially, all conversations are not faded in
          // Insert each item into the AnimatedList with a slight delay for animation
          _listKey.currentState?.insertItem(i, duration: const Duration(milliseconds: 300));
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

  // Function to reload conversations when notified from ChatScreen
  Future<void> reloadConversations() async {
    setState(() {
      _isLoading = true;
    });
    _conversations.clear();
    _conversationIDs.clear();
    _fadeInFlags.clear();
    // Removed incorrect _listKey.currentState?.setState(() {});
    await _loadConversations();
  }

  // Function to trigger fade-in effect for all conversations
  Future<void> _triggerFadeInEffect() async {
    for (int i = 0; i < _conversations.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _fadeInFlags[i] = true;
        });
      }
    }
  }

  // Function to trigger fade-out effect for loading animation
  Future<void> _triggerFadeOutLoadingAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200)); // Reduced duration
    if (mounted) {
      setState(() {
        _fadeOutLoadingAnimation = true;
      });
    }
    await Future.delayed(const Duration(milliseconds: 200)); // Reduced duration
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteConversation(BuildContext context, int index) async {
    if (_listKey.currentState == null || index < 0 || index >= _conversations.length) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Capture the data before removing
    final String deletedConversation = _conversations[index];
    final String deletedConversationID = _conversationIDs[index];
    final bool deletedFadeInFlag = _fadeInFlags[index];

    // Remove from SharedPreferences first
    List<String> conversations = prefs.getStringList('conversations') ?? [];
    if (index < conversations.length) {
      conversations.removeAt(index);
      await prefs.setStringList('conversations', conversations); // Update SharedPreferences
    }

    // Also remove messages associated with the conversation
    await prefs.remove(deletedConversationID);

    // Remove from AnimatedList first
    _listKey.currentState?.removeItem(
      index,
          (context, animation) => _buildConversationTile(
        deletedConversation,
        index,
        animation,
        fadeInFlag: deletedFadeInFlag,
      ),
      duration: const Duration(milliseconds: 300),
    );

    // Now remove from local lists
    _conversations.removeAt(index); // Remove from local list
    _conversationIDs.removeAt(index); // Remove conversation ID
    _fadeInFlags.removeAt(index); // Remove fade-in flag

    // After removing, check if the deleted conversation was open in the chat screen
    if (mainScreenKey.currentState?.chatScreenKey.currentState?.conversationID == deletedConversationID) {
      // Only reset the conversation without changing the screen
      mainScreenKey.currentState?.chatScreenKey.currentState?.resetConversation();
    }

    // Delay setState to avoid accessing an invalid index after deletion
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {});
    }

    // Show SnackBar to notify user of deletion
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sohbet silindi.'),
        backgroundColor: Color(0xFF2d2f2e), // SnackBar background color
      ),
    );
  }

  // Function to edit a conversation title
  Future<void> _editConversation(BuildContext context, int index, String newTitle) async {
    if (index < 0 || index >= _conversations.length) return;

    final prefs = await SharedPreferences.getInstance();
    _conversations[index] = newTitle; // Update local list

    List<String> conversations = prefs.getStringList('conversations') ?? [];
    if (index < conversations.length) {
      String conversationID = _conversationIDs[index];
      String newEntry = '$conversationID:$newTitle';
      conversations[index] = newEntry; // Update the entry
      await prefs.setStringList('conversations', conversations); // Update SharedPreferences
    }

    // Update the chat screen's conversationTitle if needed
    if (mainScreenKey.currentState?.chatScreenKey.currentState?.conversationID ==
        _conversationIDs[index]) {
      mainScreenKey.currentState?.chatScreenKey.currentState?.updateConversationTitle(newTitle);
    }

    setState(() {});

    // Show SnackBar to notify user of update
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sohbet güncellendi.'),
        backgroundColor: Color(0xFF2d2f2e), // SnackBar background color
      ),
    );
  }

  // Function to build a conversation tile with animation
  Widget _buildConversationTile(String conversation, int index, Animation<double> animation,
      {bool fadeInFlag = true}) {
    return SizeTransition(
      sizeFactor: animation, // Use animation to control the size of the tile
      child: AnimatedOpacity(
        opacity: fadeInFlag ? 1.0 : 0.0, // Control opacity for fade-in effect
        duration: const Duration(milliseconds: 200), // Reduced duration
        child: ConversationTile(
          key: ValueKey(conversation), // Assign a unique key
          conversation: conversation,
          conversationID: _conversationIDs.length > index ? _conversationIDs[index] : '',
          onDelete: () {
            // Ensure index is valid before attempting to delete
            if (index >= 0 && index < _conversations.length) {
              _deleteConversation(context, index);
            }
          }, // Delete conversation when delete is pressed
          onEdit: (newTitle) {
            // Ensure index is valid before attempting to edit
            if (index >= 0 && index < _conversations.length) {
              _editConversation(context, index, newTitle);
            }
          }, // Edit conversation when edit is pressed
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose(); // Dispose fade animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () {
          // Dismiss the SnackBar when tapping anywhere on the screen
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'Sohbetler',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFF141414),
            elevation: 0, // No shadow effect
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  // Start a new conversation with fade transition
                  mainScreenKey.currentState?.startNewConversation();
                },
              ),
            ],
          ),
          backgroundColor: const Color(0xFF141414),
          body: _isLoading
              ? Center(
            child: AnimatedOpacity(
              opacity: _fadeOutLoadingAnimation ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200), // Reduced duration
              child: const FadeTransitionWidget(), // Custom widget for loading animation
            ),
          )
              : _conversations.isEmpty
              ? const Center(
            child: Text(
              'Sohbet yok, sohbet et!',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          )
              : AnimatedList(
            key: _listKey,
            initialItemCount: _conversations.length,
            itemBuilder: (context, index, animation) {
              // Ensure index is valid
              if (index < 0 || index >= _conversations.length) {
                return const SizedBox.shrink();
              }
              return _buildConversationTile(_conversations[index], index, animation);
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
      duration: const Duration(milliseconds: 200), // Reduced duration
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Image.asset(
        'assets/vertexailogodarkwhite.png',
        width: 100,
        height: 100,
      ),
    );
  }
}

class ConversationTile extends StatefulWidget {
  final String conversation; // Holds the conversation title
  final String conversationID; // Holds the conversation ID
  final VoidCallback onDelete; // Callback for deleting the conversation
  final ValueChanged<String> onEdit; // Callback for editing the conversation

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.conversationID,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile>
    with SingleTickerProviderStateMixin {
  bool _isVisible = true; // Controls the visibility of the tile
  String _displayedText = ''; // Stores the text to display in the tile

  late AnimationController _dialogAnimationController;
  late Animation<double> _dialogAnimation;

  @override
  void initState() {
    super.initState();
    _displayedText = widget.conversation; // Initialize displayed text with the conversation title

    // Initialize animation controller for dialog
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
    _dialogAnimationController.dispose(); // Dispose of the dialog animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0, // Control opacity for fade in/out effect
      duration: const Duration(milliseconds: 200), // Duration of the fade animation
      child: ListTile(
        title: Text(
          _displayedText,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w400, // Use Poppins font with weight 400
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconButton(Icons.edit, Colors.white, () => _showEditDialog(context)),
            _buildIconButton(Icons.delete, Colors.red, () {
              _deleteWithAnimation(); // Start delete animation
            }),
          ],
        ),
        onTap: () {
          _navigateToChatScreen(context, widget.conversationID, widget.conversation);
        },
      ),
    );
  }

  void _deleteWithAnimation() {
    setState(() {
      _isVisible = false; // Fade out the tile
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        widget.onDelete(); // Call the delete method after fade out
      }
    });
  }

  void _navigateToChatScreen(BuildContext context, String conversationID, String conversationTitle) {
    // Switch to the ChatScreen and load the conversation
    mainScreenKey.currentState?.openConversation(conversationID, conversationTitle);
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onPressed) {
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
    final TextEditingController controller = TextEditingController(text: widget.conversation);

    _dialogAnimationController.forward();

    showDialog(
      context: context,
      builder: (context) {
        return FadeTransition(
          opacity: _dialogAnimation,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            backgroundColor: const Color(0xFF2D2F2E),
            title: const Text(
              'Sohbet Başlığını Düzenle',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Yeni Başlık',
                labelStyle: TextStyle(color: Colors.white),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              onTap: () {
                controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _dialogAnimationController.reset();
                },
                child: const Text('İptal', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () async {
                  String newText = controller.text.trim();
                  if (newText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Başlık boş olamaz.'),
                        backgroundColor: Color(0xFF2d2f2e),
                      ),
                    );
                    return;
                  }

                  Navigator.of(context).pop();
                  _dialogAnimationController.reset();
                  widget.onEdit(newText);
                },
                child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
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

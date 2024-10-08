import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'chat.dart'; // Ensure you have this import to access ChatScreen

class MenuScreen extends StatefulWidget { // Change to StatefulWidget
  const MenuScreen({super.key});

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late Future<List<String>> _conversationsFuture; // Define future
  List<String> _conversations = []; // Maintain local state of conversations

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _getConversations(); // Initialize future
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
          elevation: 0, // Shadow effect
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
              },
            ),
          ],
        ),
        backgroundColor: const Color(0xFF141414),
        body: FutureBuilder<List<String>>(
          future: _conversationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            _conversations = snapshot.data ?? [];

            if (_conversations.isEmpty) {
              return const Center(
                child: Text(
                  'sohbet yok sohbet etsene',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              );
            }

            return ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                return ConversationTile(
                  conversation: _conversations[index],
                  onDelete: () => _deleteConversation(context, _conversations[index]),
                  onEdit: (newTitle) => _editConversation(context, _conversations[index], newTitle),
                  conversationID: '',
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<String>> _getConversations() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? conversations = prefs.getStringList('conversations');
    return conversations ?? [];
  }

  Future<void> _deleteConversation(BuildContext context, String conversation) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = prefs.getStringList('conversations') ?? [];
    conversations.remove(conversation);
    await prefs.setStringList('conversations', conversations);

    // Update the local state to reflect the change immediately
    setState(() {
      _conversationsFuture = _getConversations(); // Refresh the future
    });

    // Show SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sohbet silindi.'),
        backgroundColor: Color(0xFF2d2f2e), // Beyaz arka plan rengi
      ),
    );

    // Animate the deletion of the conversation
    await Future.delayed(const Duration(milliseconds: 200)); // Delay for fade-out effect
    setState(() {
      _conversationsFuture = _getConversations(); // Refresh the future after the animation
    });
  }

  Future<void> _editConversation(BuildContext context, String oldTitle, String newTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = prefs.getStringList('conversations') ?? [];
    final index = conversations.indexOf(oldTitle);
    if (index != -1) {
      conversations[index] = newTitle; // Replace old title with new title
      await prefs.setStringList('conversations', conversations);
      setState(() {
        _conversationsFuture = _getConversations(); // Refresh the future
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sohbet güncellendi.'), // Correct message for update
          backgroundColor: Color(0xFF2d2f2e), // Background color
        ),
      );
    }
  }
}

class ConversationTile extends StatefulWidget {
  final String conversation; // Burada başlık saklanıyor.
  final String conversationID; // Burada ID saklanıyor.
  final VoidCallback onDelete;
  final ValueChanged<String> onEdit;

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

class _ConversationTileState extends State<ConversationTile> {
  bool _isVisible = true;
  String _displayedText = '';

  @override
  void initState() {
    super.initState();
    _displayedText = widget.conversation;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: ListTile(
        title: Text(
          _displayedText,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w400, // Poppins W400
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
          _navigateToChatScreen(context, widget.conversationID, widget.conversation); // Pass ID and title
        },
      ),
    );
  }

  void _deleteWithAnimation() {
    setState(() {
      _isVisible = false; // Fade out the tile
    });

    // Delay to allow the fade-out effect to finish
    Future.delayed(const Duration(milliseconds: 200), () {
      widget.onDelete(); // Call the delete method after fade out
    });
  }

  void _navigateToChatScreen(BuildContext context, String conversationID, String conversationTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationID: conversationID,
          conversationTitle: conversationTitle,
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20), // Reduce button size
        onPressed: onPressed,
        splashColor: Colors.grey, // Splash effect
        highlightColor: Colors.transparent, // Highlight color
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(text: widget.conversation);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // Round corners
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
            cursorColor: Colors.white, // Cursor color
            onTap: () {
              controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length)); // Select text
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('İptal', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  _isVisible = false; // Hide old title
                });

                String newText = controller.text;
                widget.onEdit(newText); // Save new text
                await Future.delayed(const Duration(milliseconds: 50)); // Short delay for visibility
                Navigator.of(context).pop();
                await _typeWriterEffect(newText);
              },
              child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _typeWriterEffect(String newText) async {
    setState(() {
      _displayedText = ''; // Clear previous text
      _isVisible = true; // Show new title
    });

    for (int i = 0; i <= newText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100)); // Typing speed
      setState(() {
        _displayedText = newText.substring(0, i); // Type new title
      });
    }
  }
}

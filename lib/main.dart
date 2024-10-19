import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'chat.dart';
import 'models.dart';
import 'download.dart';
import 'menu.dart';

// Export the mainScreenKey so it can be accessed from other files
export 'main.dart' show mainScreenKey;

final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

Future<void> requestStoragePermission() async {
  if (await Permission.manageExternalStorage.request().isGranted) {
    print('Genişletilmiş depolama izni verildi');
  } else {
    print('Depolama izni reddedildi');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestStoragePermission();
  final fileDownloadHelper = FileDownloadHelper();
  await fileDownloadHelper.checkAllDownloadStatuses();
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      // Use the GlobalKey when creating the MainScreen
      home: MainScreen(key: mainScreenKey),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  // Use GlobalKey to access ChatScreenState and MenuScreenState
  final GlobalKey<ChatScreenState> chatScreenKey = GlobalKey<ChatScreenState>();
  final GlobalKey<MenuScreenState> menuScreenKey = GlobalKey<MenuScreenState>();

  late final List<Widget> _screens;
  late final AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _screens = [
      ChatScreen(key: chatScreenKey),
      const ModelsScreen(),
      MenuScreen(key: menuScreenKey),
    ];

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  // Method to switch to ChatScreen and load a conversation
  void openConversation(String conversationID, String conversationTitle) {
    _animateScreenTransition(0); // Always animate transition to ChatScreen
    chatScreenKey.currentState?.loadConversation(conversationID, conversationTitle);
  }

  // Method to start a new conversation
  void startNewConversation() {
    _animateScreenTransition(0); // Always animate transition to ChatScreen
    chatScreenKey.currentState?.resetConversation();
  }

  // Make the onItemTapped method public
  void onItemTapped(int index) {
    _animateScreenTransition(index);
  }

  void _animateScreenTransition(int newIndex) {
    _animationController.reverse().then((_) {
      setState(() {
        _selectedIndex = newIndex;
      });
      _animationController.forward();
    });
  }

  Widget _buildIconButton(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isSelected ? 26 : 20,
      child: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.grey,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose(); // Dispose the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      },
      child: Scaffold(
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xFF141414),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: _buildIconButton(Icons.menu, 2),
                onPressed: () {
                  onItemTapped(2);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
              IconButton(
                icon: _buildIconButton(Icons.chat_bubble, 0),
                onPressed: () {
                  onItemTapped(0);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
              IconButton(
                icon: _buildIconButton(Icons.ac_unit, 1),
                onPressed: () {
                  onItemTapped(1);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

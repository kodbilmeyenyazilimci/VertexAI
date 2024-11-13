// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'models.dart';
import 'download.dart';
import 'menu.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'locale_provider.dart';
import 'login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart'; // ThemeProvider'ı import ettik

final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

Future<void> requestNotificationPermission() async {
  // Check the current status of notification permission
  var status = await Permission.notification.status;

  if (!status.isGranted) {
    // If not granted, request permission
    status = await Permission.notification.request();

    if (status.isGranted) {
      print('Notification permission granted');
    } else {
      print('Notification permission denied');
      // Decide what to do if the user denies permission
    }
  } else {
    print('Notification permission already granted');
  }
}

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  await requestNotificationPermission();
  await FlutterDownloader.initialize();
  final fileDownloadHelper = FileDownloadHelper();
  await fileDownloadHelper.checkAllDownloadStatuses();

  final prefs = await SharedPreferences.getInstance();
  bool? isDarkTheme = prefs.getBool('isDarkTheme');
  if (isDarkTheme == null) {
    // No preference stored, get device's brightness
    Brightness brightness = WidgetsBinding.instance.window.platformBrightness;
    isDarkTheme = brightness == Brightness.dark;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(isDarkTheme!),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
        ),
      ],
      child: const ChatApp(),
    ),
  );
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('en'), // English
        Locale('tr'), // Turkish
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        // If a locale is set in the provider, use it
        if (localeProvider.locale != null) {
          return localeProvider.locale;
        }
        // Use the device's locale if supported
        if (locale != null &&
            supportedLocales.any((supportedLocale) =>
            supportedLocale.languageCode == locale.languageCode)) {
          return locale;
        }
        return const Locale('en'); // Default to English
      },
      home: const AuthWrapper(), // Change home to AuthWrapper
    );
  }
}

/// AuthWrapper now always shows WarningScreen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const WarningScreen();
  }
}

class WarningScreen extends StatefulWidget {
  const WarningScreen({Key? key}) : super(key: key);

  @override
  _WarningScreenState createState() => _WarningScreenState();
}

class _WarningScreenState extends State<WarningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateAfterWarning();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterWarning() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    bool rememberMe = prefs.getBool('remember_me') ?? false;
    User? user = FirebaseAuth.instance.currentUser;

    if (rememberMe && user != null) {
      // If "Remember Me" is true and user is authenticated, navigate to MainScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MainScreen(key: mainScreenKey)),
      );
    } else {
      // Else, navigate to LoginScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * 0.8;

    final appLocalizations = AppLocalizations.of(context)!;
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    return Scaffold(
      backgroundColor: _isDarkTheme
          ? const Color(0xFF090909)
          : const Color(0xFFFFFFFF),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Expanded content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Warning title
                        Text(
                          appLocalizations.warningTitle,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color:
                            Theme.of(context).textTheme.titleLarge?.color,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Warning message
                        Text(
                          appLocalizations.warningMessage,
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            color: _isDarkTheme
                                ? Colors.grey[400]
                                : Colors.grey[700],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        // Email row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.email,
                                color: _isDarkTheme
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                                size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'vertexgames23@gmail.com',
                              style: TextStyle(
                                fontFamily: 'OpenSans',
                                color: _isDarkTheme
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                // "Understood" button
                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    onPressed: () {
                      _animationController.forward();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      _isDarkTheme ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      appLocalizations.understood,
                      style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isDarkTheme ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 82),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  // Use GlobalKey to access ChatScreenState and MenuScreenState
  final GlobalKey<ChatScreenState> chatScreenKey =
  GlobalKey<ChatScreenState>();
  final GlobalKey<MenuScreenState> menuScreenKey =
  GlobalKey<MenuScreenState>();

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
  void openConversation(ConversationData conversationData) {
    _animateScreenTransition(0); // Always animate transition to ChatScreen
    chatScreenKey.currentState?.loadConversation(conversationData);
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
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isSelected ? 26 : 20,
      child: Icon(
        icon,
        color: isSelected
            ? (_isDarkTheme ? Colors.white : Colors.black)
            : (_isDarkTheme ? Colors.grey : Colors.grey[600]),
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
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
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
          color: _isDarkTheme ? const Color(0xFF090909) : Colors.white,
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

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
import 'notifications.dart';
import 'theme.dart'; // ThemeProvider'ı import ettik

final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> requestNotificationPermission() async {
  // Bildirim izin durumunu kontrol et
  var status = await Permission.notification.status;

  if (!status.isGranted) {
    // İzin verilmemişse, izin iste
    status = await Permission.notification.request();

    if (status.isGranted) {
      print('Bildirim izni verildi');
    } else {
      print('Bildirim izni reddedildi');
      // Kullanıcı izni reddederse ne yapılacağına karar ver
    }
  } else {
    print('Bildirim izni zaten verildi');
  }
}

void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Firebase'i başlat
  await requestNotificationPermission();
  await FlutterDownloader.initialize();
  final fileDownloadHelper = FileDownloadHelper();
  await fileDownloadHelper.checkAllDownloadStatuses();

  final prefs = await SharedPreferences.getInstance();
  bool? isDarkTheme = prefs.getBool('isDarkTheme');
  if (isDarkTheme == null) {
    // Hiçbir tercih depolanmamışsa, cihazın parlaklık durumunu al
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
        // NotificationService burada kaldırıldı
      ],
      child: ChatApp(navigatorKey: navigatorKey), // navigatorKey'i iletin
    ),
  );
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key, required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey; // navigatorKey tanımlaması

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey, // navigatorKey'i MaterialApp'a geçir
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.black,
        hintColor: Colors.black,
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.white,
        hintColor: Colors.white,
       ),
      themeMode: themeProvider.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('en'), // İngilizce
        Locale('tr'), // Türkçe
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        // Sağlayıcıda bir locale ayarlanmışsa kullan
        return localeProvider.locale;
              // Cihazın locale'ini destekleniyorsa kullan
        if (locale != null &&
            supportedLocales.any((supportedLocale) =>
            supportedLocale.languageCode == locale.languageCode)) {
          return locale;
        }
        return const Locale('en'); // Varsayılan olarak İngilizce
      },
      builder: (context, child) {
        return Provider<NotificationService>(
          create: (_) => NotificationService(navigatorKey: navigatorKey),
          child: child!,
        );
      },
      home: const AuthWrapper(), // Home'u AuthWrapper olarak değiştir
    );
  }
}

/// AuthWrapper artık her zaman WarningScreen gösteriyor
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const WarningScreen();
  }
}

class WarningScreen extends StatefulWidget {
  const WarningScreen({super.key});

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
      // "Remember Me" true ve kullanıcı doğrulanmışsa, MainScreen'e git
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MainScreen(key: mainScreenKey)),
      );
    } else {
      // Aksi halde, LoginScreen'e git
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
    final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    return Scaffold(
      backgroundColor: isDarkTheme
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
                // Expanded içerik
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Uyarı başlığı
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
                        // Uyarı mesajı
                        Text(
                          appLocalizations.warningMessage,
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            color: isDarkTheme
                                ? Colors.grey[400]
                                : Colors.grey[700],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        // Email satırı
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.email,
                                color: isDarkTheme
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                                size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'vertexgames23@gmail.com',
                              style: TextStyle(
                                fontFamily: 'OpenSans',
                                color: isDarkTheme
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
                // "Anladım" butonu
                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    onPressed: () {
                      _animationController.forward();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      isDarkTheme ? Colors.white : Colors.black,
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
                        color: isDarkTheme ? Colors.black : Colors.white,
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

  // ChatScreenState ve MenuScreenState'e erişmek için GlobalKey kullan
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

  // ChatScreen'e geçiş yap ve bir konuşmayı yükle
  void openConversation(ConversationData conversationData) {
    _animateScreenTransition(0); // Her zaman ChatScreen'e geçiş yap
    chatScreenKey.currentState?.loadConversation(conversationData);
  }

  // Yeni bir konuşma başlat
  void startNewConversation() {
    _animateScreenTransition(0); // Her zaman ChatScreen'e geçiş yap
    chatScreenKey.currentState?.resetConversation();
  }

  // onItemTapped metodunu public yap
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
    final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isSelected ? 26 : 20,
      child: Icon(
        icon,
        color: isSelected
            ? (isDarkTheme ? Colors.white : Colors.black)
            : (isDarkTheme ? Colors.grey : Colors.grey[600]),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose(); // Animasyon kontrolcüsünü temizle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
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
          color: isDarkTheme ? const Color(0xFF090909) : Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: _buildIconButton(Icons.menu, 2),
                onPressed: _selectedIndex == 2
                    ? null // Disable if already selected
                    : () {
                  onItemTapped(2);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
              IconButton(
                icon: _buildIconButton(Icons.chat_bubble, 0),
                onPressed: _selectedIndex == 0
                    ? null // Disable if already selected
                    : () {
                  onItemTapped(0);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
              IconButton(
                icon: _buildIconButton(Icons.ac_unit, 1),
                onPressed: _selectedIndex == 1
                    ? null // Disable if already selected
                    : () {
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
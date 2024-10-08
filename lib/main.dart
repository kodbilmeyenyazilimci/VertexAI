import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'chat.dart';
import 'models.dart';
import 'download.dart';
import 'menu.dart';

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

        primaryColor: Colors.white, // Set primary color to white
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
      home: const MainScreen(), // Ana ekran
    );
  }
}


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ChatScreen(), // Chat ekranı
    const ModelsScreen(), // Ayarlar ekranı
    const MenuScreen(), // Menü ekranı
  ];

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index; // Seçili ekranı güncelle
      });
    }
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss the SnackBar when tapping anywhere on the screen
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200), // Geçiş süresi
          child: _screens[_selectedIndex], // Seçili ekran
        ),
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xFF141414),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: _buildIconButton(Icons.menu, 2),
                onPressed: () {
                  _onItemTapped(2); // Menü ekranı
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Dismiss SnackBar
                },
              ),
              IconButton(
                icon: _buildIconButton(Icons.chat_bubble, 0),
                onPressed: () {
                  _onItemTapped(0); // Chat ekranı
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Dismiss SnackBar
                },
              ),
              IconButton(
                icon: _buildIconButton(Icons.ac_unit, 1),
                onPressed: () {
                  _onItemTapped(1); // Ayarlar ekranı
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Dismiss SnackBar
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

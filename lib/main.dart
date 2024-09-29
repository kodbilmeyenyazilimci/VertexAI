import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'chat.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:system_info_plus/system_info_plus.dart';
import 'download.dart';

int _deviceMemory = -1;

Future<void> initPlatformState() async {
  int deviceMemory;
  try {
    deviceMemory = await SystemInfoPlus.physicalMemory ?? -1;
  } on PlatformException {
    deviceMemory = -1;
  }
  _deviceMemory = deviceMemory;
}

// Depolama iznini isteyen fonksiyon
Future<void> requestStoragePermission() async {
  if (await Permission.manageExternalStorage.request().isGranted) {
    print('Genişletilmiş depolama izni verildi');
  } else {
    print('Depolama izni reddedildi');
    // İzin reddedildiğinde kullanıcıya bir uyarı gösterilebilir.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await requestStoragePermission();

  await initPlatformState();

  final fileDownloadHelper = FileDownloadHelper();
  await fileDownloadHelper.checkAllDownloadStatuses();

  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: const OutlineInputBorder(),
        ),
      ),
      home: const ChatScreen(),
    );
  }

}

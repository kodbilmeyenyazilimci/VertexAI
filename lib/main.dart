import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'chat.dart';
import 'dart:async';
import 'download.dart';

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

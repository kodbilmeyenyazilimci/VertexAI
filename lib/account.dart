import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: const Color(0xFF141414),
      ),
      body: const Center(
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:system_info_plus/system_info_plus.dart';

class SystemInfoProvider {
  static Future<SystemInfoData> fetchSystemInfo() async {
    final int deviceMemory = await SystemInfoPlus.physicalMemory ?? -1;
    final int freeStorage = await _getFreeStorage();
    final int totalStorage = await _getTotalStorage();

    return SystemInfoData(
      deviceMemory: deviceMemory,
      freeStorage: freeStorage,
      totalStorage: totalStorage,
    );
  }

  static Future<int> _getFreeStorage() async {
    try {
      final int result = await _platform.invokeMethod('getFreeStorage');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get free storage: '${e.message}'.");
      return -1;
    }
  }

  static Future<int> _getTotalStorage() async {
    try {
      final int result = await _platform.invokeMethod('getTotalStorage');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get total storage: '${e.message}'.");
      return -1;
    }
  }

  static const MethodChannel _platform = MethodChannel('com.vertex.ai/storage');
}

class SystemInfoData {
  final int deviceMemory;
  final int freeStorage;
  final int totalStorage;

  SystemInfoData({
    required this.deviceMemory,
    required this.freeStorage,
    required this.totalStorage,
  });

  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device Memory: $deviceMemory MB',
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          'Free Storage: $freeStorage MB',
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          'Total Storage: $totalStorage MB',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
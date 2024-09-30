import 'package:flutter/services.dart';

class SystemInfoProvider {
  static Future<SystemInfoData> fetchSystemInfo() async {
    final int deviceMemory = await _getDeviceMemory();
    final int freeStorage = await _getFreeStorage();
    final int totalStorage = await _getTotalStorage();

    return SystemInfoData(
      deviceMemory: deviceMemory,
      freeStorage: freeStorage,
      totalStorage: totalStorage,
    );
  }

  static Future<int> _getDeviceMemory() async {
    try {
      final int result = await _memoryChannel.invokeMethod('getDeviceMemory'); // Doğrudan int döndürüyoruz
      return result; // Hatanın kaynağı burasıydı
    } on PlatformException catch (e) {
      print("Failed to get device memory: '${e.message}'");
      return -1;
    }
  }


  static Future<int> _getFreeStorage() async {
    try {
      final int result = await _storageChannel.invokeMethod('getFreeStorage');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get free storage: '${e.message}'");
      return -1;
    }
  }

  static Future<int> _getTotalStorage() async {
    try {
      final int result = await _storageChannel.invokeMethod('getTotalStorage');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get total storage: '${e.message}'");
      return -1;
    }
  }

  static const MethodChannel _storageChannel = MethodChannel('com.vertex.ai/storage');
  static const MethodChannel _memoryChannel = MethodChannel('com.vertex.ai/memory');
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
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileDownloadHelper extends ChangeNotifier {
  String _status = 'İndirilemedi';
  String get status => _status;

  Future<void> downloadModel({
    required String url,
    required String title,
    required Function(String, double) onProgress,
    required Function(String) onDownloadCompleted,
    required Function(String) onDownloadError,
  }) async {
    final permissionStatus = await Permission.manageExternalStorage.request();

    if (permissionStatus.isGranted) {
      final filename = '${title.replaceAll(' ', '').replaceAll('/', '')}.gguf';
      try {
        final downloadsDir = await getExternalStorageDirectory();

        _status = 'İndiriliyor';
        notifyListeners();

        FileDownloader.downloadFile(
          url: url,
          name: filename,
          subPath: downloadsDir?.path,
          onProgress: (String? fileName, num progress) {
            onProgress(fileName ?? '', progress.toDouble());
          },
          onDownloadCompleted: (String path) async {
            _status = 'İndirildi';
            notifyListeners();

            // İndirme durumunu SharedPreferences ile kaydet
            final prefs = await SharedPreferences.getInstance();
            prefs.setString('file_status_$filename', 'İndirildi');
            prefs.setString('file_path_$filename', path);

            onDownloadCompleted(path);
          },
          onDownloadError: (String error) {
            _status = 'İndirilemedi';
            notifyListeners();
            onDownloadError(error);
          },
        );
      } catch (e) {
        _status = 'İndirilemedi';
        notifyListeners();
        onDownloadError('An error occurred: $e');
      }
    } else {
      _status = 'İndirilemedi';
      notifyListeners();
      onDownloadError('Storage permission denied');
    }
  }

  // İndirme durumu kontrolü
  Future<void> checkDownloadStatus(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    _status = prefs.getString('file_status_$filename') ?? 'İndirilemedi';
    notifyListeners();
  }

  // Bütün indirme durumlarını kontrol et
  Future<void> checkAllDownloadStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final files = prefs.getKeys().where((key) => key.startsWith('file_status_')).toList();

    for (String fileKey in files) {
      final filename = fileKey.replaceFirst('file_status_', '');
      final fileStatus = prefs.getString(fileKey) ?? 'İndirilemedi';

      // Dosya mevcut mu kontrol et
      final downloadsDir = await getExternalStorageDirectory();
      final filePath = '${downloadsDir?.path}/$filename';
      final fileExists = await File(filePath).exists();

      if (!fileExists) {
        _status = 'İndirilemedi';
        prefs.setString(fileKey, 'İndirilemedi');
      } else {
        _status = fileStatus;
      }
    }
    notifyListeners();
  }

  // Dosya silme ve durumu sıfırlama
  Future<void> deleteFile(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('file_status_$filename');
    _status = 'İndirilemedi';
    notifyListeners();
  }
}
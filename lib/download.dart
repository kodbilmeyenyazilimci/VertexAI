import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileDownloadHelper extends ChangeNotifier {
  String _status = 'İndirilemedi';
  String get status => _status;

  final ReceivePort _port = ReceivePort();

  // Map to keep track of download tasks and their associated callbacks
  final Map<String, _DownloadTaskInfo> _tasks = {};

  FileDownloadHelper() {
    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(_downloadCallback);
  }

  void _bindBackgroundIsolate() {
    final isSuccess = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    if (!isSuccess) {
      IsolateNameServer.removePortNameMapping('downloader_send_port');
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) async {
      final String id = data[0];
      final int statusInt = data[1];
      final int progress = data[2];

      final DownloadTaskStatus status = DownloadTaskStatus.values[statusInt];

      _status = _statusFromDownloadStatus(status);
      notifyListeners();

      final taskInfo = _tasks[id];
      if (taskInfo != null) {
        if (status == DownloadTaskStatus.running) {
          // Update progress
          taskInfo.onProgress(taskInfo.title, progress.toDouble());
        } else if (status == DownloadTaskStatus.complete) {
          // Download completed
          taskInfo.onDownloadCompleted(taskInfo.filePath);
          _tasks.remove(id);
        } else if (status == DownloadTaskStatus.failed) {
          // Download failed
          taskInfo.onDownloadError('Download failed');
          _tasks.remove(id);
        } else if (status == DownloadTaskStatus.paused) {
          // Download paused
          taskInfo.onDownloadPaused();
        }
      }
    });
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }

  static void _downloadCallback(String id, int status, int progress) {
    final SendPort? send =
    IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  String _statusFromDownloadStatus(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.undefined:
        return 'Tanımsız';
      case DownloadTaskStatus.enqueued:
        return 'Sıraya Alındı';
      case DownloadTaskStatus.running:
        return 'İndiriliyor';
      case DownloadTaskStatus.paused:
        return 'Durduruldu';
      case DownloadTaskStatus.complete:
        return 'İndirildi';
      case DownloadTaskStatus.canceled:
        return 'İptal Edildi';
      case DownloadTaskStatus.failed:
        return 'İndirilemedi';
      default:
        return 'Bilinmiyor';
    }
  }

  Future<String?> downloadModel({
    required String url,
    required String filePath,
    required String title,
    required Function(String, double) onProgress,
    required Function(String) onDownloadCompleted,
    required Function(String) onDownloadError,
    required Function() onDownloadPaused,
  }) async {
    try {
      _status = 'İndiriliyor';
      notifyListeners();

      final file = File(filePath);
      final savedDir = file.parent.path;
      final fileName = file.uri.pathSegments.last;

      // Ensure the directory exists
      final savedDirPath = Directory(savedDir);
      if (!savedDirPath.existsSync()) {
        savedDirPath.createSync(recursive: true);
      }

      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: savedDir,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: false,
      );

      if (taskId != null) {
        // Store task info
        _tasks[taskId] = _DownloadTaskInfo(
          taskId: taskId,
          title: title,
          filePath: filePath,
          onProgress: onProgress,
          onDownloadCompleted: onDownloadCompleted,
          onDownloadError: onDownloadError,
          onDownloadPaused: onDownloadPaused,
        );
      } else {
        // Eğer taskId null dönerse, indirme işlemi başlatılamamıştır.
        onDownloadError('Download could not be started.');
      }

      return taskId;
    } catch (e) {
      _status = 'İndirilemedi';
      notifyListeners();
      onDownloadError('An error occurred: $e');
      return null;
    }
  }

  Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }

  Future<String?> resumeDownload(String taskId) async {
    final newTaskId = await FlutterDownloader.resume(taskId: taskId);
    if (newTaskId != null) {
      // Update the taskId in _tasks
      final taskInfo = _tasks.remove(taskId);
      if (taskInfo != null) {
        _tasks[newTaskId] = _DownloadTaskInfo(
          taskId: newTaskId,
          title: taskInfo.title,
          filePath: taskInfo.filePath,
          onProgress: taskInfo.onProgress,
          onDownloadCompleted: taskInfo.onDownloadCompleted,
          onDownloadError: taskInfo.onDownloadError,
          onDownloadPaused: taskInfo.onDownloadPaused,
        );
      }
      return newTaskId;
    }
    return null;
  }

  // Check the download status of a specific file
  Future<void> checkDownloadStatus(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    _status = prefs.getString('file_status_$filename') ?? 'İndirilemedi';
    notifyListeners();
  }

  // Check the download statuses of all files
  Future<void> checkAllDownloadStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final files = prefs
        .getKeys()
        .where((key) => key.startsWith('file_status_'))
        .toList();

    for (String fileKey in files) {
      final filename = fileKey.replaceFirst('file_status_', '');
      final fileStatus = prefs.getString(fileKey) ?? 'İndirilemedi';

      final downloadsDir = await getApplicationDocumentsDirectory();
      final filePath = '${downloadsDir.path}/$filename';
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

  // Delete a file and reset its status
  Future<void> deleteFile(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadsDir = await getApplicationDocumentsDirectory();
    final filePath = '${downloadsDir.path}/$filename';

    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }

    prefs.remove('file_status_$filename');
    _status = 'İndirilemedi';
    notifyListeners();
  }
}

// Helper class to store download task information
class _DownloadTaskInfo {
  final String taskId;
  final String title;
  final String filePath;
  final Function(String, double) onProgress;
  final Function(String) onDownloadCompleted;
  final Function(String) onDownloadError;
  final Function() onDownloadPaused;

  _DownloadTaskInfo({
    required this.taskId,
    required this.title,
    required this.filePath,
    required this.onProgress,
    required this.onDownloadCompleted,
    required this.onDownloadError,
    required this.onDownloadPaused,
  });
}

// models.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'model.dart';
import 'theme.dart';
import 'data.dart';
import 'download.dart';
import 'main.dart';
import 'system_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

enum CompatibilityStatus {
  compatible,
  insufficientRAM,
  insufficientStorage,
}

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  _ModelsScreenState createState() => _ModelsScreenState();
}

class DownloadedModelsManager {
  static final DownloadedModelsManager _instance =
  DownloadedModelsManager._internal();
  factory DownloadedModelsManager() => _instance;
  DownloadedModelsManager._internal();

  List<DownloadedModel> downloadedModels = [];
}

class DownloadedModel {
  final String name;
  final String image;

  DownloadedModel({required this.name, required this.image});
}

class _ModelsScreenState extends State<ModelsScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Map<String, bool> _downloadStates;
  late Map<String, bool> _isDownloading;
  late Map<String, bool> _isPaused;
  late Map<String, String> _downloadTaskIds;
  SystemInfoData? _systemInfo;
  String? _selectedModelTitle;
  final downloadedModelsManager = DownloadedModelsManager();

  late List<Map<String, dynamic>> _models;
  List<Map<String, dynamic>> _myModels = [];

  late String _filesDirectoryPath;

  @override
  void initState() {
    super.initState();

    _downloadStates = {};
    _isDownloading = {};
    _isPaused = {};
    _downloadTaskIds = {};

    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _initializeDirectory().then((_) {
      _loadSystemInfo();
      _loadSelectedModel();
      _initializeDownloadedModels();
      _checkDownloadStates();
      _checkDownloadingStates();

      for (var model in _models) {
        if (!(model['isServerSide'] ?? false)) {
          _checkFileExists(model['title']);
        }
      }

      _initializeMyModels();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final localizations = AppLocalizations.of(context)!;

    _models = ModelData.models(context);

    for (var model in _models) {
      if (!(model['isServerSide'] ?? false)) {
        _downloadStates[model['title']] = false;
        _isDownloading[model['title']] = false;
        _isPaused[model['title']] = false;
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _initializeDirectory() async {
    // Use the application's documents directory
    Directory appDocDir = await getApplicationDocumentsDirectory();
    _filesDirectoryPath = appDocDir.path;
    print("Files will be stored in: $_filesDirectoryPath");
  }

  Future<void> _initializeMyModels() async {
    Directory dir = Directory(_filesDirectoryPath);
    List<FileSystemEntity> files = await dir.list().toList();
    List<File> ggufFiles = files
        .whereType<File>()
        .where((file) => file.path.endsWith('.gguf'))
        .toList();

    List<String> predefinedModelPaths =
    _models.map((model) => _getFilePath(model['title'])).toList();

    setState(() {
      _myModels = ggufFiles
          .where((file) => !predefinedModelPaths.contains(file.path))
          .map((file) {
        String fileName = path.basename(file.path);
        return {
          'title': path.basenameWithoutExtension(fileName),
          'description': AppLocalizations.of(context)!.myModelDescription,
          'size': '', // Calculate file size if necessary
          'image': 'assets/customai.png',
          'path': file.path,
        };
      }).toList();
    });
  }

  Future<void> _loadSystemInfo() async {
    try {
      final systemInfo = await SystemInfoProvider.fetchSystemInfo();
      if (mounted) {
        setState(() {
          _systemInfo = systemInfo;
        });
      }
    } catch (e) {
      print('Error fetching system info: $e');
    }
  }

  Future<void> _loadSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    String? selectedModelTitle = prefs.getString('selected_model_title');
    String? selectedModelPath = prefs.getString('selected_model_path');

    if (selectedModelTitle != null && selectedModelPath != null) {
      if (mounted) {
        setState(() {
          _selectedModelTitle = selectedModelTitle;
        });
      }
    }
  }

  void _initializeDownloadedModels() {
    downloadedModelsManager.downloadedModels.clear();
    for (var model in _models) {
      String title = model['title'];
      if ((_downloadStates[title] == true) ||
          (model['isServerSide'] ?? false)) {
        downloadedModelsManager.downloadedModels.add(DownloadedModel(
          name: title,
          image: model['image'],
        ));
      }
    }
  }

  CompatibilityStatus _getCompatibilityStatus(String title, String size) {
    if (_systemInfo == null) {
      return CompatibilityStatus.insufficientRAM;
    }

    final int requiredSizeMB = _parseSizeToMB(size);
    final int ramGB = (_systemInfo!.deviceMemory / 1024).floor();
    final bool isRAMSufficient;
    final bool isStorageSufficient =
        (_systemInfo!.freeStorage / 1024) >= (requiredSizeMB / 1024);

    if (ramGB <= 3) {
      isRAMSufficient = title == 'TinyLlama';
    } else if (ramGB <= 4) {
      isRAMSufficient =
          title == 'TinyLlama' || title == 'Phi-2-Instruct-v1';
    } else if (ramGB < 8) {
      isRAMSufficient = title == 'TinyLlama' ||
          title == 'Phi-2-Instruct-v1' ||
          title == 'Mistral-7B-Turkish' ||
          title == 'Gemma';
    } else {
      isRAMSufficient = true;
    }

    if (!isRAMSufficient) return CompatibilityStatus.insufficientRAM;
    if (!isStorageSufficient) return CompatibilityStatus.insufficientStorage;
    return CompatibilityStatus.compatible;
  }

  int _parseSizeToMB(String size) {
    final sizeParts = size.split(' ');
    if (sizeParts.length < 2) return 0;
    final sizeValue =
        double.tryParse(sizeParts[0].replaceAll(',', '')) ?? 0.0;
    final unit = sizeParts[1].toUpperCase();

    switch (unit) {
      case 'GB':
        return (sizeValue * 1024).toInt();
      case 'MB':
        return sizeValue.toInt();
      default:
        return 0;
    }
  }

  String _getFilePath(String title) {
    String sanitizedTitle =
    title.replaceAll(' ', '_'); // Replace spaces with underscores
    return path.join(_filesDirectoryPath, '$sanitizedTitle.gguf');
  }

  Widget _buildModelTile(
      String title,
      String description,
      String? url,
      String? size,
      String imagePath,
      String? requirements,
      String producer,
      bool isServerSide,
      bool isDarkTheme, {
        bool isCustomModel = false,
        String? modelPath,
      }) {
    final isDownloaded =
    isCustomModel ? true : (_downloadStates[title] ?? false);
    final isDownloading = _isDownloading[title] ?? false;
    final isPaused = _isPaused[title] ?? false;
    final compatibilityStatus = isServerSide
        ? CompatibilityStatus.compatible
        : isCustomModel
        ? CompatibilityStatus.compatible
        : _getCompatibilityStatus(title, size!);

    return GestureDetector(
      onTap: () => _openModelDetail(
        title,
        description,
        imagePath,
        size ?? '',
        requirements ?? '',
        producer,
        isServerSide,
        isDownloaded,
        isDownloading,
        compatibilityStatus,
        url,
        isCustomModel: isCustomModel,
        modelPath: modelPath,
      ),
      child: AnimatedBuilder(
        animation: _rotationController,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(seconds: 1),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey[900] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isServerSide || isDownloaded
                          ? isDarkTheme
                          ? Colors.white
                          : Colors.black
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: isDarkTheme
                                  ? Colors.black54
                                  : Colors.grey[300],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: isDarkTheme
                                          ? Colors.white
                                          : Colors.black,
                                      size: 40,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: isDarkTheme
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDarkTheme
                                        ? Colors.white.withOpacity(0.85)
                                        : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isServerSide)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () =>
                                _startChatWithModel(title, isServerSide),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              isDarkTheme ? Colors.blueAccent : Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                            ),
                            child: FittedBox(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.of(context)!.chat,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (isCustomModel)
                        SizedBox(
                          width: double.infinity,
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _removeModel(title,
                                      isCustomModel: true, modelPath: modelPath),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    Colors.redAccent, // Red background
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  child: FittedBox(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppLocalizations.of(context)!.remove,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _startChatWithModel(
                                      title, isServerSide,
                                      isCustomModel: true,
                                      modelPath: modelPath),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDarkTheme
                                        ? Colors.blueAccent
                                        : Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 8),
                                  ),
                                  child: FittedBox(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppLocalizations.of(context)!.chat,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isDownloading)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _cancelDownload(title),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 8),
                              ),
                              child: FittedBox(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cancel,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(context)!
                                          .cancelDownload,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (isPaused)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _resumeDownload(title),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDarkTheme
                                      ? Colors.blueAccent
                                      : Colors.blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 8),
                                ),
                                child: FittedBox(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppLocalizations.of(context)!.resume,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else if (!isDownloaded)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: compatibilityStatus !=
                                      CompatibilityStatus.compatible
                                      ? null
                                      : () => _downloadModel(url, title),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: compatibilityStatus !=
                                        CompatibilityStatus.compatible
                                        ? Colors.grey
                                        : isDarkTheme
                                        ? Colors.white
                                        : Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 8),
                                  ),
                                  child: FittedBox(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.download,
                                          color: compatibilityStatus !=
                                              CompatibilityStatus.compatible
                                              ? Colors.white
                                              : isDarkTheme
                                              ? Colors.black
                                              : Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          compatibilityStatus ==
                                              CompatibilityStatus
                                                  .insufficientRAM
                                              ? AppLocalizations.of(context)!
                                              .insufficientRAM
                                              : compatibilityStatus ==
                                              CompatibilityStatus
                                                  .insufficientStorage
                                              ? AppLocalizations.of(context)!
                                              .insufficientStorage
                                              : AppLocalizations.of(context)!
                                              .download,
                                          style: TextStyle(
                                            color: compatibilityStatus !=
                                                CompatibilityStatus.compatible
                                                ? Colors.white
                                                : isDarkTheme
                                                ? Colors.black
                                                : Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _removeModel(title),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          Colors.redAccent, // Red background
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                        child: FittedBox(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                AppLocalizations.of(context)!.remove,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _startChatWithModel(
                                            title, isServerSide),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDarkTheme
                                              ? Colors.blueAccent
                                              : Colors.blue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 8),
                                        ),
                                        child: FittedBox(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.chat_bubble_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                AppLocalizations.of(context)!.chat,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ],
                  ),
                ),
                if (isDownloading)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: BorderPainter(
                          progress: _rotationController.value * 360,
                          borderRadius: 12,
                          isDarkTheme: isDarkTheme,
                        ),
                      ),
                    ),
                  ),
                if ((isDownloaded && !isServerSide) || isServerSide)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDarkTheme ? Colors.white : Colors.black,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkTheme) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDarkTheme ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              height: 1,
              width: 250,
              color: isDarkTheme ? Colors.white : Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  void _startChatWithModel(String title, bool isServerSide,
      {bool isCustomModel = false, String? modelPath}) async {
    await _selectModel(title, isServerSide,
        isCustomModel: isCustomModel, modelPath: modelPath);

    final modelData = isCustomModel
        ? _myModels.firstWhere((model) => model['title'] == title)
        : _models.firstWhere((model) => model['title'] == title);

    mainScreenKey.currentState?.chatScreenKey.currentState?.updateModelData(
      title: modelData['title'],
      description: modelData['description'],
      imagePath: modelData['image'],
      size: modelData['size'],
      ram: modelData['ram'] ?? '',
      producer: modelData['producer'] ?? '',
      path: isServerSide ? null : (isCustomModel ? modelPath : _getFilePath(title)),
      isServerSide: isServerSide,
    );

    mainScreenKey.currentState?.onItemTapped(0);

    mainScreenKey.currentState?.chatScreenKey.currentState?.resetConversation();
  }

  void _openModelDetail(
      String title,
      String description,
      String imagePath,
      String size,
      String ram,
      String producer,
      bool isServerSide,
      bool isDownloaded,
      bool isDownloading,
      CompatibilityStatus compatibilityStatus,
      String? url, {
        bool isCustomModel = false,
        String? modelPath,
      }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModelDetailPage(
          title: title,
          description: description,
          imagePath: imagePath,
          size: size,
          ram: ram,
          producer: producer,
          isDownloaded: isDownloaded,
          isDownloading: isDownloading,
          compatibilityStatus: compatibilityStatus,
          isServerSide: isServerSide,
          onDownloadPressed: () {
            _downloadModel(url, title);
          },
          onRemovePressed: () async {
            await _removeModel(title, isCustomModel: isCustomModel, modelPath: modelPath);
          },
          onChatPressed: () {
            _startChatWithModel(title, isServerSide, isCustomModel: isCustomModel, modelPath: modelPath);
          },
        ),
      ),
    );
  }


  void _downloadModel(String? url, String title) async {
    if (url == null) return;

    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is_downloading_$title', true);

    if (mounted) {
      setState(() {
        _isDownloading[title] = true;
        _isPaused[title] = false;
      });
    }

    final filePath = _getFilePath(title);

    String? taskId = await FileDownloadHelper().downloadModel(
      url: url,
      filePath: filePath,
      title: title,
      onProgress: (fileName, progress) {
        // Handle progress updates here if needed
      },
      onDownloadCompleted: (path) async {
        print("Download completed, file path: $path");

        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('is_downloading_$title', false);
        prefs.setBool('is_downloaded_$title', true);
        prefs.remove('download_task_id_$title');

        if (mounted) {
          setState(() {
            _isDownloading[title] = false;
            _downloadStates[title] = true;
            _isPaused[title] = false;
          });
          _initializeDownloadedModels();
        }

        mainScreenKey.currentState
            ?.chatScreenKey.currentState
            ?.reloadModels();
      },
      onDownloadError: (error) async {
        print("Download error: $error");

        if (mounted) {
          setState(() {
            _isDownloading[title] = false;
            _isPaused[title] = false;
          });
          final prefs = await SharedPreferences.getInstance();
          prefs.setBool('is_downloading_$title', false);
        }

        // Removed notification
      },
      onDownloadPaused: () {
        if (mounted) {
          setState(() {
            _isDownloading[title] = false;
            _isPaused[title] = true;
          });
        }
      },
    );

    if (taskId != null) {
      _downloadTaskIds[title] = taskId;
      prefs.setString('download_task_id_$title', taskId);
    }
  }

  Future<void> _checkFileExists(String title) async {
    final filePath = _getFilePath(title);

    final file = File(filePath);
    final bool fileExists = await file.exists();

    if (fileExists) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('is_downloaded_$title', true);

      if (mounted) {
        setState(() {
          _downloadStates[title] = true;

          if (!downloadedModelsManager.downloadedModels
              .any((model) => model.name == title)) {
            var modelData =
            _models.firstWhere((model) => model['title'] == title);
            downloadedModelsManager.downloadedModels.add(DownloadedModel(
              name: title,
              image: modelData['image'],
            ));
          }
        });
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('is_downloading_$title', false);
      prefs.setBool('is_downloaded_$title', false);
      if (mounted) {
        setState(() {
          _downloadStates[title] = false;

          downloadedModelsManager.downloadedModels
              .removeWhere((model) => model.name == title);
        });
      }
    }
  }

  void _checkDownloadStates() async {
    final prefs = await SharedPreferences.getInstance();

    for (var model in _models) {
      String title = model['title'];
      bool isServerSide = model['isServerSide'] ?? false;

      if (!isServerSide) {
        final isDownloaded = prefs.getBool('is_downloaded_$title') ?? false;
        if (mounted) {
          setState(() {
            _downloadStates[title] = isDownloaded;
          });
        }

        await _checkFileExists(title);
      }
    }

    if (mounted) {
      setState(() {
        _initializeDownloadedModels();
      });
    }
  }

  void _checkDownloadingStates() async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = await FlutterDownloader.loadTasks();

    for (var model in _models) {
      String title = model['title'];
      bool isServerSide = model['isServerSide'] ?? false;

      if (isServerSide) continue;

      String? taskId = prefs.getString('download_task_id_$title');
      if (taskId != null && tasks != null) {
        DownloadTask? task;
        for (var t in tasks) {
          if (t.taskId == taskId) {
            task = t;
            break;
          }
        }

        if (task != null) {
          if (task.status == DownloadTaskStatus.running ||
              task.status == DownloadTaskStatus.enqueued) {
            setState(() {
              _isDownloading[title] = true;
              _isPaused[title] = false;
              _downloadTaskIds[title] = taskId;
            });
          } else if (task.status == DownloadTaskStatus.paused) {
            setState(() {
              _isDownloading[title] = false;
              _isPaused[title] = true;
              _downloadTaskIds[title] = taskId;
            });
          } else if (task.status == DownloadTaskStatus.failed) {
            setState(() {
              _isDownloading[title] = false;
              _isPaused[title] = false;
            });
            prefs.setBool('is_downloading_$title', false);
            prefs.remove('download_task_id_$title');
          } else {
            setState(() {
              _isDownloading[title] = false;
              _isPaused[title] = false;
            });
          }
        } else {
          setState(() {
            _isDownloading[title] = false;
            _isPaused[title] = false;
          });
        }
      } else {
        setState(() {
          _isDownloading[title] = false;
          _isPaused[title] = false;
        });
      }
    }
  }

  Future<void> _removeModel(String title,
      {bool isCustomModel = false, String? modelPath}) async {
    final prefs = await SharedPreferences.getInstance();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.removeModel,
            style:
            TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
          ),
          content: Text(
            AppLocalizations.of(context)!.confirmRemoveModel(title),
            style:
            TextStyle(color: isDarkTheme ? Colors.white : Colors.black),
          ),
          backgroundColor:
          isDarkTheme ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(
                    color: isDarkTheme ? Colors.white : Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                AppLocalizations.of(context)!.remove,
                style: TextStyle(
                    color: isDarkTheme ? Colors.white : Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final filePath = isCustomModel ? modelPath! : _getFilePath(title);
    final file = File(filePath);

    if (await file.exists()) {
      try {
        await file.delete();
        print("File deleted: $filePath");

        if (!isCustomModel) {
          await prefs.setBool('is_downloaded_$title', false);

          if (_selectedModelTitle == title) {
            await prefs.remove('selected_model_path');
            await prefs.remove('selected_model_title');
            setState(() {
              _selectedModelTitle = null;
            });
            mainScreenKey.currentState
                ?.chatScreenKey.currentState
                ?.loadModel();
          }

          if (mounted) {
            setState(() {
              _downloadStates[title] = false;
              downloadedModelsManager.downloadedModels
                  .removeWhere((model) => model.name == title);
            });
          }

          mainScreenKey.currentState
              ?.chatScreenKey.currentState
              ?.reloadModels();
        } else {
          setState(() {
            _myModels.removeWhere((model) => model['title'] == title);
          });
        }

        // Removed notification
      } catch (e) {
        print("File deletion error: $e");
        // Removed notification
      }
    } else {
      print("File not found: $filePath");

      if (!isCustomModel) {
        await prefs.setBool('is_downloaded_$title', false);

        if (mounted) {
          setState(() {
            _downloadStates[title] = false;
            downloadedModelsManager.downloadedModels
                .removeWhere((model) => model.name == title);
          });
        }
      } else {
        setState(() {
          _myModels.removeWhere((model) => model['title'] == title);
        });
      }

      // Removed notification
    }
  }

  Future<void> _selectModel(String title, bool isServerSide,
      {bool isCustomModel = false, String? modelPath}) async {
    final prefs = await SharedPreferences.getInstance();
    String? filePath =
    isServerSide ? null : (isCustomModel ? modelPath : _getFilePath(title));

    if (!isServerSide && filePath == null) {
      filePath = _getFilePath(title);
    }

    await prefs.setString('selected_model_title', title);
    if (filePath != null) {
      await prefs.setString('selected_model_path', filePath);
    } else {
      await prefs.remove('selected_model_path');
    }

    setState(() {
      _selectedModelTitle = title;
    });

    mainScreenKey.currentState?.chatScreenKey.currentState?.updateModelData(
      title: title,
      description: isCustomModel
          ? AppLocalizations.of(context)!.myModelDescription
          : _models.firstWhere((model) => model['title'] == title)['description'],
      imagePath: isCustomModel
          ? 'assets/customai.png'
          : _models.firstWhere((model) => model['title'] == title)['image'],
      size: isCustomModel
          ? ''
          : _models.firstWhere((model) => model['title'] == title)['size'],
      ram: isCustomModel
          ? ''
          : _models.firstWhere((model) => model['title'] == title)['ram'],
      producer: isCustomModel
          ? ''
          : _models.firstWhere((model) => model['title'] == title)['producer'],
      path: filePath,
      isServerSide: isServerSide,
    );
  }

  void _cancelDownload(String title) async {
    final prefs = await SharedPreferences.getInstance();

    String? taskId = _downloadTaskIds[title];
    if (taskId != null) {
      await FileDownloadHelper().cancelDownload(taskId);
      _downloadTaskIds.remove(title);
      prefs.remove('download_task_id_$title');
    }

    prefs.setBool('is_downloading_$title', false);

    if (mounted) {
      setState(() {
        _isDownloading[title] = false;
        _isPaused[title] = false;
      });
    }

    // Removed notification
  }

  void _resumeDownload(String title) async {
    String? taskId = _downloadTaskIds[title];
    if (taskId != null) {
      String? newTaskId = await FileDownloadHelper().resumeDownload(taskId);
      if (newTaskId != null) {
        _downloadTaskIds[title] = newTaskId;
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('download_task_id_$title', newTaskId);
        setState(() {
          _isPaused[title] = false;
          _isDownloading[title] = true;
        });

        // Removed notification
      }
    }
  }

  void _showUploadModelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
        return AlertDialog(
          title: Center(
            child: Text(
              AppLocalizations.of(context)!.uploadYourOwnModel,
              style: TextStyle(
                fontWeight: FontWeight.bold, // Daha kalın başlık
                color: isDarkTheme ? Colors.white : Colors.black,
                fontSize: 18,
              ),
            ),
          ),
          content: GestureDetector(
            onTap: _pickModelFile,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: isDarkTheme ? Colors.grey[800] : Colors.grey[200],
                border: Border.all(
                  color: Colors.white, // İnce beyaz çerçeve
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(6), // Köşeleri biraz daha sivriltme
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 50,
                    color: isDarkTheme ? Colors.white : Colors.blue,
                  ),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.selectGGUFFile,
                    style: TextStyle(
                      color: isDarkTheme ? Colors.white70 : Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          backgroundColor: isDarkTheme ? Color(0xFF0121212): Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.white, width: 1), // İnce beyaz çizgi
            borderRadius: BorderRadius.circular(12.0), // Köşeleri biraz daha sivriltme
          ),
          actionsAlignment: MainAxisAlignment.center, // Butonu ortaya hizala
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.close,
                color: isDarkTheme ? Colors.white : Colors.blue,
              ),
            ),
          ],
        );
      },
    );
  }

  void _pickModelFile() async {
    Navigator.of(context).pop();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Allow all file types
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;

        // Check file extension
        if (path.extension(fileName).toLowerCase() != '.gguf') {
          // Removed notification
          return;
        }

        String newFilePath = path.join(_filesDirectoryPath, fileName);
        File file = File(filePath);

        if (await File(newFilePath).exists()) {
          // Removed notification
          return;
        }

        await file.copy(newFilePath);

        setState(() {
          _myModels.add({
            'title': path.basenameWithoutExtension(fileName),
            'description': AppLocalizations.of(context)!.myModelDescription,
            'size': '${(file.lengthSync() / 1024).toStringAsFixed(2)} KB', // Calculate file size
            'image': 'assets/customai.png',
            'path': newFilePath,
          });
        });

        // Removed notification
      } else {
        // User canceled file selection
        // Removed notification
      }
    } catch (e) {
      print("Error picking or copying file: $e");
      // Removed notification
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    final serverSideModels =
    _models.where((model) => model['isServerSide'] ?? false).toList();
    final localModels =
    _models.where((model) => !(model['isServerSide'] ?? false)).toList();

    return Scaffold(
      backgroundColor:
      _isDarkTheme ? const Color(0xFF090909) : Colors.white,
      appBar: AppBar(
        title: Text(
          localizations.modelsTitle,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: _isDarkTheme ? Colors.white : Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
        _isDarkTheme ? const Color(0xFF090909) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add,
                color: _isDarkTheme ? Colors.white : Colors.black),
            onPressed: _showUploadModelDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(
                  left: 16.0, right: 16.0, bottom: 16.0, top: 0.0),
              children: [
                if (localModels.isNotEmpty) ...[
                  _buildSectionHeader(
                      localizations.localModels, _isDarkTheme),
                  ...localModels.map((model) {
                    return _buildModelTile(
                      model['title']!,
                      model['description']!,
                      model['url'],
                      model['size'],
                      model['image']!,
                      model['ram'],
                      model['producer']!,
                      model['isServerSide'] ?? false,
                      _isDarkTheme,
                    );
                  }).toList(),
                ],
                if (serverSideModels.isNotEmpty) ...[
                  _buildSectionHeader(
                      localizations.serverSideModels, _isDarkTheme),
                  ...serverSideModels.map((model) {
                    return _buildModelTile(
                      model['title']!,
                      model['description']!,
                      model['url'],
                      model['size'],
                      model['image']!,
                      model['ram'],
                      model['producer']!,
                      model['isServerSide'] ?? false,
                      _isDarkTheme,
                    );
                  }).toList(),
                ],
                if (_myModels.isNotEmpty) ...[
                  _buildSectionHeader(localizations.myModels, _isDarkTheme),
                  ..._myModels.map((model) {
                    return _buildModelTile(
                      model['title'],
                      model['description'],
                      null,
                      '',
                      model['image'],
                      '',
                      '',
                      false,
                      _isDarkTheme,
                      isCustomModel: true,
                      modelPath: model['path'],
                    );
                  }).toList(),
                ],
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          localizations.systemInfo,
                          style: TextStyle(
                            color:
                            _isDarkTheme ? Colors.white : Colors.black,
                            fontSize: 22,
                            height: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 1,
                          width: 180,
                          color:
                          _isDarkTheme ? Colors.white : Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_systemInfo != null)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: _isDarkTheme
                          ? const Color(0xFF101010)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.deviceMemory(
                              (_systemInfo!.deviceMemory / 1024)
                                  .toStringAsFixed(1)),
                          style: TextStyle(
                            color: _isDarkTheme
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        Text(
                          localizations.storageSpace(
                              (_systemInfo!.totalStorage / 1024)
                                  .toStringAsFixed(1)),
                          style: TextStyle(
                            color: _isDarkTheme
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        Text(
                          localizations.freeStorageSpace(
                              (_systemInfo!.freeStorage / 1024)
                                  .toStringAsFixed(1)),
                          style: TextStyle(
                            color: _isDarkTheme
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final bool isDarkTheme;

  BorderPainter(
      {required this.progress,
        required this.borderRadius,
        required this.isDarkTheme});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    final SweepGradient gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 2 * pi,
      colors: [
        isDarkTheme ? Colors.white : Colors.black,
        Colors.transparent,
      ],
      stops: [0.0, 0.2],
      transform: GradientRotation((progress) * (pi / 180)),
    );

    final Paint paint = Paint()
      ..shader = gradient.createShader(rect.deflate(1))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(borderRadius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant BorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDarkTheme != isDarkTheme;
  }
}
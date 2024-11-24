// models.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'model.dart';
import 'notifications.dart';
import 'theme.dart';
import 'data.dart';
import 'download.dart';
import 'main.dart';
import 'system_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth eklemesi
import 'package:cloud_firestore/cloud_firestore.dart'; // Cloud Firestore eklemesi
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart'; // Internet Connection Checker eklemesi

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
  int _globalButtonClickCount = 0;
  bool _isGlobalButtonLocked = false;
  Timer? _resetClickCountTimer;


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
    _resetClickCountTimer?.cancel(); // Cancel any active timers
    _rotationController.stop(); // Stop any ongoing animations
    super.dispose();
  }

  Future<void> _initializeDirectory() async {
    // Uygulamanın belgeler dizinini kullan
    Directory appDocDir = await getApplicationDocumentsDirectory();
    _filesDirectoryPath = appDocDir.path;
    print("Dosyalar $_filesDirectoryPath dizinine kaydedilecek.");
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
          'size':
          '${(file.lengthSync() / 1024).toStringAsFixed(2)} KB', // Dosya boyutunu hesapla
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
      print('Sistem bilgisi alınırken hata oluştu: $e');
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
    title.replaceAll(' ', '_'); // Boşlukları alt çizgi ile değiştir
    return path.join(_filesDirectoryPath, '$sanitizedTitle.gguf');
  }

  // Kullanıcının Vertex Plus sahibi olup olmadığını kontrol eden metot
  Future<bool> _userHasVertexPlus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        return userDoc.get('hasVertexPlus') ?? false;
      }
      return false;
    } catch (e) {
      print("hasVertexPlus kontrolü sırasında hata: $e");
      return false;
    }
  }

  // "+" butonuna basıldığında çalışacak metot
  void _onAddButtonPressed() async {
    // İlk olarak internet bağlantısını kontrol et
    bool hasConnection = await InternetConnection().hasInternetAccess ;

    if (!hasConnection) {
      // İnternet bağlantısı yoksa 'İnternet Yok' bildirimini göster
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      notificationService.showNotification(
        message: AppLocalizations.of(context)!.noInternetConnection,
        isSuccess: false,
        bottomOffset: 80,
      );
      return; // İşlemi sonlandır
    }

    // İnternet bağlantısı varsa, kullanıcının Vertex Plus sahibi olup olmadığını kontrol et
    bool hasVertexPlus = await _userHasVertexPlus();
    if (hasVertexPlus) {
      // Vertex Plus sahibi ise model yükleme dialog'unu göster
      _showUploadModelDialog();
    } else {
      // Vertex Plus sahibi değilse 'Vertex Plus Satın Al' bildirimini göster
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      notificationService.showNotification(
        message: AppLocalizations.of(context)!.purchaseVertexPlusToUpload,
        isSuccess: false,
        bottomOffset: 80,
      );
    }
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
                    color: isDarkTheme
                        ? Colors.grey[900]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isServerSide || isDownloaded
                          ? (isDarkTheme
                          ? Colors.white
                          : Colors.black)
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
                                  const Icon(
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
                                    Colors.redAccent, // Kırmızı arka plan
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
                                        const Icon(
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
                                      isCustomModel: true, modelPath: modelPath),
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
                                        const Icon(
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
                      else
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: isDownloading
                              ? SizedBox(
                            key: const ValueKey('cancelButton'),
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _handleButtonPress(() => _cancelDownload(title)),
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
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    const Icon(
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
                              : isPaused
                              ? SizedBox(
                            key: const ValueKey('resumeButton'),
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _resumeDownload(title),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDarkTheme
                                    ? Colors.blueAccent
                                    : Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(8),
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
                                    const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(context)!
                                          .resume,
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
                              : !isDownloaded
                              ? SizedBox(
                            key: const ValueKey('downloadButton'),
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: compatibilityStatus !=
                                  CompatibilityStatus
                                      .compatible
                                  ? null
                                  : () => _handleButtonPress(() => _downloadModel(url, title)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                compatibilityStatus !=
                                    CompatibilityStatus
                                        .compatible
                                    ? Colors.grey
                                    : isDarkTheme
                                    ? Colors.white
                                    : Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                padding:
                                const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8),
                              ),
                              child: FittedBox(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.download,
                                      color: compatibilityStatus !=
                                          CompatibilityStatus
                                              .compatible
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
                                          ? AppLocalizations.of(
                                          context)!
                                          .insufficientRAM
                                          : compatibilityStatus ==
                                          CompatibilityStatus
                                              .insufficientStorage
                                          ? AppLocalizations.of(
                                          context)!
                                          .insufficientStorage
                                          : AppLocalizations.of(
                                          context)!
                                          .download,
                                      style: TextStyle(
                                        color: compatibilityStatus !=
                                            CompatibilityStatus
                                                .compatible
                                            ? Colors.white
                                            : isDarkTheme
                                            ? Colors.black
                                            : Colors.white,
                                        fontSize: 14,
                                        fontWeight:
                                        FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                              : SizedBox(
                            key: const ValueKey('actionButtons'),
                            width: double.infinity,
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _removeModel(title),
                                    style:
                                    ElevatedButton.styleFrom(
                                      backgroundColor:
                                      Colors.redAccent, // Kırmızı arka plan
                                      shape:
                                      RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(
                                            8),
                                      ),
                                      padding: const EdgeInsets
                                          .symmetric(
                                          vertical: 12),
                                    ),
                                    child: FittedBox(
                                      child: Row(
                                        mainAxisSize:
                                        MainAxisSize.min,
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                        children: [
                                          const Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            AppLocalizations.of(
                                                context)!
                                                .remove,
                                            style:
                                            const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight:
                                              FontWeight.bold,
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
                                    onPressed: () =>
                                        _startChatWithModel(
                                            title, isServerSide),
                                    style:
                                    ElevatedButton.styleFrom(
                                      backgroundColor: isDarkTheme
                                          ? Colors.blueAccent
                                          : Colors.blue,
                                      shape:
                                      RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(
                                            8),
                                      ),
                                      padding: const EdgeInsets
                                          .symmetric(
                                          vertical: 12,
                                          horizontal: 8),
                                    ),
                                    child: FittedBox(
                                      child: Row(
                                        mainAxisSize:
                                        MainAxisSize.min,
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                        children: [
                                          const Icon(
                                            Icons
                                                .chat_bubble_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            AppLocalizations.of(
                                                context)!
                                                .chat,
                                            style:
                                            const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight:
                                              FontWeight.bold,
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
    if (isServerSide) {
      // İnternet bağlantısını kontrol et
      bool hasConnection = await InternetConnection().hasInternetAccess;
      if (!hasConnection) {
        // Bildirim göster
        final notificationService =
        Provider.of<NotificationService>(context, listen: false);
        notificationService.showNotification(
          message: AppLocalizations.of(context)!.noInternetConnection,
          isSuccess: false,
          bottomOffset: 80,
        );
        return;
      }
    }

    await _selectModel(title, isServerSide,
        isCustomModel: isCustomModel, modelPath: modelPath);

    final modelData = isCustomModel
        ? _myModels.firstWhere((model) => model['title'] == title)
        : _models.firstWhere((model) => model['title'] == title);

    mainScreenKey.currentState?.chatScreenKey.currentState?.updateModelData(
      title: modelData['title'],
      description: modelData['description'],
      imagePath: modelData['image'],
      size: isCustomModel
          ? ''
          : _models.firstWhere((model) => model['title'] == title)['size'],
      ram: isCustomModel
          ? ''
          : _models.firstWhere((model) => model['title'] == title)['ram'],
      producer: isCustomModel
          ? ''
          : _models.firstWhere((model) => model['title'] == title)['producer'],
      path: isServerSide
          ? null
          : (isCustomModel
          ? modelPath
          : _getFilePath(title)),
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
            await _removeModel(title,
                isCustomModel: isCustomModel, modelPath: modelPath);
          },
          onChatPressed: () {
            _startChatWithModel(title, isServerSide,
                isCustomModel: isCustomModel, modelPath: modelPath);
          },
          onCancelPressed: () {
            _cancelDownload(title);
          }, // Added this line
        ),
      ),
    );
  }

  void _downloadModel(String? url, String title) async {
    if (url == null) return;
      // Check for internet connectivity
      bool hasConnection = await InternetConnection().hasInternetAccess;
      if (!hasConnection) {
        // Show notification if there's no internet connection
        final notificationService =
        Provider.of<NotificationService>(context, listen: false);
        notificationService.showNotification(
          message: AppLocalizations.of(context)!.noInternetConnection,
          // Ensure this localization key exists
          isSuccess: false,
          bottomOffset: 80, // or an appropriate value
        );
        return;
      }

    if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();

      // Indirme işlemi başlamadan önce isDownloading durumunu değiştirmiyoruz.

      final filePath = _getFilePath(title);

      String? taskId = await FileDownloadHelper().downloadModel(
        url: url,
        filePath: filePath,
        title: title,
        onProgress: (fileName, progress) {
          // İlerleme güncellemeleri
        },
        onDownloadCompleted: (path) async {
          print("İndirme tamamlandı, dosya yolu: $path");

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
          print("İndirme hatası: $error");

          // İndirme işlemi başlamadan hata oluşmuşsa, isDownloading durumunu değiştirmiyoruz
          if (error.contains('Download could not be started')) {
            // Bildirim göster
            final notificationService =
            Provider.of<NotificationService>(context, listen: false);
            notificationService.showNotification(
              message: AppLocalizations.of(context)!.noInternetConnection,
              // Ensure this localization key exists
              isSuccess: false,
              bottomOffset: 80, // Uygun bir değer
            );
          } else {
            if (mounted) {
              setState(() {
                _isDownloading[title] = false;
                _isPaused[title] = false;
              });
              final prefs = await SharedPreferences.getInstance();
              prefs.setBool('is_downloading_$title', false);
            }

            // Diğer hatalar için bildirim göstermiyoruz veya logluyoruz
          }
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

        // İndirme işlemi başarıyla başlatıldıktan sonra isDownloading durumunu güncelliyoruz
        if (mounted) {
          setState(() {
            _isDownloading[title] = true;
            _isPaused[title] = false;
          });
        }

        prefs.setBool('is_downloading_$title', true);
      }
  }

  void _handleButtonPress(VoidCallback action) {
    if (_isGlobalButtonLocked) {
      // If buttons are locked, show notification and return
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      notificationService.showNotification(
        message: AppLocalizations.of(context)!.pleaseWaitBeforeTryingAgain,
        isSuccess: false,
        bottomOffset: 80,
        width: 350,
        fontSize: 12,
      );
      return;
    }

    // Perform the action immediately
    action();

    // Increment the click count
    _globalButtonClickCount++;

    if (_globalButtonClickCount == 1) {
      // Start a timer to reset the click count after 4 seconds
      _resetClickCountTimer = Timer(Duration(seconds: 4), () {
        setState(() {
          _globalButtonClickCount = 0;
        });
      });
    }

    if (_globalButtonClickCount >= 4) {
      // Lock the buttons for 5 seconds
      setState(() {
        _isGlobalButtonLocked = true;
        _globalButtonClickCount = 0;
      });

      _resetClickCountTimer?.cancel();

      // Unlock the buttons after 3 seconds
      Timer(Duration(seconds: 3), () {
        setState(() {
          _isGlobalButtonLocked = false;
        });
      });
    }
  }

  Future<void> _checkFileExists(String title) async {
    final filePath = _getFilePath(title);

    final file = File(filePath);
    final bool fileExists = await file.exists();

    if (fileExists) {
      // final prefs = await SharedPreferences.getInstance();
      // prefs.setBool('is_downloaded_$title', true);

      if (mounted) {
        setState(() {
          // _downloadStates[title] = true;

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

            // Bildirim gönderimi kaldırıldı
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
        print("Dosya silindi: $filePath");

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

        // Başarılı bildirim gönderimi kaldırıldı
      } catch (e) {
        print("Dosya silme hatası: $e");
        // Hata bildirimi gönderimi kaldırıldı
      }
    } else {
      print("Dosya bulunamadı: $filePath");

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

      // Dosya bulunamadığında bildirim gönderimi kaldırıldı
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
      path: isServerSide
          ? null
          : (isCustomModel
          ? modelPath
          : _getFilePath(title)),
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

        // Bildirim gönderimi kaldırıldı
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
                  const SizedBox(height: 16),
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
          backgroundColor: isDarkTheme ? const Color(0xFF121212) : Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.white, width: 1), // İnce beyaz çizgi
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
        type: FileType.custom, // Sadece GGUF dosyalarını seç
        allowedExtensions: ['gguf'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;

        // Dosya uzantısını kontrol et
        if (path.extension(fileName).toLowerCase() != '.gguf') {
          // Uygun olmayan dosya uzantısı bildirimi eklenmedi
          return;
        }

        String newFilePath = _getFilePath(path.basenameWithoutExtension(fileName));
        File file = File(filePath);

        if (await File(newFilePath).exists()) {
          // Dosya zaten mevcut bildirimi kaldırıldı
          return;
        }

        await file.copy(newFilePath);

        setState(() {
          _myModels.add({
            'title': path.basenameWithoutExtension(fileName),
            'description': AppLocalizations.of(context)!.myModelDescription,
            'size':
            '${(file.lengthSync() / 1024).toStringAsFixed(2)} KB', // Dosya boyutunu hesapla
            'image': 'assets/customai.png',
            'path': newFilePath,
          });
        });

        // Sadece model başarıyla yüklendiğinde bildirim gönderiliyor
        final notificationService =
        Provider.of<NotificationService>(context, listen: false);
        notificationService.showNotification(
            message: 'Model başarıyla yüklendi.',
            isSuccess: true,
            bottomOffset: 80);
      } else {
        // Kullanıcı dosya seçiminden vazgeçtiğinde bildirim gönderilmiyor
      }
    } catch (e) {
      print("Dosya seçme veya kopyalama hatası: $e");
      // Hata bildirimi gönderimi kaldırıldı
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    final serverSideModels =
    _models.where((model) => model['isServerSide'] ?? false).toList();
    final localModels =
    _models.where((model) => !(model['isServerSide'] ?? false)).toList();

    return Scaffold(
      backgroundColor:
      isDarkTheme ? const Color(0xFF090909) : Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(
          localizations.modelsTitle,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: isDarkTheme ? Colors.white : Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
        isDarkTheme ? const Color(0xFF090909) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add,
                color: isDarkTheme ? Colors.white : Colors.black),
            onPressed: _onAddButtonPressed, // Güncellenen kısım
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
                      localizations.localModels, isDarkTheme),
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
                      isDarkTheme,
                    );
                  }),
                ],
                if (serverSideModels.isNotEmpty) ...[
                  _buildSectionHeader(
                      localizations.serverSideModels, isDarkTheme),
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
                      isDarkTheme,
                    );
                  }),
                ],
                if (_myModels.isNotEmpty) ...[
                  _buildSectionHeader(localizations.myModels, isDarkTheme),
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
                      isDarkTheme,
                      isCustomModel: true,
                      modelPath: model['path'],
                    );
                  }),
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
                            isDarkTheme ? Colors.white : Colors.black,
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
                          isDarkTheme ? Colors.white : Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_systemInfo != null)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: isDarkTheme
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
                            color: isDarkTheme
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        Text(
                          localizations.storageSpace(
                              (_systemInfo!.totalStorage / 1024)
                                  .toStringAsFixed(1)),
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        Text(
                          localizations.freeStorageSpace(
                              (_systemInfo!.freeStorage / 1024)
                                  .toStringAsFixed(1)),
                          style: TextStyle(
                            color: isDarkTheme
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
      stops: const [0.0, 0.2],
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
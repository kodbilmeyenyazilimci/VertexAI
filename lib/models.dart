import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'download.dart';
import 'main.dart';
import 'system_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  _ModelsScreenState createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Map<String, bool> _downloadStates;
  late Map<String, bool> _isDownloading;
  SystemInfoData? _systemInfo; // Nullable to handle initialization
  String? _selectedModelTitle; // Selected model title

  final List<Map<String, String>> _models = [
    {
      'title': 'TinyLlama',
      'description':
      "TinyLlama, 1.1 milyar parametreye sahip ve Llama 2'nin mimarisini kullanan bir dil modelidir. 4-bit kuantize edilmiştir ve daha düşük hesaplama gücü ile yüksek performans sunar.",
      'url':
      'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q8_0.gguf?download=true',
      'size': '1.1 GB'
    },
    {
      'title': 'Phi-2-Instruct-v1',
      'description':
      "Phi 2 Instruct-v1, yüksek performanslı ve küçük boyutlu bir AI modelidir. Model, 4-bit kuantize edilerek daha verimli bir şekilde çalışması sağlanmıştır.",
      'url':
      'https://huggingface.co/timothyckl/phi-2-instruct-v1/resolve/23d6e417677bc32b1fb4947615acbb616556142a/ggml-model-q4km.gguf',
      'size': '1.6 GB'
    },
    {
      'title': 'Mistral-7B-Turkish',
      'description':
      "Mistral 7B Instruct v0.2 Turkish, yüksek performans ve verimlilik sunan bir yapay zeka modelidir. 5-bit kuantizasyon teknolojisi ile optimize edilmiş olup, 7 milyar parametreye sahiptir. Türkçe dilinde etkili bir şekilde görev alabilir.",
      'url':
      'https://huggingface.co/sayhan/Mistral-7B-Instruct-v0.2-turkish-GGUF/resolve/main/mistral-7b-instruct-v0.2-turkish.Q5_K_M.gguf?download=true',
      'size': '4.8 GB'
    },
    {
      'title': 'Gemma',
      'description':
      "Gemma 1.1, yüksek performanslı ve kompakt bir AI modelidir. 4-bit kuantizasyon teknolojisi ile optimize edilmiştir ve 7 milyar parametreye sahiptir.",
      'url':
      'https://huggingface.co/ggml-org/gemma-1.1-7b-it-Q4_K_M-GGUF/resolve/main/gemma-1.1-7b-it.Q4_K_M.gguf?download=true',
      'size': '5.0 GB'
    },
    {
      'title': 'GPT Neo X',
      'description':
      "GPT Neo X, büyük ölçekli bir dil modelidir ve 20 milyar parametreye sahiptir. 4-bit kuantize edilerek yüksek performans ve düşük bellek kullanımı sunar.",
      'url':
      'https://huggingface.co/zhentaoyu/gpt-neox-20b-Q4_0-GGUF/resolve/main/gpt-neox-20b-q4_0.gguf',
      'size': '10.9 GB'
    },
  ];

  late String _filesDirectoryPath;

  @override
  void initState() {
    super.initState();

    // Initialize _downloadStates and _isDownloading
    _downloadStates = {};
    _isDownloading = {};

    // Initialize values through _models
    for (var model in _models) {
      _downloadStates[model['title']!] = false;
      _isDownloading[model['title']!] = false;
    }

    _initializeDirectory().then((_) {
      _checkDownloadStates();
      _checkDownloadingStates();

      // Check if downloaded files actually exist
      for (var model in _models) {
        _checkFileExists(model['title']!);
      }
    });

    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(_fadeController);

    _loadSystemInfo();

    // Load selected model from SharedPreferences
    _loadSelectedModel();

    // Request storage permissions
    _requestPermissions();
  }

  /// Requests storage permissions using permission_handler package.
  Future<void> _requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  /// Initializes the directory path using path_provider.
  Future<void> _initializeDirectory() async {
    Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      _filesDirectoryPath = externalDir.path; // e.g., /storage/emulated/0/Android/data/com.vertex.ai/files
    } else {
      // Fallback to internal directory if external storage is not available
      Directory appDocDir = await getApplicationDocumentsDirectory();
      _filesDirectoryPath = appDocDir.path;
    }
    print("Files will be stored in: $_filesDirectoryPath");
  }

  /// Loads system information asynchronously.
  Future<void> _loadSystemInfo() async {
    try {
      final systemInfo = await SystemInfoProvider.fetchSystemInfo();
      setState(() {
        _systemInfo = systemInfo;
      });
    } catch (e) {
      print('Error fetching system info: $e');
      // Handle the error as needed
    }
  }

  /// Loads the selected model from SharedPreferences.
  Future<void> _loadSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    String? selectedModelTitle = prefs.getString('selected_model_title');
    String? selectedModelPath = prefs.getString('selected_model_path');

    if (selectedModelTitle != null && selectedModelPath != null) {
      setState(() {
        _selectedModelTitle = selectedModelTitle;
      });
    }
  }

  /// Determines the text to display on the download button based on system info and model state.
  String _getDownloadButtonText(String title, String size) {
    if (_systemInfo == null) {
      return 'Az bekle'; // "Wait" in Turkish
    }

    final int requiredSizeMB = _parseSizeToMB(size);
    final int ramGB = (_systemInfo!.deviceMemory / 1024).floor();
    final bool isRAMSufficient;
    final bool isStorageSufficient = _systemInfo!.freeStorage >= requiredSizeMB;

    // Check RAM requirements
    if (ramGB <= 3) {
      isRAMSufficient = title == 'TinyLlama';
    } else if (ramGB <= 4) {
      isRAMSufficient = title == 'TinyLlama' || title == 'Phi-2-Instruct-v1';
    } else if (ramGB < 8) {
      isRAMSufficient = title == 'TinyLlama' ||
          title == 'Phi-2-Instruct-v1' ||
          title == 'Mistral-7B-Turkish' ||
          title == 'Gemma';
    } else {
      isRAMSufficient = true; // All models for >= 8 GB RAM
    }

    final isDownloaded = _downloadStates[title] ?? false;

    if (!isRAMSufficient) {
      return 'Yetersiz bellek'; // "Insufficient memory"
    }

    if (!isStorageSufficient) {
      return 'Yetersiz Depolama alanı'; // "Insufficient storage"
    }

    return isDownloaded ? 'Kaldır' : 'İndir'; // "Remove" or "Download"
  }

  /// Parses the size string to MB.
  int _parseSizeToMB(String size) {
    final sizeParts = size.split(' ');
    if (sizeParts.length < 2) return 0;
    final sizeValue = double.tryParse(sizeParts[0].replaceAll(',', '')) ?? 0.0;
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

  /// Constructs the full file path for a given model title.
  String _getFilePath(String title) {
    // Append '.ggf' extension to the title
    String sanitizedTitle = title.replaceAll(' ', '_'); // Replace spaces with underscores if necessary
    return '/storage/emulated/0/Download/$_filesDirectoryPath/${sanitizedTitle}.gguf';
  }

  /// Builds each model tile in the list.
  Widget _buildModelTile(String title, String description, String url, String size) {
    final isDownloaded = _downloadStates[title] ?? false;
    final isDownloading = _isDownloading[title] ?? false;
    final buttonText = _getDownloadButtonText(title, size);
    final bool isDisabled = buttonText != 'İndir'; // Disable button if not "Download"
    final isSelected = _selectedModelTitle == title;

    return GestureDetector(
      onTap: isDownloaded
          ? () => _selectModel(
        title,
      )
          : null, // If not downloaded, cannot select
      child: FadeTransition(
        opacity: isDownloading ? _fadeAnimation : const AlwaysStoppedAnimation(1.0),
        child: AnimatedContainer(
          duration: const Duration(seconds: 1),
          margin: const EdgeInsets.only(bottom: 16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.white.withOpacity(0.5) : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isDownloaded)
                    ElevatedButton(
                      onPressed: () => _removeModel(title), // Pass only title
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, // Red color for remove
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Kaldır', // "Remove" in Turkish
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: isDownloading || isDisabled ? null : () => _downloadModel(url, title),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDownloading
                            ? Colors.grey
                            : isDisabled
                            ? Colors.black
                            : Colors.purple[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isDownloading ? 'İndiriliyor...' : buttonText, // "Downloading..."
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  Row(
                    children: [
                      Icon(Icons.storage, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        size,
                        style: TextStyle(
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Initiates the download of a model.
  void _downloadModel(String url, String title) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is_downloading_$title', true);

    if (mounted) {
      setState(() {
        _isDownloading[title] = true;
      });
    }

    final filePath = _getFilePath(title);

    FileDownloadHelper().downloadModel(
      url: url,
      filePath: filePath,
      title: title,
      onProgress: (fileName, progress) {
        print("onProgress triggered: $progress");

        if (progress < 0.0 || progress > 100.0) {
          print("Invalid progress value ignored: $progress");
          return;
        }

        if (progress >= 100.0) {
          if (mounted) {
            setState(() {
              _isDownloading[title] = false;
              _downloadStates[title] = true;
            });
            prefs.setBool('is_downloading_$title', false); // Set to false when download completes
            prefs.setBool('is_downloaded_$title', true);
          }
        }
      },
      onDownloadCompleted: (path) async {
        print("Download completed, file path: $path");

        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('is_downloading_$title', false);
        prefs.setBool('is_downloaded_$title', true);

        if (mounted) {
          setState(() {
            _isDownloading[title] = false;
            _downloadStates[title] = true;
          });
        }
      },
      onDownloadError: (error) async {
        print("Download error: $error");

        if (mounted) {
          setState(() {
            _isDownloading[title] = false;
          });
          final prefs = await SharedPreferences.getInstance();
          prefs.setBool('is_downloading_$title', false);
        }

        // Bildirimleri kaldırdık, bu kısımlar silindi
      },
    );
  }

  /// Checks if the file for a given model exists.
  Future<void> _checkFileExists(String title) async {
    final filePath = _getFilePath(title);

    print("Checking file path: $filePath");

    final file = File(filePath);
    final bool fileExists = await file.exists();

    if (fileExists) {
      print("File exists: $filePath");
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('is_downloaded_$title', true);

      if (mounted) {
        setState(() {
          _downloadStates[title] = true;
        });
      }
    } else {
      print("File does not exist: $filePath");
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('is_downloading_$title', false);
      prefs.setBool('is_downloaded_$title', false);
      if (mounted) {
        setState(() {
          _downloadStates[title] = false;
        });
      }
    }
  }

  /// Retrieves the download states from SharedPreferences.
  void _checkDownloadStates() async {
    final prefs = await SharedPreferences.getInstance();

    for (var model in _models) {
      String title = model['title']!;
      final isDownloaded = prefs.getBool('is_downloaded_$title') ?? false;
      if (mounted) {
        setState(() {
          _downloadStates[title] = isDownloaded;
        });
      }

      // Additionally, check if the file actually exists
      _checkFileExists(title);
    }
  }

  /// Selects a model and notifies other parts of the app.
  void _selectModel(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedPath = _getFilePath(title);
    await prefs.setString('selected_model_path', selectedPath);
    await prefs.setString('selected_model_title', title);
    setState(() {
      _selectedModelTitle = title;
    });

    // Notify the chat screen to reload the model
    mainScreenKey.currentState?.chatScreenKey.currentState?.loadModel();
  }

  /// Checks the downloading states from SharedPreferences.
  void _checkDownloadingStates() async {
    // Check the downloading state of models
    final prefs = await SharedPreferences.getInstance();
    for (var model in _models) {
      String title = model['title']!;
      final isDownloading = prefs.getBool('is_downloading_$title') ?? false;
      if (isDownloading) {
        setState(() {
          _isDownloading[title] = true;
        });
      }
    }
  }

  /// Removes a downloaded model from the device using only the model's title.
  void _removeModel(String title) async {
    final prefs = await SharedPreferences.getInstance();

    // Show customized confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Modeli Kaldır',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '$title modelini cihazınızdan kaldırmak istediğinizden emin misiniz?',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), // Adjusted corner radius
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Kaldır',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final filePath = _getFilePath(title);
    final file = File(filePath);

    // Check if the file exists
    if (await file.exists()) {
      try {
        await file.delete();
        print("File deleted: $filePath");

        // Update SharedPreferences
        await prefs.setBool('is_downloaded_$title', false);

        // If the removed model is selected, clear the selection
        if (_selectedModelTitle == title) {
          await prefs.remove('selected_model_path');
          await prefs.remove('selected_model_title');
          setState(() {
            _selectedModelTitle = null;
          });
          // Notify the chat screen to reload the model
          mainScreenKey.currentState?.chatScreenKey.currentState?.loadModel();
        }

        if (mounted) {
          setState(() {
            _downloadStates[title] = false;
          });
        }

      } catch (e) {
        print("File deletion error: $e");
        // Handle the error as needed
      }
    } else {
      print("File not found: $filePath");
      // Update SharedPreferences if the file doesn't exist
      await prefs.setBool('is_downloaded_$title', false);

      if (mounted) {
        setState(() {
          _downloadStates[title] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          'Modeller',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            // Place Expanded within the body
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                ..._models.map((model) {
                  return _buildModelTile(
                    model['title']!,
                    model['description']!,
                    model['url']!,
                    model['size']!,
                  );
                }),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Sistem Bilgileri',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 1,
                          width: 180,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_systemInfo != null)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cihaz Belleği: ${(_systemInfo!.deviceMemory / 1024).toStringAsFixed(1)} GB',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Depolama Alanı: ${(_systemInfo!.totalStorage / 1024).toStringAsFixed(1)} GB',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Boş Depolama Alanı: ${(_systemInfo!.freeStorage / 1024).toStringAsFixed(1)} GB',
                          style: const TextStyle(color: Colors.white),
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

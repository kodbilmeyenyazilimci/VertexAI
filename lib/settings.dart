import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'download.dart';
import 'system_info.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Map<String, bool> _downloadStates;
  late Map<String, bool> _isDownloading;
  SystemInfoData? _systemInfo; // Nullable to handle initialization

  final List<Map<String, String>> _models = [
    {
      'title': 'TinyLlama',
      'description': "TinyLlama, 1.1 milyar parametreye sahip ve Llama 2'nin mimarisini kullanan bir dil modelidir. 4-bit kuantize edilmiştir ve daha düşük hesaplama gücü ile yüksek performans sunar.",
      'url': 'https://huggingface.co/mjschock/TinyLlama-1.1B-Chat-v1.0-Q4_K_M-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0-q4_k_m.gguf',
      'size': '668 MB'
    },
    {
      'title': 'Phi 2 Instruct-v1',
      'description': "Phi 2 Instruct-v1, yüksek performanslı ve küçük boyutlu bir AI modelidir. Model, 4-bit kuantize edilerek daha verimli bir şekilde çalışması sağlanmıştır.",
      'url': 'https://huggingface.co/timothyckl/phi-2-instruct-v1/resolve/23d6e417677bc32b1fb4947615acbb616556142a/ggml-model-q4km.gguf',
      'size': '1.6 GB'
    },
    {
      'title': 'Gemma 1.1',
      'description': "Gemma 1.1, yüksek performanslı ve kompakt bir AI modelidir. 4-bit kuantizasyon teknolojisi ile optimize edilmiştir ve 7 milyar parametreye sahiptir.",
      'url': 'https://huggingface.co/ggml-org/gemma-1.1-7b-it-Q4_K_M-GGUF/resolve/main/gemma-1.1-7b-it.Q4_K_M.gguf?download=true',
      'size': '5.0 GB'
    },
    {
      'title': 'GPT Neo X',
      'description': "GPT Neo X, büyük ölçekli bir dil modelidir ve 20 milyar parametreye sahiptir. 4-bit kuantize edilerek yüksek performans ve düşük bellek kullanımı sunar.",
      'url': 'https://huggingface.co/zhentaoyu/gpt-neox-20b-Q4_0-GGUF/resolve/main/gpt-neox-20b-q4_0.gguf',
      'size': '10.9 GB'
    },
  ];

  @override
  void initState() {
    super.initState();

    // _downloadStates ve _isDownloading'i başlatıyoruz
    _downloadStates = {};
    _isDownloading = {};

    // _models üzerinden döngü ile değerleri başlatıyoruz
    for (var model in _models) {
      _downloadStates[model['title']!] = false;
      _isDownloading[model['title']!] = false;
    }

    _checkDownloadStates();
    _checkDownloadingStates();

    // İndirilen dosyaların gerçekten var olup olmadığını kontrol et
    for (String title in _downloadStates.keys) {
      _checkFileExists(title);
    }

    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(_fadeController);

    _loadSystemInfo();
  }

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

  String _getDownloadButtonText(String title, String size) {
    if (_systemInfo == null) {
      return 'Az bekle';  // "Wait" in Turkish
    }

    final int requiredSizeMB = _parseSizeToMB(size);
    final int ramGB = (_systemInfo!.deviceMemory / 1024).floor();
    final bool isRAMSufficient;
    final bool isStorageSufficient = _systemInfo!.freeStorage >= requiredSizeMB;

    // Check RAM requirements
    if (ramGB <= 3) {
      isRAMSufficient = title == 'TinyLlama';
    } else if (ramGB <= 4) {
      isRAMSufficient = title == 'TinyLlama' || title == 'Phi 2 Instruct-v1';
    } else if (ramGB < 8) {
      isRAMSufficient = title == 'TinyLlama' || title == 'Phi 2 Instruct-v1' || title == 'Gemma 1.1';
    } else {
      isRAMSufficient = true; // All models for >= 8 GB RAM
    }

    final isDownloaded = _downloadStates[title] ?? false;

    if (!isRAMSufficient) {
      return 'Yetersiz bellek';  // "Insufficient memory"
    }

    if (!isStorageSufficient) {
      return 'Yetersiz Depolama alanı';  // "Insufficient storage"
    }

    return isDownloaded ? 'İndirildi' : 'İndir';  // "Downloaded" or "Download"
  }

  int _parseSizeToMB(String size) {
    final sizeInMB = int.tryParse(size.split(' ')[0].replaceAll(',', ''));
    if (size.contains('GB')) {
      return (sizeInMB ?? 0) * 1024;
    }
    return sizeInMB ?? 0;
  }

  Widget _buildModelTile(String title, String description, String url, String size) {
    final isDownloaded = _downloadStates[title] ?? false;
    final isDownloading = _isDownloading[title] ?? false;
    final buttonText = _getDownloadButtonText(title, size);
    final bool isDisabled = buttonText != 'İndir'; // Disable button if not "Download"

    return FadeTransition(
      opacity: isDownloading ? _fadeAnimation : const AlwaysStoppedAnimation(1.0),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
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
                  const Row(
                    children: [
                      Icon(Icons.check, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'İndirildi',  // "Downloaded"
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
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
                      isDownloading ? 'İndiriliyor...' : buttonText,  // "Downloading..."
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
    );
  }

  void _downloadModel(String url, String title) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is_downloading_$title', true);

    if (mounted) {
      setState(() {
        _isDownloading[title] = true;
      });
    }

    FileDownloadHelper().downloadModel(
      url: url,
      title: title,
      onProgress: (fileName, progress) {
        print("onProgress tetiklendi: $progress");

        if (progress < 0.0 || progress > 100.0) {
          print("Geçersiz progress değeri göz ardı edildi: $progress");
          return;
        }

        if (progress >= 100.0) {
          if (mounted) {
            setState(() {
              _isDownloading[title] = false;
              _downloadStates[title] = true;
            });
            prefs.setBool('is_downloading_$title', false); // İndirme tamamlandığında false
          }
        }
      },
      onDownloadCompleted: (path) async {
        print("İndirme tamamlandı, dosya yolu: $path");

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
        print("İndirme hatası: $error");

        if (mounted) {
          setState(() {
            _isDownloading[title] = false;
          });
          final prefs = await SharedPreferences.getInstance();
          prefs.setBool('is_downloading_$title', false);
        }
      },
    );
  }

  Future<void> _checkFileExists(String title) async {
    // Dosyanın manuel olarak kaydedildiği yolu belirle
    final manualPath = '/storage/emulated/0/Download/storage/emulated/0/Android/data/com.vertex.ai/files/';
    final filename = '${title.replaceAll(' ', '').replaceAll('/', '')}.gguf';
    final filePath = '$manualPath$filename';

    print("Dosya yolunu kontrol et: $filePath");

    final file = File(filePath);
    final bool fileExists = await file.exists();

    if (fileExists) {
      print("Dosya mevcut: $filePath");
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('is_downloaded_$title', true);

      if (mounted) {
        setState(() {
          _downloadStates[title] = true;
        });
      }
    } else {
      print("Dosya mevcut değil: $filePath");
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

  void _checkDownloadStates() async {
    final prefs = await SharedPreferences.getInstance();

    for (String title in _downloadStates.keys) {
      final isDownloaded = prefs.getBool('is_downloaded_$title') ?? false;
      if (mounted) {
        setState(() {
          _downloadStates[title] = isDownloaded;
        });
      }
    }
  }

  void _checkDownloadingStates() async {
    // İndirilen dosyaların durumunu kontrol et
    final prefs = await SharedPreferences.getInstance();
    for (String title in _isDownloading.keys) {
      final isDownloading = prefs.getBool('is_downloading_$title') ?? false;
      if (isDownloading) {
        setState(() {
          _isDownloading[title] = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 48.0, left: 12.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ayarlar',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Modeller',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(),
                        Container(
                          height: 1.4,
                          width: 120,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
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
                // Display system information if available
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

// model.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Localization package
import 'package:provider/provider.dart'; // Provider import
import 'notifications.dart';
import 'theme.dart'; // ThemeProvider import

class ModelDetailPage extends StatefulWidget {
  final String title;
  final String description;
  final String imagePath;
  final String size;
  final String producer;
  final String ram;
  final bool isDownloaded;
  final bool isDownloading;
  final CompatibilityStatus compatibilityStatus;
  final VoidCallback? onDownloadPressed;
  final Future<void> Function()? onRemovePressed;
  final VoidCallback? onChatPressed;
  final bool isServerSide; // Stored to determine UI
  final VoidCallback? onCancelPressed; // Newly added parameter

  const ModelDetailPage({
    super.key,
    required this.title,
    required this.description,
    required this.ram,
    required this.imagePath,
    required this.size,
    required this.producer,
    required this.isDownloaded,
    required this.isDownloading,
    required this.compatibilityStatus,
    this.onDownloadPressed,
    this.onRemovePressed,
    this.onChatPressed,
    required this.isServerSide, // Now stored in the widget
    this.onCancelPressed, // Newly added parameter
  });

  @override
  _ModelDetailPageState createState() => _ModelDetailPageState();
}

class _ModelDetailPageState extends State<ModelDetailPage> {
  late bool _isDownloaded;
  late bool _isDownloading;
  int _buttonClickCount = 0;
  bool _isButtonLocked = false;
  Timer? _resetClickCountTimer;

  @override
  void initState() {
    super.initState();
    _isDownloaded = widget.isDownloaded;
    _isDownloading = widget.isDownloading;
    _loadSelectedModel();
  }

  Future<void> _loadSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    String? selectedModelTitle = prefs.getString('selected_model_title');
    if (mounted) {
      setState(() {
      });
    }
  }

  Future<void> _removeModel() async {
    if (widget.onRemovePressed != null) {
      await widget.onRemovePressed!(); // Invoke the passed function
      if (mounted) {
        setState(() {
          _isDownloaded = false;
        });
      }
      Navigator.pop(context, 'model_updated');
    }
  }

  void _startChatWithModel() {
    if (widget.onChatPressed != null) {
      widget.onChatPressed!(); // Invoke the passed function
      Navigator.pop(context); // Pop the ModelDetailPage to show the chat screen
    }
  }


  void _handleButtonPress(VoidCallback action) {
    if (_isButtonLocked) {
      // Buton kilitliyse, bekleme bildirimi göster
      final notificationService = Provider.of<NotificationService>(
          context, listen: false);
      notificationService.showNotification(
        message: AppLocalizations.of(context)!.pleaseWaitBeforeTryingAgain,
        isSuccess: false,
        bottomOffset: 19,
        width: 350,
        fontSize: 12,
      );
      return;
    }

    // Tıklama sayısını artır
    _buttonClickCount++;

    if (_buttonClickCount == 1) {
      // İlk tıklamada timer'ı başlat
      _resetClickCountTimer = Timer(Duration(seconds: 4), () {
        setState(() {
          _buttonClickCount = 0;
        });
      });
    }

    if (_buttonClickCount >= 4) {
      // 4 veya daha fazla tıklama tespit edildiğinde
      final notificationService = Provider.of<NotificationService>(
          context, listen: false);
      notificationService.showNotification(
        message: AppLocalizations.of(context)!.pleaseWaitBeforeTryingAgain,
        isSuccess: false,
        bottomOffset: 19,
        width: 350,
        fontSize: 12,
      );

      // Butonları kilitle
      setState(() {
        _isButtonLocked = true;
        _buttonClickCount = 0; // Tıklama sayısını sıfırla
      });

      // Mevcut timer'ı iptal et ve 5 saniye sonra kilidi kaldır
      _resetClickCountTimer?.cancel();
      Timer(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isButtonLocked = false;
          });
        }
      });

      return;
    }

    // İlgili işlemi gerçekleştir
    action();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; // Access localization
    final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    return Scaffold(
      // Set a solid color background
      backgroundColor: isDarkTheme ? const Color(0xFF090909) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            _buildAppBar(context, localizations, isDarkTheme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Model Image and Title
                    _buildModelHeader(localizations, isDarkTheme),
                    const SizedBox(height: 16),
                    // Action Buttons Below Model Title
                    _buildActionButtons(context, localizations, isDarkTheme),
                    const SizedBox(height: 24),
                    // Model Description
                    _buildSectionTitle(localizations, 'descriptionSection', isDarkTheme),
                    const SizedBox(height: 8),
                    _buildDescription(isDarkTheme),
                    const SizedBox(height: 24),
                    // Additional Sections (if any)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom AppBar Widget
  Widget _buildAppBar(BuildContext context, AppLocalizations localizations, bool isDarkTheme) {
    return AppBar(
      scrolledUnderElevation: 0,
      title: Text(
        widget.title,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: isDarkTheme ? Colors.white : Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: isDarkTheme ? const Color(0xFF090909) : Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: isDarkTheme ? Colors.white : Colors.black),
      actions: const [],
    );
  }

  // Model Image and Title Widget
  Widget _buildModelHeader(AppLocalizations localizations, bool isDarkTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Model Image with Shadow and Rounded Corners
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: isDarkTheme ? Colors.black.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: AssetImage(widget.imagePath),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Title, Producer, Storage Info, and RAM Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.poppins(
                  color: isDarkTheme ? Colors.white : Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.producer,
                style: GoogleFonts.poppins(
                  color: isDarkTheme ? Colors.white70 : Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              // Storage Info with Icon
              Row(
                children: [
                  Icon(
                    Icons.storage,
                    color: isDarkTheme ? Colors.white70 : Colors.black54,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${localizations.storage}: ${widget.size}',
                    style: GoogleFonts.poppins(
                      color: isDarkTheme ? Colors.white70 : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // RAM Info with Icon
              Row(
                children: [
                  Icon(
                    Icons.memory, // Suitable icon for RAM
                    color: isDarkTheme ? Colors.white70 : Colors.black54,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${localizations.ram}: ${widget.ram}',
                    style: GoogleFonts.poppins(
                      color: isDarkTheme ? Colors.white70 : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Section Title Widget
  Widget _buildSectionTitle(AppLocalizations localizations, String sectionKey, bool isDarkTheme) {
    String sectionTitle;
    switch (sectionKey) {
      case 'descriptionSection':
        sectionTitle = localizations.descriptionSection;
        break;
      default:
        sectionTitle = '';
    }

    return Text(
      sectionTitle,
      style: TextStyle(
        color: isDarkTheme ? Colors.white : Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // Description Widget
  Widget _buildDescription(bool isDarkTheme) {
    return Text(
      widget.description,
      style: TextStyle(
        color: isDarkTheme ? Colors.white70 : Colors.black87,
        fontSize: 16,
        height: 1.6,
      ),
    );
  }

  // Action Buttons Widget with AnimatedSwitcher
  Widget _buildActionButtons(BuildContext context, AppLocalizations localizations, bool isDarkTheme) {
    return Column(
      children: [
        if (!widget.isServerSide) ...[
          if (!_isDownloaded) ...[
            // Download or Cancel Button with AnimatedSwitcher
            SizedBox(
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                // Ensuring the AnimatedSwitcher takes full width and maintains size
                layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: _isDownloading
                    ? SizedBox(
                  key: const ValueKey('cancel'),
                  width: double.infinity, // Ensuring full width
                  child: ElevatedButton.icon(
                    onPressed: widget.onCancelPressed == null
                        ? null
                        : () {
    _handleButtonPress(() {
      widget.onCancelPressed!();
      setState(() {
        _isDownloading = false;
      });
    });
                    },
                    icon: const Icon(
                      Icons.cancel,
                      color: Colors.white, // Always white for Cancel
                    ),
                    label: Text(
                      localizations.cancelDownload,
                      style: const TextStyle(
                        color: Colors.white, // Always white for Cancel
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, // Cancel button color
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
                    : SizedBox(
                  key: const ValueKey('download'),
                  width: double.infinity, // Ensuring full width
                  child: ElevatedButton.icon(
                    onPressed: widget.compatibilityStatus != CompatibilityStatus.compatible ||
                        widget.onDownloadPressed == null
                        ? null
                        : () {
    _handleButtonPress(() {
      // Download button pressed
      widget.onDownloadPressed!();
      setState(() {
        _isDownloading = true;
      });
    });
                    },
                    icon: Icon(
                      Icons.download,
                      color: isDarkTheme ? Colors.black : Colors.white,
                    ),
                    label: Text(
                      widget.compatibilityStatus == CompatibilityStatus.insufficientRAM
                          ? localizations.insufficientRAM
                          : widget.compatibilityStatus == CompatibilityStatus.insufficientStorage
                          ? localizations.insufficientStorage
                          : localizations.download,
                      style: TextStyle(
                        color: isDarkTheme ? Colors.black : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkTheme ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            // Remove and Chat Buttons (No change needed here)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onRemovePressed == null ? null : _removeModel,
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                    label: Text(
                      localizations.remove,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onChatPressed == null ? null : _startChatWithModel,
                    icon: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      localizations.chat,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
        if (widget.isServerSide) ...[
          // Only Chat Button for Server-Side Models
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onChatPressed == null ? null : _startChatWithModel,
              icon: const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
              ),
              label: Text(
                localizations.chat,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
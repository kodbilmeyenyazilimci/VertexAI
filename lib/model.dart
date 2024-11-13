// model.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Localization package
import 'package:provider/provider.dart'; // Provider import
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
  });

  @override
  _ModelDetailPageState createState() => _ModelDetailPageState();
}

class _ModelDetailPageState extends State<ModelDetailPage> {
  late bool _isDownloaded;
  late bool _isDownloading;
  String? _selectedModelTitle;

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
        _selectedModelTitle = selectedModelTitle;
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; // Access localization
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    return Scaffold(
      // Set a solid color background
      backgroundColor: _isDarkTheme ? const Color(0xFF090909) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            _buildAppBar(context, localizations, _isDarkTheme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Model Image and Title
                    _buildModelHeader(localizations, _isDarkTheme),
                    const SizedBox(height: 16),
                    // Action Buttons Below Model Title
                    _buildActionButtons(context, localizations, _isDarkTheme),
                    const SizedBox(height: 24),
                    // Model Description
                    _buildSectionTitle(localizations, 'descriptionSection', _isDarkTheme),
                    const SizedBox(height: 8),
                    _buildDescription(_isDarkTheme),
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
  Widget _buildAppBar(BuildContext context, AppLocalizations localizations, bool _isDarkTheme) {
    return AppBar(
      title: Text(
        widget.title,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: _isDarkTheme ? Colors.white : Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: _isDarkTheme ? const Color(0xFF090909) : Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: _isDarkTheme ? Colors.white : Colors.black),
      actions: const [],
    );
  }

  // Model Image and Title Widget
  Widget _buildModelHeader(AppLocalizations localizations, bool _isDarkTheme) {
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
                color: _isDarkTheme ? Colors.black.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
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
                  color: _isDarkTheme ? Colors.white : Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.producer,
                style: GoogleFonts.poppins(
                  color: _isDarkTheme ? Colors.white70 : Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              // Storage Info with Icon
              Row(
                children: [
                  Icon(
                    Icons.storage,
                    color: _isDarkTheme ? Colors.white70 : Colors.black54,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${localizations.storage}: ${widget.size}',
                    style: GoogleFonts.poppins(
                      color: _isDarkTheme ? Colors.white70 : Colors.black87,
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
                    color: _isDarkTheme ? Colors.white70 : Colors.black54,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${localizations.ram}: ${widget.ram}',
                    style: GoogleFonts.poppins(
                      color: _isDarkTheme ? Colors.white70 : Colors.black87,
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
  Widget _buildSectionTitle(AppLocalizations localizations, String sectionKey, bool _isDarkTheme) {
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
        color: _isDarkTheme ? Colors.white : Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // Description Widget
  Widget _buildDescription(bool _isDarkTheme) {
    return Text(
      widget.description,
      style: TextStyle(
        color: _isDarkTheme ? Colors.white70 : Colors.black87,
        fontSize: 16,
        height: 1.6,
      ),
    );
  }

  // Action Buttons Widget
  Widget _buildActionButtons(BuildContext context, AppLocalizations localizations, bool _isDarkTheme) {
    return Column(
      children: [
        if (!widget.isServerSide) ...[
          if (!widget.isDownloaded) ...[
            // Download Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isDownloading ||
                    widget.compatibilityStatus != CompatibilityStatus.compatible ||
                    widget.onDownloadPressed == null)
                    ? null
                    : () {
                  widget.onDownloadPressed!();
                  setState(() {
                    _isDownloading = true;
                  });
                },
                icon: _isDownloading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Icon(
                  Icons.download,
                  color: _isDarkTheme ? Colors.black : Colors.white,
                ),
                label: Text(
                  _isDownloading
                      ? localizations.downloading
                      : widget.compatibilityStatus == CompatibilityStatus.insufficientRAM
                      ? localizations.insufficientRAM
                      : widget.compatibilityStatus == CompatibilityStatus.insufficientStorage
                      ? localizations.insufficientStorage
                      : localizations.download,
                  style: TextStyle(
                    color: _isDarkTheme ? Colors.black : Colors.white,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDarkTheme ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            // Remove and Chat Buttons
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
                Icons.chat_bubble_outline_rounded,
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

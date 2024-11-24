// account.dart
import 'package:ai/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'locale_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';
import 'package:shimmer/shimmer.dart'; // Updated import
import 'dart:math'; // For animation
import 'notifications.dart'; // Added for NotificationService
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart'; // Import for internet connection checker

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with SingleTickerProviderStateMixin {
  String _selectedLanguageCode = 'en';
  bool _isDarkTheme = false;
  Map<String, dynamic>? _userData;
  bool _hasVertexPlus = false; // New state variable
  bool _isAlphaUser = false; // New state variable for alpha user

  // Animation controller for the animated border
  late AnimationController _animationController;
  late Animation<double> _animation;

  // NotificationService instance
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _fetchUserData();

    // Initialize NotificationService
    _notificationService = Provider.of<NotificationService>(context, listen: false);

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(); // Repeat the animation indefinitely

    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    // Get initial selected language and theme
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    _selectedLanguageCode = locale.languageCode;
  }

  @override
  void dispose() {
    _animationController.dispose(); // Dispose the controller
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>?;
          _hasVertexPlus = _userData?['hasVertexPlus'] ?? false;
          _isAlphaUser = _userData?['alphaUser'] ?? false; // Set alphaUser status
        });
      } catch (e) {
        print("Error fetching user data: $e");
      }
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    bool? savedTheme = prefs.getBool('isDarkTheme');

    if (savedTheme == null) {
      final brightness = MediaQuery.of(context).platformBrightness;
      _isDarkTheme = brightness == Brightness.dark;
    } else {
      _isDarkTheme = savedTheme;
    }

    setState(() {});
  }

  Future<void> _saveThemePreference(bool isDarkTheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', isDarkTheme);
  }

  void _changeLanguage(String languageCode) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    setState(() {
      _selectedLanguageCode = languageCode;
    });
    localeProvider.setLocale(Locale(languageCode));
  }

  void _changeTheme(String theme) {
    setState(() {
      _isDarkTheme = theme == 'dark';
    });
    _saveThemePreference(_isDarkTheme);

    // Obtain the ThemeProvider and toggle the theme
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.toggleTheme(_isDarkTheme);
  }

  /// Method to show "Coming Soon" message using NotificationService
  void _showComingSoonMessage() {
    final notificationService = Provider.of<NotificationService>(context, listen: false);

    notificationService.showCustomNotification(
      message: AppLocalizations.of(context)!.comingSoon,
      backgroundColor: _isDarkTheme ? Colors.white : Colors.black,
      textColor: _isDarkTheme ? Colors.black : Colors.white,
      textStyle: TextStyle(
        fontWeight: FontWeight.bold,
        color: _isDarkTheme ? Colors.black : Colors.white,
      ),
      beginOffset: const Offset(0, 1.0),
      endOffset: const Offset(0, 0.4),
      duration: const Duration(seconds: 2),
      width: 150.0, // Dar bir genişlik ayarı
    );
  }

  Future<bool> _hasInternetConnection() async {
    return await InternetConnection().hasInternetAccess;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context)!;

    // Determine the display name and email
    String displayName;
    String email;
    if (_userData != null && _userData!['username'] != null) {
      displayName = _userData!['username'];
    } else {
      displayName = FirebaseAuth.instance.currentUser?.email ?? '';
    }
    email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: _isDarkTheme ? const Color(0xFF141414) : Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(
          appLocalizations.settings,
          style: GoogleFonts.roboto(color: _isDarkTheme ? Colors.white : Colors.black),
        ),
        backgroundColor: _isDarkTheme ? const Color(0xFF141414) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _isDarkTheme ? Colors.white : Colors.black),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _userData == null
            ? _buildSkeletonLoader()
            : _buildContent(displayName, email, appLocalizations),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SkeletonLoaderShimmer(isDarkTheme: _isDarkTheme); // Updated to use Shimmer
  }

  /// Builds the actual content when data is loaded
  Widget _buildContent(String displayName, String email, AppLocalizations appLocalizations) {
    return ListView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildProfileHeader(displayName, email),
        const SizedBox(height: 32),
        _buildUserSection(appLocalizations), // User section
        const SizedBox(height: 30),
        _buildLanguageSelection(appLocalizations),
        const SizedBox(height: 20),
        _buildThemeSelection(appLocalizations),
        const SizedBox(height: 20),
        _buildSettingsSection(appLocalizations),
      ],
    );
  }

  Widget _buildProfileHeader(String displayName, String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Conditional Animated Border around Profile Avatar
            if (_hasVertexPlus)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: AnimatedBorderPainter(
                      animationValue: _animation.value,
                      isDarkTheme: _isDarkTheme,
                    ),
                    child: Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(4.0),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor:
                        _isDarkTheme ? Colors.grey[800] : Colors.grey[300],
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '',
                          style: TextStyle(
                            fontSize: 40,
                            color: _isDarkTheme ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(4.0),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor:
                  _isDarkTheme ? Colors.grey[800] : Colors.grey[300],
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '',
                    style: TextStyle(
                      fontSize: 40,
                      color: _isDarkTheme ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kullanıcı Adı için FittedBox
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      displayName,
                      style: GoogleFonts.poppins(
                        color: _isDarkTheme ? Colors.white : Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Email için FittedBox
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      email,
                      style: GoogleFonts.poppins(
                        color: _isDarkTheme ? Colors.white70 : Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_hasVertexPlus) _buildBadge(Icons.star, 'Plus'),
                      if (_hasVertexPlus && _isAlphaUser)
                        const SizedBox(width: 10),
                      if (_isAlphaUser) _buildBadge(Icons.explore, "Alpha"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: _isDarkTheme ? Colors.grey[900] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _isDarkTheme ? Colors.white : Colors.black,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: _isDarkTheme ? Colors.white : Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection(AppLocalizations appLocalizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appLocalizations.user,
          style: GoogleFonts.roboto(
            color: _isDarkTheme ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          appLocalizations.manageProfileDescription,
          style: GoogleFonts.roboto(
            color: _isDarkTheme ? Colors.white70 : Colors.black87,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        _buildCenteredButton(
          context: context,
          text: appLocalizations.editProfile,
          icon: Icons.edit,
          onPressed: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              bool hasInternet = await _hasInternetConnection();
              if (hasInternet) {
                _showEditProfileDialog(user);
              } else {
                // İnternet yoksa uyarı bildirimi göster
                _notificationService.showCustomNotification(
                  message: appLocalizations.noInternetConnection,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  beginOffset: const Offset(0, 1.0),
                  endOffset: const Offset(0, 0.4),
                  duration: const Duration(seconds: 2),
                  width: 250.0,
                );
              }
            }
          },
        ),
        const SizedBox(height: 10),
        _buildCenteredButton(
          context: context,
          text: appLocalizations.changePassword,
          icon: Icons.lock,
          onPressed: () async {
            bool hasInternet = await _hasInternetConnection();
            if (hasInternet) {
              _showChangePasswordDialog();
            } else {
              // İnternet yoksa uyarı bildirimi göster
              _notificationService.showCustomNotification(
                message: appLocalizations.noInternetConnection,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                beginOffset: const Offset(0, 1.0),
                endOffset: const Offset(0, 0.4),
                duration: const Duration(seconds: 2),
                width: 250.0,
              );
            }
          },
        ),
        const SizedBox(height: 10),
        _buildCenteredButton(
          context: context,
          text: appLocalizations.logout,
          icon: Icons.logout,
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
        ),
      ],
    );
  }

  /// Builds the settings section from the provided image
  Widget _buildSettingsSection(AppLocalizations appLocalizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appLocalizations.settings, // Use appLocalizations for i18n support
          style: GoogleFonts.roboto(
            color: _isDarkTheme ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          appLocalizations.accessSettingsDescription,
          style: GoogleFonts.roboto(
            color: _isDarkTheme ? Colors.white70 : Colors.black87,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: _isDarkTheme ? Colors.grey[900] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            children: [
              _buildSettingsButton(appLocalizations.help, Icons.help_outline, _showComingSoonMessage),
              _buildDivider(),
              _buildSettingsButton(appLocalizations.redeemCode, Icons.confirmation_number, _showComingSoonMessage),
              _buildDivider(),
              _buildSettingsButton(appLocalizations.shareApp, Icons.share, _showComingSoonMessage),
              _buildDivider(),
              _buildSettingsButton(appLocalizations.rateUs, Icons.star, _showComingSoonMessage),
              _buildDivider(),
              _buildSettingsButton(appLocalizations.termsOfUse, Icons.article, _showComingSoonMessage),
              _buildDivider(),
              _buildSettingsButton(appLocalizations.privacyPolicy, Icons.privacy_tip, _showComingSoonMessage),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper method to create each button in the settings section
  Widget _buildSettingsButton(String text, IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: _isDarkTheme ? Colors.grey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: _isDarkTheme ? Colors.white : Colors.black,
                ),
                const SizedBox(width: 16),
                Text(
                  text,
                  style: GoogleFonts.roboto(
                    color: _isDarkTheme ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: _isDarkTheme ? Colors.white54 : Colors.black54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Divider between buttons to create a segmented look
  Widget _buildDivider() {
    return Divider(
      color: _isDarkTheme ? Colors.grey[700] : Colors.grey[300],
      thickness: 1,
      height: 1,
    );
  }

  Widget _buildCenteredButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed, // Handle taps
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: _isDarkTheme ? Colors.grey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: GoogleFonts.roboto(
                color: _isDarkTheme ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: _isDarkTheme ? Colors.white54 : Colors.black54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelection(AppLocalizations appLocalizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appLocalizations.language,
          style: GoogleFonts.roboto(
            color: _isDarkTheme ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          appLocalizations.languageDescription,
          style: GoogleFonts.roboto(
            color: _isDarkTheme ? Colors.white70 : Colors.black87,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            _showLanguageSelectionDialog();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: _isDarkTheme ? Colors.grey[900] : Colors.grey[200],
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedLanguageCode == 'en' ? appLocalizations.english : appLocalizations.turkish, // adjust based on languages you support
                  style: GoogleFonts.roboto(
                    color: _isDarkTheme ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: _isDarkTheme ? Colors.white54 : Colors.black54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showLanguageSelectionDialog() {
    final appLocalizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(appLocalizations.language),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(appLocalizations.english),
                onTap: () {
                  _changeLanguage('en');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text(appLocalizations.turkish),
                onTap: () {
                  _changeLanguage('tr');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeSelection(AppLocalizations appLocalizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appLocalizations.theme,
          style: GoogleFonts.roboto(
            color: _isDarkTheme ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          appLocalizations.themeDescription,
          style: GoogleFonts.roboto(
            color: _isDarkTheme ? Colors.white70 : Colors.black87,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            _showThemeSelectionDialog(appLocalizations);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: _isDarkTheme ? Colors.grey[900] : Colors.grey[200],
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isDarkTheme ? appLocalizations.dark : appLocalizations.light,
                  style: GoogleFonts.roboto(
                    color: _isDarkTheme ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: _isDarkTheme ? Colors.white54 : Colors.black54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showThemeSelectionDialog(AppLocalizations appLocalizations) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(appLocalizations.theme),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(appLocalizations.light),
                onTap: () {
                  _changeTheme('light');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text(appLocalizations.dark),
                onTap: () {
                  _changeTheme('dark');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Displays the Edit Profile dialog
  void _showEditProfileDialog(User user) {
    final appLocalizations = AppLocalizations.of(context)!;
    final TextEditingController nameController = TextEditingController(
      text: _userData != null && _userData!['username'] != null
          ? _userData!['username']
          : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(appLocalizations.editProfile,
              style: TextStyle(
                  color: _isDarkTheme ? Colors.white : Colors.black)),
          backgroundColor:
          _isDarkTheme ? const Color(0xFF2D2F2E) : Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 16, // En fazla 16 karakter
                style: TextStyle(
                    color: _isDarkTheme ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: appLocalizations.username,
                  labelStyle: TextStyle(
                      color: _isDarkTheme ? Colors.white : Colors.black),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color:
                        _isDarkTheme ? Colors.white54 : Colors.black54),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: _isDarkTheme ? Colors.white : Colors.black),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  counterText: '', // Karakter sayacı gizlemek için
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text(
                appLocalizations.cancel,
                style: TextStyle(
                    color: _isDarkTheme ? Colors.white : Colors.black),
              ),
            ),
            TextButton(
              onPressed: () async {
                bool hasInternet = await _hasInternetConnection();
                if (!hasInternet) {
                  // İnternet yoksa uyarı bildirimi göster
                  Navigator.of(context).pop(); // Close dialog
                  _notificationService.showCustomNotification(
                    message: appLocalizations.noInternetConnection,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    beginOffset: const Offset(0, 1.0),
                    endOffset: const Offset(0, 0.4),
                    duration: const Duration(seconds: 2),
                    width: 250.0,
                  );
                  return;
                }

                String newName = nameController.text.trim();
                if (newName.isEmpty) {
                  // Handle empty input
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appLocalizations.invalidUsername),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (newName.length > 16) {
                  // Handle username length exceeding 16
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appLocalizations.usernameTooLong),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                try {
                  // Check if username is available
                  bool isAvailable = await _isUsernameAvailable(newName);
                  if (!isAvailable) {
                    // Username is taken, show a SnackBar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(appLocalizations.usernameTaken),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Update username in Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({'username': newName});

                  // Update usernames collection
                  if (_userData != null && _userData!['username'] != null) {
                    await FirebaseFirestore.instance
                        .collection('usernames')
                        .doc(_userData!['username'])
                        .delete();
                  }

                  await FirebaseFirestore.instance
                      .collection('usernames')
                      .doc(newName)
                      .set({'userId': user.uid});

                  // Fetch the updated user data
                  await _fetchUserData();

                  Navigator.of(context).pop(); // Close dialog
                  // Show a success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appLocalizations.profileUpdated),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  // Handle errors if necessary
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appLocalizations.updateFailed),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(
                appLocalizations.save,
                style: TextStyle(
                    color: _isDarkTheme ? Colors.white : Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Checks if the username is available
  Future<bool> _isUsernameAvailable(String username) async {
    final result = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(username)
        .get();
    return !result.exists;
  }

  /// Displays the Change Password dialog
  void _showChangePasswordDialog() {
    final appLocalizations = AppLocalizations.of(context)!;
    final TextEditingController oldPasswordController =
    TextEditingController();
    final TextEditingController newPasswordController =
    TextEditingController();
    final TextEditingController confirmPasswordController =
    TextEditingController();

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            // To manage state within the dialog
              builder: (context, setState) {
                bool isLoading = false;
                String? errorText;

                return AlertDialog(
                  title: Text(appLocalizations.changePassword,
                      style: TextStyle(
                          color: _isDarkTheme ? Colors.white : Colors.black)),
                  backgroundColor:
                  _isDarkTheme ? const Color(0xFF2D2F2E) : Colors.white,
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: oldPasswordController,
                          obscureText: true,
                          style: TextStyle(
                              color: _isDarkTheme ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: appLocalizations.oldPassword,
                            labelStyle: TextStyle(
                                color:
                                _isDarkTheme ? Colors.white : Colors.black),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: _isDarkTheme
                                      ? Colors.white54
                                      : Colors.black54),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: _isDarkTheme ? Colors.white : Colors.black),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: newPasswordController,
                          obscureText: true,
                          maxLength: 64, // En fazla 64 karakter
                          style: TextStyle(
                              color: _isDarkTheme ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: appLocalizations.newPassword,
                            labelStyle: TextStyle(
                                color:
                                _isDarkTheme ? Colors.white : Colors.black),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: _isDarkTheme
                                      ? Colors.white54
                                      : Colors.black54),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: _isDarkTheme ? Colors.white : Colors.black),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            counterText: '', // Karakter sayacı gizlemek için
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          maxLength: 64, // En fazla 64 karakter
                          style: TextStyle(
                              color: _isDarkTheme ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: appLocalizations.confirmPassword,
                            labelStyle: TextStyle(
                                color:
                                _isDarkTheme ? Colors.white : Colors.black),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: _isDarkTheme
                                      ? Colors.white54
                                      : Colors.black54),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: _isDarkTheme ? Colors.white : Colors.black),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            counterText: '', // Karakter sayacı gizlemek için
                          ),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            errorText,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                        Navigator.of(context).pop(); // Close dialog
                      },
                      child: Text(
                        appLocalizations.cancel,
                        style: TextStyle(
                            color: _isDarkTheme ? Colors.white : Colors.black),
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                        bool hasInternet = await _hasInternetConnection();
                        if (!hasInternet) {
                          // İnternet yoksa uyarı bildirimi göster
                          Navigator.of(context).pop(); // Close dialog
                          _notificationService.showCustomNotification(
                            message: appLocalizations.noInternetConnection,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                            beginOffset: const Offset(0, 1.0),
                            endOffset: const Offset(0, 0.4),
                            duration: const Duration(seconds: 2),
                            width: 250.0,
                          );
                          return;
                        }

                        String oldPassword =
                        oldPasswordController.text.trim();
                        String newPassword =
                        newPasswordController.text.trim();
                        String confirmPassword =
                        confirmPasswordController.text.trim();

                        if (oldPassword.isEmpty ||
                            newPassword.isEmpty ||
                            confirmPassword.isEmpty) {
                          setState(() {
                            errorText =
                                appLocalizations.allFieldsRequired;
                          });
                          return;
                        }

                        if (newPassword.length > 64) {
                          setState(() {
                            errorText =
                                appLocalizations.passwordTooLong;
                          });
                          return;
                        }

                        if (newPassword != confirmPassword) {
                          setState(() {
                            errorText =
                                appLocalizations.passwordsDoNotMatch;
                          });
                          return;
                        }

                        setState(() {
                          isLoading = true;
                          errorText = null;
                        });

                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            setState(() {
                              errorText =
                                  appLocalizations.userNotFound;
                              isLoading = false;
                            });
                            return;
                          }

                          // Re-authenticate the user
                          AuthCredential credential =
                          EmailAuthProvider.credential(
                            email: user.email!,
                            password: oldPassword,
                          );

                          await user.reauthenticateWithCredential(credential);

                          // Update the password
                          await user.updatePassword(newPassword);

                          setState(() {
                            isLoading = false;
                          });

                          Navigator.of(context).pop(); // Close dialog
                          // Show a success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                              Text(appLocalizations.passwordUpdated),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } on FirebaseAuthException catch (e) {
                          setState(() {
                            isLoading = false;
                            if (e.code == 'wrong-password') {
                              errorText =
                                  appLocalizations.wrongPassword;
                            } else if (e.code == 'weak-password') {
                              errorText =
                                  appLocalizations.weakPassword;
                            } else {
                              errorText = e.message;
                            }
                          });
                        } catch (e) {
                          setState(() {
                            isLoading = false;
                            errorText =
                                appLocalizations.updateFailed;
                          });
                        }
                      },
                      child: isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color:
                          _isDarkTheme ? Colors.white : Colors.black,
                          strokeWidth: 2.0,
                        ),
                      )
                          : Text(
                        appLocalizations.save,
                        style: TextStyle(
                            color: _isDarkTheme ? Colors.white : Colors.black),
                      ),
                    ),
                  ],
                );
              });
        });
  }
}

class AnimatedBorderPainter extends CustomPainter {
  final double animationValue;
  final bool isDarkTheme;

  AnimatedBorderPainter({
    required this.animationValue,
    required this.isDarkTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double strokeWidth = 2.0;
    Rect rect = Offset.zero & size;
    double radius = size.width / 2;

    Paint paint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.indigo,
          Colors.purple,
          Colors.red,
        ],
        startAngle: 0.0,
        endAngle: 2 * pi,
        transform: GradientRotation(animationValue),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(Offset(radius, radius), radius - strokeWidth / 2, paint);
  }

  @override
  bool shouldRepaint(covariant AnimatedBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDarkTheme != isDarkTheme;
  }
}

/// Updated SkeletonLoader widget using Shimmer
class SkeletonLoaderShimmer extends StatelessWidget {
  final bool isDarkTheme;

  const SkeletonLoaderShimmer({Key? key, required this.isDarkTheme}) : super(key: key);

  Widget _buildCircle(double size) {
    return Shimmer.fromColors(
      baseColor: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDarkTheme ? Colors.grey[600]! : Colors.grey[100]!,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildSkeletonSection({
    required double width,
    required double height,
    double radius = 8.0,
  }) {
    return Shimmer.fromColors(
      baseColor: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDarkTheme ? Colors.grey[600]! : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildSkeletonBadge() {
    return Shimmer.fromColors(
      baseColor: isDarkTheme ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDarkTheme ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isDarkTheme ? Colors.grey[800] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            _buildSkeletonSection(width: 20, height: 20, radius: 10),
            const SizedBox(width: 8),
            _buildSkeletonSection(width: 30, height: 14, radius: 7),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonButton() {
    return Shimmer.fromColors(
      baseColor: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDarkTheme ? Colors.grey[600]! : Colors.grey[100]!,
      child: Container(
        width: double.infinity,
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }

  Widget _buildSkeletonSettingsButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {},
          child: Shimmer.fromColors(
            baseColor: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
            highlightColor: isDarkTheme ? Colors.grey[600]! : Colors.grey[100]!,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildSkeletonSection(width: 24, height: 24),
                      const SizedBox(width: 16),
                      _buildSkeletonSection(width: 100, height: 16),
                    ],
                  ),
                  _buildSkeletonSection(width: 16, height: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Divider(
          color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
          thickness: 1,
          height: 1,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Profile Header Skeleton
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCircle(100),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonSection(width: 150, height: 32), // Display Name Skeleton
                  const SizedBox(height: 8),
                  _buildSkeletonSection(width: 200, height: 16), // Email Skeleton
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSkeletonBadge(),
                      const SizedBox(width: 10),
                      _buildSkeletonBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // User Section Skeleton
        _buildSkeletonSection(width: 40, height: 24), // Kullanıcı Başlığı
        const SizedBox(height: 8),
        _buildSkeletonSection(width: 250, height: 14), // Kullanıcı Açıklaması
        const SizedBox(height: 8),
        _buildSkeletonSection(width: 250, height: 14), // Kullanıcı Açıklaması
        const SizedBox(height: 16),
        _buildSkeletonButton(),
        _buildSkeletonButton(),
        _buildSkeletonButton(),
        const SizedBox(height: 26),

        // Language Selection Skeleton
        _buildSkeletonSection(width: 40, height: 24), // Dil Başlığı
        const SizedBox(height: 10),
        _buildSkeletonSection(width: 200, height: 14), // Dil Açıklaması
        const SizedBox(height: 8),
        _buildSkeletonSection(width: 200, height: 14), // Dil Açıklaması
        const SizedBox(height: 6),
        _buildSkeletonButton(),
        const SizedBox(height: 18),

        // Theme Selection Skeleton
        _buildSkeletonSection(width: 40, height: 24), // Tema Başlığı
        const SizedBox(height: 8),
        _buildSkeletonSection(width: 200, height: 14), // Tema Açıklaması
        const SizedBox(height: 8),
        _buildSkeletonSection(width: 200, height: 14), // Tema Açıklaması
        const SizedBox(height: 8),
        _buildSkeletonSection(width: 200, height: 14), // Tema Açıklaması
        const SizedBox(height: 16),
        _buildSkeletonButton(),
        const SizedBox(height: 20),

        // Settings Section Skeleton
        _buildSkeletonSection(width: 600, height: 24), // Ayarlar Başlığı
        const SizedBox(height: 8),
        _buildSkeletonSection(width: 200, height: 14),
        const SizedBox(height: 8),
        _buildSkeletonSection(width: 200, height: 14), // Ayarlar Açıklaması
        const SizedBox(height: 16),
        _buildSkeletonSettingsButton(),
        _buildSkeletonSettingsButton(),
        _buildSkeletonSettingsButton(),
        _buildSkeletonSettingsButton(),
        _buildSkeletonSettingsButton(),
        _buildSkeletonSettingsButton(),
      ],
    );
  }
}
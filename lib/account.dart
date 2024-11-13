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
import 'package:skeletonizer/skeletonizer.dart'; // Updated import

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _selectedLanguageCode = 'en';
  bool _isDarkTheme = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _fetchUserData();

    // Get initial selected language and theme
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    if (locale != null) {
      _selectedLanguageCode = locale.languageCode;
    }
  }

  Future<void> _fetchUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      setState(() {
        _userData = userDoc.data() as Map<String, dynamic>?;
      });
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    });
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

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context)!;

    // Determine the display name
    String displayName;
    if (_userData != null && _userData!['username'] != null) {
      displayName = _userData!['username'];
    } else {
      displayName = FirebaseAuth.instance.currentUser?.email ?? '';
    }

    return Scaffold(
      backgroundColor: _isDarkTheme ? const Color(0xFF141414) : Colors.white,
      appBar: AppBar(
        title: Text(
          appLocalizations.settings,
          style:
          GoogleFonts.roboto(color: _isDarkTheme ? Colors.white : Colors.black),
        ),
        backgroundColor: _isDarkTheme ? const Color(0xFF141414) : Colors.white,
        elevation: 0,
        iconTheme:
        IconThemeData(color: _isDarkTheme ? Colors.white : Colors.black),
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
            ? Skeletonizer(
          key: const ValueKey('skeleton'),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Profile Avatar Skeleton
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color:
                    _isDarkTheme ? Colors.grey[800] : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 16),
                // Username Skeleton
                Container(
                  width: 150,
                  height: 24,
                  color: _isDarkTheme
                      ? Colors.grey[700]
                      : Colors.grey[300],
                ),
                const SizedBox(height: 16), // Reduced from 32 to 16
                // Expanded ListView to match content structure
                Expanded(
                  child: ListView(
                    children: [
                      // Button Skeletons
                      _buildSkeletonButton(),
                      const SizedBox(height: 10),
                      _buildSkeletonButton(),
                      const SizedBox(height: 10),
                      _buildSkeletonButton(),
                      const SizedBox(height: 30),
                      // Section Header Skeleton
                      Container(
                        width: 100,
                        height: 22,
                        color: _isDarkTheme
                            ? Colors.grey[700]
                            : Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      // Language Selection Skeleton
                      _buildSkeletonOption(),
                      const SizedBox(height: 30),
                      // Theme Section Header Skeleton
                      Container(
                        width: 100,
                        height: 22,
                        color: _isDarkTheme
                            ? Colors.grey[700]
                            : Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      // Theme Selection Skeleton
                      _buildSkeletonOption(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            : Padding(
          key: const ValueKey('content'),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildProfileHeader(displayName),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildCenteredButton(
                      context: context,
                      text: appLocalizations.editProfile,
                      icon: Icons.edit,
                      onPressed: () {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          _showEditProfileDialog(user);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildCenteredButton(
                      context: context,
                      text: appLocalizations.changePassword,
                      icon: Icons.lock,
                      onPressed: () {
                        _showChangePasswordDialog();
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
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    _buildSectionHeader(appLocalizations.language),
                    const SizedBox(height: 8),
                    _buildLanguageSelection(appLocalizations),
                    const SizedBox(height: 30),
                    _buildSectionHeader(appLocalizations.theme),
                    const SizedBox(height: 8),
                    _buildThemeSelection(appLocalizations),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a skeleton button using Skeletonizer
  Widget _buildSkeletonButton() {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      decoration: BoxDecoration(
        color: _isDarkTheme ? Colors.grey[700] : Colors.grey[300],
        borderRadius: BorderRadius.circular(12.0),
      ),
    );
  }

  /// Builds a skeleton option (e.g., language or theme)
  Widget _buildSkeletonOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: _isDarkTheme ? Colors.grey[700] : Colors.grey[300],
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        Container(
          width: 80,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: _isDarkTheme ? Colors.grey[700] : Colors.grey[300],
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(String displayName) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor:
          _isDarkTheme ? Colors.grey[800] : Colors.grey[300],
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '',
            style: TextStyle(
              fontSize: 40,
              color: _isDarkTheme ? Colors.white : Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: GoogleFonts.poppins(
            color: _isDarkTheme ? Colors.white : Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCenteredButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          foregroundColor: _isDarkTheme ? Colors.white : Colors.black,
          backgroundColor:
          _isDarkTheme ? const Color(0xFF1B1B1B) : Colors.white,
          minimumSize: const Size(double.infinity, 50),
          side: BorderSide(
            color: _isDarkTheme ? Colors.white54 : Colors.black54,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        icon: Icon(icon, color: _isDarkTheme ? Colors.white : Colors.black),
        label: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 16.0,
            fontWeight: FontWeight.w500,
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: GoogleFonts.roboto(
            color: _isDarkTheme ? Colors.white : Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 0),
        Divider(
          color: _isDarkTheme ? Colors.white54 : Colors.black54,
          thickness: 1,
          indent: 100,
          endIndent: 100,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLanguageSelection(AppLocalizations localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAnimatedLanguageButton(
          languageCode: 'en',
          languageName: localizations.english,
        ),
        const SizedBox(width: 16),
        _buildAnimatedLanguageButton(
          languageCode: 'tr',
          languageName: localizations.turkish,
        ),
      ],
    );
  }

  Widget _buildThemeSelection(AppLocalizations localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAnimatedThemeButton(
          theme: 'light',
          themeName: localizations.light,
        ),
        const SizedBox(width: 16),
        _buildAnimatedThemeButton(
          theme: 'dark',
          themeName: localizations.dark,
        ),
      ],
    );
  }

  Widget _buildAnimatedLanguageButton({
    required String languageCode,
    required String languageName,
  }) {
    bool isSelected = _selectedLanguageCode == languageCode;

    return GestureDetector(
      onTap: () => _changeLanguage(languageCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
        const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isDarkTheme ? Colors.white : Colors.black)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (_isDarkTheme
                ? const Color(0xFFEAEAEA)
                : const Color(0xFF141414)),
            width: 1.5,
          ),
        ),
        child: Text(
          languageName,
          style: GoogleFonts.poppins(
            color: isSelected
                ? (_isDarkTheme ? Colors.black : Colors.white)
                : (_isDarkTheme ? Colors.white : Colors.black),
            fontSize: 16.0,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedThemeButton({
    required String theme,
    required String themeName,
  }) {
    bool isSelected =
        (_isDarkTheme && theme == 'dark') || (!_isDarkTheme && theme == 'light');

    return GestureDetector(
      onTap: () => _changeTheme(theme),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
        const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isDarkTheme ? Colors.white : Colors.black)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (_isDarkTheme
                ? const Color(0xFFEAEAEA)
                : const Color(0xFF141414)),
            width: 1.5,
          ),
        ),
        child: Text(
          themeName,
          style: GoogleFonts.poppins(
            color: isSelected
                ? (_isDarkTheme ? Colors.black : Colors.white)
                : (_isDarkTheme ? Colors.white : Colors.black),
            fontSize: 16.0,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Displays the Edit Profile dialog
  void _showEditProfileDialog(User user) {
    final appLocalizations = AppLocalizations.of(context)!;
    final TextEditingController _nameController = TextEditingController(
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
                controller: _nameController,
                style: TextStyle(
                    color: _isDarkTheme ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: appLocalizations.username,
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
                        color:
                        _isDarkTheme ? Colors.white : Colors.black),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
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
                String newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
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
                    if (_userData != null &&
                        _userData!['username'] != null) {
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
                } else {
                  // Handle empty input if necessary
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appLocalizations.invalidUsername),
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
    final TextEditingController _oldPasswordController =
    TextEditingController();
    final TextEditingController _newPasswordController =
    TextEditingController();
    final TextEditingController _confirmPasswordController =
    TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // To manage state within the dialog
          builder: (context, setState) {
            bool _isLoading = false;
            String? _errorText;

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
                      controller: _oldPasswordController,
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
                              color:
                              _isDarkTheme ? Colors.white : Colors.black),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
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
                              color:
                              _isDarkTheme ? Colors.white : Colors.black),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
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
                              color:
                              _isDarkTheme ? Colors.white : Colors.black),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isLoading
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
                  onPressed: _isLoading
                      ? null
                      : () async {
                    String oldPassword =
                    _oldPasswordController.text.trim();
                    String newPassword =
                    _newPasswordController.text.trim();
                    String confirmPassword =
                    _confirmPasswordController.text.trim();

                    if (oldPassword.isEmpty ||
                        newPassword.isEmpty ||
                        confirmPassword.isEmpty) {
                      setState(() {
                        _errorText =
                            appLocalizations.allFieldsRequired;
                      });
                      return;
                    }

                    if (newPassword != confirmPassword) {
                      setState(() {
                        _errorText =
                            appLocalizations.passwordsDoNotMatch;
                      });
                      return;
                    }

                    setState(() {
                      _isLoading = true;
                      _errorText = null;
                    });

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        setState(() {
                          _errorText =
                              appLocalizations.userNotFound;
                          _isLoading = false;
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
                        _isLoading = false;
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
                        _isLoading = false;
                        if (e.code == 'wrong-password') {
                          _errorText =
                              appLocalizations.wrongPassword;
                        } else if (e.code == 'weak-password') {
                          _errorText =
                              appLocalizations.weakPassword;
                        } else {
                          _errorText = e.message;
                        }
                      });
                    } catch (e) {
                      setState(() {
                        _isLoading = false;
                        _errorText =
                            appLocalizations.updateFailed;
                      });
                    }
                  },
                  child: _isLoading
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
                        color:
                        _isDarkTheme ? Colors.white : Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

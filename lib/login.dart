// login.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import 'package:email_validator/email_validator.dart'; // Added for email validation
import 'dart:async'; // Import for Timer

import 'main.dart';
import 'theme.dart'; // ThemeProvider'ı import ettik

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

enum AuthMode { login, register }

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  AuthMode _authMode = AuthMode.login;

  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String _username = ''; // Yeni değişken
  String _errorMessage = '';

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false; // Yeni durum değişkeni

  bool _showComingSoon = false; // For "Coming Soon" message

  late AnimationController _animationController;
  late Animation<double> _animation;

  // Added for "Coming Soon" animation
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);

    // Initialize the AnimationController for "Coming Soon" message
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Define the slide animation for "Coming Soon" message from bottom to up
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Define the fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0, // Fully transparent
      end: 1.0,   // Fully opaque
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
  }

  Future<void> _loadUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool rememberMe = prefs.getBool('remember_me') ?? false;
    String email = prefs.getString('email') ?? '';
    if (rememberMe && email.isNotEmpty) {
      setState(() {
        _rememberMe = rememberMe;
        _email = email;
      });
    }
  }

  Future<void> _saveUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('email', _email);
    } else {
      await prefs.setBool('remember_me', false);
      await prefs.remove('email');
    }
  }

  Future<bool> _isUsernameAvailable(String username) async {
    final result = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(username)
        .get();
    return !result.exists;
  }

  void _switchAuthMode() {
    setState(() {
      _authMode =
      _authMode == AuthMode.login ? AuthMode.register : AuthMode.login;
      _errorMessage = ''; // Hata mesajını sıfırla
      if (_authMode == AuthMode.register) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _submit() async {
    final appLocalizations = AppLocalizations.of(context)!;
    FormState? form = _authMode == AuthMode.login
        ? _loginFormKey.currentState
        : _registerFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    form.save();

    if (_authMode == AuthMode.register && _password != _confirmPassword) {
      setState(() {
        _errorMessage = appLocalizations.passwordsDoNotMatch;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      UserCredential userCredential;
      if (_authMode == AuthMode.login) {
        userCredential = await _auth.signInWithEmailAndPassword(
            email: _email, password: _password);
      } else {
        // Kullanıcı adı mevcut mu kontrol et
        bool isAvailable = await _isUsernameAvailable(_username);
        if (!isAvailable) {
          setState(() {
            _errorMessage = appLocalizations.usernameTaken;
            _isLoading = false;
          });
          return;
        }

        // Yeni kullanıcı oluştur
        userCredential = await _auth.createUserWithEmailAndPassword(
            email: _email, password: _password);

        // Firestore'a kullanıcı bilgilerini ekle
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'username': _username,
          'email': _email,
          'hasVertexPlus': false, // Varsayılan olarak false
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Usernames koleksiyonuna ekleme
        await FirebaseFirestore.instance
            .collection('usernames')
            .doc(_username)
            .set({
          'userId': userCredential.user!.uid,
        });
      }
      await _saveUserEmail();

      // Updated navigation code to remove previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MainScreen(key: mainScreenKey)),
            (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (error) {
      String message = '';
      switch (error.code) {
        case 'user-not-found':
          message = appLocalizations.userNotFound;
          break;
        case 'wrong-password':
          message = appLocalizations.wrongPassword;
          break;
        case 'email-already-in-use':
          message = appLocalizations.emailAlreadyInUse;
          break;
        case 'weak-password':
          message = appLocalizations.weakPassword;
          break;
        case 'invalid-email':
          message = appLocalizations.invalidEmail;
          break;
        default:
          message = '${appLocalizations.authError}: ${error.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (error) {
      setState(() {
        _errorMessage = '${appLocalizations.authError}: $error';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Method to show "Coming Soon" message
  void _showComingSoonMessage() {
    setState(() {
      _showComingSoon = true;
    });
    _animationController.forward();

    // Hide the message after 2 seconds
    Timer(const Duration(seconds: 2), () {
      _animationController.reverse().then((value) {
        setState(() {
          _showComingSoon = false;
        });
      });
    });
  }

  Widget _buildAuthForm() {
    final appLocalizations = AppLocalizations.of(context)!;
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      // Assign a unique key based on the auth mode to trigger the animation
      key: ValueKey<AuthMode>(_authMode),
      child: Form(
        key: _authMode == AuthMode.login ? _loginFormKey : _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _authMode == AuthMode.login
                  ? appLocalizations.loginToYourAccount
                  : appLocalizations.createYourAccount,
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 40),
            if (_authMode == AuthMode.register)
            // Username Field
              Column(
                children: [
                  TextFormField(
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor:
                      _isDarkTheme ? const Color(0xFF1b1b1b) : Colors.grey[200],
                      labelText: appLocalizations.username,
                      labelStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color),
                      prefixIcon:
                      Icon(Icons.person, color: Theme.of(context).iconTheme.color),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                    validator: _authMode == AuthMode.register
                        ? (value) {
                      if (value == null || value.isEmpty) {
                        return appLocalizations.invalidUsername;
                      }
                      if (value.length < 3) {
                        return 'Kullanıcı adı en az 3 karakter olmalı.';
                      }
                      return null;
                    }
                        : null,
                    onSaved: (value) {
                      _username = value!.trim();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            TextFormField(
              initialValue: _email,
              style:
              TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                filled: true,
                fillColor:
                _isDarkTheme ? const Color(0xFF1b1b1b) : Colors.grey[200],
                labelText: appLocalizations.email,
                labelStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color),
                prefixIcon:
                Icon(Icons.email, color: Theme.of(context).iconTheme.color),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return appLocalizations.invalidEmail;
                }
                if (!EmailValidator.validate(value.trim())) {
                  return appLocalizations.invalidEmail;
                }
                return null;
              },
              onSaved: (value) {
                _email = value!.trim();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              style:
              TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                filled: true,
                fillColor:
                _isDarkTheme ? const Color(0xFF1b1b1b) : Colors.grey[200],
                labelText: appLocalizations.password,
                labelStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color),
                prefixIcon:
                Icon(Icons.lock_outline, color: Theme.of(context).iconTheme.color),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              obscureText: !_isPasswordVisible,
              validator: (value) {
                if (value == null || value.isEmpty || value.length < 6) {
                  return appLocalizations.invalidPassword;
                }
                return null;
              },
              onSaved: (value) {
                _password = value!.trim();
              },
            ),
            const SizedBox(height: 16),
            if (_authMode == AuthMode.register)
            // Confirm Password Field
              Column(
                children: [
                  TextFormField(
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor:
                      _isDarkTheme ? const Color(0xFF1b1b1b) : Colors.grey[200],
                      labelText: appLocalizations.confirmPassword,
                      labelStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color),
                      prefixIcon: Icon(Icons.lock_outline,
                          color: Theme.of(context).iconTheme.color),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                    obscureText: !_isConfirmPasswordVisible,
                    validator: _authMode == AuthMode.register
                        ? (value) {
                      if (value == null ||
                          value.isEmpty ||
                          value.length < 6) {
                        return appLocalizations.invalidPassword;
                      }
                      return null;
                    }
                        : null,
                    onSaved: (value) {
                      _confirmPassword = value!.trim();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      checkColor: _isDarkTheme ? Colors.black : Colors.white,
                      activeColor: _isDarkTheme ? Colors.white : Colors.black,
                    ),
                    Text(appLocalizations.rememberMe,
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            AnimatedOpacity(
              opacity: _isLoading ? 0.7 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDarkTheme ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: Text(
                    _authMode == AuthMode.login
                        ? appLocalizations.logIn
                        : appLocalizations.signUp,
                    style: TextStyle(
                        fontSize: 18,
                        color: _isDarkTheme ? Colors.black : Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: Divider(
                        color: _isDarkTheme ? Colors.grey[700] : Colors.grey[400])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(appLocalizations.or,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                ),
                Expanded(
                    child: Divider(
                        color: _isDarkTheme ? Colors.grey[700] : Colors.grey[400])),
              ],
            ),
            const SizedBox(height: 16),
            // Google Sign-In Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDarkTheme ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  // Show "Coming Soon" message
                  _showComingSoonMessage();
                },
                icon: Icon(Icons.g_mobiledata,
                    color: _isDarkTheme ? Colors.black : Colors.white),
                label: Text(
                  appLocalizations.continueWithGoogle,
                  style: TextStyle(
                      color: _isDarkTheme ? Colors.black : Colors.white,
                      fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _switchAuthMode,
              child: Text(
                _authMode == AuthMode.login
                    ? appLocalizations.dontHaveAccount
                    : appLocalizations.alreadyHaveAccount,
                style: TextStyle(
                    fontSize: 16, color: _isDarkTheme ? Colors.blue : Colors.blue),
              ),
            ),
            if (_errorMessage.isNotEmpty)
              AnimatedOpacity(
                opacity: _errorMessage.isNotEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose(); // Dispose the AnimationController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildAuthForm(),
            ),
          ),
          // Overlay for the "Coming Soon" message
          if (_showComingSoon)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.032, // Positioned at the bottom
              left: MediaQuery.of(context).size.width * 0.32,
              right: MediaQuery.of(context).size.width * 0.32,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 20.0),
                      decoration: BoxDecoration(
                        color: _isDarkTheme ? Colors.white : Colors.black,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.comingSoon,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isDarkTheme ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
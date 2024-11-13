import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import localization
import 'theme.dart'; // Import ThemeProvider
import 'dart:async'; // Import for Timer

class PremiumScreen extends StatefulWidget {
  @override
  _PremiumScreenState createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  String selectedOption = 'monthly'; // Default to 'monthly'

  // Animation variables
  bool _showComingSoon = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize the AnimationController with shorter duration
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Adjusted duration for combined animations
    );

    // Define the slide animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5), // Start slightly above the target position
      end: const Offset(0, 0), // End at the target position
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Define the fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0, // Fully transparent
      end: 1.0, // Fully opaque
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    // Dispose the AnimationController
    _animationController.dispose();
    super.dispose();
  }

  void _showComingSoonMessage(bool isDarkTheme) {
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final _isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    return Scaffold(
      backgroundColor: _isDarkTheme ? const Color(0xFF090909) : Colors.white,
      body: Stack(
        children: [
          _buildPremiumContent(context, localizations, _isDarkTheme),
          // Overlay for the "Coming Soon" message
          if (_showComingSoon)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.072, // Move it closer to the top
              left: MediaQuery.of(context).size.width * 0.32, // Adjusted for better centering
              right: MediaQuery.of(context).size.width * 0.32,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
                      decoration: BoxDecoration(
                        color: _isDarkTheme ? Colors.white : Colors.black,
                        borderRadius: BorderRadius.circular(8.0), // Slightly smaller corner radius
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
                          localizations.comingSoon,
                          style: TextStyle(
                            fontSize: 14, // Smaller font size
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

  Widget _buildPremiumContent(
      BuildContext context, AppLocalizations localizations, bool _isDarkTheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(Icons.close,
                      color: _isDarkTheme ? Colors.white : Colors.black),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 15),
            Center(
              child: Column(
                children: [
                  Text(
                    localizations.purchasePremium,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _isDarkTheme ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    localizations.premiumDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color:
                      _isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Image.asset(
                    'assets/vertexailogo.png',
                    height: 90,
                  ),
                  const SizedBox(height: 20),
                  _buildSubscriptionOption(
                    context: context,
                    localizations: localizations,
                    title: localizations.annual,
                    description: localizations.annualDescription,
                    isBestValue: true,
                    isDarkTheme: _isDarkTheme,
                    isSelected: selectedOption == 'annual',
                    onSelect: () {
                      setState(() {
                        selectedOption = 'annual';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSubscriptionOption(
                    context: context,
                    localizations: localizations,
                    title: localizations.monthly,
                    description: localizations.monthlyDescription,
                    isDarkTheme: _isDarkTheme,
                    isSelected: selectedOption == 'monthly',
                    onSelect: () {
                      setState(() {
                        selectedOption = 'monthly';
                      });
                    },
                  ),
                  const SizedBox(height: 25),
                  Center(
                    child: _buildBenefitsList(localizations, _isDarkTheme),
                  ),
                  const SizedBox(height: 25),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: ElevatedButton(
                      key: ValueKey<String>(selectedOption),
                      onPressed: () {
                        // Trigger the "Coming Soon" message
                        _showComingSoonMessage(_isDarkTheme);
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor:
                        _isDarkTheme ? Colors.black : Colors.white,
                        backgroundColor:
                        _isDarkTheme ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 52),
                      ),
                      child: Text(
                        selectedOption == 'annual'
                            ? localizations.startFreeTrial30Days
                            : localizations.startFreeTrial7Days,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color:
                          _isDarkTheme ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Text(
                      localizations.termsAndConditions,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isDarkTheme
                            ? Colors.grey[600]
                            : Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOption({
    required BuildContext context,
    required AppLocalizations localizations,
    required String title,
    required String description,
    bool isBestValue = false,
    required bool isDarkTheme,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF1B1B1B) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: isDarkTheme ? Colors.white : Colors.black, width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkTheme ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                if (isBestValue)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 3, horizontal: 6),
                    child: Text(
                      localizations.bestValue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color:
                isDarkTheme ? Colors.white : Colors.black, // Updated colors
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsList(AppLocalizations localizations, bool isDarkTheme) {
    // Adding 8 benefits
    final benefits = [
      localizations.benefit1,
      localizations.benefit2,
      localizations.benefit3,
      localizations.benefit4,
      localizations.benefit5, // New benefit
      localizations.benefit6, // New benefit
      localizations.benefit7, // New benefit
      localizations.benefit8, // New benefit
    ];

    // Arranging benefits in rows of two
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate((benefits.length / 2).ceil(), (index) {
        // Handle even and odd number of benefits
        final firstBenefit = benefits[index * 2];
        final secondBenefit =
        (index * 2 + 1) < benefits.length ? benefits[index * 2 + 1] : null;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBenefitItem(firstBenefit, isDarkTheme),
              if (secondBenefit != null) ...[
                const SizedBox(width: 16), // Spacing between benefits in the same row
                _buildBenefitItem(secondBenefit, isDarkTheme),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBenefitItem(String benefit, bool isDarkTheme) {
    return Row(
      children: [
        Icon(
          Icons.check,
          color: Colors.green,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          benefit,
          style: TextStyle(
            fontSize: 14,
            color: isDarkTheme ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.left,
        ),
      ],
    );
  }
}

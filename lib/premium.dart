// premium.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Localization import
import 'theme.dart'; // ThemeProvider import
import 'dart:async'; // Timer import
import 'package:in_app_purchase/in_app_purchase.dart'; // In-App Purchase import
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth import
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore import
import 'notifications.dart'; // NotificationService import
import 'package:shimmer/shimmer.dart'; // Shimmer import

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  _PremiumScreenState createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  String selectedOption = 'monthly';

  // In-App Purchase variables
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // FirebaseAuth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Define your subscription IDs
  static const String _monthlySubscription = 'vertex_ai_monthly_sub';
  static const String _annualSubscription = 'vertex_ai_annual_sub';

  // List to store available subscriptions
  List<ProductDetails> _subscriptions = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _loading = true;

  // Subscription status
  bool _hasSubscription = false;

  // Animation variables (Removed as AnimatedSwitcher is used)

  @override
  void initState() {
    super.initState();

    // Listen to purchase updates
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        // Handle error
        _showCustomNotification(
          message: AppLocalizations.of(context)!.purchaseError,
          isSuccess: false,
        );
      },
    );

    _initializeStore();
  }

  Future<void> _initializeStore() async {
    // Check if In-App Purchases are available
    _isAvailable = await _inAppPurchase.isAvailable();
    if (!_isAvailable) {
      setState(() {
        _loading = false;
      });
      return;
    }

    // Define the subscription IDs you want to fetch
    const Set<String> kIds = <String>{
      _monthlySubscription,
      _annualSubscription,
    };

    // Fetch subscription details from the store
    final ProductDetailsResponse response =
    await _inAppPurchase.queryProductDetails(kIds);
    if (response.error != null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    if (response.productDetails.isEmpty) {
      setState(() {
        _loading = false;
      });
      return;
    }

    // Fetch user's subscription status from Firestore
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          // Update the user's subscription status
          _hasSubscription = userDoc.get('hasVertexPlus') ?? false;
        }
      } catch (e) {
        // Handle error
      }
    }

    // Set the subscription products and finish loading
    setState(() {
      _subscriptions = response.productDetails;
      _loading = false;
    });
  }

  @override
  void dispose() {
    // Dispose AnimationController and In-App Purchase subscription
    _subscription.cancel();
    super.dispose();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() {
          _purchasePending = true;
        });
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          setState(() {
            _purchasePending = false;
          });
          _showCustomNotification(
            message: AppLocalizations.of(context)!.purchaseFailed,
            isSuccess: false,
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          bool valid = _verifyPurchase(purchaseDetails);
          if (valid) {
            _deliverProduct(purchaseDetails);
          } else {
            // Invalid purchase
            _showCustomNotification(
              message: AppLocalizations.of(context)!.invalidPurchase,
              isSuccess: false,
            );
            return;
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  bool _verifyPurchase(PurchaseDetails purchaseDetails) {
    // Implement your purchase verification logic here.
    // For example, verify the purchase with your server.
    return true; // Demo purpose
  }

  void _deliverProduct(PurchaseDetails purchaseDetails) async {
    setState(() {
      _purchasePending = false;
    });

    // Update the user's subscription status in Firestore
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'hasVertexPlus': true});
        setState(() {
          _hasSubscription = true;
        });
        // Show success notification
        _showCustomNotification(
          message: AppLocalizations.of(context)!.purchaseSuccessful,
          isSuccess: true,
        );
        // Perform additional actions if needed
      } catch (e) {
        // Show error notification
        _showCustomNotification(
          message: AppLocalizations.of(context)!.updateFailed,
          isSuccess: false,
        );
      }
    }
  }

  void _buySubscription(String selectedOption) {
    // Find the selected subscription's ProductDetails
    ProductDetails? subscription;
    for (var sub in _subscriptions) {
      if (sub.id ==
          (selectedOption == 'annual'
              ? _annualSubscription
              : _monthlySubscription)) {
        subscription = sub;
        break;
      }
    }

    if (subscription == null) {
      // Notify user if subscription not found
      _showCustomNotification(
        message: AppLocalizations.of(context)!.productNotFound,
        isSuccess: false,
      );
      return;
    }

    final PurchaseParam purchaseParam =
    PurchaseParam(productDetails: subscription);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // Custom notification method using NotificationService
  void _showCustomNotification(
      {required String message, required bool isSuccess}) {
    final notificationService =
    Provider.of<NotificationService>(context, listen: false);
    notificationService.showNotification(
        message: message, isSuccess: isSuccess);
  }

  // Skeleton Loader Widget
  Widget _buildSkeletonLoader() {
    final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    return Shimmer.fromColors(
      baseColor: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDarkTheme ? Colors.grey[500]! : Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 50.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Close Button Placeholder
              Align(
                alignment: Alignment.center,
                child: Container(
                  key: const ValueKey('closeButtonSkeleton'),
                  width: 26,
                  height: 77,
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Title Placeholder
              Container(
                width: 250, // Adjusted width for title placeholder
                height: 30,
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8.0), // Softened edges
                ),
              ),
              const SizedBox(height: 10),
              // Description Placeholder
              Container(
                width: double.infinity,
                height: 20,
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8.0), // Softened edges
                ),
              ),
              const SizedBox(height: 6),
              // Description Placeholder
              Container(
                width: double.infinity,
                height: 20,
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8.0), // Softened edges
                ),
              ),
              const SizedBox(height: 10),
              // Image Placeholder
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(16.0), // Softened edges
                ),
              ),
              const SizedBox(height: 10),
              // Subscription Options Placeholders
              _buildSubscriptionPlaceholder(isDarkTheme),
              const SizedBox(height: 26),
              // Benefits List Placeholder
              _buildBenefitsPlaceholder(isDarkTheme),
              const SizedBox(height: 20),
              // Purchase Button Placeholder
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius:
                  BorderRadius.circular(30.0), // Softened edges
                ),
              ),
              const SizedBox(height: 22),
              // Terms and Conditions Placeholder
              Container(
                width: 400, // Adjusted width for terms and conditions text
                height: 14,
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius:
                  BorderRadius.circular(6.0), // Softened edges
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 400, // Adjusted width for terms and conditions text
                height: 14,
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius:
                  BorderRadius.circular(6.0), // Softened edges
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 400, // Adjusted width for terms and conditions text
                height: 14,
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius:
                  BorderRadius.circular(6.0), // Softened edges
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 400, // Adjusted width for terms and conditions text
                height: 14,
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius:
                  BorderRadius.circular(6.0), // Softened edges
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 400, // Adjusted width for terms and conditions text
                height: 14,
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius:
                  BorderRadius.circular(6.0), // Softened edges
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionPlaceholder(bool isDarkTheme) {
    return Column(
      children: [
        // Annual Subscription Placeholder
        Container(
          width: double.infinity,
          height: 85,
          decoration: BoxDecoration(
            color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
            borderRadius: BorderRadius.circular(14.0), // Softened edges
          ),
          margin: const EdgeInsets.only(bottom: 6),
        ),
        // Monthly Subscription Placeholder
        Container(
          width: double.infinity,
          height: 85,
          decoration: BoxDecoration(
            color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
            borderRadius: BorderRadius.circular(14.0), // Softened edges
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsPlaceholder(bool isDarkTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 2.5), // 5-pixel total spacing
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color:
                    isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4.0), // Softened edges
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color:
                      isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4.0), // Softened edges
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 2.5), // 5-pixel total spacing
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color:
                    isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4.0), // Softened edges
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color:
                      isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4.0), // Softened edges
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isDarkTheme = Provider.of<ThemeProvider>(context).isDarkTheme;

    return Scaffold(
      backgroundColor: isDarkTheme ? const Color(0xFF090909) : Colors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: (_purchasePending || _loading)
            ? Container(
          key: const ValueKey('skeleton'),
          child: _buildSkeletonLoader(),
        )
            : Container(
          key: const ValueKey('content'),
          child: _buildPremiumContent(context, localizations, isDarkTheme),
        ),
      ),
    );
  }

  Widget _buildPremiumContent(
      BuildContext context, AppLocalizations localizations, bool isDarkTheme) {
    return SafeArea(
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Close Button
            Align(
              alignment: Alignment.center,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDarkTheme ? Colors.white : Colors.black,
                  size: 28, // Moderately increased icon size
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: _hasSubscription
                    ? _buildSubscribedContent(
                    context, localizations, isDarkTheme)
                    : Column(
                  children: [
                    Text(
                      localizations.purchasePremium,
                      style: TextStyle(
                        fontSize: 26, // Moderately increased font size
                        fontWeight: FontWeight.bold,
                        color:
                        isDarkTheme ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      localizations.premiumDescription,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.2, // Moderately increased font size
                        color: isDarkTheme
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Image.asset(
                      'assets/vertexailogo.png',
                      height: 100, // Slightly increased image size
                    ),
                    const SizedBox(height: 20),
                    _buildSubscriptionOption(
                      context: context,
                      localizations: localizations,
                      title: localizations.annual,
                      description: localizations.annualDescription,
                      isBestValue: true,
                      isDarkTheme: isDarkTheme,
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
                      isDarkTheme: isDarkTheme,
                      isSelected: selectedOption == 'monthly',
                      onSelect: () {
                        setState(() {
                          selectedOption = 'monthly';
                        });
                      },
                    ),
                    const SizedBox(height: 25),
                    _buildBenefitsList(localizations, isDarkTheme),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: _subscriptions.isNotEmpty
                          ? () {
                        _buySubscription(selectedOption);
                      }
                          : null, // Disable button if subscriptions are not loaded
                      style: ElevatedButton.styleFrom(
                        foregroundColor:
                        isDarkTheme ? Colors.black : Colors.white,
                        backgroundColor:
                        isDarkTheme ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(30.0), // Rounded
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 50), // Moderately increased padding
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (Widget child,
                            Animation<double> animation) {
                          return FadeTransition(
                              child: child, opacity: animation);
                        },
                        child: Text(
                          selectedOption == 'annual'
                              ? localizations.startFreeTrial30Days
                              : localizations.startFreeTrial7Days,
                          key: ValueKey<String>(selectedOption),
                          style: TextStyle(
                            fontSize: 16, // Moderately increased font size
                            fontWeight: FontWeight.bold,
                            color: isDarkTheme
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () => _showTermsAndConditions(context),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12), // Rounded edges
                        ),
                      ),
                      child: Text(
                        localizations.termsAndConditions,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize:
                          12, // Moderately increased font size
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
    );
  }

  Widget _buildSubscribedContent(
      BuildContext context, AppLocalizations localizations, bool isDarkTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            localizations.alreadySubscribed,
            style: TextStyle(
              fontSize: 22, // Slightly increased font size
              fontWeight: FontWeight.bold,
              color: isDarkTheme ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 100,
          ),
          const SizedBox(height: 20),
          Container(
            constraints: BoxConstraints(
              maxWidth: 350, // Desired maximum width
            ),
            child: Text(
              localizations.alreadySubscribedMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16, // Moderately increased font size
                color: isDarkTheme ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelSubscriptionDialog(BuildContext context,
      AppLocalizations localizations, bool isDarkTheme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor:
          isDarkTheme ? const Color(0xFF1B1B1B) : Colors.white,
          title: Text(
            localizations.cancelSubscription,
            style: TextStyle(
              color: isDarkTheme ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            localizations.cancelSubscriptionInfo,
            style: TextStyle(
              color: isDarkTheme ? Colors.white : Colors.black,
            ),
          ),
        );
      },
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
          color:
          isDarkTheme ? const Color(0xFF1B1B1B) : Colors.grey[200],
          borderRadius: BorderRadius.circular(14), // Slightly rounded
          border: isSelected
              ? Border.all(
              color: isDarkTheme ? Colors.white : Colors.black,
              width: 2) // Moderate border width
              : Border.all(color: Colors.transparent, width: 2),
        ),
        padding: const EdgeInsets.all(14), // Moderately increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18, // Moderately increased font size
                      fontWeight: FontWeight.bold,
                      color: isDarkTheme ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                if (isBestValue)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius:
                      BorderRadius.circular(5), // Rounded
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 3, horizontal: 6), // Moderate padding
                    child: Text(
                      localizations.bestValue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10, // Small font size for badge
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: TextStyle(
                fontSize: 14, // Moderately increased font size
                color: isDarkTheme ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsList(
      AppLocalizations localizations, bool isDarkTheme) {
    // Define only 2 benefits as per the request
    final benefits = [
      localizations.benefit3,
      localizations.benefit1,
    ];

    // Arrange benefits side by side with a 5-pixel spacing between them
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: benefits.map((benefit) {
        return Expanded(
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 2.5), // 5-pixel total spacing
            child: _buildBenefitItem(benefit, isDarkTheme),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBenefitItem(String benefit, bool isDarkTheme) {
    return Row(
      children: [
        const Icon(
          Icons.check,
          color: Colors.green,
          size: 20, // Moderate icon size
        ),
        const SizedBox(width: 8), // Moderate spacing
        Expanded(
          child: Text(
            benefit,
            style: TextStyle(
              fontSize: 12, // Reduced font size from 14 to 12
              color: isDarkTheme ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  void _showTermsAndConditions(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isDarkTheme =
        Provider.of<ThemeProvider>(context, listen: false).isDarkTheme;
    final backgroundColor =
    isDarkTheme ? const Color(0xFF090909) : Colors.white;
    final textColor = isDarkTheme ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow scrolling if content is long
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6, // Adjusted height
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0), // Moderately increased padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizations.termsAndConditionsTitle,
                      style: TextStyle(
                        fontSize: 18, // Moderately increased font size
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: textColor.withOpacity(0.6),
                          size: 24), // Moderately increased icon size
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      localizations.termsAndConditionsContent,
                      style: TextStyle(
                        fontSize: 14, // Moderately increased font size
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
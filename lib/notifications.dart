import 'package:flutter/material.dart';

class NotificationService {
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationService({required this.navigatorKey});

  void showNotification({
    required String message,
    required bool isSuccess,
    double bottomOffset = 50.0,
    double fontSize = 16.0,
    double? maxWidth,
    double? width,
    VoidCallback? onTap,
  }) {
    _showOverlayNotification(
      message: message,
      backgroundColor: isSuccess ? Colors.green : Colors.red,
      icon: isSuccess ? Icons.check_circle : Icons.error,
      textColor: Colors.white,
      beginOffset: const Offset(0, 1.0),
      endOffset: const Offset(0, 0),
      bottomOffset: bottomOffset,
      fontSize: fontSize,
      maxWidth: maxWidth,
      width: width,
      onTap: onTap,
    );
  }

  void showCustomNotification({
    required String message,
    required Color backgroundColor,
    required Color textColor,
    required Offset beginOffset,
    required Offset endOffset,
    IconData? icon,
    double bottomOffset = 50.0,
    double fontSize = 16.0,
    double? maxWidth,
    double? width, // Yeni width parametresi
    Duration duration = const Duration(seconds: 3),
    TextStyle? textStyle,
    VoidCallback? onTap,
  }) {
    _showOverlayNotification(
      message: message,
      backgroundColor: backgroundColor,
      icon: icon,
      textColor: textColor,
      beginOffset: beginOffset,
      endOffset: endOffset,
      bottomOffset: bottomOffset,
      fontSize: fontSize,
      maxWidth: maxWidth,
      width: width, // Yeni width parametresi
      duration: duration,
      onTap: onTap,
    );
  }

  void _showOverlayNotification({
    required String message,
    required Color backgroundColor,
    IconData? icon,
    required Color textColor,
    required Offset beginOffset,
    required Offset endOffset,
    double bottomOffset = 50.0,
    double fontSize = 16.0,
    double? maxWidth,
    double? width, // Yeni width parametresi
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    final GlobalKey<__AnimatedNotificationState> notificationKey = GlobalKey();

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                notificationKey.currentState?.dismiss();
              },
              child: Container(),
            ),
          ),
          Positioned(
            bottom: bottomOffset,
            left: width != null
                ? (MediaQuery.of(context).size.width - width) / 2
                : MediaQuery.of(context).size.width * 0.1,
            right: width == null
                ? MediaQuery.of(context).size.width * 0.1
                : (MediaQuery.of(context).size.width - width) / 2,
            child: _AnimatedNotification(
              key: notificationKey,
              message: message,
              backgroundColor: backgroundColor,
              icon: icon,
              textColor: textColor,
              beginOffset: beginOffset,
              endOffset: endOffset,
              duration: duration,
              fontSize: fontSize,
              maxWidth: maxWidth,
              width: width, // Yeni width parametresi
              onRemove: () {
                overlayEntry.remove();
              },
              onTap: () {
                notificationKey.currentState?.dismiss();
                if (onTap != null) {
                  onTap();
                }
              },
            ),
          ),
        ],
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _AnimatedNotification extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData? icon;
  final Color textColor;
  final Offset beginOffset;
  final Offset endOffset;
  final Duration duration;
  final double fontSize;
  final double? maxWidth;
  final double? width; // Yeni width parametresi
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _AnimatedNotification({
    super.key,
    required this.message,
    required this.backgroundColor,
    this.icon,
    required this.textColor,
    required this.beginOffset,
    required this.endOffset,
    required this.duration,
    required this.fontSize,
    this.maxWidth,
    this.width, // Yeni width parametresi
    required this.onRemove,
    required this.onTap,
  });

  @override
  __AnimatedNotificationState createState() => __AnimatedNotificationState();
}

class __AnimatedNotificationState extends State<_AnimatedNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: widget.endOffset,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      _startExitAnimation();
    });
  }

  void dismiss() {
    _startExitAnimation();
  }

  void _startExitAnimation() {
    _controller.reverse().then((_) {
      widget.onRemove();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: widget.width, // Yeni width ayarı
              constraints: BoxConstraints(
                maxWidth: widget.maxWidth ?? double.infinity,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null)
                    Icon(
                      widget.icon,
                      color: widget.textColor,
                      size: widget.fontSize + 4,
                    ),
                  if (widget.icon != null) const SizedBox(width: 8.0),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: widget.fontSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class TopMessage {
  static OverlayEntry? _currentEntry;
  static bool _isShowing = false;

  static void show(
    BuildContext context, {
    required String message,
    Color backgroundColor = Colors.orangeAccent,
    Color textColor = Colors.white,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (_isShowing) return; // only one message at a time
    _isShowing = true;

    // Animation controller for slide
    final overlayState = Overlay.of(context);
    final controller = AnimationController(
      vsync: overlayState!,
      duration: const Duration(milliseconds: 300),
    );
    final animation = Tween<Offset>(
            begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: SlideTransition(
            position: animation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [backgroundColor, Colors.deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _dismiss(),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(_currentEntry!);
    controller.forward(); // start slide down animation

    Future.delayed(duration, () => _dismiss());
  }

  static void _dismiss() {
    if (_currentEntry != null) {
      _currentEntry?.remove();
      _currentEntry = null;
      _isShowing = false;
    }
  }
}

import 'package:flutter/material.dart';

class GlobalScaffold {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showMessage({
    required String message,
    Color backgroundColor = Colors.blue,
    Color textColor = Colors.white,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(color: textColor, fontSize: 14), // Adjusted font size
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      action: action,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(
          horizontal: 450, vertical: 20), // Increased horizontal margin
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)), // Compact shape
    );
    scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }
}

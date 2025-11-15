import 'package:flutter/material.dart';
import '../utils/responsive.dart';

enum SnackType { success, error, warning }

class CustomSnackBar {
  static void show(BuildContext context, String message, {SnackType type = SnackType.success, int durationInSeconds = 3}) {
    Color bgColor;
    IconData icon;

    switch (type) {
      case SnackType.success:
        bgColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case SnackType.error:
        bgColor = Colors.red;
        icon = Icons.error;
        break;
      case SnackType.warning:
        bgColor = Colors.orange;
        icon = Icons.warning;
        break;
    }

    // Get responsive values
    final EdgeInsets margin = Responsive.getPadding(context);
    final double iconSize = Responsive.getScaleFactor(context) * 24;
    final double fontSize = Responsive.getFontSize(context, baseSize: 16);
    final double borderRadius = Responsive.getScaleFactor(context) * 12;
    final double spacing = Responsive.getScaleFactor(context) * 12;

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: margin, // Responsive margin
      backgroundColor: bgColor.withOpacity(0.9),
      duration: Duration(seconds: durationInSeconds),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)), // Responsive border radius
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: iconSize), // Responsive icon size
          SizedBox(width: spacing), // Responsive spacing
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize, // Responsive font size
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}

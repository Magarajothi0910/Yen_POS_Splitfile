import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

/// 🔔 Enum to define different flushbar types
enum FlushbarType { error, success, warning, info, accessDenied }

/// 🔔 Central helper to show flushbars
void showCustomFlushbar(
  BuildContext context,
  String message, {
  FlushbarType type = FlushbarType.info,
}) {
  Color backgroundColor;
  IconData icon;
  String? title;

  switch (type) {
    case FlushbarType.error:
      backgroundColor = Colors.red[600] ?? Colors.red;
      icon = Icons.error_outline;
      break;
    case FlushbarType.success:
      backgroundColor = Colors.green[600] ?? Colors.green;
      icon = Icons.check_circle_outline;
      break;
    case FlushbarType.warning:
      backgroundColor = Colors.orange[600] ?? Colors.orange;
      icon = Icons.warning;
      break;
    case FlushbarType.info:
      backgroundColor = Colors.blue[600] ?? Colors.blue;
      icon = Icons.info_outline;
      break;
    case FlushbarType.accessDenied:
      backgroundColor = Colors.red[700] ?? Colors.red;
      icon = Icons.lock;
      break;
  }

  Flushbar(
    title: title,
    titleSize: 16,
    message: message,
    messageSize: 14,
    duration: const Duration(seconds: 1),
    backgroundColor: backgroundColor,
    flushbarPosition: FlushbarPosition.BOTTOM,
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    borderRadius: BorderRadius.circular(16),
    boxShadows: const [
      BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 6),
    ],
    icon: Icon(icon, color: Colors.white, size: 26),
    shouldIconPulse: true,
  ).show(context);
}

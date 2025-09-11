import 'package:flutter/material.dart';

String capitalizeWords(String text) {
  return text.split(' ').map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

Widget buildActionButton(BuildContext context,
    {required String label,
    required Function onPressed,
    required Color backgroundColor,
    required Color textColor}) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    ),
    onPressed: onPressed(),
    child: Text(
      label,
      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
    ),
  );
}

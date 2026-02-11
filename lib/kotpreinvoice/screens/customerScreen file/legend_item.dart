import 'package:flutter/material.dart';

Widget buildLegendIndicatorForSeconds(Color color, String label) {
  return Row(
    children: [
      Icon(
        Icons.receipt_long,
        color: color,
        size: 18,
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

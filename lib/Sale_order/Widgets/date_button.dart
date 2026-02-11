import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget buildDateButton({
  required String label,
  required DateTime? date,
  required VoidCallback onTap,
}) {
  return ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue.shade600,
      foregroundColor: Colors.white,
      elevation: 3,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            date != null ? DateFormat('dd-MM-yyyy').format(date) : label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

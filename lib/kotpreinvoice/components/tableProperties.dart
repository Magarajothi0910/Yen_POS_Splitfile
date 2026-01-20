import 'package:flutter/material.dart';

import '../providers/order_provider.dart';
import 'extractTableNumber.dart';

Color getTableColor(double totalAmount) {
  if (totalAmount > 0) {
    return const Color(0xFFBBDEFB);
    //Color(0xFFB2DFDB); // Light Amber / Soft Yellow
  } else {
    return Colors.white; // Available - green, transparent
  }
}

Color getTableBorderColor(double totalAmount) {
  if (totalAmount > 0) {
    return Colors.white; // Light Grey
  } else {
    return Colors.white; // Light Grey
  }
}

Widget buildLegendIndicatorWithCount(Color color, String label, int count) {
  return Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text("$label ($count)"),
    ],
  );
}

Map<String, int> calculateTableCounts(
  List<String> allTables,
  OrderProvider orderProvider,
) {
  final Map<String, int> counts = {'occupied': 0, 'available': 0};

  for (final table in allTables) {
    // 👇 Extract seat (B/C/D) or default to 'A' for main tables
    final seat = RegExp(r'[A-Z]$').firstMatch(table)?.group(0) ?? 'A';

    // 👇 Remove (B), (C), etc. from table name to get main table number
    final mainTable = extractMainTable(table);

    final total = orderProvider.getTableTotalPrice(mainTable, seat);

    if (total > 0) {
      counts['occupied'] = counts['occupied']! + 1;
    } else {
      counts['available'] = counts['available']! + 1;
    }
  }

  return counts;
}

Widget buildActionButton({
  required IconData icon,
  required Color color,
  required String title,
  required VoidCallback onTap,
}) {
  return ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          overflow: TextOverflow.visible, // Let text wrap naturally
          softWrap: true, // Enable wrapping
          maxLines: 2, // Allow up to 2 lines
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );
}

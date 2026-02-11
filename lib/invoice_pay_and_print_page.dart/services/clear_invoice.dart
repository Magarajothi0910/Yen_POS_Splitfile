import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yen_pos/Global/globals_data.dart';

import 'package:intl/intl.dart';

DateTime getServerDateTime() {
  final date = currentDate.value; // e.g. "13-01-2026"
  final time = currentTime.value; // e.g. "10:33 AM"

  final formatter = DateFormat('dd-MM-yyyy hh:mm a');
  debugPrint(
    'Deleted ${date} ${time} invoices older than 2 days (Server Time)',
  );

  return formatter.parse('$date $time');
}

Future<void> cleanOldInvoices(Box box) async {
  final serverNow = getServerDateTime();

  // Normalize "today" to date-only
  final today = DateTime(serverNow.year, serverNow.month, serverNow.day);

  final keysToDelete = <dynamic>[];

  for (final key in box.keys) {
    final value = box.get(key);

    if (value is Map && value['invoiceDateTime'] != null) {
      final invoiceDateTime = DateTime.parse(value['invoiceDateTime']);

      // Normalize invoice date
      final invoiceDate = DateTime(
        invoiceDateTime.year,
        invoiceDateTime.month,
        invoiceDateTime.day,
      );

      // ❌ Delete if NOT today
      if (invoiceDate != today) {
        keysToDelete.add(key);
      }
    }
  }

  if (keysToDelete.isNotEmpty) {
    await box.deleteAll(keysToDelete);
  }
}

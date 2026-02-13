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

Future<void> cleanOldSaleOrder(Box box) async {
  final serverNow = getServerDateTime();

  // Normalize "today" to date-only
  final today = DateTime(serverNow.year, serverNow.month, serverNow.day);

  final keysToDelete = <dynamic>[];

  for (final key in box.keys) {
    final value = box.get(key);

    if (value is Map && value['orderDate'] != null) {
      final orderDate = DateTime.parse(value['orderDate']);

      // Normalize invoice date
      final orderDateTime = DateTime(
        orderDate.year,
        orderDate.month,
        orderDate.day,
      );

      // ❌ Delete if NOT today
      if (orderDateTime != today) {
        keysToDelete.add(key);
      }
    }
  }

  if (keysToDelete.isNotEmpty) {
    await box.deleteAll(keysToDelete);
  }
}

Future<void> cleanOldheldOrder(Box box) async {
  final serverNow = getServerDateTime();

  // Normalize "today" to date-only
  final today = DateTime(serverNow.year, serverNow.month, serverNow.day);

  final keysToDelete = <dynamic>[];

  for (final key in box.keys) {
    final value = box.get(key);

    if (value is Map && value['orderDate'] != null) {
      final heldorderDate = DateTime.parse(value['orderDate']);

      // Normalize invoice date
      final heldorderDateTime = DateTime(
        heldorderDate.year,
        heldorderDate.month,
        heldorderDate.day,
      );

      // ❌ Delete if NOT today
      if (heldorderDateTime != today) {
        keysToDelete.add(key);
      }
    }
  }

  if (keysToDelete.isNotEmpty) {
    await box.deleteAll(keysToDelete);
  }
}

Future<void> cleanOldApprovalOrder(Box box) async {
  final serverNow = getServerDateTime();

  // Normalize "today" to date-only
  final today = DateTime(serverNow.year, serverNow.month, serverNow.day);

  final keysToDelete = <dynamic>[];

  for (final key in box.keys) {
    final value = box.get(key);

    if (value is Map && value['orderDate'] != null) {
      final approvalOrderDate = DateTime.parse(value['orderDate']);

      // Normalize invoice date
      final approvalOrderDateTime = DateTime(
        approvalOrderDate.year,
        approvalOrderDate.month,
        approvalOrderDate.day,
      );

      // ❌ Delete if NOT today
      if (approvalOrderDateTime != today) {
        keysToDelete.add(key);
      }
    }
  }

  if (keysToDelete.isNotEmpty) {
    await box.deleteAll(keysToDelete);
  }
}

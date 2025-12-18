// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:intl/intl.dart';
// import 'package:yenpos/Global/Provider/current_datetime.dart';
// import 'package:yenpos/Global/globals_data.dart';

// class InvoiceNumberGenerator {
//   Box<dynamic>? _invoiceBox;
//   final String _prefix = "33BM";

//   Future<Box<dynamic>> get _getInvoiceBox async {
//     try {
//       _invoiceBox ??= await Hive.openBox('invoiceData');
//       return _invoiceBox!;
//     } catch (e) {
//       throw Exception('Failed to open Hive box: $e');
//     }
//   }

//   //Get the server date (not local) using CurrentDatetimeService
//   Future<DateTime> _getServerDate() async {
//     await CurrentDatetimeService().fetchCurrentDateTime();

//     final dateStr = currentDate.value; // e.g., '30-10-2025'
//     try {
//       return DateFormat('dd-MM-yyyy').parse(dateStr);
//     } catch (e) {
//       debugPrint("⚠️ Error parsing server date: $e");
//       return DateTime.now(); // fallback
//     }
//   }

//   //Calculate financial year (April → next March)
//   Future<String> _getFinancialYearCode() async {
//     final serverDate = await _getServerDate();
//     int year = serverDate.year;

//     // If before April (Jan, Feb, Mar), use previous year as start
//     if (serverDate.month < 4) {
//       year -= 1;
//     }

//     // Example: year = 2025 → next = 2026 → code = '2526'
//     String start = year.toString().substring(2);
//     String end = (year + 1).toString().substring(2);
//     return '$start$end';
//   }

//   // Get the next sequence number for the current financial year
//   Future<int> _getNextInvoiceCount(String yearKey) async {
//     final box = await _getInvoiceBox;
//     int currentCount = box.get(yearKey, defaultValue: 0);
//     final newCount = currentCount + 1;
//     await box.put(yearKey, newCount);
//     return newCount;
//   }

//   //Generate invoice number (e.g. 33BMAR2526-000001)
//   Future<String> generateInvoiceNumber() async {
//     final alias = aliasname.toUpperCase(); // e.g. "AR"
//     final fyCode = await _getFinancialYearCode(); // e.g. "2526"

//     final count = await _getNextInvoiceCount(fyCode);
//     final countStr = count.toString().padLeft(6, '0');
//     debugPrint("InvoiceId:$_prefix$alias$fyCode$count");
//     return '$_prefix$alias$fyCode-$countStr';
//   }
// }
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Global/Provider/current_datetime.dart';
import 'package:yenpos/Global/globals_data.dart';

class InvoiceNumberGenerator {
  static const String _boxName = 'invoiceData';
  static const String _prefix = "33BM";

  // Singleton
  InvoiceNumberGenerator._privateConstructor();
  static final InvoiceNumberGenerator instance = InvoiceNumberGenerator._privateConstructor();

  // Use nullable + proper initialization (avoid late errors)
  Box<dynamic>? _invoiceBox;

  // Open box only once (safe to call multiple times)
  Future<Box<dynamic>> get _box async {
    if (_invoiceBox == null || !_invoiceBox!.isOpen) {
      _invoiceBox = await Hive.openBox(_boxName);
    }
    return _invoiceBox!;
  }

  Future<DateTime> _getServerDate() async {
    try {
      await CurrentDatetimeService().fetchCurrentDateTime();
      final dateStr = currentDate.value; // '10-12-2025'
      if (dateStr.isEmpty) throw Exception("Empty date");

      return DateFormat('dd-MM-yyyy').parseStrict(dateStr);
    } catch (e) {
      debugPrint("Server date error: $e → fallback to local");
      return DateTime.now();
    }
  }

  Future<String> _getFinancialYearCode() async {
    final date = await _getServerDate();
    final int fyStartYear = date.month >= 4 ? date.year : date.year - 1;
    final start = fyStartYear.toString().substring(2);
    final end = (fyStartYear + 1).toString().substring(2);
    return '$start$end'; // e.g., "2526"
  }

  Future<int> _getNextSequence(String fyCode) async {
    final box = await _box;

    int current = box.get(fyCode, defaultValue: 0) as int;
    int next = current + 1;
    await box.put(fyCode, next);

    debugPrint("FY $fyCode → Invoice #$next");
    return next;
  }

  Future<String> generateInvoiceNumber() async {
    try {
      final String alias = aliasname.trim().toUpperCase();
      if (alias.isEmpty) {
        throw Exception("aliasname is empty or not set!");
      }

      final String fyCode = await _getFinancialYearCode();
      final int seq = await _getNextSequence(fyCode);
      final String seqPadded = seq.toString().padLeft(6, '0');

      final String invoice = '$_prefix$alias$fyCode-$seqPadded';

      debugPrint("Generated: $invoice");
      return invoice;
    } catch (e, s) {
      debugPrint("Invoice generation failed: $e\n$s");
      rethrow;
    }
  }

  // Optional: View current counter (for debugging)
  Future<Map<String, dynamic>> getAllCounters() async {
    final box = await _box;
    return Map<String, dynamic>.from(box.toMap());
  }
}
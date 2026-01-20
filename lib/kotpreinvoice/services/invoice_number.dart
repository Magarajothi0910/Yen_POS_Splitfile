// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:intl/intl.dart';
// import 'package:yenpos/Global/Provider/current_datetime.dart';

// import 'package:yenpos/Global/globals_data.dart';
// import '../services/current_date_time.dart';

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

//     return '$_prefix$alias$fyCode-$countStr';
//   }
// }
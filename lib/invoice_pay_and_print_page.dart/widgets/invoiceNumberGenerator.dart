
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Global/Provider/current_datetime.dart';
import 'package:yenpos/Global/globals_data.dart';

class InvoiceNumberGenerator {
  static const String _boxName = 'invoiceNo';
  static const String _prefix = "33BM";

  // Singleton
  InvoiceNumberGenerator._privateConstructor();
  static final InvoiceNumberGenerator instance =
      InvoiceNumberGenerator._privateConstructor();

  // Use nullable + proper initialization (avoid late errors)
  Box<dynamic>? _invoiceNoBox;

  // Open box only once (safe to call multiple times)
  Future<Box<dynamic>> get _box async {
    if (_invoiceNoBox == null || !_invoiceNoBox!.isOpen) {
      _invoiceNoBox = await Hive.openBox(_boxName);
    }
    return _invoiceNoBox!;
  }

  Future<DateTime> _getServerDate() async {
    try {
      await CurrentDatetimeService().fetchCurrentDateTime();
      final dateStr = currentDate.value; // '10-12-2025'
      if (dateStr.isEmpty) throw Exception("Empty date");

      return DateFormat('dd-MM-yyyy').parseStrict(dateStr);
    } catch (e) {
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

      return invoice;
    } catch (e, s) {
      rethrow;
    }
  }

  // Optional: View current counter (for debugging)
  Future<Map<String, dynamic>> getAllCounters() async {
    final box = await _box;
    return Map<String, dynamic>.from(box.toMap());
  }
}

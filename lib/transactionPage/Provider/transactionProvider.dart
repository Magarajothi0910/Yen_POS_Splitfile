import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_kot.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';

class TransactionProvider with ChangeNotifier {
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _rawInvoiceOrders = [];
  List<Map<String, dynamic>> _invoiceList = [];

  int selectedIndex = 0;
  int? _selectedTransactionIndex;
  final TextEditingController searchController = TextEditingController();

  int? get selectedTransactionIndex => _selectedTransactionIndex;
  set selectedTransactionIndex(int? index) {
    _selectedTransactionIndex = index;
    notifyListeners();
  }

  List<Map<String, dynamic>> get invoices => _invoices;
  List<Map<String, dynamic>> get rawInvoiceOrders => _rawInvoiceOrders;
  List<Map<String, dynamic>> get invoiceList => _invoiceList;

  Box get invoiceBox => HiveManager.invoiceBox;

  TransactionProvider() {
    getInvoicesFromHive();
  }

  /// Fetch invoices safely from Hive
  Future<void> getInvoicesFromHive() async {
    print("🟢 [getInvoicesFromHive] STARTED");
    try {
      final invoiceBox = HiveManager.invoiceBox;
      final invoiceKOTBox = await HiveManagerKot().invoicesBox;
      print("🟢 Hive box opened. Total entries: ${invoiceKOTBox.length}");
      print("🟢 Hive box opened. Total entries: ${invoiceBox.length}");

      // Extract invoices safely
      List<Map<String, dynamic>> hiveInvoices = invoiceBox.values
          .where((entry) => entry is Map)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .map((invoice) {
            final salesOrder = invoice['salesOrderId'];
            if (salesOrder is Map<String, dynamic>) {
              return Map<String, dynamic>.from(salesOrder);
            } else {
              print("⚠️ Skipping invalid salesOrderId: $salesOrder");
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      List<Map<String, dynamic>> hiveInvoicesKOT = invoiceKOTBox.values
          .where((entry) => entry is Map)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          // .map((invoice) {
          //   final salesOrder = invoice['salesOrderId'];
          //   if (salesOrder is Map<String, dynamic>) {
          //     return Map<String, dynamic>.from(salesOrder);
          //   } else {
          //     print("⚠️ Skipping invalid salesOrderId: $salesOrder");
          //     return null;
          //   }
          // })
          .whereType<Map<String, dynamic>>()
          .toList();

      print("🟢 Extracted ${hiveInvoices.length} valid invoices from Hive");

      // Filter duplicates by invoiceNo
      final Set<String> seen = {};
      final List<Map<String, dynamic>> uniqueInvoices = [];
      for (var invoice in hiveInvoices) {
        final invoiceNo = invoice['invoiceNo']?.toString();
        if (invoiceNo != null &&
            invoiceNo.isNotEmpty &&
            !seen.contains(invoiceNo)) {
          seen.add(invoiceNo);
          uniqueInvoices.add(invoice);
        } else if (invoiceNo != null) {
          print("⚠️ Duplicate invoice skipped: $invoiceNo");
        } else {
          print("⚠️ Invoice missing invoiceNo skipped: $invoice");
        }
      }

      _rawInvoiceOrders = uniqueInvoices;
      _invoiceList = List.from(_rawInvoiceOrders);
      print(
        "🟢 Updated local invoice lists. Count: ${_rawInvoiceOrders.length}",
      );

      notifyListeners();
      print("🟢 Listeners notified");
    } catch (e, st) {
      print("❌ Error in getInvoicesFromHive: $e\n$st");
    }
    print("🟢 [getInvoicesFromHive] FINISHED");
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

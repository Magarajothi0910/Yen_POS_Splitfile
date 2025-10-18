import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenposapp/Hive_Manager/hive_manager_saleOrder.dart';

class TransactionProvider with ChangeNotifier {
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> get invoices => _invoices;
  List<Map<String, dynamic>> _rawInvoiceOrders = [];
  List<Map<String, dynamic>> get rawInvoiceOrders => _rawInvoiceOrders;

  List<Map<String, dynamic>> _invoiceList = [];
  List<Map<String, dynamic>> get invoiceList => _invoiceList;
  // ✅ Use the central HiveManager box
  Box get invoiceBox => HiveManager.invoiceBox;

  TransactionProvider() {
    // loadInvoices();
    getInvoicesFromHive();
  }
  Future<void> getInvoicesFromHive() async {
    try {
      final invoiceBox = await HiveManager.invoiceBox;

      // Extract invoices safely
      List<Map<String, dynamic>> hiveInvoices = invoiceBox.values
          .where((entry) => entry is Map)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .map(
            (invoice) =>
                Map<String, dynamic>.from(invoice['salesOrderId'] ?? {}),
          )
          .toList();


      // ✅ Filter duplicates based on orderInvoiceNo
      final Set<String> seen = {};
      final uniqueInvoices = <Map<String, dynamic>>[];

      for (var invoice in hiveInvoices) {
        final orderInvoiceNo = invoice['orderInvoiceNo']?.toString();
        if (orderInvoiceNo != null && orderInvoiceNo.isNotEmpty) {
          if (!seen.contains(orderInvoiceNo)) {
            seen.add(orderInvoiceNo);
            uniqueInvoices.add(invoice);
          } else {
          }
        }
      }


      _rawInvoiceOrders = uniqueInvoices;
      _invoiceList = List.from(_rawInvoiceOrders);


      notifyListeners();
    } catch (e) {
    }
  }

  /// Load invoices from Hive into local state
  Future<void> loadInvoices() async {
    if (!invoiceBox.isOpen) {
      return;
    }

    _invoices = invoiceBox.values
        .where((entry) => entry is Map)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();

    for (int i = 0; i < _invoices.length; i++) {
      _invoices[i].forEach((key, value) {
      });
    }

    notifyListeners();
  }

  /// Add or update invoice (unique by hiveInvoiceId)
  Future<void> addInvoice(Map<String, dynamic> invoice) async {
    if (!invoiceBox.isOpen) {
      return;
    }

    final hiveInvoiceId = invoice['hiveInvoiceId'];
    if (hiveInvoiceId == null) {
      return;
    }

    if (!invoiceBox.containsKey(hiveInvoiceId)) {
    } else {
    }

    await invoiceBox.put(hiveInvoiceId, invoice);

    await loadInvoices();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

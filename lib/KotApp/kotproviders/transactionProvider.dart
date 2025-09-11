import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenposapp/screens/transactionPage/transaction_model.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/services/hive_manager.dart';

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
    print("🚀 [TransactionProvider] Constructor CALLED");
    // loadInvoices();
    getInvoicesFromHive();
  }
  Future<void> getInvoicesFromHive() async {
    print("📥 [getInvoicesFromHive] STARTED");
    try {
      final invoiceBox = await HiveManager.invoiceBox;
      List<Map<String, dynamic>> hiveInvoices = invoiceBox.values
          .where((entry) => entry is Map)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();

      print(
          "✅ [getInvoicesFromHive] Retrieved ${hiveInvoices.length} invoices");
      for (var invoice in hiveInvoices) {
        print("   🔹 Invoice: $invoice");
      }

      _rawInvoiceOrders = hiveInvoices;
      _invoiceList = List.from(_rawInvoiceOrders);

      print(
          "📦 [getInvoicesFromHive] _invoiceList updated → ${_invoiceList.length} items");

      notifyListeners();
      print("🔔 [getInvoicesFromHive] notifyListeners CALLED");
    } catch (e) {
      print("❌ [getInvoicesFromHive] Error: $e");
    }
  }

  /// Load invoices from Hive into local state
  Future<void> loadInvoices() async {
    if (!invoiceBox.isOpen) {
      print("❌ [loadInvoices] invoiceBox is not open yet!");
      return;
    }

    print("📂 [loadInvoices] Loading invoices from Hive...");
    _invoices = invoiceBox.values
        .where((entry) => entry is Map)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();

    print("✅ [loadInvoices] Loaded ${_invoices.length} invoices from Hive");
    for (int i = 0; i < _invoices.length; i++) {
      print("   📑 Invoice[$i]:");
      _invoices[i].forEach((key, value) {
        print("      🔹 $key → $value");
      });
    }

    notifyListeners();
    print("🔔 [loadInvoices] notifyListeners() CALLED");
  }

  /// Add or update invoice (unique by hiveInvoiceId)
  Future<void> addInvoice(Map<String, dynamic> invoice) async {
    if (!invoiceBox.isOpen) {
      print("❌ [addInvoice] invoiceBox is not open yet!");
      return;
    }

    final hiveInvoiceId = invoice['hiveInvoiceId'];
    if (hiveInvoiceId == null) {
      print("❌ [addInvoice] Missing hiveInvoiceId in invoice → $invoice");
      return;
    }

    if (!invoiceBox.containsKey(hiveInvoiceId)) {
      print("➕ [addInvoice] Adding NEW invoice with key: $hiveInvoiceId");
    } else {
      print(
          "♻️ [addInvoice] Updating EXISTING invoice with key: $hiveInvoiceId");
    }

    await invoiceBox.put(hiveInvoiceId, invoice);
    print("📦 [Hive] Invoice saved successfully with key: $hiveInvoiceId");

    await loadInvoices();
  }

  @override
  void dispose() {
    print("🧹 [TransactionProvider.dispose] Disposing provider...");
    super.dispose();
    print("✅ [TransactionProvider.dispose] COMPLETED");
  }
}

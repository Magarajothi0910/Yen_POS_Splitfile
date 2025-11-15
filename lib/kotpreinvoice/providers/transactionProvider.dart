import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_kot.dart';



class TransactionProviderDine with ChangeNotifier {
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> get invoices => _invoices;
  
  List<Map<String, dynamic>> _rawInvoiceOrders = [];
  List<Map<String, dynamic>> get rawInvoiceOrders => _rawInvoiceOrders;

  List<Map<String, dynamic>> _invoiceList = [];
  List<Map<String, dynamic>> get invoiceList => _invoiceList;
  
  // ✅ Use the central HiveManager box
  Box get invoiceBox => HiveManagerKot().invoicesBox;
  late StreamSubscription<BoxEvent> _boxSubscription;

  TransactionProvider() {
    print("🚀 [TransactionProvider] Constructor CALLED");
    _init();
  }

  Future<void> _init() async {
    print("📥 [TransactionProvider._init] INITIALIZING");
    try {
      // Ensure box is open
      final box =  HiveManagerKot().invoicesBox;
      
      // Set up Hive box watcher for automatic updates
      _boxSubscription = box.watch().listen((BoxEvent event) {
        print("🔄 [BoxWatcher] Box changed - key: ${event.key}, deleted: ${event.deleted}");
        _getInvoicesFromHive();
      });

      // Initial load
      await _getInvoicesFromHive();
      print("✅ [TransactionProvider._init] COMPLETED");
    } catch (e) {
      print("❌ [TransactionProvider._init] Error: $e");
    }
  }

  /// Main method to load and process invoices from Hive
  Future<void> _getInvoicesFromHive() async {
    print("📥 [_getInvoicesFromHive] STARTED");
    try {
      if (!invoiceBox.isOpen) {
        print("❌ [_getInvoicesFromHive] invoiceBox is not open yet!");
        return;
      }

      // Extract all invoices from Hive
      List<Map<String, dynamic>> hiveInvoices = invoiceBox.values
          .where((entry) => entry is Map)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();

      print("📦 [_getInvoicesFromHive] Retrieved ${hiveInvoices.length} raw invoices from Hive");

      // Process sales order data and filter duplicates
      await _processInvoiceData(hiveInvoices);
      
      notifyListeners();
      print("🔔 [_getInvoicesFromHive] notifyListeners CALLED");
    } catch (e) {
      print("❌ [_getInvoicesFromHive] Error: $e");
    }
  }

  /// Process invoice data: extract sales orders and remove duplicates
  Future<void> _processInvoiceData(List<Map<String, dynamic>> hiveInvoices) async {
    print("🔄 [_processInvoiceData] Processing ${hiveInvoices.length} invoices");
    
    // Extract sales order data safely
    List<Map<String, dynamic>> salesOrders = hiveInvoices
        .map((invoice) => Map<String, dynamic>.from(invoice['salesOrderId'] ?? {}))
        .where((order) => order.isNotEmpty)
        .toList();

    print("📋 [_processInvoiceData] Extracted ${salesOrders.length} sales orders");

    // ✅ Filter duplicates based on orderInvoiceNo
    final Set<String> seenInvoiceNos = {};
    final List<Map<String, dynamic>> uniqueInvoices = [];
    final List<Map<String, dynamic>> duplicateInvoices = [];

    for (var invoice in salesOrders) {
      final orderInvoiceNo = invoice['orderInvoiceNo']?.toString();
      if (orderInvoiceNo != null && orderInvoiceNo.isNotEmpty) {
        if (!seenInvoiceNos.contains(orderInvoiceNo)) {
          seenInvoiceNos.add(orderInvoiceNo);
          uniqueInvoices.add(invoice);
        } else {
          duplicateInvoices.add(invoice);
          print("⚠️ [_processInvoiceData] Skipped duplicate invoice: $orderInvoiceNo");
        }
      }
    }

    if (duplicateInvoices.isNotEmpty) {
      print("📊 [_processInvoiceData] Found ${duplicateInvoices.length} duplicates");
    }

    // Update all state variables
    _invoices = List.from(hiveInvoices);
    _rawInvoiceOrders = List.from(uniqueInvoices);
    _invoiceList = List.from(uniqueInvoices);

    print("✅ [_processInvoiceData] Final counts:");
    print("   - _invoices: ${_invoices.length}");
    print("   - _rawInvoiceOrders: ${_rawInvoiceOrders.length}");
    print("   - _invoiceList: ${_invoiceList.length}");
  }

  /// Add or update invoice (unique by hiveInvoiceId)
  Future<void> addInvoice(Map<String, dynamic> invoice) async {
    print("➕ [addInvoice] STARTED");
    
    if (!invoiceBox.isOpen) {
      print("❌ [addInvoice] invoiceBox is not open yet!");
      return;
    }

    final hiveInvoiceId = invoice['hiveInvoiceId'];
    if (hiveInvoiceId == null) {
      print("❌ [addInvoice] Missing hiveInvoiceId in invoice → $invoice");
      return;
    }

    // Check for duplicates using the same logic as TransactionProviderDine
    final existingInvoice = invoiceBox.values.firstWhere(
      (entry) =>
          entry is Map<String, dynamic> &&
          entry['hiveInvoiceId'] == hiveInvoiceId,
      orElse: () => null,
    );

    if (existingInvoice == null) {
      print("➕ [addInvoice] Adding NEW invoice with key: $hiveInvoiceId");
      await invoiceBox.put(hiveInvoiceId, invoice);
      print("📦 [addInvoice] New invoice saved successfully");
    } else {
      print("♻️ [addInvoice] Updating EXISTING invoice with key: $hiveInvoiceId");
      await invoiceBox.put(hiveInvoiceId, invoice);
      print("📦 [addInvoice] Existing invoice updated successfully");
    }

    // Note: _getInvoicesFromHive() will be automatically triggered by the box watcher
    print("✅ [addInvoice] COMPLETED - Box watcher will trigger reload");
  }

  /// Manual refresh if needed
  Future<void> refreshInvoices() async {
    print("🔄 [refreshInvoices] Manual refresh triggered");
    await _getInvoicesFromHive();
  }

  /// Get all invoices from Hive (raw, without processing)
  Future<void> loadInvoices() async {
    print("📂 [loadInvoices] Loading raw invoices from Hive...");
    
    if (!invoiceBox.isOpen) {
      print("❌ [loadInvoices] invoiceBox is not open yet!");
      return;
    }

    _invoices = invoiceBox.values
        .where((entry) => entry is Map)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();

    print("✅ [loadInvoices] Loaded ${_invoices.length} raw invoices from Hive");
    
    // Debug print all invoices
    for (int i = 0; i < _invoices.length; i++) {
      print("   📑 Raw Invoice[$i]:");
      _invoices[i].forEach((key, value) {
        print("      🔹 $key → $value");
      });
    }

    notifyListeners();
    print("🔔 [loadInvoices] notifyListeners() CALLED");
  }

  @override
  void dispose() {
    print("🧹 [TransactionProvider.dispose] Disposing provider...");
    _boxSubscription.cancel();
    super.dispose();
    print("✅ [TransactionProvider.dispose] COMPLETED");
  }
}
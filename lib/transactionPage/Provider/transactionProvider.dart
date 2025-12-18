import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_kot.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';

// class TransactionProvider with ChangeNotifier {
//   List<Map<String, dynamic>> _invoices = [];
//   List<Map<String, dynamic>> _rawInvoiceOrders = [];
//   List<Map<String, dynamic>> _invoiceList = [];
//  String? selectedOrderFilter = "all";

//   // NEW: Categorized lists
//   List<Map<String, dynamic>> _takeawayInvoices = [];
//   List<Map<String, dynamic>> _dineInInvoices = [];
//   List<Map<String, dynamic>> _saleOrderInvoices = [];

//   // NEW: Selected category for header row
//   String _selectedCategory = 'Takeaway';
//   String get selectedCategory => _selectedCategory;
//   set selectedCategory(String cat) {
//     _selectedCategory = cat;
//     _selectedTransactionIndex = null; // Reset selection on tab change
//     notifyListeners();
//   }

//   int selectedIndex = 0;
//   int? _selectedTransactionIndex;
//   final TextEditingController searchController = TextEditingController();

//   int? get selectedTransactionIndex => _selectedTransactionIndex;
//   set selectedTransactionIndex(int? index) {
//     _selectedTransactionIndex = index;
//     notifyListeners();
//   }

//   List<Map<String, dynamic>> get invoices => _invoices;
//   List<Map<String, dynamic>> get rawInvoiceOrders => _rawInvoiceOrders;
//   List<Map<String, dynamic>> get invoiceList => _invoiceList;

//   // Getters for categorized lists
//   List<Map<String, dynamic>> get takeawayInvoices => _takeawayInvoices;
//   List<Map<String, dynamic>> get dineInInvoices => _dineInInvoices;
//   List<Map<String, dynamic>> get saleOrderInvoices => _saleOrderInvoices;

//   Box get invoiceBox => HiveManager.invoiceBox;

//   TransactionProvider() {
//     loadInvoices();
//     getInvoicesFromHive();
//   }

//   Future<void> getInvoicesFromHive() async {
//     print("🔵==============================");
//     print("🔵  START: getInvoicesFromHive()");
//     print("🔵==============================");

//     try {
//       final invoiceBox = HiveManager.invoiceBox;
//       final invoiceKOTBox = HiveManagerKot().invoicesBox;

//       final List<Map<String, dynamic>> hiveInvoices = invoiceBox.values
//           .where((e) => e is Map)
//           .map((e) => Map<String, dynamic>.from(e as Map))
//           .toList();

//       final List<Map<String, dynamic>> hiveKOT = invoiceKOTBox.values
//           .where((e) => e is Map)
//           .map((e) => Map<String, dynamic>.from(e as Map))
//           .toList();

//       // Merge & Deduplicate
//       final Set<String> seen = {};
//       final List<Map<String, dynamic>> unique = [];

//       for (var inv in [...hiveInvoices, ...hiveKOT]) {
//         String? id = inv['invoiceNo']?.toString();
//         if (id == null || id.isEmpty) {
//           id = inv['saleOrderId']?.toString();
//         }
//         if (id == null || id.isEmpty) continue;

//         if (seen.contains(id)) continue;

//         seen.add(id);
//         unique.add(inv);
//       }

//       // Keep everything in one list (no splitting)
//       _rawInvoiceOrders = unique;
//       _invoiceList = List.from(unique);
//       _invoices = List.from(unique);

//       notifyListeners();
//     } catch (e, st) {
//       print("❌ ERROR in getInvoicesFromHive: $e");
//       print(st);
//     }

//     print("🟢 FINISHED: getInvoicesFromHive()");
//     print("🟢==============================\n\n");
//   }

//   Future<void> loadInvoices() async {
//     if (!invoiceBox.isOpen) return;
//     _invoices = invoiceBox.values
//         .where((e) => e is Map)
//         .map((e) => Map<String, dynamic>.from(e as Map))
//         .toList();
//     notifyListeners();
//   }

//   Future<void> addInvoice(Map<String, dynamic> invoice) async {
//     if (!invoiceBox.isOpen) return;
//     final salesOrder = invoice['salesOrderId'];
//     if (salesOrder is! Map<String, dynamic>) return;
//     final id = salesOrder['invoiceNo']?.toString();
//     if (id == null || id.isEmpty) return;
//     await invoiceBox.put(id, invoice);
//     await loadInvoices();
//     await getInvoicesFromHive(); // Refresh categories
//   }

//   @override
//   void dispose() {
//     searchController.dispose();
//     super.dispose();
//   }
// }

class TransactionProvider with ChangeNotifier {
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _rawInvoiceOrders = [];
  List<Map<String, dynamic>> _invoiceList = [];
  String? selectedOrderFilter = "all";
  // NEW: Categorized lists
  List<Map<String, dynamic>> _takeawayInvoices = [];
  List<Map<String, dynamic>> _dineInInvoices = [];
  List<Map<String, dynamic>> _saleOrderInvoices = [];
  // NEW: Selected category for header row
  String _selectedCategory = 'Takeaway';
  String get selectedCategory => _selectedCategory;
  set selectedCategory(String cat) {
    _selectedCategory = cat;
    _selectedTransactionIndex = null; // Reset selection on tab change
    notifyListeners();
  }

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
  // Getters for categorized lists
  List<Map<String, dynamic>> get takeawayInvoices => _takeawayInvoices;
  List<Map<String, dynamic>> get dineInInvoices => _dineInInvoices;
  List<Map<String, dynamic>> get saleOrderInvoices => _saleOrderInvoices;
  Box get invoiceBox => HiveManager.invoiceBox;
  Box get invoiceKOT => HiveManagerKot().invoicesBox;
  TransactionProvider() {
    loadInvoices();
    getInvoicesFromHive();
    print("InvoiceKot - ${invoiceKOT.length}");
  }
  Future<void> getInvoicesFromHive() async {
    print("InvoiceKot - ${invoiceKOT.length}");
    print("🔵==============================");
    print("🔵 START: getInvoicesFromHive()");
    print("🔵==============================");
    try {
      final invoiceBox = HiveManager.invoiceBox;
      final invoiceKOTBox = HiveManagerKot().invoicesBox;
      final List<Map<String, dynamic>> hiveInvoices = invoiceBox.values
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final List<Map<String, dynamic>> hiveKOT = invoiceKOTBox.values
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      // Merge & Deduplicate
      final Set<String> seen = {};
      final List<Map<String, dynamic>> unique = [];
      for (var inv in [...hiveInvoices, ...hiveKOT]) {
        String? id = inv['invoiceNo']?.toString();
        if (id == null || id.isEmpty) {
          id = inv['saleOrderId']?.toString();
        }
        if (id == null || id.isEmpty) continue;
        if (seen.contains(id)) continue;
        seen.add(id);
        unique.add(inv);
      }
      // Keep everything in one list (no splitting)
      _rawInvoiceOrders = unique;
      _invoiceList = List.from(unique);
      _invoices = List.from(unique);
      notifyListeners();
    } catch (e, st) {
      print("❌ ERROR in getInvoicesFromHive: $e");
      print(st);
    }
    print("🟢 FINISHED: getInvoicesFromHive()");
    print("🟢==============================\n\n");
  }

  Future<void> refreshAfterReturn() async {
    // Just trigger rebuild + re-run FutureBuilders
    notifyListeners();
    // Optionally update badge without full reload
  }

  Future<void> loadInvoices() async {
    if (!invoiceBox.isOpen) return;
    _invoices = invoiceBox.values
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    notifyListeners();
  }

  Future<void> addInvoice(Map<String, dynamic> invoice) async {
    if (!invoiceBox.isOpen) return;
    final salesOrder = invoice['salesOrderId'];
    if (salesOrder is! Map<String, dynamic>) return;
    final id = salesOrder['invoiceNo']?.toString();
    if (id == null || id.isEmpty) return;
    await invoiceBox.put(id, invoice);
    await loadInvoices();
    await getInvoicesFromHive(); // Refresh categories
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

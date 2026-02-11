import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_kot.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';

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
  List<Map<String, dynamic>> _salesReturnInvoices = [];
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
  List<Map<String, dynamic>> get salesReturnInvoices => _salesReturnInvoices;
  Box get invoiceBox => HiveManager.invoiceBox;
  Box get invoiceKOT => HiveManagerKot().invoicesBox;
  TransactionProvider() {
    loadInvoices();
    getInvoicesFromHive();
    print("InvoiceKot - ${invoiceKOT.length}");
  }

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: Duration(seconds: 3),
      receiveTimeout: Duration(seconds: 3),
      sendTimeout: Duration(seconds: 3),
    ),
  );

  Future<void> getInvoicesFromHive() async {
    print("🔵 START: getInvoicesFromHive()");

    try {
      final invoiceBox = HiveManager.invoiceBox;
      final invoiceKOTBox = HiveManagerKot().invoicesBox;
      final salesReturnBox = await Hive.openBox('salesReturns');

      // Clear all lists
      _rawInvoiceOrders.clear();
      _invoiceList.clear();
      _invoices.clear();
      _takeawayInvoices.clear();
      _dineInInvoices.clear();
      _saleOrderInvoices.clear();
      _salesReturnInvoices.clear();

      // Load from all sources
      final hiveInvoices = invoiceBox.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final hiveKOT = invoiceKOTBox.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final hiveReturns = salesReturnBox.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      print("Loaded returns: ${hiveReturns.length}");
      if (hiveReturns.isNotEmpty) {
        print(
          "Sample return nos: ${hiveReturns.map((r) => r['salesReturnNo'] ?? 'missing').take(3).toList()}",
        );
      }

      // Mark returns clearly
      for (var ret in hiveReturns) {
        ret['isSalesReturn'] = true;
        ret['displayId'] = ret['salesReturnNo']?.toString() ?? 'SR-?';
        ret['originalInvoiceNo'] = ret['invoiceNo'];
        ret['salesType'] = 'salesReturn';
        ret['returnDateTime'] ??= DateTime.now().toIso8601String();
      }

      // Combine
      final allEntries = [...hiveInvoices, ...hiveKOT, ...hiveReturns];

      // Better deduplication: separate namespaces for invoices and returns
      final Set<String> seenInvoices = {};
      final Set<String> seenReturns = {};

      final List<Map<String, dynamic>> unique = [];

      for (var inv in allEntries) {
        final isReturn = inv['isSalesReturn'] == true;
        final String? id = isReturn
            ? inv['salesReturnNo']?.toString()
            : (inv['invoiceNo']?.toString() ?? inv['saleOrderId']?.toString());

        if (id == null || id.isEmpty) continue;

        final key = isReturn ? 'RET_$id' : 'INV_$id';

        if ((isReturn && seenReturns.contains(id)) ||
            (!isReturn && seenInvoices.contains(id))) {
          print("Skipped duplicate: $key");
          continue;
        }

        if (isReturn) {
          seenReturns.add(id);
        } else {
          seenInvoices.add(id);
        }

        unique.add(inv);
      }

      // Sort: newest first, returns AFTER their original when same time
      unique.sort((a, b) {
        final dateA = _parseDate(a);
        final dateB = _parseDate(b);
        int cmp = dateB.compareTo(dateA);
        if (cmp != 0) return cmp;

        final aIsReturn = a['isSalesReturn'] == true;
        final bIsReturn = b['isSalesReturn'] == true;

        if (aIsReturn && !bIsReturn) return 1; // return after original
        if (!aIsReturn && bIsReturn) return -1;
        return 0;
      });

      _rawInvoiceOrders = List.from(unique);
      _invoiceList = List.from(unique);
      _invoices = List.from(unique);

      _categorizeInvoices();

      print("Final list length: ${_invoices.length}");
      notifyListeners();
    } catch (e, st) {
      print("❌ ERROR in getInvoicesFromHive: $e");
      print(st);
    }
  }

  DateTime _parseDate(Map<String, dynamic> inv) {
    final raw = inv['isSalesReturn'] == true
        ? inv['returnDateTime']
        : inv['invoiceDateTime'] ?? inv['orderDateTime'];
    return DateTime.tryParse(raw?.toString() ?? '') ?? DateTime(1970);
  }

  void _categorizeInvoices() {
    _takeawayInvoices.clear();
    _dineInInvoices.clear();
    _saleOrderInvoices.clear();
    _salesReturnInvoices.clear();

    for (var inv in _invoices) {
      final type = _normalizeSalesType(inv['salesType']?.toString());
      switch (type) {
        case 'takeaway':
          _takeawayInvoices.add(inv);
          break;
        case 'dinein':
          _dineInInvoices.add(inv);
          break;
        case 'salesorder':
          _saleOrderInvoices.add(inv);
          break;
        case 'salesreturn':
          _salesReturnInvoices.add(inv);
          break;
      }
    }

    print(
      "Categorization → TA:${_takeawayInvoices.length} | DI:${_dineInInvoices.length} | SO:${_saleOrderInvoices.length} | SR:${_salesReturnInvoices.length}",
    );
  }

  String _normalizeSalesType(String? type) {
    if (type == null) return "";
    final normalized = type
        .toLowerCase()
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '');

    if (normalized == 'salesreturn') return 'salesreturn';
    if (normalized.contains('takeaway') || normalized.contains('take away'))
      return 'takeaway';
    if (normalized.contains('dinein') ||
        normalized.contains('dinning') ||
        normalized.contains('dine'))
      return 'dinein';
    if (normalized.contains('salesorder') || normalized.contains('saleorder'))
      return 'salesorder';
    return '';
  }

  // Helper method to categorize invoices
  Future<void> refreshAfterReturn() async {
    print("[REFRESH AFTER RETURN] Starting...");
    _rawInvoiceOrders.clear();
    _invoiceList.clear();
    _invoices.clear();
    _takeawayInvoices.clear();
    _dineInInvoices.clear();
    _saleOrderInvoices.clear();
    _salesReturnInvoices.clear();

    await getInvoicesFromHive();

    // Force UI rebuild even if length same
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1000));
    notifyListeners();

    print("[REFRESH AFTER RETURN] Completed → length: ${_invoices.length}");
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

  Future<void> searchInvoiceOrders(String query) async {
    query = query.trim();

    if (query.isEmpty) {
      // If search cleared → restore full list
      await getInvoicesFromHive();
      return;
    }

    try {
      final response = await _dio.get(
        'https://yenerp.com/fluttertestapi/invoices/api/search-orders?q=$query',
        //headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.data);
        final List<Map<String, dynamic>> results = data
            .cast<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        _invoices = results;
        notifyListeners();
      } else {
        debugPrint("Search API failed: ${response.statusCode}");
        await _localSearchFallback(query);
      }
    } catch (e) {
      debugPrint("Search error (network): $e");
      await _localSearchFallback(query);
    }
  }

  // Fallback: Search locally in Hive data
  Future<void> _localSearchFallback(String query) async {
    await getInvoicesFromHive(); // Ensure latest data

    final lowerQuery = query.toLowerCase();

    final matches = _rawInvoiceOrders.where((inv) {
      final invoiceNo = (inv['invoiceNo']?.toString() ?? '').toLowerCase();
      final returnNo = (inv['salesReturnNo']?.toString() ?? '').toLowerCase();
      final customerPhone = (inv['customerPhoneNumber']?.toString() ?? '')
          .toLowerCase();

      return invoiceNo.contains(lowerQuery) ||
          returnNo.contains(lowerQuery) ||
          customerPhone.contains(lowerQuery);
    }).toList();

    _invoices = matches;
    notifyListeners();
  }

  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 30;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  Future<void> loadMoreFromServer() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final response = await _dio.get(
        'https://yenerp.com/fluttertestapi/invoices/api/paginated-invoices?branchName=$branchName&page=$_currentPage&limit=$_pageSize',

        // headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.data);
        final List<dynamic> newData = json['data'] ?? [];
        final bool serverHasMore = json['has_more'] ?? false;

        if (newData.isNotEmpty) {
          final List<Map<String, dynamic>> newInvoices = newData
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          for (final inv in newInvoices) {
            final String id = inv['isSalesReturn'] == true
                ? inv['salesReturnNo']?.toString() ?? ''
                : inv['invoiceNo']?.toString() ?? '';

            if (id.isNotEmpty &&
                !_rawInvoiceOrders.any(
                  (existing) =>
                      (existing['isSalesReturn'] == true
                          ? existing['salesReturnNo']
                          : existing['invoiceNo']) ==
                      id,
                )) {
              _rawInvoiceOrders.add(inv);
              _invoiceList.add(inv);
              _invoices.add(inv);
            }
          }

          _currentPage++;
          _hasMore = serverHasMore;
        } else {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint("Load more error: $e");
      _hasMore = false;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void resetPagination() {
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;
  }
}

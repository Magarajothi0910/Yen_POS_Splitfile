import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Hive_Manager/hive_manager_kot.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';


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
  }

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: Duration(seconds: 3),
      receiveTimeout: Duration(seconds: 3),
      sendTimeout: Duration(seconds: 3),
    ),
  );

  Future<void> getInvoicesFromHive() async {

    try {
      final invoiceBox = HiveManager.invoiceBox;
      final invoiceKOTBox = HiveManagerKot().invoicesBox;
      final salesReturnBox = await Hive.openBox('salesReturns');

      // Clear existing lists
      _rawInvoiceOrders.clear();
      _invoiceList.clear();
      _invoices.clear();
      _takeawayInvoices.clear();
      _dineInInvoices.clear();
      _saleOrderInvoices.clear();

      // Load all invoices
      final List<Map<String, dynamic>> hiveInvoices = invoiceBox.values
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final List<Map<String, dynamic>> hiveKOT = invoiceKOTBox.values
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final List<Map<String, dynamic>> hiveReturns = salesReturnBox.values
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Mark returns clearly
      for (var ret in hiveReturns) {
        ret['isSalesReturn'] = true;
        ret['displayId'] = ret['salesReturnNo']?.toString() ?? ret['invoiceNo'];
        ret['originalInvoiceNo'] = ret['invoiceNo'];
        ret['salesType'] = 'salesReturn';
        ret['returnDateTime'] =
            ret['returnDateTime'] ?? DateTime.now().toIso8601String();
      }

      // Combine and deduplicate
      final Set<String> seen = {};
      final List<Map<String, dynamic>> unique = [];

      for (var inv in [...hiveInvoices, ...hiveKOT, ...hiveReturns]) {
        String? id;
        if (inv['isSalesReturn'] == true) {
          id = inv['salesReturnNo']?.toString();
        } else {
          id = inv['invoiceNo']?.toString() ?? inv['saleOrderId']?.toString();
        }

        if (id == null || id.isEmpty || seen.contains(id)) continue;

        seen.add(id);
        unique.add(inv);
      }

      // Sort by date descending
      unique.sort((a, b) {
        final DateTime dateA =
            DateTime.tryParse(
              (a['isSalesReturn'] == true
                      ? a['returnDateTime']
                      : a['invoiceDateTime'] ?? a['orderDateTime'] ?? '')
                  .toString(),
            ) ??
            DateTime(1970);
        final DateTime dateB =
            DateTime.tryParse(
              (b['isSalesReturn'] == true
                      ? b['returnDateTime']
                      : b['invoiceDateTime'] ?? b['orderDateTime'] ?? '')
                  .toString(),
            ) ??
            DateTime(1970);
        return dateB.compareTo(dateA);
      });

      _rawInvoiceOrders = List.from(unique);
      _invoiceList = List.from(unique);
      _invoices = List.from(unique);

      // Categorize invoices
      // _categorizeInvoices();

      notifyListeners();
    } catch (e, st) {
    }
  }

  // Helper method to categorize invoices
  void _categorizeInvoices() {
    _takeawayInvoices.clear();
    _dineInInvoices.clear();
    _saleOrderInvoices.clear();

    for (var invoice in _invoices) {
      final type = invoice['salesType']?.toString();
      switch (type) {
        case 'takeaway':
          _takeawayInvoices.add(invoice);
          break;
        case 'dinein':
          _dineInInvoices.add(invoice);
          break;
        case 'salesorder':
          _saleOrderInvoices.add(invoice);
          break;
        // salesreturn is handled separately
      }
    }
  }

  Future<void> refreshAfterReturn() async {
    // Clear all cached data and reload from Hive
    _rawInvoiceOrders.clear();
    _invoiceList.clear();
    _invoices.clear();
    _takeawayInvoices.clear();
    _dineInInvoices.clear();
    _saleOrderInvoices.clear();

    // Force reload from Hive
    await getInvoicesFromHive();

    // Also reset selection if needed
    _selectedTransactionIndex = null;

    notifyListeners();
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
        await _localSearchFallback(query);
      }
    } catch (e) {
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

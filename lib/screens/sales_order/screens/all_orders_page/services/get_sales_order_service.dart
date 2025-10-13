import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yenposapp/Global/allorderprint.dart';
import 'package:yenposapp/data/global_data_manager.dart';
import 'package:yenposapp/screens/transactionPage/transaction_model.dart';
import 'package:yenposapp/screens/transactionPage/transaction_page.dart';
import 'package:yenposapp/server/Service/hive%20boxes.dart';
import 'package:yenposapp/services/hive_manager.dart';

import '../../../../../services/websocketService.dart';
import '../../create_salesOrder.dart/models/held_order_model.dart';
import '../../model/sales_order_display_model.dart';
// import '../../model/sales_order_model.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class ApiServiceSalesOrderProvider extends ChangeNotifier {
  ApiServiceSalesOrderProvider({required this.webSocketService}) {
    fetchOrdersFromHive();

    setupHiveListener();
  }

  late salesInvoiceReceiptPrinter receiptPrinter;

  List<Map<String, dynamic>> _rawOrders = [];
  List<Map<String, dynamic>> get rawOrders => _rawOrders;

  List<Map<String, dynamic>> _hivefilteredOrders = [];
  List<Map<String, dynamic>> get hivefilteredOrders => _hivefilteredOrders;
  List<Map<String, dynamic>> _hivefilteredAllOrders = [];
  List<Map<String, dynamic>> get hivefilteredAllOrders =>
      _hivefilteredAllOrders;

  /// ✅ Fetch Invoices

  /// ✅ Fetch Orders
  Future<void> fetchOrdersFromHive() async {
    try {
      List<Map<String, dynamic>> hiveOrders =
          await webSocketService.getSavedSalesOrders();

      for (var order in hiveOrders) {}

      _rawOrders = hiveOrders;
      _hivefilteredOrders = List.from(_rawOrders);
      _hivefilteredAllOrders = List.from(_rawOrders);
      notifyListeners();
    } catch (e) {}
  }

  /// ✅ Filter Orders By Date
  void filterOrdersByDate(DateTime selectedDate) {
    _hivefilteredOrders = _rawOrders.where((order) {
      if (order.containsKey('data') &&
          order['data'].containsKey('deliveryDate')) {
        try {
          String rawDate = order['data']['deliveryDate'];
          DateTime orderDate = DateFormat('dd-MM-yyyy').parse(rawDate);

          bool match = DateFormat('yyyy-MM-dd').format(orderDate) ==
              DateFormat('yyyy-MM-dd').format(selectedDate);

          return match;
        } catch (e) {
          return false;
        }
      }
      return false;
    }).toList();

    notifyListeners();
  }

  /// ✅ Setup Hive Listener
  Future<void> setupHiveListener() async {
    final saleOrderBox = await Hive.openBox('saleOrderBox');
    saleOrderBox.watch().listen((event) {
      refreshOrders();
    });
  }

  /// ✅ Refresh Orders
  Future<void> refreshOrders() async {
    await fetchOrdersFromHive();
  }

  void filterOrdersByStatus(String selectedFilter) {
    if (selectedFilter == "All Order") {
      _hivefilteredAllOrders = List.from(_rawOrders);
    } else {
      String targetStatus = selectedFilter;

      // Handle special mapping
      if (selectedFilter == "Cancel") {
        targetStatus = "Cancel Order";
      } else if (selectedFilter == "Confirm") {
        targetStatus = "Confirm Order"; // Map "Confirm" to actual status
      } else if (selectedFilter == "Pending") {
        targetStatus = "Waiting for approval"; // Map "Confirm" to actual status
      }

      _hivefilteredAllOrders = _rawOrders.where((order) {
        if (order.containsKey("data") && order["data"].containsKey("status")) {
          String orderStatus = order["data"]["status"].toString();
          return orderStatus.toLowerCase() == targetStatus.toLowerCase();
        } else {
          return false;
        }
      }).toList();
    }

    // Notify UI
    notifyListeners();
  }

  void fetchFilteredOrders({DateTime? startDate, DateTime? endDate}) {
    _hivefilteredAllOrders = _rawOrders.where((order) {
      if (order.containsKey('data') &&
          order['data'].containsKey('deliveryDate')) {
        try {
          String rawDate = order['data']['deliveryDate'];
          DateTime deliveryDate = DateFormat('dd-MM-yyyy').parse(rawDate);

          // Only filter if user has selected dates
          if (startDate != null && endDate != null) {
            return (deliveryDate.isAtSameMomentAs(startDate) ||
                    deliveryDate.isAfter(startDate)) &&
                (deliveryDate.isAtSameMomentAs(endDate) ||
                    deliveryDate.isBefore(endDate));
          }

          // If no dates selected, include all
          return true;
        } catch (e) {
          return false;
        }
      } else {
        return false;
      }
    }).toList();

    notifyListeners();
  }

  bool _groupByDeliveryDate = true;
  bool get groupByDeliveryDate => _groupByDeliveryDate;

  List<CreditOrder> _creditOrders = [];
  List<SalesOrderDisplay> _filteredSalesOrders = [];
  List<SalesOrderDisplay> _filteredAllSalesOrders = [];
  List<SalesOrderDisplay> _allSalesOrders = [];
  List<SalesOrderDisplay> _originalSalesOrder = [];
  bool _isLoading = false;
  Timer? _debounce;
  List<ModifyOrder> _modifiedOrders = [];
  List<ToApprove> _toApprove = [];
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  List<CreditOrder> get creditOrders => _creditOrders;
  List<SalesOrderDisplay> get filteredSalesOrders => _filteredSalesOrders;
  List<ModifyOrder> get modifyorder => _modifiedOrders;
  List<ToApprove> get toApprove => _toApprove;
  List<SalesOrderDisplay> get allSalesOrders => _allSalesOrders;
  List<SalesOrderDisplay> get originalSalesOrders => _originalSalesOrder;
  bool get isLoading => _isLoading;
  String? _searchQuery;

  DateTime fetchDate = DateTime.now();
  DateTime get date => fetchDate;
  DateTime? _selectedDate = DateTime.now();
  DateTime? get selectedDate => _selectedDate;
  final ScrollController scrollController = ScrollController();
  bool isLoadingMore = false;
  int currentPage = 1;
  final int pageSize = 10;
  final WebSocketService webSocketService;

  List<SalesOrderDisplay> _salesOrders = [];
  List<SalesOrderDisplay> get salesOrders => _salesOrders;

  List<Transaction> _invoiceDataOrders = [];
  List<Transaction> get invoiceDataOrders => _invoiceDataOrders;
  Map<String, List<SalesOrderDisplay>> _ordersByDate = {};
  List<String> _sortedDates = [];
  String _todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  // Add getters
  Map<String, List<SalesOrderDisplay>> get ordersByDate => _ordersByDate;
  List<String> get sortedDates => _sortedDates;
  String get todayDate => _todayDate;

  void scanQRCode(String qrCode) {
    _searchQuery = qrCode.trim(); // Remove unnecessary whitespace
    notifyListeners();
    searchOrders(_searchQuery!); // Trigger the search logic with the QR code
  }

  /// ✅ Change Date
  void changeDate(Duration duration) {
    final oldDate = _selectedDate;
    _selectedDate = _selectedDate!.add(duration);

    filterOrdersByDate(_selectedDate!);

    notifyListeners();
  }

  List<SalesOrderDisplay> get filteredAllSalesOrders {
    return _allSalesOrders.map((order) {
      // Find matching modified orders
      final matchingModifiedOrders = _modifiedOrders
          .where((modOrder) =>
              modOrder.previousId == order.salesOrderId ||
              modOrder.saleOrderNo == order.saleOrderNo)
          .toList();

      // Return order with matched modifications
      return order.copyWith(
        modifiedOrders: matchingModifiedOrders,
      );
    }).toList();
  }

  Future<void> fetchAllOrders() async {
    try {
      // Fetch original sales orders
      final salesOrderResponse = await http.get(Uri.parse(
          'http://192.168.29.246:8881/fastapi/salesorders/withoutpagination/'));

      if (salesOrderResponse.statusCode == 200) {
        // final salesOrderData = jsonDecode(salesOrderResponse.body) as List;
        final responseBody = jsonDecode(salesOrderResponse.body);
        if (responseBody is List) {
          final salesOrderData = responseBody
              .map((json) => SalesOrderDisplay.fromMap(json))
              .toList();
          //  _allSalesOrders = salesOrderData
          //     .map((json) => SalesOrderDisplay.fromMap(json))
          //     .toList();
          _filteredAllSalesOrders = salesOrderData
              .where((order) => order.status == "Confirm Order")
              .toList()
              .reversed
              .toList();
          _originalSalesOrder = _filteredAllSalesOrders;
          _allSalesOrders = _filteredAllSalesOrders;
        } else if (responseBody is Map<String, dynamic>) {
          final salesOrderData = responseBody['data'] as List;
          _allSalesOrders = salesOrderData
              .map((json) => SalesOrderDisplay.fromMap(json))
              .toList();
          _filteredAllSalesOrders = _allSalesOrders
              .where((order) => order.status == "Confirm Order")
              .toList()
              .reversed
              .toList();
          _originalSalesOrder = _filteredAllSalesOrders;
          _allSalesOrders = _filteredAllSalesOrders;
        } else {
          throw Exception('Failed to load sales orders');
        }
      }

      // Fetch modified orders
      final modifiedOrderResponse = await http
          .get(Uri.parse('http://192.168.29.246:8881/fastapi/modify/'));
      if (modifiedOrderResponse.statusCode == 200) {
        final modifiedOrderData =
            jsonDecode(modifiedOrderResponse.body) as List;
        _modifiedOrders = modifiedOrderData
            .map((json) => ModifyOrder.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to load modified orders');
      }

      // Fetch toApprove orders
      final toApproveResponse = await http
          .get(Uri.parse('http://192.168.29.246:8881/fastapi/toapprove/'));
      if (toApproveResponse.statusCode == 200) {
        final toApproveData = jsonDecode(toApproveResponse.body) as List;
        _toApprove =
            toApproveData.map((json) => ToApprove.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load toApprove orders');
      }

      // Merge modified and toApprove data into sales orders
      _allSalesOrders = _allSalesOrders.map((order) {
        // Find matching modified orders
        final matchingModifiedOrders = _modifiedOrders
            .where((modOrder) =>
                modOrder.previousId == order.salesOrderId ||
                modOrder.saleOrderNo == order.saleOrderNo)
            .toList();

        // Find matching toApprove orders
        final matchingToApproveOrders = _toApprove
            .where((approveOrder) =>
                approveOrder.previousId == order.salesOrderId ||
                approveOrder.saleOrderNo == order.saleOrderNo)
            .toList();

        // Return order with matched modifications and approvals
        return order
            .copyWith(modifiedOrders: matchingModifiedOrders)
            .copytoapprove(toApprove: matchingToApproveOrders);
      }).toList();

      notifyListeners();
    } catch (e) {}
  }

  void toggleGrouping() {
    _groupByDeliveryDate = !_groupByDeliveryDate;
    // _allSalesOrders.clear();
    // _ordersByDate.clear();
    // print('_groupByDeliveryDate${_groupByDeliveryDate}');
    // fetchAllOrders(); // This will fetch with the new grouping

    notifyListeners();
  }

  void clearAllOrders() {
    _ordersByDate.clear();
    _allSalesOrders.clear();
    _filteredAllSalesOrders.clear();
    _originalSalesOrder.clear();
    _sortedDates.clear();
    notifyListeners();
  }

  void filterGroupedOrders({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? searchQuery,
  }) {
    _filteredAllSalesOrders = _allSalesOrders.where((order) {
      bool matchesDate = true;
      // if (startDate != null && endDate != null) {

      //   matchesDate =
      //       order.deliveryDate.isAfter(startDate.subtract(Duration(days: 1))) &&
      //           order.deliveryDate.isBefore(endDate.add(Duration(days: 1)));
      // }
      DateTime? deliveryDate;
      try {
        deliveryDate = DateFormat("dd-MM-yyyy").parse(order.deliveryDate);
      } catch (e) {
        return false;
      }

      // Check if the order falls within the selected date range
      if (startDate != null && endDate != null) {
        matchesDate =
            deliveryDate.isAfter(startDate.subtract(Duration(days: 1))) &&
                deliveryDate.isBefore(endDate.add(Duration(days: 1)));
      }

      bool matchesStatus = true;
      if (status != null && status != 'All Order') {
        matchesStatus = order.status == status;
      }

      bool matchesSearch = true;
      if (searchQuery != null && searchQuery.isNotEmpty) {
        matchesSearch = order.saleOrderNo
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ||
            (order.employeeName?.toLowerCase() ?? '')
                .contains(searchQuery.toLowerCase());
      }

      return matchesDate && matchesStatus && matchesSearch;
    }).toList();

    // Update grouped orders based on filtered results
    _updateGroupedOrders();
    notifyListeners();
  }

  // Helper method to update grouped orders
  void _updateGroupedOrders() {
    _ordersByDate = {};
    for (var order in _filteredAllSalesOrders) {
      // final orderDate = DateFormat('dd-MM-yyyy').format(order.deliveryDate);
      final orderDate = order.deliveryDate;
      final DateTime parsedDate = DateTime.parse(orderDate);

// Now you can format it into 'dd-MM-yyyy'
      final String formattedDate = DateFormat('dd-MM-yyyy').format(parsedDate);

      if (_ordersByDate.containsKey(formattedDate)) {
        _ordersByDate[formattedDate]!.add(order);
      } else {
        _ordersByDate[formattedDate] = [order];
      }
    }

    _sortedDates = _ordersByDate.keys.toList()
      ..sort((a, b) => DateFormat('dd-MM-yyyy')
          .parse(b)
          .compareTo(DateFormat('dd-MM-yyyy').parse(a)));
  }

  void searchOrders(String query) {
    final trimmedQuery = query.trim().toLowerCase();

    // Print full raw orders before filtering
    for (var i = 0; i < _rawOrders.length; i++) {}

    if (trimmedQuery.isEmpty) {
      _hivefilteredAllOrders = List.from(_rawOrders);
    } else {
      _hivefilteredAllOrders = _rawOrders.where((order) {
        if (order is Map) {
          // Convert to Map<String, dynamic> safely
          final data = order['data'] != null
              ? Map<String, dynamic>.from(order['data'] as Map)
              : <String, dynamic>{};

          String customerName =
              data['customerName']?.toString().toLowerCase() ?? '';
          String customerNumber =
              data['customerNumber']?.toString().toLowerCase() ?? '';
          String salesOrderId =
              data['saleOrderNo']?.toString().toLowerCase() ?? '';
          String event = data['event']?.toString().toLowerCase() ?? '';

          bool match = customerName.contains(trimmedQuery) ||
              customerNumber.contains(trimmedQuery) ||
              salesOrderId.contains(trimmedQuery) ||
              event.contains(trimmedQuery);

          return match;
        }
        return false;
      }).toList();
    }

    // Print filtered orders after filtering
    for (var i = 0; i < _hivefilteredAllOrders.length; i++) {}

    notifyListeners();
  }

  // bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;

//  bool get isLoading => _isLoading;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  void setStartDate(DateTime date) {
    _startDate = date;
    notifyListeners(); // Notify listeners about the change
  }

  void setEndDate(DateTime date) {
    _endDate = date;
    notifyListeners(); // Notify listeners about the change
  }
}

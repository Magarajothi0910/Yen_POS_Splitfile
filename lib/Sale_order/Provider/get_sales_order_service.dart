import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// import '../../model/sales_order_model.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:yenpos/Notification/notification_service.dart';
import 'package:yenpos/Notification/websocket_service.dart';
import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';
import 'package:yenpos/Server_Client/websocketService.dart';
import 'package:yenpos/transactionPage/Model/transaction_model.dart';

class ApiServiceSalesOrderProvider extends ChangeNotifier {
  final NotificationWebSocketService _wsService =
      NotificationWebSocketService();
  final String _wsUrl = 'wss://yenerp.com/fastapi/salesorders/ws';
  bool _isDisposed = false;
  String _lastUpdateMessage = '';
  String get lastUpdateMessage => _lastUpdateMessage;

  ApiServiceSalesOrderProvider() {
    fetchOrdersFromHive();
    setupHiveListener();

    // Initialize notifications
    NotificationService.init();

    // Connect after short delay
    Future.delayed(const Duration(seconds: 2), () {
      connectWebSocket();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _wsService.disconnect();
    super.dispose();
  }

  /// 🔗 Connects to WebSocket safely with auto-reconnect
  void connectWebSocket() {
    if (_isDisposed) return;

    try {
      _wsService.connect(_wsUrl);

      _wsService.channel?.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          print("⚠️ WebSocket error: $error. Reconnecting in 5s...");
          _reconnect();
        },
        onDone: () {
          print("⚠️ WebSocket closed. Reconnecting in 5s...");
          _reconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      print("❌ WebSocket connect exception: $e");
      _reconnect();
    }
  }

  void _reconnect() {
    if (_isDisposed) return;
    _wsService.disconnect();
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isDisposed) connectWebSocket();
    });
  }

  Future<void> _handleWebSocketMessage(dynamic rawMessage) async {
    try {
      final data = jsonDecode(rawMessage);
      final type = data['type'];
      final messageText = data['message'] ?? 'Update received';
      final payload = data['data'] ?? {};

      print("📩 WebSocket message → $data");
      if (type == 'salesOrder_updated' || type == 'dispatch_received') {
        _lastUpdateMessage = messageText;
        notifyListeners();

        // Show notification
        await NotificationService.showNotification(
          type == 'salesOrder_updated'
              ? 'Sale Order Updated'
              : 'Dispatch Received',
          messageText,
        );

        // Sync updated data to server
        await sendataToServer({"type": type, "data": payload});
      }
    } catch (e) {
      print("❌ Failed to parse WebSocket message: $rawMessage | Error: $e");
    }
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
      List<Map<String, dynamic>> hiveOrders = await getSavedSalesOrders();

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

          bool match =
              DateFormat('yyyy-MM-dd').format(orderDate) ==
              DateFormat('yyyy-MM-dd').format(selectedDate);

          return match;
        } catch (e) {
          return false;
        }
      }
      return false;
    }).toList();
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
    print("🔹 [FILTER] Requested filter: $selectedFilter");

    // Step 1: Handle "All Order" case
    if (selectedFilter == "All Order") {
      _hivefilteredAllOrders = List.from(_rawOrders);
      print(
        "✅ [FILTER] Showing all orders. Total: ${_hivefilteredAllOrders.length}",
      );
    } else {
      // Step 2: Map display name to actual status string
      String targetStatus = selectedFilter;

      if (selectedFilter == "Cancel") {
        targetStatus = "Cancel Order";
      } else if (selectedFilter == "Confirm") {
        targetStatus = "Confirm Order";
      } else if (selectedFilter == "Pending") {
        targetStatus = "Waiting for approval";
      }

      print("🧭 [FILTER] Mapped '$selectedFilter' → '$targetStatus'");

      // Step 3: Filter the list
      _hivefilteredAllOrders = _rawOrders.where((order) {
        // Check if order has a valid data structure
        if (order.containsKey("data") && order["data"].containsKey("status")) {
          final orderStatus = order["data"]["status"].toString();
          final isMatch =
              orderStatus.toLowerCase() == targetStatus.toLowerCase();

          // Detailed per-item debug
          print(
            "🔍 Checking order ID: ${order['data']['id'] ?? 'N/A'} "
            "| Status: $orderStatus | Match: $isMatch",
          );

          return isMatch;
        } else {
          print(
            "⚠️ Skipping invalid order entry: Missing 'data' or 'status' field",
          );
          return false;
        }
      }).toList();

      print("📊 [FILTER] Matched orders: ${_hivefilteredAllOrders.length}");
    }

    // Step 4: Update UI
    print(
      "🔁 [FILTER] UI notified to refresh with ${_hivefilteredAllOrders.length} items.",
    );
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
          .where(
            (modOrder) =>
                modOrder.previousId == order.salesOrderId ||
                modOrder.saleOrderNo == order.saleOrderNo,
          )
          .toList();

      // Return order with matched modifications
      return order.copyWith(modifiedOrders: matchingModifiedOrders);
    }).toList();
  }

  Future<void> fetchAllOrders() async {
    try {
      // Fetch original sales orders
      final salesOrderResponse = await http.get(
        Uri.parse('https://yenerp.com/fastapi/salesorders/withoutpagination/'),
      );

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
      final modifiedOrderResponse = await http.get(
        Uri.parse('https://yenerp.com/fastapi/modify/'),
      );
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
      final toApproveResponse = await http.get(
        Uri.parse('https://yenerp.com/fastapi/toapprove/'),
      );
      if (toApproveResponse.statusCode == 200) {
        final toApproveData = jsonDecode(toApproveResponse.body) as List;
        _toApprove = toApproveData
            .map((json) => ToApprove.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to load toApprove orders');
      }

      // Merge modified and toApprove data into sales orders
      _allSalesOrders = _allSalesOrders.map((order) {
        // Find matching modified orders
        final matchingModifiedOrders = _modifiedOrders
            .where(
              (modOrder) =>
                  modOrder.previousId == order.salesOrderId ||
                  modOrder.saleOrderNo == order.saleOrderNo,
            )
            .toList();

        // Find matching toApprove orders
        final matchingToApproveOrders = _toApprove
            .where(
              (approveOrder) =>
                  approveOrder.previousId == order.salesOrderId ||
                  approveOrder.saleOrderNo == order.saleOrderNo,
            )
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
        matchesSearch =
            order.saleOrderNo.toLowerCase().contains(
              searchQuery.toLowerCase(),
            ) ||
            (order.employeeName?.toLowerCase() ?? '').contains(
              searchQuery.toLowerCase(),
            );
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
      ..sort(
        (a, b) => DateFormat(
          'dd-MM-yyyy',
        ).parse(b).compareTo(DateFormat('dd-MM-yyyy').parse(a)),
      );
  }

  void searchOrders(String query) {
    print("🔍 searchOrders called with query: '$query'");

    try {
      final trimmedQuery = query.trim().toLowerCase();
      print("📏 Trimmed Query: '$trimmedQuery'");

      // Function to filter a list of orders
      List<Map<String, dynamic>> filterOrders(
        List<Map<String, dynamic>> orders,
      ) {
        if (trimmedQuery.isEmpty) return List.from(orders);

        return orders.where((order) {
          if (order is Map) {
            final data = order['data'] != null
                ? Map<String, dynamic>.from(order['data'] as Map)
                : <String, dynamic>{};

            final customerName =
                data['customerName']?.toString().toLowerCase() ?? '';
            final customerNumber =
                data['customerNumber']?.toString().toLowerCase() ?? '';
            final salesOrderId =
                data['saleOrderNo']?.toString().toLowerCase() ?? '';
            final event = data['event']?.toString().toLowerCase() ?? '';

            final match =
                customerName.contains(trimmedQuery) ||
                customerNumber.contains(trimmedQuery) ||
                salesOrderId.contains(trimmedQuery) ||
                event.contains(trimmedQuery);

            if (match) {
              print(
                "✅ Match found: customer=$customerName, number=$customerNumber, orderNo=$salesOrderId, event=$event",
              );
            }

            return match;
          } else {
            print("⚠️ Skipping non-Map order: $order");
            return false;
          }
        }).toList();
      }

      // Apply filter to both lists
      _hivefilteredOrders = filterOrders(_rawOrders);
      _hivefilteredAllOrders = filterOrders(_rawOrders);

      print("🔎 Filtered current orders count: ${_hivefilteredOrders.length}");
      print("🔎 Filtered all orders count: ${_hivefilteredAllOrders.length}");

      // Notify listeners
      if (hasListeners) {
        notifyListeners();
      }
    } catch (e, st) {
      print("❌ Error in searchOrders: $e");
      print("📜 Stack trace:\n$st");
    }

    print("✅ searchOrders completed.\n");
  }

  // 🔍 Search only hivefilteredOrders
  void searchHiveFilteredOrders(String query) {
    print("🔍 searchHiveFilteredOrders called with query: '$query'");

    try {
      final trimmedQuery = query.trim().toLowerCase();
      print("📏 Trimmed Query: '$trimmedQuery'");

      List<Map<String, dynamic>> filterOrders(
        List<Map<String, dynamic>> orders,
      ) {
        if (trimmedQuery.isEmpty) return List.from(orders);

        return orders.where((order) {
          if (order is Map) {
            final data = order['data'] != null
                ? Map<String, dynamic>.from(order['data'] as Map)
                : <String, dynamic>{};

            final customerName =
                data['customerName']?.toString().toLowerCase() ?? '';
            final customerNumber =
                data['customerNumber']?.toString().toLowerCase() ?? '';
            final salesOrderId =
                data['saleOrderNo']?.toString().toLowerCase() ?? '';
            final event = data['event']?.toString().toLowerCase() ?? '';

            return customerName.contains(trimmedQuery) ||
                customerNumber.contains(trimmedQuery) ||
                salesOrderId.contains(trimmedQuery) ||
                event.contains(trimmedQuery);
          }
          return false;
        }).toList();
      }

      _hivefilteredOrders = filterOrders(_rawOrders);
      print("✅ hivefilteredOrders count: ${_hivefilteredOrders.length}");

      if (hasListeners) notifyListeners();
    } catch (e, st) {
      print("❌ Error in searchHiveFilteredOrders: $e");
      print(st);
    }
  }

  void searchHiveFilteredAllOrders(String query) {
    print("🔍 searchHiveFilteredAllOrders called with query: '$query'");

    try {
      final trimmedQuery = query.trim().toLowerCase();
      print("📏 Trimmed Query: '$trimmedQuery'");

      List<Map<String, dynamic>> filterOrders(
        List<Map<String, dynamic>> orders,
      ) {
        if (trimmedQuery.isEmpty) return List.from(orders);

        return orders.where((order) {
          if (order is Map) {
            final data = order['data'] != null
                ? Map<String, dynamic>.from(order['data'] as Map)
                : <String, dynamic>{};

            final customerName =
                data['customerName']?.toString().toLowerCase() ?? '';
            final customerNumber =
                data['customerNumber']?.toString().toLowerCase() ?? '';
            final salesOrderId =
                data['saleOrderNo']?.toString().toLowerCase() ?? '';
            final event = data['event']?.toString().toLowerCase() ?? '';

            return customerName.contains(trimmedQuery) ||
                customerNumber.contains(trimmedQuery) ||
                salesOrderId.contains(trimmedQuery) ||
                event.contains(trimmedQuery);
          }
          return false;
        }).toList();
      }

      _hivefilteredAllOrders = filterOrders(_rawOrders);
      print("✅ hivefilteredAllOrders count: ${_hivefilteredAllOrders.length}");

      if (hasListeners) notifyListeners();
    } catch (e, st) {
      print("❌ Error in searchHiveFilteredAllOrders: $e");
      print(st);
    }
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

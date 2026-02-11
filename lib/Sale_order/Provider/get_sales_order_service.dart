import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// import '../../model/sales_order_model.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Notification/notification_service.dart';
import 'package:yen_pos/Notification/websocket_service.dart';
import 'package:yen_pos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Server_Client/handlers/webscoket_messgae_handler.dart';
import 'package:yen_pos/Server_Client/websocketService.dart';
import 'package:yen_pos/transactionPage/Model/transaction_model.dart';

class ApiServiceSalesOrderProvider extends ChangeNotifier {
  final NotificationWebSocketService _wsService =
      NotificationWebSocketService();

  final List<String> _wsUrls = [
    'wss://yenerp.com/fluttertestapi/salesorders/ws',
    'wss://yenerp.com/fluttertestapi/dispatches/ws',
    'wss://yenerp.com/fluttertestapi/heldorders/ws',
  ];

  final Map<String, WebSocketChannel> _wsConnections = {};
  bool _isDisposed = false;
  String _lastUpdateMessage = '';

  String get lastUpdateMessage => _lastUpdateMessage;

  ApiServiceSalesOrderProvider() {
    fetchOrdersFromHive();

    setupHiveListener();

    NotificationService.init();

    Future.delayed(const Duration(seconds: 2), () {
      for (var url in _wsUrls) {
        connectWebSocket(url);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;

    _wsService.disconnectAll();

    super.dispose();
  }

  /// Connect with auto-reconnect
  void connectWebSocket(String url) {
    if (_isDisposed) {
      return;
    }

    try {
      final channel = _wsService.connect(url);
      _wsConnections[url] = channel;

      // LISTEN FOR STREAM

      channel.stream.listen(
        (data) {
          _handleWebSocketMessage(data);
        },
        onError: (e) {
          _scheduleReconnect(url);
        },
        onDone: () {
          _scheduleReconnect(url);
        },
        cancelOnError: true,
      );
    } catch (e) {
      _scheduleReconnect(url);
    }
  }

  /// Schedules reconnect
  void _scheduleReconnect(String url) {
    if (_isDisposed) {
      return;
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (_isDisposed) {
        return;
      }

      _wsService.disconnect(url);

      connectWebSocket(url);
    });
  }

  /// Handles incoming WebSocket messages
  Future<void> _handleWebSocketMessage(dynamic rawMessage) async {
    try {
      final data = jsonDecode(rawMessage);

      final type = data['type'];
      final messageText = data['message'] ?? 'Update received';
      final payload = data['data'] ?? {};

      final notificationTitles = {
        'salesOrder_updated': 'Sale Order Updated',
        'Approved_salesOrder_updated': 'Order Approved',
        'dispatch_received': 'Dispatch Received',
        'received': 'Stock Received',

        'salesOrder_created': 'Open Order Created',
        'salesOrder_approval_updated': 'Sale Order Approval Updated',
        'approval_updated': 'Approval Approved',
        'salesOrder_created_confirm': "Confirm Order Created",
      };

      if (notificationTitles.containsKey(type)) {
        _lastUpdateMessage = messageText;

        notifyListeners();

        await NotificationService.showNotification(
          notificationTitles[type]!,
          messageText,
        );

        await sendataToServer({"type": type, "data": payload});
      } else {}
    } catch (e, stack) {}
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
    // Step 1: Handle "All Order" case
    if (selectedFilter == "All Order") {
      _hivefilteredAllOrders = List.from(_rawOrders);
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

      // Step 3: Filter the list
      _hivefilteredAllOrders = _rawOrders.where((order) {
        // Check if order has a valid data structure
        if (order.containsKey("data") && order["data"].containsKey("status")) {
          final orderStatus = order["data"]["status"].toString();
          final isMatch =
              orderStatus.toLowerCase() == targetStatus.toLowerCase();

          // Detailed per-item debug

          return isMatch;
        } else {
          return false;
        }
      }).toList();
    }

    // Step 4: Update UI
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

  void toggleGrouping() {
    _groupByDeliveryDate = !_groupByDeliveryDate;

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
    try {
      final trimmedQuery = query.trim().toLowerCase();

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

            if (match) {}

            return match;
          } else {
            return false;
          }
        }).toList();
      }

      // Apply filter to both lists
      _hivefilteredOrders = filterOrders(_rawOrders);
      _hivefilteredAllOrders = filterOrders(_rawOrders);

      // Notify listeners
      if (hasListeners) {
        notifyListeners();
      }
    } catch (e, st) {}
  }

  // 🔍 Search only hivefilteredOrders
  void searchHiveFilteredOrders(String query) {
    try {
      final trimmedQuery = query.trim().toLowerCase();

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

      if (hasListeners) notifyListeners();
    } catch (e, st) {}
  }

  void searchHiveFilteredAllOrders(String query) {
    try {
      final trimmedQuery = query.trim().toLowerCase();

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

      if (hasListeners) notifyListeners();
    } catch (e, st) {}
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

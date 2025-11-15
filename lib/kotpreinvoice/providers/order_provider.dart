import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import 'package:yenpos/Hive_Manager/hive_manager_kot.dart';
import '../handlers/FullCancelOrder_Handler.dart';
import '../handlers/ItemWiseCancel.dart';
import '../handlers/global_datamanager.dart';
import '../providers/upi_provider.dart';
import '../services/printer_services.dart';
import '../Helper/orderpatch_helper.dart';
import 'package:yenpos/Global/globals_data.dart';
import '../models/printer.dart';
import '../screens/Receiver methods/FullorderPatch_receiver.dart';
import '../screens/Receiver methods/itemwiseCancelreceiver.dart';
import '../services/hive_service.dart';
import '../services/serverreachable.dart';
import '../providers/printer_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'product_provider.dart';

class OrderProvider with ChangeNotifier {
  List<Map<String, dynamic>> _orders = [];
  Box? canceledOrderBox;
  Box? preInvoicesBox;
  Box? invoiceBox;
  late Box _orderBox;
  List<Map<String, dynamic>> _preInvoices = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> get preInvoices => _preInvoices;
  List<Map<String, dynamic>> get invoices => _invoices;
  String orderSource = const Uuid().v4();
  final Set<String> _processedInvoiceIds = {};
  late WebSocketChannel channel;
  String? lastProcessedMessage;
  bool ordersLoadedFromHive = false;
  bool get isOrderDataReady => ordersLoadedFromHive && _orders.isNotEmpty;

  /// Holds a reference so we can tell it when to reload
  ProductProvider? productProvider;
  UpiProviderDine? upiProvider;
  late final Map<String, Future<void> Function(Map<String, dynamic>)>
  _actionHandlers;
  late Map<String, Future<void> Function(Map<String, dynamic>)> _typeHandlers;

    void handleSeatTransferInClient(Map<String, dynamic> data) async {
    if (appType == 'server') {
      debugPrint("⚠️ [SeatTransfer] Skipped — running on server appType.");
      return;
    }
    final currentTable = data['currentTable']?.toString();
    final currentSeat = data['currentSeat']?.toString();
    final targetTable = data['targetTable']?.toString();
    final targetSeat = data['targetSeat']?.toString();
 
    if (currentTable == null || currentSeat == null || targetTable == null || targetSeat == null) {
      debugPrint("❌ [Client SeatTransfer] Missing required fields: $data");
      return;
    }
 
    debugPrint("🔄 [Client SeatTransfer] Processing: $currentTable ($currentSeat) → $targetTable ($targetSeat)");
 
    // Open Hive box for orders
    var ordersBox = Hive.isBoxOpen('ordersBox') ? Hive.box('ordersBox') : await Hive.openBox('ordersBox');
 
    int updatedCount = 0;
    List<Map<String, dynamic>> updatedOrders = [];
 
    // Find and update ALL matching orders in Hive (safe string comparison)
    for (var key in ordersBox.keys) {
      dynamic rawOrder = ordersBox.get(key);
      if (rawOrder == null) continue;
 
      // Decode if stringified
      if (rawOrder is String) {
        try {
          rawOrder = jsonDecode(rawOrder);
        } catch (e) {
          debugPrint("⚠️ [Client SeatTransfer] Failed to decode order $key: $e");
          continue;
        }
      }
 
      if (rawOrder is! Map<String, dynamic>) {
        debugPrint("⚠️ [Client SeatTransfer] Invalid order type for $key: ${rawOrder.runtimeType}");
        continue;
      }
 
      final order = Map<String, dynamic>.from(rawOrder);
 
      // Safe string match
      if (order['table']?.toString() == currentTable && order['seat']?.toString() == currentSeat) {
        debugPrint("✅ [Client SeatTransfer] Found matching order $key (ID: ${order['seathiveOrderId']})");
 
        // Update
        order['table'] = targetTable;
        order['seat'] = targetSeat;
        order['edit'] = "Yes";
        order['seat_transfer'] = true;
 
        // Save back
        await ordersBox.put(key, order);
        updatedOrders.add(order);
        updatedCount++;
        debugPrint("💾 [Client SeatTransfer] Updated Hive order $key → $targetTable ($targetSeat)");
      }
    }
 
    if (updatedCount == 0) {
      debugPrint("❌ [Client SeatTransfer] No matching orders found in local Hive (keys: ${ordersBox.keys.length}). Data: $data");
      // Optional: Trigger full sync as fallback
      // await requestDataFromServer(); // But avoid loop; use only if critical
      return;
    }
 
    debugPrint("✅ [Client SeatTransfer] Updated $updatedCount orders in Hive.");
 
    // Update in-memory _orders
    bool memoryUpdated = false;
    for (int i = 0; i < _orders.length; i++) {
      final inMemoryOrder = _orders[i];
      if (inMemoryOrder['table']?.toString() == currentTable && inMemoryOrder['seat']?.toString() == currentSeat) {
        _orders[i] = updatedOrders[0]; // Or merge if multiples; assume 1 for simplicity, or loop
        memoryUpdated = true;
        debugPrint("🔄 [Client SeatTransfer] Updated in-memory order ${inMemoryOrder['seathiveOrderId']}");
        break; // Update first match; extend for multiples if needed
      }
    }
 
    notifyListeners();
    debugPrint("🔄 [Client SeatTransfer] Notified listeners. Memory updated: $memoryUpdated");
  }

  /// Call this once from your UI after creating both providers
  void setUpiProvider(UpiProviderDine provider) {
    upiProvider = provider;
    debugPrint('🔗 OrderProvider linked to UpiProvider.');
  }

  void setProductProvider(ProductProvider pp) {
    productProvider = pp;
  }

  OrderProvider() {
    printerProvider = PrinterProviderDine();
    printerProvider.printerInitializeHive().then((_) {}).catchError((e) {});
    _initializeActionHandlers();
    _initializeTypeHandlers();
  }
  void _initializeActionHandlers() {
    _actionHandlers = {
      'allDataResponse': (data) async => handleReceivedData(data),
      'printerDetails': (data) async => _updatePrinterDetails(data),
      'updatePrinterItems': (data) async => _updatePrinterDetails(data),
      'invoiceGeneratedKOT': _handleInvoiceGenerated,
      'updateOrderStatus': _handleUpdateOrderStatus,
      'updateFullOrderCancelStatus': _handleFullOrderCancelStatus,
      'orderCancelled': _handleOrderCancelled,
      'branchwiseItems': _handleBranchwiseItems,
      'seat_transfer_applied': (data) async {
        final seathiveOrderId = data['seathiveOrderId'];
        final newTable = data['newTable'] ?? data['targetTable'];
        final newSeat = data['newSeat'] ?? data['targetSeat'];

        if (seathiveOrderId == null || newTable == null || newSeat == null) {
          return;
        }

        final ordersBox = HiveManagerKot().ordersBox;
        final allOrders = List<Map<String, dynamic>>.from(
          ordersBox.get('data') ?? [],
        );

        bool foundInHive = false;

        for (var order in allOrders) {
          if (order['seathiveOrderId'] == seathiveOrderId) {
            order['table'] = newTable;
            order['seat'] = newSeat;
            foundInHive = true;
          }
        }

        if (foundInHive) {
          await ordersBox.put('data', allOrders);
        } else {}

        bool foundInMemory = false;

        for (var order in _orders) {
          if (order['seathiveOrderId'] == seathiveOrderId) {
            order['table'] = newTable;
            order['seat'] = newSeat;
            foundInMemory = true;
          }
        }

        if (foundInMemory) {
          notifyListeners();
        } else {}
      },
      'reverseCancelOrderItem': _handleReverseCancelItem,
      'stockIncreaseUpdate': _handleStockIncreaseUpdate,
      'stockDecreaseUpdate': _handleStockDecreaseUpdate,
      'seat_transfer': (data) async => handleSeatTransferInClient,
         
      'updateUpiState': (data) async {
        try {
          final enabled = data['isUpiEnabled'] as bool?;
          debugPrint('📩 Received updateUpiState: $data');
          debugPrint('🔍 enabled current value: $enabled');

          // Safe access: Check null FIRST, then use ! or just access
          if (enabled != null && upiProvider != null) {
            debugPrint('📥 Applying new UPI state: $enabled');
            upiProvider!.setUpiState(enabled); // Now safe with prior check
          } else {
            debugPrint(
              '⚠️ Skipping UPI update: enabled=$enabled, upiProvider=${upiProvider != null ? "ready" : "null"}',
            );
            // Optional: Trigger UI to initialize providers, e.g., via a callback or event bus
          }
        } catch (e, st) {
          debugPrint(
            '❌ Error handling updateUpiState in OrderProvider: $e\n$st',
          );
        }
      },
      'sync_invoice_update': (data) async {
        final seathiveOrderId = data['seathiveOrderId'];
        final invoiceNo = data['invoiceNo'];
 
        final ordersBox = await Hive.openBox('ordersBox');
 
        for (final key in ordersBox.keys) {
          final order = ordersBox.get(key);
          if (order is Map && order['seathiveOrderId'] == seathiveOrderId) {
            final updatedOrder = Map<String, dynamic>.from(order)..['invoiceNo'] = invoiceNo;
            await ordersBox.put(key, updatedOrder);
          }
        }
 
        print('🔁 Synced invoice number update locally for seathiveOrderId: $seathiveOrderId');
      }
    };
  }

  late PrinterProviderDine printerProvider;

  void initializePrinterProvider(PrinterProviderDine provider) {
    printerProvider = provider;
  }

  void _initializeTypeHandlers() {
    _typeHandlers = {'order': (data) async => processOrderData(data)};
  }

  List<Map<String, dynamic>> get orders => _orders;

  Future<void> ensureWebSocketConnection() async {
    final isAlive = await isServerReachable(serverip, port);
    if (!isAlive) {
      debugPrint('❌ Server not reachable, skipping WebSocket connection');
      return;
    }
 
    try {
      final wsUrl = 'ws://$serverip:$port';
      debugPrint('🌐 Connecting to WebSocket: $wsUrl');
      channel = IOWebSocketChannel.connect(wsUrl);
      debugPrint('✅ WebSocket connected successfully');
 
      // Start listening for server messages
      listenForServerUpdates();
 
      // Send an initial ping
      channel!.sink.add(jsonEncode({"action": "ping"}));
      debugPrint('📡 Initial ping sent');
    } catch (e, stack) {
      debugPrint("❌ WebSocket connection error: $e");
      debugPrintStack(stackTrace: stack);
    }
  }
 
  Future<void> initializeWebSocket() async {
    await ensureWebSocketConnection();
  }
  Future<void> _handleInvoiceGenerated(Map<String, dynamic> data) async {
    final invoice = data['invoiceKOT'] as Map<String, dynamic>;
    final invoiceId = invoice['invoiceNo'] as String?;
    if (invoiceId != null && !_processedInvoiceIds.contains(invoiceId)) {
      _processedInvoiceIds.add(invoiceId);
      await addInvoice(invoice);
    } else {}
  }

  Future<void> _handleBranchwiseItems(Map<String, dynamic> data) async {
    print(
      "Fourth  Received branchwise items from server: ${data['data'].length} items",
    );
    final payload = data['data']; // Full item map
    try {
      final productBox = Hive.box('productBox');

      // ✅ Only this line is needed
      await productBox.put('data', {'data': payload});
      await productProvider!.initProductBox();

      if (productProvider != null) {
        await productProvider!.loadProductsFromHive();
      }

      GlobalDataManager().branchwiseItems = payload;
    } catch (e) {}
  }

  Future<void> _handleFullOrderCancelStatus(
    Map<String, dynamic> patchData,
  ) async {
    OrderPatchReceiver.updateOrdersFromPatch(
      orders: _orders,
      patchData: patchData,
      notifyUpdates: () => notifyListeners(),
    );
    await OrderPatchHiveUpdater.updateOrderInHive(
      patchData: patchData,
      hiveKey: 'data',
    );
  }

  Future<void> _handleOrderCancelled(Map<String, dynamic> data) async {
    await applyOrderCancelPatch(
      orderBox: _orderBox,
      inMemoryOrders: _orders,
      data: data,
    );
  }

  Future<void> _handleUpdateOrderStatus(Map<String, dynamic> data) async {
    final seathiveOrderId = data['seathiveOrderId'] as String?;
    final newStatus = data['status'] as String?;
    final preinvoiceTime = data['preinvoiceTime'] as String?;

    if (seathiveOrderId != null &&
        newStatus != null &&
        preinvoiceTime != null) {
      await patchSeatOrderStatus(seathiveOrderId, newStatus, preinvoiceTime);
    } else {}
  }

  Future<void> _handleReverseCancelItem(Map<String, dynamic> data) async {
    String hiveOrderId = data['hiveOrderId'];
    int updatedIndex = data['updatedIndex'];
    double updatedQuantity = data['updatedQuantity'];
    double updatedCancelledQty = data['updatedCancelledQty'];
    double totalAmount = data['totalAmount'];
    bool partiallyCancelled = data['partiallycancelled'];

    int index = orders.indexWhere((o) => o['hiveOrderId'] == hiveOrderId);
    if (index != -1) {
      orders[index]['quantities'][updatedIndex] = updatedQuantity;
      orders[index]['cancelledQty'][updatedIndex] = updatedCancelledQty;
      orders[index]['totalAmount'] = totalAmount;
      orders[index]['partiallycancelled'] = partiallyCancelled;

      // ✅ Make sure status is active
      orders[index]['status'] = 'active';

      // ✅ Optional safety: Recalculate total from quantities × prices
      double recalculatedTotal = 0.0;
      for (int i = 0; i < orders[index]['quantities'].length; i++) {
        recalculatedTotal +=
            (orders[index]['quantities'][i] as num) *
            (orders[index]['prices'][i] as num);
      }
      orders[index]['totalAmount'] = recalculatedTotal;

      notifyListeners();
    }
  }

  Future<void> _handleStockIncreaseUpdate(Map<String, dynamic> data) async {
    final branchAlias = data['branchAlias'];
    final varianceCode = data['varianceCode'];
    final varianceName = data['varianceName'];
    final updatedStock = data['updatedStock'];

    print(
      '📈 Stock Increase Received → $varianceName ($varianceCode) for $branchAlias',
    );
    print('🔢 New Stock: $updatedStock');

    // Optionally: update in-memory data or UI
    // For example:
    await _updateLocalMemoryStock(
      branchAlias,
      varianceCode,
      varianceName,
      updatedStock,
    );
    notifyListeners();
  }

  Future<void> _handleStockDecreaseUpdate(Map<String, dynamic> data) async {
    final branchAlias = data['branchAlias'];
    final varianceCode = data['varianceCode'];
    final varianceName = data['varianceName'];
    final updatedStock = data['updatedStock'];

    print(
      '📉 Stock Decrease Received → $varianceName ($varianceCode) for $branchAlias',
    );
    print('🔢 New Stock: $updatedStock');

    await _updateLocalMemoryStock(
      branchAlias,
      varianceCode,
      varianceName,
      updatedStock,
    );
    notifyListeners();
  }

  Future<void> _updateLocalMemoryStock(
    String branchAlias,
    String varianceCode,
    String varianceName,
    int updatedStock,
  ) async {
    try {
      dynamic globalData = GlobalDataManager().branchwiseItems;
      if (globalData == null || globalData['data'] == null) return;

      Map<String, dynamic> branchwiseData = Map<String, dynamic>.from(
        globalData['data'],
      );

      branchwiseData.forEach((itemKey, itemValue) {
        if (itemValue is Map && itemValue.containsKey('variance')) {
          final varianceMap = Map<String, dynamic>.from(itemValue['variance']);
          varianceMap.forEach((varianceKey, varianceValue) {
            if (varianceValue is Map) {
              final storedCode =
                  varianceValue['varianceitemCode']?.toString() ?? '';
              final storedName =
                  varianceValue['varianceName']?.toString() ?? '';
              if (storedCode == varianceCode && storedName == varianceName) {
                if (varianceValue.containsKey('branchwise')) {
                  Map<String, dynamic> branchwiseMap =
                      Map<String, dynamic>.from(varianceValue['branchwise']);
                  if (branchwiseMap.containsKey(branchAlias)) {
                    Map<String, dynamic> branchData = Map<String, dynamic>.from(
                      branchwiseMap[branchAlias],
                    );
                    branchData['localHiveStock_$branchAlias'] = updatedStock;
                    branchwiseMap[branchAlias] = branchData;
                    varianceValue['branchwise'] = branchwiseMap;
                    varianceMap[varianceKey] = varianceValue;
                    itemValue['variance'] = varianceMap;
                    branchwiseData[itemKey] = itemValue;
                  }
                }
              }
            }
          });
        }
      });

      globalData['data'] = branchwiseData;
      GlobalDataManager().branchwiseItems = globalData;

      print(
        '✅ In-memory stock updated successfully for $varianceName ($varianceCode)',
      );
    } catch (e) {
      print('⚠️ Error updating in-memory stock: $e');
    }
  }

  Future<void> requestDataFromServer() async {
    await initializeHive();
    await ensureWebSocketConnection();
    try {
      channel.sink.add(jsonEncode({'action': 'requestAllData'}));
      channel.sink.add(
        jsonEncode({'action': 'requestBranchwiseItemsForClient'}),
      );
      debugPrint("📤 Requested all data and branchwise items from server");
    } catch (e) {
      debugPrint("❌ Error sending data requests to server: $e");
    }
    print("first send request to server for items.");
  }

  Future<void> initializeHive() async {
    try {
      await initializeWebSocket();

      // Await HiveManagerKot's init() to open boxes first
      await HiveManagerKot().init();

      // Now safe to assign the boxes
      _orderBox = HiveManagerKot().ordersBox;
      canceledOrderBox = HiveManagerKot().cancelledOrderBox;
      invoiceBox = HiveManagerKot().invoicesBox;

      await loadOrdersFromHive(); // await loading after boxes ready

      print("✅ Hive initialized and orders loaded successfully");
    } catch (e, stack) {
      print("❌ Hive Initialization Error: $e\n$stack");
    }
  }

   Future<void> loadOrdersFromHive() async {
    print('📦 [Hive] Starting to load orders from Hive...');
 
    try {
      Box? orderBox;
 
      // ✅ Open the box safely
      if (!Hive.isBoxOpen('ordersBox')) {
        orderBox = await Hive.openBox('ordersBox');
      } else {
        orderBox = Hive.box('ordersBox');
      }
 
      // ✅ Check if the box is empty
      if (orderBox.isEmpty) {
        print('⚠️ [Hive] No orders found in box. Returning empty list.');
        _orders = [];
        notifyListeners();
        return;
      }
 
      // ✅ Load and convert Hive data to in-memory list
      _orders = orderBox.values
          .whereType<Map>() // Ensure valid map entries
          .map((orderData) {
        return Map<String, dynamic>.from(orderData);
      }).toList();
 
      print('✅ [Hive] Loaded ${_orders.length} orders successfully.');
 
      notifyListeners();
    } on HiveError catch (hiveError) {
      print('❌ [HiveError] Failed to load orders: $hiveError');
      _orders = [];
      notifyListeners();
    } on FormatException catch (formatError) {
      print('⚠️ [FormatError] Invalid data format while loading orders: $formatError');
      _orders = [];
      notifyListeners();
    } catch (e, stack) {
      print('🔥 [Error] Unexpected error while loading orders: $e');
      print('📜 Stack Trace: $stack');
      _orders = [];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    channel.sink.close();
    _orderBox.close();
    canceledOrderBox?.close();
    preInvoicesBox?.close();
    invoiceBox?.close();
    channel.sink.close();
    super.dispose();
  }

  void addOrder(Map<String, dynamic> order) {
    order['orderSource'] = orderSource; // Add the order source
    _orders.add(order);
    _saveOrdersToHive();
    notifyListeners();
  }

  void _saveOrdersToHive() async {
    try {
      print('💾 Starting to save orders to Hive...');
      print('📦 Total orders to save: ${_orders.length}');
      print('📂 Hive box name: ${_orderBox.name}');

      await _orderBox.put('data', _orders);

      print('✅ Orders successfully saved to Hive!');
      notifyListeners();
      print('🔄 Listeners notified after saving orders.');
    } catch (e, stackTrace) {
      print('❌ Error saving orders to Hive: $e');
      print('📜 StackTrace:\n$stackTrace');
    }
  }

  List<Map<String, dynamic>> getActiveOrdersForSeat(
    String tableNumber,
    String seat,
  ) {
    return _orders
        .where(
          (order) =>
              order['table'] == tableNumber &&
              order['seat'] == seat &&
              (order['status'] == 'active' || order['status'] == 'confirm'),
        ) // Only get active orders
        .toList();
  }

  List<Map<String, dynamic>> getRunningOrdersForSeat(
    String tableNumber,
    String seat,
  ) {
    return _orders
        .where(
          (order) =>
              order['table'] == tableNumber &&
                  order['seat'] == seat &&
                  order['status'] == 'active' ||
              order['status'] == 'confirm',
        ) // Only get active orders
        .toList();
  }

  List<Map<String, dynamic>> getCancelledOrdersForSeat(
    String tableNumber,
    String seat,
  ) {
    return _orders
        .where(
          (order) =>
              order['table'] == tableNumber &&
              order['seat'] == seat &&
              order['status'] == 'cancelled',
        ) // Only get cancelled orders
        .toList();
  }

  double getTableTotalPrice(String tableNumber) {
    final tableOrders = _orders
        .where(
          (order) =>
              order['table'] == tableNumber &&
              (order['status'] == 'active' || order['status'] == 'confirm'),
        )
        .toList();

    final total = tableOrders.fold(0.0, (sum, order) {
      final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
      return sum + totalAmount;
    });

    return total;
  }

  // double getTableTotalPrice(String tableNumber, String seat) {
  //   final tableOrders = _orders.where((order) =>
  //       order['table'].toString() == tableNumber &&
  //       order['seat'].toString() == seat &&
  //       order['status'] == 'active');

  //   final total = tableOrders.fold(0.0, (sum, order) {
  //     final amount = (order['totalAmount'] ?? order['amount']) as num? ?? 0.0;
  //     return sum + amount.toDouble();
  //   });

  //   return total;
  // }

  double getseatTotalPrice(String tableNumber, String seat) {
    // Fetch active orders for the specified table and seat
    final seatOrders = getActiveOrdersForSeat(tableNumber, seat);

    // Sum up the totalAmount field for relevant orders
    final total = seatOrders.fold(0.0, (sum, order) {
      if (order['table'] == tableNumber &&
          order['seat'] == seat &&
          (order['status'] == 'active' || order['status'] == 'confirm')) {
        final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
        return sum + totalAmount;
      }
      return sum;
    });

    return total;
  }

  String getWaiterName(String seathiveOrderId) {
    return "";
  }

  bool isseatOccupied(String tableNumber, String seat) {
    final seatOrders = getActiveOrdersForSeat(tableNumber, seat);
    return seatOrders.isNotEmpty;
  }

  List<String> getAvailableSeats(String tableNumber) {
    final occupiedSeats = _orders
        .where((order) => order['table'] == tableNumber)
        .map((order) => order['seat'])
        .toSet();
    final allSeats = List.generate(
      4,
      (index) => String.fromCharCode(65 + index),
    );
    return allSeats.where((seat) => !occupiedSeats.contains(seat)).toList();
  }

  List getOccupiedSeats(String tableNumber) {
    return _orders
        .where((order) => order['table'] == tableNumber)
        .map((order) => order['seat'])
        .toList();
  }

  void listenForServerUpdates() {
    // if (_isListening) return;
    // _isListening = true;

    // print("Listening for server updates..."); // Initial confirmation
    channel.stream.listen(
      (message) {
        // print("Actual message $message");
        if (message == lastProcessedMessage) {
          //print("⛔ Duplicate message ignored...$lastProcessedMessage");
          return;
        }
        lastProcessedMessage = message;

        handleIncomingMessage(message);
      },
      onError: (error) {
        clients.remove(channel);
      },
      onDone: () {
        clients.remove(channel);
      },
    );
  }

  Future<void> handleIncomingMessage(String message) async {
    try {
      final updateData = jsonDecode(message) as Map<String, dynamic>;
      final action = updateData['action'] as String?;
      final type = updateData['type'] as String?;

      if (action == null && type == null) return;

      if (action != null) {
        final handler = _actionHandlers[action];
        if (handler != null) {
          await handler(updateData);
        } else {
          print('No handler found for action: $action');
        }
      }

      if (type != null) {
        final typeHandler = _typeHandlers[type];
        if (typeHandler != null) {
          await typeHandler(updateData);
        } else {
          print('No handler found for type: $type');
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      print('Error handling incoming message: $e');
      print(stackTrace);
    }
  }

  void handleReceivedData(Map<String, dynamic> data) async {
    if (data.containsKey('orders')) {
      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(
        data['orders'],
      );
      for (var order in orders) {
        order['prices'] = toDoubleList(order['prices']);
        order['quantities'] = toDoubleList(order['quantities']);
        order['weights'] = toDoubleList(order['weights']);
        order['taxes'] = toDoubleList(order['taxes']);
      }
      await _saveToHiveBox(_orderBox, orders, 'orders');
      _orders = orders;
    }
    if (data.containsKey('invoices')) {
      final List<Map<String, dynamic>> invoices =
          List<Map<String, dynamic>>.from(data['invoices']);
      await _saveToHiveBox(invoiceBox, invoices, 'invoices');
      _invoices = invoices;
    }

    if (data.containsKey('printers')) {
      final List<dynamic> printers = data['printers'];
      for (var printerJson in printers) {
        if (printerJson is Map<String, dynamic>) {
          final printer = Printer.fromJson(
            Map<String, dynamic>.from(printerJson),
          );
          printerProvider.addPrinter(
            printer,
          ); // Use the PrinterProvider to store printer details in Hive
        }
      }
    }

    loadPrintersFromHive();
    notifyListeners();
  }

  Future<void> _saveToHiveBox(
    Box? box,
    List<Map<String, dynamic>> data,
    String boxName,
  ) async {
    if (box == null) {
      return;
    }

    await box.clear(); // Clear existing data to avoid duplicates
    for (var item in data) {
      await box.add(item);
    }
  }

  Future<void> patchSeatOrderStatus(
    String seathiveOrderId,
    String newStatus,
    String preinvoiceTime,
  ) async {
    final ordersBox = HiveManagerKot().ordersBox;

    try {
      // Filter matching orders
      final matchingOrderKeys = ordersBox.keys.where((key) {
        final order = ordersBox.get(key);
        return order is Map<String, dynamic> &&
            order['seathiveOrderId'] == seathiveOrderId;
      }).toList();

      // Update each matching order
      for (final orderKey in matchingOrderKeys) {
        final order = ordersBox.get(orderKey);

        if (order is Map<String, dynamic>) {
          order['status'] = newStatus;
          order['preinvoiceTime'] = preinvoiceTime;

          await ordersBox.put(orderKey, order);
        } else {
          print('Skipped invalid order at key $orderKey: $order');
        }
      }

      notifyListeners(); // Refresh UI after updates
    } catch (e, stackTrace) {
      print('Error updating order status for $seathiveOrderId: $e');
      print(stackTrace);
    }
  }

  Future<void> patchSeatCancelOrderStatus(
    String seathiveOrderId,
    String newStatus,
    String orderRemark,
  ) async {
    final ordersBox = HiveManagerKot().ordersBox;

    try {
      // Filter orders matching the seathiveOrderId
      final matchingOrderKeys = ordersBox.keys.where((key) {
        final order = ordersBox.get(key);
        return order is Map<String, dynamic> &&
            order['seathiveOrderId'] == seathiveOrderId;
      }).toList();

      // Update each matching order
      for (final orderKey in matchingOrderKeys) {
        final order = ordersBox.get(orderKey);

        if (order is Map<String, dynamic>) {
          order['status'] = newStatus;
          order['orderRemark'] = orderRemark;

          await ordersBox.put(orderKey, order);
        } else {
          print('Skipped invalid order at key $orderKey: $order');
        }
      }

      notifyListeners(); // Refresh UI
    } catch (e, stackTrace) {
      print('Error updating cancelled order status for $seathiveOrderId: $e');
      print(stackTrace);
    }
  }

  Future<void> patchOrderStatusBySeathiveOrderId(
    String seathiveOrderId,
    String newStatus,
  ) async {
    IOWebSocketChannel? channel;
    try {
      final String currentTime = DateFormat(
        "hh:mm:ss a",
      ).format(DateTime.now());
      print('🕒 Preparing to patch order status at $currentTime');
      print('📦 Target seathiveOrderId: $seathiveOrderId');
      print('🔄 New status to apply: $newStatus');

      // Open WebSocket connection
      final wsUrl = 'ws://$serverip:$port';
      print('🌐 Connecting to WebSocket: $wsUrl');
      channel = IOWebSocketChannel.connect(wsUrl);
      print('✅ WebSocket connected successfully');

      final patchData = {
        'action': 'patchOrderStatusBySeathiveOrderId',
        'seathiveOrderId': seathiveOrderId,
        'status': newStatus,
        'preinvoiceTime': currentTime,
        'statusEdited': "true",
        'edit': "Yes",
      };

      print('📤 Sending patch data: ${jsonEncode(patchData)}');
      channel.sink.add(jsonEncode(patchData));

      print('📂 Accessing Hive orders box directly...');
      final ordersBox = Hive.box('ordersBox'); // ✅ Directly open the Hive box
      final allOrders = ordersBox.get('data') ?? [];

      print('📦 Raw data currently in Hive box:');
      try {
        final formattedData = const JsonEncoder.withIndent(
          '  ',
        ).convert(allOrders);
        print(formattedData);
      } catch (e) {
        print('⚠️ Could not format Hive data as JSON. Raw content below:');
        print(allOrders);
      }

      print('📦 Raw data currently in Hive box:');
      print(jsonEncode(allOrders)); // Pretty-print current Hive data

      if (allOrders is List) {
        bool updated = false;
        print('📋 Total orders loaded from Hive: ${allOrders.length}');
        for (var order in allOrders) {
          if (order is Map<String, dynamic> &&
              order['seathiveOrderId'] == seathiveOrderId) {
            print('🧾 Found matching order before update: $order');
            order['status'] = newStatus;
            order['preinvoiceTime'] = currentTime;
            updated = true;
            print(
              '✅ Updated order status and preinvoiceTime for seathiveOrderId: $seathiveOrderId',
            );
            print('🆕 Updated order data: $order');
          }
        }

        if (updated) {
          await ordersBox.put('data', allOrders);
          print('💾 Hive data successfully updated.');
          print('📦 Hive box content *after update*:');
          print(jsonEncode(ordersBox.get('data'))); // Show updated Hive state
        } else {
          print('⚠️ No order found with seathiveOrderId: $seathiveOrderId');
        }
      } else {
        print(
          '❌ Expected a List in Hive orders, but got: ${allOrders.runtimeType}',
        );
      }

      notifyListeners();
      print('🔔 Notified listeners after patching order status');
    } catch (e, stackTrace) {
      print('❌ Error patching order $seathiveOrderId: $e');
      print('📜 StackTrace:\n$stackTrace');
    } finally {
      // Ensure WebSocket is closed
      await channel?.sink.close();
      print(
        '🔒 WebSocket connection closed for seathiveOrderId: $seathiveOrderId',
      );
    }
  }

  void updateOrderByHiveOrderId(
    String hiveOrderId,
    Map<String, dynamic> updatedOrder,
  ) {
    int index = orders.indexWhere((o) => o['hiveOrderId'] == hiveOrderId);
    if (index != -1) {
      orders[index] = updatedOrder;
      notifyListeners();
    }
  }

  void patchOrderQty(
    String seathiveOrderId,
    List<double> updatedQuantities,
    List<double> cancelledQty,
    List<double> amounts,
    double totalAmount,
    String partiallyCancelled,
    List<String> itemRemark,
  ) {
    for (var order in _orders) {
      if (order['seathiveOrderId'] == seathiveOrderId) {
        // Apply the updated quantities and cancel quantities
        order['quantities'] = updatedQuantities;
        order['cancelledQty'] = cancelledQty;
        order['amounts'] = amounts;
        order['totalAmount'] = totalAmount;
        order['partiallyCancelled'] = partiallyCancelled;
        order['itemRemark'] = itemRemark;

        order['fieldsEdited'] = "true";
        order['edit'] = "Yes";

        _saveOrdersToHive(); // Save to Hive
        notifyListeners(); // Notify listeners to update UI
        break;
      }
    }
  }

  Future<void> addInvoice(Map<String, dynamic> invoice) async {
    try {
      var invoiceBox = HiveManagerKot().invoicesBox;

      // Ensure box values are Maps
      final existingInvoices = invoiceBox.values
          .whereType<Map<String, dynamic>>()
          .toList();

      Map<String, dynamic>? existingInvoice;

      try {
        existingInvoice = existingInvoices.firstWhere(
          (entry) => entry['hiveInvoiceId'] == invoice['hiveInvoiceId'],
        );
      } catch (e) {
        // Not found, leave existingInvoice as null
        existingInvoice = null;
      }

      if (existingInvoice == null) {
        await invoiceBox.add(invoice);
        print("✅ Invoice added: ${invoice['hiveInvoiceId']}");
        await loadInvoices();
      } else {
        print("⚠️ Invoice already exists: ${invoice['hiveInvoiceId']}");
      }

      notifyListeners();
    } catch (e, st) {
      print("🔥 Error adding invoice: $e\n$st");
    }
  }

  Future<void> loadInvoices() async {
    var invoiceBox = HiveManagerKot().invoicesBox;

    _invoices = invoiceBox.values
        .where(
          (entry) => entry is Map<String, dynamic>,
        ) // ✅ Ensure correct format
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();

    notifyListeners();
  }

  Future<void> _updatePrinterDetails(Map<String, dynamic> printerData) async {
    try {
      if (printerData['action'] == 'removePrinter') {
        final printerName = printerData['printerName']?.toString();
        if (printerName != null && printerName.isNotEmpty) {
          printerProvider.removePrinterByName(printerName);
          debugPrint("✅ Removed printer: $printerName");
        } else {
          debugPrint(
            '⚠️ removePrinter action received but printerName is null or empty',
          );
        }
      } else {
        final printerJson = printerData['printer'];
        if (printerJson is Map<String, dynamic>) {
          final printer = Printer.fromJson(
            Map<String, dynamic>.from(printerJson),
          );
          final existingIndex = printerProvider.printers.indexWhere(
            (p) => p.name == printer.name,
          );
          if (existingIndex != -1) {
            printerProvider.updatePrinter(existingIndex, printer);
            debugPrint("✅ Updated printer: ${printer.name}");
          } else {
            printerProvider.addPrinter(printer);
            debugPrint("✅ Added printer: ${printer.name}");
          }
        } else {
          debugPrint("⚠️ Invalid printer data: $printerJson");
        }
      }
      // No notifyListeners here; PrinterProvider handles it
    } catch (e, st) {
      debugPrint('❌ Error updating printer details: $e\n$st');
    }
  }

  void handleServerData(Map<String, dynamic> data) {
    if (data.containsKey('action')) {
      switch (data['action']) {
        case 'receivedData':
          if (data.containsKey('data') && data['data']['type'] == 'order') {
            processOrderData(data['data']);
          }
          break;

        default:
      }
    }
  }

  List<double> safeListToDouble(List<dynamic>? list) {
    return list?.map((e) => (e is num ? e.toDouble() : 0.0)).toList() ?? [];
  }

  void processOrderData(Map<String, dynamic> orderData) {
    if (orderData['hiveOrderId'] == null) {
      orderData['hiveOrderId'] = const Uuid().v4();
    }

    orderData['prices'] = safeListToDouble(orderData['prices']);
    orderData['quantities'] = safeListToDouble(orderData['quantities']);

    orderData['weights'] = (orderData['weights'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    orderData['taxes'] = (orderData['taxes'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    if (_orders.any(
      (order) => order['hiveOrderId'] == orderData['hiveOrderId'],
    )) {
      return;
    }

    _orders.add(orderData);

    _saveOrdersToHive();
    notifyListeners();
  }

  int getLockedTableSeatCount(List<String> allTables) {
    return allTables.where((tableNumber) {
      final seatMatch = RegExp(r'\((\w)\)$').firstMatch(tableNumber);
      final seat = seatMatch != null ? seatMatch.group(1)! : 'A';
      return orders.any(
        (order) =>
            order['table'] == tableNumber &&
            order['seat'] == seat &&
            order['status'] == 'confirm',
      );
    }).length;
  }

  Future<void> appendAddonToOrderHive(
    String hiveOrderId,
    String varianceName,
    Map<String, dynamic> newAddon,
  ) async {
    try {
      final ordersBox = HiveManagerKot().ordersBox;

      // Retrieve all orders from Hive
      var allOrders = ordersBox.get('data') ?? [];
      if (allOrders is! List) {
        print('Invalid orders structure in Hive. Expected a List.');
        return;
      }

      // Find the corresponding order
      Map<String, dynamic>? order = allOrders.firstWhere(
        (order) => order['hiveOrderId'] == hiveOrderId,
        orElse: () => null,
      );

      if (order == null) {
        print('No order found with hiveOrderId: $hiveOrderId');
        return;
      }

      // Initialize addOns if missing or invalid
      if (order['addOns'] == null || order['addOns'] is! List) {
        order['addOns'] = <Map<String, dynamic>>[];
      }

      List<dynamic> addOns = order['addOns'];

      // Append the new add-on
      addOns.add({
        'varianceName': varianceName,
        'addOnName': newAddon['addOnName'] ?? 'Unknown',
        'quantity': (newAddon['quantity'] ?? 1).toInt(),
        'price': (newAddon['price'] ?? 0.0).toDouble(),
      });

      // Save updated orders back to Hive
      await ordersBox.put('data', allOrders);

      notifyListeners(); // Update the UI
    } catch (e, stackTrace) {
      print('Error appending add-on to order: $e');
      print(stackTrace);
    }
  }


  // Future<void> printOrderReceipts(Map<String, dynamic> orderData) async {
  //   try {
  //     debugPrint("🟢 Starting receipt print for order in OrderProvider");

  //     // Parse main order data safely
  //     final varianceNames = List<String>.from(orderData['varianceNames'] ?? []);
  //     final prices = (orderData['prices'] as List<dynamic>? ?? [])
  //         .map((e) => (e as num).toDouble())
  //         .toList();
  //     final quantities = (orderData['quantities'] as List<dynamic>? ?? [])
  //         .map((e) => (e as num).toDouble())
  //         .toList();
  //     final weights = (orderData['weights'] as List<dynamic>? ?? [])
  //         .map((e) => (e as num).toDouble())
  //         .toList();
  //     final amounts = (orderData['amounts'] as List<dynamic>? ?? [])
  //         .map((e) => (e as num).toDouble())
  //         .toList();

  //     final addOns = List<Map<String, dynamic>>.from(orderData['addOns'] ?? []);
  //     final config = List<Map<String, dynamic>>.from(orderData['config'] ?? []);
  //     final tokenNo = orderData['tokenNo'] ?? 0;
  //     final tableNumber = orderData['table'];
  //     final seat = orderData['seat']?.toString() ?? '';
  //     final date = orderData['date']?.toString() ?? '';
  //     final time = orderData['time']?.toString() ?? '';
  //     final waiter = orderData['waiter']?.toString() ?? '';
  //     final totalAmount =
  //         double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0;
  //     final orderType = orderData['orderType']?.toString() ?? '';

  //     debugPrint(
  //       "📝 Parsed main order details for table $tableNumber, seat $seat",
  //     );

  //     // Build a flat list of line-items (main + add-ons)
  //     List<Map<String, dynamic>> seatOrders = [];

  //     // Group add-ons by varianceName
  //     final groupedAddOns = <String, List<Map<String, dynamic>>>{};
  //     for (var addOn in addOns) {
  //       try {
  //         groupedAddOns.putIfAbsent(addOn['varianceName'], () => []).add(addOn);
  //       } catch (e, st) {
  //         debugPrint("⚠️ Failed to group add-on: $addOn\n$e\n$st");
  //       }
  //     }

  //     for (var i = 0; i < varianceNames.length; i++) {
  //       try {
  //         final name = varianceNames[i];
  //         var qty = quantities.length > i ? quantities[i] : 0.0;

  //         debugPrint("🔹 Processing item: $name | Qty: $qty");

  //         // Process add-ons first
  //         if (groupedAddOns.containsKey(name)) {
  //           for (var ao in groupedAddOns[name]!) {
  //             try {
  //               final addonQty = ao['quantity'] ?? 1.0;
  //               final addonPrice = ao['price'] ?? 0.0;

  //               seatOrders.add({
  //                 'itemName': '$name (${ao['addOnName']})',
  //                 'price': addonPrice,
  //                 'quantity': addonQty,
  //                 'weights': ao['weights'] ?? 0.0,
  //                 'amount': addonPrice * addonQty,
  //                 'addonQuantity': addonQty,
  //               });

  //               qty -= addonQty;
  //               debugPrint(
  //                 "➕ Add-on added: ${ao['addOnName']} x $addonQty = ₹${addonPrice * addonQty}",
  //               );
  //             } catch (e, st) {
  //               debugPrint(
  //                 "⚠️ Error processing add-on for $name: $ao\n$e\n$st",
  //               );
  //             }
  //           }
  //         }

  //         // Process main item
  //         if (qty > 0) {
  //           final myConfigs = config
  //               .where((c) => c['varianceName'] == name)
  //               .toList();

  //           seatOrders.add({
  //             'itemName': name,
  //             'price': prices.length > i ? prices[i] : 0.0,
  //             'quantity': qty,
  //             'weights': weights.length > i ? weights[i] : 0.0,
  //             'amount': amounts.length > i ? amounts[i] : 0.0,
  //             'config': myConfigs,
  //           });
  //           debugPrint(
  //             "🧾 Main item added: $name | Qty: $qty | Amount: ₹${amounts.length > i ? amounts[i] : 0.0}",
  //           );
  //         }
  //       } catch (e, st) {
  //         debugPrint("⚠️ Error processing item ${varianceNames[i]}: $e\n$st");
  //       }
  //     }

  //     debugPrint("📦 Total items to print: ${seatOrders.length}");

  //     await printerProvider.printerInitializeHive();
  //     debugPrint("🖨 Printer initialized");

  //     final overallPrinterIp = printerProvider.getOverallPrinterIp();

  //     if (overallPrinterIp != null) {
  //       debugPrint(
  //         "📤 Sending print job to overall printer ($overallPrinterIp)...",
  //       );
  //       await PrinterService.printReceipt(
  //         ipAddress: overallPrinterIp,
  //         tableNumber: tableNumber,
  //         seat: seat,
  //         date: date,
  //         time: time,
  //         waiter: waiter,
  //         total: totalAmount,
  //         seatOrders: seatOrders,
  //         tokenNumber: tokenNo,
  //         isOverall: true,
  //         userName: orderData['userName'] ?? '',
  //         orderType: orderType,
  //       );
  //       debugPrint("✅ Overall print job sent successfully!");
  //     } else {
  //       debugPrint("⚠️ Overall printer IP not found, skipping print");
  //     }

  //     // Print itemwise receipts
  //     await _printItemwiseReceipts(
  //       seatOrders: seatOrders,
  //       tableNumber: tableNumber,
  //       seat: seat,
  //       date: date,
  //       time: time,
  //       waiter: waiter,
  //       totalAmount: totalAmount,
  //       tokenNo: tokenNo,
  //       orderType: orderType,
  //       userName: orderData['userName'] ?? '',
  //     );
  //   } catch (e, st) {
  //     debugPrint("🔥 Fatal error in printOrderReceipts: $e\n$st");
  //   }
  // }

  // Future<void> _printItemwiseReceipts({
  //   required List<Map<String, dynamic>> seatOrders,
  //   required String tableNumber,
  //   required String seat,
  //   required String date,
  //   required String time,
  //   required String waiter,
  //   required double totalAmount,
  //   required int tokenNo,
  //   required String orderType,
  //   required String userName,
  // }) async {
  //   try {
  //     debugPrint("📤 Starting itemwise receipt printing in OrderProvider...");
  //     debugPrint("📌 Total line-items to print: ${seatOrders.length}");

  //     // Group items by printer IP
  //     Map<String, List<Map<String, dynamic>>> groupedByPrinter = {};
  //     for (var item in seatOrders) {
  //       try {
  //         final ip = printerProvider.getPrinterIpForItem(item['itemName']);
  //         if (ip != null) {
  //           groupedByPrinter.putIfAbsent(ip, () => []).add(item);
  //         }
  //       } catch (e, st) {
  //         debugPrint(
  //           "⚠️ Error grouping item by printer: ${item['itemName']}\n$e\n$st",
  //         );
  //       }
  //     }

  //     // Print each group
  //     for (var entry in groupedByPrinter.entries) {
  //       try {
  //         debugPrint(
  //           "📤 Printing to printer: ${entry.key} | Items: ${entry.value.length}",
  //         );
  //         await PrinterService.printReceipt(
  //           ipAddress: entry.key,
  //           tableNumber: tableNumber,
  //           seat: seat,
  //           date: date,
  //           time: time,
  //           waiter: waiter,
  //           total: totalAmount,
  //           seatOrders: entry.value,
  //           tokenNumber: tokenNo,
  //           isOverall: false,
  //           userName: userName,
  //           orderType: orderType,
  //         );
  //         debugPrint("✅ Printed successfully on printer: ${entry.key}");
  //       } catch (e, st) {
  //         debugPrint("❌ Failed to print on printer: ${entry.key}\n$e\n$st");
  //       }
  //     }

  //     debugPrint("🎉 Itemwise receipt printing completed!");
  //   } catch (e, st) {
  //     debugPrint("🔥 Fatal error in _printItemwiseReceipts: $e\n$st");
  //   }
  // }
}

List<double> toDoubleList(List<dynamic>? list) {
  return list?.map((e) => (e is num ? e.toDouble() : 0.0)).toList() ?? [];
}

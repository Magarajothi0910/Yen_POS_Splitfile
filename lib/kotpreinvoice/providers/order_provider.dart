import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:yen_pos/Hive_Manager/hive_manager_kot.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Server_Client/handlers/websocket_handler.dart';
import 'package:yen_pos/kotpreinvoice/handlers/cancel_order_response_handler.dart';
// import 'package:yen_pos/kotpreinvoice/handlers/cancel_order_approve_handler.dart';
import 'package:yen_pos/kotpreinvoice/handlers/handleRemoveHoldOrdersKOT.dart';
import 'package:yen_pos/kotpreinvoice/handlers/holdOrdersKOT.dart';
import 'package:yen_pos/kotpreinvoice/handlers/priorityUpdateHandler.dart';
import 'package:yen_pos/kotpreinvoice/providers/timerProvider.dart';
import 'package:yen_pos/kotpreinvoice/services/hive_service.dart';
import 'package:yen_pos/kotpreinvoice/services/sendDataToClients.dart';
import 'package:yen_pos/kotpreinvoice/widgets/cancel_order_approve.dart';
import 'package:yen_pos/main.dart';
import '../handlers/FullCancelOrder_Handler.dart';
import '../handlers/ItemWiseCancel.dart';
import '../handlers/global_datamanager.dart';
import '../providers/upi_provider.dart';
import '../services/printer_services.dart';
import '../Helper/orderpatch_helper.dart';
import 'package:yen_pos/Global/globals_data.dart';
import '../models/printer.dart';
import '../screens/Receiver methods/FullorderPatch_receiver.dart';
import '../screens/Receiver methods/itemwiseCancelreceiver.dart';
// import '../services/hive_service.dart';
import '../services/serverreachable.dart';
import '../providers/printer_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'product_provider.dart';

class OrderProvider with ChangeNotifier {
  // ValueNotifier<bool> refreshNotifier = ValueNotifier<bool>(false);

  List<Map<String, dynamic>> _orders = [];
  Box? canceledOrderBox;
  Box? preInvoicesBox;
  Box? invoiceBox;
  Box? branchwise_tables;
  late Box _orderBox;
  late Box holdOrderKOTBox;

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
  final Map<String, DateTime> _preInvoiceTimers = {};
  final Map<String, Timer> _activeTimers = {};

  bool chargeSubmit = true;

  /// Holds a reference so we can tell it when to reload
  ProductProvider? productProvider;
  UpiProviderDine? upiProvider;
  late final Map<String, Future<void> Function(Map<String, dynamic>)>
  _actionHandlers;
  late Map<String, Future<void> Function(Map<String, dynamic>)> _typeHandlers;
  // ValueNotifier<Map<String, List<String>>> extraTablesNotifier = ValueNotifier<Map<String, List<String>>>({});

  void handleSeatTransferInClient(Map<String, dynamic> data) async {
    if (appType == 'server') {
      debugPrint("⚠️ [SeatTransfer] Skipped — running on server appType.");
      return;
    }
    final currentTable = data['currentTable']?.toString();
    final currentSeat = data['currentSeat']?.toString();
    final targetTable = data['targetTable']?.toString();
    final targetSeat = data['targetSeat']?.toString();

    if (currentTable == null ||
        currentSeat == null ||
        targetTable == null ||
        targetSeat == null) {
      debugPrint("❌ [Client SeatTransfer] Missing required fields: $data");
      return;
    }

    debugPrint(
      "🔄 [Client SeatTransfer] Processing: $currentTable ($currentSeat) → $targetTable ($targetSeat)",
    );

    // Open Hive box for orders
    var ordersBox = Hive.isBoxOpen('ordersBox')
        ? Hive.box('ordersBox')
        : await Hive.openBox('ordersBox');

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
          debugPrint(
            "⚠️ [Client SeatTransfer] Failed to decode order $key: $e",
          );
          continue;
        }
      }

      if (rawOrder is! Map<String, dynamic>) {
        debugPrint(
          "⚠️ [Client SeatTransfer] Invalid order type for $key: ${rawOrder.runtimeType}",
        );
        continue;
      }

      final order = Map<String, dynamic>.from(rawOrder);

      // Safe string match
      if (order['table']?.toString() == currentTable &&
          order['seat']?.toString() == currentSeat) {
        debugPrint(
          "✅ [Client SeatTransfer] Found matching order $key (ID: ${order['seathiveOrderId']})",
        );

        // Update
        order['table'] = targetTable;
        order['seat'] = targetSeat;
        order['edit'] = "Yes";
        order['seat_transfer'] = true;

        // Save back
        await ordersBox.put(key, order);
        updatedOrders.add(order);
        updatedCount++;
        debugPrint(
          "💾 [Client SeatTransfer] Updated Hive order $key → $targetTable ($targetSeat)",
        );
      }
    }

    if (updatedCount == 0) {
      debugPrint(
        "❌ [Client SeatTransfer] No matching orders found in local Hive (keys: ${ordersBox.keys.length}). Data: $data",
      );
      // Optional: Trigger full sync as fallback
      return;
    }

    debugPrint("✅ [Client SeatTransfer] Updated $updatedCount orders in Hive.");

    // Update in-memory _orders
    bool memoryUpdated = false;
    for (int i = 0; i < _orders.length; i++) {
      final inMemoryOrder = _orders[i];
      if (inMemoryOrder['table']?.toString() == currentTable &&
          inMemoryOrder['seat']?.toString() == currentSeat) {
        _orders[i] =
            updatedOrders[0]; // Or merge if multiples; assume 1 for simplicity, or loop
        memoryUpdated = true;
        debugPrint(
          "🔄 [Client SeatTransfer] Updated in-memory order ${inMemoryOrder['seathiveOrderId']}",
        );
        break; // Update first match; extend for multiples if needed
      }
    }

    notifyListeners();
    debugPrint(
      "🔄 [Client SeatTransfer] Notified listeners. Memory updated: $memoryUpdated",
    );
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
    // _loadTimersFromStorage();
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
          debugPrint('⚠️ Invalid seat transfer payload: $data');
          return;
        }

        try {
          // final ordersBox = HiveManager.instance.ordersBox;
          final ordersBox = Hive.isBoxOpen('ordersBox')
              ? Hive.box('ordersBox')
              : await Hive.openBox('ordersBox');
          bool foundInHive = false;

          // 🔹 Iterate through all Hive entries (keys: 0, 1, 2, ...)
          for (var key in ordersBox.keys) {
            final order = ordersBox.get(key);
            if (order is Map<String, dynamic> &&
                order['seathiveOrderId'] == seathiveOrderId) {
              order['table'] = newTable;
              order['seat'] = newSeat;
              await ordersBox.put(key, order);
              foundInHive = true;
            }
          }

          if (foundInHive) {
            debugPrint(
              '✅ Seat transfer applied in Hive for order: $seathiveOrderId',
            );
          } else {
            debugPrint(
              '⚠️ Seat transfer: Order not found in Hive: $seathiveOrderId',
            );
          }

          bool foundInMemory = false;

          // 🔹 Update in-memory orders
          for (var order in _orders) {
            if (order['seathiveOrderId'] == seathiveOrderId) {
              order['table'] = newTable;
              order['seat'] = newSeat;
              foundInMemory = true;
            }
          }

          if (foundInMemory) {
            notifyListeners();
            debugPrint(
              '✅ Seat transfer applied to in-memory orders: $seathiveOrderId',
            );
          } else {
            debugPrint(
              '⚠️ Seat transfer: Order not found in memory: $seathiveOrderId',
            );
          }

          notifyListeners();
        } catch (e, st) {
          debugPrint('❌ Error applying seat transfer: $e\n$st');
        }
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
        final preinvoiceTime = data['preinvoiceTime'];

        // final ordersBox = HiveManager.instance.ordersBox;
        final ordersBox = Hive.isBoxOpen('ordersBox')
            ? Hive.box('ordersBox')
            : await Hive.openBox('ordersBox');

        for (final key in ordersBox.keys) {
          final order = ordersBox.get(key);

          if (order is Map && order['seathiveOrderId'] == seathiveOrderId) {
            final updatedOrder = Map<String, dynamic>.from(order)
              ..['invoiceNo'] = invoiceNo
              ..['status'] = 'confirm'
              ..['preinvoiceTime'] = preinvoiceTime; // ✅ update status here

            await ordersBox.put(key, updatedOrder);
          }
        }

        print(
          '🔁 Synced invoice number update locally for seathiveOrderId: $seathiveOrderId',
        );

        await loadOrdersFromHive();
      },

      'addHoldOrdersKOT': (data) async => handleAddHoldOrdersKOT(data, clients),
      'removeHoldOrdersKOT': (data) async =>
          handleRemoveHoldOrdersKOT(data, clients),
      'approveCancelOrder': (data) async =>
          handleApproveCancelOrder(data, clients),
      'cancelOrderApprovalResponse': (data) async =>
          handleCancelOrderApprovalResponse(data, clients),
      'priorityUpdate': (data) async => handlePriorityUpdate(data),
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
    // _initializeActionHandlers();
    // _initializeTypeHandlers();
  }

  // Future<void> _handleInvoiceGenerated(Map<String, dynamic> data) async {
  //   final invoice = data['invoiceKOT'] as Map<String, dynamic>;
  //   final invoiceId = invoice['invoiceNo'] as String?;
  //   if (invoiceId != null && !_processedInvoiceIds.contains(invoiceId)) {
  //     _processedInvoiceIds.add(invoiceId);
  //     await addInvoice(invoice);
  //   } else {}
  // }

  Future<void> _handleInvoiceGenerated(Map<String, dynamic> data) async {
    try {
      final invoice = data['invoiceKOT'] as Map<String, dynamic>;
      final invoiceId = invoice['invoiceNo'] as String?;
      if (invoiceId != null && !_processedInvoiceIds.contains(invoiceId)) {
        _processedInvoiceIds.add(invoiceId);
        await addInvoice(invoice);
        debugPrint('✅ Invoice generated and processed: $invoiceId');
        notifyListeners();
      } else {
        debugPrint('⚠️ Invoice already processed or invalid: $invoiceId');
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('❌ Error handling invoice generated: $e\n$st');
    }
  }

  Future<void> _handleBranchwiseItems(Map<String, dynamic> data) async {
    print(
      "Fourth  Received branchwise items from server: ${data['data'].length} items",
    );
    final payload = data['data']; // Full item map
    try {
      final productBox = Hive.box('items');

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
    await loadOrdersFromHive();
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
    debugPrint("received from sever : $data");
    String hiveOrderId = data['hiveOrderId'];
    int updatedIndex = data['updatedIndex'];
    double updatedQuantity = data['updatedQuantity'];
    double updatedCancelledQty = data['updatedCancelledQty'];
    double totalAmount = data['totalAmount'];
    bool partiallyCancelled = data['partiallycancelled'];
    List config = data['config'];

    int index = orders.indexWhere((o) => o['hiveOrderId'] == hiveOrderId);
    if (index != -1) {
      orders[index]['quantities'][updatedIndex] = updatedQuantity;
      orders[index]['cancelledQty'][updatedIndex] = updatedCancelledQty;
      orders[index]['totalAmount'] = totalAmount;
      orders[index]['partiallycancelled'] = partiallyCancelled;
      orders[index]['config'] = config;

      // ✅ Make sure status is active
      orders[index]['status'] = 'active';

      // ✅ Optional safety: Recalculate total from quantities × prices
      double recalculatedTotal = 0.0;

      for (int i = 0; i < orders[index]['quantities'].length; i++) {
        final String uom = orders[index]['uoms'][i].toString().toLowerCase();
        final num price = orders[index]['prices'][i] as num;
        final num quantity = orders[index]['quantities'][i] as num;
        final num weight = orders[index]['weights'][i] as num;

        num lineTotal = 0;

        // Weighted items
        if (uom == 'g' || uom == 'kg' || uom == 'kgs') {
          lineTotal = price * quantity * weight;
        }
        // Non-weighted items
        else {
          lineTotal = price * quantity;
        }

        recalculatedTotal += lineTotal;
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
      sendataToServer({'action': 'requestAllData'});
      sendataToServer({'action': 'requestBranchwiseItemsForClient'});
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
      _orderBox = Hive.isBoxOpen('ordersBox')
          ? Hive.box('ordersBox')
          : await Hive.openBox('ordersBox');
      // canceledOrderBox = HiveManagerKot().cancelledOrderBox;
      canceledOrderBox = Hive.isBoxOpen('cancelledOrderBox')
          ? Hive.box('cancelledOrderBox')
          : await Hive.openBox('cancelledOrderBox');
      invoiceBox = Hive.isBoxOpen('invoicesKOT')
          ? Hive.box('invoicesKOT')
          : await Hive.openBox('invoicesKOT');

      holdOrderKOTBox = Hive.isBoxOpen('holdOrdersKOT')
          ? Hive.box('holdOrdersKOT')
          : await Hive.openBox('holdOrdersKOT');

      await loadOrdersFromHive(); // await loading after boxes ready

      print("✅ Hive initialized and orders loaded successfully");
    } catch (e, stack) {
      print("❌ Hive Initialization Error: $e\n$stack");
    }
  }

  // Future<void> loadOrdersFromHive() async {
  //   print('📦 [Hive] Starting to load orders from Hive...');

  //   try {
  //     Box? orderBox;

  //     // ✅ Open the box safely
  //     if (!Hive.isBoxOpen('ordersBox')) {
  //       orderBox = await Hive.openBox('ordersBox');
  //     } else {
  //       orderBox = Hive.box('ordersBox');
  //     }

  //     // ✅ Check if the box is empty
  //     if (orderBox.isEmpty) {
  //       print('⚠️ [Hive] No orders found in box. Returning empty list.');
  //       _orders = [];
  //       notifyListeners();
  //       return;
  //     }

  //     // ✅ Load and convert Hive data to in-memory list
  //     _orders = orderBox.values
  //         .whereType<Map>() // Ensure valid map entries
  //         .map((orderData) {
  //           return Map<String, dynamic>.from(orderData);
  //         })
  //         .toList();

  //     print('✅ [Hive] Loaded ${_orders.length} orders successfully.');

  //     notifyListeners();
  //   } on HiveError catch (hiveError) {
  //     print('❌ [HiveError] Failed to load orders: $hiveError');
  //     _orders = [];
  //     notifyListeners();
  //   } on FormatException catch (formatError) {
  //     print(
  //       '⚠️ [FormatError] Invalid data format while loading orders: $formatError',
  //     );
  //     _orders = [];
  //     notifyListeners();
  //   } catch (e, stack) {
  //     print('🔥 [Error] Unexpected error while loading orders: $e');
  //     print('📜 Stack Trace: $stack');
  //     _orders = [];
  //     notifyListeners();
  //   }
  // }

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hasListeners) return;
      notifyListeners();
    });
  }

  Future<void> loadOrdersFromHive() async {
    print('📦 [Hive] Starting to load orders from Hive...');

    try {
      if (!_orderBox.isOpen) {
        print('⚠️ [Hive] ordersBox not open. Cannot load orders.');
        _orders = [];
        _safeNotify();
        return;
      }

      if (_orderBox.isEmpty) {
        print('⚠️ [Hive] No orders found in box. Returning empty list.');
        _orders = [];
        _safeNotify();
        return;
      }

      _orders = _orderBox.values
          .whereType<Map>()
          .map((orderData) => Map<String, dynamic>.from(orderData))
          .toList();

      print('✅ [Hive] Loaded ${_orders.length} orders successfully.');
      _safeNotify();
    } on HiveError catch (e) {
      print('❌ [HiveError] Failed to load orders: $e');
      _orders = [];
      _safeNotify();
    } catch (e, stack) {
      print('🔥 [Error] Unexpected error while loading orders: $e');
      print('📜 Stack Trace: $stack');
      _orders = [];
      _safeNotify();
    }
  }

  @override
  void dispose() {
    channel.sink.close();
    _orderBox.close();
    canceledOrderBox?.close();
    preInvoicesBox?.close();
    invoiceBox?.close();
    holdOrderKOTBox.close();
    channel.sink.close();
    _activeTimers.forEach((key, timer) {
      timer.cancel();
    });
    _activeTimers.clear();
    super.dispose();
  }

  // void _saveOrdersToHive() async {
  //   try {
  //     print('💾 Starting to save orders to Hive...');
  //     print('📦 Total orders to save: ${_orders.length}');
  //     print('📂 Hive box name: ${_orderBox.name}');

  //     _orderBox.clear();

  //     await _orderBox.put('data', _orders);
  //     final fullorders = await _orderBox.get('data');

  //     print("_orderBox of orders  $fullorders");

  //     print('✅ Orders successfully saved to Hive!');
  //     notifyListeners();
  //     print('🔄 Listeners notified after saving orders.');
  //   } catch (e, stackTrace) {
  //     print('❌ Error saving orders to Hive: $e');
  //     print('📜 StackTrace:\n$stackTrace');
  //   }
  // }

  void _saveOrdersToHive() async {
    try {
      print('💾 [Hive] Saving orders to box...');

      final box = _orderBox;

      // 🧹 Clear old data
      await box.clear();

      final Set<String> addedHiveOrderIds = {};
      final Map<int, dynamic> ordersMap = {};

      for (int i = 0; i < _orders.length; i++) {
        final order = _orders[i];
        final String hiveOrderId = order['hiveOrderId'];

        if (addedHiveOrderIds.contains(hiveOrderId)) {
          continue; // skip duplicate
        }

        addedHiveOrderIds.add(hiveOrderId);
        ordersMap[i] = order;
      }

      // ⚡ Save all orders at once
      await box.putAll(ordersMap);

      print('✅ [Hive] Orders saved successfully.');
      print('📦 Total Orders Saved: ${_orders.length}');
      notifyListeners();
    } catch (e, stack) {
      print('❌ [HiveError] Failed to save orders: $e');
      print('📜 Stack Trace: $stack');
    }
  }

  List<Map<String, dynamic>> getActiveOrdersForSeat(
    String tableNumber,
    String seat,
  ) {
    // debugPrint("_orders are ${_orders.first}");
    // for (int i = 0; i < _orders.length; i++) {
    //   debugPrint("_orders ::: is ${_orders[i]['hiveOrderId']}");
    // }

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
              (order['status'] == 'active' || order['status'] == 'confirm'),
        )
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

  // double getTableTotalPrice(String tableNumber) {
  //   final tableOrders = _orders
  //       .where(
  //         (order) =>
  //             order['table'] == tableNumber &&
  //             (order['status'] == 'active' || order['status'] == 'confirm'),
  //       )
  //       .toList();

  //   final total = tableOrders.fold(0.0, (sum, order) {
  //     final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
  //     return sum + totalAmount;
  //   });

  //   return total;
  // }

  double getTableTotalPrice(String tableNumber, String seatNumber) {
    final tableOrders = _orders
        .where(
          (order) =>
              order['table'] == tableNumber &&
              order['seat'] == seatNumber &&
              (order['status'] == 'active' || order['status'] == 'confirm'),
        )
        .toList();

    final total = tableOrders.fold<double>(
      0.0,
      (sum, order) => sum + ((order['totalAmount'] as num?)?.toDouble() ?? 0.0),
    );

    return total;
  }

  int getActiveTableCount(String tableNumber) {
    return _orders
        .where(
          (order) =>
              order['table'] == tableNumber && (order['status'] == 'active'),
        )
        .length;
  }

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

      debugPrint("Client data is $updateData");
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

  // void handleReceivedData(Map<String, dynamic> data) async {
  //   print("recieved message from sever , ${data['action']}");
  //   if (data.containsKey('orders')) {
  //     final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(
  //       data['orders'],
  //     );
  //     for (var order in orders) {
  //       order['prices'] = toDoubleList(order['prices']);
  //       order['quantities'] = toDoubleList(order['quantities']);
  //       order['weights'] = toDoubleList(order['weights']);
  //       order['taxes'] = toDoubleList(order['taxes']);
  //     }
  //     await _saveToHiveBox(_orderBox, orders, 'orders');
  //     _orders = orders;
  //   }
  //   if (data.containsKey('invoicesKOT')) {
  //     final List<Map<String, dynamic>> invoices =
  //         List<Map<String, dynamic>>.from(data['invoicesKOT']);
  //     await _saveToHiveBox(invoiceBox, invoices, 'invoicesKOT');
  //     _invoices = invoices;
  //   }

  //   if (data.containsKey('KOTprinters')) {
  //     final List<dynamic> printers = data['KOTprinters'];
  //     for (var printerJson in printers) {
  //       if (printerJson is Map<String, dynamic>) {
  //         final printer = Printer.fromJson(
  //           Map<String, dynamic>.from(printerJson),
  //         );
  //         printerProvider.addPrinter(
  //           printer,
  //         ); // Use the PrinterProvider to store printer details in Hive
  //       }
  //     }
  //   }

  //   if (data.containsKey('tables')) {
  //     print("client : tabels are recieved");
  //     tables = data['tables'];
  //     print("client : ${data['tables']}");

  //     await _saveToHiveBox(branchwise_tables, tables, 'branchwise_tables');
  //   }

  //   loadPrintersFromHive();
  //   notifyListeners();
  // }

  List<Map<String, dynamic>> buildTotalTableFromFlat(
    List<Map<String, dynamic>> flatTables,
  ) {
    final Map<String, List<Map<String, dynamic>>> areaMap = {};

    for (final table in flatTables) {
      final areaName = table['areaName']?.toString() ?? 'Unknown Area';

      areaMap.putIfAbsent(areaName, () => []);
      areaMap[areaName]!.add({
        'tableNumber': table['tableNumber'],
        'seats': table['seats'],
        'position': table['position'],
      });
    }

    return areaMap.entries.map((entry) {
      return {'areaName': entry.key, 'tables': entry.value};
    }).toList();
  }

  Future<void> saveTablesForBranch({
    required String aliasName,
    required List<Map<String, dynamic>> flatTables,
  }) async {
    final totalTable = buildTotalTableFromFlat(flatTables);

    final List<Map<String, dynamic>> hiveData = [
      {'location': aliasName, 'totalTable': totalTable},
    ];

    await productProvider?.tableBox.put('data', hiveData);

    debugPrint("✅ Tables saved to Hive in UI-compatible format");
    debugPrint("📍 Location: $aliasName");
    debugPrint("🏷️ Areas: ${totalTable.length}");
  }

  Future<void> handleReceivedData(Map<String, dynamic> data) async {
    try {
      final hiveManager = HiveManager();

      // 🔹 ORDERS
      if (data.containsKey('orders')) {
        final List<Map<String, dynamic>> orders =
            List<Map<String, dynamic>>.from(data['orders']);

        for (var order in orders) {
          order['prices'] = toDoubleList(order['prices']);
          order['quantities'] = toDoubleList(order['quantities']);
          order['weights'] = toDoubleList(order['weights']);
          order['taxes'] = toDoubleList(order['taxes']);
        }

        await _saveToHiveBox(_orderBox, orders, 'ordersBox');

        _orders = orders;
        debugPrint('✅ Orders data received and saved');
      }

      if (data.containsKey('holdOrdersKOT')) {
        final List<Map<String, dynamic>> holdOrders =
            List<Map<String, dynamic>>.from(data['holdOrdersKOT']);

        await _saveToHiveBox(holdOrderKOTBox, holdOrders, 'holdOrdersKOT');

        debugPrint('✅ Hold Orders data received and saved');
      }

      // 🔹 INVOICES
      if (data.containsKey('invoicesKOT')) {
        final List<Map<String, dynamic>> invoices =
            List<Map<String, dynamic>>.from(data['invoicesKOT']);

        await _saveToHiveBox(invoiceBox, invoices, 'invoicesKOT');

        _invoices = invoices;
        debugPrint('✅ Invoices data received and saved');
      }

      if (data.containsKey('tables') && data['tables'] is List) {
        debugPrint("📥 Raw Tables Data received");

        final List<Map<String, dynamic>> parsedTables = [];

        for (final area in data['tables']) {
          if (area is! Map) continue;

          final String areaName = area['areaName']?.toString() ?? '';

          final List<dynamic> areaTables = area['tables'] is List
              ? area['tables']
              : [];

          for (final table in areaTables) {
            if (table is! Map) continue;

            parsedTables.add({
              'areaName': areaName,
              'tableNumber': table['tableNumber']?.toString() ?? '',
              'seats': table['seats'] ?? 0,
              'position': table['position'],
            });
          }
        }

        debugPrint("📊 Total tables parsed: ${parsedTables.length}");
        if (parsedTables.isNotEmpty) {
          debugPrint("🧾 First table: ${parsedTables.first}");
          debugPrint("🧾 Last table: ${parsedTables.last}");
        }

        // ✅ Save in UI-compatible Hive format
        final deviceBox = Hive.box('deviceData');
        final String? aliasName = deviceBox.get('aliasName');

        if (aliasName != null) {
          final totalTable = buildTotalTableFromFlat(parsedTables);

          // ✅ Save to Hive
          final List<Map<String, dynamic>> hiveData = [
            {'location': aliasName, 'totalTable': totalTable},
          ];
          await productProvider?.tableBox.put('data', hiveData);

          // ✅ CRITICAL: Update globals.tables with grouped data
          tables = totalTable;

          debugPrint("Updated globals.tables with ${tables.length} areas");
          for (var area in tables) {
            debugPrint(
              "Area: ${area['areaName']}, Tables: ${(area['tables'] as List).length}",
            );
          }
        }

        debugPrint("✅ Tables parsed, grouped, and saved correctly");
      }

      // 🔹 KOT PRINTERS
      if (data.containsKey('KOTprinters')) {
        final List<dynamic> printers = data['KOTprinters'];

        for (var printerJson in printers) {
          if (printerJson is Map<String, dynamic>) {
            final printer = Printer.fromJson(
              Map<String, dynamic>.from(printerJson),
            );
            printerProvider.addPrinter(printer);
          }
        }

        debugPrint('✅ Printers data received');
      }

      await loadPrintersFromHive();
      notifyListeners();
    } catch (e, st) {
      debugPrint('❌ Error handling received data: $e\n$st');
    }
  }

  Future<void> _saveToHiveBox(
    Box? box,
    List<Map<String, dynamic>> data,
    String boxName,
  ) async {
    debugPrint('✅ _saveToHiveBoxOrders: ${data.length} records to Hive');

    // data.asMap().forEach((index, item) {
    //   debugPrint('📦 Record [$index]: $item');
    // });

    if (box == null) return;

    // ✅ Do NOT clear if incoming data is empty
    if (data.isNotEmpty) {
      debugPrint('Hive box cleared for $boxName');
      await box.clear();
    }

    for (final item in data) {
      await box.add(item);
    }

    debugPrint(
      '✅ _saveToHiveBoxOrders [$boxName] Saved ${data.length} records to Hive.',
    );
  }

  Future<void> patchSeatOrderStatus(
    String seathiveOrderId,
    String newStatus,
    String preinvoiceTime,
  ) async {
    final ordersBox = Hive.isBoxOpen('ordersBox')
        ? Hive.box('ordersBox')
        : await Hive.openBox('ordersBox');

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
      loadOrdersFromHive();

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
    final ordersBox = Hive.isBoxOpen('ordersBox')
        ? Hive.box('ordersBox')
        : await Hive.openBox('ordersBox');

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

  // timerFunctions >>>> ......
  // OrderProvider(){
  //   _loadTimersFromStorage();
  // }

  // void _loadTimersFromStorage() async {
  //   try {
  //     final box = await Hive.openBox('pre_invoice_timers');
  //     final storedTimers = box.toMap();

  //     storedTimers.forEach((key, value) {
  //       if (value is String) {
  //         _preInvoiceTimers[key] = DateTime.parse(value);
  //       }
  //     });

  //     // Start timers for existing pre-invoices
  //     _preInvoiceTimers.forEach((key, _) {
  //       _startTimerForKey(key);
  //     });

  //     notifyListeners();
  //   } catch (e) {
  //     debugPrint('Error loading timers: $e');
  //   }
  // }

  // void startTimer(String tableNumber, String seat) {
  //   final key = '$tableNumber-$seat';

  //   // Cancel existing timer if any
  //   _activeTimers[key]?.cancel();

  //   // Start new timer
  //   _preInvoiceTimers[key] = DateTime.now();
  //   _startTimerForKey(key);

  //   // Save to storage
  //   _saveTimerToStorage(key, _preInvoiceTimers[key]!);

  //   notifyListeners();
  // }

  // void _startTimerForKey(String key) {
  //   _activeTimers[key] = Timer.periodic(const Duration(seconds: 1), (timer) {
  //     notifyListeners();
  //   });
  // }

  // void stopTimer(String tableNumber, String seat) {
  //   final key = '$tableNumber-$seat';
  //   _activeTimers[key]?.cancel();
  //   _activeTimers.remove(key);
  //   _preInvoiceTimers.remove(key);

  //   // Remove from storage
  //   _removeTimerFromStorage(key);

  //   notifyListeners();
  // }

  // // Get elapsed time for a table-seat
  // Duration getElapsedTime(String tableNumber, String seat) {
  //   final key = '$tableNumber-$seat';
  //   final startTime = _preInvoiceTimers[key];
  //   if (startTime == null) return Duration.zero;

  //   return DateTime.now().difference(startTime);
  // }

  // // Get formatted time string
  // String getFormattedTime(String tableNumber, String seat) {
  //   final duration = getElapsedTime(tableNumber, seat);
  //   final minutes = duration.inMinutes;
  //   final seconds = duration.inSeconds % 60;

  //   return '${minutes}m ${seconds}s';
  // }

  // Color getPreinvoiceTimeColor(String tableNumber, String seat) {
  //   final duration = getElapsedTime(tableNumber, seat);
  //   final minutes = duration.inMinutes;
  //   return minutes < 2
  //       ? Colors.red.withOpacity(.2)
  //       : minutes < 5
  //       ? Colors.red.withOpacity(.3)
  //       : minutes < 10
  //       ? Colors.red.withOpacity(.6)
  //       : Colors.red.withOpacity(.6);
  // }

  // Color getOrderTimeColor(String tableNumber, String seat) {
  //   final duration = getElapsedTime(tableNumber, seat);
  //   final minutes = duration.inMinutes;
  //   return Colors.teal.withOpacity(.05);
  // }

  // // Check if timer exists for table-seat
  // bool hasTimer(String tableNumber, String seat) {
  //   final key = '$tableNumber-$seat';
  //   return _preInvoiceTimers.containsKey(key);
  // }

  // // Save timer to Hive
  // void _saveTimerToStorage(String key, DateTime startTime) async {
  //   try {
  //     final box = await Hive.openBox('pre_invoice_timers');
  //     await box.put(key, startTime.toIso8601String());
  //   } catch (e) {
  //     debugPrint('Error saving timer: $e');
  //   }
  // }

  // // Remove timer from Hive
  // void _removeTimerFromStorage(String key) async {
  //   try {
  //     final box = await Hive.openBox('pre_invoice_timers');
  //     await box.delete(key);
  //   } catch (e) {
  //     debugPrint('Error removing timer: $e');
  //   }
  // }

  Future<void> patchOrderStatusBySeathiveOrderId(
    String seathiveOrderId,
    String newStatus,
    String tableNumber,
    String seat,
  ) async {
    try {
      final String currentTime = DateFormat(
        "hh:mm:ss a",
      ).format(DateTime.now());
      print('🕒 Preparing to patch order status at $currentTime');
      print('📦 Target seathiveOrderId: $seathiveOrderId');
      print('🔄 New status to apply: $newStatus');

      final patchData = {
        'action': 'patchOrderStatusBySeathiveOrderId',
        'seathiveOrderId': seathiveOrderId,
        'status': newStatus,
        'preinvoiceTime': currentTime,
        'statusEdited': "true",
        'edit': "Yes",
      };

      print('📤 Sending patch data: ${jsonEncode(patchData)}');
      sendataToServer(patchData);

      bool updatedInMemory = false;
      for (int i = 0; i < _orders.length; i++) {
        if (_orders[i]['seathiveOrderId'] == seathiveOrderId) {
          _orders[i]['status'] = newStatus;
          _orders[i]['preinvoiceTime'] = currentTime;
          updatedInMemory = true;
          print('✅ Updated in-memory order status to: $newStatus for index $i');
          // no break here, update all matches
        }
      }

      if (updatedInMemory) {
        notifyListeners();
      }

      // Update all matching Hive orders
      final ordersBox = Hive.box('ordersBox');
      final dynamic hiveData = ordersBox.get('data') ?? [];
      if (hiveData is List) {
        final allOrders = List<Map<String, dynamic>>.from(hiveData);

        bool updatedInHive = false;
        for (int i = 0; i < allOrders.length; i++) {
          final order = allOrders[i];
          print('Before updating Hive order status : ${order['status']}');
          if (order['seathiveOrderId'] == seathiveOrderId) {
            order['status'] = newStatus;
            order['preinvoiceTime'] = currentTime;
            updatedInHive = true;
            print('💾 Updated Hive order at index $i');
            print('Before updating Hive order status : ${order['status']}');
          }
        }

        if (updatedInHive) {
          await ordersBox.put('data', allOrders);
          print('💾 Hive data successfully updated.');
        }
      }

      notifyListeners();

      print('🔔 Notified listeners after patching order status');
    } catch (e, stackTrace) {
      print('❌ Error patching order $seathiveOrderId: $e');
      print('📜 StackTrace:\n$stackTrace');
    } finally {}
  }

  // ✅ ADD THIS METHOD: Force reload orders from Hive to sync data
  Future<void> forceReloadOrders() async {
    try {
      print('🔄 Force reloading orders from Hive...');
      await loadOrdersFromHive();
      print('✅ Orders force reloaded successfully');
    } catch (e) {
      print('❌ Error force reloading orders: $e');
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
      final invoiceBox = Hive.isBoxOpen('invoicesKOT')
          ? Hive.box('invoicesKOT')
          : await Hive.openBox('invoicesKOT');

      // Ensure box values are Maps
      final existingInvoices = invoiceBox.values
          .whereType<Map<String, dynamic>>()
          .toList();

      Map<String, dynamic>? existingInvoice;

      try {
        existingInvoice = existingInvoices.firstWhere(
          (entry) => entry['invoiceNo'] == invoice['invoiceNo'],
        );
      } catch (e) {
        // Not found, leave existingInvoice as null
        existingInvoice = null;
      }

      if (existingInvoice == null) {
        await invoiceBox.add(invoice);
        print("✅ Invoice added: ${invoice['invoiceNo']}");
        await loadInvoices();
      } else {
        print("⚠️ Invoice already exists: ${invoice['invoiceNo']}");
      }

      notifyListeners();
    } catch (e, st) {
      print("🔥 Error adding invoice: $e\n$st");
    }
  }

  Future<void> loadInvoices() async {
    var invoiceBox = Hive.isBoxOpen('invoicesKOT')
        ? Hive.box('invoicesKOT')
        : await Hive.openBox('invoicesKOT');

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

  List<double> safeListToDouble(List<dynamic>? list) {
    return list?.map((e) => (e is num ? e.toDouble() : 0.0)).toList() ?? [];
  }

  void processOrderData(Map<String, dynamic> orderData) {
    // 1️⃣ Always work on a COPY to avoid reference duplication
    final Map<String, dynamic> data = Map<String, dynamic>.from(orderData);

    // 2️⃣ Normalize / generate hiveOrderId
    final String? incomingId = data['hiveOrderId']?.toString();

    if (incomingId == null || incomingId.isEmpty) {
      data['hiveOrderId'] = const Uuid().v4();
    }

    final String hiveOrderId = data['hiveOrderId'];

    // 3️⃣ HARD DUPLICATE CHECK (in-memory)
    final bool alreadyExists = _orders.any(
      (order) => order['hiveOrderId'] == hiveOrderId,
    );

    if (alreadyExists) {
      debugPrint("❌ Duplicate order blocked: $hiveOrderId");
      return;
    }

    // 4️⃣ Normalize numeric lists SAFELY
    data['prices'] = safeListToDouble(data['prices']);
    data['quantities'] = safeListToDouble(data['quantities']);

    data['weights'] = (data['weights'] as List? ?? [])
        .map((e) => (e as num).toDouble())
        .toList();

    data['taxes'] = (data['taxes'] as List? ?? [])
        .map((e) => (e as num).toDouble())
        .toList();

    // 5️⃣ ADD ORDER (single source of truth)
    _orders.add(data);

    // 6️⃣ Persist & notify
    _saveOrdersToHive();
    notifyListeners();

    debugPrint("✅ Order added successfully: $hiveOrderId");
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

  // Future<void> appendAddonToOrderHive(
  //   String hiveOrderId,
  //   String varianceName,
  //   Map<String, dynamic> newAddon,
  // ) async {
  //   try {
  //     final ordersBox = Hive.isBoxOpen('ordersBox')
  //         ? Hive.box('ordersBox')
  //         : await Hive.openBox('ordersBox');

  //     // Retrieve all orders from Hive
  //     var allOrders = ordersBox.get('data') ?? [];
  //     if (allOrders is! List) {
  //       print('Invalid orders structure in Hive. Expected a List.');
  //       return;
  //     }

  //     // Find the corresponding order
  //     Map<String, dynamic>? order = allOrders.firstWhere(
  //       (order) => order['hiveOrderId'] == hiveOrderId,
  //       orElse: () => null,
  //     );

  //     if (order == null) {
  //       print('No order found with hiveOrderId: $hiveOrderId');
  //       return;
  //     }

  //     // Initialize addOns if missing or invalid
  //     if (order['addOns'] == null || order['addOns'] is! List) {
  //       order['addOns'] = <Map<String, dynamic>>[];
  //     }

  //     List<dynamic> addOns = order['addOns'];

  //     // Append the new add-on
  //     addOns.add({
  //       'varianceName': varianceName,
  //       'addOnName': newAddon['addOnName'] ?? 'Unknown',
  //       'quantity': (newAddon['quantity'] ?? 1).toInt(),
  //       'price': (newAddon['price'] ?? 0.0).toDouble(),
  //     });

  //     // Save updated orders back to Hive
  //     await ordersBox.put('data', allOrders);

  //     notifyListeners(); // Update the UI
  //   } catch (e, stackTrace) {
  //     print('Error appending add-on to order: $e');
  //     print(stackTrace);
  //   }
  // }

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

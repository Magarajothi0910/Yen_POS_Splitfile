import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yenposapp/screens/kot_screen/global/globals.dart';
import '../../data/global_data_manager.dart';
import '../Helper/itemwiseCancelOrder.dart';
import '../Helper/orderpatch_helper.dart';
import '../models/globals.dart';
import '../models/hive boxes.dart';
import '../models/printer.dart';
import '../screens/Receiver methods/FullorderPatch_receiver.dart';
import '../screens/Receiver methods/itemwiseCancelreceiver.dart';
import '../screens/Receiver methods/reverseOrder-receive.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'printer_provider.dart';
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

  /// Holds a reference so we can tell it when to reload
  ProductProvider? productProvider;

  /// Call this once from your UI after creating both providers
  void setProductProvider(ProductProvider pp) {
    productProvider = pp;
  }

  List<Map<String, dynamic>> get orders => _orders;
  WebSocketChannel? channel;

  Future<void> initializeWebSocket() async {
    try {
      channel = IOWebSocketChannel.connect('ws://$serverip:$port');
      listenForServerUpdates();
      channel?.sink.add(jsonEncode({"action": "ping"}));
    } catch (e) {
    }
  }

  late PrinterProvider printerProvider;

  void initializePrinterProvider(PrinterProvider provider) {
    printerProvider = provider;
  }

  void requestDataFromServer() {
    try {
      initializeWebSocket();
      // channel = IOWebSocketChannel.connect(Uri.parse('ws://$serverip:$port'));
      channel?.sink.add(jsonEncode({
        'action': 'requestAllData',
      }));
      // if (appType == 'client' && channel != null) {
      //   channel?.sink.add(jsonEncode({'action': 'requestBranchwiseItems'}));
      // }
      initializeHive(); // Ensure boxes are open

    } catch (e) {
    }
  }

  Future<void> initializeHive() async {
    try {
      _orderBox = HiveManagerKot().ordersBox;
      canceledOrderBox = await HiveManagerKot().canceled_orderBox;
     
      await loadOrdersFromHive();
    } catch (e, st) {
    }
  }

  Future<void> loadOrdersFromHive() async {
    try {
      final dynamic raw = await _orderBox.get('data');
      if (raw is List) {
        _orders = raw.map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e);
          return m;
        }).toList();
      } else {
      }
    } catch (e, st) {
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Close WebSocket connection and Hive boxes
    channel?.sink.close();
    // _orderBox.close();
    // canceledOrderBox?.close();
    // preInvoicesBox?.close();
    // invoiceBox?.close();
    super.dispose();
  }


  void printOrders() {
    for (var order in _orders) {
      // This will print each order's details as a map
    }
  }

  void addOrder(Map<String, dynamic> order) {
    order['orderSource'] = orderSource; // Add the order source
    _orders.add(order);
    _saveOrdersToHive();
    notifyListeners();
  }

  void processIncomingOrder(Map<String, dynamic> orderData) {
    orderData['prices'] = toDoubleList(orderData['prices']);
    orderData['quantities'] = toDoubleList(orderData['quantities']);
    orderData['weights'] = toDoubleList(orderData['weights']);
    orderData['taxes'] = toDoubleList(orderData['taxes']);
    if (_orders
        .any((order) => order['hiveOrderId'] == orderData['hiveOrderId'])) {
      return;
    }

    _orders.add(orderData);

    _saveOrdersToHive();

    notifyListeners();
  }

  void _saveOrdersToHive() async {
    try {
      await _orderBox.put('data', _orders);

      notifyListeners(); // Ensure UI is updated after saving
    } catch (e) {}
  }

  List<Map<String, dynamic>> getActiveOrdersForSeat(
      String tableNumber, String seat) {
    return _orders
        .where((order) =>
            order['table'] == tableNumber &&
                order['seat'] == seat &&
                order['status'] == 'active' ||
            order['status'] == 'confirm') // Only get active orders
        .toList();
  }

  List<Map<String, dynamic>> getRunningOrdersForSeat(
      String tableNumber, String seat) {
    return _orders
        .where((order) =>
            order['table'] == tableNumber &&
            order['seat'] == seat &&
            order['status'] == 'active') // Only get active orders
        .toList();
  }

  List<Map<String, dynamic>> getCancelledOrdersForSeat(
      String tableNumber, String seat) {
    return _orders
        .where((order) =>
            order['table'] == tableNumber &&
            order['seat'] == seat &&
            order['status'] == 'cancelled') // Only get cancelled orders
        .toList();
  }

  double getTableTotalPrice(String tableNumber) {
    final tableOrders = _orders
        .where((order) =>
            order['table'] == tableNumber &&
            (order['status'] == 'active' || order['status'] == 'confirm'))
        .toList();

    // Sum the totalAmount field directly
    final total = tableOrders.fold(0.0, (sum, order) {
      final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
      return sum + totalAmount;
    });

    return total;
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

  bool isseatOccupied(String tableNumber, String seat) {
    final seatOrders = getActiveOrdersForSeat(tableNumber, seat);
    return seatOrders.isNotEmpty;
  }

  List<String> getAvailableSeats(String tableNumber) {
    final occupiedSeats = _orders
        .where((order) => order['table'] == tableNumber)
        .map((order) => order['seat'])
        .toSet();
    final allSeats =
        List.generate(4, (index) => String.fromCharCode(65 + index));
    return allSeats.where((seat) => !occupiedSeats.contains(seat)).toList();
  }

  List getOccupiedSeats(String tableNumber) {
    return _orders
        .where((order) => order['table'] == tableNumber)
        .map((order) => order['seat'])
        .toList();
  }

  void listenForServerUpdates() {
    // Initial confirmation
    channel?.stream.listen(
      (message) {
        handleIncomingMessage(message); // Process the message
      },
      onError: (error) {
      },
      onDone: () {
        // Optionally, reconnect here if needed
      },
    );
  }

  Future<void> handleIncomingMessage(String message) async {
    final updateData = jsonDecode(message);
    final action = updateData['action'];

    switch (action) {
      case 'allDataResponse':
        handleReceivedData(updateData);
        break;
      case 'printerDetails':
        _updatePrinterDetails(updateData);
        break;

      case 'invoiceGenerated':
        final invoice = updateData['invoice'];
        final invoiceId = invoice['hiveInvoiceId'];
        if (!_processedInvoiceIds.contains(invoiceId)) {
          _processedInvoiceIds.add(invoiceId);
          addInvoice(invoice);
        } else {
        }
        break;

      case 'updateOrderStatus':
        final String? seathiveOrderId = updateData['seathiveOrderId'];
        final String? newStatus = updateData['status'];
        final String? preinvoiceTime = updateData['preinvoiceTime'];

        // final String? orderRemark = updateData['orderRemark'];

        if (seathiveOrderId != null && newStatus != null) {
          patchSeatOrderStatus(seathiveOrderId, newStatus,
              preinvoiceTime!); // Ensure local persistence
        } else {}
        break;
      case 'updateFullOrderCancelStatus': // The action key for cancellation updates.
        OrderPatchReceiver.updateOrdersFromPatch(
          orders: _orders,
          patchData: updateData,
          notifyUpdates: () => notifyListeners(),
        );
        // Update persistent Hive data.
        await OrderPatchHiveUpdater.updateOrderInHive(
          patchData: updateData,
          hiveKey:
              'data', // Use the key under which orders are stored as a list.
        );
      case 'orderCancelled':
        await applyOrderCancelPatch(
          orderBox: _orderBox,
          inMemoryOrders: _orders,
          data: updateData,
        );
        break;

      case 'branchwiseItems':
        final payload = updateData['data'];
        final branchBox = await Hive.openBox('branchwise_items');
        await branchBox.put('data', payload);

        // **reload the in‐memory list** in ProductProvider
        if (productProvider != null) {
          // await productProvider!.loadProductsFromHive();
        } //kotProductLoad function
        GlobalDataManager().branchwiseItems = payload;
        break;

      case 'configDetailsUpdated':
        handleConfigDetailsUpdated(updateData);
        break;
      case 'seat_transfer':
        handleSeatTransfer(updateData);
        break;
      case 'reverseCancelOrderItem':
        final String hiveOrderId = updateData['hiveOrderId'];
        final int index = updateData['updatedIndex'];
        final double updatedQty =
            (updateData['updatedQuantity'] as num).toDouble();
        final double updatedCancelledQty =
            (updateData['updatedCancelledQty'] as num).toDouble();
        final double totalAmount =
            (updateData['totalAmount'] as num).toDouble();
        final bool partiallycancelled =
            updateData['partiallycancelled'] == true;

        await reverseCancellationInHiveByIndex(
          hiveOrderId,
          index,
          updatedQty,
          updatedCancelledQty,
          totalAmount,
          partiallycancelled,
        );

        notifyListeners();
        break;

      default:
    }

    notifyListeners();
  }

  void handleConfigDetailsUpdated(Map<String, dynamic> updateData) {
    // Extract the seathiveOrderId
    final String seathiveOrderId = updateData['seathiveOrderId'];

    // Extract the config list
    final List<dynamic> configList = updateData['config'];

    // Extract additional fields
    final List<double> quantities = (updateData['quantities'] as List<dynamic>)
        .map((e) => (e as num).toDouble())
        .toList();
    final List<double> cancelledQty =
        (updateData['cancelledQty'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();
    final List<double> amounts = (updateData['amounts'] as List<dynamic>)
        .map((e) => (e as num).toDouble())
        .toList();
    final String partiallyCancelled = updateData['partiallyCancelled'] ?? "No";
    final String? status = updateData['status']; // Optional field

    if (status != null) {
    }

    // Process each config item
    for (final configItem in configList) {
      if (configItem is Map<String, dynamic>) {
        final String varianceName = configItem['varianceName'] ?? '';
        final List<int> configQty = (configItem['configQty'] as List<dynamic>)
            .map((e) => e as int)
            .toList();
        final List<List<String>> addOn = (configItem['addOn'] as List<dynamic>)
            .map((addOnList) =>
                (addOnList as List<dynamic>).map((e) => e.toString()).toList())
            .toList();
        final List<String> variance = (configItem['variance'] as List<dynamic>)
            .map((e) => e.toString())
            .toList();
        final List<String> type = (configItem['type'] as List<dynamic>)
            .map((e) => e.toString())
            .toList();
        final List<String> remark = (configItem['remark'] as List<dynamic>)
            .map((e) => e.toString())
            .toList();

        // Log individual config details

        // Add further processing logic here if needed
      } else {
      }
    }
  }

  void handleSeatTransfer(Map<String, dynamic> data) async {
    final currentTable = data['currentTable'];
    final currentSeat = data['currentSeat'];
    final targetTable = data['targetTable'];
    final targetSeat = data['targetSeat'];

    // Open Hive box for orders
    var ordersBox = HiveManagerKot().ordersBox;
    // Find the matching order in the Hive database
    for (var key in ordersBox.keys) {
      final order = ordersBox.get(key);

      if (order is Map<String, dynamic> &&
          order['table'] == currentTable &&
          order['seat'] == currentSeat) {
        // Update the order with new table and seat information
        order['table'] = targetTable;
        order['seat'] = targetSeat;

        // Save the updated order back to Hive
        await ordersBox.put(key, order);

        // Update in-memory data as well
        for (var inMemoryOrder in _orders) {
          if (inMemoryOrder['table'] == currentTable &&
              inMemoryOrder['seat'] == currentSeat) {
            inMemoryOrder['table'] = targetTable;
            inMemoryOrder['seat'] = targetSeat;
          }
        }

        notifyListeners(); // Notify listeners to update the UI
        break;
      }
    }
  }

  void handleReceivedData(Map<String, dynamic> data) async {
    if (data.containsKey('orders')) {
      final List<Map<String, dynamic>> orders =
          List<Map<String, dynamic>>.from(data['orders']);
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

    if (data.containsKey('printerDetails')) {
      final List<dynamic> printers = data['printerDetails'];
      for (var printerJson in printers) {
        if (printerJson is Map<String, dynamic>) {
          final printer =
              Printer.fromJson(Map<String, dynamic>.from(printerJson));
          printerProvider.addPrinter(
              printer); // Use the PrinterProvider to store printer details in Hive
        }
      }
    }

    notifyListeners();
  }

  Future<void> _saveToHiveBox(
      Box? box, List<Map<String, dynamic>> data, String boxName) async {
    if (box == null) {
      return;
    }

    await box.clear(); // Clear existing data to avoid duplicates
    for (var item in data) {
      await box.add(item);
    }

  }

  Future<void> patchSeatOrderStatus(
      String seathiveOrderId, String newStatus, String preinvoiceTime) async {
    final ordersBox = HiveManagerKot().ordersBox;
    // Iterate over all orders and update those that match the seathiveOrderId
    final matchingOrderKeys = ordersBox.keys.where((key) {
      final order = ordersBox.get(key);

      // Ensure key is compatible and order is a map
      return order is Map && order['seathiveOrderId'] == seathiveOrderId;
    }).toList();

    // Update each matching order's status
    for (var orderKey in matchingOrderKeys) {
      try {
        final order = ordersBox.get(orderKey);

        // Only proceed if order is a valid map
        if (order is Map<String, dynamic>) {
          order['status'] = newStatus;
          order['preinvoiceTime'] = preinvoiceTime;

          // Save the updated order back to Hive
          await ordersBox.put(orderKey, order);
        }
      } catch (e) {
      }
    }
    notifyListeners(); // Notify listeners to refresh the UI
  }

  Future<void> patchSeatCancelOrderStatus(
      String seathiveOrderId, String newStatus, String orderRemark) async {
    final ordersBox = HiveManagerKot().ordersBox;

    // Iterate over all orders and update those that match the seathiveOrderId
    final matchingOrderKeys = ordersBox.keys.where((key) {
      final order = ordersBox.get(key);

      // Ensure key is compatible and order is a map
      return order is Map && order['seathiveOrderId'] == seathiveOrderId;
    }).toList();

    // Update each matching order's status
    for (var orderKey in matchingOrderKeys) {
      try {
        final order = ordersBox.get(orderKey);

        // Only proceed if order is a valid map
        if (order is Map<String, dynamic>) {
          order['status'] = newStatus;
          order['orderRemark'] = orderRemark;

          // Save the updated order back to Hive
          await ordersBox.put(orderKey, order);
        }
      } catch (e) {
      }
    }
    notifyListeners(); // Notify listeners to refresh the UI
  }

  Future<void> patchOrderStatusBySeathiveOrderId(
      String seathiveOrderId, String newStatus) async {
    try {
      String currentTime = DateFormat("hh:mm:ss a").format(DateTime.now());
      final channel = IOWebSocketChannel.connect('ws://$serverip:$port');

      final patchData = {
        'action': 'patchOrderStatusBySeathiveOrderId',
        'seathiveOrderId': seathiveOrderId,
        'status': newStatus,
        "preinvoiceTime": currentTime,
        'statusEdited': "true",
        'edit': "Yes",
      };
      channel.sink.add(jsonEncode(patchData));
      // channel.sink.close();
      // 🛠 Proper Hive patch logic if using 'data' key
      final ordersBox = HiveManagerKot().ordersBox;
      final allOrders = ordersBox.get('data') ?? [];

      if (allOrders is List) {
        for (var order in allOrders) {
          if (order['seathiveOrderId'] == seathiveOrderId) {
            order['status'] = newStatus;
            order['preinvoiceTime'] = currentTime;
          }
        }
        await ordersBox.put('data', allOrders); // Save the updated list back
      }
      notifyListeners();
    } catch (e) {
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
    var invoiceBox = await HiveManagerKot().invoiceBox;

    final existingInvoices = invoiceBox.values.toList();
    final existingInvoice = existingInvoices.firstWhere(
      (entry) => entry['hiveInvoiceId'] == invoice['hiveInvoiceId'],
      orElse: () => null,
    );

    if (existingInvoice == null) {
      await invoiceBox.add(invoice); // ✅ Only add unique invoice

      await loadInvoices(); // ✅ Refresh the provider after adding
    } else {
    }

    notifyListeners();
  }

  Future<void> loadInvoices() async {

    var invoiceBox = await HiveManagerKot().invoiceBox;

    _invoices = invoiceBox.values
        .where(
            (entry) => entry is Map<String, dynamic>) // ✅ Ensure correct format
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();

    notifyListeners();
  }

  void _updatePrinterDetails(Map<String, dynamic> printerData) {
    try {
      if (printerData['action'] == 'removePrinter') {
        final printerName = printerData['printerName'];
        printerProvider.removePrinterByName(printerName);
      } else {
        final printer = Printer(
          name: printerData['printerName'] ?? printerData['name'] ?? 'Unknown',
          ipAddress: printerData['ipAddress'] ?? 'Unknown',
          type: printerData['type'] ?? 'Unknown',
          items: List<String>.from(
              printerData['items'] ?? printerData['assignedItems'] ?? []),
        );

        final existingPrinterIndex =
            printerProvider.printers.indexWhere((p) => p.name == printer.name);

        if (existingPrinterIndex != -1) {
          printerProvider.updatePrinter(printer);
        } else {
          printerProvider.addPrinter(printer);
        }
      }

      printerProvider.notifyListeners();
    } catch (e) {
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
    orderData['taxes'] =
        (orderData['taxes'] as List).map((e) => (e as num).toDouble()).toList();
    if (_orders
        .any((order) => order['hiveOrderId'] == orderData['hiveOrderId'])) {
      return;
    }

    _orders.add(orderData);

    _saveOrdersToHive();
    notifyListeners();
  }

  Future<void> appendAddonToOrderHive(
    String hiveOrderId,
    String varianceName,
    Map<String, dynamic> newAddon,
  ) async {
    try {
      // Open the Hive box for orders
      final ordersBox = HiveManagerKot().ordersBox;

      // Retrieve all orders from Hive
      var allOrders = ordersBox.get('data') ?? [];
      if (allOrders is! List) {
        throw Exception("Invalid orders structure in Hive");
      }

      // Find the corresponding order
      Map<String, dynamic>? order = allOrders.firstWhere(
        (order) => order['hiveOrderId'] == hiveOrderId,
        orElse: () => null,
      );

      if (order == null) {
        return;
      }

      // Check if addOns field exists; initialize if necessary
      if (order['addOns'] == null) {
        order['addOns'] = [];
      }

      // Ensure addOns is a list
      List<dynamic> addOns = order['addOns'];

      // Append the new add-on
      addOns.add({
        'varianceName': varianceName,
        'addOnName': newAddon['addOnName'],
        'quantity': newAddon['quantity'] ?? 1, // Default to 1 if not provided
        'price': newAddon['price'] ?? 0.0, // Default to 0.0 if not provided
      });

      // Save the updated order back to Hive
      await ordersBox.put('data', allOrders);

      notifyListeners(); // Notify UI about the changes
    } catch (e) {
    }
  }
}

List<double> toDoubleList(List<dynamic>? list) {
  return list?.map((e) => (e is num ? e.toDouble() : 0.0)).toList() ?? [];
}

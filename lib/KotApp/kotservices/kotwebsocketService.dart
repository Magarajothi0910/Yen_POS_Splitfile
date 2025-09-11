import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../screens/kot_screen/global/globals.dart';
import '../kotproviders/order_type_provider.dart';
import '../models/hive boxes.dart';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:hive/hive.dart';
import '../models/globals.dart';
import '../models/printer.dart';
import '../kotproviders/login_provider.dart';
import '../kotproviders/order_provider.dart';
import '../kotproviders/printer_provider.dart';
import 'printer_services.dart';

class WebSocketServicekot with ChangeNotifier {
  late WebSocketChannel channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  List<Map<String, dynamic>> _orders = [];
  bool get isConnected =>
      _isConnected; // 🔴 Public getter for connection status
  Box<dynamic>?
      settingsBox; // Add this line to declare the Hive box for settings

  final List<Map<String, dynamic>> _receivedActions = [];
  List<Map<String, dynamic>> _receivedOrders = [];
  late OrderProvider orderProvider;
  late PrinterProvider printerProvider;
  late LoginProvider
      loginProvider; // Add this line to declare the LoginProvider field

  late OrderTypeProvider orderTypeProvider;
  List<Map<String, dynamic>> get orders => _orders;

  List<Map<String, dynamic>> get receivedActions => _receivedActions;
  List<Map<String, dynamic>> get receivedOrders => _receivedOrders;

  bool print2 = false;
  Map<String, String> _itemPrinterIpCache = {};

  WebSocketServicekot(
    this.orderProvider,
    this.printerProvider,
    this.orderTypeProvider,
    this.loginProvider, // Add LoginProvider to the constructor parameters
  ) {
    print2 = false;
    //startWebSocketClient();
    initializeHive();

    _connect();
  }
  void initializeHive() async {
    Hive.initFlutter(); // Ensure Hive is initialized (if not already done)
    settingsBox = await Hive.openBox('settings'); // Open the settings box
    // Read server IP and other initializations can be done here after box is opened
    startWebSocketClient();
  }

  Set<String> processedOrderIds = {}; // Global set to track processed orders

  void startWebSocketClient() {
    const Text("startWebSocketClient3...");
    try {

      channel = IOWebSocketChannel.connect('ws://$serverip:$port');

      channel.stream.listen(
        (message) {
          var jsonData = jsonDecode(message);
          if (jsonData['type'] == 'order') {
            _receivedOrders.add(jsonData);
            orderProvider.processIncomingOrder(jsonData);

            _cachePrinterIps(jsonData);

            // if (count == 0) {
            //   count++;
            //   _printOrder(jsonData);
            // }

            notifyListeners();
          } else if (jsonData['action'] == 'seat_tapped') {
            _receivedActions.add(jsonData);
            notifyListeners(); // Update UI
          } else if (jsonData['action'] == 'updatePrinterItems') {
            final updatedPrinter = Printer.fromJson(jsonData['printer']);
            printerProvider.updatePrinter(updatedPrinter);
            notifyListeners(); // Ensure the UI is updated
          } else if (jsonData['action'] == 'printerDetails' ||
              jsonData['action'] == 'items' ||
              jsonData['action'] == 'removePrinter') {
            _updatePrinterDetails(jsonData);
            notifyListeners(); // Ensure the UI is updated
          } else {
            _receivedActions.add(jsonData);
            notifyListeners();
            saveActionToHive(jsonData);
          }
        },
        onError: (error) {
        },
        onDone: () {
        },
      );

      _startHeartbeat();
    } catch (e) {
    }
  }

  void updateOrderProviderkot(OrderProvider newOrderProvider) {
    orderProvider = newOrderProvider;
  }

  void _cachePrinterIps(Map<String, dynamic> orderData) {
    List<String> varianceNames =
        List<String>.from(orderData['varianceNames'] ?? []);

    for (String varianceName in varianceNames) {
      if (!_itemPrinterIpCache.containsKey(varianceName)) {
        String? ip = printerProvider.getPrinterIpForItem(varianceName);
        if (ip != null) {
          _itemPrinterIpCache[varianceName] = ip;
        }
      }
    }
  }

  Set<String> processedOrders = {};
  Set<String> processedOverallPrints = {};

  bool isPrinting = false;

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      channel.sink.add(jsonEncode({
        'action': 'heartbeat',
      }));
    });
  }

  Future<void> saveActionToHive(Map<String, dynamic> action) async {
    try {
      var actionsBox = await Hive.openBox('actions');
      await actionsBox.add(action);
    } catch (e) {}
  }

  Future<void> loadOrdersFromHive() async {
    try {
      var orderBox = await HiveManagerKot().ordersBox;

      final data = orderBox.get('data');
      if (data != null && data is List) {
        _orders = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)),
        );
        _receivedOrders = _orders; // Ensure orders are loaded to receivedOrders
        notifyListeners();
      }
    } catch (e) {
    }
  }

  void _connect() {
    try {
      // ✅ Read the latest server IP from Hive before connecting
      channel = IOWebSocketChannel.connect('ws://$serverip:$port');
      _isConnected = true;
      notifyListeners();

      // _hideConnectionLostDialog();

      channel.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _isConnected = false;
          notifyListeners();
          // _showConnectionLostDialog();
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
          // _showConnectionLostDialog();
          _scheduleReconnect();
        },
      );

      _startHeartbeat();
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      // _showConnectionLostDialog();
      _scheduleReconnect();
    }
  }

  void reconnectWithNewIP(String newIp) {
    serverip = newIp; // ✅ Update global server IP
    channel.sink.close(); // ✅ Close the existing WebSocket connection
    _connect(); // ✅ Start a new connection
    notifyListeners(); // ✅ Notify UI about the change
  }

  Future<bool> _checkServerAvailability(String serverIp) async {
    try {
      final WebSocketChannel channel = IOWebSocketChannel.connect(
          'ws://$serverIp:$port'); // Replace PORT with your WebSocket server port

      channel.sink
          .add(jsonEncode({'action': 'heartbeat'})); // Send a heartbeat message
      final response = await channel.stream.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          channel.sink.close();
          return null;
        },
      );

      if (response != null) {
        final data = jsonDecode(response);
        if (data['action'] == 'heartbeatAck') {
          channel.sink.close();
          return true; // Server is online
        }
      }
      channel.sink.close();
      return false;
    } catch (e) {
      return false;
    }
  }


  void _handleMessage(dynamic message) {
    var jsonData = jsonDecode(message);

    if (jsonData.containsKey('table') && jsonData.containsKey('items')) {
      if (!jsonData.containsKey('orderSource')) {
        jsonData['orderSource'] = orderProvider.orderSource;
      }
    } else {
      _receivedActions.add(jsonData);
      notifyListeners();
      saveActionToHive(jsonData);
    }

    if (jsonData['action'] == 'printerDetails' ||
        jsonData['action'] == 'items' ||
        jsonData['action'] == 'removePrinter') {
      _updatePrinterDetails(jsonData);
    }
    if (jsonData['action'] == 'seat_returned') {
      // Remove the seat returned status from the _receivedActions list
      _receivedActions.removeWhere((action) =>
          action['action'] == 'seat_tapped' &&
          action['tableNumber'] == jsonData['tableNumber'] &&
          action['seat'] == jsonData['seat']);
      notifyListeners(); // Update UI to remove red indicator
    }
  }

  bool isPrintOrder = false;
  void _printOrder(Map<String, dynamic> orderData) async {

    final String hiveOrderId = orderData['hiveOrderId']?.toString() ?? "";
    if (hiveOrderId.isEmpty) {
      return;
    }
    List<String> itemNames = List<String>.from(orderData['itemNames'] ?? []);
    List<String> varianceNames =
        List<String>.from(orderData['varianceNames'] ?? []);
    List<double> prices = List<double>.from(orderData['prices'] ?? []);
    List<double> quantities = List<double>.from(orderData['quantities'] ?? []);
    List<double> weights = List<double>.from(orderData['weights'] ?? []);
    List<double> amounts = List<double>.from(orderData['amounts'] ?? []);
    List<Map<String, dynamic>> addOns =
        List<Map<String, dynamic>>.from(orderData['addOns'] ?? []);
    List<Map<String, dynamic>> config =
        List<Map<String, dynamic>>.from(orderData['config'] ?? []);
    int tokenNo = orderData['tokenNo'] ?? 0;
    String? overallPrinterIp = printerProvider.getOverallPrinterIp();
    final userName = loginProvider.loggedInUserName ?? "";
    String tableNumber = orderData['table'];
    String seat = orderData['seat']?.toString() ?? '';
    String date = orderData['date']?.toString() ?? '';
    String time = orderData['time']?.toString() ?? '';
    String waiter = orderData['waiter']?.toString() ?? '';
    double totalAmount =
        double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0;
    String orderType = orderData['orderType']?.toString() ?? '';

    List<Map<String, dynamic>> seatOrders = [];
    Map<String, List<Map<String, dynamic>>> groupedAddOns = {};
    for (var addOn in addOns) {
      String varianceName = addOn['varianceName'] ?? '';
      groupedAddOns.putIfAbsent(varianceName, () => []).add(addOn);
    }
    final stopwatch = Stopwatch()..start();
    // Group add-ons by varianceName
    try {

      for (int i = 0; i < itemNames.length; i++) {
        String varianceName = varianceNames.length > i ? varianceNames[i] : '';
        double itemQuantity = quantities.length > i ? quantities[i] : 0.0;

        // Add-ons processing
        if (groupedAddOns.containsKey(varianceName)) {
          for (var addOn in groupedAddOns[varianceName]!) {
            seatOrders.add({
              'itemName': '$varianceName(${addOn['addOnName']})',
              'varianceName': '',
              'price': addOn['price'] ?? 0.0,
              'quantity': addOn['quantity'] ?? 0.0,
              'weights': addOn['weights'] ?? 0.0,
              'amount': (addOn['price'] ?? 0.0) * (addOn['quantity'] ?? 1.0),
              'config': config
                  .where((c) => c['varianceName'] == varianceName)
                  .toList()
            });
            itemQuantity -= addOn['quantity'] ?? 0.0;
          }
        }

        if (itemQuantity > 0) {
          seatOrders.add({
            'itemName': varianceName,
            'varianceName': varianceName,
            'price': prices.length > i ? prices[i] : 0.0,
            'quantity': itemQuantity,
            'weights': weights.length > i ? weights[i] : 0.0,
            'amount': amounts.length > i ? amounts[i] : 0.0,
            'config':
                config.where((c) => c['varianceName'] == varianceName).toList(),
          });
        }
      }


      Map<String, List<Map<String, dynamic>>> groupedItemsByPrinter = {};
      for (var item in seatOrders) {
        String? itemPrinterIp = _itemPrinterIpCache[item['itemName']];

        if (itemPrinterIp != null) {
          groupedItemsByPrinter.putIfAbsent(itemPrinterIp, () => []).add(item);
        }
      }



      if (count2 == 0) {
        count2++;
        await Future.wait(groupedItemsByPrinter.keys.map((ip) {
          return _printReceipt(
              ip,
              groupedItemsByPrinter[ip]!,
              tableNumber,
              seat,
              date,
              time,
              waiter,
              totalAmount,
              tokenNo,
              userName,
              orderType);
        }));
      }
      if (overallPrinterIp != null && count3 == 0) {
        count3++;
        // ignore: use_build_context_synchronously
        await _printReceipt(
          overallPrinterIp,
          seatOrders,
          tableNumber,
          seat,
          date,
          time,
          waiter,
          totalAmount,
          tokenNo,
          userName,
          orderType,
          isOverall: true,
        );
      }
      // await ordersBox.put(hiveOrderId, savedOrder); // Mark order as printed
      // print("Order $hiveOrderId marked as printed.");
      stopwatch.stop();
    } catch (e) {
    }
  }

  Future<void> _printReceipt(
    String ipAddress,
    List<Map<String, dynamic>> seatOrders,
    String tableNumber,
    String seat,
    String date,
    String time,
    String waiter,
    double totalAmount,
    int tokenNo,
    String userName,
    String orderType, {
    bool isOverall = false,
  }) async {
    await PrinterService.printReceipt(
      ipAddress: ipAddress,
      tableNumber: tableNumber,
      seat: seat,
      date: date,
      time: time,
      waiter: waiter,
      total: totalAmount,
      seatOrders: seatOrders,
      tokenNumber: tokenNo.toString(),
      isOverall: isOverall,
      userName: userName,
      orderType: orderType,
    );
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return; // Avoid multiple timers
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isConnected) {
        _connect();
      } else {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      }
    });
  }

  void reconnect() {
    channel.sink.close();
    _connect();
  }

  sendDeviceCodeToServer(String deviceCode) {
    final channel = IOWebSocketChannel.connect(
        'ws://$serverip:$port'); // Server WebSocket URL
    final message = jsonEncode({
      'action': 'newClientConnected',
      'deviceCode': deviceCode,
    });

    channel.sink.add(message);
    channel.stream.listen((message) {
      var data = jsonDecode(message);

      // Handle received data (for orders, preInvoice, invoice, etc.)
      orderProvider.handleServerData(data);
    }, onError: (error) {
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    channel.sink.close();
    super.dispose();
  }

  void sendPrinterDetails(Printer printer) {
    final data = {
      'action': 'printerDetails',
      'name': printer.name,
      'ipAddress': printer.ipAddress,
      'type': printer.type,
      'items': printer.items,
      'orderSource': orderProvider.orderSource,
    };

    channel.sink.add(jsonEncode(data));
  }

  void sendAssignedItems(Printer printer) {
    final data = {
      'action': 'updatePrinterItems',
      'printer': printer.toJson(), // Ensure printer is converted to JSON
    };
    channel.sink.add(jsonEncode(data));
  }

  void sendRemovePrinter(String printerName) {
    final data = {
      'action': 'removePrinter',
      'printerName': printerName,
      'orderSource': orderProvider.orderSource,
    };

    channel.sink.add(jsonEncode(data));
  }

  void _updatePrinterDetails(Map<String, dynamic> printerData) {
    try {
      if (printerData['action'] == 'removePrinter') {
        final printerName = printerData['printerName'];
        printerProvider.removePrinterByName(printerName);
      } else {
        final printer = Printer(
          name: printerData['printerName'] ?? printerData['name'] ?? '',
          ipAddress: printerData['ipAddress'] ?? '',
          type: printerData['type'] ?? '',
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
    } catch (e) {}
  }
}

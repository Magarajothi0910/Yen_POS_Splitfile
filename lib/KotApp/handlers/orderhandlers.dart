import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../kotproviders/printer_provider.dart';
import '../kotservices/Token_service.dart';
import '../kotservices/printer_services.dart';
import '../kotservices/sendDataToClients.dart';
import '../kotservices/sync_service.dart';

final SyncServiceKot _syncService = SyncServiceKot();
Map<String, String> _itemPrinterIpCache = {};

Future<void> handleOrder(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  dynamic branchName = data['branchName'];
  final seat = data['seat'];
  data['deviceId'] = data['deviceId']?.toString() ?? '';

  if (data['seathiveOrderId'] == null || data['seathiveOrderId'].isEmpty) {
    data['seathiveOrderId'] = generateSeathiveOrderId(branchName, seat);
  } else {
  }

  final date = data['date'];
  final time = data['time'];
  if (branchName != null && date != null && time != null) {
    data['hiveOrderId'] = await generatehiveOrderId(branchName);
  }

  data['tokenNo'] = generateTokenNumber();
  sendDataToClients(data, clients);

  await _syncService.saveOrderToHive(data);
  await _printReceiptOnServer(data);
  await _printItemwiseReceipts(data);

}

Future<void> _printReceiptOnServer(Map<String, dynamic> orderData) async {
  // parse fields exactly like your client did:
  final hiveOrderId = orderData['hiveOrderId']?.toString() ?? '';
  final itemNames = List<String>.from(orderData['itemNames'] ?? []);
  final varianceNames = List<String>.from(orderData['varianceNames'] ?? []);
  final prices = (orderData['prices'] as List<dynamic>? ?? [])
      .map((e) => (e as num).toDouble())
      .toList();
  final quantities = (orderData['quantities'] as List<dynamic>? ?? [])
      .map((e) => (e as num).toDouble())
      .toList();
  final weights = (orderData['weights'] as List<dynamic>? ?? [])
      .map((e) => (e as num).toDouble())
      .toList();
  final amounts = (orderData['amounts'] as List<dynamic>? ?? [])
      .map((e) => (e as num).toDouble())
      .toList();

  final addOns = List<Map<String, dynamic>>.from(orderData['addOns'] ?? []);
  final config = List<Map<String, dynamic>>.from(orderData['config'] ?? []);
  final tokenNo = orderData['tokenNo'] ?? 0;
  final tableNumber = orderData['table'];
  final seat = orderData['seat']?.toString() ?? '';
  final date = orderData['date']?.toString() ?? '';
  final time = orderData['time']?.toString() ?? '';
  final waiter = orderData['waiter']?.toString() ?? '';
  final totalAmount =
      double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0;
  final orderType = orderData['orderType']?.toString() ?? '';

  // Build a flat list of line‐items (main + add-ons)
  List<Map<String, dynamic>> seatOrders = [];
  final groupedAddOns = <String, List<Map<String, dynamic>>>{};
  for (var addOn in addOns) {
    groupedAddOns.putIfAbsent(addOn['varianceName'], () => []).add(addOn);
  }

  for (var i = 0; i < varianceNames.length; i++) {

    final name = varianceNames[i];
    var qty = quantities.length > i ? quantities[i] : 0.0;
    // add-ons first
    if (groupedAddOns.containsKey(name)) {
      for (var ao in groupedAddOns[name]!) {
        seatOrders.add({
          'itemName': '${name}(${ao['addOnName']})',
          'price': ao['price'] ?? 0.0,
          'quantity': ao['quantity'] ?? 0.0,
          'weights': ao['weights'] ?? 0.0,
          'amount': (ao['price'] ?? 0) * (ao['quantity'] ?? 1),
        });
        qty -= ao['quantity'] ?? 0.0;
      }
    }
    if (qty > 0) {
      seatOrders.add({
        'itemName': name,
        'price': prices.length > i ? prices[i] : 0.0,
        'quantity': qty,
        'weights': weights.length > i ? weights[i] : 0.0,
        'amount': amounts.length > i ? amounts[i] : 0.0,
      });
    }

    // change it to:
    if (qty > 0) {
      // grab only the configs that belong to this variance
      final myConfigs = config.where((c) => c['varianceName'] == name).toList();

      seatOrders.add({
        'itemName': name,
        'price': prices.length > i ? prices[i] : 0.0,
        'quantity': qty,
        'weights': weights.length > i ? weights[i] : 0.0,
        'amount': amounts.length > i ? amounts[i] : 0.0,
        'config': myConfigs,
      });
    }
  }
  final printerService = PrinterProvider();
  await printerService.initializeHive();
  final overallPrinterIp = await printerService.getOverallPrinterIp();
  Map<String, List<Map<String, dynamic>>> groupedItemsByPrinter = {};
  for (var item in seatOrders) {
    String? itemPrinterIp = _itemPrinterIpCache[item['itemName']];

    if (itemPrinterIp != null) {
      groupedItemsByPrinter.putIfAbsent(itemPrinterIp, () => []).add(item);
    }
  }



  if (overallPrinterIp != null) {
    await PrinterService.printReceipt(
      ipAddress: overallPrinterIp,
      tableNumber: tableNumber,
      seat: seat,
      date: date,
      time: time,
      waiter: waiter,
      total: totalAmount,
      seatOrders: seatOrders,
      tokenNumber: tokenNo.toString(),
      isOverall: true,
      userName: orderData['userName'] ?? '',
      orderType: orderType,
    );
  }
}

Future<void> _printItemwiseReceipts(Map<String, dynamic> orderData) async {
  // parse out exactly as in _printReceiptOnServer
  final varianceNames = List<String>.from(orderData['varianceNames'] ?? []);
  final prices = (orderData['prices'] as List<dynamic>? ?? [])
      .map((e) => (e as num).toDouble())
      .toList();
  final quantities = (orderData['quantities'] as List<dynamic>? ?? [])
      .map((e) => (e as num).toDouble())
      .toList();
  final weights = (orderData['weights'] as List<dynamic>? ?? [])
      .map((e) => (e as num).toDouble())
      .toList();
  final amounts = (orderData['amounts'] as List<dynamic>? ?? [])
      .map((e) => (e as num).toDouble())
      .toList();
  final addOns = List<Map<String, dynamic>>.from(orderData['addOns'] ?? []);
  final config = List<Map<String, dynamic>>.from(orderData['config'] ?? []);
  final tableNumber = orderData['table'];
  final seat = orderData['seat']?.toString() ?? '';
  final date = orderData['date']?.toString() ?? '';
  final time = orderData['time']?.toString() ?? '';
  final waiter = orderData['waiter']?.toString() ?? '';
  final totalAmount =
      double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0;
  final tokenNo = orderData['tokenNo']?.toString() ?? '';
  final orderType = orderData['orderType']?.toString() ?? '';
  final userName = orderData['userName'] ?? '';

  // build flat list of all line-items (main + add-ons + config)
  List<Map<String, dynamic>> seatOrders = [];
  final groupedAddOns = <String, List<Map<String, dynamic>>>{};
  for (var ao in addOns) {
    groupedAddOns.putIfAbsent(ao['varianceName'], () => []).add(ao);
  }

  for (var i = 0; i < varianceNames.length; i++) {
    final name = varianceNames[i];
    double qty = quantities.length > i ? quantities[i] : 0.0;

    // add-ons
    if (groupedAddOns.containsKey(name)) {
      for (var ao in groupedAddOns[name]!) {
        seatOrders.add({
          'itemName': '$name(${ao['addOnName']})',
          'price': ao['price'] ?? 0.0,
          'quantity': ao['quantity'] ?? 0.0,
          'weights': ao['weights'] ?? 0.0,
          'amount': (ao['price'] ?? 0) * (ao['quantity'] ?? 1),
          'config': config.where((c) => c['varianceName'] == name).toList(),
        });
        qty -= ao['quantity'] ?? 0.0;
      }
    }

    // main item (with any configs)
    if (qty > 0) {
      seatOrders.add({
        'itemName': name,
        'price': prices.length > i ? prices[i] : 0.0,
        'quantity': qty,
        'weights': weights.length > i ? weights[i] : 0.0,
        'amount': amounts.length > i ? amounts[i] : 0.0,
        'config': config.where((c) => c['varianceName'] == name).toList(),
      });
    }
  }

  // group by printer IP
  final printerService = PrinterProvider();
  await printerService.initializeHive();
  Map<String, List<Map<String, dynamic>>> groupedByPrinter = {};
  for (var item in seatOrders) {
    final ip = printerService.getPrinterIpForItem(item['itemName']);
    if (ip != null) {
      groupedByPrinter.putIfAbsent(ip, () => []).add(item);
    }
  }

  // print each group to its own printer
  for (var entry in groupedByPrinter.entries) {
    await PrinterService.printReceipt(
      ipAddress: entry.key,
      tableNumber: tableNumber,
      seat: seat,
      date: date,
      time: time,
      waiter: waiter,
      total: totalAmount,
      seatOrders: entry.value,
      tokenNumber: tokenNo,
      isOverall: false,
      userName: userName,
      orderType: orderType,
    );
  }
}

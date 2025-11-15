
// import '../services/Token_service.dart';
// import '../services/sendDataToClients.dart';
// import '../services/sync_service.dart';

// // ignore: non_constant_identifier_names
// final SyncServiceKot _SyncServiceKot = SyncServiceKot();
// Map<String, String> _itemPrinterIpCache = {};

// Future<void> handleOrder(Map<String, dynamic> data) async {
//   dynamic branchName = data['branchName'];
//   final table = data['table'];
//   data['deviceId'] = data['deviceId']?.toString() ?? '';
//   print("Received order data for seathiveorderid: $data");
//   if (data['seathiveOrderId'] == null || data['seathiveOrderId'].isEmpty) {
//     data['seathiveOrderId'] = generateSeathiveOrderId(branchName, table);
//     print("Generated new seathiveOrderId: ${data['seathiveOrderId']}");
//   } else {
//     print("Using provided seathiveOrderId: ${data['seathiveOrderId']}");
//   }

//   final date = data['date'];
//   final time = data['time'];
//   if (branchName != null && date != null && time != null) {
//     data['hiveOrderId'] = await generatehiveOrderId(branchName);
//   }

//   data['tokenNo'] = generateTokenNumber();
//   sendDataToClients(data);
//   print("Send order data to clients: $data");
//   print("calling saveOrderToHive...");
//   // await _printReceiptOnServer(data);
//   // await _printItemwiseReceipts(data);
//   await _SyncServiceKot.saveOrderToHive(data);
// }


import '../../kotpreinvoice/providers/printer_provider.dart';
import '../../kotpreinvoice/services/printer_services.dart';
 
import '../services/Token_service.dart';
import '../services/sendDataToClients.dart';
import '../services/sync_service.dart';
 
final SyncServiceKot _SyncServiceKot = SyncServiceKot();
Map<String, String> _itemPrinterIpCache = {};
 
Future<void> handleOrder(Map<String, dynamic> data) async {
  print("📦 [ORDER] Received order data: $data");
 
  try {
    dynamic branchName = data['branchName'];
    final table = data['table'];
    data['deviceId'] = data['deviceId']?.toString() ?? '';
 
    if (data['seathiveOrderId'] == null || data['seathiveOrderId'].isEmpty) {
      data['seathiveOrderId'] = generateSeathiveOrderId(branchName, table);
      print("🆕 Generated new seathiveOrderId: ${data['seathiveOrderId']}");
    } else {
      print("🔁 Using existing seathiveOrderId: ${data['seathiveOrderId']}");
    }
 
    final date = data['date'];
    final time = data['time'];
    if (branchName != null && date != null && time != null) {
      data['hiveOrderId'] = await generatehiveOrderId(branchName);
      print("🔢 Generated HiveOrderId: ${data['hiveOrderId']}");
    }
 
    data['tokenNo'] = generateTokenNumber();
    print("🎫 Token generated: ${data['tokenNo']}");
 
    sendDataToClientsKOT(data);
    print("📤 Order data sent to clients successfully!");
 
    print("💾 Saving order and printing...");
 
    await _SyncServiceKot.saveOrderToHive(data);
    await _printReceiptOnServer(data);
    await _printItemwiseReceipts(data);
    print("✅ [ORDER COMPLETED] Order saved successfully with ID: ${data['seathiveOrderId']}");
  } catch (e, stack) {
    print("❗ [ERROR:handleOrder] Failed to handle order → $e");
    print("🧩 Stack Trace:\n$stack");
  }
}
 
Future<void> _printReceiptOnServer(Map<String, dynamic> orderData) async {
  print("🖨️ [PRINT] Starting _printReceiptOnServer...");
  try {
    final varianceNames = List<String>.from(orderData['varianceNames'] ?? []);
    final prices = (orderData['prices'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()).toList();
    final quantities = (orderData['quantities'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()).toList();
    final weights = (orderData['weights'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()).toList();
    final amounts = (orderData['amounts'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()).toList();
 
    final addOns = List<Map<String, dynamic>>.from(orderData['addOns'] ?? []);
    final config = List<Map<String, dynamic>>.from(orderData['config'] ?? []);
    final tokenNo = orderData['tokenNo'] ?? 0;
    final tableNumber = orderData['table'];
    final seat = orderData['seat']?.toString() ?? '';
    final date = orderData['date']?.toString() ?? '';
    final time = orderData['time']?.toString() ?? '';
    final waiter = orderData['waiter']?.toString() ?? '';
    final totalAmount = double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0;
    final orderType = orderData['orderType']?.toString() ?? '';
 
    List<Map<String, dynamic>> seatOrders = [];
    final groupedAddOns = <String, List<Map<String, dynamic>>>{};
    for (var addOn in addOns) {
      groupedAddOns.putIfAbsent(addOn['varianceName'], () => []).add(addOn);
    }
 
    for (var i = 0; i < varianceNames.length; i++) {
      final name = varianceNames[i];
      var qty = quantities.length > i ? quantities[i] : 0.0;
 
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
 
    final printerService = PrinterProviderDine();
    await printerService.printerInitializeHive();
    final overallPrinterIp = printerService.getOverallPrinterIp();
 
    if (overallPrinterIp != null) {
      print("🖨️ Printing overall receipt to printer IP: $overallPrinterIp");
      await PrinterService.printReceipt(
        ipAddress: overallPrinterIp,
        tableNumber: tableNumber,
        seat: seat,
        date: date,
        time: time,
        waiter: waiter,
        total: totalAmount,
        seatOrders: seatOrders,
        tokenNumber: tokenNo,
        isOverall: true,
        userName: orderData['userName'] ?? '',
        orderType: orderType,
      );
      print("✅ [PRINT SUCCESS] Overall receipt printed successfully!");
    } else {
      print("⚠️ No overall printer IP found. Skipping overall print.");
    }
  } catch (e, stack) {
    print("❗ [ERROR:_printReceiptOnServer] Failed to print receipt → $e");
    print("🧩 Stack Trace:\n$stack");
  }
}
 
Future<void> _printItemwiseReceipts(Map<String, dynamic> orderData) async {
  print("🖨️ [PRINT] Starting _printItemwiseReceipts...");
  try {
    final varianceNames = List<String>.from(orderData['varianceNames'] ?? []);
    final prices = (orderData['prices'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()).toList();
    final quantities = (orderData['quantities'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()).toList();
    final weights = (orderData['weights'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()).toList();
    final amounts = (orderData['amounts'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()).toList();
    final addOns = List<Map<String, dynamic>>.from(orderData['addOns'] ?? []);
    final config = List<Map<String, dynamic>>.from(orderData['config'] ?? []);
    final tableNumber = orderData['table'];
    final seat = orderData['seat']?.toString() ?? '';
    final date = orderData['date']?.toString() ?? '';
    final time = orderData['time']?.toString() ?? '';
    final waiter = orderData['waiter']?.toString() ?? '';
    final totalAmount = double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0;
    final tokenNo = orderData['tokenNo'];
    final orderType = orderData['orderType']?.toString() ?? '';
    final userName = orderData['userName'] ?? '';
 
    List<Map<String, dynamic>> seatOrders = [];
    final groupedAddOns = <String, List<Map<String, dynamic>>>{};
    for (var ao in addOns) {
      groupedAddOns.putIfAbsent(ao['varianceName'], () => []).add(ao);
    }
 
    for (var i = 0; i < varianceNames.length; i++) {
      final name = varianceNames[i];
      double qty = quantities.length > i ? quantities[i] : 0.0;
 
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
 
    final printerService = PrinterProviderDine();
    await printerService.printerInitializeHive();
    Map<String, List<Map<String, dynamic>>> groupedByPrinter = {};
 
    for (var item in seatOrders) {
      final ip = printerService.getPrinterIpForItem(item['itemName']);
      if (ip != null) {
        groupedByPrinter.putIfAbsent(ip, () => []).add(item);
      }
    }
 
    if (groupedByPrinter.isEmpty) {
      print("⚠️ No item-wise printers found for this order.");
      return;
    }
 
    for (var entry in groupedByPrinter.entries) {
      print("🖨️ Printing to item printer IP: ${entry.key} with ${entry.value.length} items...");
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
      print("✅ [PRINT SUCCESS] Printed ${entry.value.length} items to ${entry.key}");
    }
  } catch (e, stack) {
    print("❗ [ERROR:_printItemwiseReceipts] Failed to print itemwise → $e");
    print("🧩 Stack Trace:\n$stack");
  }
}
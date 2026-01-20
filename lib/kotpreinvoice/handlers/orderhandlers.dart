// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:yenpos/Global/globals_data.dart';
// import 'package:yenpos/Server_Client/sendDataToClients.dart';
// import 'package:yenpos/Server_Client/stockupdateService.dart';

// import '../../kotpreinvoice/providers/printer_provider.dart';
// import '../../kotpreinvoice/services/printer_services.dart';

// import '../services/Token_service.dart';
// import '../services/sendDataToClients.dart';
// import '../services/sync_service.dart';

// final SyncServiceKot _SyncServiceKot = SyncServiceKot();
// Map<String, String> _itemPrinterIpCache = {};

// Future<void> handleOrder(Map<String, dynamic> data) async {
//   try {
//     final holdOrdersBox = await Hive.openBox('holdOrdersKOT');

//     final key = '${data['table']}_${data['seat']}';

//     if (holdOrdersBox.containsKey(key)) {
//       holdOrdersBox.delete(key);
//       debugPrint('🗑️ Removed hold order for this key $key');
//     } else {
//       debugPrint('⚠️ No hold order to remove for $key');
//     }
//     dynamic branchName = data['branchName'];
//     final table = data['table'];
//     data['deviceId'] = data['deviceId']?.toString() ?? '';

//     if (data['seathiveOrderId'] == null || data['seathiveOrderId'].isEmpty) {
//       data['seathiveOrderId'] = generateSeathiveOrderId(branchName, table);
//       print("🆕 Generated new seathiveOrderId: ${data['seathiveOrderId']}");
//     } else {
//       print("🔁 Using existing seathiveOrderId: ${data['seathiveOrderId']}");
//     }

//     final date = data['date'];
//     final time = data['time'];
//     if (branchName != null && date != null && time != null) {
//       data['hiveOrderId'] = await generatehiveOrderId(branchName);
//     }

//     data['tokenNo'] = generateTokenNumber();

//     final List<dynamic> varianceCodesRaw = data['varianceitemCodes'] is List
//         ? List.from(data['varianceitemCodes'])
//         : [data['varianceitemCodes']];

//     final List<dynamic> varianceNamesRaw = data['varianceNames'] is List
//         ? List.from(data['varianceNames'])
//         : [data['varianceNames']];

//     final List<dynamic> qtyRaw = data['quantities'] is List
//         ? List.from(data['quantities'])
//         : [data['quantities']];

//     final List<dynamic> weightRaw = data['weights'] is List
//         ? List.from(data['weights'])
//         : [data['weights'] ?? 0.0];

//     final List<dynamic> uomRaw = data['uoms'] is List
//         ? List.from(data['uoms'])
//         : [data['uoms'] ?? 'Pcs'];

//     final int maxItems = [
//       varianceCodesRaw.length,
//       varianceNamesRaw.length,
//       qtyRaw.length,
//       weightRaw.length,
//       uomRaw.length,
//     ].reduce((a, b) => a > b ? a : b);

//     List<String> varianceCodes = [];
//     List<String> varianceNames = [];
//     List<double> deductionAmounts = [];

//     for (int i = 0; i < maxItems; i++) {
//       final code = (i < varianceCodesRaw.length)
//           ? varianceCodesRaw[i]?.toString().trim()
//           : null;
//       final name = (i < varianceNamesRaw.length)
//           ? varianceNamesRaw[i]?.toString().trim()
//           : null;
//       final qtyVal = (i < qtyRaw.length) ? qtyRaw[i] : 1.0;
//       final weightVal = (i < weightRaw.length) ? weightRaw[i] : 0.0;
//       final uomVal = (i < uomRaw.length)
//           ? uomRaw[i]?.toString() ?? 'Pcs'
//           : 'Pcs';

//       if (code == null || code.isEmpty || name == null || name.isEmpty) {
//         print("Skipping invalid item at index $i");
//         continue;
//       }

//       double qty = 0.0;
//       if (qtyVal is num)
//         qty = qtyVal.toDouble();
//       else if (qtyVal is String)
//         qty = double.tryParse(qtyVal) ?? 0.0;

//       double weight = 0.0;
//       if (weightVal is num)
//         weight = weightVal.toDouble();
//       else if (weightVal is String)
//         weight = double.tryParse(weightVal) ?? 0.0;

//       final deduction = getStockDeductionAmount(
//         uom: uomVal,
//         weight: weight,
//         qty: qty,
//       );

//       if (deduction <= 0) {
//         print("Zero deduction for $name → skipped");
//         continue;
//       }

//       varianceCodes.add(code);
//       varianceNames.add(name);
//       deductionAmounts.add(deduction);

//       print(
//         "Will decrease: $name ($code) by $deduction $uomVal ${weight > 0 ? '(weight: $weight kg)' : '(qty: $qty)'}",
//       );
//     }

//     if (varianceCodes.isNotEmpty) {
//       print("Decreasing stock for ${varianceCodes.length} items...");
//       await decreaseLocalHiveStock(
//         clients: clients,
//         branchAlias: aliasname,
//         varianceCodes: varianceCodes,
//         varianceNames: varianceNames,
//         stockDeductionAmounts: deductionAmounts, // Now double!
//         uoms: uomRaw.map((e) => e.toString()).toList(),
//       );
//       print("Stock successfully decreased (weighted items supported)");

//       sendDataToClients(data, clients);

//       await _SyncServiceKot.saveOrderToHive(data);
//       await _printReceiptOnServer(data);
//       await _printItemwiseReceipts(data);
//       print(
//         "✅ [ORDER COMPLETED] Order saved successfully with ID: ${data['seathiveOrderId']}",
//       );
//     }
//   } catch (e, stack) {
//     print("❗ [ERROR:handleOrder] Failed to handle order → $e");
//     print("🧩 Stack Trace:\n$stack");
//   }
// }

// Future<void> _printReceiptOnServer(Map<String, dynamic> orderData) async {
//   print("🖨️ [PRINT] Starting _printReceiptOnServer...");
//   try {
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

//     List<Map<String, dynamic>> seatOrders = [];
//     final groupedAddOns = <String, List<Map<String, dynamic>>>{};
//     for (var addOn in addOns) {
//       groupedAddOns.putIfAbsent(addOn['varianceName'], () => []).add(addOn);
//     }

//     for (var i = 0; i < varianceNames.length; i++) {
//       final name = varianceNames[i];
//       var qty = quantities.length > i ? quantities[i] : 0.0;

//       if (groupedAddOns.containsKey(name)) {
//         for (var ao in groupedAddOns[name]!) {
//           seatOrders.add({
//             'itemName': '${name}(${ao['addOnName']})',
//             'price': ao['price'] ?? 0.0,
//             'quantity': ao['quantity'] ?? 0.0,
//             'weights': ao['weights'] ?? 0.0,
//             'amount': (ao['price'] ?? 0) * (ao['quantity'] ?? 1),
//           });
//           qty -= ao['quantity'] ?? 0.0;
//         }
//       }

//       if (qty > 0) {
//         final myConfigs = config
//             .where((c) => c['varianceName'] == name)
//             .toList();
//         seatOrders.add({
//           'itemName': name,
//           'price': prices.length > i ? prices[i] : 0.0,
//           'quantity': qty,
//           'weights': weights.length > i ? weights[i] : 0.0,
//           'amount': amounts.length > i ? amounts[i] : 0.0,
//           'config': myConfigs,
//         });
//       }
//     }

//     final printerService = PrinterProviderDine();
//     await printerService.printerInitializeHive();
//     final overallPrinterIp = printerService.getOverallPrinterIp();

//     if (overallPrinterIp != null) {
//       print("🖨️ Printing overall receipt to printer IP: $overallPrinterIp");
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
//       print("✅ [PRINT SUCCESS] Overall receipt printed successfully!");
//     } else {
//       print("⚠️ No overall printer IP found. Skipping overall print.");
//     }
//   } catch (e, stack) {
//     print("❗ [ERROR:_printReceiptOnServer] Failed to print receipt → $e");
//     print("🧩 Stack Trace:\n$stack");
//   }
// }

// Future<void> _printItemwiseReceipts(Map<String, dynamic> orderData) async {
//   print("🖨️ [PRINT] Starting _printItemwiseReceipts...");
//   try {
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
//     final tableNumber = orderData['table'];
//     final seat = orderData['seat']?.toString() ?? '';
//     final date = orderData['date']?.toString() ?? '';
//     final time = orderData['time']?.toString() ?? '';
//     final waiter = orderData['waiter']?.toString() ?? '';
//     final totalAmount =
//         double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0;
//     final tokenNo = orderData['tokenNo'];
//     final orderType = orderData['orderType']?.toString() ?? '';
//     final userName = orderData['userName'] ?? '';

//     List<Map<String, dynamic>> seatOrders = [];
//     final groupedAddOns = <String, List<Map<String, dynamic>>>{};
//     for (var ao in addOns) {
//       groupedAddOns.putIfAbsent(ao['varianceName'], () => []).add(ao);
//     }

//     for (var i = 0; i < varianceNames.length; i++) {
//       final name = varianceNames[i];
//       double qty = quantities.length > i ? quantities[i] : 0.0;

//       if (groupedAddOns.containsKey(name)) {
//         for (var ao in groupedAddOns[name]!) {
//           seatOrders.add({
//             'itemName': '$name(${ao['addOnName']})',
//             'price': ao['price'] ?? 0.0,
//             'quantity': ao['quantity'] ?? 0.0,
//             'weights': ao['weights'] ?? 0.0,
//             'amount': (ao['price'] ?? 0) * (ao['quantity'] ?? 1),
//             'config': config.where((c) => c['varianceName'] == name).toList(),
//           });
//           qty -= ao['quantity'] ?? 0.0;
//         }
//       }

//       if (qty > 0) {
//         seatOrders.add({
//           'itemName': name,
//           'price': prices.length > i ? prices[i] : 0.0,
//           'quantity': qty,
//           'weights': weights.length > i ? weights[i] : 0.0,
//           'amount': amounts.length > i ? amounts[i] : 0.0,
//           'config': config.where((c) => c['varianceName'] == name).toList(),
//         });
//       }
//     }

//     final printerService = PrinterProviderDine();
//     await printerService.printerInitializeHive();
//     Map<String, List<Map<String, dynamic>>> groupedByPrinter = {};

//     for (var item in seatOrders) {
//       final ip = printerService.getPrinterIpForItem(item['itemName']);
//       if (ip != null) {
//         groupedByPrinter.putIfAbsent(ip, () => []).add(item);
//       }
//     }

//     if (groupedByPrinter.isEmpty) {
//       print("⚠️ No item-wise printers found for this order.");
//       return;
//     }

//     for (var entry in groupedByPrinter.entries) {
//       print(
//         "🖨️ Printing to item printer IP: ${entry.key} with ${entry.value.length} items...",
//       );
//       await PrinterService.printReceipt(
//         ipAddress: entry.key,
//         tableNumber: tableNumber,
//         seat: seat,
//         date: date,
//         time: time,
//         waiter: waiter,
//         total: totalAmount,
//         seatOrders: entry.value,
//         tokenNumber: tokenNo,
//         isOverall: false,
//         userName: userName,
//         orderType: orderType,
//       );
//       print(
//         "✅ [PRINT SUCCESS] Printed ${entry.value.length} items to ${entry.key}",
//       );
//     }
//   } catch (e, stack) {
//     print("❗ [ERROR:_printItemwiseReceipts] Failed to print itemwise → $e");
//     print("🧩 Stack Trace:\n$stack");
//   }
// }

// import 'package:server/models/globals.dart';
// import 'package:server/providers/printer_provider.dart';
// import 'package:server/services/printer_services.dart';
// import 'package:server/services/sendDataToClients.dart';
// import 'package:server/services/stockUpdateService.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/handlers/invoice_handler.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart'
    hide getStockDeductionAmount;
import 'package:yenpos/kotpreinvoice/providers/printer_provider.dart';
import 'package:yenpos/kotpreinvoice/services/printer_services.dart';

import '../services/Token_service.dart';
import '../services/sync_service.dart';

final SyncServiceKot _SyncServiceKot = SyncServiceKot();
Map<String, String> _itemPrinterIpCache = {};

Future<void> handleOrder(Map<String, dynamic> data) async {

  
  print("🟢 [ORDER] handleOrder() START");
  print("📦 [ORDER] Raw incoming data keys: ${data.keys.toList()}");
  print("📦 [ORDER] Raw order payload: $data");

  try {
    // ─────────────────── BASIC INFO ───────────────────
    dynamic branchName = data['branchName'];
    String aliasNameRaw = data['aliasName'] ?? '';
    final table = data['table'];
    print(
      "🏷️ [ORDER] Branch: $branchName | AliasName: $aliasNameRaw | Table: $table",
    );

    data['deviceId'] = data['deviceId']?.toString() ?? '';
    print("📱 [ORDER] Device ID: ${data['deviceId']}");

    // ─────────────────── SEATHIVE ORDER ID ───────────────────
    if (data['seathiveOrderId'] == null || data['seathiveOrderId'].isEmpty) {
      data['seathiveOrderId'] = generateSeathiveOrderId(branchName, table);
      print("🆕 [ORDER] Generated seathiveOrderId: ${data['seathiveOrderId']}");
    } else {
      print(
        "🔁 [ORDER] Using existing seathiveOrderId: ${data['seathiveOrderId']}",
      );
    }

    // ─────────────────── HIVE ORDER ID ───────────────────
    final date = data['date'];
    final time = data['time'];
    print("📅 [ORDER] Date: $date | Time: $time");

    if (branchName != null && date != null && time != null) {
      data['hiveOrderId'] = await generatehiveOrderId(branchName);
      print("🔢 [ORDER] Generated hiveOrderId: ${data['hiveOrderId']}");
    } else {
      print("⚠️ [ORDER] hiveOrderId not generated (missing branch/date/time)");
    }

    // ─────────────────── TOKEN ───────────────────
    data['tokenNo'] = await generateTokenNumber();
    print("🎫 [ORDER] Token generated: ${data['tokenNo']}");

    // ─────────────────── RAW ITEM ARRAYS ───────────────────
    final List<dynamic> varianceCodesRaw = data['varianceitemCodes'] is List
        ? List.from(data['varianceitemCodes'])
        : data['varianceitemCodes'] is List
        ? List.from(data['varianceitemCodes'])
        : [data['varianceitemCodes']];

    final List<dynamic> varianceNamesRaw = data['varianceNames'] is List
        ? List.from(data['varianceNames'])
        : [data['varianceNames']];

    final List<dynamic> qtyRaw = data['quantities'] is List
        ? List.from(data['quantities'])
        : [data['quantities']];

    final List<dynamic> weightRaw = data['weights'] is List
        ? List.from(data['weights'])
        : [data['weights'] ?? 0.0];

    final List<dynamic> uomRaw = data['uoms'] is List
        ? List.from(data['uoms'])
        : [data['uoms'] ?? 'Pcs'];

    print("📊 [ORDER] Raw items count:");
    print("   • Codes   : ${varianceCodesRaw.length}");
    print("   • Names   : ${varianceNamesRaw.length}");
    print("   • Qty     : ${qtyRaw.length}");
    print("   • Weight  : ${weightRaw.length}");
    print("   • UOM     : ${uomRaw.length}");

    final int maxItems = [
      varianceCodesRaw.length,
      varianceNamesRaw.length,
      qtyRaw.length,
      weightRaw.length,
      uomRaw.length,
    ].reduce((a, b) => a > b ? a : b);

    print("📦 [ORDER] Max item iterations: $maxItems");

    // ─────────────────── PROCESS ITEMS ───────────────────
    List<String> varianceCodes = [];
    List<String> varianceNames = [];
    List<double> deductionAmounts = [];

    for (int i = 0; i < maxItems; i++) {
      print("🔍 [ITEM] Processing index $i");

      final code = (i < varianceCodesRaw.length)
          ? varianceCodesRaw[i]?.toString().trim()
          : null;
      final name = (i < varianceNamesRaw.length)
          ? varianceNamesRaw[i]?.toString().trim()
          : null;
      final qtyVal = (i < qtyRaw.length) ? qtyRaw[i] : 1.0;
      final weightVal = (i < weightRaw.length) ? weightRaw[i] : 0.0;
      final uomVal = (i < uomRaw.length)
          ? uomRaw[i]?.toString() ?? 'Pcs'
          : 'Pcs';

      if (code == null || code.isEmpty || name == null || name.isEmpty) {
        print("⚠️ [ITEM] Skipping invalid item at index $i");
        continue;
      }

      double qty = 0.0;
      if (qtyVal is num) {
        qty = qtyVal.toDouble();
      } else if (qtyVal is String) {
        qty = double.tryParse(qtyVal) ?? 0.0;
      }

      double weight = 0.0;
      if (weightVal is num) {
        weight = weightVal.toDouble();
      } else if (weightVal is String) {
        weight = double.tryParse(weightVal) ?? 0.0;
      }

      final deduction = getStockDeductionAmount(
        uom: uomVal,
        weight: weight,
        qty: qty,
      );

      if (deduction <= 0) {
        print("⚠️ [ITEM] Zero deduction → $name skipped");
        continue;
      }

      varianceCodes.add(code);
      varianceNames.add(name);
      deductionAmounts.add(deduction);

      print(
        "➖ [STOCK] $name ($code) → Deduct $deduction $uomVal "
        "${weight > 0 ? '(weight: $weight)' : '(qty: $qty)'}",
      );
    }

    // ─────────────────── STOCK DECREASE ───────────────────
    if (varianceCodes.isNotEmpty) {
      print("📉 [STOCK] Decreasing stock for ${varianceCodes.length} items");

      await decreaseLocalHiveStock(
        clients: clients,
        branchAlias: aliasNameRaw,
        varianceCodes: varianceCodes,
        varianceNames: varianceNames,
        stockDeductionAmounts: deductionAmounts,
        uoms: uomRaw.map((e) => e.toString()).toList(),
      );

      print("✅ [STOCK] Stock decreased successfully");

      // ─────────────────── SEND TO CLIENTS ───────────────────
      sendDataToClients(data, clients);
      print("📤 [ORDER] Order data sent to clients");

      // ─────────────────── SAVE & PRINT ───────────────────
      print("💾 [ORDER] Saving order to Hive...");
      await _SyncServiceKot.saveOrderToHive(data);

      print("🖨️ [ORDER] Printing main receipt...");
      await _printReceiptOnServer(data);

      print("🖨️ [ORDER] Printing item-wise receipts...");
      await _printItemwiseReceipts(data);

      print("🎉 [ORDER COMPLETED] seathiveOrderId: ${data['seathiveOrderId']}");
    } else {
      print("⚠️ [ORDER] No valid items to process, order skipped");
    }
  } catch (e, stack) {
    print("❌ [ERROR:handleOrder] $e");
    print("🧩 Stack Trace:\n$stack");
  }

  print("🟢 [ORDER] handleOrder() END");
}

Future<void> _printReceiptOnServer(Map<String, dynamic> orderData) async {
  print("🖨️ [PRINT] Starting _printReceiptOnServer...");
  try {
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
        final myConfigs = config
            .where((c) => c['varianceName'] == name)
            .toList();
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
        // printerNames: [],
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
    Map<String, dynamic> groupedByPrinter =
        {}; // {ip: {'items': List<Map>, 'names': Set<String>}}

    for (var item in seatOrders) {
      // Assuming PrinterProvider has a method getPrinterForItem that returns Map<String, dynamic>? {'ip': String?, 'name': String}
      // If not, implement it in PrinterProvider to return both IP and name based on itemName.
      final printerInfo = printerService.getPrinterForItem(item['itemName']);
      if (printerInfo != null && printerInfo['ip'] != null) {
        final ip = printerInfo['ip'] as String;
        final name = printerInfo['name'] as String? ?? 'Unknown Printer';
        if (!groupedByPrinter.containsKey(ip)) {
          groupedByPrinter[ip] = {
            'items': <Map<String, dynamic>>[],
            'names': <String>{},
          };
        }
        (groupedByPrinter[ip] as Map<String, dynamic>)['names'].add(name);
        (groupedByPrinter[ip] as Map<String, dynamic>)['items'].add(item);
      }
    }

    if (groupedByPrinter.isEmpty) {
      print("⚠️ No item-wise printers found for this order.");
      return;
    }

    for (var entry in groupedByPrinter.entries) {
      final ip = entry.key;
      final group = entry.value as Map<String, dynamic>;
      final items = group['items'] as List<Map<String, dynamic>>;
      final namesSet = group['names'] as Set<String>;
      final printerNames = namesSet.toList()
        ..sort(); // Sort for consistent order
      print(
        "🖨️ Printing to item printer IP: $ip with ${items.length} items and ${printerNames.length} printer name(s): $printerNames",
      );
      await PrinterService.printReceipt(
        ipAddress: ip,
        tableNumber: tableNumber,
        seat: seat,
        date: date,
        time: time,
        waiter: waiter,
        total: totalAmount,
        seatOrders: items,
        tokenNumber: tokenNo,
        isOverall: false,
        userName: userName,
        orderType: orderType,
        // printerNames: printerNames,
      );
      print("✅ [PRINT SUCCESS] Printed ${items.length} items to $ip");
    }
  } catch (e, stack) {
    print("❗ [ERROR:_printItemwiseReceipts] Failed to print itemwise → $e");
    print("🧩 Stack Trace:\n$stack");
  }
}

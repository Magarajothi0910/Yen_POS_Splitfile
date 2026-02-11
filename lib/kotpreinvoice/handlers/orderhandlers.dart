import 'package:flutter/material.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Server_Client/handlers/invoice_handler.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/Server_Client/stockupdateService.dart'
    hide getStockDeductionAmount;
import 'package:yen_pos/kotpreinvoice/providers/printer_provider.dart';
import 'package:yen_pos/kotpreinvoice/services/printer_services.dart';

import '../services/Token_service.dart';
import '../services/sync_service.dart';

final SyncServiceKot _SyncServiceKot = SyncServiceKot();

Future<void> handleOrder(Map<String, dynamic> data) async {
  debugPrint("🟢 [ORDER] handleOrder() START");
  debugPrint("📦 [ORDER] Raw incoming data keys: ${data.keys.toList()}");
  debugPrint("📦 [ORDER] Raw order payload: $data");

  try {
    // ─────────────────── BASIC INFO ───────────────────
    dynamic branchName = data['branchName'];
    String aliasNameRaw = data['aliasName'] ?? '';
    final table = data['table'];
    print(
      "🏷️ [ORDER] Branch: $branchName | AliasName: $aliasNameRaw | Table: $table",
    );

    data['deviceId'] = data['deviceId']?.toString() ?? '';
    debugPrint("📱 [ORDER] Device ID: ${data['deviceId']}");

    // ─────────────────── SEATHIVE ORDER ID ───────────────────
    if (data['seathiveOrderId'] == null || data['seathiveOrderId'].isEmpty) {
      data['seathiveOrderId'] = generateSeathiveOrderId(branchName, table);
      debugPrint(
        "🆕 [ORDER] Generated seathiveOrderId: ${data['seathiveOrderId']}",
      );
    } else {
      print(
        "🔁 [ORDER] Using existing seathiveOrderId: ${data['seathiveOrderId']}",
      );
    }

    // ─────────────────── HIVE ORDER ID ───────────────────
    final date = data['date'];
    final time = data['time'];
    debugPrint("📅 [ORDER] Date: $date | Time: $time");

    if (branchName != null && date != null && time != null) {
      data['hiveOrderId'] = await generatehiveOrderId(branchName);
      debugPrint("🔢 [ORDER] Generated hiveOrderId: ${data['hiveOrderId']}");
    } else {
      debugPrint(
        "⚠️ [ORDER] hiveOrderId not generated (missing branch/date/time)",
      );
    }

    // ─────────────────── TOKEN ───────────────────
    data['tokenNo'] = await generateTokenNumber();
    debugPrint("🎫 [ORDER] Token generated: ${data['tokenNo']}");

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

    debugPrint("📊 [ORDER] Raw items count:");
    debugPrint("   • Codes   : ${varianceCodesRaw.length}");
    debugPrint("   • Names   : ${varianceNamesRaw.length}");
    debugPrint("   • Qty     : ${qtyRaw.length}");
    debugPrint("   • Weight  : ${weightRaw.length}");
    debugPrint("   • UOM     : ${uomRaw.length}");

    final int maxItems = [
      varianceCodesRaw.length,
      varianceNamesRaw.length,
      qtyRaw.length,
      weightRaw.length,
      uomRaw.length,
    ].reduce((a, b) => a > b ? a : b);

    debugPrint("📦 [ORDER] Max item iterations: $maxItems");

    // ─────────────────── PROCESS ITEMS ───────────────────
    List<String> varianceCodes = [];
    List<String> varianceNames = [];
    List<double> deductionAmounts = [];

    for (int i = 0; i < maxItems; i++) {
      debugPrint("🔍 [ITEM] Processing index $i");

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
        debugPrint("⚠️ [ITEM] Skipping invalid item at index $i");
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
        debugPrint("⚠️ [ITEM] Zero deduction → $name skipped");
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
      debugPrint(
        "📉 [STOCK] Decreasing stock for ${varianceCodes.length} items",
      );

      await decreaseLocalHiveStock(
        clients: clients,
        locationId: locationId,
        varianceCodes: varianceCodes,
        varianceNames: varianceNames,
        stockDeductionAmounts: deductionAmounts,
        uoms: uomRaw.map((e) => e.toString()).toList(),
      );

      debugPrint("✅ [STOCK] Stock decreased successfully");

      // ─────────────────── SEND TO CLIENTS ───────────────────
      sendDataToClients(data, clients);
      debugPrint("📤 [ORDER] Order data sent to clients");

      // ─────────────────── SAVE & PRINT ───────────────────
      debugPrint("💾 [ORDER] Saving order to Hive...");
      await _SyncServiceKot.saveOrderToHive(data);

      debugPrint("🖨️ [ORDER] Printing main receipt...");
      await _printReceiptOnServer(data);

      debugPrint("🖨️ [ORDER] Printing item-wise receipts...");
      await _printItemwiseReceipts(data);

      debugPrint(
        "🎉 [ORDER COMPLETED] seathiveOrderId: ${data['seathiveOrderId']}",
      );
    } else {
      debugPrint("⚠️ [ORDER] No valid items to process, order skipped");
    }
  } catch (e, stack) {
    debugPrint("❌ [ERROR:handleOrder] $e");
    debugPrint("🧩 Stack Trace:\n$stack");
  }

  debugPrint("🟢 [ORDER] handleOrder() END");
}

List<Map<String, dynamic>> splitConfigByType(
  Map<String, dynamic> cfg,
  String targetType, // 'Parcel' or 'Dining'
) {
  final List<Map<String, dynamic>> result = [];

  final List qty = cfg['configQty'] ?? [];
  final List types = cfg['type'] ?? [];
  final List variants = cfg['variance'] ?? [];

  // 🔎 detect if ANY parcel exists for this config
  final bool hasParcel = types.any(
    (t) => t != null && t.toString() == 'Parcel',
  );

  for (int i = 0; i < qty.length; i++) {
    final type = (i < types.length && types[i].toString().isNotEmpty)
        ? types[i]
        : 'Dining';

    if (type != targetType) continue;

    final bool attachRemark =
        targetType == 'Parcel' || (!hasParcel && targetType == 'Dining');

    result.add({
      'varianceName': cfg['varianceName'],
      'weight': cfg['weight'],
      'configQty': [1],
      'variance': [i < variants.length ? variants[i] : ''],
      'addOn': cfg['addOn'],
      'addOnQuantities': cfg['addOnQuantities'],
      'addOnPrice': cfg['addOnPrice'],
      'remark': attachRemark ? cfg['remark'] : '',
      'type': [type],
    });
  }

  return result;
}

Future<void> _printReceiptOnServer(Map<String, dynamic> orderData) async {
  debugPrint("🖨️ [PRINT] START _printReceiptOnServer");
  debugPrint("orderData => $orderData");

  try {
    // ───────────────── BASE DATA ─────────────────
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
    final orderType = orderData['orderType']?.toString() ?? '';
    final totalAmount =
        double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0;

    // ───────────────── BUILD seatOrders (NO GROUPING) ─────────────────
    final List<Map<String, dynamic>> seatOrders = [];

    for (int i = 0; i < varianceNames.length; i++) {
      seatOrders.add({
        'itemName': varianceNames[i],
        'price': prices.length > i ? prices[i] : 0.0,
        'quantity': quantities.length > i ? quantities[i] : 0.0,
        'weights': weights.length > i ? weights[i] : 0.0,
        'amount': amounts.length > i ? amounts[i] : 0.0,
        'config': <Map<String, dynamic>>[],
      });
    }

    // ───────────────── ATTACH CONFIG (ONCE PER ITEM) ─────────────────
    for (final item in seatOrders) {
      final String name = item['itemName'];
      final double weight = item['weights'];

      Map<String, dynamic>? matchedConfig;

      for (final c in config) {
        final cfgName = c['varianceName'];
        final cfgWeight = (c['weight'] as num?)?.toDouble() ?? 0.0;

        if (cfgName == name && cfgWeight == weight) {
          matchedConfig = {
            'varianceName': cfgName,
            'weight': cfgWeight,
            'configQty': List<int>.from(c['configQty'] ?? []),
            'variance': List.from(c['variance'] ?? []),
            'addOn': List.from(c['addOn'] ?? []),
            'addOnQuantities': List.from(c['addOnQuantities'] ?? []),
            'addOnPrice': List.from(c['addOnPrice'] ?? []),
            'remark': List.from(c['remark'] ?? []),
            'type':
                (c['type'] as List?)
                    ?.where((t) => t == 'Dining' || t == 'Parcel')
                    .toList() ??
                [],
          };
          break; // 🔑 attach only once
        }
      }

      item['config'] = matchedConfig != null ? [matchedConfig] : [];
    }

    debugPrint("✅ FINAL seatOrders => $seatOrders");

    // ───────────────── PRINT ─────────────────
    final printerService = PrinterProviderDine();
    await printerService.printerInitializeHive();

    final overallPrinterIp = printerService.getOverallPrinterIp();

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
        tokenNumber: tokenNo,
        isOverall: true,
        userName: orderData['userName'] ?? '',
        orderType: orderType,
        printerNames: const [],
      );

      debugPrint("✅ PRINT SUCCESS");
    } else {
      debugPrint("⚠️ No printer IP found");
    }
  } catch (e, stack) {
    debugPrint("❌ ERROR in _printReceiptOnServer => $e");
    debugPrint("STACK => $stack");
  }
}

Future<void> _printItemwiseReceipts(Map<String, dynamic> orderData) async {
  debugPrint("🖨️ [PRINT] Starting _printItemwiseReceipts");

  try {
    // ───────────────── PARSE LISTS ─────────────────
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

    String itemKey(String name, double weight) => '$name|$weight';

    // ───────────────── GROUP ADDONS ─────────────────
    final Map<String, List<Map<String, dynamic>>> groupedAddOns = {};
    for (final ao in addOns) {
      final aoName = ao['varianceName'];
      final aoWeight = (ao['weight'] as num?)?.toDouble() ?? 0.0;
      groupedAddOns.putIfAbsent(itemKey(aoName, aoWeight), () => []).add(ao);
    }

    // ───────────────── BUILD seatOrders WITHOUT GROUPING ─────────────────
    final List<Map<String, dynamic>> seatOrders = [];

    // Each index corresponds to one item (weighted or not)
    for (int i = 0; i < varianceNames.length; i++) {
      final name = varianceNames[i];
      final weight = weights.length > i ? weights[i] : 0.0;
      final qty = quantities.length > i ? quantities[i] : 0.0;
      final price = prices.length > i ? prices[i] : 0.0;
      final amount = amounts.length > i ? amounts[i] : 0.0;

      final key = itemKey(name, weight);

      // Add add-ons for this item if any (must be filtered by addOn with matching varianceName & weight)
      final itemAddOns = groupedAddOns[key] ?? [];

      // Add add-ons as separate seatOrders entries
      for (final ao in itemAddOns) {
        final aoQty = (ao['quantity'] as num?)?.toDouble() ?? 0.0;
        final aoPrice = (ao['price'] as num?)?.toDouble() ?? 0.0;
        final aoName = ao['addOnName'] ?? '';

        seatOrders.add({
          'itemName': '$name ($aoName)',
          'price': aoPrice,
          'quantity': aoQty,
          'weights': weight,
          'amount': aoQty * aoPrice,
          'config': const [],
        });
      }

      // Attach config for this specific item index
      Map<String, dynamic>? matchedConfig;

      for (final c in config) {
        final cfgName = c['varianceName'];
        final cfgWeight = (c['weight'] as num?)?.toDouble() ?? 0.0;

        if (cfgName == name && cfgWeight == weight) {
          matchedConfig = {
            'varianceName': cfgName,
            'weight': cfgWeight,
            'configQty': List<int>.from(c['configQty'] ?? []),
            'variance': List.from(c['variance'] ?? []),
            'addOn': List.from(c['addOn'] ?? []),
            'addOnQuantities': List.from(c['addOnQuantities'] ?? []),
            'addOnPrice': List.from(c['addOnPrice'] ?? []),
            'remark': List.from(c['remark'] ?? []),
            'type':
                (c['type'] as List?)
                    ?.where((t) => t == 'Dining' || t == 'Parcel')
                    .toList() ??
                [],
          };
          break;
        }
      }

      // Add the main item itself (weighted, ungrouped)
      seatOrders.add({
        'itemName': name,
        'price': price,
        'quantity': qty,
        'weights': weight,
        'amount': amount,
        'config': matchedConfig != null ? [matchedConfig] : [],
      });
    }

    // ───────────────── PRINTER GROUPING ─────────────────
    final printerService = PrinterProviderDine();
    await printerService.printerInitializeHive();

    final Map<String, List<Map<String, dynamic>>> groupedByPrinter = {};

    for (final item in seatOrders) {
      final printerInfo = printerService.getPrinterForItem(item['itemName']);

      if (printerInfo == null) continue;

      final ip = printerInfo['ip'];
      final printerName = printerInfo['name'];

      if (ip == null || printerName == null) continue;

      final key = '$ip|$printerName';

      groupedByPrinter.putIfAbsent(key, () => []);
      groupedByPrinter[key]!.add(item);
    }

    if (groupedByPrinter.isEmpty) {
      debugPrint("⚠️ No item-wise printers found");
      return;
    }

    // ───────────────── PRINT ─────────────────
    for (final entry in groupedByPrinter.entries) {
      final parts = entry.key.split('|');
      final ip = parts[0];
      final printerName = parts[1];
      final items = entry.value;

      debugPrint("🖨️ Printing ${items.length} items to $printerName ($ip)");

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
        printerNames: [printerName],
      );
    }
  } catch (e, stack) {
    debugPrint("❌ ERROR _printItemwiseReceipts => $e");
    debugPrint("STACK TRACE => $stack");
  }
}

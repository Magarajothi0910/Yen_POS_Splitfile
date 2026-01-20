// import 'dart:convert';
// import 'package:hive/hive.dart';
// import 'package:yenpos/Global/globals_data.dart';
// import 'package:yenpos/Server_Client/handlers/invoice_handler.dart';
// import 'package:yenpos/Server_Client/sendDataToClients.dart';
// import 'package:yenpos/Server_Client/stockupdateService.dart'
//     hide getStockDeductionAmount;
// import 'package:yenpos/kotpreinvoice/services/sync_service.dart';
// import '../services/sendDataToClients.dart'; // ✅ Make sure this import path is correct

// class OrderPatchHandler {
//   static Future<void> handleFullCancelOrderPatch(
//     Map<String, dynamic> patchData,
//   ) async {
//     print("🗑️ [FullCancelOrderPatch] Received patch data: $patchData");

//     // 🔹 Extract required fields
//     final String seathiveOrderId =
//         patchData['seathiveOrderId']?.toString() ?? '';
//     final String newStatus = patchData['status']?.toString() ?? 'cancelled';
//     final String orderRemark = patchData['orderRemark']?.toString() ?? '';

//     if (seathiveOrderId.isEmpty) {
//       print("❌ [FullCancelOrderPatch] Missing seathiveOrderId in patchData.");
//       return;
//     }

//     if (!Hive.isBoxOpen('ordersBox')) {
//       await Hive.openBox('ordersBox');
//     }
//     if (!Hive.isBoxOpen('cancelledOrderBox')) {
//       await Hive.openBox('cancelledOrderBox');
//     }

//     final orderBox = Hive.box('ordersBox');
//     final cancelledOrderBox = Hive.box('cancelledOrderBox');

//     final List<dynamic> varianceCodesRaw =
//         patchData['varianceitemCodes'] is List
//         ? List.from(patchData['varianceitemCodes'])
//         : [patchData['varianceitemCodes']];

//     final List<dynamic> varianceNamesRaw = patchData['varianceNames'] is List
//         ? List.from(patchData['varianceNames'])
//         : [patchData['varianceNames']];

//     final List<dynamic> qtyRaw = patchData['quantities'] is List
//         ? List.from(patchData['quantities'])
//         : [patchData['quantities']];

//     final List<dynamic> weightRaw = patchData['weights'] is List
//         ? List.from(patchData['weights'])
//         : [patchData['weights'] ?? 0.0];

//     final List<dynamic> uomRaw = patchData['uoms'] is List
//         ? List.from(patchData['uoms'])
//         : [patchData['uoms'] ?? 'Pcs'];

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
//         "Will increase: $name ($code) by $deduction $uomVal ${weight > 0 ? '(weight: $weight kg)' : '(qty: $qty)'}",
//       );
//     }

//     if (varianceCodes.isNotEmpty) {
//       print("Decreasing stock for ${varianceCodes.length} items...");
//       await increaseLocalHiveStock(
//         clients: clients,
//         branchAlias: aliasname,
//         varianceCodes: varianceCodes,
//         varianceNames: varianceNames,
//         stockIncreaseAmounts: deductionAmounts, // Now double!
//         uoms: uomRaw.map((e) => e.toString()).toList(),
//       );

//       bool orderUpdated = false;
//       int updatedCount = 0;

//       final List<MapEntry<dynamic, dynamic>> remainingOrders = [];

//       print(
//         '📂 [FullCancelOrderPatch] Checking Hive box (keys: ${orderBox.keys.length})...',
//       );

//       // Iterate through all entries in the orderBox
//       for (var key in orderBox.keys.toList()) {
//         final order = orderBox.get(key);

//         if (order is Map<String, dynamic> &&
//             order['seathiveOrderId'] == seathiveOrderId) {
//           print(
//             '✅ [FullCancelOrderPatch] Found matching order (key: $key). Updating...',
//           );

//           try {
//             order['status'] = newStatus;
//             order['orderRemark'] = orderRemark;
//             order['edit'] = "Yes";
//             order['statusEdited'] = "true";
//             updatedCount++;
//             orderUpdated = true;

//             // If cancelled → move to cancelledOrderBox
//             if (newStatus.toLowerCase() == 'cancelled') {
//               await cancelledOrderBox.add(order);
//               print(
//                 '🚮 [FullCancelOrderPatch] Moved order to cancelledOrderBox.',
//               );
//               // Do NOT keep it in remainingOrders → effectively deletes it
//             } else {
//               remainingOrders.add(MapEntry(key, order));
//             }
//           } catch (e) {
//             print('❌ [FullCancelOrderPatch] Error processing key $key: $e');
//           }
//         } else {
//           // Keep orders that are not matched
//           remainingOrders.add(MapEntry(key, order));
//         }
//       }

//       // 🔹 Rebuild orderBox with continuous keys (0,1,2,...)
//       await SyncServiceKot().patchEditedOrders();
//       await orderBox.clear();
//       for (var entry in remainingOrders) {
//         await orderBox.add(entry.value);
//       }
//       print(
//         "♻️ [FullCancelOrderPatch] Reindexed ordersBox (${orderBox.length} items remaining)",
//       );

//       if (orderUpdated) {
//         print(
//           "✅ [FullCancelOrderPatch] Updated $updatedCount orders for seathiveOrderId: $seathiveOrderId.",
//         );
//       } else {
//         print(
//           "⚠️ [FullCancelOrderPatch] No matching order found for seathiveOrderId: $seathiveOrderId",
//         );
//       }

//       // 🔹 Construct broadcast data
//       final Map<String, dynamic> broadcastData = {
//         'action': 'updateFullOrderCancelStatus',
//         'seathiveOrderId': seathiveOrderId,
//         'status': newStatus,
//         'orderRemark': orderRemark,
//         'fieldsEdited': "true",
//         'edit': "Yes",
//         'sync': "Yes",
//         'updatedCount': updatedCount,
//       };

//       // 🔹 Broadcast to clients
//       try {
//         sendDataToClients(broadcastData, clients);
//         print(
//           "📢 [FullCancelOrderPatch] Broadcasted update: ${jsonEncode(broadcastData)}",
//         );
//         await SyncServiceKot().patchEditedOrders();
//       } catch (e) {
//         print("❌ [FullCancelOrderPatch] Failed to broadcast to clients: $e");
//       }
//     }
//   }

//   static Future<void> handleFullInvoiceOrderPatch(
//     Map<String, dynamic> patchData,
//   ) async {
//     print("🧾 [FullInvoiceOrderPatch] Received patch data: $patchData");

//     // 🔹 Extract required fields
//     final String seathiveOrderId =
//         patchData['seathiveOrderId']?.toString() ?? '';
//     final String newStatus = patchData['status']?.toString() ?? 'invoiced';
//     final String invoiceNumber = patchData['invoiceNumber']?.toString() ?? '';

//     if (seathiveOrderId.isEmpty) {
//       print("❌ [FullInvoiceOrderPatch] Missing seathiveOrderId in patchData.");
//       return;
//     }

//     // 🔹 Ensure Hive boxes are open
//     if (!Hive.isBoxOpen('ordersBox')) {
//       await Hive.openBox('ordersBox');
//     }
//     if (!Hive.isBoxOpen('invoicesKOT')) {
//       await Hive.openBox('invoicesKOT');
//     }

//     final orderBox = Hive.box('ordersBox');
//     final invoices = Hive.box('invoicesKOT');

//     bool orderUpdated = false;
//     int updatedCount = 0;
//     final List<MapEntry<dynamic, dynamic>> remainingOrders = [];

//     print(
//       '📂 [FullInvoiceOrderPatch] Checking Hive box (keys: ${orderBox.keys.length})...',
//     );

//     // 🔹 Iterate through all entries in the orderBox
//     for (var key in orderBox.keys.toList()) {
//       final order = orderBox.get(key);

//       if (order is Map<String, dynamic> &&
//           order['seathiveOrderId'] == seathiveOrderId) {
//         print(
//           '✅ [FullInvoiceOrderPatch] Found matching order (key: $key). Updating...',
//         );

//         try {
//           order['status'] = newStatus;
//           order['invoiceNumber'] = invoiceNumber;
//           order['edit'] = "Yes";
//           order['statusEdited'] = "true";
//           updatedCount++;
//           orderUpdated = true;

//           // If invoiced → move to invoices
//           if (newStatus.toLowerCase() == 'invoiced') {
//             await invoices.add(order);
//             print('🧾 [FullInvoiceOrderPatch] Moved order to invoices.');
//             // Do NOT keep it in remainingOrders → effectively deletes it
//           } else {
//             remainingOrders.add(MapEntry(key, order));
//           }
//         } catch (e) {
//           print('❌ [FullInvoiceOrderPatch] Error processing key $key: $e');
//         }
//       } else {
//         // Keep orders that are not matched
//         remainingOrders.add(MapEntry(key, order));
//       }
//     }

//     // 🔹 Rebuild orderBox with continuous keys (0,1,2,...)
//     await orderBox.clear();
//     for (var entry in remainingOrders) {
//       await orderBox.add(entry.value);
//     }
//     print(
//       "♻️ [FullInvoiceOrderPatch] Reindexed ordersBox (${orderBox.length} items remaining)",
//     );

//     if (orderUpdated) {
//       print(
//         "✅ [FullInvoiceOrderPatch] Updated $updatedCount orders for seathiveOrderId: $seathiveOrderId.",
//       );
//     } else {
//       print(
//         "⚠️ [FullInvoiceOrderPatch] No matching order found for seathiveOrderId: $seathiveOrderId",
//       );
//     }

//     // 🔹 Construct broadcast data
//     final Map<String, dynamic> broadcastData = {
//       'action': 'updateFullOrderInvoiceStatus',
//       'seathiveOrderId': seathiveOrderId,
//       'status': newStatus,
//       'invoiceNumber': invoiceNumber,
//       'fieldsEdited': "true",
//       'edit': "Yes",
//       'sync': "Yes",
//       'updatedCount': updatedCount,
//     };

//     // 🔹 Broadcast to clients
//     try {
//       sendDataToClients(broadcastData, clients);
//       print(
//         "📢 [FullInvoiceOrderPatch] Broadcasted update: ${jsonEncode(broadcastData)}",
//       );
//       await SyncServiceKot().patchEditedOrders();
//     } catch (e) {
//       print("❌ [FullInvoiceOrderPatch] Failed to broadcast to clients: $e");
//     }
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/handlers/invoice_handler.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart'
    hide getStockDeductionAmount;
import 'package:yenpos/kotpreinvoice/services/sync_service.dart';

class OrderPatchHandler {
  /// Handles full order cancellation patch
  /// Restores stock, updates order status, moves to cancelled box, and broadcasts update
  static Future<void> handleFullCancelOrderPatch(
    Map<String, dynamic> patchData,
  ) async {
    debugPrint("🗑️ [FullCancelOrderPatch] Received patch data: $patchData");

    final String seathiveOrderId =
        patchData['seathiveOrderId']?.toString() ?? '';
    final String newStatus = patchData['status']?.toString() ?? 'cancelled';
    final String orderRemark = patchData['orderRemark']?.toString() ?? '';
    final List<dynamic> dataList = patchData['data'] is List
        ? List.from(patchData['data'])
        : [patchData['data'] ?? {}];

    if (seathiveOrderId.isEmpty) {
      debugPrint("❌ [FullCancelOrderPatch] Missing seathiveOrderId");
      return;
    }

    // Ensure Hive boxes are open
    final orderBox = await _ensureBoxOpen('ordersBox');
    final cancelledOrderBox = await _ensureBoxOpen('cancelledOrderBox');

    // Extract and normalize item data for stock restoration
    final stockRestoreData = _extractStockRestoreData(dataList);

    debugPrint("stockRestoreData is $stockRestoreData");

    if (stockRestoreData.varianceCodes.isNotEmpty) {
      debugPrint(
        "📈 Restoring stock for ${stockRestoreData.varianceCodes.length} items...",
      );
      await increaseLocalHiveStock(
        clients: clients,
        branchAlias: aliasname,
        varianceCodes: stockRestoreData.varianceCodes,
        varianceNames: stockRestoreData.varianceNames,
        stockIncreaseAmounts: stockRestoreData.deductionAmounts,
        uoms: stockRestoreData.uoms,
      );
    }

    // Update orders in Hive
    final updatedOrders = await _updateOrdersInBox(
      orderBox: orderBox,
      seathiveOrderId: seathiveOrderId,
      newStatus: newStatus,
      orderRemark: orderRemark,
      targetBoxForCancelled: cancelledOrderBox,
    );

    // Reindex orderBox
    await _reindexOrderBox(orderBox, updatedOrders.remainingOrders);

    // Broadcast update
    final broadcastData = {
      'action': 'updateFullOrderCancelStatus',
      'seathiveOrderId': seathiveOrderId,
      'status': newStatus,
      'orderRemark': orderRemark,
      'fieldsEdited': "true",
      'edit': "Yes",
      'sync': "Yes",
      'updatedCount': updatedOrders.updatedCount,
    };

    try {
      sendDataToClients(broadcastData, clients);
      debugPrint(
        "📢 [FullCancelOrderPatch] Broadcasted: ${jsonEncode(broadcastData)}",
      );
      await SyncServiceKot().patchEditedOrders();
    } catch (e) {
      debugPrint("❌ [FullCancelOrderPatch] Broadcast failed: $e");
    }
  }

  /// Handles full order invoicing patch
  /// Updates status, moves to invoicesKOT box, and broadcasts
  static Future<void> handleFullInvoiceOrderPatch(
    Map<String, dynamic> patchData,
  ) async {
    debugPrint("🧾 [FullInvoiceOrderPatch] Received patch data: $patchData");

    final String seathiveOrderId =
        patchData['seathiveOrderId']?.toString() ?? '';
    final String newStatus = patchData['status']?.toString() ?? 'invoiced';
    final String invoiceNumber = patchData['invoiceNumber']?.toString() ?? '';

    if (seathiveOrderId.isEmpty) {
      debugPrint("❌ [FullInvoiceOrderPatch] Missing seathiveOrderId");
      return;
    }

    final orderBox = await _ensureBoxOpen('ordersBox');
    final invoicesBox = await _ensureBoxOpen('invoicesKOT');

    final updatedOrders = await _updateOrdersInBox(
      orderBox: orderBox,
      seathiveOrderId: seathiveOrderId,
      newStatus: newStatus,
      invoiceNumber: invoiceNumber,
      targetBoxForInvoiced: invoicesBox,
    );

    await _reindexOrderBox(orderBox, updatedOrders.remainingOrders);

    final broadcastData = {
      'action': 'updateFullOrderInvoiceStatus',
      'seathiveOrderId': seathiveOrderId,
      'status': newStatus,
      'invoiceNumber': invoiceNumber,
      'fieldsEdited': "true",
      'edit': "Yes",
      'sync': "Yes",
      'updatedCount': updatedOrders.updatedCount,
    };

    try {
      sendDataToClients(broadcastData, clients);
      debugPrint(
        "📢 [FullInvoiceOrderPatch] Broadcasted: ${jsonEncode(broadcastData)}",
      );
      await SyncServiceKot().patchEditedOrders();
    } catch (e) {
      debugPrint("❌ [FullInvoiceOrderPatch] Broadcast failed: $e");
    }
  }

  // ==================== Helper Methods ====================

  static Future<Box> _ensureBoxOpen(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }

  static _StockRestoreData _extractStockRestoreData(List<dynamic> dataList) {
    final List<String> varianceCodes = [];
    final List<String> varianceNames = [];
    final List<double> deductionAmounts = [];
    final List<String> uoms = [];

    for (var data in dataList) {
      final List<dynamic> codes = data['varianceitemCodes'] is List
          ? List.from(data['varianceitemCodes'])
          : [data['varianceitemCodes'] ?? ''];
      final List<dynamic> names = data['varianceNames'] is List
          ? List.from(data['varianceNames'])
          : [data['varianceNames'] ?? ''];
      final List<dynamic> qtyRaw = data['quantities'] is List
          ? List.from(data['quantities'])
          : [data['quantities'] ?? 0.0];
      final List<dynamic> weightRaw = data['weights'] is List
          ? List.from(data['weights'])
          : [data['weights'] ?? 0.0];
      final List<dynamic> uomRaw = data['uoms'] is List
          ? List.from(data['uoms'])
          : [data['uoms'] ?? 'Pcs'];

      final int maxLen = [
        codes.length,
        names.length,
        qtyRaw.length,
        weightRaw.length,
        uomRaw.length,
      ].reduce((a, b) => a > b ? a : b);

      for (int i = 0; i < maxLen; i++) {
        final String? code = i < codes.length
            ? codes[i]?.toString().trim()
            : null;
        final String? name = i < names.length
            ? names[i]?.toString().trim()
            : null;
        final double qty = i < qtyRaw.length
            ? (qtyRaw[i] as num).toDouble()
            : 0.0;
        final double weight = i < weightRaw.length
            ? (weightRaw[i] as num).toDouble()
            : 0.0;
        final String uom = i < uomRaw.length
            ? uomRaw[i]?.toString() ?? 'Pcs'
            : 'Pcs';

        if (code == null || code.isEmpty || name == null || name.isEmpty)
          continue;

        final deduction = getStockDeductionAmount(
          uom: uom,
          weight: weight,
          qty: qty,
        );
        if (deduction <= 0) continue;

        varianceCodes.add(code);
        varianceNames.add(name);
        deductionAmounts.add(deduction);
        uoms.add(uom);

        debugPrint("Will restore: $name ($code) +$deduction $uom");
      }
    }

    return _StockRestoreData(
      varianceCodes: varianceCodes,
      varianceNames: varianceNames,
      deductionAmounts: deductionAmounts,
      uoms: uoms,
    );
  }

  static Future<_OrderUpdateResult> _updateOrdersInBox({
    required Box orderBox,
    required String seathiveOrderId,
    required String newStatus,
    String? orderRemark,
    String? invoiceNumber,
    Box? targetBoxForCancelled,
    Box? targetBoxForInvoiced,
  }) async {
    int updatedCount = 0;
    final List<MapEntry<dynamic, dynamic>> remainingOrders = [];

    for (var key in orderBox.keys.toList()) {
      final order = orderBox.get(key);
      if (order is Map<String, dynamic> &&
          order['seathiveOrderId'] == seathiveOrderId) {
        order['status'] = newStatus;
        order['edit'] = "Yes";
        order['statusEdited'] = "true";
        if (orderRemark != null) order['orderRemark'] = orderRemark;
        if (invoiceNumber != null) order['invoiceNumber'] = invoiceNumber;

        updatedCount++;

        // Move to appropriate box based on status
        if (newStatus.toLowerCase() == 'cancelled' &&
            targetBoxForCancelled != null) {
          await targetBoxForCancelled.add(order);
        } else if (newStatus.toLowerCase() == 'invoiced' &&
            targetBoxForInvoiced != null) {
          await targetBoxForInvoiced.add(order);
        } else {
          remainingOrders.add(MapEntry(key, order));
        }
      } else {
        remainingOrders.add(MapEntry(key, order));
      }
    }

    return _OrderUpdateResult(
      updatedCount: updatedCount,
      remainingOrders: remainingOrders,
    );
  }

  static Future<void> _reindexOrderBox(
    Box orderBox,
    List<MapEntry<dynamic, dynamic>> remainingOrders,
  ) async {
    await orderBox.clear();
    for (var entry in remainingOrders) {
      await orderBox.add(entry.value);
    }
    debugPrint("♻️ Orders reindexed. Remaining: ${orderBox.length}");
  }
}

// Helper classes
class _StockRestoreData {
  final List<String> varianceCodes;
  final List<String> varianceNames;
  final List<double> deductionAmounts;
  final List<String> uoms;

  _StockRestoreData({
    required this.varianceCodes,
    required this.varianceNames,
    required this.deductionAmounts,
    required this.uoms,
  });
}

class _OrderUpdateResult {
  final int updatedCount;
  final List<MapEntry<dynamic, dynamic>> remainingOrders;

  _OrderUpdateResult({
    required this.updatedCount,
    required this.remainingOrders,
  });
}

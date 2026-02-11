import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Server_Client/handlers/invoice_handler.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/Server_Client/stockupdateService.dart'
    hide getStockDeductionAmount;
import 'package:yen_pos/kotpreinvoice/services/CancellationReceipt.dart';
import 'package:yen_pos/kotpreinvoice/services/sync_service.dart';

// Future<void> patchOrderInHiveIndexWise(
//   String hiveOrderId,
//   int updatedIndex,
//   double updatedQty,
//   double updatedCancelledQty,
//   double totalAmount,
//   bool partiallycancelled,

// ) async {
//   var orderBox = await Hive.box('ordersBox');

//   for (int i = 0; i < orderBox.length; i++) {
//     var orderData = orderBox.getAt(i);
//     if (orderData['hiveOrderId'] == hiveOrderId) {
//       List<double> quantities = (orderData['quantities'] as List)
//           .map((e) => (e as num).toDouble())
//           .toList();
//       List<double> cancelledQty = (orderData['cancelledQty'] as List)
//           .map((e) => (e as num).toDouble())
//           .toList();

//       quantities[updatedIndex] = updatedQty;
//       cancelledQty[updatedIndex] = updatedCancelledQty;

//       orderData['quantities'] = quantities;
//       orderData['cancelledQty'] = cancelledQty;
//       orderData['totalAmount'] = totalAmount;
//       orderData['partiallycancelled'] = partiallycancelled;

//       await orderBox.putAt(i, orderData);
//       break;
//     }
//   }
// }

// Future<void> patchOrderInHiveIndexWise(
//   String hiveOrderId,
//   int updatedIndex,
//   double updatedQty,
//   double updatedCancelledQty,
//   double totalAmount,
//   bool partiallycancelled,
//   String ipAddress,
// ) async {
//   final orderBox = Hive.isBoxOpen('ordersBox')
//       ? Hive.box('ordersBox')
//       : await Hive.openBox('ordersBox');

//   Map<String, dynamic>? updatedOrder;

//   for (int i = 0; i < orderBox.length; i++) {
//     final rawOrder = orderBox.getAt(i);

//     if (rawOrder is! Map || rawOrder['hiveOrderId'] != hiveOrderId) continue;

//     final orderData = normalizeMap(rawOrder);

//     /* ================= QUANTITIES ================= */
//     final List<double> quantities = (orderData['quantities'] as List)
//         .map((e) => (e as num).toDouble())
//         .toList();
//     final List<double> cancelledQty = (orderData['cancelledQty'] as List)
//         .map((e) => (e as num).toDouble())
//         .toList();

//     quantities[updatedIndex] = updatedQty;
//     cancelledQty[updatedIndex] = updatedCancelledQty;

//     orderData['quantities'] = quantities;
//     orderData['cancelledQty'] = cancelledQty;
//     orderData['totalAmount'] = totalAmount;
//     orderData['partiallycancelled'] = partiallycancelled;

//     /* ================= CONFIG SYNC ================= */
//     final List<String> varianceNames = List<String>.from(
//       orderData['varianceNames'],
//     );

//     final String varianceName = varianceNames[updatedIndex];

//     // Normalize configs
//     final List<Map<String, dynamic>> configs =
//         (orderData['config'] as List? ?? []).map(normalizeMap).toList();

//     // Find config for this variance
//     Map<String, dynamic>? cfg = configs.firstWhere(
//       (c) => c['varianceName'] == varianceName,
//       orElse: () => {},
//     );

//     // ❌ FULL CANCEL → REMOVE CONFIG
//     if (updatedQty <= 0) {
//       configs.removeWhere((c) => c['varianceName'] == varianceName);
//     }
//     // 🔄 REVERSE / PARTIAL → ADD OR ADJUST CONFIG
//     else {
//       // If config doesn't exist → create it
//       if (cfg.isEmpty) {
//         cfg = {
//           'varianceName': varianceName,
//           'weight': orderData['weights']?[updatedIndex] ?? 0.0,
//           'configQty': List.filled(updatedQty.toInt(), 1),
//           'addOn': List.generate(updatedQty.toInt(), (_) => []),
//           'addOnQuantities': List.generate(updatedQty.toInt(), (_) => []),
//           'variance': List.generate(updatedQty.toInt(), (_) => ''),
//           'type': List.generate(updatedQty.toInt(), (_) => ''),
//           'remark': List.generate(updatedQty.toInt(), (_) => ''),
//           'addOnPrice': List.generate(updatedQty.toInt(), (_) => []),
//         };
//         configs.add(cfg);
//       } else {
//         final List<dynamic> configQty = List.from(cfg['configQty'] ?? []);

//         final int currentConfigQty = configQty.length;
//         final int targetQty = updatedQty.toInt();

//         // 🔼 Need to ADD config rows
//         if (targetQty > currentConfigQty) {
//           final int toAdd = targetQty - currentConfigQty;

//           configQty.addAll(List.filled(toAdd, 1));
//           cfg['addOn']?.addAll(List.generate(toAdd, (_) => []));
//           cfg['addOnQuantities']?.addAll(List.generate(toAdd, (_) => []));
//           cfg['variance']?.addAll(List.generate(toAdd, (_) => ''));
//           cfg['type']?.addAll(List.generate(toAdd, (_) => ''));
//           cfg['remark']?.addAll(List.generate(toAdd, (_) => ''));
//           cfg['addOnPrice']?.addAll(List.generate(toAdd, (_) => []));
//         }
//         // 🔽 Need to REMOVE config rows
//         else if (targetQty < currentConfigQty) {
//           configQty.removeRange(targetQty, currentConfigQty);
//           cfg['addOn']?.removeRange(targetQty, currentConfigQty);
//           cfg['addOnQuantities']?.removeRange(targetQty, currentConfigQty);
//           cfg['variance']?.removeRange(targetQty, currentConfigQty);
//           cfg['type']?.removeRange(targetQty, currentConfigQty);
//           cfg['remark']?.removeRange(targetQty, currentConfigQty);
//           cfg['addOnPrice']?.removeRange(targetQty, currentConfigQty);
//         }

//         cfg['configQty'] = configQty;
//       }
//     }

//     // Save back
//     orderData['config'] = configs;

//     /* ================= SAVE ================= */
//     await orderBox.putAt(i, orderData);
//     updatedOrder = orderData;
//     break;
//   }

//   if (updatedOrder == null) return;

//   /* =========================================================
//      🖨️ ITEM REVERTED PRINT (NEW – SINGLE SOURCE OF TRUTH)
//   ========================================================= */
//   try {
//     final String itemName = updatedOrder['varianceNames'][updatedIndex]
//         .toString()
//         .trim()
//         .toLowerCase();

//     if (ipAddress.isNotEmpty) {
//       final List<double> prices = (updatedOrder['prices'] as List)
//           .map((e) => (e as num).toDouble())
//           .toList();

//       final Map<String, dynamic> filteredOrder = {
//         ...updatedOrder,
//         'quantities': [updatedQty],
//         'cancelledQty': [updatedCancelledQty],
//         'amounts': [updatedQty * prices[updatedIndex]],
//         'prices': [prices[updatedIndex]],
//         'varianceNames': [updatedOrder['varianceNames'][updatedIndex]],
//         'config': (updatedOrder['config'] as List)
//             .map(normalizeMap)
//             .where(
//               (c) =>
//                   c['varianceName'] ==
//                   updatedOrder?['varianceNames'][updatedIndex],
//             )
//             .toList(),
//       };

//       await CancelPrinterService.printUniversalReceipt(
//         ipAddress: ipAddress,
//         tableNumber: updatedOrder['table'] ?? '',
//         seat: updatedOrder['seat'] ?? '',
//         userName: updatedOrder['userName'] ?? '',
//         waiter: updatedOrder['waiter'] ?? '',
//         seatOrders: [filteredOrder],
//         receiptType: 'ITEM REVERTED',
//       );

//       debugPrint("✅ ITEM REVERTED printed for $itemName");
//     }
//   } catch (e) {
//     debugPrint("❌ Printer error (REVERT): $e");
//   }

//   /* ================= SEND TO CLIENTS ================= */
//   sendDataToClients({
//     'action': 'reverseCancelOrderItem',
//     'hiveOrderId': hiveOrderId,
//     'updatedIndex': updatedIndex,
//     'updatedQuantity': updatedQty,
//     'updatedCancelledQty': updatedCancelledQty,
//     'totalAmount': totalAmount,
//     'partiallycancelled': partiallycancelled,
//     'config': (updatedOrder['config'] as List).map(normalizeMap).toList(),
//   }, clients);
// }

// Future<void> patchOrderInHiveIndexWise(
//   String hiveOrderId,
//   int updatedIndex,
//   double updatedQty,
//   double updatedCancelledQty,
//   double totalAmount,
//   bool partiallycancelled,
//   String ipAddress,
// ) async {
//   debugPrint("totalAmount of reverse order is $totalAmount");
//   final orderBox = Hive.isBoxOpen('ordersBox')
//       ? Hive.box('ordersBox')
//       : await Hive.openBox('ordersBox');

//   Map<String, dynamic>? updatedOrder;

//   try {
//     for (int i = 0; i < orderBox.length; i++) {
//       final rawOrder = orderBox.getAt(i);

//       if (rawOrder is! Map || rawOrder['hiveOrderId'] != hiveOrderId) {
//         continue;
//       }

//       final orderData = normalizeMap(rawOrder);

//       debugPrint("🟢 PATCH START → Order: $hiveOrderId");
//       debugPrint("🔹 updatedIndex: $updatedIndex");
//       debugPrint("🔹 updatedQty: $updatedQty");
//       debugPrint("🔹 updatedCancelledQty: $updatedCancelledQty");

//       /* ================= QUANTITIES ================= */

//       final List<double> quantities = (orderData['quantities'] as List)
//           .map((e) => (e as num).toDouble())
//           .toList();

//       final List<double> cancelledQty = (orderData['cancelledQty'] as List)
//           .map((e) => (e as num).toDouble())
//           .toList();

//       if (updatedIndex < 0 || updatedIndex >= quantities.length) {
//         debugPrint("❌ Invalid updatedIndex for quantities");
//         return;
//       }

//       quantities[updatedIndex] = updatedQty;
//       cancelledQty[updatedIndex] = updatedCancelledQty;

//       orderData['quantities'] = quantities;
//       orderData['cancelledQty'] = cancelledQty;
//       orderData['totalAmount'] = totalAmount;
//       orderData['partiallycancelled'] = partiallycancelled;

//       /* ================= CONFIG PATCH (PATCH ONLY) ================= */

//       final List<Map<String, dynamic>> configs =
//           (orderData['config'] as List? ?? []).map(normalizeMap).toList();

//       if (updatedIndex < 0 || updatedIndex >= configs.length) {
//         debugPrint("❌ Invalid updatedIndex for config list");
//         return;
//       }

//       final Map<String, dynamic> cfg = configs[updatedIndex];

//       debugPrint(
//         "🛠️ Config BEFORE → index=$updatedIndex | "
//         "variance=${cfg['varianceName']} | "
//         "configQty=${cfg['configQty']}",
//       );

//       // Ensure configQty exists
//       List<dynamic> configQty = List.from(cfg['configQty'] ?? []);

//       if (configQty.isEmpty) {
//         configQty.add(0);
//       }

//       // 🔥 SINGLE RULE
//       // Cancel  → 0
//       // Revert  → actual qty
//       configQty[0] = updatedQty.toInt();

//       cfg['configQty'] = configQty;

//       debugPrint(
//         "✅ Config AFTER  → index=$updatedIndex | "
//         "variance=${cfg['varianceName']} | "
//         "configQty=${cfg['configQty']}",
//       );

//       orderData['config'] = configs;

//       /* ================= SAVE ================= */

//       await orderBox.putAt(i, orderData);
//       updatedOrder = orderData;

//       debugPrint("💾 Hive updated successfully");
//       break;
//     }

//     if (updatedOrder == null) {
//       debugPrint("❌ Order not found in Hive");
//       return;
//     }

//     /* =========================================================
//        🖨️ PRINT (INDEX-SAFE)
//     ========================================================= */

//     try {
//       if (ipAddress.isNotEmpty) {
//         final List<double> prices = (updatedOrder['prices'] as List)
//             .map((e) => (e as num).toDouble())
//             .toList();

//         final Map<String, dynamic> filteredOrder = {
//           ...updatedOrder,
//           'quantities': [updatedQty],
//           'cancelledQty': [updatedCancelledQty],
//           'amounts': [updatedQty * prices[updatedIndex]],
//           'prices': [prices[updatedIndex]],
//           'varianceNames': [updatedOrder['varianceNames'][updatedIndex]],
//           'config': [
//             (updatedOrder['config'] as List)
//                 .map(normalizeMap)
//                 .elementAt(updatedIndex),
//           ],
//         };

//         debugPrint("🖨️ Printing with config index $updatedIndex");

//         await CancelPrinterService.printUniversalReceipt(
//           ipAddress: ipAddress,
//           tableNumber: updatedOrder['table'] ?? '',
//           seat: updatedOrder['seat'] ?? '',
//           userName: updatedOrder['userName'] ?? '',
//           waiter: updatedOrder['waiter'] ?? '',
//           seatOrders: [filteredOrder],
//           receiptType: updatedQty > 0 ? 'ITEM REVERTED' : 'ITEM CANCELLED',
//         );

//         debugPrint("✅ Print success");
//       }
//     } catch (e) {
//       debugPrint("❌ Printer error: $e");
//     }

//     /* ================= CLIENT SYNC ================= */

//     sendDataToClients({
//       'action': 'reverseCancelOrderItem',
//       'hiveOrderId': hiveOrderId,
//       'updatedIndex': updatedIndex,
//       'updatedQuantity': updatedQty,
//       'updatedCancelledQty': updatedCancelledQty,
//       'totalAmount': totalAmount,
//       'partiallycancelled': partiallycancelled,
//       'config': (updatedOrder['config'] as List).map(normalizeMap).toList(),
//     }, clients);

//     debugPrint("📡 Clients synced successfully");
//   } catch (e, s) {
//     debugPrint("💥 patchOrderInHiveIndexWise ERROR: $e");
//     debugPrint("📌 Stack: $s");
//   }
// }

Future<void> patchOrderInHiveIndexWise(
  String hiveOrderId,
  int updatedIndex,
  double updatedQty,
  double updatedCancelledQty,
  double totalAmount,
  bool partiallycancelled,
  String ipAddress,
  Map<String, dynamic> data,
) async {
  debugPrint("════════════════════════════════════════════");
  debugPrint("➡️ patchOrderInHiveIndexWise START");
  debugPrint("hiveOrderId           : $hiveOrderId");
  debugPrint("updatedIndex          : $updatedIndex");
  debugPrint("updatedQty            : $updatedQty");
  debugPrint("updatedCancelledQty   : $updatedCancelledQty");
  debugPrint("totalAmount           : $totalAmount");
  debugPrint("partiallycancelled    : $partiallycancelled");
  debugPrint("ipAddress             : $ipAddress");
  debugPrint("data             : $data");
  debugPrint("════════════════════════════════════════════");

  final orderBox = Hive.isBoxOpen('ordersBox')
      ? Hive.box('ordersBox')
      : await Hive.openBox('ordersBox');

  debugPrint("📦 ordersBox length : ${orderBox.length}");

  Map<String, dynamic>? updatedOrder;

  try {
    for (int i = 0; i < orderBox.length; i++) {
      final rawOrder = orderBox.getAt(i);

      debugPrint("🔍 Checking Hive index $i");

      if (rawOrder is! Map) {
        debugPrint("⚠️ Skipped: Not a Map at index $i");
        continue;
      }

      if (rawOrder['hiveOrderId'] != hiveOrderId) {
        debugPrint("⚠️ hiveOrderId mismatch at index $i");
        continue;
      }

      debugPrint("✅ Matching order found at index $i");

      final orderData = normalizeMap(rawOrder);

      debugPrint("🟢 PATCH START → Order: $hiveOrderId");
      debugPrint("Current quantities    : ${orderData['quantities']}");
      debugPrint("Current cancelledQty  : ${orderData['cancelledQty']}");
      debugPrint("Current totalAmount   : ${orderData['totalAmount']}");

      /* ================= QUANTITIES ================= */

      final List<double> quantities = (orderData['quantities'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      final List<double> cancelledQty = (orderData['cancelledQty'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      if (updatedIndex < 0 || updatedIndex >= quantities.length) {
        debugPrint("❌ Invalid updatedIndex for quantities");
        debugPrint("quantities length : ${quantities.length}");
        return;
      }

      debugPrint(
        "✏️ Updating quantities[$updatedIndex] "
        "${quantities[updatedIndex]} → $updatedQty",
      );

      debugPrint(
        "✏️ Updating cancelledQty[$updatedIndex] "
        "${cancelledQty[updatedIndex]} → $updatedCancelledQty",
      );

      quantities[updatedIndex] = updatedQty;
      cancelledQty[updatedIndex] = updatedCancelledQty;

      orderData['quantities'] = quantities;
      orderData['cancelledQty'] = cancelledQty;
      orderData['totalAmount'] = totalAmount;
      orderData['partiallycancelled'] = partiallycancelled;
      orderData['fieldsEdited'] = 'true';
      orderData['sync'] = "Yes";
      orderData['edit'] = "Yes";

      debugPrint("✅ Quantities patched");
      debugPrint("Updated quantities   : $quantities");
      debugPrint("Updated cancelledQty : $cancelledQty");

      /* ================= CONFIG PATCH ================= */

      final List<Map<String, dynamic>> configs =
          (orderData['config'] as List? ?? []).map(normalizeMap).toList();

      debugPrint("Config list length : ${configs.length}");

      if (updatedIndex < 0 || updatedIndex >= configs.length) {
        debugPrint("❌ Invalid updatedIndex for config list");
        return;
      }

      final Map<String, dynamic> cfg = configs[updatedIndex];

      debugPrint(
        "🛠️ Config BEFORE → "
        "index=$updatedIndex | "
        "variance=${cfg['varianceName']} | "
        "weight=${cfg['weight']} | "
        "configQty=${cfg['configQty']}",
      );

      List<dynamic> configQty = List.from(cfg['configQty'] ?? []);

      if (configQty.isEmpty) {
        debugPrint("⚠️ configQty empty → initializing with 0");
        configQty.add(0);
      }

      debugPrint(
        "✏️ Updating configQty[0] "
        "${configQty[0]} → ${updatedQty.toInt()}",
      );

      configQty[0] = updatedQty.toInt();
      cfg['configQty'] = configQty;

      debugPrint(
        "✅ Config AFTER  → "
        "index=$updatedIndex | "
        "variance=${cfg['varianceName']} | "
        "weight=${cfg['weight']} | "
        "configQty=${cfg['configQty']}",
      );

      orderData['config'] = configs;

      /* ================= SAVE ================= */

      debugPrint("💾 Saving updated order back to Hive (index $i)");
      await orderBox.putAt(i, orderData);
      updatedOrder = orderData;

      debugPrint("✅ Hive update successful");
      break;
    }

    if (updatedOrder == null) {
      debugPrint("❌ Order not found in Hive for hiveOrderId=$hiveOrderId");
      return;
    }

    /* ================= PRINT ================= */

    try {
      if (ipAddress.isNotEmpty) {
        debugPrint("🖨️ Preparing print payload");
        final List<double> prices = (updatedOrder['prices'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
        final List<double> amount = (updatedOrder['amounts'] as List)
            .map((e) => (e as num).toDouble())
            .toList();

        debugPrint("Prices list : $amount");

        final Map<String, dynamic> filteredOrder = {
          ...updatedOrder,
          'quantities': [updatedQty],
          'cancelledQty': [updatedCancelledQty],
          'amounts': [amount[updatedIndex]],
          'prices': [prices[updatedIndex]],
          'varianceNames': [updatedOrder['varianceNames'][updatedIndex]],
          'config': [
            (updatedOrder['config'] as List)
                .map(normalizeMap)
                .elementAt(updatedIndex),
          ],
        };

        debugPrint("🖨️ Filtered print order : $filteredOrder");
        debugPrint(
          "🖨️ Receipt type : "
          "${updatedQty > 0 ? 'ITEM REVERTED' : 'ITEM CANCELLED'}",
        );

        await CancelPrinterService.printUniversalReceipt(
          ipAddress: ipAddress,
          tableNumber: updatedOrder['table'] ?? '',
          seat: updatedOrder['seat'] ?? '',
          userName: updatedOrder['userName'] ?? '',
          waiter: updatedOrder['waiter'] ?? '',
          seatOrders: [filteredOrder],
          receiptType: updatedQty > 0 ? 'ITEM REVERTED' : 'ITEM CANCELLED',
        );

        debugPrint("✅ Print completed successfully");
      } else {
        debugPrint("⚠️ Print skipped: ipAddress empty");
      }
    } catch (e) {
      debugPrint("❌ Printer error: $e");
    }
    debugPrint("⬇️ Decreasing stock by");
    final double weight =
        double.tryParse(data['weight']?.toString() ?? '0') ?? 0.0;
    final double qty =
        double.tryParse(data['updatedQuantity']?.toString() ?? '0') ?? 0.0;

    final deduction = getStockDeductionAmount(
      uom: data['uom'].toString(),
      weight: weight,
      qty: qty,
    );

    debugPrint("deduction is $deduction");

    debugPrint("⬇️ Decreasing stock by $deduction");

    await decreaseLocalHiveStock(
      clients: clients,
      locationId: locationId,
      varianceCodes: [data['varianceItemCode']],
      varianceNames: [data['varianceName']],
      stockDeductionAmounts: [deduction],
      uoms: [data['uom']],
    );
    /* ================= CLIENT SYNC ================= */

    final clientPayload = {
      'action': 'reverseCancelOrderItem',
      'hiveOrderId': hiveOrderId,
      'updatedIndex': updatedIndex,
      'updatedQuantity': updatedQty,
      'updatedCancelledQty': updatedCancelledQty,
      'totalAmount': totalAmount,
      'partiallycancelled': partiallycancelled,
      'config': (updatedOrder['config'] as List).map(normalizeMap).toList(),
      'fieldsEdited': 'true',
      'sync': "Yes",
      'edit': "Yes",
    };

    debugPrint("📡 Sending update to clients : $clientPayload");

    sendDataToClients(clientPayload, clients);
    SyncServiceKot().patchEditedOrders();

    debugPrint("✅ Clients synced successfully");
  } catch (e, s) {
    debugPrint("💥 patchOrderInHiveIndexWise ERROR");
    debugPrint("ERROR : $e");
    debugPrint("STACK : $s");
  }

  debugPrint("⬅️ patchOrderInHiveIndexWise END");
  debugPrint("════════════════════════════════════════════");
}

Map<String, dynamic> normalizeMap(dynamic raw) {
  return Map<String, dynamic>.from(
    (raw as Map).map((k, v) => MapEntry(k.toString(), v)),
  );
}

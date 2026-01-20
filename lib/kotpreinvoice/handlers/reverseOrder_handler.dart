import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/kotpreinvoice/services/CancellationReceipt.dart';

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

Future<void> patchOrderInHiveIndexWise(
  String hiveOrderId,
  int updatedIndex,
  double updatedQty,
  double updatedCancelledQty,
  double totalAmount,
  bool partiallycancelled,
  String ipAddress,
) async {
  final orderBox = Hive.isBoxOpen('ordersBox')
      ? Hive.box('ordersBox')
      : await Hive.openBox('ordersBox');

  Map<String, dynamic>? updatedOrder;

  for (int i = 0; i < orderBox.length; i++) {
    final rawOrder = orderBox.getAt(i);

    if (rawOrder is! Map || rawOrder['hiveOrderId'] != hiveOrderId) continue;

    final orderData = normalizeMap(rawOrder);

    /* ================= QUANTITIES ================= */
    final List<double> quantities = (orderData['quantities'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final List<double> cancelledQty = (orderData['cancelledQty'] as List)
        .map((e) => (e as num).toDouble())
        .toList();

    quantities[updatedIndex] = updatedQty;
    cancelledQty[updatedIndex] = updatedCancelledQty;

    orderData['quantities'] = quantities;
    orderData['cancelledQty'] = cancelledQty;
    orderData['totalAmount'] = totalAmount;
    orderData['partiallycancelled'] = partiallycancelled;

    /* ================= CONFIG SYNC ================= */
    final List<String> varianceNames = List<String>.from(
      orderData['varianceNames'],
    );

    final String varianceName = varianceNames[updatedIndex];

    // Normalize configs
    final List<Map<String, dynamic>> configs =
        (orderData['config'] as List? ?? []).map(normalizeMap).toList();

    // Find config for this variance
    Map<String, dynamic>? cfg = configs.firstWhere(
      (c) => c['varianceName'] == varianceName,
      orElse: () => {},
    );

    // ❌ FULL CANCEL → REMOVE CONFIG
    if (updatedQty <= 0) {
      configs.removeWhere((c) => c['varianceName'] == varianceName);
    }
    // 🔄 REVERSE / PARTIAL → ADD OR ADJUST CONFIG
    else {
      // If config doesn't exist → create it
      if (cfg.isEmpty) {
        cfg = {
          'varianceName': varianceName,
          'weight': orderData['weights']?[updatedIndex] ?? 0.0,
          'configQty': List.filled(updatedQty.toInt(), 1),
          'addOn': List.generate(updatedQty.toInt(), (_) => []),
          'addOnQuantities': List.generate(updatedQty.toInt(), (_) => []),
          'variance': List.generate(updatedQty.toInt(), (_) => ''),
          'type': List.generate(updatedQty.toInt(), (_) => ''),
          'remark': List.generate(updatedQty.toInt(), (_) => ''),
          'addOnPrice': List.generate(updatedQty.toInt(), (_) => []),
        };
        configs.add(cfg);
      } else {
        final List<dynamic> configQty = List.from(cfg['configQty'] ?? []);

        final int currentConfigQty = configQty.length;
        final int targetQty = updatedQty.toInt();

        // 🔼 Need to ADD config rows
        if (targetQty > currentConfigQty) {
          final int toAdd = targetQty - currentConfigQty;

          configQty.addAll(List.filled(toAdd, 1));
          cfg['addOn']?.addAll(List.generate(toAdd, (_) => []));
          cfg['addOnQuantities']?.addAll(List.generate(toAdd, (_) => []));
          cfg['variance']?.addAll(List.generate(toAdd, (_) => ''));
          cfg['type']?.addAll(List.generate(toAdd, (_) => ''));
          cfg['remark']?.addAll(List.generate(toAdd, (_) => ''));
          cfg['addOnPrice']?.addAll(List.generate(toAdd, (_) => []));
        }
        // 🔽 Need to REMOVE config rows
        else if (targetQty < currentConfigQty) {
          configQty.removeRange(targetQty, currentConfigQty);
          cfg['addOn']?.removeRange(targetQty, currentConfigQty);
          cfg['addOnQuantities']?.removeRange(targetQty, currentConfigQty);
          cfg['variance']?.removeRange(targetQty, currentConfigQty);
          cfg['type']?.removeRange(targetQty, currentConfigQty);
          cfg['remark']?.removeRange(targetQty, currentConfigQty);
          cfg['addOnPrice']?.removeRange(targetQty, currentConfigQty);
        }

        cfg['configQty'] = configQty;
      }
    }

    // Save back
    orderData['config'] = configs;

    /* ================= SAVE ================= */
    await orderBox.putAt(i, orderData);
    updatedOrder = orderData;
    break;
  }

  if (updatedOrder == null) return;

  /* =========================================================
     🖨️ ITEM REVERTED PRINT (NEW – SINGLE SOURCE OF TRUTH)
  ========================================================= */
  try {
    final String itemName = updatedOrder['varianceNames'][updatedIndex]
        .toString()
        .trim()
        .toLowerCase();

    if (ipAddress.isNotEmpty) {
      final List<double> prices = (updatedOrder['prices'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      final Map<String, dynamic> filteredOrder = {
        ...updatedOrder,
        'quantities': [updatedQty],
        'cancelledQty': [updatedCancelledQty],
        'amounts': [updatedQty * prices[updatedIndex]],
        'prices': [prices[updatedIndex]],
        'varianceNames': [updatedOrder['varianceNames'][updatedIndex]],
        'config': (updatedOrder['config'] as List)
            .map(normalizeMap)
            .where(
              (c) =>
                  c['varianceName'] ==
                  updatedOrder?['varianceNames'][updatedIndex],
            )
            .toList(),
      };

      await CancelPrinterService.printUniversalReceipt(
        ipAddress: ipAddress,
        tableNumber: updatedOrder['table'] ?? '',
        seat: updatedOrder['seat'] ?? '',
        userName: updatedOrder['userName'] ?? '',
        waiter: updatedOrder['waiter'] ?? '',
        seatOrders: [filteredOrder],
        receiptType: 'ITEM REVERTED',
      );

      debugPrint("✅ ITEM REVERTED printed for $itemName");
    }
  } catch (e) {
    debugPrint("❌ Printer error (REVERT): $e");
  }

  /* ================= SEND TO CLIENTS ================= */
  sendDataToClients({
    'action': 'reverseCancelOrderItem',
    'hiveOrderId': hiveOrderId,
    'updatedIndex': updatedIndex,
    'updatedQuantity': updatedQty,
    'updatedCancelledQty': updatedCancelledQty,
    'totalAmount': totalAmount,
    'partiallycancelled': partiallycancelled,
    'config': (updatedOrder['config'] as List).map(normalizeMap).toList(),
  }, clients);
}

Map<String, dynamic> normalizeMap(dynamic raw) {
  return Map<String, dynamic>.from(
    (raw as Map).map((k, v) => MapEntry(k.toString(), v)),
  );
}

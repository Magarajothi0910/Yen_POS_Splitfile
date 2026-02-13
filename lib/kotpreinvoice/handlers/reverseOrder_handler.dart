import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Server_Client/handlers/invoice_handler.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/Server_Client/stockupdateService.dart'
    hide getStockDeductionAmount;
import 'package:yen_pos/kotpreinvoice/services/CancellationReceipt.dart';
import 'package:yen_pos/kotpreinvoice/services/sync_service.dart';

Future<void> patchOrderInHiveIndexWise(
  String hiveOrderId,
  int updatedIndex,
  double updatedQty,
  double revertedQty,
  double updatedCancelledQty,
  double updatedAmount,
  double totalAmount,
  bool partiallycancelled,
  String ipAddress,
  Map<String, dynamic> data,
) async {
  debugPrint("════════════════════════════════════════════");
  debugPrint("➡️ patchOrderInHiveIndexWise START");

  final orderBox = Hive.isBoxOpen('ordersBox')
      ? Hive.box('ordersBox')
      : await Hive.openBox('ordersBox');

  Map<String, dynamic>? updatedOrder;

  try {
    for (int i = 0; i < orderBox.length; i++) {
      final rawOrder = orderBox.getAt(i);
      if (rawOrder is! Map) continue;
      if (rawOrder['hiveOrderId'] != hiveOrderId) continue;

      final orderData = normalizeMap(rawOrder);

      /* ================= QUANTITIES ================= */

      final List<double> quantities = (orderData['quantities'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      final List<double> cancelledQty = (orderData['cancelledQty'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final List<double> amounts = (orderData['amounts'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      amounts[updatedIndex] = updatedAmount;

      quantities[updatedIndex] = updatedQty;
      cancelledQty[updatedIndex] = updatedCancelledQty;
      orderData['amounts'] = amounts;
      orderData['quantities'] = quantities;
      orderData['cancelledQty'] = cancelledQty;
      orderData['totalAmount'] = totalAmount;
      orderData['partiallycancelled'] = partiallycancelled;
      orderData['fieldsEdited'] = 'true';
      orderData['sync'] = "Yes";
      orderData['edit'] = "Yes";

      /* ================= CONFIG PATCH  (ONLY CHANGE HERE) ================= */

      final List<Map<String, dynamic>> configs = (orderData['config'] as List)
          .map(normalizeMap)
          .toList();

      final Map<String, dynamic> cfg = configs[updatedIndex];
      List<dynamic> configQty = List.from(cfg['configQty'] ?? []);

      final int qty = updatedQty.toInt();

      // ✅ CORRECT LOGIC — ONLY FIX
      for (int j = 0; j < configQty.length; j++) {
        configQty[j] = j < qty ? 1 : 0;
      }

      cfg['configQty'] = configQty;
      orderData['config'] = configs;

      /* ================= SAVE ================= */

      await orderBox.putAt(i, orderData);
      updatedOrder = orderData;
      break;
    }

    if (updatedOrder == null) return;

    /* ================= PRINT (UNCHANGED) ================= */

    if (ipAddress.isNotEmpty) {
      final List<double> prices = (updatedOrder['prices'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      final List<double> amounts = (updatedOrder['amounts'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      final Map<String, dynamic> filteredOrder = {
        ...updatedOrder,
        'quantities': [updatedQty],
        'cancelledQty': [updatedCancelledQty],
        'amounts': [amounts[updatedIndex]],
        'prices': [prices[updatedIndex]],
        'varianceNames': [updatedOrder['varianceNames'][updatedIndex]],
        'config': [
          (updatedOrder['config'] as List)
              .map(normalizeMap)
              .elementAt(updatedIndex),
        ],
      };

      await CancelPrinterService.printUniversalReceipt(
        ipAddress: ipAddress,
        tableNumber: updatedOrder['table'] ?? '',
        seat: updatedOrder['seat'] ?? '',
        userName: updatedOrder['userName'] ?? '',
        waiter: updatedOrder['waiter'] ?? '',
        seatOrders: [filteredOrder],
        receiptType: updatedQty > 0 ? 'ITEM REVERTED' : 'ITEM CANCELLED',
      );
    }

    /* ================= STOCK & SYNC (UNCHANGED) ================= */

    final double weight =
        double.tryParse(data['weight']?.toString() ?? '0') ?? 0.0;
    final double qty =
        double.tryParse(data['revertedQty']?.toString() ?? '0') ?? 0.0;

    final deduction = getStockDeductionAmount(
      uom: data['uom'].toString(),
      weight: weight,
      qty: qty,
    );

    await decreaseLocalHiveStock(
      clients: clients,
      locationId: locationId,
      varianceCodes: [data['varianceItemCode']],
      varianceNames: [data['varianceName']],
      stockDeductionAmounts: [deduction],
      uoms: [data['uom']],
    );

    final clientPayload = {
      'action': 'reverseCancelOrderItem',
      'hiveOrderId': hiveOrderId,
      'updatedIndex': updatedIndex,
      'updatedQuantity': updatedQty,
      'revertedQty': revertedQty,
      'updatedCancelledQty': updatedCancelledQty,
      'totalAmount': totalAmount,
      'partiallycancelled': partiallycancelled,
      'config': (updatedOrder['config'] as List).map(normalizeMap).toList(),
      'fieldsEdited': 'true',
      'sync': "Yes",
      'edit': "Yes",
    };

    sendDataToClients(clientPayload, clients);
    SyncServiceKot().patchEditedOrders();
  } catch (e, s) {
    debugPrint("💥 patchOrderInHiveIndexWise ERROR");
    debugPrint("ERROR : $e");
    debugPrint("STACK : $s");
  }

  debugPrint("⬅️ patchOrderInHiveIndexWise END");
}

Map<String, dynamic> normalizeMap(dynamic raw) {
  return Map<String, dynamic>.from(
    (raw as Map).map((k, v) => MapEntry(k.toString(), v)),
  );
}

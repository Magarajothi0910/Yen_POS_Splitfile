import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/Server_Client/stockupdateService.dart';
import 'package:yen_pos/kotpreinvoice/services/CancellationReceipt.dart';
import 'package:yen_pos/kotpreinvoice/services/hive_service.dart';
import 'package:yen_pos/kotpreinvoice/services/sync_service.dart';

import '../services/sendDataToClients.dart';

class CancelOrderPatchHandler {
  static Map<String, dynamic> normalizeMap(dynamic raw) {
    return Map<String, dynamic>.from(
      (raw as Map).map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  // static Future<void> patchCancelOrderItem(Map<String, dynamic> data) async {
  //   Map<String, dynamic>? updatedOrder;
  //   Map<String, dynamic>? previousOrder;

  //   try {
  //     debugPrint("🟡 patchCancelOrderItem called");
  //     debugPrint("➡️ Incoming data: $data");

  //     final orderBox = Hive.isBoxOpen('ordersBox')
  //         ? Hive.box('ordersBox')
  //         : await Hive.openBox('ordersBox');

  //     for (int i = 0; i < orderBox.length; i++) {
  //       var orderData = orderBox.get(i);

  //       if (orderData is Map &&
  //           orderData['hiveOrderId'] == data['hiveOrderId']) {
  //         debugPrint("✅ Order matched at Hive index $i");

  //         previousOrder = Map<String, dynamic>.from(orderData);

  //         // ===== PATCH BASIC FIELDS =====
  //         orderData['cancelledQty'] = data['cancelledQty'];
  //         orderData['totalAmount'] = data['totalAmount'];
  //         orderData['quantities'] = data['quantities'];
  //         orderData['itemRemark'] = data['itemRemark'];
  //         orderData['partiallycancelled'] = data['partiallycancelled'];
  //         orderData['fieldsEdited'] = 'true';
  //         orderData['sync'] = "Yes";
  //         orderData['edit'] = "Yes";

  //         final int itemIndex = data['itemIndex'];
  //         final int? configIndex = data['configIndex'];

  //         debugPrint("🧾 itemIndex: $itemIndex");
  //         debugPrint("⚙️ configIndex:  $configIndex");

  //         final List<double> updatedQuantities = (data['quantities'] as List)
  //             .map((e) => (e as num).toDouble())
  //             .toList();

  //         final String varianceName = orderData['varianceNames'][itemIndex];
  //         final double remainingQty = updatedQuantities[itemIndex];

  //         debugPrint("📦 varianceName: $varianceName");
  //         debugPrint("📉 remainingQty: $remainingQty");

  //         // ===== LOAD CONFIGS =====
  //         final List<Map<String, dynamic>> configs =
  //             (orderData['config'] as List? ?? [])
  //                 .map((c) => normalizeMap(c))
  //                 .toList();

  //         debugPrint("📋 Configs BEFORE update:");
  //         for (int c = 0; c < configs.length; c++) {
  //           debugPrint("   [$c] ${configs[c]}");
  //         }

  //         // ===== EXACT CONFIG CANCELLATION =====
  //         if (remainingQty <= 0 &&
  //             configIndex != null &&
  //             configIndex >= 0 &&
  //             configIndex < configs.length) {
  //           debugPrint(
  //             "✏️ Patching config at index $configIndex → ${configs[configIndex]}",
  //           );

  //           final config = configs[configIndex];

  //           // 1️⃣ Zero out quantity safely
  //           if (config['configQty'] is List) {
  //             for (int i = 0; i < data['cancelQty'].length; i++) {
  //               config['configQty'][i] = 0;
  //             }
  //           }
  //         } else {
  //           debugPrint("ℹ️ No config patch condition met");
  //         }

  //         orderData['config'] = configs;

  //         debugPrint("📋 Configs AFTER update:");
  //         for (int c = 0; c < configs.length; c++) {
  //           debugPrint("   [$c] ${configs[c]}");
  //         }

  //         final bool allCancelled = (data['quantities'] as List).every(
  //           (q) => (q as num).toDouble() == 0.0,
  //         );

  //         debugPrint("🚫 allCancelled: $allCancelled");

  //         if (allCancelled) {
  //           orderData['status'] = 'cancelled';
  //           debugPrint("🛑 Order marked as CANCELLED");
  //         }

  //         debugPrint("orderData is :: $orderData");

  //         await orderBox.put(i, orderData);

  //         final newData = orderBox.get(i);

  //         debugPrint('🟢 AFTER PUT');
  //         debugPrint('Index : $i');
  //         // debugPrint('Key   : $key');
  //         debugPrint('Value : ${newData['config']}');

  //         updatedOrder = Map<String, dynamic>.from(orderData);

  //         debugPrint("💾 Hive order updated successfully");
  //         break;
  //       }
  //     }

  //     // ================= PRINTING =================

  //     final int itemIndex = data['itemIndex'];
  //     final int? configIndex = data['configIndex'];

  //     debugPrint("🖨️ Preparing print payload");
  //     debugPrint("🧾 Print itemIndex: $itemIndex");
  //     debugPrint("⚙️ Print configIndex: $configIndex");

  //     final List<Map<String, dynamic>> previousConfigs =
  //         (previousOrder?['config'] as List? ?? [])
  //             .map((c) => normalizeMap(c))
  //             .toList();

  //     final List<Map<String, dynamic>> itemConfigs =
  //         (configIndex != null &&
  //             configIndex >= 0 &&
  //             configIndex < previousConfigs.length)
  //         ? [previousConfigs[configIndex]]
  //         : [];

  //     debugPrint("🖨️ itemConfigs (PRINT): $itemConfigs");

  //     final Map<String, dynamic> filteredOrder = {
  //       ...updatedOrder!,
  //       'quantities': [updatedOrder['quantities'][itemIndex]],
  //       'cancelledQty': [updatedOrder['cancelledQty'][itemIndex]],
  //       'prices': [updatedOrder['prices'][itemIndex]],
  //       'weights': [updatedOrder['weights'][itemIndex]],
  //       'varianceNames': [updatedOrder['varianceNames'][itemIndex]],
  //       'config': itemConfigs,
  //       'itemRemark': [data['itemRemark']],
  //     };

  //     debugPrint("🧾 Final print payload: $filteredOrder");

  //     // === STOCK INCREASE: Only for the item at 'itemIndex' ===
  //     try {
  //       final int itemIndex = data['itemIndex'] as int;

  //       // Helper to safely get value at index, or return null/default
  //       T? safeGet<T>(List<dynamic>? list, int index, [T? defaultValue]) {
  //         if (list == null || index < 0 || index >= list.length) {
  //           return defaultValue;
  //         }
  //         return list[index] as T?;
  //       }

  //       // Extract lists safely
  //       final List<dynamic> varianceCodesList =
  //           data['varianceitemCodes'] is List
  //           ? List.from(data['varianceitemCodes'])
  //           : [data['varianceitemCodes']];

  //       final List<dynamic> varianceNamesList = data['varianceNames'] is List
  //           ? List.from(data['varianceNames'])
  //           : [data['varianceNames']];

  //       final List<dynamic> cancelledQtyList = data['cancelledQty'] is List
  //           ? List.from(data['cancelledQty'])
  //           : [data['cancelledQty']];

  //       final List<dynamic> weightsList = updatedOrder['weights'];

  //       debugPrint("varianceNamesList is $varianceNamesList");
  //       debugPrint("weightsList is ${updatedOrder['weights']}");

  //       final List<dynamic> uomsList = data['uoms'] is List
  //           ? List.from(data['uoms'])
  //           : (data['uoms'] != null ? [data['uoms']] : ['Pcs']);

  //       // Find the maximum safe length (usually varianceCodesList is the reference)
  //       final int maxLength = varianceCodesList.length;

  //       if (itemIndex < 0 || itemIndex >= maxLength) {
  //         debugPrint(
  //           "⚠️ Invalid itemIndex: $itemIndex (valid range: 0–${maxLength - 1})",
  //         );
  //         // Skip stock increase safely
  //       } else {
  //         final String? code = safeGet<String>(
  //           varianceCodesList,
  //           itemIndex,
  //         )?.trim();
  //         final String? name = safeGet<String>(
  //           varianceNamesList,
  //           itemIndex,
  //         )?.trim();
  //         final dynamic cancelledQtyVal = safeGet(
  //           cancelledQtyList,
  //           itemIndex,
  //           0.0,
  //         );
  //         final dynamic weightVal = safeGet(weightsList, itemIndex, 0.0);

  //         debugPrint("weightVal is A $weightVal");
  //         final String uom =
  //             safeGet<String>(uomsList, itemIndex, 'Pcs')?.trim() ?? 'Pcs';

  //         if (code == null || code.isEmpty || name == null || name.isEmpty) {
  //           debugPrint(
  //             "Skipping stock increase: missing code/name at index $itemIndex",
  //           );
  //         } else {
  //           // Parse cancelled quantity
  //           double cancelledQty = 0.0;
  //           if (cancelledQtyVal is num) {
  //             cancelledQty = cancelledQtyVal.toDouble();
  //           } else if (cancelledQtyVal is String) {
  //             cancelledQty = double.tryParse(cancelledQtyVal) ?? 0.0;
  //           }

  //           if (cancelledQty <= 0) {
  //             debugPrint(
  //               "No cancelled quantity at index $itemIndex → skip stock increase",
  //             );
  //           } else {
  //             // Parse weight safely
  //             double weight = 0.0;
  //             if (weightVal is num) {
  //               weight = weightVal.toDouble();
  //             } else if (weightVal is String) {
  //               weight = double.tryParse(weightVal) ?? 0.0;
  //             }

  //             final double deduction = getStockDeductionAmount(
  //               uom: uom,
  //               weight: weight,
  //               qty: cancelledQty,
  //             );

  //             debugPrint("weight is deduction $weight");

  //             if (deduction > 0) {
  //               await increaseLocalHiveStock(
  //                 clients: clients,
  //                 branchAlias: aliasname,
  //                 varianceCodes: [code],
  //                 varianceNames: [name],
  //                 stockIncreaseAmounts: [deduction],
  //                 uoms: [uom],
  //               );

  //               debugPrint(
  //                 "✅ Stock increased: +$deduction $uom → $name ($code) [cancelled qty: $cancelledQty]",
  //               );
  //             } else {
  //               debugPrint("Zero deduction for $name → no stock increase");
  //             }
  //           }
  //         }
  //       }

  //       debugPrint(
  //         "Stock increase processing completed for itemIndex: $itemIndex",
  //       );
  //     } catch (e, stack) {
  //       debugPrint("❌ Error during safe stock increase: $e");
  //       debugPrint("Stack: $stack");
  //     }

  //     await CancelPrinterService.printUniversalReceipt(
  //       ipAddress: data['ipAddress'],
  //       tableNumber: updatedOrder['table'] ?? '',
  //       seat: updatedOrder['seat'] ?? '',
  //       userName: updatedOrder['userName'] ?? '',
  //       waiter: updatedOrder['waiter'] ?? '',
  //       seatOrders: [filteredOrder],
  //       receiptType: 'ITEM CANCELLED',
  //     );

  //     debugPrint("✅ Cancellation receipt printed");

  //     // ================= CLIENT SYNC =================

  //     sendDataToClients({
  //       'action': 'orderCancelled',
  //       'hiveOrderId': data['hiveOrderId'],
  //       'cancelledQty': data['cancelledQty'],
  //       'totalAmount': data['totalAmount'],
  //       'quantities': data['quantities'],
  //       'itemRemark': data['itemRemark'],
  //       'partiallycancelled': data['partiallycancelled'],
  //       'config': (updatedOrder['config'] as List? ?? [])
  //           .map((c) => normalizeMap(c))
  //           .toList(),
  //       'status': updatedOrder['status'],
  //       'fieldsEdited': 'true',
  //       'sync': "Yes",
  //       'edit': "Yes",
  //     }, clients);

  //     await SyncServiceKot().patchEditedOrders();

  //     debugPrint("📡 Clients notified");
  //   } catch (e, s) {
  //     debugPrint("❌ patchCancelOrderItem FAILED: $e");
  //     debugPrint("📌 StackTrace: $s");
  //   }
  // }

  static Future<void> patchCancelOrderItem(Map<String, dynamic> data) async {
    debugPrint('[01] ▶️ ENTER patchCancelOrderItem');
    debugPrint('[02] Incoming data => $data');

    Map<String, dynamic>? updatedOrder;
    Map<String, dynamic>? previousOrder;

    try {
      debugPrint('[03] Opening Hive ordersBox');

      final orderBox = Hive.isBoxOpen('ordersBox')
          ? Hive.box('ordersBox')
          : await Hive.openBox('ordersBox');

      debugPrint('[04] ordersBox length => ${orderBox.length}');

      for (int i = 0; i < orderBox.length; i++) {
        debugPrint('[05] Loop index i=$i');

        var orderData = orderBox.get(i);
        debugPrint('[06] orderData => $orderData');

        if (orderData is Map &&
            orderData['hiveOrderId'] == data['hiveOrderId']) {
          debugPrint('[07] ✅ Order matched at index $i');

          previousOrder = Map<String, dynamic>.from(orderData);
          debugPrint('[08] previousOrder snapshot saved');

          // ===== PATCH BASIC FIELDS =====
          debugPrint('[09] Patching base fields');
          orderData['cancelledQty'] = data['cancelledQty'];
          orderData['totalAmount'] = data['totalAmount'];
          orderData['quantities'] = data['quantities'];
          orderData['itemRemark'] = data['itemRemark'];
          orderData['partiallycancelled'] = data['partiallycancelled'];
          orderData['fieldsEdited'] = 'true';
          orderData['sync'] = "Yes";
          orderData['edit'] = "Yes";

          final int itemIndex = data['itemIndex'];
          final int? configIndex = data['configIndex'];
          // ===== PATCH AMOUNT FOR SINGLE ITEM ONLY =====
          if (orderData['amounts'] is List &&
              itemIndex >= 0 &&
              itemIndex < orderData['amounts'].length) {
            final List<double> amounts = List<double>.from(
              orderData['amounts'],
            );

            final double oldAmount = (amounts[itemIndex] as num).toDouble();
            final double cancelAmount = (data['cancelAmount'] as num)
                .toDouble();

            final double newAmount = (oldAmount - cancelAmount).clamp(
              0.0,
              double.infinity,
            );

            debugPrint('💰 Amount BEFORE [$itemIndex] => $oldAmount');
            debugPrint('💰 CancelAmount => $cancelAmount');
            debugPrint('💰 Amount AFTER [$itemIndex] => $newAmount');

            amounts[itemIndex] = newAmount;

            // 🔒 Other indices untouched
            orderData['amounts'] = amounts;
          }

          debugPrint('[10] itemIndex=$itemIndex, configIndex=$configIndex');

          final List<double> updatedQuantities = (data['quantities'] as List)
              .map((e) {
                final v = (e as num).toDouble();
                debugPrint('[11] quantity value => $v');
                return v;
              })
              .toList();

          final String varianceName = orderData['varianceNames'][itemIndex];
          final double remainingQty = updatedQuantities[itemIndex];

          debugPrint('[12] varianceName=$varianceName');
          debugPrint('[13] remainingQty=$remainingQty');

          // ===== LOAD CONFIGS =====
          debugPrint('[14] Loading configs');
          final List<Map<String, dynamic>> configs =
              (orderData['config'] as List? ?? [])
                  .map((c) => normalizeMap(c))
                  .toList();

          for (int c = 0; c < configs.length; c++) {
            debugPrint('[15] Config BEFORE [$c] => ${configs[c]}');
          }

          // ===== EXACT CONFIG CANCELLATION =====
          if (configIndex != null &&
              configIndex >= 0 &&
              configIndex < configs.length) {
            final config = configs[configIndex];

            if (config['configQty'] is List) {
              final List<int> configQty = List<int>.from(config['configQty']);

              double cancelQty = (data['cancelQty'] as num).toDouble();

              debugPrint('🧮 Original configQty => $configQty');
              debugPrint('🧮 CancelQty => $cancelQty');

              for (int i = configQty.length - 1; i >= 0 && cancelQty > 0; i--) {
                if (configQty[i] > 0) {
                  configQty[i] -= 1;
                  cancelQty -= 1;
                }
              }

              config['configQty'] = configQty;

              debugPrint('🧮 Updated configQty => $configQty');
            }
          } else {
            debugPrint('[18] No config patch applied');
          }

          orderData['config'] = configs;

          for (int c = 0; c < configs.length; c++) {
            debugPrint('[19] Config AFTER [$c] => ${configs[c]}');
          }

          final bool allCancelled = (data['quantities'] as List).every((q) {
            final val = (q as num).toDouble() == 0.0;
            debugPrint('[20] allCancelled check => $q => $val');
            return val;
          });

          debugPrint('[21] allCancelled=$allCancelled');

          if (allCancelled) {
            orderData['status'] = 'cancelled';
            debugPrint('[22] Order marked CANCELLED');
          }

          debugPrint('[23] Writing updated order to Hive');
          await orderBox.put(i, orderData);

          updatedOrder = Map<String, dynamic>.from(orderData);
          debugPrint('[24] Hive update success');

          break;
        }
      }

      // ================= PRINT PAYLOAD =================
      debugPrint('[25] Preparing print payload');

      final int itemIndex = data['itemIndex'];
      final int? configIndex = data['configIndex'];

      debugPrint('[26] Print itemIndex=$itemIndex, configIndex=$configIndex');

      final List<Map<String, dynamic>> previousConfigs =
          (previousOrder?['config'] as List? ?? [])
              .map((c) => normalizeMap(c))
              .toList();

      final List<Map<String, dynamic>> itemConfigs =
          (configIndex != null &&
              configIndex >= 0 &&
              configIndex < previousConfigs.length)
          ? [previousConfigs[configIndex]]
          : [];

      debugPrint('[27] itemConfigs => $itemConfigs');

      final Map<String, dynamic> filteredOrder = {
        ...updatedOrder!,
        'quantities': [updatedOrder['quantities'][itemIndex]],
        'cancelledQty': [updatedOrder['cancelledQty'][itemIndex]],
        'prices': [updatedOrder['prices'][itemIndex]],
        'weights': [updatedOrder['weights'][itemIndex]],
        'varianceNames': [updatedOrder['varianceNames'][itemIndex]],
        'config': itemConfigs,
        'itemRemark': [data['itemRemark']],
      };

      debugPrint('[28] Final print payload => $filteredOrder');

      // ================= PRINT =================
      debugPrint('[29] Sending data to printer');

      await CancelPrinterService.printUniversalReceipt(
        ipAddress: data['ipAddress'],
        tableNumber: updatedOrder['table'] ?? '',
        seat: updatedOrder['seat'] ?? '',
        userName: updatedOrder['userName'] ?? '',
        waiter: updatedOrder['waiter'] ?? '',
        seatOrders: [filteredOrder],
        receiptType: 'ITEM CANCELLED',
      );

      debugPrint('[30] ✅ Printing completed');

      // ================= CLIENT SYNC =================
      debugPrint('[31] Syncing clients');

      sendDataToClients({
        'action': 'orderCancelled',
        'hiveOrderId': data['hiveOrderId'],
        'cancelledQty': data['cancelledQty'],
        'totalAmount': data['totalAmount'],
        'quantities': data['quantities'],
        'itemRemark': data['itemRemark'],
        'partiallycancelled': data['partiallycancelled'],
        'config': (updatedOrder['config'] as List? ?? [])
            .map((c) => normalizeMap(c))
            .toList(),
        'status': updatedOrder['status'],
        'fieldsEdited': 'true',
        'sync': "Yes",
        'edit': "Yes",
      }, clients);

      debugPrint('[32] Clients notified');

      await SyncServiceKot().patchEditedOrders();
      debugPrint('[33] SyncServiceKot completed');

      debugPrint('[34] ✅ EXIT patchCancelOrderItem SUCCESS');
    } catch (e, s) {
      debugPrint('[99] ❌ ERROR patchCancelOrderItem => $e');
      debugPrint('[99] StackTrace => $s');
    }
  }
}

// class CancelOrderPatchHandler {
//   // static Future<void> patchCancelOrderItem(
//   //   Map<String, dynamic> data,
//   //   // Set<WebSocketChannel> clients
//   // ) async {
//   //   try {
//   //     var orderBox = await Hive.box('ordersBox');

//   //     for (int i = 0; i < orderBox.length; i++) {
//   //       var orderData = orderBox.getAt(i);
//   //       if (orderData is Map &&
//   //           orderData['hiveOrderId'] == data['hiveOrderId']) {
//   //         // Patch the updated fields
//   //         orderData['cancelledQty'] = data['cancelledQty'];
//   //         orderData['totalAmount'] = data['totalAmount'];
//   //         orderData['quantities'] = data['quantities'];
//   //         orderData['itemRemark'] = data['itemRemark'];
//   //         orderData['partiallycancelled'] = data['partiallycancelled'];

//   //         // ✅ Check if all quantities are 0 -> mark status as 'cancelled'
//   //         final allCancelled = (data['quantities'] as List).every(
//   //           (q) => (q as num).toDouble() == 0.0,
//   //         );

//   //         if (allCancelled) {
//   //           orderData['status'] = 'cancelled';
//   //           print(
//   //             "✅ All items cancelled. Updated status in Hive for ${data['hiveOrderId']}.",
//   //           );
//   //         }

//   //         // ✅ Save patched data to Hive
//   //         await orderBox.putAt(i, orderData);
//   //         print("✅ Hive updated for order: ${data['hiveOrderId']}");
//   //         break;
//   //       }
//   //     }
//   //     try {
//   //       final List<dynamic> varianceCodesRaw = data['varianceitemCodes'] is List
//   //           ? List.from(data['varianceitemCodes'])
//   //           : [data['varianceitemCodes']];

//   //       final List<dynamic> varianceNamesRaw = data['varianceNames'] is List
//   //           ? List.from(data['varianceNames'])
//   //           : [data['varianceNames']];

//   //       final List<dynamic> qtyRaw = data['cancelledQty'] is List
//   //           ? List.from(data['cancelledQty'])
//   //           : [data['cancelledQty']];

//   //       final List<dynamic> weightRaw = data['weights'] is List
//   //           ? List.from(data['weights'])
//   //           : [data['weights'] ?? 0.0];

//   //       final List<dynamic> uomRaw = data['uoms'] is List
//   //           ? List.from(data['uoms'])
//   //           : [data['uoms'] ?? 'Pcs'];

//   //       final int maxItems = [
//   //         varianceCodesRaw.length,
//   //         varianceNamesRaw.length,
//   //         qtyRaw.length,
//   //         weightRaw.length,
//   //         uomRaw.length,
//   //       ].reduce((a, b) => a > b ? a : b);

//   //       List<String> varianceCodes = [];
//   //       List<String> varianceNames = [];
//   //       List<double> deductionAmounts = [];
//   //       List<String> uomsList = [];
//   //       for (int i = 0; i < maxItems; i++) {
//   //         final code = (i < varianceCodesRaw.length)
//   //             ? varianceCodesRaw[i]?.toString().trim()
//   //             : null;
//   //         final name = (i < varianceNamesRaw.length)
//   //             ? varianceNamesRaw[i]?.toString().trim()
//   //             : null;
//   //         final qtyVal = (i < qtyRaw.length) ? qtyRaw[i] : 1.0;
//   //         final weightVal = (i < weightRaw.length) ? weightRaw[i] : 0.0;
//   //         final uomVal = (i < uomRaw.length)
//   //             ? uomRaw[i]?.toString() ?? 'Pcs'
//   //             : 'Pcs';

//   //         if (code == null || code.isEmpty || name == null || name.isEmpty) {
//   //           print("Skipping invalid item at index $i");
//   //           continue;
//   //         }

//   //         double qty = 0.0;
//   //         if (qtyVal is num)
//   //           qty = qtyVal.toDouble();
//   //         else if (qtyVal is String)
//   //           qty = double.tryParse(qtyVal) ?? 0.0;

//   //         double weight = 0.0;
//   //         if (weightVal is num)
//   //           weight = weightVal.toDouble();
//   //         else if (weightVal is String)
//   //           weight = double.tryParse(weightVal) ?? 0.0;

//   //         final deduction = getStockDeductionAmount(
//   //           uom: uomVal,
//   //           weight: weight,
//   //           qty: qty,
//   //         );

//   //         if (deduction <= 0) {
//   //           print("Zero deduction for $name → skipped");
//   //           continue;
//   //         }

//   //         varianceCodes.add(code);
//   //         varianceNames.add(name);
//   //         deductionAmounts.add(deduction);
//   //         uomsList.add(uomVal);

//   //         print(
//   //           "Will decrease: $name ($code) by $deduction $uomVal ${weight > 0 ? '(weight: $weight kg)' : '(qty: $qty)'}",
//   //         );
//   //       }
//   //       await increaseLocalHiveStock(
//   //         clients: clients,
//   //         branchAlias: aliasname,
//   //         varianceCodes: varianceCodes,
//   //         varianceNames: varianceNames,
//   //         stockIncreaseAmounts: deductionAmounts,
//   //         uoms: uomsList,
//   //       );

//   //       debugPrint("stock increase succesfully during itemwise cancelled!!");
//   //     } catch (e) {
//   //       debugPrint("error while stock increase during itemwise cancelled $e");
//   //     }

//   //     // ✅ Notify clients with updated data
//   //     sendDataToClients({
//   //       'action': 'orderCancelled',
//   //       'hiveOrderId': data['hiveOrderId'],
//   //       'cancelledQty': data['cancelledQty'],
//   //       'totalAmount': data['totalAmount'],
//   //       'quantities': data['quantities'],
//   //       'itemRemark': data['itemRemark'],
//   //       'partiallycancelled': data['partiallycancelled'],
//   //       'status': data['status'], // ✅ include this
//   //     }, clients);
//   //   } catch (e) {
//   //     print("❌ Failed to patch order cancellation: $e");
//   //   }
//   // }

//   static Future<void> patchCancelOrderItem(
//     Map<String, dynamic> data,
//     // Set<WebSocketChannel> clients  // Uncomment if needed
//   ) async {
//     try {
//       var orderBox = await Hive.box('ordersBox');

//       // Update the order in Hive
//       for (int i = 0; i < orderBox.length; i++) {
//         var orderData = orderBox.getAt(i);
//         if (orderData is Map &&
//             orderData['hiveOrderId'] == data['hiveOrderId']) {
//           // Patch the updated fields
//           orderData['cancelledQty'] = data['cancelledQty'];
//           orderData['totalAmount'] = data['totalAmount'];
//           orderData['quantities'] = data['quantities'];
//           orderData['itemRemark'] = data['itemRemark'];
//           orderData['partiallycancelled'] = data['partiallycancelled'];

//           // Check if all items are fully cancelled → mark order as 'cancelled'
//           final allCancelled = (data['quantities'] as List).every(
//             (q) => (q as num).toDouble() == 0.0,
//           );

//           if (allCancelled) {
//             orderData['status'] = 'cancelled';
//             print(
//               "✅ All items cancelled. Updated status in Hive for ${data['hiveOrderId']}.",
//             );
//           }

//           // Save updated order back to Hive
//           await orderBox.putAt(i, orderData);
//           print("✅ Hive updated for order: ${data['hiveOrderId']}");
//           break;
//         }
//       }

//       // === STOCK INCREASE: Only for the item at 'itemIndex' ===
//       try {
//         final int itemIndex = data['itemIndex'] as int;

//         // Helper to safely get value at index, or return null/default
//         T? safeGet<T>(List<dynamic>? list, int index, [T? defaultValue]) {
//           if (list == null || index < 0 || index >= list.length) {
//             return defaultValue;
//           }
//           return list[index] as T?;
//         }

//         // Extract lists safely
//         final List<dynamic> varianceCodesList =
//             data['varianceitemCodes'] is List
//             ? List.from(data['varianceitemCodes'])
//             : [data['varianceitemCodes']];

//         final List<dynamic> varianceNamesList = data['varianceNames'] is List
//             ? List.from(data['varianceNames'])
//             : [data['varianceNames']];

//         final List<dynamic> cancelledQtyList = data['cancelledQty'] is List
//             ? List.from(data['cancelledQty'])
//             : [data['cancelledQty']];

//         final List<dynamic> weightsList = data['weights'] is List
//             ? List.from(data['weights'])
//             : (data['weights'] != null ? [data['weights']] : []);

//         final List<dynamic> uomsList = data['uoms'] is List
//             ? List.from(data['uoms'])
//             : (data['uoms'] != null ? [data['uoms']] : ['Pcs']);

//         // Find the maximum safe length (usually varianceCodesList is the reference)
//         final int maxLength = varianceCodesList.length;

//         if (itemIndex < 0 || itemIndex >= maxLength) {
//           debugPrint(
//             "⚠️ Invalid itemIndex: $itemIndex (valid range: 0–${maxLength - 1})",
//           );
//           // Skip stock increase safely
//         } else {
//           final String? code = safeGet<String>(
//             varianceCodesList,
//             itemIndex,
//           )?.trim();
//           final String? name = safeGet<String>(
//             varianceNamesList,
//             itemIndex,
//           )?.trim();
//           final dynamic cancelledQtyVal = safeGet(
//             cancelledQtyList,
//             itemIndex,
//             0.0,
//           );
//           final dynamic weightVal = safeGet(weightsList, itemIndex, 0.0);
//           final String uom =
//               safeGet<String>(uomsList, itemIndex, 'Pcs')?.trim() ?? 'Pcs';

//           if (code == null || code.isEmpty || name == null || name.isEmpty) {
//             debugPrint(
//               "Skipping stock increase: missing code/name at index $itemIndex",
//             );
//           } else {
//             // Parse cancelled quantity
//             double cancelledQty = 0.0;
//             if (cancelledQtyVal is num) {
//               cancelledQty = cancelledQtyVal.toDouble();
//             } else if (cancelledQtyVal is String) {
//               cancelledQty = double.tryParse(cancelledQtyVal) ?? 0.0;
//             }

//             if (cancelledQty <= 0) {
//               debugPrint(
//                 "No cancelled quantity at index $itemIndex → skip stock increase",
//               );
//             } else {
//               // Parse weight safely
//               double weight = 0.0;
//               if (weightVal is num) {
//                 weight = weightVal.toDouble();
//               } else if (weightVal is String) {
//                 weight = double.tryParse(weightVal) ?? 0.0;
//               }

//               final double deduction = getStockDeductionAmount(
//                 uom: uom,
//                 weight: weight,
//                 qty: cancelledQty,
//               );

//               if (deduction > 0) {
//                 await increaseLocalHiveStock(
//                   clients: clients,
//                   branchAlias: aliasname,
//                   varianceCodes: [code],
//                   varianceNames: [name],
//                   stockIncreaseAmounts: [deduction],
//                   uoms: [uom],
//                 );

//                 debugPrint(
//                   "✅ Stock increased: +$deduction $uom → $name ($code) [cancelled qty: $cancelledQty]",
//                 );
//               } else {
//                 debugPrint("Zero deduction for $name → no stock increase");
//               }
//             }
//           }
//         }

//         debugPrint(
//           "Stock increase processing completed for itemIndex: $itemIndex",
//         );
//       } catch (e, stack) {
//         debugPrint("❌ Error during safe stock increase: $e");
//         debugPrint("Stack: $stack");
//       }

//       // === Notify all clients with full updated data (unchanged) ===
//       sendDataToClients({
//         'action': 'orderCancelled',
//         'hiveOrderId': data['hiveOrderId'],
//         'cancelledQty': data['cancelledQty'],
//         'totalAmount': data['totalAmount'],
//         'quantities': data['quantities'],
//         'itemRemark': data['itemRemark'],
//         'partiallycancelled': data['partiallycancelled'],
//         'status': data.containsKey('status') ? data['status'] : null,
//       }, clients);
//     } catch (e) {
//       print("❌ Failed to patch order cancellation: $e");
//     }
//   }
// }

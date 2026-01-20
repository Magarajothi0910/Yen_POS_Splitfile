import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart';
import 'package:yenpos/kotpreinvoice/services/CancellationReceipt.dart';

import '../services/sendDataToClients.dart';

class CancelOrderPatchHandler {
  static Map<String, dynamic> normalizeMap(dynamic raw) {
    return Map<String, dynamic>.from(
      (raw as Map).map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  static Future<void> patchCancelOrderItem(Map<String, dynamic> data) async {
    Map<String, dynamic>? updatedOrder;
    Map<String, dynamic>? previousOrder;

    try {
      // var orderBox = HiveManager.instance.ordersBox;
      final orderBox = Hive.isBoxOpen('ordersBox')
          ? Hive.box('ordersBox')
          : await Hive.openBox('ordersBox');

      // Update the order in Hive
      for (int i = 0; i < orderBox.length; i++) {
        var orderData = orderBox.getAt(i);
        if (orderData is Map &&
            orderData['hiveOrderId'] == data['hiveOrderId']) {
          previousOrder = Map<String, dynamic>.from(orderData);

          // Patch the updated fields
          orderData['cancelledQty'] = data['cancelledQty'];
          orderData['totalAmount'] = data['totalAmount'];
          orderData['quantities'] = data['quantities'];
          orderData['itemRemark'] = data['itemRemark'];
          orderData['partiallycancelled'] = data['partiallycancelled'];

          // Check if all items are fully cancelled → mark order as 'cancelled'
          final allCancelled = (data['quantities'] as List).every(
            (q) => (q as num).toDouble() == 0.0,
          );

          final int itemIndex = data['itemIndex'] as int;
          final List<double> updatedQuantities = (data['quantities'] as List)
              .map((e) => (e as num).toDouble())
              .toList();

          final String varianceName = orderData['varianceNames'][itemIndex];
          final double remainingQty = updatedQuantities[itemIndex];

          // Ensure config list exists
          final List<Map<String, dynamic>> configs =
              (orderData['config'] as List? ?? [])
                  .map((c) => normalizeMap(c))
                  .toList();

          // Filter configs for this variance
          final List<Map<String, dynamic>> varianceConfigs = configs
              .where((c) => c['varianceName'] == varianceName)
              .toList();

          if (remainingQty <= 0) {
            configs.removeWhere((c) => c['varianceName'] == varianceName);
          } else {
            // 🔄 Partially cancelled → adjust config quantities
            double totalConfigQty = varianceConfigs.fold(
              0.0,
              (sum, c) => sum + ((c['configQty'] as num?)?.toDouble() ?? 0.0),
            );

            double excessQty = totalConfigQty - remainingQty;

            if (excessQty > 0) {
              // Reduce config quantities safely (last-added-first-removed)
              for (final cfg in varianceConfigs.reversed) {
                double cfgQty = (cfg['configQty'] as num).toDouble();

                if (excessQty <= 0) break;

                if (cfgQty <= excessQty) {
                  excessQty -= cfgQty;
                  cfg['configQty'] = 0.0;
                } else {
                  cfg['configQty'] = cfgQty - excessQty;
                  excessQty = 0;
                }
              }
            }
          }

          // Save back
          orderData['config'] = configs;

          if (allCancelled) {
            orderData['status'] = 'cancelled';
            print(
              "✅ All items cancelled. Updated status in Hive for ${data['hiveOrderId']}.",
            );
          }

          // Save updated order back to Hive
          await orderBox.putAt(i, orderData);
          print("Updated Data: $orderData");
          updatedOrder = Map<String, dynamic>.from(orderData);

          print("✅ Hive updated for order: ${data['hiveOrderId']}");
          break;
        }
      }

      final int itemIndex = data['itemIndex'] as int;

      final List<dynamic> varianceNames = updatedOrder!['varianceNames'] ?? [];
      final List<dynamic> prices = updatedOrder['prices'] ?? [];
      final List<dynamic> weights = updatedOrder['weights'] ?? [];
      final List<dynamic> quantities = updatedOrder['quantities'] ?? [];
      final List<dynamic> cancelledQty = updatedOrder['cancelledQty'] ?? [];

      final String varianceName = varianceNames[itemIndex];

      // ✅ capture configs for THIS item only
      final List<Map<String, dynamic>> itemConfigs =
          (previousOrder?['config'] as List? ?? [])
              .map((c) => normalizeMap(c))
              .where((c) => c['varianceName'] == varianceName)
              .toList();

      // ✅ build filteredOrder for printing
      final Map<String, dynamic> filteredOrder = {
        ...updatedOrder,
        'quantities': [quantities[itemIndex]],
        'cancelledQty': [cancelledQty[itemIndex]],
        'amounts': [
          (prices[itemIndex] as num).toDouble() *
              (cancelledQty[itemIndex] as num).toDouble(),
        ],
        'prices': [prices[itemIndex]],
        'weights': [weights[itemIndex]],
        'varianceNames': [varianceName],
        'config': itemConfigs,
        'itemRemark': [
          (updatedOrder['itemRemark'] is List &&
                  updatedOrder['itemRemark'].length > itemIndex)
              ? updatedOrder['itemRemark'][itemIndex]
              : '',
        ],
      };

      try {
        await CancelPrinterService.printUniversalReceipt(
          ipAddress: data['ipAddress'],
          tableNumber: updatedOrder['table'] ?? '',
          seat: updatedOrder['seat'] ?? '',
          userName: updatedOrder['userName'] ?? '',
          waiter: updatedOrder['waiter'] ?? '',
          seatOrders: [filteredOrder], // ✅ FIXED
          receiptType: 'ITEM CANCELLED',
        );
        print("✅ Cancellation receipt printed successfully");
      } catch (printError) {
        print("❌ Printer error: $printError");
      }

      // === STOCK INCREASE: Only for the item at 'itemIndex' ===
      try {
        final int itemIndex = data['itemIndex'] as int;

        // Helper to safely get value at index, or return null/default
        T? safeGet<T>(List<dynamic>? list, int index, [T? defaultValue]) {
          if (list == null || index < 0 || index >= list.length) {
            return defaultValue;
          }
          return list[index] as T?;
        }

        // Extract lists safely
        final List<dynamic> varianceCodesList =
            data['varianceitemCodes'] is List
            ? List.from(data['varianceitemCodes'])
            : [data['varianceitemCodes']];

        final List<dynamic> varianceNamesList = data['varianceNames'] is List
            ? List.from(data['varianceNames'])
            : [data['varianceNames']];

        final List<dynamic> cancelledQtyList = data['cancelledQty'] is List
            ? List.from(data['cancelledQty'])
            : [data['cancelledQty']];

        final List<dynamic> weightsList = data['weights'] is List
            ? List.from(data['weights'])
            : (data['weights'] != null ? [data['weights']] : []);

        final List<dynamic> uomsList = data['uoms'] is List
            ? List.from(data['uoms'])
            : (data['uoms'] != null ? [data['uoms']] : ['Pcs']);

        // Find the maximum safe length (usually varianceCodesList is the reference)
        final int maxLength = varianceCodesList.length;

        if (itemIndex < 0 || itemIndex >= maxLength) {
          debugPrint(
            "⚠️ Invalid itemIndex: $itemIndex (valid range: 0–${maxLength - 1})",
          );
          // Skip stock increase safely
        } else {
          final String? code = safeGet<String>(
            varianceCodesList,
            itemIndex,
          )?.trim();
          final String? name = safeGet<String>(
            varianceNamesList,
            itemIndex,
          )?.trim();
          final dynamic cancelledQtyVal = safeGet(
            cancelledQtyList,
            itemIndex,
            0.0,
          );
          final dynamic weightVal = safeGet(weightsList, itemIndex, 0.0);
          final String uom =
              safeGet<String>(uomsList, itemIndex, 'Pcs')?.trim() ?? 'Pcs';

          if (code == null || code.isEmpty || name == null || name.isEmpty) {
            debugPrint(
              "Skipping stock increase: missing code/name at index $itemIndex",
            );
          } else {
            // Parse cancelled quantity
            double cancelledQty = 0.0;
            if (cancelledQtyVal is num) {
              cancelledQty = cancelledQtyVal.toDouble();
            } else if (cancelledQtyVal is String) {
              cancelledQty = double.tryParse(cancelledQtyVal) ?? 0.0;
            }

            if (cancelledQty <= 0) {
              debugPrint(
                "No cancelled quantity at index $itemIndex → skip stock increase",
              );
            } else {
              // Parse weight safely
              double weight = 0.0;
              if (weightVal is num) {
                weight = weightVal.toDouble();
              } else if (weightVal is String) {
                weight = double.tryParse(weightVal) ?? 0.0;
              }

              final double deduction = getStockDeductionAmount(
                uom: uom,
                weight: weight,
                qty: cancelledQty,
              );

              if (deduction > 0) {
                await increaseLocalHiveStock(
                  clients: clients,
                  branchAlias: aliasname,
                  varianceCodes: [code],
                  varianceNames: [name],
                  stockIncreaseAmounts: [deduction],
                  uoms: [uom],
                );

                debugPrint(
                  "✅ Stock increased: +$deduction $uom → $name ($code) [cancelled qty: $cancelledQty]",
                );
              } else {
                debugPrint("Zero deduction for $name → no stock increase");
              }
            }
          }
        }

        debugPrint(
          "Stock increase processing completed for itemIndex: $itemIndex",
        );
      } catch (e, stack) {
        debugPrint("❌ Error during safe stock increase: $e");
        debugPrint("Stack: $stack");
      }

      // === Notify all clients with full updated data (unchanged) ===
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
        'status': data.containsKey('status') ? data['status'] : null,
      } , clients);
    } catch (e) {
      print("❌ Failed to patch order cancellation: $e");
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

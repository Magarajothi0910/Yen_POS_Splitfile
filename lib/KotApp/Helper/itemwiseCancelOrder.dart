// import 'dart:convert';
// import 'package:hive/hive.dart';
// import '../models/hive boxes.dart';

// /// A helper class for processing item‐wise cancellation updates on the client side.
// /// This class encapsulates the logic needed to update the local Hive storage for orders
// /// when a specific order item is cancelled.
// class ItemWiseCancelHiveUpdater {
//   /// Updates the Hive orders for all matching orders using the given [patchData].
//   ///
//   /// [hiveKey] is the key under which your orders are stored (for example, 'data').
//   /// [patchData] must contain at least:
//   /// - 'seathiveOrderId': the common identifier for the seat.
//   /// - 'hiveOrderId': the unique identifier for the specific order.
//   /// - 'itemIndex': the index (integer) of the item that is cancelled.
//   /// - 'cancelledQty': the quantity that is cancelled.
//   /// - 'remark': the cancellation remark.
//   ///
//   /// This method iterates through all orders stored under [hiveKey] in the ordersBox and
//   /// updates only the target item within each matching order:
//   ///   - Sets the quantity for the item at [itemIndex] to zero.
//   ///   - Updates the 'cancelledQty' for that index.
//   ///   - Updates the 'orderRemark' field.
//   ///   - Sets 'partiallyCancelled' to "yes" if not all items are cancelled.
//   ///   - Updates common flags.
//   ///
//   /// Finally, it writes the updated list back to Hive.
//   static Future<void> updateItemWiseOrderInHive({
//     required Map<String, dynamic> patchData,
//     required String hiveKey,
//   }) async {
//     try {
//       // Retrieve the Hive orders box via HiveManager.
//       final orderBox = HiveManager().ordersBox;
//       if (orderBox == null) {
//         print("ordersBox is null.");
//         return;
//       }

//       // Get the data; if null, initialize it as an empty list.
//       dynamic ordersData = orderBox.get(hiveKey);
//       if (ordersData == null) {
//         print(
//             "No data found in Hive for key '$hiveKey'. Initializing as empty list.");
//         ordersData = [];
//         await orderBox.put(hiveKey, ordersData);
//       }
//       if (ordersData is! List) {
//         print(
//             "Data under Hive key '$hiveKey' is not a List. Initializing as empty list.");
//         ordersData = [];
//         await orderBox.put(hiveKey, ordersData);
//       }

//       print("Orders retrieved from Hive: ${jsonEncode(ordersData)}");

//       final String patchSeathiveId =
//           patchData['seathiveOrderId']?.toString() ?? '';
//       final String patchHiveOrderId =
//           patchData['hiveOrderId']?.toString() ?? '';
//       final int itemIndex = patchData['itemIndex'];
//       final dynamic cancelledQtyVal = patchData['cancelledQty'];
//       double cancelledQty = 0.0;
//       if (cancelledQtyVal is num) {
//         cancelledQty = cancelledQtyVal.toDouble();
//       } else {
//         print("cancelledQty is not a number; received: $cancelledQtyVal");
//       }
//       final String remark = patchData['remark']?.toString() ?? '';

//       bool orderFound = false;
//       // Loop through all orders in the Hive data.
//       for (var order in ordersData) {
//         if (order is Map<String, dynamic>) {
//           if (order['seathiveOrderId'] == patchSeathiveId &&
//               order['hiveOrderId'] == patchHiveOrderId) {
//             orderFound = true;

//             // Check that 'quantities' is a List.
//             if (order['quantities'] is List) {
//               List<dynamic> quantities = order['quantities'];
//               if (itemIndex < quantities.length) {
//                 quantities[itemIndex] = 0.0;
//               } else {
//                 print(
//                     "itemIndex $itemIndex out of bounds for 'quantities': $quantities");
//                 continue;
//               }
//             } else {
//               print("Order 'quantities' is not a list for order: ${order}");
//               continue;
//             }

//             // Initialize or update 'cancelledQty'
//             if (order['cancelledQty'] == null ||
//                 order['cancelledQty'] is! List ||
//                 (order['cancelledQty'] as List).length !=
//                     (order['quantities'] as List).length) {
//               order['cancelledQty'] =
//                   List.filled((order['quantities'] as List).length, 0.0);
//             }
//             (order['cancelledQty'] as List)[itemIndex] = cancelledQty;

//             // Check if all items are cancelled.
//             bool allItemsCancelled =
//                 (order['quantities'] as List).every((qty) => qty == 0.0);
//             if (allItemsCancelled) {
//               // Optionally, update order-level status here (if needed).
//               // order['status'] = 'cancelled';
//               print("All items in this order are cancelled.");
//             } else {
//               order['partiallyCancelled'] = "yes";
//             }

//             // Update common fields.
//             order['orderRemark'] = remark;
//             order['edit'] = patchData['edit'] ?? "Yes";
//             order['statusEdited'] = patchData['statusEdited'] ?? "true";

//             print("Updated order: ${jsonEncode(order)}");
//           }
//         }
//       }
//       if (!orderFound) {
//         print(
//             "No matching order found for seathiveOrderId: $patchSeathiveId, hiveOrderId: $patchHiveOrderId");
//       } else {
//         // Write the updated orders list back to Hive.
//         await orderBox.put(hiveKey, ordersData);
//         print(
//             "Updated Hive orders for key '$hiveKey': ${jsonEncode(ordersData)}");
//       }
//     } catch (e) {
//       print("Error updating Hive orders in ItemWiseCancelHiveUpdater: $e");
//     }
//   }
// }

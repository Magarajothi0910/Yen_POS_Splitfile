// // server/order_patch_item_handler.dart

// import 'dart:convert';
// import 'package:hive/hive.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import '../models/hive boxes.dart';
// import '../services/sendDataToClients.dart';

// /// A handler class for processing cancellation patch requests for a specific order item.
// /// This class encapsulates the logic needed to update the server's Hive storage for the
// /// canceled item and broadcast the update to all connected clients.
// class OrderPatchItemHandler {
//   /// Processes a cancellation patch for a specific order item.
//   ///
//   /// [patchData] must contain:
//   /// - 'seathiveOrderId': The common identifier for the seat orders.
//   /// - 'hiveOrderId': The unique identifier for the specific order.
//   /// - 'itemIndex': The index of the item to cancel.
//   /// - 'cancelledQty': The quantity to cancel.
//   /// - 'remark': The cancellation remark.
//   ///
//   /// This method updates the corresponding order in Hive (under the 'data' key) by:
//   /// - Setting the quantity for the item at [itemIndex] to zero.
//   /// - Updating the 'cancelledQty' field.
//   /// - Marking the order as partially cancelled.
//   ///
//   /// Finally, it broadcasts the update to all connected clients.
//   static Future<void> handleCancelOrderItemPatch(
//     Map<String, dynamic> patchData,
//     Set<WebSocketChannel> clients,
//   ) async {
//     print("handleCancelOrderItemPatch33...");
//     final String seathiveOrderId =
//         patchData['seathiveOrderId']?.toString() ?? '';
//     final String hiveOrderId = patchData['hiveOrderId']?.toString() ?? '';
//     final int itemIndex = patchData['itemIndex'];
//     final double cancelledQty = patchData['cancelledQty'] is num
//         ? (patchData['cancelledQty'] as num).toDouble()
//         : 0.0;
//     final String remark = patchData['remark']?.toString() ?? '';

//     // --- Update the Hive orders ---
//     // Open the orders box (ensure 'ordersBox' is your server's Hive box name)
//     final orderBox = HiveManager().ordersBox;

//     final dynamic ordersData = orderBox.get('data');
//     if (ordersData != null && ordersData is List) {
//       for (var order in ordersData) {
//         if (order is Map<String, dynamic> &&
//             order['seathiveOrderId'] == seathiveOrderId &&
//             order['hiveOrderId'] == hiveOrderId) {
//           // Set the quantity at the specified item index to zero.
//           order['quantities'][itemIndex] = 0.0;
//           // Initialize cancelledQty if needed.
//           if (order['cancelledQty'] == null ||
//               order['cancelledQty'].length != order['quantities'].length) {
//             order['cancelledQty'] =
//                 List.filled(order['quantities'].length, 0.0);
//           }
//           // Update the cancelledQty for this item.
//           order['cancelledQty'][itemIndex] = cancelledQty;
//           // Mark the order as partially cancelled and update remark and flags.
//           order['partiallyCancelled'] = "true";
//           order['orderRemark'] = remark;
//           order['edit'] = "Yes";
//           order['statusEdited'] = "true";
//         }
//       }
//       await orderBox.put('data', ordersData);
//     }

//     // --- Broadcast the update to all connected clients ---
//     final Map<String, dynamic> broadcastData = {
//       'action': 'updateOrderItemCancellation',
//       'seathiveOrderId': seathiveOrderId,
//       'hiveOrderId': hiveOrderId,
//       'itemIndex': itemIndex,
//       'cancelledQty': cancelledQty,
//       'remark': remark,
//       //'status': 'cancelled',
//       'partiallyCancelled': "true",
//       'edit': "Yes",
//       'statusEdited': "true",
//     };
//     sendDataToClients(broadcastData, clients);
//     print("Broadcasted cancellation update: ${jsonEncode(broadcastData)}");
//   }
// }

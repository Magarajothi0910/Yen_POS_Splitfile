// // In server/order_patch_handler.dart (server side)
// static Future<void> handleCancelOrderItemPatch(
//   Map<String, dynamic> patchData,
//   Set<WebSocketChannel> clients,
// ) async {
//   final String seathiveOrderId = patchData['seathiveOrderId']?.toString() ?? '';
//   final String hiveOrderId = patchData['hiveOrderId']?.toString() ?? '';
//   final int itemIndex = patchData['itemIndex'];
//   final double cancelledQty = patchData['cancelledQty'] is num
//       ? (patchData['cancelledQty'] as num).toDouble()
//       : 0.0;
//   final String remark = patchData['remark']?.toString() ?? '';

//   // Update the Hive orders (similar to the client implementation)
//   final orderBox = await Hive.openBox('ordersBox');
//   final dynamic ordersData = orderBox.get('data');
//   if (ordersData != null && ordersData is List) {
//     for (var order in ordersData) {
//       if (order is Map<String, dynamic> &&
//           order['seathiveOrderId'] == seathiveOrderId &&
//           order['hiveOrderId'] == hiveOrderId) {
//         order['quantities'][itemIndex] = 0.0;
//         if (order['cancelledQty'] == null ||
//             order['cancelledQty'].length != order['quantities'].length) {
//           order['cancelledQty'] =
//               List.filled(order['quantities'].length, 0.0);
//         }
//         order['cancelledQty'][itemIndex] = cancelledQty;
//         order['partiallyCancelled'] = "true";
//         order['orderRemark'] = remark;
//         order['edit'] = "Yes";
//         order['statusEdited'] = "true";
//       }
//     }
//     await orderBox.put('data', ordersData);
//   }
//   // Broadcast the update to all clients.
//   final broadcastData = {
//     'action': 'updateOrderItemCancellation',
//     'seathiveOrderId': seathiveOrderId,
//     'hiveOrderId': hiveOrderId,
//     'itemIndex': itemIndex,
//     'cancelledQty': cancelledQty,
//     'remark': remark,
//     'status': 'cancelled',
//     'partiallyCancelled': "true",
//     'edit': "Yes",
//     'statusEdited': "true",
//   };
//   sendDataToClients(broadcastData, clients);
//   print("Broadcasted cancellation update: ${jsonEncode(broadcastData)}");
// }

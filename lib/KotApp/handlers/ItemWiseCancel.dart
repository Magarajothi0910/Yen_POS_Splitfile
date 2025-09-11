// lib/handlers/cancel_order_patch_handler.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../kotservices/sendDataToClients.dart';

class CancelOrderPatchHandler {
  /// Patches the order cancellation data to the Hive storage on the server
  /// and broadcasts the updated order to all connected clients.
  ///
  /// - [data]: The cancellation patch data received from a client (or elsewhere).
  ///   Expected keys: 'hiveOrderId', 'cancelledQty', 'totalAmount', 'quantities', 'itemRemark', 'partiallycancelled'.
  /// - [clients]: The set of connected WebSocketChannel clients to broadcast to.
  static Future<void> patchCancelOrderItem(
      Map<String, dynamic> data, Set<WebSocketChannel> clients) async {
    try {
      var orderBox = await Hive.openBox('ordersBox');

      for (int i = 0; i < orderBox.length; i++) {
        var orderData = orderBox.getAt(i);
        if (orderData is Map &&
            orderData['hiveOrderId'] == data['hiveOrderId']) {
          // Patch the updated fields
          orderData['cancelledQty'] = data['cancelledQty'];
          orderData['totalAmount'] = data['totalAmount'];
          orderData['quantities'] = data['quantities'];
          orderData['itemRemark'] = data['itemRemark'];
          orderData['partiallycancelled'] = data['partiallycancelled'];

          // ✅ Check if all quantities are 0 -> mark status as 'cancelled'
          final allCancelled = (data['quantities'] as List)
              .every((q) => (q as num).toDouble() == 0.0);

          if (allCancelled) {
            orderData['status'] = 'cancelled';
          }

          // ✅ Save patched data to Hive
          await orderBox.putAt(i, orderData);
          break;
        }
      }

      // ✅ Notify clients with updated data
      sendDataToClients({
        'action': 'orderCancelled',
        'hiveOrderId': data['hiveOrderId'],
        'cancelledQty': data['cancelledQty'],
        'totalAmount': data['totalAmount'],
        'quantities': data['quantities'],
        'itemRemark': data['itemRemark'],
        'partiallycancelled': data['partiallycancelled'],
        'status': data['status'], // ✅ include this
      }, clients);
    } catch (e) {
    }
  }
}

import 'package:hive_flutter/hive_flutter.dart';

import '../services/sendDataToClients.dart';

class CancelOrderPatchHandler {
  static Future<void> patchCancelOrderItem(
    Map<String, dynamic> data,
    // Set<WebSocketChannel> clients
  ) async {
    try {
      var orderBox = await Hive.box('ordersBox');

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
            print(
                "✅ All items cancelled. Updated status in Hive for ${data['hiveOrderId']}.");
          }

          // ✅ Save patched data to Hive
          await orderBox.putAt(i, orderData);
          print("✅ Hive updated for order: ${data['hiveOrderId']}");
          break;
        }
      }

      // ✅ Notify clients with updated data
      sendDataToClientsKOT({
        'action': 'orderCancelled',
        'hiveOrderId': data['hiveOrderId'],
        'cancelledQty': data['cancelledQty'],
        'totalAmount': data['totalAmount'],
        'quantities': data['quantities'],
        'itemRemark': data['itemRemark'],
        'partiallycancelled': data['partiallycancelled'],
        'status': data['status'], // ✅ include this
      });
    } catch (e) {
      print("❌ Failed to patch order cancellation: $e");
    }
  }
}

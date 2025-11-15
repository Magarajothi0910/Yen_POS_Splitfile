// services/order_patch_service.dart

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/hive boxes.dart';

class OrderPatchService {
  static Future<void> patchOrderCancellation({
    required String seathiveOrderId,
    required String remark,
    required WebSocketChannel channel,
    List<Map<String, dynamic>>? inMemoryOrders,
  }) async {
    // Define the new cancellation status.
    const String newStatus = 'cancelled';

    // *** Local Update: Update the Hive storage without modifying preinvoiceTime ***
        final ordersBox = Hive.box('ordersBox'); // Ensure the box is open

    final dynamic data = ordersBox.get('data');
    if (data != null && data is List) {
      // If orders are stored as a list under the key 'data', update that list.
      for (var order in data) {
        if (order is Map<String, dynamic> &&
            order['seathiveOrderId'] == seathiveOrderId) {
          order['status'] = newStatus;
          order['orderRemark'] = remark;
          // Omit updating preinvoiceTime for cancellation
          order['edit'] = "Yes";
          order['sync'] = "No";
          order['statusEdited'] = "true";
        }
      }
      await ordersBox.put('data', data);
    } else {
      // Otherwise, iterate through separate Hive keys.
      for (var key in ordersBox.keys) {
        var order = ordersBox.get(key);
        if (order is Map<String, dynamic> &&
            order['seathiveOrderId'] == seathiveOrderId) {
          order['status'] = newStatus;
          order['orderRemark'] = remark;
          order['edit'] = "Yes";
          order['sync'] = "No";
          order['statusEdited'] = "true";
          await ordersBox.put(key, order);
        }
      }
    }

    // *** In-Memory Update (Optional) ***
    if (inMemoryOrders != null) {
      for (var order in inMemoryOrders) {
        if (order['seathiveOrderId'] == seathiveOrderId) {
          order['status'] = newStatus;
          order['orderRemark'] = remark;
          order['edit'] = "Yes";
          order['sync'] = "No";
          order['statusEdited'] = "true";
        }
      }
    }

    // *** Prepare and send the patch object via WebSocket ***
    final Map<String, dynamic> patchData = {
      'action': 'FullCancelOrderPatch',
      'seathiveOrderId': seathiveOrderId,
      'status': newStatus,
      'orderRemark': remark,
      // Notice no preinvoiceTime is being sent.
      'statusEdited': "true",
      'edit': "Yes",
      'sync': "No",
    };

    try {
      channel.sink.add(jsonEncode(patchData));
      print("Patch sent to server: $patchData");
    } catch (e) {
      print("Error sending patch: $e");
    }
  }
}

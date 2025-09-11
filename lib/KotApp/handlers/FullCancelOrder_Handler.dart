// server/order_patch_handler.dart

import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../kotservices/sendDataToClients.dart';

/// A handler class for processing order patch requests on the server.
/// This class encapsulates the logic for updating cancellation patches.
class OrderPatchHandler {
  /// Processes a cancellation patch request.
  ///
  /// [patchData] should contain the keys:
  ///   - 'seathiveOrderId' : the unique identifier of the order.
  ///   - 'status'         : the new status (should be 'cancelled').
  ///   - 'orderRemark'    : cancellation remark from the client.
  ///   - 'statusEdited'   : a flag, e.g. "true".
  ///   - 'edit'           : a flag, e.g. "Yes".
  ///
  /// The method updates the order in the local Hive storage and then broadcasts
  /// the updated order details to all connected clients using [clients].
  static Future<void> handleFullCancelOrderPatch(
    Map<String, dynamic> patchData,
    Set<WebSocketChannel> clients,
  ) async {
    // Extract required fields from the patchData.
    final String seathiveOrderId =
        patchData['seathiveOrderId']?.toString() ?? '';
    final String newStatus = patchData['status']?.toString() ?? 'cancelled';
    final String orderRemark = patchData['orderRemark']?.toString() ?? '';


    // Open the Hive orders box.
    final orderBox = await Hive.openBox('ordersBox');
    bool orderUpdated = false;

    // Option 1: If orders are stored as a list under a common key 'data'.
    final dynamic ordersData = orderBox.get('data');
    if (ordersData != null && ordersData is List) {
      for (var order in ordersData) {
        if (order is Map<String, dynamic> &&
            order['seathiveOrderId'] == seathiveOrderId) {
          order['status'] = newStatus;
          order['orderRemark'] = orderRemark;
          order['edit'] = "Yes";
          order['statusEdited'] = "true";
          orderUpdated = true;
        }
      }
      if (orderUpdated) {
        await orderBox.put('data', ordersData);
      }
    } else {
      // Option 2: If orders are stored individually.
      for (var key in orderBox.keys) {
        final order = orderBox.get(key);
        if (order is Map<String, dynamic> &&
            order['seathiveOrderId'] == seathiveOrderId) {
          order['status'] = newStatus;
          order['orderRemark'] = orderRemark;
          order['edit'] = "Yes";
          order['statusEdited'] = "true";
          orderUpdated = true;
          await orderBox.put(key, order);
          break; // Stop once the matching order is updated.
        }
      }
    }

    if (orderUpdated) {
    } else {
    }

    // Construct the broadcast message.
    final Map<String, dynamic> broadcastData = {
      'action': 'updateFullOrderCancelStatus',
      'seathiveOrderId': seathiveOrderId,
      'status': newStatus,
      'orderRemark': orderRemark,
      'statusEdited': "true",
      'edit': "Yes",
    };

    // Broadcast updated order to all connected clients.
    sendDataToClients(broadcastData, clients);
  }
}

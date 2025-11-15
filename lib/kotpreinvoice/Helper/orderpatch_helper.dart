import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class OrderPatchHiveUpdater {
  static Future<void> updateOrderInHive({
    required Map<String, dynamic> patchData,
    required String hiveKey,
  }) async {
    try {
      debugPrint("🔄 Starting Hive order update...");
      debugPrint("📦 Hive Key: $hiveKey");
      debugPrint("🧾 Patch Data: $patchData");

      final orderBox = Hive.box('ordersBox');
      debugPrint("📂 Hive box 'ordersBox' opened successfully. Total keys: ${orderBox.keys.length}");

      bool orderUpdated = false;
      final dynamic ordersData = orderBox.get(hiveKey);

      // CASE 1: Orders are stored as a list under hiveKey
      if (ordersData != null && ordersData is List) {
        debugPrint("📋 Found a list of orders under key '$hiveKey'. Total orders: ${ordersData.length}");

        for (var order in ordersData) {
          if (order is Map<String, dynamic>) {
            debugPrint("🔍 Checking order: ${order['seathiveOrderId']}");
            if (order['seathiveOrderId'] == patchData['seathiveOrderId']) {
              debugPrint("✅ Match found in list for orderId: ${patchData['seathiveOrderId']}");
              debugPrint("📝 Before update: $order");

              order['status'] = patchData['status'];
              order['orderRemark'] = patchData['orderRemark'];
              order['edit'] = patchData['edit'];
              order['statusEdited'] = patchData['statusEdited'];
              orderUpdated = true;

              debugPrint("🆕 After update: $order");
            }
          }
        }

        if (orderUpdated) {
          await orderBox.put(hiveKey, ordersData);
          debugPrint("💾 Updated order list saved back to Hive for key '$hiveKey'");
        } else {
          debugPrint("⚠️ No matching order found in list for orderId: ${patchData['seathiveOrderId']}");
        }
      }
      // CASE 2: Orders stored individually in Hive box
      else {
        debugPrint("📁 Orders not stored as list — checking each Hive entry individually...");
        for (var key in orderBox.keys) {
          final order = orderBox.get(key);
          if (order is Map<String, dynamic>) {
            debugPrint("🔍 Checking individual order at key: $key | ID: ${order['seathiveOrderId']}");
            if (order['seathiveOrderId'] == patchData['seathiveOrderId']) {
              debugPrint("✅ Match found in individual record for orderId: ${patchData['seathiveOrderId']}");
              debugPrint("📝 Before update: $order");

              order['status'] = patchData['status'];
              order['orderRemark'] = patchData['orderRemark'];
              order['edit'] = patchData['edit'];
              order['statusEdited'] = patchData['statusEdited'];
              orderUpdated = true;

              await orderBox.put(key, order);
              debugPrint("💾 Updated order saved for key: $key");
            }
          }
        }

        if (!orderUpdated) {
          debugPrint("⚠️ No matching orders found in Hive for orderId: ${patchData['seathiveOrderId']}");
        }
      }

      debugPrint(orderUpdated ? "✅ Hive update completed successfully for orderId: ${patchData['seathiveOrderId']}" : "⚠️ Hive update completed, but no matching order was found.");
    } catch (e, st) {
      debugPrint("🔥 Error updating Hive with patch data: $e");
      debugPrint("📄 StackTrace: $st");
    }
  }
}

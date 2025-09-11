// lib/utils/order_patch_hive_updater.dart

import 'package:hive/hive.dart';

class OrderPatchHiveUpdater {
  /// Updates the persistent Hive storage for orders using the [patchData].
  ///
  /// [hiveKey] is the key under which you save the orders list (e.g. 'data').
  static Future<void> updateOrderInHive({
    required Map<String, dynamic> patchData,
    required String hiveKey,
  }) async {
    try {
      // Open the Hive box; adjust 'ordersBox' to your box name.
      final orderBox = await Hive.openBox('ordersBox');
      bool orderUpdated = false;

      final dynamic ordersData = orderBox.get(hiveKey);
      if (ordersData != null && ordersData is List) {
        for (var order in ordersData) {
          if (order is Map<String, dynamic> &&
              order['seathiveOrderId'] == patchData['seathiveOrderId']) {
            order['status'] = patchData['status'];
            order['orderRemark'] = patchData['orderRemark'];
            order['edit'] = patchData['edit'];
            order['statusEdited'] = patchData['statusEdited'];
            orderUpdated = true;
          }
        }
        if (orderUpdated) {
          await orderBox.put(hiveKey, ordersData);
      
        }
      } else {
        // If orders are stored individually (not as a list), iterate over keys.
        for (var key in orderBox.keys) {
          final order = orderBox.get(key);
          if (order is Map<String, dynamic> &&
              order['seathiveOrderId'] == patchData['seathiveOrderId']) {
            order['status'] = patchData['status'];
            order['orderRemark'] = patchData['orderRemark'];
            order['edit'] = patchData['edit'];
            order['statusEdited'] = patchData['statusEdited'];
            orderUpdated = true;
            await orderBox.put(key, order);
            // No break here, so the loop continues updating any additional matching orders.
          }
        }
      }
    } catch (e) {

    }
  }
}

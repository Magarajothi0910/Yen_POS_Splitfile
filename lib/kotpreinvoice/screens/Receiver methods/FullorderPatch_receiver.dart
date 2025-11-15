import 'package:flutter/material.dart';

class OrderPatchReceiver {
  static void updateOrdersFromPatch({
    required List<Map<String, dynamic>> orders,
    required Map<String, dynamic> patchData,
    required VoidCallback notifyUpdates,
  }) {
    debugPrint("🔄 Received patch update: $patchData");

    final String patchOrderId = patchData['seathiveOrderId']?.toString() ?? '';
    final String orderRemark = patchData['orderRemark']?.toString() ?? '';
    final String editFlag = patchData['edit']?.toString() ?? '';
    final String statusEdited = patchData['statusEdited']?.toString() ?? '';

    debugPrint("🆔 Patch Details:");
    debugPrint("   - seathiveOrderId: $patchOrderId");
    debugPrint("   - orderRemark: $orderRemark");
    debugPrint("   - edit: $editFlag");
    debugPrint("   - statusEdited: $statusEdited");
    debugPrint("📦 Total orders in list: ${orders.length}");

    bool updated = false;

    for (var order in orders) {
      debugPrint("🔍 Checking order: ${order['seathiveOrderId']}");
      if (order['seathiveOrderId'] == patchOrderId) {
        debugPrint("✅ Match found for orderId: $patchOrderId");
        debugPrint("📝 Before update: $order");

        order['orderRemark'] = orderRemark;
        order['edit'] = editFlag;
        order['statusEdited'] = statusEdited;

        debugPrint("✅ Order updated successfully!");
        debugPrint("🆕 After update: $order");
        updated = true;
      }
    }

    if (updated) {
      debugPrint("📢 Orders with seathiveOrderId $patchOrderId updated. Notifying listeners...");
      notifyUpdates();
    } else {
      debugPrint("⚠️ No matching orders found for seathiveOrderId: $patchOrderId");
    }

    debugPrint("🔚 Finished processing patch update.\n");
  }
}

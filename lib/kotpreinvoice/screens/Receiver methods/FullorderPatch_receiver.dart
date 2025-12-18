import 'package:flutter/material.dart';

class OrderPatchReceiver {
  static void updateOrdersFromPatch({
    required List<Map<String, dynamic>> orders,
    required Map<String, dynamic> patchData,
    required VoidCallback notifyUpdates,
  }) {
    final String patchOrderId = patchData['seathiveOrderId']?.toString() ?? '';
    // final String newStatus = patchData['status']?.toString() ?? '';
    final String orderRemark = patchData['orderRemark']?.toString() ?? '';
    final String editFlag = patchData['edit']?.toString() ?? '';
    final String statusEdited = patchData['statusEdited']?.toString() ?? '';

    bool updated = false;
    for (var order in orders) {
      if (order['seathiveOrderId'] == patchOrderId) {
        // order['status'] = newStatus;
        order['orderRemark'] = orderRemark;
        order['edit'] = editFlag;
        order['statusEdited'] = statusEdited;
        updated = true;
      }
    }

    if (updated) {
      debugPrint(
          'Orders with seathiveOrderId $patchOrderId updated:  remark: $orderRemark');
      notifyUpdates();
    } else {
      debugPrint('No matching orders found for seathiveOrderId: $patchOrderId');
    }
  }
}

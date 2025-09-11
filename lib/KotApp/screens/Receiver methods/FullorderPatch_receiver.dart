// lib/utils/order_patch_receiver.dart

import 'package:flutter/material.dart';

/// A helper class for processing order patch messages on the client side.
/// This class encapsulates the logic for updating an in-memory list of orders
/// based on patch data received from the server.
class OrderPatchReceiver {
  /// Updates the provided [orders] list using the [patchData].
  ///
  /// The [patchData] should include:
  /// - 'seathiveOrderId': Unique identifier of the order.
  /// - 'status': The new status (e.g. 'cancelled').
  /// - 'orderRemark': The cancellation remark.
  /// - 'edit' & 'statusEdited': Additional flags as needed.
  ///
  /// Once the matching orders are updated, [notifyUpdates] is called (typically a
  /// callback such as the provider’s notifyListeners()) so the UI refreshes.
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

      notifyUpdates();
    } else {
     
    }
  }
}

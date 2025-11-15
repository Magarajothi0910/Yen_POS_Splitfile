import 'package:flutter/widgets.dart';

import '../../services/sendDataToClients.dart';
import '../soService.dart';
import '../soSyncService.dart';

class soApproveAndHoldOrderHandler {
  final _syncService = SyncServicePos();

  Future<void> handleToApproveOrder(
    Map<String, dynamic> data,
    dynamic clients,
  ) async {
    // Notify connected clients about the new sales order.

    debugPrint("toApproveOrderGenerated: $data");

    // Save the sales order locally.
    await saveToApproveOrderToHive(data);
    debugPrint("Saved sale order locally: $data");

    // If the sales order data contains a nested "data" key,
    // extract it. Otherwise, fallback to the original data.
    final modifyOrder = data['data'] ?? data;

    sendDataToClientsKOT(
      {
        'action': 'toApproveOrderGenerated',
        'toApproveOrder': data,
      },
    );

    // Post the flattened sales order to the FastAPI endpoint.
    bool success = await _syncService.postToApproveOrder({
      "data": [modifyOrder]
    });

    if (success) {
      // _syncService.patchSaleOrder();
      debugPrint("Modify order api posted successfully.");
    } else {
      debugPrint("Failed to post sales order.");
    }
  }

  Future<void> handleHoldOrder(
    Map<String, dynamic> data,
    dynamic clients,
  ) async {
    // Notify connected clients about the new sales order.

    debugPrint("toApproveOrderGenerated: $data");

    // Save the sales order locally.
    await saveToApproveOrderToHive(data);
    debugPrint("Saved sale order locally: $data");

    // If the sales order data contains a nested "data" key,
    // extract it. Otherwise, fallback to the original data.
    final modifyOrder = data['data'] ?? data;

    sendDataToClientsKOT(
      {
        'action': 'holdOrderGenerated',
        'holdOrder': data,
      },
    );
    // Post the flattened sales order to the FastAPI endpoint.
    bool success = await _syncService.postToApproveOrder({
      "data": [modifyOrder]
    });

    if (success) {
      // _syncService.patchSaleOrder();
      debugPrint("Modify order api posted successfully.");
    } else {
      debugPrint("Failed to post sales order.");
    }
  }

  Future<void> handleSalesApprovalOrder(
    Map<String, dynamic> data,
    dynamic clients,
  ) async {
    print("handleSalesApprovalOrder $data");
    final salesOrder = data['data'] ?? data;
    print("savePosInvoiceToHive 1");
    await saveSalesApprovalOrderToHive(data);
    sendDataToClientsKOT(
      {
        'action': 'salesApprovalOrderGenerated',
        'salesApprovalOrder': data,
      },
    );
    bool success = await _syncService.postDiscountOrder({
      "data": [salesOrder]
    });

    if (success) {
      // _syncService.patchSaleOrder();
      debugPrint("Modify order api posted successfully.");
    } else {
      debugPrint("Failed to post sales order.");
    }
    print("savePosInvoiceToHive 2 $data");
  }
}

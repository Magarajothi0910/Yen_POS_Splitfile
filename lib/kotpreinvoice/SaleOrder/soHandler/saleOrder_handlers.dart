import 'dart:developer';
import 'package:flutter/widgets.dart';
import '../../services/sendDataToClients.dart';
import '../service/soHiveService.dart';
import '../soService.dart';
import '../soSyncService.dart';

class SaleOrderHandler {
  final _syncService = SyncServicePos();
  int sendDataToClientsCallCount = 0;

  Future<void> handleSaleOrder(
    Map<String, dynamic> data,
    dynamic clients,
    dynamic saleOrderBox,
  ) async {
    log("handleSaleOrder: \$data");

    final salesOrder = data['data'] ?? data;
    String prefix = salesOrder['saleOrderNo']?.toString().trim() ??
        salesOrder['branchAlias']?.toString().trim() ??
        "SOSB";

    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);
    if (newSalesOrderNo == null) {
      log("Failed to fetch a new sales order number");
      return;
    }

    final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
    salesOrder['saleOrderNo'] = cleanSalesOrderNo;
    log("Updated sales order with new number: \$cleanSalesOrderNo");
    await savePosSaleOrderToHive(data, saleOrderBox);
    log("Saved sale order locally: \$data");

    sendDataToClientsKOT({
      'action': 'salesOrderGenerated',
      'salesOrder': data,
    });

    sendDataToClientsCallCount++;
    log("Sent data to clients \$sendDataToClientsCallCount times");

    bool success = await _syncService.postSalesOrder({
      "data": [salesOrder]
    });

    if (success) {
      log("Sales order posted successfully.");
    } else {
      log("Failed to post sales order.");
    }
  }

  Future<void> handleModifyOrder(
    Map<String, dynamic> data,
    dynamic clients,
  ) async {
    sendDataToClientsKOT(
      {
        'action': 'modifyOrderGenerated',
        'modifyOrder': data,
      },
    );

    log("handleModifyOrder: \$data");
    await saveModifyOrderToHive(data);

    final modifyOrder = data['data'] ?? data;
    bool success = await _syncService.postModifyOrder({
      "data": [modifyOrder]
    });

    if (success) {
      log("Modify order posted successfully.");
    } else {
      log("Failed to post modify order.");
    }
  }

  Future<void> handleDiscountApprovalOrder(
    Map<String, dynamic> data,
    dynamic clients,
  ) async {
    sendDataToClientsKOT({
      'action': 'modifyOrderGenerated',
      'modifyOrder': data,
    });

    log("handleDiscountApprovalOrder: \$data");
    await saveModifyOrderToHive(data);

    final modifyOrder = data['data'] ?? data;
    bool success = await _syncService.postModifyOrder({
      "data": [modifyOrder]
    });

    if (success) {
      log("Discount approval order posted successfully.");
    } else {
      log("Failed to post discount approval order.");
    }
  }

  Future<void> handleSalesOrderAddCustomer(
    Map<String, dynamic> data,
    dynamic clients,
  ) async {
    // ── broadcast to clients & local Hive ─────────────────────────
    sendDataToClientsKOT({
      'action': 'salesOrderAddCustomerGenerated',
      'salesOrderAddCustomer': data,
    });

    saveSalesOrderAddCustomerToHive(data);

    // ── extract fields for the sync call ──────────────────────────
    final String? name = data['name'] as String?;
    final String? mobile = data['mobile'] as String?;
    final String? branch = data['branchId'] as String?;

    if (name == null || mobile == null) {
      return;
    }

    final success = await _syncService.postAddNewCustomerOrder(
      name: name,
      mobile: mobile,
      branchId: branch,
    );

    if (success) {
      debugPrint('✅ Sales‑order customer posted successfully.');
    } else {
      debugPrint('❌ Failed to post sales‑order customer.');
    }
  }
}

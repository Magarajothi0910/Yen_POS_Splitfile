import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:yenpos/Global/globals_data.dart';
import '../../services/sendDataToClients.dart';

import '../soSyncService.dart';

Future<void> handlePatchSaleOrder({
  required Map<String, dynamic> data,
  // required Set<WebSocketChannel> clients,
  required Box saleOrderBox,
  required SyncServicePos syncService,
}) async {
  final salesOrderId = data['salesOrderId'];
  final patchData = data['data'];
  final deviceName = data['deviceName'];
  final type = data['type'];
  final sync = data['sync'];
  final edit = data['edit'];
  final waitingForApprovalResult = data['waitingForApprovalResult'];
  final soNo = data['saleOrderNo'];
  debugPrint('🔧 Starting handlePatchSaleOrder for $salesOrderId');

  // Find the target key in Hive
  String? targetKey;
  for (final entry in saleOrderBox.toMap().entries) {
    final orderData = entry.value['data'];
    if (orderData is Map && orderData['saleOrderNo'] == salesOrderId) {
      targetKey = entry.key.toString();
      break;
    }
  }

  if (targetKey == null) {
    debugPrint("❌ Order $salesOrderId not found in Hive");
    return;
  }

  // Update the order in Hive
  final existingOrder = saleOrderBox.get(targetKey);
  final updatedOrder = Map<String, dynamic>.from(existingOrder);

  if (updatedOrder['data'] is Map) {
    updatedOrder['data'] = Map.from(updatedOrder['data'])..addAll(patchData);
  }

  updatedOrder.addAll({
    'deviceName': deviceName,
    'type': type,
    'sync': sync,
    'edit': edit,
    'waitingForApprovalResult': waitingForApprovalResult ?? 'Yes',
    'saleOrderNo': soNo,
  });

  await saleOrderBox.put(targetKey, updatedOrder);
  debugPrint('✅ Successfully updated Hive entry $targetKey');

  sendDataToClientsKOT({
    'action': 'patchsaleorderGenerated',
    'saleOrderNo': salesOrderId,
    'patchSaleOrder': data,
  });

  debugPrint('📨 sendDataToClients dispatched');

  try {
    bool success = await syncService.patchSalesOrder({
      'saleOrderNo': salesOrderId,
      'data': patchData,
      'deviceName': deviceName,
      'type': type,
      'sync': sync,
      'edit': edit,
      'waitingForApprovalResult': waitingForApprovalResult,
    });

    if (success) {
      debugPrint('✅ Successfully patched sales order $salesOrderId to cloud');
      updatedOrder['sync'] = true;
      await saleOrderBox.put(targetKey, updatedOrder);
    } else {
      debugPrint('❌ Failed to patch sales order $salesOrderId to cloud');
    }
  } catch (e) {
    debugPrint('🚨 Error patching to cloud: $e');
  }
}

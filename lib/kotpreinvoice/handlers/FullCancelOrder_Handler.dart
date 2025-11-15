// server/order_patch_handler.dart

import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:yenpos/kotpreinvoice/services/sync_service.dart';
import '../services/sendDataToClients.dart';

class OrderPatchHandler {
  static Future<void> handleFullCancelOrderPatch(
    Map<String, dynamic> patchData,
    // Set<WebSocketChannel> clients,
  ) async {
    print("🟦 [OrderPatchHandler] Received cancel patch data: $patchData");

    try {
      // ✅ Validate and extract data
      if (patchData.isEmpty) {
        print(
          "⚠️ [OrderPatchHandler] Empty patchData received — aborting update.",
        );
        return;
      }

      final String seathiveOrderId =
          patchData['seathiveOrderId']?.toString() ?? '';
      final String newStatus = patchData['status']?.toString() ?? 'cancelled';
      final String orderRemark = patchData['orderRemark']?.toString() ?? '';

      if (seathiveOrderId.isEmpty) {
        print(
          "❌ [OrderPatchHandler] Missing seathiveOrderId in patchData: $patchData",
        );
        return;
      }

      print(
        "🔍 [OrderPatchHandler] Processing cancel for order ID: $seathiveOrderId",
      );

      // ✅ Open Hive box safely
      Box? orderBox;
      try {
        orderBox = Hive.box('ordersBox');
      } catch (e) {
        print("❌ [OrderPatchHandler] Failed to open Hive box 'ordersBox': $e");
        return;
      }

      bool orderUpdated = false;

      // ✅ Option 1: Orders stored as a list under 'data'
      try {
        final dynamic ordersData = orderBox.get('data');
        if (ordersData != null && ordersData is List) {
          for (var order in ordersData) {
            if (order is Map<String, dynamic> &&
                order['seathiveOrderId'] == seathiveOrderId) {
              print(
                "🟨 [OrderPatchHandler] Found matching order in list. Updating fields...",
              );
              order['status'] = newStatus;
              order['orderRemark'] = orderRemark;
              order['edit'] = "Yes";
              order['sync'] = "No";
              order['statusEdited'] = "true";
              orderUpdated = true;
            }
          }

          if (orderUpdated) {
            await orderBox.put('data', ordersData);
            print("✅ [OrderPatchHandler] Updated orders list successfully.");
          }
        } else {
          // ✅ Option 2: Orders stored individually
          for (var key in orderBox.keys) {
            final order = orderBox.get(key);
            if (order is Map && order['seathiveOrderId'] == seathiveOrderId) {
              print(
                "🟨 [OrderPatchHandler] Found matching order with key '$key'. Updating fields...",
              );
              order['status'] = newStatus;
              order['orderRemark'] = orderRemark;
              order['edit'] = "Yes";
              order['statusEdited'] = "true";
              order['sync'] = "No";
              orderUpdated = true;
              await orderBox.put(key, order);
              print(
                "✅ [OrderPatchHandler] Order with key '$key' updated successfully.",
              );
              break;
            }
          }
        }
      } catch (e, stackTrace) {
        print("❌ [OrderPatchHandler] Error while updating order in Hive: $e");
        print("📜 Stack trace: $stackTrace");
        return;
      }

      if (orderUpdated) {
        print(
          "✅ [OrderPatchHandler] Order $seathiveOrderId updated in Hive as cancelled.",
        );
      } else {
        print(
          "⚠️ [OrderPatchHandler] No matching order found for seathiveOrderId: $seathiveOrderId",
        );
      }

      // ✅ Prepare broadcast payload
      final Map<String, dynamic> broadcastData = {
        'action': 'updateFullOrderCancelStatus',
        'seathiveOrderId': seathiveOrderId,
        'status': newStatus,
        'orderRemark': orderRemark,
        'statusEdited': "true",
        'edit': "Yes",
        'sync': "No",
      };

      // ✅ Try sending to clients
      try {
        sendDataToClientsKOT(broadcastData);
        print(
          "📡 [OrderPatchHandler] Broadcasted cancellation update: ${jsonEncode(broadcastData)}",
        );
      } catch (e, stackTrace) {
        print("❌ [OrderPatchHandler] Failed to broadcast update: $e");
        print("📜 Stack trace: $stackTrace");
      }
    } catch (e, stackTrace) {
      print(
        "❌ [OrderPatchHandler] Unexpected error in handleFullCancelOrderPatch: $e",
      );
      print("📜 Stack trace: $stackTrace");
    }
  }

  static Future<void> handleFullInvoiceOrderPatch(
    Map<String, dynamic> patchData,
  ) async {
    print("🧾 [FullInvoiceOrderPatch] Received patch data: $patchData");

    // 🔹 Extract required fields
    final String seathiveOrderId =
        patchData['seathiveOrderId']?.toString() ?? '';
    final String newStatus = patchData['status']?.toString() ?? 'invoiced';
    final String invoiceNumber = patchData['invoiceNumber']?.toString() ?? '';

    if (seathiveOrderId.isEmpty) {
      print("❌ [FullInvoiceOrderPatch] Missing seathiveOrderId in patchData.");
      return;
    }

    // 🔹 Ensure Hive boxes are open
    if (!Hive.isBoxOpen('ordersBox')) {
      await Hive.openBox('ordersBox');
    }
    if (!Hive.isBoxOpen('invoices')) {
      await Hive.openBox('invoices');
    }

    final orderBox = Hive.box('ordersBox');
    final invoices = Hive.box('invoices');

    bool orderUpdated = false;
    int updatedCount = 0;
    final List<MapEntry<dynamic, dynamic>> remainingOrders = [];

    print(
      '📂 [FullInvoiceOrderPatch] Checking Hive box (keys: ${orderBox.keys.length})...',
    );

    // 🔹 Iterate through all entries in the orderBox
    for (var key in orderBox.keys.toList()) {
      final order = orderBox.get(key);

      if (order is Map<String, dynamic> &&
          order['seathiveOrderId'] == seathiveOrderId) {
        print(
          '✅ [FullInvoiceOrderPatch] Found matching order (key: $key). Updating...',
        );

        try {
          order['status'] = newStatus;
          order['invoiceNumber'] = invoiceNumber;
          order['edit'] = "Yes";
          order['statusEdited'] = "true";
          updatedCount++;
          orderUpdated = true;

          // If invoiced → move to invoices
          if (newStatus.toLowerCase() == 'invoiced') {
            await invoices.add(order);
            print('🧾 [FullInvoiceOrderPatch] Moved order to invoices.');
            // Do NOT keep it in remainingOrders → effectively deletes it
          } else {
            remainingOrders.add(MapEntry(key, order));
          }
        } catch (e) {
          print('❌ [FullInvoiceOrderPatch] Error processing key $key: $e');
        }
      } else {
        // Keep orders that are not matched
        remainingOrders.add(MapEntry(key, order));
      }
    }

    // 🔹 Rebuild orderBox with continuous keys (0,1,2,...)
    await orderBox.clear();
    for (var entry in remainingOrders) {
      await orderBox.add(entry.value);
    }
    print(
      "♻️ [FullInvoiceOrderPatch] Reindexed ordersBox (${orderBox.length} items remaining)",
    );

    if (orderUpdated) {
      print(
        "✅ [FullInvoiceOrderPatch] Updated $updatedCount orders for seathiveOrderId: $seathiveOrderId.",
      );
    } else {
      print(
        "⚠️ [FullInvoiceOrderPatch] No matching order found for seathiveOrderId: $seathiveOrderId",
      );
    }

    // 🔹 Construct broadcast data
    final Map<String, dynamic> broadcastData = {
      'action': 'updateFullOrderInvoiceStatus',
      'seathiveOrderId': seathiveOrderId,
      'status': newStatus,
      'invoiceNumber': invoiceNumber,
      'fieldsEdited': "true",
      'edit': "Yes",
      'sync': "Yes",
      'updatedCount': updatedCount,
    };

    // 🔹 Broadcast to clients
    try {
      sendDataToClientsKOT(broadcastData);
      print(
        "📢 [FullInvoiceOrderPatch] Broadcasted update: ${jsonEncode(broadcastData)}",
      );
      await SyncServiceKot().patchEditedOrders();
    } catch (e) {
      print("❌ [FullInvoiceOrderPatch] Failed to broadcast to clients: $e");
    }
  }
}

import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:yenpos/kotpreinvoice/services/sync_service.dart';
import '../services/sendDataToClients.dart'; // ✅ Make sure this import path is correct

class OrderPatchHandler {
  static Future<void> handleFullCancelOrderPatch(
    Map<String, dynamic> patchData,
  ) async {
    print("🗑️ [FullCancelOrderPatch] Received patch data: $patchData");

    // 🔹 Extract required fields
    final String seathiveOrderId = patchData['seathiveOrderId']?.toString() ?? '';
    final String newStatus = patchData['status']?.toString() ?? 'cancelled';
    final String orderRemark = patchData['orderRemark']?.toString() ?? '';

    if (seathiveOrderId.isEmpty) {
      print("❌ [FullCancelOrderPatch] Missing seathiveOrderId in patchData.");
      return;
    }

    if (!Hive.isBoxOpen('ordersBox')) {
      await Hive.openBox('ordersBox');
    }
    if (!Hive.isBoxOpen('cancelledOrderBox')) {
      await Hive.openBox('cancelledOrderBox');
    }

    final orderBox = Hive.box('ordersBox');
    final cancelledOrderBox = Hive.box('cancelledOrderBox');

    bool orderUpdated = false;
    int updatedCount = 0;
    final List<MapEntry<dynamic, dynamic>> remainingOrders = [];

    print('📂 [FullCancelOrderPatch] Checking Hive box (keys: ${orderBox.keys.length})...');

    // Iterate through all entries in the orderBox
    for (var key in orderBox.keys.toList()) {
      final order = orderBox.get(key);

      if (order is Map<String, dynamic> && order['seathiveOrderId'] == seathiveOrderId) {
        print('✅ [FullCancelOrderPatch] Found matching order (key: $key). Updating...');

        try {
          order['status'] = newStatus;
          order['orderRemark'] = orderRemark;
          order['edit'] = "Yes";
          order['statusEdited'] = "true";
          updatedCount++;
          orderUpdated = true;

          // If cancelled → move to cancelledOrderBox
          if (newStatus.toLowerCase() == 'cancelled') {
            await cancelledOrderBox.add(order);
            print('🚮 [FullCancelOrderPatch] Moved order to cancelledOrderBox.');
            // Do NOT keep it in remainingOrders → effectively deletes it
          } else {
            remainingOrders.add(MapEntry(key, order));
          }
        } catch (e) {
          print('❌ [FullCancelOrderPatch] Error processing key $key: $e');
        }
      } else {
        // Keep orders that are not matched
        remainingOrders.add(MapEntry(key, order));
      }
    }

    // 🔹 Rebuild orderBox with continuous keys (0,1,2,...)
    await SyncServiceKot().patchEditedOrders();
    await orderBox.clear();
    for (var entry in remainingOrders) {
      await orderBox.add(entry.value);
    }
    print("♻️ [FullCancelOrderPatch] Reindexed ordersBox (${orderBox.length} items remaining)");

    if (orderUpdated) {
      print("✅ [FullCancelOrderPatch] Updated $updatedCount orders for seathiveOrderId: $seathiveOrderId.");
    } else {
      print("⚠️ [FullCancelOrderPatch] No matching order found for seathiveOrderId: $seathiveOrderId");
    }

    // 🔹 Construct broadcast data
    final Map<String, dynamic> broadcastData = {
      'action': 'updateFullOrderCancelStatus',
      'seathiveOrderId': seathiveOrderId,
      'status': newStatus,
      'orderRemark': orderRemark,
      'fieldsEdited': "true",
      'edit': "Yes",
      'sync': "Yes",
      'updatedCount': updatedCount,
    };

    // 🔹 Broadcast to clients
    try {
      sendDataToClientsKOT(broadcastData);
      print("📢 [FullCancelOrderPatch] Broadcasted update: ${jsonEncode(broadcastData)}");
      await SyncServiceKot().patchEditedOrders();
    } catch (e) {
      print("❌ [FullCancelOrderPatch] Failed to broadcast to clients: $e");
    }
  }

  static Future<void> handleFullInvoiceOrderPatch(
    Map<String, dynamic> patchData,
  ) async {
    print("🧾 [FullInvoiceOrderPatch] Received patch data: $patchData");

    // 🔹 Extract required fields
    final String seathiveOrderId = patchData['seathiveOrderId']?.toString() ?? '';
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
    if (!Hive.isBoxOpen('invoicesKOT')) {
      await Hive.openBox('invoicesKOT');
    }

    final orderBox = Hive.box('ordersBox');
    final invoices = Hive.box('invoicesKOT');

    bool orderUpdated = false;
    int updatedCount = 0;
    final List<MapEntry<dynamic, dynamic>> remainingOrders = [];

    print('📂 [FullInvoiceOrderPatch] Checking Hive box (keys: ${orderBox.keys.length})...');

    // 🔹 Iterate through all entries in the orderBox
    for (var key in orderBox.keys.toList()) {
      final order = orderBox.get(key);

      if (order is Map<String, dynamic> && order['seathiveOrderId'] == seathiveOrderId) {
        print('✅ [FullInvoiceOrderPatch] Found matching order (key: $key). Updating...');

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
    print("♻️ [FullInvoiceOrderPatch] Reindexed ordersBox (${orderBox.length} items remaining)");

    if (orderUpdated) {
      print("✅ [FullInvoiceOrderPatch] Updated $updatedCount orders for seathiveOrderId: $seathiveOrderId.");
    } else {
      print("⚠️ [FullInvoiceOrderPatch] No matching order found for seathiveOrderId: $seathiveOrderId");
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
      print("📢 [FullInvoiceOrderPatch] Broadcasted update: ${jsonEncode(broadcastData)}");
      await SyncServiceKot().patchEditedOrders();
    } catch (e) {
      print("❌ [FullInvoiceOrderPatch] Failed to broadcast to clients: $e");
    }
  }
}

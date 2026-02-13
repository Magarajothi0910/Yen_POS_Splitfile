import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Server_Client/handlers/webscoket_messgae_handler.dart';

final Set<String> _processedOrders = {};
final Set<String> _activeOrders = {};

Future<void> handleHoldOrder(Map<String, dynamic> jsonData) async {
  Map<String, dynamic>? orderData;

  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  debugPrint('[HOLD ORDER] WS MESSAGE RECEIVED');
  debugPrint(jsonData.toString());

  try {
    // ───────── Step 1: Extract holdOrder ─────────
    final salesOrder = jsonData['holdOrder'];
    if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
      debugPrint('[HOLD ORDER] ❌ Invalid or missing "holdOrder"');
      return;
    }

    orderData = salesOrder['data'] ?? {};
    if (orderData is! Map<String, dynamic>) {
      debugPrint('[HOLD ORDER] ❌ Invalid holdOrder.data format');
      return;
    }

    final saleOrderNo = orderData['holdOrderId']?.toString();
    if (saleOrderNo == null || saleOrderNo.isEmpty) {
      debugPrint('[HOLD ORDER] ❌ holdOrderId missing');
      return;
    }

    debugPrint('[HOLD ORDER] ID → $saleOrderNo');

    // ───────── Step 2: Active order guard ─────────
    if (_activeOrders.contains(saleOrderNo)) {
      debugPrint('[HOLD ORDER] ⏳ Already processing → $saleOrderNo');
      return;
    }

    _activeOrders.add(saleOrderNo);
    debugPrint('[HOLD ORDER] 🔒 Marked ACTIVE → $saleOrderNo');

    // ───────── Step 3: Extract media paths ─────────
    final audioPath = orderData['audioPath'] ?? '';
    final imagePaths = orderData['imagePaths'] ?? [];

    debugPrint('[HOLD ORDER] AudioPath → $audioPath');
    debugPrint('[HOLD ORDER] ImagePaths → $imagePaths');

    // ───────── Step 4: Add metadata ─────────
    orderData['type'] = 'holdOrder';
    orderData['audioPath'] = audioPath;
    orderData['imagePaths'] = imagePaths;

    debugPrint('[HOLD ORDER] Metadata appended');

    // ───────── Step 5: Hive box access ─────────
    final salesOrderBox = HiveManager.holdOrderBox;

    debugPrint('[HOLD ORDER] Hive box opened');

    // ───────── Step 6: Duplicate guard ─────────
    if (salesOrderBox.containsKey(saleOrderNo)) {
      debugPrint('[HOLD ORDER] ⚠️ Already exists in Hive → $saleOrderNo');
      _processedOrders.add(saleOrderNo);
      _activeOrders.remove(saleOrderNo);
      return;
    }

    // ───────── Step 7: Save to Hive ─────────
    await salesOrderBox.put(saleOrderNo, orderData);
    debugPrint('[HOLD ORDER] ✅ Saved to Hive → $saleOrderNo');

    _processedOrders.add(saleOrderNo);
    debugPrint('[HOLD ORDER] ✅ Marked PROCESSED → $saleOrderNo');

    // ───────── Step 8: Verify saved orders ─────────
    final orders = await getSavedHoldOrders();
    debugPrint('[HOLD ORDER] Total saved hold orders → ${orders.length}');

    if (orders.isEmpty) {
      debugPrint('[HOLD ORDER] ⚠️ No hold orders found after save');
      return;
    }

    debugPrint('[HOLD ORDER] 🎉 Hold order stored successfully');

    // ❌ NO PRINT TRIGGER HERE
    // customerProvider.updateReceiptData(orderData);

  } catch (e, st) {
    debugPrint('[HOLD ORDER] ❌ ERROR → $e');
    debugPrint(st.toString());

    if (orderData != null && orderData['holdOrderId'] != null) {
      final failedOrderNo = orderData['holdOrderId'];
      debugPrint('[HOLD ORDER] 🧹 Rolling back state → $failedOrderNo');
      _processedOrders.remove(failedOrderNo);
      _activeOrders.remove(failedOrderNo);
    }
  } finally {
    if (orderData != null && orderData['holdOrderId'] != null) {
      final orderNo = orderData['holdOrderId'];
      if (_activeOrders.contains(orderNo)) {
        _activeOrders.remove(orderNo);
        debugPrint('[HOLD ORDER] 🔓 Removed ACTIVE lock → $orderNo');
      }
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
}
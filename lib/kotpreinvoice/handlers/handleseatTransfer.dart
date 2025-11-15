import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/hive_service.dart';
import '../services/sendDataToClients.dart';

Future<void> handleSeatTransfer({
  required Map<String, dynamic> data,
  required List<Map<String, dynamic>> receivedData,
}) async {
  try {
    print('📥 [SeatTransfer] Received transfer data: $data');
    print('🗃️ [SeatTransfer] Current in-memory orders count: ${receivedData.length}');

    final seathiveOrderId = data['seathiveOrderId']?.toString();
    final newTable = data['targetTable']?.toString();
    final newSeat = data['targetSeat']?.toString();

    // Validate inputs
    if (seathiveOrderId == null || newTable == null || newSeat == null) {
      print("❌ [SeatTransfer] Invalid seat transfer data: Missing required fields.");
      return;
    }

    print('🪑 [SeatTransfer] Processing transfer for seathiveOrderId=$seathiveOrderId → newTable=$newTable, newSeat=$newSeat');

    // Open Hive box
    if (!Hive.isBoxOpen('ordersBox')) {
      print('📦 [SeatTransfer] Hive box not open. Opening now...');
      await Hive.openBox('ordersBox');
      print('✅ [SeatTransfer] Hive box opened.');
    } else {
      print('📦 [SeatTransfer] Hive box already open.');
    }

    final orderBox = Hive.box('ordersBox');
    print('📋 [SeatTransfer] Hive box contains ${orderBox.length} records.');

    // Load existing orders
    print('📤 [SeatTransfer] Loading all orders from Hive...');
    final allOrders = await loadOrdersFromHive();
    print('✅ [SeatTransfer] Loaded $allOrders total orders.');

    // Update orders in Hive
    bool orderFound = false;
    for (var i = 0; i < allOrders.length; i++) {
      var order = allOrders[i];
      if (order['seathiveOrderId'] == seathiveOrderId) {
        print('🆔 [SeatTransfer] Found matching order at index $i: ${order['orderId'] ?? 'N/A'}');
        print('🪑 [SeatTransfer] Old Table: ${order['table']}, Old Seat: ${order['seat']}');
        order['table'] = newTable;
        order['seat'] = newSeat;
        print('🔁 [SeatTransfer] Updated to New Table: $newTable, New Seat: $newSeat');
        orderFound = true;
      }
    }

    if (!orderFound) {
      print("⚠️ [SeatTransfer] No order found with seathiveOrderId: $seathiveOrderId");
      return;
    }

    // Clear and rewrite Hive orders
    print('🧹 [SeatTransfer] Clearing old Hive data...');
    await orderBox.clear();
    print('✍️ [SeatTransfer] Rewriting updated orders to Hive...');
    for (var i = 0; i < allOrders.length; i++) {
      await orderBox.add(allOrders[i]);
      print('✅ [SeatTransfer] Re-added order $i with seathiveOrderId: ${allOrders[i]['seathiveOrderId']}');
    }

    // Update in-memory receivedData
    print('🧠 [SeatTransfer] Updating in-memory order list...');
    for (var i = 0; i < receivedData.length; i++) {
      if (receivedData[i]['seathiveOrderId'] == seathiveOrderId) {
        print('🧩 [SeatTransfer] Found in-memory order at index $i. Updating...');
        receivedData[i]['table'] = newTable;
        receivedData[i]['seat'] = newSeat;
        print('✅ [SeatTransfer] In-memory order updated.');
      }
    }

    // Broadcast to clients
    final broadcastPayload = {
      'action': 'seat_transfer_applied',
      'seathiveOrderId': seathiveOrderId,
      'newTable': newTable,
      'newSeat': newSeat,
    };
    print('📡 [SeatTransfer] Broadcasting update to clients: $broadcastPayload');
    sendDataToClientsKOT(broadcastPayload);

    print('✅ [SeatTransfer] Transfer applied successfully for seathiveOrderId=$seathiveOrderId');
    print('🔄 [SeatTransfer] Reloading Hive data to verify...');
    await loadOrdersFromHive();
    print('🏁 [SeatTransfer] Seat transfer process completed.');
  } catch (e, st) {
    print("❌ [SeatTransfer] Error occurred: $e");
    print("📜 StackTrace:\n$st");
    rethrow;
  }
}

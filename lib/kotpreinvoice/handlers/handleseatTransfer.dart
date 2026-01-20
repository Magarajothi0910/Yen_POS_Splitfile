import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/kotpreinvoice/providers/order_provider.dart';
import 'package:yenpos/kotpreinvoice/services/stockUpdateService.dart';
import 'package:yenpos/kotpreinvoice/services/sync_service.dart';
import '../services/hive_service.dart';
import '../services/sendDataToClients.dart';

final syncServiceKot = SyncServiceKot();
final orderProvider = OrderProvider();

// Future<void> handleSeatTransfer({
//   required Map<String, dynamic> data,
//   // required List<Map<String, dynamic>> receivedData,
// }) async {
//   try {
//     print('📥 [SeatTransfer] Received transfer data: $data');
//     // p?rint(
//     //   '🗃️ [SeatTransfer] Current in-memory orders count: ${receivedData.length}',
//     // );

//     final seathiveOrderId = data['seathiveOrderId']?.toString();
//     final newTable = data['targetTable']?.toString();
//     final newSeat = data['targetSeat']?.toString();

//     // Validate inputs
//     if (seathiveOrderId == null || newTable == null || newSeat == null) {
//       print(
//         "❌ [SeatTransfer] Invalid seat transfer data: Missing required fields.",
//       );
//       return;
//     }

//     print(
//       '🪑 [SeatTransfer] Processing transfer for seathiveOrderId=$seathiveOrderId → newTable=$newTable, newSeat=$newSeat',
//     );

//     // Open Hive box
//     if (!Hive.isBoxOpen('ordersBox')) {
//       print('📦 [SeatTransfer] Hive box not open. Opening now...');
//       await Hive.openBox('ordersBox');
//       print('✅ [SeatTransfer] Hive box opened.');
//     } else {
//       print('📦 [SeatTransfer] Hive box already open.');
//     }

//     final orderBox = Hive.box('ordersBox');
//     print('📋 [SeatTransfer] Hive box contains ${orderBox.length} records.');

//     // Load existing orders
//     final allOrders = await loadOrdersFromHiveUtility();

//     // Update orders in Hive
//     bool orderFound = false;
//     for (var i = 0; i < allOrders.length; i++) {
//       var order = allOrders[i];
//       if (order['seathiveOrderId'] == seathiveOrderId) {
//         print(
//           '🆔 [SeatTransfer] Found matching order at index $i: ${order['orderId'] ?? 'N/A'}',
//         );
//         print(
//           '🪑 [SeatTransfer] Old Table: ${order['table']}, Old Seat: ${order['seat']}',
//         );
//         order['table'] = newTable;
//         order['seat'] = newSeat;
//         print(
//           '🔁 [SeatTransfer] Updated to New Table: $newTable, New Seat: $newSeat',
//         );
//         orderFound = true;
//       }
//     }

//     if (!orderFound) {
//       print(
//         "⚠️ [SeatTransfer] No order found with seathiveOrderId: $seathiveOrderId",
//       );
//       return;
//     }

//     // Clear and rewrite Hive orders
//     print('🧹 [SeatTransfer] Clearing old Hive data...');
//     await orderBox.clear();
//     print('✍️ [SeatTransfer] Rewriting updated orders to Hive...');
//     for (var i = 0; i < allOrders.length; i++) {
//       await orderBox.add(allOrders[i]);
//       print(
//         '✅ [SeatTransfer] Re-added order $i with seathiveOrderId: ${allOrders[i]['seathiveOrderId']}',
//       );
//     }

//     // Update in-memory receivedData
//     // print('🧠 [SeatTransfer] Updating in-memory order list...');
//     // for (var i = 0; i < receivedData.length; i++) {
//     //   if (receivedData[i]['seathiveOrderId'] == seathiveOrderId) {
//     //     print(
//     //       '🧩 [SeatTransfer] Found in-memory order at index $i. Updating...',
//     //     );
//     //     receivedData[i]['table'] = newTable;
//     //     receivedData[i]['seat'] = newSeat;
//     //     print('✅ [SeatTransfer] In-memory order updated.');
//     //   }
//     // }

//     // Broadcast to clients
//     final broadcastPayload = {
//       'action': 'seat_transfer_applied',
//       'seathiveOrderId': seathiveOrderId,
//       'newTable': newTable,
//       'newSeat': newSeat,
//     };
//     print(
//       '📡 [SeatTransfer] Broadcasting update to clients: $broadcastPayload',
//     );
//     sendDataToClients(broadcastPayload, clients);

//     print(
//       '✅ [SeatTransfer] Transfer applied successfully for seathiveOrderId=$seathiveOrderId',
//     );
//     print('🔄 [SeatTransfer] Reloading Hive data to verify...');
//     await loadOrdersFromHiveUtility();

//     try {
//       await syncServiceKot.patchOrderTableAndSeat(
//         seathiveOrderId,
//         newTable,
//         newSeat,
//       );
//     } catch (e, st) {
//       print("⚠️ [SeatTransfer] Error while patching to backend: $e");
//       print("📜 [SeatTransfer] StackTrace:\n$st");
//     }

//     print('🏁 [SeatTransfer] Seat transfer process completed.');
//   } catch (e, st) {
//     print("❌ [SeatTransfer] Error occurred: $e");
//     print("📜 StackTrace:\n$st");
//     rethrow;
//   }
// }

final Set<String> _activeSeatTransfers = {};

Future<void> handleSeatTransfer({required Map<String, dynamic> data}) async {
  try {
    print('📥 [SeatTransfer] Incoming data: $data');

    final seathiveOrderId = data['seathiveOrderId']?.toString();
    final newTable = data['targetTable']?.toString();
    final newSeat = data['targetSeat']?.toString();

    if (seathiveOrderId == null || newTable == null || newSeat == null) {
      print('❌ [SeatTransfer] Missing required fields');
      return;
    }

    // 🔒 Idempotency guard
    if (_activeSeatTransfers.contains(seathiveOrderId)) {
      print('⏭️ [SeatTransfer] Duplicate event ignored for $seathiveOrderId');
      return;
    }
    _activeSeatTransfers.add(seathiveOrderId);

    print(
      '🪑 [SeatTransfer] Processing seathiveOrderId=$seathiveOrderId → '
      'Table=$newTable Seat=$newSeat',
    );

    // 📦 Open Hive box if needed
    if (!Hive.isBoxOpen('ordersBox')) {
      await Hive.openBox('ordersBox');
    }

    final Box orderBox = Hive.box('ordersBox');
    print('📋 [SeatTransfer] Hive records: ${orderBox.length}');

    dynamic matchedKey;
    Map<String, dynamic>? order;

    // 🔍 Locate order by Hive key
    for (final key in orderBox.keys) {
      final value = orderBox.get(key);
      if (value is Map &&
          value['seathiveOrderId']?.toString() == seathiveOrderId) {
        matchedKey = key;
        order = Map<String, dynamic>.from(value);
        break;
      }
    }

    if (matchedKey == null || order == null) {
      print('⚠️ [SeatTransfer] Order not found: $seathiveOrderId');
      return;
    }

    print(
      '🆔 [SeatTransfer] Found order. '
      'Old Table=${order['table']} Old Seat=${order['seat']}',
    );

    // 🔁 Apply update
    order['table'] = newTable;
    order['seat'] = newSeat;

    // 💾 Atomic update (NO duplication possible)
    await orderBox.put(matchedKey, order);

    print(
      '✅ [SeatTransfer] Updated successfully → '
      'Table=$newTable Seat=$newSeat',
    );

    // 📡 Broadcast to clients
    final payload = {
      'action': 'seat_transfer_applied',
      'seathiveOrderId': seathiveOrderId,
      'newTable': newTable,
      'newSeat': newSeat,
    };

    print('📡 [SeatTransfer] Broadcasting: $payload');
    sendDataToClients(payload, clients);

    // 🌐 Sync with backend
    try {
      await syncServiceKot.patchOrderTableAndSeat(
        seathiveOrderId,
        newTable,
        newSeat,
      );
      print('🌐 [SeatTransfer] Backend sync success');
    } catch (e, st) {
      print('⚠️ [SeatTransfer] Backend sync failed: $e');
      print('📜 $st');
    }

    print('🏁 [SeatTransfer] Completed for $seathiveOrderId');
  } catch (e, st) {
    print('❌ [SeatTransfer] Fatal error: $e');
    print('📜 $st');
  } finally {
    _activeSeatTransfers.remove(data['seathiveOrderId']?.toString());
  }
}

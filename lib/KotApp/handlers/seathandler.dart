import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../kotservices/sendDataToClients.dart';
import '../kotservices/sync_service.dart';

Future<void> handleSeatTransfer({
  required Map<String, dynamic> data,
  required List<Map<String, dynamic>> receivedData,
  required Set<WebSocketChannel> clients,
}) async {

  final currentTable = data['currentTable'];
  final currentSeat = data['currentSeat'];
  final targetTable = data['targetTable'];
  final targetSeat = data['targetSeat'];
  final seathiveOrderId = data['seathiveOrderId'];


  bool foundInMemory = false;

  // Update in-memory orders: update all matching orders
  for (var order in receivedData) {
    if (order['seathiveOrderId'] == seathiveOrderId) {
      order['table'] = targetTable;
      order['seat'] = targetSeat;
      order['edit'] = "Yes";
      order['seat_transfer'] = true;
      foundInMemory = true;
    }
  }

  // Update orders in Hive without breaking on the first update.
  var orderBox = await Hive.openBox('ordersBox');
  bool foundInHive = false;

  for (int i = 0; i < orderBox.length; i++) {
    var orderData = orderBox.getAt(i);

    if (orderData is String) {
      orderData = jsonDecode(orderData);
    }

    if (orderData['seathiveOrderId'] == seathiveOrderId) {
      orderData['table'] = targetTable;
      orderData['seat'] = targetSeat;
      orderData['edit'] = "Yes";
      orderData['seat_transfer'] = true;

      await orderBox.putAt(i, orderData);

      // Add to in-memory list if not already present.
      if (!receivedData.contains(orderData)) {
        receivedData.add(orderData);
      }

      foundInHive = true;
      // Removed break to continue updating all matching orders.
    }
  }

  if (foundInMemory || foundInHive) {
    // Broadcast the updated data to all clients.
    sendDataToClients({
      'action': 'seat_transfer',
      'currentTable': currentTable,
      'currentSeat': currentSeat,
      'targetTable': targetTable,
      'targetSeat': targetSeat,
      'seathiveOrderId': seathiveOrderId,
    }, clients);

    final syncService = SyncServiceKot();
    final patched = await syncService.patchOrderTableAndSeat(
      seathiveOrderId,
      targetTable,
      targetSeat,
    );

    if (patched) {
    } else {
    }
  } else {
  }
}

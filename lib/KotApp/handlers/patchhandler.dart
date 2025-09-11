import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../kotservices/sendDataToClients.dart';
import '../kotservices/sync_service.dart';

final SyncServiceKot _syncService = SyncServiceKot();

void handlePatchOrderStatusBySeathiveOrderId(
    String seathiveOrderId,
    String newStatus,
    String orderRemark,
    String preinvoiceTime,
    Set<WebSocketChannel> clients,
    List<Map<String, dynamic>> receivedData) async {
  // First, update in _receivedData
  bool dataUpdated = false;
  for (var order in receivedData) {
    if (order['seathiveOrderId'] == seathiveOrderId) {
      order['status'] = newStatus; // Update the status
      order['orderRemark'] = orderRemark; // Update the status

      order['preinvoiceTime'] = preinvoiceTime;

      order['edit'] = "Yes"; // Set edit to Yes
      dataUpdated = true; // Set flag to indicate that an update was made
    }
  }

  // If data was updated in _receivedData, proceed to update in Hive
  if (dataUpdated) {
    var orderBox =
        await Hive.openBox('ordersBox'); // Ensure the box name is correct

    // Iterate over all stored orders and update matching ones
    for (int i = 0; i < orderBox.length; i++) {
      var orderData = orderBox.getAt(i);

      // If the stored data is a string, decode it into a map
      if (orderData is String) {
        orderData = jsonDecode(orderData) as Map<String, dynamic>;
      }

      if (orderData['seathiveOrderId'] == seathiveOrderId) {
        // Update the fields
        orderData['status'] = newStatus;
        orderData['orderRemark'] = orderRemark; // Update the status
        orderData['preinvoiceTime'] = preinvoiceTime; // Update the status

        orderData['edit'] = "Yes";
        orderData['statusEdited'] = "true";

        // Save the updated order back to Hive
        await orderBox.putAt(i, orderData);
      }
    }

    // Send data to all connected clients after the update
    sendDataToClients({
      'action': 'updateOrderStatus',
      'hiveOrderId': seathiveOrderId,
      'status': newStatus,
      'orderRemark': orderRemark,
      "preinvoiceTime": preinvoiceTime,
      'statusEdited': "true",
      'edit': "Yes",
    }, clients);
    await _syncService.patchEditedOrders();
  } else {
  }
}

void handlePatchCancelOrderStatusBySeathiveOrderId(
    String hiveOrderId,
    String newStatus,
    String orderRemark,
    Set<WebSocketChannel> clients,
    List<Map<String, dynamic>> receivedData) async {
  // First, update in _receivedData
  bool dataUpdated = false;
  for (var order in receivedData) {
    if (order['hiveOrderId'] == hiveOrderId) {
      order['status'] = newStatus; // Update the status
      order['orderRemark'] = orderRemark; // Update the status

      order['edit'] = "Yes"; // Set edit to Yes
      dataUpdated = true; // Set flag to indicate that an update was made
    }
  }

  // If data was updated in _receivedData, proceed to update in Hive
  if (dataUpdated) {
    var orderBox =
        await Hive.openBox('ordersBox'); // Ensure the box name is correct

    // Iterate over all stored orders and update matching ones
    for (int i = 0; i < orderBox.length; i++) {
      var orderData = orderBox.getAt(i);

      // If the stored data is a string, decode it into a map
      if (orderData is String) {
        orderData = jsonDecode(orderData) as Map<String, dynamic>;
      }

      if (orderData['hiveOrderId'] == hiveOrderId) {
        // Update the fields
        orderData['status'] = newStatus;
        orderData['orderRemark'] = orderRemark; // Update the status

        orderData['edit'] = "Yes";
        orderData['statusEdited'] = "true";

        // Save the updated order back to Hive
        await orderBox.putAt(i, orderData);
      }
    }

    // Send data to all connected clients after the update
    sendDataToClients({
      'action': 'updateCancelOrderStatus',
      'hiveOrderId': hiveOrderId,
      'status': newStatus,
      'orderRemark': orderRemark,
      'statusEdited': "true",
      'edit': "Yes",
    }, clients);
    await _syncService.patchEditedOrders();
  } else {
  }
}

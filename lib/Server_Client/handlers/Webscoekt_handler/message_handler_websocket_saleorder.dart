import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';

final Set<String> _processedOrders = {};
final Set<String> _activeOrders = {};

Future<void> handleSalesOrder(
  Map<String, dynamic> jsonData,
  CustomerScreenProvider customerProvider,

) async {

  Map<String, dynamic>? orderData;

  try {
    final salesOrder = jsonData['salesOrder'];
    if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
      return;
    }

    orderData = salesOrder['data'] ?? {};
    if (orderData is! Map<String, dynamic>) {
      return;
    }

    final saleOrderNo = orderData['saleOrderNo']?.toString();

    if (saleOrderNo == null || saleOrderNo.isEmpty) {
      return;
    }


    if (_activeOrders.contains(saleOrderNo)) {
      return;
    }

    if (_processedOrders.contains(saleOrderNo)) {
      return;
    }

    _activeOrders.add(saleOrderNo);

    // Extract audio and image paths
    final audioPath = salesOrder["data"]?['audioPath'] ?? '';
    final imagePath = salesOrder["data"]?['imagePaths'] ?? '';


    // Add metadata to order data
    orderData['type'] = 'salesOrder';
    orderData['audioPath'] = audioPath;
    orderData['imagePaths'] = imagePath;

    final salesOrderBox2 = HiveManager.salesOrderBox;

    if (salesOrderBox2.containsKey(saleOrderNo)) {
      _processedOrders.add(saleOrderNo);
      _activeOrders.remove(saleOrderNo);
      return;
    }

    await salesOrderBox2.put(saleOrderNo, orderData);

    _processedOrders.add(saleOrderNo);

    final orders = await getSavedSalesOrders();
    if (orders.isEmpty) {
      return;
    }


    // Step 3: Get the most recent order
    final lastOrder = orders.last;

    // Step 4: Update receipt data in provider
    customerProvider.updateReceiptData(orderData);

  } catch (e, st) {

    if (orderData != null && orderData['saleOrderNo'] != null) {
      final failedOrderNo = orderData['saleOrderNo'];
      _processedOrders.remove(failedOrderNo);
      _activeOrders.remove(failedOrderNo);
    }
  } finally {
    if (orderData != null && orderData['saleOrderNo'] != null) {
      final orderNo = orderData['saleOrderNo'];
      if (_activeOrders.contains(orderNo)) {
        _activeOrders.remove(orderNo);
      }
    }

  }
}

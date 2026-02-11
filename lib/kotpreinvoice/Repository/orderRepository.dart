import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class OrderRepository {
  final Box _orderBox;

  OrderRepository(this._orderBox);

  /// Retrieves all orders from Hive as a list of Map<String, dynamic>
  List<Map<String, dynamic>> getAllOrders() {
    return _orderBox.values.map((order) {
      if (order is String) {
        order = jsonDecode(order);
      }
      if (order is Map) {
        return Map<String, dynamic>.from(order);
      }
      throw Exception("Unexpected order type");
    }).toList();
  }

  /// Updates all orders identified by seathiveOrderId with the given updates.
  /// Returns the count of updated orders.
  Future<int> updateOrders(
      String seathiveOrderId, Map<String, dynamic> updates) async {
    int updatedCount = 0;
    final orders = _orderBox.values.toList();
    for (int i = 0; i < orders.length; i++) {
      var orderData = orders[i];
      // If order is stored as a JSON string, decode it.
      if (orderData is String) {
        orderData = jsonDecode(orderData);
      }
      // Convert to Map<String, dynamic>
      if (orderData is Map) {
        orderData = Map<String, dynamic>.from(orderData);
      } else {
        continue; // Skip if it's not a map
      }
      if (orderData['seathiveOrderId'] == seathiveOrderId) {
        orderData.addAll(updates);
        await _orderBox.putAt(i, orderData);
        updatedCount++;
      }
    }
    return updatedCount;
  }
}

import 'package:hive/hive.dart';

class OrderRepository {
  final Box ordersBox;

  OrderRepository({required this.ordersBox});

  /// Update all orders that match the given seathiveOrderId.
  Future<int> updateOrder(
      String seathiveOrderId, Map<String, dynamic> updatedData) async {
    int updatedCount = 0;
    // Assuming the orders are stored with a 'data' key as a List
    final allOrders = ordersBox.get('data') ?? [];
    if (allOrders is List) {
      for (int i = 0; i < allOrders.length; i++) {
        final order = allOrders[i];
        if (order['seathiveOrderId'] == seathiveOrderId) {
          allOrders[i] = updatedData;
          updatedCount++;
        }
      }
      await ordersBox.put('data', allOrders);
    }
    return updatedCount;
  }
}

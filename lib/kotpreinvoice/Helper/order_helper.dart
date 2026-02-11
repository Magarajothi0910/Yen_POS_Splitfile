// utils/order_helpers.dart

List<Map<String, dynamic>> filterValidSeatOrders({
  required List<dynamic> allOrders,
  required String tableNumber,
  required String seat,
}) {
  return allOrders
      .where((order) =>
          order is Map<String, dynamic> &&
          order['table'] == tableNumber &&
          order['seat'] == seat &&
          (order['status'] == 'active' || order['status'] == 'confirm'))
      .cast<Map<String, dynamic>>()
      .toList();
}

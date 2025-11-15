import 'dart:convert';
import 'package:hive/hive.dart';

import 'patchorderRepo.dart';

class OrderService {
  final OrderRepository repository;
  final List<Map<String, dynamic>> orders;

  OrderService({required this.repository, required this.orders});

  /// Returns the order matching the provided seathiveOrderId (if any).
  Map<String, dynamic>? findOrder(String seathiveOrderId) {
    try {
      return orders.firstWhere(
        (order) => order['seathiveOrderId'] == seathiveOrderId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Updates the cancellation data for an order.
  Future<bool> updateCancellation({
    required String seathiveOrderId,
    required List<double> updatedQuantities,
    required List<double> updatedCancelledQty,
    required List<double> amounts,
    required double totalAmount,
    required String partiallyCancelled,
    required List<String> itemRemark,
  }) async {
    final order = findOrder(seathiveOrderId);
    if (order != null) {
      order['quantities'] = updatedQuantities;
      order['cancelledQty'] = updatedCancelledQty;
      order['amounts'] = amounts;
      order['totalAmount'] = totalAmount;
      order['partiallyCancelled'] = partiallyCancelled;
      order['itemRemark'] = itemRemark;
      order['edit'] = "Yes";
      order['fieldsEdited'] = "true";

      // Update in persistent storage (using your repository)
      await repository.updateOrder(seathiveOrderId, order);
      return true;
    }
    return false;
  }
}

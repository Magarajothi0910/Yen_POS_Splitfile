import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';

final Set<String> _processedHoldOrders = {};

Future<void> handleHoldOrder(Map<String, dynamic> jsonData) async {
  final salesOrder = jsonData['holdOrder'];
  if (salesOrder == null || salesOrder is! Map<String, dynamic>) return;

  final list = salesOrder['data'] ?? [];
  if (list is! List || list.isEmpty) return;

  final order = list.first;
  final holdOrderId = order['holdOrderId']?.toString();
  if (holdOrderId == null || holdOrderId.isEmpty) return;

  if (_processedHoldOrders.contains(holdOrderId)) return;

  final box = HiveManager.holdOrderBox;
  if (box.containsKey(holdOrderId)) {
    _processedHoldOrders.add(holdOrderId);
    return;
  }

  try {
    await box.put(holdOrderId, order);
    _processedHoldOrders.add(holdOrderId);
    print("💾 Saved hold order $holdOrderId");
  } catch (e) {
    print("❌ Error saving hold order: $e");
  }
}

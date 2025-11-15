import 'package:hive/hive.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';

Future<void> handleApprovalOrder(Map<String, dynamic> salesOrder) async {
  if (salesOrder == null) return;

  // Step 1: Save to Hive
  await _saveApproveOrderToHive(salesOrder);

  // Step 2: Retrieve all saved approval orders
  final approvalOrders = await getSavedApprovalOrder();

  // Optional: Do something with approvalOrders if needed
  print("✅ Total saved approval orders: ${approvalOrders.length}");
}

Future<void> _saveApproveOrderToHive(Map<String, dynamic> salesOrder) async {
  var approveOrderBox = await Hive.openBox('salesApprovalOrder');

  Map<String, dynamic> orderToSave = salesOrder;

  if (salesOrder.containsKey('data') &&
      salesOrder['data'] is List &&
      (salesOrder['data'] as List).isNotEmpty) {
    orderToSave = Map<String, dynamic>.from((salesOrder['data'] as List).first);
  }

  final saleOrderNo = orderToSave['saleOrderNo']?.toString();
  if (saleOrderNo == null) return;

  final exists = approveOrderBox.values.any((storedOrder) {
    if (storedOrder is Map<String, dynamic>) {
      return storedOrder['saleOrderNo']?.toString() == saleOrderNo;
    }
    return false;
  });

  if (!exists) {
    await approveOrderBox.add(orderToSave);
  }
}

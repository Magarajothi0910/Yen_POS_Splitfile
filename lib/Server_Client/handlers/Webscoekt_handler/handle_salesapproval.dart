import 'package:hive/hive.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';

Future<void> handleApprovalOrder(Map<String, dynamic>? salesOrder) async {
  if (salesOrder == null) {
    return;
  }

  // Step 0: Extract actual sales approval order
  Map<String, dynamic>? orderData;

  if (salesOrder.containsKey('salesApprovalOrder')) {
    final salesApprovalOrder = salesOrder['salesApprovalOrder'];
    if (salesApprovalOrder is Map && salesApprovalOrder.containsKey('data')) {
      final data = salesApprovalOrder['data'];
      if (data is Map) {
        orderData = Map<String, dynamic>.from(data);
      } else if (data is List && data.isNotEmpty && data.first is Map) {
        orderData = Map<String, dynamic>.from(data.first);
      }
    }
  }

  if (orderData == null) {
    return;
  }


  // Step 1: Save to Hive (with proper duplicate handling)
  await _saveOrUpdateApprovalOrder(orderData);

  // Step 2: Retrieve all saved approval orders
  final approvalOrders = await getSavedApprovalOrder();

  for (int i = 0; i < approvalOrders.length; i++) {
  }

  printHiveBoxDetails();
}

// ------------------------
// Save or update order in Hive
// ------------------------
Future<void> _saveOrUpdateApprovalOrder(Map<String, dynamic> orderData) async {
  var box = HiveManager.salesApprovalOrder;

  final saleOrderNo = orderData['saleOrderNo']?.toString();
  if (saleOrderNo == null || saleOrderNo.isEmpty) {
    return;
  }

  // Check for existing entry by saleOrderNo
  dynamic existingKey;
  for (var key in box.keys) {
    final storedOrder = box.get(key);
    if (storedOrder is Map) {
      final storedSaleOrderNo = storedOrder['saleOrderNo']?.toString();
      if (storedSaleOrderNo == saleOrderNo) {
        existingKey = key;
        break;
      }
    }
  }

  if (existingKey != null) {
    await box.put(existingKey, orderData);
  } else {
    await box.add(orderData);
  }

} // ------------------------

// Print Hive box full structure
// ------------------------
void printHiveBoxDetails() {
  var box = HiveManager.salesApprovalOrder;
  box.toMap().forEach((key, value) {
    if (value is Map) {
      value.forEach((k, v) {
      });
    } else {
    }
  });
}

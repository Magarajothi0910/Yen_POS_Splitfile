import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

String generateSalesOrderId(String branchCode, int sequenceNumber) {
  final yearSuffix = DateFormat('yy').format(DateTime.now());
  final sequenceStr = sequenceNumber.toString().padLeft(4, '0');
  return 'SO$branchCode$yearSuffix$sequenceStr';
}

Future<String?> fetchNextSalesOrderNumberFromHive(String prefix) async {
  // Open the Hive box for sales orders
  final salesOrderBox = await Hive.openBox('salesOrders');

  // Get the current count for the prefix or initialize it to 250000
  final currentCount = salesOrderBox.get(prefix) ?? 0000;

  // Increment to get the next count
  final nextCount = currentCount + 1;

  // Save the updated count back to Hive
  await salesOrderBox.put(prefix, nextCount);

  // Format the numeric part with leading zeros to ensure it is always six digits
  final formattedNumber = nextCount.toString().padLeft(4, '0');

  // Return the new sales order number in the format "prefix + formattedNumber"
  return '$prefix$formattedNumber';
}

Future<void> saveToApproveOrderToHive(Map<String, dynamic> data) async {
  // Save the sales approval order to the Hive database
  var modifyOrdersBox = await Hive.openBox('salesOrderToApprove');
  await modifyOrdersBox.add(data);
  print('Sales approval order saved to Hive: $data');
}

// Define a method to handle adding a customer to a sales order.
Future<void> saveSalesOrderAddCustomerToHive(Map<String, dynamic> data) async {
  // Save the sales order customer addition to the Hive database
  var salesOrderAddCustomerBox = await Hive.openBox('salesOrderAddCustomer');
  await salesOrderAddCustomerBox.add(data);
  debugPrint('Sales order customer addition saved to Hive: $data');
}

Future<void> saveSalesApprovalOrderToHive(Map<String, dynamic> data) async {
  var box = await Hive.openBox('salesApprovalOrder');
  await box.add(data);
  print("Sales approval order saved to Hive: $data");
}

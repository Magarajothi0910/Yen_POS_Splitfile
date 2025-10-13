// import 'dart:async';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:hive/hive.dart';

// class SyncService {
//   final String apiUrl = 'https://yenerp.com/orders/';
//   final String invoiceApiUrl = 'https://yenerp.com/fastapi/invoices/';

//   bool _isSyncing = false;

//   SyncService() {
//     Timer.periodic(const Duration(minutes: 10), (timer) async {
//       syncUnsyncedOrders();
//       await syncUnsyncedInvoices();
//       await patchEditedOrders();
//     });
//   }

//   Future<void> saveOrderToHive(Map<String, dynamic> order) async {
//     var orderBox = await Hive.openBox('ordersBox');
//     order['sync'] = 'No';
//     order['edit'] = 'No'; // Initialize edit field as "No" for new orders
//     await orderBox.add(order);
//     print('Order saved locally with sync: No');
//     print(order);

//     await syncUnsyncedOrders();
//   }

//   Future<void> saveInvoiceToHive(Map<String, dynamic> invoice) async {
//     var invoiceBox = await Hive.openBox('invoicesBox');
//     invoice['sync'] = 'No';
//     invoice['edit'] = 'No'; // Initialize edit field as "No" for new invoices
//     await invoiceBox.add(invoice);
//     print('Invoice saved locally with sync: No');
//     print(invoice);
//     print("Full data in invoiceBox: ${invoiceBox.toMap()}");

//     // Check connectivity and try to sync after saving locally
//     await syncUnsyncedInvoices();
//   }

//   Future<void> syncUnsyncedOrders() async {
//     print("Syncing unsynced orders...");
//     if (_isSyncing) return;
//     _isSyncing = true;

//     var orderBox = await Hive.openBox('ordersBox');
//     for (int i = 0; i < orderBox.length; i++) {
//       var orderData = orderBox.getAt(i);
//       if (orderData is String) {
//         orderData = jsonDecode(orderData) as Map<String, dynamic>;
//       }

//       if (orderData is Map<String, dynamic> && orderData['sync'] == 'No') {
//         bool success = await postOrder(orderData);
//         if (success) {
//           orderData['sync'] = 'Yes';
//           await orderBox.putAt(i, orderData);
//           print('Order ${orderData['hiveOrderId']} synced successfully.');
//         } else {
//           break; // Stop if a post fails
//         }
//       }
//     }
//     _isSyncing = false;
//     await patchEditedOrders();
//   }

//   Future<void> patchEditedOrders() async {
//     print(
//         "Checking orders to patch statuses or other fields if sync and edit are 'Yes'...");
//     var orderBox = await Hive.openBox('ordersBox');

//     for (int i = 0; i < orderBox.length; i++) {
//       var orderData = orderBox.getAt(i);
//       if (orderData is String) {
//         orderData = jsonDecode(orderData) as Map<String, dynamic>;
//       }
//       if (orderData is Map<String, dynamic> &&
//           orderData['sync'] == 'Yes' &&
//           orderData['edit'] == 'Yes') {
//         //  Case 1: fieldsEdited == "true" (Update quantities and cancelledQty)
//         if (orderData['fieldsEdited'] == 'true') {
//           final hiveOrderId = orderData['hiveOrderId'].toString();
//           print("Attempting to patch fields for hiveOrderId: $hiveOrderId");

//           // Patch quantities and cancelledQty
//           bool patchedFields =
//               await patchFieldsByHiveOrderId(hiveOrderId, orderData);

//           if (patchedFields) {
//             orderData['edit'] = 'No'; // Reset edit flag after successful patch
//             orderData['fieldsEdited'] = 'false';
//             await orderBox.putAt(i, orderData);
//             print('Order $hiveOrderId fields patched successfully.');
//           } else {
//             print('Failed to patch fields for $hiveOrderId');
//           }
//         }

//         // Case 2: statusEdited == "true" (Update status)
//         if (orderData['statusEdited'] == 'true' &&
//             orderData.containsKey('seathiveOrderId')) {
//           final seathiveOrderId = orderData['seathiveOrderId'].toString();
//           final status = orderData['status'];

//           print(
//               "Attempting to patch status for seathiveOrderId: $seathiveOrderId");

//           // Patch status
//           bool patchedStatus =
//               await patchOrderStatusWithRetry(seathiveOrderId, status);

//           if (patchedStatus) {
//             orderData['edit'] = 'No'; // Reset edit flag after successful patch
//             orderData['statusEdited'] = 'false';
//             await orderBox.putAt(i, orderData);
//             print(
//                 'Order status for $seathiveOrderId patched successfully to $status.');
//           } else {
//             print('Failed to patch status for $seathiveOrderId');
//           }
//         }
//       }
//     }
//   }

//   Future<bool> patchOrderStatusWithRetry(String seathiveOrderId, String status,
//       {int retries = 3}) async {
//     for (int attempt = 0; attempt < retries; attempt++) {
//       bool success =
//           await patchOrderStatusBySeathiveOrderId(seathiveOrderId, status);
//       if (success) {
//         return true;
//       } else {
//         print(
//             'Retrying patch request for $seathiveOrderId... Attempt ${attempt + 1} of $retries');
//       }
//     }
//     print(
//         'Failed to patch order status after $retries attempts for $seathiveOrderId.');
//     return false;
//   }

//   Future<bool> patchOrderStatusBySeathiveOrderId(
//       String seathiveOrderId, String status) async {
//     try {
//       final patchUrl =
//           Uri.parse('${apiUrl}patch-status/$seathiveOrderId?status=$status');
//       print('Patching order status at: $patchUrl');

//       final response = await http.patch(
//         patchUrl,
//         headers: {'Content-Type': 'application/json'},
//       );

//       if (response.statusCode == 200) {
//         print('Order status patched successfully for $seathiveOrderId.');
//         return true;
//       } else {
//         print(
//             'Failed to patch order status. Status code: ${response.statusCode}');
//         print('Response body: ${response.body}');
//         return false;
//       }
//     } catch (e) {
//       print('Error patching order status by seathiveOrderId: $e');
//       return false;
//     }
//   }

//   Future<bool> patchFieldsByHiveOrderId(
//       String hiveOrderId, Map<String, dynamic> fields) async {
//     try {
//       final patchUrl = Uri.parse('${apiUrl}patch-fields/$hiveOrderId');
//       Map<String, dynamic> patchData = {
//         'hiveOrderId': hiveOrderId,
//       };

//       if (fields.containsKey('quantities')) {
//         patchData['quantities'] = fields['quantities'];
//       }

//       if (fields.containsKey('cancelledQty')) {
//         patchData['cancelledQty'] = fields['cancelledQty'];
//       }
//       if (fields.containsKey('amounts')) {
//         patchData['amounts'] = fields['amounts'];
//       }
//       if (fields.containsKey('totalAmount')) {
//         patchData['totalAmount'] = fields['totalAmount'];
//       }
//       print('Patching fields for order at: $patchUrl');
//       print('Patch data: ${jsonEncode(patchData)}');

//       final response = await http.patch(
//         patchUrl,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(patchData),
//       );

//       if (response.statusCode == 200) {
//         print('Order fields patched successfully for $hiveOrderId.');
//         return true;
//       } else {
//         print(
//             'Failed to patch order fields. Status code: ${response.statusCode}');
//         print('Response body: ${response.body}');
//         return false;
//       }
//     } catch (e) {
//       print('Error patching order fields by hiveOrderId: $e');
//       return false;
//     }
//   }

//   Future<bool> postOrder(Map<String, dynamic> order) async {
//     try {
//       print('Posting order: ${jsonEncode(order)}');
//       final response = await http.post(
//         Uri.parse(apiUrl),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(order),
//       );

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         print('Order posted successfully.');
//         return true;
//       } else {
//         print('Failed to post order. Status code: ${response.statusCode}');
//         print('Response body: ${response.body}');
//         return false;
//       }
//     } catch (e) {
//       print('Error posting order: $e');
//       return false;
//     }
//   }

//   Future<bool> patchOrderTableAndSeat(
//       String seathiveOrderId, int table, String seat) async {
//     try {
//       final patchUrl = Uri.parse(
//           '${apiUrl}patch-table-seat/$seathiveOrderId?table=$table&seat=$seat');
//       Map<String, dynamic> patchData = {
//         'table': table,
//         'seat': seat,
//       };

//       print('Patching table and seat for order at: $patchUrl');
//       print('Patch data: ${jsonEncode(patchData)}');

//       final response = await http.patch(
//         patchUrl,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(patchData),
//       );

//       if (response.statusCode == 200) {
//         print(
//             'Order table and seat patched successfully for $seathiveOrderId.');
//         return true;
//       } else {
//         print(
//             'Failed to patch order table and seat. Status code: ${response.statusCode}');
//         print('Response body: ${response.body}');
//         return false;
//       }
//     } catch (e) {
//       print('Error patching order table and seat: $e');
//       return false;
//     }
//   }

//   Future<void> syncUnsyncedInvoices() async {
//     print("Syncing unsynced invoices...");
//     if (_isSyncing) return;
//     _isSyncing = true;

//     var invoiceBox = await Hive.openBox('invoicesBox');
//     for (int i = 0; i < invoiceBox.length; i++) {
//       var invoiceData = invoiceBox.getAt(i);
//       if (invoiceData is String) {
//         invoiceData = jsonDecode(invoiceData) as Map<String, dynamic>;
//       }

//       if (invoiceData is Map<String, dynamic> && invoiceData['sync'] == 'No') {
//         bool success = await postInvoice(invoiceData);
//         if (success) {
//           invoiceData['sync'] = 'Yes';
//           await invoiceBox.putAt(i, invoiceData);
//           print('Invoice ${invoiceData['hiveInvoiceId']} synced successfully.');
//         } else {
//           break; // Stop if a post fails
//         }
//       }
//     }
//     _isSyncing = false;
//   }

//   Future<bool> postInvoice(Map<String, dynamic> invoice) async {
//     try {
//       print('Posting invoice: ${jsonEncode(invoice)}');
//       invoice['cash'] = int.tryParse(invoice['cash']?.toString() ?? '') ?? 0;

//       invoice['card'] = int.tryParse(invoice['card']?.toString() ?? '') ?? 0;
//       invoice['upi'] = int.tryParse(invoice['upi']?.toString() ?? '') ?? 0;
//       final response = await http.post(
//         Uri.parse(invoiceApiUrl),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(invoice),
//       );

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         print('Invoice posted successfully.');
//         return true;
//       } else {
//         print('Failed to post invoice. Status code: ${response.statusCode}');
//         print('Response body: ${response.body}');
//         return false;
//       }
//     } catch (e) {
//       print('Error posting invoice: $e');
//       return false;
//     }
//   }
// }

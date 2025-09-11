// import 'dart:convert';
// import 'package:intl/intl.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:hive_flutter/hive_flutter.dart';

// import '../services/hive_service.dart';
// import '../services/loaddatafromHive.dart';

// Future<void> sendAllDataToClient(WebSocketChannel channel) async {
//   final orders = await loadOrdersFromHive();
//   final invoices = await loadInvoicesFromHive();
//   final preInvoices = await loadPreInvoicesFromHive(); // Optional if needed
//   var printerBox = await Hive.openBox('printerData');
//   final printerDetails = printerBox.values.toList();

//   final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
//   print("currentDate for all data $currentDate");

//   final filteredOrders = orders.where((order) {
//     final dateStr = order['date']?.toString();
//     if (dateStr == null || dateStr.isEmpty) {
//       print("Skipping order with missing date: $order");
//       return false;
//     }
//     try {
//       final orderDate = DateFormat('dd-MM-yyyy').parse(dateStr);
//       return DateFormat('dd-MM-yyyy').format(orderDate) == currentDate;
//     } catch (e) {
//       print("Error parsing order date: $dateStr - $e");
//       return false;
//     }
//   }).toList();

//   final filteredInvoices = invoices.where((invoice) {
//     final dateStr = invoice['invoiceDate']?.toString();
//     if (dateStr == null || dateStr.isEmpty) {
//       print("Skipping invoice with missing date: $invoice");
//       return false;
//     }
//     try {
//       final invoiceDate = DateFormat('dd-MM-yyyy').parse(dateStr);
//       return DateFormat('dd-MM-yyyy').format(invoiceDate) == currentDate;
//     } catch (e) {
//       print("Error parsing invoice date: $dateStr - $e");
//       return false;
//     }
//   }).toList();

//   print("filteredInvoices $filteredInvoices");

//   final allDataMessage = jsonEncode({
//     'action': 'allDataResponse',
//     'orders': filteredOrders,
//     'invoices': filteredInvoices,
//     // 'preInvoices': preInvoices, // Uncomment if you want to include
//     'printerDetails': printerDetails,
//   });

//   print("send invoices data to clients:$filteredInvoices");

//   channel.sink.add(allDataMessage);
// }

// import 'dart:convert';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:intl/intl.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

// import 'package:yen_pos/Global/globals_data.dart';
// import 'hive_service.dart';

// final List<Map<String, dynamic>> _receivedData = [];

// Future<void> handleNewClientConnected(
//   Map<String, dynamic> data,
//   WebSocketChannel channel,
// ) async {
//   try {
//     final deviceCode = data['deviceCode'];
//     print("🔌 New client connected: $deviceCode");

//     // Ensure deviceData box is open
//     if (!Hive.isBoxOpen('deviceData')) {
//       await Hive.openBox('deviceData');
//       print("📦 Opened deviceData box");
//     }
//     var deviceBox = Hive.box('deviceData');
//     await deviceBox.put(deviceCode, {
//       'connectedAt': DateTime.now().toIso8601String(),
//       'status': 'active',
//     });
//     print("💾 Device stored in Hive: $deviceCode");

//     await sendReceivedDataToNewClient(channel);

//     // Send acknowledgment back to the client
//     var response = jsonEncode({
//       'action': 'deviceCodeStored',
//       'status': 'success',
//       'message': 'Device code $deviceCode stored successfully.',
//     });

//     try {
//       channel.sink.add(response);
//       print("✅ Acknowledgment sent to $deviceCode");
//     } catch (e, st) {
//       print("❌ Failed to send acknowledgment to $deviceCode: $e\n$st");
//     }
//   } catch (e, st) {
//     print("⚠️ Error in handleNewClientConnected: $e\n$st");
//   }
// }

// Future<void> sendReceivedDataToNewClient(WebSocketChannel channel) async {
//   final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

//   for (var data in _receivedData) {
//     try {
//       if (data['action'] == 'seat_transfer' ||
//           (data.containsKey('date') &&
//               data['date'] == currentDate &&
//               (data['status'] == "active" ||
//                   data['status'] == "confirm" ||
//                   data['status'] == "invoiced" ||
//                   data['status'] == "cancelled"))) {
//         final message = jsonEncode({'action': 'receivedData', 'data': data});
//         channel.sink.add(message);
//         print("📤 Sent receivedData to new client: ${data['action']}");
//       } else if (data['action'] == 'printerDetails') {
//         final printerMessage = jsonEncode({
//           'action': 'printerDetails',
//           'name': data['name'],
//           'ipAddress': data['ipAddress'],
//           'type': data['type'],
//           'items': data['items'],
//           'orderSource': data['orderSource'],
//         });
//         channel.sink.add(printerMessage);
//         print("🖨️ Sent printerDetails to new client: ${data['name']}");
//       }
//     } catch (e, st) {
//       print("❌ Error sending data to new client: $e\n$st");
//     }
//   }
// }

// Future<void> sendDataToClientsKOT(Map<String, dynamic> data) async {
//   try {
//     print("📡 Broadcasting data to clients: $data");
//     final before = DateTime.now();
//     final jsonData = jsonEncode(data);

//     final clientsCopy = Set<WebSocketChannel>.from(clients);
//     final failedClients = <WebSocketChannel>{};

//     for (var client in clientsCopy) {
//       bool success = false;

//       for (int retry = 0; retry < 3 && !success; retry++) {
//         try {
//           client.sink.add(jsonData);

//           // print("jsonData $jsonData");
//           await Future.delayed(const Duration(milliseconds: 50));
//           success = true;
//           print("✅ Data sent successfully to client .... $client");
//         } catch (e, st) {
//           print("⚠️ Send failed to client $client (retry $retry): $e\n$st");
//           await Future.delayed(const Duration(milliseconds: 200));
//         }
//       }

//       if (!success) {
//         print("❌ Removing client after 3 failed retries: $client");
//         failedClients.add(client);
//         try {
//           await client.sink.close();
//           print("🛑 Closed client sink: $client");
//         } catch (_) {
//           print("⚠️ Failed to close client sink, skipping");
//         }
//       }
//     }

//     clients.removeAll(failedClients);
//     final after = DateTime.now();
//     print(
//       "📤 Data sent to ${clients.length} clients in ${after.difference(before).inMilliseconds} ms",
//     );
//   } catch (e, st) {
//     print("⚠️ sendDataToClients encountered error: $e\n$st");
//   }
// }

// Future<void> handleRemovePrinter(Map<String, dynamic> data) async {
//   try {
//     final printerName = data['printerName'];
//     if (printerName == null) return;

//     _receivedData.removeWhere(
//       (entry) =>
//           entry['action'] == 'printerDetails' && entry['name'] == printerName,
//     );
//     var printerBox = Hive.box('printerData');
//     await printerBox.delete(printerName);

//     print("🗑️ Removed printer: $printerName");

//     await sendDataToClientsKOT({
//       'action': 'removePrinter',
//       'name': printerName,
//     });

//     final updatedPrinters = printerBox.values.toList();
//     await sendDataToClientsKOT({
//       'action': 'allPrinterDetails',
//       'printers': updatedPrinters,
//     });
//     print("📄 Updated printer list sent to clients");
//   } catch (e, st) {
//     print("⚠️ Error in handleRemovePrinter: $e\n$st");
//   }
// }

// Future<void> sendAllDataToClient(
//   WebSocketChannel channel, {
//   required bool isUpiEnabled,
// }) async {
//   try {
//     final orders = await loadOrdersFromHive();
//     final invoices = await loadInvoicesFromHive();
//     final printerDetails = await loadPrintersFromHive();
//     print("📦 Loaded orders, invoices, printer details, and UPI state");

//     final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

//     final filteredOrders = orders.where((order) {
//       try {
//         final orderDate = DateFormat('dd-MM-yyyy').parse(order['date']);
//         return DateFormat('dd-MM-yyyy').format(orderDate) == currentDate;
//       } catch (_) {
//         return false;
//       }
//     }).toList();

//     final filteredInvoices = invoices.where((invoice) {
//       try {
//         final invoiceDate = DateFormat(
//           'dd-MM-yyyy',
//         ).parse(invoice['invoiceDate']);
//         return DateFormat('dd-MM-yyyy').format(invoiceDate) == currentDate;
//       } catch (_) {
//         return false;
//       }
//     }).toList();

//     final Map<String, Map<String, dynamic>> uniqueInvoices = {};
//     for (var invoice in filteredInvoices) {
//       final id = invoice['hiveInvoiceId']?.toString();
//       if (id != null) uniqueInvoices[id] = invoice;
//     }
//     final dedupedInvoices = uniqueInvoices.values.toList();

//     final allDataMessage = jsonEncode({
//       'action': 'allDataResponse',
//       'orders': filteredOrders,
//       'invoices': dedupedInvoices,
//       'printers': printerDetails,
//       'upiState': isUpiEnabled,
//       'tables': tables,
//     });

//     channel.sink.add(allDataMessage);
//     print("📤 All data + UPI state sent to new client");
//   } catch (e, st) {
//     print("⚠️ Error in sendAllDataToClient: $e\n$st");
//   }
// }

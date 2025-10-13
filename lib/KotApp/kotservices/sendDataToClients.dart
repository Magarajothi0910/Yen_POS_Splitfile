import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'hive_service.dart';

final List<Map<String, dynamic>> _receivedData = [];

Future<void> handleNewClientConnected(
    Map<String, dynamic> data, WebSocketChannel channel) async {
  final deviceCode = data['deviceCode'];

  // Store the device information in Hive
  var deviceBox = await Hive.openBox('deviceData');
  await deviceBox.put(deviceCode, {
    'connectedAt': DateTime.now().toIso8601String(),
    'status': 'active',
  });

  await sendReceivedDataToNewClient(channel);

  // Optionally send an acknowledgment back to the client
  var response = jsonEncode({
    'action': 'deviceCodeStored',
    'status': 'success',
    'message': 'Device code $deviceCode stored successfully.',
  });
  channel.sink.add(response);
}

Future<void> sendReceivedDataToNewClient(WebSocketChannel channel) async {
  final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  // Iterate through _receivedData and send relevant items to the new client
  for (var data in _receivedData) {
    // Check if the item is an order with a matching date and status
    if (data['action'] == 'transfer_seat' ||
        (data.containsKey('date') &&
            data['date'] == currentDate &&
            (data['status'] == "active" ||
                data['status'] == "confirm" ||
                data['status'] == "invoiced" ||
                data['status'] == "cancelled"))) {
      // Prepare the message for order data
      final receivedDataMessage = jsonEncode({
        'action': 'receivedData',
        'data': data,
      });

      channel.sink.add(receivedDataMessage);
    } else if (data['action'] == 'printerDetails') {
      // If the item is printer details, send it separately
      final printerDetailsMessage = jsonEncode({
        'action': 'printerDetails',
        'name': data['name'],
        'ipAddress': data['ipAddress'],
        'type': data['type'],
        'items': data['items'],
        'orderSource': data['orderSource'],
      });

      channel.sink.add(printerDetailsMessage);
    } else {
      // If data doesn't match, print a message for debugging
    }
  }
}

int serverSendCount = 0;
int clientSendCount = 0;
int clientReceiveCount = 0;
final Map<String, int> serverSendTracker = {};
final Map<String, int> clientSendTracker = {};
final Map<String, int> clientReceiveTracker = {};
Map<WebSocketChannel, Set<String>> clientPatchLog = {};
// ---------------------------------------------------------
int sendDataToClients(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) {
  final soNo = data['saleOrderNo'] ?? 'UNKNOWN';

  final jsonString = jsonEncode(data);
  int sentCount = 0;

  for (var client in clients) {
    clientPatchLog[client] ??= {};
    if (!clientPatchLog[client]!.contains(soNo)) {
      client.sink.add(jsonString);
      clientPatchLog[client]!.add(soNo);
      sentCount++;
    }
  }

 
  return sentCount;
}

void handleRemovePrinter(
    Map<String, dynamic> data, Set<WebSocketChannel> clients) async {
  final printerName = data['printerName'];

  if (printerName != null) {
    // Update the local _receivedData by removing the printer with the matching name
    _receivedData.removeWhere((entry) =>
        entry['action'] == 'printerDetails' && entry['name'] == printerName);

    // Save the updated printer list to Hive
    var printerBox = await Hive.openBox('printerData');
    await printerBox.delete(printerName);

    // Broadcast the removal to all clients
    sendDataToClients({
      'action': 'removePrinter',
      'printerName': printerName,
    }, clients);

    // Optionally, broadcast the updated list of printers to all clients
    final updatedPrinters = printerBox.values.toList();
    sendDataToClients({
      'action': 'allPrinterDetails',
      'printers': updatedPrinters,
    }, clients);
  } else {}
}

Future<void> sendAllDataToClient(WebSocketChannel channel) async {
  // Fetch all orders, invoices, and printer details
  final orders = await loadOrdersFromHive();
  final invoices = await loadInvoicesFromHive();
  final preInvoices = await loadPreInvoicesFromHive();
  var printerBox = await Hive.openBox('printerData');
  final printerDetails = printerBox.values.toList();

  // Get the current date in dd-MM-yyyy format
  final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  // Filter data by the current date
  final filteredOrders = orders.where((order) {
    try {
      final orderDate = DateFormat('dd-MM-yyyy').parse(order['date']);
      return DateFormat('dd-MM-yyyy').format(orderDate) == currentDate;
    } catch (e) {
      return false;
    }
  }).toList();

  final filteredInvoices = invoices.where((invoice) {
    try {
      final invoiceDate =
          DateFormat('dd-MM-yyyy').parse(invoice['invoiceDate']);
      return DateFormat('dd-MM-yyyy').format(invoiceDate) == currentDate;
    } catch (e) {
      return false;
    }
  }).toList();

  // Deduplicate invoices using a Map keyed by 'hiveInvoiceId'
  final Map<String, Map<String, dynamic>> uniqueInvoices = {};
  for (var invoice in filteredInvoices) {
    final id = invoice['hiveInvoiceId']?.toString();
    if (id != null) {
      uniqueInvoices[id] = invoice;
    }
  }
  final dedupedInvoices = uniqueInvoices.values.toList();

  // Prepare the full data message to be sent
  final allDataMessage = jsonEncode({
    'action': 'allDataResponse',
    'orders': filteredOrders,
    'invoices': dedupedInvoices,
    'printerDetails': printerDetails,
  });

  channel.sink.add(allDataMessage);
}

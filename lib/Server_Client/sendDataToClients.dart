import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

void sendDataToClients(
    Map<String, dynamic> data, Set<WebSocketChannel> clients) {
  final jsonData = jsonEncode(data);

  for (var client in clients) {
    bool success = false;
    int retryCount = 0;

    while (!success && retryCount < 3) {
      try {
        client.sink.add(jsonData);
        success = true;
      } catch (e) {
        retryCount++;
      }
    }

    if (!success) {
      clients.remove(client);
    }
  }
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

  } else {
  }
}

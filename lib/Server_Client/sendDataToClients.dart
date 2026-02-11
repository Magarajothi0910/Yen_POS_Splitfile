import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Global/globals_data.dart';

final List<Map<String, dynamic>> _receivedData = [];

Future<void> handleNewClientConnected(
  Map<String, dynamic> data,
  WebSocketChannel channel,
) async {
  // Safely extract deviceCode
  final dynamic rawDeviceCode = data['deviceCode'];

  // 1. Null or missing check
  if (rawDeviceCode == null) {
    channel.sink.add(
      jsonEncode({
        'action': 'error',
        'message': 'deviceCode is missing or null',
      }),
    );
    return;
  }

  // 2. Convert to String (Hive loves String keys)
  // This works whether it's String, int, double, etc.
  final String deviceCode = rawDeviceCode.toString().trim();

  // 3. Optional: reject empty strings
  if (deviceCode.isEmpty) {
    channel.sink.add(
      jsonEncode({'action': 'error', 'message': 'deviceCode is empty'}),
    );
    return;
  }

  try {
    final deviceBox = await Hive.openBox('deviceData');

    // Now 100% safe: key is always a String
    await deviceBox.put(deviceCode, {
      'connectedAt': DateTime.now().toIso8601String(),
      'status': 'active',
    });

    // Send existing data to the newly connected device
    await sendReceivedDataToNewClient(channel);

    // Success response
    channel.sink.add(
      jsonEncode({
        'action': 'deviceCodeStored',
        'status': 'success',
        'message': 'Device $deviceCode connected and stored.',
      }),
    );
  } catch (e, stackTrace) {
    developer.log('Hive put failed: $e', stackTrace: stackTrace);
    channel.sink.add(
      jsonEncode({
        'action': 'error',
        'message': 'Failed to save device info: $e',
      }),
    );
  }
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

/// Sends data safely to all connected WebSocketChannel clients
void sendDataToClients(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients, {
  WebSocketChannel? sender,
}) {
  final message = jsonEncode(data);

  final List<WebSocketChannel> disconnected = [];

  for (var client in clients) {
    try {
      client.sink.add(message);
    } catch (e) {
      disconnected.add(client);
    }
  }

  // cleanup
  if (disconnected.isNotEmpty) {
    for (var dead in disconnected) {
      clients.remove(dead);
    }
  }
}

// void sendDataToClients(Map<String, dynamic> data ,Set<WebSocketChannel> clients) {
//   final message = jsonEncode(data);

//   debugPrint(
//     '📤 Server sending → clients=${clients.length}',
//   );

//   final List<WebSocketChannel> disconnected = [];

//   for (final client in clients.toList()) {
//     try {
//       client.sink.add(message);
//     } catch (_) {
//       disconnected.add(client);
//     }
//   }

//   for (final dead in disconnected) {
//     clients.remove(dead);
//   }
// }

void handleRemovePrinter(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  final printerName = data['printerName'];

  if (printerName != null) {
    // Update the local _receivedData by removing the printer with the matching name
    _receivedData.removeWhere(
      (entry) =>
          entry['action'] == 'printerDetails' && entry['name'] == printerName,
    );

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

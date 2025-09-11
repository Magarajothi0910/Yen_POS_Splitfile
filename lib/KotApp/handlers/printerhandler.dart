import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../kotservices/hive_service.dart';
import '../kotservices/sendDataToClients.dart';

Future<void> handlePrinterDetails(
    Map<String, dynamic> data, Set<WebSocketChannel> clients) async {
  if (!data.containsKey('printer')) return;

  final printer = data['printer'];
  final printerName = printer['name'];
  final updatedItems = printer['items'];

  // Save the updated printer details to Hive
  await savePrinterDetailsToHive({
    'action': 'printerDetails',
    'name': printerName,
    'ipAddress': printer['ipAddress'],
    'type': printer['type'],
    'items': updatedItems,
    'orderSource': printer['orderSource'],
  });

  // Broadcast the updated printer details to all clients
  sendDataToClients({
    'action': 'updatePrinterItems',
    'printer': {
      'name': printerName,
      'ipAddress': printer['ipAddress'],
      'type': printer['type'],
      'items': updatedItems,
    }
  }, clients);
}

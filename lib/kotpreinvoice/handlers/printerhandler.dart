
import '../services/hive_service.dart';
import '../services/sendDataToClients.dart';

Future<void> handlePrinterDetails(
  Map<String, dynamic> data,
  //Set<WebSocketChannel> clients
) async {
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
  sendDataToClientsKOT({
    'action': 'updatePrinterItems',
    'printer': {
      'name': printerName,
      'ipAddress': printer['ipAddress'],
      'type': printer['type'],
      'items': updatedItems,
    }
  });
}

// on_data_received_handler.dart

Future<void> onDataReceivedHandler(
  Map<String, dynamic> data,
  Function(Map<String, dynamic>) sendDataToClients,
  Function(Map<String, dynamic>) handleRemovePrinter,
  List<Map<String, dynamic>> receivedData,
) async {
  if (data.isEmpty) return;

  if (data['action'] == 'seat_tapped' || data['action'] == 'seat_returned') {
    sendDataToClients(data);
  }

  if (data['action'] == 'removePrinter') {
    handleRemovePrinter(data);
  }

  receivedData.add(data); // You may need to notify listeners depending on use
}

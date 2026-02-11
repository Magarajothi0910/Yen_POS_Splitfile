import 'dart:convert';
import 'package:yen_pos/Server_Client/websocketService.dart';

/// Sends a sales order to the server via shared WebSocketService.
/// Includes detailed logs for debugging connection and payload issues.
Future<void> sendataToServer(Map<String, dynamic> salesOrderData) async {
  final wsService = WebSocketService.instance;

  // Check WebSocket connection status

  if (wsService.channel == null || wsService.channel!.closeCode != null) {
    await wsService.reconnect();

    // Wait until connection is established
    int attempts = 0;
    int maxAttempts = 5;

    while ((wsService.channel == null ||
            wsService.channel!.closeCode != null) &&
        attempts < maxAttempts) {
      attempts++;
      await Future.delayed(Duration(seconds: 1));
    }

    // Final connection check
    if (wsService.channel == null || wsService.channel!.closeCode != null) {
      throw Exception("WebSocket connection unavailable after retries.");
    } else {}
  } else {}

  try {
    // Log key data fields for debugging
    if (salesOrderData.containsKey('saleOrderNo')) {}
    if (salesOrderData.containsKey('action')) {}

    // Show first 3 data entries for debugging
    salesOrderData.entries.take(3).forEach((entry) {});
    if (salesOrderData.length > 3) {}

    // Encode to JSON
    final jsonData = jsonEncode(salesOrderData);

    // Decode back to verify
    final decodedData = jsonDecode(jsonData);

    // Send via WebSocket
    wsService.sendMessage(decodedData);

    // Log transmission completion
    if (salesOrderData.containsKey('saleOrderNo')) {}
  } catch (e, st) {
    // Log the data that failed to send for debugging

    // Try to show problematic data
    try {
      jsonEncode(salesOrderData);
    } catch (jsonError) {}

    rethrow;
  } finally {}
}

import 'dart:convert';
import 'package:yenpos/Server_Client/websocketService.dart';

/// Sends a sales order to the server via shared WebSocketService.
/// Includes detailed logs for debugging connection and payload issues.
Future<void> sendataToServer(Map<String, dynamic> salesOrderData) async {

  final wsService = WebSocketService.instance;

  // Wait until connected
  if (wsService.channel == null || wsService.channel!.closeCode != null) {
    await wsService.reconnect();

    // Wait until connection is established
    int attempts = 0;
    while ((wsService.channel == null ||
            wsService.channel!.closeCode != null) &&
        attempts < 5) {
      await Future.delayed(Duration(seconds: 1));
      attempts++;
    }

    if (wsService.channel == null || wsService.channel!.closeCode != null) {
      throw Exception("WebSocket connection unavailable after retries.");
    }
  }

  try {
    final jsonData = jsonEncode(salesOrderData);
    final decodedData = jsonDecode(jsonData);

    wsService.sendMessage(decodedData);

  } catch (e, st) {
    rethrow;
  } finally {
  }
}

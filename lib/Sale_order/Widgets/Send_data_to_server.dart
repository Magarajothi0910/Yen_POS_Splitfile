import 'dart:convert';
import 'package:yenpos/Server_Client/websocketService.dart';

/// Sends a sales order to the server via shared WebSocketService.
/// Includes detailed logs for debugging connection and payload issues.
Future<void> sendataToServer(Map<String, dynamic> salesOrderData) async {
  print("🔹 [sendSalesOrderDataToServer] --- STARTED ---");

  final wsService = WebSocketService.instance;

  // Wait until connected
  if (wsService.channel == null || wsService.channel!.closeCode != null) {
    print("⚠️ WebSocket not connected, attempting to connect...");
    await wsService.reconnect();

    // Wait until connection is established
    int attempts = 0;
    while ((wsService.channel == null ||
            wsService.channel!.closeCode != null) &&
        attempts < 5) {
      await Future.delayed(Duration(seconds: 1));
      attempts++;
      print("⏳ Waiting for WebSocket connection... attempt $attempts");
    }

    if (wsService.channel == null || wsService.channel!.closeCode != null) {
      throw Exception("WebSocket connection unavailable after retries.");
    }
  }

  try {
    final jsonData = jsonEncode(salesOrderData);
    final decodedData = jsonDecode(jsonData);

    wsService.sendMessage(decodedData);

    print("✅ Data sent successfully via WebSocket.");
    print("📤 Payload summary:");
    print("   → Type: ${decodedData['type'] ?? 'N/A'}");
    print(
      "   → Sales Order No: ${decodedData['data']?['saleOrderNo'] ?? 'N/A'}",
    );
  } catch (e, st) {
    print("❌ Exception sending sales order: $e");
    print(st);
    rethrow;
  } finally {
    print("🏁 [sendSalesOrderDataToServer] --- COMPLETED ---");
  }
}

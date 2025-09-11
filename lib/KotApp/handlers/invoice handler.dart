import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/globals.dart';
import '../kotservices/Token_service.dart';
import '../kotservices/sendDataToClients.dart';
import '../kotservices/hive_service.dart';
import '../kotservices/sync_service.dart';

final SyncServiceKot _syncService = SyncServiceKot();
Future<void> handleInvoice(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  print("🚀 [handleInvoice] Called with data: $data");

  try {
    final salesOrderRaw = data['salesOrderId'];
    print("ℹ️ [handleInvoice] Extracted salesOrderRaw: $salesOrderRaw");

    // Validate salesOrderRaw
    if (salesOrderRaw is! Map<String, dynamic>) {
      print("❌ [handleInvoice] salesOrderId is not a valid Map.");
      return;
    }

    final branchName = salesOrderRaw['branchName'];
    final date = salesOrderRaw['invoiceDate'];
    final time = salesOrderRaw['invoiceTime'];
    final status = salesOrderRaw['status'] ?? 'Unknown';

    print(
        "📌 [handleInvoice] branchName: $branchName | date: $date | time: $time | status: $status");

    // Generate invoice only if branchName is valid
    if (branchName != null) {
      final hiveInvoiceId = await generatehiveInvoiceId(branchName);
      print("✅ [handleInvoice] Generated hiveInvoiceId: $hiveInvoiceId");

      salesOrderRaw['orderInvoiceNo'] = hiveInvoiceId;
    } else {
      print(
          "⚠️ [handleInvoice] branchName is null. Skipping invoice ID generation.");
    }

    // Save invoice in Hive (local database)
    print("💾 [handleInvoice] Saving invoice to Hive...");
    await savePosInvoiceToHive(data);

    print("💾 [handleInvoice] Saving invoice via SyncServiceKot...");
    await _syncService.savePosInvoiceToHive(data);

    // Notify clients via WebSocket
    print("📡 [handleInvoice] Sending invoice data to clients...");
    sendDataToClients({
      'action': 'invoiceGenerated',
      'invoice': data,
    }, clients);

    print("🎉 [handleInvoice] Invoice handling completed successfully.");
  } catch (e, stacktrace) {
    print("❌ [handleInvoice] Error: $e");
    print("🛑 Stacktrace: $stacktrace");
  }
}

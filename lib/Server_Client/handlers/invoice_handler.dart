import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Server_Client/handlers/Token_service.dart';
import 'package:yenpos/Server_Client/hive_service.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart';
import 'package:yenpos/Server_Client/sync_service.dart';

final SyncService _syncService = SyncService();

Future<void> handleInvoice(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {
    print("🧾 handleInvoice called with data: ${jsonEncode(data)}");

    // ✅ Validate salesOrderId
    final salesOrderRaw = data['salesOrderId'];
    if (salesOrderRaw is! Map<String, dynamic>) {
      print("❌ Invalid salesOrderId format in data: ${data.keys}");
      return;
    }

    print("✅ salesOrderRaw extracted successfully.");

    final branchName = salesOrderRaw['branchName'];
    final aliasName = salesOrderRaw['aliasName'];
    final date = salesOrderRaw['invoiceDate'];
    final time = salesOrderRaw['invoiceTime'];
    final status = salesOrderRaw['status'] ?? 'Unknown';

    print(
      "🧩 Invoice details — Branch: $branchName | Alias: $aliasName | Date: $date | Time: $time | Status: $status",
    );

    // ✅ Generate Hive invoice ID
    if (branchName != null) {
      final hiveInvoiceId = await generateInvoiceId(aliasName);
      salesOrderRaw['invoiceNo'] = hiveInvoiceId;
      print("✅ Generated Hive Invoice ID: $hiveInvoiceId");
    } else {
      print("⚠️ Branch name is null, cannot generate Hive Invoice ID");
    }

    // ✅ Save invoice locally
    print("💾 Saving invoice to local Hive...");
    await savePosInvoiceToHive(data);
    // await _syncService.savePosInvoiceToHive(data);
    print("✅ Invoice saved locally.");

    // ✅ STOCK DECREASE LOGIC
    try {
      print("📦 Processing stock decrease...");
      final varianceCodesRaw = salesOrderRaw['varianceitemCode'];
      final varianceNamesRaw = salesOrderRaw['varianceName'];
      final qtyRaw = salesOrderRaw['qty'];

      if (varianceCodesRaw == null ||
          varianceNamesRaw == null ||
          qtyRaw == null) {
        print("⚠️ Stock decrease skipped — missing fields");
      } else {
        // 🛡 Convert to safe lists
        final varianceCodes =
            (varianceCodesRaw is List ? varianceCodesRaw : [varianceCodesRaw])
                .where((e) => e != null)
                .map((e) => e.toString())
                .toList();

        final varianceNames =
            (varianceNamesRaw is List ? varianceNamesRaw : [varianceNamesRaw])
                .where((e) => e != null)
                .map((e) => e.toString())
                .toList();

        final stockUpdates = (qtyRaw is List ? qtyRaw : [qtyRaw])
            .where((e) => e != null)
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .toList();

        // ✅ Ensure same length
        final int minLength = [
          varianceCodes.length,
          varianceNames.length,
          stockUpdates.length,
        ].reduce((a, b) => a < b ? a : b);

        final trimmedCodes = varianceCodes.take(minLength).toList();
        final trimmedNames = varianceNames.take(minLength).toList();
        final trimmedQty = stockUpdates.take(minLength).toList();

        print("✅ Decreasing stock for ${trimmedCodes.length} items...");
        await decreaseLocalHiveStock(
          clients: clients,
          branchAlias: aliasName ?? 'Unknown',
          varianceCodes: trimmedCodes,
          varianceNames: trimmedNames,
          stockUpdates: trimmedQty,
        );
        print("✅ Stock successfully decreased.");
      }
    } catch (e, st) {
      print("❌ Error while decreasing stock: $e\n$st");
    }

    // ✅ Notify connected WebSocket clients
    final clientData = {'action': 'invoiceGenerated', 'invoice': data};
    sendDataToClients(clientData, clients);
    print("📢 WebSocket clients notified about invoice generation.");

    // ✅ POST invoice to API (send only salesOrderRaw)
    print("🌐 Sending invoice data to API...");
    bool success = await _syncService.postInvoiceOrder({
      "data": [salesOrderRaw], // 👈 Only the invoice data is passed
    });

    if (success) {
      print("✅ Invoice successfully synced with API.");
    } else {
      print("⚠️ Invoice sync failed, will retry later.");
    }
  } catch (e, stacktrace) {
    print("❌ Exception in handleInvoice: $e\n$stacktrace");
  }
}

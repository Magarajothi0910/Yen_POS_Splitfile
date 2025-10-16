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
  print("🚀 [handleInvoice] Function called with raw data: $data");

  try {
    print("🔍 [Step 1] Validating 'salesOrderId' in received data...");

    // ✅ Validate salesOrderId
    final salesOrderRaw = data['salesOrderId'];
    if (salesOrderRaw is! Map<String, dynamic>) {
      print(
          "❌ [Error] 'salesOrderId' is missing or invalid (expected Map). Received: ${data['salesOrderId']}");
      return;
    }

    print("✅ [Step 1 Complete] 'salesOrderId' validated successfully.");
    print("📦 Extracted salesOrderRaw data: $salesOrderRaw");

    print(
        "🧾 [Step 2] Extracting invoice details (branch, alias, date, time, status)...");

    final branchName = salesOrderRaw['branchName'];
    final aliasName = salesOrderRaw['aliasName'];
    final date = salesOrderRaw['invoiceDate'];
    final time = salesOrderRaw['invoiceTime'];
    final status = salesOrderRaw['status'] ?? 'Unknown';

    print("📍 [Invoice Details]");
    print("   ├─ Branch Name : $branchName");
    print("   ├─ Alias Name  : $aliasName");
    print("   ├─ Invoice Date: $date");
    print("   ├─ Invoice Time: $time");
    print("   └─ Status      : $status");

    // ✅ Generate Hive invoice ID
    if (branchName != null) {
      print(
          "🔢 [Step 3] Generating Hive Invoice ID for branch: $branchName...");
      final hiveInvoiceId = await generatehiveInvoiceId(branchName);
      salesOrderRaw['orderInvoiceNo'] = hiveInvoiceId;
      print("✅ [Step 3 Complete] Hive Invoice ID generated: $hiveInvoiceId");
    } else {
      print(
          "⚠️ [Warning] 'branchName' is null. Skipping Hive Invoice ID generation.");
    }

    // ✅ Save invoice locally
    print("💾 [Step 4] Saving invoice to Hive local database...");
    await savePosInvoiceToHive(data);
    print(
        "✅ [Step 4 Complete] Invoice successfully saved via savePosInvoiceToHive()");

    print("🔄 [Step 5] Syncing invoice data through SyncServiceKot...");
    await _syncService.savePosInvoiceToHive(data);
    print("✅ [Step 5 Complete] Invoice successfully synced via SyncServiceKot");

    // ✅ STOCK DECREASE LOGIC
    print("📉 [Step 6] Starting local stock decrease logic...");

    try {
      print(
          "📦 Extracting item variance and quantity data for stock update...");
      final varianceCodesRaw = salesOrderRaw['varianceitemCode'];
      final varianceNamesRaw = salesOrderRaw['varianceName'];
      final qtyRaw = salesOrderRaw['qty'];

      print("🔹 Raw Variance Codes : $varianceCodesRaw");
      print("🔹 Raw Variance Names : $varianceNamesRaw");
      print("🔹 Raw Quantities     : $qtyRaw");

      if (varianceCodesRaw == null ||
          varianceNamesRaw == null ||
          qtyRaw == null) {
        print(
            "⚠️ Missing variance data (itemCode, varianceName, or qty). Skipping stock update.");
      } else {
        // 🛡 Convert to safe string/int lists, filtering nulls
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

        // ✅ Ensure list lengths match
        final int minLength = [
          varianceCodes.length,
          varianceNames.length,
          stockUpdates.length
        ].reduce((a, b) => a < b ? a : b);

        final trimmedCodes = varianceCodes.take(minLength).toList();
        final trimmedNames = varianceNames.take(minLength).toList();
        final trimmedQty = stockUpdates.take(minLength).toList();

        print("✅ [Stock Data Prepared]");
        print("   ├─ Variance Codes : $trimmedCodes");
        print("   ├─ Variance Names : $trimmedNames");
        print("   └─ Quantities     : $trimmedQty");

        print("⚙️ [Step 6.1] Calling decreaseLocalHiveStock()...");
        await decreaseLocalHiveStock(
          clients: clients,
          branchAlias: aliasName ?? 'Unknown',
          varianceCodes: trimmedCodes,
          varianceNames: trimmedNames,
          stockUpdates: trimmedQty,
        );

        print("✅ [Step 6 Complete] Stock decreased successfully.");
      }
    } catch (e, st) {
      print("🔥 [Error] Stock decrease operation failed.");
      print("🧩 Exception: $e");
      print("📜 Stacktrace:\n$st");
    }

    // ✅ Notify connected WebSocket clients
    print(
        "📡 [Step 7] Preparing to notify ${clients.length} connected WebSocket client(s)...");
    final clientData = {
      'action': 'invoiceGenerated',
      'invoice': data,
    };
    print("📤 Sending data to clients: $clientData");

    sendDataToClients(clientData, clients);
    print(
        "✅ [Step 7 Complete] Data successfully sent to all connected clients.");

    print(
        "🎉 [handleInvoice] ✅ All steps completed successfully for invoice: ${salesOrderRaw['orderInvoiceNo']}");
  } catch (e, stacktrace) {
    print("❌ [handleInvoice] A fatal error occurred while processing invoice.");
    print("🧩 Exception: $e");
    print("📜 Stacktrace:\n$stacktrace");
  }
}

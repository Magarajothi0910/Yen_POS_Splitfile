import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenposapp/Server_Client/handlers/Token_service.dart';
import 'package:yenposapp/Server_Client/hive_service.dart';
import 'package:yenposapp/Server_Client/sendDataToClients.dart';
import 'package:yenposapp/Server_Client/stockupdateService.dart';
import 'package:yenposapp/Server_Client/sync_service.dart';

final SyncService _syncService = SyncService();

Future<void> handleInvoice(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {

  try {

    // ✅ Validate salesOrderId
    final salesOrderRaw = data['salesOrderId'];
    if (salesOrderRaw is! Map<String, dynamic>) {
      return;
    }



    final branchName = salesOrderRaw['branchName'];
    final aliasName = salesOrderRaw['aliasName'];
    final date = salesOrderRaw['invoiceDate'];
    final time = salesOrderRaw['invoiceTime'];
    final status = salesOrderRaw['status'] ?? 'Unknown';


    // ✅ Generate Hive invoice ID
    if (branchName != null) {
      final hiveInvoiceId = await generatehiveInvoiceId(branchName);
      salesOrderRaw['orderInvoiceNo'] = hiveInvoiceId;
    } else {
    }

    // ✅ Save invoice locally
    await savePosInvoiceToHive(data);

    await _syncService.savePosInvoiceToHive(data);

    // ✅ STOCK DECREASE LOGIC

    try {
      final varianceCodesRaw = salesOrderRaw['varianceitemCode'];
      final varianceNamesRaw = salesOrderRaw['varianceName'];
      final qtyRaw = salesOrderRaw['qty'];


      if (varianceCodesRaw == null ||
          varianceNamesRaw == null ||
          qtyRaw == null) {
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


        await decreaseLocalHiveStock(
          clients: clients,
          branchAlias: aliasName ?? 'Unknown',
          varianceCodes: trimmedCodes,
          varianceNames: trimmedNames,
          stockUpdates: trimmedQty,
        );

      }
    } catch (e, st) {
    }

    // ✅ Notify connected WebSocket clients
    final clientData = {
      'action': 'invoiceGenerated',
      'invoice': data,
    };

    sendDataToClients(clientData, clients);

  } catch (e, stacktrace) {
  }
}

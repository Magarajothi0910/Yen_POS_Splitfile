import 'package:flutter/material.dart';

import '../services/Token_service.dart';
import '../services/sendDataToClients.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';

// ignore: non_constant_identifier_names
final SyncServiceKot _SyncServiceKot = SyncServiceKot();

Future<void> handleInvoiceKOT(
  Map<String, dynamic> data,
  // Set<WebSocketChannel> clients,
) async {
  print("validateInvoiceData: $data");
  final branchName = data['branchName'];
  final date = data['invoiceDate'];
  final time = data['invoiceTime'];

  if (branchName != null && date != null && time != null) {
    data['hiveInvoiceId'] = await generatehiveInvoiceId(branchName);
  }
  debugPrint("Generated hiveInvoiceId: ${data['hiveInvoiceId']}");
  sendDataToClientsKOT({
    'action': 'invoiceGeneratedKOT',
    'invoiceKOT': data,
  });
  debugPrint("Invoice data sent to clients: $data");
  await saveKotInvoiceToHive(data);
  await _SyncServiceKot.saveKotInvoiceToHive(data);
}

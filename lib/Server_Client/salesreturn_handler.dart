import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Server_Client/handlers/invoice_handler.dart'
    hide getStockDeductionAmount;
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/Server_Client/stockupdateService.dart';

Future<void> handleSalesReturn(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {
    debugPrint('SalesReturn received: ${jsonEncode(data)}');

    if (data['type'] != 'salesReturn') {
      debugPrint("Not a sales return message");
      return;
    }

    final salesReturnRaw = data['data'];
    if (salesReturnRaw is! Map<String, dynamic>) {
      debugPrint("Invalid sales return data format");
      return;
    }

    final locationId = salesReturnRaw['locationId']?.toString() ?? 'AR';
    final salesReturnNo = salesReturnRaw['salesReturnNo']?.toString();

    // ←←← NEW: POST TO SERVER FIRST ←←←
    final bool postSuccess = await _postSalesReturnAndWait(salesReturnRaw);

    if (!postSuccess) {
      debugPrint(
        "Server rejected sales return $salesReturnNo → NOT processing locally",
      );
      return; // ←←← STOP EVERYTHING HERE
    }

    debugPrint(
      "Server accepted → Now applying local changes for $salesReturnNo",
    );

    // === ONLY NOW: Do all local stuff ===
    final salesReturnBox = await Hive.openBox("salesReturns");

    // Optional: double-check not already saved (safety)
    if (salesReturnBox.containsKey(salesReturnNo)) {
      debugPrint("Already processed: $salesReturnNo");
      return;
    }

    // Save to Hive
    await salesReturnBox.put(salesReturnNo, salesReturnRaw);
    debugPrint("Sales Return saved to Hive: $salesReturnNo");
    printer.updateReceiptData(salesReturnRaw);

    // === STOCK INCREASE (same as before) ===
    try {
      final List<dynamic> varianceCodesRaw =
          (salesReturnRaw['varianceitemCode'] is List)
          ? List.from(salesReturnRaw['varianceitemCode'])
          : [];

      final List<dynamic> varianceNamesRaw =
          (salesReturnRaw['varianceName'] is List)
          ? List.from(salesReturnRaw['varianceName'])
          : [];

      final List<dynamic> qtyRaw = (salesReturnRaw['qty'] is List)
          ? List.from(salesReturnRaw['qty'])
          : [];

      final List<dynamic> weightRaw = (salesReturnRaw['weight'] is List)
          ? List.from(salesReturnRaw['weight'])
          : [];

      final List<dynamic> uomRaw = (salesReturnRaw['uom'] is List)
          ? List.from(salesReturnRaw['uom'])
          : [];

      final int maxItems = [
        varianceCodesRaw.length,
        varianceNamesRaw.length,
        qtyRaw.length,
        weightRaw.length,
        uomRaw.length,
      ].fold(0, (a, b) => a > b ? a : b);

      List<String> varianceCodes = [];
      List<String> varianceNames = [];
      List<double> increaseAmounts = [];

      for (int i = 0; i < maxItems; i++) {
        final code = i < varianceCodesRaw.length
            ? varianceCodesRaw[i]?.toString().trim()
            : null;
        final name = i < varianceNamesRaw.length
            ? varianceNamesRaw[i]?.toString().trim()
            : null;
        final qtyVal = i < qtyRaw.length ? qtyRaw[i] : 0.0;
        final weightVal = i < weightRaw.length ? weightRaw[i] : 0.0;
        final uomVal = i < uomRaw.length
            ? uomRaw[i]?.toString() ?? 'Pcs'
            : 'Pcs';

        if (code == null || code.isEmpty || name == null || name.isEmpty)
          continue;

        double qty = qtyVal is num
            ? qtyVal.toDouble()
            : (double.tryParse(qtyVal.toString()) ?? 0.0);
        double weight = weightVal is num
            ? weightVal.toDouble()
            : (double.tryParse(weightVal.toString()) ?? 0.0);

        final increase = getStockDeductionAmount(
          uom: uomVal,
          weight: weight,
          qty: qty,
        );
        if (increase <= 0) continue;

        varianceCodes.add(code);
        varianceNames.add(name);
        increaseAmounts.add(increase);
      }

      if (varianceCodes.isNotEmpty) {
        await increaseLocalHiveStock(
          clients: clients,
          locationId: locationId,
          varianceCodes: varianceCodes,
          varianceNames: varianceNames,
          stockIncreaseAmounts: increaseAmounts,
          uoms: uomRaw.map((e) => e?.toString() ?? 'Pcs').toList(),
        );
        debugPrint("Stock increased locally after server approval");
      }
    } catch (e, st) {
      debugPrint("Stock increase failed: $e\n$st");
    }

    // Notify all clients
    sendDataToClients({
      'action': 'salesReturnProcessed',
      'returnData': salesReturnRaw,
      'salesReturnNo': salesReturnNo,
    }, clients);
  } catch (e, st) {
    debugPrint("handleSalesReturn error: $e\n$st");
  }
}

bool _isPostingReturn = false;

Future<bool> _postSalesReturnAndWait(Map<String, dynamic> returnData) async {
  if (_isPostingReturn) {
    debugPrint("Already posting a return. Skipping duplicate.");
    return false;
  }
  _isPostingReturn = true;

  try {
    debugPrint("Posting sales return to server...");

    final response = await http
        .post(
          Uri.parse('https://yenerp.com/fluttertestapi/salesreturns/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(returnData),
        )
        .timeout(const Duration(seconds: 20));

    debugPrint("Server Response: ${response.statusCode} | ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      debugPrint("Sales return ACCEPTED by server");
      return true;
    } else {
      debugPrint("Server REJECTED sales return: ${response.statusCode}");
      return false;
    }
  } catch (e) {
    debugPrint("POST failed: $e");
    return false;
  } finally {
    _isPostingReturn = false;
  }
}

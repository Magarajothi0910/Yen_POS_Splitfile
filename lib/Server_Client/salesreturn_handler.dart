import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Server_Client/handlers/invoice_handler.dart'
    hide getStockDeductionAmount;
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart';

Future<void> handleSalesReturn(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {
  
    if (data['type'] != 'salesReturn') {
      return;
    }

    final salesReturnRaw = data['data'];
    if (salesReturnRaw is! Map<String, dynamic>) {
      return;
    }

    final branchAlias = salesReturnRaw['aliasName']?.toString() ?? 'AR';
    final salesReturnNo = salesReturnRaw['salesReturnNo']?.toString();

    // ←←← NEW: POST TO SERVER FIRST ←←←
    final bool postSuccess = await _postSalesReturnAndWait(salesReturnRaw);

    if (!postSuccess) {
      return; // ←←← STOP EVERYTHING HERE
    }

    // === ONLY NOW: Do all local stuff ===
    final salesReturnBox = await Hive.openBox("salesReturns");

    // Optional: double-check not already saved (safety)
    if (salesReturnBox.containsKey(salesReturnNo)) {
      return;
    }

    // Save to Hive
    await salesReturnBox.put(salesReturnNo, salesReturnRaw);
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
          branchAlias: branchAlias,
          varianceCodes: varianceCodes,
          varianceNames: varianceNames,
          stockIncreaseAmounts: increaseAmounts,
          uoms: uomRaw.map((e) => e?.toString() ?? 'Pcs').toList(),
        );
      }
    } catch (e, st) {}

    // Notify all clients
    sendDataToClients({
      'action': 'salesReturnProcessed',
      'returnData': salesReturnRaw,
      'salesReturnNo': salesReturnNo,
    }, clients);
  } catch (e, st) {}
}

bool _isPostingReturn = false;

Future<bool> _postSalesReturnAndWait(Map<String, dynamic> returnData) async {
  if (_isPostingReturn) {
    return false;
  }
  _isPostingReturn = true;

  try {
    final response = await http
        .post(
          Uri.parse('https://yenerp.com/fluttertestapi/salesreturns/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(returnData),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      return false;
    }
  } catch (e) {
    return false;
  } finally {
    _isPostingReturn = false;
  }
}

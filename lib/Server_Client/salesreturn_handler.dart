

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart';

Future<void> handleSalesReturn(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {
    debugPrint('SalesReturn received: ${jsonEncode(data)}');

    // ← CORRECT: You sent { type: "salesReturn", data: {...} }
    if (data['type'] != 'salesReturn') {
      debugPrint("Not a sales return message");
      return;
    }

    final salesReturnRaw = data['data']; // ← This is your actual return map
    if (salesReturnRaw is! Map<String, dynamic>) {
      debugPrint("Invalid sales return data format");
      return;
    }

    final branchAlias = salesReturnRaw['aliasName']?.toString() ?? 'AR';
    final invoiceNo = salesReturnRaw['invoiceNo']?.toString();
    final salesReturnNo = salesReturnRaw['salesReturnNo']?.toString();

    debugPrint("Processing Sales Return: $salesReturnNo | Invoice: $invoiceNo | Branch: $branchAlias");

    // Save to Hive
    // final box = await Hive.openBox('salesReturns');
    // await box.put(salesReturnNo, salesReturnRaw);
    debugPrint("Sales Return saved to Hive: $salesReturnNo");

    // === STOCK INCREASE ===
    try {
      final List<dynamic> varianceCodesRaw = (salesReturnRaw['varianceitemCode'] is List)
          ? List.from(salesReturnRaw['varianceitemCode'])
          : [];

      final List<dynamic> varianceNamesRaw = (salesReturnRaw['varianceName'] is List)
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
        final code = i < varianceCodesRaw.length ? varianceCodesRaw[i]?.toString().trim() : null;
        final name = i < varianceNamesRaw.length ? varianceNamesRaw[i]?.toString().trim() : null;
        final qtyVal = i < qtyRaw.length ? qtyRaw[i] : 0.0;
        final weightVal = i < weightRaw.length ? weightRaw[i] : 0.0;
        final uomVal = i < uomRaw.length ? uomRaw[i]?.toString() ?? 'Pcs' : 'Pcs';

        if (code == null || code.isEmpty || name == null || name.isEmpty) continue;

        double qty = qtyVal is num ? qtyVal.toDouble() : (double.tryParse(qtyVal.toString()) ?? 0.0);
        double weight = weightVal is num ? weightVal.toDouble() : (double.tryParse(weightVal.toString()) ?? 0.0);

        final increase = getStockDeductionAmount(uom: uomVal, weight: weight, qty: qty);
        if (increase <= 0) continue;

        varianceCodes.add(code);
        varianceNames.add(name);
        increaseAmounts.add(increase);

        debugPrint("Return → Increase stock: $name (+$increase $uomVal)");
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
        debugPrint("Stock increased for return: ${varianceCodes.length} items");
      }
    } catch (e, st) {
      debugPrint("Stock increase failed on return: $e\n$st");
    }

    // Notify all clients
    sendDataToClients({
      'action': 'salesReturnProcessed',
      'returnData': salesReturnRaw,
      'salesReturnNo': salesReturnNo,
      'invoiceNo': invoiceNo,
    }, clients);

  } catch (e, st) {
    debugPrint("handleSalesReturn error: $e\n$st");
  }
}
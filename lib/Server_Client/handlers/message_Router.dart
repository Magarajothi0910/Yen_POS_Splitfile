import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handleHandShake.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_ModifyOrder.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_holdorder_websocket.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_invoice.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_invoiceNo.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_opsaleorder_generated.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_patch_approval_order.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_patchsaleorder.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_salesReturn.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_salesapproval.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_sync_invoice.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/invoice_patch_saleorder.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/message_handler_websocket_saleorder.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/websocket_patch_saleorder.dart';

import 'package:yenpos/Server_Client/websocketService.dart';

class MessageRouter {
  static Future<void> handle(
    String rawMessage,
    CustomerScreenProvider provider,
    SalesInvoiceReceiptPrinter printer,
    WebSocketService ws,
  ) async {
    final data = jsonDecode(rawMessage);
    final action = data['action'];

    switch (action) {
      case 'salesOrderGenerated':
        await handleSalesOrder(data, provider);
        break;
      case 'OpSalesOrderGenerated':
        await handleOpSalesOrder(data, provider);
        break;
      case 'holdOrderGenerated':
        await handleHoldOrder(data);
        break;
      case 'invoiceGenerated':
        await handleInvoice(data, printer);
        break;
      case 'patchsaleorderGenerated':
        await handlePatchSalesOrder(data, provider);
        break;
      case 'modifyOrderGenerated':
        await handleModifyOrder(data, provider);
        break;
      case 'salesApprovalOrderGenerated':
        await handleApprovalOrder(data);
        break;
      case 'salesOrder_updated':
        await handleWebsocketPatchSalesOrder(data, provider);
        break;
      case 'approval_updated':
        await handlePatchSalesApprovalOrder(data, provider);
        break;
      case 'patchInvoicesaleorderGenerated':
        await handleInvoicePatchSalesOrder(data, provider);
        break;
      case 'ApprovedsalesOrderGenerated':
        await handleWebsocketPatchSalesOrder(data, provider);
        break;
      case 'soStockDecreaseUpdate':
        final branchAliseName = data['branchAlias'];
        final varianceCode = data['varianceCode'];
        final varianceName = data['varianceName'];
        final updatedStock = data['updatedStock'];
        // await handleStockDecreaseUpdate(decoded);
        break;

      case 'stockDecreaseUpdate':
        _handleLiveStockUpdate(data);
        break;
      case 'stockIncreaseUpdate':
        _handleLiveStockUpdate(data);
        break;
      case 'salesReturnProcessed':
        handleSalesReturn(data);
        break;
      case 'handshake':
        handleHandShake(data);
      case 'syncInvoice':
        await handleSyncInvoice(data);
        break;
      case 'stock':
        _handleLiveStockUpdate(data);
        break;

      case 'invoiceNoGenerated':
        handleInvoiceNo(data);
        break;
      default:
        break;
    }
  }
}

void _handleLiveStockUpdate(Map<String, dynamic> data) {
  try {
    final String? action = data['action']?.toString();
    final String? branchAlias = data['branchAlias']?.toString();
    final String? varianceName = data['varianceName']?.toString();

    if (branchAlias == null || varianceName == null) {
      return;
    }

    double newStock = 0.0;
    double newStockSO = 0.0;

    // Handle different message formats gracefully
    if (action == 'stockIncreaseUpdate' || action == 'stockDecreaseUpdate') {
      final dynamic raw = data['updatedStock'];
      newStock = _parseToDouble(raw);
      newStockSO = 0.0; // older format didn't send SO
    } else if (action == 'stock') {
      newStock = _parseToDouble(data['systemStock']);
      newStockSO = _parseToDouble(data['systemstockSo']);
    } else {
      return;
    }

    // Clean precision
    newStock = double.parse(newStock.toStringAsFixed(3));
    newStockSO = double.parse(newStockSO.toStringAsFixed(3));


    // 1. Update UI immediately
    GlobalDataManager().updateStockLive(
      branchAlias: branchAlias,
      varianceName: varianceName,
      systemStock: newStock,
      soStock: newStockSO,
    );

    // 2. Also sync to local Hive (only on client!)
    _applyRemoteStockUpdateToLocalHive(
      action: action,
      branchAlias: branchAlias,
      varianceName: varianceName,
      systemStock: newStock,
      systemstockSo: newStockSO,
    );
  } catch (e, st) {}
}

double _parseToDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

/// Called from WebSocket listener on client only
Future<void> _applyRemoteStockUpdateToLocalHive({
  required String? action,
  required String branchAlias,
  required String varianceName,
  required double systemStock,
  required double systemstockSo,
}) async {
  // ──────── ONLY RUN ON CLIENT DEVICES (NOT ON SERVER) ────────
  if (const String.fromEnvironment('APP_TYPE', defaultValue: 'client') ==
      'server') {
    return;
  }


  try {
    final box = await Hive.openBox('items');
    final hiveKey = 'branchwiseItems_$branchAlias';

    final dynamic boxedData = await box.get(hiveKey);
    if (boxedData == null) {
      return;
    }

    final globalData = Map<String, dynamic>.from(boxedData as Map);
    if (globalData['data'] == null) return;

    final branchwiseData = Map<String, dynamic>.from(globalData['data']);
    bool foundAndUpdated = false;

    for (final itemEntry in branchwiseData.entries) {
      final itemVal = Map<String, dynamic>.from(itemEntry.value);
      if (!itemVal.containsKey('variance')) continue;

      final varianceMap = Map<String, dynamic>.from(itemVal['variance']);
      if (!varianceMap.containsKey(varianceName)) continue;

      final variance = Map<String, dynamic>.from(varianceMap[varianceName]);
      if (!variance.containsKey('branchwise')) continue;

      final branchwiseMap = Map<String, dynamic>.from(variance['branchwise']);
      if (!branchwiseMap.containsKey(branchAlias)) continue;

      final branchData = Map<String, dynamic>.from(branchwiseMap[branchAlias]);

      final sysKey = 'systemStock_$branchAlias';
      final soKey = 'systemstockSo_$branchAlias';

      // Clean values
      final double newStock = double.parse(systemStock.toStringAsFixed(3));
      final double newSO = double.parse(systemstockSo.toStringAsFixed(3));

      branchData[sysKey] = newStock;
      branchData[soKey] = newSO;

      // Rebuild nested structure
      branchwiseMap[branchAlias] = branchData;
      variance['branchwise'] = branchwiseMap;
      varianceMap[varianceName] = variance;
      itemVal['variance'] = varianceMap;
      branchwiseData[itemEntry.key] = itemVal;

      foundAndUpdated = true;
      break;
    }

    if (foundAndUpdated) {
      globalData['data'] = branchwiseData;
      await box.put(hiveKey, globalData);

      // Also notify UI via GlobalDataManager (your existing live update)
      GlobalDataManager().updateStockLive(
        branchAlias: branchAlias,
        varianceName: varianceName,
        systemStock: systemStock,
        soStock: systemstockSo,
        // newStockSO: systemstockSo,
      );
    } else {}
  } catch (e, st) {}
}

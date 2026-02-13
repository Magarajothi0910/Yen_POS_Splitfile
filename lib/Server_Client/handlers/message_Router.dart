// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:yen_pos/Global/global_data_manager.dart';
// import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
// import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handleHandShake.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_ModifyOrder.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_holdorder_websocket.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_invoice.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_invoiceNo.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_opsaleorder_generated.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_patch_approval_order.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_patchsaleorder.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_salesReturn.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_salesapproval.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_shift.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_sync_invoice.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/invoice_patch_saleorder.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/message_handler_websocket_saleorder.dart';
// import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/websocket_patch_saleorder.dart';

// import 'package:yen_pos/Server_Client/websocketService.dart';
// import 'package:yen_pos/kotpreinvoice/handlers/updateTopPriorityHandlers.dart';

// class MessageRouter {
//   static Future<void> handle(
//     String rawMessage,
//     CustomerScreenProvider provider,
//     SalesInvoiceReceiptPrinter printer,
//     WebSocketService ws,
//   ) async {
//     final data = jsonDecode(rawMessage);
//     final action = data['action'];

//     switch (action) {
//       case 'salesOrderGenerated':
//         await handleSalesOrder(data, provider);
//         break;
//       case 'OpSalesOrderGenerated':
//         await handleOpSalesOrder(data, provider);
//         break;
//       case 'holdOrderGenerated':
//         await handleHoldOrder(data);
//         break;
//       case 'invoiceGenerated':
//         await handleInvoice(data, printer);
//         break;
//       case 'patchsaleorderGenerated':
//         await handlePatchSalesOrder(data, provider);
//         break;
//       case 'modifyOrderGenerated':
//         await handleModifyOrder(data, provider);
//         break;
//       case 'salesApprovalOrderGenerated':
//         await handleApprovalOrder(data);
//         break;
//       case 'salesOrder_updated':
//         await handleWebsocketPatchSalesOrder(data, provider);
//         break;
//       case 'approval_updated':
//         await handlePatchSalesApprovalOrder(data, provider);
//         break;
//       case 'patchInvoicesaleorderGenerated':
//         await handleInvoicePatchSalesOrder(data, provider);
//         break;
//       case 'ApprovedsalesOrderGenerated':
//         await handleWebsocketPatchSalesOrder(data, provider);
//         break;
//       case 'soStockDecreaseUpdate':
//         print("1234 for stock update");
//         final branchAliseName = data['locationId'];
//         print("branchAliseName: $branchAliseName");
//         final varianceCode = data['varianceCode'];
//         print("varianceCode: $varianceCode");
//         final varianceName = data['varianceName'];
//         print("varianceName: $varianceName");
//         final updatedStock = data['updatedStock'];
//         print("updatedStock: $updatedStock");
//         // await handleStockDecreaseUpdate(decoded);
//         break;

//       case 'stockDecreaseUpdate':
//         _handleLiveStockUpdate(data);
//         break;
//       case 'stockIncreaseUpdate':
//         _handleLiveStockUpdate(data);
//         break;
//       case 'salesReturnProcessed':
//         handleSalesReturn(data);
//         break;
//       case 'handshake':
//         handleHandShake(data);
//       case 'syncInvoice':
//         await handleSyncInvoice(data);
//         break;
//       case 'stock':
//         _handleLiveStockUpdate(data);
//         break;

//       case 'invoiceNoGenerated':
//         handleInvoiceNo(data);
//         break;

//       case 'DineInStatus':
//         handleKOT(data);
//         break;

//        case 'allDataResponse':
//         handleInvoices(data, printer);
//         break;

//       case 'subnetIpChanged':
//         handleIp(data);
//         break;

//        case 'priorityUpdate':
//         handlePriorityUpdate(data);
//         break;

//       default:
//         print('[WS] Unknown action: $action');
//         break;
//     }
//   }
// }

// void _handleLiveStockUpdate(Map<String, dynamic> data) {
//   try {
//     final String? action = data['action']?.toString();
//     final String? locationId = data['locationId']?.toString();
//     final String? varianceName = data['varianceName']?.toString();

//     if (locationId == null || varianceName == null) {
//       debugPrint("Invalid stock payload (missing branch/varianceName): $data");
//       return;
//     }

//     double newStock = 0.0;
//     double newStockSO = 0.0;

//     // Handle different message formats gracefully
//     if (action == 'stockIncreaseUpdate' || action == 'stockDecreaseUpdate') {
//       final dynamic raw = data['updatedStock'];
//       newStock = _parseToDouble(raw);
//       newStockSO = 0.0; // older format didn't send SO
//     } else if (action == 'stock') {
//       newStock = _parseToDouble(data['systemStock']);
//       newStockSO = _parseToDouble(data['systemstockSo']);
//     } else {
//       debugPrint("Unknown stock action: $action");
//       return;
//     }

//     // Clean precision
//     newStock = double.parse(newStock.toStringAsFixed(3));
//     newStockSO = double.parse(newStockSO.toStringAsFixed(3));

//     debugPrint(
//       "LIVE STOCK RECEIVED → $locationId | $varianceName = $newStock (SO: $newStockSO)",
//     );

//     // 1. Update UI immediately
//     GlobalDataManager().updateStockLive(
//       locationId: locationId,
//       varianceName: varianceName,
//       systemStock: newStock,
//       soStock: newStockSO,
//     );

//     // 2. Also sync to local Hive (only on client!)
//     _applyRemoteStockUpdateToLocalHive(
//       action: action,
//       locationId: locationId,
//       varianceName: varianceName,
//       systemStock: newStock,
//       systemstockSo: newStockSO,
//     );
//   } catch (e, st) {
//     debugPrint("Stock update error: $e\n$st");
//   }
// }

// // double _parseToDouble(dynamic value) {
// //   if (value is num) return value.toDouble();
// //   if (value is String) return double.tryParse(value) ?? 0.0;
// //   return 0.0;
// // }

// // void _handleLiveStockUpdates(Map<String, dynamic> data) {
// //   try {
// //     final String? branchAlias = data['branchAlias']?.toString();
// //     final String? varianceName = data['varianceName']?.toString();

// //     final dynamic rawSystem = data['systemStock'];
// //     final dynamic rawSystemSO = data['systemstockSo'];

// //     if (branchAlias == null || varianceName == null) {
// //       debugPrint("Invalid stock update payload: $data");
// //       return;
// //     }

// //     double newSystem = _parseToDouble(rawSystem);
// //     double newSystemSO = _parseToDouble(rawSystemSO);

// //     // Clean precision
// //     newSystem = double.parse(newSystem.toStringAsFixed(3));
// //     newSystemSO = double.parse(newSystemSO.toStringAsFixed(3));

// //     debugPrint("LIVE STOCK → $branchAlias | $varianceName = $newSystem (SO: $newSystemSO)");

// //     GlobalDataManager().updateStockLive(
// //       branchAlias: branchAlias,
// //       varianceName: varianceName,
// //       newStock: newSystem,
// //       //newStockSO: newSystemSO, // if you have this param
// //     );

// //   } catch (e, st) {
// //     debugPrint("Stock update error: $e\n$st");
// //   }
// // }

// double _parseToDouble(dynamic value) {
//   if (value is num) return value.toDouble();
//   if (value is String) return double.tryParse(value) ?? 0.0;
//   return 0.0;
// }

// /// Called from WebSocket listener on client only
// Future<void> _applyRemoteStockUpdateToLocalHive({
//   required String? action,
//   required String locationId,
//   required String varianceName,
//   required double systemStock,
//   required double systemstockSo,
// }) async {
//   // ──────── ONLY RUN ON CLIENT DEVICES (NOT ON SERVER) ────────
//   if (const String.fromEnvironment('APP_TYPE', defaultValue: 'client') ==
//       'server') {
//     debugPrint("Skipping Hive update: Running in server mode");
//     return;
//   }

//   debugPrint(
//     "CLIENT: Applying remote stock update → $varianceName = $systemStock (SO: $systemstockSo)",
//   );

//   try {
//     final box = await Hive.openBox('items');
//     final hiveKey = 'branchwiseItems_$locationId';

//     final dynamic boxedData = await box.get(hiveKey);
//     if (boxedData == null) {
//       debugPrint(
//         "No local branch data for $locationId – cannot apply remote update",
//       );
//       return;
//     }

//     final globalData = Map<String, dynamic>.from(boxedData as Map);
//     if (globalData['data'] == null) return;

//     final branchwiseData = Map<String, dynamic>.from(globalData['data']);
//     bool foundAndUpdated = false;

//     for (final itemEntry in branchwiseData.entries) {
//       final itemVal = Map<String, dynamic>.from(itemEntry.value);
//       if (!itemVal.containsKey('variance')) continue;

//       final varianceMap = Map<String, dynamic>.from(itemVal['variance']);
//       if (!varianceMap.containsKey(varianceName)) continue;

//       final variance = Map<String, dynamic>.from(varianceMap[varianceName]);
//       if (!variance.containsKey('branchwise')) continue;

//       final branchwiseMap = Map<String, dynamic>.from(variance['branchwise']);
//       if (!branchwiseMap.containsKey(locationId)) continue;

//       final branchData = Map<String, dynamic>.from(branchwiseMap[locationId]);

//       final sysKey = 'systemStock';
//       final soKey = 'systemstockSo';

//       // Clean values
//       final double newStock = double.parse(systemStock.toStringAsFixed(3));
//       final double newSO = double.parse(systemstockSo.toStringAsFixed(3));

//       branchData[sysKey] = newStock;
//       branchData[soKey] = newSO;

//       // Rebuild nested structure
//       branchwiseMap[locationId] = branchData;
//       variance['branchwise'] = branchwiseMap;
//       varianceMap[varianceName] = variance;
//       itemVal['variance'] = varianceMap;
//       branchwiseData[itemEntry.key] = itemVal;

//       foundAndUpdated = true;
//       break;
//     }

//     if (foundAndUpdated) {
//       globalData['data'] = branchwiseData;
//       await box.put(hiveKey, globalData);
//       debugPrint(
//         "CLIENT: Hive updated successfully for $varianceName @ $locationId",
//       );

//       // Also notify UI via GlobalDataManager (your existing live update)
//       GlobalDataManager().updateStockLive(
//         locationId: locationId,
//         varianceName: varianceName,
//         systemStock: systemStock,
//         soStock: systemstockSo,
//         // newStockSO: systemstockSo,
//       );
//     } else {
//       debugPrint("CLIENT: Variance '$varianceName' not found in local Hive");
//     }
//   } catch (e, st) {
//     debugPrint("Failed to apply remote stock to local Hive: $e\n$st");
//   }
// }

import 'dart:convert';
// import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handleHandShake.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_ModifyOrder.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_holdorder_websocket.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_invoice.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_invoiceNo.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_opsaleorder_generated.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_patch_approval_order.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_patchsaleorder.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_salesReturn.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_salesapproval.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_shift.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_sync_invoice.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/invoice_patch_saleorder.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/message_handler_websocket_saleorder.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/websocket_patch_saleorder.dart';

import 'package:yen_pos/Server_Client/websocketService.dart';
import 'package:yen_pos/kotpreinvoice/handlers/handleRemoveHoldOrdersKOT.dart';
import 'package:yen_pos/kotpreinvoice/handlers/holdOrdersKOT.dart';
import 'package:yen_pos/kotpreinvoice/handlers/priorityUpdateHandler.dart';
import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';

class MessageRouter {
  static Future<void> handle(
    String rawMessage,
    CustomerScreenProvider provider,
    SalesInvoiceReceiptPrinter printer,
    WebSocketService ws,
  ) async {
    final data = jsonDecode(rawMessage);
    final action = data['action'];

    // final ctx = navigatorKey.currentContext!;

    // final orderProvider = Provider.of<OrderProvider>(ctx, listen: false);

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
        print("1234 for stock update");
        final branchAliseName = data['locationId'];
        print("branchAliseName: $branchAliseName");
        final varianceCode = data['varianceCode'];
        print("varianceCode: $varianceCode");
        final varianceName = data['varianceName'];
        print("varianceName: $varianceName");
        final updatedStock = data['updatedStock'];
        print("updatedStock: $updatedStock");
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

      case 'DineInStatus':
        handleKOT(data);
        break;

      case 'allDataResponse':
        handleInvoices(data, printer);
        break;

      case 'subnetIpChanged':
        handleIp(data);
        break;

      case 'priorityUpdate':
        handlePriorityUpdate(data);
        break;

      // case 'addHoldOrdersKOT':
      //   handleAddHoldOrdersKOT(data, clients);
      //   break;

      // case 'removeHoldOrdersKOT':
      //   handleRemoveHoldOrdersKOT(data, clients);
      //   break;

      // case 'order':
      //   orderProvider.processOrderData(data);
      //   break;
      default:
        print('[WS] Unknown action: $action');
        break;
    }
  }
}

void _handleLiveStockUpdate(Map<String, dynamic> data) {
  try {
    final String? action = data['action']?.toString();
    final String? locationId = data['locationId']?.toString();
    final String? varianceName = data['varianceName']?.toString();

    if (locationId == null || varianceName == null) {
      debugPrint("Invalid stock payload (missing branch/varianceName): $data");
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
      debugPrint("Unknown stock action: $action");
      return;
    }

    // Clean precision
    newStock = double.parse(newStock.toStringAsFixed(3));
    newStockSO = double.parse(newStockSO.toStringAsFixed(3));

    debugPrint(
      "LIVE STOCK RECEIVED → $locationId | $varianceName = $newStock (SO: $newStockSO)",
    );

    // 1. Update UI immediately
    GlobalDataManager().updateStockLive(
      locationId: locationId,
      varianceName: varianceName,
      systemStock: newStock,
      soStock: newStockSO,
    );

    // 2. Also sync to local Hive (only on client!)
    _applyRemoteStockUpdateToLocalHive(
      action: action,
      locationId: locationId,
      varianceName: varianceName,
      systemStock: newStock,
      systemstockSo: newStockSO,
    );
  } catch (e, st) {
    debugPrint("Stock update error: $e\n$st");
  }
}

// double _parseToDouble(dynamic value) {
//   if (value is num) return value.toDouble();
//   if (value is String) return double.tryParse(value) ?? 0.0;
//   return 0.0;
// }

// void _handleLiveStockUpdates(Map<String, dynamic> data) {
//   try {
//     final String? branchAlias = data['branchAlias']?.toString();
//     final String? varianceName = data['varianceName']?.toString();

//     final dynamic rawSystem = data['systemStock'];
//     final dynamic rawSystemSO = data['systemstockSo'];

//     if (branchAlias == null || varianceName == null) {
//       debugPrint("Invalid stock update payload: $data");
//       return;
//     }

//     double newSystem = _parseToDouble(rawSystem);
//     double newSystemSO = _parseToDouble(rawSystemSO);

//     // Clean precision
//     newSystem = double.parse(newSystem.toStringAsFixed(3));
//     newSystemSO = double.parse(newSystemSO.toStringAsFixed(3));

//     debugPrint("LIVE STOCK → $branchAlias | $varianceName = $newSystem (SO: $newSystemSO)");

//     GlobalDataManager().updateStockLive(
//       branchAlias: branchAlias,
//       varianceName: varianceName,
//       newStock: newSystem,
//       //newStockSO: newSystemSO, // if you have this param
//     );

//   } catch (e, st) {
//     debugPrint("Stock update error: $e\n$st");
//   }
// }

double _parseToDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

/// Called from WebSocket listener on client only
Future<void> _applyRemoteStockUpdateToLocalHive({
  required String? action,
  required String locationId,
  required String varianceName,
  required double systemStock,
  required double systemstockSo,
}) async {
  // ──────── ONLY RUN ON CLIENT DEVICES (NOT ON SERVER) ────────
  if (const String.fromEnvironment('APP_TYPE', defaultValue: 'client') ==
      'server') {
    debugPrint("Skipping Hive update: Running in server mode");
    return;
  }

  debugPrint(
    "CLIENT: Applying remote stock update → $varianceName = $systemStock (SO: $systemstockSo)",
  );

  try {
    final box = await Hive.openBox('items');
    final hiveKey = 'branchwiseItems_$locationId';

    final dynamic boxedData = await box.get(hiveKey);
    if (boxedData == null) {
      debugPrint(
        "No local branch data for $locationId – cannot apply remote update",
      );
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
      if (!branchwiseMap.containsKey(locationId)) continue;

      final branchData = Map<String, dynamic>.from(branchwiseMap[locationId]);

      final sysKey = 'systemStock';
      final soKey = 'systemstockSo';

      // Clean values
      final double newStock = double.parse(systemStock.toStringAsFixed(3));
      final double newSO = double.parse(systemstockSo.toStringAsFixed(3));

      branchData[sysKey] = newStock;
      branchData[soKey] = newSO;

      // Rebuild nested structure
      branchwiseMap[locationId] = branchData;
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
      debugPrint(
        "CLIENT: Hive updated successfully for $varianceName @ $locationId",
      );

      // Also notify UI via GlobalDataManager (your existing live update)
      GlobalDataManager().updateStockLive(
        locationId: locationId,
        varianceName: varianceName,
        systemStock: systemStock,
        soStock: systemstockSo,
        // newStockSO: systemstockSo,
      );
    } else {
      debugPrint("CLIENT: Variance '$varianceName' not found in local Hive");
    }
  } catch (e, st) {
    debugPrint("Failed to apply remote stock to local Hive: $e\n$st");
  }
}

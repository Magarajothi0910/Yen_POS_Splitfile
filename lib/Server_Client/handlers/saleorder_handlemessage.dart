import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Server_Client/hive_service.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/Server_Client/sync_service.dart';

import '../../Global/globals_data.dart' as globals;

int _sendDataToClientsCount = 0;
final SyncService _syncService = SyncService();
Future<void> handleOpenSaleOrder(Map<String, dynamic> data) async {
  // Extract the sales order data (nested or top-level)
  final salesOrder = data['data'] ?? data;

  // Determine the prefix for the sales order number
  String prefix =
      salesOrder['saleOrderNo']?.toString().trim() ??
      salesOrder['branchAlias']?.toString().trim() ??
      "SOSB";

  // Get new sales order number from API/Hive
  final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);

  if (newSalesOrderNo == null) {
    return;
  }

  // Clean and update the sales order number
  final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
  salesOrder['saleOrderNo'] = cleanSalesOrderNo;

  // Save the order locally
  await savePosSaleOrderToHive(data, HiveManager.salesOrderBox);

  // Notify clients with updated order number
  sendDataToClients({
    'action': 'OpSalesOrderGenerated',
    'opSalesOrder': data, // now includes updated saleOrderNo
  }, clients);
  _sendDataToClientsCount++;

  // Post to API
  bool success = await _syncService.postSalesOrder(salesOrder);

  if (success) {
  } else {}
}

String generateSalesOrderId(String branchCode, int sequenceNumber) {
  final yearSuffix = DateFormat('yy').format(DateTime.now());
  final sequenceStr = sequenceNumber.toString().padLeft(4, '0');
  return 'SO$branchCode$yearSuffix$sequenceStr';
}

Future<String?> fetchNextSalesOrderNumberFromHive(String prefix) async {
  final box = HiveManager.salesOrderNumberBox;

  // 🔹 Current year last 2 digits (2026 → 26)
  final String yearYY = DateTime.now().year.toString().substring(2);

  final String basePrefix = '$prefix$yearYY'; // SOKKR26

  final validNumbers = <String>[];
  final keysToDelete = <dynamic>[];

  // STEP 1: Collect valid entries
  for (var key in box.keys) {
    final value = box.get(key);

    if (value is String && value.startsWith(basePrefix)) {
      validNumbers.add(value);
    } else if (value == null || value is! String) {
      keysToDelete.add(key);
    }
  }

  // STEP 2: Cleanup invalid entries
  if (keysToDelete.isNotEmpty) {
    for (var key in keysToDelete) {
      await box.delete(key);
    }
  } else {}

  // STEP 3: First order for this year
  if (validNumbers.isEmpty) {
    final firstOrder = '${basePrefix}0001';

    await box.put(DateTime.now().millisecondsSinceEpoch.toString(), firstOrder);

    return firstOrder;
  }

  // STEP 4: Get last order
  validNumbers.sort();
  final lastOrder = validNumbers.last;

  // STEP 5: Extract ONLY last 4 digits
  final match = RegExp(r'(\d{4})$').firstMatch(lastOrder);
  final lastCount = int.tryParse(match?.group(1) ?? '0') ?? 0;

  // STEP 6: Increment
  final nextCount = lastCount + 1;
  final formatted = nextCount.toString().padLeft(4, '0');

  final newOrderNumber = '$basePrefix$formatted';

  // STEP 7: Save
  await box.put(
    DateTime.now().millisecondsSinceEpoch.toString(),
    newOrderNumber,
  );

  return newOrderNumber;
}

Future<String?> fetchNextHoldOrderNumberFromHive() async {
  final box = HiveManager.holdOrderIdBox;
  const String prefix = 'HOLD';

  final validNumbers = <String>[];
  final keysToDelete = <dynamic>[];

  // STEP 1: Scan Hive
  for (var key in box.keys) {
    final value = box.get(key);

    if (value is String && value.startsWith(prefix)) {
      validNumbers.add(value);
    } else {
      keysToDelete.add(key);
    }
  }

  // STEP 2: Cleanup invalid entries
  for (var key in keysToDelete) {
    await box.delete(key);
  }

  // STEP 3: First Hold Order
  if (validNumbers.isEmpty) {
    const firstOrder = 'HOLD01';
    await box.put(DateTime.now().millisecondsSinceEpoch.toString(), firstOrder);
    return firstOrder;
  }

  // STEP 4: Get last order
  validNumbers.sort();
  final lastOrder = validNumbers.last;

  // STEP 5: Extract last 2 digits
  final match = RegExp(r'(\d{2})$').firstMatch(lastOrder);
  final lastCount = int.tryParse(match?.group(1) ?? '0') ?? 0;

  // STEP 6: Increment
  final nextCount = lastCount + 1;
  final formatted = nextCount.toString().padLeft(2, '0');

  final newOrderNumber = '$prefix$formatted';

  // STEP 7: Save
  await box.put(
    DateTime.now().millisecondsSinceEpoch.toString(),
    newOrderNumber,
  );

  return newOrderNumber;
}

Future<String?> fetchNextInvoiceOrderNumberFromHive(String prefix) async {
  // Open the Hive box for sales orders
  final invoiceBox = await Hive.openBox('invoices');

  // Get the current count for the prefix or initialize it to 250000
  final currentCount = invoiceBox.get(prefix) ?? 0000;

  // Increment to get the next count
  final nextCount = currentCount + 1;

  // Save the updated count back to Hive
  await invoiceBox.put(prefix, nextCount);

  // Format the numeric part with leading zeros to ensure it is always six digits
  final formattedNumber = nextCount.toString().padLeft(4, '0');

  // Return the new sales order number in the format "prefix + formattedNumber"
  return '$prefix$formattedNumber';
}

Future<void> handlePatchSaleOrder(Map<String, dynamic> data) async {
  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  debugPrint('[PATCH SALE ORDER] START');
  debugPrint('Incoming Data: $data');

  final String soNo = data['saleOrderNo'] ?? '';
  final String editAbout = data['editAbout'] ?? ''; // 🔥 FIX
  debugPrint('SaleOrderNo: $soNo');
  debugPrint('EditAbout: $editAbout');

  var saleOrderBox = HiveManager.salesOrderBox;

  String? targetKey;
  Map<String, dynamic>? existingData;

  // 🔍 Find order in Hive
  for (final entry in saleOrderBox.toMap().entries) {
    final orderData = entry.value['data'];
    if (orderData is Map && orderData['saleOrderNo'] == soNo) {
      targetKey = entry.key.toString();
      existingData = Map<String, dynamic>.from(entry.value);
      break;
    }
  }

  if (targetKey == null || existingData == null) {
    debugPrint('❌ Order not found in Hive');
    return;
  }

  // 🔹 Patch payload data
  final Map<String, dynamic> patchData = Map<String, dynamic>.from(
    data['data'] ?? {},
  );

  final Map<String, dynamic> existingOrderData = Map<String, dynamic>.from(
    existingData['data'] ?? {},
  );

  // 🔄 Merge PATCH data
  existingOrderData.addAll(patchData);

  // 🔥 MOST IMPORTANT FIX
  // Inject editAbout INTO INNER DATA (receipt reads from here)
  existingOrderData['editAbout'] = editAbout;

  // Also store at outer level (optional but good)
  existingData['editAbout'] = editAbout;
  existingData['data'] = existingOrderData;

  debugPrint('Merged Order Data: $existingOrderData');

  // 💾 Save locally
  await saleOrderBox.put(targetKey, existingData);
  debugPrint('✅ Patch saved to Hive');

  // 📡 Notify clients
  sendDataToClients({
    'action': 'patchsaleorderGenerated',
    'saleOrderNo': soNo,
    'patchSaleOrder': existingData,
    'editAbout': editAbout,
  }, clients);

  // 🖨 Update receipt
  final customerProvider = Provider.of<CustomerScreenProvider>(
    navigatorKey.currentContext!,
    listen: false,
  );

  customerProvider.updatePatchReceiptData(existingData);

  // 🌐 Sync to server
  try {
    bool success = await _syncService.patchSalesOrder(soNo, existingData);

    if (success) {
      existingData['sync'] = "Yes";
      await saleOrderBox.put(targetKey, existingData);
      debugPrint('✅ Server sync success');
    }
  } catch (e, stack) {
    debugPrint('❌ Sync error: $e');
    debugPrint('$stack');
  }

  debugPrint('[PATCH SALE ORDER] END');
  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}

Future<void> handlePatchApprovalSaleOrder(Map<String, dynamic> data) async {
  // Extract patch payload (not nested)
  final Map<String, dynamic> patchData = Map<String, dynamic>.from(
    data['data'] ?? {},
  );
  final String soNo = patchData['saleOrderNo'] ?? '';

  // Hive box
  var saleOrderBox = HiveManager.salesApprovalOrder;

  // ========== Debug all entries ==========
  for (var entry in saleOrderBox.toMap().entries) {}

  // Search for matching entry
  String? targetKey;
  Map<String, dynamic>? existingData;

  for (final entry in saleOrderBox.toMap().entries) {
    final orderData = entry.value; // raw map stored in Hive

    if (orderData is Map && orderData['saleOrderNo'] == soNo) {
      targetKey = entry.key.toString();
      existingData = Map<String, dynamic>.from(orderData);
      break;
    }
  }

  if (targetKey == null || existingData == null) {
    return;
  }

  // EXISTING order data (full map)

  // MERGE patch fields directly into the existing Hive map
  existingData.addAll(patchData);

  // Save updated entry back to Hive
  await saleOrderBox.put(targetKey, existingData);

  // Broadcast to clients
  sendDataToClients({
    'action': 'approval_updated',
    'saleOrderNo': soNo,
    'patchapprovalSaleOrder': existingData,
  }, clients);
}

Future<void> handlePatchwebsocketSaleOrder(Map<String, dynamic> data) async {
  // Extract sale order number correctly from nested structure
  final soNo = data['data']?['salesOrderNo'] ?? '';
  if (soNo.isEmpty) {
    return;
  }

  // Access Hive box
  var saleOrderBox = HiveManager.salesOrderBox;

  // Locate matching sale order entry in Hive
  String? targetKey;
  Map<String, dynamic>? existingData;
  for (final entry in saleOrderBox.toMap().entries) {
    final orderData = entry.value['data'];
    if (orderData is Map && orderData['saleOrderNo'] == soNo) {
      targetKey = entry.key.toString();
      existingData = Map<String, dynamic>.from(entry.value);
      break;
    }
  }

  if (targetKey == null || existingData == null) {
    return;
  }

  // Merge patch data into existing order
  final patchData = Map<String, dynamic>.from(data['data'] ?? {});
  final existingOrderData = Map<String, dynamic>.from(
    existingData['data'] ?? {},
  );

  existingOrderData.addAll(patchData);
  existingData['data'] = existingOrderData;

  // Save back to Hive
  await saleOrderBox.put(targetKey, existingData);

  // Notify all connected clients
  sendDataToClients({
    'action': 'salesOrder_updated',
    'saleOrderNo': soNo,
    'patchSaleOrder': existingData,
  }, clients);

  // Sync with API server
  try {
    bool success = await _syncService.patchSalesOrder(soNo, existingData);

    if (success) {
      existingData['sync'] = "Yes";
      await saleOrderBox.put(targetKey, existingData);
    } else {}
  } catch (e, stack) {}
}

Future<void> handlePatchHoldOrder(Map<String, dynamic> data) async {
  // Extract fields safely
  final patchData = Map<String, dynamic>.from(data['data'] ?? {});
  final deviceName = data['deviceName'];
  final type = data['type'];
  final sync = data['sync'];
  final edit = data['edit'];
  final holdOrderId = data['holdOrderId'];

  // 🧩 STEP 0: Debug all current hold orders
  final allHoldOrders = HiveManager.holdOrderBox.toMap();
  if (allHoldOrders.isEmpty) {
  } else {
    for (final entry in allHoldOrders.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is Map && value['data'] != null) {
      } else if (value is Map) {
      } else {}
    }
  }

  dynamic targetKey;

  // 🧩 STEP 1: Find the existing hold order
  for (final entry in HiveManager.holdOrderBox.toMap().entries) {
    final order = entry.value;

    if (order is Map) {
      // Direct match
      if (order['holdOrderId'] == holdOrderId) {
        targetKey = entry.key;
        break;
      }
      // Nested match
      if (order['data'] is Map && order['data']['holdOrderId'] == holdOrderId) {
        targetKey = entry.key;
        break;
      }
    } else {}
  }

  if (targetKey == null) {
    return;
  }

  // 🧩 STEP 2: Load existing order safely
  final rawValue = await HiveManager.holdOrderBox.get(targetKey);
  if (rawValue == null) {
    return;
  }
  if (rawValue is! Map) {
    await HiveManager.holdOrderBox.delete(targetKey);
    return;
  }

  final existingOrder = Map<String, dynamic>.from(rawValue);

  // 🧩 STEP 3: Apply patch
  if (existingOrder.containsKey('data') && existingOrder['data'] is Map) {
    final nestedData = Map<String, dynamic>.from(existingOrder['data']);
    nestedData.addAll(patchData);
    existingOrder['data'] = nestedData;
  } else {
    existingOrder.addAll(patchData);
  }

  // 🧩 STEP 4: Add metadata
  existingOrder.addAll({
    'deviceName': deviceName,
    'type': type,
    'sync': sync,
    'edit': edit,
    'saleOrderNo': holdOrderId,
    'waitingForApprovalResult': data['waitingForApprovalResult'] ?? 'Yes',
  });

  // 🧩 STEP 5: Save back to Hive safely
  try {
    await HiveManager.holdOrderBox.put(targetKey, existingOrder);
  } catch (e, st) {
    return;
  }

  // 🧩 STEP 6: Notify connected clients
  try {
    sendDataToClients({
      'action': 'patchholdorderGenerated',
      'patchHoldOrder': data,
    }, clients);
  } catch (e, st) {}

  // 🧩 STEP 7: Sync to server
  try {
    final success = await _syncService.patchToHoldOrder(holdOrderId, {
      'data': patchData,
      'deviceName': deviceName,
      'type': type,
      'sync': sync,
      'edit': edit,
      'waitingForApprovalResult': data['waitingForApprovalResult'],
    });

    if (success) {
      existingOrder['sync'] = true;
      await HiveManager.holdOrderBox.put(targetKey, existingOrder);
    } else {}
  } catch (e, st) {}
}

// Helper function to debug Hive box structure
void debugHiveBoxStructure() {
  final boxMap = HiveManager.holdOrderBox.toMap();

  boxMap.entries.forEach((entry) {
    if (entry.value is Map) {
      final map = entry.value as Map;

      if (map.containsKey('data')) {
        if (map['data'] is List) {}
      }
    }
  });
}

// ===========================================================
// 🧠 HANDLE SALES ORDER
// ===========================================================
Future<void> handleSaleOrder(Map<String, dynamic> data) async {
  try {
    // STEP 1: Extract sales order data
    final salesOrder = data['data'] ?? data;

    // STEP 2: Determine Prefix
    String prefix =
        salesOrder['saleOrderNo']?.toString().trim() ??
        salesOrder['aliasName']?.toString().trim() ??
        "SOSB";

    // STEP 3: Fetch next order number from Hive
    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);
    if (newSalesOrderNo == null) {
      return;
    }

    final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
    salesOrder['saleOrderNo'] = cleanSalesOrderNo;

    // STEP 4: Check for duplicates in Hive
    final existingOrder = HiveManager.salesOrderBox.get(cleanSalesOrderNo);
    if (existingOrder != null) {
      return;
    }

    // STEP 5: Save order locally
    await savePosSaleOrderToHive(data, HiveManager.salesOrderBox);

    // Optional: Also save via _syncService
    // await _syncService.savePosSaleorderToHive(data);

    // STEP 7: Notify connected clients
    sendDataToClients({
      'action': 'salesOrderGenerated',
      'salesOrder': data,
    }, clients);
    _sendDataToClientsCount++;
    // 🔔 UPDATE UI (THIS IS WHAT YOU WANT)
    final customerProvider = Provider.of<CustomerScreenProvider>(
      navigatorKey.currentContext!,
      listen: false,
    );

    customerProvider.updateReceiptData(salesOrder);
    // STEP 8: Post to API
    bool success = await _syncService.postSalesOrder(salesOrder);

    if (success) {
      data["sync"] = "Yes";
      await HiveManager.salesOrderBox.put(cleanSalesOrderNo, data);
    } else {}
  } catch (e, st) {}
}

Future<void> handleApprovedSaleOrder(Map<String, dynamic> data) async {
  try {
    // STEP 1: Extract sales order data
    final salesOrder = data['data'] ?? data;

    // STEP 5: Save order locally
    await savePosSaleOrderToHive(data, HiveManager.salesOrderBox);

    // Optional: Also save via _syncService
    // await _syncService.savePosSaleorderToHive(data);

    // STEP 7: Notify connected clients
    sendDataToClients({
      'action': 'ApprovedsalesOrderGenerated',
      'salesOrder': data,
    }, clients);
    _sendDataToClientsCount++;

    // STEP 8: Post to API
  } catch (e, st) {}
}

Future<void> handleApprovalSaleOrder(Map<String, dynamic> data) async {
  try {
    // STEP 1: Extract sales order data
    final salesOrder = data['data'] ?? data;

    await savePosSaleOrderToHive(data, HiveManager.salesOrderBox);

    // Optional: Also save via _syncService
    // await _syncService.savePosSaleorderToHive(data);

    // STEP 7: Notify connected clients
    sendDataToClients({
      'action': 'Approved_salesOrder_updated ',
      'salesOrder': data,
    }, clients);
    _sendDataToClientsCount++;
  } catch (e, st) {}
}

Future<void> handleInvoicePatchSaleOrder(Map<String, dynamic> data) async {
  final String soNo = data['saleOrderNo'] ?? '';

  // Open Hive Box
  var saleOrderBox = HiveManager.salesOrderBox;

  // Find matching entry in Hive
  String? targetKey;
  Map<String, dynamic>? existingData;
  for (final entry in saleOrderBox.toMap().entries) {
    final orderData = entry.value['data'];
    if (orderData is Map && orderData['saleOrderNo'] == soNo) {
      targetKey = entry.key.toString();
      existingData = Map<String, dynamic>.from(entry.value);
      break;
    }
  }

  if (targetKey == null || existingData == null) {
    return;
  }

  // Merge patchData into existingData
  final Map<String, dynamic> patchData = Map<String, dynamic>.from(
    data['data'] ?? {},
  );
  final Map<String, dynamic> existingOrderData = Map<String, dynamic>.from(
    existingData['data'] ?? {},
  );

  existingOrderData.addAll(patchData);
  existingData['data'] = existingOrderData;

  await saleOrderBox.put(targetKey, existingData);

  // Notify connected clients
  sendDataToClients({
    'action': 'patchInvoicesaleorderGenerated',
    'saleOrderNo': soNo,
    'patchSaleOrder': existingData,
  }, clients);

  // Sync with server
  try {
    bool success = await _syncService.patchSalesOrder(soNo, existingData);

    if (success) {
      existingData['sync'] = "Yes";
      await saleOrderBox.put(targetKey, existingData);
    } else {}
  } catch (e, stack) {}
}

Future<void> handleInvoiceOrder(Map<String, dynamic> data) async {
  // Extract the sales order data (nested or top-level)
  final salesOrder = data['data'] ?? data;

  // Determine the prefix for the sales order number
  String prefix =
      salesOrder['saleOrderNo']?.toString().trim() ??
      salesOrder['branchAlias']?.toString().trim() ??
      "SOSB";

  // Get new sales order number from API/Hive
  final newSalesOrderNo = await fetchNextInvoiceOrderNumberFromHive(prefix);
  if (newSalesOrderNo == null) {
    return;
  }

  // Clean and update the sales order number
  final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
  salesOrder['saleOrderNo'] = cleanSalesOrderNo;

  // Save the order locally
  await savePosInvoiceOrderToHive(data, HiveManager.salesOrderBox);

  // Notify clients with updated order number
  sendDataToClients({
    'action': 'invoiceGenerated',
    'invoice': data, // now includes updated saleOrderNo
  }, clients);
  _sendDataToClientsCount++;

  // Post to API

  bool success = await _syncService.postInvoiceOrder({
    "data": [salesOrder],
  });

  if (success) {
  } else {}
}

void handleModifyOrder(Map<String, dynamic> data) async {
  // Notify connected clients about the new sales order.
  sendDataToClients({
    'action': 'modifyOrderGenerated',
    'modifyOrder': data,
  }, clients);

  // Save the sales order locally.
  await saveModifyOrderToHive(data);

  // If the sales order data contains a nested "data" key,
  // extract it. Otherwise, fallback to the original data.
  final modifyOrder = data['data'] ?? data;

  // Post the flattened sales order to the FastAPI endpoint.
  bool success = await _syncService.postModifyOrder(modifyOrder);

  // Print result of API call
  if (success) {
  } else {}
}

void handleDiscountApprovalOrder(Map<String, dynamic> data) async {
  // Notify connected clients about the new sales order.
  sendDataToClients({
    'action': 'modifyOrderGenerated',
    'modifyOrder': data,
  }, clients);

  // Save the sales order locally.
  await saveModifyOrderToHive(data);

  // If the sales order data contains a nested "data" key,
  // extract it. Otherwise, fallback to the original data.
  final modifyOrder = data['data'] ?? data;

  // Post the flattened sales order to the FastAPI endpoint.
  bool success = await _syncService.postModifyOrder({
    "data": [modifyOrder],
  });

  if (success) {
  } else {}
}

Future<void> saveToApproveOrderToHive(Map<String, dynamic> data) async {
  // Save the sales approval order to the Hive database
  var modifyOrdersBox = await Hive.openBox('salesOrderToApprove');
  await modifyOrdersBox.add(data);
}

// Define a method to handle adding a customer to a sales order.
Future<void> saveSalesOrderAddCustomerToHive(
  Map<String, dynamic> customerData,
) async {
  // STEP 1: Open Hive Box
  var customerBox = HiveManager.customers;

  // STEP 2: Extract Mobile
  final String? mobile = customerData['mobile'];

  if (mobile == null) {
    return;
  }

  // SAFE DUPLICATE CHECK
  bool exists = false;
  for (var item in customerBox.values) {
    if (item == null) continue;
    if (item is! Map) continue;

    final existing = Map<String, dynamic>.from(item);

    if (existing['mobile'] == mobile) {
      exists = true;
      break;
    }
  }

  if (exists) {
    return;
  }

  // STEP 4: Save Customer
  await customerBox.add(customerData);
}

void handleSalesOrderAddCustomer(Map<String, dynamic> data) async {
  // ─────────────────────────────────────────────
  // STEP 1: Save to Hive with duplicate check
  // ─────────────────────────────────────────────
  await saveSalesOrderAddCustomerToHive(data);

  // ─────────────────────────────────────────────
  // STEP 2: Extract fields for API sync
  // ─────────────────────────────────────────────

  final String? name = data['name'] as String?;
  final String? mobile = data['mobile'] as String?;

  if (name == null || mobile == null) {
    return;
  }

  // ─────────────────────────────────────────────
  // STEP 3: Broadcast to all connected clients
  // ─────────────────────────────────────────────

  sendDataToClients({
    'action': 'salesOrderAddCustomerGenerated',
    'salesOrderAddCustomer': data,
  }, clients);

  // ─────────────────────────────────────────────
  // STEP 4: API Sync
  // ─────────────────────────────────────────────

  final success = await _syncService.postAddNewCustomerOrder(
    name: name,
    mobile: mobile,
  );

  if (success) {
  } else {}
}

void handleToApproveOrder(Map<String, dynamic> data) async {
  // Notify connected clients about the new sales order.

  // Save the sales order locally.
  await saveToApproveOrderToHive(data);

  // If the sales order data contains a nested "data" key,
  // extract it. Otherwise, fallback to the original data.
  final modifyOrder = data['data'] ?? data;

  sendDataToClients({
    'action': 'toApproveOrderGenerated',
    'toApproveOrder': data,
  }, clients);

  // Post the flattened sales order to the FastAPI endpoint.
  bool success = await _syncService.postToApproveOrder({
    "data": [modifyOrder],
  });

  if (success) {
  } else {}
}

Future<void> handleHoldOrder(Map<String, dynamic> data) async {
  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  debugPrint('[SERVER][HOLD ORDER] REQUEST RECEIVED');
  debugPrint(data.toString());

  try {
    // ───────── STEP 1: Extract data ─────────
    final salesOrder = data['data'] ?? data;
    debugPrint('[SERVER][HOLD ORDER] Data extracted');

    // ───────── STEP 2: Generate HOLD order number ─────────
    final newHoldOrderId = await fetchNextHoldOrderNumberFromHive();
    if (newHoldOrderId == null) {
      debugPrint('[SERVER][HOLD ORDER] ❌ Failed to generate HoldOrderId');
      return;
    }

    salesOrder['holdOrderId'] = newHoldOrderId;
    final cleanHoldOrderId = newHoldOrderId;

    debugPrint(
      '[SERVER][HOLD ORDER] Generated HoldOrderId → $cleanHoldOrderId',
    );

    // ───────── STEP 3: Duplicate check ─────────
    debugPrint('[SERVER][HOLD ORDER] Checking duplicate in Hive...');
    final existingOrder = HiveManager.holdOrderBox.get(cleanHoldOrderId);

    if (existingOrder != null) {
      debugPrint('[SERVER][HOLD ORDER] ⚠️ Duplicate found → $cleanHoldOrderId');
      return;
    }

    debugPrint('[SERVER][HOLD ORDER] No duplicate found');

    // ───────── STEP 4: Save Hold Order locally ─────────
    debugPrint('[SERVER][HOLD ORDER] Saving to Hive...');
    await saveHoldOrderToHive(data, HiveManager.holdOrderBox);
    debugPrint('[SERVER][HOLD ORDER] ✅ Saved to Hive');

    // ───────── STEP 5: Send data to connected clients ─────────
    debugPrint('[SERVER][HOLD ORDER] Sending data to clients...');
    sendDataToClients({
      'action': 'holdOrderGenerated',
      'holdOrder': data,
    }, clients);

    _sendDataToClientsCount++;
    debugPrint(
      '[SERVER][HOLD ORDER] 📡 Data sent to clients (count=$_sendDataToClientsCount)',
    );

    // ───────── STEP 6: Sync with backend ─────────
    debugPrint('[SERVER][HOLD ORDER] Syncing with backend...');
    final bool success = await _syncService.postSalesOrder(salesOrder);

    if (success) {
      debugPrint('[SERVER][HOLD ORDER] ✅ Sync SUCCESS');
      data["sync"] = "Yes";

      await HiveManager.holdOrderBox.put(cleanHoldOrderId, data);

      debugPrint(
        '[SERVER][HOLD ORDER] Hive updated with sync=Yes → $cleanHoldOrderId',
      );
    } else {
      debugPrint('[SERVER][HOLD ORDER] ❌ Sync FAILED');
    }
  } catch (e, st) {
    debugPrint('[SERVER][HOLD ORDER] ❌ ERROR → $e');
    debugPrint(st.toString());
  } finally {
    debugPrint('[SERVER][HOLD ORDER] PROCESS COMPLETED');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
}

Future<void> handleSalesApprovalOrder(Map<String, dynamic> data) async {
  try {
    final salesOrder = data['data'] ?? data;

    // STEP 2: Determine Prefix
    String prefix =
        salesOrder['saleOrderNo']?.toString().trim() ??
        salesOrder['aliasName']?.toString().trim() ??
        "SOSB";

    // STEP 3: Fetch next order number from Hive
    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);
    if (newSalesOrderNo == null) {
      return;
    }

    final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
    salesOrder['saleOrderNo'] = cleanSalesOrderNo;

    // STEP 4: Check for duplicates in Hive

    // Save initially to Hive
    await saveSalesApprovalOrderToHive(salesOrder);

    // Notify clients
    sendDataToClients({
      'action': 'salesApprovalOrderGenerated',
      'salesApprovalOrder': data,
    }, clients);

    // Post to server
    bool success = await _syncService.postDiscountOrder(salesOrder);

    if (success) {
      // Update Hive record with sync = Yes
      var box = HiveManager.salesApprovalOrder;

      // Find the last added record (assumption: it's the one we just added)
      int key = box.keys.last as int;
      var savedData = box.get(key);
      savedData['sync'] = "Yes"; // Update sync status
      await box.put(key, savedData);
    } else {}
  } catch (e, stacktrace) {}
}

// ----------------------------------------------------------------------
// SAVE SALES APPROVAL ORDER TO HIVE WITH PRINT STATEMENTS
// ----------------------------------------------------------------------
Future<void> saveSalesApprovalOrderToHive(Map<String, dynamic> data) async {
  try {
    var box = HiveManager.salesApprovalOrder;

    await box.add(data);
  } catch (e, stacktrace) {}
}

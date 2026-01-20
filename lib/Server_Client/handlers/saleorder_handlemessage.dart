import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Server_Client/hive_service.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/sync_service.dart';

import '../../Global/globals_data.dart' as globals;

int _sendDataToClientsCount = 0;
final SyncService _syncService = SyncService();
Future<void> handleOpenSaleOrder(Map<String, dynamic> data) async {
  // Extract the sales order data (nested or top-level)
  final salesOrder = data['data'] ?? data;

  String aliasName = salesOrder['aliasName']?.toString().trim() ?? "";

  // Get new sales order number from API/Hive
  final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(
    prefix: 'SO',
    branchAlias: aliasName,
  );

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

Future<String?> fetchNextSalesOrderNumberFromHive({
  required String prefix,
  required String branchAlias,
}) async {
  final saleOrderNumberBox = HiveManager.salesOrderNumberBox;

  // STEP 1: Determine current year suffix
  final now = DateTime.now();
  final yearSuffix = now.year % 100; // 2026 -> 26

  const sequenceLength = 4; // 0001, 0002, etc.

  // STEP 2: Build the filter key
  final filterKey = '$prefix$branchAlias$yearSuffix';

  // STEP 3: Filter existing numbers for this branch + current year ONLY
  final validNumbers = <String>[];
  final keysToDelete = <dynamic>[];

  for (var key in saleOrderNumberBox.keys) {
    final value = saleOrderNumberBox.get(key);
    if (value is String && value.isNotEmpty) {
      // only include numbers with this prefix + branch + year
      if (value.startsWith(filterKey)) {
        validNumbers.add(value);
      }
    } else {
      keysToDelete.add(key);
    }
  }

  // Delete invalid entries
  for (var key in keysToDelete) {
    await saleOrderNumberBox.delete(key);
  }

  // STEP 4: Determine next sequence for this branch + year
  int nextCount = 1; // default if no previous orders
  if (validNumbers.isNotEmpty) {
    validNumbers.sort((a, b) {
      final seqA = int.tryParse(a.substring(filterKey.length)) ?? 0;
      final seqB = int.tryParse(b.substring(filterKey.length)) ?? 0;
      return seqA.compareTo(seqB);
    });

    final lastOrder = validNumbers.last;
    final lastCountStr = lastOrder.substring(filterKey.length);
    final lastCount = int.tryParse(lastCountStr) ?? 0;
    nextCount = lastCount + 1;
  }

  // STEP 5: Format new order number
  final formattedSequence = nextCount.toString().padLeft(sequenceLength, '0');
  final newOrderNumber = '$filterKey$formattedSequence';

  // STEP 6: Save new number in Hive
  final newKey = DateTime.now().millisecondsSinceEpoch.toString();
  await saleOrderNumberBox.put(newKey, newOrderNumber);

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

  // Extract patch data
  final Map<String, dynamic> patchData = Map<String, dynamic>.from(
    data['data'] ?? {},
  );

  // Get existing order data
  final Map<String, dynamic> existingOrderData = Map<String, dynamic>.from(
    existingData['data'] ?? {},
  );

  // Merge patch data into existing data
  existingOrderData.addAll(patchData);
  existingData['data'] = existingOrderData;

  patchData.keys.forEach((key) {});

  // Save to local storage
  await saleOrderBox.put(targetKey, existingData);

  // Notify connected clients
  sendDataToClients({
    'action': 'patchsaleorderGenerated',
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
    String aliasName = salesOrder['aliasName']?.toString().trim() ?? "";

    // Get new sales order number from API/Hive
    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(
      prefix: 'SO',
      branchAlias: aliasName,
    );

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

// 🔹 HANDLE HOLD ORDER (Server Side)
Future<void> handleHoldOrder(Map<String, dynamic> data) async {
  try {
    // 🧩 Step 1: Validate input
    if (data.isEmpty) {
      return;
    }

    // 🧩 Step 2: Extract holdOrderId safely
    String cleanHoldOrderId = 'UNKNOWN_HOLD_ORDER';

    if (data['data'] != null && data['data'] is Map<String, dynamic>) {
      cleanHoldOrderId = data['data']['holdOrderId'] ?? 'UNKNOWN_HOLD_ORDER';
    } else if (data['holdOrderId'] != null) {
      cleanHoldOrderId = data['holdOrderId'];
    } else {}

    // 🧾 Step 3: Save to Hive
    await saveHoldOrderToHive(data, HiveManager.holdOrderBox);

    // Verify Hive save
    final hiveBox = HiveManager.holdOrderBox;
    final allEntries = hiveBox.toMap();
    allEntries.forEach((key, value) {});

    // 🧮 Step 4: Extract inner map
    Map<String, dynamic> holdOrder;
    if (data['data'] != null && data['data'] is Map<String, dynamic>) {
      holdOrder = Map<String, dynamic>.from(data['data']);
    } else {
      holdOrder = Map<String, dynamic>.from(data);
    }

    // 🔔 Step 5: Notify connected clients
    sendDataToClients({
      'action': 'holdOrderGenerated',
      'holdOrder': data,
    }, clients);

    // 🌐 Step 6: Post to FastAPI server
    bool success = await _syncService.postToHoldOrder(holdOrder);

    // 🧭 Step 7: Update sync status in Hive
    if (success) {
      data["sync"] = "Yes";
      await HiveManager.holdOrderBox.put(cleanHoldOrderId, data);
    } else {}
  } catch (e, st) {
  } finally {}
}

Future<void> handleSalesApprovalOrder(Map<String, dynamic> data) async {
  try {
    final salesOrder = data['data'] ?? data;

    String aliasName = salesOrder['aliasName']?.toString().trim() ?? "";

    // Get new sales order number from API/Hive
    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(
      prefix: 'SO',
      branchAlias: aliasName,
    );

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

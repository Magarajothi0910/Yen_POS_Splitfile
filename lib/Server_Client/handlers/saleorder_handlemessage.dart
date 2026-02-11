import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
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
  print("🟡 fetchNextSalesOrderNumberFromHive() called");
  print("📌 Incoming prefix: $prefix");

  final box = HiveManager.salesOrderNumberBox;

  // 🔹 Current year last 2 digits (2026 → 26)
  final String yearYY = DateTime.now().year.toString().substring(2);
  print("📅 Current year (YY): $yearYY");

  final String basePrefix = '$prefix$yearYY'; // SOKKR26
  print("🔗 Base prefix (prefix + year): $basePrefix");

  final validNumbers = <String>[];
  final keysToDelete = <dynamic>[];

  // STEP 1: Collect valid entries
  print("📦 Scanning Hive salesOrderNumberBox...");
  for (var key in box.keys) {
    final value = box.get(key);
    print("➡️ Key: $key | Value: $value");

    if (value is String && value.startsWith(basePrefix)) {
      validNumbers.add(value);
      print("✅ Valid order number added: $value");
    } else if (value == null || value is! String) {
      keysToDelete.add(key);
      print("🗑️ Marked invalid key for deletion: $key");
    }
  }

  // STEP 2: Cleanup invalid entries
  if (keysToDelete.isNotEmpty) {
    print("🧹 Cleaning invalid Hive entries...");
    for (var key in keysToDelete) {
      await box.delete(key);
      print("🗑️ Deleted key: $key");
    }
  } else {
    print("✅ No invalid entries found");
  }

  // STEP 3: First order for this year
  if (validNumbers.isEmpty) {
    print("🆕 No existing orders found for $basePrefix");
    final firstOrder = '${basePrefix}0001';

    await box.put(DateTime.now().millisecondsSinceEpoch.toString(), firstOrder);

    print("🎉 First sales order generated: $firstOrder");
    return firstOrder;
  }

  // STEP 4: Get last order
  validNumbers.sort();
  final lastOrder = validNumbers.last;
  print("📌 Last order found: $lastOrder");

  // STEP 5: Extract ONLY last 4 digits
  final match = RegExp(r'(\d{4})$').firstMatch(lastOrder);
  final lastCount = int.tryParse(match?.group(1) ?? '0') ?? 0;
  print("🔢 Extracted last counter: $lastCount");

  // STEP 6: Increment
  final nextCount = lastCount + 1;
  final formatted = nextCount.toString().padLeft(4, '0');
  print("➡️ Incremented counter: $formatted");

  final newOrderNumber = '$basePrefix$formatted';
  print("🆕 New sales order number generated: $newOrderNumber");

  // STEP 7: Save
  await box.put(
    DateTime.now().millisecondsSinceEpoch.toString(),
    newOrderNumber,
  );
  print("💾 New order number saved to Hive");

  print("🔚 fetchNextSalesOrderNumberFromHive() completed\n");

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
  print("🔄 Starting PATCH sale order process...");

  final String soNo = data['saleOrderNo'] ?? '';
  print("📋 Target Sale Order Number: $soNo");

  // Open Hive Box
  var saleOrderBox = HiveManager.salesOrderBox;
  print("📦 Opened Hive sales order box");

  // Find matching entry in Hive
  print("🔍 Searching for existing order in local storage...");
  String? targetKey;
  Map<String, dynamic>? existingData;

  for (final entry in saleOrderBox.toMap().entries) {
    final orderData = entry.value['data'];
    if (orderData is Map && orderData['saleOrderNo'] == soNo) {
      targetKey = entry.key.toString();
      existingData = Map<String, dynamic>.from(entry.value);
      print("✅ Found existing order with key: $targetKey");
      break;
    }
  }

  if (targetKey == null || existingData == null) {
    print("❌ No existing order found with number: $soNo");
    print("⚠️ Aborting PATCH operation - order not found");
    return;
  }

  // Extract patch data
  print("📄 Extracting PATCH data...");
  final Map<String, dynamic> patchData = Map<String, dynamic>.from(
    data['data'] ?? {},
  );
  print("📝 PATCH data contains ${patchData.length} fields to update");

  // Get existing order data
  final Map<String, dynamic> existingOrderData = Map<String, dynamic>.from(
    existingData['data'] ?? {},
  );
  print("📊 Existing order has ${existingOrderData.length} fields");

  // Merge patch data into existing data
  print("🔄 Merging PATCH data into existing order...");
  existingOrderData.addAll(patchData);
  existingData['data'] = existingOrderData;

  print("✅ Local merge complete. Updated fields:");
  patchData.keys.forEach((key) {
    print("   • $key: ${patchData[key]}");
  });

  // Save to local storage
  print("💾 Saving updated order to local storage...");
  await saleOrderBox.put(targetKey, existingData);
  print("✅ Local storage updated successfully");

  // Notify connected clients
  print("📢 Notifying connected clients about update...");
  sendDataToClients({
    'action': 'patchsaleorderGenerated',
    'saleOrderNo': soNo,
    'patchSaleOrder': existingData,
  }, clients);
  print("✅ Clients notified");

  // Sync with server
  print("☁️ Starting server synchronization...");
  try {
    bool success = await _syncService.patchSalesOrder(soNo, existingData);

    if (success) {
      print("✅ Server synchronization successful");
      existingData['sync'] = "Yes";
      await saleOrderBox.put(targetKey, existingData);
      print("✅ Local sync status updated to 'Yes'");
    } else {
      print("❌ Server synchronization failed");
      print("⚠️ Order saved locally but not synced to server");
    }
  } catch (e, stack) {
    print("🚨 ERROR during server sync:");
    print("   Exception: $e");
    print("   Stack trace: $stack");
    print("⚠️ Order saved locally but server sync failed with error");
  }

  print("🎉 PATCH sale order process completed for: $soNo");
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
  print("🟡 handleHoldOrder() called");
  print("📥 Incoming data: $data");

  try {
    // 🧩 Step 1: Validate input
    if (data.isEmpty) {
      print("⚠️ Data is empty. Exiting handleHoldOrder()");
      return;
    }

    // 🧩 Step 2: Extract holdOrderId safely
    String cleanHoldOrderId = 'UNKNOWN_HOLD_ORDER';
    print("🔍 Extracting holdOrderId...");

    if (data['data'] != null && data['data'] is Map<String, dynamic>) {
      cleanHoldOrderId = data['data']['holdOrderId'] ?? 'UNKNOWN_HOLD_ORDER';
      print("✅ holdOrderId found inside data['data']: $cleanHoldOrderId");
    } else if (data['holdOrderId'] != null) {
      cleanHoldOrderId = data['holdOrderId'];
      print("✅ holdOrderId found at root level: $cleanHoldOrderId");
    } else {
      print("❌ holdOrderId not found. Using default: $cleanHoldOrderId");
    }

    // 🧾 Step 3: Save to Hive
    print("💾 Saving hold order to Hive...");
    await saveHoldOrderToHive(data, HiveManager.holdOrderBox);
    print("✅ Hold order saved to Hive");

    // 🔍 Verify Hive save
    final hiveBox = HiveManager.holdOrderBox;
    final allEntries = hiveBox.toMap();

    print("📦 Current Hive holdOrderBox entries:");
    allEntries.forEach((key, value) {
      print("➡️ Key: $key | Value: $value");
    });

    // 🧮 Step 4: Extract inner map
    print("🧮 Extracting holdOrder map...");
    Map<String, dynamic> holdOrder;

    if (data['data'] != null && data['data'] is Map<String, dynamic>) {
      holdOrder = Map<String, dynamic>.from(data['data']);
      print("✅ holdOrder extracted from data['data']");
    } else {
      holdOrder = Map<String, dynamic>.from(data);
      print("✅ holdOrder extracted from root data");
    }

    print("📄 holdOrder payload: $holdOrder");

    // 🔔 Step 5: Notify connected clients
    print("📡 Sending holdOrderGenerated event to clients...");
    sendDataToClients({
      'action': 'holdOrderGenerated',
      'holdOrder': data,
    }, clients);
    print("✅ Data sent to connected clients");

    // 🌐 Step 6: Post to FastAPI server
    print("🌐 Syncing hold order to FastAPI server...");
    bool success = await _syncService.postToHoldOrder(holdOrder);

    print("📨 FastAPI response success: $success");

    // 🧭 Step 7: Update sync status in Hive
    if (success) {
      print("🔄 Updating sync status in Hive for $cleanHoldOrderId");
      data["sync"] = "Yes";
      await HiveManager.holdOrderBox.put(cleanHoldOrderId, data);
      print("✅ Sync status updated successfully");
    } else {
      print("⚠️ Sync failed. Will retry later");
    }
  } catch (e, st) {
    print("❌ Exception in handleHoldOrder()");
    print("🧨 Error: $e");
    print("📌 StackTrace: $st");
  } finally {
    print("🔚 handleHoldOrder() completed\n");
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

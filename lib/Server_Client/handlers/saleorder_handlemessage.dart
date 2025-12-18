import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Server_Client/hive_service.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/sync_service.dart';

int _sendDataToClientsCount = 0;
final SyncService _syncService = SyncService();
Future<void> handleOpenSaleOrder(Map<String, dynamic> data) async {
  print("------------------------------------------------------------");
  print("🔵 [handleOpenSaleOrder] Function triggered");
  print("🔵 Incoming RAW data: $data");

  // Extract the sales order data (nested or top-level)
  final salesOrder = data['data'] ?? data;
  print("🟡 Extracted salesOrder object: $salesOrder");

  // Determine the prefix for the sales order number
  String prefix =
      salesOrder['saleOrderNo']?.toString().trim() ??
      salesOrder['branchAlias']?.toString().trim() ??
      "SOSB";

  print("🟣 Determined prefix for Sales Order: $prefix");

  // Get new sales order number from API/Hive
  print("🟠 Requesting next sales order number from Hive...");
  final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);

  if (newSalesOrderNo == null) {
    print("🔴 ERROR: Unable to generate new Sales Order number. Aborting!");
    return;
  }

  print("🟢 New Sales Order No received: $newSalesOrderNo");

  // Clean and update the sales order number
  final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
  salesOrder['saleOrderNo'] = cleanSalesOrderNo;

  print("🟢 Cleaned Sales Order No: $cleanSalesOrderNo");
  print("🟢 Updated salesOrder object before saving: $salesOrder");

  // Save the order locally
  print("🟠 Saving updated Sales Order into Hive...");
  await savePosSaleOrderToHive(data, HiveManager.salesOrderBox);
  print("🟢 Successfully saved Sales Order into Hive.");

  // Notify clients with updated order number
  print("🟠 Broadcasting updated Sales Order to all clients...");
  sendDataToClients({
    'action': 'OpSalesOrderGenerated',
    'opSalesOrder': data, // now includes updated saleOrderNo
  }, clients);
  _sendDataToClientsCount++;

  print(
    "🟢 Broadcast successful. Total messages sent: $_sendDataToClientsCount",
  );

  // Post to API
  print("🟠 Posting Sales Order to API...");
  bool success = await _syncService.postSalesOrder(salesOrder);

  if (success) {
    print("🟢 Sales Order synced to API successfully!");
  } else {
    print("🔴 ERROR syncing Sales Order to API!");
  }

  print("🔵 [handleOpenSaleOrder] Completed.");
  print("------------------------------------------------------------");
}

String generateSalesOrderId(String branchCode, int sequenceNumber) {
  final yearSuffix = DateFormat('yy').format(DateTime.now());
  final sequenceStr = sequenceNumber.toString().padLeft(4, '0');
  return 'SO$branchCode$yearSuffix$sequenceStr';
}

Future<String?> fetchNextSalesOrderNumberFromHive(String prefix) async {
  print("==============================================");
  print("🔵 fetchNextSalesOrderNumberFromHive() CALLED");
  print("➡️ Prefix received: $prefix");
  print("==============================================");

  // STEP 1: Open Hive box
  final saleOrderNumberBox = HiveManager.salesOrderNumberBox;
  print("📦 Hive Box Loaded: $saleOrderNumberBox");
  print("📦 Current Keys: ${saleOrderNumberBox.keys.toList()}");

  // STEP 2: Clean up invalid entries
  final validNumbers = <String>[];
  final keysToDelete = <dynamic>[];

  print("🔍 Validating existing entries...");
  for (var key in saleOrderNumberBox.keys) {
    final value = saleOrderNumberBox.get(key);
    print("➡️ Checking Key: $key | Value: $value");

    if (value is String && value.isNotEmpty) {
      print("✔️ VALID entry found: $value");
      validNumbers.add(value);
    } else {
      print("❌ INVALID entry found → Marking for delete");
      keysToDelete.add(key);
    }
  }

  // Delete invalid entries
  if (keysToDelete.isNotEmpty) {
    print("🧹 Cleaning invalid entries: $keysToDelete");
    for (var key in keysToDelete) {
      await saleOrderNumberBox.delete(key);
      print("❌ Deleted invalid key: $key");
    }
  } else {
    print("👍 No invalid entries found");
  }

  print("📊 Valid Numbers in Box: $validNumbers");

  // STEP 3: If no valid numbers exist, create first number
  if (validNumbers.isEmpty) {
    final newNumber = '${prefix}0001';

    final newKey = DateTime.now().millisecondsSinceEpoch.toString();
    await saleOrderNumberBox.put(newKey, newNumber);

    print("🆕 No existing order numbers → Creating FIRST Number: $newNumber");
    print("💾 Saved FIRST Order Number with key: $newKey");
    print("==============================================");
    return newNumber;
  }

  // STEP 4: Sort valid numbers to get latest
  validNumbers.sort();
  final String lastOrderNumber = validNumbers.last;

  print("🔚 Last Stored Order Number: $lastOrderNumber");
  print("🔢 Extracting numeric part...");

  // STEP 5: Extract numeric part
  String numericPart = '';
  if (lastOrderNumber.startsWith(prefix)) {
    numericPart = lastOrderNumber.substring(prefix.length);
    print("✔️ Prefix matched → Numeric part: $numericPart");
  } else {
    final match = RegExp(r'(\d+)$').firstMatch(lastOrderNumber);
    numericPart = match?.group(1) ?? '0';
    print("⚠️ Prefix mismatch → Regex extracted numeric part: $numericPart");
  }

  // STEP 6: Convert + Increment
  final int lastCount = int.tryParse(numericPart) ?? 0;
  final int nextCount = lastCount + 1;

  print("🔢 Parsed last count: $lastCount");
  print("➕ Incremented count: $nextCount");

  // STEP 7: Format number
  final String formattedNumber = nextCount.toString().padLeft(4, '0');
  final String newOrderNumber = '$prefix$formattedNumber';

  print("🧩 Formatted next order number: $formattedNumber");
  print("🎯 Final Order Number: $newOrderNumber");

  // STEP 8: Save new number using TIMESTAMP KEY (fix)
  final newKey = DateTime.now().millisecondsSinceEpoch.toString();
  await saleOrderNumberBox.put(newKey, newOrderNumber);

  print("💾 Saved new Order Number → Key: $newKey | Value: $newOrderNumber");
  print("==============================================");

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
  print(
    "\n======================= 🔵 PATCH APPROVAL START =======================",
  );
  print("📥 Incoming Patch Data: $data");

  // Extract patch payload (not nested)
  final Map<String, dynamic> patchData = Map<String, dynamic>.from(
    data['data'] ?? {},
  );
  final String soNo = patchData['saleOrderNo'] ?? '';
  print("🆔 Target SaleOrderNo: $soNo");

  // Hive box
  var saleOrderBox = HiveManager.salesApprovalOrder;
  print("📦 Hive Box opened. Total entries: ${saleOrderBox.length}");

  // ========== Debug all entries ==========
  for (var entry in saleOrderBox.toMap().entries) {
    print("🔑 Key: ${entry.key}");
    print("📄 Value: ${entry.value}");
  }

  // Search for matching entry
  String? targetKey;
  Map<String, dynamic>? existingData;

  for (final entry in saleOrderBox.toMap().entries) {
    final orderData = entry.value; // raw map stored in Hive

    if (orderData is Map && orderData['saleOrderNo'] == soNo) {
      targetKey = entry.key.toString();
      existingData = Map<String, dynamic>.from(orderData);
      print("✅ Found matching entry in Hive. Key: $targetKey");
      break;
    }
  }

  if (targetKey == null || existingData == null) {
    print("⚠️ No matching sale order found for SaleOrderNo: $soNo");
    return;
  }

  // EXISTING order data (full map)
  print("📄 Existing Order Data before patch: $existingData");

  // MERGE patch fields directly into the existing Hive map
  existingData.addAll(patchData);

  print("📄 Merged Order Data: $existingData");

  // Save updated entry back to Hive
  await saleOrderBox.put(targetKey, existingData);
  print("💾 Hive updated for key: $targetKey");

  // Broadcast to clients
  sendDataToClients({
    'action': 'approval_updated',
    'saleOrderNo': soNo,
    'patchapprovalSaleOrder': existingData,
  }, clients);

  print("📡 Sent patch update to connected clients.");
  print(
    "======================= 🔵 PATCH APPROVAL END =======================\n",
  );
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
    print('\n[HANDLE ORDER] Received data: $data');

    // STEP 1: Extract sales order data
    final salesOrder = data['data'] ?? data;
    print('[HANDLE ORDER] Extracted sales order: $salesOrder');

    // STEP 2: Determine Prefix
    String prefix =
        salesOrder['saleOrderNo']?.toString().trim() ??
        salesOrder['aliasName']?.toString().trim() ??
        "SOSB";
    print('[HANDLE ORDER] Determined prefix: $prefix');

    // STEP 3: Fetch next order number from Hive
    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);
    if (newSalesOrderNo == null) {
      print(
        '[HANDLE ORDER][WARN] Failed to fetch next sales order number. Aborting.',
      );
      return;
    }
    print('[HANDLE ORDER] Fetched new sales order number: $newSalesOrderNo');

    final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
    salesOrder['saleOrderNo'] = cleanSalesOrderNo;
    print('[HANDLE ORDER] Cleaned sales order number: $cleanSalesOrderNo');

    // STEP 4: Check for duplicates in Hive
    final existingOrder = HiveManager.salesOrderBox.get(cleanSalesOrderNo);
    if (existingOrder != null) {
      print(
        '[HANDLE ORDER][WARN] Sales order $cleanSalesOrderNo already exists in Hive. Skipping save.',
      );
      return;
    }

    // STEP 5: Save order locally
    print('[HANDLE ORDER] Saving sales order to Hive...');
    await savePosSaleOrderToHive(data, HiveManager.salesOrderBox);
    print('[HANDLE ORDER] Sales order saved to Hive successfully.');

    // Optional: Also save via _syncService
    print('[HANDLE ORDER] Saving sales order via _syncService...');
    // await _syncService.savePosSaleorderToHive(data);
    print('[HANDLE ORDER] Sales order saved via _syncService successfully.');

    // STEP 7: Notify connected clients
    print('[HANDLE ORDER] Notifying clients...');
    sendDataToClients({
      'action': 'salesOrderGenerated',
      'salesOrder': data,
    }, clients);
    _sendDataToClientsCount++;
    print(
      '[HANDLE ORDER] Clients notified. Total notifications sent: $_sendDataToClientsCount',
    );

    // STEP 8: Post to API
    print('[HANDLE ORDER] Posting sales order to API...');
    bool success = await _syncService.postSalesOrder(salesOrder);
    print('[HANDLE ORDER] Post result for $cleanSalesOrderNo: $success');

    if (success) {
      data["sync"] = "Yes";
      print('[HANDLE ORDER] Marking sales order as synced in Hive...');
      await HiveManager.salesOrderBox.put(cleanSalesOrderNo, data);
      print('[HANDLE ORDER] Sales order $cleanSalesOrderNo marked as synced.');
    } else {
      print(
        '[HANDLE ORDER][WARN] Failed to post sales order $cleanSalesOrderNo. Will retry later.',
      );
    }
  } catch (e, st) {
    print('[HANDLE ORDER][ERROR] Exception occurred: $e');
    print('[HANDLE ORDER][ERROR] Stack trace: $st');
  }
}

Future<void> handleApprovedSaleOrder(Map<String, dynamic> data) async {
  try {
    print('\n[HANDLE ORDER] Received data: $data');

    // STEP 1: Extract sales order data
    final salesOrder = data['data'] ?? data;
    print('[HANDLE ORDER] Extracted sales order: $salesOrder');

    // STEP 5: Save order locally
    print('[HANDLE ORDER] Saving sales order to Hive...');
    await savePosSaleOrderToHive(data, HiveManager.salesOrderBox);
    print('[HANDLE ORDER] Sales order saved to Hive successfully.');

    // Optional: Also save via _syncService
    print('[HANDLE ORDER] Saving sales order via _syncService...');
    // await _syncService.savePosSaleorderToHive(data);
    print('[HANDLE ORDER] Sales order saved via _syncService successfully.');

    // STEP 7: Notify connected clients
    print('[HANDLE ORDER] Notifying clients...');
    sendDataToClients({
      'action': 'ApprovedsalesOrderGenerated',
      'salesOrder': data,
    }, clients);
    _sendDataToClientsCount++;
    print(
      '[HANDLE ORDER] Clients notified. Total notifications sent: $_sendDataToClientsCount',
    );

    // STEP 8: Post to API
    print('[HANDLE ORDER] Posting sales order to API...');
  } catch (e, st) {
    print('[HANDLE ORDER][ERROR] Exception occurred: $e');
    print('[HANDLE ORDER][ERROR] Stack trace: $st');
  }
}

Future<void> handleApprovalSaleOrder(Map<String, dynamic> data) async {
  try {
    print('\n[HANDLE ORDER] Received data: $data');

    // STEP 1: Extract sales order data
    final salesOrder = data['data'] ?? data;
    print('[HANDLE ORDER] Extracted sales order: $salesOrder');

    await savePosSaleOrderToHive(data, HiveManager.salesOrderBox);
    print('[HANDLE ORDER] Sales order saved to Hive successfully.');

    // Optional: Also save via _syncService
    print('[HANDLE ORDER] Saving sales order via _syncService...');
    // await _syncService.savePosSaleorderToHive(data);
    print('[HANDLE ORDER] Sales order saved via _syncService successfully.');

    // STEP 7: Notify connected clients
    print('[HANDLE ORDER] Notifying clients...');
    sendDataToClients({
      'action': 'Approved_salesOrder_updated ',
      'salesOrder': data,
    }, clients);
    _sendDataToClientsCount++;
    print(
      '[HANDLE ORDER] Clients notified. Total notifications sent: $_sendDataToClientsCount',
    );
  } catch (e, st) {
    print('[HANDLE ORDER][ERROR] Exception occurred: $e');
    print('[HANDLE ORDER][ERROR] Stack trace: $st');
  }
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
  print("📥 handleModifyOrder called with data:");
  print(data);

  // Notify connected clients about the new sales order.
  print("📤 Sending data to connected clients...");
  sendDataToClients({
    'action': 'modifyOrderGenerated',
    'modifyOrder': data,
  }, clients);
  print("✅ Data sent to clients successfully.");

  // Save the sales order locally.
  print("💾 Saving sales order locally to Hive...");
  await saveModifyOrderToHive(data);
  print("✅ Sales order saved to Hive.");

  // If the sales order data contains a nested "data" key,
  // extract it. Otherwise, fallback to the original data.
  final modifyOrder = data['data'] ?? data;
  print("🔹 Modify order payload prepared for API:");
  print(modifyOrder);

  // Post the flattened sales order to the FastAPI endpoint.
  print("🌐 Sending modify order to FastAPI endpoint...");
  bool success = await _syncService.postModifyOrder(modifyOrder);

  // Print result of API call
  if (success) {
    print("✅ Successfully posted modify order to FastAPI.");
  } else {
    print("❌ Failed to post modify order to FastAPI.");
  }
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
  print("====================================================");
  print("🔵 saveSalesOrderAddCustomerToHive() CALLED");
  print("Incoming Customer Data: $customerData");
  print("====================================================");

  // STEP 1: Open Hive Box
  var customerBox = HiveManager.customers;
  print("✔ Hive Box opened. Total existing customers: ${customerBox.length}");

  // STEP 2: Extract Mobile
  final String? mobile = customerData['mobile'];
  print("STEP 2: Extracted Mobile: $mobile");

  if (mobile == null) {
    print("❌ ERROR: Customer mobile number is NULL.");
    return;
  }

  print("STEP 3: Checking for duplicate customer by mobile...");

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
    print("⚠ DUPLICATE FOUND → Mobile already exists in Hive.");
    print("Skipping save operation.");
    return;
  }

  print("✔ No duplicate found. Proceeding to save customer.");

  // STEP 4: Save Customer
  await customerBox.add(customerData);
  print("✔ Customer saved successfully.");
  print("New Hive box count: ${customerBox.length}");

  print("====================================================");
  print("🔵 saveSalesOrderAddCustomerToHive() COMPLETED");
  print("====================================================");
}

void handleSalesOrderAddCustomer(Map<String, dynamic> data) async {
  print("==============================================");
  print("🔵 handleSalesOrderAddCustomer() CALLED");
  print("Incoming Data: $data");
  print("==============================================");

  // ─────────────────────────────────────────────
  // STEP 1: Save to Hive with duplicate check
  // ─────────────────────────────────────────────
  print("STEP 1: Saving customer to Hive...");
  await saveSalesOrderAddCustomerToHive(data);
  print("✔ Customer saved locally (Hive)");

  // ─────────────────────────────────────────────
  // STEP 2: Extract fields for API sync
  // ─────────────────────────────────────────────
  print("STEP 2: Extracting fields...");

  final String? name = data['name'] as String?;
  final String? mobile = data['mobile'] as String?;

  print("Extracted Name   : $name");
  print("Extracted Mobile : $mobile");

  if (name == null || mobile == null) {
    print("❌ ERROR: Name or Mobile is NULL. Aborting sync.");
    return;
  }

  // ─────────────────────────────────────────────
  // STEP 3: Broadcast to all connected clients
  // ─────────────────────────────────────────────
  print("STEP 3: Broadcasting data to clients...");
  print(
    "Broadcast Payload: {    'action': 'salesOrderAddCustomerGenerated',    'salesOrderAddCustomer': $data  }",
  );

  sendDataToClients({
    'action': 'salesOrderAddCustomerGenerated',
    'salesOrderAddCustomer': data,
  }, clients);

  print("✔ Broadcast sent to clients.");

  // ─────────────────────────────────────────────
  // STEP 4: API Sync
  // ─────────────────────────────────────────────
  print("STEP 4: Syncing to Server API...");
  print("Calling API: postAddNewCustomerOrder()");
  print("Payload → Name: $name, Mobile: $mobile");

  final success = await _syncService.postAddNewCustomerOrder(
    name: name,
    mobile: mobile,
  );

  if (success) {
    print("✔ API Sync SUCCESS: Customer added to server.");
  } else {
    print("❌ API Sync FAILED: Check internet or backend logs.");
  }

  print("==============================================");
  print("🔵 handleSalesOrderAddCustomer() COMPLETED");
  print("==============================================");
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
  print("🔵 handleHoldOrder() CALLED");
  print("📦 Incoming data: $data");

  try {
    // 🧩 Step 1: Validate input
    if (data.isEmpty) {
      print("❌ ERROR: Received EMPTY data. Aborting...");
      return;
    }
    print("✅ Step 1: Data is valid");

    // 🧩 Step 2: Extract holdOrderId safely
    print("🔍 Extracting holdOrderId...");
    String cleanHoldOrderId = 'UNKNOWN_HOLD_ORDER';

    if (data['data'] != null && data['data'] is Map<String, dynamic>) {
      cleanHoldOrderId = data['data']['holdOrderId'] ?? 'UNKNOWN_HOLD_ORDER';
      print("➡️ Extracted from data['data']: $cleanHoldOrderId");
    } else if (data['holdOrderId'] != null) {
      cleanHoldOrderId = data['holdOrderId'];
      print("➡️ Extracted from data: $cleanHoldOrderId");
    } else {
      print("⚠️ holdOrderId not found. Using default: $cleanHoldOrderId");
    }

    // 🧾 Step 3: Save to Hive
    print("📥 Saving hold order into Hive...");
    await saveHoldOrderToHive(data, HiveManager.holdOrderBox);
    print("✅ Hold order saved in Hive");

    // Verify Hive save
    final hiveBox = HiveManager.holdOrderBox;
    final allEntries = hiveBox.toMap();
    print("📦 Hive current entries count: ${allEntries.length}");
    allEntries.forEach((key, value) {
      print("   - Key: $key | Value: $value");
    });

    // 🧮 Step 4: Extract inner map
    print("🧩 Extracting actual holdOrder map for syncing...");
    Map<String, dynamic> holdOrder;
    if (data['data'] != null && data['data'] is Map<String, dynamic>) {
      holdOrder = Map<String, dynamic>.from(data['data']);
      print("➡️ holdOrder extracted from data['data']");
    } else {
      holdOrder = Map<String, dynamic>.from(data);
      print("➡️ holdOrder extracted directly from data");
    }
    print("📦 holdOrder: $holdOrder");

    // 🔔 Step 5: Notify connected clients
    print("📡 Sending event to connected clients...");
    sendDataToClients({
      'action': 'holdOrderGenerated',
      'holdOrder': data,
    }, clients);
    print("✅ Clients notified");

    // 🌐 Step 6: Post to FastAPI server
    print("🌍 Syncing Hold Order to FastAPI...");
    bool success = await _syncService.postToHoldOrder(holdOrder);

    print("🌍 Server Response: ${success ? 'SUCCESS' : 'FAILED'}");

    // 🧭 Step 7: Update sync status in Hive
    if (success) {
      print("🔄 Updating sync status in Hive...");
      data["sync"] = "Yes";
      await HiveManager.holdOrderBox.put(cleanHoldOrderId, data);
      print("✅ Sync status updated (Yes)");
    } else {
      print("⚠️ Sync failed. Not updating Hive status.");
    }
  } catch (e, st) {
    print("❌ EXCEPTION in handleHoldOrder(): $e");
    print("📍 STACKTRACE: $st");
  } finally {
    print("🔚 handleHoldOrder() COMPLETED");
  }
}

Future<void> handleSalesApprovalOrder(Map<String, dynamic> data) async {
  try {
    final salesOrder = data['data'] ?? data;

    print('[HANDLE ORDER] Extracted sales order: $salesOrder');

    // STEP 2: Determine Prefix
    String prefix =
        salesOrder['saleOrderNo']?.toString().trim() ??
        salesOrder['aliasName']?.toString().trim() ??
        "SOSB";
    print('[HANDLE ORDER] Determined prefix: $prefix');

    // STEP 3: Fetch next order number from Hive
    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);
    if (newSalesOrderNo == null) {
      print(
        '[HANDLE ORDER][WARN] Failed to fetch next sales order number. Aborting.',
      );
      return;
    }
    print('[HANDLE ORDER] Fetched new sales order number: $newSalesOrderNo');

    final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
    salesOrder['saleOrderNo'] = cleanSalesOrderNo;
    print('[HANDLE ORDER] Cleaned sales order number: $cleanSalesOrderNo');

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
    print('\n[HIVE SAVE] Opening salesApprovalOrder box...');
    var box = HiveManager.salesApprovalOrder;

    print('[HIVE SAVE] Data to insert: $data');
    await box.add(data);

    print('🟦 [HIVE SAVE] Data successfully added to Hive');
  } catch (e, stacktrace) {
    print('🚨 ERROR saving to Hive: $e');
    print('📌 Stacktrace: $stacktrace');
  }
}

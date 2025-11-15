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

  bool success = await _syncService.postSalesOrder({
    "data": [salesOrder],
  });

  if (success) {
  } else {}
}

String generateSalesOrderId(String branchCode, int sequenceNumber) {
  final yearSuffix = DateFormat('yy').format(DateTime.now());
  final sequenceStr = sequenceNumber.toString().padLeft(4, '0');
  return 'SO$branchCode$yearSuffix$sequenceStr';
}

Future<String?> fetchNextSalesOrderNumberFromHive(String prefix) async {
  print("\n🧾 [fetchNextSalesOrderNumberFromHive] --- START ---");
  print("🔹 Prefix received: $prefix");

  // STEP 1: Open the Hive box
  print("\n📦 STEP 1: Opening Hive box 'salesOrderNumberBox'...");
  final saleOrderNumberBox = await Hive.openBox('salesOrderNumberBox');
  print("✅ Box opened successfully. Box name: ${saleOrderNumberBox.name}");
  print("📊 Current box length: ${saleOrderNumberBox.length}");

  // STEP 2: Clean up any invalid entries
  print("\n🧹 STEP 2: Cleaning up invalid entries (non-string or empty)...");
  final validNumbers = <String>[];
  final keysToDelete = <dynamic>[];
  for (var key in saleOrderNumberBox.keys) {
    final value = saleOrderNumberBox.get(key);
    if (value is String && value.isNotEmpty) {
      validNumbers.add(value);
    } else {
      keysToDelete.add(key);
    }
  }

  // Delete invalid entries
  for (var key in keysToDelete) {
    await saleOrderNumberBox.delete(key);
    print("❌ Removed invalid entry at key: $key");
  }

  print("📋 Valid sales order numbers after cleanup: $validNumbers");

  // STEP 3: Handle case when there are no existing order numbers
  if (validNumbers.isEmpty) {
    print(
      "\n🆕 STEP 3: No existing sales order numbers found. Starting fresh...",
    );
    final newNumber = '${prefix}0001';
    await saleOrderNumberBox.add(newNumber);
    print("🧮 New starting number generated & saved: $newNumber");
    print("📦 Updated box content: ${saleOrderNumberBox.values.toList()}");
    print("✅ [fetchNextSalesOrderNumberFromHive] --- END ---\n");
    return newNumber;
  }

  // STEP 4: Get the last stored number
  print("\n🔢 STEP 4: Getting the last stored order number...");
  final String lastOrderNumber = validNumbers.last;
  print("📍 Last stored order number: $lastOrderNumber");

  // STEP 5: Extract numeric part safely
  print("\n🔍 STEP 5: Extracting numeric part from last order number...");
  String numericPart = '';
  if (lastOrderNumber.startsWith(prefix)) {
    numericPart = lastOrderNumber.substring(prefix.length);
    print("✅ Prefix match found. Numeric part: $numericPart");
  } else {
    print("⚠️ Prefix not found in last order number. Using regex fallback...");
    final match = RegExp(r'(\d+)$').firstMatch(lastOrderNumber);
    numericPart = match?.group(1) ?? '0';
    print("🧩 Extracted numeric part using regex: $numericPart");
  }

  // STEP 6: Convert and increment
  print("\n🧮 STEP 6: Incrementing numeric part...");
  final int lastCount = int.tryParse(numericPart) ?? 0;
  final int nextCount = lastCount + 1;
  print("➡️ Last numeric value: $lastCount");
  print("➡️ Incremented numeric value: $nextCount");

  // STEP 7: Pad to 4 digits and format
  print("\n🧱 STEP 7: Formatting new order number...");
  final String formattedNumber = nextCount.toString().padLeft(4, '0');
  final String newOrderNumber = '$prefix$formattedNumber';
  print("🎯 New formatted order number: $newOrderNumber");

  // STEP 8: Save new order number in Hive
  print("\n💾 STEP 8: Saving new order number into Hive...");
  await saleOrderNumberBox.add(newOrderNumber);
  print("✅ Successfully saved: $newOrderNumber");
  print("📦 Updated Hive box content: ${saleOrderNumberBox.values.toList()}");
  print("📊 Total items in box: ${saleOrderNumberBox.length}");

  print("\n🏁 [fetchNextSalesOrderNumberFromHive] --- END ---\n");
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
  print("🟢 handlePatchSaleOrder called for SO No: $soNo");

  // Open Hive Box
  var saleOrderBox = HiveManager.salesOrderBox;
  print(
    "📦 Hive box 'saleOrderBox' opened. Total entries: ${saleOrderBox.length}",
  );

  // Find matching entry in Hive
  String? targetKey;
  Map<String, dynamic>? existingData;
  for (final entry in saleOrderBox.toMap().entries) {
    final orderData = entry.value['data'];
    if (orderData is Map && orderData['saleOrderNo'] == soNo) {
      targetKey = entry.key.toString();
      existingData = Map<String, dynamic>.from(entry.value);
      print("✅ Matching sale order found in Hive. Key: $targetKey");
      break;
    }
  }

  if (targetKey == null || existingData == null) {
    print("⚠️ No matching sale order found for SO No: $soNo");
    return;
  }

  // Merge patchData into existingData
  final Map<String, dynamic> patchData = Map<String, dynamic>.from(
    data['data'] ?? {},
  );
  final Map<String, dynamic> existingOrderData = Map<String, dynamic>.from(
    existingData['data'] ?? {},
  );

  print("🧩 Merging patch data into existing order...");
  print("📄 Patch Data: $patchData");

  existingOrderData.addAll(patchData);
  existingData['data'] = existingOrderData;

  await saleOrderBox.put(targetKey, existingData);
  print("💾 Updated sale order saved back to Hive for SO No: $soNo");

  // Notify connected clients
  print("📤 Sending patch sale order data to clients...");
  sendDataToClients({
    'action': 'patchsaleorderGenerated',
    'saleOrderNo': soNo,
    'patchSaleOrder': existingData,
  }, clients);

  // Sync with server
  try {
    print("🌐 Attempting to sync patched sale order with server...");
    bool success = await _syncService.patchSalesOrder(soNo, existingData);

    if (success) {
      existingData['sync'] = "Yes";
      await saleOrderBox.put(targetKey, existingData);
      print("✅ Sync successful for SO No: $soNo. Marked as synced in Hive.");
    } else {
      print("❌ Sync failed for SO No: $soNo. Will retry later.");
    }
  } catch (e, stack) {
    print("🔥 Error while syncing sale order $soNo: $e");
    print(stack);
  }

  print("🏁 handlePatchSaleOrder completed for SO No: $soNo\n");
}

Future<void> handlePatchwebsocketSaleOrder(Map<String, dynamic> data) async {
  print("🟢 handlePatchSaleOrder triggered with data: $data");

  // Extract sale order number correctly from nested structure
  final soNo = data['data']?['salesOrderNo'] ?? '';
  if (soNo.isEmpty) {
    print("❌ No 'salesOrderNo' found in received data → Cannot proceed.");
    return;
  }

  print("🟢 Processing patch for Sale Order No: $soNo");

  // Access Hive box
  var saleOrderBox = HiveManager.salesOrderBox;
  print(
    "📦 Hive box 'saleOrderBox' opened. Total entries: ${saleOrderBox.length}",
  );

  // Locate matching sale order entry in Hive
  String? targetKey;
  Map<String, dynamic>? existingData;
  for (final entry in saleOrderBox.toMap().entries) {
    final orderData = entry.value['data'];
    if (orderData is Map && orderData['saleOrderNo'] == soNo) {
      targetKey = entry.key.toString();
      existingData = Map<String, dynamic>.from(entry.value);
      print("✅ Found matching sale order in Hive. Key: $targetKey");
      break;
    }
  }

  if (targetKey == null || existingData == null) {
    print("⚠️ No matching sale order found in Hive for SO No: $soNo");
    return;
  }

  // Merge patch data into existing order
  final patchData = Map<String, dynamic>.from(data['data'] ?? {});
  final existingOrderData = Map<String, dynamic>.from(
    existingData['data'] ?? {},
  );

  print("🧩 Merging patch data → ${patchData.keys.toList()}");
  existingOrderData.addAll(patchData);
  existingData['data'] = existingOrderData;

  // Save back to Hive
  await saleOrderBox.put(targetKey, existingData);
  print("💾 Hive updated for SO No: $soNo");

  // Notify all connected clients
  print("📤 Broadcasting updated sale order to connected clients...");
  sendDataToClients({
    'action': 'patchsaleorderGenerated',
    'saleOrderNo': soNo,
    'patchSaleOrder': existingData,
  }, clients);

  // Sync with API server
  try {
    print("🌐 Syncing patched sale order with backend...");
    bool success = await _syncService.patchSalesOrder(soNo, existingData);

    if (success) {
      existingData['sync'] = "Yes";
      await saleOrderBox.put(targetKey, existingData);
      print("✅ Sync success for SO No: $soNo");
    } else {
      print("❌ Sync failed for SO No: $soNo → will retry later.");
    }
  } catch (e, stack) {
    print("🔥 Exception during sync for $soNo → $e");
    print(stack);
  }

  print("🏁 handlePatchSaleOrder completed for SO No: $soNo\n");
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
  print("\n🧾 [HANDLE SALE ORDER] --- START ---");

  try {
    // STEP 1: Extract sales order data
    print("🔍 STEP 1: Extracting sales order data...");
    final salesOrder = data['data'] ?? data;
    print("📦 Extracted Data Keys: ${salesOrder.keys.toList()}");

    // STEP 2: Determine Prefix
    print("🔍 STEP 2: Determining prefix...");
    String prefix =
        salesOrder['saleOrderNo']?.toString().trim() ??
        salesOrder['aliasName']?.toString().trim() ??
        "SOSB";
    print("🧩 Prefix determined: $prefix");

    // STEP 3: Fetch next order number
    print("🔍 STEP 3: Fetching next Sales Order Number from Hive...");
    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);
    if (newSalesOrderNo == null) {
      print("⚠️ Failed to fetch new Sales Order number. Aborting.");
      return;
    }

    final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
    salesOrder['saleOrderNo'] = cleanSalesOrderNo;
    print("🆕 Generated Sales Order No: $cleanSalesOrderNo");

    // STEP 4: Check for duplicates in Hive
    print("🔍 STEP 4: Checking for existing order in Hive...");
    final existingOrder = HiveManager.salesOrderBox.get(cleanSalesOrderNo);
    if (existingOrder != null) {
      print(
        "⚠️ Order already exists in Hive with No: $cleanSalesOrderNo. Skipping duplicate.",
      );
      return;
    }

    // STEP 5: Save order locally
    print("💾 STEP 5: Saving order locally to Hive...");
    await savePosSaleOrderToHive(data, HiveManager.salesOrderBox);
    print("✅ Saved order locally (HiveManager).");

    print("💾 Saving order locally via SyncService...");
    await _syncService.savePosSaleorderToHive(data);
    print("✅ Saved order locally (SyncService).");

    // STEP 7: Notify clients
    print("📡 STEP 6: Broadcasting to connected clients...");
    sendDataToClients({
      'action': 'salesOrderGenerated',
      'salesOrder': data,
    }, clients);
    _sendDataToClientsCount++;
    print(
      "✅ Broadcast sent to ${clients.length} clients. Total sends: $_sendDataToClientsCount",
    );

    // STEP 8: Post to API
    print("🌐 STEP 7: Posting Sales Order to API server...");
    bool success = await _syncService.postSalesOrder({
      "data": [salesOrder],
    });

    if (success) {
      data["sync"] = "Yes";
      await HiveManager.salesOrderBox.put(cleanSalesOrderNo, data);
      print("✅ API Post success. Order marked as synced and updated in Hive.");
    } else {
      print("❌ API Post failed. Order remains unsynced (sync=No).");
    }
  } catch (e, st) {
    print("❌ [HANDLE SALE ORDER] Exception: $e");
    print("🧾 StackTrace:\n$st");
  }

  print("🧾 [HANDLE SALE ORDER] --- END ---\n");
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
  bool success = await _syncService.postModifyOrder({
    "data": [modifyOrder],
  });

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
  var customerBox = await Hive.openBox('customerBox');
  final String? mobile = customerData['mobile'];

  if (mobile == null) {
    return;
  }

  // ── Check for duplicates ──
  final exists = customerBox.values.any((customer) {
    final existing = Map<String, dynamic>.from(customer);
    return existing['mobile'] == mobile;
  });

  if (exists) {
    return;
  }

  // ── Save new customer ──
  await customerBox.add(customerData);
}

void handleSalesOrderAddCustomer(Map<String, dynamic> data) async {
  // ── Save locally (with duplicate check)
  await saveSalesOrderAddCustomerToHive(data);

  // ── Extract fields for API sync
  final String? name = data['name'] as String?;
  final String? mobile = data['mobile'] as String?;
  final String? branch = data['branchId'] as String?;

  if (name == null || mobile == null) {
    return;
  }

  // ── broadcast to clients
  sendDataToClients({
    'action': 'salesOrderAddCustomerGenerated',
    'salesOrderAddCustomer': data,
  }, clients);

  final success = await _syncService.postAddNewCustomerOrder(
    name: name,
    mobile: mobile,
    branchId: branch,
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
    }

    // 🧾 Step 3: Save to Hive
    await saveHoldOrderToHive(data, HiveManager.holdOrderBox);

    // Verify Hive save
    final hiveBox = HiveManager.holdOrderBox;
    final allEntries = hiveBox.toMap();
    for (final entry in allEntries.entries) {}

    // 🧮 Step 4: Extract inner hold order map
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
    bool success = await _syncService.postToHoldOrder({"data": holdOrder});

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

    // Save initially to Hive
    await saveSalesApprovalOrderToHive(data);

    // Notify clients
    sendDataToClients({
      'action': 'salesApprovalOrderGenerated',
      'salesApprovalOrder': data,
    }, clients);

    // Post to server
    bool success = await _syncService.postDiscountOrder({
      "data": [salesOrder],
    });

    if (success) {
      // Update Hive record with sync = Yes
      var box = await Hive.openBox('salesApprovalOrder');

      // Find the last added record (assumption: it's the one we just added)
      int key = box.keys.last as int;
      var savedData = box.get(key);
      savedData['sync'] = "Yes"; // Update sync status
      await box.put(key, savedData);
    } else {}
  } catch (e, stacktrace) {}
}

// Function to save sales approval order to Hive
Future<void> saveSalesApprovalOrderToHive(Map<String, dynamic> data) async {
  try {
    var box = await Hive.openBox('salesApprovalOrder');
    await box.add(data);
  } catch (e, stacktrace) {}
}

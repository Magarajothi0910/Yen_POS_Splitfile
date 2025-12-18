import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Server_Client/handlers/patch_handler.dart';

Future<void> handleStockDecreaseUpdate(Map<String, dynamic> data) async {
  try {
    final branchAlias = data['branchAlias']?.toString() ?? '';
    final varianceCodes = List<String>.from(data['varianceCode'] ?? []);
    final varianceNames = List<String>.from(data['varianceNames'] ?? []);
    final stockUpdates = List<int>.from(data['stockUpdates'] ?? []);

    if (branchAlias.isEmpty ||
        varianceCodes.isEmpty ||
        varianceNames.isEmpty ||
        stockUpdates.isEmpty) {
      return;
    }

    // Load Hive box where stock data is stored
    final box = await Hive.openBox('branchwiseStock');
    final existingData = Map<String, dynamic>.from(box.get('data') ?? {});

    // Update stock locally
    for (int i = 0; i < varianceCodes.length; i++) {
      final varCode = varianceCodes[i];
      final varName = varianceNames[i];
      final decreaseQty = stockUpdates[i];

      existingData.forEach((itemKey, itemValue) {
        final item = Map<String, dynamic>.from(itemValue);
        final varianceMap = Map<String, dynamic>.from(item['variance'] ?? {});

        varianceMap.forEach((vKey, vValue) {
          final variance = Map<String, dynamic>.from(vValue);
          if (variance['varianceitemCode'] == varCode &&
              variance['varianceName'] == varName) {
            final branchMap = Map<String, dynamic>.from(
              variance['branchwise'] ?? {},
            );
            final branchData = Map<String, dynamic>.from(
              branchMap[branchAlias] ?? {},
            );

            final stockKey = 'systemStock_$branchAlias';
            int currentStock =
                int.tryParse(branchData[stockKey]?.toString() ?? '0') ?? 0;
            int updatedStock = (currentStock - decreaseQty).clamp(0, 999999);

            branchData[stockKey] = updatedStock;
            branchMap[branchAlias] = branchData;
            variance['branchwise'] = branchMap;
            varianceMap[vKey] = variance;
            item['variance'] = varianceMap;
            existingData[itemKey] = item;
          }
        });
      });
    }

    // Save updated data back to Hive
    await box.put('data', existingData);
  } catch (e, st) {}
}

Future<void> saveApproveOrderToHive(Map<String, dynamic> salesOrder) async {
  // Step 1: Open Hive box
  var approveOrderBox = await Hive.openBox('salesApprovalOrder');

  // Step 2: Extract and clean order data
  Map<String, dynamic> orderToSave = salesOrder;

  if (salesOrder.containsKey('data') &&
      salesOrder['data'] is List &&
      (salesOrder['data'] as List).isNotEmpty) {
    orderToSave = Map<String, dynamic>.from((salesOrder['data'] as List).first);
  } else {}

  // Step 3: Validate and extract saleOrderNo
  final saleOrderNo = orderToSave['saleOrderNo']?.toString();
  if (saleOrderNo == null) {
    return;
  }

  // Step 4: Check for duplicates
  final exists = approveOrderBox.values.any((storedOrder) {
    if (storedOrder is Map<String, dynamic>) {
      return storedOrder['saleOrderNo']?.toString() == saleOrderNo;
    }
    return false;
  });

  // Step 5: Save or skip
  if (!exists) {
    await approveOrderBox.add(orderToSave);
  } else {}
}

Future<void> saveAddNewCustomerToHive(Map<String, dynamic> customerData) async {
  var customerBox = HiveManager.customers;

  final newMobile = customerData['mobile']?.toString() ?? '';

  // 🔎 Check if mobile number already exists in Hive
  bool exists = customerBox.values.any((customer) {
    final existingMobile = customer['mobile']?.toString() ?? '';
    return existingMobile == newMobile;
  });

  if (exists) {
  } else {
    await customerBox.add(customerData);
  }
}

Future<List<Map<String, dynamic>>> getAddnewCustomer() async {
  var customerBox = HiveManager.customers;
  final customers = customerBox.values
      .map((customer) => Map<String, dynamic>.from(customer))
      .toList();

  return customers;
}

Future<void> saveModifyOrderToHive(Map<String, dynamic> salesOrder) async {
  var approveOrderBox = HiveManager.modifyOrderBox;
  Map<String, dynamic> orderToSave = salesOrder;
  // If the salesOrder has a nested 'data' key with a list, use its first element.
  if (salesOrder.containsKey('data') &&
      salesOrder['data'] is List &&
      (salesOrder['data'] as List).isNotEmpty) {
    orderToSave = Map<String, dynamic>.from((salesOrder['data'] as List).first);
  }
  await approveOrderBox.add(orderToSave);
}

Map<String, int> saleOrderNoCounts = {};

Future<List<Map<String, dynamic>>> getSavedSalesOrders() async {
  try {
    final saleOrderBox = HiveManager.salesOrderBox;

    final seenSaleOrderNos = <String>{};
    final uniqueOrders = <Map<String, dynamic>>[];
    final keysToDelete = <dynamic>[];

    final allEntries = saleOrderBox.toMap();

    for (final entry in allEntries.entries) {
      final key = entry.key;
      final order = entry.value;

      if (order is! Map) {
        keysToDelete.add(key);
        continue;
      }

      final orderMap = Map<String, dynamic>.from(order);
      final dataMap = orderMap['data'] is Map
          ? Map<String, dynamic>.from(orderMap['data'])
          : orderMap;

      final saleOrderNo = dataMap['saleOrderNo']?.toString().trim();

      if (saleOrderNo == null || saleOrderNo.isEmpty) {
        keysToDelete.add(key);
        continue;
      }

      if (seenSaleOrderNos.contains(saleOrderNo)) {
        // Duplicate found, mark for deletion if key != saleOrderNo
        if (key.toString() != saleOrderNo) {
          keysToDelete.add(key);
        }
      } else {
        seenSaleOrderNos.add(saleOrderNo);
        uniqueOrders.add(orderMap);
      }
    }

    if (keysToDelete.isNotEmpty) {
      await saleOrderBox.deleteAll(keysToDelete);
    }

    return uniqueOrders;
  } catch (e, st) {
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> getSavedHoldOrders() async {
  try {
    final saleOrderBox = HiveManager.holdOrderBox;

    print("📦 Hive holdOrderBox opened. Total entries: ${saleOrderBox.length}");
    print("💾 Hive box content:");
    saleOrderBox.toMap().forEach((key, value) {
      print("  Key: $key, Value: $value");
    });

    final seenIds = <String>{};
    final uniqueOrders = <Map<String, dynamic>>[];
    final keysToDelete = <dynamic>[];

    for (var entry in saleOrderBox.toMap().entries) {
      final key = entry.key;
      final order = entry.value;

      print("\n🔹 Processing entry with key: $key");
      print("Original order from Hive: $order");

      if (order is Map) {
        // Convert Hive Map<dynamic, dynamic> to Map<String, dynamic> safely
        final orderMap = Map<String, dynamic>.from(
          order.map((k, v) => MapEntry(k.toString(), v)),
        );

        print("Converted orderMap: $orderMap");

        // Extract nested 'data' safely
        final dataMap = orderMap['data'] is Map
            ? Map<String, dynamic>.from(
                (orderMap['data'] as Map).map(
                  (k, v) => MapEntry(k.toString(), v),
                ),
              )
            : Map<String, dynamic>.from(orderMap);

        print("Extracted dataMap: $dataMap");

        final holdOrderId = dataMap['holdOrderId'] as String?;
        print("holdOrderId: $holdOrderId");

        if (holdOrderId != null) {
          if (!seenIds.contains(holdOrderId)) {
            print(
              "✅ New holdOrderId found: $holdOrderId. Adding to uniqueOrders.",
            );
            seenIds.add(holdOrderId);
            uniqueOrders.add(orderMap);
          } else {
            print(
              "⚠️ Duplicate holdOrderId found: $holdOrderId. Marking key $key for deletion.",
            );
            keysToDelete.add(key);
          }
        } else {
          print("❌ holdOrderId is null for key: $key. Skipping.");
        }
      } else {
        print("❌ Entry is not a Map. Skipping key: $key");
      }
    }

    if (keysToDelete.isNotEmpty) {
      print("🗑 Deleting duplicate keys: $keysToDelete");
      await saleOrderBox.deleteAll(keysToDelete);
    } else {
      print("✅ No duplicates found. No deletion needed.");
    }

    print("📊 Total unique orders: ${uniqueOrders.length}");
    return uniqueOrders;
  } catch (e, stackTrace) {
    print("❌ Error in getSavedHoldOrders: $e");
    print(stackTrace);
    rethrow;
  }
}

Future<void> saveInvoiceToHive(Map<String, dynamic> invoiceData) async {
  try {
    print("🚀 [saveInvoiceToHive] Function called");

    // Step 1: Open Hive box
    var invoiceBox = HiveManager.invoiceBox;
    print("📦 [Step 1] Invoice box opened successfully");

    // Step 2: Extract sales order safely
    final salesOrder = invoiceData['salesOrderId'];
    if (salesOrder == null) {
      print("⚠️ [Step 2] salesOrderId is null in invoiceData: $invoiceData");
      return;
    }
    if (salesOrder is! Map<String, dynamic>) {
      print("⚠️ [Step 2] salesOrderId is not a Map: $salesOrder");
      return;
    }
    print("✅ [Step 2] Extracted salesOrder: $salesOrder");

    // Step 3: Get order invoice number
    final orderInvoiceNo = salesOrder['invoiceNo']?.toString();
    if (orderInvoiceNo == null || orderInvoiceNo.isEmpty) {
      print(
        "⚠️ [Step 3] invoiceNo is missing or empty in salesOrder: $salesOrder",
      );
      return;
    }
    print("✅ [Step 3] Invoice number extracted: $orderInvoiceNo");

    // Step 4: Check if invoice already exists
    if (invoiceBox.containsKey(orderInvoiceNo)) {
      print(
        "ℹ️ [Step 4] Invoice already exists in Hive with key: $orderInvoiceNo",
      );
      return;
    }
    print("✅ [Step 4] Invoice does not exist yet. Proceeding to save.");

    // Step 5: Save invoice to Hive
    await invoiceBox.put(orderInvoiceNo, invoiceData);
    print("💾 [Step 5] Invoice saved successfully: $orderInvoiceNo");

    // Optional: Log current total invoices
    print("📊 Total invoices in Hive now: ${invoiceBox.length}");
  } catch (e, st) {
    print("❌ [saveInvoiceToHive] Error saving invoice: $e");
    print("📄 Stack trace: $st");
  }
}

Future<List<Map<String, dynamic>>> getInvoiceOrders() async {
  try {
    final invoiceBox = HiveManager.invoiceBox;

    // ✅ Collect values as Map
    final rawInvoices = invoiceBox.keys
        .map((key) {
          final value = invoiceBox.get(key);
          if (value is Map<String, dynamic>) {
            return Map<String, dynamic>.from(value);
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    // ✅ Ensure uniqueness by orderInvoiceNo
    final Set<String> seen = {};
    final uniqueInvoices = <Map<String, dynamic>>[];

    for (var inv in rawInvoices) {
      final orderNo = inv['salesOrderId']?['orderInvoiceNo']?.toString();
      if (orderNo != null && orderNo.isNotEmpty) {
        if (seen.add(orderNo)) {
          uniqueInvoices.add(inv); // only first occurrence added
        }
      }
    }

    return uniqueInvoices;
  } catch (e, st) {
    return [];
  }
}

Future<List<Map<String, dynamic>>> getSavedHoldOrder() async {
  // var holdOrderBox = await Hive.openBox('holdSalesOrderBox');
  try {
    var holdOrderBox = HiveManager.holdOrderBox;

    final seenHoldOrderNos = <String>{};
    final uniqueOrders = <Map<String, dynamic>>[];
    final keysToDelete = <dynamic>[];

    for (var entry in holdOrderBox.toMap().entries) {
      final key = entry.key;
      final order = entry.value;

      if (order is Map) {
        final orderMap = Map<String, dynamic>.from(order);
        // Check for saleOrderNo in the nested data map
        final dataMap = orderMap['data'] is Map
            ? Map<String, dynamic>.from(orderMap['data'])
            : orderMap;
        final saleOrderNo = dataMap['holdOrderId'] as String?;

        if (saleOrderNo != null) {
          if (!seenHoldOrderNos.contains(saleOrderNo)) {
            seenHoldOrderNos.add(saleOrderNo);
            uniqueOrders.add(orderMap);
          } else {
            keysToDelete.add(key);
          }
        }
      }
    }

    await holdOrderBox.deleteAll(keysToDelete);
    return uniqueOrders;
  } catch (e) {
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> getSavedApprovalOrder() async {
  var box = HiveManager.salesApprovalOrder;

  print("🔹 Opening Hive box for approval orders...");

  if (box.isEmpty) {
    print("⚠️ The approval order box is empty. Returning empty list.");
    return [];
  }

  print("✅ The box has ${box.length} records.");

  print("🔹 Iterating through Hive box contents (key -> value):");
  box.toMap().forEach((key, value) {
    print("   🔑 Key: $key");
    print("   📦 Value: $value");
  });

  // --------------------------------------------------------
  // 🔥 STEP 1: Remove duplicates based on saleOrderNo
  // --------------------------------------------------------
  print("🔍 Checking for duplicate saleOrderNo entries...");

  Map<String, dynamic> latestEntryMap = {}; // saleOrderNo → key
  List<dynamic> keysToDelete = [];

  box.toMap().forEach((key, value) {
    final orderMap = Map<String, dynamic>.from(value);
    final saleOrderNo = orderMap['saleOrderNo']?.toString() ?? "";

    if (saleOrderNo.isEmpty) return;

    if (latestEntryMap.containsKey(saleOrderNo)) {
      // ❌ Duplicate found — delete old one
      print(
        "❌ Duplicate found for SaleOrderNo: $saleOrderNo → Removing older entry (Key: $key)",
      );
      keysToDelete.add(key);
    } else {
      latestEntryMap[saleOrderNo] = key; // store unique key
    }
  });

  // Delete duplicates from Hive
  for (var delKey in keysToDelete) {
    await box.delete(delKey);
    print("🗑️ Deleted duplicate Hive entry with Key: $delKey");
  }

  print("✅ Duplicate removal complete. Final count: ${box.length}");

  // --------------------------------------------------------
  // 🔥 STEP 2: Return all cleaned approval orders
  // --------------------------------------------------------
  final orders = box.values.map((order) {
    final convertedOrder = Map<String, dynamic>.from(order);
    print("   📝 Converted order: $convertedOrder");
    return convertedOrder;
  }).toList();

  print("🔹 Returning ${orders.length} approval orders.");
  return orders;
}

Future<List<Map<String, dynamic>>> getModifyOrder() async {
  try {
    // var modifyOrderBox = await Hive.openBox('modifyOrderBox');

    final modifyOrderBox = HiveManager.modifyOrderBox;
    final seenSaleOrderNos = <String>{};
    final uniqueOrders = <Map<String, dynamic>>[];

    for (var order in modifyOrderBox.values) {
      if (order is Map) {
        final orderMap = Map<String, dynamic>.from(order);
        final saleOrderNo = orderMap['saleOrderNo'] as String?;

        if (saleOrderNo != null && !seenSaleOrderNos.contains(saleOrderNo)) {
          seenSaleOrderNos.add(saleOrderNo);
          uniqueOrders.add(orderMap);
        }
      }
    }

    return uniqueOrders;
  } catch (e) {
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> getToApproveOrder() async {
  try {
    final modifyOrderBox = HiveManager.toApproveOrderBox;
    final seenSaleOrderNos = <String>{};
    final uniqueOrders = <Map<String, dynamic>>[];
    for (var order in modifyOrderBox.values) {
      if (order is Map) {
        final orderMap = Map<String, dynamic>.from(order);
        final saleOrderNo = orderMap['saleOrderNo'] as String?;

        if (saleOrderNo != null && !seenSaleOrderNos.contains(saleOrderNo)) {
          seenSaleOrderNos.add(saleOrderNo);
          uniqueOrders.add(orderMap);
        }
      }
    }

    return uniqueOrders;
  } catch (e) {
    rethrow;
  }
}

Future<void> patchHoldOrder(Map<String, dynamic> patchData) async {
  final box = HiveManager.holdOrderBox;
  final holdOrderId = patchData['holdOrderId'];
  if (holdOrderId == null) {
    return;
  }

  dynamic existingKey;
  dynamic existingOrder;

  for (var key in box.keys) {
    final value = box.get(key);
    if (value is Map && value['holdOrderId'] == holdOrderId) {
      existingKey = key;
      existingOrder = value;
      break;
    }
  }

  if (existingKey != null) {
    // Merge existing data with new data
    final updatedOrder = {...existingOrder, ...patchData};

    await box.put(existingKey, updatedOrder);
  } else {
    await box.add(patchData);
  }
}

Future<void> putOrder(dynamic key, Map<String, dynamic> order) async {
  await HiveManager.salesOrderBox.put(key, order);
  await HiveManager.salesOrderBox.flush();
  await HiveManager.salesOrderBox.compact();
}

Future<void> handlePatchSaleOrderMessage(
  Map<String, dynamic> messageData,
) async {
  print('\n=============== HANDLE PATCH SALE ORDER MESSAGE ===============');
  print('📥 Incoming Patch Message: $messageData');

  try {
    // STEP 1️⃣ Extract saleOrderNo
    print('\n----------- STEP 1: Extract saleOrderNo -----------');

    final saleOrderNo =
        messageData['saleOrderNo']?.toString() ??
        messageData['patchSaleOrder']?['saleOrderNo']?.toString() ??
        messageData['patchSaleOrder']?['data']?['saleOrderNo']?.toString();

    print('🔍 Extracted saleOrderNo: $saleOrderNo');

    if (saleOrderNo == null || saleOrderNo.isEmpty) {
      print('⚠️ No saleOrderNo found. Stop patch process.');
      return;
    }

    // STEP 2️⃣ Extract patch data
    print('\n----------- STEP 2: Extract Patch Data -----------');

    final patchData = Map<String, dynamic>.from(
      messageData['patchSaleOrder']?['data'] ?? {},
    );

    print('🟦 Patch Data Extracted: $patchData');

    if (patchData.isEmpty) {
      print('⚠️ Patch data is empty. Nothing to update.');
      return;
    }

    print('🔄 Iterating Patch Fields:');
    for (final entry in patchData.entries) {
      print('   ➤ ${entry.key} = ${entry.value}');
    }

    // STEP 3️⃣ Access Hive box
    print('\n----------- STEP 3: Access Hive Box -----------');
    final saleOrderBox = HiveManager.salesOrderBox;
    print('📦 Hive Box Loaded (salesOrderBox)');
    print('📊 Total Entries in Hive: ${saleOrderBox.length}');

    // STEP 4️⃣ Locate the existing order
    print('\n----------- STEP 4: Locate Existing Order -----------');

    final allEntries = saleOrderBox.toMap();
    print('🔍 Total Entries to Search: ${allEntries.length}');

    final matchingEntry = allEntries.entries.firstWhere((entry) {
      final entryData = entry.value['data'] ?? entry.value;
      return entryData is Map &&
          entryData['saleOrderNo']?.toString() == saleOrderNo;
    }, orElse: () => const MapEntry('', null));

    if (matchingEntry.key == '') {
      print('❌ No matching order found for saleOrderNo: $saleOrderNo');
      return;
    }

    print('✅ Matching Entry Found at Key: ${matchingEntry.key}');
    print('📄 Existing Order Value: ${matchingEntry.value}');

    // STEP 5️⃣ Load existing order data
    print('\n----------- STEP 5: Load Existing Order Data -----------');

    final existingValue = Map<String, dynamic>.from(matchingEntry.value ?? {});
    final existingData = Map<String, dynamic>.from(existingValue['data'] ?? {});

    print('📄 Existing Data Before Patch: $existingData');

    // STEP 6️⃣ Merge patch data
    print('\n----------- STEP 6: Merge Patch Data -----------');

    patchData.forEach((key, value) {
      if (existingData.containsKey(key)) {
        print(
          '✏️ Updating field: $key | Old: ${existingData[key]} → New: $value',
        );
      } else {
        print('➕ Adding new field: $key = $value');
      }
      existingData[key] = value;
    });

    print('🟢 Merged Data: $existingData');

    // STEP 7️⃣ Save updated order back to Hive
    print('\n----------- STEP 7: Save Back to Hive -----------');

    existingValue['data'] = existingData;
    existingValue['lastUpdated'] = DateTime.now().toIso8601String();

    await saleOrderBox.put(matchingEntry.key, existingValue);
    print('💾 Hive Updated Successfully at Key: ${matchingEntry.key}');

    // STEP 8️⃣ Verification
    print('\n----------- STEP 8: Verify Saved Data -----------');

    final savedOrder = saleOrderBox.get(matchingEntry.key);
    if (savedOrder != null) {
      print('🟩 Verification Success! Saved Order: $savedOrder');
    } else {
      print('❌ Verification Failed! Could not read saved data.');
    }

    print('\n=============== END PATCH SALE ORDER MESSAGE ===============\n');
  } catch (e, st) {
    print('🚨 ERROR in handlePatchSaleOrderMessage: $e');
    print('📌 Stacktrace: $st');
  }
}

Future<void> handlePatchSaleApprovalOrderMessage(
  Map<String, dynamic> messageData,
) async {
  print('\n=============== HANDLE PATCH SALE APPROVAL ORDER ===============');
  print('📥 Incoming Patch Message: $messageData');

  try {
    // STEP 1️⃣ Extract saleOrderNo
    print('\n----------- STEP 1: Extract saleOrderNo -----------');

    final saleOrderNo =
        messageData['saleOrderNo']?.toString() ??
        messageData['patchapprovalSaleOrder']?['saleOrderNo']?.toString();

    print('🔍 Extracted saleOrderNo: $saleOrderNo');

    if (saleOrderNo == null || saleOrderNo.isEmpty) {
      print('⚠️ No saleOrderNo found. Stopping patch process.');
      return;
    }

    // STEP 2️⃣ Extract patch data (NO inner .data)
    print('\n----------- STEP 2: Extract Patch Data -----------');

    final patchData = Map<String, dynamic>.from(
      messageData['patchapprovalSaleOrder'] ?? {},
    );

    print('🟦 Patch Data Extracted: $patchData');

    if (patchData.isEmpty) {
      print('⚠️ Patch data is empty! Check incoming server data.');
      return;
    }

    print('🔄 Patch Fields:');
    patchData.forEach((key, value) {
      print('   ➤ $key = $value');
    });

    // STEP 3️⃣ Access Hive box
    print('\n----------- STEP 3: Access Hive Box -----------');

    final saleOrderBox = HiveManager.salesApprovalOrder;
    print('📦 Hive Box Loaded');
    print('📊 Total Entries in Hive: ${saleOrderBox.length}');

    // STEP 4️⃣ Locate the existing order
    print('\n----------- STEP 4: Locate Existing Order -----------');

    final allEntries = saleOrderBox.toMap();

    final matchingEntry = allEntries.entries.firstWhere((entry) {
      final entryMap = entry.value;

      if (entryMap is Map &&
          entryMap['saleOrderNo']?.toString() == saleOrderNo) {
        return true;
      }

      return false;
    }, orElse: () => const MapEntry('', null));

    if (matchingEntry.key == '') {
      print('❌ No matching Hive entry found for saleOrderNo: $saleOrderNo');
      return;
    }

    print('✅ Matching Entry Found — Key: ${matchingEntry.key}');
    print('📄 Existing Hive Value: ${matchingEntry.value}');

    // STEP 5️⃣ Load existing order data
    print('\n----------- STEP 5: Load Existing Order Data -----------');

    final existingValue = Map<String, dynamic>.from(matchingEntry.value);
    print('📄 Existing Data Before Merge: $existingValue');

    // STEP 6️⃣ Merge patch into existing
    print('\n----------- STEP 6: Merge Patch Data -----------');

    patchData.forEach((key, value) {
      print('✏️ Updating: $key → $value');
      existingValue[key] = value;
    });

    print('🟢 Final Merged Data: $existingValue');

    // STEP 7️⃣ Save updated order back to Hive
    print('\n----------- STEP 7: Save Back to Hive -----------');

    existingValue['lastUpdated'] = DateTime.now().toIso8601String();

    await saleOrderBox.put(matchingEntry.key, existingValue);
    print('💾 Hive Updated Successfully at Key: ${matchingEntry.key}');

    // STEP 8️⃣ Verification
    print('\n----------- STEP 8: Verify Saved Data -----------');

    final savedOrder = saleOrderBox.get(matchingEntry.key);
    print('🟩 Verification — Saved Order: $savedOrder');

    print('\n=============== END PATCH SALE APPROVAL ORDER ===============\n');
  } catch (e, st) {
    print('🚨 ERROR in handlePatchSaleApprovalOrderMessage: $e');
    print('📌 Stacktrace: $st');
  }
}

Future<void> patchSaleOrder(Map<String, dynamic> patchData) async {
  final box = HiveManager.salesOrderBox;
  final newSaleOrderNo = patchData['salesOrderId'];

  int? existingKey;
  dynamic matchedOrder;

  for (var key in box.keys) {
    final value = box.get(key);
    if (value is Map &&
        (value['saleOrderNo'] == newSaleOrderNo ||
            value['id'] == patchData['id'])) {
      existingKey = key;
      matchedOrder = value;
      break;
    }
  }

  if (existingKey != null) {
    await box.put(existingKey, patchData);
  } else {
    await box.add(patchData);
  }
}

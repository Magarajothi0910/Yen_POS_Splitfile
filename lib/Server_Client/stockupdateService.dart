// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:yenpos/Global/global_data_manager.dart';
// import 'package:yenpos/Server_Client/sendDataToClients.dart';

// Future<void> increaseLocalHiveStock({
//   required Set<WebSocketChannel> clients,
//   required String branchAlias,
//   required List<String> varianceCodes,
//   required List<String> varianceNames,
//   required List<double> stockIncreaseAmounts, // ← double for Kg support
//   required List<String> uoms,
// }) async {
//   debugPrint("STOCK INCREASE (Return) Starting for branch: $branchAlias");

//   if (varianceCodes.length != varianceNames.length ||
//       varianceCodes.length != stockIncreaseAmounts.length ||
//       varianceCodes.length != uoms.length) {
//     debugPrint("Length mismatch in increaseLocalHiveStock!");
//     return;
//   }

//   final lazyBox = await Hive.openBox('items');
//   final key = 'branchwiseItems_$branchAlias';
//   final globalDataBoxed = await lazyBox.get(key);

//   if (globalDataBoxed == null) {
//     debugPrint("No branch data found for $branchAlias");
//     return;
//   }

//   final globalData = Map<String, dynamic>.from(globalDataBoxed as Map);
//   if (globalData['data'] == null) return;

//   Map<String, dynamic> branchwiseData = Map<String, dynamic>.from(
//     globalData['data'],
//   );
//   bool anyUpdated = false;

//   for (int i = 0; i < varianceCodes.length; i++) {
//     final varCode = varianceCodes[i];
//     final varName = varianceNames[i];
//     final increase = stockIncreaseAmounts[i];
//     final uom = uoms[i];

//     debugPrint("   Increasing: $varName ($varCode) by +$increase $uom");

//     bool found = false;

//     for (final itemEntry in branchwiseData.entries) {
//       if (found) break;
//       final itemKey = itemEntry.key;
//       final itemValue = Map<String, dynamic>.from(itemEntry.value);

//       if (!itemValue.containsKey('variance')) continue;

//       final varianceMap = Map<String, dynamic>.from(itemValue['variance']);

//       for (final varianceEntry in varianceMap.entries) {
//         if (found) break;
//         final varianceValue = Map<String, dynamic>.from(varianceEntry.value);

//         final storedCode = varianceValue['varianceitemCode']?.toString() ?? '';
//         final storedName = varianceValue['varianceName']?.toString() ?? '';

//         if (storedCode != varCode || storedName != varName) continue;

//         debugPrint("     Found match in item: $itemKey");

//         if (!varianceValue.containsKey('branchwise')) continue;

//         final branchwiseMap = Map<String, dynamic>.from(
//           varianceValue['branchwise'],
//         );
//         if (!branchwiseMap.containsKey(branchAlias)) continue;

//         final branchData = Map<String, dynamic>.from(
//           branchwiseMap[branchAlias],
//         );
//         final stockKey = 'systemStock_$branchAlias';

//         dynamic rawStock = branchData[stockKey] ?? 0;
//         double currentStock = rawStock is num
//             ? rawStock.toDouble()
//             : (double.tryParse(rawStock.toString()) ?? 0.0);

//         double updatedStock = currentStock + increase;
//         updatedStock = double.parse(
//           updatedStock.toStringAsFixed(3),
//         ); // Clean float

//         branchData[stockKey] = updatedStock;
//         branchwiseMap[branchAlias] = branchData;
//         varianceValue['branchwise'] = branchwiseMap;
//         varianceMap[varianceEntry.key] = varianceValue;
//         itemValue['variance'] = varianceMap;
//         branchwiseData[itemKey] = itemValue;

//         found = true;
//         anyUpdated = true;

//         debugPrint("     New Stock: $currentStock → $updatedStock");

//         // Notify all clients
//         final message = {
//           'action': 'stockIncreaseUpdate',
//           'branchAlias': branchAlias,
//           'varianceCode': varCode,
//           'varianceName': varName,
//           'updatedStock': updatedStock,
//         };
//         sendDataToClients(message, clients);
//       }
//     }

//     if (!found) {
//       debugPrint("     Not Found: $varName ($varCode) in branch $branchAlias");
//     }
//   }

//   if (anyUpdated) {
//     globalData['data'] = branchwiseData;
//     await lazyBox.put(key, globalData);
//     debugPrint("Stock increase SAVED to Hive on return");
//   }
// }

// Future<void> decreaseLocalHiveStock({
//   required Set<WebSocketChannel> clients,
//   required String branchAlias,
//   required List<String> varianceCodes,
//   required List<String> varianceNames,
//   required List<double> stockDeductionAmounts, // ← Now double, not int!
//   required List<String> uoms, // Add UOM list
// }) async {
//   debugPrint("STOCK DECREASE Starting for branch: $branchAlias");
//   debugPrint("   Decreasing ${varianceCodes.length} variances");

//   if (varianceCodes.length != varianceNames.length ||
//       varianceCodes.length != stockDeductionAmounts.length ||
//       varianceCodes.length != uoms.length) {
//     debugPrint("Length mismatch in decreaseLocalHiveStock!");
//     return;
//   }

//   final lazyBox = await Hive.openBox('items');
//   final key = 'branchwiseItems_$branchAlias';

//   final globalDataBoxed = await lazyBox.get(key);
//   if (globalDataBoxed == null) {
//     debugPrint("No branch data found for $branchAlias");
//     return;
//   }

//   final globalData = Map<String, dynamic>.from(globalDataBoxed as Map);
//   if (globalData['data'] == null) {
//     debugPrint("No 'data' field in branch items");
//     return;
//   }

//   Map<String, dynamic> branchwiseData = Map<String, dynamic>.from(
//     globalData['data'],
//   );
//   bool anyUpdated = false;

//   for (int i = 0; i < varianceCodes.length; i++) {
//     final varCode = varianceCodes[i];
//     final varName = varianceNames[i];
//     final deduction = stockDeductionAmounts[i]; // e.g., 0.5 kg
//     final uom = uoms[i];

//     debugPrint("   Decreasing: $varName ($varCode) by -$deduction $uom");

//     bool found = false;

//     for (final itemEntry in branchwiseData.entries) {
//       if (found) break;
//       final itemKey = itemEntry.key;
//       final itemValue = Map<String, dynamic>.from(itemEntry.value);

//       if (!itemValue.containsKey('variance')) continue;

//       final varianceMap = Map<String, dynamic>.from(itemValue['variance']);

//       for (final varianceEntry in varianceMap.entries) {
//         if (found) break;
//         final varianceValue = Map<String, dynamic>.from(varianceEntry.value);

//         final storedCode = varianceValue['varianceitemCode']?.toString() ?? '';
//         final storedName = varianceValue['varianceName']?.toString() ?? '';

//         if (storedCode != varCode && storedName != varName) continue;

//         debugPrint("     Found variance match in item: $itemKey");

//         if (!varianceValue.containsKey('branchwise')) {
//           debugPrint("     No branchwise data!");
//           continue;
//         }

//         final branchwiseMap = Map<String, dynamic>.from(
//           varianceValue['branchwise'],
//         );
//         if (!branchwiseMap.containsKey(branchAlias)) {
//           debugPrint("     No stock data for branch: $branchAlias");
//           continue;
//         }

//         final branchData = Map<String, dynamic>.from(
//           branchwiseMap[branchAlias],
//         );
//         final stockKey = 'systemStock_$branchAlias';

//         dynamic rawStock = branchData[stockKey];
//         double currentStock = 0.0;

//         if (rawStock is num) {
//           currentStock = rawStock.toDouble();
//         } else if (rawStock is String) {
//           currentStock = double.tryParse(rawStock) ?? 0.0;
//         }

//         debugPrint(
//           "     Current Stock: $currentStock (raw: $rawStock, type: ${rawStock.runtimeType})",
//         );

//         double updatedStock = currentStock - deduction;

//         // Optional: Prevent negative stock
//         if (updatedStock < 0) {
//           debugPrint("     Warning: Stock would go negative → clamping to 0");
//           updatedStock = 0.0;
//         }

//         // Round to 3 decimal places to avoid floating point garbage
//         updatedStock = double.parse(updatedStock.toStringAsFixed(3));

//         branchData[stockKey] = updatedStock;
//         branchwiseMap[branchAlias] = branchData;
//         varianceValue['branchwise'] = branchwiseMap;
//         varianceMap[varianceEntry.key] = varianceValue;
//         itemValue['variance'] = varianceMap;
//         branchwiseData[itemKey] = itemValue;

//         found = true;
//         anyUpdated = true;

//         debugPrint("     New Stock: $updatedStock");

//         // Broadcast update
//         final message = {
//           'action': 'stockDecreaseUpdate',
//           'branchAlias': branchAlias,
//           'varianceCode': varCode,
//           'varianceName': varName,
//           'updatedStock': updatedStock,
//         };
//         sendDataToClients(message, clients);
//         debugPrint("     Sent WebSocket: stockDecreaseUpdate → $updatedStock");

//         break;
//       }
//     }

//     if (!found) {
//       debugPrint(
//         "     Not Found: Variance '$varName' ($varCode) not found in branch $branchAlias!",
//       );
//     }
//   }

//   if (anyUpdated) {
//     final newGlobalData = Map<String, dynamic>.from(globalData);
//     newGlobalData['data'] = branchwiseData;
//     await lazyBox.put(key, newGlobalData);
//     debugPrint("Stock decrease SAVED to Hive for $branchAlias");
//   } else {
//     debugPrint("No stock was decreased — nothing matched");
//   }
// }

// double getStockDeductionAmount({
//   required String uom,
//   required double weight,
//   required double qty,
// }) {
//   final lowerUom = uom.toLowerCase().trim();

//   if (lowerUom == 'kgs' || lowerUom == 'kg' || lowerUom == 'kilogram') {
//     return weight; // e.g., 0.5 kg sold → deduct 0.5
//   } else if (lowerUom == 'grams' || lowerUom == 'g') {
//     return weight / 1000; // convert grams → kg (if you store in kg)
//   } else {
//     return qty; // Pcs, Box, etc. → use quantity
//   }
// }

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';

Future<void> increaseLocalHiveStock({
  required Set<WebSocketChannel> clients,
  required String branchAlias,
  required List<String> varianceCodes,
  required List<String> varianceNames,
  required List<double> stockIncreaseAmounts, // ← double for Kg support
  required List<String> uoms,
}) async {
  debugPrint("STOCK INCREASE (Return) Starting for branch: $branchAlias");

  if (varianceCodes.length != varianceNames.length ||
      varianceCodes.length != stockIncreaseAmounts.length ||
      varianceCodes.length != uoms.length) {
    debugPrint("Length mismatch in increaseLocalHiveStock!");
    return;
  }

  final lazyBox = await Hive.openBox('items');
  final key = 'branchwiseItems_$branchAlias';
  final globalDataBoxed = await lazyBox.get(key);

  if (globalDataBoxed == null) {
    debugPrint("No branch data found for $branchAlias");
    return;
  }

  final globalData = Map<String, dynamic>.from(globalDataBoxed as Map);
  if (globalData['data'] == null) return;

  Map<String, dynamic> branchwiseData = Map<String, dynamic>.from(
    globalData['data'],
  );
  bool anyUpdated = false;

  for (int i = 0; i < varianceCodes.length; i++) {
    final varCode = varianceCodes[i];
    final varName = varianceNames[i];
    final increase = stockIncreaseAmounts[i];
    final uom = uoms[i];

    debugPrint("   Increasing: $varName ($varCode) by +$increase $uom");

    bool found = false;

    for (final itemEntry in branchwiseData.entries) {
      if (found) break;
      final itemKey = itemEntry.key;
      final itemValue = Map<String, dynamic>.from(itemEntry.value);

      if (!itemValue.containsKey('variance')) continue;

      final varianceMap = Map<String, dynamic>.from(itemValue['variance']);

      for (final varianceEntry in varianceMap.entries) {
        if (found) break;
        final varianceValue = Map<String, dynamic>.from(varianceEntry.value);

        final storedCode = varianceValue['itemCode']?.toString() ?? '';
        final storedName = varianceValue['varianceName']?.toString() ?? '';

        if (storedCode != varCode || storedName != varName) continue;

        debugPrint("     Found match in item: $itemKey");

        if (!varianceValue.containsKey('branchwise')) continue;

        final branchwiseMap = Map<String, dynamic>.from(
          varianceValue['branchwise'],
        );
        if (!branchwiseMap.containsKey(branchAlias)) continue;

        final branchData = Map<String, dynamic>.from(
          branchwiseMap[branchAlias],
        );
        final stockKey = 'systemStock_$branchAlias';

        dynamic rawStock = branchData[stockKey] ?? 0;
        double currentStock = rawStock is num
            ? rawStock.toDouble()
            : (double.tryParse(rawStock.toString()) ?? 0.0);

        double updatedStock = currentStock + increase;
        updatedStock = double.parse(
          updatedStock.toStringAsFixed(3),
        ); // Clean float

        branchData[stockKey] = updatedStock;
        branchwiseMap[branchAlias] = branchData;
        varianceValue['branchwise'] = branchwiseMap;
        varianceMap[varianceEntry.key] = varianceValue;
        itemValue['variance'] = varianceMap;
        branchwiseData[itemKey] = itemValue;

        found = true;
        anyUpdated = true;

        debugPrint("     New Stock: $currentStock → $updatedStock");

        // Notify all clients
        final message = {
          'action': 'stockIncreaseUpdate',
          'branchAlias': branchAlias,
          'varianceCode': varCode,
          'varianceName': varName,
          'updatedStock': updatedStock,
        };
        sendDataToClients(message, clients);
      }
    }

    if (!found) {
      debugPrint("     Not Found: $varName ($varCode) in branch $branchAlias");
    }
  }

  if (anyUpdated) {
    globalData['data'] = branchwiseData;
    await lazyBox.put(key, globalData);
    debugPrint("Stock increase SAVED to Hive on return");
  }
}

Future<void> decreaseLocalHiveStock({
  required Set<WebSocketChannel> clients,
  required String branchAlias,
  required List<String> varianceCodes,
  required List<String> varianceNames,
  required List<double> stockDeductionAmounts, // ← Now double, not int!
  required List<String> uoms, // Add UOM list
}) async {
  debugPrint("STOCK DECREASE Starting for branch: $branchAlias");
  debugPrint("   Decreasing ${varianceCodes.length} variances");

  if (varianceCodes.length != varianceNames.length ||
      varianceCodes.length != stockDeductionAmounts.length ||
      varianceCodes.length != uoms.length) {
    debugPrint("Length mismatch in decreaseLocalHiveStock!");
    return;
  }

  final lazyBox = await Hive.openBox('items');
  final key = 'branchwiseItems_$branchAlias';

  final globalDataBoxed = await lazyBox.get(key);
  if (globalDataBoxed == null) {
    debugPrint("No branch data found for $branchAlias");
    return;
  }

  final globalData = Map<String, dynamic>.from(globalDataBoxed as Map);
  if (globalData['data'] == null) {
    debugPrint("No 'data' field in branch items");
    return;
  }

  Map<String, dynamic> branchwiseData = Map<String, dynamic>.from(
    globalData['data'],
  );
  bool anyUpdated = false;

  for (int i = 0; i < varianceCodes.length; i++) {
    final varCode = varianceCodes[i];
    final varName = varianceNames[i];
    final deduction = stockDeductionAmounts[i]; // e.g., 0.5 kg
    final uom = uoms[i];

    debugPrint("   Decreasing: $varName ($varCode) by -$deduction $uom");

    bool found = false;

    for (final itemEntry in branchwiseData.entries) {
      if (found) break;
      final itemKey = itemEntry.key;
      final itemValue = Map<String, dynamic>.from(itemEntry.value);

      if (!itemValue.containsKey('variance')) continue;

      final varianceMap = Map<String, dynamic>.from(itemValue['variance']);

      for (final varianceEntry in varianceMap.entries) {
        if (found) break;
        final varianceValue = Map<String, dynamic>.from(varianceEntry.value);

        final storedCode = varianceValue['varianceitemCode']?.toString() ?? '';
        final storedName = varianceValue['varianceName']?.toString() ?? '';

        if (storedCode != varCode && storedName != varName) continue;

        debugPrint("     Found variance match in item: $itemKey");

        if (!varianceValue.containsKey('branchwise')) {
          debugPrint("     No branchwise data!");
          continue;
        }

        final branchwiseMap = Map<String, dynamic>.from(
          varianceValue['branchwise'],
        );
        if (!branchwiseMap.containsKey(branchAlias)) {
          debugPrint("     No stock data for branch: $branchAlias");
          continue;
        }

        final branchData = Map<String, dynamic>.from(
          branchwiseMap[branchAlias],
        );
        final stockKey = 'systemStock_$branchAlias';

        dynamic rawStock = branchData[stockKey];
        double currentStock = 0.0;

        if (rawStock is num) {
          currentStock = rawStock.toDouble();
        } else if (rawStock is String) {
          currentStock = double.tryParse(rawStock) ?? 0.0;
        }

        debugPrint(
          "     Current Stock: $currentStock (raw: $rawStock, type: ${rawStock.runtimeType})",
        );

        double updatedStock = currentStock - deduction;

        // Optional: Prevent negative stock
        if (updatedStock < 0) {
          debugPrint("     Warning: Stock would go negative → clamping to 0");
          updatedStock = 0.0;
        }

        // Round to 3 decimal places to avoid floating point garbage
        updatedStock = double.parse(updatedStock.toStringAsFixed(3));

        branchData[stockKey] = updatedStock;
        branchwiseMap[branchAlias] = branchData;
        varianceValue['branchwise'] = branchwiseMap;
        varianceMap[varianceEntry.key] = varianceValue;
        itemValue['variance'] = varianceMap;
        branchwiseData[itemKey] = itemValue;

        found = true;
        anyUpdated = true;

        debugPrint("     New Stock: $updatedStock");

        // Broadcast update
        final message = {
          'action': 'stockDecreaseUpdate',
          'branchAlias': branchAlias,
          'varianceCode': varCode,
          'varianceName': varName,
          'updatedStock': updatedStock,
        };
        sendDataToClients(message, clients);
        debugPrint("     Sent WebSocket: stockDecreaseUpdate → $updatedStock");

        break;
      }
    }

    if (!found) {
      debugPrint(
        "     Not Found: Variance '$varName' ($varCode) not found in branch $branchAlias!",
      );
    }
  }

  if (anyUpdated) {
    final newGlobalData = Map<String, dynamic>.from(globalData);
    newGlobalData['data'] = branchwiseData;
    await lazyBox.put(key, newGlobalData);
    debugPrint("Stock decrease SAVED to Hive for $branchAlias");
  } else {
    debugPrint("No stock was decreased — nothing matched");
  }
}

double getStockDeductionAmount({
  required String uom,
  required double weight,
  required double qty,
}) {
  final lowerUom = uom.toLowerCase().trim();

  if (lowerUom == 'kgs' || lowerUom == 'kg' || lowerUom == 'kilogram') {
    return weight; // e.g., 0.5 kg sold → deduct 0.5
  } else if (lowerUom == 'grams' || lowerUom == 'g') {
    return weight / 1000; // convert grams → kg (if you store in kg)
  } else {
    return qty; // Pcs, Box, etc. → use quantity
  }
}

/// Fully fixed & production-ready version
/// Works with your exact Hive structure (varianceitemCode + nested branchwise)
Future<void> increaseHiveStockFromVarianceNameMap({
  required Set<WebSocketChannel> clients,
  required String branchAlias, // e.g., "AR"
  required Map<String, dynamic>
  varianceNameStockMap, // key = varianceName (e.g. "CHOCO BUN")
}) async {
  debugPrint("STOCK INCREASE REQUEST for branch: $branchAlias");
  debugPrint("Incoming data: $varianceNameStockMap");

  // ──────── Step 1: Validate & Normalize incoming data ────────
  if (varianceNameStockMap.isEmpty) {
    debugPrint("Empty stock update map received");
    return;
  }

  final Map<String, Map<String, dynamic>> safeStockMap = {};

  for (final entry in varianceNameStockMap.entries) {
    final String varianceName = entry.key;
    final dynamic rawValue = entry.value;

    if (rawValue is Map<String, dynamic>) {
      safeStockMap[varianceName] = Map<String, dynamic>.from(rawValue);
    } else if (rawValue is num) {
      safeStockMap[varianceName] = {
        'systemStock_$branchAlias': rawValue.toDouble(),
        'systemstockSo_$branchAlias': 0.0,
      };
    } else if (rawValue is String && num.tryParse(rawValue) != null) {
      final double value = double.parse(rawValue);
      safeStockMap[varianceName] = {
        'systemStock_$branchAlias': value,
        'systemstockSo_$branchAlias': 0.0,
      };
    } else {
      debugPrint(
        "SKIPPED invalid data for $varianceName → $rawValue (${rawValue.runtimeType})",
      );
    }
  }

  if (safeStockMap.isEmpty) {
    debugPrint("No valid items to update after validation");
    return;
  }

  // ──────── Step 2: Open Hive and load branch data ────────
  final lazyBox = await Hive.openBox('items');
  final hiveKey = 'branchwiseItems_$branchAlias';

  final dynamic globalDataBoxed = await lazyBox.get(hiveKey);
  if (globalDataBoxed == null) {
    debugPrint("No branch-wise data found in Hive for key: $hiveKey");
    return;
  }

  final globalData = Map<String, dynamic>.from(globalDataBoxed);
  if (globalData['data'] == null) {
    debugPrint("globalData['data'] is null");
    return;
  }

  Map<String, dynamic> branchwiseData = Map<String, dynamic>.from(
    globalData['data'],
  );
  bool anyUpdated = false;

  // ──────── Step 3: Process each variance update ────────
  for (final entry in safeStockMap.entries) {
    final String varianceName = entry.key;
    final Map<String, dynamic> stockData = entry.value;

    final double addSystem = (stockData['systemStock_$branchAlias'] ?? 0.0)
        .toDouble();
    final double addSystemSO = (stockData['systemstockSo_$branchAlias'] ?? 0.0)
        .toDouble();

    debugPrint(
      "Processing $varianceName → +$addSystem system | +$addSystemSO SO",
    );

    bool found = false;

    for (final itemEntry in branchwiseData.entries) {
      if (found) break;

      final itemVal = Map<String, dynamic>.from(itemEntry.value);
      if (!itemVal.containsKey('variance')) continue;

      final varianceMap = Map<String, dynamic>.from(itemVal['variance']);

      // Search by variance name (key in varianceMap)
      if (!varianceMap.containsKey(varianceName)) continue;

      final variance = Map<String, dynamic>.from(varianceMap[varianceName]);

      debugPrint("MATCH FOUND: $varianceName");

      if (!variance.containsKey('branchwise')) {
        debugPrint("No 'branchwise' in variance for $varianceName");
        continue;
      }

      final branchwiseMap = Map<String, dynamic>.from(variance['branchwise']);
      if (!branchwiseMap.containsKey(branchAlias)) {
        debugPrint("No data for branch '$branchAlias' in branchwise");
        continue;
      }

      final branchData = Map<String, dynamic>.from(branchwiseMap[branchAlias]);

      final String sysKey = "systemStock_$branchAlias";
      final String sysSoKey = "systemstockSo_$branchAlias";

      final double currentSystem = (branchData[sysKey] ?? 0.0).toDouble();
      final double currentSystemSO = (branchData[sysSoKey] ?? 0.0).toDouble();

      final double newSystem = (currentSystem + addSystem)
          .toStringAsFixed(3)
          .parseDouble();
      final double newSystemSO = (currentSystemSO + addSystemSO)
          .toStringAsFixed(3)
          .parseDouble();

      // Update in-place
      branchData[sysKey] = newSystem;
      branchData[sysSoKey] = newSystemSO;

      branchwiseMap[branchAlias] = branchData;
      variance['branchwise'] = branchwiseMap;
      varianceMap[varianceName] = variance;
      itemVal['variance'] = varianceMap;
      branchwiseData[itemEntry.key] = itemVal;

      found = true;
      anyUpdated = true;

      debugPrint("UPDATED $varianceName:");
      debugPrint("   $sysKey: $currentSystem → $newSystem");
      debugPrint("   $sysSoKey: $currentSystemSO → $newSystemSO");

      // ──────── Broadcast to all WebSocket clients ────────
      sendDataToClients({
        'action': 'stock',
        'branchAlias': branchAlias,
        'varianceName': varianceName, // now using varianceName
        'systemStock': newSystem,
        'systemstockSo': newSystemSO,
      }, clients);

      break; // exit variance loop
    }

    if (!found) {
      debugPrint(
        "NOT FOUND in Hive: $varianceName (variance name not matched in any item)",
      );
    }
  }

  // ──────── Step 4: Save back to Hive if changed ────────
  if (anyUpdated) {
    globalData['data'] = branchwiseData;
    await lazyBox.put(hiveKey, globalData);
    debugPrint("Hive saved successfully for branch: $branchAlias");
  } else {
    debugPrint("No changes were made to Hive");
  }
}

Future<void> decreaseLocalHiveSaleorderStock({
  required Set<WebSocketChannel> clients,
  required String branchAlias,
  required List<String> varianceCodes,
  required List<String> varianceNames,
  required List<double> stockDeductionAmounts,
  required List<String> uoms,
}) async {
  debugPrint("STOCK DECREASE Starting for branch: $branchAlias");
  debugPrint("   Decreasing ${varianceCodes.length} variances");

  if (varianceCodes.length != varianceNames.length ||
      varianceCodes.length != stockDeductionAmounts.length ||
      varianceCodes.length != uoms.length) {
    debugPrint("Length mismatch in decreaseLocalHiveStock!");
    return;
  }

  final lazyBox = await Hive.openBox('items');
  final key = 'branchwiseItems_$branchAlias';

  final globalDataBoxed = await lazyBox.get(key);
  if (globalDataBoxed == null) {
    debugPrint("❌ No branch data found for $branchAlias");
    return;
  }

  final globalData = Map<String, dynamic>.from(globalDataBoxed as Map);

  if (globalData['data'] == null) {
    debugPrint("❌ No 'data' field in branchwise items");
    return;
  }

  Map<String, dynamic> branchwiseData = Map<String, dynamic>.from(
    globalData['data'],
  );

  bool anyUpdated = false;

  for (int i = 0; i < varianceCodes.length; i++) {
    final varCode = varianceCodes[i];
    final varName = varianceNames[i];
    final deduction = stockDeductionAmounts[i];
    final uom = uoms[i];

    debugPrint(
      "🔽 Decreasing: $varName ($varCode) by -$deduction $uom (systemstockSo_$branchAlias)",
    );

    bool found = false;

    for (final itemEntry in branchwiseData.entries) {
      if (found) break;

      final itemKey = itemEntry.key;
      final itemValue = Map<String, dynamic>.from(itemEntry.value);

      if (!itemValue.containsKey('variance')) continue;

      final varianceMap = Map<String, dynamic>.from(itemValue['variance']);

      for (final varianceEntry in varianceMap.entries) {
        if (found) break;

        final varianceValue = Map<String, dynamic>.from(varianceEntry.value);

        final storedCode = varianceValue['itemCode']?.toString() ?? '';
        final storedName = varianceValue['varianceName']?.toString() ?? '';

        if (storedCode != varCode && storedName != varName) continue;

        debugPrint("✔ Found match inside item: $itemKey");

        if (!varianceValue.containsKey('branchwise')) {
          debugPrint("   ⚠ No branchwise data for this variance");
          continue;
        }

        final branchwiseMap = Map<String, dynamic>.from(
          varianceValue['branchwise'],
        );

        if (!branchwiseMap.containsKey(branchAlias)) {
          debugPrint("   ⚠ No stock data for branch: $branchAlias");
          continue;
        }

        final branchData = Map<String, dynamic>.from(
          branchwiseMap[branchAlias],
        );

        // 🔥 THIS IS THE KEY YOU WANTED TO DECREASE 🔥
        final stockKey = 'systemstockSo_$branchAlias';

        dynamic rawStock = branchData[stockKey];
        double currentStock = 0.0;

        if (rawStock is num)
          currentStock = rawStock.toDouble();
        else if (rawStock is String)
          currentStock = double.tryParse(rawStock) ?? 0.0;

        debugPrint("   Current systemstockSo: $currentStock");

        double updatedStock = currentStock - deduction;

        if (updatedStock < 0) {
          updatedStock = 0.0; // prevent negative
          debugPrint("   ⚠ Stock negative → set to 0");
        }

        updatedStock = double.parse(
          updatedStock.toStringAsFixed(3),
        ); // clean rounding

        branchData[stockKey] = updatedStock;
        branchwiseMap[branchAlias] = branchData;
        varianceValue['branchwise'] = branchwiseMap;
        varianceMap[varianceEntry.key] = varianceValue;
        itemValue['variance'] = varianceMap;
        branchwiseData[itemKey] = itemValue;

        found = true;
        anyUpdated = true;

        debugPrint("   ✅ New Stock (systemstockSo): $updatedStock");

        // WebSocket Broadcast
        final message = {
          'action': 'soStockDecreaseUpdate',
          'branchAlias': branchAlias,
          'varianceCode': varCode,
          'varianceName': varName,
          'updatedStock': updatedStock,
        };
        sendDataToClients(message, clients);
        debugPrint("   📡 Sent WebSocket update");
      }
    }

    if (!found) {
      debugPrint(
        "❌ Not Found: $varName ($varCode) not found for branch $branchAlias",
      );
    }
  }

  if (anyUpdated) {
    final newGlobalData = Map<String, dynamic>.from(globalData);
    newGlobalData['data'] = branchwiseData;
    await lazyBox.put(key, newGlobalData);

    debugPrint("💾 Stock decrease SAVED to Hive (systemstockSo updated)");
  } else {
    debugPrint("⚠ No stock updated — nothing matched");
  }
}

/// Handles incoming `updateDispatch` messages from server
Future<void> handleUpdateDispatch({
  required Map<String, dynamic> message,
  required Set<WebSocketChannel> clients,
  required String branchAlias,
}) async {
  final dynamic rawData = message['data'];

  if (rawData is! Map<String, dynamic>) {
    debugPrint("updateDispatch: Invalid or missing 'data' field → $rawData");
    return;
  }

  final Map<String, dynamic> stockUpdates = Map<String, dynamic>.from(rawData);

  if (stockUpdates.isEmpty) {
    debugPrint("updateDispatch: Empty stock updates received");
    return;
  }

  debugPrint(
    "Valid updateDispatch → variances: ${stockUpdates.keys.join(', ')}",
  );

  await increaseHiveStockFromVarianceNameMap(
    clients: clients,
    branchAlias: branchAlias,
    varianceNameStockMap: stockUpdates,
  );
}

// ──────── Helper Extension ────────
extension DoubleParse on String {
  double parseDouble() => double.tryParse(this) ?? 0.0;
}

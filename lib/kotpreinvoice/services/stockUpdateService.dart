import 'package:hive/hive.dart';
import '../SaleOrder/soSyncService.dart';

import '../handlers/global_datamanager.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'sendDataToClients.dart';

final syncService = SyncServicePos(); // ✅ FIX: instantiate the service

Future<void> updateLocalHiveStock({
  required String branchAlias,
  required List<String> varianceCodes,
  required List<String> varianceNames,
  required List<int> stockUpdates,
  // required Set<WebSocketChannel> clients,
}) async {
  print('🔄 Starting stock update for branch: $branchAlias');
  print('📦 Variance Codes: $varianceCodes');
  print('🏷️ Variance Names: $varianceNames');
  print('📊 Stock Updates: $stockUpdates');

  try {
    // ✅ Validation
    if (varianceCodes.length != varianceNames.length || varianceCodes.length != stockUpdates.length) {
      print('❌ Length mismatch: varianceCodes(${varianceCodes.length}), varianceNames(${varianceNames.length}), stockUpdates(${stockUpdates.length})');
      return;
    }

    // ✅ Fetch global data
    dynamic globalData = GlobalDataManager().branchwiseItems;
    if (globalData == null || globalData['data'] == null) {
      print('❌ GlobalDataManager.branchwiseItems is empty or invalid ⚠️');
      return;
    }

    Map<String, dynamic> branchwiseData = Map<String, dynamic>.from(globalData['data']);
    bool anyUpdated = false;

    // 🔁 Process each variance
    for (int i = 0; i < varianceCodes.length; i++) {
      final varCode = varianceCodes[i];
      final varName = varianceNames[i];
      final delta = stockUpdates[i];

      print('\n🧩 Processing variance: $varName ($varCode) | 🔼 Increase by $delta');
      bool updatedThisVariance = false;

      branchwiseData.forEach((itemKey, itemValue) {
        try {
          if (itemValue is Map && itemValue.containsKey('variance')) {
            Map<String, dynamic> varianceMap = Map<String, dynamic>.from(itemValue['variance']);

            varianceMap.forEach((varianceKey, varianceValue) {
              if (varianceValue is Map) {
                final storedCode = varianceValue['varianceitemCode']?.toString() ?? '';
                final storedName = varianceValue['varianceName']?.toString() ?? '';

                if (storedCode == varCode && storedName == varName) {
                  if (varianceValue.containsKey('branchwise') && varianceValue['branchwise'] is Map) {
                    Map<String, dynamic> branchwiseMap = Map<String, dynamic>.from(varianceValue['branchwise']);

                    if (branchwiseMap.containsKey(branchAlias)) {
                      Map<String, dynamic> branchData = Map<String, dynamic>.from(branchwiseMap[branchAlias]);
                      final stockKey = 'localHiveStock_$branchAlias';

                      int currentStock = int.tryParse(branchData[stockKey]?.toString() ?? '0') ?? 0;
                      int updatedStock = currentStock + delta;

                      print('   📍 Before: $currentStock | After: $updatedStock');

                      branchData[stockKey] = updatedStock;

                      // Update nested structure
                      branchwiseMap[branchAlias] = branchData;
                      varianceValue['branchwise'] = branchwiseMap;
                      varianceMap[varianceKey] = varianceValue;
                      itemValue['variance'] = varianceMap;
                      branchwiseData[itemKey] = itemValue;

                      updatedThisVariance = true;
                      anyUpdated = true;

                      // Notify other clients
                      final stockUpdateMessage = {
                        'action': 'stockIncreaseUpdate',
                        'branchAlias': branchAlias,
                        'varianceCode': varCode,
                        'varianceName': varName,
                        'updatedStock': updatedStock,
                      };
                      sendDataToClientsKOT(stockUpdateMessage);

                      // Queue sync to backend
                      syncService.queueSync(() async {
                        await syncService.sendStockUpdateToAPI(
                          branchAlias: branchAlias,
                          varianceCode: varCode,
                          varianceName: varName,
                          updatedStock: updatedStock,
                        );
                      });

                      print('✅ Updated successfully: $varName ($varCode) at $branchAlias.');
                    } else {
                      print('🚫 Branch "$branchAlias" not found for $varName ($varCode)');
                    }
                  }
                }
              }
            });
          }
        } catch (e) {
          print('⚠️ Error in item "$itemKey": $e');
        }
      });

      if (!updatedThisVariance) {
        print('❌ No matching variance found for $varName ($varCode)');
      }
    }

    // 💾 Save updated data
    if (anyUpdated) {
      try {
        print('\n💾 Saving updates to Hive...');
        var box = await Hive.openLazyBox('items');
        Map<String, dynamic> newGlobalData = Map<String, dynamic>.from(globalData);
        newGlobalData['data'] = branchwiseData;

        await box.put('branchwiseItems_$branchAlias', newGlobalData);
        GlobalDataManager().branchwiseItems = newGlobalData;

        print('🎉 All stock increases saved successfully!');
      } catch (e) {
        print('💥 Error saving to Hive: $e');
      }
    } else {
      print('⚠️ No stock changes detected — nothing saved.');
    }
  } catch (e, st) {
    print('🔥 Fatal error in updateLocalHiveStock: $e');
    print(st.toString());
  }

  print('🏁 Finished updateLocalHiveStock process.\n');
}

Future<void> decreaseLocalHiveStock({
  required String branchAlias,
  required List<String> varianceCodes,
  required List<String> varianceNames,
  required List<int> stockUpdates,
}) async {
  print('🚀 Starting stock decrease for branch: $branchAlias');
  print('📦 Variance Codes: $varianceCodes');
  print('🏷️ Variance Names: $varianceNames');
  print('📉 Stock Decreases: $stockUpdates');

  try {
    if (varianceCodes.length != varianceNames.length || varianceCodes.length != stockUpdates.length) {
      print('❌ Length mismatch between variance lists and stock updates');
      return;
    }

    dynamic globalData = GlobalDataManager().branchwiseItems;
    if (globalData == null || globalData['data'] == null) {
      print('❌ GlobalDataManager.branchwiseItems is empty or invalid');
      return;
    }

    Map<String, dynamic> branchwiseData = Map<String, dynamic>.from(globalData['data']);
    bool anyUpdated = false;

    // 🔁 Loop through each variance
    for (int i = 0; i < varianceCodes.length; i++) {
      final varCode = varianceCodes[i];
      final varName = varianceNames[i];
      final decreaseAmount = stockUpdates[i];

      print('\n🧩 Processing variance: $varName ($varCode) | 🔽 Decrease by $decreaseAmount');
      bool updatedThisVariance = false;

      branchwiseData.forEach((itemKey, itemValue) {
        try {
          if (itemValue is Map && itemValue.containsKey('variance')) {
            Map<String, dynamic> varianceMap = Map<String, dynamic>.from(itemValue['variance']);

            varianceMap.forEach((varianceKey, varianceValue) {
              if (varianceValue is Map) {
                final storedCode = varianceValue['varianceitemCode']?.toString() ?? '';
                final storedName = varianceValue['varianceName']?.toString() ?? '';

                if (storedCode == varCode && storedName == varName) {
                  if (varianceValue.containsKey('branchwise') && varianceValue['branchwise'] is Map) {
                    Map<String, dynamic> branchwiseMap = Map<String, dynamic>.from(varianceValue['branchwise']);

                    if (branchwiseMap.containsKey(branchAlias)) {
                      Map<String, dynamic> branchData = Map<String, dynamic>.from(branchwiseMap[branchAlias]);
                      final stockKey = 'localHiveStock_$branchAlias';

                      int currentStock = int.tryParse(branchData[stockKey]?.toString() ?? '0') ?? 0;
                      int updatedStock = currentStock - decreaseAmount;
                      if (updatedStock < 0) updatedStock = 0;

                      print('   📍 Before: $currentStock | After: $updatedStock');

                      branchData[stockKey] = updatedStock;

                      // 🔄 Update nested maps
                      branchwiseMap[branchAlias] = branchData;
                      varianceValue['branchwise'] = branchwiseMap;
                      varianceMap[varianceKey] = varianceValue;
                      itemValue['variance'] = varianceMap;
                      branchwiseData[itemKey] = itemValue;

                      updatedThisVariance = true;
                      anyUpdated = true;

                      // Notify other clients
                      final msg = {
                        'action': 'stockDecreaseUpdate',
                        'branchAlias': branchAlias,
                        'varianceCode': varCode,
                        'varianceName': varName,
                        'updatedStock': updatedStock,
                      };
                      sendDataToClientsKOT(msg);

                      print('✅ Stock decreased successfully for $varName ($varCode)');
                    } else {
                      print('🚫 Branch alias "$branchAlias" not found in variance map');
                    }
                  }
                }
              }
            });
          }
        } catch (e) {
          print('⚠️ Error while processing item "$itemKey": $e');
        }
      });

      if (!updatedThisVariance) {
        print('❌ Variance not found: $varName ($varCode)');
      }
    }

    // 💾 Save if any updates
    if (anyUpdated) {
      try {
        print('\n💾 Saving stock decreases to Hive...');
        var box = await Hive.openLazyBox('items');
        Map<String, dynamic> newGlobalData = Map<String, dynamic>.from(globalData);
        newGlobalData['data'] = branchwiseData;

        await box.put('branchwiseItems_$branchAlias', newGlobalData);
        GlobalDataManager().branchwiseItems = newGlobalData;

        print('🎉 All stock decreases saved successfully!');
      } catch (e) {
        print('💥 Error while saving to Hive: $e');
      }
    } else {
      print('⚠️ No stock decrease changes to save.');
    }
  } catch (e, st) {
    print('🔥 Fatal error in decreaseLocalHiveStock: $e');
    print(st.toString());
  }

  print('🏁 Finished decreaseLocalHiveStock process.\n');
}

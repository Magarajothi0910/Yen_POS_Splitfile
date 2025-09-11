import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../data/global_data_manager.dart';
import '../server/Service/sendDataToClients.dart';

Future<void> updateLocalHiveStock({
  required Set<WebSocketChannel> clients,
  required String branchAlias,
  required List<String> varianceCodes,
  required List<String> varianceNames,
  required List<int> stockUpdates,
}) async {
  if (varianceCodes.length != varianceNames.length ||
      varianceCodes.length != stockUpdates.length) {
    return;
  }

  // Get the global branchwiseItems map
  dynamic globalData = GlobalDataManager().branchwiseItems;
  if (globalData == null || globalData['data'] == null) {
    return;
  }

  // Convert to mutable map
  Map<String, dynamic> branchwiseData =
      Map<String, dynamic>.from(globalData['data']);

  bool anyUpdated = false;

  for (int i = 0; i < varianceCodes.length; i++) {
    final varCode = varianceCodes[i];
    final varName = varianceNames[i];
    final delta = stockUpdates[i];

    bool updatedThisVariance = false;

    branchwiseData.forEach((itemKey, itemValue) {
      if (itemValue is Map && itemValue.containsKey('variance')) {
        Map<String, dynamic> varianceMap =
            Map<String, dynamic>.from(itemValue['variance']);

        varianceMap.forEach((varianceKey, varianceValue) {
          if (varianceValue is Map) {
            final storedCode =
                varianceValue['varianceitemCode']?.toString() ?? '';
            final storedName = varianceValue['varianceName']?.toString() ?? '';

            if (storedCode == varCode && storedName == varName) {
              if (varianceValue.containsKey('branchwise') &&
                  varianceValue['branchwise'] is Map) {
                Map<String, dynamic> branchwiseMap =
                    Map<String, dynamic>.from(varianceValue['branchwise']);

                if (branchwiseMap.containsKey(branchAlias)) {
                  Map<String, dynamic> branchData =
                      Map<String, dynamic>.from(branchwiseMap[branchAlias]);

                  final stockKey = 'localHiveStock_$branchAlias';
                  int currentStock = 0;
                  if (branchData.containsKey(stockKey)) {
                    currentStock =
                        int.tryParse(branchData[stockKey].toString()) ?? 0;
                  }

                  final updatedStock = currentStock + delta;
                  branchData[stockKey] = updatedStock;

                  // Update nested maps
                  branchwiseMap[branchAlias] = branchData;
                  varianceValue['branchwise'] = branchwiseMap;
                  varianceMap[varianceKey] = varianceValue;
                  itemValue['variance'] = varianceMap;
                  branchwiseData[itemKey] = itemValue;

                  updatedThisVariance = true;
                  anyUpdated = true;
                  final stockUpdateMessage = {
                    'action': 'stockIncreaseUpdate',
                    'branchAlias': branchAlias,
                    'varianceCode': varCode,
                    'varianceName': varName,
                    'updatedStock': updatedStock,
                  };

// Broadcast update to all clients
                  sendDataToClients(stockUpdateMessage, clients);
                } else {
                }
              }
            }
          }
        });
      }
    });

    if (!updatedThisVariance) {
    }
  }

  if (anyUpdated) {
    // Save back to Hive
    var box = await Hive.openLazyBox('items');
    // Prepare the whole map with the updated 'data' key
    Map<String, dynamic> newGlobalData = Map<String, dynamic>.from(globalData);
    newGlobalData['data'] = branchwiseData;

    await box.put('branchwiseItems_$branchAlias', newGlobalData);
    // Update global manager too
    GlobalDataManager().branchwiseItems = newGlobalData;

  } else {
  }
}

Future<void> decreaseLocalHiveStock({
  required Set<WebSocketChannel> clients,
  required String branchAlias,
  required List<String> varianceCodes,
  required List<String> varianceNames,
  required List<int> stockUpdates,
}) async {
  // Validate input list lengths
  if (varianceCodes.length != varianceNames.length ||
      varianceCodes.length != stockUpdates.length) {
    return;
  }

  // Retrieve global data from memory
  dynamic globalData = GlobalDataManager().branchwiseItems;
  if (globalData == null || globalData['data'] == null) {
    return;
  }

  Map<String, dynamic> branchwiseData =
      Map<String, dynamic>.from(globalData['data']);
  bool anyUpdated = false;

  for (int i = 0; i < varianceCodes.length; i++) {
    final varCode = varianceCodes[i];
    final varName = varianceNames[i];
    final decreaseAmount = stockUpdates[i];
    bool updatedThisVariance = false;

    for (final itemEntry in branchwiseData.entries) {
      final itemKey = itemEntry.key;
      final itemValue = Map<String, dynamic>.from(itemEntry.value);

      if (!itemValue.containsKey('variance')) continue;

      Map<String, dynamic> varianceMap =
          Map<String, dynamic>.from(itemValue['variance']);

      for (final varianceEntry in varianceMap.entries) {
        final varianceKey = varianceEntry.key;
        final varianceValue = Map<String, dynamic>.from(varianceEntry.value);

        final storedCode = varianceValue['varianceitemCode']?.toString() ?? '';
        final storedName = varianceValue['varianceName']?.toString() ?? '';

        if (storedCode == varCode && storedName == varName) {
          if (!varianceValue.containsKey('branchwise')) continue;

          Map<String, dynamic> branchwiseMap =
              Map<String, dynamic>.from(varianceValue['branchwise']);

          if (!branchwiseMap.containsKey(branchAlias)) {
            continue;
          }

          Map<String, dynamic> branchData =
              Map<String, dynamic>.from(branchwiseMap[branchAlias]);
          final stockKey = 'localHiveStock_$branchAlias';

          int currentStock =
              int.tryParse(branchData[stockKey]?.toString() ?? '0') ?? 0;
          int updatedStock = currentStock - decreaseAmount;

          if (updatedStock < 0) {
            updatedStock = 0;
          }

          branchData[stockKey] = updatedStock;

          // Re-assign updated maps
          branchwiseMap[branchAlias] = branchData;
          varianceValue['branchwise'] = branchwiseMap;
          varianceMap[varianceKey] = varianceValue;
          itemValue['variance'] = varianceMap;
          branchwiseData[itemKey] = itemValue;

          // Notify clients
          final decreaseMessage = {
            'action': 'stockDecreaseUpdate',
            'branchAlias': branchAlias,
            'varianceCode': varCode,
            'varianceName': varName,
            'updatedStock': updatedStock,
          };
          sendDataToClients(decreaseMessage, clients);

          updatedThisVariance = true;
          anyUpdated = true;
        }
      }
    }

    if (!updatedThisVariance) {
    }
  }

  if (anyUpdated) {
    final box = await Hive.openLazyBox('items');
    final newGlobalData = Map<String, dynamic>.from(globalData);
    newGlobalData['data'] = branchwiseData;

    await box.put('branchwiseItems_$branchAlias', newGlobalData);
    GlobalDataManager().branchwiseItems = newGlobalData;

  } else {
  }
}

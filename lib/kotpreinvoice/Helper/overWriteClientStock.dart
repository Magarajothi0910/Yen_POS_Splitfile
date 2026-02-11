import 'package:hive_flutter/hive_flutter.dart';

import '../handlers/global_datamanager.dart';

Future<void> overwriteLocalHiveStock({
  required String branchAlias,
  required String varianceCode,
  required String varianceName,
  required int finalStock,
}) async {
  final globalData = GlobalDataManager().branchwiseItems;
  if (globalData == null || globalData['data'] == null) {
    print('❌ GlobalDataManager.branchwiseItems is empty.');
    return;
  }

  final Map<String, dynamic> branchwiseData =
      Map<String, dynamic>.from(globalData['data']);

  bool updated = false;

  branchwiseData.forEach((itemKey, itemValue) {
    if (itemValue is Map && itemValue.containsKey('variance')) {
      final varianceMap =
          Map<String, dynamic>.from(itemValue['variance'] ?? {});

      varianceMap.forEach((varianceKey, varianceValue) {
        if (varianceValue is Map) {
          final storedCode =
              varianceValue['varianceitemCode']?.toString() ?? '';
          final storedName = varianceValue['varianceName']?.toString() ?? '';

          if (storedCode == varianceCode && storedName == varianceName) {
            final branchwiseMap =
                Map<String, dynamic>.from(varianceValue['branchwise'] ?? {});
            if (branchwiseMap.containsKey(branchAlias)) {
              final branchData =
                  Map<String, dynamic>.from(branchwiseMap[branchAlias]);

              final stockKey = 'localHiveStock_$branchAlias';
              branchData[stockKey] = finalStock;

              branchwiseMap[branchAlias] = branchData;
              varianceValue['branchwise'] = branchwiseMap;
              varianceMap[varianceKey] = varianceValue;
              itemValue['variance'] = varianceMap;
              branchwiseData[itemKey] = itemValue;

              updated = true;
              print(
                  '✅ Stock replaced: $varianceCode ($varianceName) at $branchAlias → $finalStock');
            }
          }
        }
      });
    }
  });

  if (updated) {
    final box = await Hive.openLazyBox('items');
    final newGlobalData = Map<String, dynamic>.from(globalData);
    newGlobalData['data'] = branchwiseData;

    await box.put('branchwiseItems_$branchAlias', newGlobalData);
    GlobalDataManager().branchwiseItems = newGlobalData;
  } else {
    print('⚠️ No match found to overwrite stock for $varianceCode');
  }
}

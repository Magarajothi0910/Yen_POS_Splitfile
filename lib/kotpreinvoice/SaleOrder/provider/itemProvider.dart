import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../handlers/global_datamanager.dart';
import 'package:yenpos/Global/globals_data.dart';

class ItemProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  // List<Map<String, dynamic>> _originalMixboxItems = [];
  List<String> _filteredVarianceNames = []; // For search results
  List<String> _varianceNames = []; // List of variance names
  List<String> get varianceNames => _varianceNames; // Getter to access variance names
  List<Map<String, dynamic>> _birthdayCakeItems = []; // Add this line

  List<Map<String, dynamic>> get birthdayCakeItems => _birthdayCakeItems;

  Future<void> fetchDataIfNeeded({String? branchAlias}) async {
    print("🔍 Checking connectivity and Hive state...");

    var connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    var lazyBox = await Hive.openLazyBox('items');
    var dio = Dio();

    try {
      // ✅ Fetch from API if not already in Hive
      if (branchAlias != null && (appType == 'server' || appType == '') && !lazyBox.containsKey('branchwiseItems_$branchAlias')) {
        try {
          var response = await dio.get('https://yenerp.com/fastapi/branchwiseitems/?branch_alias=$branchAlias');

          if (response.statusCode == 200) {
            var jsonData = response.data;
            await lazyBox.put('branchwiseItems_$branchAlias', jsonData);
            GlobalDataManager().branchwiseItems = jsonData;

            _extractVarianceNames(jsonData);
            _filteredVarianceNames = _varianceNames;

            print("✅ Fetched & stored branchwiseItems for $branchAlias");

            // ✅ Update local stock
            final branchwiseItems = jsonData['data'] as Map<String, dynamic>;
            var localStockBox = Hive.box('localStockBox');

            for (var itemEntry in branchwiseItems.entries) {
              final itemName = itemEntry.key;
              final itemDetails = itemEntry.value;

              final variances = itemDetails['variance'] as Map<String, dynamic>?;

              if (variances != null) {
                for (var varianceEntry in variances.entries) {
                  final varianceName = varianceEntry.key;
                  final varianceData = varianceEntry.value;
                  final String? itemCode = varianceData['varianceitemCode'];

                  final branchData = (varianceData['branchwise'] as Map?)?[branchAlias];

                  if (itemCode != null && branchData != null) {
                    final localStockKey = 'localStock_${branchAlias}_$itemCode';
                    final localHiveStock = branchData['localHiveStock_$branchAlias'];

                    if (localHiveStock != null) {
                      // ✅ Update localStockBox
                      await localStockBox.put(localStockKey, localHiveStock);
                      print('🔁 Updated localStockBox for $itemCode: $localHiveStock');

                      // ✅ Update inside branchwiseItems Hive too
                      final currentGlobalData = await lazyBox.get('branchwiseItems_$branchAlias');
                      if (currentGlobalData != null) {
                        final dataMap = Map<String, dynamic>.from(currentGlobalData);
                        final itemMap = Map<String, dynamic>.from(dataMap['data']);
                        if (itemMap.containsKey(itemName)) {
                          final itemDetailsMap = Map<String, dynamic>.from(itemMap[itemName]);
                          final varianceMap = Map<String, dynamic>.from(itemDetailsMap['variance']);
                          if (varianceMap.containsKey(varianceName)) {
                            final varianceDataMap = Map<String, dynamic>.from(varianceMap[varianceName]);
                            final branchwiseMap = Map<String, dynamic>.from(varianceDataMap['branchwise']);
                            if (branchwiseMap.containsKey(branchAlias)) {
                              final updatedBranchData = Map<String, dynamic>.from(branchwiseMap[branchAlias]);
                              updatedBranchData['localHiveStock_$branchAlias'] = localHiveStock;
                              branchwiseMap[branchAlias] = updatedBranchData;
                              varianceDataMap['branchwise'] = branchwiseMap;
                              varianceMap[varianceName] = varianceDataMap;
                              itemDetailsMap['variance'] = varianceMap;
                              itemMap[itemName] = itemDetailsMap;
                              dataMap['data'] = itemMap;

                              await lazyBox.put('branchwiseItems_$branchAlias', dataMap);
                              GlobalDataManager().branchwiseItems = dataMap;

                              print('✅ Synced localHiveStock_$branchAlias for $itemCode in Hive');
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            final result = checkVarianceItemCode("FG011");
            print(result);
            notifyListeners();
          } else {
            print('❌ Failed to fetch branchwise items: ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Error fetching branchwise items: $e');
        }
      } else {
        // ✅ Load from Hive if already present
        GlobalDataManager().branchwiseItems = await lazyBox.get('branchwiseItems_$branchAlias');
        _extractVarianceNames(GlobalDataManager().branchwiseItems);
        _filteredVarianceNames = _varianceNames;
        print("📦 Loaded branchwiseItems from Hive for $branchAlias");
      }

      // ✅ Fetch branch list if missing
      if (!lazyBox.containsKey('branches')) {
        try {
          var response = await dio.get('https://yenerp.com/fastapi/branches/');

          if (response.statusCode == 200) {
            var jsonData = response.data;
            await lazyBox.put('branches', jsonData);
            GlobalDataManager().branches = jsonData;
            printBranchNames(jsonData);
            notifyListeners();
          } else {
            print('❌ Failed to fetch branches: ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Error fetching branches: $e');
        }
      } else {
        GlobalDataManager().branches = await lazyBox.get('branches');
      }
    } finally {
      dio.close();
    }
  }

  Future<int?> getLocalStock(String branchAlias, String itemCode) async {
    final box = Hive.box('localStockBox');
    final key = 'localStock_${branchAlias}_$itemCode';
    return box.get(key);
  }

  Future<void> updateLocalStock(String branchAlias, String itemCode, int newStock) async {
    final box = await Hive.box('localStockBox');
    final key = 'localStock_${branchAlias}_$itemCode';
    await box.put(key, newStock);
    notifyListeners();
  }

  Map<String, dynamic>? _convertMap(Map<dynamic, dynamic>? original) {
    return original?.map((k, v) => MapEntry(k.toString(), v));
  }

  /// Return the variance-item-code (FGxxxx) for a given variance name,
  /// or null if not found.
  String? varianceCodeForName(String varianceName) {
    final data = _convertMap(GlobalDataManager().branchwiseItems['data'] as Map<dynamic, dynamic>?);
    if (data == null) return null;

    for (final item in data.values) {
      final itemMap = _convertMap(item as Map<dynamic, dynamic>?);
      final variances = _convertMap(itemMap?['variance'] as Map<dynamic, dynamic>?);
      if (variances == null) continue;

      for (final v in variances.values) {
        final varianceMap = _convertMap(v as Map<dynamic, dynamic>?);
        if (varianceMap?['varianceName'] == varianceName) {
          return varianceMap?['varianceitemCode'] as String?;
        }
      }
    }
    return null;
  }

  Future<void> fetchAndSaveEmployees() async {
    const String apiUrl = 'https://yenerp.com/fastapi/employees/';
    final dio = Dio();

    try {
      final response = await dio.get(apiUrl);
      if (response.statusCode == 200) {
        final List<dynamic> employeeData = response.data;

        // Open Hive box and store employee data
        var box = await Hive.box('employeeBox');
        await box.put('employees', employeeData);
      } else {
        print("Failed to fetch employee data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching employee data: $e");
    } finally {
      dio.close();
    }
  }

  void _extractVarianceNames(dynamic data) {
    _varianceNames.clear();
    if (data is Map && data.containsKey('data')) {
      final branchwiseItems = data['data'];
      if (branchwiseItems is Map) {
        branchwiseItems.forEach((itemName, itemDetails) {
          final variances = itemDetails['variance'];
          if (variances is Map) {
            variances.forEach((varianceName, varianceDetails) {
              _varianceNames.add(varianceName);
            });
          }
        });
      }
    }
    notifyListeners(); // Notify listeners after updating variance names
  }

  List<String> get filteredVarianceNames => _filteredVarianceNames;

  @override
  void dispose() {
    super.dispose();
  }

  List<String> getBranchNames() {
    if (GlobalDataManager().branches is List) {
      return (GlobalDataManager().branches as List).map((branch) => branch['branchName'] as String).toList();
    }
    return [];
  }

  Future<String?> getAliasName(String branchName) async {
    // Assuming GlobalDataManager().branches contains branch data with alias names
    if (GlobalDataManager().branches is List) {
      final branches = GlobalDataManager().branches as List;
      final branch = branches.firstWhere(
        (branch) => branch['branchName'] == branchName,
        orElse: () => null,
      );
      return branch?['aliasName'] ?? 'Alias Not Found';
    }
    return 'Alias Not Found';
  }

  void printBranchNames(dynamic data) {
    if (data is List) {
      for (var branch in data) {
        String branchName = branch['branchName'] ?? 'Unknown';
        // String aliasName = branch['aliasName'] ?? 'Unknown';
        String pettyCash = branch['pettyCash'] ?? 'Unknown';
        print('Branch Name: $branchName, Alias Name: $pettyCash');
      }
    }
  }

  void printCategories(List<String> categories) {
    for (var category in categories) {
      print('Category: $category');
    }
  }

  void printData(dynamic data, {required String dataType, required bool isNewData}) {
    if (isNewData) {
      print('New $dataType data fetched and saved: $data');
    } else {
      print('Using saved $dataType data: $data');
    }
  }

  void CategoriesFromData(dynamic data) {
    if (data is Map && data.containsKey('categories')) {
      List<String> categories = List<String>.from(data['categories']);
      printCategories(categories);
    } else {
      print('No categories found.');
    }
  }

  void printVarianceNames() {
    print('Attempting to print variance names...');

    final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map?;
    if (branchwiseItems == null) {
      print('No branchwise items available.');
      return;
    }

    Set<String> varianceNames = {};

    // Iterate over each item in the data
    branchwiseItems.forEach((itemName, itemDetails) {
      var variances = itemDetails['variance'] as Map?;
      if (variances != null) {
        // Extract each variance name from the variance map
        variances.forEach((varianceName, _) {
          varianceNames.add(varianceName);
        });
      }
    });

    // Print all unique variance names
    if (varianceNames.isEmpty) {
      print('No variance names found.');
    } else {
      print('All unique variance names:');
      varianceNames.forEach(print);
    }
  }

  List<Map<String, dynamic>> checkVarianceItemCode(String varianceItemCode) {
    print('Attempting to find the variance item code: $varianceItemCode');

    final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map?;
    if (branchwiseItems == null) {
      print('No branchwise items available.');
      return [];
    }

    for (var entry in branchwiseItems.entries) {
      // final itemName = entry.key;
      final itemDetails = entry.value as Map;

      final itemData = itemDetails['item'] as Map;
      final variances = itemDetails['variance'] as Map?;

      if (variances != null) {
        for (var varianceEntry in variances.entries) {
          final varianceData = varianceEntry.value as Map;
          if (varianceData['varianceitemCode'] == varianceItemCode) {
            return [
              {
                "itemData": itemData,
                "varianceData": varianceData,
                "quantity": 1,
              }
            ];
          }
        }
      }
    }

    print('No variance found for the given item code: $varianceItemCode');
    return [];
  }
}

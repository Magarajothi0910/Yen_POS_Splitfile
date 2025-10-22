import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;

class ItemProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  // List<Map<String, dynamic>> _originalMixboxItems = [];
  List<String> _filteredVarianceNames = []; // For search results
  List<String> _varianceNames = []; // List of variance names
  List<String> get varianceNames =>
      _varianceNames; // Getter to access variance names
  List<Map<String, dynamic>> _birthdayCakeItems = []; // Add this line

  // Getter for birthdayCakeItems
  List<Map<String, dynamic>> get birthdayCakeItems => _birthdayCakeItems;
  ItemProvider() {
    fetchAndSaveSalesOrders();
    fetchAndStoreBranches();
    fetchDataIfNeeded(branchAlias: globals.aliasname);
    fetchAndSaveEmployees();
  }
  Future<void> fetchAndSaveSalesOrders() async {
    const String apiUrl =
        'https://yenerp.com/fastapi/salesorders/withoutpagination/';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> salesOrders = json.decode(response.body);

        // Open Hive box to store sales orders
        var box = await Hive.openBox('salesOrderNumberBox');

        // Extract and save only saleOrderNo values
        List<String> saleOrderNos = [];
        for (var order in salesOrders) {
          if (order is Map && order.containsKey('saleOrderNo')) {
            saleOrderNos.add(order['saleOrderNo'].toString());
          }
        }

        // Save to Hive
        await box.put('saleOrderNos', saleOrderNos);

        // Optional: keep in GlobalDataManager
        GlobalDataManager().salesorders = saleOrderNos;

        notifyListeners();
      } else {}
    } catch (e) {}
  }

  Future<void> fetchDataIfNeeded({String? branchAlias}) async {
    var connectivityResult = await _connectivity.checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      return;
    }

    var lazyBox = await Hive.openLazyBox('items');

    var client = http.Client();

    try {
      bool needToFetch =
          branchAlias != null &&
          (globals.appType == 'server' || globals.appType == '') &&
          !await lazyBox.containsKey('branchwiseItems_$branchAlias');

      if (needToFetch) {
        try {
          var url =
              'https://yenerp.com/fastapi/branchwiseitems/?branch_alias=$branchAlias';

          var response = await client.get(Uri.parse(url));

          if (response.statusCode == 200) {
            var jsonData = json.decode(response.body);

            await lazyBox.put('branchwiseItems_$branchAlias', jsonData);

            GlobalDataManager().branchwiseItems = jsonData;

            _extractVarianceNames(jsonData);
            _filteredVarianceNames = _varianceNames;

            final branchwiseItems = jsonData['data'] as Map<String, dynamic>;
            var localStockBox = await Hive.openBox('localStockBox');

            for (var itemEntry in branchwiseItems.entries) {
              final itemName = itemEntry.key;
              final itemDetails = itemEntry.value;

              final variances =
                  itemDetails['variance'] as Map<String, dynamic>?;
              if (variances != null) {
                for (var varianceEntry in variances.entries) {
                  final varianceName = varianceEntry.key;
                  final varianceData = varianceEntry.value;

                  final String? itemCode = varianceData['varianceitemCode'];

                  final branchData =
                      (varianceData['branchwise'] as Map?)?[branchAlias];

                  if (itemCode != null && branchData != null) {
                    final localStockKey =
                        'systemStock_${branchAlias}_$itemCode';
                    final localHiveStock =
                        branchData['systemStock_$branchAlias'];

                    if (localHiveStock != null) {
                      await localStockBox.put(localStockKey, localHiveStock);

                      final currentGlobalData = await lazyBox.get(
                        'branchwiseItems_$branchAlias',
                      );

                      if (currentGlobalData != null) {
                        final dataMap = Map<String, dynamic>.from(
                          currentGlobalData,
                        );
                        final itemMap = Map<String, dynamic>.from(
                          dataMap['data'],
                        );
                        if (itemMap.containsKey(itemName)) {
                          final itemDetailsMap = Map<String, dynamic>.from(
                            itemMap[itemName],
                          );
                          final varianceMap = Map<String, dynamic>.from(
                            itemDetailsMap['variance'],
                          );
                          if (varianceMap.containsKey(varianceName)) {
                            final varianceDataMap = Map<String, dynamic>.from(
                              varianceMap[varianceName],
                            );
                            final branchwiseMap = Map<String, dynamic>.from(
                              varianceDataMap['branchwise'],
                            );
                            if (branchwiseMap.containsKey(branchAlias)) {
                              final updatedBranchData =
                                  Map<String, dynamic>.from(
                                    branchwiseMap[branchAlias],
                                  );
                              updatedBranchData['systemStock_$branchAlias'] =
                                  localHiveStock;

                              branchwiseMap[branchAlias] = updatedBranchData;
                              varianceDataMap['branchwise'] = branchwiseMap;
                              varianceMap[varianceName] = varianceDataMap;
                              itemDetailsMap['variance'] = varianceMap;
                              itemMap[itemName] = itemDetailsMap;
                              dataMap['data'] = itemMap;

                              await lazyBox.put(
                                'branchwiseItems_$branchAlias',
                                dataMap,
                              );

                              GlobalDataManager().branchwiseItems = dataMap;
                            }
                          }
                        }
                      } else {}
                    } else {}
                  } else {}
                }
              } else {}
            }

            final result = checkVarianceItemCode("FG011");

            notifyListeners();
          } else {}
        } catch (e, st) {}
      } else {
        GlobalDataManager().branchwiseItems = await lazyBox.get(
          'branchwiseItems_$branchAlias',
        );

        _extractVarianceNames(GlobalDataManager().branchwiseItems);
        _filteredVarianceNames = _varianceNames;
      }

      if (!await lazyBox.containsKey('branches')) {
        try {
          var response = await client.get(
            Uri.parse('https://yenerp.com/fastapi/branches/'),
          );
          if (response.statusCode == 200) {
            var jsonData = json.decode(response.body);
            await lazyBox.put('branches', jsonData);
            GlobalDataManager().branches = jsonData;
            printBranchNames(jsonData);
            notifyListeners();
          } else {}
        } catch (e, st) {}
      } else {
        GlobalDataManager().branches = await lazyBox.get('branches');
      }
    } finally {
      client.close();
    }
  }

  Future<void> fetchAndStoreBranches() async {
    var client = http.Client();
    var lazyBox = await Hive.openLazyBox('items');

    try {
      var response = await client.get(
        Uri.parse('https://yenerp.com/fastapi/branches/'),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);

        await lazyBox.put('branches', jsonData);

        GlobalDataManager().branches = jsonData;

        for (var branch in GlobalDataManager().branches) {}
        printBranchNames(jsonData);

        notifyListeners();
      } else {}
    } catch (e) {
    } finally {
      client.close();
    }
  }

  Future<int?> getLocalStock(String branchAlias, String itemCode) async {
    final box = await Hive.openBox('localStockBox');
    final key = 'systemStock_${branchAlias}_$itemCode';
    return box.get(key);
  }

  Future<void> updateLocalStock(
    String branchAlias,
    String itemCode,
    int newStock,
  ) async {
    final box = await Hive.openBox('localStockBox');
    final key = 'systemStock_${branchAlias}_$itemCode';
    await box.put(key, newStock);
    notifyListeners();
  }

  Map<String, dynamic>? _convertMap(Map<dynamic, dynamic>? original) {
    return original?.map((k, v) => MapEntry(k.toString(), v));
  }

  /// Return the variance-item-code (FGxxxx) for a given variance name,
  /// or null if not found.
  String? varianceCodeForName(String varianceName) {
    final data = _convertMap(
      GlobalDataManager().branchwiseItems['data'] as Map<dynamic, dynamic>?,
    );
    if (data == null) return null;

    for (final item in data.values) {
      final itemMap = _convertMap(item as Map<dynamic, dynamic>?);
      final variances = _convertMap(
        itemMap?['variance'] as Map<dynamic, dynamic>?,
      );
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
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> employeeData = json.decode(response.body);

        // Open Hive box and store employee data
        var box = await Hive.openBox('employeeBox');
        await box.put('employees', employeeData);
      } else {}
    } catch (e) {}
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

  // Fetch Mixbox API and store data
  Future<void> fetchAndSaveMixboxData(LazyBox lazyBox) async {
    const mixboxKey = 'mixboxData';

    try {
      var response = await http.get(
        Uri.parse('https://yenerp.com/fastapi/mixbox/'),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);
        await lazyBox.put(mixboxKey, jsonData); // Store mixbox data in Hive
        GlobalDataManager().mixboxData =
            jsonData; // Store globally in GlobalDataManager
        notifyListeners(); // Notify listeners to update the UI
      } else {}
    } catch (e) {}
  }

  List<String> getBranchNames() {
    if (GlobalDataManager().branches is List) {
      return (GlobalDataManager().branches as List)
          .map((branch) => branch['branchName'] as String)
          .toList();
    }
    return [];
  }

  Future<String?> getAliasName(String branchName) async {
    if (GlobalDataManager().branches is List) {
      final branches = GlobalDataManager().branches as List;
      final branch = branches.firstWhere(
        (b) => b['branchName'] == branchName,
        orElse: () => null,
      );
      final alias = branch?['aliasName'];
      return alias ?? 'Alias Not Found';
    }
    return 'Alias Not Found';
  }

  Future<String?> getBranchNameFromAlias(String aliasName) async {
    // Step 1: Validate input
    if (aliasName.trim().isEmpty) {
      return 'Invalid alias name';
    }

    // Step 2: Check if branches list exists
    final branchesData = GlobalDataManager().branches;
    if (branchesData == null) {
      return 'Branches list not available';
    }

    if (branchesData is! List) {
      return 'Invalid branches format';
    }

    final branches = branchesData as List;

    // Step 3: Print all available aliases (for debugging visibility)
    for (int i = 0; i < branches.length; i++) {}

    // Step 4: Search for branch by alias name (case-insensitive match for robustness)
    final branch = branches.firstWhere(
      (b) =>
          (b['aliasName']?.toString().trim().toLowerCase() ?? '') ==
          aliasName.trim().toLowerCase(),
      orElse: () => null,
    );

    // Step 5: Handle result
    if (branch != null) {
      final branchName = branch['branchName']?.toString() ?? 'Unknown Branch';
      return branchName;
    } else {
      return 'Branch Not Found';
    }
  }

  void printBranchNames(dynamic data) {
    if (data is List) {
      for (var branch in data) {
        String branchName = branch['branchName'] ?? 'Unknown';
        // String aliasName = branch['aliasName'] ?? 'Unknown';
        String pettyCash = branch['pettyCash'] ?? 'Unknown';
      }
    }
  }

  void printCategories(List<String> categories) {
    for (var category in categories) {}
  }

  void printData(
    dynamic data, {
    required String dataType,
    required bool isNewData,
  }) {
    if (isNewData) {
    } else {}
  }

  void CategoriesFromData(dynamic data) {
    if (data is Map && data.containsKey('categories')) {
      List<String> categories = List<String>.from(data['categories'] ?? "");
      printCategories(categories);
    } else {}
  }

  void printVarianceNames() {
    final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map?;
    if (branchwiseItems == null) {
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
    } else {
      varianceNames.forEach(print);
    }
  }

  List<Map<String, dynamic>> checkVarianceItemCode(String varianceItemCode) {
    final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map?;
    if (branchwiseItems == null) {
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
              },
            ];
          }
        }
      }
    }

    return [];
  }
}

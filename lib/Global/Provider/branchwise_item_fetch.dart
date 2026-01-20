import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';

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
    fetchAndSaveSalesOrders(branchAlias: globals.aliasname);
    fetchAndStoreBranches();
    fetchDataIfNeeded(branchAlias: globals.aliasname);
    fetchAndSaveEmployees();
    fetchAndStoreEvents();
    fetchAndStoreCustomCharges();
    fetchAndStoreDeliveryType();
    // fetchSalesOrdersPage();
    fetchAndSaveCustomers();
    fetchAndStoreDiscount();
    fetchAndStoreAdvancePercent(branchAlias: globals.aliasname);
  }
  Future<void> fetchAndSaveSalesOrders({String? branchAlias}) async {
    String apiUrl =
        'https://yenerp.com/fluttertestapi/salesorders/last-sale-order/$branchAlias';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        String saleOrderNo = data['saleOrderNo']?.toString() ?? "";

        // Open Hive box
        var box = HiveManager.salesOrderNumberBox;

        // Save single saleOrderNo
        await box.put('saleOrderNo', saleOrderNo);

        // Optional: update global
        GlobalDataManager().salesorders = [saleOrderNo];

        notifyListeners();
      } else {}
    } catch (e, stackTrace) {}
  }

  Future<void> fetchDataIfNeeded({String? branchAlias}) async {
    // Validate branchAlias
    if (branchAlias == null || branchAlias.trim().isEmpty) {
      return;
    }

    var connectivityResult = await _connectivity.checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      return;
    }

    var lazyBox = await Hive.openBox('items');

    var client = http.Client();

    try {
      bool needToFetch =
          branchAlias != null &&
          (globals.appType == 'server' || globals.appType == '');

      if (needToFetch) {
        try {
          var url =
              'https://yenerp.com/fluttertestapi/branchwiseitems/?branch_alias=$branchAlias';

          var response = await client.get(Uri.parse(url));

          if (response.statusCode == 200) {
            var jsonData = json.decode(response.body);

            await lazyBox.put('branchwiseItems_$branchAlias', jsonData);

            _extractVarianceNames(jsonData);
            _filteredVarianceNames = _varianceNames;

            final branchwiseItems = jsonData['data'] as Map<String, dynamic>;
            var localStockBox = await Hive.openBox('localStockBox');

            for (var itemEntry in branchwiseItems.entries) {
              final itemName = itemEntry.key;
              final itemDetails = itemEntry.value;

              final variances =
                  itemDetails['variance'] as Map<String, dynamic>?;

              if (variances == null) {
                continue;
              }

              for (var varianceEntry in variances.entries) {
                final varianceName = varianceEntry.key;
                final varianceData =
                    varianceEntry.value as Map<String, dynamic>;

                final String? itemCode = varianceData['itemCode'];

                final branchwiseMap =
                    varianceData['branchwise'] as Map<String, dynamic>?;

                if (itemCode == null || branchwiseMap == null) {
                  continue;
                }

                // ✅ CORRECT: Direct branch data fetch
                final branchData =
                    branchwiseMap[branchAlias] as Map<String, dynamic>?;

                if (branchData == null) {
                  continue;
                }

                final localHiveStock = branchData['systemStock_$branchAlias'];
                final localSystemStockSo =
                    branchData['systemstockSo_$branchAlias'];

                // Save to Hive
                final localStockKey = 'systemStock_$branchAlias';
                final localSystemStockSoKey = 'systemstockSo_$branchAlias';

                if (localHiveStock != null) {
                  await localStockBox.put(localStockKey, localHiveStock);
                }

                if (localSystemStockSo != null) {
                  await localStockBox.put(
                    localSystemStockSoKey,
                    localSystemStockSo,
                  );
                }

                // Update global Hive copy
                final currentGlobalData = await lazyBox.get(
                  'branchwiseItems_$branchAlias',
                );

                if (currentGlobalData != null) {
                  final dataMap = Map<String, dynamic>.from(currentGlobalData);
                  final itemMap = Map<String, dynamic>.from(dataMap['data']);
                  final itemDetailsMap = Map<String, dynamic>.from(
                    itemMap[itemName],
                  );
                  final varianceMap = Map<String, dynamic>.from(
                    itemDetailsMap['variance'],
                  );
                  final varianceDataMap = Map<String, dynamic>.from(
                    varianceMap[varianceName],
                  );
                  final branchwiseMap = Map<String, dynamic>.from(
                    varianceDataMap['branchwise'],
                  );

                  // Update correct branch
                  final updatedBranchData = Map<String, dynamic>.from(
                    branchwiseMap[branchAlias],
                  );

                  updatedBranchData['systemStock_$branchAlias'] =
                      localHiveStock;

                  if (localSystemStockSo != null) {
                    updatedBranchData['systemstockSo_$branchAlias'] =
                        localSystemStockSo;
                  }

                  branchwiseMap[branchAlias] = updatedBranchData;

                  varianceDataMap['branchwise'] = branchwiseMap;
                  varianceMap[varianceName] = varianceDataMap;
                  itemDetailsMap['variance'] = varianceMap;
                  itemMap[itemName] = itemDetailsMap;
                  dataMap['data'] = itemMap;

                  await lazyBox.put('branchwiseItems_$branchAlias', dataMap);
                }
              }
            }

            final result = checkVarianceItemCode("FG011", globals.aliasname);

            notifyListeners();
          } else {}
        } catch (e, st) {}
      } else {
        var localData = await lazyBox.get('branchwiseItems_$branchAlias');
        _extractVarianceNames(localData);
        _filteredVarianceNames = _varianceNames;
      }
    } finally {
      client.close();
    }
  }

  Future<void> fetchAndStoreBranches() async {
    var client = http.Client();
    var lazyBox = HiveManager.branches;

    try {
      var response = await client.get(
        Uri.parse('https://yenerp.com/nextjstestapi/locations/'),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);

        await lazyBox.add(jsonData);

        GlobalDataManager().branches = jsonData;

        notifyListeners();
      } else {}
    } catch (e) {
    } finally {
      client.close();
    }
  }

  Future<void> fetchAndSaveCustomers() async {
    var client = http.Client();
    var lazyBox = HiveManager.customers;

    try {
      var response = await client.get(
        Uri.parse('https://yenerp.com/fluttertestapi/customers/'),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);

        await lazyBox.put('customers', jsonData);

        GlobalDataManager().customers = jsonData;

        notifyListeners();
      } else {}
    } catch (e, stackTrace) {
    } finally {
      client.close();
    }
  }

  Future<void> fetchAndStoreEvents() async {
    var client = http.Client();
    var lazyBox = HiveManager.events;

    try {
      var response = await client.get(
        Uri.parse('https://yenerp.com/nextjstestapi/events/'),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);

        await lazyBox.put('events', jsonData);

        GlobalDataManager().events = jsonData;

        notifyListeners();
      } else {}
    } catch (e, stackTrace) {
    } finally {
      client.close();
    }
  }

  Future<void> fetchAndStoreDiscount() async {
    var client = http.Client();
    var lazyBox = HiveManager.discounts;

    try {
      var response = await client.get(
        Uri.parse('https://yenerp.com/nextjstestapi/discounts/'),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);

        await lazyBox.add(jsonData);

        GlobalDataManager().discounts = jsonData;

        notifyListeners();
      } else {}
    } catch (e, stackTrace) {
    } finally {
      client.close();
    }
  }

  Future<void> fetchAndStoreAdvancePercent({String? branchAlias}) async {
    var client = http.Client();
    var lazyBox = HiveManager.advancePercent;

    try {
      var response = await client.get(
        Uri.parse(
          'https://yenerp.com/fluttertestapi/advanceamounts/advance/by-alias?aliasName=${globals.aliasname}',
        ),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);

        await lazyBox.add(jsonData);

        GlobalDataManager().advancePercent = jsonData;

        notifyListeners();
      } else {}
    } catch (e, stackTrace) {
    } finally {
      client.close();
    }
  }

  Future<void> fetchAndStoreDeliveryType() async {
    var client = http.Client();
    var lazyBox = HiveManager.deliveryTypes;

    try {
      var response = await client.get(
        Uri.parse('https://yenerp.com/nextjstestapi/deliverytypes/'),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);

        await lazyBox.put('deliveryTypes', jsonData);

        GlobalDataManager().deliveryTypes = jsonData;

        notifyListeners();
      } else {}
    } catch (e, stackTrace) {
    } finally {
      client.close();
    }
  }

  Future<void> fetchAndStoreCustomCharges() async {
    var client = http.Client();
    var lazyBox = HiveManager.customCharges;

    try {
      var response = await client.get(
        Uri.parse('https://yenerp.com/nextjstestapi/charges/'),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);

        await lazyBox.put('charges', jsonData);

        GlobalDataManager().charges = jsonData;

        notifyListeners();
      } else {}
    } catch (e, stackTrace) {
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

  Future<Map<String, dynamic>?> _loadBranchwiseDataFromHive(
    String branchAlias,
  ) async {
    final lazyBox = await Hive.openBox('items');

    final hiveData = await lazyBox.get('branchwiseItems_$branchAlias');

    if (hiveData == null || hiveData['data'] == null) {
      return null;
    }

    return Map<String, dynamic>.from(hiveData['data']);
  }

  /// Return the variance-item-code (FGxxxx) for a given variance name,
  /// or null if not found.
  // String? varianceCodeForName(String varianceName) {
  //   final data = _convertMap(
  //     GlobalDataManager().branchwiseItems['data'] as Map<dynamic, dynamic>?,
  //   );
  //   if (data == null) return null;

  //   for (final item in data.values) {
  //     final itemMap = _convertMap(item as Map<dynamic, dynamic>?);
  //     final variances = _convertMap(
  //       itemMap?['variance'] as Map<dynamic, dynamic>?,
  //     );
  //     if (variances == null) continue;

  //     for (final v in variances.values) {
  //       final varianceMap = _convertMap(v as Map<dynamic, dynamic>?);
  //       if (varianceMap?['varianceName'] == varianceName) {
  //         return varianceMap?['varianceitemCode'] as String?;
  //       }
  //     }
  //   }
  //   return null;
  // }
  Future<String?> varianceCodeForName(
    String varianceName,
    String branchAlias,
  ) async {
    final hiveData = await _loadBranchwiseDataFromHive(branchAlias);
    if (hiveData == null) return null;

    final data = _convertMap(hiveData);
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

  Future<Map<String, String>?> getBranchInfoFromAlias(String aliasName) async {
    if (aliasName.trim().isEmpty) {
      return null;
    }

    final branchesData = GlobalDataManager().branches;
    if (branchesData == null || branchesData is! List) {
      return null;
    }

    // Normalize the alias input
    String normalize(String str) =>
        str.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

    final branch = (branchesData as List).firstWhere(
      (b) =>
          normalize(b['aliasName']?.toString() ?? '') == normalize(aliasName),
      orElse: () => null,
    );

    if (branch != null) {
      return {
        'branchName': branch['branchName']?.toString() ?? 'Unknown Branch',
        'address': branch['address']?.toString() ?? 'Address Not Available',
        'phone': branch['phoneNumber']?.toString() ?? 'Phone Not Available',
      };
    } else {
      return null;
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

  // void printVarianceNames() {
  //   final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map?;
  //   if (branchwiseItems == null) {
  //     return;
  //   }

  //   Set<String> varianceNames = {};

  //   // Iterate over each item in the data
  //   branchwiseItems.forEach((itemName, itemDetails) {
  //     var variances = itemDetails['variance'] as Map?;
  //     if (variances != null) {
  //       // Extract each variance name from the variance map
  //       variances.forEach((varianceName, _) {
  //         varianceNames.add(varianceName);
  //       });
  //     }
  //   });

  //   // Print all unique variance names
  //   if (varianceNames.isEmpty) {
  //   } else {
  //     varianceNames.forEach(print);
  //   }
  // }

  // List<Map<String, dynamic>> checkVarianceItemCode(String varianceItemCode) {
  //   final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map?;
  //   if (branchwiseItems == null) {
  //     return [];
  //   }

  //   for (var entry in branchwiseItems.entries) {
  //     // final itemName = entry.key;
  //     final itemDetails = entry.value as Map;

  //     final itemData = itemDetails['item'] as Map;
  //     final variances = itemDetails['variance'] as Map?;

  //     if (variances != null) {
  //       for (var varianceEntry in variances.entries) {
  //         final varianceData = varianceEntry.value as Map;
  //         if (varianceData['varianceitemCode'] == varianceItemCode) {
  //           return [
  //             {
  //               "itemData": itemData,
  //               "varianceData": varianceData,
  //               "quantity": 1,
  //             },
  //           ];
  //         }
  //       }
  //     }
  //   }

  //   return [];
  // }

  Future<void> printVarianceNames(String branchAlias) async {
    final branchwiseItems = await _loadBranchwiseDataFromHive(branchAlias);
    if (branchwiseItems == null) return;

    Set<String> varianceNames = {};

    branchwiseItems.forEach((itemName, itemDetails) {
      var variances = itemDetails['variance'] as Map?;
      if (variances != null) {
        variances.forEach((varianceName, _) {
          varianceNames.add(varianceName.toString());
        });
      }
    });

    varianceNames.forEach(print);
  }

  Future<List<Map<String, dynamic>>> checkVarianceItemCode(
    String branchAlias,
    String varianceItemCode,
  ) async {
    final branchwiseItems = await _loadBranchwiseDataFromHive(branchAlias);
    if (branchwiseItems == null) return [];

    for (var entry in branchwiseItems.entries) {
      final itemDetails = entry.value as Map;

      final itemData = itemDetails['item'] as Map?;
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

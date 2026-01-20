import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../kotpreinvoice/handlers/global_datamanager.dart';
import 'dart:async';
import 'package:yenpos/Global/globals_data.dart';
import '../models/product.dart';
import '../components/flushbar.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  late Box _productBox;
  late Box _tableBox;
  get tableBox => _tableBox;
  late Box _addOnBox; // Add-on box for storing add-ons
  List<Map<String, dynamic>> _addons = []; // List to store add-ons data
  late Box _variantBox; // Add-on box for storing add-ons
  List<Map<String, dynamic>> _variants = []; // List to store add-ons data
  final Map<int, String?> _selectedVariants = {};

  final Completer<void> _hiveInitialized = Completer<void>();

  List<Product> get products => _products;
  List<Map<String, dynamic>> get addons => _addons;
  List<Map<String, dynamic>> get variants => _variants;
  bool loading = false;

  Future<void> initializeHive() async {
    // _productBox = Hive.box('items');
    _tableBox = Hive.box('branchwise_tables');
    _addOnBox = Hive.box('addons');
    _variantBox = Hive.box('variants');

    // Complete initialization before fetching data
    // await loadProductsFromHive();
    await loadTablesFromHive();
    await _loadAddOnsFromHive();
    await _loadvariantsFromHive();

    if (!_hiveInitialized.isCompleted) {
      _hiveInitialized.complete();
    }
    notifyListeners();
  }

  Future<void> initProductBox() async {
    _productBox = Hive.box('items');
  }

  // Future<void> loadProductsFromHive() async {
  //   try {
  //     // if (!_productBox.isOpen) {
  //     //   await Hive.openBox('items');
  //     // }
  //     final branchItems = await Hive.openBox('items');

  //     debugPrint("branchItems is $branchItems");

  //     final fullWrapper = branchItems.get('branchwiseItems_$aliasname');
  //     debugPrint("fullWrapper is $fullWrapper");

  //     final hiveDataRaw = fullWrapper;

  //     debugPrint("hiveDataRaw is $hiveDataRaw");

  //     if (hiveDataRaw != null && hiveDataRaw is Map) {
  //       final productData = castToStringKeyedMap(hiveDataRaw);

  //       debugPrint("productData is $productData");

  //       if (productData.isEmpty) return;

  //       _products = []; // Reset before appending valid data

  //       productData.forEach((key, value) {
  //         debugPrint("value is $value");
  //         final item = castToStringKeyedMap(value['item'] ?? {});
  //         final variances = castToStringKeyedMap(value['variance'] ?? {});

  //         variances.forEach((varKey, varValue) {
  //           try {
  //             final defaultPrice = (varValue['variance_Defaultprice'] is num)
  //                 ? (varValue['variance_Defaultprice'] as num).toDouble()
  //                 : double.tryParse(
  //                         varValue['variance_Defaultprice'].toString(),
  //                       ) ??
  //                       (item['item_Defaultprice'] is num
  //                           ? (item['item_Defaultprice'] as num).toDouble()
  //                           : double.tryParse(
  //                               item['item_Defaultprice'].toString(),
  //                             )) ??
  //                       0.0;

  //             final branchwise =
  //                 varValue['branchwise'] as Map<String, dynamic>?;
  //             int localHiveStock = 0;
  //             if (branchwise != null && branchwise.containsKey(aliasname)) {
  //               final branchData =
  //                   branchwise[aliasname] as Map<String, dynamic>;
  //               final stockKey = 'localHiveStock_$aliasname';
  //               const fallbackKey = 'localHiveStock';

  //               if (branchData.containsKey(stockKey)) {
  //                 localHiveStock =
  //                     int.tryParse(branchData[stockKey].toString()) ?? 0;
  //               } else if (branchData.containsKey(fallbackKey)) {
  //                 localHiveStock =
  //                     int.tryParse(branchData[fallbackKey].toString()) ?? 0;
  //               }
  //             }

  //             _products.add(
  //               Product.fromJson({
  //                 ...item,
  //                 ...varValue,
  //                 'defaultprice': defaultPrice,
  //                 'varianceName': varValue['varianceName'] ?? '',
  //                 'varianceitemCode': varValue['varianceitemCode'] ?? '',
  //                 'localHiveStock': localHiveStock,
  //               }),
  //             );
  //           } catch (e, stack) {
  //             debugPrint('Error parsing variance $varKey: $e\n$stack');
  //           }
  //         });
  //       });
  //     } else {
  //       debugPrint('No valid product data found in Hive.');
  //     }

  //     printAllLocalHiveStock();

  //     // Notify listeners safely after build
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       notifyListeners();
  //     });
  //   } catch (e, stack) {
  //     debugPrint('Failed to load products from Hive: $e\n$stack');
  //   }
  // }

  Future<void> loadProductsFromHive() async {
    try {
      
      // Open Hive box
      final Box branchItems = await Hive.openBox('items');

      debugPrint("branchItems opened");

      final dynamic fullWrapper = branchItems.get('branchwiseItems_$aliasname');

      // debugPrint("fullWrapper: $fullWrapper");

      if (fullWrapper == null || fullWrapper is! Map) {
        debugPrint('No valid product data found in Hive.');
        return;
      }

      final Map<String, dynamic> productData = castToStringKeyedMap(
        fullWrapper,
      );

      debugPrint("productData keys: ${productData.keys}");

      // 🔴 IMPORTANT: Only iterate `data`, NOT `categories`
      final dynamic rawData = productData['data'];

      if (rawData == null || rawData is! Map) {
        debugPrint('Invalid or missing `data` key in Hive');
        return;
      }

      final Map<String, dynamic> dataMap = castToStringKeyedMap(rawData);

      _products = []; // Reset product list

      dataMap.forEach((itemKey, value) {
        if (value is! Map) return;

        final Map<String, dynamic> item = castToStringKeyedMap(
          value['item'] ?? {},
        );

        final Map<String, dynamic> variances = castToStringKeyedMap(
          value['variance'] ?? {},
        );

        variances.forEach((varKey, varValue) {
          try {
            if (varValue is! Map) return;

            // -------- PRICE RESOLUTION --------
            final double defaultPrice =
                (varValue['variance_Defaultprice'] is num)
                ? (varValue['variance_Defaultprice'] as num).toDouble()
                : double.tryParse(
                        varValue['variance_Defaultprice']?.toString() ?? '',
                      ) ??
                      (item['item_Defaultprice'] is num
                          ? (item['item_Defaultprice'] as num).toDouble()
                          : double.tryParse(
                              item['item_Defaultprice']?.toString() ?? '',
                            )) ??
                      0.0;

            // -------- STOCK RESOLUTION --------
            int localHiveStock = 0;

            final Map<String, dynamic>? branchwise =
                varValue['branchwise'] as Map<String, dynamic>?;

            if (branchwise != null && branchwise.containsKey(aliasname)) {
              final Map<String, dynamic> branchData = castToStringKeyedMap(
                branchwise[aliasname],
              );

              final String stockKey = 'localHiveStock_$aliasname';

              if (branchData.containsKey(stockKey)) {
                localHiveStock =
                    int.tryParse(branchData[stockKey].toString()) ?? 0;
              } else if (branchData.containsKey('localHiveStock')) {
                localHiveStock =
                    int.tryParse(branchData['localHiveStock'].toString()) ?? 0;
              }
            }

            // -------- PRODUCT BUILD --------
            _products.add(
              Product.fromJson({
                ...item,
                ...varValue,
                'defaultprice': defaultPrice,
                'varianceName': varValue['varianceName'] ?? '',
                'varianceitemCode': varValue['itemCode'] ?? '',
                'localHiveStock': localHiveStock,
              }),
            );
          } catch (e, stack) {
            debugPrint('Error parsing variance $varKey: $e\n$stack');
          }
        });
      });

      printAllLocalHiveStock();

      // Notify listeners safely
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e, stack) {
      debugPrint('Failed to load products from Hive: $e\n$stack');
    }
  }

  // Utility function to recursively cast dynamic maps

  Map<String, dynamic> castToStringKeyedMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(
          key.toString(),
          value is Map ? castToStringKeyedMap(value) : value,
        ),
      );
    }
    return {};
  }

  Future<void> loadTablesFromHive() async {
    try {
      print("loadTablesFromHive is worked");
      final deviceBox = Hive.box('deviceData');
      final String? storedAlias = deviceBox.get('aliasName') ?? 'AR';

      if (storedAlias == null) {
        debugPrint("❌ Alias name not found in deviceData box");
        return;
      }

      final dynamic data = _tableBox.get('data');

      if (data == null) {
        debugPrint("❌ No table data found in Hive");
        return;
      }

      if (data is! List) {
        debugPrint("❌ Table data is not a List. Found: ${data.runtimeType}");
        return;
      }

      debugPrint("✅ Table data length: ${data.length}");

      final branches = data.map<Map<String, dynamic>>((json) {
        try {
          return Map<String, dynamic>.from(json as Map);
        } catch (e) {
          debugPrint("⚠️ Failed to parse branch JSON: $json, error: $e");
          return {};
        }
      }).toList();

      final Map<String, dynamic> branchData = branches.firstWhere(
        (branch) => branch['location'] == storedAlias,
        orElse: () {
          debugPrint("⚠️ No matching branch found for alias: $storedAlias");
          return {};
        },
      );

      if (branchData.isEmpty) {
        debugPrint("⚠️ No branch data found for $storedAlias");
        return;
      }

      final totalTableList = branchData['totalTable'];
      if (totalTableList == null || totalTableList is! List) {
        debugPrint("⚠️ totalTable is null or not a List");
        tables = [];
        return;
      }

      tables = totalTableList.map<Map<String, dynamic>>((area) {
        try {
          final String areaName = area['areaName'] ?? 'Unknown Area';
          final dynamic tablesList = area['tables'];
          List<Map<String, dynamic>> tablesInArea = [];

          if (tablesList != null && tablesList is List) {
            tablesInArea = tablesList.map<Map<String, dynamic>>((table) {
              try {
                return Map<String, dynamic>.from(table as Map);
              } catch (e) {
                debugPrint("⚠️ Failed to parse table: $table, error: $e");
                return <String, dynamic>{};
              }
            }).toList();
          }

          return {'areaName': areaName, 'tables': tablesInArea};
        } catch (e) {
          debugPrint("⚠️ Failed to parse area: $area, error: $e");
          return {
            'areaName': 'Unknown Area',
            'tables': <Map<String, dynamic>>[],
          };
        }
      }).toList();

      debugPrint("✅ Tables successfully loaded: ${tables.length} areas found");
    } catch (e, st) {
      debugPrint("❌ Error loading tables from Hive: $e");
      debugPrintStack(stackTrace: st);
      tables = [];
    }

    notifyListeners();
  }

  Future<void> fetchDataAndSaveInHive(BuildContext context) async {
    final dio = Dio();

    try {
      await _hiveInitialized.future;
      debugPrint("📡 Starting fetch of all data...");

      final url =
          'https://yenerp.com/fastapi/branchwiseitems/?branch_alias=$aliasname';
      debugPrint("🌐 Fetching from URL: $url");

      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      // 🧩 Check for valid response
      if (response.statusCode != 200) {
        debugPrint("⚠️ Unexpected status code: ${response.statusCode}");
        return;
      }
      if (response.data == null) {
        debugPrint("⚠️ Response data is null");
        return;
      }

      debugPrint("📦 Data fetched successfully from server ✅");

      final decoded = response.data is String ? response.data : response.data;
      if (decoded is! Map || decoded['data'] is! Map<String, dynamic>) {
        debugPrint("⚠️ Unexpected data format received");
        return;
      }

      final branchwiseItems = decoded['data'] as Map<String, dynamic>;
      final localStockBox = Hive.box('localStockBox');

      debugPrint("🔍 Processing ${branchwiseItems.length} items...");

      branchwiseItems.forEach((itemName, itemDetails) {
        try {
          final variances = (itemDetails['variance'] as Map?) ?? {};
          variances.forEach((varianceName, varianceData) {
            try {
              final itemCode = varianceData['varianceitemCode'] as String?;
              final branchData =
                  (varianceData['branchwise'] as Map?)?[aliasname];

              if (itemCode != null && branchData != null) {
                final localStockKey = 'localStock_${aliasname}_$itemCode';
                final localHiveStock = branchData['localHiveStock_$aliasname'];

                if (localHiveStock != null) {
                  localStockBox.put(localStockKey, localHiveStock);

                  final updatedBranchData = Map<String, dynamic>.from(
                    branchData,
                  )..['localHiveStock_$aliasname'] = localHiveStock;

                  final updatedVarianceData = Map<String, dynamic>.from(
                    varianceData,
                  );
                  final updatedBranchwiseMap = Map<String, dynamic>.from(
                    updatedVarianceData['branchwise'],
                  );
                  updatedBranchwiseMap[aliasname] = updatedBranchData;

                  updatedVarianceData['branchwise'] = updatedBranchwiseMap;
                  variances[varianceName] = updatedVarianceData;
                }
              }
            } catch (varianceError, varianceStack) {
              debugPrint(
                "❌ Error processing variance '$varianceName' for item '$itemName': $varianceError\n$varianceStack",
              );
            }
          });

          itemDetails['variance'] = variances;
          branchwiseItems[itemName] = itemDetails;
        } catch (itemError, itemStack) {
          debugPrint(
            "❌ Error processing item '$itemName': $itemError\n$itemStack",
          );
        }
      });

      final updatedData = {'data': branchwiseItems};

      // 💾 Save data to Hive
      final branchwiseBox = Hive.box('branchwise_items');
      await branchwiseBox.put('data', updatedData);

      debugPrint("💾 Data successfully saved to Hive box 'branchwise_items' ✅");

      GlobalDataManager().branchwiseItems = updatedData;

      debugPrint(
        "✅ branchwiseItems cache updated. Total items: ${branchwiseItems.length}",
      );
    } on DioException catch (e) {
      debugPrint("❌ Dio error fetching branchwiseItems: ${e.message}");
    } catch (e, stack) {
      debugPrint("❌ Unexpected error: $e\n$stack");
    } finally {
      dio.close();
    }

    // 🔄 Reload products
    debugPrint("🔄 Reloading products from Hive...");
    await loadProductsFromHive();
    debugPrint("✅ Products reloaded successfully.");
  }

  Future<void> fetchAllData(BuildContext context) async {
    print("fetchAllData is successfully Called !!");
    loading = true;
    notifyListeners();

    try {
      await fetchDataAndSaveInHive(context);
      await fetchTablesAndSaveInHive(context);
    } catch (e, stack) {
      debugPrint("❌ Error in fetchAllData: $e\n$stack");
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<int?> getLocalStock(String branchAlias, String itemCode) async {
    final box = Hive.box('localStockBox');
    final key = 'localStock_${branchAlias}_$itemCode';
    return box.get(key);
  }

  Future<void> updateLocalStock(
    String branchAlias,
    String itemCode,
    int newStock,
  ) async {
    final box = Hive.box('localStockBox');
    final key = 'localStock_${branchAlias}_$itemCode';
    await box.put(key, newStock);
    notifyListeners();
  }

  Future<void> printAllLocalHiveStock() async {
    final box = Hive.box('localStockBox');

    if (box.isEmpty) {
      return;
    }

    int count = 0;
    for (var key in box.keys) {
      final value = box.get(key);

      count++;
      if (count >= 10) break; // ✅ Stop after 10 items
    }
  }

  Future<void> printDataLengthFromHive() async {
    final storedData = _productBox.get('data');

    if (storedData != null && storedData is Map) {
      for (var key in storedData.keys) {
        final value = storedData[key];
        if (value is Map) {}
      }
    } else {}
  }

  Future<void> fetchTablesAndSaveInHive(BuildContext context) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );

    try {
      await _hiveInitialized.future;
      final response = await dio.get('https://yenerp.com/nextjstestapi/tables/');

      if (response.statusCode == 200) {
        try {
          final data = response.data as List<dynamic>;
          final tabledata = await _tableBox.put('data', data);
          await loadTablesFromHive();
        } catch (e) {
          debugPrint('JSON decoding error: $e');
          throw FormatException('Failed to decode tables data: $e');
        }
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: 'Failed to load tables data: HTTP ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        debugPrint('⏱️ Timeout error fetching tables: $e');
        showCustomFlushbar(
          context,
          '⏱️ Request timed out. Please try again later.',
          type: FlushbarType.warning,
        );
      } else if (e.type == DioExceptionType.connectionError) {
        debugPrint('🌐 Network error fetching tables: $e');
        showCustomFlushbar(
          context,
          '🌐 No internet connection. Please check your network.',
          type: FlushbarType.warning,
        );
      } else if (e.response != null) {
        debugPrint('💻 HTTP error: ${e.message}');
        showCustomFlushbar(
          context,
          '💻 Server error: HTTP ${e.response!.statusCode}',
          type: FlushbarType.error,
        );
      } else {
        debugPrint('❌ Dio error: $e');
        showCustomFlushbar(
          context,
          '❌ An error occurred while fetching tables.',
          type: FlushbarType.error,
        );
      }
    } on FormatException catch (e) {
      debugPrint('⚠️ Format error: $e');
      showCustomFlushbar(
        context,
        '⚠️ Invalid data format received from server.',
        type: FlushbarType.error,
      );
    } catch (e) {
      debugPrint('❌ Unexpected error fetching tables: $e');
      showCustomFlushbar(
        context,
        '❌ An unexpected error occurred. Please try again.',
        type: FlushbarType.error,
      );
    } finally {
      dio.close();
    }

    notifyListeners();
  }

  Future<void> _loadAddOnsFromHive() async {
    try {
      final data = _addOnBox.get('data');
      if (data != null && data is List) {
        _addons = data.map((json) {
          final addOn = Map<String, dynamic>.from(json as Map);
          addOn['addOnItems'] = addOn['addOnItems'] ?? [];
          return addOn;
        }).toList();
      } else {
        _addons = [];
      }
    } catch (e) {
      _addons = [];
    }
    notifyListeners();
  }

  bool hasAddOns(String varianceName) {
    final data = _addOnBox.get('data');

    return _addons.any((addon) {
      final addOnItems = addon['addOnItems'] as List<dynamic>;
      return addOnItems.contains(varianceName);
    });
  }

  // bool hasAddOns(String varianceName) {
  //   print("varianceName is $varianceName");

  //   List<dynamic> addONS = [
  //     "SPL GHEELADDU BOX",
  //     "BUTTER BUN",
  //     "BUTTERSCOTCH 1Kg",
  //     "CHOCOTRUFFLE CAKE 1/2Kg",
  //     "ROSE MILK CAKE 1/2Kg",
  //     "RED VELVET CAKE 1Kg",
  //     "ROSE MILK CAKE 1Kg",
  //     "ROSE MILK CAKE BOX",
  //     "ROLL CREAM CAKE",
  //     "CASHEW BOX 50g",
  //     "DATES FUDGE BOX",
  //   ];

  //   print("addONS is: $addONS");

  //   // Just check if varianceName exists in addONS list
  //   return addONS.contains(varianceName);
  // }

  Future<void> fetchAddOnsAndSaveInHive() async {
    final dio = Dio();

    try {
      await _hiveInitialized.future;

      final response = await dio.get(
        'https://yenerp.com/fastapi/addons/',
        options: Options(headers: {"Accept": "application/json"}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is List
            ? response.data
            : List.from(response.data);
        print("addon data is $data");
        await _addOnBox.put('data', data);
        await _loadAddOnsFromHive();
        print("✅ Add-ons loaded successfully.");
      } else {
        print("❌ Failed to load add-ons. Status: ${response.statusCode}");
      }
    } on DioError catch (dioError) {
      // Handles Dio-specific errors (network, timeout, response errors)
      print("⚠️ DioError while fetching add-ons: ${dioError.message}");
      if (dioError.response != null) {
        print("Response: ${dioError.response?.data}");
      }
    } on TimeoutException catch (_) {
      print("⏱️ Request timed out while fetching add-ons");
    } catch (e, st) {
      // Handles other errors
      print("❌ Unexpected error while fetching add-ons: $e");
      print(st);
    } finally {
      dio.close();
    }
  }

  Future<void> fetchVariantsAndSaveInHive() async {
    final dio = Dio();

    try {
      await _hiveInitialized.future;

      final response = await dio
          .get(
            'https://yenerp.com/fastapi/kotvariants/',
            options: Options(headers: {"Accept": "application/json"}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is List
            ? response.data
            : List.from(response.data);
        await _variantBox.put('data', data);
        await _loadvariantsFromHive();
        print("✅ Variants loaded successfully.");
      } else {
        print("❌ Failed to load variants. Status: ${response.statusCode}");
      }
    } on DioError catch (dioError) {
      print("⚠️ DioError while fetching variants: ${dioError.message}");
      if (dioError.response != null) {
        print("Response: ${dioError.response?.data}");
      }
    } on TimeoutException catch (_) {
      print("⏱️ Request timed out while fetching variants");
    } catch (e, st) {
      print("❌ Unexpected error while fetching variants: $e");
      print(st);
    } finally {
      dio.close();
    }
  }

  Future<void> _loadvariantsFromHive() async {
    try {
      final data = _variantBox.get('data');
      if (data != null && data is List) {
        _variants = data.map((json) {
          final variant = Map<String, dynamic>.from(json as Map);
          variant['variantItems'] = variant['variantItems'] ?? [];
          return variant;
        }).toList();
      } else {
        _variants = [];
      }
    } catch (e) {
      _variants = [];
    }
    notifyListeners();
  }

  bool hasVariants(String varianceName) {
    return _variants.any((variant) {
      final variantItems = variant['variantItems'] as List<dynamic>;
      return variantItems.contains(varianceName);
    });
  }

  // Method to get available variants for a specific product item
  List<String> getVariantsForItem(String varianceName) {
    List<String> availableVariants = [];

    for (var variant in _variants) {
      if (variant['variantItems'].contains(varianceName)) {
        availableVariants.add(variant['variant']);
      }
    }

    return availableVariants;
  }

  void setSelectedVariant(int index, String variant) {
    _selectedVariants[index] = variant;
    notifyListeners();
  }

  String? getSelectedVariant(int index) {
    return _selectedVariants[index];
  }
}

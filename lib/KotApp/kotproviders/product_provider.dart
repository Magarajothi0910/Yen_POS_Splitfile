import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import '../../screens/kot_screen/global/globals.dart';
import '../models/product.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  late Box _productBox;
  late Box _tableBox;
  late Box _addOnBox; // Add-on box for storing add-ons
  List<Map<String, dynamic>> _addons = []; // List to store add-ons data
  late Box _variantBox; // Add-on box for storing add-ons
  List<Map<String, dynamic>> _variants = []; // List to store add-ons data
  final Map<int, String?> _selectedVariants = {};
  WebSocketChannel? _ws;

  final Completer<void> _hiveInitialized = Completer<void>();

  List<Product> get products => _products;
  List<Map<String, dynamic>> get addons => _addons;
  List<Map<String, dynamic>> get variants => _variants;

  Future<void> initializeHive() async {
    _productBox = await Hive.openBox('branchwise_items');
    _tableBox = await Hive.openBox('branchwise_tables');
    _addOnBox = await Hive.openBox('addons'); // Open the add-ons box
    _variantBox = await Hive.openBox('variants'); // Open the add-ons box
    // Complete initialization before fetching data

    // await loadProductsFromHive();

    await _loadTablesFromHive();
    await _loadAddOnsFromHive();
    await _loadvariantsFromHive();

    if (!_hiveInitialized.isCompleted) {
      _hiveInitialized.complete();
    }
    notifyListeners();
  }

  Map<String, dynamic> castToStringKeyedMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(
            key.toString(), value is Map ? castToStringKeyedMap(value) : value),
      );
    }
    return {};
  }

  Future<void> _loadTablesFromHive() async {
    try {
      final data = _tableBox.get('data');
      if (data != null && data is List) {
        final branches =
            data.map((json) => Map<String, dynamic>.from(json as Map)).toList();
        final branchData = branches.firstWhere(
          (branch) => branch['location'] == aliasname,
        );

        totalTables = branchData['totalTableCount'];
        tables = (branchData['totalTable'] as List)
            .map((area) => {
                  'areaName': area['areaName'],
                  'tables': (area['tables'] as List)
                      .map((table) => Map<String, dynamic>.from(table as Map))
                      .toList(),
                })
            .toList();
      } else {}
    } catch (e) {}
    notifyListeners();
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

  Future<void> fetchTablesAndSaveInHive() async {
    try {
      await _hiveInitialized.future;
      final response =
          await http.get(Uri.parse('https://yenerp.com/fastapi/tables/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        await _tableBox.put('data', data);
        await _loadTablesFromHive();
      } else {
        throw Exception('Failed to load tables data');
      }
    } catch (e) {}
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
    return _addons.any((addon) {
      final addOnItems = addon['addOnItems'] as List<dynamic>;
      return addOnItems.contains(varianceName);
    });
  }

  Future<void> fetchAddOnsAndSaveInHive() async {
    try {
      await _hiveInitialized.future;
      final response =
          await http.get(Uri.parse('https://yenerp.com/fastapi/addons/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;

        await _addOnBox.put('data', data);
        await _loadAddOnsFromHive();
      } else {
        throw Exception('Failed to load add-ons data');
      }
    } catch (e) {}
  }

  Future<void> fetchVariantsAndSaveInHive() async {
    try {
      await _hiveInitialized.future;
      final response =
          await http.get(Uri.parse('https://yenerp.com/fastapi/kotvariants/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;

        await _variantBox.put('data', data);
        await _loadvariantsFromHive();
      } else {
        throw Exception('Failed to load kotvariantsdata');
      }
    } catch (e) {}
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

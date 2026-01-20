import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'isolation/sales_caculate.dart';

class CurrentSaleProvider with ChangeNotifier {
  late SaleCalculator _saleCalculator = SaleCalculator(
    [],
  ); // Initialize with an empty list

  List<Map<String, dynamic>> _currentSaleItems = [];
  final double _discountPercentage = 0.0; // Initial discount percentage
  final double _customCharge = 0.0; // New property for custom charge
  double get discountPercentage => _discountPercentage;
  double sgst = 0.0; // SGST amount
  double cgst = 0.0; // CGST amount

  double get sgstAmount => sgst; // Add getter for SGST
  double get cgstAmount => cgst; // Add getter for CGST
  List<Map<String, dynamic>> get currentSaleItems => _currentSaleItems;
  double get customCharge => _customCharge; // Getter for custom charge

  double sgstRate = 0.0; // Rate in percentage
  double cgstRate = 0.0; // Rate in percentage

  // Add getters for SGST and CGST rates
  double get sgstRatePercentage => sgstRate;
  double get cgstRatePercentage => cgstRate;

  String _selectedOption = 'TakeAway'; // Set default to "Take Away"

  String get selectedOption => _selectedOption;
  String _status = ''; // Track the current sale status
  String get saleStatus => _status;

  String? _holdBillId; // Store the selected hold bill ID

  String? get holdBillId => _holdBillId;
  String? _currentHoldId; // Store the currently loaded hold bill ID
  String? get currentHoldId => _currentHoldId;

  void setCurrentHoldId(String? id) {
    _currentHoldId = id;
    notifyListeners();
  }

  void setHoldBillId(String id) {
    _holdBillId = id;
    notifyListeners();
  }

  void selectOption(String option) {
    _selectedOption = option;
    _status = ''; // Reset the sale status
    notifyListeners(); // Notify the UI of changes
  }

  CurrentSaleProvider() {
    loadCartItems();
  }

  

  set discountPercentage(double value) {
    _saleCalculator.discountPercentage = value;
    notifyListeners(); // Notify listeners to update UI
  }

  set customCharge(double value) {
    _saleCalculator.customCharge = value;
    notifyListeners();
  }

  // Future<void> addItemToCart(Map<String, dynamic> newItem) async {
  //   print("DEBUG: Adding item with quantity: ${newItem['quantity']}, totalPrice: ${newItem['totalPrice']}");
  //   final uom = newItem['varianceData']?['variance_Uom']?.toString().toLowerCase() ?? 'pcs';
  //   if (uom == 'kgs') {
  //     newItem['quantity'] = newItem['quantity'] != null ? newItem['quantity'].toDouble() : 1.0;
  //     newItem['weight'] = newItem['weight']?.toDouble() ?? newItem['quantity'];
  //   } else {
  //     newItem['quantity'] = newItem['quantity'] != null ? newItem['quantity'].toDouble() : 1.0;
  //   }
  //   newItem['totalPrice'] =
  //       newItem['totalPrice']?.toDouble() ??
  //       (newItem['varianceData']?['variance_Defaultprice']?.toDouble() ?? 0.0) * newItem['quantity'];
  //   newItem['varianceData'] = {
  //     ...newItem['varianceData'],
  //     'variance_Defaultprice': newItem['varianceData']?['variance_Defaultprice']?.toDouble() ?? 0.0,
  //     'variance_Uom': newItem['varianceData']?['variance_Uom']?.toString() ?? 'Pcs',
  //   };
  //   newItem['id'] = newItem['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();

  //   if (uom == 'pcs') {
  //     bool exists = _currentSaleItems.any(
  //       (item) =>
  //           item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
  //           item['varianceData']['varianceName'] == newItem['varianceData']['varianceName'],
  //     );

  //     if (exists) {
  //       _currentSaleItems = _currentSaleItems.map((item) {
  //         if (item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
  //             item['varianceData']['varianceName'] == newItem['varianceData']['varianceName']) {
  //           // ✅ Add to existing quantity instead of replacing
  //           final oldQty = (item['quantity'] ?? 0).toDouble();
  //           final addQty = (newItem['quantity'] ?? 0).toDouble();
  //           final updatedQty = oldQty + addQty;

  //           item['quantity'] = updatedQty;
  //           item['totalPrice'] = updatedQty * (item['varianceData']?['variance_Defaultprice']?.toDouble() ?? 0.0);

  //           print("DEBUG: Updated existing item quantity: $oldQty + $addQty = $updatedQty");
  //         }
  //         return item;
  //       }).toList();
  //     } else {
  //       _currentSaleItems.insert(0, newItem);
  //       print("DEBUG: CurrentSaleProvider - Added new Pcs item: $newItem");
  //     }
  //   } else {
  //     _currentSaleItems.insert(0, newItem);
  //     print("DEBUG: CurrentSaleProvider - Added new Kgs item: $newItem");
  //   }

  //   _saleCalculator = SaleCalculator(_currentSaleItems);
  //   var box = await Hive.openBox('cartBox');
  //   await box.put('cartItems', _currentSaleItems);
  //   print("DEBUG: CurrentSaleProvider - Saved cart items to Hive: $_currentSaleItems");

  //   notifyListeners();
  // }

  Future<void> addItemToCart(Map<String, dynamic> newItem) async {
    print(
      "DEBUG: Adding item with quantity: ${newItem['quantity']}, totalPrice: ${newItem['totalPrice']}",
    );

    final uom =
        newItem['varianceData']?['variance_Uom']?.toString().toLowerCase() ??
        'pcs';
    newItem['quantity'] = (newItem['quantity'] ?? 1.0).toDouble();

    if (uom == 'kgs') {
      newItem['weight'] = (newItem['weight'] ?? newItem['quantity']).toDouble();
    }

    newItem['totalPrice'] =
        newItem['totalPrice']?.toDouble() ??
        (newItem['varianceData']?['variance_Defaultprice']?.toDouble() ?? 0.0) *
            newItem['quantity'];

    // Normalize & Create unique key
    final itemId =
        newItem['itemData']['itemId']?.toString().trim().toLowerCase() ?? '';
    final varianceName =
        newItem['varianceData']?['varianceName']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    newItem['cartKey'] = "${itemId}_$varianceName";

    if (uom == 'pcs') {
      final existingIndex = _currentSaleItems.indexWhere(
        (item) => item['cartKey'] == newItem['cartKey'],
      );

      if (existingIndex != -1) {
        final oldQty = (_currentSaleItems[existingIndex]['quantity'] ?? 0)
            .toDouble();
        final addQty = newItem['quantity'];
        final updatedQty = oldQty + addQty;

        _currentSaleItems[existingIndex]['quantity'] = updatedQty;
        _currentSaleItems[existingIndex]['totalPrice'] =
            updatedQty *
            (_currentSaleItems[existingIndex]['varianceData']?['variance_Defaultprice']
                    ?.toDouble() ??
                0.0);

        print(
          "✅ Merged existing item: ${newItem['cartKey']} → Qty $oldQty + $addQty = $updatedQty",
        );
      } else {
        _currentSaleItems.insert(0, newItem);
        print("🆕 Added new Pcs item: ${newItem['cartKey']}");
      }
    } else {
      _currentSaleItems.insert(0, newItem);
      print("🆕 Added new Kgs item: ${newItem['cartKey']}");
    }

    _saleCalculator = SaleCalculator(_currentSaleItems);

    var box = await Hive.openBox('cartBox');
    await box.put('cartItems', _currentSaleItems);

    print("DEBUG: Cart saved to Hive (${_currentSaleItems.length} items)");
    notifyListeners();
  }

  void addItemToCartExpressMode(Map<String, dynamic> newItem) async {
    // Normalize new item
    final uom =
        newItem['varianceData']?['variance_Uom']?.toString().toLowerCase() ??
        'pcs';
    if (uom == 'kgs') {
      newItem['quantity'] = newItem['quantity'] != null
          ? newItem['quantity'].toDouble()
          : 1.0;
      newItem['weight'] = newItem['weight']?.toDouble() ?? newItem['quantity'];
    } else {
      newItem['quantity'] = newItem['quantity'] != null
          ? int.tryParse(newItem['quantity'].toString()) ?? 1
          : 1;
    }
    newItem['id'] =
        newItem['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Check for existing item only for Pcs units
    if (uom == 'pcs') {
      bool exists = _currentSaleItems.any(
        (item) =>
            item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
            item['varianceData']['varianceName'] ==
                newItem['varianceData']['varianceName'],
      );

      if (exists) {
        _currentSaleItems = _currentSaleItems.map((item) {
          if (item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
              item['varianceData']['varianceName'] ==
                  newItem['varianceData']['varianceName']) {
            item['quantity'] += newItem['quantity'];
            print(
              "DEBUG: CurrentSaleProvider - Updated express Pcs item: $item",
            );
          }
          return item;
        }).toList();
      } else {
        _currentSaleItems.insert(0, newItem);
        print(
          "DEBUG: CurrentSaleProvider - Added new express Pcs item: $newItem",
        );
      }
    } else {
      _currentSaleItems.insert(0, newItem);
      print(
        "DEBUG: CurrentSaleProvider - Added new express Kgs item: $newItem",
      );
    }

    _saleCalculator = SaleCalculator(_currentSaleItems);
    var box = await Hive.openBox('cartBox');
    await box.put('cartItems', _currentSaleItems);

    notifyListeners();
  }

  void addItemsToCurrentSale(List<Map<String, dynamic>> newItems) {
    for (var newItem in newItems) {
      final uom =
          newItem['varianceData']?['variance_Uom']?.toString().toLowerCase() ??
          'pcs';
      if (uom == 'kgs') {
        newItem['quantity'] = newItem['quantity']?.toDouble() ?? 1.0;
        newItem['weight'] =
            newItem['weight']?.toDouble() ?? newItem['quantity'];
      } else {
        newItem['quantity'] =
            int.tryParse(newItem['quantity']?.toString() ?? '1') ?? 1;
      }
      newItem['id'] =
          newItem['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      if (uom == 'pcs') {
        bool exists = _currentSaleItems.any(
          (item) =>
              item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
              item['varianceData']['varianceName'] ==
                  newItem['varianceData']['varianceName'],
        );

        if (exists) {
          _currentSaleItems = _currentSaleItems.map((item) {
            if (item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
                item['varianceData']['varianceName'] ==
                    newItem['varianceData']['varianceName']) {
              item['quantity'] += newItem['quantity'];
              print(
                "DEBUG: CurrentSaleProvider - Updated bulk Pcs item: $item",
              );
            }
            return item;
          }).toList();
        } else {
          _currentSaleItems.add(newItem);
          print(
            "DEBUG: CurrentSaleProvider - Added new bulk Pcs item: $newItem",
          );
        }
      } else {
        _currentSaleItems.add(newItem);
        print("DEBUG: CurrentSaleProvider - Added new bulk Kgs item: $newItem");
      }
    }

    _saleCalculator = SaleCalculator(_currentSaleItems);
    notifyListeners();
  }

  Future<void> loadCartItems() async {
    try {
      var box = await Hive.openBox('cartBox');
      List<dynamic> rawItems = box.get('cartItems', defaultValue: []);
      _currentSaleItems = rawItems
          .map((item) {
            final map = Map<String, dynamic>.from(item);
            final uom =
                map['varianceData']?['variance_Uom']
                    ?.toString()
                    .toLowerCase() ??
                'pcs';
            // Use double for all quantities to preserve precision
            map['quantity'] = (map['quantity'] as num?)?.toDouble() ?? 1.0;
            map['weight'] =
                (map['weight'] as num?)?.toDouble() ??
                (uom == 'kgs' ? map['quantity'] : 0.0);
            map['totalPrice'] = (map['totalPrice'] as num?)?.toDouble() ?? 0.0;
            if (map['varianceData'] != null && map['varianceData'] is Map) {
              final varianceMap = Map<String, dynamic>.from(
                map['varianceData'],
              );
              varianceMap['variance_Defaultprice'] =
                  (varianceMap['variance_Defaultprice'] as num?)?.toDouble() ??
                  0.0;
              varianceMap['variance_Uom'] =
                  varianceMap['variance_Uom']?.toString() ?? 'Pcs';
              map['varianceData'] = varianceMap;
            }
            map['id'] =
                map['id']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString();
            return map;
          })
          .where((item) => (item['quantity'] ?? 0.0) > 0)
          .toList();

      _saleCalculator = SaleCalculator(_currentSaleItems, debug: true);
      print(
        "DEBUG: CurrentSaleProvider - Loaded cart items: $_currentSaleItems",
      );
      notifyListeners();
    } catch (e) {
      print("DEBUG: CurrentSaleProvider - Error loading cart items: $e");
    }
  }

  void clearCart() {
    _currentSaleItems.clear();
    Hive.box('cartBox').put('cartItems', []);
    print("DEBUG: CurrentSaleProvider - Cleared cart");
    notifyListeners();
  }

  // void loadItemsFromBill(List<dynamic>? items, {bool merge = false, String? holdId}) {
  //   if (items == null || items.isEmpty) {
  //     return;
  //   }

  //   if (!merge) {
  //     _currentSaleItems.clear();
  //   }

  //   for (var newItem in items) {
  //     if (newItem == null || !newItem.containsKey('itemData') || !newItem.containsKey('varianceData')) {
  //       continue;
  //     }

  //     bool exists = _currentSaleItems.any(
  //       (item) =>
  //           item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
  //           item['varianceData']['varianceName'] == newItem['varianceData']['varianceName'],
  //     );

  //     if (!exists) {
  //       _currentSaleItems.add(newItem);
  //     }
  //   }

  //   _currentHoldId = holdId;
  //   _saleCalculator = SaleCalculator(_currentSaleItems);
  //   notifyListeners();
  // }

  // In your CurrentSaleProvider class

  void loadItemsFromBill(
    List<Map<String, dynamic>> items, {
    bool merge = false,
    String? holdId,
  }) {
    try {
      if (!merge) {
        // Clear current items when loading a single bill
        currentSaleItems.clear();
      }

      // Add all items with proper structure
      for (var item in items) {
        // Ensure the item has proper structure
        Map<String, dynamic> processedItem = _processItemForCart(item);

        // Check if item already exists in cart (only for quantity items in merge mode)
        if (merge) {
          final String uom =
              (processedItem['varianceData']?['variance_Uom']
                  ?.toString()
                  .toLowerCase() ??
              '');
          final bool isWeightItem =
              uom.contains('kg') || uom.contains('kgs') || uom.contains('gm');

          if (!isWeightItem) {
            // For quantity items in merge mode, check if same item exists
            int existingIndex = _findExistingQuantityItem(processedItem);
            if (existingIndex != -1) {
              // Combine quantities
              double currentQty =
                  (currentSaleItems[existingIndex]['quantity'] as num)
                      .toDouble();
              double newQty = (processedItem['quantity'] as num).toDouble();
              currentSaleItems[existingIndex]['quantity'] = currentQty + newQty;
              continue;
            }
          }
          // For weight items or new quantity items, add as new entry
        }

        currentSaleItems.add(processedItem);
      }

      // if (holdId != null) {
      //   this.holdBillId = holdId;
      // }

      notifyListeners();

      print(
        'DEBUG: Loaded ${items.length} items to cart. Total items: ${currentSaleItems.length}',
      );
    } catch (e) {
      print('Error loading items from bill: $e');
      throw e;
    }
  }

  int _findExistingQuantityItem(Map<String, dynamic> newItem) {
    final String newItemCode = newItem['itemCode']?.toString() ?? '';
    final String newVarianceName =
        newItem['varianceData']?['varianceName']?.toString() ?? '';
    final String newUom =
        (newItem['varianceData']?['variance_Uom']?.toString().toLowerCase() ??
        '');

    // Only look for quantity items (non-weight items)
    final bool isWeightItem =
        newUom.contains('kg') ||
        newUom.contains('kgs') ||
        newUom.contains('gm');
    if (isWeightItem) return -1;

    for (int i = 0; i < currentSaleItems.length; i++) {
      final existingItem = currentSaleItems[i];
      final String existingItemCode =
          existingItem['itemCode']?.toString() ?? '';
      final String existingVarianceName =
          existingItem['varianceData']?['varianceName']?.toString() ?? '';
      final String existingUom =
          (existingItem['varianceData']?['variance_Uom']
              ?.toString()
              .toLowerCase() ??
          '');

      // Skip weight items in existing cart
      final bool existingIsWeightItem =
          existingUom.contains('kg') ||
          existingUom.contains('kgs') ||
          existingUom.contains('gm');
      if (existingIsWeightItem) continue;

      if (existingItemCode == newItemCode &&
          existingVarianceName == newVarianceName) {
        return i;
      }
    }
    return -1;
  }

  Map<String, dynamic> _processItemForCart(Map<String, dynamic> item) {
    // Deep clone itemData and varianceData
    final Map<String, dynamic> itemData = item['itemData'] != null
        ? Map<String, dynamic>.from(item['itemData'] as Map)
        : <String, dynamic>{};

    final Map<String, dynamic> varianceData = item['varianceData'] != null
        ? Map<String, dynamic>.from(item['varianceData'] as Map)
        : <String, dynamic>{};

    // CRITICAL: RESTORE TAX — THIS WAS MISSING BEFORE!
    if (itemData['tax'] == null || itemData['tax'] == 0.0) {
      // Try from varianceData
      final taxFromVariance =
          varianceData['tax'] ??
          varianceData['variance_Tax'] ??
          varianceData['itemTax'];
      if (taxFromVariance != null) {
        itemData['tax'] = (taxFromVariance is num)
            ? taxFromVariance.toDouble()
            : double.tryParse(taxFromVariance.toString()) ?? 5.0;
      } else {
        itemData['tax'] = 5.0; // Default Indian GST
      }
    }

    // Ensure itemName exists
    itemData['itemName'] ??=
        varianceData['varianceName'] ?? item['itemName'] ?? 'Unknown Item';

    // Ensure itemCode
    itemData['itemCode'] ??=
        item['itemCode'] ?? varianceData['varianceitemCode'] ?? '';

    return {
      'itemData': itemData, // MUST BE HERE
      'varianceData': varianceData, // MUST BE HERE
      'quantity': (item['quantity'] as num?)?.toDouble() ?? 1.0,
      'weight': (item['weight'] as num?)?.toDouble() ?? 0.0,
      'price':
          (item['price'] as num?)?.toDouble() ??
          (varianceData['variance_Defaultprice'] as num?)?.toDouble() ??
          0.0,
      'amount': item['amount'],
      'uniqueId':
          item['uniqueId'] ??
          '${DateTime.now().millisecondsSinceEpoch}-${itemData['itemCode']}',
    };
  }

  String buildQuantityPriceDisplay(Map<String, dynamic> item) {
    try {
      final String uom =
          (item['varianceData']?['variance_Uom']?.toString().toLowerCase() ??
          '');
      final bool isWeightItem =
          uom.contains('kg') || uom.contains('kgs') || uom.contains('gm');

      if (isWeightItem) {
        double weight =
            (item['weight'] as num?)?.toDouble() ??
            (item['quantity'] as num?)?.toDouble() ??
            0.0;
        double price = (item['varianceData']?['variance_Defaultprice'] ?? 0.0)
            .toDouble();
        String uom = (item['varianceData']?['variance_Uom'] ?? '');
        return '${weight.toStringAsFixed(3)} kg × ₹${price.toStringAsFixed(2)}';
      } else {
        double quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        double price = (item['varianceData']?['variance_Defaultprice'] ?? 0.0)
            .toDouble();
        String uom = (item['varianceData']?['variance_Uom'] ?? '');
        return '${quantity.toStringAsFixed(0)} $uom × ₹${price.toStringAsFixed(2)}';
      }
    } catch (e) {
      print('Error building display: $e for item: $item');
      return 'Error';
    }
  }

  // double calculateItemTotal(Map<String, dynamic> item) {
  //   try {
  //     double price = (item['varianceData']?['variance_Defaultprice'] ?? 0.0)
  //         .toDouble();
  //     double quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
  //     return price * quantity;
  //   } catch (e) {
  //     print('Error calculating item total: $e for item: $item');
  //     return 0.0;
  //   }
  // }

  double calculateItemTotal(Map<String, dynamic> item) {
  try {
    double price = (item['varianceData']?['variance_Defaultprice'] as num?)?.toDouble() ?? 0.0;
    String uom = (item['uom'] as String?)?.toLowerCase() ?? '';

    if (uom == 'kgs' || uom == 'kg') {
      // For weight-based items, use 'weight' field
      double weight = (item['weight'] as num?)?.toDouble() ?? 0.0;
      if (weight <= 0) {
        // Fallback: if weight is missing or zero, avoid returning 0
        return price; // or return 0.0 if you prefer
      }
      return price * weight;
    } else {
      // For quantity-based items (Pcs, Pkt, etc.), use 'quantity'
      double quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      return price * quantity;
    }
  } catch (e) {
    print('Error calculating item total: $e for item: $item');
    return 0.0;
  }
}

  void clearItems() async {
    _currentSaleItems.clear();
    var box = await Hive.openBox('cartBox');
    await box.put('cartItems', []);
    _saleCalculator = SaleCalculator(_currentSaleItems); // Reset SaleCalculator
    notifyListeners(); // Notify listeners after clearing the items
  }

  // void removeItem(int index) async {
  //   if (index >= 0 && index < _currentSaleItems.length) {
  //     if (_currentSaleItems[index]['quantity'] > 1) {
  //       _currentSaleItems[index]['quantity'] -= 1;
  //       _currentSaleItems[index]['totalPrice'] =
  //           _currentSaleItems[index]['quantity'] * (_currentSaleItems[index]['varianceData']['variance_Defaultprice'] ?? 0.0);
  //     } else {
  //       _currentSaleItems.removeAt(index);
  //     }
  //     var box = await Hive.openBox('cartBox');
  //     await box.put('cartItems', _currentSaleItems);
  //     _saleCalculator = SaleCalculator(_currentSaleItems);
  //     notifyListeners();
  //   }
  // }

  void removeItem(int index) async {
    if (index >= 0 && index < _currentSaleItems.length) {
      // Always remove the entire item
      _currentSaleItems.removeAt(index);

      // Persist to Hive
      var box = await Hive.openBox('cartBox');
      await box.put('cartItems', _currentSaleItems);

      // Recalculate totals
      _saleCalculator = SaleCalculator(_currentSaleItems);
      notifyListeners();
    }
  }

  double calculateTotal() {
    return _saleCalculator.calculateTotal();
  }

  double calculateDiscountAmount() {
    return _saleCalculator.calculateDiscountAmount();
  }

  // String buildQuantityPriceDisplay(Map<String, dynamic> item) {
  //   return _saleCalculator.buildQuantityPriceDisplay(item);
  // }

  // In your CurrentSaleProvider class

  Future<void> saveBillWithTitle(
    BuildContext context,
    String ticketTitle,
  ) async {
    if (currentSaleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No items to save!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      var box = await Hive.openBox('cartBox');

      Map<String, dynamic> billData = {
        'holdId': DateTime.now().millisecondsSinceEpoch.toString(),
        'items': currentSaleItems
            .map((item) => _prepareItemForStorage(item))
            .toList(),
        'total': calculateTotal(),
        'date': DateTime.now().toIso8601String(),
        'status': 'hold',
        'ticketName': ticketTitle,
      };

      await box.add(billData);

      // Clear current items after saving
      clearItems();
    } catch (e) {
      print('Error saving bill: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving bill: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Map<String, dynamic> _prepareItemForStorage(Map<String, dynamic> item) {
    return {
      ...item,
      'varianceData': Map<String, dynamic>.from(item['varianceData'] ?? {}),
    };
  }

  void saveBillsplitBill(
    BuildContext context,
    List<List<Map<String, dynamic>>> tickets,
    List<String> ticketTitles,
  ) async {
    try {
      var box = await Hive.openBox('cartBox');

      for (int i = 0; i < tickets.length; i++) {
        if (tickets[i].isNotEmpty) {
          Map<String, dynamic> billData = {
            'holdId': '${DateTime.now().millisecondsSinceEpoch}-$i',
            'items': tickets[i]
                .map((item) => _prepareItemForStorage(item))
                .toList(),
            'total': _calculateTicketTotal(tickets[i]),
            'date': DateTime.now().toIso8601String(),
            'status': 'hold',
            'ticketName': ticketTitles[i],
          };

          await box.add(billData);
        }
      }

      // Clear cart items after splitting
      clearItems();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tickets.length} tickets saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error saving split bills: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving tickets: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  double _calculateTicketTotal(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, item) {
      double price = (item['varianceData']?['variance_Defaultprice'] ?? 0.0)
          .toDouble();
      double quantity = (item['quantity'] ?? 0).toDouble();
      return sum + (price * quantity);
    });
  }

  // String buildQuantityPriceDisplay(Map<String, dynamic> item) {
  //   final String uom = item['varianceData']['variance_Uom'].toLowerCase();
  //   final double price = item['varianceData']['variance_Defaultprice']
  //       .toDouble(); // Ensure price is a double
  //   final double quantity =
  //       (item['quantity'] ?? 1).toDouble(); // Ensure quantity is a double

  //   String quantityDisplay = '';
  //   String weightQuantityDidpay = '';
  //   // Check if the unit of measure is in kilograms or grams
  //   if (uom == 'kg' || uom == 'kgs') {
  //     if (quantity >= 1) {
  //       quantityDisplay = '${quantity.toStringAsFixed(1)} kg'; // Display in kg
  //     } else {
  //       // If quantity is less than 1 kg, convert to grams
  //       double grams = quantity * 1000;
  //       quantityDisplay = '${grams.toStringAsFixed(1)} g'; // Display in grams
  //     }
  //   } else {
  //     // For other units, assume the quantity is in pieces or count
  //     quantityDisplay = '${quantity.toInt()} $uom';
  //   }

  //   // Print the result in the console
  //   print(s
  //       'Quantity: $quantityDisplay x ₹ ${price.toStringAsFixed(2)} per $uom');
  //   print('Quantity: $quantityDisplay');

  //   // Return the formatted string for UI or other purposes
  //   return '$quantityDisplay';
  // }

  // double calculateItemTotal(Map<String, dynamic> item) {
  //   return _saleCalculator.calculateItemTotal(item);
  // }

  // void updateItemQuantity(int index, dynamic newValue) async {
  //   if (index >= 0 && index < _currentSaleItems.length) {
  //     final item = _currentSaleItems[index];
  //     String? uom = item['varianceData']['variance_Uom'];
  //     double price = item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0;
  //     double newValueDouble = newValue.toDouble(); // Convert newValue to double

  //     if (uom == 'Kgs' || uom == 'Kg') {
  //       // Update weight for Kgs/Kg UOM
  //       item['weight'] = newValueDouble;
  //       item['quantity'] = newValueDouble; // Sync quantity with weight for consistency (optional)
  //       item['total'] = (price * newValueDouble); // Recalculate total based on weight
  //     } else {
  //       // Update quantity for Pcs/Pkt UOM
  //       item['quantity'] = newValueDouble;
  //       item['weight'] = null; // Clear weight if not applicable
  //       item['total'] = (price * newValueDouble); // Recalculate total based on quantity
  //     }

  //     // Update SaleCalculator with the new items
  //     _saleCalculator = SaleCalculator(_currentSaleItems);

  //     // Save to Hive
  //     var box = await Hive.openBox('cartBox');
  //     await box.put('cartItems', _currentSaleItems);

  //     // Notify listeners to update the UI
  //     notifyListeners();
  //   }
  // }

  void updateItemQuantity(int index, dynamic newValue) async {
    if (index < 0 || index >= _currentSaleItems.length) return;

    final item = _currentSaleItems[index];
    final double price =
        (item['varianceData']['variance_Defaultprice'] as num?)?.toDouble() ??
        0.0;
    final double qty = (newValue is num) ? newValue.toDouble() : 1.0;

    item['quantity'] = qty;
    item['totalPrice'] = price * qty;

    if (item['varianceData']['variance_Uom']?.toString().toLowerCase() ==
        'kgs') {
      item['weight'] = qty;
    } else {
      item['weight'] = null;
    }

    _saleCalculator = SaleCalculator(_currentSaleItems);
    final box = await Hive.openBox('cartBox');
    await box.put('cartItems', _currentSaleItems);
    notifyListeners();
  }

  Future<void> saveBill(BuildContext context) async {
    if (_currentSaleItems.isEmpty) {
      _showSnackBar(context, 'No items to save!', Colors.red);
      return;
    }

    var box = await Hive.openBox('cartBox');
    List<Map<String, dynamic>> itemsWithStatus = _currentSaleItems
        .map((item) => {...item, 'status': 'hold'})
        .toList();

    var randomId = generatetheholdrandomId();

    Map<String, dynamic> billData = {
      'holdId': randomId,
      'date': DateTime.now().toIso8601String(),
      'items': itemsWithStatus,
      'total': calculateTotal(),
      'status': 'hold',
    };
    // Map<String, dynamic> billDataforhive = {
    //   'holdId': randomId,
    //   'date': DateTime.now().toIso8601String(),
    //   'items': itemsWithStatus,
    //   'total': calculateTotal(),
    //   'status': 'hold',
    // };

    // Print the data to console
    // print("Bill Data for Hive: $billDataforhive");

    // Transform `itemsWithStatus` into API-compatible format
    // ignore: unused_local_variable
    Map<String, dynamic> hivedatpostsapledata = {
      "holdId": randomId.toString(),
      "itemId": itemsWithStatus
          .map((item) => item['itemData']['itemId'] ?? "")
          .toList(),
      "itemCode": itemsWithStatus
          .map((item) => item['varianceData']['varianceitemCode'] ?? "")
          .toList(),
      "itemName": itemsWithStatus
          .map((item) => item['itemData']['itemName'] ?? "")
          .toList(),
      "weight": itemsWithStatus
          .map((item) => item['varianceData']['variance_Uom'] ?? "")
          .toList(),
      "price": itemsWithStatus
          .map(
            (item) => item['varianceData']['variance_Defaultprice'].toString(),
          )
          .toList(),
      "category": itemsWithStatus
          .map((item) => item['itemData']['category'] ?? "")
          .toList(),
      "qty": itemsWithStatus
          .map((item) => item['quantity'].toString())
          .toList(),
      "amount": itemsWithStatus
          .map((item) => calculateItemTotal(item).toString())
          .toList(),
      "tax": itemsWithStatus
          .map((item) => item['itemData']['tax'].toString())
          .toList(),
      "uom": itemsWithStatus
          .map((item) => item['itemData']['item_Uom'] ?? "")
          .toList(),
      "totalAmount": calculateTotal().toString(),
      "totalAmount2": "0",
      "totalAmount3": "0",
      "status": "hold",
      "branchId": "0",
      "branch": "string",
      "discountPercentage": "0",
      "discountAmount": "0",
      "employeeName": "",
      "phoneNumber": "0",
      "phoneNumber2": "",
      "customCharge": "0",
      "netPrice": calculateTotal().toString(),
      "invoiceNo": "0",
      "date": DateTime.now().toIso8601String(),
      "time": DateTime.now().toIso8601String(),
      "paymentType": "",
      "salesType": "",
      "salesReturn": "",
      "salesReturnNumber": "0",
      "type": "",
      "salesOrderNumber": "",
      "customerName": "",
      "deliveryDate": "",
      "deliveryTime": "",
      "event": "",
      "advance": "",
      "orderPreference": "",
      "deliveryPreference": "",
      "orderDate": "",
      "orderTime": "",
      "remark": "",
      "orderInvoiceNo": "",
      "invoiceDate": "",
      "cash": "",
      "upi": "",
      "card": "",
      "deliveryPartner": "",
      "otherPayment": "",
      "deliveryPartnerName": "",
      "shiftNumber": "",
      "shiftId": "",
      "deliveryLocation": "",
      "preinvoiceId": "",
      "ticketType": "",
      "ticketName": "",
    };

    // Post the bill data to the FastAPI endpoint
    // try {
    //   final url = Uri.parse('http://192.168.1.114:8888/fastapi/holds/');
    //   final response = await http.post(
    //     url,
    //     headers: {'Content-Type': 'application/json'},
    //     body: jsonEncode(hivedatpostsapledata),
    //   );

    //   if (response.statusCode == 200 || response.statusCode == 201) {
    //     // Show success message
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(
    //           'Bill saved as hold (Hold ID: $randomId)',
    //           style: TextStyle(fontWeight: FontWeight.bold),
    //         ),
    //         backgroundColor: Colors.green,
    //         duration: const Duration(seconds: 2),
    //         behavior: SnackBarBehavior.floating,
    //         margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
    //         shape: RoundedRectangleBorder(
    //           borderRadius: BorderRadius.circular(10),
    //         ),
    //       ),
    //     );
    //   } else {
    //     // Handle server errors
    //     print('Failed to post data to server: ${response.statusCode}');
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(
    //           'Failed to post data to server: ${response.statusCode}',
    //           style: TextStyle(fontWeight: FontWeight.bold),
    //         ),
    //         backgroundColor: Colors.red,
    //         duration: Duration(seconds: 2),
    //       ),
    //     );
    //   }
    // } catch (error) {
    //   // Handle network errors
    //   print('Network error: $error');
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text(
    //         'Network error: $error',
    //         style: TextStyle(fontWeight: FontWeight.bold),
    //       ),
    //       backgroundColor: Colors.red,
    //       duration: Duration(seconds: 2),
    //     ),
    //   );
    // }

    await box.add(billData);
    _showSnackBar(
      context,
      'Bill saved as hold (Hold ID: $randomId)',
      Colors.green,
    );
    clearItems();
  }

  Future<void> removeHold(int index) async {
    var box = await Hive.openBox('cartBox');
    await box.deleteAt(index);
    notifyListeners();
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Future<void> saveBillsplitBill(
  //   BuildContext context,
  //   List<List<Map<String, dynamic>>> tickets,
  //   List<String> ticketTitles,
  // ) async {
  //   if (tickets.isEmpty || tickets.every((ticket) => ticket.isEmpty)) {
  //     _showSnackBar(context, 'No items to save!', Colors.red);
  //     return;
  //   }

  //   var box = await Hive.openBox('cartBox');

  //   for (int i = 0; i < tickets.length; i++) {
  //     // 🔹 Prepare Items for Hive Storage
  //     List<Map<String, dynamic>> itemsWithStatus = tickets[i].map((item) => {...item, 'status': 'hold'}).toList();

  //     // 🔹 Generate unique Hold ID
  //     var randomId = generatetheholdrandomId();
  //     String ticketName = ticketTitles[i]; // Ticket name
  //     String ticketType = "SplitBill"; // Default type

  //     double ticketTotal = SaleCalculator(itemsWithStatus).calculateTotal();

  //     // 🔹 Prepare Data for Hive
  //     Map<String, dynamic> billData = {
  //       'holdId': randomId,
  //       'date': DateTime.now().toIso8601String(),
  //       'items': itemsWithStatus,
  //       'total': ticketTotal, // Calculate per ticket total
  //       'status': 'hold',
  //       "ticketType": ticketType,
  //       "ticketName": ticketName,
  //     };

  //     // ✅ Save in Hive
  //     await box.add(billData);

  //     // 🔹 Prepare Data for API
  //     // ignore: unused_local_variable
  //     Map<String, dynamic> apiData = {
  //       "holdId": randomId.toString(),
  //       "itemId": itemsWithStatus.map((item) => item['itemData']['itemId'] ?? "").toList(),
  //       "itemCode": itemsWithStatus.map((item) => item['varianceData']['varianceitemCode'] ?? "").toList(),
  //       "itemName": itemsWithStatus.map((item) => item['varianceData']['varianceName'] ?? "").toList(),
  //       "weight": itemsWithStatus.map((item) => item['varianceData']['variance_Uom'] ?? "").toList(),
  //       "price": itemsWithStatus.map((item) => item['varianceData']['variance_Defaultprice'].toString()).toList(),
  //       "category": itemsWithStatus.map((item) => item['itemData']['category'] ?? "").toList(),
  //       "qty": itemsWithStatus.map((item) => item['quantity'].toString()).toList(),
  //       "amount": itemsWithStatus.map((item) => calculateItemTotal(item).toString()).toList(),
  //       "tax": itemsWithStatus.map((item) => item['itemData']['tax'].toString()).toList(),
  //       "uom": itemsWithStatus.map((item) => item['itemData']['item_Uom'] ?? "").toList(),
  //       "totalAmount": ticketTotal,
  //       "status": "hold",
  //       "ticketType": ticketType,
  //       "ticketName": ticketName,
  //       "date": DateTime.now().toIso8601String(),
  //       "time": DateTime.now().toIso8601String(),
  //       "netPrice": calculateTotal2(itemsWithStatus).toString(),
  //       "discountPercentage": "0",
  //       "discountAmount": "0",
  //       "customCharge": "0",
  //       "employeeName": "",
  //       "phoneNumber": "0",
  //       "paymentType": "",
  //     };

  //     // ✅ Post Data to API
  //     // try {
  //     //   final url = Uri.parse('http://192.168.1.114:8888/fastapi/holds/');
  //     //   final response = await http.post(
  //     //     url,
  //     //     headers: {'Content-Type': 'application/json'},
  //     //     body: jsonEncode(apiData),
  //     //   );

  //     //   if (response.statusCode == 200 || response.statusCode == 201) {
  //     //     print(
  //     //         "✅ API Success: Ticket $ticketName saved with Hold ID $randomId");
  //     //     ScaffoldMessenger.of(context).showSnackBar(
  //     //       SnackBar(
  //     //         content: Text("Ticket $ticketName saved successfully."),
  //     //         backgroundColor: Colors.green,
  //     //       ),
  //     //     );
  //     //   } else {
  //     //     print("❌ API Error: ${response.statusCode}");
  //     //   }
  //     // } catch (error) {
  //     //   print("❌ Network Error: $error");
  //     // }
  //   }

  //   // ✅ Clear current items after saving split bills
  //   clearItems();
  // }

  int generatetheholdrandomId() {
    return 10 + (Random().nextInt(90)); // 90 ensures the range is 10 to 99
  }

  double calculateTotal2(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, item) {
      double price = (item['varianceData']?['variance_Defaultprice'] ?? 0.0)
          .toDouble(); // Get price safely
      int quantity = (item['quantity'] ?? 0).toInt(); // Get quantity safely
      return sum + (price * quantity);
    });
  }

  // double calculateTotal2(List<Map<String, dynamic>> items) {
  //   return items.fold(
  //       0.0,
  //       (sum, item) =>
  //           sum + (item['variance_Defaultprice'] * item['quantity']));
  // }

  // Future<void> saveBill(BuildContext context) async {
  //   if (_currentSaleItems.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: const Text(
  //           'No items to save!',
  //           style: TextStyle(fontWeight: FontWeight.bold),
  //         ),
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 2),
  //         behavior: SnackBarBehavior.floating,
  //         margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //       ),
  //     );
  //     return;
  //   }

  //   // Open the Hive box for invoices
  //   var holdinvoiceBox = await Hive.openBox('cartBox');

  //   // Set the status for each item to 'hold'
  //   List<Map<String, dynamic>> itemsWithStatus =
  //       _currentSaleItems.map((item) => {...item, 'status': 'hold'}).toList();
  //   print("HO${itemsWithStatus}");
  //   // Generate a unique hold bill ID
  //   var randomId = generatetheholdrandomId();

  //   // Prepare the bill data for Hive and API
  //   Map<String, dynamic> billDataforhive = {
  //     'holdId': randomId,
  //     'date': DateTime.now().toIso8601String(),
  //     'items': itemsWithStatus,
  //     'total': calculateTotal(),
  //     'status': 'hold',
  //   };
  //   Map<String, dynamic> hivedatpostsapledata = {
  //     "itemId": ["string"],
  //     "itemName": ["string"],
  //     "itemCode": ["string"],
  //     "weight": ["string"],
  //     "price": ["string"],
  //     "category": ["string"],
  //     "qty": ["string"],
  //     "amount": ["string"],
  //     "tax": ["string"],
  //     "uom": ["string"],
  //     "totalAmount": 0,
  //     "totalAmount2": 0,
  //     "totalAmount3": 0,
  //     "status": "string",
  //     "branchId": 0,
  //     "branch": "string",
  //     "discountPercentage": 0,
  //     "discountAmount": 0,
  //     "employeeName": "string",
  //     "phoneNumber": 0,
  //     "customCharge": 0,
  //     "netPrice": 0,
  //     "invoiceNo": 0,
  //     "date": DateTime.now().toIso8601String(),
  //     "time": DateTime.now().toIso8601String(),
  //     "paymentType": "string",
  //     "salesType": "string",
  //     "salesReturn": "string",
  //     "salesReturnNumber": 0,
  //     "type": "string",
  //     "salesOrderNumber": "string",
  //     "customerName": "string",
  //     "deliveryDate": "string",
  //     "deliveryTime": "string",
  //     "event": "string",
  //     "advance": "string",
  //     "orderPreference": "string",
  //     "deliveryPreference": "string",
  //     "orderDate": "string",
  //     "orderTime": "string",
  //     "remark": "string",
  //     "orderInvoiceNo": "string",
  //     "invoiceDate": "string",
  //     "cash": "string",
  //     "upi": "string",
  //     "card": "string",
  //     "deliveryPartner": "string",
  //     "otherPayment": "string",
  //     "deliveryPartnerName": "string",
  //     "shiftNumber": "string",
  //     "shiftId": "string",
  //     "deliveryLocation": "string",
  //     "phoneNumber2": "string",
  //     "preinvoiceId": "string"
  //   };
  //   // Save the bill to Hive
  //   await holdinvoiceBox.add(billDataforhive);

  //   // Post the bill data to the FastAPI endpoint
  //   try {
  //     final url = Uri.parse('http://192.168.1.114:8888/fastapi/holds/');
  //     final response = await http.post(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode(hivedatpostsapledata),
  //     );

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       // Show success message
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             'Bill saved as hold (Hold ID: $randomId)',
  //             style: TextStyle(fontWeight: FontWeight.bold),
  //           ),
  //           backgroundColor: Colors.green,
  //           duration: const Duration(seconds: 2),
  //           behavior: SnackBarBehavior.floating,
  //           margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(10),
  //           ),
  //         ),
  //       );
  //     } else {
  //       // Handle server errors
  //       print('Failed to post data to server: ${response.statusCode}');
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             'Failed to post data to server: ${response.statusCode}',
  //             style: TextStyle(fontWeight: FontWeight.bold),
  //           ),
  //           backgroundColor: Colors.red,
  //           duration: Duration(seconds: 2),
  //         ),
  //       );
  //     }
  //   } catch (error) {
  //     // Handle network errors
  //     print('Network error: $error');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           'Network error: $error',
  //           style: TextStyle(fontWeight: FontWeight.bold),
  //         ),
  //         backgroundColor: Colors.red,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //   }
  //   clearItems();
  // }
}
//     // Clear items after saving
//     // clearItems();

// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'isolation/sales_caculate.dart';

// class CurrentSaleProvider with ChangeNotifier {
//   late SaleCalculator _saleCalculator = SaleCalculator([]);
//   List<Map<String, dynamic>> _currentSaleItems = [];
//   double _discountPercentage = 0.0;
//   double _customCharge = 0.0;
//   double sgst = 0.0;
//   double cgst = 0.0;
//   double sgstRate = 0.0;
//   double cgstRate = 0.0;
//   String _selectedOption = 'TakeAway';
//   String _status = '';
//   String? _holdBillId;
//   String? _currentHoldId;

//   List<Map<String, dynamic>> get currentSaleItems => _currentSaleItems;
//   double get discountPercentage => _discountPercentage;
//   double get customCharge => _customCharge;
//   double get sgstAmount => sgst;
//   double get cgstAmount => cgst;
//   double get sgstRatePercentage => sgstRate;
//   double get cgstRatePercentage => cgstRate;
//   String get selectedOption => _selectedOption;
//   String get saleStatus => _status;
//   String? get holdBillId => _holdBillId;
//   String? get currentHoldId => _currentHoldId;

//   set discountPercentage(double value) {
//     _discountPercentage = value;
//     _saleCalculator.discountPercentage = value;
//     notifyListeners();
//   }

//   set customCharge(double value) {
//     _customCharge = value;
//     _saleCalculator.customCharge = value;
//     notifyListeners();
//   }

//   void setCurrentHoldId(String? id) {
//     _currentHoldId = id;
//     notifyListeners();
//   }

//   void setHoldBillId(String id) {
//     _holdBillId = id;
//     notifyListeners();
//   }

//   void selectOption(String option) {
//     _selectedOption = option;
//     _status = '';
//     notifyListeners();
//   }

//   CurrentSaleProvider() {
//     loadCartItems();
//   }

//   void addItemToCart(Map<String, dynamic> newItem) async {
//     Map<String, dynamic> itemData = newItem['itemData'] ??
//         {
//           'itemId': newItem['itemId'] ?? newItem['itemCode'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
//           'itemName': newItem['itemName'] ?? newItem['varianceData']?['varianceName'] ?? 'Unknown Item',
//           'itemCode': newItem['itemCode'] ?? newItem['varianceData']?['varianceName'] ?? '',
//           'tax': newItem['tax']?.toDouble() ?? 0.0,
//           'item_Uom': newItem['uom'] ?? 'Pcs',
//           'category': newItem['category'] ?? 'Unknown',
//         };

//     Map<String, dynamic> varianceData = newItem['varianceData'] ??
//         {
//           'varianceName': newItem['varianceName'] ?? 'Unknown Variance',
//           'variance_Defaultprice': newItem['variance_Defaultprice']?.toDouble() ?? 0.0,
//           'variance_Uom': newItem['uom'] ?? 'Pcs',
//           'variancetax': newItem['tax']?.toDouble() ?? 0.0,
//           'varianceItemCode': newItem['itemCode'] ?? newItem['varianceName'] ?? '',
//         };

//     // Get quantity and weight from the newItem
//     int quantity = int.tryParse(newItem['quantity']?.toString() ?? '1') ?? 1;
//     double weight = double.tryParse(newItem['weight']?.toString() ?? '0.0') ?? 0.0;
//     double price = double.tryParse(varianceData['variance_Defaultprice']?.toString() ?? '0.0') ?? 0.0;

//     // For weight items, quantity should be 1 and use weight for calculation
//     bool isWeightItem =
//         (varianceData['variance_Uom']?.toLowerCase() == 'kgs' || varianceData['variance_Uom']?.toLowerCase() == 'kg');

//     double totalPrice = isWeightItem ? weight * price : quantity * price;

//     print('DEBUG: addItemToCart - UOM: ${varianceData['variance_Uom']}, IsWeightItem: $isWeightItem');
//     print('DEBUG: addItemToCart - Quantity: $quantity, Weight: $weight, Price: $price, TotalPrice: $totalPrice');

//     Map<String, dynamic> normalizedItem = {
//       ...newItem,
//       'itemData': itemData,
//       'varianceData': varianceData,
//       'quantity': isWeightItem ? 1 : quantity, // For weight items, quantity is always 1
//       'weight': weight,
//       'totalPrice': totalPrice,
//       'itemName': itemData['itemName'],
//       'itemCode': itemData['itemCode'],
//       'tax': itemData['tax'],
//       'uom': varianceData['variance_Uom'],
//     };

//     // Check if item already exists
//     bool exists = isWeightItem
//         ? _currentSaleItems.any((item) =>
//             item['itemData']['itemId'] == itemData['itemId'] &&
//             item['varianceData']['varianceName'] == varianceData['varianceName'] &&
//             item['weight'] == weight) // For weight items, check exact weight match
//         : _currentSaleItems.any((item) =>
//             item['itemData']['itemId'] == itemData['itemId'] &&
//             item['varianceData']['varianceName'] == varianceData['varianceName']);

//     print('DEBUG: addItemToCart - Item exists: $exists');

//     if (exists && !isWeightItem) {
//       // For non-weight items, update quantity
//       _currentSaleItems = _currentSaleItems.map((item) {
//         if (item['itemData']['itemId'] == itemData['itemId'] &&
//             item['varianceData']['varianceName'] == varianceData['varianceName']) {
//           item['quantity'] = ((item['quantity'] as num?)?.toInt() ?? 0) + quantity;
//           item['totalPrice'] = item['quantity'] * (item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
//           print('DEBUG: addItemToCart - Updated existing item: $item');
//         }
//         return item;
//       }).toList();
//     } else if (exists && isWeightItem) {
//       // For weight items, we don't merge - add as separate entry with different weight
//       _currentSaleItems.insert(0, normalizedItem);
//       print('DEBUG: addItemToCart - Added new weight item: $normalizedItem');
//     } else {
//       // New item
//       _currentSaleItems.insert(0, normalizedItem);
//       print('DEBUG: addItemToCart - Added new item: $normalizedItem');
//     }

//     print('DEBUG: addItemToCart - Current Sale Items: $_currentSaleItems');

//     _saleCalculator = SaleCalculator(_currentSaleItems);
//     var box = await Hive.openBox('cartBox');
//     await box.put('cartItems', _currentSaleItems);
//     notifyListeners();
//   }

//   // Also update the express mode method similarly
//   void addItemToCartExpressMode(Map<String, dynamic> newItem) async {
//     Map<String, dynamic> itemData = newItem['itemData'] ??
//         {
//           'itemId': newItem['itemId'] ?? newItem['itemCode'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
//           'itemName': newItem['itemName'] ?? newItem['varianceData']?['varianceName'] ?? 'Unknown Item',
//           'itemCode': newItem['itemCode'] ?? newItem['varianceData']?['varianceName'] ?? '',
//           'tax': newItem['tax']?.toDouble() ?? 0.0,
//           'item_Uom': newItem['uom'] ?? 'Pcs',
//           'category': newItem['category'] ?? 'Unknown',
//         };

//     Map<String, dynamic> varianceData = newItem['varianceData'] ??
//         {
//           'varianceName': newItem['varianceName'] ?? 'Unknown Variance',
//           'variance_Defaultprice': newItem['variance_Defaultprice']?.toDouble() ?? 0.0,
//           'variance_Uom': newItem['uom'] ?? 'Pcs',
//           'variancetax': newItem['tax']?.toDouble() ?? 0.0,
//           'varianceItemCode': newItem['itemCode'] ?? newItem['varianceName'] ?? '',
//         };

//     int quantity = int.tryParse(newItem['quantity']?.toString() ?? '1') ?? 1;
//     double weight = double.tryParse(newItem['weight']?.toString() ?? '0.0') ?? 0.0;
//     double price = double.tryParse(varianceData['variance_Defaultprice']?.toString() ?? '0.0') ?? 0.0;

//     bool isWeightItem =
//         (varianceData['variance_Uom']?.toLowerCase() == 'kgs' || varianceData['variance_Uom']?.toLowerCase() == 'kg');

//     double totalPrice = isWeightItem ? weight * price : quantity * price;

//     Map<String, dynamic> normalizedItem = {
//       ...newItem,
//       'itemData': itemData,
//       'varianceData': varianceData,
//       'quantity': isWeightItem ? 1 : quantity, // For weight items, quantity is always 1
//       'weight': weight,
//       'totalPrice': totalPrice,
//       'itemName': itemData['itemName'],
//       'itemCode': itemData['itemCode'],
//       'tax': itemData['tax'],
//       'uom': varianceData['variance_Uom'],
//     };

//     bool exists = isWeightItem
//         ? _currentSaleItems.any((item) =>
//             item['itemData']['itemId'] == itemData['itemId'] &&
//             item['varianceData']['varianceName'] == varianceData['varianceName'] &&
//             item['weight'] == weight)
//         : _currentSaleItems.any((item) =>
//             item['itemData']['itemId'] == itemData['itemId'] &&
//             item['varianceData']['varianceName'] == varianceData['varianceName']);

//     if (exists && !isWeightItem) {
//       _currentSaleItems = _currentSaleItems.map((item) {
//         if (item['itemData']['itemId'] == itemData['itemId'] &&
//             item['varianceData']['varianceName'] == varianceData['varianceName']) {
//           item['quantity'] += quantity;
//           item['totalPrice'] = item['quantity'] * (item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
//         }
//         return item;
//       }).toList();
//     } else {
//       _currentSaleItems.insert(0, normalizedItem);
//     }

//     print('DEBUG: addItemToCartExpressMode - Current Sale Items: $_currentSaleItems');

//     _saleCalculator = SaleCalculator(_currentSaleItems);
//     var box = await Hive.openBox('cartBox');
//     await box.put('cartItems', _currentSaleItems);
//     notifyListeners();
//   }

//   // Update the updateItemQuantity method to handle weight items properly
//   void updateItemQuantity(int index, dynamic newValue) async {
//     if (index >= 0 && index < _currentSaleItems.length) {
//       String uom = _currentSaleItems[index]['varianceData']['variance_Uom']?.toLowerCase() ?? 'pcs';
//       bool isWeightItem = (uom == 'kgs' || uom == 'kg');

//       print('DEBUG: updateItemQuantity - Index: $index, New Value: $newValue, UOM: $uom, IsWeightItem: $isWeightItem');

//       if (isWeightItem) {
//         // For weight items, update weight and keep quantity as 1
//         double weight = double.tryParse(newValue.toString()) ?? 0.0;
//         _currentSaleItems[index]['weight'] = weight;
//         _currentSaleItems[index]['quantity'] = 1; // Always 1 for weight items
//         _currentSaleItems[index]['totalPrice'] =
//             weight * (_currentSaleItems[index]['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
//       } else {
//         // For quantity items, update quantity
//         int quantity = int.tryParse(newValue.toString()) ?? 1;
//         _currentSaleItems[index]['quantity'] = quantity;
//         _currentSaleItems[index]['totalPrice'] =
//             quantity * (_currentSaleItems[index]['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
//       }
//       print('DEBUG: updateItemQuantity - Updated item: ${_currentSaleItems[index]}');

//       var box = await Hive.openBox('cartBox');
//       await box.put('cartItems', _currentSaleItems);
//       _saleCalculator = SaleCalculator(_currentSaleItems);
//       notifyListeners();
//     }
//   }

//   Future<void> addItemsToCurrentSale(List<Map<String, dynamic>> newItems) async {
//     for (var newItem in newItems) {
//       Map<String, dynamic> itemData = newItem['itemData'] ??
//           {
//             'itemId': newItem['itemId'] ?? newItem['itemCode'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
//             'itemName': newItem['itemName'] ?? newItem['varianceData']?['varianceName'] ?? 'Unknown Item',
//             'itemCode': newItem['itemCode'] ?? newItem['varianceData']?['varianceName'] ?? '',
//             'tax': newItem['tax']?.toDouble() ?? 0.0,
//             'item_Uom': newItem['uom'] ?? 'Pcs',
//             'category': newItem['category'] ?? 'Unknown',
//           };

//       Map<String, dynamic> varianceData = newItem['varianceData'] ??
//           {
//             'varianceName': newItem['varianceName'] ?? 'Unknown Variance',
//             'variance_Defaultprice': newItem['variance_Defaultprice']?.toDouble() ?? 0.0,
//             'variance_Uom': newItem['uom'] ?? 'Pcs',
//             'variancetax': newItem['tax']?.toDouble() ?? 0.0,
//             'varianceItemCode': newItem['itemCode'] ?? newItem['varianceName'] ?? '',
//           };

//       int quantity = int.tryParse(newItem['quantity']?.toString() ?? '1') ?? 1;
//       double weight = double.tryParse(newItem['weight']?.toString() ?? '0.0') ?? 0.0;
//       double price = double.tryParse(varianceData['variance_Defaultprice']?.toString() ?? '0.0') ?? 0.0;
//       double totalPrice =
//           (varianceData['variance_Uom']?.toLowerCase() == 'kgs' || varianceData['variance_Uom']?.toLowerCase() == 'kg')
//               ? weight * price
//               : quantity * price;

//       Map<String, dynamic> normalizedItem = {
//         ...newItem,
//         'itemData': itemData,
//         'varianceData': varianceData,
//         'quantity': quantity,
//         'weight': weight,
//         'totalPrice': totalPrice,
//         'itemName': itemData['itemName'],
//         'itemCode': itemData['itemCode'],
//         'tax': itemData['tax'],
//         'uom': varianceData['variance_Uom'],
//       };

//       bool exists = (varianceData['variance_Uom']?.toLowerCase() == 'kgs' || varianceData['variance_Uom']?.toLowerCase() == 'kg')
//           ? _currentSaleItems.any((item) =>
//               item['itemData']['itemId'] == itemData['itemId'] &&
//               item['varianceData']['varianceName'] == varianceData['varianceName'] &&
//               item['weight'] == weight)
//           : _currentSaleItems.any((item) =>
//               item['itemData']['itemId'] == itemData['itemId'] &&
//               item['varianceData']['varianceName'] == varianceData['varianceName']);

//       if (exists &&
//           (varianceData['variance_Uom']?.toLowerCase() != 'kgs' && varianceData['variance_Uom']?.toLowerCase() != 'kg')) {
//         _currentSaleItems = _currentSaleItems.map((item) {
//           if (item['itemData']['itemId'] == itemData['itemId'] &&
//               item['varianceData']['varianceName'] == varianceData['varianceName']) {
//             item['quantity'] += quantity;
//             item['totalPrice'] = item['quantity'] * (item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
//           }
//           return item;
//         }).toList();
//       } else {
//         _currentSaleItems.add(normalizedItem);
//       }
//     }

//     print('DEBUG: addItemsToCurrentSale - Current Sale Items: $_currentSaleItems');

//     _saleCalculator = SaleCalculator(_currentSaleItems);
//     var box = await Hive.openBox('cartBox');
//     await box.put('cartItems', _currentSaleItems);
//     notifyListeners();
//   }

//   Future<void> loadCartItems() async {
//     var box = await Hive.openBox('cartBox');
//     List<dynamic> rawItems = box.get('cartItems', defaultValue: []);
//     _currentSaleItems = rawItems
//         .map((item) {
//           final map = Map<String, dynamic>.from(item);
//           map['itemData'] = map['itemData'] ??
//               {
//                 'itemId': map['itemId'] ?? map['itemCode'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
//                 'itemName': map['itemName'] ?? map['varianceData']?['varianceName'] ?? 'Unknown Item',
//                 'itemCode': map['itemCode'] ?? map['varianceData']?['varianceName'] ?? '',
//                 'tax': map['tax']?.toDouble() ?? 0.0,
//                 'item_Uom': map['uom'] ?? 'Pcs',
//                 'category': map['category'] ?? 'Unknown',
//               };
//           map['varianceData'] = map['varianceData'] ??
//               {
//                 'varianceName': map['varianceName'] ?? 'Unknown Variance',
//                 'variance_Defaultprice': map['variance_Defaultprice']?.toDouble() ?? 0.0,
//                 'variance_Uom': map['uom'] ?? 'Pcs',
//                 'variancetax': map['tax']?.toDouble() ?? 0.0,
//                 'varianceItemCode': map['itemCode'] ?? map['varianceName'] ?? '',
//               };
//           map['quantity'] = int.tryParse(map['quantity']?.toString() ?? '1') ?? 1;
//           map['weight'] = double.tryParse(map['weight']?.toString() ?? '0.0') ?? 0.0;
//           map['totalPrice'] = double.tryParse(map['totalPrice']?.toString() ?? '0.0') ??
//               ((map['varianceData']['variance_Uom']?.toLowerCase() == 'kgs' ||
//                       map['varianceData']['variance_Uom']?.toLowerCase() == 'kg')
//                   ? map['weight'] * (map['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0)
//                   : map['quantity'] * (map['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0));
//           map['itemName'] = map['itemData']['itemName'];
//           map['itemCode'] = map['itemData']['itemCode'];
//           map['tax'] = map['itemData']['tax'];
//           map['uom'] = map['varianceData']['variance_Uom'];
//           return map;
//         })
//         .where((item) => item['quantity'] > 0 || item['weight'] > 0)
//         .toList();
//     _saleCalculator = SaleCalculator(_currentSaleItems);
//     print('DEBUG: loadCartItems - Loaded Items: $_currentSaleItems');
//     notifyListeners();
//   }

//   void loadItemsFromBill(List<dynamic>? items, {bool merge = false, String? holdId}) {
//     if (items == null || items.isEmpty) {
//       return;
//     }

//     if (!merge) {
//       _currentSaleItems.clear();
//     }

//     for (var newItem in items) {
//       if (newItem == null || !newItem.containsKey('itemData') || !newItem.containsKey('varianceData')) {
//         continue;
//       }

//       Map<String, dynamic> itemData = newItem['itemData'];
//       Map<String, dynamic> varianceData = newItem['varianceData'];
//       int quantity = int.tryParse(newItem['quantity']?.toString() ?? '1') ?? 1;
//       double weight = double.tryParse(newItem['weight']?.toString() ?? '0.0') ?? 0.0;
//       double price = double.tryParse(varianceData['variance_Defaultprice']?.toString() ?? '0.0') ?? 0.0;
//       double totalPrice =
//           (varianceData['variance_Uom']?.toLowerCase() == 'kgs' || varianceData['variance_Uom']?.toLowerCase() == 'kg')
//               ? weight * price
//               : quantity * price;

//       Map<String, dynamic> normalizedItem = {
//         ...newItem,
//         'itemData': {
//           'itemId': itemData['itemId'] ?? itemData['itemCode'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
//           'itemName': itemData['itemName'] ?? varianceData['varianceName'] ?? 'Unknown Item',
//           'itemCode': itemData['itemCode'] ?? varianceData['varianceName'] ?? '',
//           'tax': itemData['tax']?.toDouble() ?? 0.0,
//           'item_Uom': varianceData['variance_Uom'] ?? 'Pcs',
//           'category': itemData['category'] ?? 'Unknown',
//         },
//         'varianceData': varianceData,
//         'quantity': quantity,
//         'weight': weight,
//         'totalPrice': totalPrice,
//         'itemName': itemData['itemName'] ?? varianceData['varianceName'] ?? 'Unknown Item',
//         'itemCode': itemData['itemCode'] ?? varianceData['varianceName'] ?? '',
//         'tax': itemData['tax']?.toDouble() ?? 0.0,
//         'uom': varianceData['variance_Uom'] ?? 'Pcs',
//       };

//       bool exists = (varianceData['variance_Uom']?.toLowerCase() == 'kgs' || varianceData['variance_Uom']?.toLowerCase() == 'kg')
//           ? _currentSaleItems.any((item) =>
//               item['itemData']['itemId'] == normalizedItem['itemData']['itemId'] &&
//               item['varianceData']['varianceName'] == normalizedItem['varianceData']['varianceName'] &&
//               item['weight'] == weight)
//           : _currentSaleItems.any((item) =>
//               item['itemData']['itemId'] == normalizedItem['itemData']['itemId'] &&
//               item['varianceData']['varianceName'] == normalizedItem['varianceData']['varianceName']);

//       if (!exists) {
//         _currentSaleItems.add(normalizedItem);
//       }
//     }

//     _currentHoldId = holdId;
//     _saleCalculator = SaleCalculator(_currentSaleItems);
//     print('DEBUG: loadItemsFromBill - Current Sale Items: $_currentSaleItems');
//     notifyListeners();
//   }

//   void clearItems() async {
//     _currentSaleItems.clear();
//     var box = await Hive.openBox('cartBox');
//     await box.put('cartItems', []);
//     _saleCalculator = SaleCalculator(_currentSaleItems);
//     print('DEBUG: clearItems - Cleared Current Sale Items');
//     notifyListeners();
//   }

//   void removeItem(int index) async {
//     if (index >= 0 && index < _currentSaleItems.length) {
//       if (_currentSaleItems[index]['quantity'] > 1 &&
//           (_currentSaleItems[index]['varianceData']['variance_Uom']?.toLowerCase() != 'kgs' &&
//               _currentSaleItems[index]['varianceData']['variance_Uom']?.toLowerCase() != 'kg')) {
//         _currentSaleItems[index]['quantity'] -= 1;
//         _currentSaleItems[index]['totalPrice'] = _currentSaleItems[index]['quantity'] *
//             (_currentSaleItems[index]['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0);
//         print('DEBUG: removeItem - Decreased quantity for item at index $index: ${_currentSaleItems[index]}');
//       } else {
//         _currentSaleItems.removeAt(index);
//         print('DEBUG: removeItem - Removed item at index $index');
//       }
//       var box = await Hive.openBox('cartBox');
//       await box.put('cartItems', _currentSaleItems);
//       _saleCalculator = SaleCalculator(_currentSaleItems);
//       notifyListeners();
//     }
//   }

//   double calculateTotal() {
//     sgst = _saleCalculator.sgst;
//     cgst = _saleCalculator.cgst;
//     return _saleCalculator.calculateTotal();
//   }

//   double calculateDiscountAmount() {
//     return _saleCalculator.calculateDiscountAmount();
//   }

//   String buildQuantityPriceDisplay(Map<String, dynamic> item) {
//     return _saleCalculator.buildQuantityPriceDisplay(item);
//   }

//   double calculateItemTotal(Map<String, dynamic> item) {
//     return _saleCalculator.calculateItemTotal(item);
//   }

//   Future<void> saveBill(BuildContext context) async {
//     if (_currentSaleItems.isEmpty) {
//       _showSnackBar(context, 'No items to save!', Colors.red);
//       return;
//     }

//     var box = await Hive.openBox('cartBox');
//     List<Map<String, dynamic>> itemsWithStatus = _currentSaleItems.map((item) => {...item, 'status': 'hold'}).toList();
//     var randomId = generatetheholdrandomId();

//     Map<String, dynamic> billData = {
//       'holdId': randomId,
//       'date': DateTime.now().toIso8601String(),
//       'items': itemsWithStatus,
//       'total': calculateTotal(),
//       'status': 'hold',
//     };

//     await box.add(billData);
//     _showSnackBar(context, 'Bill saved as hold (Hold ID: $randomId)', Colors.green);
//     clearItems();
//   }

//   Future<void> saveBillsplitBill(
//       BuildContext context, List<List<Map<String, dynamic>>> tickets, List<String> ticketTitles) async {
//     if (tickets.isEmpty || tickets.every((ticket) => ticket.isEmpty)) {
//       _showSnackBar(context, 'No items to save!', Colors.red);
//       return;
//     }

//     var box = await Hive.openBox('cartBox');

//     for (int i = 0; i < tickets.length; i++) {
//       List<Map<String, dynamic>> itemsWithStatus = tickets[i]
//           .map((item) => {
//                 ...item,
//                 'status': 'hold',
//               })
//           .toList();

//       var randomId = generatetheholdrandomId();
//       String ticketName = ticketTitles[i];
//       String ticketType = "SplitBill";

//       Map<String, dynamic> billData = {
//         'holdId': randomId,
//         'date': DateTime.now().toIso8601String(),
//         'items': itemsWithStatus,
//         'total': calculateTotal2(itemsWithStatus),
//         'status': 'hold',
//         'ticketType': ticketType,
//         'ticketName': ticketName,
//       };

//       await box.add(billData);
//     }

//     clearItems();
//   }

//   int generatetheholdrandomId() {
//     return 10 + (Random().nextInt(90));
//   }

//   double calculateTotal2(List<Map<String, dynamic>> items) {
//     return items.fold(0.0, (sum, item) {
//       double price = (item['varianceData']?['variance_Defaultprice']?.toDouble() ?? 0.0);
//       double weight = (item['weight']?.toDouble() ?? 0.0);
//       int quantity = (item['quantity']?.toInt() ?? 0);
//       String uom = item['varianceData']?['variance_Uom']?.toLowerCase() ?? 'pcs';
//       return sum + ((uom == 'kgs' || uom == 'kg') ? weight * price : quantity * price);
//     });
//   }

//   void _showSnackBar(BuildContext context, String message, Color color) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           message,
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: color,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }
// }

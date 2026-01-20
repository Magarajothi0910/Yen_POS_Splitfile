import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';

class HoldOrderProvider with ChangeNotifier {
  Timer? _saveHoldTimer;
  Timer? _removeHoldTimer;

  final Box _holdOrdersBox = Hive.box('holdOrdersKOT');

  HoldOrderProvider() {
    _cleanOldOrders();
  }

  String get _todayDate => DateFormat('dd-MM-yyyy').format(DateTime.now());

  // ENHANCED: Save with complete data validation
  void saveHoldOrder(
    String tableNumber,
    String seat,
    Map<String, dynamic> cart, {
    String areaName = '',
  }) {
    _saveHoldTimer?.cancel();

    _saveHoldTimer = Timer(const Duration(milliseconds: 800), () {
      try {
        final key = '${tableNumber}_$seat';

        // Validate cart data before saving
        final validatedCart = _validateAndCleanCart(cart);

        final orderData = {
          'date': _todayDate,
          'areaName': areaName,
          'table': tableNumber,
          'seat': seat,
          'cart': validatedCart,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        };

        final OrderDataType = {'type': 'addHoldOrdersKOT', 'data': orderData};

        sendataToServer(OrderDataType);

        // _holdOrdersBox.put(key, orderData);

        // final tableHoldOrder = _holdOrdersBox.get(key);

        // debugPrint('tableHoldOrder $tableHoldOrder');

        // Debug: Print cart structure for verification
        validatedCart.forEach((productName, productData) {
          debugPrint('📋 Product: $productName - Qty: ${productData['qty']}');
        });

        notifyListeners();
      } catch (e) {
        debugPrint('❌ Error saving hold order: $e');
      }
    });
  }

  // NEW: Validate and clean cart data before saving
  Map<String, dynamic> _validateAndCleanCart(Map<String, dynamic> cart) {
    final Map<String, dynamic> cleanedCart = {};

    cart.forEach((productName, productData) {
      try {
        // Ensure productData is a Map
        if (productData is Map<String, dynamic>) {
          final cleanedProductData = Map<String, dynamic>.from(productData);

          // Ensure required fields exist with defaults
          cleanedProductData['qty'] = cleanedProductData['qty'] ?? 1;
          cleanedProductData['weight'] = cleanedProductData['weight'] ?? 0;
          cleanedProductData['selectedAddOns'] =
              cleanedProductData['selectedAddOns'] ?? {};
          cleanedProductData['totalAmount'] =
              cleanedProductData['totalAmount'] ?? 0;
          cleanedProductData['remarks'] = cleanedProductData['remarks'] ?? [];
          cleanedProductData['toggleRemarks'] =
              cleanedProductData['toggleRemarks'] ?? [false];

          // Ensure arrays exist and are properly initialized
          cleanedProductData['addons'] = cleanedProductData['addons'] ?? [];
          cleanedProductData['addonQuantities'] =
              cleanedProductData['addonQuantities'] ?? [];
          cleanedProductData['variants'] = cleanedProductData['variants'] ?? [];
          cleanedProductData['type'] = cleanedProductData['type'] ?? [];
          cleanedProductData['configQty'] =
              cleanedProductData['configQty'] ?? [];

          cleanedCart[productName] = cleanedProductData;
        }
      } catch (e) {
        debugPrint('❌ Error cleaning product $productName: $e');
      }
    });

    return cleanedCart;
  }

  // ENHANCED: Load with better error handling and validation
  Map<String, dynamic>? loadHoldOrder(String tableNumber, String seat) {
    try {
      final key = '${tableNumber}_$seat';

      if (_holdOrdersBox.containsKey(key)) {
        final orderData = _holdOrdersBox.get(key);

        // Check if it's today's order
        if (orderData['date'] == _todayDate) {
          final cart = orderData['cart'];

          if (cart != null && cart is Map && cart.isNotEmpty) {
            // Validate loaded cart data
            final validatedCart = _validateAndCleanCart(
              Map<String, dynamic>.from(cart),
            );

            // Debug: Print loaded cart structure
            validatedCart.forEach((productName, productData) {});

            return validatedCart;
          } else {
            debugPrint(
              '❌ Invalid or empty cart data for $tableNumber - Seat $seat',
            );
          }
        } else {
          debugPrint(
            '🗑️ Removing expired hold order for $tableNumber - Seat $seat',
          );
          _holdOrdersBox.delete(key);
        }
      } else {
        debugPrint('❌ No hold order found for $tableNumber - Seat $seat');
      }
    } catch (e) {
      debugPrint('❌ Error loading hold order: $e');
    }

    return null;
  }

  // ... rest of your existing methods remain the same
  bool hasHoldOrder(String tableNumber, String seat) {
    final key = '${tableNumber}_$seat';

    if (_holdOrdersBox.containsKey(key)) {
      final orderData = _holdOrdersBox.get(key);
      final exists = orderData['date'] == _todayDate;

      return exists;
    }

    return false;
  }

  List<Map<String, dynamic>> getAllHoldOrders() {
    final List<Map<String, dynamic>> holdOrders = [];

    try {
      final allKeys = _holdOrdersBox.keys;

      for (var key in allKeys) {
        try {
          final orderData = _holdOrdersBox.get(key);

          if (orderData != null && orderData['date'] == _todayDate) {
            final tableSeat = key.toString().split('_');

            final table = tableSeat.isNotEmpty ? tableSeat[0] : 'Unknown';
            final seat = tableSeat.length > 1 ? tableSeat[1] : 'A';

            final holdOrder = {
              'table': table,
              'seat': seat,
              'areaName': orderData['areaName'] ?? 'Unknown Area',
              'cart': orderData['cart'],
              'createdAt': orderData['createdAt'] ?? 0,
            };

            holdOrders.add(holdOrder);
          }
        } catch (e) {
          debugPrint('❌ Error processing hold order key $key: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting all hold orders: $e');
    }

    return holdOrders;
  }

  void removeHoldOrder(String tableNumber, String seat) {
    final key = '${tableNumber}_$seat';
    final removeHoldOrder = {'type': 'removeHoldOrdersKOT', 'data': key};
    _removeHoldTimer?.cancel();
    _removeHoldTimer = Timer(const Duration(milliseconds: 800), () {
      sendataToServer(removeHoldOrder);
    });
  }

  void _cleanOldOrders() {
    final keysToRemove = _holdOrdersBox.keys.where((key) {
      final orderData = _holdOrdersBox.get(key);
      return orderData['date'] != _todayDate;
    }).toList();

    for (var key in keysToRemove) {
      _holdOrdersBox.delete(key);
    }
  }
}

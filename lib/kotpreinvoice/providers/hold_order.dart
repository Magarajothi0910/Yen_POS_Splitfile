import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';

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
        if (productData is Map) {
          final cleanedProductData = Map<String, dynamic>.from(
            productData as Map,
          );

          // ───── Normalize legacy keys ─────
          cleanedProductData['remarks'] ??=
              cleanedProductData.remove('remark') ?? [];

          cleanedProductData['toggleRemarks'] ??=
              cleanedProductData.remove('toggleRemark') ?? [false];

          // ───── Defaults ─────
          cleanedProductData['qty'] ??= 1;
          cleanedProductData['weight'] ??= 0.0;
          cleanedProductData['selectedAddOns'] ??= {};
          cleanedProductData['totalAmount'] ??= 0.0;

          // ───── Lists ─────
          cleanedProductData['addons'] =
              (cleanedProductData['addons'] as List?) ?? [];

          cleanedProductData['addonQuantities'] =
              (cleanedProductData['addonQuantities'] as List?) ?? [];

          cleanedProductData['variants'] =
              (cleanedProductData['variants'] as List?) ?? [];

          cleanedProductData['type'] =
              (cleanedProductData['type'] as List?)
                  ?.map((e) => e ?? '')
                  .toList() ??
              [];

          cleanedProductData['configQty'] =
              (cleanedProductData['configQty'] as List?) ?? [];

          cleanedCart[productName] = cleanedProductData;
        }
      } catch (e, s) {
        debugPrint('❌ Error cleaning $productName: $e');
        debugPrintStack(stackTrace: s);
      }
    });

    return cleanedCart;
  }

  Map<String, dynamic>? loadHoldOrder(String tableNumber, String seat) {
    final key = '${tableNumber}_$seat';
    if (_holdOrdersBox.containsKey(key)) {
      final orderData = _holdOrdersBox.get(key);
      if (orderData['date'] == _todayDate) {
        return Map<String, dynamic>.from(orderData['cart']);
      } else {
        _holdOrdersBox.delete(key); // Remove old order
      }
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

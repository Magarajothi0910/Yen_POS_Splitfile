import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

// class HoldOrderProvider with ChangeNotifier {
//   final Box _holdOrdersBox = Hive.box('holdOrdersKOT');

//   HoldOrderProvider() {
//     _cleanOldOrders(); // Remove outdated orders on initialization
//   }

//   // Get today's date in dd-MM-yyyy format
//   String get _todayDate => DateFormat('dd-MM-yyyy').format(DateTime.now());

//   // Save the current cart to hold orders with date
//   void saveHoldOrder(String tableNumber, String seat, Map<String, dynamic> cart) {
//     final key = '${tableNumber}_$seat';
//     final orderData = {
//       'date': _todayDate, // Store order date in dd-MM-yyyy format
//       'cart': cart,
//     };
//     _holdOrdersBox.put(key, orderData);
//     print('hold order data is orderdata is ${orderData.entries} and ${orderData['cart']}');
//     print('Hold order saved for  $tableNumber - Seat $seat');
//     notifyListeners();
//   }

//   // Retrieve hold order for a specific table and seat (only if it's today's order)
//   Map<String, dynamic>? loadHoldOrder(String tableNumber, String seat) {
//     final key = '${tableNumber}_$seat';
//     if (_holdOrdersBox.containsKey(key)) {
//       final orderData = _holdOrdersBox.get(key);
//       if (orderData['date'] == _todayDate) {
//         return Map<String, dynamic>.from(orderData['cart']);
//       } else {
//         _holdOrdersBox.delete(key); // Remove old order
//       }
//     }
//     return null;
//   }

//   // Remove hold order after submission or when cleared
//   void removeHoldOrder(String tableNumber, String seat) {
//     final key = '${tableNumber}_$seat';
//     if (_holdOrdersBox.containsKey(key)) {
//       _holdOrdersBox.delete(key);
//       notifyListeners();
//     }
//   }

//   // Check if a hold order exists for the current date
//   bool hasHoldOrder(String tableNumber, String seat) {
//     final key = '${tableNumber}_$seat';
//     if (_holdOrdersBox.containsKey(key)) {
//       final orderData = _holdOrdersBox.get(key);
//       return orderData['date'] == _todayDate;
//     }
//     return false;
//   }

//   // Get all hold orders for the current date
//   List<Map<String, dynamic>> getAllHoldOrders() {
//     return _holdOrdersBox.keys.where((key) {
//       final orderData = _holdOrdersBox.get(key);
//       return orderData['date'] == _todayDate;
//     }).map((key) {
//       final tableSeat = key.toString().split('_');

//       // Ensure key has both table and seat parts
//       final table = tableSeat.isNotEmpty ? tableSeat[0] : 'Unknown';
//       final seat = tableSeat.length > 1 ? tableSeat[1] : 'A'; // Default to 'A' if missing

//       return {
//         'table': table,
//         'seat': seat,
//         'cart': _holdOrdersBox.get(key)['cart'],
//       };
//     }).toList();
//   }

//   // Delete all old orders that are not from the current date
//   void _cleanOldOrders() {
//     final keysToRemove = _holdOrdersBox.keys.where((key) {
//       final orderData = _holdOrdersBox.get(key);
//       return orderData['date'] != _todayDate; // Remove if date is old
//     }).toList();

//     for (var key in keysToRemove) {
//       _holdOrdersBox.delete(key);
//     }
//   }
// }

// class HoldOrderProvider with ChangeNotifier {
//   final Box _holdOrdersBox = Hive.box('holdOrdersKOT');

//   HoldOrderProvider() {
//     _cleanOldOrders(); // Remove outdated orders on initialization
//   }

//   // Get today's date in dd-MM-yyyy format
//   String get _todayDate => DateFormat('dd-MM-yyyy').format(DateTime.now());

//   // ENHANCED: Save the current cart to hold orders with complete metadata
//   void saveHoldOrder(String tableNumber, String seat, Map<String, dynamic> cart, {String areaName = ''}) {
//     final key = '${tableNumber}_$seat';
//     final orderData = {
//       'date': _todayDate,
//       'areaName': areaName, // Store area name
//       'table': tableNumber, // Store table number
//       'seat': seat, // Store seat
//       'cart': cart,
//       'createdAt': DateTime.now().millisecondsSinceEpoch, // Track creation time
//     };

//     _holdOrdersBox.put(key, orderData);

//     debugPrint('💾 Hold order saved for $tableNumber - Seat $seat');
//     debugPrint('📦 Cart items: ${cart.length}');
//     debugPrint('📍 Area: $areaName');
//     debugPrint('🕒 Created at: ${orderData['createdAt']}');

//     notifyListeners();
//   }

//   // ENHANCED: Retrieve hold order for a specific table and seat
//   Map<String, dynamic>? loadHoldOrder(String tableNumber, String seat) {
//     final key = '${tableNumber}_$seat';

//     if (_holdOrdersBox.containsKey(key)) {
//       final orderData = _holdOrdersBox.get(key);

//       // Check if it's today's order
//       if (orderData['date'] == _todayDate) {
//         debugPrint('✅ Loaded hold order for $tableNumber - Seat $seat');
//         debugPrint('📦 Cart items: ${orderData['cart']?.length ?? 0}');

//         // Return the cart data
//         return Map<String, dynamic>.from(orderData['cart'] ?? {});
//       } else {
//         debugPrint('🗑️ Removing old hold order for $tableNumber - Seat $seat');
//         _holdOrdersBox.delete(key); // Remove old order
//       }
//     } else {
//       debugPrint('❌ No hold order found for $tableNumber - Seat $seat');
//     }

//     return null;
//   }

//   // ENHANCED: Check if a hold order exists for the current date
//   bool hasHoldOrder(String tableNumber, String seat) {
//     final key = '${tableNumber}_$seat';

//     if (_holdOrdersBox.containsKey(key)) {
//       final orderData = _holdOrdersBox.get(key);
//       final exists = orderData['date'] == _todayDate;

//       debugPrint('🔍 Hold order check for $tableNumber - Seat $seat: $exists');
//       return exists;
//     }

//     return false;
//   }

//   // ENHANCED: Get all hold orders for the current date with complete data
//   List<Map<String, dynamic>> getAllHoldOrders() {
//     final List<Map<String, dynamic>> holdOrders = [];

//     try {
//       final allKeys = _holdOrdersBox.keys;
//       debugPrint('🔍 Checking ${allKeys.length} keys in hold orders box');

//       for (var key in allKeys) {
//         try {
//           final orderData = _holdOrdersBox.get(key);

//           if (orderData != null && orderData['date'] == _todayDate) {
//             final tableSeat = key.toString().split('_');

//             // Ensure key has both table and seat parts
//             final table = tableSeat.isNotEmpty ? tableSeat[0] : 'Unknown';
//             final seat = tableSeat.length > 1 ? tableSeat[1] : 'A';

//             final holdOrder = {
//               'table': table,
//               'seat': seat,
//               'areaName': orderData['areaName'] ?? 'Unknown Area',
//               'cart': orderData['cart'],
//               'createdAt': orderData['createdAt'] ?? 0,
//             };

//             holdOrders.add(holdOrder);
//             debugPrint('✅ Found hold order: $table - Seat $seat (Area: ${holdOrder['areaName']})');
//           }
//         } catch (e) {
//           debugPrint('❌ Error processing hold order key $key: $e');
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ Error getting all hold orders: $e');
//     }

//     debugPrint('📦 Total hold orders found: ${holdOrders.length}');
//     return holdOrders;
//   }

//   // Remove hold order after submission or when cleared
//   void removeHoldOrder(String tableNumber, String seat) {
//     final key = '${tableNumber}_$seat';

//     if (_holdOrdersBox.containsKey(key)) {
//       _holdOrdersBox.delete(key);
//       debugPrint('🗑️ Removed hold order for $tableNumber - Seat $seat');
//       notifyListeners();
//     } else {
//       debugPrint('⚠️ No hold order to remove for $tableNumber - Seat $seat');
//     }
//   }

//   // Delete all old orders that are not from the current date
//   void _cleanOldOrders() {
//     final keysToRemove = _holdOrdersBox.keys.where((key) {
//       final orderData = _holdOrdersBox.get(key);
//       return orderData['date'] != _todayDate; // Remove if date is old
//     }).toList();

//     debugPrint('🧹 Cleaning ${keysToRemove.length} old hold orders');

//     for (var key in keysToRemove) {
//       _holdOrdersBox.delete(key);
//     }
//   }
// }

class HoldOrderProvider with ChangeNotifier {
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
    try {
      final key = '${tableNumber}_$seat';
      print("cart data is $cart");
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
      
      print("holdorder data is $orderData");

      _holdOrdersBox.put(key, orderData);

      debugPrint('💾 Hold order saved for $tableNumber - Seat $seat');
      debugPrint('📦 Cart items: ${validatedCart.length}');
      debugPrint('📍 Area: $areaName');
      debugPrint('🕒 Created at: ${orderData['createdAt']}');

      // Debug: Print cart structure for verification
      validatedCart.forEach((productName, productData) {
        debugPrint('📋 Product: $productName - Qty: ${productData['qty']}');
      });

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error saving hold order: $e');
    }
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

          print("Holdorder today is $cart");

          if (cart != null && cart is Map && cart.isNotEmpty) {
            debugPrint('📦 Cart items: ${cart.length}');

            // Validate loaded cart data
            final validatedCart = _validateAndCleanCart(
              Map<String, dynamic>.from(cart),
            );

            // Debug: Print loaded cart structure
            validatedCart.forEach((productName, productData) {
              debugPrint(
                '📋 Loaded Product: $productName - Qty: ${productData['qty']}',
              );
            });

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

      debugPrint('🔍 Hold order check for $tableNumber - Seat $seat: $exists');
      return exists;
    }

    return false;
  }

  List<Map<String, dynamic>> getAllHoldOrders() {
    final List<Map<String, dynamic>> holdOrders = [];

    try {
      final allKeys = _holdOrdersBox.keys;
      // debugPrint('🔍 Checking ${allKeys.length} keys in hold orders box');

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
            debugPrint(
              '✅ Found hold order: $table - Seat $seat (Area: ${holdOrder['areaName']})',
            );
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

    if (_holdOrdersBox.containsKey(key)) {
      _holdOrdersBox.delete(key);
      debugPrint('🗑️ Removed hold order for $tableNumber - Seat $seat');
      notifyListeners();
    } else {
      debugPrint('⚠️ No hold order to remove for $tableNumber - Seat $seat');
    }
  }

  void _cleanOldOrders() {
    final keysToRemove = _holdOrdersBox.keys.where((key) {
      final orderData = _holdOrdersBox.get(key);
      return orderData['date'] != _todayDate;
    }).toList();

    debugPrint('🧹 Cleaning ${keysToRemove.length} old hold orders');

    for (var key in keysToRemove) {
      _holdOrdersBox.delete(key);
    }
  }
}

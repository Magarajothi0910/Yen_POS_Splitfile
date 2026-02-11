import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/flushbar.dart';

import 'hold_order.dart';

class CartProviderKOT with ChangeNotifier {
  Map<String, dynamic> _cart = {};

  Map<String, dynamic> get cart => _cart;

  bool _isToggled = false;
  bool get isToggled => _isToggled;
  int _cartLineCounter = 0;

  final ValueNotifier<String> currentTableNumber = ValueNotifier('');
  final ValueNotifier<String> currentSeat = ValueNotifier('');
  final ValueNotifier<String> currentAreaName = ValueNotifier('');
  final ValueNotifier<String> currentSeathiveOrderId = ValueNotifier('');

  bool getToggleRemarkForItem(String productId, int itemIndex) {
    final cartItem = cart[productId];
    if (cartItem != null && cartItem['toggleRemark'] is List) {
      final toggleList = List<bool>.from(cartItem['toggleRemark'] ?? []);
      return itemIndex < toggleList.length ? toggleList[itemIndex] : false;
    }
    return false;
  }

  String getRemarkForItem(String productId, int itemIndex) {
    final cartItem = cart[productId];
    if (cartItem != null && cartItem['remark'] is List) {
      final remarkList = List<String>.from(cartItem['remark'] ?? []);
      return itemIndex < remarkList.length ? remarkList[itemIndex] : '';
    }
    return '';
  }

  void updateCartWithPerItemRemarks(
    String productId,
    List<List<String>> addons,
    List<List<int>> addonQuantities,
    List<String> variants,
    List<String> type,
    List<String> remark, // Changed to List<String>
    List<bool> toggleRemark, // Changed to List<bool>
  ) {
    if (cart.containsKey(productId)) {
      cart[productId] = {
        ...cart[productId]!,
        'addons': addons,
        'addonQuantities': addonQuantities,
        'variants': variants,
        'type': type,
        'remark': remark, // Now a list
        'toggleRemark': toggleRemark, // Now a list
      };
      notifyListeners();
    }
  }

  void clearTableSeat() {
    currentTableNumber.value = '';
    currentSeat.value = '';
    currentAreaName.value = '';
    currentSeathiveOrderId.value = '';
  }

  void setToggled(bool value) {
    _isToggled = value;
    notifyListeners();
  }

  String _nextCartKey() {
    _cartLineCounter++;
    return _cartLineCounter.toString();
  }

  void addToCart(String varianceName, {double? weight}) {
    // ── Decision: should we treat this as weighted (separate line) item? ──
    final bool isWeightedItem = (weight ?? 0) > 0;

    if (!isWeightedItem) {
      if (_cart.containsKey(varianceName)) {
        _cart[varianceName]['qty'] = (_cart[varianceName]['qty'] as int) + 1;
      } else {
        _cart[varianceName] = {
          'weight': 0.0,
          'qty': 1,
          'selectedAddOns': {},
          'totalAmount': 0.0,
          'baseName': varianceName,
        };
      }
    } else {
      final key = _nextCartKey();
      final String uniqueKey = "$varianceName-${key}";

      if (_cart.containsValue(varianceName)) {
        _cart[uniqueKey]['qty'] = (_cart[uniqueKey]['qty'] as int) + 1;
      } else {
        _cart[uniqueKey] = {
          'weight': weight,
          'qty': 1,
          'selectedAddOns': {},
          'totalAmount': 0.0,
          'baseName': varianceName,
        };
      }
    }

    notifyListeners();
  }

  void addAddOn(String varianceName, String addOnName, int addOnValue) {
    // Initialize the cart entry if it doesn't exist
    if (_cart[varianceName] == null) {
      _cart[varianceName] = {
        'weight': 0,
        'qty': 1,
        'selectedAddOns': {}, // Initialize selectedAddOns as a Map
        'totalAmount': 0,
      };
    }

    // Initialize selectedAddOns and totalAmount if they are null
    _cart[varianceName]['selectedAddOns'] =
        _cart[varianceName]['selectedAddOns'] ?? [];
    _cart[varianceName]['totalAmount'] =
        _cart[varianceName]['totalAmount'] ?? 0;

    // Add the selected add-on to the list
    (_cart[varianceName]['selectedAddOns'] as List).add({
      'name': addOnName,
      'value': addOnValue,
    });

    _cart[varianceName]['totalAmount'] += addOnValue;

    notifyListeners();
  }

  void removeItemFromCart1(BuildContext context, String varianceName) {
    if (_cart.containsKey(varianceName)) {
      final currentQty = _cart[varianceName]['qty'];

      if (currentQty > 1) {
        _cart[varianceName]['qty'] = currentQty - 1;
        notifyListeners(); // Notify listeners when the quantity is decreased
      } else {
        showCustomFlushbar(
          context,
          "Quantity is already at minimum (1). Swipe to remove item instead.",
          type: FlushbarType.warning,
        );
        return;
      }
    }
  }

  void removeItemFromCart(
    BuildContext context,
    String varianceName,
    String tableNumber,
    String seat,
  ) {
    if (_cart.containsKey(varianceName)) {
      final currentQty = _cart[varianceName]['qty'];

      if (currentQty > 1) {
        _cart[varianceName]['qty'] = currentQty - 1;
      } else {
        // ⚠️ Quantity already at minimum
        showCustomFlushbar(
          context,
          "Quantity is already at minimum (1). Swipe to remove the item.",
          type: FlushbarType.warning,
        );
        return;
      }

      notifyListeners();
      _updateHoldOrder(
        context,
        tableNumber,
        seat,
      ); // Update hold order after change
    }
  }

  void removeItemFromCard1(BuildContext context, String productId) {
    if (cart.containsKey(productId)) {
      int currentQty = cart[productId]['qty'];

      if (currentQty > 1) {
        cart[productId]['qty']--;
      } else {
        cart.remove(productId); // Completely remove when quantity is 0
      }

      notifyListeners(); // Update UI
    }
  }

  void removeItemFromCard(
    BuildContext context,
    String productId,
    String tableNumber,
    String seat,
  ) {
    if (_cart.containsKey(productId)) {
      int currentQty = _cart[productId]['qty'];

      if (currentQty > 1) {
        _cart[productId]['qty']--;
      } else {
        _cart.remove(productId); // Completely remove when quantity reaches 0
      }

      notifyListeners();
      _updateHoldOrder(
        context,
        tableNumber,
        seat,
      ); // Ensure hold order is updated
    }
  }

  void _updateHoldOrder(BuildContext context, String tableNumber, String seat) {
    if (_cart.isEmpty) {
      Provider.of<HoldOrderProvider>(
        context,
        listen: false,
      ).removeHoldOrder(tableNumber, seat);
    } else {
      Provider.of<HoldOrderProvider>(
        context,
        listen: false,
      ).saveHoldOrder(tableNumber, seat, _cart);
    }
  }

  void updateItemWeight(String productName, int newWeight) {
    if (cart.containsKey(productName)) {
      cart[productName]['weight'] = newWeight;
      notifyListeners();
    }
  }

  void updateItemQuantity(String productName, double newQty) {
    if (cart.containsKey(productName)) {
      cart[productName]['qty'] = newQty;
      notifyListeners();
    }
  }

  void removeFromCart(
    BuildContext context,
    String productId,
    String tableNumber,
    String seat,
  ) {
    if (_cart.containsKey(productId)) {
      _cart.remove(productId); // Directly remove the item from the cart
      notifyListeners();
      _updateHoldOrder(
        context,
        tableNumber,
        seat,
      ); // Notify listeners after the item is removed
    }
  }

  void debugCartState() {
    debugPrint('🛒 Current Cart State:');
    if (cart.isEmpty) {
      debugPrint('   - Cart is empty');
    } else {
      cart.forEach((productName, productData) {
        debugPrint(
          '   - $productName: ${productData['qty']} qty, Data: $productData',
        );
      });
    }
  }

  void addOrUpdateAddOn(String varianceName, String addOn, int addOnValue) {
    if (_cart.containsKey(varianceName)) {
      var selectedAddOns = _cart[varianceName]!['selectedAddOns'];

      if (selectedAddOns is Map) {
        // Ensure it is treated as Map<String, Map<String, dynamic>>
        selectedAddOns = (selectedAddOns).cast<String, Map<String, dynamic>>();
      } else {
        // If it's not a Map, initialize it as a new Map
        selectedAddOns = <String, Map<String, dynamic>>{};
      }

      if (selectedAddOns.containsKey(addOn)) {
        selectedAddOns[addOn]!['qty'] += 1; // Increment the quantity
      } else {
        selectedAddOns[addOn] = {
          'qty': 1,
          'value': addOnValue,
        }; // Add new add-on with quantity 1
      }

      _cart[varianceName]!['selectedAddOns'] = selectedAddOns;
    } else {
      _cart[varianceName] = {
        'qty': 1,
        'selectedAddOns': {
          addOn: {'qty': 1, 'value': addOnValue},
        },
      };
    }
    notifyListeners();
  }

  void updateAddOnQuantity(String productName, String addOnName, int newQty) {
    if (_cart.containsKey(productName)) {
      final product = _cart[productName];
      final selectedAddOns = product?['selectedAddOns'];

      if (selectedAddOns != null && selectedAddOns.containsKey(addOnName)) {
        if (newQty > 0) {
          selectedAddOns[addOnName]['qty'] = newQty;
        } else {
          selectedAddOns.remove(addOnName);
        }
        product?['selectedAddOns'] = selectedAddOns;
        notifyListeners();
      }
    }
  }

  void loadCart(Map<dynamic, dynamic> holdOrder) {
    // Safely convert holdOrder to Map<String, dynamic>
    _cart = holdOrder.map((key, value) {
      return MapEntry(
        key.toString(), // Ensure key is a String
        Map<String, dynamic>.from(
          value,
        ), // Convert value to Map<String, dynamic>
      );
    });

    notifyListeners();
  }

  int? getParcelQuantity(String varianceName) {
    return cart[varianceName]?['parcelQty'];
  }

  void updateParcelQuantity(String varianceName, int quantity) {
    cart[varianceName]?['parcelQty'] = quantity;
    notifyListeners(); // Notify UI to refresh
  }

  void updateCart(
    String productId,
    List<List<String>> addons,
    List<List<int>> addonQuantities,
    List<String> variants,
    List<String> type,
    String remark, // Changed from List<String> to String
    bool toggleRemark, // Include toggleRemarks
  ) {
    debugPrint("Updating cart for productId: $variants");
    if (_cart.containsKey(productId)) {
      _cart[productId]['addons'] = addons;
      _cart[productId]['addonQuantities'] = addonQuantities;
      _cart[productId]['variants'] = variants;
      _cart[productId]['type'] = type;
      _cart[productId]['remark'] = remark; // Single string
      _cart[productId]['toggleRemark'] = toggleRemark; // Save toggle states
    }
    notifyListeners(); // Notify UI to update
  }

  bool getToggleRemark(String productId) {
    if (_cart.containsKey(productId) &&
        _cart[productId]['toggleRemark'] != null) {
      return _cart[productId]['toggleRemark'] as bool;
    }
    return false; // Default to false
  }

  String getRemark(String productId) {
    if (_cart.containsKey(productId) && _cart[productId]['remark'] != null) {
      return _cart[productId]['remark'].toString();
    }
    return ""; // Default to empty string
  }

  // In CartProviderKOT
  // Make sure this method handles per-item remarks when syncing quantity
  void syncConfigWithQuantity(String productId, int newQuantity) {
    final cartItem = cart[productId];
    if (cartItem == null) return;

    final oldQuantity = cartItem['qty'] ?? 1;

    if (newQuantity > oldQuantity) {
      // Add new items with default remark values
      final currentToggleRemark = List<bool>.from(
        cartItem['toggleRemark'] ?? [],
      );
      final currentRemark = List<String>.from(cartItem['remark'] ?? []);

      while (currentToggleRemark.length < newQuantity) {
        currentToggleRemark.add(false);
      }
      while (currentRemark.length < newQuantity) {
        currentRemark.add('');
      }

      cart[productId]!['toggleRemark'] = currentToggleRemark;
      cart[productId]!['remark'] = currentRemark;
    } else if (newQuantity < oldQuantity) {
      // Remove excess items
      final currentToggleRemark = List<bool>.from(
        cartItem['toggleRemark'] ?? [],
      );
      final currentRemark = List<String>.from(cartItem['remark'] ?? []);

      if (currentToggleRemark.length > newQuantity) {
        cart[productId]!['toggleRemark'] = currentToggleRemark.sublist(
          0,
          newQuantity,
        );
      }
      if (currentRemark.length > newQuantity) {
        cart[productId]!['remark'] = currentRemark.sublist(0, newQuantity);
      }
    }

    cart[productId]!['qty'] = newQuantity;
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }
}

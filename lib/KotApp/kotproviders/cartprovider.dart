import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'hold_order.dart';

class CartProviderkot with ChangeNotifier {
  Map<String, dynamic> _cart = {};

  Map<String, dynamic> get cart => _cart;

  void addToCart(String varianceName, {int? weight}) {
    if (_cart.containsKey(varianceName)) {
      if (weight != null && weight > 0) {
        _cart[varianceName]['weight'] = weight;
      }
      _cart[varianceName]['qty'] = (_cart[varianceName]['qty'] as int) + 1;
    } else {
      _cart[varianceName] = {
        'weight': weight ?? 0,
        'qty': 1,
        'selectedAddOns': {},
        'totalAmount': 0,
      };
    }
    notifyListeners(); // Notify listeners about the changes
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

    // Update the total amount
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
        // Display message when trying to remove quantity less than 1

        Flushbar(
          message: "Swipe to remove item, quantity is already at minimum (1).",
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red[600] ?? Colors.red,
          flushbarPosition: FlushbarPosition.BOTTOM,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(20),
        ).show(context);
        return;
      }
    }
  }

  void removeItemFromCart(BuildContext context, String varianceName,
      String tableNumber, String seat) {
    if (_cart.containsKey(varianceName)) {
      final currentQty = _cart[varianceName]['qty'];

      if (currentQty > 1) {
        _cart[varianceName]['qty'] = currentQty - 1;
      } else {
        Flushbar(
          message: "Swipe to remove item, quantity is already at minimum (1).",
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red[600] ?? Colors.red,
          flushbarPosition: FlushbarPosition.BOTTOM,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(20),
        ).show(context);
        return;
      }

      notifyListeners();
      _updateHoldOrder(
          context, tableNumber, seat); // Update hold order after change
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
      BuildContext context, String productId, String tableNumber, String seat) {
    if (_cart.containsKey(productId)) {
      int currentQty = _cart[productId]['qty'];

      if (currentQty > 1) {
        _cart[productId]['qty']--;
      } else {
        _cart.remove(productId); // Completely remove when quantity reaches 0
      }

      notifyListeners();
      _updateHoldOrder(
          context, tableNumber, seat); // Ensure hold order is updated
    }
  }

  void _updateHoldOrder(BuildContext context, String tableNumber, String seat) {
    if (_cart.isEmpty) {
      Provider.of<HoldOrderProvider>(context, listen: false)
          .removeHoldOrder(tableNumber, seat);
    } else {
      Provider.of<HoldOrderProvider>(context, listen: false)
          .saveHoldOrder(tableNumber, seat, _cart);
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
      BuildContext context, String productId, String tableNumber, String seat) {
    if (_cart.containsKey(productId)) {
      _cart.remove(productId); // Directly remove the item from the cart
      notifyListeners();
      _updateHoldOrder(context, tableNumber,
          seat); // Notify listeners after the item is removed
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
        }
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
            value), // Convert value to Map<String, dynamic>
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
    List<String> variants,
    List<String> type,
    List<String> remarks,
    List<bool> toggleRemarks, // Include toggleRemarks
  ) {
    if (_cart.containsKey(productId)) {
      _cart[productId]['addons'] = addons;
      _cart[productId]['variants'] = variants;
      _cart[productId]['type'] = type;
      _cart[productId]['remarks'] = remarks; // Save remarks
      _cart[productId]['toggleRemarks'] = toggleRemarks; // Save toggle states
    }
    notifyListeners(); // Notify UI to update
  }

  List<bool> getToggleRemarks(String productId, int quantity) {
    if (_cart[productId]['toggleRemarks'] != null) {
      return List<bool>.from(_cart[productId]['toggleRemarks']);
    }
    return List.generate(quantity, (i) => false); // Default to false
  }

  List<String> getRemarks(String productId, int quantity) {
    if (_cart[productId]['remarks'] != null) {
      return List<String>.from(_cart[productId]['remarks']);
    }
    return List.generate(quantity, (i) => ""); // Default to empty
  }

  void syncConfigWithQuantity(String productId, int quantity) {
    if (_cart.containsKey(productId)) {
      // Adjust remarks and toggleRemarks lengths without calling notifyListeners
      List<String> remarks = List.generate(
        quantity,
        (i) => (_cart[productId]['remarks'] != null &&
                i < _cart[productId]['remarks'].length)
            ? _cart[productId]['remarks'][i]
            : "", // Default remark
      );

      List<bool> toggleRemarks = List.generate(
        quantity,
        (i) => (_cart[productId]['toggleRemarks'] != null &&
                i < _cart[productId]['toggleRemarks'].length)
            ? _cart[productId]['toggleRemarks'][i]
            : false, // Default toggle state
      );

      // Update internal state without notifying listeners during build
      _cart[productId]['remarks'] = remarks;
      _cart[productId]['toggleRemarks'] = toggleRemarks;
    }
  }

  void clearCart() {
    _cart.clear();

    notifyListeners();
  }
}

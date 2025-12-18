import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Sale_order/Widgets/custom_qty_keyboard.dart';

class CartItem {
  final String rowId; // stable unique ID
  final String varianceName;
  final String itemName;
  final String itemCode;
  final int pricePerKg;
  int? sellingPrice;
  double? sellingAmount;
  double? finalPrice;
  double itemWiseDiscount;
  double itemWiseDiscountAmount;
  double? discount;
  String? isBoxItem;
  final int tax;
  int? boxQuantity;
  final String uom;
  ValueNotifier<int> quantity; // ✅ make quantity a ValueNotifier
  double weight;

  CartItem({
    String? rowId, // optional, will be generated if null
    required this.varianceName,
    required this.itemName,
    required this.itemCode,
    this.sellingPrice,
    this.sellingAmount,
    required this.pricePerKg,
    this.finalPrice,
    required this.itemWiseDiscount,
    required this.itemWiseDiscountAmount,
    this.discount,
    this.isBoxItem,
    required this.tax,
    this.boxQuantity,
    required this.uom,
    required int quantity, // input int
    required this.weight,
  }) : quantity = ValueNotifier<int>(quantity),
       rowId = rowId ?? UniqueKey().toString(); // assign stable ID
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _closingStockItems = []; // Closing stock cart

  final List<List<CartItem>> _savedBills = [];
  int? _currentBillIndex; // Tracks the index of the currently loaded bill
  List<bool> itemSelections = [];
  List<CartItem> get cartItems => globals.cartItems;
  void toggleItemSelection(int index) {
    itemSelections[index] = !itemSelections[index];
    notifyListeners();
  }

  // Add reactive properties
  ValueNotifier<double> totalAmount = ValueNotifier<double>(0);
  ValueNotifier<double> customCharge = ValueNotifier<double>(0);

  void addChargeController(String chargeType) {
    if (!customChargeControllers.containsKey(chargeType)) {
      final controller = TextEditingController();
      controller.addListener(() {
        updateCustomCharge(chargeType, controller.text);
      });
      customChargeControllers[chargeType] = controller;
    }
  }

  List<CartItem> get closingStockItems => _closingStockItems;
  List<List<CartItem>> get savedBills => _savedBills;

  final List<Map<String, dynamic>> _addedVariances = [];

  List<Map<String, dynamic>> get addedVariances => _addedVariances;
  Map<String, TextEditingController?> customChargeControllers = {};
  List<CartItem> _cartItems = [];
  int _cartItemCount = 5;
  int get cartItemCount => _cartItemCount;

  double get totalWeight {
    double total = 0;

    // Calculate the weight of predefined variances
    total += _addedVariances.fold(
      0,
      (sum, variance) => sum + (variance['weight'] ?? 0),
    );

    return total;
  }

  void addVariance(Map<String, dynamic> variance) {
    _addedVariances.add(variance);
    notifyListeners(); // Notify listeners about the change
  }

  void removeVariance(Map<String, dynamic> variance) {
    _addedVariances.removeWhere(
      (item) => item['varianceName'] == variance['varianceName'],
    );
    notifyListeners();
  }

  get items => null;

  // Main Cart Methods
  void updateQuantity(int index, int quantity) {
    if (globals.cartItems.isNotEmpty &&
        index >= 0 &&
        index < globals.cartItems.length) {
      globals.cartItems[index].quantity.value = quantity;
    } else {}
    _recalculateTotal();
    notifyListeners();
  }

  void addItemToCart(CartItem newItem) {
    int existingItemIndex = -1;

    if (newItem.isBoxItem == 'no') {
      existingItemIndex = globals.cartItems.indexWhere(
        (item) =>
            item.isBoxItem == 'no' &&
            item.varianceName == newItem.varianceName &&
            item.itemName == newItem.itemName &&
            item.uom == newItem.uom &&
            item.weight == newItem.weight,
      );
    }

    if (existingItemIndex != -1) {
      globals.cartItems[existingItemIndex].quantity.value +=
          newItem.quantity.value;
    } else {
      globals.cartItems.add(newItem);
    }

    _cartItems = globals.cartItems;
    _recalculateTotal();
    notifyListeners();
  }

  void increaseQuantity(int index) {
    globals.cartItems[index].quantity.value++;
    _recalculateTotal();
    notifyListeners();
  }

  void decreaseQuantity(int index) {
    if (globals.cartItems[index].quantity.value > 1) {
      globals.cartItems[index].quantity.value--;
    } else {
      globals.cartItems.removeAt(index);
    }
    _recalculateTotal();
    notifyListeners();
  }

  // void clearCart() async {
  //   globals.cartItems.clear();
  //   _cartItems.clear();
  //   customChargeController.clear();
  //   notifyListeners();
  // }

  // Closing Stock Cart Methods

  void addItemToClosingStock(CartItem newItem) {
    int existingItemIndex = _closingStockItems.indexWhere(
      (item) => item.varianceName == newItem.varianceName,
    );
    if (existingItemIndex != -1) {
      _closingStockItems[existingItemIndex].quantity.value +=
          newItem.quantity.value;
    } else {
      _closingStockItems.add(newItem);
    }
    notifyListeners();
  }

  void increaseClosingStockQuantity(int index) {
    _closingStockItems[index].quantity.value++;
    notifyListeners();
  }

  void decreaseClosingStockQuantity(int index) {
    if (_closingStockItems[index].quantity.value > 1) {
      _closingStockItems[index].quantity.value--;
    } else {
      _closingStockItems.removeAt(index);
    }
    notifyListeners();
  }

  void clearClosingStockCart() {
    _closingStockItems.clear();
    notifyListeners();
  }

  // Save and Load Bill Methods

  void saveBill() {
    if (globals.cartItems.isNotEmpty) {
      if (_currentBillIndex == null) {
        _savedBills.add(List.from(globals.cartItems));
      } else {
        _savedBills[_currentBillIndex!] = List.from(globals.cartItems);
      }
      clearCart(); // Clear the cart after saving
      _currentBillIndex = null; // Reset the current bill index
      notifyListeners();
    }
  }

  void loadSavedBill(int index) {
    _currentBillIndex = index; // Set the current bill index
    globals.cartItems = List.from(
      _savedBills[index],
    ); // Load the saved bill into the cart
    notifyListeners();
  }

  void deleteSavedBill(int index) {
    _savedBills.removeAt(index);
    notifyListeners();
  }

  void deleteCurrentBill() {
    if (_currentBillIndex != null) {
      _savedBills.removeAt(_currentBillIndex!);
      _currentBillIndex = null;
      notifyListeners();
    }
  }

  // For multiple charges
  // void updateCustomCharge(String chargeType, String value) {
  //   // Initialize map if not already
  //   if (!_customChargeValues.containsKey(chargeType)) {
  //     _customChargeValues[chargeType] = 0.0;
  //   }

  //   _customChargeValues[chargeType] = double.tryParse(value) ?? 0.0;

  //   _recalculateTotal();
  // }

  // Optional: store all charge values
  Map<String, double> _customChargeValues = {};
  Map<String, double> get customChargeValues => _customChargeValues;
  void _recalculateTotal() {
    double total = 0;

    for (var item in _cartItems) {
      double itemTotal =
          item.finalPrice?.toDouble() ??
          ((item.uom.toLowerCase() == 'kgs' || item.uom.toLowerCase() == 'kg')
              ? (item.weight * item.quantity.value * item.pricePerKg).toDouble()
              : (item.quantity.value * item.pricePerKg).toDouble());
      total += itemTotal;
    }
    total += customCharge.value;
    totalAmount.value = total;
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();

    globals.cartItems.clear();
    _cartItems.clear();

    _recalculateTotal();
    notifyListeners();
  }

  double getTotalAmount() {
    double totalAmount = 0;

    for (var item in globals.cartItems) {
      double itemTotal = 0;

      if (item.finalPrice != null) {
        itemTotal = item.finalPrice!;
      } else if (item.quantity?.value != null) {
        if (item.uom?.toLowerCase() == 'kg' ||
            item.uom?.toLowerCase() == 'kgs') {
          itemTotal =
              (item.weight ?? 0) *
              (item.quantity!.value ?? 0) *
              (item.pricePerKg ?? 0);
        } else {
          itemTotal =
              (item.quantity!.value ?? 0).toDouble() * (item.pricePerKg ?? 0);
        }
      }

      totalAmount += itemTotal;
    }

    // Sum all custom charges
    for (var controller in customChargeControllers.values) {
      final charge = double.tryParse(controller!.text) ?? 0;
      totalAmount += charge;
    }

    return totalAmount;
  }

  void updateCart() {
    _recalculateTotal();
    notifyListeners();
  }

  void addItem(CartItem item) {
    cartItems.add(item);
    notifyListeners();
  }

  void removeItemById(String id) {
    final index = cartItems.indexWhere((e) => e.rowId == id);
    if (index == -1) return;

    cartItems.removeAt(index);
    notifyListeners();
  }

  void removeItemByVarianceName(String varianceName) {
    final index = globals.cartItems.indexWhere(
      (item) => item.varianceName == varianceName,
    );

    if (index < 0) {
      print("⚠ Cannot delete. Item not found: $varianceName");
      return;
    }

    globals.cartItems.removeAt(index);
    notifyListeners();
  }

  void updateCustomCharge(String chargeType, String value) {
    if (!customChargeControllers.containsKey(chargeType)) {
      customChargeControllers[chargeType] = TextEditingController(text: value);
    } else {
      customChargeControllers[chargeType]!.text = value;
    }
    _recalculateTotal();
    notifyListeners();
  }

  void setCustomChargeValue(String chargeType, String value) {
    updateCustomCharge(chargeType, value);
  }

  // double calculateSubtotal() {
  //   double subtotal = 0.0;
  //   for (var item in globals.cartItems) {
  //     subtotal += item.quantity.value * item.pricePerKg;
  //   }
  //   return subtotal;
  // }
  void removeItemByRowId(String rowId) {
    final index = globals.cartItems.indexWhere((e) => e.rowId == rowId);

    if (index == -1) return;

    globals.cartItems.removeAt(index);
    notifyListeners();
  }

  void removeItemByIndex(int index) {
    if (index < 0 || index >= cartItems.length) {
      print("⚠ Invalid index: $index");
      return;
    }
    cartItems.removeAt(index);
    notifyListeners();
  }

  // Remove item from the cart by index
  void removeItemFromCart(int index) {
    if (index < 0 || index >= globals.cartItems.length) {
      print("⚠ ERROR AVOIDED → removeItemFromCart invalid index: $index");
      return;
    }

    globals.cartItems.removeAt(index);
    notifyListeners();
  }

  void updateWeight(int index, double newWeight) {
    // Update weight for the item at the given index
    globals.cartItems[index].weight = newWeight;
    notifyListeners();
  }

  void showQuantityDialog(
    BuildContext context,
    int index,
    int currentQuantity,
    String uom,
  ) {
    final TextEditingController quantityController = TextEditingController(
      text: currentQuantity.toString(),
    );
    FocusNode customFocusNode = FocusNode();
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 40,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 260,
                  maxWidth: 320, // 🎯 Medium width dialog
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Update Quantity',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quantity Input Field
                    TextField(
                      controller: quantityController,
                      focusNode: customFocusNode,
                      readOnly: true, // block system keyboard
                      showCursor: true,
                      keyboardType: TextInputType.none,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 18,
                        ),
                        suffixText: uom,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ✅ Attach custom numeric keyboard
                    SizedBox(
                      height: 220,
                      child: Consumer<QtyKeyboardProvider>(
                        builder: (context, provider, _) {
                          // force numeric mode for quantity
                          if (!provider.isNumeric) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              provider.setNumeric(true);
                            });
                          }
                          return QtyCustomKeyboardWidgetAll2(
                            controller: quantityController,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final newQuantity = double.tryParse(
                                quantityController.text,
                              );
                              if (newQuantity == 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cannot add 0 quantity'),
                                  ),
                                );
                                return;
                              }
                              if (newQuantity != null && newQuantity >= 0) {
                                updateQuantity(index, newQuantity.toInt());
                                // if (uom == 'Pcs' || uom == 'Pkt') {
                                //   updateQuantity(index, newQuantity.toInt());
                                // } else {
                                //   updateWeight(index, newQuantity);
                                // }
                                Navigator.of(context).pop();
                              }
                              updateCart();
                              notifyListeners();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

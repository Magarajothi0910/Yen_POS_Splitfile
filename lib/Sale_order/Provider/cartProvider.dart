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
  final String varianceName;
  final String itemName;
  final String itemCode;
  final int pricePerKg;
  double? finalPrice;
  double itemWiseDiscount;
  double itemWiseDiscountAmount;
  double? discount;
  String? isBoxItem;
  final int tax;
  int? boxQuantity;
  final String uom; // Add the uom field
  int quantity;
  double weight;
  CartItem({
    required this.varianceName,
    required this.itemName,
    this.isBoxItem,
    this.boxQuantity,
    this.finalPrice,
    this.discount,
    required this.pricePerKg,
    required this.itemWiseDiscountAmount,
    required this.itemWiseDiscount,
    required this.tax,
    required this.itemCode,
    required this.uom, // Initialize uom
    required this.quantity,
    required this.weight,
  });
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _closingStockItems = []; // Closing stock cart
  late Box _cartBox;
  final List<List<CartItem>> _savedBills = [];
  int? _currentBillIndex; // Tracks the index of the currently loaded bill
  List<bool> itemSelections = [];
  void toggleItemSelection(int index) {
    itemSelections[index] = !itemSelections[index];
    notifyListeners();
  }

  CartProvider() {
    init();
  }
  Future<void> init() async {
    _cartBox = await Hive.openBox('cartBox');
  }

  List<CartItem> get closingStockItems => _closingStockItems;
  List<List<CartItem>> get savedBills => _savedBills;

  final List<Map<String, dynamic>> _addedVariances = [];
  final TextEditingController customChargeController = TextEditingController();
  List<Map<String, dynamic>> get addedVariances => _addedVariances;

  List<CartItem> _cartItems = [];
  int _cartItemCount = 5;
  int get cartItemCount => _cartItemCount;
  List<CartItem> get cartItems => _cartItems;

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
      globals.cartItems[index].quantity = quantity;
      notifyListeners();
    } else {}
  }

  void addItemToCart(CartItem newItem) {
    // Check if an item with the same name and UOM exists but with different attributes
    int existingItemIndex = globals.cartItems.indexWhere(
      (item) =>
          item.varianceName == newItem.varianceName &&
          item.itemName == newItem.itemName &&
          item.uom == newItem.uom &&
          item.weight == newItem.weight,
    );
    globals.cartItemCount = 2;

    if (existingItemIndex != -1) {
      // Update quantity for identical items
      globals.cartItems[existingItemIndex].quantity += newItem.quantity;
      _cartItems = globals.cartItems;
      notifyListeners();
    } else {
      // Add a new entry for items with different weights or attributes
      globals.cartItems.add(newItem);
      _cartItems = globals.cartItems;
      notifyListeners();
    }

    notifyListeners();
  }

  void increaseQuantity(int index) {
    globals.cartItems[index].quantity++;
    notifyListeners();
  }

  void decreaseQuantity(int index) {
    if (globals.cartItems[index].quantity > 1) {
      globals.cartItems[index].quantity--;
    } else {
      globals.cartItems.removeAt(index);
    }
    notifyListeners();
  }

  void clearCart() async {
    globals.cartItems.clear();

    // Clear Hive storage
    await _cartBox.clear();

    customChargeController.clear();
    notifyListeners();
  }

  // Closing Stock Cart Methods

  void addItemToClosingStock(CartItem newItem) {
    int existingItemIndex = _closingStockItems.indexWhere(
      (item) => item.varianceName == newItem.varianceName,
    );
    if (existingItemIndex != -1) {
      _closingStockItems[existingItemIndex].quantity += newItem.quantity;
    } else {
      _closingStockItems.add(newItem);
    }
    notifyListeners();
  }

  void increaseClosingStockQuantity(int index) {
    _closingStockItems[index].quantity++;
    notifyListeners();
  }

  void decreaseClosingStockQuantity(int index) {
    if (_closingStockItems[index].quantity > 1) {
      _closingStockItems[index].quantity--;
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

  double getTotalAmount() {
    double totalAmount = 0;

    for (var i = 0; i < globals.cartItems.length; i++) {
      var item = globals.cartItems[i];
      double itemTotal = 0;

      if (item.finalPrice != null) {
        itemTotal = item.finalPrice!;
      } else {
        if (item.uom == 'Kgs' || item.uom == 'Kg') {
          itemTotal = item.weight * item.quantity * item.pricePerKg;
        } else {
          itemTotal = item.quantity.toDouble() * item.pricePerKg;
        }
      }

      totalAmount += itemTotal;
    }

    notifyListeners();

    // Adding custom charge
    final customCharge = double.tryParse(customChargeController.text) ?? 0;
    print("custom charge: $customCharge");
    totalAmount += customCharge;

    notifyListeners();

    return totalAmount;
  }

  void updateCart() {
    notifyListeners();
  }

  void setCustomChargeValue(String value) {
    customChargeController.text = value;
    notifyListeners(); // this triggers UI rebuild
  }

  double calculateSubtotal() {
    double subtotal = 0.0;
    for (var item in globals.cartItems) {
      subtotal += item.quantity * item.pricePerKg;
    }
    return subtotal;
  }

  String get formattedSubtotal {
    final subtotal = calculateSubtotal();
    return NumberFormat.currency(
      symbol: '₹',
    ).format(subtotal); // Format as currency
  }

  // Remove item from the cart by index
  void removeItemFromCart(int index) {
    if (index >= 0 && index < globals.cartItems.length) {
      globals.cartItems.removeAt(index);
      notifyListeners();
    }
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

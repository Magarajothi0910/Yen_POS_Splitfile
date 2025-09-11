import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../globals.dart' as globals;

class modifyCartItem {
  final String itemName;
  final String variancename;
  final String itemCode;
  final int pricePerKg;
  final int tax;
  final String uom; // Add the uom field
  int quantity;
  double weight;

  modifyCartItem({
    required this.itemName,
    required this.variancename,
    required this.pricePerKg,
    required this.tax,
    required this.itemCode,
    required this.uom, // Initialize uom
    required this.quantity,
    required this.weight,
  });
}

class ModifyCartProvider extends ChangeNotifier {
  final List<modifyCartItem> _closingStockItems = []; // Closing stock cart
  TextEditingController searchController = TextEditingController();

  final List<List<modifyCartItem>> _savedBills = [];
  int? _currentBillIndex; // Tracks the index of the currently loaded bill

  List<modifyCartItem> get closingStockItems => _closingStockItems;
  List<List<modifyCartItem>> get savedBills => _savedBills;

  final List<Map<String, dynamic>> _addedVariances = [];

  List<Map<String, dynamic>> get addedVariances => _addedVariances;
  List<Map<String, dynamic>> filteredItems = [];

  double get totalWeight {
    double total = 0;

    // Calculate the weight of predefined variances
    total += _addedVariances.fold(
        0, (sum, variance) => sum + (variance['weight'] ?? 0));

    return total;
  }

  void addVariance(Map<String, dynamic> variance) {
    _addedVariances.add(variance);
    notifyListeners(); // Notify listeners about the change
  }

  void removeVariance(Map<String, dynamic> variance) {
    _addedVariances.removeWhere(
        (item) => item['varianceName'] == variance['varianceName']);
    notifyListeners();
  }

  get items => null;

  // Main Cart Methods
  void updateQuantity(int index, int quantity) {

    if (globals.modifyItems.isNotEmpty &&
        index >= 0 &&
        index < globals.modifyItems.length) {
      globals.modifyItems[index].quantity = quantity;
      notifyListeners();
    } else {
    }
  }

  void addItemToCart(modifyCartItem newItem) {
    // Check if an item with the same name and UOM exists but with different attributes
    int existingItemIndex = globals.modifyItems.indexWhere((item) =>
        item.variancename == newItem.variancename &&
        item.uom == newItem.uom &&
        item.weight == newItem.weight);

    if (existingItemIndex != -1) {
      // Update quantity for identical items
      globals.modifyItems[existingItemIndex].quantity += newItem.quantity;
    } else {
      // Add a new entry for items with different weights or attributes
      globals.modifyItems.add(newItem);
    }

    notifyListeners();
  }

  // void updateItemCount(String itemName, int newCount) {
  //   // Find the item in the cart and update its count
  //   for (var cartItem in cartItems) {
  //     if (cartItem.name == itemName) {
  //       cartItem.count = newCount;
  //       break;
  //     }
  //   }
  //   notifyListeners();
  // }

  void increaseQuantity(int index) {
    globals.modifyItems[index].quantity++;
    notifyListeners();
  }

  void decreaseQuantity(int index) {
    if (globals.modifyItems[index].quantity > 1) {
      globals.modifyItems[index].quantity--;
    } else {
      globals.modifyItems.removeAt(index);
    }
    notifyListeners();
  }

  void clearCart() {
    globals.modifyItems.clear();
    notifyListeners();
  }

  // Closing Stock Cart Methods

  void addItemToClosingStock(modifyCartItem newItem) {
    int existingItemIndex = _closingStockItems
        .indexWhere((item) => item.itemName == newItem.itemName);
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
    if (globals.modifyItems.isNotEmpty) {
      if (_currentBillIndex == null) {
        _savedBills.add(List.from(globals.modifyItems));
      } else {
        _savedBills[_currentBillIndex!] = List.from(globals.modifyItems);
      }
      clearCart(); // Clear the cart after saving
      _currentBillIndex = null; // Reset the current bill index
      notifyListeners();
    }
  }

  void loadSavedBill(int index) {
    _currentBillIndex = index; // Set the current bill index
    globals.modifyItems =
        List.from(_savedBills[index]); // Load the saved bill into the cart
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

    for (var item in globals.modifyItems) {
      if (item.uom == 'Kgs') {
        // Calculate based on weight for items in kilograms
        totalAmount += item.weight * item.quantity * item.pricePerKg;
      } else {
        // Calculate based on quantity for items in pieces
        totalAmount += item.quantity * item.pricePerKg;
      }
    }

    return totalAmount;
  }

  double calculateSubtotal() {
    double subtotal = 0.0;
    for (var item in globals.modifyItems) {
      subtotal += item.quantity * item.pricePerKg;
    }
    return subtotal;
  }

  String get formattedSubtotal {
    final subtotal = calculateSubtotal();
    return NumberFormat.currency(symbol: '₹')
        .format(subtotal); // Format as currency
  }

  // Remove item from the cart by index
  void removeItemFromCart(int index) {
    if (index >= 0 && index < globals.modifyItems.length) {
      globals.modifyItems.removeAt(index);
      notifyListeners();
    }
  }

  void updateWeight(int index, double newWeight) {
    // Update weight for the item at the given index
    globals.modifyItems[index].weight = newWeight;
    notifyListeners();
  }

  void showQuantityDialog(
      BuildContext context, int index, int currentQuantity, String uom) {
    final TextEditingController quantityController =
        TextEditingController(text: currentQuantity.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0), // Rounded corners
          ),
          title: const Text(
            'Update Quantity',
            style: TextStyle(
              color: Colors.black, // Primary color for title
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: uom != 'Pcs' &&
                      uom != 'Pkt', // Allow decimal only if not "Pcs" or "Pkt"
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(
                      uom == 'Pcs' || uom == 'Pkt' ? r'^\d+$' : r'^\d*\.?\d*',
                    ),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Enter quantity',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(8.0), // Rounded input border
                  ),
                  filled: true,
                  fillColor:
                      Colors.grey[200], // Light background color for input
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Update quantity based on UOM and close the dialog

                final newQuantity = double.tryParse(quantityController.text);
                if (newQuantity == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cannot addd 0 quantity'),
                    ),
                  );
                  return;
                }
                if (newQuantity != null && newQuantity >= 0) {
                  // For "Pcs" or "Pkt", use integer values
                  if (uom == 'Pcs' || uom == 'Pkt') {
                    updateQuantity(index, newQuantity.toInt());
                  } else {
                    // For other UOMs like "Kgs", accept the float value
                    updateWeight(index, newQuantity);
                  }
                }
                Navigator.of(context).pop(); // Close the dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      8.0), // Rounded corners for the button
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

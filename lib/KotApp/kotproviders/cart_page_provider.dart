// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';

// import '../models/salecalculator.dart';

// class CurrentSaleProvider with ChangeNotifier {
//   late SaleCalculator _saleCalculator =
//       SaleCalculator([]); // Initialize with an empty list

//   List<Map<String, dynamic>> _currentSaleItems = [];
//   final double _discountPercentage = 0.0; // Initial discount percentage
//   final double _customCharge = 0.0; // New property for custom charge
//   double get discountPercentage => _discountPercentage;
//   double sgst = 0.0; // SGST amount
//   double cgst = 0.0; // CGST amount

//   double get sgstAmount => sgst; // Add getter for SGST
//   double get cgstAmount => cgst; // Add getter for CGST
//   List<Map<String, dynamic>> get currentSaleItems => _currentSaleItems;
//   double get customCharge => _customCharge; // Getter for custom charge

//   double sgstRate = 0.0; // Rate in percentage
//   double cgstRate = 0.0; // Rate in percentage

//   // Add getters for SGST and CGST rates
//   double get sgstRatePercentage => sgstRate;
//   double get cgstRatePercentage => cgstRate;

//   String _selectedOption = 'TakeAway'; // Set default to "Take Away"

//   String get selectedOption => _selectedOption;
//   String _status = ''; // Track the current sale status
//   String get saleStatus => _status;

//   String? _holdBillId; // Store the selected hold bill ID

//   String? get holdBillId => _holdBillId;

//   void setHoldBillId(String id) {
//     _holdBillId = id;
//     notifyListeners();
//   }

//   void selectOption(String option) {
//     _selectedOption = option;
//     _status = ''; // Reset the sale status
//     notifyListeners(); // Notify the UI of changes
//   }

//   set discountPercentage(double value) {
//     _saleCalculator.discountPercentage = value;
//     notifyListeners(); // Notify listeners to update UI
//   }

//   set customCharge(double value) {
//     _saleCalculator.customCharge = value;
//     notifyListeners();
//   }

//   void loadItemsFromBill(List<Map<String, dynamic>> items) {
//     _currentSaleItems = items;
//     _status =
//         'active'; // Assuming you want to set it to 'active' to resume the transaction
//     _saleCalculator = SaleCalculator(
//         _currentSaleItems); // Reinitialize the calculator with the new items
//     notifyListeners(); // Notify the UI to update totals and other dependent UI components
//   }

//   void clearItems() async {
//     _currentSaleItems.clear();
//     var box = await Hive.openBox('cartBox');
//     await box.put('cartItems', []);
//     _saleCalculator = SaleCalculator(_currentSaleItems); // Reset SaleCalculator
//     notifyListeners(); // Notify listeners after clearing the items
//   }

//   void removeItem(int index) async {
//     _currentSaleItems.removeAt(index);
//     var box = await Hive.openBox('cartBox');
//     await box.put('cartItems', _currentSaleItems);
//     notifyListeners(); // Notify listeners after removing the item
//   }

//   double calculateTotal() {
//     return _saleCalculator.calculateTotal();
//   }

//   double calculateDiscountAmount() {
//     return _saleCalculator.calculateDiscountAmount();
//   }

//   String buildQuantityPriceDisplay(Map<String, dynamic> item) {
//     return _saleCalculator.buildQuantityPriceDisplay(item);
//   }

//   // String buildQuantityPriceDisplay(Map<String, dynamic> item) {
//   //   final String uom = item['varianceData']['variance_Uom'].toLowerCase();
//   //   final double price = item['varianceData']['variance_Defaultprice']
//   //       .toDouble(); // Ensure price is a double
//   //   final double quantity =
//   //       (item['quantity'] ?? 1).toDouble(); // Ensure quantity is a double

//   //   String quantityDisplay = '';
//   //   String weightQuantityDidpay = '';
//   //   // Check if the unit of measure is in kilograms or grams
//   //   if (uom == 'kg' || uom == 'kgs') {
//   //     if (quantity >= 1) {
//   //       quantityDisplay = '${quantity.toStringAsFixed(1)} kg'; // Display in kg
//   //     } else {
//   //       // If quantity is less than 1 kg, convert to grams
//   //       double grams = quantity * 1000;
//   //       quantityDisplay = '${grams.toStringAsFixed(1)} g'; // Display in grams
//   //     }
//   //   } else {
//   //     // For other units, assume the quantity is in pieces or count
//   //     quantityDisplay = '${quantity.toInt()} $uom';
//   //   }

//   //   // Print the result in the console
//   //   print(s
//   //       'Quantity: $quantityDisplay x ₹ ${price.toStringAsFixed(2)} per $uom');
//   //   print('Quantity: $quantityDisplay');

//   //   // Return the formatted string for UI or other purposes
//   //   return '$quantityDisplay';
//   // }

//   double calculateItemTotal(Map<String, dynamic> item) {
//     return _saleCalculator.calculateItemTotal(item);
//   }

//   void updateItemQuantity(int index, double newQuantity) async {
//     _currentSaleItems[index]['quantity'] = newQuantity;
//     _saleCalculator = SaleCalculator(
//         _currentSaleItems); // Update SaleCalculator with the new items
//     var box = await Hive.openBox('cartBox');
//     await box.put('cartItems', _currentSaleItems);
//     notifyListeners(); // Notify listeners after updating the item quantity
//   }

//   Future<void> saveBill(BuildContext context) async {
//     if (_currentSaleItems.isEmpty) {
//       // If there are no items to save, show a snackbar notification
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text(
//             'No items to save!',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 2),
//           behavior: SnackBarBehavior.floating,
//           margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//       return;
//     }

//     // Open the Hive box for invoices
//     var holdinvoiceBox = await Hive.openBox('holdinvoiceBox');

//     // Set the status for each item to 'hold'
//     List<Map<String, dynamic>> itemsWithStatus =
//         _currentSaleItems.map((item) => {...item, 'status': 'hold'}).toList();

//     // Add the bill data to the invoiceBox
//     clearItems(); // This will clear the cart and reset the total

//     // Set the sale status to 'hold' without clearing items
//     _status = 'hold';
//     notifyListeners();

//     // Show a snackbar notification indicating the bill was saved successfully
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text(
//           'Bill saved as hold and printed',
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
//     // clearItems();
//   }
// }

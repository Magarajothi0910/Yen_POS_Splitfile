import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Sale_order/Widgets/sales_caculate.dart';

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

  void addItemToCart(Map<String, dynamic> newItem) async {
    bool exists = _currentSaleItems.any(
      (item) =>
          item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
          item['varianceData']['varianceName'] ==
              newItem['varianceData']['varianceName'],
    );

    if (exists) {
      // Update quantity for existing item
      _currentSaleItems = _currentSaleItems.map((item) {
        if (item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
            item['varianceData']['varianceName'] ==
                newItem['varianceData']['varianceName']) {
          item['quantity'] += newItem['quantity'];
        }
        return item;
      }).toList();
    } else {
      // Insert new item at the beginning of the list
      _currentSaleItems.insert(0, newItem);
    }

    _saleCalculator = SaleCalculator(_currentSaleItems); // Recalculate totals

    // Save updated cart to Hive
    var box = await Hive.openBox('cartBox');
    await box.put('cartItems', _currentSaleItems); // Save updated list

    notifyListeners(); // Notify UI to rebuild
  }

  void addItemToCartExpressMode(Map<String, dynamic> newItem) async {
    bool exists = _currentSaleItems.any(
      (item) =>
          item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
          item['varianceData']['varianceName'] ==
              newItem['varianceData']['varianceName'],
    );

    if (exists) {
      // Update quantity for existing item
      _currentSaleItems = _currentSaleItems.map((item) {
        if (item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
            item['varianceData']['varianceName'] ==
                newItem['varianceData']['varianceName']) {
          item['quantity'] += newItem['quantity'];
        }
        return item;
      }).toList();
    } else {
      // Insert new item at the beginning of the list
      _currentSaleItems.insert(0, newItem);
    }

    _saleCalculator = SaleCalculator(_currentSaleItems); // Recalculate totals

    // Save updated cart to Hive
    var box = await Hive.openBox('cartBox');
    await box.put('cartItems', _currentSaleItems); // Save updated list

    notifyListeners(); // Notify UI to rebuild
  }

  void addItemsToCurrentSale(List<Map<String, dynamic>> newItems) {
    for (var newItem in newItems) {
      bool exists = _currentSaleItems.any(
        (item) =>
            item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
            item['varianceData']['varianceName'] ==
                newItem['varianceData']['varianceName'],
      );

      if (exists) {
        // If the item already exists, update its quantity
        _currentSaleItems = _currentSaleItems.map((item) {
          if (item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
              item['varianceData']['varianceName'] ==
                  newItem['varianceData']['varianceName']) {
            item['quantity'] += newItem['quantity'];
          }
          return item;
        }).toList();
      } else {
        // If the item is new, add it to the list
        _currentSaleItems.add(newItem);
      }
    }

    _saleCalculator = SaleCalculator(_currentSaleItems); // Recalculate totals
    notifyListeners(); // Notify the UI to update
  }

  Future<void> loadCartItems() async {
    var box = await Hive.openBox('cartBox');
    List<dynamic> rawItems = box.get('cartItems', defaultValue: []);
    _currentSaleItems = rawItems
        .map((item) => Map<String, dynamic>.from(item))
        .toList(); // Load all items, including new additions
    _saleCalculator = SaleCalculator(_currentSaleItems);

    notifyListeners(); // Notify UI to rebuild
  }

  void loadItemsFromBill(
    List<dynamic>? items, {
    bool merge = false,
    String? holdId,
  }) {
    if (items == null || items.isEmpty) {
      return;
    }

    if (!merge) {
      _currentSaleItems.clear();
    }

    for (var newItem in items) {
      if (newItem == null ||
          !newItem.containsKey('itemData') ||
          !newItem.containsKey('varianceData')) {
        continue;
      }

      bool exists = _currentSaleItems.any(
        (item) =>
            item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
            item['varianceData']['varianceName'] ==
                newItem['varianceData']['varianceName'],
      );

      if (!exists) {
        _currentSaleItems.add(newItem);
      }
    }

    _currentHoldId = holdId;
    _saleCalculator = SaleCalculator(_currentSaleItems);
    notifyListeners();
  }

  void clearItems() async {
    _currentSaleItems.clear();
    var box = await Hive.openBox('cartBox');
    await box.put('cartItems', []);
    _saleCalculator = SaleCalculator(_currentSaleItems); // Reset SaleCalculator
    notifyListeners(); // Notify listeners after clearing the items
  }

  void removeItem(int index) {
    // If there's only one item left, remove it directly
    if (_currentSaleItems[index]['quantity'] <= 1) {
      _currentSaleItems.removeAt(index);
    } else {
      // Otherwise, just decrease the quantity
      _currentSaleItems.removeAt(index);
    }

    // After modifying the list, make sure to update your state management to reflect this change
    notifyListeners();
  }

  double calculateTotal() {
    return _saleCalculator.calculateTotal();
  }

  double calculateDiscountAmount() {
    return _saleCalculator.calculateDiscountAmount();
  }

  String buildQuantityPriceDisplay(Map<String, dynamic> item) {
    return _saleCalculator.buildQuantityPriceDisplay(item);
  }

  double calculateItemTotal(Map<String, dynamic> item) {
    return _saleCalculator.calculateItemTotal(item);
  }

  void updateItemQuantity(int index, dynamic newQuantity) async {
    _currentSaleItems[index]['quantity'] = newQuantity;
    _saleCalculator = SaleCalculator(
      _currentSaleItems,
    ); // Update SaleCalculator with the new items
    var box = await Hive.openBox('cartBox');
    await box.put('cartItems', _currentSaleItems);
    notifyListeners(); // Notify listeners after updating the item quantity
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

  Future<void> saveBillsplitBill(
    BuildContext context,
    List<List<Map<String, dynamic>>> tickets,
    List<String> ticketTitles,
  ) async {
    if (tickets.isEmpty || tickets.every((ticket) => ticket.isEmpty)) {
      _showSnackBar(context, 'No items to save!', Colors.red);
      return;
    }

    var box = await Hive.openBox('cartBox');

    for (int i = 0; i < tickets.length; i++) {
      // 🔹 Prepare Items for Hive Storage
      List<Map<String, dynamic>> itemsWithStatus = tickets[i]
          .map((item) => {...item, 'status': 'hold'})
          .toList();

      // 🔹 Generate unique Hold ID
      var randomId = generatetheholdrandomId();
      String ticketName = ticketTitles[i]; // Ticket name
      String ticketType = "SplitBill"; // Default type

      // 🔹 Prepare Data for Hive
      Map<String, dynamic> billData = {
        'holdId': randomId,
        'date': DateTime.now().toIso8601String(),
        'items': itemsWithStatus,
        'total': calculateTotal2(itemsWithStatus), // Calculate per ticket total
        'status': 'hold',
        "ticketType": ticketType,
        "ticketName": ticketName,
      };

      // ✅ Save in Hive
      await box.add(billData);

      // 🔹 Prepare Data for API
      // ignore: unused_local_variable
      Map<String, dynamic> apiData = {
        "holdId": randomId.toString(),
        "itemId": itemsWithStatus
            .map((item) => item['itemData']['itemId'] ?? "")
            .toList(),
        "itemCode": itemsWithStatus
            .map((item) => item['varianceData']['varianceitemCode'] ?? "")
            .toList(),
        "itemName": itemsWithStatus
            .map((item) => item['varianceData']['varianceName'] ?? "")
            .toList(),
        "weight": itemsWithStatus
            .map((item) => item['varianceData']['variance_Uom'] ?? "")
            .toList(),
        "price": itemsWithStatus
            .map(
              (item) =>
                  item['varianceData']['variance_Defaultprice'].toString(),
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
        "totalAmount": calculateTotal2(itemsWithStatus).toString(),
        "status": "hold",
        "ticketType": ticketType,
        "ticketName": ticketName,
        "date": DateTime.now().toIso8601String(),
        "time": DateTime.now().toIso8601String(),
        "netPrice": calculateTotal2(itemsWithStatus).toString(),
        "discountPercentage": "0",
        "discountAmount": "0",
        "customCharge": "0",
        "employeeName": "",
        "phoneNumber": "0",
        "paymentType": "",
      };
    }

    // ✅ Clear current items after saving split bills
    clearItems();
  }

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
}
    // Clear items after saving
    // clearItems();
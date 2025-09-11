import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'isolation/sales_caculate.dart';

class CurrentSaleProvider with ChangeNotifier {
  late SaleCalculator _saleCalculator =
      SaleCalculator([]); // Initialize with an empty list

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
    bool exists = _currentSaleItems.any((item) =>
        item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
        item['varianceData']['varianceName'] ==
            newItem['varianceData']['varianceName']);

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
    bool exists = _currentSaleItems.any((item) =>
        item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
        item['varianceData']['varianceName'] ==
            newItem['varianceData']['varianceName']);

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
      bool exists = _currentSaleItems.any((item) =>
          item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
          item['varianceData']['varianceName'] ==
              newItem['varianceData']['varianceName']);

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

  void loadItemsFromBill(List<dynamic>? items,
      {bool merge = false, String? holdId}) {
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

      bool exists = _currentSaleItems.any((item) =>
          item['itemData']['itemId'] == newItem['itemData']['itemId'] &&
          item['varianceData']['varianceName'] ==
              newItem['varianceData']['varianceName']);

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

  // String buildQuantityPriceDisplay(Map<String, dynamic> item) {
  //   final String uom = item['varianceData']['variance_Uom'].toLowerCase();
  //   final double price = item['varianceData']['variance_Defaultprice']
  //       .toDouble(); // Ensure price is a double
  //   final double quantity =
  //       (item['quantity'] ?? 1).toDouble(); // Ensure quantity is a double

  //   String quantityDisplay = '';
  //   String weightQuantityDidpay = '';
  //   // Check if the unit of measure is in kilograms or grams
  //   if (uom == 'kg' || uom == 'kgs') {
  //     if (quantity >= 1) {
  //       quantityDisplay = '${quantity.toStringAsFixed(1)} kg'; // Display in kg
  //     } else {
  //       // If quantity is less than 1 kg, convert to grams
  //       double grams = quantity * 1000;
  //       quantityDisplay = '${grams.toStringAsFixed(1)} g'; // Display in grams
  //     }
  //   } else {
  //     // For other units, assume the quantity is in pieces or count
  //     quantityDisplay = '${quantity.toInt()} $uom';
  //   }

  //   // Print the result in the console
  //   print(s
  //       'Quantity: $quantityDisplay x ₹ ${price.toStringAsFixed(2)} per $uom');
  //   print('Quantity: $quantityDisplay');

  //   // Return the formatted string for UI or other purposes
  //   return '$quantityDisplay';
  // }

  double calculateItemTotal(Map<String, dynamic> item) {
    return _saleCalculator.calculateItemTotal(item);
  }

  void updateItemQuantity(int index, dynamic newQuantity) async {
    _currentSaleItems[index]['quantity'] = newQuantity;
    _saleCalculator = SaleCalculator(
        _currentSaleItems); // Update SaleCalculator with the new items
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
    List<Map<String, dynamic>> itemsWithStatus =
        _currentSaleItems.map((item) => {...item, 'status': 'hold'}).toList();

    var randomId = generatetheholdrandomId();

    Map<String, dynamic> billData = {
      'holdId': randomId,
      'date': DateTime.now().toIso8601String(),
      'items': itemsWithStatus,
      'total': calculateTotal(),
      'status': 'hold',
    };
    // Map<String, dynamic> billDataforhive = {
    //   'holdId': randomId,
    //   'date': DateTime.now().toIso8601String(),
    //   'items': itemsWithStatus,
    //   'total': calculateTotal(),
    //   'status': 'hold',
    // };

    // Print the data to console
    // print("Bill Data for Hive: $billDataforhive");

    // Transform `itemsWithStatus` into API-compatible format
    // ignore: unused_local_variable
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
          .map((item) =>
              item['varianceData']['variance_Defaultprice'].toString())
          .toList(),
      "category": itemsWithStatus
          .map((item) => item['itemData']['category'] ?? "")
          .toList(),
      "qty":
          itemsWithStatus.map((item) => item['quantity'].toString()).toList(),
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
      "ticketName": ""
    };

    // Post the bill data to the FastAPI endpoint
    // try {
    //   final url = Uri.parse('http://192.168.1.130:8888/fastapi/holds/');
    //   final response = await http.post(
    //     url,
    //     headers: {'Content-Type': 'application/json'},
    //     body: jsonEncode(hivedatpostsapledata),
    //   );

    //   if (response.statusCode == 200 || response.statusCode == 201) {
    //     // Show success message
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(
    //           'Bill saved as hold (Hold ID: $randomId)',
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
    //   } else {
    //     // Handle server errors
    //     print('Failed to post data to server: ${response.statusCode}');
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(
    //           'Failed to post data to server: ${response.statusCode}',
    //           style: TextStyle(fontWeight: FontWeight.bold),
    //         ),
    //         backgroundColor: Colors.red,
    //         duration: Duration(seconds: 2),
    //       ),
    //     );
    //   }
    // } catch (error) {
    //   // Handle network errors
    //   print('Network error: $error');
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text(
    //         'Network error: $error',
    //         style: TextStyle(fontWeight: FontWeight.bold),
    //       ),
    //       backgroundColor: Colors.red,
    //       duration: Duration(seconds: 2),
    //     ),
    //   );
    // }

    await box.add(billData);
    _showSnackBar(
        context, 'Bill saved as hold (Hold ID: $randomId)', Colors.green);
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
        content: Text(
          message,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> saveBillsplitBill(
      BuildContext context,
      List<List<Map<String, dynamic>>> tickets,
      List<String> ticketTitles) async {
    if (tickets.isEmpty || tickets.every((ticket) => ticket.isEmpty)) {
      _showSnackBar(context, 'No items to save!', Colors.red);
      return;
    }

    var box = await Hive.openBox('cartBox');

    for (int i = 0; i < tickets.length; i++) {
      // 🔹 Prepare Items for Hive Storage
      List<Map<String, dynamic>> itemsWithStatus = tickets[i]
          .map((item) => {
                ...item,
                'status': 'hold',
              })
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
        "ticketName": ticketName
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
            .map((item) =>
                item['varianceData']['variance_Defaultprice'].toString())
            .toList(),
        "category": itemsWithStatus
            .map((item) => item['itemData']['category'] ?? "")
            .toList(),
        "qty":
            itemsWithStatus.map((item) => item['quantity'].toString()).toList(),
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

      // ✅ Post Data to API
      // try {
      //   final url = Uri.parse('http://192.168.1.130:8888/fastapi/holds/');
      //   final response = await http.post(
      //     url,
      //     headers: {'Content-Type': 'application/json'},
      //     body: jsonEncode(apiData),
      //   );

      //   if (response.statusCode == 200 || response.statusCode == 201) {
      //     print(
      //         "✅ API Success: Ticket $ticketName saved with Hold ID $randomId");
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         content: Text("Ticket $ticketName saved successfully."),
      //         backgroundColor: Colors.green,
      //       ),
      //     );
      //   } else {
      //     print("❌ API Error: ${response.statusCode}");
      //   }
      // } catch (error) {
      //   print("❌ Network Error: $error");
      // }
    }

    // ✅ Clear current items after saving split bills
    clearItems();
  }

  // double calculateTotal2(List<Map<String, dynamic>> items) {
  //   return items.fold(
  //       0.0,
  //       (sum, item) =>
  //           sum + (item['variance_Defaultprice'] * item['quantity']));
  // }

  // Future<void> saveBill(BuildContext context) async {
  //   if (_currentSaleItems.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: const Text(
  //           'No items to save!',
  //           style: TextStyle(fontWeight: FontWeight.bold),
  //         ),
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 2),
  //         behavior: SnackBarBehavior.floating,
  //         margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //       ),
  //     );
  //     return;
  //   }

  //   // Open the Hive box for invoices
  //   var holdinvoiceBox = await Hive.openBox('cartBox');

  //   // Set the status for each item to 'hold'
  //   List<Map<String, dynamic>> itemsWithStatus =
  //       _currentSaleItems.map((item) => {...item, 'status': 'hold'}).toList();
  //   print("HO${itemsWithStatus}");
  //   // Generate a unique hold bill ID
  //   var randomId = generatetheholdrandomId();

  //   // Prepare the bill data for Hive and API
  //   Map<String, dynamic> billDataforhive = {
  //     'holdId': randomId,
  //     'date': DateTime.now().toIso8601String(),
  //     'items': itemsWithStatus,
  //     'total': calculateTotal(),
  //     'status': 'hold',
  //   };
  //   Map<String, dynamic> hivedatpostsapledata = {
  //     "itemId": ["string"],
  //     "itemName": ["string"],
  //     "itemCode": ["string"],
  //     "weight": ["string"],
  //     "price": ["string"],
  //     "category": ["string"],
  //     "qty": ["string"],
  //     "amount": ["string"],
  //     "tax": ["string"],
  //     "uom": ["string"],
  //     "totalAmount": 0,
  //     "totalAmount2": 0,
  //     "totalAmount3": 0,
  //     "status": "string",
  //     "branchId": 0,
  //     "branch": "string",
  //     "discountPercentage": 0,
  //     "discountAmount": 0,
  //     "employeeName": "string",
  //     "phoneNumber": 0,
  //     "customCharge": 0,
  //     "netPrice": 0,
  //     "invoiceNo": 0,
  //     "date": DateTime.now().toIso8601String(),
  //     "time": DateTime.now().toIso8601String(),
  //     "paymentType": "string",
  //     "salesType": "string",
  //     "salesReturn": "string",
  //     "salesReturnNumber": 0,
  //     "type": "string",
  //     "salesOrderNumber": "string",
  //     "customerName": "string",
  //     "deliveryDate": "string",
  //     "deliveryTime": "string",
  //     "event": "string",
  //     "advance": "string",
  //     "orderPreference": "string",
  //     "deliveryPreference": "string",
  //     "orderDate": "string",
  //     "orderTime": "string",
  //     "remark": "string",
  //     "orderInvoiceNo": "string",
  //     "invoiceDate": "string",
  //     "cash": "string",
  //     "upi": "string",
  //     "card": "string",
  //     "deliveryPartner": "string",
  //     "otherPayment": "string",
  //     "deliveryPartnerName": "string",
  //     "shiftNumber": "string",
  //     "shiftId": "string",
  //     "deliveryLocation": "string",
  //     "phoneNumber2": "string",
  //     "preinvoiceId": "string"
  //   };
  //   // Save the bill to Hive
  //   await holdinvoiceBox.add(billDataforhive);

  //   // Post the bill data to the FastAPI endpoint
  //   try {
  //     final url = Uri.parse('http://192.168.1.130:8888/fastapi/holds/');
  //     final response = await http.post(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode(hivedatpostsapledata),
  //     );

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       // Show success message
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             'Bill saved as hold (Hold ID: $randomId)',
  //             style: TextStyle(fontWeight: FontWeight.bold),
  //           ),
  //           backgroundColor: Colors.green,
  //           duration: const Duration(seconds: 2),
  //           behavior: SnackBarBehavior.floating,
  //           margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(10),
  //           ),
  //         ),
  //       );
  //     } else {
  //       // Handle server errors
  //       print('Failed to post data to server: ${response.statusCode}');
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             'Failed to post data to server: ${response.statusCode}',
  //             style: TextStyle(fontWeight: FontWeight.bold),
  //           ),
  //           backgroundColor: Colors.red,
  //           duration: Duration(seconds: 2),
  //         ),
  //       );
  //     }
  //   } catch (error) {
  //     // Handle network errors
  //     print('Network error: $error');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           'Network error: $error',
  //           style: TextStyle(fontWeight: FontWeight.bold),
  //         ),
  //         backgroundColor: Colors.red,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //   }
  //   clearItems();
  // }

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
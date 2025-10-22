import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/Audio%20Player/audio_provider.dart';
import 'package:yenpos/Global/Model/branch_model.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';

import 'package:yenpos/Global/globals_data.dart' as globalsData;
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Models/approval_order_model.dart';
import 'package:yenpos/Sale_order/Models/held_order_model.dart';
import 'package:yenpos/Sale_order/Models/sale_order_model.dart';
import 'package:yenpos/Sale_order/Models/sales_invoicemodel.dart';
import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Sale_order/Print_Receipt/salesOrder_print.dart';
import 'package:yenpos/Sale_order/Print_Receipt/so_placeorder_payment_print.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Provider/saveAudioandImageFile.dart';
import 'package:yenpos/Sale_order/Screens/create_sales_order.dart';
import 'package:yenpos/Sale_order/Widgets/storetype_selection_dialogue.dart';
import 'package:yenpos/Server_Client/websocketService.dart';

// import 'package:yenpos/screens/take_away_orders/screens/create_salesOrder.dart/create_sales_order.dart';
import '../../Global/Provider/branchSelection_provider.dart';

import 'cartProvider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http_parser/http_parser.dart';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import '../../../Global/globals_data.dart' as globalbranch;
import 'modifyOrderProvider.dart';

class CustomerScreenProvider with ChangeNotifier {
  late salesOrderReceiptPrinter receiptPrinter;
  late salesInvoiceReceiptPrinter
  invoiceReceiptPrinter; // Separate printer for invoices
  bool isRequestInProgress = false; // Added variable definition

  //from kot payment variable
  double orderAmount = 0.0;
  double discount = 0;
  double customCharge = 0;
  double totalAdvance = 0;
  double deductedAmount = 0;
  double totalAmount = 0.0;

  CustomerScreenProvider() {
    // Initialize printers
    receiptPrinter = salesOrderReceiptPrinter(
      employeeNameController: TextEditingController(),
      customerNumberController: TextEditingController(),
      discountController: 0.0,
      customChargeController: 0.0,
      selectedPaymentOptionValue: '',
      totalAmount: 0.0,
      advanceAmount: [],
      balanceAmount: 0.0,
      customerType: '',
      deliveryDateprint: '',
      deliveryTimeprint: '',
      customAmountController: TextEditingController(),
      selectedPaymentOption: [],
      saleOrderNo: '',
      discountAmountController: 0.0,
      selectedPaymentOptionAmount: [],

      advanceDateTime: [],
      totalAmount2: 0.0,
      finalPrice: 0.0,
      discountAmount: 0.0,
      // currentPatchId: '',
    );

    invoiceReceiptPrinter = salesInvoiceReceiptPrinter(
      employeeNameController: TextEditingController(),
      customerNumberController: TextEditingController(),
      discountController: 0.0,
      customChargeController: 0.0,
      selectedPaymentOptionValue: '',
      totalAmount: 0.0,
      advanceAmount: 0.0,
      balanceAmount: 0.0,
      customerType: '',
      deliveryDateprint: '',
      deliveryTimeprint: '',
      customAmountController: TextEditingController(),
      selectedPaymentOption: '',
    );

    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);

    _initWebSocket();
  }

  TextEditingController otherEventController = TextEditingController();
  TextEditingController combinedController = TextEditingController();

  late WebSocketChannel _channel;
  final Razorpay _razorpay = Razorpay();
  void _initWebSocket() {
    // Replace these with your actual server IP and port defined in globals.
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://${globals.serverip}:${globals.port}'),
    );
    // Listen for messages from the server.
    _channel.stream.listen(
      (data) {
        // print('Received dataCustomerProvider: $data');
        // WebSocketService();
        WebSocketService(
          CustomerScreenProvider(),
          SalesInvoiceReceiptPrinter(),
        ).handleMessage(data);
      },
      onError: (error) {
        // print('WebSocket error: $error');
      },
    );
  }

  void onImagesSelected(File? image1, File? image2) async {
    if (image1 != null && image2 != null) {
      final box = Hive.box('imagesBox');
      await box.put('image1', image1.path);
      await box.put('image2', image2.path);

      pickedImage1 = image1;
      pickedImage2 = image2;
      notifyListeners();
    }
  }

  String _selectedStoreType = 'Warehouse';
  bool _isStoreTypeSelected = false;

  String get selectedStoreType => _selectedStoreType;
  bool get isStoreTypeSelected => _isStoreTypeSelected;

  List<Map<String, dynamic>> _hiveholdSalesOrders = [];
  List<Map<String, dynamic>> get hiveholdSalesOrders => _hiveholdSalesOrders;
  List<Map<String, dynamic>> _rawOrders = [];
  List<Map<String, dynamic>> get rawOrders => _rawOrders;
  String recordedFilePath = '';
  File? pickedImage1;
  File? pickedImage2;
  String salesOrderId = '';
  // Cheque FocusNodes
  bool isSubmitting = false;
  String? audioPlayerId;
  String? photoScreenId;
  String? previousAudioId;
  String? previousImageId;
  String? audioPlayer;
  String? photoScreen;
  Future<void> saveStoreType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

    await prefs.setString('storeType', type);
    await prefs.setInt('lastShownTimestamp', currentTimestamp);

    _selectedStoreType = type;
    _isStoreTypeSelected = true;
    notifyListeners();
  }

  Future<void> sendPaymentDataToServer(Map<String, dynamic> paymentData) async {
    try {
      final jsonData = jsonEncode(paymentData);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  void clikedThePaymentButton() {
    Map<String, dynamic> paymentData = {
      "type": "placeOrderCliked",
      "cliked ": "Yes",
    };

    // Call your API service method here
    sendClikedThePaymentButtonServer(paymentData);
  }

  /// Sends the brand‑new customer to the back‑end so every device sees it.
  Future<void> sendNewCustomer(String mobile, String name) async {
    final Map<String, dynamic> cutomerPayload = {
      "type": "newCustomer",
      "mobile": mobile,
      "name": name,
      "branchId": storedBranch?.branchId, // optional
      "timestamp": DateTime.now().toIso8601String(),
    };

    try {
      sendSoAddNewCustomerServer(cutomerPayload);
    } catch (e) {}
  }

  Future<void> sendClikedThePaymentButtonServer(
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final jsonData = jsonEncode(paymentData);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  Future<void> sendSoAddNewCustomerServer(
    Map<String, dynamic> customerdata,
  ) async {
    try {
      final jsonData = jsonEncode(customerdata);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  Future<List<Map<String, dynamic>>> fetchHolderFromHive() async {
    try {
      print('🚀 Starting fetchHolderFromHive()...');

      // Step 1: Initialize WebSocketService
      print('🔧 Initializing WebSocketService...');
      WebSocketService webSocketService = WebSocketService(
        CustomerScreenProvider(),
        SalesInvoiceReceiptPrinter(),
      );
      print('✅ WebSocketService initialized successfully.');

      // Step 2: Fetch all saved hold orders from Hive
      print('📦 Fetching all saved hold orders from Hive...');
      List<Map<String, dynamic>> hiveOrders = await webSocketService
          .getSavedHoldOrders();

      print('📥 Total raw orders fetched from Hive: ${hiveOrders.length}');
      if (hiveOrders.isEmpty) {
        print('⚠️ No orders found in Hive.');
        return [];
      }

      for (int i = 0; i < hiveOrders.length; i++) {
        print('   🔹 Order[$i]: ${hiveOrders[i]}');
      }

      // Step 3: Filter orders with status = "Hold Order"
      print('🧮 Filtering only "Hold Order" records...');
      List<Map<String, dynamic>> holdOrders = hiveOrders.where((order) {
        // Extract the nested "data" map safely
        final data = order['data'] ?? {};
        final status = (data['status'] ?? '').toString().trim().toLowerCase();
        return status == 'hold order';
      }).toList();

      print('✅ Total Hold Orders filtered: ${holdOrders.length}');
      if (holdOrders.isEmpty) {
        print('⚠️ No hold orders found after filtering.');
      } else {
        for (int i = 0; i < holdOrders.length; i++) {
          print('   🛒 Hold Order[$i]: ${holdOrders[i]}');
        }
      }

      // ✅ Optional Step: Flatten data for easier UI access
      // This lets you access values directly like order['customerName'], etc.
      List<Map<String, dynamic>> flattenedHoldOrders = holdOrders
          .map((order) => Map<String, dynamic>.from(order['data'] ?? {}))
          .toList();

      // Step 4: Assign to internal variables
      print('🧩 Assigning filtered hold orders to internal lists...');
      _rawOrders = flattenedHoldOrders;
      _hiveholdSalesOrders = List.from(_rawOrders);
      print(
        '✅ Assignment complete. Total stored hold orders: ${_hiveholdSalesOrders.length}',
      );

      // Step 5: Notify listeners for UI updates
      print('🔔 Notifying listeners...');
      notifyListeners();
      print('✅ Listeners notified successfully.');

      print('🎯 fetchHolderFromHive() completed successfully.');
      return _hiveholdSalesOrders;
    } catch (e, stacktrace) {
      print('❌ ERROR in fetchHolderFromHive(): $e');
      print('📄 Stacktrace:\n$stacktrace');
      return [];
    }
  }

  // Updated updateInvoiceReceiptData method
  void updateInvoiceReceiptData(Map<String, dynamic> orderData) {
    final data = orderData;

    // Update invoice receipt printer (not receiptPrinter)
    invoiceReceiptPrinter.employeeNameController.text =
        data['employeeName'] ?? '';
    invoiceReceiptPrinter.customerNumberController.text =
        data['customerNumber'] ?? '';
    invoiceReceiptPrinter.discountController = (data['discount'] ?? 0.0)
        .toDouble();
    invoiceReceiptPrinter.customChargeController = (data['customCharge'] ?? 0.0)
        .toDouble();
    invoiceReceiptPrinter.selectedPaymentOptionValue =
        data['paymentOption'] ?? '';
    invoiceReceiptPrinter.totalAmount = (data['totalAmount'] ?? 0.0).toDouble();

    invoiceReceiptPrinter.advanceAmount =
        (data['advanceAmount'] is List && data['advanceAmount'].isNotEmpty)
        ? (data['advanceAmount'][0] ?? 0.0).toDouble()
        : 0.0;

    invoiceReceiptPrinter.balanceAmount = (data['balanceAmount'] ?? 0.0)
        .toDouble();
    invoiceReceiptPrinter.customerType = data['customerType'] ?? '';
    invoiceReceiptPrinter.deliveryDateprint = data['deliveryDate'] ?? '';
    invoiceReceiptPrinter.deliveryTimeprint = data['deliveryTime'] ?? '';
    invoiceReceiptPrinter.customAmountController.text =
        data['customAmount']?.toString() ?? '';

    invoiceReceiptPrinter.selectedPaymentOption =
        (data['advancePaymentType'] is List &&
            data['advancePaymentType'].isNotEmpty)
        ? data['advancePaymentType'][0] ?? ''
        : '';

    String advanceDateTime =
        (data['advanceDateTime'] is List && data['advanceDateTime'].isNotEmpty)
        ? data['advanceDateTime'][0].toString()
        : '';

    // Clear and update globals.invoiceItems (NOT cartItems)
    globals.invoiceItems = [];
    if (data.containsKey('varianceName') && data['varianceName'] is List) {
      for (int i = 0; i < data['varianceName'].length; i++) {
        // Create invoice item (assuming InvoiceItem class exists)
        globals.invoiceItems.add(
          SalesOrderItem(
            // or CartItem if you're using the same class
            itemName: (data['itemName'].length > i ? data['itemName'][i] : ''),
            varianceName: data['varianceName'][i] ?? '',
            itemCode: (data['itemCode'].length > i ? data['itemCode'][i] : ''),
            qty: (data['qty'].length > i ? data['qty'][i] : 0).toInt(),
            tax: (data['tax'].length > i ? data['tax'][i] : 0).toDouble(),
            uom: (data['uom'].length > i ? data['uom'][i] : ''),
            price: (data['price'].length > i ? data['price'][i] : 0).toDouble(),
            weight: (data['weight'].length > i ? data['weight'][i] : 0.0)
                .toDouble(),
            // Add invoice-specific fields if needed
            amount: (data['amount'] != null && data['amount'].length > i)
                ? (data['amount'][i] ?? 0.0).toDouble()
                : 0.0,
          ),
        );
      }
    }

    // Print invoice receipt
    invoiceprintReceipt();
    notifyListeners();
  }

  void updatePatchReceiptData(Map<String, dynamic> orderData) {
    // 🔹 Extract inner data map if present
    final data = orderData['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(orderData['data'])
        : orderData;

    // --- BASIC DETAILS ---
    receiptPrinter.employeeNameController.text = data['employeeName'] ?? '';

    receiptPrinter.customerNumberController.text = data['customerNumber'] ?? '';

    receiptPrinter.discountController = (data['discount'] ?? 0.0).toDouble();

    receiptPrinter.discountAmountController = (data['discountAmount'] ?? 0.0)
        .toDouble();

    receiptPrinter.customChargeController = (data['customCharge'] ?? 0.0)
        .toDouble();

    receiptPrinter.selectedPaymentOptionValue = data['paymentOption'] ?? '';

    receiptPrinter.totalAmount = (data['totalAmount'] ?? 0.0).toDouble();
    receiptPrinter.totalAmount2 = (data['totalAmount2'] ?? 0.0).toDouble();

    receiptPrinter.discountAmount = (data['discountAmount'] ?? 0.0).toDouble();
    receiptPrinter.finalPrice = (data['finalPrice'] ?? 0.0).toDouble();

    receiptPrinter.balanceAmount = (data['balanceAmount'] ?? 0.0).toDouble();

    receiptPrinter.customerType = data['customerType'] ?? '';

    receiptPrinter.deliveryDateprint = data['deliveryDate'] ?? '';
    receiptPrinter.deliveryTimeprint = data['deliveryTime'] ?? '';

    receiptPrinter.saleOrderNo = data['saleOrderNo'] ?? '';

    // --- ADVANCE AMOUNTS ---
    receiptPrinter.advanceAmount = data['advanceAmount'] != null
        ? List<double>.from(
            (data['advanceAmount'] as List).map((x) => (x as num).toDouble()),
          )
        : <double>[];

    receiptPrinter.advanceDateTime = List<String>.from(
      data['advanceDateTime'] ?? [],
    );

    receiptPrinter.selectedPaymentOption = data['advancePaymentType'] != null
        ? List<List<String>>.from(
            (data['advancePaymentType'] as List).map(
              (x) => List<String>.from((x as List).map((y) => y.toString())),
            ),
          )
        : [];

    receiptPrinter.selectedPaymentOptionAmount = data['modeWiseAmount'] != null
        ? List<List<String>>.from(
            (data['modeWiseAmount'] as List).map(
              (x) => List<String>.from((x as List).map((y) => y.toString())),
            ),
          )
        : [];

    receiptPrinter.customAmountController.text =
        data['customAmount']?.toString() ?? '';

    // --- CART ITEMS ---
    globals.cartItems = [];
    if (data.containsKey('varianceName') && data['varianceName'] is List) {
      for (int i = 0; i < data['varianceName'].length; i++) {
        CartItem item = CartItem(
          itemName: (data['itemName'].length > i ? data['itemName'][i] : ''),
          varianceName: data['varianceName'][i] ?? '',
          itemCode: (data['itemCode'].length > i ? data['itemCode'][i] : ''),
          quantity: (data['qty'].length > i ? data['qty'][i] : 0).toInt(),
          tax: (data['tax'].length > i ? data['tax'][i] : 0).toInt(),
          uom: (data['uom'].length > i ? data['uom'][i] : ''),
          pricePerKg: (data['price'].length > i ? data['price'][i] : 0).toInt(),
          weight: (data['weight'].length > i ? data['weight'][i] : 0.0)
              .toDouble(),
          itemWiseDiscount:
              (data['itemWiseDiscount'] != null &&
                  data['itemWiseDiscount'].length > i)
              ? (data['itemWiseDiscount'][i] as num).toDouble()
              : 0.0,
          itemWiseDiscountAmount:
              (data['itemWiseDiscountAmount'] != null &&
                  data['itemWiseDiscountAmount'].length > i)
              ? (data['itemWiseDiscountAmount'][i] as num).toDouble()
              : 0.0,
        );

        globals.cartItems.add(item);
      }
    } else {}

    // --- PRINT RECEIPT ---
    printPatchReceipt();

    notifyListeners();
  }

  // Print sales order receipt
  Future<void> printPatchReceipt() async {
    try {
      await receiptPrinter.patchprintReceiptDetails();
    } catch (e) {}
  }

  // Keep existing updateReceiptData for sales orders
  void updateReceiptData(Map<String, dynamic> orderData) {
    // 🔹 Extract inner data map if present
    final data = orderData['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(orderData['data'])
        : orderData;

    // --- BASIC DETAILS ---
    receiptPrinter.employeeNameController.text = data['employeeName'] ?? '';

    receiptPrinter.customerNumberController.text = data['customerNumber'] ?? '';

    receiptPrinter.discountController = (data['discount'] ?? 0.0).toDouble();

    receiptPrinter.discountAmountController = (data['discountAmount'] ?? 0.0)
        .toDouble();

    receiptPrinter.customChargeController = (data['customCharge'] ?? 0.0)
        .toDouble();

    receiptPrinter.selectedPaymentOptionValue = data['paymentOption'] ?? '';

    receiptPrinter.totalAmount = (data['totalAmount'] ?? 0.0).toDouble();

    receiptPrinter.totalAmount2 = (data['totalAmount2'] ?? 0.0).toDouble();

    receiptPrinter.discountAmount = (data['discountAmount'] ?? 0.0).toDouble();

    receiptPrinter.finalPrice = (data['finalPrice'] ?? 0.0).toDouble();

    receiptPrinter.balanceAmount = (data['balanceAmount'] ?? 0.0).toDouble();

    receiptPrinter.customerType = data['customerType'] ?? '';

    receiptPrinter.deliveryDateprint = data['deliveryDate'] ?? '';
    receiptPrinter.deliveryTimeprint = data['deliveryTime'] ?? '';

    receiptPrinter.saleOrderNo = data['saleOrderNo'] ?? '';

    // --- ADVANCE AMOUNTS ---
    receiptPrinter.advanceAmount = data['advanceAmount'] != null
        ? List<double>.from(
            (data['advanceAmount'] as List).map((x) => (x as num).toDouble()),
          )
        : <double>[];

    receiptPrinter.advanceDateTime = List<String>.from(
      data['advanceDateTime'] ?? [],
    );

    receiptPrinter.selectedPaymentOption = data['advancePaymentType'] != null
        ? List<List<String>>.from(
            (data['advancePaymentType'] as List).map(
              (x) => List<String>.from((x as List).map((y) => y.toString())),
            ),
          )
        : [];

    receiptPrinter.selectedPaymentOptionAmount = data['modeWiseAmount'] != null
        ? List<List<String>>.from(
            (data['modeWiseAmount'] as List).map(
              (x) => List<String>.from((x as List).map((y) => y.toString())),
            ),
          )
        : [];

    receiptPrinter.customAmountController.text =
        data['customAmount']?.toString() ?? '';

    // --- CART ITEMS ---
    globals.cartItems = [];
    if (data.containsKey('varianceName') && data['varianceName'] is List) {
      for (int i = 0; i < data['varianceName'].length; i++) {
        CartItem item = CartItem(
          itemName: (data['itemName'].length > i ? data['itemName'][i] : ''),
          varianceName: data['varianceName'][i] ?? '',
          itemCode: (data['itemCode'].length > i ? data['itemCode'][i] : ''),
          quantity: (data['qty'].length > i ? data['qty'][i] : 0).toInt(),
          tax: (data['tax'].length > i ? data['tax'][i] : 0).toInt(),
          uom: (data['uom'].length > i ? data['uom'][i] : ''),
          pricePerKg: (data['price'].length > i ? data['price'][i] : 0).toInt(),
          weight: (data['weight'].length > i ? data['weight'][i] : 0.0)
              .toDouble(),
          itemWiseDiscount:
              (data['itemWiseDiscount'] != null &&
                  data['itemWiseDiscount'].length > i)
              ? (data['itemWiseDiscount'][i] as num).toDouble()
              : 0.0,
          itemWiseDiscountAmount:
              (data['itemWiseDiscountAmount'] != null &&
                  data['itemWiseDiscountAmount'].length > i)
              ? (data['itemWiseDiscountAmount'][i] as num).toDouble()
              : 0.0,
        );

        globals.cartItems.add(item);
      }
    } else {}

    // --- PRINT RECEIPT ---
    printReceipt();
    notifyListeners();
  }

  // Print sales order receipt
  Future<void> printReceipt() async {
    try {
      await receiptPrinter.printReceiptDetails();
    } catch (e) {}
  }

  // Print invoice receipt
  Future<void> invoiceprintReceipt() async {
    try {
      await invoiceReceiptPrinter.printReceiptDetails();
    } catch (e) {}
  }

  Future<void> checkAndShowStoreTypeDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownTimestamp = prefs.getInt('lastShownTimestamp') ?? 0;
    final storedStoreType = prefs.getString('storeType') ?? '';

    final lastShownDate = DateTime.fromMillisecondsSinceEpoch(
      lastShownTimestamp,
    );
    final currentDate = DateTime.now();

    final isSameDay =
        lastShownDate.year == currentDate.year &&
        lastShownDate.month == currentDate.month &&
        lastShownDate.day == currentDate.day;

    if (storedStoreType.isNotEmpty) {
      _selectedStoreType = storedStoreType;
      notifyListeners();
    }

    if (!isSameDay || storedStoreType.isEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            StoreTypeSelectionDialog(onStoreTypeSelected: saveStoreType),
      );
    } else {
      _isStoreTypeSelected = true;
      notifyListeners();
    }
  }

  void updateDate(String newDate) {
    dateController.text = newDate;
    notifyListeners(); // Trigger UI rebuild
  }

  int _sendInvoiceCallCount = 0;

  Future<void> sendSalesOrderDataToServer(
    Map<String, dynamic> salesOrderData,
  ) async {
    _sendInvoiceCallCount++;
    try {
      final jsonData = jsonEncode(salesOrderData);
      _channel.sink.add(jsonData);
    } catch (e) {
      throw e;
    }
  }

  Future<void> sendApprovalDataToServer(
    Map<String, dynamic> approvalData,
  ) async {
    _sendInvoiceCallCount++;

    try {
      final jsonData = jsonEncode(approvalData);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  List<String>? advanceDateTime;
  List<String>? advancePaymentType;
  Timer? _debounce;
  bool showAudioandImage = true;
  String selectedOrderOption = 'Inhouse';

  Future<void> cancelOrder(
    String salesOrderId,
    Map<String, dynamic> payload,
  ) async {
    try {
      // Step 1: Prepare cancel order data
      final cancelOrderData = {
        'type': 'cancelOrder', // Action identifier for server
        'saleOrderNo': salesOrderId,
        'data': payload,
      };

      // Step 2: Increase invoice call counter
      _sendInvoiceCallCount++;

      // Step 3: Encode to JSON
      final jsonData = jsonEncode(cancelOrderData);

      // Step 4: Send to WebSocket
      _channel.sink.add(jsonData);
    } catch (e, stackTrace) {
      // Step 5: Error handling
      // Optional: show user error message here
    }
  }

  Future<void> cancelOrderAccounts(
    String salesOrderId,
    Map<String, dynamic> payload,
  ) async {
    try {
      // Add the salesOrderId to the payload if needed
      final cancelOrderData = {
        'action': 'cancelOrder', // Add an action identifier for the server
        'salesOrderId': salesOrderId,
        'payload': payload,
      };

      final jsonData = jsonEncode(cancelOrderData);
      _channel.sink.add(jsonData);
    } catch (e) {
      // You might want to show an error to the user here
    }
  }

  Future<void> sendInvoiceDataToServer(Map<String, dynamic> invoiceData) async {
    _sendInvoiceCallCount++;

    try {
      final jsonData = jsonEncode(invoiceData);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  void showOutletAdvancePaymentPopup(
    BuildContext context,
    SalesOrderDisplay salesOrder,
    CartProvider cartProvider,
  ) {
    bool hasItemLevelDiscount = cartProvider.cartItems.any(
      (item) => item.itemWiseDiscount != null && item.itemWiseDiscount! > 0,
    );
    double orderAmount = salesOrder.totalAmount;
    double discount = 0;
    double customCharge = 0;
    double totalAdvance = 0;
    double deductedAmount = 0;
    double totalAmount = orderAmount + customCharge - deductedAmount;

    TextEditingController advanceController = TextEditingController();
    TextEditingController remarkController = TextEditingController();

    String selectedPaymentMethod = 'Cash'; // Default payment method

    advanceController.clear();

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.white],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade200, Colors.blue.shade600],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.payment_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Payment Details',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Column(
                              //   crossAxisAlignment: CrossAxisAlignment.start,
                              //   children: [
                              //     // Section Title
                              //     Text(
                              //       'Payment Method',
                              //       style: TextStyle(
                              //         fontSize: 18,
                              //         fontWeight: FontWeight.bold,
                              //         color: Colors.black87,
                              //       ),
                              //     ),
                              //     const SizedBox(height: 10),

                              //     // Payment Methods Container
                              //     Container(
                              //       padding: const EdgeInsets.all(15),
                              //       decoration: BoxDecoration(
                              //         color: Colors.white,
                              //         borderRadius: BorderRadius.circular(15),
                              //         border: Border.all(
                              //           color: Colors.grey.shade300,
                              //         ),
                              //         boxShadow: [
                              //           BoxShadow(
                              //             color: Colors.grey.withOpacity(0.1),
                              //             blurRadius: 8,
                              //             offset: const Offset(0, 3),
                              //           ),
                              //         ],
                              //       ),
                              //       child: Wrap(
                              //         spacing: 15,
                              //         runSpacing: 15,
                              //         children: [
                              //           _buildPaymentMethodTile(
                              //             context,
                              //             'Cash',
                              //             Icons.money,
                              //             selectedPaymentMethod,
                              //             (value) {
                              //               setState(() {
                              //                 selectedPaymentMethod = value!;
                              //                 updatePaymentData();
                              //               }
                              //                   // () =>

                              //                   );
                              //             },
                              //           ),
                              //           _buildPaymentMethodTile(
                              //             context,
                              //             'Card',
                              //             Icons.credit_card,
                              //             selectedPaymentMethod,
                              //             (value) {
                              //               setState(() {
                              //                 selectedPaymentMethod = value!;
                              //                 updatePaymentData();
                              //               });
                              //             },
                              //           ),
                              //           _buildPaymentMethodTile(
                              //             context,
                              //             'UPI',
                              //             Icons.phone_android,
                              //             selectedPaymentMethod,
                              //             (value) {
                              //               setState(() {
                              //                 selectedPaymentMethod = value!;
                              //                 updatePaymentData();
                              //               });
                              //             },
                              //           ),
                              //           _buildPaymentMethodTile(
                              //             context,
                              //             'Cheque',
                              //             Icons.account_balance_wallet,
                              //             selectedPaymentMethod,
                              //             (value) {
                              //               setState(() {
                              //                 selectedPaymentMethod = value!;
                              //                 if (value == 'Cheque' &&
                              //                     advanceController
                              //                         .text.isNotEmpty) {
                              //                   chequeAmountController.text =
                              //                       advanceController.text;
                              //                 }
                              //               });
                              //             },
                              //           ),
                              //           _buildPaymentMethodTile(
                              //             context,
                              //             'Others',
                              //             Icons.more_horiz,
                              //             selectedPaymentMethod,
                              //             (value) {
                              //               setState(() {
                              //                 selectedPaymentMethod = value!;
                              //                 updatePaymentData();
                              //               });
                              //             },
                              //           ),
                              //         ],
                              //       ),
                              //     ),

                              //     // Advance Amount Input (Visible only for Cash Payment)
                              //     if (selectedPaymentMethod == 'Cash')
                              //       Padding(
                              //         padding: const EdgeInsets.only(top: 20),
                              //         child: TextFormField(
                              //           controller: advanceController,
                              //           keyboardType: TextInputType.number,
                              //           decoration: InputDecoration(
                              //             labelText: 'Advance Amount',
                              //             labelStyle: TextStyle(
                              //               color: Colors.black87,
                              //             ),
                              //             filled: true,
                              //             fillColor: Colors.white,
                              //             prefixIcon: Icon(
                              //               Icons.payment,
                              //               color: Colors.grey.shade600,
                              //             ),
                              //             prefixText: '₹ ',
                              //             enabledBorder: OutlineInputBorder(
                              //               borderRadius: BorderRadius.circular(
                              //                 12,
                              //               ),
                              //               borderSide: BorderSide(
                              //                 color: Colors.grey.shade300,
                              //               ),
                              //             ),
                              //             focusedBorder: OutlineInputBorder(
                              //               borderRadius: BorderRadius.circular(
                              //                 12,
                              //               ),
                              //               borderSide: BorderSide(
                              //                 color: Colors.black87,
                              //                 width: 2,
                              //               ),
                              //             ),
                              //             hintText: 'Enter advance amount',
                              //           ),
                              //           onChanged: (value) {
                              //             setState(() {
                              //               double enteredValue =
                              //                   double.tryParse(value) ?? 0;
                              //               if (enteredValue > totalAmount) {
                              //                 advanceController.text =
                              //                     totalAmount
                              //                         .toStringAsFixed(0);
                              //                 advanceController.selection =
                              //                     TextSelection.fromPosition(
                              //                   TextPosition(
                              //                     offset: advanceController
                              //                         .text.length,
                              //                   ),
                              //                 );
                              //                 totalAdvance = totalAmount;
                              //               } else {
                              //                 totalAdvance = enteredValue;
                              //               }
                              //               updatePaymentData();
                              //               if (selectedPaymentMethod ==
                              //                   'Cheque') {
                              //                 chequeAmountController.text =
                              //                     advanceController.text;
                              //               }
                              //             });
                              //           },
                              //         ),
                              //       ),

                              //     // Cheque Details Section (Visible only when Cheque is selected)
                              //     if (selectedPaymentMethod == 'Cheque')
                              //       if (selectedPaymentMethod == 'Cash')
                              //         Padding(
                              //           padding: const EdgeInsets.only(top: 20),
                              //           child: Card(
                              //             elevation: 3,
                              //             shape: RoundedRectangleBorder(
                              //               borderRadius: BorderRadius.circular(
                              //                 12,
                              //               ),
                              //             ),
                              //             child: Padding(
                              //               padding: const EdgeInsets.symmetric(
                              //                 horizontal: 15,
                              //                 vertical: 10,
                              //               ),
                              //               child: TextFormField(
                              //                 controller: advanceController,
                              //                 keyboardType:
                              //                     TextInputType.number,
                              //                 decoration: InputDecoration(
                              //                   labelText: 'Advance Amount',
                              //                   labelStyle: TextStyle(
                              //                     color: Colors.black87,
                              //                     fontSize: 16,
                              //                   ),
                              //                   filled: true,
                              //                   fillColor: Colors.white,
                              //                   prefixIcon: Icon(
                              //                     Icons.payment,
                              //                     color: Colors.black54,
                              //                   ),
                              //                   prefixText: '₹ ',
                              //                   enabledBorder:
                              //                       OutlineInputBorder(
                              //                     borderRadius:
                              //                         BorderRadius.circular(
                              //                       12,
                              //                     ),
                              //                     borderSide: BorderSide(
                              //                       color: Colors.grey.shade300,
                              //                     ),
                              //                   ),
                              //                   focusedBorder:
                              //                       OutlineInputBorder(
                              //                     borderRadius:
                              //                         BorderRadius.circular(
                              //                       12,
                              //                     ),
                              //                     borderSide: BorderSide(
                              //                       color: Colors.black87,
                              //                       width: 2,
                              //                     ),
                              //                   ),
                              //                   hintText:
                              //                       'Enter advance amount',
                              //                 ),
                              //                 onChanged: (value) {
                              //                   setState(() {
                              //                     double enteredValue =
                              //                         double.tryParse(value) ??
                              //                             0;
                              //                     if (enteredValue >
                              //                         totalAmount) {
                              //                       advanceController.text =
                              //                           totalAmount
                              //                               .toStringAsFixed(0);
                              //                       advanceController
                              //                               .selection =
                              //                           TextSelection
                              //                               .fromPosition(
                              //                         TextPosition(
                              //                           offset:
                              //                               advanceController
                              //                                   .text.length,
                              //                         ),
                              //                       );
                              //                       totalAdvance = totalAmount;
                              //                     } else {
                              //                       totalAdvance = enteredValue;
                              //                     }

                              //                     if (selectedPaymentMethod ==
                              //                         'Cheque') {
                              //                       chequeAmountController
                              //                               .text =
                              //                           advanceController.text;
                              //                     }
                              //                   });
                              //                 },
                              //               ),
                              //             ),
                              //           ),
                              //         ),

                              //     if (selectedPaymentMethod == 'Cheque')
                              //       Padding(
                              //         padding: const EdgeInsets.symmetric(
                              //           vertical: 3,
                              //           horizontal: 15,
                              //         ),
                              //         child: Card(
                              //           color: Colors.white,
                              //           elevation: 3,
                              //           shape: RoundedRectangleBorder(
                              //             borderRadius: BorderRadius.circular(
                              //               12,
                              //             ),
                              //           ),
                              //           child: Padding(
                              //             padding: const EdgeInsets.all(15),
                              //             child: Column(
                              //               crossAxisAlignment:
                              //                   CrossAxisAlignment.start,
                              //               children: [
                              //                 // Section Header
                              //                 Row(
                              //                   children: [
                              //                     Icon(
                              //                       Icons.description,
                              //                       color: Colors.blueAccent,
                              //                       size: 26,
                              //                     ),
                              //                     const SizedBox(width: 10),
                              //                     Text(
                              //                       'Cheque Details',
                              //                       style: TextStyle(
                              //                         color: Colors.black87,
                              //                         fontWeight:
                              //                             FontWeight.w600,
                              //                         fontSize: 20,
                              //                       ),
                              //                     ),
                              //                   ],
                              //                 ),
                              //                 const Divider(
                              //                   thickness: 1.5,
                              //                   height: 20,
                              //                 ),

                              //                 // Row 1: Cheque Number, Cheque Amount, Holder Name
                              //                 Row(
                              //                   children: [
                              //                     Expanded(
                              //                       child:
                              //                           _buildStyledFormField(
                              //                         controller:
                              //                             chequeNumberController,
                              //                         labelText:
                              //                             'Cheque Number',
                              //                         icon: Icons.numbers,
                              //                         hintText:
                              //                             'Enter cheque number',
                              //                         keyboardType:
                              //                             TextInputType.number,
                              //                       ),
                              //                     ),
                              //                     const SizedBox(width: 15),
                              //                     Expanded(
                              //                       child:
                              //                           _buildStyledFormField(
                              //                         controller:
                              //                             chequeAmountController,
                              //                         labelText:
                              //                             'Cheque Amount',
                              //                         icon:
                              //                             Icons.currency_rupee,
                              //                         hintText: 'Enter amount',
                              //                         keyboardType:
                              //                             TextInputType.number,
                              //                         prefixText: '₹ ',
                              //                       ),
                              //                     ),
                              //                     const SizedBox(width: 15),
                              //                     Expanded(
                              //                       child: GestureDetector(
                              //                         onTap: () async {
                              //                           final DateTime? picked =
                              //                               await showDatePicker(
                              //                             context: context,
                              //                             initialDate:
                              //                                 DateTime.now(),
                              //                             firstDate: DateTime(
                              //                               2000,
                              //                             ),
                              //                             lastDate: DateTime(
                              //                               2100,
                              //                             ),
                              //                             builder: (
                              //                               context,
                              //                               child,
                              //                             ) {
                              //                               return Theme(
                              //                                 data: Theme.of(
                              //                                   context,
                              //                                 ).copyWith(
                              //                                   colorScheme:
                              //                                       ColorScheme
                              //                                           .light(
                              //                                     primary: Colors
                              //                                         .blueAccent,
                              //                                     onPrimary:
                              //                                         Colors
                              //                                             .white,
                              //                                     onSurface:
                              //                                         Colors
                              //                                             .black,
                              //                                   ),
                              //                                 ),
                              //                                 child: child!,
                              //                               );
                              //                             },
                              //                           );
                              //                           if (picked != null) {
                              //                             setState(() {
                              //                               chequeDateController
                              //                                       .text =
                              //                                   "${picked.day}/${picked.month}/${picked.year}";
                              //                             });
                              //                           }
                              //                         },
                              //                         child:
                              //                             _buildStyledFormField(
                              //                           controller:
                              //                               chequeDateController,
                              //                           labelText:
                              //                               'Cheque Date',
                              //                           icon: Icons
                              //                               .calendar_today,
                              //                           hintText: 'Select date',
                              //                           readOnly: true,
                              //                         ),
                              //                       ),
                              //                     ),
                              //                   ],
                              //                 ),
                              //                 const SizedBox(height: 10),

                              //                 // Row 2: Cheque Date, Bank Name
                              //                 Row(
                              //                   children: [
                              //                     Expanded(
                              //                       child:
                              //                           _buildStyledFormField(
                              //                         controller:
                              //                             chequeNameController,
                              //                         labelText:
                              //                             'Cheque Holder Name',
                              //                         icon: Icons.person,
                              //                         hintText:
                              //                             'Enter name on cheque',
                              //                       ),
                              //                     ),
                              //                     const SizedBox(width: 15),
                              //                     Expanded(
                              //                       child: BankSearchDropdown(
                              //
                              //                       ), // Dropdown for bank selection
                              //                     ),
                              //                   ],
                              //                 ),
                              //               ],
                              //             ),
                              //           ),
                              //         ),
                              //       ),
                              //   ],
                              // ),
                              SizedBox(height: 25),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade600,
                                      Colors.blue.shade800,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildAmountInfo('Advance', totalAdvance),
                                    _buildSeparator(),
                                    _buildAmountInfo('Total', totalAmount),
                                    _buildSeparator(),
                                    _buildAmountInfo(
                                      'Balance',
                                      totalAmount - totalAdvance,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Footer Actions
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Cancel Button
                          OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(color: Colors.blue.shade400),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                          const SizedBox(width: 15),

                          // Complete/Approve Order Button
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              // Validate cheque details if Cheque is selected
                              if (selectedPaymentMethod == 'Cheque') {
                                // Call the sendToApproval function if payment type is Cheque
                                await OutletSendForApproval(
                                  salesOrder,
                                  totalAdvance,
                                  orderAmount,
                                  discount,
                                  deductedAmount,
                                  customCharge,
                                  totalAmount,
                                  remarkController.text,
                                  "Cheque",
                                  context,
                                );
                                return;
                              }

                              showDialog(
                                barrierDismissible: false,
                                context: context,
                                builder: (BuildContext context) {
                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 10),
                                            const Text('Confirm Order'),
                                          ],
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Are you sure you want to complete the order?',
                                            ),
                                            const SizedBox(height: 20),
                                            // Radio buttons for order option
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              await outletSaveOrder(
                                                salesOrder,
                                                totalAdvance,
                                                orderAmount,
                                                discount,
                                                deductedAmount,
                                                totalAmount,
                                                customCharge,
                                                remarkController.text,
                                                selectedStoreType,
                                                context,
                                              );

                                              cartProvider.clearCart();

                                              // SalesOrderScreenState()
                                              //     .clearCartAndResetState;
                                            },
                                            child: const Text('Confirm'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              backgroundColor: Colors.blue.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              selectedPaymentMethod == 'Cheque'
                                  ? 'Send to Approval'
                                  : 'Complete Order',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> outletSaveOrder(
    SalesOrderDisplay saleOrders,
    double totalAdvance,
    double orderAmount,
    double discount,
    double deductedAmount,
    double totalAmount,
    double customCharge,
    String remark,
    String? selectedOrderOption,
    BuildContext context,
  ) async {
    double balanceAmount = totalAmount - totalAdvance;

    // Initialize advance breakdown
    List<double> cashAdvance = [0.0];
    List<double> cardAdvance = [0.0];
    List<double> upiAdvance = [0.0];

    if (selectedPaymentMethod == 'Cash') {
      cashAdvance[0] = totalAdvance;
    } else if (selectedPaymentMethod == 'Card') {
      cardAdvance[0] = totalAdvance;
    } else if (selectedPaymentMethod == 'UPI') {
      upiAdvance[0] = totalAdvance;
    }

    // Prepare advance metadata
    String currentDateTime = DateTime.now().toIso8601String();
    advanceDateTime ??= [];
    advancePaymentType ??= [];

    advanceDateTime!.add(currentDateTime);
    advancePaymentType!.add(selectedPaymentMethod);

    String saleOrderNo = generateSaleOrderNo();
    // Common sales order data
    Map<String, dynamic> orderData = {
      "itemName": saleOrders.itemName,
      "varianceName":
          saleOrders.varianceName, // Assuming saleOrders.varianceName is a list
      "itemCode": saleOrders.itemCode, // Assuming saleOrders.itemCode is a list
      "qty": saleOrders.qty, // Assuming saleOrders.qty is a list
      "tax": saleOrders.tax, // Assuming saleOrders.tax is a list
      "uom": saleOrders.uom, // Assuming saleOrders.uom is a list
      "amount": saleOrders.amount, // Assuming saleOrders.amount is a list
      "branchId": saleOrders.branchId,
      "branchName": saleOrders.branchName,
      "price": saleOrders.price, // Assuming saleOrders.price is a list
      "weight": saleOrders.weight, // Assuming saleOrders.weight is a list
      "deliveryDate": saleOrders.deliveryDate,
      "deliveryTime": saleOrders.deliveryTime,
      "event": saleOrders.event,
      "customerNumber": saleOrders.customerNumber,
      "customerName": saleOrders.customerName,
      "deliveryType": saleOrders.deliveryType,
      "address": saleOrders.address,
      "landmark": saleOrders.landmark,
      "discountAmount": discount,

      "orderDate": saleOrders.orderDate,
      "orderTime": saleOrders.orderTime,
      "employeeName": saleOrders.employeeName,
      "status": "Confirm Order",
      "orderType": saleOrders.orderType,
      "eventDate": saleOrders.eventDate,
      "itemWiseDiscount": saleOrders.itemWiseDiscount,
      "itemWiseDiscountAmount": saleOrders.itemWiseDiscountAmount,
      "boxQty": saleOrders.boxQty,
      "totalAmount": totalAmount,
      "remark": remark,
      "customCharge": customCharge,
      "deductedAmount": deductedAmount,
      "orderAmount": orderAmount,
      "advanceAmount": [totalAdvance],
      "advancePaymentType": advancePaymentType,
      "advanceDateTime": advanceDateTime,
      "balanceAmount": balanceAmount,

      "discount": discount,
    };

    try {
      String jsonadvanceSalesOrder = jsonEncode({
        "data": orderData,
        "saleOrderNo": saleOrders.saleOrderNo,
        "type": "patchSaleOrder",
        "sync": "No",
        "edit": "No",
      });

      await sendInvoiceDataToServer(jsonDecode(jsonadvanceSalesOrder));
      // Full Sales Order POST

      await Future.delayed(Duration(milliseconds: 500)); // small delay

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
    } finally {
      clearControllers();

      isSubmitting = false;
      showAudioandImage = false;
      advanceDateTime?.clear();
      advancePaymentType?.clear();
      notifyListeners();
    }
  }

  Widget _buildMiniCard({
    required String title,
    required String value,
    required List<Color> gradient,
  }) {
    return Expanded(
      child: Container(
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey[400]!,
              offset: const Offset(2, 2),
              blurRadius: 6,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 6,
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> OutletSendForApproval(
    SalesOrderDisplay saleOrders,
    double totalAdvance,
    double orderAmount,
    double discount,
    double deductedAmount,
    double customCharge,
    double totalAmount,
    String remark,
    String? selectedOrderOption,
    BuildContext context,
  ) async {
    // if (isSubmitting) return; // Prevent double submission
    // isSubmitting = true;

    double balanceAmount = totalAmount - totalAdvance;
    List<double> advanceAmountList = [totalAdvance];
    List<double> cashAdvance = [0.0];
    List<double> cardAdvance = [0.0];
    List<double> upiAdvance = [0.0];

    if (selectedPaymentMethod == 'Cash') {
      cashAdvance[0] = totalAdvance; // Update the first element of cashAdvance
    } else if (selectedPaymentMethod == 'Card') {
      cardAdvance[0] = totalAdvance; // Update the first element of cardAdvance
    } else if (selectedPaymentMethod == 'UPI') {
      upiAdvance[0] = totalAdvance; // Update the first element of upiAdvance
    }
    String currentDateTime = DateTime.now().toIso8601String();
    advanceDateTime ??= [];
    advancePaymentType ??= [];

    // Add datetime and payment type
    advanceDateTime!.add(currentDateTime);
    advancePaymentType!.add(selectedPaymentMethod);

    String approvalType;
    String approvalStatus;
    if (selectedOrderOption == 'Cheque') {
      approvalType = 'Cheque';
      approvalStatus = 'Pending Cheque Payment';
    } else {
      approvalType = 'Discount';
      approvalStatus = 'Sending to Approval';
    } // Common sales order data
    // Convert 'dd-MM-yyyy' to DateTime
    DateTime parsedOrderDate = DateFormat(
      "dd-MM-yyyy",
    ).parse(saleOrders.orderDate);
    String saleOrderNo = generateSaleOrderNo();
    Map<String, dynamic> orderData = {
      "itemName": saleOrders.itemName,
      "varianceName":
          saleOrders.varianceName, // Assuming saleOrders.varianceName is a list
      "itemCode": saleOrders.itemCode, // Assuming saleOrders.itemCode is a list
      "qty": saleOrders.qty, // Assuming saleOrders.qty is a list
      "tax": saleOrders.tax, // Assuming saleOrders.tax is a list
      "uom": saleOrders.uom, // Assuming saleOrders.uom is a list
      "amount": saleOrders.amount, // Assuming saleOrders.amount is a list
      "branchId": saleOrders.branchId,
      "branchName": saleOrders.branchName,
      "price": saleOrders.price, // Assuming saleOrders.price is a list
      "weight": saleOrders.weight, // Assuming saleOrders.weight is a list
      "deliveryDate": saleOrders.deliveryDate,
      "deliveryTime": saleOrders.deliveryTime,
      "event": saleOrders.event,
      "customerNumber": saleOrders.customerNumber,
      "customerName": saleOrders.customerName,
      "deliveryType": saleOrders.deliveryType,
      "address": saleOrders.address,
      "landmark": saleOrders.landmark,
      "discountAmount": discount,
      "saleOrderNo": saleOrderNo,
      "orderDate": parsedOrderDate.toIso8601String(),
      "orderTime": saleOrders.orderTime,
      "employeeName": saleOrders.employeeName,
      "status": "Confirm Order",
      "orderType": saleOrders.orderType,
      "eventDate": saleOrders.eventDate,
      "itemWiseDiscount": saleOrders.itemWiseDiscount,
      "itemWiseDiscountAmount": saleOrders.itemWiseDiscountAmount,
      "boxQty": saleOrders.boxQty,
      "totalAmount": totalAmount,
      "remark": remark,
      "customCharge": customCharge,
      "deductedAmount": deductedAmount,
      "orderAmount": orderAmount,
      "advanceAmount": [totalAdvance],
      "advancePaymentType": advancePaymentType,
      "advanceDateTime": advanceDateTime,
      "balanceAmount": balanceAmount,
      "discount": discount,

      /// ✅ Add the approval details here
      "approvalDetails": [
        ApprovalOrderDetail(
          approvalType: approvalType,
          approvalStatus: approvalStatus,
          approvalDate: DateTime.now().toIso8601String(),
          summary: 'No',
        ).toJson(),
      ],
    };

    // String jsonSalesOrder = jsonEncode(salesOrder.toJson());

    try {
      String jsonSalesOrder = jsonEncode({
        "data": [orderData],
        "type": "salesApprovalOrder",
        'sync': "No",
        'edit': 'No',
        'waitingForApprovalResult': 'Yes',
        "saleOrderNo": saleOrders.saleOrderNo,
      });
      // initializeReceiptPrinter(
      //   deliveryTime: timeController.text,
      //   deliverydateprint: dateController.text,
      //   employeeNameController: searchController,
      //   customerNumberController: mobileNoController,
      //   discountController: deductedAmount,
      //   customChargeController: customCharge,
      //   selectedPaymentOptionValue: selectedPaymentMethod,
      //   totalAmount: totalAmount,
      //   advanceAmount: totalAdvance,
      //   balanceAmount: balanceAmount,
      //   customerType: 'SalesOrder',
      //   // context: context,
      //   customAmountController: mobileNoController,
      //   selectedPaymentOption: selectedPaymentMethod,
      //   // saveInvoiceToHiveAndPrint: () {}
      // );
      await sendApprovalDataToServer(jsonDecode(jsonSalesOrder));
      // Check if it reaches here

      final patchData = jsonEncode(orderData); // Use the single orderData map
      final url = Uri.parse(
        'http://192.168.1.130:8888/fastapi/salesorders/${saleOrders.salesOrderId}',
      );

      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: patchData,
      );

      if (response.statusCode == 200) {
      } else {
        throw Exception('Failed to patch sales order.');
      }
    } catch (e) {
      // Catches any errors during the request
    } finally {
      clearControllers();

      isSubmitting = false;
      showAudioandImage = false;
      advanceDateTime!.clear();
      advancePaymentType!.clear();
      // audioOrderId = null;
      // clearAudioAndPhotoIds();
      notifyListeners();
    }
  }

  bool isPaymentDone = false;

  List<String> filteredItems = [];
  List<Map<String, dynamic>> submittedOrders = [];
  List<SalesOrder> orders = [];
  TextEditingController advanceAmountController = TextEditingController();
  BranchProvider branchProvider = BranchProvider();
  Branch? storedBranch;
  ItemProvider getbranchaliasname = ItemProvider();
  TextEditingController customersearchController = TextEditingController();
  List<Map<String, String>> filteredCustomers = [];
  String customersearchQuery = '';
  String patchHoldOrderId = "";
  String approvalOrderId = "";

  TextEditingController customerNameController = TextEditingController();
  TextEditingController customChargeController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  TextEditingController birthdaydateController = TextEditingController();
  TextEditingController timeController = TextEditingController();
  TextEditingController mobileNoController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController landmarkController = TextEditingController();
  TextEditingController remarkController = TextEditingController();
  TextEditingController companyNameController = TextEditingController();
  TextEditingController companyAddressController = TextEditingController();
  TextEditingController companygstNumberController = TextEditingController();
  TextEditingController customerCombinedController = TextEditingController();

  String? _selectedEvent;
  String? get selectedEvent => _selectedEvent;
  String? _selectedHoldOrderId;
  String? get selectedHoldOrderId => _selectedHoldOrderId;
  // Member variable for payment method
  String selectedPaymentMethod = 'Cash'; // Initialized with a default value
  String searchQuery = '';
  String? selectedDeliveryType = 'Pickup by Customer';
  void setSelectedEvent(String? event) {
    _selectedEvent = event;
  }

  void setSelectedHoldOrderId(String? holdOrderId) {
    _selectedHoldOrderId = holdOrderId;
    notifyListeners();
  }

  void setSelectedDeliveryType(String? newValue) {
    selectedDeliveryType = newValue;
  }

  void selectEmployee(String employee) {
    searchController.text = employee;
    filteredItems = [];
    notifyListeners();
  }

  // -------------------- FUNCTION -------------------- //
  void holdOrers(cartProvider, path, apiProvider, img1, img2) {
    print('📦 holdOrers() called');
    _heldOrder(cartProvider, path, apiProvider, img1, img2);
  }

  void clearControllers() {
    dateController.clear();
    timeController.clear();
    landmarkController.clear();
    addressController.clear();
    customerNameController.clear();
    mobileNoController.clear();
    searchController.clear();
    companyAddressController.clear();
    birthdaydateController.clear();
    companyNameController.clear();
    companygstNumberController.clear();
    remarkController.clear();
    combinedController.clear();
    dateController.clear();
    timeController.clear();
    mobileNoController.clear();
    customerCombinedController.clear();
    CartProvider().clearCart();

    notifyListeners();
  }

  @override
  void dispose() {
    dateController.dispose();
    timeController.dispose();
    mobileNoController.dispose();
    customerNameController.dispose();
    addressController.dispose();
    landmarkController.dispose();
    searchController.dispose();
    advanceAmountController.dispose(); // Dispose all controllers
    super.dispose();
  }

  void _startPayment(CartProvider cartProvider) {
    double orderAmount = cartProvider.getTotalAmount();
    String amountText = orderAmount.toString();
    double amount = double.tryParse(amountText) ?? 0.0;

    if (amount <= 0) {
      return;
    }

    final options = {
      'key': 'rzp_live_DkLaEuvsoESEhW',
      'amount': (amount * 100).toInt(),
      'name': 'NGXCORP PRIVATE LIMITED',
      'description': 'Payment for your order',
      'prefill': {'contact': '9840911266', 'email': 'prakash018@ngxcorp.com'},
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void showAdvancePaymentPopup(
    BuildContext context,
    CartSelectionProvider cartSelectionProvider,
    CartProvider cartProvider,
    String? path,
    ApiServiceSalesOrderProvider apiprovider,
    File? img1,
    File? img2,
    String customerType,
    String? audioOrderId,
    String? holdId,
  ) {
    bool hasItemLevelDiscount = cartProvider.cartItems.any(
      (item) => item.itemWiseDiscount != null && item.itemWiseDiscount! > 0,
    );
    orderAmount = cartProvider.getTotalAmount();
    discount = 0;
    customCharge = 0;
    totalAdvance = 0;
    deductedAmount = 0;
    totalAmount = orderAmount + customCharge - deductedAmount;
    TextEditingController advanceController = TextEditingController();

    advanceController.clear();

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            double padding = MediaQuery.of(context).size.width * 0.04;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.white],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade200, Colors.blue.shade600],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.payment_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Payment Details',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 🔹 Scrollable Payment Section
                    // Replace "Select Payment Method" section with your class
                    SizedBox(
                      height: 600,
                      child: PlaceOrderPaymentPrint(
                        totalAmount: totalAmount,
                        holdBillId: holdId ?? '',
                        orderId: salesOrderId ?? '',
                        discount: discount,
                        totalAdvance: totalAdvance,
                        cartSelectionProvider: cartSelectionProvider,
                        cartProvider: cartProvider,
                        apiprovider: apiprovider,
                        customCharge: customCharge,
                        selectedStoreType: selectedStoreType,
                        orderAmount: orderAmount,
                        remark: remarkController.text,
                        deductedAmount: deductedAmount,
                        customerType: customerType,
                        path: path,
                        img1: img1,
                        img2: img2,
                        audioOrderId: audioOrderId,
                        holdId: holdId,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeparator() {
    return Container(
      height: 50,
      width: 1.5,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildAmountInfo(String title, double amount) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade50,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  final Map<String, int> branchOrderCount = HashMap();

  String generateSaleOrderNo() {
    // Get the current year in YY format (last two digits of the year)
    String currentYear = DateFormat('yy').format(DateTime.now());

    // Fetch the stored branch data from Hive
    Branch? storedBranch = branchProvider.getStoredBranch(
      globalbranch.branchName,
    );

    // Check if branch data is found
    if (storedBranch == null) {
      return 'Error: Branch data not found';
    }

    // Get the aliasName from the stored branch
    String aliasName = storedBranch.aliasName;

    // Generate the sales order number in the desired format
    return 'SO$aliasName$currentYear';
  }

  Future<void> saveOrder(
    CartProvider cartProvider,
    CartSelectionProvider cartSelectionProvider,
    double totalAdvance,
    double orderAmount,
    double discount,
    double deductedAmount,
    double totalAmount,
    String remark,
    String? path,
    ApiServiceSalesOrderProvider apiProvider,
    File? img1,
    File? img2,
    String? audioOrderId,
    String? holdOrderId,
    String? selectedOrderOption,
    BuildContext context,
    Map<String, double> payments,
  ) async {
    print('🟢 [saveOrder] Triggered...');
    print('--------------------------------------------------');

    // ========================
    //  PAYMENT PROCESSING
    // ========================
    final List<double> advanceAmount = [];
    final List<List<String>> advancePaymentType = [];
    final List<List<double>> modeWiseAmount = [];
    final List<String> advanceDateTime = [];

    void addAdvancePayment(Map<String, double> payMap) {
      final filtered = Map.fromEntries(
        payMap.entries.where((e) => e.value > 0),
      );
      if (filtered.isEmpty) return;

      final total = filtered.values.fold<double>(0, (a, b) => a + b);
      advanceAmount.add(total);
      advancePaymentType.add(filtered.keys.toList(growable: false));
      modeWiseAmount.add(filtered.values.toList(growable: false));
      advanceDateTime.add(DateTime.now().toIso8601String());
    }

    if (payments.isNotEmpty) {
      addAdvancePayment(payments);
    }

    final double computedTotalAdvance = advanceAmount.fold<double>(
      0,
      (a, b) => a + b,
    );

    // ========================
    //  CART ITEM DETAILS
    // ========================
    final List<String> itemNames = globals.cartItems
        .map((e) => e.itemName)
        .toList();
    final List<String> varianceNames = globals.cartItems
        .map((e) => e.varianceName)
        .toList();
    final List<int> quantities = globals.cartItems
        .map((e) => e.quantity)
        .toList();
    final List<String> itemCodes = globals.cartItems
        .map((e) => e.itemCode)
        .toList();
    final List<String> uoms = globals.cartItems.map((e) => e.uom).toList();
    final List<int> taxs = globals.cartItems.map((e) => e.tax).toList();
    final List<double> weights = globals.cartItems
        .map((e) => e.weight)
        .toList();
    final List<int> prices = globals.cartItems
        .map((e) => e.pricePerKg)
        .toList();
    final List<int> boxQuantities = globals.cartItems
        .map((e) => e.boxQuantity ?? 0)
        .toList();
    final List<String> isBoxItem = globals.cartItems
        .map((e) => e.isBoxItem ?? '')
        .toList();
    final List<double> itemWiseDiscounts = globals.cartItems
        .map((e) => e.itemWiseDiscount ?? 0.0)
        .toList();
    final List<double> itemWiseDiscountAmounts = globals.cartItems
        .map((e) => e.itemWiseDiscountAmount ?? 0.0)
        .toList();

    final double customCharge =
        double.tryParse(cartProvider.customChargeController.text) ?? 0;

    final List<double> amounts = globals.cartItems.map((item) {
      final base = (item.uom == 'Pcs' || item.uom == 'Pkt')
          ? (item.pricePerKg * item.quantity).toDouble()
          : (item.weight * item.quantity * item.pricePerKg);
      final disc = (item.itemWiseDiscountAmount ?? 0.0);
      return base - disc;
    }).toList();

    final double itemTotal = amounts.fold<double>(0, (a, b) => a + b);
    final double totalAmount2 = itemTotal + customCharge;
    final double finalPrice = itemTotal + customCharge - deductedAmount;
    final double balanceAmount = finalPrice - computedTotalAdvance;

    // ========================
    //  ORDER METADATA
    // ========================
    final String saleOrderNo = generateSaleOrderNo();
    final String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    const String deviceName = "POS1";

    Directory? orderDir = await createOrderDir(saleOrderNo);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // ========================
    //  FILE SAVING (AUDIO/IMG)
    // ========================
    String? savedAudioPath;
    String? savedImg1Path;
    String? savedImg2Path;

    if (path != null && orderDir != null) {
      savedAudioPath = await saveFile(
        File(path),
        orderDir,
        '${saleOrderNo}_${timestamp}_audio',
      );
    }
    if (img1 != null && orderDir != null) {
      savedImg1Path = await saveFile(
        img1,
        orderDir,
        '${saleOrderNo}_${timestamp}_img1',
      );
    }
    if (img2 != null && orderDir != null) {
      savedImg2Path = await saveFile(
        img2,
        orderDir,
        '${saleOrderNo}_${timestamp}_img2',
      );
    }

    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);

    // ========================
    //  BUILD SALES ORDER OBJECT
    // ========================
    final salesOrder = SalesOrder(
      itemName: itemNames,
      varianceName: varianceNames,
      qty: quantities,
      uom: uoms,
      isBoxItem: isBoxItem,
      weight: weights,
      amount: amounts,
      boxQty: boxQuantities,
      totalAmount2: totalAmount2,
      branchId: storedBranch?.branchId ?? "",
      branchName: storedBranch?.branchName ?? "",
      aliasName: storedBranch?.aliasName ?? "",
      totalAmount: itemTotal,
      itemCode: itemCodes,
      tax: taxs,
      price: prices,
      deliveryDate: dateController.text,
      deliveryTime: timeController.text,
      event: (selectedEvent ?? ""),
      customerNumber: mobileNoController.text,
      customerName: customerNameController.text,
      deliveryType: (selectedDeliveryType ?? ""),
      address: addressController.text,
      landmark: landmarkController.text,
      discount: discount,
      discountAmount: deductedAmount,
      remark: remark,
      shiftId: globalsData.shiftId.value,
      customCharge: customCharge,
      advanceAmount: advanceAmount,
      advancePaymentType: advancePaymentType,
      modeWiseAmount: modeWiseAmount,
      finalPrice: finalPrice,
      balanceAmount: balanceAmount,
      saleOrderNo: saleOrderNo,
      orderDate: DateTime.now().toIso8601String(),
      orderTime: formattedTime,
      audioPath: savedAudioPath,
      imagePath1: savedImg1Path,
      imagePath2: savedImg2Path,
      employeeName: searchController.text,
      status: 'Confirm Order',
      advanceDateTime: advanceDateTime,
      companyName: companyNameController.text,
      companyAddress: companyAddressController.text,
      companyGST: companygstNumberController.text,
      orderType: (selectedOrderOption ?? ""),
      eventDate: birthdaydateController.text,
      itemWiseDiscount: itemWiseDiscounts,
      itemWiseDiscountAmount: itemWiseDiscountAmounts,
      holdOrderId: patchHoldOrderId,
      approvalOrderId: approvalOrderId,
    );

    try {
      // ========================
      //  SAVE TO HIVE
      // ========================
      final salesOrderBox = HiveManager.salesOrderBox;
      await salesOrderBox.put(saleOrderNo, salesOrder.toJson());

      // ========================
      //  SEND SALES ORDER TO SERVER
      // ========================
      final postData = {
        "data": salesOrder.toJson(),
        "type": "salesOrder",
        "deviceName": deviceName,
        "sync": "No",
        "WaitingForDiscountApproval": "No",
        "edit": "No",
      };

      await sendSalesOrderDataToServer(postData);

      // ========================
      //  PATCH HOLD ORDER (CONVERT)
      // ========================
      if (patchHoldOrderId.isNotEmpty) {
        print('🔁 [HoldOrder] Converting Hold Order → Sale Order...');
        Map<String, dynamic> requestBody = {"status": "HoldOrder Converted"};

        final patchData = {
          "data": requestBody,
          "type": "patchHoldOrder",
          "sync": "No",
          "edit": "No",
          "holdOrderId": patchHoldOrderId,
          "deviceName": deviceName,
        };

        print('📦 [patchHoldOrder] Sending data: ${jsonEncode(patchData)}');
        await sendSalesOrderDataToServer(patchData);
        print('✅ Hold Order converted and patched successfully.');
        await fetchHolderFromHive();
        notifyListeners();
      }

      // ========================
      //  CLEANUP AFTER SUCCESS
      // ========================
      try {
        if (savedAudioPath != null && await File(savedAudioPath).exists()) {
          await File(savedAudioPath).delete();
        }
        if (savedImg1Path != null && await File(savedImg1Path).exists()) {
          await File(savedImg1Path).delete();
        }
        if (savedImg2Path != null && await File(savedImg2Path).exists()) {
          await File(savedImg2Path).delete();
        }

        photoScreen = null;
        audioPlayer = null;
        savedAudioPath = null;
        savedImg1Path = null;
        savedImg2Path = null;

        clearControllers();
        CartProvider().clearCart();
        cartSelectionProvider.clearSelections();
        advanceDateTime.clear();
        advancePaymentType.clear();
        modeWiseAmount.clear();
        advanceAmount.clear();
        cartProvider.customChargeController.clear();

        isSubmitting = false;
        showAudioandImage = false;
        pickedImage1 = null;
        pickedImage2 = null;
        recordedFilePath = '';

        print('✅ [Cleanup] Temporary data cleared.');
      } catch (e) {
        print('⚠️ [Cleanup Warning] $e');
      }

      print('✅ [saveOrder] Completed Successfully!');
    } catch (e, st) {
      print('❌ [saveOrder] Error: $e');
      print(st);
      rethrow;
    } finally {
      cartSelectionProvider.clearSelections();
      advanceDateTime.clear();
      advancePaymentType.clear();
      modeWiseAmount.clear();
      advanceAmount.clear();
      cartProvider.customChargeController.clear();

      isSubmitting = false;
      showAudioandImage = false;
      pickedImage1 = null;
      pickedImage2 = null;
      recordedFilePath = '';
      audioPlayer = null;
      photoScreen = null;
      path = null;
      img1 = null;
      img2 = null;

      notifyListeners();
    }
  }

  int _approvalOrderCounter = 0;
  String generateApprovalOrderId() {
    _approvalOrderCounter++;
    return 'Approval${_approvalOrderCounter.toString().padLeft(2, '0')}';
  }

  void submitForApproval(
    BuildContext context,
    CartSelectionProvider cartSelectionProvider,
    CartProvider cartProvider,
    String recordedFilePath,
    ApiServiceSalesOrderProvider apiService,
    File? pickedImage1,
    File? pickedImage2,
    String customerType,
  ) async {
    try {
      // 🔹 Multi-advance data structures

      // Step 1: Initial values
      double totalAdvance = 0.0;
      double balanceAmount = cartProvider.getTotalAmount();
      List<double> advanceAmountList = [0.0];
      List<String> advanceDateTime = [DateTime.now().toIso8601String()];

      // Step 2: Collect cart item details
      List<String> itemNames = globals.cartItems
          .map((item) => item.itemName)
          .toList();
      List<String> varianceNames = globals.cartItems
          .map((item) => item.varianceName)
          .toList();
      List<int> quantities = globals.cartItems
          .map((item) => item.quantity)
          .toList();
      List<String> itemCodes = globals.cartItems
          .map((item) => item.itemCode.toString())
          .toList();
      List<String> uoms = globals.cartItems
          .map((item) => item.uom.toString())
          .toList();
      List<int> taxs = globals.cartItems.map((item) => item.tax).toList();
      List<double> weights = globals.cartItems
          .map((item) => item.weight)
          .toList();
      List<int> prices = globals.cartItems
          .map((item) => item.pricePerKg)
          .toList();

      // Step 3: Calculate amounts
      List<double> amounts = globals.cartItems.map((item) {
        double amt = (item.uom == 'Pcs' || item.uom == 'Pkt')
            ? item.pricePerKg * item.quantity.toDouble()
            : item.weight * item.quantity * item.pricePerKg;
        return amt;
      }).toList();
      approvalOrderId = generateApprovalOrderId();
      // Step 4: Create SalesOrder object
      SalesOrder approvalOrder = SalesOrder(
        itemName: itemNames,
        varianceName: varianceNames,
        qty: quantities,
        uom: uoms,
        weight: weights,
        amount: amounts,
        totalAmount2: cartProvider.getTotalAmount(),
        branchId: storedBranch!.branchId,
        branchName: storedBranch!.branchName,
        totalAmount: cartProvider.getTotalAmount(),
        itemCode: itemCodes,
        tax: taxs,
        price: prices,
        deliveryDate: dateController.text,
        deliveryTime: timeController.text,
        event: selectedEvent.toString(),
        customerNumber: mobileNoController.text,
        customerName: customerNameController.text,
        deliveryType: selectedDeliveryType.toString(),
        address: addressController.text,
        shiftId: globalsData.shiftId.toString(),
        landmark: landmarkController.text,
        discount: 0.0,
        discountAmount: 0.0,
        remark: remarkController.text,
        advanceAmount: advanceAmountList,
        finalPrice: cartProvider.getTotalAmount(),
        balanceAmount: balanceAmount,
        saleOrderNo: generateSaleOrderNo(),
        orderDate: DateTime.now().toIso8601String(),
        orderTime: DateFormat('hh:mm a').format(DateTime.now()),
        employeeName: searchController.text,
        status: 'Waiting for Approval',
        advanceDateTime: advanceDateTime,
        companyName: companyNameController.text,
        companyAddress: companyAddressController.text,
        companyGST: companygstNumberController.text,
        orderType: selectedOrderOption,
        holdOrderId: patchHoldOrderId,
        approvalOrderId: approvalOrderId,
        approvalDetails: [
          ApprovalOrderDetail(
            approvalType: "Discount",
            approvalStatus: 'Sending to Approval',
            approvalDate: DateTime.now().toIso8601String(),
            summary: 'No',
          ),
        ],
      );

      // Step 5: Encode and send
      String jsonApprovalOrder = jsonEncode({
        "data": approvalOrder.toJson(),
        "type": "salesApprovalOrder",
        'sync': "No",
        'edit': 'No',
        'approvalStatusChanged': 'No',
      });

      // Step 6: Send to server
      await sendApprovalDataToServer(jsonDecode(jsonApprovalOrder));

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order submitted for approval successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting approval: $e')));
    } finally {
      isSubmitting = false;
      clearControllers();
      cartProvider.clearCart();
      cartSelectionProvider.clearSelections();
      advanceDateTime?.clear();
      advancePaymentType?.clear();
      isSubmitting = false;
      showAudioandImage = false;

      notifyListeners();
    }
  }

  Future<void> sendHoldDataToServer(Map<String, dynamic> holdData) async {
    _sendInvoiceCallCount++;

    try {
      final jsonData = jsonEncode(holdData);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  Future<void> sendForApproval(
    CartProvider cartProvider,
    double totalAdvance,
    double orderAmount,
    double discount,
    double deductedAmount,
    double customCharge,
    double totalAmount,
    String remark,
    String? path,
    ApiServiceSalesOrderProvider apiProvider,
    File? img1,
    File? img2,
    String? audioOrderId,
    String? holdId,
    String? selectedOrderOption,
    BuildContext context,
    Map<String, double> payments, // 👈 new param
  ) async {
    // if (isSubmitting) return; // Prevent double submission
    // isSubmitting = true;

    double balanceAmount = totalAmount - totalAdvance;
    List<double> advanceAmountList = [totalAdvance];
    List<double> cashAdvance = [0.0];
    List<double> cardAdvance = [0.0];
    List<double> upiAdvance = [0.0];

    if (selectedPaymentMethod == 'Cash') {
      cashAdvance[0] = totalAdvance; // Update the first element of cashAdvance
    } else if (selectedPaymentMethod == 'Card') {
      cardAdvance[0] = totalAdvance; // Update the first element of cardAdvance
    } else if (selectedPaymentMethod == 'UPI') {
      upiAdvance[0] = totalAdvance; // Update the first element of upiAdvance
    }
    String currentDateTime = DateTime.now().toIso8601String();
    advanceDateTime ??= [];
    advancePaymentType ??= [];

    // Add datetime and payment type
    advanceDateTime!.add(currentDateTime);
    advancePaymentType!.add(selectedPaymentMethod);

    List<String> itemNames = globals.cartItems
        .map((item) => item.itemName)
        .toList();
    List<String> varianceNames = globals.cartItems
        .map((item) => item.varianceName)
        .toList();
    List<int> quantities = globals.cartItems
        .map((item) => item.quantity)
        .toList();
    List<String> itemCodes = globals.cartItems
        .map((item) => item.itemCode.toString())
        .toList();
    List<String> uoms = globals.cartItems
        .map((item) => item.uom.toString())
        .toList();
    List<int> taxs = globals.cartItems.map((item) => item.tax).toList();
    List<double> weights = globals.cartItems
        .map((item) => item.weight)
        .toList();
    List<int> prices = globals.cartItems
        .map((item) => item.pricePerKg)
        .toList();

    List<double> amounts = globals.cartItems.map((item) {
      double calculatedAmount;
      if (item.uom == 'Pcs' || item.uom == 'Pkt') {
        calculatedAmount = item.pricePerKg * item.quantity.toDouble();
      } else {
        calculatedAmount = item.weight * item.quantity * item.pricePerKg;
      }
      return calculatedAmount;
    }).toList();

    String saleOrderNo = generateSaleOrderNo();
    // String formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    String approvalType;
    String approvalStatus;
    if (selectedOrderOption == 'Cheque') {
      approvalType = 'Cheque';
      approvalStatus = 'Pending Cheque Payment';
    } else {
      approvalType = 'Discount';
      approvalStatus = 'Sending to Approval';
    }
    SalesOrder salesOrder = SalesOrder(
      itemName: itemNames,
      varianceName: varianceNames,
      qty: quantities,
      uom: uoms,
      weight: weights,
      amount: amounts,
      totalAmount2: totalAmount,
      branchId: storedBranch!.branchId,
      branchName: storedBranch!.branchName,
      totalAmount: totalAmount,
      itemCode: itemCodes,
      tax: taxs,
      price: prices,
      deliveryDate: dateController.text,
      deliveryTime: timeController.text,
      event: selectedEvent.toString(),
      customerNumber: mobileNoController.text,
      customerName: customerNameController.text,
      deliveryType: selectedDeliveryType.toString(),
      address: addressController.text,
      landmark: landmarkController.text,
      discount: discount,
      discountAmount: deductedAmount,
      remark: remark,
      customCharge: customCharge,
      advanceAmount: advanceAmountList,
      shiftId: globalsData.shiftId.toString(),
      finalPrice: orderAmount,
      balanceAmount: balanceAmount,
      saleOrderNo: saleOrderNo,
      orderDate: DateTime.now().toIso8601String(),
      orderTime: formattedTime,
      employeeName: searchController.text,
      status: 'Waiting for Approval',
      advanceDateTime: advanceDateTime,
      companyName: companyNameController.text,
      companyAddress: companyAddressController.text,
      companyGST: companygstNumberController.text,
      orderType: selectedOrderOption,
      holdOrderId: patchHoldOrderId,
      approvalOrderId: approvalOrderId,
      approvalDetails: [
        ApprovalOrderDetail(
          approvalType: approvalType,
          // approvalStatus: approvalStatus,
          // approvalDate: DateTime.now().toIso8601String(),
          summary: 'No',
        ),
      ],
      // cash: cashAdvance,
      // card: cardAdvance,
      // upi: upiAdvance,
    );

    // String jsonSalesOrder = jsonEncode(salesOrder.toJson());

    try {
      String jsonSalesOrder = jsonEncode({
        "data": [salesOrder.toJson()],
        "type": "salesApprovalOrder",
        'sync': "No",
        'edit': 'No',
        'waitingForApprovalResult': 'Yes',
        "saleOrderNo": salesOrder.saleOrderNo,
      });

      await sendApprovalDataToServer(jsonDecode(jsonSalesOrder));
      // Check if it reaches here
    } catch (e) {
      // Catches any errors during the request
    } finally {
      clearControllers();
      cartProvider.clearCart();
      isSubmitting = false;
      showAudioandImage = false;
      advanceDateTime!.clear();
      advancePaymentType!.clear();
      audioOrderId = null;
      // clearAudioAndPhotoIds();
      notifyListeners();
    }
  }

  Future<void> deleteHoldOrderFromHive(String holdOrderId) async {
    try {
      print('🟢 Attempting to delete hold order: $holdOrderId');

      final box = HiveManager.holdOrderBox;
      print('📦 Hive box contains ${box.keys.length} keys before deletion');

      // Check inside 'data'
      final keyToDelete = box.keys.firstWhere(
        (key) => box.get(key)?['data']?['holdOrderId'] == holdOrderId,
        orElse: () => null,
      );
      print("keyToDelete: $keyToDelete");

      if (keyToDelete != null) {
        print(
          '✅ Found key $keyToDelete for hold order $holdOrderId. Deleting...',
        );
        await box.delete(keyToDelete);

        // Remove from the in-memory list
        final removedCount = _hiveholdSalesOrders.removeWhere(
          (order) => order['data']?['holdOrderId'] == holdOrderId,
        );
        // print('🗑️ Removed $removedCount order(s) from in-memory list');
        fetchHolderFromHive();
        notifyListeners();
        print('🎉 Hold order $holdOrderId deleted successfully');
      } else {
        print('⚠️ Hold order $holdOrderId not found in Hive');
      }

      print('📦 Hive box now contains ${box.keys.length} keys after deletion');
    } catch (e, stackTrace) {
      print('❌ Failed to delete hold order: $e');
      print(stackTrace);
    }
  }

  int _holdOrderCounter = 0;

  // Function to generate holdOrderId like HOLD01, HOLD02...
  String generateHoldOrderId() {
    _holdOrderCounter++;
    return 'HOLD${_holdOrderCounter.toString().padLeft(2, '0')}';
  }

  Future<void> _heldOrder(
    CartProvider cartProvider,
    String path,
    ApiServiceSalesOrderProvider apiProvider,
    File? img1,
    File? img2,
  ) async {
    print("✅ Step 1: Start _heldOrder function");

    print('🛒 [Cart] Collecting cart item details...');
    final List<String> itemNames = globals.cartItems
        .map((e) => e.itemName)
        .toList();
    final List<String> varianceNames = globals.cartItems
        .map((e) => e.varianceName)
        .toList();
    final List<int> quantities = globals.cartItems
        .map((e) => e.quantity)
        .toList();
    final List<String> itemCodes = globals.cartItems
        .map((e) => e.itemCode)
        .toList();
    final List<String> uoms = globals.cartItems.map((e) => e.uom).toList();
    final List<int> taxs = globals.cartItems.map((e) => e.tax).toList();
    final List<double> weights = globals.cartItems
        .map((e) => e.weight)
        .toList();
    final List<int> prices = globals.cartItems
        .map((e) => e.pricePerKg)
        .toList();
    final List<int> boxQuantities = globals.cartItems
        .map((e) => e.boxQuantity ?? 0)
        .toList();
    final List<String> isBoxItem = globals.cartItems
        .map((e) => e.isBoxItem ?? '')
        .toList();
    final List<double> itemWiseDiscounts = globals.cartItems
        .map((e) => e.itemWiseDiscount ?? 0.0)
        .toList();
    final List<double> itemWiseDiscountAmounts = globals.cartItems
        .map((e) => e.itemWiseDiscountAmount ?? 0.0)
        .toList();

    print('✅ [Cart] ${globals.cartItems.length} items found.');

    final double customCharge =
        double.tryParse(cartProvider.customChargeController.text) ?? 0;
    print('⚙️ Custom Charge: $customCharge');

    final List<double> amounts = globals.cartItems.map((item) {
      final base = (item.uom == 'Pcs' || item.uom == 'Pkt')
          ? (item.pricePerKg * item.quantity).toDouble()
          : (item.weight * item.quantity * item.pricePerKg);
      final disc = (item.itemWiseDiscountAmount ?? 0.0);
      final result = base - disc;
      print(
        '🧮 Item "${item.itemName}" | Base: $base | Discount: $disc | Final: $result',
      );
      return result;
    }).toList();

    final double itemTotal = amounts.fold<double>(0, (a, b) => a + b);
    final double totalAmount2 = itemTotal + customCharge;
    final double finalPrice = itemTotal + customCharge - deductedAmount;

    print('🧾 Totals:');
    print('   🔹 Item Total: $itemTotal');
    print('   🔹 Total + Custom Charge: $totalAmount2');
    print('   🔹 Final Price: $finalPrice');

    final String saleOrderNo = generateSaleOrderNo();
    final String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    const String deviceName = "POS1";

    print('🆔 Generated Sale Order No: $saleOrderNo');
    print('🕒 Time: $formattedTime');
    print('💻 Device: $deviceName');

    Directory? orderDir = await createOrderDir(saleOrderNo);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    print('📂 Order Directory: $orderDir');
    print('⏱ Timestamp: $timestamp');

    // 🔹 Save Files
    String? savedAudioPath;
    String? savedImg1Path;
    String? savedImg2Path;

    if (path != null && orderDir != null) {
      savedAudioPath = await saveFile(
        File(path),
        orderDir,
        '${saleOrderNo}_${timestamp}_audio',
      );
      print('🎧 Audio File Saved: $savedAudioPath');
    }

    if (img1 != null && orderDir != null) {
      savedImg1Path = await saveFile(
        img1,
        orderDir,
        '${saleOrderNo}_${timestamp}_img1',
      );
      print('🖼️ Image1 File Saved: $savedImg1Path');
    }

    if (img2 != null && orderDir != null) {
      savedImg2Path = await saveFile(
        img2,
        orderDir,
        '${saleOrderNo}_${timestamp}_img2',
      );
      print('🖼️ Image2 File Saved: $savedImg2Path');
    }
    String holdOrderId = generateHoldOrderId();
    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
    print('🏢 Branch Info: ${storedBranch?.branchName ?? "Unknown"}');

    // Construct the HeldOrder object
    print("📋 Creating HeldOrder object...");
    HeldOrder holdsalesOrder = HeldOrder(
      salesOrderId: '',
      itemName: itemNames,
      varianceName: varianceNames,
      qty: quantities,
      uom: uoms,
      isBoxItem: isBoxItem,
      weight: weights,
      amount: amounts,
      boxQty: boxQuantities,
      totalAmount2: totalAmount2,
      branchId: storedBranch?.branchId ?? "",
      branchName: storedBranch?.branchName ?? "",
      aliasName: storedBranch?.aliasName ?? "",
      totalAmount: itemTotal,
      itemCode: itemCodes,
      tax: taxs,
      price: prices,
      deliveryDate: dateController.text,
      deliveryTime: timeController.text,
      event: (selectedEvent ?? ""),
      customerNumber: mobileNoController.text,
      customerName: customerNameController.text,
      deliveryType: (selectedDeliveryType ?? ""),
      address: addressController.text,
      landmark: landmarkController.text,
      discount: discount,
      discountAmount: deductedAmount,
      remark: remarkController.text,
      shiftId: globalsData.shiftId.value,
      customCharge: customCharge,

      finalPrice: finalPrice,

      saleOrderNo: saleOrderNo,
      orderDate: DateTime.now().toIso8601String(),
      orderTime: formattedTime,
      audioPath: savedAudioPath,
      imagePath1: savedImg1Path,
      imagePath2: savedImg2Path,
      employeeName: searchController.text,
      status: 'Hold Order',
      advanceDateTime: advanceDateTime,
      companyName: companyNameController.text,
      companyAddress: companyAddressController.text,
      companyGST: companygstNumberController.text,
      orderType: (selectedOrderOption ?? ""),
      eventDate: birthdaydateController.text,
      itemWiseDiscount: itemWiseDiscounts,
      itemWiseDiscountAmount: itemWiseDiscountAmounts,
      holdOrderId: holdOrderId,
      approvalOrderId: approvalOrderId,
    );

    print("✅ HeldOrder object created successfully.");

    print("🧾 Converting HeldOrder to JSON...");
    // Prepare JSON
    print("holdsalesOrder.toJson(): ${holdsalesOrder.toJson()}");
    print("hold order data : ${[holdsalesOrder.toJson()]}");
    String jsonHoldSalesOrder = jsonEncode({
      "data": holdsalesOrder.toJson(),
      "type": "holdOrder",
      'sync': "No",
      'edit': 'No',
    });
    await sendHoldDataToServer(jsonDecode(jsonHoldSalesOrder));
    print("final data: ${jsonDecode(jsonHoldSalesOrder)}");
    print('📤 Final Hold Order JSON: $jsonHoldSalesOrder');
    await fetchHolderFromHive();
    // 🧹 [CLEANUP AFTER SUCCESSFUL SERVER SYNC]
    try {
      photoScreen = null;
      audioPlayer = null;

      img1 = null;
      img2 = null;

      // Clear temp selections, inputs, and UI state
      clearControllers();
      CartProvider().clearCart();

      cartProvider.customChargeController.clear();

      isSubmitting = false;
      showAudioandImage = false;
      pickedImage1 = null;
      pickedImage2 = null;
      recordedFilePath = '';

      notifyListeners();
      print("✅ [Cleanup] All media and temp data cleared successfully.");
    } catch (e) {
      print("⚠️ [Cleanup Warning] Post-upload cleanup failed: $e");
    }

    notifyListeners();
    // 🧩 Clear references (local variables)
    path = '';
    img1 = null;
    img2 = null;

    print("✅ [Cleanup] Cleared local and global media references.");

    notifyListeners();
    // Send via WebSocket or API
    try {
      print("🌐 Sending hold order data to server...");

      print("✅ Hold data sent successfully.");
    } catch (e) {
      print('❌ Error while posting order: $e');
    } finally {
      print("🧹 Clearing inputs and resetting state...");
      clearControllers();
      cartProvider.clearCart();
      isSubmitting = false;
      showAudioandImage = false;
      advanceDateTime?.clear();
      advancePaymentType?.clear();
      print("✅ Hold order flow completed.");
    }
  }

  //
}

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
import 'package:yenposapp/Global/Audio%20Player/audio_provider.dart';
import 'package:yenposapp/Global/allorderprint.dart';
import 'package:yenposapp/Global/globals_data.dart' as globalsData;
import 'package:yenposapp/screens/sales_order/sales_order_print/so_placeorder_payment_print.dart';
import 'package:yenposapp/screens/sales_order/sales_order_providers/cart_selection_provider.dart';
import 'package:yenposapp/screens/sales_order/screens/create_salesOrder.dart/create_sales_order_widgets/storetype_selection_dialogue.dart';
import 'package:yenposapp/screens/sales_order/screens/model/sales_invoicemodel.dart';
// import 'package:yenposapp/screens/take_away_orders/screens/create_salesOrder.dart/create_sales_order.dart';
import '../../../Global/branchSelection.dart';
import '../../../Global/salesOrder_print.dart';
import '../../../data/global_data_manager.dart';
import '../../../services/branchwise_item_fetch.dart';
import '../../../services/hive_manager.dart';
import '../../../services/websocketService.dart';
import '../sales_order_print/invoicePrint.dart';
import '../screens/all_orders_page/services/get_sales_order_service.dart';
import '../screens/create_salesOrder.dart/models/approval_order_model.dart';
import '../screens/create_salesOrder.dart/models/held_order_model.dart';
import '../screens/create_salesOrder.dart/models/sale_order_model.dart';
import '../screens/model/sales_order_display_model.dart';
import 'cartProvider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http_parser/http_parser.dart';
import '../globals.dart' as globals;
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import '../../../Global/globals_data.dart' as globalbranch;
import 'modifyOrderProvider.dart';
import '../../kot_screen/global/globals.dart' as globals;

import 'saveAudioandImageFile.dart';

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

  CustomerScreenProvider() : keyboardKey = GlobalKey() {
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

      advanceDateTime: [], totalAmount2: 0.0, finalPrice: 0.0,
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

  final GlobalKey keyboardKey;
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
      Map<String, dynamic> paymentData) async {
    try {
      final jsonData = jsonEncode(paymentData);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  Future<void> sendSoAddNewCustomerServer(
      Map<String, dynamic> customerdata) async {
    try {
      final jsonData = jsonEncode(customerdata);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  Future<List<Map<String, dynamic>>> fetchHolderFromHive() async {
    try {
      WebSocketService webSocketService = WebSocketService(
        CustomerScreenProvider(),
        SalesInvoiceReceiptPrinter(),
      );
      List<Map<String, dynamic>> hiveOrders =
          await webSocketService.getSavedHoldOrders();

      for (int i = 0; i < hiveOrders.length; i++) {}

      _rawOrders = hiveOrders;
      _hiveholdSalesOrders = List.from(_rawOrders);

      notifyListeners();

      return _hiveholdSalesOrders;
    } catch (e) {
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
    invoiceReceiptPrinter.discountController =
        (data['discount'] ?? 0.0).toDouble();
    invoiceReceiptPrinter.customChargeController =
        (data['customCharge'] ?? 0.0).toDouble();
    invoiceReceiptPrinter.selectedPaymentOptionValue =
        data['paymentOption'] ?? '';
    invoiceReceiptPrinter.totalAmount = (data['totalAmount'] ?? 0.0).toDouble();

    invoiceReceiptPrinter.advanceAmount =
        (data['advanceAmount'] is List && data['advanceAmount'].isNotEmpty)
            ? (data['advanceAmount'][0] ?? 0.0).toDouble()
            : 0.0;

    invoiceReceiptPrinter.balanceAmount =
        (data['balanceAmount'] ?? 0.0).toDouble();
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

    receiptPrinter.discountAmountController =
        (data['discountAmount'] ?? 0.0).toDouble();

    receiptPrinter.customChargeController =
        (data['customCharge'] ?? 0.0).toDouble();

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
            (data['advanceAmount'] as List).map((x) => (x as num).toDouble()))
        : <double>[];

    receiptPrinter.advanceDateTime =
        List<String>.from(data['advanceDateTime'] ?? []);

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
          weight:
              (data['weight'].length > i ? data['weight'][i] : 0.0).toDouble(),
          itemWiseDiscount: (data['itemWiseDiscount'] != null &&
                  data['itemWiseDiscount'].length > i)
              ? (data['itemWiseDiscount'][i] as num).toDouble()
              : 0.0,
          itemWiseDiscountAmount: (data['itemWiseDiscountAmount'] != null &&
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

    receiptPrinter.discountAmountController =
        (data['discountAmount'] ?? 0.0).toDouble();

    receiptPrinter.customChargeController =
        (data['customCharge'] ?? 0.0).toDouble();

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
            (data['advanceAmount'] as List).map((x) => (x as num).toDouble()))
        : <double>[];

    receiptPrinter.advanceDateTime =
        List<String>.from(data['advanceDateTime'] ?? []);

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
          weight:
              (data['weight'].length > i ? data['weight'][i] : 0.0).toDouble(),
          itemWiseDiscount: (data['itemWiseDiscount'] != null &&
                  data['itemWiseDiscount'].length > i)
              ? (data['itemWiseDiscount'][i] as num).toDouble()
              : 0.0,
          itemWiseDiscountAmount: (data['itemWiseDiscountAmount'] != null &&
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

    final lastShownDate =
        DateTime.fromMillisecondsSinceEpoch(lastShownTimestamp);
    final currentDate = DateTime.now();

    final isSameDay = lastShownDate.year == currentDate.year &&
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
        builder: (context) => StoreTypeSelectionDialog(
          onStoreTypeSelected: saveStoreType,
        ),
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
      Map<String, dynamic> salesOrderData) async {
    try {
      // Read file contents if they exist
      if (salesOrderData['audioPath'] != null) {
        final audioFile = File(salesOrderData['audioPath']);
        final audioBytes = await audioFile.readAsBytes();
        salesOrderData['audioContent'] =
            base64Encode(audioBytes); // Encode as base64
        salesOrderData['audioPath'] =
            null; // Remove the path since we're sending the content
      }
      if (salesOrderData['image1Path'] != null) {
        final image1File = File(salesOrderData['image1Path']);
        final image1Bytes = await image1File.readAsBytes();
        salesOrderData['image1Content'] = base64Encode(image1Bytes);
        salesOrderData['image1Path'] = null;
      }
      if (salesOrderData['image2Path'] != null) {
        final image2File = File(salesOrderData['image2Path']);
        final image2Bytes = await image2File.readAsBytes();
        salesOrderData['image2Content'] = base64Encode(image2Bytes);
        salesOrderData['image2Path'] = null;
      }

      final jsonData = jsonEncode(salesOrderData);
      _channel.sink.add(jsonData);
    } catch (e) {
      throw e;
    }
  }

  Future<void> sendApprovalDataToServer(
      Map<String, dynamic> approvalData) async {
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

  void onSuggestionSelected(Map<String, String> suggestion) {
    mobileNoController.text = suggestion['mobile']!;
    customerNameController.text = suggestion['name']!;
    suggestions = []; // Clear suggestions after selection
    notifyListeners();
  }

  Future<void> cancelOrder(
      String salesOrderId, Map<String, dynamic> payload) async {
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
      String salesOrderId, Map<String, dynamic> payload) async {
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

  Future<void> fetchSuggestions(String query) async {
    if (query.isEmpty) {
      suggestions = [];
      notifyListeners();
      return;
    }

    final url = Uri.parse('http://192.168.29.8:8881/customer/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List customers = json.decode(response.body);
        suggestions = customers
            .where((customer) => customer['customerPhoneNumber']
                .toString()
                .startsWith(query)) // Filter by mobile number prefix
            .map((customer) => {
                  'mobile': customer['customerPhoneNumber'].toString(),
                  'name': customer['customerName'].toString(),
                })
            .toList();
        notifyListeners();
      } else {
        throw Exception('Failed to load customers');
      }
    } catch (e) {
      suggestions = [];
      notifyListeners();
    }
  }

  void fetchCompanySuggestionsDebounced(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      fetchCompanySuggestions(query);
    });
  }

  Future<bool> addCompany(String name, String address, String gst) async {
    try {
      final response = await http.post(
        Uri.parse('https://yenerp.com/fastapi/companies/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'companyName': name,
          'companyAddress': address,
          'companyGST': gst,
          'status': '1',
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchCompanySuggestions(String query) async {
    if (query.isEmpty) {
      suggestions = [];
      notifyListeners();
      return;
    }

    final url = Uri.parse('https://yenerp.com/companies/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List customers = json.decode(response.body);

        suggestions = customers
            .where((customer) => customer['companyName']
                .toString()
                .startsWith(query)) // Filter by company name prefix
            .map((customer) => {
                  'name': customer['companyName'].toString(),
                  'address': customer['companyAddress'].toString(),
                  'gst': customer['companyGST'].toString(),
                })
            .toList();
        notifyListeners();
      } else {
        throw Exception('Failed to load companies');
      }
    } catch (e) {
      suggestions = [];
      notifyListeners();
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
        (item) => item.itemWiseDiscount != null && item.itemWiseDiscount! > 0);
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
                              //                         keyboardKey: keyboardKey,
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

      await sendInvoiceDataToServer(
        jsonDecode(jsonadvanceSalesOrder),
      );
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
    DateTime parsedOrderDate =
        DateFormat("dd-MM-yyyy").parse(saleOrders.orderDate);
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
          'http://192.168.1.130:8888/fastapi/salesorders/${saleOrders.salesOrderId}');

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
  String holdOrderId = "";
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
    notifyListeners();
  }

  void setSelectedHoldOrderId(String? holdOrderId) {
    _selectedHoldOrderId = holdOrderId;
    notifyListeners();
  }

  void setSelectedDeliveryType(String? newValue) {
    selectedDeliveryType = newValue;
    notifyListeners();
  }

  void selectEmployee(String employee) {
    searchController.text = employee;
    filteredItems = [];
    notifyListeners();
  }

  void holdOrers(cartProvider, path, apiProvider, img1, img2) {
    _heldOrder(cartProvider, path, apiProvider, img1, img2);
  }

  Future<void> updateCustomId(String curentCustomId, String CustomId) async {
    final String currentCustomId =
        curentCustomId; // Replace with actual custom ID
    final String newCustomId = CustomId; // New custom ID

    final url = Uri.parse(
        'https://yenerp.com/fastapi/audios/media/$currentCustomId/audio');

    final response = await http.patch(
      url,
      body: {
        'new_custom_id': newCustomId,
      },
    );

    if (response.statusCode == 200) {
    } else {}
  }

  Future<void> updateImageId(String currentCustomId, String newCustomId) async {
    final url =
        Uri.parse("https://yenerp.com/fastapi/imageOrder/media/batch_update");

    try {
      // Prepare the request body
      final body = {
        'current_custom_id': currentCustomId,
        'new_custom_id': newCustomId,
      };

      // Send the PATCH request
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        // Parse the response if needed
        final data = json.decode(response.body);
      } else {}
    } catch (e) {}
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
    _selectedEvent = null;
    selectedDeliveryType = null;
    customerCombinedController.clear();
    notifyListeners(); // Optional, if you're using ChangeNotifier
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

  Future<bool> addCustomer(String mobile, String name) async {
    try {
      final response = await http.post(
        Uri.parse('https://yenerp.com/fastapi/customers/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customerPhoneNumber': mobile,
          'customerName': name,
          'status': '1'
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding customer: $e');
      return false;
    }
  }

  bool isFormValid = true;
  List<Map<String, String>> suggestions = [];

  Future<List<Map<String, String>>> fetchCustomerList() async {
    try {
      final response = await http.get(
        // Uri.parse('https://yenerp.com/fastapi/customer/'),
        Uri.parse('https://yenerp.com/fastapi/customers/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> customerData = json.decode(response.body);
        return customerData.map((data) {
          return {
            'customerName': data['customerName'] as String,
            'customerPhoneNumber': data['customerPhoneNumber'] as String,
          };
        }).toList();
      } else {
        throw Exception('Failed to load customer');
      }
    } catch (e) {
      throw Exception('Error fetching customer: $e');
    }
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
        'wallets': ['paytm']
      }
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
        (item) => item.itemWiseDiscount != null && item.itemWiseDiscount! > 0);
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
                                  const Icon(Icons.payment_rounded,
                                      color: Colors.white, size: 28),
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
    Branch? storedBranch =
        branchProvider.getStoredBranch(globalbranch.branchName);

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
    print("🚀 [saveOrder] Function called at ${DateTime.now()}");

    final List<double> advanceAmount = [];
    final List<List<String>> advancePaymentType = [];
    final List<List<double>> modeWiseAmount = [];
    final List<String> advanceDateTime = [];

    void addAdvancePayment(Map<String, double> payMap) {
      print("💰 [Advance Payment] Incoming payment map: $payMap");
      final filtered = Map.fromEntries(
        payMap.entries.where((e) => e.value > 0),
      );
      if (filtered.isEmpty) {
        print("⚠️ No valid payment entries found, skipping.");
        return;
      }

      final total = filtered.values.fold<double>(0, (a, b) => a + b);
      print(
          "✅ [Advance Payment] Total: $total, Modes: ${filtered.keys.toList()}");

      advanceAmount.add(total);
      advancePaymentType.add(filtered.keys.toList(growable: false));
      modeWiseAmount.add(filtered.values.toList(growable: false));
      advanceDateTime.add(DateTime.now().toIso8601String());
    }

    if (payments.isNotEmpty) {
      print("💳 [Payments] Found ${payments.length} payment methods");
      addAdvancePayment(payments);
    } else {
      print("⚠️ [Payments] No payments provided");
    }

    final double computedTotalAdvance =
        advanceAmount.fold<double>(0, (a, b) => a + b);
    print("💵 [Advance Total] Computed total advance: $computedTotalAdvance");

    // 🔹 Cart Items
    print("🛒 [Cart] Extracting items from globals.cartItems...");
    final List<String> itemNames =
        globals.cartItems.map((e) => e.itemName).toList();
    final List<String> varianceNames =
        globals.cartItems.map((e) => e.varianceName).toList();
    final List<int> quantities =
        globals.cartItems.map((e) => e.quantity).toList();
    final List<String> itemCodes =
        globals.cartItems.map((e) => e.itemCode).toList();
    final List<String> uoms = globals.cartItems.map((e) => e.uom).toList();
    final List<int> taxs = globals.cartItems.map((e) => e.tax).toList();
    final List<double> weights =
        globals.cartItems.map((e) => e.weight).toList();
    final List<int> prices =
        globals.cartItems.map((e) => e.pricePerKg).toList();
    final List<int> boxQuantities =
        globals.cartItems.map((e) => e.boxQuantity ?? 0).toList();
    final List<String> isBoxItem =
        globals.cartItems.map((e) => e.isBoxItem ?? '').toList();
    final List<double> itemWiseDiscounts =
        globals.cartItems.map((e) => e.itemWiseDiscount ?? 0.0).toList();
    final List<double> itemWiseDiscountAmounts =
        globals.cartItems.map((e) => e.itemWiseDiscountAmount ?? 0.0).toList();

    print("📦 [Cart Summary]");
    for (int i = 0; i < globals.cartItems.length; i++) {
      final item = globals.cartItems[i];
      print(
          "  🧾 Item ${i + 1}: ${item.itemName} (${item.varianceName}), Code: ${item.itemCode}, Qty: ${item.quantity}, UOM: ${item.uom}, Price: ${item.pricePerKg}, Tax: ${item.tax}");
    }

    final double customCharge =
        double.tryParse(cartProvider.customChargeController.text) ?? 0;
    print("⚙️ [Custom Charge] Applied: $customCharge");

    final List<double> amounts = globals.cartItems.map((item) {
      final base = (item.uom == 'Pcs' || item.uom == 'Pkt')
          ? (item.pricePerKg * item.quantity).toDouble()
          : (item.weight * item.quantity * item.pricePerKg);
      final disc = (item.itemWiseDiscountAmount ?? 0.0);
      final result = base - disc;
      print(
          "💰 [Item Calc] ${item.itemName} (${item.uom}): Base=$base, Discount=$disc, Final=$result");
      return result;
    }).toList();

    // 🔹 Totals
    final double itemTotal = amounts.fold<double>(0, (a, b) => a + b);
    final double totalAmount2 = itemTotal + customCharge;
    final double finalPrice = itemTotal + customCharge - deductedAmount;
    final double balanceAmount = finalPrice - computedTotalAdvance;

    print("📊 [Totals]");
    print("   ➕ Item Total: $itemTotal");
    print("   ➕ Custom Charge: $customCharge");
    print("   ➖ Discount Amount: $deductedAmount");
    print("   💵 Final Price: $finalPrice");
    print("   💸 Balance After Advance: $balanceAmount");

    // 🔹 Generate identifiers
    final String saleOrderNo = generateSaleOrderNo();
    final String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    const String deviceName = "POS1";

    print("🧾 [Order Info]");
    print("   🆔 SaleOrderNo: $saleOrderNo");
    print("   ⏰ Time: $formattedTime");
    print("   💻 Device: $deviceName");

    Directory? orderDir = await createOrderDir(saleOrderNo);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // 🔹 SAVE FILES
    String? savedAudioPath;
    String? savedImg1Path;
    String? savedImg2Path;

    if (path != null && orderDir != null) {
      print("🎙️ [File Save] Saving audio file...");
      savedAudioPath = await saveFile(
          File(path), orderDir, '${saleOrderNo}_${timestamp}_audio');
      print("✅ Audio Saved: $savedAudioPath");
    }

    if (img1 != null && orderDir != null) {
      print("🖼️ [File Save] Saving Image 1...");
      savedImg1Path =
          await saveFile(img1, orderDir, '${saleOrderNo}_${timestamp}_img1');
      print("✅ Image 1 Saved: $savedImg1Path");
    }

    if (img2 != null && orderDir != null) {
      print("🖼️ [File Save] Saving Image 2...");
      savedImg2Path =
          await saveFile(img2, orderDir, '${saleOrderNo}_${timestamp}_img2');
      print("✅ Image 2 Saved: $savedImg2Path");
    }

    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
    print(
        "🏬 [Branch] BranchName: ${storedBranch?.branchName}, Alias: ${storedBranch?.aliasName}");

    // 🔹 Build SalesOrder Object
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
      holdOrderId: (selectedHoldOrderId ?? ""),
      approvalOrderId: approvalOrderId,
    );

    print("🧩 [SalesOrder] Object ready: ${jsonEncode(salesOrder.toJson())}");

    try {
      print("💾 [Hive] Saving order to local Hive...");
      final salesOrderBox = HiveManager.salesOrderBox;
      await salesOrderBox.put(saleOrderNo, salesOrder.toJson());
      print("✅ [Hive] Saved order successfully with key: $saleOrderNo");

      final postData = {
        "data": salesOrder.toJson(),
        "type": "salesOrder",
        "deviceName": deviceName,
        "sync": "No",
        "WaitingForDiscountApproval": "No",
        "edit": "No",
      };

      print("🌐 [API] Sending sales order to server...");
      await sendSalesOrderDataToServer(postData);
      print("✅ [API] Sales order sent successfully.");

      // 🔹 Handle Hold Orders
      if ((selectedHoldOrderId ?? "").isNotEmpty) {
        print("🕐 [Hold Order] Converting hold order: $selectedHoldOrderId");
        final patchData = {
          "data": {"status": "Hold Order Converted"},
          "type": "patchHoldOrder",
          "sync": "No",
          "edit": "No",
          "holdOrderId": selectedHoldOrderId,
        };

        await sendSalesOrderDataToServer(patchData);
        print("✅ [Hold Order] Successfully patched hold order.");
      }
    } catch (e) {
      print("🔥 [Error] Exception during saveOrder: $e");
      rethrow;
    } finally {
      print("🧹 [Cleanup] Clearing controllers and resetting state...");
      clearControllers();
      globals.cartItems.clear();
      cartSelectionProvider.clearSelections();
      advanceDateTime.clear();
      advancePaymentType.clear();
      modeWiseAmount.clear();
      advanceAmount.clear();

      isSubmitting = false;
      showAudioandImage = false;
      pickedImage1 = null;
      pickedImage2 = null;
      recordedFilePath = '';
      audioPlayer = null;
      photoScreen = null;

      print("✅ [Cleanup] State cleared successfully.");
      notifyListeners();
    }

    print(
        "🎉 [saveOrder] Completed successfully for SaleOrderNo: $saleOrderNo");
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
      List<String> itemNames =
          globals.cartItems.map((item) => item.itemName).toList();
      List<String> varianceNames =
          globals.cartItems.map((item) => item.varianceName).toList();
      List<int> quantities =
          globals.cartItems.map((item) => item.quantity).toList();
      List<String> itemCodes =
          globals.cartItems.map((item) => item.itemCode.toString()).toList();
      List<String> uoms =
          globals.cartItems.map((item) => item.uom.toString()).toList();
      List<int> taxs = globals.cartItems.map((item) => item.tax).toList();
      List<double> weights =
          globals.cartItems.map((item) => item.weight).toList();
      List<int> prices =
          globals.cartItems.map((item) => item.pricePerKg).toList();

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
        holdOrderId: holdOrderId,
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
        'approvalStatusChanged': 'No'
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting approval: $e')),
      );
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

    List<String> itemNames =
        globals.cartItems.map((item) => item.itemName).toList();
    List<String> varianceNames =
        globals.cartItems.map((item) => item.varianceName).toList();
    List<int> quantities =
        globals.cartItems.map((item) => item.quantity).toList();
    List<String> itemCodes =
        globals.cartItems.map((item) => item.itemCode.toString()).toList();
    List<String> uoms =
        globals.cartItems.map((item) => item.uom.toString()).toList();
    List<int> taxs = globals.cartItems.map((item) => item.tax).toList();
    List<double> weights =
        globals.cartItems.map((item) => item.weight).toList();
    List<int> prices =
        globals.cartItems.map((item) => item.pricePerKg).toList();

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
      holdOrderId: holdOrderId,
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
      // audioOrderId = null;
      // clearAudioAndPhotoIds();
      notifyListeners();
    }
  }

  Future<void> saveNewOrder(ModifyCartProvider cartProvider,
      SalesOrderDisplay saleorderdisplay, BuildContext context) async {
    // if (isSubmitting) return; // Prevent double submission
    // isSubmitting = true;

    double cashAdvance = 0.0;
    double cardAdvance = 0.0;
    double upiAdvance = 0.0;
    List<double> totalAdvance = saleorderdisplay.advanceAmount!;

    List<String> itemNames =
        globals.modifyItems.map((item) => item.itemName).toList();
    List<String> varianceNames =
        globals.modifyItems.map((item) => item.variancename).toList();
    List<int> quantities =
        globals.modifyItems.map((item) => item.quantity).toList();
    List<String> itemCodes =
        globals.modifyItems.map((item) => item.itemCode.toString()).toList();
    List<String> uoms =
        globals.modifyItems.map((item) => item.uom.toString()).toList();
    List<int> taxs = globals.cartItems.map((item) => item.tax).toList();
    List<double> weights =
        globals.modifyItems.map((item) => item.weight).toList();
    List<int> prices =
        globals.modifyItems.map((item) => item.pricePerKg).toList();

    List<double> amounts = globals.modifyItems.map((item) {
      double calculatedAmount;
      if (item.uom == 'Pcs' || item.uom == 'Pkt') {
        calculatedAmount = item.pricePerKg * item.quantity.toDouble();
      } else {
        calculatedAmount = item.weight * item.quantity * item.pricePerKg;
      }
      return calculatedAmount;
    }).toList();

    // String saleOrderNo = generateSaleOrderNo();
    String formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    String formattedTime = DateFormat('hh:mm a').format(DateTime.now());

    SalesOrder salesOrder = SalesOrder(
        itemName: itemNames,
        varianceName: varianceNames,
        qty: quantities,
        uom: uoms,
        weight: weights,
        amount: amounts,
        // totalAmount2: totalAmount,
        branchId: storedBranch!.branchId,
        branchName: storedBranch!.branchName,
        totalAmount: 0,
        itemCode: itemCodes,
        tax: taxs,
        price: prices,
        deliveryDate: saleorderdisplay.deliveryDate,
        deliveryTime: saleorderdisplay.deliveryTime,
        event: saleorderdisplay.event,
        customerNumber: saleorderdisplay.customerNumber,
        customerName: saleorderdisplay.customerName,
        deliveryType: saleorderdisplay.deliveryType,
        address: saleorderdisplay.address,
        landmark: saleorderdisplay.landmark,
        discount: 0,
        discountAmount: saleorderdisplay.discountAmount,
        remark: saleorderdisplay.remark,
        customCharge: 0,
        advanceAmount: totalAdvance,
        // advancePaymentType: selectedPaymentMethod,
        finalPrice: 0,
        shiftId: globalsData.shiftId.toString(),
        balanceAmount: 0,
        saleOrderNo: saleorderdisplay.saleOrderNo,
        orderDate: formattedDate,
        orderTime: formattedTime,
        employeeName: searchController.text,
        status: 'Modify request',
        cash: cashAdvance,
        card: cardAdvance,
        upi: upiAdvance,
        holdOrderId: holdOrderId,
        approvalOrderId: approvalOrderId);

    String jsonSalesOrder = jsonEncode(salesOrder.toJson());

    try {
      // Check if it reaches here
      // final response = await http.post(
      //   Uri.parse('https://yenerp.com/salesOrders/'),
      final response = await http.post(
        // Uri.parse("https://yenerp.com/fastapi/salesorders/"),
        Uri.parse("https://yenerp.com/fastapi/salesorders/"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonSalesOrder,
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        // String salesOrderId = responseData['salesOrderId'];

        String salesOrderId = responseData;

        notifyListeners();
        // print(submittedOrders);
      } else {}
    } catch (e) {
      // Catches any errors during the request
    } finally {
      clearControllers();
      // clearControllers();
      // cartProvider.clearCart();
      // isSubmitting = false;
      // audioOrderId = null;
      notifyListeners();
    }
  }

  Future<void> deleteHoldOrderFromHive(String salesOrderId) async {
    try {
      final box = HiveManager.holdOrderBox;

      // Find the key of the order with the matching salesOrderId
      final keyToDelete = box.keys.firstWhere(
        (key) => box.get(key)?['holdOrderId'] == salesOrderId,
        orElse: () => null,
      );

      if (keyToDelete != null) {
        await box.delete(keyToDelete);

        // Remove from the in-memory list
        _hiveholdSalesOrders
            .removeWhere((order) => order['holdOrderId'] == salesOrderId);

        notifyListeners();
      } else {}
    } catch (e) {}
  }

  Future<void> _postImages(
      String salesOrderId, File? pickedImage1, File? pickedImage2) async {
    try {
      var uri = Uri.parse(
          "https://yenerp.com/fastapi/imageOrder/upload_photo"); // Change to your FastAPI endpoint
      var request = http.MultipartRequest('POST', uri);

      // Attach the salesOrderId to the request
      request.fields['custom_id'] = salesOrderId;

      // Check and add image1 if it's picked
      if (pickedImage1 != null) {
        var image1Bytes = await pickedImage1.readAsBytes();
        var image1MimeType = lookupMimeType(pickedImage1.path) ??
            'image/jpeg'; // Default to 'image/jpeg' if MIME type is not found

        // Add image1 as a multipart file
        request.files.add(http.MultipartFile.fromBytes(
          'files', // The field name expected by FastAPI
          image1Bytes,
          filename: pickedImage1.path
              .split('/')
              .last, // Extract the filename from the path
          contentType:
              MediaType.parse(image1MimeType), // Use the correct MIME type
        ));
      }

      // Check and add image2 if it's picked
      if (pickedImage2 != null) {
        var image2Bytes = await pickedImage2.readAsBytes();
        var image2MimeType = lookupMimeType(pickedImage2.path) ??
            'image/jpeg'; // Default to 'image/jpeg' if MIME type is not found

        // Add image2 as a multipart file
        request.files.add(http.MultipartFile.fromBytes(
          'files', // The field name expected by FastAPI
          image2Bytes,
          filename: pickedImage2.path
              .split('/')
              .last, // Extract the filename from the path
          contentType:
              MediaType.parse(image2MimeType), // Use the correct MIME type
        ));
      }

      // Send the request and await the response
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var responseData = jsonDecode(responseBody);

        // Process the response to get the uploaded image URLs
        var uploadedPhotos = responseData['uploaded_photos'];
        for (var photo in uploadedPhotos) {}
      } else {}
    } catch (e) {}
  }

  Future<void> handleAudioOrder(
      String? audioOrderId, String salesOrderId, String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    if (audioOrderId != null) {
      await updateCustomId(audioOrderId, salesOrderId);
    } else {
      await _postAudioFile(salesOrderId, path);
    }
  }

  Future<void> handleImageUpload(
      String salesOrderId, File? img1, File? img2) async {
    if (img1 != null || img2 != null) {
      await _postImages(salesOrderId, img1, img2);
    }
  }

  Future<void> handleHoldOrder(String? holdId) async {
    if (holdId != null) {
      await _patchHoldOrderStatus(holdId);
    }
  }

  Future<void> _patchHoldOrderStatus(String? holdOrderId) async {
    if (holdOrderId == null || holdOrderId.isEmpty) {
      return; // Return early if there's no valid holdOrderId
    }

    try {
      // Create the request body with the new status
      final Map<String, dynamic> requestBody = {
        'status': 'completed order', // Update the status to 'completed order'
      };

      final response = await http.patch(
        Uri.parse(
            "https://yenerp.com/fastapi/heldorders/$holdOrderId"), // Use holdOrderId in the URL
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody), // Convert request body to JSON
      );

      if (response.statusCode == 200) {
      } else {}
    } catch (e) {}
  }

  Future<void> _postAudioFile(String customId, String filePath) async {
    // final uri = Uri.parse('https://yenerp.com/fastapi/audios/upload_audio');
    final uri = Uri.parse('https://yenerp.com/fastapi/audios/upload_audio');

    try {
      // Determine the content type based on the file extension (simplified example)
      String fileExtension = filePath.split('.').last.toLowerCase();
      String contentType = 'audio/$fileExtension';

      // Create a new MultipartRequest
      final request = http.MultipartRequest('POST', uri);

      // Add the audio file with dynamic content type
      var file = await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType.parse(contentType),
      );
      request.files.add(file);

      // Debug: Check what is being added to the request

      // Pass customId in the form fields
      if (customId.isNotEmpty) {
        request.fields['custom_id'] = customId;
      }

      // Debug: Check the request before sending it

      // Send the request
      final response = await request.send();
      final responseBody =
          await response.stream.bytesToString(); // Read response body

      // Debug: Check the server's response
      if (response.statusCode == 200) {
      } else {}
    } catch (e) {
      // Optionally, handle error more gracefully (e.g., display a user-friendly message)
    }
  }

  int _holdOrderCounter = 0;

// Function to generate holdOrderId like HOLD01, HOLD02...
  String generateHoldOrderId() {
    _holdOrderCounter++;
    return 'HOLD${_holdOrderCounter.toString().padLeft(2, '0')}';
  }

  Future<void> _heldOrder(CartProvider cartProvider, String path,
      ApiServiceSalesOrderProvider apiProvider, File? img1, File? img2) async {
    // Extract cart data
    List<String> itemNames =
        globals.cartItems.map((item) => item.itemName).toList();
    List<String> varianceNames =
        globals.cartItems.map((item) => item.varianceName).toList();
    List<int> quantities =
        globals.cartItems.map((item) => item.quantity).toList();
    List<String> itemCodes =
        globals.cartItems.map((item) => item.itemCode.toString()).toList();
    List<String> uoms =
        globals.cartItems.map((item) => item.uom.toString()).toList();
    List<int> taxs = globals.cartItems.map((item) => item.tax).toList();
    List<double> weights =
        globals.cartItems.map((item) => item.weight).toList();
    List<int> prices =
        globals.cartItems.map((item) => item.pricePerKg).toList();
    final List<double> itemWiseDiscounts =
        globals.cartItems.map((e) => e.itemWiseDiscount ?? 0.0).toList();
    final List<double> itemWiseDiscountAmounts =
        globals.cartItems.map((e) => e.itemWiseDiscountAmount ?? 0.0).toList();

    // Calculate amounts
    List<double> amounts = globals.cartItems.map((item) {
      double calculatedAmount;
      if (item.uom == 'Pcs' || item.uom == 'Pkt') {
        calculatedAmount = item.pricePerKg * item.quantity.toDouble();
      } else {
        calculatedAmount = item.weight * item.quantity * item.pricePerKg;
      }
      return calculatedAmount;
    }).toList();

    // Generate IDs and Timestamps
    String saleOrderNo = generateSaleOrderNo();
    String formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    String holdOrderId = generateHoldOrderId();

    // Construct the HeldOrder object
    HeldOrder holdsalesOrder = HeldOrder(
      salesOrderId: '',
      itemName: itemNames,
      varianceName: varianceNames,
      qty: quantities,
      uom: uoms,
      weight: weights,
      amount: amounts,
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
      saleOrderNo: saleOrderNo,
      orderDate: formattedDate,
      orderTime: formattedTime,
      employeeName: searchController.text,
      status: 'Hold Order',
      holdOrderId: holdOrderId,
      eventDate: birthdaydateController.text,
      remarks: remarkController.text,
      itemWiseDiscount: itemWiseDiscounts,
      itemWiseDiscountAmount: itemWiseDiscountAmounts,
    );

    // Prepare JSON
    String jsonHoldSalesOrder = jsonEncode({
      "data": [
        holdsalesOrder.toJson(),
      ],
      "type": "holdOrder",
      'sync': "No",
      'edit': 'No'
    });

    // Send via WebSocket or API
    try {
      await sendHoldDataToServer(jsonDecode(jsonHoldSalesOrder));
    } catch (e) {
    } finally {
      clearControllers();
      cartProvider.clearCart();
      isSubmitting = false;
      showAudioandImage = false;
      advanceDateTime?.clear();
      advancePaymentType?.clear();
    }
  }

  Future<void> postCreditCustomer(
    CartProvider cartProvider,
    double totalAdvance,
    double orderAmount,
    double discount,
    double deductedAmount,
    double customCharge,
    double totalAmount,
    String remark,
    String? path,
    File? img1,
    File? img2,
    BuildContext context, // Pass the context to the function
  ) async {
    double balanceAmount = totalAmount - totalAdvance;
    double cashAdvance = 0.0;
    double cardAdvance = 0.0;
    double upiAdvance = 0.0;

    if (selectedPaymentMethod == 'Cash') {
      cashAdvance = totalAdvance;
    } else if (selectedPaymentMethod == 'Card') {
      cardAdvance = totalAdvance;
    } else if (selectedPaymentMethod == 'UPI') {
      upiAdvance = totalAdvance;
    }

    List<String> itemNames =
        globals.cartItems.map((item) => item.itemName).toList();

    List<String> varianceNames =
        globals.cartItems.map((item) => item.varianceName).toList();
    List<double> quantities =
        globals.cartItems.map((item) => item.quantity.toDouble()).toList();
    List<String> itemCodes =
        globals.cartItems.map((item) => item.itemCode.toString()).toList();
    List<String> uoms =
        globals.cartItems.map((item) => item.uom.toString()).toList();
    List<double> taxs =
        globals.cartItems.map((item) => item.tax.toDouble()).toList();
    List<double> weights =
        globals.cartItems.map((item) => item.weight).toList();
    List<double> prices =
        globals.cartItems.map((item) => item.pricePerKg.toDouble()).toList();

    List<double> amounts = globals.cartItems.map((item) {
      double calculatedAmount;
      if (item.uom == 'Pcs' || item.uom == 'Pkt') {
        calculatedAmount = item.pricePerKg * item.quantity.toDouble();
      } else {
        calculatedAmount = item.weight * item.quantity * item.pricePerKg;
      }
      return calculatedAmount;
    }).toList();

    // String saleOrderNo = generateSaleOrderNo();
    // String formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    // String formattedTime = DateFormat('hh:mm a').format(DateTime.now());

    CreditOrder creditOrder = CreditOrder(
      creditBillId: '', // You can provide a valid ID if available
      itemName: itemNames, // List of item names
      price: prices, // List of prices
      weight: weights, // List of weights
      qty: quantities, // List of quantities
      amount: amounts, // List of amounts
      tax: taxs, // List of taxes
      branch: storedBranch!.branchName,
      totalAmount: totalAmount,
      branchId: storedBranch!.branchId,
      balanceAmount: balanceAmount,
      uom: uoms, // List of units of measure
      employeeName: searchController.text, // Employee name from controller
      phoneNumber: mobileNoController.text
          .toString(), // Customer phone number from controller
      deliveryDate: dateController.text.toString(), // Date from controller
      deliveryTime: timeController.text.toString(), // Time from controller
      deliveryType: selectedDeliveryType.toString(), // Delivery type selected
      discountAmount: deductedAmount,
      customCharge: customCharge,
      paymentType: selectedPaymentMethod,
      customerName:
          customerNameController.text, // Customer name from controller
      customerAddress: addressController.text, // Address from controller
    );

    String jsonSalesOrder = jsonEncode(creditOrder.toJson());

    try {
      // Attempt to post the data

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
      //   customerType: 'CreditOrder',
      //   // context: context,
      //   customAmountController: mobileNoController,
      //   selectedPaymentOption: selectedPaymentMethod,
      // );
      final response = await http.post(
        Uri.parse("http://:8888/creditbills/"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonSalesOrder,
      );

      if (response.statusCode == 201) {
        var responseData = jsonDecode(response.body);

        String salesOrderId = responseData['creditBillId'];

        // Proceed only if the sales order was successfully created
        if (img1 != null || img2 != null) {
          await _postImages(salesOrderId, img1, img2);
        }
        if (path != null || path!.isNotEmpty) {
          await _postAudioFile(salesOrderId, path);
        }

        // Ensure widget is still mounted before calling printReceipt
        if (context.mounted) {
          await printReceipt();
        }
        // if (context.mounted) {
        //   Navigator.pop(context);
        // }
      } else {
        // Handle unsuccessful response (e.g., show an error message)
        debugPrint(
            'Failed to create sales order. Status code: ${response.statusCode}');
      }
    } catch (e) {
    } finally {
      // Clear controllers after the process is done
      clearControllers();
    }
  }

  Future<void> fetchCreditBills() async {
    try {
      // Send GET request to the server to fetch data
      final response = await http.get(
        Uri.parse("https://yenerp.com/fastapi/creditbills/"),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      // Check if the response status is OK (200)
      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        // Process the fetched data as required
        // For example, you could map the data to a model or update UI state
        // For now, just print the data
      } else {}
    } catch (e) {}
  }

  Widget buildCompanyInputFields(BuildContext context) {
    return Column(
      children: [
        // Company-specific fields
        Row(
          children: [
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: TextFormField(
                controller: companyNameController,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9 ]*$')),
                  LengthLimitingTextInputFormatter(50),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Company Name',
                  // prefixIcon: Icon(Icons.search),
                  isDense: true, // Makes the field more compact
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: (value) {
                  fetchCompanySuggestionsDebounced(value);
                },
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Company Name is required';
                  }
                  return null;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
          ],
        ),

        if (companyNameController.text.isNotEmpty &&
            companyAddressController.text.isEmpty)
          Container(
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListView.builder(
              itemCount: suggestions.isEmpty ? 1 : suggestions.length + 1,
              itemBuilder: (context, index) {
                // Show suggestions if available
                if (suggestions.isNotEmpty && index < suggestions.length) {
                  final company = suggestions[index];
                  return ListTile(
                    title: Text(company['name'] ?? ""),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(company['address'] ?? ""),
                        Text('GST: ${company['gst']}'),
                      ],
                    ),
                    onTap: () {
                      companyNameController.text = company['name'] ?? "";
                      companyAddressController.text = company['address'] ?? "";
                      companygstNumberController.text = company['gst'] ?? "";
                      suggestions.clear();
                      // FocusScope.of(context).unfocus();
                      notifyListeners();
                    },
                  );
                }
                // Show "Add Customer Details" as the last item
                return ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  title: const Text('Add Company Details'),
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        final TextEditingController nameController =
                            TextEditingController();
                        final TextEditingController addressController =
                            TextEditingController();
                        final TextEditingController gstController =
                            TextEditingController();

                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          title: const Row(
                            children: [
                              Icon(Icons.business, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Add Company',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Company Name',
                                    border: OutlineInputBorder(),
                                    isDense:
                                        true, // Makes the field more compact
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Company Address',
                                    border: OutlineInputBorder(),
                                    isDense:
                                        true, // Makes the field more compact
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: gstController,
                                  decoration: const InputDecoration(
                                    labelText: 'Company GST',
                                    border: OutlineInputBorder(),
                                    isDense:
                                        true, // Makes the field more compact
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final String name = nameController.text.trim();
                                final String address =
                                    addressController.text.trim();
                                final String gst = gstController.text.trim();

                                if (name.isNotEmpty &&
                                    address.isNotEmpty &&
                                    gst.isNotEmpty) {
                                  final response =
                                      await addCompany(name, address, gst);

                                  if (response) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          'Company "$name" added successfully!',
                                          style: const TextStyle(
                                              color: Colors.white)),
                                      backgroundColor: Colors.green,
                                    ));
                                    fetchCompanySuggestionsDebounced('');
                                    Navigator.pop(context);
                                  } else {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                          'Failed to add company. Please try again.'),
                                      backgroundColor: Colors.red,
                                    ));
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please fill in all fields correctly.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Submit',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

        const SizedBox(height: 10),
        Row(
          children: [
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: TextFormField(
                enabled: false,
                controller: companyAddressController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Company Address',
                  isDense: true, // Makes the field more compact
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Company Address is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10), // Spacing between the two fields
            Expanded(
              child: TextFormField(
                enabled: false,
                controller: companygstNumberController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Company GST',
                  isDense: true, // Makes the field more compact
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Company GST is required';
                  }
                  return null;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
          ],
        ),
      ],
    );
  }

  Widget buildCustomerInputFields(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: TextFormField(
                controller: mobileNoController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Search Mobile Number',
                  labelStyle: TextStyle(fontSize: 10),

                  isDense: true, // Makes the field more compact
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6), // Same padding as above
                ),
                onChanged: (value) {
                  // Clear customer name when mobile number changes
                  customerNameController.clear();
                  fetchSuggestions(value);
                },
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Customer Mobile No is required';
                  }
                  return null;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: TextFormField(
                enabled: false,
                controller: customerNameController,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(24),
                  FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9 ]*$')),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Customer Name',
                  labelStyle: TextStyle(fontSize: 10),
                  isDense: true, // Makes the field more compact
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6), // Same padding as above
                ),
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Customer Name is required';
                  }
                  return null;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
          ],
        ),
        const SizedBox(height: 8.0),

        // Only show suggestions container when mobile number is not empty AND customer name is empty
        if (mobileNoController.text.isNotEmpty &&
            customerNameController.text.isEmpty)
          Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListView.builder(
              itemCount: suggestions.isEmpty ? 1 : suggestions.length + 1,
              itemBuilder: (context, index) {
                // Show suggestions if available
                if (suggestions.isNotEmpty && index < suggestions.length) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    title: Text(suggestion['mobile'] ?? 'Unknown Mobile'),
                    subtitle: Text(suggestion['name'] ?? 'Unknown Name'),
                    onTap: () {
                      onSuggestionSelected(suggestion);
                      // Set focus to next field or clear focus
                      FocusScope.of(context).unfocus();
                    },
                  );
                }

                // Show "Add Customer Details" as the last item
                return ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0), // Reduced padding
                  title: const Text('Add Customer Details'),
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        final TextEditingController mobileController =
                            TextEditingController(
                                text: mobileNoController.text);
                        final TextEditingController nameController =
                            TextEditingController();
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          title: const Row(
                            children: [
                              Icon(Icons.person_add, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Add Customer',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: mobileController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Mobile Number',
                                    prefixText: '+91 ',
                                    prefixStyle:
                                        const TextStyle(color: Colors.black),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.0)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: nameController,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(24),
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^[a-zA-Z ]*$')),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Customer Name',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.0)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final String mobile =
                                    mobileController.text.trim();
                                final String name = nameController.text.trim();

                                if (mobile.length == 10 &&
                                    RegExp(r'^\d+$').hasMatch(mobile) &&
                                    name.isNotEmpty) {
                                  final response =
                                      await addCustomer(mobile, name);
                                  if (response) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Customer "$name" added successfully!',
                                            style: const TextStyle(
                                                color: Colors.white)),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    await fetchSuggestions(mobile);
                                    Navigator.pop(context);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Failed to add customer. Please try again.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please enter a valid mobile number and name.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Submit',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget buildAddCustomerDialog(BuildContext context) {
    final TextEditingController mobileController =
        TextEditingController(text: mobileNoController.text);
    final TextEditingController nameController = TextEditingController();

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      title: const Row(
        children: [
          Icon(Icons.person_add, color: Colors.blue),
          SizedBox(width: 8),
          Text('Add Customer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: mobileController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                prefixText: '+91 ',
                prefixStyle: const TextStyle(color: Colors.black),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameController,
              inputFormatters: [
                LengthLimitingTextInputFormatter(24),
                FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z ]*$')),
              ],
              decoration: InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () async {
            final String mobile = mobileController.text.trim();
            final String name = nameController.text.trim();

            if (mobile.length == 10 &&
                RegExp(r'^\d+$').hasMatch(mobile) &&
                name.isNotEmpty) {
              final response = await addCustomer(mobile, name);
              if (response) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Customer "$name" added successfully!',
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green,
                  ),
                );
                await fetchSuggestions(mobile);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to add customer. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid mobile number and name.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Widget buildCustomerInputFieldsforcredit(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: TextFormField(
                controller: mobileNoController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Search Mobile Number',
                  labelStyle: TextStyle(fontSize: 10),
                  isDense: true, // Makes the field more compact
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6), // Same padding as above
                ),
                onChanged: (value) {
                  // Clear customer name when mobile number changes
                  customerNameController.clear();

                  // Fetch suggestions based on the mobile number input
                  fetchSuggestions(value);
                },
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Customer Mobile No is required';
                  }
                  return null;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: TextFormField(
                enabled: false,
                controller: customerNameController,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(24),
                  FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9 ]*$')),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Customer Name',
                  labelStyle: TextStyle(fontSize: 10),
                  isDense: true, // Makes the field more compact
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6), // Same padding as above
                ),
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Customer Name is required';
                  }
                  return null;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
          ],
        ),
        const SizedBox(height: 8.0),

        // Only show suggestions container when mobile number is not empty AND customer name is empty
        if (mobileNoController.text.isNotEmpty &&
            customerNameController.text.isEmpty)
          Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListView.builder(
              itemCount: suggestions.isEmpty ? 1 : suggestions.length,
              itemBuilder: (context, index) {
                // Show suggestions if available
                if (suggestions.isNotEmpty) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    title: Text(suggestion['mobile'] ?? 'Unknown Mobile'),
                    subtitle: Text(suggestion['name'] ?? 'Unknown Name'),
                    onTap: () {
                      onSuggestionSelected(suggestion);
                      // Set focus to next field or clear focus
                      FocusScope.of(context).unfocus();
                    },
                  );
                }

                // If no suggestions are found, show an error directly.
                return const ListTile(
                  title: Text('No customer found for this mobile number.',
                      style: TextStyle(color: Colors.red)),
                );
              },
            ),
          ),
      ],
    );
  }
}

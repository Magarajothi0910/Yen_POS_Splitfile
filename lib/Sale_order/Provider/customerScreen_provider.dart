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
import 'package:yenpos/Sale_order/Print_Receipt/op_placeorder_payment.dart';
import 'package:yenpos/Sale_order/Print_Receipt/salesOrder_print.dart';
import 'package:yenpos/Sale_order/Print_Receipt/so_placeorder_payment_print.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Provider/saveAudioandImageFile.dart';
import 'package:yenpos/Sale_order/Screens/create_sales_order.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yenpos/Sale_order/Widgets/storetype_selection_dialogue.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';
import '../../Global/Provider/branchSelection_provider.dart';
import 'cartProvider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../Global/globals_data.dart' as globalbranch;

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
      editAbout: '',
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
      cashAmount: 0.0,
      cardAmount: 0.0,
      upiAmount: 0.0,
      invoiceNo: '',
    );

    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
  }

  TextEditingController otherEventController = TextEditingController();
  TextEditingController combinedController = TextEditingController();

  String? holdId;

  final Razorpay _razorpay = Razorpay();

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

  TextEditingController allBoxQtyController = TextEditingController();
  TextEditingController bulkDiscountController = TextEditingController();
  String _selectedStoreType = 'Warehouse';
  bool _isStoreTypeSelected = false;

  String get selectedStoreType => _selectedStoreType;
  bool get isStoreTypeSelected => _isStoreTypeSelected;

  String customerType = 'Normal';
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
  String selectedChargeType = "Custom Charge";
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
      sendataToServer(cutomerPayload);
    } catch (e) {}
  }

  List<Map<String, dynamic>> cartItems = []; // your cart items list

  // Add this method
  bool hasInvalidCartItems() {
    // Example condition: item quantity <= 0 or item is null
    for (var item in cartItems) {
      if (item['quantity'] == null || item['quantity'] <= 0) {
        return true;
      }
      // Add any other validation you need
      // e.g., if(item['price'] == null || item['price'] <= 0) return true;
    }
    return false; // no invalid items
  }

  Future<List<Map<String, dynamic>>> fetchHolderFromHive() async {
    try {
      // Step 2: Fetch all saved hold orders from Hive
      List<Map<String, dynamic>> hiveOrders = await getSavedHoldOrders();

      if (hiveOrders.isEmpty) {
        return [];
      }

      for (int i = 0; i < hiveOrders.length; i++) {}

      // Step 3: Filter orders with status = "Hold Order"
      List<Map<String, dynamic>> holdOrders = hiveOrders.where((order) {
        // Extract the nested "data" map safely
        final data = order['data'] ?? {};
        final status = (data['status'] ?? '').toString().trim().toLowerCase();
        return status == 'hold order';
      }).toList();

      if (holdOrders.isEmpty) {
      } else {
        for (int i = 0; i < holdOrders.length; i++) {}
      }

      // ✅ Optional Step: Flatten data for easier UI access
      // This lets you access values directly like order['customerName'], etc.
      List<Map<String, dynamic>> flattenedHoldOrders = holdOrders
          .map((order) => Map<String, dynamic>.from(order['data'] ?? {}))
          .toList();

      // Step 4: Assign to internal variables
      _rawOrders = flattenedHoldOrders;
      _hiveholdSalesOrders = List.from(_rawOrders);

      // Step 5: Notify listeners for UI updates
      notifyListeners();

      return _hiveholdSalesOrders;
    } catch (e, stacktrace) {
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
    receiptPrinter.editAbout = orderData['editAbout'] ?? '';

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

      await sendataToServer(cancelOrderData);
    } catch (e, stackTrace) {
      // Step 5: Error handling
      // Optional: show user error message here
    }
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
      // "itemName": saleOrders.itemName,
      // "varianceName":
      //     saleOrders.varianceName, // Assuming saleOrders.varianceName is a list
      // "itemCode": saleOrders.itemCode, // Assuming saleOrders.itemCode is a list
      // "qty": saleOrders.qty, // Assuming saleOrders.qty is a list
      // "tax": saleOrders.tax, // Assuming saleOrders.tax is a list
      // "uom": saleOrders.uom, // Assuming saleOrders.uom is a list
      // "amount": saleOrders.amount, // Assuming saleOrders.amount is a list
      // "branchId": saleOrders.branchId,
      // "branchName": saleOrders.branchName,
      // "price": saleOrders.price, // Assuming saleOrders.price is a list
      // "weight": saleOrders.weight, // Assuming saleOrders.weight is a list
      // "deliveryDate": saleOrders.deliveryDate,
      // "deliveryTime": saleOrders.deliveryTime,
      // "event": saleOrders.event,
      // "customerNumber": saleOrders.customerNumber,
      // "customerName": saleOrders.customerName,
      // "deliveryType": saleOrders.deliveryType,
      // "address": saleOrders.address,
      // "landmark": saleOrders.landmark,
      // "discountAmount": discount,

      // "orderDate": saleOrders.orderDate,
      // "orderTime": saleOrders.orderTime,
      // "employeeName": saleOrders.employeeName,
      "status": "Confirm Order",
      // "orderType": saleOrders.orderType,
      // "eventDate": saleOrders.eventDate,
      // "itemWiseDiscount": saleOrders.itemWiseDiscount,
      // "itemWiseDiscountAmount": saleOrders.itemWiseDiscountAmount,
      // "boxQty": saleOrders.boxQty,
      // "totalAmount": totalAmount,
      // "remark": remark,
      // "customCharge": customCharge,
      // "deductedAmount": deductedAmount,
      // "orderAmount": orderAmount,
      // "advanceAmount": [totalAdvance],
      // "advancePaymentType": advancePaymentType,
      // "advanceDateTime": advanceDateTime,
      // "balanceAmount": balanceAmount,

      // "discount": discount,
    };

    try {
      String jsonadvanceSalesOrder = jsonEncode({
        "data": orderData,
        "saleOrderNo": saleOrders.saleOrderNo,
        "type": "patchSaleOrder",
        "sync": "No",
        "edit": "No",
      });

      await sendataToServer(jsonDecode(jsonadvanceSalesOrder));
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

      await sendataToServer(jsonDecode(jsonSalesOrder));
      // Check if it reaches here

      final patchData = jsonEncode(orderData); // Use the single orderData map
      final url = Uri.parse(
        'https://yenerp.com/fastapi/salesorders/${saleOrders.salesOrderId}',
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

  // -------------------- FUNCTION -------------------- //

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
    cartItems.clear();
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
    } catch (e) {}
  }

  void showAdvancePaymentPopup(
    BuildContext context,

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
                        color: Colors.blue,
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

  void showOPAdvancePaymentPopup(
    BuildContext context,
    SalesOrderDisplay salesOrder,
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
    totalAmount = salesOrder.totalAmount;
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
                        color: Colors.blue,
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
                      child: OpPlaceOrderPaymentPrint(
                        salesOrder: salesOrder,
                        totalAmount: totalAmount,
                        holdBillId: holdId ?? '',
                        orderId: salesOrderId ?? '',
                        discount: discount,
                        totalAdvance: totalAdvance,

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
    // =====================================================
    // STEP 1: PAYMENT PROCESSING
    // =====================================================

    final List<double> advanceAmount = [];
    final List<List<String>> advancePaymentType = [];
    final List<List<double>> modeWiseAmount = [];
    final List<String> advanceDateTime = [];

    void addAdvancePayment(Map<String, double> payMap) {
      final filtered = Map.fromEntries(
        payMap.entries.where((e) => e.value > 0),
      );

      if (filtered.isEmpty) {
        return;
      }

      final total = filtered.values.fold<double>(0, (a, b) => a + b);

      advanceAmount.add(total);
      advancePaymentType.add(filtered.keys.toList(growable: false));
      modeWiseAmount.add(filtered.values.toList(growable: false));
      advanceDateTime.add(DateTime.now().toIso8601String());
    }

    if (payments.isNotEmpty) {
      addAdvancePayment(payments);
    } else {}

    final double computedTotalAdvance = advanceAmount.fold<double>(
      0,
      (a, b) => a + b,
    );

    // =====================================================
    // STEP 2: CART ITEM DETAILS
    // =====================================================

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
    final int boxQuantities = globals.cartItems.first.boxQuantity ?? 0;

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
      final total = base - disc;
      return total;
    }).toList();

    final double itemTotal = amounts.fold<double>(0, (a, b) => a + b);
    final double totalAmount2 = itemTotal + customCharge;
    final double finalPrice = itemTotal + customCharge - deductedAmount;
    final double balanceAmount = finalPrice - computedTotalAdvance;

    // =====================================================
    // STEP 3: ORDER METADATA
    // =====================================================

    final String saleOrderNo = generateSaleOrderNo();
    final String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    const String deviceName = "POS1";

    Directory? orderDir = await createOrderDir(saleOrderNo);

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // =====================================================
    // STEP 4: FILE SAVING (AUDIO/IMAGES)
    // =====================================================

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

    // =====================================================
    // STEP 5: BUILD SALES ORDER OBJECT
    // =====================================================

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
      shiftId: [globalsData.shiftId.value],
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
      customChargeType: selectedChargeType,
    );

    // =====================================================
    // STEP 6: SAVE & SYNC DATA
    // =====================================================

    try {
      final postData = {
        "data": salesOrder.toJson(),
        "type": "salesOrder",
        "deviceName": deviceName,
        "sync": "No",
        "WaitingForDiscountApproval": "No",
        "edit": "No",
      };

      await sendataToServer(postData);

      if (patchHoldOrderId.isNotEmpty) {
        Map<String, dynamic> requestBody = {"status": "HoldOrder Converted"};
        final patchData = {
          "data": requestBody,
          "type": "patchHoldOrder",
          "sync": "No",
          "edit": "No",
          "holdOrderId": patchHoldOrderId,
          "deviceName": deviceName,
        };
        await sendataToServer(patchData);
        await fetchHolderFromHive();
        notifyListeners();
      }
      isSubmitting = false;

      clearControllers();
      cartProvider.clearCart();
      cartProvider.cartItems.clear();
      globals.cartItems.clear();
      print("globals.cartitem: ${globals.cartItems.length}");
      advanceDateTime.clear();
      advancePaymentType.clear();
      modeWiseAmount.clear();
      advanceAmount.clear();
      cartProvider.customChargeController.clear();
      patchHoldOrderId = "";
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
    } catch (e, st) {
      rethrow;
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
      isSubmitting = true;

      // 🔹 Step 1: Initial values
      double totalAdvance = 0.0;
      double balanceAmount = cartProvider.getTotalAmount();
      List<double> advanceAmountList = [0.0];
      List<String> advanceDateTime = [DateTime.now().toIso8601String()];

      // 🔹 Step 2: Collect cart item details
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

      // 🔹 Step 3: Calculate amounts
      List<double> amounts = globals.cartItems.map((item) {
        double amt = (item.uom == 'Pcs' || item.uom == 'Pkt')
            ? item.pricePerKg * item.quantity.toDouble()
            : item.weight * item.quantity * item.pricePerKg;
        return amt;
      }).toList();

      // Generate IDs
      approvalOrderId = generateApprovalOrderId();
      String saleOrderNo = generateSaleOrderNo();

      // 🔹 Step 4: Create SalesOrder object
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
        shiftId: [globalsData.shiftId.value],
        landmark: landmarkController.text,
        discount: 0.0,
        discountAmount: 0.0,
        remark: remarkController.text,
        advanceAmount: advanceAmountList,
        finalPrice: cartProvider.getTotalAmount(),
        balanceAmount: balanceAmount,
        saleOrderNo: saleOrderNo,
        orderDate: DateTime.now().toIso8601String(),
        orderTime: DateFormat('hh:mm a').format(DateTime.now()),
        employeeName: searchController.text,
        status: 'Waiting for Approval',
        advanceDateTime: advanceDateTime,
        companyName: companyNameController.text,
        companyAddress: companyAddressController.text,
        companyGST: companygstNumberController.text,
        orderType: selectedOrderOption,
        eventDate: birthdaydateController.text,
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
        customChargeType: selectedChargeType,
      );

      // 🔹 Step 5: Encode to JSON
      String jsonApprovalOrder = jsonEncode({
        "data": approvalOrder.toJson(),
        "type": "salesApprovalOrder",
        'sync': "No",
        'edit': 'No',
        'approvalStatusChanged': 'No',
      });

      // 🔹 Step 6: Send to server
      await sendataToServer(jsonDecode(jsonApprovalOrder));

      // 🔹 Step 7: Success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order submitted for approval successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, stacktrace) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting approval: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      isSubmitting = false;
      clearControllers();
      cartProvider.clearCart();
      cartSelectionProvider.clearSelections();
      advanceDateTime?.clear();
      advancePaymentType?.clear();
      showAudioandImage = false;
      notifyListeners();
    }
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
      shiftId: [globalsData.shiftId.value],
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
          approvalStatus: approvalStatus,
          approvalDate: DateTime.now().toIso8601String(),
          summary: 'No',
        ),
      ],
      customChargeType: selectedChargeType,
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

      await sendataToServer(jsonDecode(jsonSalesOrder));
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
      final box = await HiveManager.holdOrderBox;

      // Find the key that matches the holdOrderId inside 'data' map
      final keyToDelete = box.keys.firstWhere(
        (key) {
          final order = box.get(key);
          final holdId = order?['data']?['holdOrderId']; // access nested map
          return holdId == holdOrderId;
        },
        orElse: () {
          return null;
        },
      );

      if (keyToDelete != null) {
        // Delete from Hive
        await box.delete(keyToDelete);

        // Delete from in-memory list
        final removedCount = _hiveholdSalesOrders.removeWhere(
          (order) => order['data']?['holdOrderId'] == holdOrderId,
        );
        // print('📝 Removed $removedCount entries from in-memory list');

        notifyListeners();

        // Refresh provider list
        await fetchHolderFromHive();
      }
    } catch (e, stackTrace) {}
  }

  int _holdOrderCounter = 0;

  // Function to generate holdOrderId like HOLD01, HOLD02...
  String generateHoldOrderId() {
    _holdOrderCounter++;
    return 'HOLD${_holdOrderCounter.toString().padLeft(2, '0')}';
  }

  Future<void> heldrder(
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

    String? holdOrderId,
    String? selectedOrderOption,
    BuildContext context,
  ) async {
    // =====================================================
    // STEP 1: PAYMENT PROCESSING
    // =====================================================
    final List<double> advanceAmount = [];
    final List<List<String>> advancePaymentType = [];
    final List<List<double>> modeWiseAmount = [];
    final List<String> advanceDateTime = [];

    final double computedTotalAdvance = advanceAmount.fold<double>(
      0,
      (a, b) => a + b,
    );

    // =====================================================
    // STEP 2: CART ITEM DETAILS
    // =====================================================

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
    final int boxQuantities = globals.cartItems.first.boxQuantity ?? 0;
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
      final total = base - disc;
      return total;
    }).toList();

    final double itemTotal = amounts.fold<double>(0, (a, b) => a + b);
    final double totalAmount2 = itemTotal + customCharge;
    final double finalPrice = itemTotal + customCharge - deductedAmount;
    final double balanceAmount = finalPrice - computedTotalAdvance;

    // =====================================================
    // STEP 3: ORDER METADATA
    // =====================================================
    final String saleOrderNo = generateSaleOrderNo();
    final String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    const String deviceName = "POS1";

    Directory? orderDir = await createOrderDir(saleOrderNo);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // =====================================================
    // STEP 4: FILE SAVING (AUDIO/IMAGES)
    // =====================================================
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
    String holdOrderId = generateHoldOrderId();

    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);

    // =====================================================
    // STEP 5: BUILD SALES ORDER OBJECT
    // =====================================================
    final hodOrders = HeldOrder(
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

      finalPrice: finalPrice,
      balanceAmount: balanceAmount,
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
      salesOrderId: '',
    );

    // =====================================================
    // STEP 6: SAVE & SYNC DATA
    // =====================================================
    try {
      final postData = {
        "data": hodOrders.toJson(),
        "type": "holdOrder",
        "deviceName": deviceName,
        "sync": "No",
        "WaitingForDiscountApproval": "No",
        "edit": "No",
      };

      await sendataToServer(postData);

      // PATCH HOLD ORDER

      globals.cartItems.clear();
      clearControllers();

      notifyListeners();
      // =====================================================
      // STEP 7: CLEANUP
      // =====================================================
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
        photoScreen = null;
        audioPlayer = null;
      } catch (e) {}
    } catch (e, st) {
      rethrow;
    } finally {
      cartProvider.clearCart();
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
}

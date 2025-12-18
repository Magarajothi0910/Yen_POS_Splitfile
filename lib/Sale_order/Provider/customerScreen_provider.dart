import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/Audio%20Player/audio_provider.dart';
import 'package:yenpos/Global/Model/branch_model.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Global/Provider/connectivity_internet.dart';

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
import 'package:yenpos/Server_Client/handlers/saleorder_handlemessage.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';
import 'package:yenpos/printer_screen/provider/printer_config_provider.dart';
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
  final PrinterProviderpos printerProvider;

  //from kot payment variable
  double orderAmount = 0.0;
  double discount = 0;
  double customCharge = 0;
  double totalAdvance = 0;
  double deductedAmount = 0;
  double totalAmount = 0.0;
  ValueNotifier<int> cartItemCountNotifier = ValueNotifier<int>(0);
  ValueNotifier<int> cartItemsNotifier = ValueNotifier<int>(0);
  CustomerScreenProvider({required this.printerProvider}) {
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
      chargeType: '',
      printerProvider: printerProvider,

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
      saleOrderNo: "",
      printerProvider: printerProvider,
    );
    // Initialize connectivity provider from context

    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
    getEventList();
    getChargesList();
  }

  TextEditingController otherEventController = TextEditingController();
  TextEditingController combinedController = TextEditingController();
  final FocusNode customChargeFocus = FocusNode(); // 👈 new
  String? holdId;

  final Razorpay _razorpay = Razorpay();
  bool isStoreTypeDialogShowing = false;
  bool isStoreTypeSelected = false;
  List<bool> itemSelections = []; // List to track selection state of each item
  String selectedStoreType = 'Warehouse';
  bool showCheckBoxes = false; // To control if checkboxes should be shown

  final TextEditingController allBoxQtyController = TextEditingController();
  final FocusNode allBoxQtyFocus = FocusNode(); // 👈 new
  final Map<String, TextEditingController> boxQtyControllers = {};
  final TextEditingController bulkDiscountController = TextEditingController();
  final Map<String, TextEditingController> discountControllers = {};
  final Map<String, FocusNode> discountFocusNodes = {};
  bool isDialogShownToday = false;
  // Prevent listener loop
  bool isInternalUpdate = false;
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

  /// 📸 Multiple picked images
  List<File> pickedImages = [];

  /// Update images from ImagePickerWidget
  void setPickedImages(List<File> images) {
    pickedImages = images;
    notifyListeners();
  }

  List<String> getEventList() {
    final eventsBox = HiveManager.events;
    final storedEvents = eventsBox.get('events', defaultValue: []);

    // Extract event names correctly
    if (storedEvents is List) {
      return storedEvents.map<String>((e) {
        if (e is Map && e.containsKey('eventname')) {
          return e['eventname'].toString(); // 👈 correct key
        }
        return e.toString();
      }).toList();
    }

    return [];
  }

  List<String> getChargesList() {
    final eventsBox = HiveManager.customCharges;
    final storedEvents = eventsBox.get('charges', defaultValue: []);

    // Extract event names correctly
    if (storedEvents is List) {
      return storedEvents.map<String>((e) {
        if (e is Map && e.containsKey('chargeType')) {
          return e['chargeType'].toString(); // 👈 correct key
        }
        return e.toString();
      }).toList();
    }

    return [];
  }

  String _selectedStoreType = 'Warehouse';
  bool _isStoreTypeSelected = false;

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
  String? selectedChargeType;
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

  List<String> selectedChargeTypes =
      []; // Instead of a single selectedChargeType
  void updateCartCount() {
    cartItemCountNotifier.value = globals.cartItems.length;
  }

  // Update notifier when cart changes
  void updateCartItems() {
    cartItemsNotifier.value = globals.cartItems.length;
  }

  /// Sends the brand‑new customer to the back‑end so every device sees it.
  Future<bool> sendNewCustomer(
    String mobile,
    String name,
    BuildContext context,
  ) async {
    final Map<String, dynamic> customerPayload = {
      "type": "newCustomer",
      "mobile": mobile,
      "name": name,
      "timestamp": DateTime.now().toIso8601String(),
    };

    try {
      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );

      if (connectivityProvider.isConnected) {
        print("send data to customer server");
        await sendataToServer(customerPayload);
        return true; // 🔥 SUCCESS (ONLINE)
      } else {
        print("send customer data in local");
        handleSalesOrderAddCustomer(customerPayload);
        return true; // 🔥 SUCCESS (OFFLINE)
      }
    } catch (e) {
      print("Error adding customer: $e");
      return false; // ❌ ERROR
    }
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

  void resetControllers() {
    mobileNoController.text = '';
    customerNameController.text = '';
    combinedController.text = "";
    // Reset any other controllers if needed
  }

  // ==========================
  // FETCH HELD ORDERS FROM HIVE
  // ==========================
  Future<List<Map<String, dynamic>>> fetchHolderFromHive() async {
    try {
      final hiveOrders = await getSavedHoldOrders();

      if (hiveOrders.isEmpty) return [];

      // Filter orders with status "Hold Order"
      final holdOrders = hiveOrders.where((order) {
        final data = order['data'] ?? {};
        final status = (data['status'] ?? '').toString().toLowerCase().trim();
        return status == 'hold order';
      }).toList();

      // Flatten for easier UI access
      final flattenedOrders = holdOrders
          .map((order) => Map<String, dynamic>.from(order['data'] ?? {}))
          .toList();

      _hiveholdSalesOrders = List.from(flattenedOrders);
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
          rowId: UniqueKey().toString(), // 🔥 NEVER reuse
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
    receiptPrinter.chargeType = data['customChargeType'] ?? '';
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
          rowId: UniqueKey().toString(), // 🔥 NEVER reuse
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
    BuildContext context,
  ) async {
    try {
      // Step 1: Prepare cancel order data
      final cancelOrderData = {
        'type': 'cancelOrder', // Action identifier for server
        'saleOrderNo': salesOrderId,
        'data': payload,
      };
      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );
      if (connectivityProvider.isConnected) {
        await sendataToServer(cancelOrderData);
      } else {
        handlePatchSaleOrder(cancelOrderData);
      }
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
    Map<String, double> payments,
    double customChargeAmount,
    String customChargeType,
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

    final double itemTotal = saleOrders.amount.fold<double>(0, (a, b) => a + b);

    final double totalAmount2 = itemTotal + customCharge;

    final double finalPrice = itemTotal + customCharge - deductedAmount;

    final double balanceAmount = finalPrice - computedTotalAdvance;

    // Common sales order data
    Map<String, dynamic> orderData = {
      "discountAmount": deductedAmount,
      "discount": discount,
      "status": "Confirm Order",
      "customChargeType": customChargeType,
      "customCharge": customChargeAmount,
      "shiftId": [globalsData.shiftId.value],
      "advanceAmount": advanceAmount,
      "advancePaymentType": advancePaymentType,
      "modeWiseAmount": modeWiseAmount,
      "advanceDateTime": advanceDateTime,
      "balanceAmount": balanceAmount,
      "totalAmount2": totalAmount2,
    };

    try {
      String jsonadvanceSalesOrder = jsonEncode({
        "data": orderData,
        "saleOrderNo": saleOrders.saleOrderNo,
        "type": "patchSaleOrder",
        "sync": "No",
        "edit": "No",
      });
      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );
      if (connectivityProvider.isConnected) {
        await sendataToServer(jsonDecode(jsonadvanceSalesOrder));
      } else {
        handlePatchSaleOrder(jsonDecode(jsonadvanceSalesOrder));
      }

      // Small delay
      await Future.delayed(Duration(milliseconds: 500));

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
    } finally {
      clearControllers();

      isSubmitting = false;
      showAudioandImage = false;

      advanceDateTime.clear();
      advancePaymentType.clear();

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
      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );
      if (connectivityProvider.isConnected) {
        await sendataToServer(jsonDecode(jsonSalesOrder));
      } else {
        handleSalesApprovalOrder(jsonDecode(jsonSalesOrder));
      }

      // Check if it reaches here

      final patchData = jsonEncode(orderData); // Use the single orderData map
      final url = Uri.parse(
        'https://yenerp.com/fluttertestapi/salesorders/${saleOrders.salesOrderId}',
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
  String? selectedDeliveryType = '';
  void setSelectedEvent(String? event) {
    _selectedEvent = event;
    notifyListeners();
  }

  void setSelectedCustomCharge(String? charges) {
    selectedChargeType = charges;
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
    CartProvider().notifyListeners();
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
    allBoxQtyController.dispose();
    for (final controller in boxQtyControllers.values) {
      controller.dispose();
    }
    for (final controller in discountControllers.values) {
      controller.dispose();
    }
    bulkDiscountController.dispose();

    super.dispose();
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
                        cartSelectionProvider: cartSelectionProvider,
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

    // Get the aliasName from the stored branch
    String aliasName = globals.aliasname;

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
        .map((e) => e.quantity.value)
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
    final List<int> sellingPrices = globals.cartItems
        .map((item) => (item.sellingPrice ?? 0).toInt())
        .toList();
    final List<double> sellingAmounts = globals.cartItems
        .map((item) => (item.sellingAmount ?? 0.0).toDouble())
        .toList();
    double customCharge = 0;

    // Sum all custom charges from the map
    for (var controller in cartProvider.customChargeControllers.values) {
      customCharge += double.tryParse(controller!.text) ?? 0;
    }

    final List<double> amounts = globals.cartItems.map((item) {
      final base = (item.uom == 'Pcs' || item.uom == 'Pkt')
          ? (item.pricePerKg * item.quantity.value).toDouble()
          : (item.weight * item.quantity.value * item.pricePerKg);
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
    List<String> savedImagePaths = [];

    if (pickedImages.isNotEmpty && orderDir != null) {
      for (int i = 0; i < pickedImages.length; i++) {
        final savedPath = await saveFile(
          pickedImages[i],
          orderDir,
          '${saleOrderNo}_${timestamp}_img${i + 1}',
        );
        savedImagePaths.add(savedPath!);
      }
    }
    final String orderDateIso = DateTime.now().toIso8601String();
    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
    DateTime eventDateTime;
    if (birthdaydateController.text.isNotEmpty &&
        timeController.text.isNotEmpty) {
      eventDateTime = DateFormat(
        "dd-MM-yyyy hh:mm a",
      ).parse("${birthdaydateController.text} ${timeController.text}");
    } else {
      eventDateTime = DateTime.now(); // or null, or skip
    }
    final String eventDateIso = eventDateTime.toIso8601String();
    DateTime deliveryDateTime;
    if (dateController.text.isNotEmpty && timeController.text.isNotEmpty) {
      deliveryDateTime = DateFormat(
        "dd-MM-yyyy hh:mm a",
      ).parse("${dateController.text} ${timeController.text}");
    } else {
      throw Exception("Delivery date & time missing");
    }
    final String deliveryDateIso = deliveryDateTime.toIso8601String();
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
      sellingPrice: sellingPrices, // now List<int>
      sellingAmount: sellingAmounts, // List<double>
      boxQty: boxQuantities,
      totalAmount2: totalAmount2,
      branchId: globals.branchId,
      branchName: globals.branchName,
      aliasName: globals.aliasname,
      totalAmount: itemTotal,
      itemCode: itemCodes,
      tax: taxs,
      price: prices,
      deliveryDate: deliveryDateIso,
      deliveryTime: timeController.text,
      event: (selectedEvent ?? ""),
      customerNumber: mobileNoController.text,
      customerName: customerNameController.text,
      deliveryType: (selectedDeliveryType ?? ""),
      address: addressController.text,
      landmark: landmarkController.text,
      discount: discount,
      discountAmount: deductedAmount,

      shiftId: [globalsData.shiftId.value],
      customCharge: customCharge,
      advanceAmount: advanceAmount,
      advancePaymentType: advancePaymentType,
      modeWiseAmount: modeWiseAmount,
      finalPrice: finalPrice,
      balanceAmount: balanceAmount,
      saleOrderNo: saleOrderNo,
      orderDate: orderDateIso,
      imagePaths: savedImagePaths, // List<String>
      audioPath: savedAudioPath,
      // imagePath1: savedImg1Path,
      // imagePath2: savedImg2Path,
      employeeName: searchController.text,
      status: 'Confirm Order',
      advanceDateTime: advanceDateTime,
      companyName: companyNameController.text,
      companyAddress: companyAddressController.text,
      companyGST: companygstNumberController.text,
      orderType: (selectedOrderOption ?? ""),
      eventDate: eventDateIso,
      itemWiseDiscount: itemWiseDiscounts,
      itemWiseDiscountAmount: itemWiseDiscountAmounts,
      holdOrderId: patchHoldOrderId,
      approvalOrderId: approvalOrderId,
      customChargeType: selectedChargeType,
      remark: remarkController.text,
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
      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );
      if (connectivityProvider.isConnected) {
        await sendataToServer(postData);
      } else {
        await handleSaleOrder(postData);
      }

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
        if (connectivityProvider.isConnected) {
          await sendataToServer(patchData);
        } else {
          await handlePatchHoldOrder(patchData);
        }

        await fetchHolderFromHive();
        notifyListeners();
      }
      globals.cartItems.clear();
      clearControllers();

      notifyListeners();
      // =====================================================
      // STEP 7: CLEANUP
      // =====================================================
      try {
        cartSelectionProvider.clearSelections();
        globals.cartItems.clear();
        clearControllers();
        cartProvider.clearCart();
        if (path != null) clearFile(path);
        if (img1 != null) clearFile(img1.path);
        if (img2 != null) clearFile(img2.path);
        if (path != null) clearFile(path);
        advanceDateTime.clear();
        advancePaymentType.clear();
        modeWiseAmount.clear();
        advanceAmount.clear();

        isSubmitting = false;
        showAudioandImage = false;
        pickedImage1 = null;
        pickedImage2 = null;
        recordedFilePath = '';
        photoScreen = null;
        audioPlayer = null;
        Navigator.of(context).pop();
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
      isSubmitting = true;

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

      final double computedTotalAdvance = advanceAmount.fold<double>(
        0,
        (a, b) => a + b,
      );

      // 🔹 Step 2: Collect cart item details
      List<String> itemNames = globals.cartItems
          .map((item) => item.itemName)
          .toList();
      List<String> varianceNames = globals.cartItems
          .map((item) => item.varianceName)
          .toList();
      List<int> quantities = globals.cartItems
          .map((item) => item.quantity.value)
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
      final List<double> itemWiseDiscounts = globals.cartItems
          .map((e) => e.itemWiseDiscount ?? 0.0)
          .toList();
      final List<double> itemWiseDiscountAmounts = globals.cartItems
          .map((e) => e.itemWiseDiscountAmount ?? 0.0)
          .toList();
      final List<int> sellingPrices = globals.cartItems
          .map((item) => (item.sellingPrice ?? 0).toInt())
          .toList();
      final List<double> sellingAmounts = globals.cartItems
          .map((item) => (item.sellingAmount ?? 0.0).toDouble())
          .toList();

      final int boxQuantities = globals.cartItems.first.boxQuantity ?? 0;

      final List<String> isBoxItem = globals.cartItems
          .map((e) => e.isBoxItem ?? '')
          .toList();

      double customCharge = 0;

      // Sum all custom charges from the map
      for (var controller in cartProvider.customChargeControllers.values) {
        customCharge += double.tryParse(controller!.text) ?? 0;
      }

      final List<double> amounts = globals.cartItems.map((item) {
        final base = (item.uom == 'Pcs' || item.uom == 'Pkt')
            ? (item.pricePerKg * item.quantity.value).toDouble()
            : (item.weight * item.quantity.value * item.pricePerKg);
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

      if (recordedFilePath != null && orderDir != null) {
        savedAudioPath = await saveFile(
          File(recordedFilePath),
          orderDir,
          '${saleOrderNo}_${timestamp}_audio',
        );
      }

      if (pickedImage1 != null && orderDir != null) {
        savedImg1Path = await saveFile(
          pickedImage1,
          orderDir,
          '${saleOrderNo}_${timestamp}_img1',
        );
      }

      if (pickedImage2 != null && orderDir != null) {
        savedImg2Path = await saveFile(
          pickedImage2,
          orderDir,
          '${saleOrderNo}_${timestamp}_img2',
        );
      }
      List<String> savedImagePaths = [];

      if (pickedImages.isNotEmpty && orderDir != null) {
        for (int i = 0; i < pickedImages.length; i++) {
          final savedPath = await saveFile(
            pickedImages[i],
            orderDir,
            '${saleOrderNo}_${timestamp}_img${i + 1}',
          );
          savedImagePaths.add(savedPath!);
        }
      }
      // Generate IDs
      approvalOrderId = generateApprovalOrderId();
      final String orderDateIso = DateTime.now().toIso8601String();
      storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
      DateTime eventDateTime;
      if (birthdaydateController.text.isNotEmpty &&
          timeController.text.isNotEmpty) {
        eventDateTime = DateFormat(
          "dd-MM-yyyy hh:mm a",
        ).parse("${birthdaydateController.text} ${timeController.text}");
      } else {
        eventDateTime = DateTime.now(); // or null, or skip
      }
      final String eventDateIso = eventDateTime.toIso8601String();
      DateTime deliveryDateTime;
      if (dateController.text.isNotEmpty && timeController.text.isNotEmpty) {
        deliveryDateTime = DateFormat(
          "dd-MM-yyyy hh:mm a",
        ).parse("${dateController.text} ${timeController.text}");
      } else {
        throw Exception("Delivery date & time missing");
      }
      final String deliveryDateIso = deliveryDateTime.toIso8601String();
      // =====================================================
      // STEP 5: BUILD SALES ORDER OBJECT
      // =====================================================
      // 🔹 Step 4: Create SalesOrder object
      SalesOrder approvalOrder = SalesOrder(
        itemName: itemNames,
        varianceName: varianceNames,
        qty: quantities,
        uom: uoms,

        isBoxItem: isBoxItem,
        weight: weights,
        amount: amounts,
        sellingPrice: sellingPrices, // now List<int>
        sellingAmount: sellingAmounts, // List<double>
        boxQty: boxQuantities,
        totalAmount2: totalAmount2,
        branchId: globals.branchId,
        branchName: globals.branchName,
        aliasName: globals.aliasname,
        totalAmount: itemTotal,
        itemCode: itemCodes,
        tax: taxs,
        price: prices,
        deliveryDate: deliveryDateIso,
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
        shiftId: [globalsData.shiftId.value],
        customCharge: customCharge,
        advanceAmount: advanceAmount,
        advancePaymentType: advancePaymentType,
        modeWiseAmount: modeWiseAmount,
        finalPrice: finalPrice,
        balanceAmount: balanceAmount,
        saleOrderNo: saleOrderNo,
        orderDate: orderDateIso,

        audioPath: savedAudioPath,
        imagePaths: savedImagePaths, // List<String>
        // imagePath1: savedImg1Path,
        // imagePath2: savedImg2Path,
        employeeName: searchController.text,

        advanceDateTime: advanceDateTime,
        companyName: companyNameController.text,
        companyAddress: companyAddressController.text,
        companyGST: companygstNumberController.text,
        orderType: (selectedOrderOption ?? ""),
        eventDate: eventDateIso,
        itemWiseDiscount: itemWiseDiscounts,
        itemWiseDiscountAmount: itemWiseDiscountAmounts,
        holdOrderId: patchHoldOrderId,
        approvalOrderId: approvalOrderId,

        status: 'Waiting for Approval',

        approvalDetails: [
          ApprovalOrderDetail(
            approvalType: "Discount",
            approvalStatus: 'Sending to Approval',
            approvalDate: DateTime.now().toIso8601String(),
            summary: 'No',
          ),
        ],
        customChargeType: selectedChargeType ?? '',
      );
      // 🔹 Step 5: Encode to JSON
      String jsonApprovalOrder = jsonEncode({
        "data": approvalOrder.toJson(),
        "type": "salesApprovalOrder",
        'sync': "No",
        'edit': 'No',
        'approvalStatusChanged': 'No',
      });
      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );
      if (connectivityProvider.isConnected) {
        await sendataToServer(jsonDecode(jsonApprovalOrder));
      } else {
        await handleSalesApprovalOrder(jsonDecode(jsonApprovalOrder));
      }

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
    ;

    List<String> itemNames = globals.cartItems
        .map((item) => item.itemName)
        .toList();
    List<String> varianceNames = globals.cartItems
        .map((item) => item.varianceName)
        .toList();
    List<int> quantities = globals.cartItems
        .map((item) => item.quantity.value)
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
    final List<int> sellingPrices = globals.cartItems
        .map((item) => (item.sellingPrice ?? 0).toInt())
        .toList();
    final List<double> sellingAmounts = globals.cartItems
        .map((item) => (item.sellingAmount ?? 0.0).toDouble())
        .toList();

    // Generate IDs
    approvalOrderId = generateApprovalOrderId();

    String approvalType;
    String approvalStatus;
    if (selectedOrderOption == 'Cheque') {
      approvalType = 'Cheque';
      approvalStatus = 'Pending Cheque Payment';
    } else {
      approvalType = 'Discount';
      approvalStatus = 'Sending to Approval';
    }
    isSubmitting = true;

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

    final double computedTotalAdvance = advanceAmount.fold<double>(
      0,
      (a, b) => a + b,
    );

    // 🔹 Step 2: Collect cart item details

    final List<double> itemWiseDiscounts = globals.cartItems
        .map((e) => e.itemWiseDiscount ?? 0.0)
        .toList();
    final List<double> itemWiseDiscountAmounts = globals.cartItems
        .map((e) => e.itemWiseDiscountAmount ?? 0.0)
        .toList();

    final int boxQuantities = globals.cartItems.first.boxQuantity ?? 0;

    final List<String> isBoxItem = globals.cartItems
        .map((e) => e.isBoxItem ?? '')
        .toList();

    double customCharge = 0;

    // Sum all custom charges from the map
    for (var controller in cartProvider.customChargeControllers.values) {
      customCharge += double.tryParse(controller!.text) ?? 0;
    }

    final List<double> amounts = globals.cartItems.map((item) {
      final base = (item.uom == 'Pcs' || item.uom == 'Pkt')
          ? (item.pricePerKg * item.quantity.value).toDouble()
          : (item.weight * item.quantity.value * item.pricePerKg);
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

    if (recordedFilePath != null && orderDir != null) {
      savedAudioPath = await saveFile(
        File(recordedFilePath),
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
    List<String> savedImagePaths = [];

    if (pickedImages.isNotEmpty && orderDir != null) {
      for (int i = 0; i < pickedImages.length; i++) {
        final savedPath = await saveFile(
          pickedImages[i],
          orderDir,
          '${saleOrderNo}_${timestamp}_img${i + 1}',
        );
        savedImagePaths.add(savedPath!);
      }
    }
    // Generate IDs
    approvalOrderId = generateApprovalOrderId();
    final String orderDateIso = DateTime.now().toIso8601String();
    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
    DateTime eventDateTime;
    if (birthdaydateController.text.isNotEmpty &&
        timeController.text.isNotEmpty) {
      eventDateTime = DateFormat(
        "dd-MM-yyyy hh:mm a",
      ).parse("${birthdaydateController.text} ${timeController.text}");
    } else {
      eventDateTime = DateTime.now(); // or null, or skip
    }
    final String eventDateIso = eventDateTime.toIso8601String();
    DateTime deliveryDateTime;
    if (dateController.text.isNotEmpty && timeController.text.isNotEmpty) {
      deliveryDateTime = DateFormat(
        "dd-MM-yyyy hh:mm a",
      ).parse("${dateController.text} ${timeController.text}");
    } else {
      throw Exception("Delivery date & time missing");
    }
    final String deliveryDateIso = deliveryDateTime.toIso8601String();
    // =====================================================
    // STEP 5: BUILD SALES ORDER OBJECT
    // =====================================================
    SalesOrder salesOrder = SalesOrder(
      itemName: itemNames,
      varianceName: varianceNames,
      qty: quantities,
      uom: uoms,

      isBoxItem: isBoxItem,
      weight: weights,
      amount: amounts,
      sellingPrice: sellingPrices, // now List<int>
      sellingAmount: sellingAmounts, // List<double>
      boxQty: boxQuantities,
      totalAmount2: totalAmount2,
      branchId: globals.branchId,
      branchName: globals.branchName,
      aliasName: globals.aliasname,
      totalAmount: itemTotal,
      itemCode: itemCodes,
      tax: taxs,
      price: prices,
      deliveryDate: deliveryDateIso,
      deliveryTime: timeController.text,
      event: (selectedEvent ?? ""),
      customerNumber: mobileNoController.text,
      customerName: customerNameController.text,
      deliveryType: (selectedDeliveryType ?? ""),
      address: addressController.text,
      landmark: landmarkController.text,
      discount: discount,
      discountAmount: deductedAmount,

      shiftId: [globalsData.shiftId.value],
      customCharge: customCharge,
      advanceAmount: advanceAmount,
      advancePaymentType: advancePaymentType,
      modeWiseAmount: modeWiseAmount,
      finalPrice: finalPrice,
      balanceAmount: balanceAmount,
      saleOrderNo: saleOrderNo,
      orderDate: orderDateIso,
      imagePaths: savedImagePaths, // List<String>
      audioPath: savedAudioPath,
      // imagePath1: savedImg1Path,
      // imagePath2: savedImg2Path,
      employeeName: searchController.text,

      advanceDateTime: advanceDateTime,
      companyName: companyNameController.text,
      companyAddress: companyAddressController.text,
      companyGST: companygstNumberController.text,
      orderType: (selectedOrderOption ?? ""),
      eventDate: eventDateIso,
      itemWiseDiscount: itemWiseDiscounts,
      itemWiseDiscountAmount: itemWiseDiscountAmounts,
      holdOrderId: patchHoldOrderId,
      approvalOrderId: approvalOrderId,
      customChargeType: selectedChargeType,
      remark: remarkController.text,

      status: 'Waiting for Approval',

      approvalDetails: [
        ApprovalOrderDetail(
          approvalType: approvalType,
          approvalStatus: approvalStatus,
          approvalDate: DateTime.now().toIso8601String(),
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
        "data": salesOrder.toJson(),
        "type": "salesApprovalOrder",
        'sync': "No",
        'edit': 'No',
        'waitingForApprovalResult': 'Yes',
        "saleOrderNo": salesOrder.saleOrderNo,
      });
      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );
      if (connectivityProvider.isConnected) {
        await sendataToServer(jsonDecode(jsonSalesOrder));
      } else {
        await handleSalesApprovalOrder(jsonDecode(jsonSalesOrder));
      }

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
        .map((e) => e.quantity.value)
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
    double customCharge = 0;

    // Sum all custom charges from the map
    for (var controller in cartProvider.customChargeControllers.values) {
      customCharge += double.tryParse(controller!.text) ?? 0;
    }

    final List<double> amounts = globals.cartItems.map((item) {
      final base = (item.uom == 'Pcs' || item.uom == 'Pkt')
          ? (item.pricePerKg * item.quantity.value).toDouble()
          : (item.weight * item.quantity.value * item.pricePerKg);
      final disc = (item.itemWiseDiscountAmount ?? 0.0);
      final total = base - disc;
      return total;
    }).toList();
    final List<int> sellingPrices = globals.cartItems
        .map((item) => (item.sellingPrice ?? 0).toInt())
        .toList();
    final List<double> sellingAmounts = globals.cartItems
        .map((item) => (item.sellingAmount ?? 0.0).toDouble())
        .toList();
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
    List<String> savedImagePaths = [];

    if (pickedImages.isNotEmpty && orderDir != null) {
      for (int i = 0; i < pickedImages.length; i++) {
        final savedPath = await saveFile(
          pickedImages[i],
          orderDir,
          '${saleOrderNo}_${timestamp}_img${i + 1}',
        );
        savedImagePaths.add(savedPath!);
      }
    }
    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
    final String orderDateIso = DateTime.now().toIso8601String();
    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
    DateTime eventDateTime = DateFormat(
      "dd-MM-yyyy hh:mm a",
    ).parse("${birthdaydateController.text} ${timeController.text}");

    final String eventDateIso = eventDateTime.toIso8601String();
    DateTime deliveryDateTime = DateFormat(
      "dd-MM-yyyy hh:mm a",
    ).parse("${dateController.text} ${timeController.text}");

    final String deliveryDateIso = deliveryDateTime.toIso8601String();
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
      sellingPrice: sellingPrices, // now List<int>
      sellingAmount: sellingAmounts, // List<double>
      boxQty: boxQuantities,
      totalAmount2: totalAmount2,
      branchId: globals.branchId,
      branchName: globals.branchName,
      aliasName: globals.aliasname,
      totalAmount: itemTotal,
      itemCode: itemCodes,
      tax: taxs,
      price: prices,
      deliveryDate: deliveryDateIso,
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
      finalPrice: finalPrice,
      balanceAmount: balanceAmount,
      imagePaths: savedImagePaths, // List<String>
      saleOrderNo: saleOrderNo,
      orderDate: orderDateIso,
      audioPath: savedAudioPath,

      employeeName: searchController.text,
      status: 'Hold Order',
      advanceDateTime: advanceDateTime,
      companyName: companyNameController.text,
      companyAddress: companyAddressController.text,
      companyGST: companygstNumberController.text,
      orderType: (selectedOrderOption ?? ""),
      eventDate: eventDateIso,
      itemWiseDiscount: itemWiseDiscounts,
      itemWiseDiscountAmount: itemWiseDiscountAmounts,
      holdOrderId: holdOrderId,
      approvalOrderId: approvalOrderId,
      customChargeType: selectedChargeType,

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

      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );
      if (connectivityProvider.isConnected) {
        await sendataToServer(postData);
      } else {
        await handleHoldOrder(postData);
      }
      // PATCH HOLD ORDER

      globals.cartItems.clear();
      clearControllers();

      notifyListeners();
      // =====================================================
      // STEP 7: CLEANUP
      // =====================================================
      try {
        cartSelectionProvider.clearSelections();
        globals.cartItems.clear();
        clearControllers();
        cartProvider.clearCart();
        if (path != null) clearFile(path);
        if (img1 != null) clearFile(img1.path);
        if (img2 != null) clearFile(img2.path);
        if (path != null) clearFile(path);
        advanceDateTime.clear();
        advancePaymentType.clear();
        modeWiseAmount.clear();
        advanceAmount.clear();

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

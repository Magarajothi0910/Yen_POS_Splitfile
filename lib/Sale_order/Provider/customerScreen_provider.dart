import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Audio%20Player/audio_provider.dart';
import 'package:yen_pos/Global/Model/branch_model.dart';
import 'package:yen_pos/Global/Provider/connectivity_internet.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart' as globalsData;
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Models/approval_order_model.dart';
import 'package:yen_pos/Sale_order/Models/held_order_model.dart';
import 'package:yen_pos/Sale_order/Models/sale_order_model.dart';
import 'package:yen_pos/Sale_order/Models/sales_invoicemodel.dart';
import 'package:yen_pos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/salesOrder_print.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/op_placeorder_payment.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/so_placeorder_payment_print.dart';
import 'package:yen_pos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yen_pos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yen_pos/Sale_order/Provider/saveAudioandImageFile.dart';
import 'package:yen_pos/Sale_order/Screens/create_sales_order.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Sale_order/Widgets/order_placed_dialogue.dart';
import 'package:yen_pos/Server_Client/handlers/saleorder_handlemessage.dart';
import 'package:yen_pos/Server_Client/handlers/webscoket_messgae_handler.dart';
import 'package:yen_pos/printer_screen/provider/printer_config_provider.dart';
import '../../Global/Provider/branchSelection_provider.dart';
import 'cartProvider.dart';
import '../../../Global/globals_data.dart' as globalbranch;

class CustomerScreenProvider with ChangeNotifier {
  // ==================== PRINTERS ====================
  late salesOrderReceiptPrinter receiptPrinter;
  late salesInvoiceReceiptPrinter invoiceReceiptPrinter;
  final PrinterProviderpos printerProvider;

  // ==================== STATE VARIABLES ====================
  String _orderType = 'Warehouse';
  bool _isRestoringOrder = false;
  bool isRestoringApprovalOrder = false;
  String? originalApprovalStatus;
  bool isOrderAlreadyApproved = false;
  bool isSubmitting = false;
  bool showAudioandImage = true;
  String? holdId;
  int? restoredBoxQty;
  String recordedFilePath = '';
  String salesOrderId = '';
  String? audioPlayer;
  String? photoScreen;
  int? _approvalOrderCounter = 0;
  int _holdOrderCounter = 0;

  // ==================== LISTS ====================
  final List<File> _pickedImages = [];
  List<String> selectedChargeTypes = [];
  List<Map<String, dynamic>> _hiveholdSalesOrders = [];
  List<Map<String, dynamic>> _rawOrders = [];
  List<Map<String, dynamic>> cartItems = [];
  List<String> filteredItems = [];
  final Map<String, int> branchOrderCount = HashMap();

  // ==================== TEXT CONTROLLERS ====================
  final TextEditingController otherEventController = TextEditingController();
  final TextEditingController combinedController = TextEditingController();
  final TextEditingController allBoxQtyController = TextEditingController();
  final TextEditingController bulkDiscountController = TextEditingController();
  final TextEditingController deliveryDateTimeController =
      TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController advanceAmountController = TextEditingController();
  final TextEditingController customersearchController =
      TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customChargeController = TextEditingController();
  final TextEditingController birthdaydateController = TextEditingController();
  final TextEditingController mobileNoController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController companyAddressController =
      TextEditingController();
  final TextEditingController companygstNumberController =
      TextEditingController();
  final TextEditingController customerCombinedController =
      TextEditingController();

  // ==================== FOCUS NODES ====================
  final FocusNode customChargeFocus = FocusNode();
  final FocusNode allBoxQtyFocus = FocusNode();
  final Map<String, FocusNode> discountFocusNodes = {};

  // ==================== CONTROLLER MAPS ====================
  final Map<String, TextEditingController> boxQtyControllers = {};
  final Map<String, TextEditingController> discountControllers = {};

  // ==================== PROVIDERS ====================
  final BranchProvider branchProvider = BranchProvider();
  Branch? storedBranch;

  // ==================== PAYMENT VARIABLES ====================
  double orderAmount = 0.0;
  double discount = 0;
  double customCharge = 0;
  double totalAdvance = 0;
  double deductedAmount = 0;
  double totalAmount = 0.0;
  ValueNotifier<int> cartItemCountNotifier = ValueNotifier<int>(0);
  ValueNotifier<int> cartItemsNotifier = ValueNotifier<int>(0);

  // ==================== SELECTION VARIABLES ====================
  String? _selectedEvent;
  String? _selectedHoldOrderId;
  String selectedPaymentMethod = 'Cash';
  String? selectedDeliveryType = '';
  String customerType = 'Normal';
  String patchHoldOrderId = "";
  String approvalOrderId = "";
  File? pickedImage1;
  File? pickedImage2;
  // ==================== WIDGET KEYS ====================
  Key audioWidgetKey = UniqueKey();

  // ==================== GETTERS ====================
  String get orderType => _orderType;
  List<File> get pickedImages => _pickedImages;
  bool get isRestoringOrder => _isRestoringOrder;
  String? get selectedEvent => _selectedEvent;
  String? get selectedHoldOrderId => _selectedHoldOrderId;
  List<Map<String, dynamic>> get hiveholdSalesOrders => _hiveholdSalesOrders;
  List<Map<String, dynamic>> get rawOrders => _rawOrders;

  bool get shouldEnableSendForApproval {
    if (isRestoringApprovalOrder && isOrderAlreadyApproved) return false;
    return true;
  }

  String? selectedChargeType;

  void setSelectedCustomCharge(String? charges) {
    selectedChargeType = charges;
    notifyListeners();
  }

  bool hasInvalidCartItems() {
    // FIX: Check if cartItems is null
    if (cartItems == null) {
      return false; // or true, depending on your logic
    }

    // Example condition: item quantity <= 0 or item is null
    for (var item in cartItems) {
      if (item == null || item['quantity'] == null || item['quantity'] <= 0) {
        return true;
      }
      // Add any other validation you need
    }
    return false; // no invalid items
  }

  // ==================== CONSTRUCTOR ====================
  CustomerScreenProvider({required this.printerProvider}) {
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
      chargeType: [],
      printerProvider: printerProvider,
      customCharge: [],
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
      salesReturnNo: '',
      salesType: '',
    );

    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
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

    receiptPrinter.customChargeController = (data['totalCustomCharge'] ?? 0.0)
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
    receiptPrinter.chargeType =
        (data['customChargeType'] as List?)?.cast<String>() ?? [];

    // Option 2: More verbose but safer approach
    if (data['customChargeType'] != null) {
      final chargeTypes = data['customChargeType'] as List;
      receiptPrinter.chargeType = chargeTypes.map((e) => e.toString()).toList();
    } else {
      receiptPrinter.chargeType = [];
    }

    // Also update your print statement to handle lists properly

    // --- ADVANCE AMOUNTS ---

    receiptPrinter.advanceAmount = data['advanceAmount'] != null
        ? List<double>.from(
            (data['advanceAmount'] as List).map((x) => (x as num).toDouble()),
          )
        : <double>[];

    receiptPrinter.customCharge = data['customCharge'] != null
        ? List<double>.from(
            (data['customCharge'] as List).map((x) => (x as num).toDouble()),
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
      int itemCount = data['varianceName'].length;

      for (int i = 0; i < itemCount; i++) {
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

    receiptPrinter.customChargeController = (data['totalCustomCharge'] ?? 0.0)
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
    receiptPrinter.chargeType =
        (data['customChargeType'] as List?)?.cast<String>() ?? [];

    // Option 2: More verbose but safer approach
    if (data['customChargeType'] != null) {
      final chargeTypes = data['customChargeType'] as List;
      receiptPrinter.chargeType = chargeTypes.map((e) => e.toString()).toList();
    } else {
      receiptPrinter.chargeType = [];
    }

    // Also update your print statement to handle lists properly

    // --- ADVANCE AMOUNTS ---

    receiptPrinter.advanceAmount = data['advanceAmount'] != null
        ? List<double>.from(
            (data['advanceAmount'] as List).map((x) => (x as num).toDouble()),
          )
        : <double>[];

    receiptPrinter.customCharge = data['customCharge'] != null
        ? List<double>.from(
            (data['customCharge'] as List).map((x) => (x as num).toDouble()),
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
      int itemCount = data['varianceName'].length;

      for (int i = 0; i < itemCount; i++) {
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

  // ==================== ORDER TYPE METHODS ====================
  void toggle() {
    _orderType = (_orderType == 'Inhouse') ? 'Warehouse' : 'Inhouse';
    notifyListeners();
  }

  void setOrderType(String type) {
    _orderType = type;
    notifyListeners();
  }

  // ==================== IMAGE METHODS ====================
  void addImages(List<File> images) {
    _pickedImages.addAll(images);
    notifyListeners();
  }

  void removeImage(int index) {
    if (index >= 0 && index < _pickedImages.length) {
      _pickedImages.removeAt(index);
      notifyListeners();
    }
  }

  void resetImages() {
    _pickedImages.clear();
    notifyListeners();
  }

  void setImages(List<File> images) {
    _pickedImages.clear();
    _pickedImages.addAll(images);
    notifyListeners();
  }

  void clearImages() {
    _pickedImages.clear();
    notifyListeners();
  }

  // ==================== AUDIO METHODS ====================
  void resetAudioRecording() {
    recordedFilePath = '';
    notifyListeners();
  }

  void clearAudio() {
    audioPlayer = null;
    recordedFilePath = '';
    photoScreen = null;
    showAudioandImage = false;
    notifyListeners();
  }

  void resetAudioWidget() {
    audioWidgetKey = UniqueKey();
    audioPlayer = null;
    recordedFilePath = '';
    showAudioandImage = false;
    notifyListeners();
  }

  void resetAudioCompletelyAfterHeldOrder() {
    recordedFilePath = '';
    audioPlayer = null;
    showAudioandImage = false;
    photoScreen = null;
    audioWidgetKey = UniqueKey();
    notifyListeners();
  }

  // ==================== CART METHODS ====================
  void updateCartCount() {
    cartItemCountNotifier.value = globals.cartItems.length;
  }

  void updateCartItems() {
    cartItemsNotifier.value = globals.cartItems.length;
  }

  // ==================== ORDER STATE METHODS ====================
  void startNewOrder() {
    _isRestoringOrder = false;
    isRestoringApprovalOrder = false;
    originalApprovalStatus = null;
    notifyListeners();
  }

  void resetOrderState() {
    _isRestoringOrder = false;
    isRestoringApprovalOrder = false;
    originalApprovalStatus = null;
    clearAudio();
    notifyListeners();
  }

  void setRestoringOrder(bool value) {
    _isRestoringOrder = value;
    notifyListeners();
  }

  void setOriginalApprovalStatus(String? status) {
    originalApprovalStatus = status;
    notifyListeners();
  }

  void setRestoringApprovalOrder(bool value) {
    isRestoringApprovalOrder = value;
    notifyListeners();
  }

  void setIsOrderAlreadyApproved(bool value) {
    isOrderAlreadyApproved = value;
    notifyListeners();
  }

  void resetApprovalFlags() {
    isRestoringApprovalOrder = false;
    originalApprovalStatus = null;
    isOrderAlreadyApproved = false;
    notifyListeners();
  }

  void setRestoredBoxQty(int? value) {
    restoredBoxQty = value;
    notifyListeners();
  }

  void clearRestoredBoxQty() {
    restoredBoxQty = null;
    notifyListeners();
  }

  // ==================== SELECTION METHODS ====================
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
    filteredItems.clear();
    notifyListeners();
  }

  // ==================== DATE/TIME METHODS ====================
  void updateDateTime(String date, String timeWithAmPm) {
    try {
      print("=== updateDateTime Called ===");
      print("Date received: $date");
      print("Time received: $timeWithAmPm");

      // 1. UI-க்கு set செய்யுங்கள்
      deliveryDateTimeController.text = "$date | $timeWithAmPm";
      dateController.text = date;
      timeController.text = timeWithAmPm;

      // 2. Parse date
      final dateParts = date.split('-');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      // 3. Parse time with AM/PM
      int hour = 0;
      int minute = 0;

      if (timeWithAmPm.contains('AM') || timeWithAmPm.contains('PM')) {
        // Remove AM/PM and get time parts
        final timeStr = timeWithAmPm
            .replaceAll(' AM', '')
            .replaceAll(' PM', '');
        final timeParts = timeStr.split(':');

        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);

        // Convert to 24-hour format
        if (timeWithAmPm.contains('PM') && hour < 12) {
          hour += 12;
        }
        if (timeWithAmPm.contains('AM') && hour == 12) {
          hour = 0;
        }
      } else {
        // Already in 24-hour format
        final timeParts = timeWithAmPm.split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      }

      // 4. Create DateTime for server
      final dateTime = DateTime(year, month, day, hour, minute);
      final time24Hour =
          "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
      final dateTimeForServer = "$date $time24Hour";

      print("Parsed - Hour: $hour, Minute: $minute");
      print("24-hour time: $time24Hour");
      print("For Server: $dateTimeForServer");
      print("=============================\n");

      // Save to your database or state management
      // _saveToDatabase(dateTimeForServer);
    } catch (e) {
      print('Error in updateDateTime: $e');
      // Fallback - just show in UI
      deliveryDateTimeController.text = "$date | $timeWithAmPm";
      dateController.text = date;
      timeController.text = timeWithAmPm;
    }
  }

  String formatTimeWithAmPm(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  // ==================== HIVE METHODS ====================
  List<String> getEventList() {
    final eventsBox = HiveManager.events;
    final storedEvents = eventsBox.get('events', defaultValue: []);

    if (storedEvents is List) {
      return storedEvents.map<String>((e) {
        if (e is Map && e.containsKey('eventname')) {
          return e['eventname'].toString();
        }
        return e.toString();
      }).toList();
    }
    return [];
  }

  List<String> getChargesList() {
    final eventsBox = HiveManager.customCharges;
    final storedEvents = eventsBox.get('charges', defaultValue: []);

    if (storedEvents is List) {
      return storedEvents.map<String>((e) {
        if (e is Map && e.containsKey('chargeType')) {
          return e['chargeType'].toString();
        }
        return e.toString();
      }).toList();
    }
    return [];
  }

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

  // ==================== CUSTOMER METHODS ====================
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
        await sendataToServer(customerPayload);
        return true;
      } else {
        handleSalesOrderAddCustomer(customerPayload);
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  // ==================== ORDER ID GENERATION ====================
  String generateSaleOrderNo() {
    final aliasName = globals.aliasname;
    return 'SO$aliasName';
  }

  String generateApprovalOrderId() {
    _approvalOrderCounter = (_approvalOrderCounter ?? 0) + 1;
    return 'Approval${_approvalOrderCounter.toString().padLeft(2, '0')}';
  }

  // ==================== ORDER SAVE FUNCTIONS ====================
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
    String? audioOrderId,
    String? holdOrderId,
    String? selectedOrderOption,
    BuildContext context,
    Map<String, double> payments,
  ) async {
    if (isSubmitting) return;
    isSubmitting = true;

    try {
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

      if (payments.isNotEmpty) addAdvancePayment(payments);

      final List<String> customChargeTypes = cartProvider.customChargeTypes;
      final List<double> customChargeValues = cartProvider.customChargeValues;
      double totalCustomCharge = customChargeValues.fold(
        0.0,
        (sum, value) => sum + value,
      );

      final double computedTotalAdvance = advanceAmount.fold<double>(
        0,
        (a, b) => a + b,
      );

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
          .map((e) => e.itemWiseDiscountAmount.roundToDouble())
          .toList();
      final List<int> sellingPrices = globals.cartItems
          .map((item) => (item.sellingPrice ?? 0).toInt())
          .toList();
      final List<double> sellingAmounts = globals.cartItems
          .map((item) => (item.sellingAmount ?? 0.0).toDouble())
          .toList();

      final List<double> amounts = globals.cartItems.map((item) {
        final base = (item.uom == 'Pcs' || item.uom == 'Pkt')
            ? (item.pricePerKg * item.quantity.value).toDouble()
            : (item.weight * item.quantity.value * item.pricePerKg);
        final disc = (item.itemWiseDiscountAmount ?? 0.0);
        return base - disc;
      }).toList();

      final double itemTotal = amounts.fold<double>(0, (a, b) => a + b);
      final double totalAmount2 = itemTotal + totalCustomCharge;
      final double finalPrice = itemTotal + totalCustomCharge - deductedAmount;
      final double balanceAmount = finalPrice - computedTotalAdvance;

      final String saleOrderNo = generateSaleOrderNo();
      Directory? orderDir = await createOrderDir(saleOrderNo);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      String? savedAudioPath;
      if (path != null && path.isNotEmpty && orderDir != null) {
        savedAudioPath = await saveFile(
          File(path),
          orderDir,
          '${saleOrderNo}_${timestamp}_audio',
        );
      }

      List<String> savedImagePaths = [];
      if (_pickedImages.isNotEmpty && orderDir != null) {
        for (int i = 0; i < _pickedImages.length; i++) {
          final savedPath = await saveFile(
            _pickedImages[i],
            orderDir,
            '${saleOrderNo}_${timestamp}_img${i + 1}',
          );
          if (savedPath != null) savedImagePaths.add(savedPath);
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
        eventDateTime = DateTime.now();
      }
      final String eventDateIso = eventDateTime.toIso8601String();

      DateTime deliveryDateTime;
      if (dateController.text.isNotEmpty && timeController.text.isNotEmpty) {
        deliveryDateTime = DateFormat(
          "dd-MM-yyyy hh:mm a",
        ).parse("${dateController.text} ${timeController.text}");
      } else {
        deliveryDateTime = DateTime.now();
      }
      final String deliveryDateIso = deliveryDateTime.toIso8601String();
      print("globals.aliasName;${globals.aliasname}");
      print("globals.aliasName;${globals.locationId}");

      final salesOrder = SalesOrder(
        itemName: itemNames,
        varianceName: varianceNames,
        qty: quantities,
        uom: uoms,
        isBoxItem: isBoxItem,
        weight: weights,
        amount: amounts,
        sellingPrice: sellingPrices,
        sellingAmount: sellingAmounts,
        boxQty: boxQuantities,
        totalAmount2: totalAmount2.roundToDouble(),
        branchId: globals.locationId,
        branchName: globals.branchName,
        aliasName: globals.aliasname,
        totalAmount: itemTotal.roundToDouble(),
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
        discountAmount: deductedAmount.roundToDouble(),
        shiftId: [globalsData.shiftId.value],
        customCharge: customChargeValues,
        advanceAmount: advanceAmount,
        advancePaymentType: advancePaymentType,
        modeWiseAmount: modeWiseAmount,
        finalPrice: finalPrice.roundToDouble(),
        balanceAmount: balanceAmount.roundToDouble(),
        saleOrderNo: saleOrderNo,
        orderDate: orderDateIso,
        imagePaths: savedImagePaths,
        audioPath: savedAudioPath,
        employeeName: searchController.text,
        status: 'Confirm Order',
        advanceDateTime: advanceDateTime,
        companyName: companyNameController.text,
        companyAddress: companyAddressController.text,
        companyGST: companygstNumberController.text,
        orderType: (_orderType ?? ""),
        eventDate: eventDateIso,
        itemWiseDiscount: itemWiseDiscounts,
        itemWiseDiscountAmount: itemWiseDiscountAmounts,
        holdOrderId: patchHoldOrderId,
        approvalOrderId: approvalOrderId,
        customChargeType: customChargeTypes,
        remark: remarkController.text,
        totalCustomCharge: totalCustomCharge,
      );

      final postData = {
        "data": salesOrder.toJson(),
        "type": "salesOrder",
        "deviceName": "POS1",
        "sync": "No",
        "WaitingForDiscountApproval": "No",
        "edit": "No",
      };

      if (context.mounted) {
        final connectivityProvider = Provider.of<ConnectivityProvider>(
          context,
          listen: false,
        );
        if (connectivityProvider.isConnected) {
          await sendataToServer(postData);
        } else {
          await handleSaleOrder(postData);
        }
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
          "deviceName": "POS1",
        };

        if (context.mounted) {
          final connectivityProvider = Provider.of<ConnectivityProvider>(
            context,
            listen: false,
          );
          if (connectivityProvider.isConnected) {
            await sendataToServer(patchData);
          } else {
            await handlePatchHoldOrder(patchData);
          }
        } else {
          await handlePatchHoldOrder(patchData);
        }

        await fetchHolderFromHive();
      }

      if (context.mounted) {
        try {
          final audioProvider = Provider.of<AudioProvider>(
            context,
            listen: false,
          );
          await audioProvider.completeAudioReset();
          resetAudioCompletelyAfterHeldOrder();
        } catch (e) {}
      }

      globals.cartItems.clear();
      cartProvider.clearCart();
      cartProvider.clearAllCustomCharges();

      for (var charge in GlobalDataManager().charges) {
        charge['amount'] = 0.0;
      }

      clearControllers();
      resetAudioWidget();
      cartSelectionProvider.clearSelections();
      cartProvider.clearCustomCharges();

      if (path != null && path.isNotEmpty) {
        try {
          final audioFile = File(path);
          if (await audioFile.exists()) await audioFile.delete();
        } catch (e) {}
      }

      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              PopSuccessDialog(onClose: () => Navigator.of(context).pop()),
        );
        Navigator.pop(context);
      }
    } catch (e, st) {
      rethrow;
    } finally {
      cartProvider.clearCart();
      cartSelectionProvider.clearSelections();
      isSubmitting = false;
      showAudioandImage = false;
      recordedFilePath = '';
      audioPlayer = null;
      photoScreen = null;
      if (context.mounted) notifyListeners();
    }
  }

  // ==================== OUTLET SAVE ORDER ====================
  Future<void> outletSaveOrder(
    SalesOrderDisplay saleOrders,
    double totalAdvance,
    double orderAmount,
    double discount,
    double deductedAmount,
    double customCharge,
    String remark,
    String? selectedOrderOption,
    BuildContext context,
    Map<String, double> payments,
    List<String> customChargeType,
    List<double> customChargeValue,
  ) async {
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

    if (payments.isNotEmpty) addAdvancePayment(payments);

    final List<String> customChargeTypes = customChargeType;
    final List<double> customChargeValues = customChargeValue;
    double totalCustomCharge = customChargeValues.fold(
      0.0,
      (sum, val) => sum + val,
    );

    final double computedTotalAdvance = advanceAmount.fold<double>(
      0,
      (a, b) => a + b,
    );
    final double itemTotal = saleOrders.amount.fold<double>(0, (a, b) => a + b);
    final double totalAmount2 = itemTotal + totalCustomCharge;
    final double finalPrice = itemTotal + totalCustomCharge - deductedAmount;
    final double balanceAmount = finalPrice - computedTotalAdvance;

    Map<String, dynamic> orderData = {
      "discountAmount": deductedAmount,
      "discount": discount,
      "status": "Confirm Order",
      "customChargeType": customChargeTypes,
      "customCharge": customChargeValues,
      "shiftId": [globalsData.shiftId.value],
      "advanceAmount": advanceAmount,
      "advancePaymentType": advancePaymentType,
      "modeWiseAmount": modeWiseAmount,
      "advanceDateTime": advanceDateTime,
      "balanceAmount": balanceAmount,
      "totalAmount2": totalAmount2,
      "finalPrice": finalPrice,
      "totalAmount": itemTotal,
      "remark": remark,
      "orderType": selectedOrderOption ?? "",
      "totalCustomCharge": totalCustomCharge,
      "employeeName": saleOrders.employeeName,
      "deliveryDate": saleOrders.deliveryDate,
      "deliveryTime": saleOrders.deliveryTime,
      "itemName": saleOrders.itemName,
      "varianceName": saleOrders.varianceName,
      "qty": saleOrders.qty,
      "uom": saleOrders.uom,
      "sellingPrice": saleOrders.sellingPrice,
      "sellingAmount": saleOrders.sellingAmount,
      "customerName": saleOrders.customerName,
      "customerNumber": saleOrders.customerNumber,
      "address": saleOrders.address,
      "landmark": saleOrders.landmark,
      "branchId": saleOrders.branchId,
      "branchName": saleOrders.branchName,
    };

    try {
      final Map<String, dynamic> patchData = {
        "data": orderData,
        "saleOrderNo": saleOrders.saleOrderNo,
        "type": "patchSaleOrder",
        "sync": "No",
        "edit": "No",
        "deviceName": "POS1",
      };

      bool isConnected = await _checkConnectivity(context);
      if (isConnected) {
        await sendataToServer(patchData);
      } else {
        await handlePatchSaleOrder(patchData);
      }

      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              PopSuccessDialog(onClose: () => Navigator.of(context).pop()),
        );
        Navigator.pop(context);
      }
    } catch (e, st) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save order: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<bool> _checkConnectivity(BuildContext context) async {
    try {
      if (context.mounted) {
        final connectivityProvider = Provider.of<ConnectivityProvider>(
          context,
          listen: false,
        );
        return connectivityProvider.isConnected;
      }
    } catch (e) {}
    return false;
  }

  // ==================== SEND FOR APPROVAL FUNCTIONS ====================
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
    String? audioOrderId,
    String? holdId,
    String? selectedOrderOption,
    BuildContext context,
    Map<String, double> payments,
  ) async {
    if (isSubmitting) return;
    isSubmitting = true;

    try {
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

      final List<String> customChargeTypes = cartProvider.customChargeTypes;
      final List<double> customChargeValues = cartProvider.customChargeValues;
      double totalCustomCharge = customChargeValues.fold(
        0.0,
        (sum, value) => sum + value,
      );

      final double computedTotalAdvance = advanceAmount.fold<double>(
        0,
        (a, b) => a + b,
      );

      final List<String> itemNames = globals.cartItems
          .map((item) => item.itemName)
          .toList();
      final List<String> varianceNames = globals.cartItems
          .map((item) => item.varianceName)
          .toList();
      final List<int> quantities = globals.cartItems
          .map((item) => item.quantity.value)
          .toList();
      final List<String> itemCodes = globals.cartItems
          .map((item) => item.itemCode.toString())
          .toList();
      final List<String> uoms = globals.cartItems
          .map((item) => item.uom.toString())
          .toList();
      final List<int> taxs = globals.cartItems.map((item) => item.tax).toList();
      final List<double> weights = globals.cartItems
          .map((item) => item.weight)
          .toList();
      final List<int> prices = globals.cartItems
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

      final List<double> amounts = globals.cartItems.map((item) {
        final base = (item.uom == 'Pcs' || item.uom == 'Pkt')
            ? (item.pricePerKg * item.quantity.value).toDouble()
            : (item.weight * item.quantity.value * item.pricePerKg);
        final disc = (item.itemWiseDiscountAmount ?? 0.0);
        return base - disc;
      }).toList();

      final double itemTotal = amounts.fold<double>(0, (a, b) => a + b);
      final double totalAmount2 = itemTotal + totalCustomCharge;
      final double finalPrice = itemTotal + totalCustomCharge - deductedAmount;
      final double balanceAmount = finalPrice - computedTotalAdvance;

      final String saleOrderNo = generateSaleOrderNo();
      Directory? orderDir = await createOrderDir(saleOrderNo);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      String? savedAudioPath;
      if (recordedFilePath.isNotEmpty && orderDir != null) {
        savedAudioPath = await saveFile(
          File(recordedFilePath),
          orderDir,
          '${saleOrderNo}_${timestamp}_audio',
        );
      }

      List<String> savedImagePaths = [];
      if (_pickedImages.isNotEmpty && orderDir != null) {
        for (int i = 0; i < _pickedImages.length; i++) {
          final savedPath = await saveFile(
            _pickedImages[i],
            orderDir,
            '${saleOrderNo}_${timestamp}_img${i + 1}',
          );
          savedImagePaths.add(savedPath!);
        }
      }

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
        eventDateTime = DateTime.now();
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

      String approvalType = selectedOrderOption == 'Cheque'
          ? 'Cheque'
          : 'Discount';
      String approvalStatus = selectedOrderOption == 'Cheque'
          ? 'Pending Cheque Payment'
          : 'Sending to Approval';

      SalesOrder salesOrder = SalesOrder(
        itemName: itemNames,
        varianceName: varianceNames,
        qty: quantities,
        uom: uoms,
        isBoxItem: isBoxItem,
        weight: weights,
        amount: amounts,
        sellingPrice: sellingPrices,
        sellingAmount: sellingAmounts,
        boxQty: boxQuantities,
        totalAmount2: totalAmount2,
        branchId: globals.locationId,
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
        customCharge: customChargeValues,
        advanceAmount: advanceAmount,
        advancePaymentType: advancePaymentType,
        modeWiseAmount: modeWiseAmount,
        finalPrice: finalPrice,
        balanceAmount: balanceAmount,
        saleOrderNo: saleOrderNo,
        orderDate: orderDateIso,
        imagePaths: savedImagePaths,
        audioPath: savedAudioPath,
        employeeName: searchController.text,
        advanceDateTime: advanceDateTime,
        companyName: companyNameController.text,
        companyAddress: companyAddressController.text,
        companyGST: companygstNumberController.text,
        orderType: (_orderType ?? ""),
        eventDate: eventDateIso,
        itemWiseDiscount: itemWiseDiscounts,
        itemWiseDiscountAmount: itemWiseDiscountAmounts,
        holdOrderId: patchHoldOrderId,
        approvalOrderId: approvalOrderId,
        customChargeType: customChargeTypes,
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
        totalCustomCharge: totalCustomCharge,
      );

      String jsonSalesOrder = jsonEncode({
        "data": salesOrder.toJson(),
        "type": "salesApprovalOrder",
        'sync': "No",
        'edit': 'No',
        'waitingForApprovalResult': 'Yes',
        "saleOrderNo": salesOrder.saleOrderNo,
      });

      if (context.mounted) {
        final connectivityProvider = Provider.of<ConnectivityProvider>(
          context,
          listen: false,
        );
        if (connectivityProvider.isConnected) {
          await sendataToServer(jsonDecode(jsonSalesOrder));
        } else {
          await handleSalesApprovalOrder(jsonDecode(jsonSalesOrder));
        }

        try {
          final audioProvider = Provider.of<AudioProvider>(
            context,
            listen: false,
          );
          await audioProvider.completeAudioReset();
          resetAudioCompletelyAfterHeldOrder();
        } catch (e) {}
      }

      globals.cartItems.clear();
      cartProvider.clearCart();
      cartProvider.clearAllCustomCharges();

      for (var charge in GlobalDataManager().charges) {
        charge['amount'] = 0.0;
      }

      clearControllers();
      cartProvider.clearCustomCharges();

      if (context.mounted) notifyListeners();
    } catch (e, st) {
      rethrow;
    } finally {
      cartProvider.clearCart();
      isSubmitting = false;
      showAudioandImage = false;
      recordedFilePath = '';
      audioPlayer = null;
      photoScreen = null;
      if (context.mounted) notifyListeners();
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
    double balanceAmount = totalAmount - totalAdvance;
    List<double> advanceAmountList = [totalAdvance];

    String approvalType = selectedOrderOption == 'Cheque'
        ? 'Cheque'
        : 'Discount';
    String approvalStatus = selectedOrderOption == 'Cheque'
        ? 'Pending Cheque Payment'
        : 'Sending to Approval';

    DateTime parsedOrderDate = DateFormat(
      "dd-MM-yyyy",
    ).parse(saleOrders.orderDate);
    String saleOrderNo = generateSaleOrderNo();

    Map<String, dynamic> orderData = {
      "itemName": saleOrders.itemName,
      "varianceName": saleOrders.varianceName,
      "itemCode": saleOrders.itemCode,
      "qty": saleOrders.qty,
      "tax": saleOrders.tax,
      "uom": saleOrders.uom,
      "amount": saleOrders.amount,
      "branchId": saleOrders.branchId,
      "branchName": saleOrders.branchName,
      "price": saleOrders.price,
      "weight": saleOrders.weight,
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
      "advancePaymentType": [selectedPaymentMethod],
      "advanceDateTime": [DateTime.now().toIso8601String()],
      "balanceAmount": balanceAmount,
      "discount": discount,
      "approvalDetails": [
        ApprovalOrderDetail(
          approvalType: approvalType,
          approvalStatus: approvalStatus,
          approvalDate: DateTime.now().toIso8601String(),
          summary: 'No',
        ).toJson(),
      ],
    };

    try {
      String jsonSalesOrder = jsonEncode({
        "data": [orderData],
        "type": "salesApprovalOrder",
        'sync': "No",
        'edit': 'No',
        'waitingForApprovalResult': 'Yes',
        "saleOrderNo": saleOrders.saleOrderNo,
      });

      if (context.mounted) {
        final connectivityProvider = Provider.of<ConnectivityProvider>(
          context,
          listen: false,
        );
        if (connectivityProvider.isConnected) {
          await sendataToServer(jsonDecode(jsonSalesOrder));
        } else {
          handleSalesApprovalOrder(jsonDecode(jsonSalesOrder));
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      clearControllers();
      isSubmitting = false;
      showAudioandImage = false;
      notifyListeners();
    }
  }

  // ==================== SUBMIT FOR APPROVAL ====================
  Future<void> submitForApproval(
    BuildContext context,
    CartSelectionProvider cartSelectionProvider,
    CartProvider cartProvider,
    String recordedFilePath,
    ApiServiceSalesOrderProvider apiService,
    File? pickedImage1,
    File? pickedImage2,
    String customerType,
  ) async {
    if (isSubmitting) return;
    isSubmitting = true;

    try {
      String? originalAudioPath = recordedFilePath;

      final List<double> advanceAmount = [];
      final List<List<String>> advancePaymentType = [];
      final List<List<double>> modeWiseAmount = [];
      final List<String> advanceDateTime = [];

      final double computedTotalAdvance = advanceAmount.fold<double>(
        0,
        (a, b) => a + b,
      );
      final List<String> customChargeTypes = cartProvider.customChargeTypes;
      final List<double> customChargeValues = cartProvider.customChargeValues;
      double totalCustomCharge = customChargeValues.fold(
        0.0,
        (sum, value) => sum + value,
      );

      final List<String> itemNames = globals.cartItems
          .map((item) => item.itemName)
          .toList();
      final List<String> varianceNames = globals.cartItems
          .map((item) => item.varianceName)
          .toList();
      final List<int> quantities = globals.cartItems
          .map((item) => item.quantity.value)
          .toList();
      final List<String> itemCodes = globals.cartItems
          .map((item) => item.itemCode.toString())
          .toList();
      final List<String> uoms = globals.cartItems
          .map((item) => item.uom.toString())
          .toList();
      final List<int> taxs = globals.cartItems.map((item) => item.tax).toList();
      final List<double> weights = globals.cartItems
          .map((item) => item.weight)
          .toList();
      final List<int> prices = globals.cartItems
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

      final List<double> amounts = globals.cartItems.map((item) {
        final base = (item.uom == 'Pcs' || item.uom == 'Pkt')
            ? (item.pricePerKg * item.quantity.value).toDouble()
            : (item.weight * item.quantity.value * item.pricePerKg);
        final disc = (item.itemWiseDiscountAmount ?? 0.0);
        return base - disc;
      }).toList();

      final double itemTotal = amounts.fold<double>(0, (a, b) => a + b);
      final double totalAmount2 = itemTotal + totalCustomCharge;
      final double finalPrice = itemTotal + totalCustomCharge - deductedAmount;
      final double balanceAmount = finalPrice - computedTotalAdvance;

      final String saleOrderNo = generateSaleOrderNo();
      Directory? orderDir = await createOrderDir(saleOrderNo);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      String? savedAudioPath;
      if (recordedFilePath.isNotEmpty && orderDir != null) {
        savedAudioPath = await saveFile(
          File(recordedFilePath),
          orderDir,
          '${saleOrderNo}_${timestamp}_audio',
        );
      }

      List<String> savedImagePaths = [];
      if (_pickedImages.isNotEmpty && orderDir != null) {
        for (int i = 0; i < _pickedImages.length; i++) {
          final savedPath = await saveFile(
            _pickedImages[i],
            orderDir,
            '${saleOrderNo}_${timestamp}_img${i + 1}',
          );
          savedImagePaths.add(savedPath!);
        }
      }

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
        eventDateTime = DateTime.now();
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

      SalesOrder approvalOrder = SalesOrder(
        itemName: itemNames,
        varianceName: varianceNames,
        qty: quantities,
        uom: uoms,
        isBoxItem: isBoxItem,
        weight: weights,
        amount: amounts,
        sellingPrice: sellingPrices,
        sellingAmount: sellingAmounts,
        boxQty: boxQuantities,
        totalAmount2: totalAmount2,
        branchId: globals.locationId,
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
        customCharge: customChargeValues,
        advanceAmount: advanceAmount,
        advancePaymentType: advancePaymentType,
        modeWiseAmount: modeWiseAmount,
        finalPrice: finalPrice,
        balanceAmount: balanceAmount,
        saleOrderNo: saleOrderNo,
        orderDate: orderDateIso,
        audioPath: savedAudioPath,
        imagePaths: savedImagePaths,
        employeeName: searchController.text,
        advanceDateTime: advanceDateTime,
        companyName: companyNameController.text,
        companyAddress: companyAddressController.text,
        companyGST: companygstNumberController.text,
        orderType: (_orderType ?? ""),
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
        customChargeType: customChargeTypes,
        totalCustomCharge: totalCustomCharge,
      );

      String jsonApprovalOrder = jsonEncode({
        "data": approvalOrder.toJson(),
        "type": "salesApprovalOrder",
        'sync': "No",
        'edit': 'No',
        'approvalStatusChanged': 'No',
      });

      if (context.mounted) {
        final connectivityProvider = Provider.of<ConnectivityProvider>(
          context,
          listen: false,
        );
        if (connectivityProvider.isConnected) {
          await sendataToServer(jsonDecode(jsonApprovalOrder));
        } else {
          await handleSalesApprovalOrder(jsonDecode(jsonApprovalOrder));
        }

        try {
          final audioProvider = Provider.of<AudioProvider>(
            context,
            listen: false,
          );
          await audioProvider.completeAudioReset();
          resetAudioCompletelyAfterHeldOrder();
        } catch (e) {}
      }

      globals.cartItems.clear();
      cartProvider.clearCart();
      cartProvider.clearAllCustomCharges();

      for (var charge in GlobalDataManager().charges) {
        charge['amount'] = 0.0;
      }

      clearControllers();
      cartSelectionProvider.clearSelections();
      cartProvider.clearCustomCharges();

      if (originalAudioPath != null && originalAudioPath.isNotEmpty) {
        try {
          final audioFile = File(originalAudioPath);
          if (await audioFile.exists()) await audioFile.delete();
        } catch (e) {}
      }

      if (context.mounted) notifyListeners();
    } catch (e, st) {
      rethrow;
    } finally {
      cartProvider.clearCart();
      cartSelectionProvider.clearSelections();
      isSubmitting = false;
      showAudioandImage = false;
      recordedFilePath = '';
      audioPlayer = null;
      photoScreen = null;
      if (context.mounted) notifyListeners();
    }
  }

  // ==================== HELD ORDER ====================
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
    String? originalAudioPath = path;

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

    final int boxQuantities = globals.cartItems.isNotEmpty
        ? globals.cartItems.first.boxQuantity ?? 0
        : 0;

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

    for (var controller in cartProvider.customChargeControllers.values) {
      double parsed = double.tryParse(controller!.text) ?? 0;
      customCharge += parsed;
    }

    final List<String> customChargeTypes = cartProvider.customChargeTypes;

    final List<double> customChargeValues = cartProvider.customChargeValues;

    double totalCustomCharge = customChargeValues.fold(
      0.0,
      (sum, value) => sum + value,
    );

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
    } else {}

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

    String generatedHoldOrderId = generateHoldOrderId();

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
    } else {}

    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);

    final String orderDateIso = DateTime.now().toIso8601String();

    // =====================================================
    // FIXED DATE PARSING WITH ERROR HANDLING
    // =====================================================

    String? eventDateIso;
    String? deliveryDateIso;

    if (birthdaydateController.text.trim().isNotEmpty &&
        timeController.text.trim().isNotEmpty) {
      try {
        final String eventDateText = birthdaydateController.text.trim();
        final String eventTimeText = timeController.text.trim();

        DateTime eventDateTime = DateFormat(
          "dd-MM-yyyy hh:mm a",
        ).parse("$eventDateText $eventTimeText");
        eventDateIso = eventDateTime.toIso8601String();
      } catch (e) {
        eventDateIso = DateTime.now().toIso8601String();
      }
    } else {
      eventDateIso = DateTime.now().toIso8601String();
    }

    if (dateController.text.trim().isNotEmpty &&
        timeController.text.trim().isNotEmpty) {
      try {
        final String deliveryDateText = dateController.text.trim();
        final String deliveryTimeText = timeController.text.trim();

        DateTime deliveryDateTime = DateFormat(
          "dd-MM-yyyy hh:mm a",
        ).parse("$deliveryDateText $deliveryTimeText");
        deliveryDateIso = deliveryDateTime.toIso8601String();
      } catch (e) {
        deliveryDateIso = DateTime.now().toIso8601String();
      }
    } else {
      deliveryDateIso = DateTime.now().toIso8601String();
    }

    eventDateIso = DateTime.now().toIso8601String();
    deliveryDateIso = DateTime.now().toIso8601String();

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
      sellingPrice: sellingPrices,
      sellingAmount: sellingAmounts,
      boxQty: boxQuantities,
      totalAmount2: totalAmount2,
      branchId: globals.locationId,
      branchName: globals.branchName,
      aliasName: globals.aliasname,
      totalAmount: itemTotal,
      itemCode: itemCodes,
      tax: taxs,
      price: prices,
      deliveryDate: deliveryDateIso,
      deliveryTime: timeController.text.trim().isNotEmpty
          ? timeController.text.trim()
          : formattedTime,
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
      customCharge: customChargeValues,
      finalPrice: finalPrice,
      balanceAmount: balanceAmount,
      imagePaths: savedImagePaths,
      saleOrderNo: saleOrderNo,
      orderDate: orderDateIso,
      audioPath: savedAudioPath,
      employeeName: searchController.text,
      status: 'Hold Order',
      advanceDateTime: advanceDateTime,
      companyName: companyNameController.text,
      companyAddress: companyAddressController.text,
      companyGST: companygstNumberController.text,
      orderType: (_orderType ?? ""),
      eventDate: eventDateIso,
      itemWiseDiscount: itemWiseDiscounts,
      itemWiseDiscountAmount: itemWiseDiscountAmounts,
      holdOrderId: generatedHoldOrderId,
      approvalOrderId: approvalOrderId,
      customChargeType: customChargeTypes,
      totalCustomCharge: totalCustomCharge,
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

      bool isContextValid = false;
      try {
        if (context.mounted) {
          isContextValid = true;
        }
      } catch (e) {
        isContextValid = false;
      }

      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );

      if (connectivityProvider.isConnected) {
        await sendataToServer(postData);
      } else {
        await handleHoldOrder(postData);
      }

      // 🔥 COMPLETE AUDIO CLEANUP
      if (isContextValid && context.mounted) {
        try {
          final audioProvider = Provider.of<AudioProvider>(
            context,
            listen: false,
          );
          await audioProvider.completeAudioReset();

          resetAudioCompletelyAfterHeldOrder();
        } catch (e) {}
      }
      // Use read() instead of watch()
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.clearCart();
      // 🔥 CLEAR CART AND STATE
      globals.cartItems.clear();

      clearControllers();

      cartSelectionProvider.clearSelections();

      cartProvider.clearCart();

      cartProvider.clearCustomCharges();

      // Delete original temp audio file
      if (originalAudioPath != null && originalAudioPath!.isNotEmpty) {
        try {
          final audioFile = File(originalAudioPath!);
          if (await audioFile.exists()) {
            await audioFile.delete();
          } else {}
        } catch (e) {}
      }

      if (isContextValid && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => SalesOrderScreen()),
          (route) => false,
        );
      }

      notifyListeners();
    } catch (e, st) {
      rethrow;
    } finally {
      cartProvider.clearCart();

      cartSelectionProvider.clearSelections();

      isSubmitting = false;

      showAudioandImage = false;

      pickedImage1 = null;
      pickedImage2 = null;

      recordedFilePath = '';

      audioPlayer = null;
      photoScreen = null;

      notifyListeners();
    }
  }

  // ==================== PAYMENT DIALOGS ====================
  void showAdvancePaymentPopup(
    BuildContext context,
    CartSelectionProvider cartSelectionProvider,
    CartProvider cartProvider,
    String? path,
    ApiServiceSalesOrderProvider apiprovider,
    String customerType,
    String? audioOrderId,
    String? holdId,
  ) {
    orderAmount = cartProvider.getTotalAmount();
    discount = 0;
    customCharge = 0;
    totalAdvance = 0;
    deductedAmount = 0;
    totalAmount = orderAmount + customCharge - deductedAmount;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
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
                          const Icon(
                            Icons.payment_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Payment Details – ₹${orderAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
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
                ),
                SizedBox(
                  height: 600,
                  child: PlaceOrderPaymentPrint(
                    cartSelectionProvider: cartSelectionProvider,
                    totalAmount: totalAmount,
                    holdBillId: holdId ?? '',
                    orderId: salesOrderId,
                    discount: discount,
                    totalAdvance: totalAdvance,
                    cartProvider: cartProvider,
                    apiprovider: apiprovider,
                    customCharge: customCharge,
                    selectedStoreType: _orderType,
                    orderAmount: orderAmount,
                    remark: remarkController.text,
                    deductedAmount: deductedAmount,
                    customerType: customerType,
                    path: path,
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
    orderAmount = cartProvider.getTotalAmount();
    discount = 0;
    customCharge = 0;
    totalAdvance = 0;
    deductedAmount = 0;
    totalAmount = salesOrder.totalAmount;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
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
                    ),
                  ),
                ),
                SizedBox(
                  height: 600,
                  child: OpPlaceOrderPaymentPrint(
                    salesOrder: salesOrder,
                    totalAmount: totalAmount,
                    holdBillId: holdId ?? '',
                    orderId: salesOrderId,
                    discount: discount,
                    totalAdvance: totalAdvance,
                    cartProvider: cartProvider,
                    apiprovider: apiprovider,
                    customCharge: customCharge,
                    selectedStoreType: _orderType,
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
  }

  // ==================== CLEANUP METHODS ====================
  void resetControllers() {
    mobileNoController.clear();
    customerNameController.clear();
    combinedController.clear();
    dateController.clear();
    timeController.clear();
    landmarkController.clear();
    addressController.clear();
    companyAddressController.clear();
    birthdaydateController.clear();
    companyNameController.clear();
    companygstNumberController.clear();
    remarkController.clear();
    deliveryDateTimeController.clear();
    customerCombinedController.clear();
    cartItems.clear();
    CartProvider().clearCart();
    CartProvider().notifyListeners();
  }

  Future<void> clearMediaAfterOrder() async {
    if (recordedFilePath.isNotEmpty) {
      try {
        final file = File(recordedFilePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore errors for cleanup
      }
    }
    recordedFilePath = '';
    audioPlayer = null;
    _pickedImages.clear();
    showAudioandImage = false;
  }

  // ==================== DISPOSE ====================
  @override
  void dispose() {
    dateController.dispose();
    timeController.dispose();
    mobileNoController.dispose();
    customerNameController.dispose();
    addressController.dispose();
    landmarkController.dispose();
    searchController.dispose();
    advanceAmountController.dispose();
    allBoxQtyController.dispose();
    bulkDiscountController.dispose();

    for (final controller in boxQtyControllers.values) {
      controller.dispose();
    }
    for (final controller in discountControllers.values) {
      controller.dispose();
    }
    for (final node in discountFocusNodes.values) {
      node.dispose();
    }

    super.dispose();
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
    cartItems.clear();
    deliveryDateTimeController.clear();
    CartProvider().clearCart();
    CartProvider().notifyListeners();
  }
}

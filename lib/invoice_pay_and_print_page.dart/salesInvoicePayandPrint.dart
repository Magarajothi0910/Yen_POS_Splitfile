import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_ui/services/format-time/format_date.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/Provider/current_datetime.dart';
import 'package:yenpos/Global/Screen/camera_qr_screen.dart';
import 'package:yenpos/Global/Widget/custom_sized_box.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Global/pos_detector.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/customer_search.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/invoiceNumberGenerator.dart';
import 'package:yenpos/regular_mode_page/widget/emp_search.dart';

import '../regular_mode_page/provider/cart_page_provider.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'services/save_data_local.dart';
import 'widgets/invoice_Print_Receipt.dart';
import 'services/invoice_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dio/dio.dart';
import 'package:lottie/lottie.dart';

class SalesInvoicePayAndPrint extends StatefulWidget {
  final double totalAmount;
  final String holdBillId;
  final VoidCallback? onDismiss;

  const SalesInvoicePayAndPrint({
    super.key,
    required this.totalAmount,
    required this.holdBillId,
    this.onDismiss,
  });

  @override
  State<SalesInvoicePayAndPrint> createState() =>
      SalesInvoicePayAndPrintState();
}

class SalesInvoicePayAndPrintState extends State<SalesInvoicePayAndPrint> {
  final InvoiceService _invoiceService = InvoiceService();
  final List<String> cashOptions = [];
  final TextEditingController _customAmountController = TextEditingController();
  //final TextEditingController _employeeNumberController = TextEditingController();
  Map<String, Map<String, dynamic>> _allEmployees = {};
  final TextEditingController _customerNumberController =
      TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _couponCodeController = TextEditingController();
  final TextEditingController _customChargeController = TextEditingController();
  final TextEditingController _customCashController = TextEditingController();
  final TextEditingController _customUpiController = TextEditingController();
  final TextEditingController _customCardController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  late List<FocusNode> _focusNodes;
  late ValueNotifier<int> _currentFocusIndexNotifier;
  late List<TextEditingController> _keyboardControllers;

  late WebSocketChannel _channel;

  bool _isInitialSend = true;
  SalesInvoiceState get prov =>
      Provider.of<SalesInvoiceState>(context, listen: false);

  @override
  void initState() {
    super.initState();

    // Connect WebSocket safely
    final uri = Uri.parse('ws://$serverip:$port');
    _channel = WebSocketChannel.connect(uri);
    debugPrint("✅ WebSocket connected to $uri");

    // Setup controllers
    _keyboardControllers = [
      prov.employee,
      _customerNumberController,
      _discountController,
      _customChargeController,
      _customCashController,
      _customUpiController,
      _customCardController,
      _couponCodeController,
      _birthdayController,
    ];

    // Setup focus nodes
    _focusNodes = List.generate(
      _keyboardControllers.length,
      (_) => FocusNode(),
    );
    _currentFocusIndexNotifier = ValueNotifier<int>(0);

    // Listen to focus changes (only once)
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          _currentFocusIndexNotifier.value = i;
        }
      });
    }

    // WebSocket listener (store subscription if you want to cancel)
    _channel.stream.listen(
      (data) {
        debugPrint("Received WebSocket data: $data");
      },
      onError: (error) {
        debugPrint("❌ WebSocket error: $error");
      },
    );

    // Setup providers
    final saleState = Provider.of<SalesInvoiceState>(context, listen: false);
    saleState.updateBalanceAmount(widget.totalAmount);
    cashOptions.addAll(_generateCashOptions(widget.totalAmount));

    _loadEmployees();
    // _addStateListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendState();
    });
  }

  Timer? _debounce;
  Map<String, dynamic> _lastSentData = {};

  final Map<TextEditingController, Timer?> _debounceMap = {};
  bool _listenersAdded = false;

  void _sendState({
    String type = 'state_update',
    Map<String, dynamic>? extraData,
  }) {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );

    final currentData = {
      'isUpiPaid': stateProvider.isUpiPaid,
      'isCardPaid': stateProvider.isCardPaid,
      if (extraData != null) ...extraData,
    };

    final changedFields = <String, dynamic>{};

    if (_isInitialSend) {
      _isInitialSend = false;
    } else {
      currentData.forEach((key, value) {
        if (_lastSentData[key] != value) {
          changedFields[key] = value;
        }
      });
    }

    if (changedFields.isEmpty) return; // nothing changed

    _lastSentData.addAll(changedFields);

    final message = {
      'message': 'changed_fields',
      'type': type,
      ...changedFields,
    };

    try {
      final jsonData = jsonEncode(message);
      _channel.sink.add(jsonData);
      developer.log('Sent: $jsonData', name: 'WebSocket');
    } catch (e) {
      debugPrint('❌ Error sending data: $e');
    }
  }

  void _removeStateListeners() {
    prov.employee.removeListener(() {});
    _customerNumberController.removeListener(() {});
    _customAmountController.removeListener(() {});
    _discountController.removeListener(() {});
    _customChargeController.removeListener(() {});
    _customCashController.removeListener(() {});
    _customUpiController.removeListener(() {});
    _customCardController.removeListener(() {});
    _birthdayController.removeListener(() {});
    _couponCodeController.removeListener(() {});
  }

  // ------------------- QR STATE -------------------
  bool _isQrMode = false;
  final FocusNode _qrFocusNode = FocusNode();
  final TextEditingController _qrController = TextEditingController();
  bool _isProcessingQr = false;

  // ------------------- QR TOGGLE -------------------
  Future<void> _toggleQrMode() async {
    final isPOS = await POSDetector.isPOSDevice;

    if (isPOS) {
      _startHardwareScanner();
    } else {
      _startCameraScan();
    }
  }

  // POS Hardware Scanner
  void _startHardwareScanner() {
    setState(() {
      _isQrMode = true;
      _qrFocusNode.requestFocus();
    });
  }

  // Camera Scanner
  Future<void> _startCameraScan() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QRCodeScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      _handleQrInput(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No QR code scanned.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ------------------- QR INPUT HANDLER -------------------
  void _handleQrInput(String raw) async {
    if (_isProcessingQr || !_isQrMode) return;
    setState(() => _isProcessingQr = true);

    try {
      final data = _parseQrData(raw);
      final name = data['Name']?.toString().trim();
      if (name == null) throw Exception('Name not found');

      final match = _allEmployees.entries.firstWhereOrNull(
        (e) => e.key.contains(name),
      );

      if (match != null) {
        _selectEmployee(match.key);
        prov.employee.selection = TextSelection.fromPosition(
          TextPosition(offset: match.key.length),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee not found in list.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QR Error: $e')));
    } finally {
      _qrController.clear();
      _qrFocusNode.unfocus();
      setState(() {
        _isProcessingQr = false;
        _isQrMode = false;
      });
    }
  }

  // ------------------- QR PARSING -------------------
  Map<String, dynamic> _parseQrData(String raw) {
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      final map = <String, dynamic>{};
      raw.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
        final kv = pair.split(':');
        if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
      });
      if (map.isEmpty) throw Exception('Invalid QR format');
      return map;
    }
  }

  @override
  void dispose() {
    _qrFocusNode.dispose();
    prov.employee.dispose();
    _qrController.dispose();
    debugPrint("🧹 Disposing Payment Screen...");

    _removeStateListeners();

    // Cancel debounce timers
    for (var timer in _debounceMap.values) {
      timer?.cancel();
    }
    _debounceMap.clear();

    // Dispose controllers and focus nodes
    for (final controller in _keyboardControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _currentFocusIndexNotifier.dispose();

    // Close WebSocket
    try {
      _channel.sink.close();
      debugPrint("🔌 WebSocket closed");
    } catch (e) {
      debugPrint("⚠️ Error closing WebSocket: $e");
    }

    // Reset providers
    final saleProvider = Provider.of<CurrentSaleProvider>(
      context,
      listen: false,
    );
    saleProvider.discountPercentage = 0.0;
    saleProvider.customCharge = 0.0;
    saleProvider.calculateTotal();

    final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
    qrProvider.disconnectWebSocket();
    qrProvider.isCardPaid = false;
    qrProvider.errorMessage = null;

    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    stateProvider.reset(); // ✅ This clears all lingering state
    prov.employee.clear();
    super.dispose();
  }

  void setupListener(
    TextEditingController controller, [
    VoidCallback? extraAction,
  ]) {
    controller.addListener(() {
      debugPrint('1 Listener triggered for ${controller.hashCode}');

      extraAction?.call();
      _debounceMap[controller]?.cancel();
      _debounceMap[controller] = Timer(
        const Duration(milliseconds: 200),
        _sendState,
      );
    });
  }

  Future<void> _openDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          Provider.of<SalesInvoiceState>(
            context,
            listen: false,
          ).selectedBirthday ??
          DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      Provider.of<SalesInvoiceState>(
        context,
        listen: false,
      ).updateSelectedBirthday(picked);
      _birthdayController.text = DateFormat('dd-MM-yyyy').format(picked);
      _handleKeyboardOk();
    } else {
      _focusNodes[2].requestFocus();
    }
  }

  // void _handleCardPayment() {
  //   final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
  //   final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
  //   final cardAmountStr = _customCardController.text;

  //   if (cardAmountStr.isNotEmpty) {
  //     final cardAmount = double.tryParse(cardAmountStr);
  //     if (cardAmount != null && cardAmount > 0) {
  //       qrProvider.createOrderAndPay(cardAmount, (String type, Map<String, dynamic>? extraData) {
  //         _sendState(type: type, extraData: extraData);
  //         _sendState(type: 'start_card_payment', extraData: {'amount': cardAmountStr});

  //         if (type == 'card_payment_success') {
  //           stateProvider.updateIsCardPaid(true);
  //           ScaffoldMessenger.of(
  //             context,
  //           ).showSnackBar(const SnackBar(content: Text('Card payment successful!'), backgroundColor: Colors.green));
  //         } else if (type == 'card_payment_error') {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(
  //               content: Text('Card payment failed: ${extraData?['message'] ?? 'Unknown error'}'),
  //               backgroundColor: Colors.red,
  //             ),
  //           );
  //         }
  //       });
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Please enter a valid card amount greater than 0.'), backgroundColor: Colors.red),
  //       );
  //     }
  //   } else {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(const SnackBar(content: Text('Please enter a card amount first.'), backgroundColor: Colors.orange));
  //   }
  // }

  void _handleCardPayment() {
    final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    final cardAmountStr = _customCardController.text;

    if (cardAmountStr.isNotEmpty) {
      final cardAmount = double.tryParse(cardAmountStr);
      if (cardAmount != null && cardAmount > 0) {
        qrProvider.createOrderAndPay(cardAmount, (
          String type,
          Map<String, dynamic>? extraData,
        ) {
          _sendState(type: type, extraData: extraData);
          _sendState(
            type: 'start_card_payment',
            extraData: {'amount': cardAmountStr},
          );

          if (type == 'card_payment_success') {
            // ← UPDATED: Mark as paid
            stateProvider.updateIsCardPaid(true);

            // ← NEW: Show paid amount in the Card field
            _customCardController.text = stateProvider.cardAmount
                .toStringAsFixed(0);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Card payment successful!'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (type == 'card_payment_error') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Card payment failed: ${extraData?['message'] ?? 'Unknown error'}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid card amount greater than 0.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a card amount first.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  final Set<String> _loggedInvoices = {};

  void validateForm() {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    bool isEmployeeSelected =
        stateProvider.selectedEmployeeFirstName != null &&
        prov.employee.text.isNotEmpty;
    bool isCustomerNumberValid = _customerNumberController.text.isNotEmpty;
    bool isBalanceZeroOrNegative = stateProvider.roundedBalance <= 0;

    stateProvider.updateIsPrintButtonEnabled(
      isEmployeeSelected && isCustomerNumberValid && isBalanceZeroOrNegative,
    );
  }

  Future<void> _loadEmployees() async {
    var box = await Hive.openBox('employeeBox');
    List<dynamic> employees = box.get('employees', defaultValue: []);
    // Update _allEmployees without setState
    _allEmployees = {
      for (var emp in employees)
        '${(emp as Map)["employeeNumber"]} - ${(emp as Map)["firstName"]}':
            (emp as Map).cast<String, dynamic>(),
    };
  }

  // void _selectEmployee(String selection) {
  //   final employee = _allEmployees[selection];
  //   if (employee != null) {
  //     Provider.of<SalesInvoiceState>(context, listen: false).updateMultiple(selectedEmployeeFirstName: employee['firstName']);
  //     prov.employee.text = selection;
  //   }
  //   validateForm();
  //   _moveToNextField(0);
  // }

  void _selectEmployee(String selection) {
    final employee = _allEmployees[selection];
    if (employee != null) {
      final stateProvider = Provider.of<SalesInvoiceState>(
        context,
        listen: false,
      );

      stateProvider.updateMultiple(
        selectedEmployeeFirstName: employee['firstName'],
        selectedEmployeeNumber: employee['employeeNumber'], // <-- NEW
      );

      prov.employee.text = selection; // UI text (kept for Autocomplete)
    }

    validateForm();
    _moveToNextField(0);
  }

  Set<String> _sentInvoices = {};

  Future<void> loadSentInvoices() async {
    var box = await Hive.openBox('sentInvoicesBox');
    _sentInvoices = Set<String>.from(box.get('sentInvoices', defaultValue: []));
  }

  Future<void> saveSentInvoices() async {
    var box = await Hive.openBox('sentInvoicesBox');
    await box.put('sentInvoices', _sentInvoices.toList());
  }

  // Future<void> sendInvoiceDataToServer(Map<String, dynamic> invoiceData) async {
  //   try {
  //     final jsonData = jsonEncode(invoiceData);
  //     _channel.sink.add(jsonData);
  //   } catch (e) {}
  // }

  Future<void> sendBillToCustomer(
    String invoiceNo,
    Map<String, dynamic> invoiceData,
  ) async {
    final response = await http.post(
      Uri.parse('http://192.168.1.107:8888/fastapi/invoices/api/send-bill'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'invoiceNo': invoiceNo,
        'invoiceData': invoiceData, // Full data from saveInvoiceToHiveAndPrint1
      }),
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      print('Bill sent: ${result['pdfUrl']}');
    } else {
      print('Failed: ${response.body}');
    }
  }

  Future<void> saveInvoiceToHiveAndPrint1(String newInvoiceNumber) async {
    // Step 1: Generate a unique HiveInvoiceId
    String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();

    // Step 2: Prepare the invoice data
    var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
    var stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
    var cartItems = cartProvider.currentSaleItems ?? [];

    // Extract item data into separate lists
    List<String> itemNames = [];
    List<String> varianceNames = [];
    List<double> prices = [];
    List<double> weights = [];
    List<double> quantities = [];
    List<double> amounts = [];
    List<double> taxes = [];
    List<String> uoms = [];
    List<String> varianceItemCode = [];
    List<String> gstRates = [];
    List<String> gstValues = [];

    double discount_perc = _discountController.text.isNotEmpty
        ? double.tryParse(_discountController.text) ?? 0.0
        : 0.0;
    double customCharge = _customChargeController.text.isNotEmpty
        ? double.tryParse(_customChargeController.text) ?? 0.0
        : 0.0;

    double totalItemTotal = 0.0; // Sum of discounted, tax-inclusive item totals
    double totalNet = 0.0; // Net amount before tax (after discount)
    double totalCross = 0.0; // Total amount including custom charge
    double totalDiscountAmount = 0.0; // Total discount applied

    List<double> sellingPrices = [];
    List<double> sellingAmounts = [];

    for (var item in cartItems) {
      itemNames.add(item['itemData']['itemName'] ?? 'N/A');
      varianceNames.add(item['varianceData']['varianceName'] ?? 'N/A');
      double price =
          item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0;
      varianceItemCode.add(item['varianceData']['varianceitemCode'] ?? 'N/A');
      prices.add(price);
      weights.add((item['weight'] ?? 0.0).toDouble());
      double qty = (item['quantity'] as num).toDouble() ?? 0.0;
      quantities.add(qty);
      double orig_amount = cartProvider
          .calculateItemTotal(item)
          .toDouble(); // Tax-inclusive
      amounts.add(orig_amount);
      double tax = (item['itemData']['tax'] as num).toDouble();
      taxes.add(tax);
      uoms.add(item['varianceData']['variance_Uom'] ?? 'N/A');

      // === CORRECT GST & DISCOUNT CALCULATION ===
      double item_discount_amt = orig_amount * (discount_perc / 100);
      double discounted_gross =
          orig_amount - item_discount_amt; // Tax-inclusive after discount

      double tax_rate = tax / 100.0;
      double net_exclusive = tax > 0
          ? discounted_gross / (1 + tax_rate)
          : discounted_gross;
      double gst_amount = discounted_gross - net_exclusive;

      // Accumulate totals
      totalDiscountAmount += item_discount_amt;
      totalItemTotal += discounted_gross;
      totalNet += net_exclusive;

      // Store GST
      gstRates.add(tax.toStringAsFixed(1));
      gstValues.add(gst_amount.toStringAsFixed(2));

      // Selling price (for display)
      double disc_price = price * (1 - discount_perc / 100);
      sellingPrices.add(disc_price);
      sellingAmounts.add(discounted_gross);
    }

    totalCross = totalItemTotal + customCharge;

    // Step 3: Prepare the complete invoice data
    DateTime billDate = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(billDate);
    String formattedTime = DateFormat('hh:mm a').format(billDate);

    String uniqueIdentifier =
        '$formattedDate-${totalItemTotal}-${_customerNumberController.text}';

    String customerPhone = _customerNumberController.text
        .split(' - ')
        .first
        .trim();

    //final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);

    String salesPersonId = stateProvider.selectedEmployeeNumber ?? '';
    String salesPersonName = stateProvider.selectedEmployeeFirstName ?? '';

    // ---- Defensive fallback (only if Provider is empty) ----
    if (salesPersonId.isEmpty || salesPersonName.isEmpty) {
      final raw = prov.employee.text;
      if (raw.contains(' - ')) {
        final parts = raw.split(' - ');
        salesPersonId = parts[0].trim();
        salesPersonName = parts.length > 1 ? parts[1].trim() : salesPersonId;
      }
    }
    developer.log(
      'SalesPerson → ID: "$salesPersonId", Name: "$salesPersonName"',
      name: 'Invoice',
    );

    Map<String, dynamic> invoiceData = {
      'HiveInvoiceId': hiveInvoiceId,
      'itemName': itemNames,
      'varianceitemCode': varianceItemCode,
      'varianceName': varianceNames,
      'price': prices,
      'sellingPrice': sellingPrices,
      'sellingAmount': sellingAmounts,
      'weight': weights,
      'qty': quantities,
      'amount': amounts,
      'tax': taxes,
      'uom': uoms,
      'salesPersonId': salesPersonId,
      'salesPersonName': salesPersonName,
      'customerPhoneNumber': customerPhone,
      'discountPercentage': _discountController.text.isNotEmpty
          ? int.tryParse(_discountController.text) ?? 0
          : 0,
      'customCharge': _customChargeController.text.isNotEmpty
          ? int.tryParse(_customChargeController.text) ?? 0
          : 0,
      'totalAmount': totalItemTotal.toStringAsFixed(0),
      'netAmount': totalNet.toStringAsFixed(2),
      'grossAmount': totalCross.toStringAsFixed(0),
      'invoiceDateTime': billDate.toIso8601String(),
      'branchId': "$branchId",
      'salesType': "TakeAway",
      'branchName': "$branchName",
      'aliasName': "$aliasname",
      'cash': stateProvider.cashAmount > 0 ? stateProvider.cashAmount : null,
      'card': stateProvider.cardAmount > 0 ? stateProvider.cardAmount : null,
      'upi': stateProvider.upiAmount > 0 ? stateProvider.upiAmount : null,
      'others': null,
      'shiftNumber': "1",
      'shiftId': shiftId.value,
      'invoiceNo': newInvoiceNumber,
      'deviceNumber': "1",
      'sync': "no",
      'status': "active",
      'uniqueIdentifier': uniqueIdentifier,
      'gst': gstRates,
      'gstValue': gstValues,
      'discountAmount': totalDiscountAmount > 0
          ? totalDiscountAmount
          : null, // Added
    };
    debugPrint('posInvoice1');
    // Wrap invoice into JSON
    final invoiceJson = jsonEncode({
      "salesOrderId": invoiceData,
      "type": "posInvoice",
      "sync": "No",
      "edit": "No",
    });
    // String jsonInvoiceData = jsonEncode({'data': invoiceData, 'type': 'posInvoice'});
    debugPrint('posInvoice2');
    await sendataToServer(jsonDecode(invoiceJson));
    debugPrint('posInvoice3 $invoiceJson');

    // Step 4: Log the invoice data only if it hasn't been logged before
    if (!_loggedInvoices.contains(uniqueIdentifier)) {
      _loggedInvoices.add(uniqueIdentifier);
      developer.log('Invoice Data:', name: 'InvoiceLog');
      developer.log(invoiceData.toString(), name: 'InvoiceLog');
    }

    // Step 5: Save the invoice to Hive only if it doesn't already exist
    var box = await Hive.openBox('invoices');
    bool exists = box.values.any(
      (invoice) =>
          invoice is Map<String, dynamic> && invoice[' '] == uniqueIdentifier,
    );

    if (!exists) {
      await box.add(invoiceData);
      developer.log('Invoice saved to Hive:', name: 'InvoiceLog');
    }
    try {
      var response = await _invoiceService.postInvoiceToFastAPI(invoiceData);
      if (response.statusCode == 201) {
        // When the invoice is finished (inside saveInvoiceToHiveAndPrint1)
        final stateProvider = Provider.of<SalesInvoiceState>(
          context,
          listen: false,
        );
        stateProvider
            .reset(); // <-- automatically clears isUpiPaid / isCardPaid

        final qrProvider = Provider.of<RazorpayQRProvider>(
          context,
          listen: false,
        );
        qrProvider.disconnectWebSocket();
        qrProvider.isCardPaid = false;
        qrProvider.errorMessage = null;
        print("ok1233");
        // Send SMS
        String customerNumber = _customerNumberController.text;
        // Extract only the phone number from customerNumber (e.g., "6985748963 - test" -> "6985748963")
        String phoneNumber = customerNumber
            .split(' - ')[0]
            .trim(); // Get the part before " - "
        if (RegExp(r'^\d{10}$').hasMatch(phoneNumber)) {
          // Validate it's a 10-digit number
          String totalAmount = totalItemTotal.toStringAsFixed(
            0,
          ); // Use discounted total
          String billNumber = invoiceData['invoiceNo'];

          // Send SMS
          if (isSMSEnabled) {
            String smsApiUrl =
                'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK&senderid=BMUMMY&templateid=1707167058380400950&number=$phoneNumber&message=WELCOME TO BESTMUMMY BILL NO:$billNumber BILL AMOUNT: $totalAmount VISIT OUR 45 THANK YOU FOR VISITING AGAIN';

            var smsResponse = await http.get(Uri.parse(smsApiUrl));
            if (smsResponse.statusCode == 200) {
              print('SMS sent successfully to $phoneNumber');
            } else {
              print('Failed to send SMS: ${smsResponse.body}');
            }
          }

          // Send WhatsApp message
          if (isWhatsAppEnabled) {
            await sendBillToCustomer(newInvoiceNumber, invoiceData);
            // String whatsappApiUrl =
            //     'https://backend.askeva.io/v1/message/send-message?token=226b3bc6338f9de4107cc93016924fb2868113776165b8d4b9a76914930e2fa2e47ff2906d87e0281121e425dccf62d84a6a82303c99beb2c24d0f9da7a46c1e32af25b2e74b7e42a7d17ce834c474aeb9b4abecdf454ade5fcd7519b8dd2e3893e0ac008bf50aa0d2ddc59737e381d4166d7d1e45af5cb285d388959efdc897c43af27799a56ea571830eca7cb8d5f08cf4284b28dff365fb85a2ad9d645ee0aaf8a86e8d6103150f29361e0f4556ba02cbf0149bacd06ad35fbe51d0ba630533cf73a51476c02eccc3845d13506638';

            // Map<String, dynamic> whatsappMessage = {
            //   "to": "91$phoneNumber", // Use the extracted phone number with country code
            //   "type": "template",
            //   "template": {
            //     "language": {"policy": "deterministic", "code": "en"},
            //     "name": "whatsapp_test",
            //     "components": [
            //       {
            //         "type": "header",
            //         "parameters": [
            //           {
            //             "type": "image",
            //             "image": {"link": "https://yenerp.com/share/offer.jpg"},
            //           },
            //         ],
            //       },
            //       {
            //         "type": "body",
            //         "parameters": [
            //           {"type": "text", "text": "Customer"},
            //           {"type": "text", "text": "Bill No: $billNumber"},
            //           {"type": "text", "text": "Amount: $totalAmount"},
            //         ],
            //       },
            //     ],
            //   },
            // };

            // var whatsappResponse = await http.post(
            //   Uri.parse(whatsappApiUrl),
            //   headers: {"Content-Type": "application/json"},
            //   body: json.encode(whatsappMessage),
            // );

            // if (whatsappResponse.statusCode == 200) {
            //   print('WhatsApp message sent successfully to $phoneNumber');
            // } else {
            //   print('Failed to send WhatsApp message: ${whatsappResponse.body}');
            // }
          }
        } else {
          print('Invalid phone number format: $phoneNumber');
        }
      } else {
        print('Failed to post invoice: ${response.statusCode}');
      }
    } catch (e) {
      print('Error posting invoice or sending message: $e');
    }
    print("web123");

    Navigator.of(context).pop();
    print("out");
    cartProvider.clearItems();
    print("web done");
  }

  void _applyDiscount(String discount) {
    final saleProvider = Provider.of<CurrentSaleProvider>(
      context,
      listen: false,
    );
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    double discountValue = double.tryParse(discount) ?? 0.0;
    saleProvider.discountPercentage = discountValue;
    saleProvider.calculateTotal();
    stateProvider.updateBalanceAmount(getTotalWithAdjustments());
    _updateBalance();
  }

  double getTotalWithAdjustments() {
    double discountValue =
        (double.tryParse(_discountController.text) ?? 0.0) / 100;
    double totalCharges =
        (double.tryParse(_customChargeController.text) ?? 0.0);
    return (widget.totalAmount * (1 - discountValue)) + totalCharges;
  }

  double getRemainingForMethod(String method) {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    double total = getTotalWithAdjustments();
    double otherPayments = 0.0;
    if (method != 'Cash') otherPayments += stateProvider.cashAmount;
    if (method != 'Upi') otherPayments += stateProvider.upiAmount;
    if (method != 'Card') otherPayments += stateProvider.cardAmount;
    return total - otherPayments;
  }

  void _updateBalance() {
    final saleProvider = Provider.of<CurrentSaleProvider>(
      context,
      listen: false,
    );
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );

    double totalPayments =
        stateProvider.cashAmount +
        stateProvider.cardAmount +
        stateProvider.upiAmount;

    double totalWithDiscount = getTotalWithAdjustments();

    // <-- Use the *raw* double for internal math
    stateProvider.updateBalanceAmount(totalWithDiscount - totalPayments);

    // <-- Cash-options are generated from the *rounded* balance
    cashOptions.clear();
    cashOptions.addAll(
      _generateCashOptions(
        stateProvider.roundedBalance > 0
            ? stateProvider.roundedBalance.toDouble()
            : totalWithDiscount,
      ),
    );

    validateForm(); // <-- now uses rounded value
  }

  // void _updateBalance() {
  //   final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
  //   final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
  //   double totalPayments = stateProvider.cashAmount + stateProvider.cardAmount + stateProvider.upiAmount;
  //   double totalWithDiscount = getTotalWithAdjustments();

  //   stateProvider.updateBalanceAmount(totalWithDiscount - totalPayments);
  //   cashOptions.clear();
  //   cashOptions.addAll(_generateCashOptions(stateProvider.balanceAmount > 0 ? stateProvider.balanceAmount : totalWithDiscount));
  //   validateForm();
  // }

  List<String> _generateCashOptions(double amount) {
    List<String> options = [];
    int exactAmount = amount.ceil();

    options.add(exactAmount.toString());

    List<int> denominations = [1, 2, 5, 10, 20, 50, 100, 200, 500];

    int roundUpTo(int base, int denomination) {
      return ((base + denomination - 1) ~/ denomination) * denomination;
    }

    for (int denom in denominations) {
      int next = roundUpTo(exactAmount, denom);
      if (next > exactAmount) {
        options.add(next.toString());
      }
    }

    options = options.toSet().toList();
    options.sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    return options;
  }

  void _selectPaymentOption(String method, String amount) {
    double selectedAmount = double.tryParse(amount) ?? 0.0;
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );

    stateProvider.updateMultiple(
      selectedPaymentOption: '$method: ${selectedAmount.toStringAsFixed(0)}',
      selectedPaymentOptionValue: method,
    );

    switch (method) {
      case "Cash":
        stateProvider.updateCashAmount(selectedAmount);
        _customCashController.text = selectedAmount.toStringAsFixed(0);
        break;
      case "Upi":
        stateProvider.updateUpiAmount(selectedAmount);
        _customUpiController.text = selectedAmount.toStringAsFixed(0);
        break;
      case "Card":
        stateProvider.updateCardAmount(selectedAmount);
        _customCardController.text = selectedAmount.toStringAsFixed(0);
        break;
    }

    _updateBalance();
  }

  void _showUpiQrDialog(double amount) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RazorpayQRProvider>(context, listen: false).createQR(amount);
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.qr_code, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'UPI QR Code',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            height: 600,
            width: 285,
            child: Consumer2<RazorpayQRProvider, SalesInvoiceState>(
              builder: (context, qrProvider, stateProvider, _) {
                if (qrProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (qrProvider.errorMessage != null) {
                  // Send error message to client
                  _sendState(
                    type: 'upi_payment_error',
                    extraData: {'message': qrProvider.errorMessage},
                  );
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        qrProvider.errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.red,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text("Close"),
                        onPressed: () {
                          qrProvider.disconnectWebSocket();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            6,
                            62,
                            247,
                          ),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                    ],
                  );
                } else if (qrProvider.paymentSuccess) {
                  Provider.of<SalesInvoiceState>(
                    context,
                    listen: false,
                  ).updateIsUpiPaid(true);

                  // ← NEW: Show paid amount in the UPI field
                  _customUpiController.text = stateProvider.upiAmount
                      .toStringAsFixed(0);
                  _sendState(type: 'upi_payment_success');
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/Payment Successful.json',
                        repeat: false,
                        height: 500,
                        //height: double.infinity,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        onLoaded: (composition) {
                          Future.delayed(
                            composition.duration + const Duration(seconds: 2),
                            () {
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                          );
                        },
                      ),
                      const Text(
                        'UPI Payment Successful!',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                } else if (qrProvider.qrImageUrl != null) {
                  _sendState(
                    type: 'show_upi_qr',
                    extraData: {
                      'qrUrl': qrProvider.qrImageUrl,
                      'amount': amount,
                    },
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(
                        qrProvider.qrImageUrl!,
                        height: 535,
                        //height: double.infinity,
                        width: double.infinity,
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) {
                          _sendState(
                            type: 'upi_payment_error',
                            extraData: {'message': 'Failed to load QR code'},
                          );
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.red, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load QR code',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text("Close"),
                              onPressed: () {
                                qrProvider.disconnectWebSocket();
                                Navigator.pop(context);
                                _sendState(type: 'upi_payment_cancelled');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  6,
                                  62,
                                  247,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  _sendState(
                    type: 'upi_payment_error',
                    extraData: {'message': 'No QR code generated'},
                  );
                  return const Center(child: Text('No QR generated'));
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption(String amount, String method) {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
    bool isSelected = stateProvider.selectedPaymentOption == '$method: $amount';
    TextEditingController controller;

    switch (method) {
      case 'Cash':
        controller = _customCashController;
        break;
      case 'Upi':
        controller = _customUpiController;
        break;
      case 'Card':
        controller = _customCardController;
        break;
      default:
        controller = _customAmountController;
    }

    if (amount == 'Custom') {
      return Padding(
        padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
        child: SizedBox(
          width: 130,
          height: 50,
          child: Material(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    showCursor: true,
                    readOnly: true,
                    enabled: method == 'Upi'
                        ? !stateProvider.isUpiPaid
                        : !qrProvider.isCardPaid,
                    controller: controller,
                    focusNode: _getFocusNodeForController(controller),
                    keyboardType: TextInputType.none,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue, width: 1),
                      ),
                      border: const OutlineInputBorder(),
                      filled: isSelected,
                      hintText: "Enter $method",
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      _selectPaymentOption(method, value);
                    },
                    onTap: () {
                      setCurrentFocusForController(controller);
                    },
                  ),
                ),
                if (method == 'Upi' || method == 'Card')
                  Consumer<RazorpayQRProvider>(
                    builder: (context, qrProvider, _) {
                      return IconButton(
                        icon: Icon(
                          method == 'Upi' ? Icons.qr_code : Icons.credit_card,
                          color: method == 'Upi' ? Colors.black : Colors.blue,
                          size: 24,
                        ),
                        onPressed:
                            isPaymentEnabled &&
                                (method == 'Upi'
                                    ? !stateProvider.isUpiPaid
                                    : !qrProvider.isCardPaid) &&
                                (method == 'Upi'
                                    ? stateProvider.balanceAmount > 0
                                    : stateProvider.balanceAmount > 0)
                            ? () {
                                final amountStr = controller.text;
                                if (amountStr.isNotEmpty) {
                                  final amount = double.tryParse(amountStr);
                                  if (amount != null && amount > 0) {
                                    if (method == 'Upi') {
                                      _showUpiQrDialog(amount);
                                    } else {
                                      _handleCardPayment();
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Please enter a valid $method amount greater than 0.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Please enter a $method amount first.',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }
                            : null,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () {
            _selectPaymentOption(method, amount);
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: Center(
              child: Text(
                amount,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: isSelected ? Colors.white : Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  // Widget _buildPaymentOption(String amount, String method) {
  //   return Consumer2<SalesInvoiceState, RazorpayQRProvider>(
  //     builder: (context, stateProvider, qrProvider, _) {
  //       final bool isSelected = stateProvider.selectedPaymentOption == '$method: $amount';

  //       // ---------- CONTROLLERS ----------
  //       final TextEditingController controller;
  //       final bool isCash = method == 'Cash';
  //       final bool isUpi = method == 'Upi';
  //       final bool isCard = method == 'Card';

  //       if (isCash)
  //         controller = _customCashController;
  //       else if (isUpi)
  //         controller = _customUpiController;
  //       else if (isCard)
  //         controller = _customCardController;
  //       else
  //         controller = _customAmountController;

  //       // ---------- ENABLE LOGIC ----------
  //       // Only UPI & Card have "paid" flags
  //       final bool methodIsPaid = isUpi
  //           ? stateProvider.isUpiPaid
  //           : isCard
  //           ? qrProvider.isCardPaid
  //           : false; // Cash never "paid"

  //       final bool canPressIcon = isPaymentEnabled && !methodIsPaid && stateProvider.balanceAmount > 0;

  //       final bool fieldEnabled = !methodIsPaid; // Cash always true

  //       // ---------- LOCK PAID FIELDS ----------
  //       // Once paid, ignore onChanged and keep readOnly
  //       ValueChanged<String>? onChangedCallback;
  //       if (fieldEnabled) {
  //         onChangedCallback = (String v) => _selectPaymentOption(method, v);
  //       } // else null → no changes allowed

  //       // --------------------------------------------------------------
  //       // 2. CUSTOM AMOUNT (TextField + Icon)
  //       // --------------------------------------------------------------
  //       if (amount == 'Custom') {
  //         return Padding(
  //           padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
  //           child: SizedBox(
  //             width: 130,
  //             height: 50,
  //             child: Material(
  //               color: Colors.grey.withOpacity(0.1),
  //               borderRadius: BorderRadius.circular(8),
  //               child: Row(
  //                 children: [
  //                   // ----- TEXT FIELD -----
  //                   Expanded(
  //                     child: TextField(
  //                       showCursor: true,
  //                       readOnly: true, // custom keyboard
  //                       enabled: fieldEnabled, // visual disable
  //                       controller: controller,
  //                       focusNode: _getFocusNodeForController(controller),
  //                       keyboardType: TextInputType.none,
  //                       onChanged: onChangedCallback, // ← null when paid
  //                       onTap: fieldEnabled ? () => setCurrentFocusForController(controller) : null,
  //                       decoration: InputDecoration(
  //                         enabledBorder: OutlineInputBorder(
  //                           borderSide: const BorderSide(color: Colors.white, width: 1.5),
  //                           borderRadius: BorderRadius.circular(8),
  //                         ),
  //                         focusedBorder: OutlineInputBorder(
  //                           borderRadius: BorderRadius.circular(8),
  //                           borderSide: const BorderSide(color: Colors.blue, width: 1),
  //                         ),
  //                         border: const OutlineInputBorder(),
  //                         filled: isSelected,
  //                         hintText: fieldEnabled ? "Enter $method" : "Paid",
  //                         fillColor: fieldEnabled ? Colors.white : Colors.grey.shade200,
  //                       ),
  //                     ),
  //                   ),

  //                   // ----- ICON BUTTON (UPI / CARD ONLY) -----
  //                   if (isUpi || isCard)
  //                     IconButton(
  //                       icon: Icon(
  //                         isUpi ? Icons.qr_code : Icons.credit_card,
  //                         color: isUpi ? Colors.black : Colors.blue,
  //                         size: 24,
  //                       ),
  //                       onPressed: canPressIcon
  //                           ? () {
  //                               final String txt = controller.text;
  //                               if (txt.isEmpty) {
  //                                 ScaffoldMessenger.of(context).showSnackBar(
  //                                   const SnackBar(
  //                                     content: Text('Please enter an amount first.'),
  //                                     backgroundColor: Colors.orange,
  //                                   ),
  //                                 );
  //                                 return;
  //                               }
  //                               final double? amt = double.tryParse(txt);
  //                               if (amt == null || amt <= 0) {
  //                                 ScaffoldMessenger.of(context).showSnackBar(
  //                                   SnackBar(
  //                                     content: Text('Please enter a valid $method amount > 0.'),
  //                                     backgroundColor: Colors.red,
  //                                   ),
  //                                 );
  //                                 return;
  //                               }

  //                               if (isUpi) {
  //                                 _showUpiQrDialog(amt);
  //                               } else {
  //                                 _handleCardPayment();
  //                               }
  //                             }
  //                           : null,
  //                     ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         );
  //       }

  //       // --------------------------------------------------------------
  //       // 3. NON-CUSTOM OPTIONS
  //       // --------------------------------------------------------------
  //       return Padding(
  //         padding: const EdgeInsets.all(8),
  //         child: GestureDetector(
  //           onTap: fieldEnabled ? () => _selectPaymentOption(method, amount) : null,
  //           child: Container(
  //             height: 40,
  //             padding: const EdgeInsets.symmetric(horizontal: 12),
  //             decoration: BoxDecoration(
  //               color: isSelected ? Colors.blue : Colors.white,
  //               borderRadius: BorderRadius.circular(6),
  //               border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300, width: 1.5),
  //               boxShadow: [
  //                 if (isSelected) BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
  //               ],
  //             ),
  //             child: Center(
  //               child: Text(
  //                 amount,
  //                 style: TextStyle(fontSize: 14, color: isSelected ? Colors.white : Colors.blue, fontWeight: FontWeight.w500),
  //               ),
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildPaymentSection(String method) {
    double remaining = getRemainingForMethod(method);
    String exactStr = remaining.toStringAsFixed(0);
    List<String> extraOptions = [];

    if (method == 'Cash') {
      final stateProvider = Provider.of<SalesInvoiceState>(
        context,
        listen: false,
      );
      double amountForOptions = stateProvider.balanceAmount > 0
          ? stateProvider.balanceAmount
          : getTotalWithAdjustments();
      extraOptions = _generateCashOptions(amountForOptions).skip(1).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CustomText(
              text: method,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const CustomSizedBox(width: 20),
            _buildPaymentOption('Custom', method),
            _buildPaymentOption(exactStr, method),
          ],
        ),
        if (extraOptions.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                for (var option in extraOptions)
                  _buildPaymentOption(option, method),
              ],
            ),
          ),
      ],
    );
  }

  FocusNode _getFocusNodeForController(TextEditingController controller) {
    int index = _keyboardControllers.indexOf(controller);
    return index >= 0 ? _focusNodes[index] : FocusNode();
  }

  void setCurrentFocusForController(TextEditingController controller) {
    int index = _keyboardControllers.indexOf(controller);
    if (index >= 0) {
      _currentFocusIndexNotifier.value = index;
      _focusNodes[index].requestFocus();
      if (controller == _birthdayController) {
        _openDatePicker();
      }
    }
  }

  void _moveToNextField(int currentIndex) {
    int nextIndex = currentIndex + 1;
    if (nextIndex == 2 && currentIndex == 0) {
      nextIndex = 3;
    }
    if (nextIndex < _keyboardControllers.length) {
      _currentFocusIndexNotifier.value = nextIndex;
      _focusNodes[nextIndex].requestFocus();
    }
  }

  void _handleKeyboardTextInput(String text) {
    final currentIndex = _currentFocusIndexNotifier.value;
    final currentController = _keyboardControllers[currentIndex];

    currentController.text = currentController.text + text;
    currentController.selection = TextSelection.fromPosition(
      TextPosition(offset: currentController.text.length),
    );

    if (currentController == _discountController) {
      if (currentController.text.isEmpty) {
        _applyDiscount('0');
      } else {
        _applyDiscount(currentController.text);
      }
    } else if (currentController == _customChargeController) {
      double charge = double.tryParse(currentController.text) ?? 0.0;
      Provider.of<CurrentSaleProvider>(context, listen: false).customCharge =
          charge;
      _updateBalance();
    } else if (currentController == _customCashController) {
      _selectPaymentOption('Cash', currentController.text);
    } else if (currentController == _customUpiController) {
      _selectPaymentOption('Upi', currentController.text);
    } else if (currentController == _customCardController) {
      _selectPaymentOption('Card', currentController.text);
    } else {
      validateForm();
    }
  }

  void _handleKeyboardBackspace() {
    final currentIndex = _currentFocusIndexNotifier.value;
    final currentController = _keyboardControllers[currentIndex];

    if (currentController.text.isNotEmpty) {
      currentController.text = currentController.text.substring(
        0,
        currentController.text.length - 1,
      );
      currentController.selection = TextSelection.fromPosition(
        TextPosition(offset: currentController.text.length),
      );
    }

    if (currentController == _discountController) {
      if (currentController.text.isEmpty) {
        _applyDiscount('0');
      } else {
        _applyDiscount(currentController.text);
      }
    } else if (currentController == _customChargeController) {
      double charge = double.tryParse(currentController.text) ?? 0.0;
      Provider.of<CurrentSaleProvider>(context, listen: false).customCharge =
          charge;
      _updateBalance();
    } else if (currentController == _customCashController) {
      _selectPaymentOption('Cash', currentController.text);
    } else if (currentController == _customUpiController) {
      _selectPaymentOption('Upi', currentController.text);
    } else if (currentController == _customCardController) {
      _selectPaymentOption('Card', currentController.text);
    } else {
      validateForm();
    }
  }

  void _handleKeyboardOk() {
    final currentIndex = _currentFocusIndexNotifier.value;
    _moveToNextField(currentIndex);
  }

  bool _isSubmitting = false;

  void _printReceiptDetails() async {
    if (_isSubmitting) {
      developer.log(
        'Print button already in progress, skipping',
        name: 'SalesInvoice',
      );
      return;
    }
    _isSubmitting = true;
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    stateProvider.employee.clear();
    var invoiceNumberGenerator = InvoiceNumberGenerator();
    String newInvoiceNumber = await invoiceNumberGenerator
        .generateInvoiceNumber();
    saveInvoiceToHiveAndPrint1(newInvoiceNumber);

    try {
      developer.log('Starting print receipt process', name: 'SalesInvoice');
      if (isPrintEnabled) {
        final stateProvider = Provider.of<SalesInvoiceState>(
          context,
          listen: false,
        );
        ReceiptPrinter printer = ReceiptPrinter(
          employeeNumberController: stateProvider.selectedEmployeeFirstName
              .toString(),
          customerNumberController: _customerNumberController,
          discountController: _discountController,
          customChargeController: _customChargeController,
          selectedPaymentOptionValue: stateProvider.selectedPaymentOptionValue,
          totalAmount: widget.totalAmount,
          context: context,
          newInvoiceNumber: newInvoiceNumber,
          selectedPaymentOption: stateProvider.selectedPaymentOption,
          //saveInvoiceToHiveAndPrint: saveInvoiceToHiveAndPrint1,
          discountAmount: stateProvider.roundedDiscountAmount,
          invoiceNo: stateProvider.invoiceNumber,
          cashAmount: stateProvider.cashAmount,
          cardAmount: stateProvider.cardAmount,
          upiAmount: stateProvider.upiAmount,
        );

        await printer.printReceiptDetails();
        developer.log(
          'Print receipt completed successfully',
          name: 'SalesInvoice',
        );
        if (mounted) {
          _isSubmitting = false;
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in printReceiptDetails: $e',
        name: 'SalesInvoice',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _isSubmitting = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('entered1');
    // final saleProvider = Provider.of<CurrentSaleProvider>(context);
    // final stateProvider = Provider.of<SalesInvoiceState>(context);
    // final qrProvider = Provider.of<RazorpayQRProvider>(context);
    // return WillPopScope(
    //   onWillPop: () async {
    //     saleProvider.discountPercentage = 0.0;
    //     saleProvider.customCharge = 0.0;
    //     saleProvider.calculateTotal();
    //     stateProvider.reset(); // Add a reset method to SalesInvoiceState
    //     qrProvider.disconnectWebSocket(); // Disconnect any active WebSocket
    //     qrProvider.isCardPaid = false; // Reset card payment state
    //     qrProvider.errorMessage = null; // Clear errors
    //     return true;
    //   },
    //   child:
    return Scaffold(
      backgroundColor: Colors.white,
      body: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomText(
                  text: 'Payment Details',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const CustomSizedBox(height: 20),

                /// Sales Person + Birthday Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Consumer<SalesInvoiceState>(
                      builder: (context, p, _) {
                        return Expanded(
                          flex: 2,
                          child: Material(
                            elevation: 4,
                            shadowColor: Colors.black,
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                // ------------------- AUTOCOMPLETE WITH QR -------------------
                                Autocomplete<String>(
                                  optionsMaxHeight: 120,
                                  optionsViewBuilder:
                                      (context, onSelected, options) {
                                        return Material(
                                          color: Colors.white,
                                          shadowColor: Colors.black,
                                          elevation: 4,
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(8),
                                            bottomRight: Radius.circular(8),
                                          ),
                                          child: ListView.separated(
                                            separatorBuilder:
                                                (context, index) =>
                                                    const Divider(
                                                      thickness: 1,
                                                      color: Colors.black12,
                                                    ),
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (context, index) {
                                              final option = options.elementAt(
                                                index,
                                              );
                                              return ListTile(
                                                title: Text(option),
                                                onTap: () => onSelected(option),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return const Iterable<String>.empty();
                                    }
                                    final query = textEditingValue.text
                                        .toLowerCase();
                                    return _allEmployees.keys.where(
                                      (key) =>
                                          key.toLowerCase().contains(query),
                                    );
                                  },
                                  onSelected: (String selection) =>
                                      _selectEmployee(selection),
                                  fieldViewBuilder:
                                      (
                                        context,
                                        controllers,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        controllers.value = prov.employee.value;
                                        return TextFormField(
                                          readOnly: true,
                                          showCursor: true,
                                          controller: prov.employee,
                                          focusNode: focusNode,
                                          onTap: () =>
                                              setCurrentFocusForController(
                                                prov.employee,
                                              ),
                                          decoration: InputDecoration(
                                            labelText: "Sales Person",
                                            labelStyle: const TextStyle(
                                              fontFamily: 'Poppins',
                                              color: Colors.black54,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Colors.blue,
                                                width: 1,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Colors.black12,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 15,
                                                  horizontal: 10,
                                                ),
                                            // QR ICON
                                            suffixIcon: IconButton(
                                              icon: const Icon(
                                                Icons.qr_code_scanner,
                                              ),
                                              onPressed: _toggleQrMode,
                                              tooltip: 'Scan Employee QR',
                                            ),
                                          ),
                                        );
                                      },
                                ),

                                // ------------------- HIDDEN QR FIELD (POS Hardware Scanner) -------------------
                                if (_isQrMode)
                                  Offstage(
                                    offstage: true,
                                    child: TextField(
                                      focusNode: _qrFocusNode,
                                      controller: _qrController,
                                      keyboardType: TextInputType.none,
                                      onSubmitted: _handleQrInput,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                      ),
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Material(
                        elevation: 4,
                        shadowColor: Colors.black,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: TextField(
                          showCursor: true,
                          controller: _birthdayController,
                          focusNode: _getFocusNodeForController(
                            _birthdayController,
                          ),
                          onTap: () =>
                              setCurrentFocusForController(_birthdayController),
                          readOnly: true,
                          keyboardType: TextInputType.none,
                          decoration: InputDecoration(
                            labelText: "Birthday Date",
                            labelStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.black54,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.black12,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Material(
                        elevation: 4,
                        shadowColor: Colors.black,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: TextField(
                          showCursor: true,
                          readOnly: true,
                          keyboardType: TextInputType.none,
                          controller: _customChargeController,
                          focusNode: _getFocusNodeForController(
                            _customChargeController,
                          ),
                          onTap: () => setCurrentFocusForController(
                            _customChargeController,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            prefixText: "₹",
                            labelText: "Custom Charge",
                            labelStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.black54,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.black12,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 10,
                            ),
                          ),
                          onChanged: (value) {
                            double charge = double.tryParse(value) ?? 0.0;
                            //saleProvider.customCharge = charge;
                            _updateBalance();
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// Customer + Discount + Custom Charge Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 300,
                      child: Material(
                        elevation: 4,
                        shadowColor: Colors.black,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: CustomerSearchDropdown(
                          customerNumberController: _customerNumberController,
                          focusNode: _getFocusNodeForController(
                            _customerNumberController,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Material(
                        elevation: 4,
                        shadowColor: Colors.black,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: TextField(
                          showCursor: true,
                          readOnly: true,
                          keyboardType: TextInputType.none,
                          controller: _discountController,
                          focusNode: _getFocusNodeForController(
                            _discountController,
                          ),
                          onTap: () =>
                              setCurrentFocusForController(_discountController),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.percent),
                            labelText: "Discount",
                            labelStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.black54,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.black12,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 10,
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isEmpty) {
                              _applyDiscount('0');
                            } else if (value.length > 2) {
                              _discountController.text = value.substring(0, 2);
                              _discountController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: _discountController.text.length,
                                    ),
                                  );
                              _applyDiscount(_discountController.text);
                            } else {
                              _applyDiscount(value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Material(
                        elevation: 4,
                        shadowColor: Colors.black,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: TextField(
                          showCursor: true,
                          readOnly: true,
                          keyboardType: TextInputType.none,
                          controller: _couponCodeController,
                          focusNode: _getFocusNodeForController(
                            _couponCodeController,
                          ),
                          onTap: () => setCurrentFocusForController(
                            _couponCodeController,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.local_offer_outlined),
                            labelText: "Coupon Code",
                            labelStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.black54,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.black12,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 10,
                            ),
                          ),
                          onChanged: (value) {
                            double charge = double.tryParse(value) ?? 0.0;
                            //saleProvider.customCharge = charge;
                            _updateBalance();
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const CustomSizedBox(height: 20),

                /// Payment Section + Numeric Keyboard
                Consumer<SalesInvoiceState>(
                  builder: (context, prov, _) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 10,
                                  bottom: 20,
                                ),
                                child: Material(
                                  elevation: 4,
                                  shadowColor: Colors.black,
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: _buildPaymentSection('Cash'),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 10,
                                  bottom: 20,
                                ),
                                child: Material(
                                  elevation: 4,
                                  shadowColor: Colors.black,
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: _buildPaymentSection('Upi'),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 10,
                                  bottom: 20,
                                ),
                                child: Material(
                                  elevation: 4,
                                  shadowColor: Colors.black,
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: _buildPaymentSection('Card'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 20, thickness: 1),
                        Expanded(
                          flex: 2,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _currentFocusIndexNotifier,
                            builder: (context, currentFocusIndex, _) {
                              return Column(
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 300,
                                    ),
                                    child: NumericKeyboard(
                                      focusNode: _focusNodes[currentFocusIndex],
                                      controller:
                                          _keyboardControllers[currentFocusIndex],
                                      onTextInput: _handleKeyboardTextInput,
                                      onBackspace: _handleKeyboardBackspace,
                                      onOk: _handleKeyboardOk,
                                      isLastField:
                                          currentFocusIndex ==
                                          _keyboardControllers.length - 1,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const CustomSizedBox(height: 10),

                /// Mini Cards + Print Button
                Consumer2<CurrentSaleProvider, SalesInvoiceState>(
                  builder: (context, salesProvider, statesProvider, _) {
                    final int roundedBal = statesProvider.roundedBalance;
                    return Row(
                      children: [
                        _buildMiniCard(
                          title: "Total",
                          value:
                              "₹${salesProvider.calculateTotal().toStringAsFixed(0)}",
                          gradient: [Colors.blue[200]!, Colors.blue[500]!],
                        ),
                        const SizedBox(width: 5),
                        // _buildMiniCard(
                        //   title: "Balance",
                        //   value: statesProvider.balanceAmount < 0
                        //       ? "-₹${statesProvider.balanceAmount.abs().toStringAsFixed(0)}"
                        //       : "₹${statesProvider.balanceAmount.toStringAsFixed(0)}",
                        //   gradient: [Colors.blue[200]!, Colors.blue[500]!],
                        // ),
                        _buildMiniCard(
                          title: "Balance",
                          value: roundedBal < 0
                              ? "-₹${roundedBal.abs()}"
                              : "₹$roundedBal",
                          gradient: [Colors.blue[200]!, Colors.blue[500]!],
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 75,
                          width: 300,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                statesProvider.isPrintButtonEnabled
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              foregroundColor: MaterialStateProperty.all(
                                Colors.white,
                              ),
                              padding: MaterialStateProperty.all(
                                const EdgeInsets.symmetric(
                                  horizontal: 30.0,
                                  vertical: 18.0,
                                ),
                              ),
                              shape:
                                  MaterialStateProperty.all<
                                    RoundedRectangleBorder
                                  >(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                              elevation: MaterialStateProperty.all(5.0),
                            ),
                            onPressed: statesProvider.isPrintButtonEnabled
                                ? _printReceiptDetails
                                : null,
                            child: const CustomText(
                              text: "Print Receipt",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const CustomSizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
      // ),
    );
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
                fontFamily: 'Poppins',
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
                fontFamily: 'Poppins',
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

class NumericKeyboard extends StatelessWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final Function(String)? onTextInput;
  final VoidCallback? onBackspace;
  final VoidCallback? onOk;
  final bool isLastField;

  const NumericKeyboard({
    super.key,
    required this.focusNode,
    required this.controller,
    this.onTextInput,
    this.onBackspace,
    this.onOk,
    this.isLastField = false,
  });

  void _textInputHandler(String text) {
    if (onTextInput != null) {
      onTextInput!(text);
    } else {
      final currentText = controller.text;
      final newText = currentText + text;
      controller.text = newText;
      controller.selection = TextSelection.collapsed(offset: newText.length);
    }
  }

  void _backspaceHandler() {
    if (onBackspace != null) {
      onBackspace!();
    } else {
      final currentText = controller.text;
      if (currentText.isNotEmpty) {
        final newText = currentText.substring(0, currentText.length - 1);
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: newText.length);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('7', () => _textInputHandler('7')),
            _buildKey('8', () => _textInputHandler('8')),
            _buildKey('9', () => _textInputHandler('9')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('4', () => _textInputHandler('4')),
            _buildKey('5', () => _textInputHandler('5')),
            _buildKey('6', () => _textInputHandler('6')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('1', () => _textInputHandler('1')),
            _buildKey('2', () => _textInputHandler('2')),
            _buildKey('3', () => _textInputHandler('3')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('0', () => _textInputHandler('0')),
            _buildKey('C', () {
              controller.clear();
              if (onTextInput != null)
                onTextInput!(''); // optional: notify parent
            }),
            _buildKey('⌫', _backspaceHandler),
          ],
        ),

        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_buildKey('OK', onOk ?? () {}, isAction: true, flex: 1)],
        ),
      ],
    );
  }

  Widget _buildKey(
    String label,
    VoidCallback onPressed, {
    int flex = 1,
    bool isAction = false,
    bool isEnabled = true,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isAction ? Colors.blue : Colors.white,
            foregroundColor: isAction ? Colors.white : Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            disabledBackgroundColor: Colors.grey[200],
            disabledForegroundColor: Colors.grey[400],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class CustomNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow only digits
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Check if all characters are digits
    if (!RegExp(r'^[0-9]+$').hasMatch(newValue.text)) {
      return oldValue;
    }

    // Limit to 10 digits
    if (newValue.text.length > 10) {
      return oldValue;
    }

    // Validate Indian mobile number format only when 10 digits are entered
    if (newValue.text.length == 10) {
      if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(newValue.text)) {
        // If 10 digits but doesn't start with 6-9, keep the old value
        return oldValue;
      }
    }

    return newValue;
  }
}

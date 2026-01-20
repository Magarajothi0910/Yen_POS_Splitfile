import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:yenpos/Global/Provider/bottomNavprovider.dart';
import 'package:yenpos/Global/Screen/camera_qr_screen.dart';
import 'package:yenpos/Global/pos_detector.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/customer_search.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/invoiceNumberGenerator.dart';
import 'package:yenpos/kotpreinvoice/providers/cartprovider.dart';
import 'package:yenpos/kotpreinvoice/providers/timerProvider.dart';
import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
import 'package:yenpos/regular_mode_page/widget/emp_search.dart';
import '../providers/razorpay_qr_provider.dart';
import '../providers/upi_provider.dart';
import 'package:web_socket_channel/io.dart';
import '../components/globalAppbar.dart';
import '../models/fetchDiningTax.dart';
import 'package:yenpos/Global/globals_data.dart';
import '../../kotpreinvoice/providers/bottomNavprovider.dart';
import '../providers/login_provider.dart';
import '../providers/order_provider.dart';
import '../providers/printer_provider.dart';
import '../screens/table_screen.dart';
import '../services/invoiceReceipt.dart';
import '../services/invoiceReceipt%20utility.dart';
import 'bottomNav.dart';

// 🔔 ChangeNotifier to manage SalesInvoicePayAndPrint state (Updated for multiple payments)
class SalesInvoicePayAndPrintState extends ChangeNotifier {
  double _balanceAmount = 0.0;
  bool _isSubmitting = false;

  // Individual payment amounts
  double _cashAmount = 0.0;
  double _upiAmount = 0.0;
  double _cardAmount = 0.0;

  String? _razorpayPaymentId;
  bool _isUpiPaid = false;
  bool _isCardPaid = false;

  double get balanceAmount => _balanceAmount;
  bool get isSubmitting => _isSubmitting;

  double get cashAmount => _cashAmount;
  double get upiAmount => _upiAmount;
  double get cardAmount => _cardAmount;

  String? get razorpayPaymentId => _razorpayPaymentId;
  bool get isUpiPaid => _isUpiPaid;
  bool get isCardPaid => _isCardPaid;

  void updatePayments({
    double? cash,
    double? upi,
    double? card,
    required double totalAmount,
  }) {
    if (cash != null) _cashAmount = cash;
    if (upi != null) _upiAmount = upi;
    if (card != null) _cardAmount = card;

    double totalPaid = _cashAmount + _upiAmount + _cardAmount;
    _balanceAmount = totalAmount - totalPaid;

    debugPrint(
      "💰 Updated payments: Cash=$_cashAmount, UPI=$_upiAmount, Card=$_cardAmount → Balance=$_balanceAmount",
    );
    notifyListeners();
  }

  void setRazorpayPaymentId(String? paymentId) {
    _razorpayPaymentId = paymentId;
    debugPrint("💳 Razorpay Payment ID: $_razorpayPaymentId");
    notifyListeners();
  }

  void resetPaymentState(double totalAmount) {
    _cashAmount = 0.0;
    _upiAmount = 0.0;
    _cardAmount = 0.0;
    _balanceAmount = totalAmount;
    _razorpayPaymentId = null;
    _isUpiPaid = false;
    _isCardPaid = false;
    debugPrint("🔄 Reset payment state: Balance=$_balanceAmount");
    notifyListeners();
  }

  void setSubmitting(bool value) {
    _isSubmitting = value;
    debugPrint("⏳ Submitting state: $_isSubmitting");
    notifyListeners();
  }

  void updateIsUpiPaid(bool value) {
    _isUpiPaid = value;
    notifyListeners();
  }

  void updateIsCardPaid(bool value) {
    _isCardPaid = value;
    notifyListeners();
  }
}

class SalesInvoicePayAndPrint extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>> items;
  final String branchName;
  final String deviceCode;
  const SalesInvoicePayAndPrint({
    Key? key,
    required this.totalAmount,
    required this.items,
    required this.branchName,
    required this.deviceCode,
  }) : super(key: key);

  @override
  State<SalesInvoicePayAndPrint> createState() =>
      _SalesInvoicePayAndPrintState();
}

class _SalesInvoicePayAndPrintState extends State<SalesInvoicePayAndPrint> {
  final TextEditingController _employeeNumberController =
      TextEditingController();
  final TextEditingController _customerNumberController =
      TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customChargeController = TextEditingController();
  final TextEditingController _customUpiController = TextEditingController();
  final TextEditingController _customCardController = TextEditingController();
  final TextEditingController _couponCodeController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _customCashController = TextEditingController();
  bool _isInitialSend = true;

  Map<String, Map<String, dynamic>> _allEmployees = {};
  final Razorpay _razorpay = Razorpay();
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "https://yenerp.com",
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
  IOWebSocketChannel? _channel;
  late SalesInvoicePayAndPrintState state;
  ScaffoldMessengerState? _scaffoldMessenger;
  Timer? _paymentStatusTimer;
  List<String> cashOptions = [];
  late List<FocusNode> _focusNodes;
  late ValueNotifier<int> _currentFocusIndexNotifier;
  late List<TextEditingController> _keyboardControllers;
  late Box ordersBox;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _customerNumberController.removeListener(_safeCustomerNumberLimiter);
    _customerNumberController.addListener(_safeCustomerNumberLimiter);
  }

  void _safeCustomerNumberLimiter() {
    final currentText = _customerNumberController.text;
    if (currentText.contains(' - ') &&
        currentText.split(' - ').length > 1 &&
        currentText.split(' - ')[1].trim().isNotEmpty) {
      return;
    }
    String digitsOnly = currentText.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(0, 10);
    }
    if (digitsOnly != currentText) {
      _customerNumberController.value = TextEditingValue(
        text: digitsOnly,
        selection: TextSelection.collapsed(offset: digitsOnly.length),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    state = SalesInvoicePayAndPrintState();

    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    // // ← ADD THIS LISTENER
    // // Listen to changes in mobileNoController and customerNameController
    // void updateCustomerDisplay() {
    //   final mobile = customerProvider.mobileNoController.text.trim();
    //   final name = customerProvider.customerNameController.text.trim();

    //   if (mobile.isNotEmpty && name.isNotEmpty) {
    //     _customerNumberController.text = "$mobile - $name";
    //   } else if (mobile.isNotEmpty) {
    //     _customerNumberController.text = mobile;
    //   } else {
    //     _customerNumberController.text = '';
    //   }
    // }

    // // Initial setup
    // updateCustomerDisplay();

    // Listen for future changes
    // customerProvider.mobileNoController.addListener(updateCustomerDisplay);
    // customerProvider.customerNameController.addListener(updateCustomerDisplay);
    final salesState = Provider.of<SalesInvoiceState>(context, listen: false);
    final employeeName = salesState.selectedEmployeeFirstName ?? "";
    _loadEmployees();
    state.resetPaymentState(widget.totalAmount);

    if (widget.items.isNotEmpty && widget.items.first.containsKey('waiter')) {
      _employeeNumberController.text = widget.items.first['waiter'] ?? '';
    }
    if (widget.items.isNotEmpty &&
        widget.items.first.containsKey('customerPhoneNumber')) {
      _customerNumberController.text =
          widget.items.first['customerPhoneNumber'] ?? '';
    }
    if (employeeName.isNotEmpty) {
      _employeeNumberController.text = employeeName ?? '';
    }

    _keyboardControllers = [
      // _employeeNumberController,
      _customerNumberController,
      _customCashController,
      _customUpiController,
      _customCardController,
      _discountController,
      _customChargeController,
      _couponCodeController,
      _birthdayController,
    ];
    _focusNodes = List.generate(
      _keyboardControllers.length,
      (_) => FocusNode(),
    );
    _currentFocusIndexNotifier = ValueNotifier<int>(0);

    // for (int i = 0; i < _focusNodes.length; i++) {
    //   _focusNodes[i].addListener(() {
    //     if (_focusNodes[i].hasFocus) {
    //       _currentFocusIndexNotifier.value = i;
    //     }
    //   });
    // }

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _initializeWebSocket();
    cashOptions.addAll(_generateCashOptions(widget.totalAmount));
  }

  Future<void> _initializeWebSocket() async {
    try {
      _channel = IOWebSocketChannel.connect('ws://$serverip:$port');
      debugPrint("📡 WebSocket connected to ws://$serverip:$port");
    } catch (e) {
      debugPrint("❌ Failed to connect to WebSocket: $e");
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Text('Failed to connect to server: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      sendataToServer(jsonDecode(jsonData));
      developer.log('Sent: $jsonData', name: 'WebSocket');
    } catch (e) {
      debugPrint('❌ Error sending data: $e');
    }
  }

  @override
  void dispose() {
    _employeeNumberController.dispose();
    _customerNumberController.dispose();
    _discountController.dispose();
    _customChargeController.dispose();
    _customUpiController.dispose();
    _customCardController.dispose();
    _couponCodeController.dispose();
    _birthdayController.dispose();
    _customCashController.dispose();
    _paymentStatusTimer?.cancel();
    _razorpay.clear();
    for (final node in _focusNodes) {
      node.dispose();
    }
    _currentFocusIndexNotifier.dispose();
    if (_channel != null) {
      _channel!.sink.close();
      debugPrint("🗑️ WebSocket channel closed");
    }
    state.dispose();
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    customerProvider.mobileNoController.removeListener(() {
      // You'll need to store the function reference or use a different approach
    });
    super.dispose();
  }

  String _getSuggestedAmount() {
    final cashAmount = double.tryParse(_customCashController.text) ?? 0.0;
    final upiAmount = double.tryParse(_customUpiController.text) ?? 0.0;
    final cardAmount = double.tryParse(_customCardController.text) ?? 0.0;
    final totalEntered = cashAmount + upiAmount + cardAmount;
    final remaining = widget.totalAmount - totalEntered;
    return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
  }

  void _showCustomSnackBar(String message, {bool isSuccess = false}) {
    if (mounted && _scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _loadEmployees() async {
    var box = await Hive.openBox('employeeBox');
    List<dynamic> employees = box.get('employees', defaultValue: []);
    _allEmployees = {
      for (var emp in employees)
        '${(emp as Map)["employeeNumber"]} - ${(emp as Map)["firstName"]}':
            (emp as Map).cast<String, dynamic>(),
    };
  }

  void _selectEmployee(String selection) {
    final employee = _allEmployees[selection];
    if (employee != null) {
      final stateProvider = Provider.of<SalesInvoiceState>(
        context,
        listen: false,
      );
      stateProvider.updateMultiple(
        selectedEmployeeFirstName: employee['firstName'],
        selectedEmployeeNumber: employee['employeeNumber'],
      );
      _employeeNumberController.text = selection;
    }
  }

  bool _isQrMode = false;
  final FocusNode _qrFocusNode = FocusNode();
  final TextEditingController _qrController = TextEditingController();
  bool _isProcessingQr = false;

  Future<void> _toggleQrMode() async {
    final isPOS = await POSDetector.isPOSDevice;
    if (isPOS) {
      _startHardwareScanner();
    } else {
      _startCameraScan();
    }
  }

  void _startHardwareScanner() {
    setState(() {
      _isQrMode = true;
      _qrFocusNode.requestFocus();
    });
  }

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
        _employeeNumberController.selection = TextSelection.fromPosition(
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

  // Payment validation and update logic
  double getRemainingForMethod(String method) {
    final totalAmount = widget.totalAmount;
    double otherPayments = 0.0;

    if (method != 'Cash') otherPayments += state.cashAmount;
    if (method != 'UPI') otherPayments += state.upiAmount;
    if (method != 'Card') otherPayments += state.cardAmount;

    return totalAmount - otherPayments;
  }

  void _selectPaymentOption(String method, String amountStr) {
    double enteredAmount = double.tryParse(amountStr) ?? 0.0;
    double currentCash = state.cashAmount;
    double currentUpi = state.upiAmount;
    double currentCard = state.cardAmount;

    if (enteredAmount == 0) {
      switch (method) {
        case "Cash":
          currentCash = 0.0;
          _customCashController.clear();
          break;
        case "UPI":
          currentUpi = 0.0;
          _customUpiController.clear();
          state.updateIsUpiPaid(false);
          break;
        case "Card":
          currentCard = 0.0;
          _customCardController.clear();
          state.updateIsCardPaid(false);
          break;
      }
    } else {
      if (method == "UPI" || method == "Card") {
        double remaining = getRemainingForMethod(method);
        if (enteredAmount > remaining + 0.01) {
          _showCustomSnackBar(
            "${method} payment cannot exceed ₹${remaining.toStringAsFixed(0)}",
            isSuccess: false,
          );
          enteredAmount = remaining;
        }
        if (enteredAmount < 0) {
          _showCustomSnackBar(
            "$method amount cannot be negative",
            isSuccess: false,
          );
          enteredAmount = 0.0;
        }
      }

      if (method == "Cash") {
        double remaining = getRemainingForMethod('Cash');
        if (enteredAmount > remaining + 5000) {
          _showCustomSnackBar(
            "Cash amount seems very high. Please double-check.",
            isSuccess: false,
          );
        }
        if (enteredAmount < 0) {
          _showCustomSnackBar(
            "Cash amount cannot be negative",
            isSuccess: false,
          );
          enteredAmount = 0.0;
        }
      }

      switch (method) {
        case "Cash":
          currentCash = enteredAmount;
          _customCashController.text = enteredAmount.toStringAsFixed(0);
          break;
        case "UPI":
          currentUpi = enteredAmount;
          _customUpiController.text = enteredAmount.toStringAsFixed(0);
          break;
        case "Card":
          currentCard = enteredAmount;
          _customCardController.text = enteredAmount.toStringAsFixed(0);
          break;
      }
    }

    state.updatePayments(
      cash: currentCash,
      upi: currentUpi,
      card: currentCard,
      totalAmount: widget.totalAmount,
    );

    double remainingBalance = state.balanceAmount > 0
        ? state.balanceAmount
        : 0.0;
    cashOptions.clear();
    cashOptions.addAll(_generateCashOptions(remainingBalance));
  }

  void _clearAllPayments({bool showSnackBar = true}) {
    _customCashController.clear();
    _customUpiController.clear();
    _customCardController.clear();
    state.resetPaymentState(widget.totalAmount);
    if (showSnackBar && mounted) {
      _showCustomSnackBar("Payments cleared", isSuccess: false);
    }
  }

  void _processControllerChange(TextEditingController controller) {
    if (controller == _customCashController) {
      _selectPaymentOption('Cash', controller.text);
    } else if (controller == _customUpiController) {
      _selectPaymentOption('UPI', controller.text);
    } else if (controller == _customCardController) {
      _selectPaymentOption('Card', controller.text);
    } else if (controller == _discountController ||
        controller == _customChargeController) {
      _clearAllPayments(showSnackBar: false);
    }
  }

  List<String> _generateCashOptions(double amount) {
    if (amount <= 0) return ['0'];
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

  void _handleKeyboardTextInput(String text) {
    final currentIndex = _currentFocusIndexNotifier.value;
    final currentController = _keyboardControllers[currentIndex];
    if (currentController.text == "0" || currentController.text.isEmpty) {
      currentController.text = text;
    } else {
      currentController.text = currentController.text + text;
    }
    currentController.selection = TextSelection.fromPosition(
      TextPosition(offset: currentController.text.length),
    );
    _processControllerChange(currentController);
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
    _processControllerChange(currentController);
  }

  void _handleKeyboardOk() {
    final currentIndex = _currentFocusIndexNotifier.value;
    if (currentIndex < _keyboardControllers.length - 1) {
      _currentFocusIndexNotifier.value = currentIndex + 1;
      _focusNodes[currentIndex + 1].requestFocus();
    }
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

  Future<void> _createOrderAndPay() async {
    final amount = double.tryParse(_customCardController.text);
    if (amount == null || amount <= 0) {
      debugPrint(
        "⚠️ Invalid card amount entered: ${_customCardController.text}",
      );
      if (mounted) {
        _showCustomSnackBar('Enter a valid card amount', isSuccess: false);
      }
      return;
    }
    debugPrint(
      "💳 Creating Razorpay order for ₹${amount.toStringAsFixed(2)}...",
    );
    try {
      state.setSubmitting(true);
      final response = await _dio.post(
        "/fastapi/razorPay/create_order/?price=$amount",
      );
      debugPrint("📦 Order Response: ${response.data}");
      final orderData = response.data;
      if (orderData == null || orderData['id'] == null) {
        debugPrint("⚠️ Invalid order response: $orderData");
        if (mounted) {
          _showCustomSnackBar(
            'Invalid order data from server',
            isSuccess: false,
          );
        }
        state.setSubmitting(false);
        return;
      }
      final razorpayAmount = (amount * 100).toInt();
      String customerNumber = _customerNumberController.text.trim();
      final options = {
        'key': 'rzp_live_RSsJoT9ThF9zms',
        'amount': razorpayAmount,
        'name': 'YenKOT Payments',
        'description': 'Card Payment for ₹${amount.toStringAsFixed(2)}',
        'order_id': orderData['id'],
        'prefill': {'contact': customerNumber, 'method': 'card'},
        'theme': {'color': '#2E86DE', 'backdrop_color': '#ffffff'},
      };
      debugPrint("🚀 Opening Razorpay with options: $options");
      try {
        _razorpay.open(options);
        debugPrint("✅ Razorpay window triggered successfully");
      } catch (e) {
        debugPrint("❌ Error opening Razorpay: $e");
        _showCustomSnackBar('Could not open payment window.', isSuccess: false);
        state.setSubmitting(false);
      }
    } on DioException catch (e) {
      debugPrint("💥 DioException while creating order: ${e.message}");
      if (mounted) {
        _showCustomSnackBar('Network issue creating order.', isSuccess: false);
      }
      state.setSubmitting(false);
    } catch (e, stack) {
      debugPrint("💥 Unexpected error creating order: $e");
      debugPrint("🧾 Stacktrace: $stack");
      if (mounted) {
        _showCustomSnackBar(
          'Unexpected error while creating order.',
          isSuccess: false,
        );
      }
      state.setSubmitting(false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    state.setSubmitting(true);
    final verifyData = {
      "order_id": response.orderId,
      "payment_id": response.paymentId,
      "signature": response.signature,
    };
    try {
      final result = await _dio.post(
        "https://yenerp.com/fastapi/razorPay/verify_payment",
        data: verifyData,
      );
      if (result.data["status"] == "success") {
        state.setRazorpayPaymentId(response.paymentId);
        state.updateIsCardPaid(true);
        if (mounted) {
          _showCustomSnackBar(
            'Amount received! Processing invoice...',
            isSuccess: true,
          );
          _processInvoiceAndPrint();
        }
        state.setSubmitting(false);
      } else {
        if (mounted) {
          _showCustomSnackBar('Payment verification failed', isSuccess: false);
          state.setSubmitting(false);
        }
      }
    } catch (e) {
      debugPrint("❌ Error verifying payment: $e");
      if (mounted) {
        _showCustomSnackBar('Error verifying payment: $e', isSuccess: false);
        state.setSubmitting(false);
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("❌ Payment failed: ${response.code} | ${response.message}");
    if (mounted) {
      _showCustomSnackBar(
        'Payment failed: ${response.message}',
        isSuccess: false,
      );
      state.setSubmitting(false);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("💳 External Wallet: ${response.walletName}");
    state.setSubmitting(false);
  }

  Widget _buildPaymentOption(String amount, String method) {
    return Consumer<SalesInvoicePayAndPrintState>(
      builder: (context, state, _) {
        TextEditingController controller;
        double currentAmount = 0.0;
        bool isPaid = false;

        switch (method) {
          case 'Cash':
            controller = _customCashController;
            currentAmount = state.cashAmount;
            break;
          case 'UPI':
            controller = _customUpiController;
            currentAmount = state.upiAmount;
            isPaid = state.isUpiPaid;
            break;
          case 'Card':
            controller = _customCardController;
            currentAmount = state.cardAmount;
            isPaid = state.isCardPaid;
            break;
          default:
            controller = TextEditingController();
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
                        readOnly: false,
                        enabled: !isPaid,
                        controller: controller,
                        focusNode: _getFocusNodeForController(controller),
                        keyboardType: TextInputType.none,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 1,
                            ),
                          ),
                          border: const OutlineInputBorder(),
                          hintText: isPaid ? "Paid" : "Enter $method",
                          fillColor: currentAmount > 0
                              ? Colors.blue.shade50
                              : Colors.white,
                          filled: true,
                        ),
                        onChanged: (value) {
                          if (!isPaid) {
                            _selectPaymentOption(
                              method,
                              value.isEmpty ? '0' : value,
                            );
                          }
                        },
                        onTap: () {
                          if (!isPaid) {
                            setCurrentFocusForController(controller);
                          }
                        },
                      ),
                    ),
                    if (method == 'UPI' || method == 'Card')
                      IconButton(
                        icon: Icon(
                          method == 'UPI' ? Icons.qr_code : Icons.credit_card,
                          color: isPaid
                              ? Colors.grey
                              : (method == 'UPI' ? Colors.black : Colors.blue),
                          size: 24,
                        ),
                        onPressed: !isPaid && isKOTPaymentEnabled
                            ? () {
                                final amountStr = controller.text;
                                if (amountStr.isNotEmpty) {
                                  final amount = double.tryParse(amountStr);
                                  if (amount != null && amount > 0) {
                                    if (method == 'UPI') {
                                      _showUpiQrDialog(amount);
                                    } else {
                                      _createOrderAndPay();
                                    }
                                  } else {
                                    _showCustomSnackBar(
                                      "Please enter a valid $method amount > 0",
                                      isSuccess: false,
                                    );
                                  }
                                } else {
                                  _showCustomSnackBar(
                                    "Please enter a $method amount first",
                                    isSuccess: false,
                                  );
                                }
                              }
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          );
        } else {
          final bool isThisAmountSelected =
              currentAmount == (double.tryParse(amount) ?? 0.0);

          return Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: isPaid ? null : () => _selectPaymentOption(method, amount),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.grey
                      : (isThisAmountSelected ? Colors.blue : Colors.white),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPaid
                        ? Colors.grey
                        : (isThisAmountSelected
                              ? Colors.blue
                              : Colors.grey.shade300),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    amount,
                    style: TextStyle(
                      fontSize: 14,
                      color: isPaid
                          ? Colors.white
                          : (isThisAmountSelected ? Colors.white : Colors.blue),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildPaymentSection(String method) {
    double remaining = getRemainingForMethod(method);
    String exactStr = remaining > 0 ? remaining.toStringAsFixed(0) : '0';
    List<String> extraOptions = [];
    if (method == 'Cash') {
      double amountForOptions = state.balanceAmount > 0
          ? state.balanceAmount
          : 0.0;
      extraOptions = _generateCashOptions(amountForOptions).skip(1).toList();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              method,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 20),
            _buildPaymentOption('Custom', method),
            _buildPaymentOption(exactStr, method),
          ],
        ),
        if (method == 'Cash' && extraOptions.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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

      if (controller == _customUpiController && controller.text.isEmpty) {
        double remaining = getRemainingForMethod('UPI');
        if (remaining > 0) {
          _selectPaymentOption('UPI', remaining.toStringAsFixed(0));
        }
      } else if (controller == _customCardController &&
          controller.text.isEmpty) {
        double remaining = getRemainingForMethod('Card');
        if (remaining > 0) {
          _selectPaymentOption('Card', remaining.toStringAsFixed(0));
        }
      }
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

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider(create: (_) => RazorpayProvider()),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Consumer<SalesInvoicePayAndPrintState>(
          builder: (context, state, _) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Consumer<SalesInvoicePayAndPrintState>(
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
                                    Autocomplete<String>(
                                      optionsMaxHeight: 120,
                                      optionsViewBuilder:
                                          (context, onSelected, options) {
                                            return Material(
                                              color: Colors.white,
                                              shadowColor: Colors.black,
                                              elevation: 4,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    bottomLeft: Radius.circular(
                                                      8,
                                                    ),
                                                    bottomRight:
                                                        Radius.circular(8),
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
                                                  final option = options
                                                      .elementAt(index);
                                                  return ListTile(
                                                    title: Text(option),
                                                    onTap: () =>
                                                        onSelected(option),
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
                                      onSelected: (String selection) => {
                                        _selectEmployee(selection),
                                        //p.setSelected(true),
                                      },
                                      fieldViewBuilder:
                                          (
                                            context,
                                            controllers,
                                            focusNode,
                                            onFieldSubmitted,
                                          ) {
                                            _employeeNumberController
                                                .addListener(() {
                                                  controllers.value =
                                                      _employeeNumberController
                                                          .value;
                                                });
                                            return AbsorbPointer(
                                              absorbing: createdBy.isNotEmpty,
                                              child: TextFormField(
                                                readOnly: true,
                                                showCursor: true,
                                                controller:
                                                    _employeeNumberController,
                                                focusNode: focusNode,
                                                onTap: () =>
                                                    setCurrentFocusForController(
                                                      _employeeNumberController,
                                                    ),
                                                decoration: InputDecoration(
                                                  labelText: "Sales person",
                                                  labelStyle: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: Colors.black54,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color:
                                                                  Colors.blue,
                                                              width: 1,
                                                            ),
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: Colors
                                                                  .black12,
                                                            ),
                                                      ),
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 15,
                                                        horizontal: 10,
                                                      ),
                                                  suffixIcon: IconButton(
                                                    icon: const Icon(
                                                      Icons.qr_code_scanner,
                                                    ),
                                                    onPressed: _toggleQrMode,
                                                    tooltip: 'Scan Employee QR',
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                    ),

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
                          child: AbsorbPointer(
                            absorbing: true,
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
                                onTap: () => setCurrentFocusForController(
                                  _birthdayController,
                                ),
                                readOnly: true,
                                keyboardType: TextInputType.none,
                                decoration: InputDecoration(
                                  labelText: "Birthday Date",
                                  labelStyle: const TextStyle(
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
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: true,
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
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    /// Customer + Discount + Coupon Row
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
                              showTopProducts: false,
                              customerNumberController:
                                  _customerNumberController,
                              focusNode: _getFocusNodeForController(
                                _customerNumberController,
                              ),
                              readOnly: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: true,
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
                                onTap: () => setCurrentFocusForController(
                                  _discountController,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.percent),
                                  labelText: "Discount",
                                  labelStyle: const TextStyle(
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
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: true,
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
                                  prefixIcon: const Icon(
                                    Icons.local_offer_outlined,
                                  ),
                                  labelText: "Coupon Code",
                                  labelStyle: const TextStyle(
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
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Payment Section
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 5,
                                  bottom: 10,
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
                                  left: 5,
                                  bottom: 10,
                                ),
                                child: Material(
                                  elevation: 4,
                                  shadowColor: Colors.black,
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: _buildPaymentSection('UPI'),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 5,
                                  bottom: 10,
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
                        const VerticalDivider(width: 15, thickness: 1),
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
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildMiniCard(
                          title: "Total",
                          value: "₹${widget.totalAmount.toStringAsFixed(0)}",
                          gradient: [Colors.blue[200]!, Colors.blue[500]!],
                        ),
                        const SizedBox(width: 5),
                        _buildMiniCard(
                          title: "Balance",
                          value: state.balanceAmount < 0
                              ? "-₹${state.balanceAmount.abs().toStringAsFixed(0)}"
                              : "₹${state.balanceAmount.toStringAsFixed(0)}",
                          gradient: [Colors.blue[200]!, Colors.blue[500]!],
                        ),
                        const SizedBox(width: 10),

                        // SizedBox(
                        //   height: 75,
                        //   width: 300,
                        //   child: ElevatedButton(
                        //     style: ButtonStyle(
                        //       backgroundColor: MaterialStateProperty.all(
                        //         state.balanceAmount <= 0 ? Colors.blue : Colors.grey,
                        //       ),
                        //       foregroundColor: MaterialStateProperty.all(Colors.white),
                        //       padding: MaterialStateProperty.all(
                        //         const EdgeInsets.symmetric(horizontal: 30.0, vertical: 18.0),
                        //       ),
                        //       shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        //         RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        //       ),
                        //       elevation: MaterialStateProperty.all(5.0),
                        //     ),
                        //     onPressed: (state.balanceAmount <= 0)
                        //         ? () async {
                        //             _processInvoiceAndPrint();
                        //           }
                        //         : null,
                        //     child: Text(
                        //       state.isSubmitting ? "Processing..." : "Proceed to payment",
                        //       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        //     ),
                        //   ),
                        // ),
                        // SizedBox(
                        //   height: 75,
                        //   width: 300,
                        //   child: Consumer<SalesInvoicePayAndPrintState>(
                        //     builder: (context, state, _) {
                        //       final String customerText =
                        //           _customerNumberController.text.trim();
                        //       final bool isCustomerFilled =
                        //           customerText.isNotEmpty;
                        //       final bool isFullyPaid = state.balanceAmount <= 0;
                        //       final bool canProceed =
                        //           isFullyPaid &&
                        //           isCustomerFilled &&
                        //           !state.isSubmitting;

                        //       print(
                        //         "_customerNumberController.text ${_customerNumberController.text}",
                        //       );
                        //       print("canProceed ${canProceed}");

                        //       return ElevatedButton(
                        //         style: ButtonStyle(
                        //           backgroundColor: MaterialStateProperty.all(
                        //             canProceed ? Colors.blue : Colors.grey,
                        //           ),
                        //           foregroundColor: MaterialStateProperty.all(
                        //             Colors.white,
                        //           ),
                        //           padding: MaterialStateProperty.all(
                        //             const EdgeInsets.symmetric(
                        //               horizontal: 30.0,
                        //               vertical: 18.0,
                        //             ),
                        //           ),
                        //           shape:
                        //               MaterialStateProperty.all<
                        //                 RoundedRectangleBorder
                        //               >(
                        //                 RoundedRectangleBorder(
                        //                   borderRadius: BorderRadius.circular(
                        //                     8.0,
                        //                   ),
                        //                 ),
                        //               ),
                        //           elevation: MaterialStateProperty.all(5.0),
                        //         ),
                        //         onPressed: canProceed
                        //             ? () async {
                        //                 _processInvoiceAndPrint();
                        //               }
                        //             : null,
                        //         child: Text(
                        //           state.isSubmitting
                        //               ? "Processing..."
                        //               : "Proceed to payment",
                        //           style: const TextStyle(
                        //             fontSize: 16,
                        //             fontWeight: FontWeight.bold,
                        //           ),
                        //         ),
                        //       );
                        //     },
                        //   ),
                        // ),
                        SizedBox(
                          height: 75,
                          width: 300,
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _customerNumberController,
                            builder: (context, customerValue, _) {
                              return Consumer<SalesInvoicePayAndPrintState>(
                                builder: (context, state, _) {
                                  final String customerText = customerValue.text
                                      .trim();
                                  final bool isCustomerFilled =
                                      customerText.length >= 10;
                                  final bool isFullyPaid =
                                      state.balanceAmount <= 0;
                                  final bool canProceed =
                                      isFullyPaid &&
                                      isCustomerFilled &&
                                      !state.isSubmitting;

                                  return ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor:
                                          MaterialStateProperty.all(
                                            canProceed
                                                ? Colors.blue
                                                : Colors.grey,
                                          ),
                                      foregroundColor:
                                          MaterialStateProperty.all(
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
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                            ),
                                          ),
                                      elevation: MaterialStateProperty.all(5.0),
                                    ),
                                    onPressed: canProceed
                                        ? () async {
                                            _processInvoiceAndPrint();
                                          }
                                        : null,
                                    child: Text(
                                      state.isSubmitting
                                          ? "Processing..."
                                          : "Proceed to payment",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<String> generatehiveInvoiceId(String branchName) async {
    final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final currentDate1 = DateFormat('ddMMyy').format(DateTime.now());
    var invoiceBox = await Hive.openBox('invoices');
    String lastInvoiceDate = invoiceBox.get(
      'lastInvoiceDate',
      defaultValue: "",
    );
    int invoiceCounter = invoiceBox.get('invoiceCounter', defaultValue: 0);
    if (lastInvoiceDate != currentDate || invoiceCounter == 0) {
      invoiceCounter = 1;
    } else {
      invoiceCounter++;
    }
    String hiveInvoiceId =
        'BM/$branchName $currentDate1 KOTINVOICE${invoiceCounter.toString().padLeft(3, '0')}';
    await invoiceBox.put('invoiceCounter', invoiceCounter);
    await invoiceBox.put('lastInvoiceDate', currentDate);
    return hiveInvoiceId;
  }

  void _sendInvoiceDataToServer() async {
    debugPrint("📦 Preparing and grouping invoice data for server...");
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final loggedInUserName = loginProvider.loggedInUserName ?? "";
    double diningTaxPercentage = getTaxPercentage();
    Map<String, Map<String, dynamic>> groupedItems = {};
    List<Map<String, dynamic>> kotAddOns = [];

    for (var item in widget.items) {
      if (item.isEmpty) continue;
      for (int i = 0; i < (item['varianceName']?.length ?? 0); i++) {
        String variance = item['varianceName']?[i] ?? "";
        if (!groupedItems.containsKey(variance)) {
          groupedItems[variance] = {
            "varianceName": variance,
            "varianceitemCode": item['varianceitemCode']?[i] ?? "",
            "itemName": item['itemName']?[i] ?? "",
            "price": item['price']?[i] ?? 0.0,
            "qty": 0.0,
            "weight": 0.0,
            "amount": 0.0,
            "tax": diningTaxPercentage,
            "uom": item['uom']?[i] ?? "",
          };
        }
        groupedItems[variance]!['qty'] += item['qty']?[i] ?? 0.0;
        groupedItems[variance]!['weight'] += item['weight']?[i] ?? 0.0;
        groupedItems[variance]!['amount'] += item['amount']?[i] ?? 0.0;

        if (item.containsKey('config') && item['config'] != null) {
          for (var configItem in item['config']) {
            String varianceName = configItem['varianceName'] ?? "";
            bool isAlreadyAdded = kotAddOns.any(
              (existingConfig) =>
                  existingConfig["varianceName"] == varianceName &&
                  existingConfig["configQty"].toString() ==
                      configItem["configQty"].toString(),
            );
            if (!isAlreadyAdded) {
              kotAddOns.add({
                "varianceName": varianceName,
                "weight": configItem['weight'] ?? 0,
                "configQty": List.from(configItem['configQty'] ?? []),
                "addOn": List.from(configItem['addOn'] ?? []),
                "addOnPrice": List.from(configItem['addOnPrice'] ?? []),
                "addOnQuantities": List.from(
                  configItem['addOnQuantities'] ?? [],
                ),
                "variance": List.from(configItem['variance'] ?? []),
                "type": List.from(configItem['type'] ?? []),
                "remark": List.from(configItem['remark'] ?? []),
              });
            }
          }
        }
      }
    }

    DateTime billDate = DateTime.now();
    //final invoiceNo = await generatehiveInvoiceId(widget.branchName);

    final beforeEmployeeNumber = _employeeNumberController.text.trim();
    final beforeEmployeeNumberValue = beforeEmployeeNumber.split(' - ');
    final employeeNumber = beforeEmployeeNumberValue.isNotEmpty
        ? beforeEmployeeNumberValue[0]
        : '';
    final employeeName = beforeEmployeeNumberValue.length > 1
        ? beforeEmployeeNumberValue[1]
        : '';

    final beforeCustomerNumber = _customerNumberController.text.trim();
    final beforeCustomerNumberValue = beforeCustomerNumber.split(' - ');
    final customerNumber = beforeCustomerNumberValue.isNotEmpty
        ? int.tryParse(beforeCustomerNumberValue[0])
        : '';
    final customerName = beforeCustomerNumberValue.length > 1
        ? beforeCustomerNumberValue[1]
        : '';

    // final int customerName = beforeCustomerNumberValue.length > 1
    //     ? int.tryParse(beforeCustomerNumberValue[1]) ?? 0
    //     : 0;

    final cashAmount = double.tryParse(_customCashController.text) ?? 0.0;
    final upiAmount = double.tryParse(_customUpiController.text) ?? 0.0;
    final cardAmount = double.tryParse(_customCardController.text) ?? 0.0;

    List<String> paymentTypes = [];
    if (cashAmount > 0) paymentTypes.add("Cash");
    if (upiAmount > 0) paymentTypes.add("UPI");
    if (cardAmount > 0) paymentTypes.add("Card");

    Map<String, dynamic> invoiceData = {
      "type": "invoiceKOT",
      "invoiceNo": widget.items.first['invoiceNo'] ?? "",
      "seathiveOrderId": widget.items.first['seathiveOrderId'] ?? "",
      "varianceitemCode": groupedItems.values
          .map((item) => item['varianceitemCode'])
          .toList(),
      "varianceName": groupedItems.keys.toList(),
      "itemName": groupedItems.values.map((item) => item['itemName']).toList(),
      "price": groupedItems.values.map((item) => item['price']).toList(),
      "qty": groupedItems.values.map((item) => item['qty']).toList(),
      "weight": groupedItems.values.map((item) => item['weight']).toList(),
      "amount": groupedItems.values.map((item) => item['amount']).toList(),
      "tax": groupedItems.values.map((item) => item['tax']).toList(),
      "uom": groupedItems.values.map((item) => item['uom']).toList(),
      "totalAmount": widget.totalAmount,
      "sellingPrice": groupedItems.values
          .map((item) => item['price'])
          .toList(),
      "sellingAmount": groupedItems.values
          .map((item) => item['amount'])
          .toList(),
      "paymentType": paymentTypes,
      "cash": cashAmount,
      "card": cardAmount,
      "upi": upiAmount,
      "razorpayPaymentId": state.razorpayPaymentId ?? "",
      "invoiceDate": DateFormat('dd-MM-yyyy').format(DateTime.now()),
      "invoiceTime": DateFormat('hh:mm a').format(DateTime.now()),
      'invoiceDateTime': billDate.toIso8601String(),
      "deviceCode": widget.deviceCode,
      "branchId": branchId,
      "branchName": widget.branchName,
      "aliasName": aliasname,
      "salesPersonId": loggedInUserName,
      "salesPersonName": employeeName,
      "employeeNumber": employeeNumber,
      "customerPhoneNumber": customerNumber,
      "sync": "No",
      "salesType": ordertype,
      "kotaddOns": kotAddOns,
      "shiftId": shiftId.value,
      "shiftNumber": int.tryParse(shiftNumber.value) ?? 0,
      "gst": groupedItems.values.map((item) => item['tax']).toList(),
    };

    debugPrint("✅ Final invoice data prepared: $invoiceData");

    if (invoiceData['totalAmount'] <= 0.0) {
      _showCustomSnackBar(
        "Invalid invoice data, total amount is zero.",
        isSuccess: false,
      );
      return;
    }

    try {
      if (_channel == null) {
        await _initializeWebSocket();
        if (_channel == null)
          throw Exception('Failed to establish WebSocket connection');
      }
      final serializedData = jsonEncode(invoiceData);
      _channel!.sink.add(serializedData);
      debugPrint("🎉 Invoice data sent to server successfully!");
    } catch (e) {
      debugPrint("⚠️ Error sending invoice data: $e");
      _showCustomSnackBar("Error sending invoice data: $e", isSuccess: false);
    }
  }

  void _processInvoiceAndPrint() async {
    try {
      _sendInvoiceDataToServer();

      String seathiveOrderId = widget.items.first['seathiveOrderId'] ?? '';
      String table = widget.items.first['table'] ?? '';
      String seat = widget.items.first['seat'] ?? '';

      if (seathiveOrderId.isNotEmpty) {
        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );
        orderProvider.patchOrderStatusBySeathiveOrderId(
          seathiveOrderId,
          'invoiced',
          table,
          seat,
        );
      }

      final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);
      final prov = Provider.of<SalesInvoiceState>(context, listen: false);

      cartProvider.clearCart();

      prov.employee.text = '';

      createdBy = '';

      Navigator.of(context).pop();

      // if (mounted) {
      //   await Future.delayed(const Duration(milliseconds: 500));
      //   if (mounted) {
      //     Provider.of<BottomNavProvider>(context, listen: false).updateIndex(2);
      //   }
      // }
    } catch (e, st) {
      debugPrint("❌ Error during invoice printing: $e\n$st");
      if (mounted) {
        _showCustomSnackBar("Error: $e", isSuccess: false);
      }
    } finally {
      if (mounted) {
        state.setSubmitting(false);
      }
    }
  }
}

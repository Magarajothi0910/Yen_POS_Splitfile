import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_ui/services/format-time/format_date.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Global/Provider/current_datetime.dart';
import 'package:yen_pos/Global/Screen/camera_qr_screen.dart';
import 'package:yen_pos/Global/Widget/custom_sized_box.dart';
import 'package:yen_pos/Global/Widget/custom_textWidgets.dart';
import 'package:yen_pos/Global/Widget/todat_orders_print.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Global/pos_detector.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Hive_Manager/hive_service.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/customer_search.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/invoiceNumberGenerator.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/pending_print.dart';
import 'package:yen_pos/kotpreinvoice/utils/custom_snackbar.dart';
import 'package:yen_pos/regular_mode_page/widget/emp_search.dart';

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
  final String customerNumber;
  final String employeeNumber;
  const SalesInvoicePayAndPrint({
    super.key,
    required this.totalAmount,
    required this.holdBillId,
    this.customerNumber = '',
    this.employeeNumber = '',
    this.onDismiss,
  });
  @override
  State<SalesInvoicePayAndPrint> createState() =>
      SalesInvoicePayAndPrintState();
}

class SalesInvoicePayAndPrintState extends State<SalesInvoicePayAndPrint> {
  bool _hasAutoPrintedThisBill = false;
  final InvoiceService _invoiceService = InvoiceService();
  final List<String> cashOptions = [];
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _employeeNumberController =
      TextEditingController();
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
  late SalesInvoiceState stateProvider;
  late RazorpayQRProvider qrProvider;
  late CurrentSaleProvider saleProvider;
  SalesInvoiceState get prov =>
      Provider.of<SalesInvoiceState>(context, listen: false);
  bool _isPrinting = false; // ← Loading state

  double get totalUpiPaid => prov.splitPayments
      .where((p) => p['method'] == 'Upi' && p['paid'] == true)
      .fold(0.0, (sum, p) => sum + (p['amount'] as double));

  double get totalCardPaid => prov.splitPayments
      .where((p) => p['method'] == 'Card' && p['paid'] == true)
      .fold(0.0, (sum, p) => sum + (p['amount'] as double));

  bool get hasRemainingBalance {
    return getRemainingForMethod('Upi') > 0 ||
        getRemainingForMethod('Card') > 0;
  }

  bool get hasAnySuccessfulDigitalPayment {
    return prov.splitPayments.any(
          (p) =>
              (p['method'] == 'Upi' || p['method'] == 'Card') &&
              p['paid'] == true,
        ) ||
        totalUpiPaid > 0 ||
        totalCardPaid > 0;
  }

  bool canAddMoreForMethod(String method) {
    if (method != 'Upi' && method != 'Card') return false;

    double remainingForThisMethod = getRemainingForMethod(method);

    // Allow adding only if:
    // 1. There is still positive remaining balance for this method
    // 2. (optional strict rule) Bill is not already fully paid overall
    bool billNotFullyPaid = prov.balanceAmount > 0;

    return remainingForThisMethod > 0 && billNotFullyPaid;
  }

  bool get shouldDisableDiscount {
    return hasAnySuccessfulDigitalPayment;
  }

  void _handleCardPaymentForSplit(double amount, VoidCallback onSuccess) {
    final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
    qrProvider.createOrderAndPay(amount, (type, extraData) {
      if (type == 'card_payment_success') {
        onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card payment successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  double get totalPaidFromSplits => totalUpiPaid + totalCardPaid;
  void _initiateSplitPayment(Map<String, dynamic> payment) {
    String method = payment['method'] as String;
    double amount = payment['amount'] as double;

    if (method == 'Upi') {
      _showUpiQrDialog(
        amount,
        onSuccess: () {
          // This is the key fix – mark as paid + aggregate
          prov.markSplitPaymentAsPaid(payment);

          // // Optional visual feedback
          // _customUpiController.text = prov.effectiveUpiAmount.toStringAsFixed(
          //   0,
          // );

          _updateBalance();
          validateForm();

          if (_shouldAutoPrintAfterUpiSuccess() && !_hasAutoPrintedThisBill) {
            _hasAutoPrintedThisBill = true; // LOCK IT — only once per bill

            Future.delayed(const Duration(milliseconds: 2000), () {
              if (mounted && !_isSubmitting) {
                debugPrint("Auto-printing now — UPI fully/completely paid");
                _printReceiptDetails();
              }
            });
          }
        },
      );
    } else if (method == 'Card') {
      _handleCardPaymentForSplit(amount, () {
        prov.markSplitPaymentAsPaid(payment);
        // _customCardController.text = prov.effectiveCardAmount.toStringAsFixed(
        //   0,
        // );

        _updateBalance();
        validateForm();
      });
    }
  }

  void _showAddSplitPaymentDialog(String method) {
    final TextEditingController splitController = TextEditingController();
    double remaining = getRemainingForMethod(method);

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No remaining balance to pay with this method"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Prevents accidental dismissal
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(
                method == 'Upi' ? Icons.qr_code_2 : Icons.credit_card,
                color: Colors.blue,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                "Add Another $method Payment",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          content: Container(
            width: 350, // Fixed width for consistency on tablets/POS screens
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Remaining Balance Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Remaining Balance",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        "₹${remaining.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Amount Input Field
                TextField(
                  controller: splitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: "Enter Amount",
                    labelStyle: TextStyle(color: Colors.black87),
                    prefixText: "₹ ",
                    prefixStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    hintText: "Max: ₹${remaining.toStringAsFixed(0)}",
                    hintStyle: TextStyle(color: Colors.black),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.black!, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.black!, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.blue!, width: 2.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                  onChanged: (value) {
                    double? amt = double.tryParse(value);
                    if (amt != null && amt > remaining) {
                      splitController.text = remaining.toStringAsFixed(0);
                      splitController.selection = TextSelection.fromPosition(
                        TextPosition(offset: splitController.text.length),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Generate QR / Pay Button
            ElevatedButton(
              onPressed: () {
                String input = splitController.text.trim();
                if (input.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter an amount"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                double? amt = double.tryParse(input);
                if (amt == null || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Invalid amount"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (amt > remaining + 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Amount cannot exceed remaining ₹${remaining.toStringAsFixed(0)}",
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Add split payment
                prov.addSplitPayment({
                  'method': method,
                  'amount': amt,
                  'paid': false,
                });

                Navigator.pop(dialogContext);

                // Start payment immediately
                _initiateSplitPayment(prov.splitPayments.last);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                elevation: 6,
                shadowColor: Colors.blue[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    method == 'Upi' ? Icons.qr_code_scanner : Icons.payment,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    method == 'Upi' ? "Generate QR" : "Proceed Payment",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Connect WebSocket safely
    final uri = Uri.parse('ws://$serverip:$port');
    _channel = WebSocketChannel.connect(uri);
    debugPrint("✅ WebSocket connected to $uri");
    _hasAutoPrintedThisBill = false;

    if (widget.customerNumber.isNotEmpty) {
      _customerNumberController.text = widget.customerNumber;
    }
    if (widget.employeeNumber.isNotEmpty) {
      _employeeNumberController.text = widget.employeeNumber;
    }

    // Setup controllers
    _keyboardControllers = [
      _employeeNumberController,
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendState();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendState();
      final stateProvider = Provider.of<SalesInvoiceState>(
        context,
        listen: false,
      );
      stateProvider.reset(); // Force reset on init to clear any global leaks
      _updateBalance();
      validateForm();
    });
    stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
    qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
    saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Remove any old listener first
    _customerNumberController.removeListener(_safeCustomerNumberLimiter);

    // Add NEW safe listener that NEVER touches "Mobile - Name
    _customerNumberController.addListener(_safeCustomerNumberLimiter);
  }

  void _safeCustomerNumberLimiter() {
    final currentText = _customerNumberController.text;

    // CRITICAL: If customer is already selected (has " - Name"), DO NOT modify text!
    if (currentText.contains(' - ') &&
        currentText.split(' - ').length > 1 &&
        currentText.split(' - ')[1].trim().isNotEmpty) {
      return;
    }

    // Only limit digits when user is typing a fresh mobile number
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

  void _removeStateListeners() {
    _employeeNumberController.removeListener(() {});
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

  // @override
  // void dispose() {
  //   debugPrint("Disposing Payment Screen...1");
  //   _qrFocusNode.dispose();
  //   _employeeNumberController.dispose();
  //   _qrController.dispose();
  //   debugPrint("Disposing Payment Screen...2.1");
  //   _removeStateListeners();
  //   // Cancel debounce timers
  //   for (var timer in _debounceMap.values) {
  //     timer?.cancel();
  //   }
  //   debugPrint("Disposing Payment Screen...2.1.1");
  //   _debounceMap.clear();
  //   debugPrint("Disposing Payment Screen...2.1.2");
  //   // Dispose controllers and focus nodes
  //   for (final controller in _keyboardControllers) {
  //     controller.dispose();
  //   }
  //   debugPrint("Disposing Payment Screen...2.2");
  //   for (final node in _focusNodes) {
  //     node.dispose();
  //   }
  //   _currentFocusIndexNotifier.dispose();
  //   // Close WebSocket
  //   try {
  //     // _channel.sink.close();
  //     debugPrint("🔌 WebSocket closed");
  //   } catch (e) {
  //     debugPrint("⚠️ Error closing WebSocket: $e");
  //   }
  //   // Reset providers
  //   debugPrint("Disposing Payment Screen...2");
  //   saleProvider.discountPercentage = 0.0;
  //   saleProvider.customCharge = 0.0;
  //   saleProvider.calculateTotal();
  //   debugPrint("Disposing Payment Screen...3");
  //   qrProvider.disconnectWebSocket();
  //   qrProvider.isCardPaid = false;
  //   qrProvider.errorMessage = null;
  //   debugPrint("Disposing Payment Screen...4");
  //   stateProvider.reset(); // ✅ This clears all lingering state
  //   debugPrint("Disposing Payment Screen...4.1");
  //   _employeeNumberController.clear();
  //   debugPrint("Disposing Payment Screen...5");
  //   stateProvider.updateMultiple(
  //     cashAmount: 0.0,
  //     upiAmount: 0.0,
  //     cardAmount: 0.0,
  //     isUpiPaid: false,
  //     isCardPaid: false,
  //     balanceAmount: widget.totalAmount, // reset balance to current bill
  //   );
  //   _hasAutoPrintedThisBill = false;
  //   debugPrint("Disposing Payment Screen...E");
  //   super.dispose();
  // }

  @override
  void dispose() {
    debugPrint("Disposing Payment Screen...1");

    _qrFocusNode.dispose();
    _qrController.dispose();

    debugPrint("Disposing Payment Screen...2");

    _removeStateListeners();

    // Cancel debounce timers
    for (var timer in _debounceMap.values) {
      timer?.cancel();
    }
    _debounceMap.clear();

    debugPrint("Disposing Payment Screen...2.1");

    // Dispose ALL controllers **once**
    for (final controller in _keyboardControllers) {
      controller.dispose();
    }

    debugPrint("Disposing Payment Screen...2.2");

    for (final node in _focusNodes) {
      node.dispose();
    }

    _currentFocusIndexNotifier.dispose();

    // WebSocket
    try {
      _channel.sink.close();
      debugPrint("🔌 WebSocket closed");
    } catch (e) {
      debugPrint("⚠️ Error closing WebSocket: $e");
    }

    // Reset providers
    debugPrint("Disposing Payment Screen...3");

    saleProvider.discountPercentage = 0.0;
    saleProvider.customCharge = 0.0;
    saleProvider.calculateTotal();

    qrProvider.disconnectWebSocket();
    qrProvider.isCardPaid = false;
    qrProvider.errorMessage = null;

    debugPrint("Disposing Payment Screen...4");

    stateProvider.reset(); // This should now run reliably

    debugPrint("Disposing Payment Screen...4.1");

    stateProvider.updateMultiple(
      cashAmount: 0.0,
      upiAmount: 0.0,
      cardAmount: 0.0,
      isUpiPaid: false,
      isCardPaid: false,
      balanceAmount: widget.totalAmount,
    );

    _hasAutoPrintedThisBill = false;

    debugPrint("Disposing Payment Screen...E");
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
            stateProvider.updateIsCardPaid(true);
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
    bool isEmployeeSelected = _employeeNumberController.text.contains(' - ');
    bool isCustomerNumberValid = _customerNumberController.text.contains(' - ');
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stateProvider = Provider.of<SalesInvoiceState>(
        context,
        listen: false,
      );
      stateProvider.updateBalanceAmount(widget.totalAmount);
      validateForm(); // Re-enable Print button if employee/customer already filled
    });
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

  Future<void> sendBillToCustomer(
    String invoiceNo,
    Map<String, dynamic> invoiceData,
  ) async {
    final response = await http.post(
      Uri.parse('https://yenerp.com/fluttertestapi/invoices/api/send-bill'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'invoiceNo': invoiceNo, 'invoiceData': invoiceData}),
    );
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      print('Bill sent: ${result['pdfUrl']}');
    } else {
      print('Failed: ${response.body}');
    }
  }

  Map<String, dynamic> normalizeItem(Map<String, dynamic> item) {
    final variance = item['varianceData'] ?? {};
    final itemData = item['itemData'] ?? {};

    return {
      "itemData": {
        "itemName":
            itemData["itemName"] ??
            item["itemName"] ??
            variance["varianceName"] ??
            "Unknown",
        "tax": itemData["tax"] ?? item["tax"] ?? variance["variancetax"] ?? 0,
        "item_Uom":
            itemData["item_Uom"] ??
            item["uom"] ??
            variance["variance_Uom"] ??
            "N/A",
        "hsnCode": itemData['hsnCode'] ?? item['hsnCode'] ?? 0,
      },
      "varianceData": variance,
      "quantity": item["quantity"] ?? item["qty"] ?? 1,
      "weight": item["weight"] ?? 0,
      "itemName": item["itemName"] ?? variance["varianceName"] ?? "Unknown",
    };
  }

  Future<void> saveInvoiceToHiveAndPrint1() async {
    debugPrint('entered slaesInvoice');
    String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();

    var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
    var stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
    var cartItems = cartProvider.currentSaleItems ?? [];

    List<String> itemNames = [];
    List<int> hsnCode = [];
    List<String> varianceNames = [];
    List<double> prices = [];
    List<double> sellingPrices = [];
    List<double> weights = [];
    List<int> quantities = [];
    List<double> amounts = [];
    List<double> sellingAmounts = [];
    List<double> taxes = [];
    List<String> uoms = [];
    List<String> varianceItemCode = [];
    List<double> gstRates = [];
    List<double> gstValues = [];

    List<String> paymentMethods = [
      if (prov.cashAmount > 0) 'Cash',
      if (prov.effectiveUpiAmount > 0) 'Upi',
      if (prov.effectiveCardAmount > 0) 'Card',
    ];

    double discount_perc = _discountController.text.isNotEmpty
        ? double.tryParse(_discountController.text) ?? 0.0
        : 0.0;

    List<double> customCharge = _customChargeController.text.isNotEmpty
        ? [(double.tryParse(_customChargeController.text) ?? 0.0)]
        : [];

    double totalItemTotal = 0.0;
    double totalNet = 0.0;
    double totalCross = 0.0;
    double totalDiscountAmount = 0.0;

    for (var raw in cartItems) {
      final item = normalizeItem(raw);

      final itemName = item['itemData']['itemName'] ?? 'N/A';
      final varianceName = item['varianceData']['varianceName'] ?? 'N/A';
      final uom =
          item['varianceData']['variance_Uom'] ??
          item['itemData']['item_Uom'] ??
          'N/A';

      final rate =
          item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0;

      double weight = (item['weight'] ?? 0).toDouble();
      int qty = (item['quantity'] ?? 0).round();

      if (weight > 0 && qty == 0) qty = 1;

      final tax = (item['itemData']['tax'] ?? 0).toDouble();

      // ==============================
      // ✅ FIXED PRICE CALCULATION
      // ==============================
      double actualUnitPrice = uom == "Kgs" ? rate * weight : rate;

      actualUnitPrice = double.parse(actualUnitPrice.toStringAsFixed(2));

      double grossAmount = uom == "Kgs"
          ? actualUnitPrice
          : actualUnitPrice * qty;

      // Discount
      double itemDiscount = grossAmount * (discount_perc / 100);
      double discountedGross = grossAmount - itemDiscount;

      // GST split
      double taxRate = tax / 100;
      double netExclusive = tax > 0
          ? discountedGross / (1 + taxRate)
          : discountedGross;
      double gstAmount = discountedGross - netExclusive;

      // Totals
      totalDiscountAmount += itemDiscount;
      totalItemTotal += discountedGross;
      totalNet += netExclusive;

      // ==============================
      // PUSH VALUES (FIXED)
      // ==============================
      itemNames.add(itemName);
      varianceNames.add(varianceName);
      varianceItemCode.add(item['varianceData']['itemCode'] ?? 'N/A');
      hsnCode.add(item['itemData']['hsnCode'] ?? 0);

      prices.add(actualUnitPrice);
      sellingPrices.add(
        discount_perc > 0
            ? double.parse(
                (actualUnitPrice * (1 - discount_perc / 100)).toStringAsFixed(
                  2,
                ),
              )
            : actualUnitPrice,
      );

      weights.add(weight);
      quantities.add(qty);

      amounts.add(double.parse(grossAmount.toStringAsFixed(2)));
      sellingAmounts.add(double.parse(discountedGross.toStringAsFixed(2)));

      taxes.add(tax);
      uoms.add(uom);
      gstRates.add(tax);
      gstValues.add(double.parse(gstAmount.toStringAsFixed(2)));
    }

    double totalCustomCharge = customCharge.fold(
      0.0,
      (sum, item) => sum + item,
    );

    totalCross = totalItemTotal + totalCustomCharge;

    DateTime billDate = DateTime.now();

    String uniqueIdentifier =
        '${DateFormat('dd-MM-yyyy').format(billDate)}-$totalItemTotal-${_customerNumberController.text}';

    // String customerPhone = _customerNumberController.text
    //     .split(' - ')
    //     .first
    //     .trim();

    int? customerPhone = int.tryParse(
      _customerNumberController.text
          .split(' - ')
          .first
          .trim()
          .replaceAll(RegExp(r'[^0-9]'), ''),
    );

    String salesPersonId = stateProvider.selectedEmployeeNumber ?? '';
    String salesPersonName = stateProvider.selectedEmployeeFirstName ?? '';

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
      'discountPercentage': int.tryParse(_discountController.text) ?? 0,
      'customCharge': customCharge,
      'totalAmount': totalItemTotal,
      'netAmount': totalNet,
      'grossAmount': totalCross,
      'invoiceDateTime': billDate.toIso8601String(),
      'locationId': locationId,
      'salesType': "TakeAway",
      'branchName': branchName,
      'aliasName': aliasname,
      'cash': prov.cashAmount > 0 ? prov.cashAmount : null,
      'card': prov.effectiveCardAmount > 0 ? prov.effectiveCardAmount : null,
      'upi': prov.effectiveUpiAmount > 0 ? prov.effectiveUpiAmount : null,
      'others': null,
      'shiftNumber': int.tryParse(shiftNumber.value) ?? 0,
      'shiftId': shiftId.value,
      'invoiceNo': '',
      'deviceNumber': 1,
      'sync': "No",
      'status': "active",
      'uniqueIdentifier': uniqueIdentifier,
      'gst': gstRates,
      'gstValue': gstValues,
      'discountAmount': totalDiscountAmount > 0 ? totalDiscountAmount : null,
      'hsnCode': hsnCode,
      'paymentType': paymentMethods,
    };

    debugPrint('posInvoice1');
    // Wrap invoice into JSON
    final invoiceJson = jsonEncode({
      "salesOrderId": invoiceData,
      "type": "invoice",
      //"sync": "No",
      "edit": "No",
    });
    // String jsonInvoiceData = jsonEncode({'data': invoiceData, 'type': 'posInvoice'});
    debugPrint('posInvoice2');
    try {
      await sendataToServer(jsonDecode(invoiceJson));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending invoice to server: $e')),
      );
    }
    debugPrint('posInvoice3 $invoiceJson');

    // Step 4: Log the invoice data only if it hasn't been logged before
    if (!_loggedInvoices.contains(uniqueIdentifier)) {
      _loggedInvoices.add(uniqueIdentifier);
      developer.log('Invoice Data:', name: 'InvoiceLog');
      developer.log(invoiceData.toString(), name: 'InvoiceLog');
    }
    try {
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
          await sendBillToCustomer('', invoiceData);
        }
      } else {
        print('Invalid phone number format: $phoneNumber');
      }
    } catch (e) {
      print('Error posting invoice or sending message: $e');
    }
    print("web123");

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

    // Enforce max 2 digits
    if (discount.length > 2) {
      discount = discount.substring(0, 2);
      _discountController.text = discount;
      _discountController.selection = TextSelection.fromPosition(
        TextPosition(offset: discount.length),
      );
    }

    double discountValue = double.tryParse(discount) ?? 0.0;
    if (discountValue > 99) discountValue = 99;

    saleProvider.discountPercentage = discountValue;
    saleProvider.calculateTotal();
    double newTotal = getTotalWithAdjustments();
    stateProvider.updateBalanceAmount(newTotal);
    _recalculatePaymentsOnTotalChange();
  }

  // NEW METHOD: Update payment fields when discount changes
  void _updatePaymentFieldsAfterDiscount() {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    final totalWithAdjustments = getTotalWithAdjustments();

    // Recalculate payment amounts to maintain balance
    double totalPayments =
        stateProvider.cashAmount +
        stateProvider.upiAmount +
        stateProvider.cardAmount;

    // If total payments exceed new total, adjust them
    if (totalPayments > totalWithAdjustments) {
      double excess = totalPayments - totalWithAdjustments;

      // Reduce payments proportionally (simple approach: reduce cash first)
      if (stateProvider.cashAmount >= excess) {
        stateProvider.updateCashAmount(stateProvider.cashAmount - excess);
        _customCashController.text = stateProvider.cashAmount.toStringAsFixed(
          0,
        );
      } else {
        double remainingExcess = excess - stateProvider.cashAmount;
        stateProvider.updateCashAmount(0);
        _customCashController.text = '0';

        if (stateProvider.upiAmount >= remainingExcess) {
          stateProvider.updateUpiAmount(
            stateProvider.upiAmount - remainingExcess,
          );
          _customUpiController.text = stateProvider.upiAmount.toStringAsFixed(
            0,
          );
        } else {
          double finalExcess = remainingExcess - stateProvider.upiAmount;
          stateProvider.updateUpiAmount(0);
          _customUpiController.text = '0';

          stateProvider.updateCardAmount(
            stateProvider.cardAmount - finalExcess,
          );
          _customCardController.text = stateProvider.cardAmount.toStringAsFixed(
            0,
          );
        }
      }
    }

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

    // Use EFFECTIVE values that include splits!
    if (method != 'Cash') otherPayments += stateProvider.cashAmount;
    if (method != 'Upi') otherPayments += prov.effectiveUpiAmount; // ← key fix
    if (method != 'Card')
      otherPayments += prov.effectiveCardAmount; // ← key fix

    double remaining = total - otherPayments;
    return remaining.clamp(0.0, double.infinity); // never negative
  }

  void _updateBalance() {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );

    // Use EFFECTIVE paid amounts (includes splits!)
    double totalPayments =
        stateProvider.cashAmount +
        prov.effectiveUpiAmount +
        prov.effectiveCardAmount;

    double totalWithDiscount = getTotalWithAdjustments();

    double rawBalance = totalWithDiscount - totalPayments;
    stateProvider.updateBalanceAmount(
      rawBalance.clamp(-double.infinity, double.infinity),
    );

    double amountForOptions = rawBalance.abs();
    cashOptions.clear();
    cashOptions.addAll(_generateCashOptions(amountForOptions));

    validateForm();
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

  // void _selectPaymentOption(String method, String amount) {
  //   final stateProvider = Provider.of<SalesInvoiceState>(
  //     context,
  //     listen: false,
  //   );

  //   double selectedAmount = double.tryParse(amount) ?? 0.0;

  //   // FIXED: Allow clearing the field (0 amount)
  //   if (selectedAmount == 0) {
  //     // Clear this payment method
  //     switch (method) {
  //       case "Cash":
  //         stateProvider.updateCashAmount(0);
  //         _customCashController.text = '';
  //         break;
  //       case "Upi":
  //         stateProvider.updateUpiAmount(0);
  //         _customUpiController.text = '';
  //         stateProvider.updateIsUpiPaid(false);
  //         break;
  //       case "Card":
  //         stateProvider.updateCardAmount(0);
  //         _customCardController.text = '';
  //         final qrProvider = Provider.of<RazorpayQRProvider>(
  //           context,
  //           listen: false,
  //         );
  //         qrProvider.isCardPaid = false;
  //         break;
  //     }
  //     _updateBalance();
  //     return;
  //   }

  //   // FIXED: Different validation for Cash vs UPI/Card
  //   if (method == "Upi" || method == "Card") {
  //     double remainingBalance = getRemainingForMethod(method);

  //     // For UPI/Card: Allow typing but validate it doesn't exceed remaining balance
  //     if (selectedAmount > remainingBalance + 0.01) {
  //       String methodName = method == "Upi"
  //           ? "UPI"
  //           : "Card";
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             "$methodName payment cannot exceed ₹${remainingBalance.toStringAsFixed(0)}",
  //           ),
  //           backgroundColor: Colors.orange[700],
  //           duration: const Duration(seconds: 2),
  //         ),
  //       );
  //       // Auto-correct to remaining balance if exceeds
  //       selectedAmount = remainingBalance;
  //       amount = remainingBalance.toStringAsFixed(0);

  //       // Update the text field immediately
  //       if (method == "Upi") {
  //         _customUpiController.text = amount;
  //       } else if (method == "Card") {
  //         _customCardController.text = amount;
  //       } else {
  //         _customCashController.text = amount;
  //       }
  //     }

  //     // FIXED: Also validate that amount is not less than 0
  //     if (selectedAmount < 0) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text("$method amount cannot be negative"),
  //           backgroundColor: Colors.red,
  //           duration: const Duration(seconds: 2),
  //         ),
  //       );
  //       selectedAmount = 0;
  //       amount = '0';

  //       if (method == "Upi") {
  //         _customUpiController.text = '';
  //       } else if (method == "Card") {
  //         _customCardController.text = amount;
  //       } else {
  //         _customCashController.text = amount;
  //       }
  //       return;
  //     }
  //   } else if (method == "Cash") {
  //     // For Cash: Allow any amount (including overpayment)
  //     double remainingBalance = getRemainingForMethod(method);

  //     // Optional: Show warning for very large overpayment
  //     if (selectedAmount > remainingBalance + 5000) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("Cash amount seems very high. Please double-check."),
  //           backgroundColor: Colors.orange,
  //           duration: const Duration(seconds: 2),
  //         ),
  //       );
  //     }

  //     // FIXED: Validate cash amount is not negative
  //     if (selectedAmount < 0) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("Cash amount cannot be negative"),
  //           backgroundColor: Colors.red,
  //           duration: const Duration(seconds: 2),
  //         ),
  //       );
  //       selectedAmount = 0;
  //       amount = '0';
  //       _customCashController.text = '';
  //       return;
  //     }
  //   }

  //   // Update state
  //   stateProvider.updateMultiple(
  //     selectedPaymentOption: '$method: ${selectedAmount.toStringAsFixed(0)}',
  //     selectedPaymentOptionValue: method,
  //   );

  //   switch (method) {
  //     case "Cash":
  //       stateProvider.updateCashAmount(selectedAmount);
  //       _customCashController.text = selectedAmount.toStringAsFixed(0);
  //       break;
  //     case "Upi":
  //       stateProvider.updateUpiAmount(selectedAmount);
  //       _customUpiController.text = selectedAmount.toStringAsFixed(0);
  //       break;
  //     case "Card":
  //       stateProvider.updateCardAmount(selectedAmount);
  //       _customCardController.text = selectedAmount.toStringAsFixed(0);
  //       break;
  //   }

  //   _updateBalance();
  // }

  void _selectPaymentOption(String method, String amount) {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );

    double selectedAmount = double.tryParse(amount) ?? 0.0;

    // Allow clearing the field
    if (selectedAmount == 0) {
      switch (method) {
        case "Cash":
          stateProvider.updateCashAmount(0);
          _customCashController.text = '';
          break;
        case "Upi":
          stateProvider.updateUpiAmount(0);
          _customUpiController.text = '';
          stateProvider.updateIsUpiPaid(false);
          break;
        case "Card":
          stateProvider.updateCardAmount(0);
          _customCardController.text = '';
          final qrProvider = Provider.of<RazorpayQRProvider>(
            context,
            listen: false,
          );
          qrProvider.isCardPaid = false;
          break;
      }
      _updateBalance();
      return;
    }

    // Get current payment values (before applying new amount)
    double currentCash = stateProvider.cashAmount;
    double currentUpi = stateProvider.upiAmount;
    double currentCard = stateProvider.cardAmount;

    // Temporarily set current method to 0 to calculate "other payments"
    if (method == "Cash") currentCash = 0;
    if (method == "Upi") currentUpi = 0;
    if (method == "Card") currentCard = 0;

    double otherPayments = currentCash + currentUpi + currentCard;
    double totalWithAdjustments = getTotalWithAdjustments();
    double remainingBalance = totalWithAdjustments - otherPayments;

    // NEW RULE: Check if any digital payment (UPI or Card) is already used
    bool hasDigitalPayment =
        stateProvider.upiAmount > 0 || stateProvider.cardAmount > 0;

    // If we're entering a digital payment now, it will be counted after update
    if ((method == "Upi" || method == "Card") && selectedAmount > 0) {
      hasDigitalPayment = true;
    }

    // Core Validation
    if (method == "Upi" || method == "Card") {
      // Digital payments NEVER allowed to exceed remaining
      if (selectedAmount > remainingBalance + 0.01) {
        String methodName = method == "Upi" ? "UPI" : "Card";

        // Auto-correct to max allowed
        selectedAmount = remainingBalance;
        amount = remainingBalance.toStringAsFixed(0);

        if (method == "Upi") {
          _customUpiController.text = amount;
          _customUpiController.selection = TextSelection.fromPosition(
            TextPosition(offset: amount.length),
          );
        } else {
          _customCardController.text = amount;
          _customCardController.selection = TextSelection.fromPosition(
            TextPosition(offset: amount.length),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "$methodName payment cannot exceed remaining ₹${remainingBalance.toStringAsFixed(0)}",
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (method == "Cash") {
      double remainingBalance = getRemainingForMethod(
        'Cash',
      ); // now uses effective!

      // When digital payments exist → strict cap (no overpayment allowed)
      if (hasDigitalPayment) {
        if (selectedAmount > remainingBalance + 0.01) {
          selectedAmount = remainingBalance;
          amount = remainingBalance.toStringAsFixed(0);
          _customCashController.text = amount;
          _customCashController.selection = TextSelection.fromPosition(
            TextPosition(offset: amount.length),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Cash capped at remaining ₹${remainingBalance.toStringAsFixed(0)}",
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      // Pure cash → still allow some overpayment (change / rounding), but warn on very high
      else {
        if (selectedAmount > remainingBalance + 5000) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("High cash amount entered. Please confirm."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Always prevent negative
      if (selectedAmount < 0) {
        selectedAmount = 0;
        amount = '0';
        _customCashController.text = '';
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text("Amount cannot be negative")),
        // );
      }
    }

    // Prevent negative amounts
    if (selectedAmount < 0) {
      selectedAmount = 0;
      amount = '0';
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text("Amount cannot be negative"),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }

    // Apply corrected amount
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

  void _recalculatePaymentsOnTotalChange() {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    final totalWithAdjustments = getTotalWithAdjustments();

    double protectedUpi = 0;
    double protectedCard = 0;

    // Collect already SUCCESSFULLY PAID digital amounts (protected)
    for (var p in prov.splitPayments) {
      if (p['paid'] == true) {
        if (p['method'] == 'Upi') {
          protectedUpi += (p['amount'] as double);
        } else if (p['method'] == 'Card') {
          protectedCard += (p['amount'] as double);
        }
      }
    }

    // Also consider single (non-split) successful payments
    if (stateProvider.isUpiPaid) {
      protectedUpi += stateProvider.upiAmount;
    }
    if (stateProvider.isCardPaid) {
      protectedCard += stateProvider.cardAmount;
    }

    double currentCash = stateProvider.cashAmount;
    double currentUpi = stateProvider.upiAmount;
    double currentCard = stateProvider.cardAmount;

    double totalCurrentPayments = currentCash + currentUpi + currentCard;

    if (totalCurrentPayments > totalWithAdjustments) {
      double excess = totalCurrentPayments - totalWithAdjustments;

      // 1. First try to remove from unprotected cash
      if (currentCash >= excess) {
        stateProvider.updateCashAmount(currentCash - excess);
        _customCashController.text = (currentCash - excess).toStringAsFixed(0);
      }
      // 2. Then from unprotected part of UPI/Card
      else {
        excess -= currentCash;
        stateProvider.updateCashAmount(0);
        _customCashController.text = '0';

        double unprotectedUpi = currentUpi - protectedUpi;
        double unprotectedCard = currentCard - protectedCard;

        if (unprotectedUpi >= excess) {
          stateProvider.updateUpiAmount(
            protectedUpi + (unprotectedUpi - excess),
          );
          _customUpiController.text = stateProvider.upiAmount.toStringAsFixed(
            0,
          );
        } else {
          excess -= unprotectedUpi;
          stateProvider.updateUpiAmount(protectedUpi);
          _customUpiController.text = protectedUpi.toStringAsFixed(0);

          // Last resort - reduce card (even protected one - rare case)
          stateProvider.updateCardAmount(
            (currentCard - excess).clamp(protectedCard, currentCard),
          );
          _customCardController.text = stateProvider.cardAmount.toStringAsFixed(
            0,
          );
        }
      }
    }

    _updateBalance();
  }

  void _showUpiQrDialog(double amount, {required VoidCallback onSuccess}) {
    final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
    qrProvider.paymentSuccess = false;
    qrProvider.errorMessage = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      qrProvider.createQR(amount);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext qrDialogContext) {
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
                          Navigator.pop(qrDialogContext);
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
                  //  Future.delayed(const Duration(milliseconds: 200));
                  // Provider.of<SalesInvoiceState>(
                  //   parentContext,
                  //   listen: false,
                  // ).updateIsUpiPaid(true);
                  // // _customUpiController.text = stateProvider.upiAmount
                  // //     .toStringAsFixed(0);
                  // _sendState(type: 'upi_payment_success');
                  // // if (mounted) {
                  // //   setState(() {});
                  // // }
                  // // _updateBalance();
                  // // validateForm();
                  // // Future.delayed(const Duration(seconds: 2), () {
                  // //   if (mounted && Navigator.canPop(qrDialogContext)) {
                  // //     Navigator.pop(qrDialogContext);
                  // //   }
                  // // });
                  // return Column(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     // Lottie.asset(
                  //     //   'assets/Payment Successful.json',
                  //     //   repeat: false,
                  //     //   height: 500,
                  //     //   width: double.infinity,
                  //     //   fit: BoxFit.contain,
                  //     //   onLoaded: (composition) {
                  //     //     Future.delayed(
                  //     //       composition.duration + const Duration(seconds: 2),
                  //     //       () {
                  //     //         if (mounted) {
                  //     //           Navigator.pop(context);
                  //     //         }
                  //     //       },
                  //     //     );
                  //     //   },
                  //     // ),
                  //     Column(
                  //       children: [
                  //         Center(
                  //           child: const Text(
                  //             'UPI Payment Successful!',
                  //             style: TextStyle(
                  //               fontFamily: 'Poppins',
                  //               fontSize: 18,
                  //               fontWeight: FontWeight.bold,
                  //               color: Colors.green,
                  //             ),
                  //             textAlign: TextAlign.center,
                  //           ),
                  //         ),
                  //         Expanded(
                  //           child: ElevatedButton.icon(
                  //             icon: const Icon(Icons.close),
                  //             label: const Text("Close"),
                  //             onPressed: () {
                  //               Navigator.pop(qrDialogContext);
                  //             },
                  //             style: ElevatedButton.styleFrom(
                  //               backgroundColor: const Color.fromARGB(
                  //                 255,
                  //                 6,
                  //                 62,
                  //                 247,
                  //               ),
                  //               foregroundColor: Colors.white,
                  //               shape: RoundedRectangleBorder(
                  //                 borderRadius: BorderRadius.circular(7),
                  //               ),
                  //             ),
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ],
                  // );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // qrProvider.disconnectWebSocket();
                    // Navigator.of(context, rootNavigator: true).pop();
                    onSuccess();
                    // 🔥 notify parent
                  });

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
                      Column(
                        children: [
                          Center(
                            child: const Text(
                              'UPI Payment Successful!',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Expanded(
                          //   child: ElevatedButton.icon(
                          //     icon: const Icon(Icons.close),
                          //     label: const Text("Close"),
                          //     onPressed: () {
                          //       Navigator.pop(qrDialogContext);
                          //     },
                          //     style: ElevatedButton.styleFrom(
                          //       backgroundColor: const Color.fromARGB(
                          //         255,
                          //         6,
                          //         62,
                          //         247,
                          //       ),
                          //       foregroundColor: Colors.white,
                          //       shape: RoundedRectangleBorder(
                          //         borderRadius: BorderRadius.circular(7),
                          //       ),
                          //     ),
                          //   ),
                          // ),
                        ],
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
                                Navigator.pop(qrDialogContext);
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

  bool _shouldAutoPrintAfterUpiSuccess() {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );

    // 1. Must have sales person
    bool hasSalesPerson =
        stateProvider.selectedEmployeeFirstName != null &&
        _employeeNumberController.text.trim().isNotEmpty;

    // 2. Must have customer number
    bool hasCustomer = _customerNumberController.text.trim().isNotEmpty;

    // 3. Balance is zero (or negative) after this payment
    bool isFullyPaid = stateProvider.balanceAmount <= 0.01;

    // Optional: you can make it stricter — only auto-print if FULLY paid via UPI
    // bool paidOnlyViaUpi = stateProvider.cashAmount <= 0 &&
    //                      stateProvider.cardAmount <= 0 &&
    //                      stateProvider.effectiveUpiAmount >= getTotalWithAdjustments() - 0.01;

    return hasSalesPerson && hasCustomer && isFullyPaid;
  }

  // In your payment option widget, update this part:
  Widget _buildPaymentOption(String amount, String method) {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    bool isSelected = stateProvider.selectedPaymentOption == '$method: $amount';

    TextEditingController controller = method == 'Cash'
        ? _customCashController
        : method == 'Upi'
        ? _customUpiController
        : _customCardController;

    bool isUpiPaid = method == 'Upi' && stateProvider.isUpiPaid;
    bool isCardPaid = method == 'Card' && stateProvider.isCardPaid;
    bool shouldDisable = isUpiPaid || isCardPaid;

    if (amount == 'Custom') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
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
                    readOnly: shouldDisable,
                    enabled: !shouldDisable,
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

                      hintText: shouldDisable ? "Paid" : "Enter $method",
                      fillColor: shouldDisable ? Colors.grey : Colors.grey[100],
                      filled: true,
                    ),
                    onChanged: (v) =>
                        _selectPaymentOption(method, v.isEmpty ? '0' : v),
                    onTap: () => !shouldDisable
                        ? setCurrentFocusForController(controller)
                        : null,
                  ),
                ),
                if (method == 'Upi' || method == 'Card')
                  IconButton(
                    icon: Icon(
                      method == 'Upi' ? Icons.qr_code : Icons.credit_card,
                      color: shouldDisable ? Colors.grey : Colors.blue,
                    ),
                    onPressed: isPaymentEnabled && !shouldDisable
                        ? () {
                            final val = controller.text;
                            final amt = double.tryParse(val);
                            if (val.isNotEmpty && amt != null && amt > 0) {
                              debugPrint(
                                "UPI : ${getTotalWithAdjustments().toStringAsFixed(0)} - ${_customUpiController.text}",
                              );
                              method == 'Upi'
                                  ? _showUpiQrDialog(
                                      amt,
                                      onSuccess: () {
                                        // 🔥 NOW we are OUTSIDE dialog
                                        Provider.of<SalesInvoiceState>(
                                          context,
                                          listen: false,
                                        ).updateIsUpiPaid(true);

                                        _customUpiController.text =
                                            Provider.of<SalesInvoiceState>(
                                              context,
                                              listen: false,
                                            ).upiAmount.toStringAsFixed(0);
                                        _updateBalance();
                                        validateForm();

                                        _sendState(type: 'upi_payment_success');
                                        if (_shouldAutoPrintAfterUpiSuccess() &&
                                            !_hasAutoPrintedThisBill) {
                                          _hasAutoPrintedThisBill =
                                              true; // LOCK IT — only once per bill

                                          Future.delayed(
                                            const Duration(milliseconds: 2000),
                                            () {
                                              if (mounted && !_isSubmitting) {
                                                debugPrint(
                                                  "Auto-printing now — UPI fully/completely paid",
                                                );
                                                _printReceiptDetails();
                                              }
                                            },
                                          );
                                        }
                                      },
                                    )
                                  : _handleCardPayment();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Enter valid $method amount'),
                                ),
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
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: shouldDisable
            ? null
            : () => _selectPaymentOption(method, amount),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: shouldDisable
                ? Colors.grey[300]
                : (isSelected ? Colors.blue : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: shouldDisable
                  ? Colors.grey
                  : (isSelected ? Colors.blue : Colors.grey.shade300),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              amount,
              style: TextStyle(
                color: shouldDisable
                    ? Colors.grey[600]
                    : (isSelected ? Colors.white : Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _removeSplitPayment(Map<String, dynamic> paymentToRemove) {
    if (paymentToRemove['paid'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot remove a completed payment")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Payment?"),
        content: Text(
          "Are you sure you want to remove this pending ₹${paymentToRemove['amount'].toStringAsFixed(0)} payment?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              prov.splitPayments.remove(paymentToRemove);

              _updateBalance();
              validateForm();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Pending payment removed")),
              );
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(String method) {
    bool isDigital = method == 'Upi' || method == 'Card';
    double remaining = getRemainingForMethod(
      method,
    ); // keep your existing logic
    // For all methods, show exact remaining amount as suggestion
    String exactStr = remaining > 0 ? remaining.toStringAsFixed(0) : '0';

    List<String> extraOptions = [];
    if (method == 'Cash') {
      final stateProvider = Provider.of<SalesInvoiceState>(
        context,
        listen: false,
      );
      double amountForOptions = stateProvider.balanceAmount > 0
          ? stateProvider.balanceAmount
          : 0.0;
      extraOptions = _generateCashOptions(amountForOptions).skip(1).toList();
    }
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );

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
            const CustomSizedBox(width: 5),
            _buildPaymentOption('Custom', method),
            _buildPaymentOption(
              remaining > 0 ? remaining.toStringAsFixed(0) : '0',
              method,
            ),

            // ADD BUTTON - Only for UPI and Card
            if (isDigital) ...[
              // const SizedBox(width: 10),
              IconButton(
                icon: Icon(
                  Icons.add_circle,
                  size: 26,
                  color: stateProvider.isUpiPaid && canAddMoreForMethod(method)
                      ? Colors.blue
                      : Colors.grey,
                ),
                tooltip: stateProvider.isUpiPaid
                    ? (hasRemainingBalance
                          ? 'Add another $method payment'
                          : 'Bill fully paid')
                    : 'Complete one $method payment first',
                onPressed:
                    stateProvider.isUpiPaid && canAddMoreForMethod(method)
                    ? () => _showAddSplitPaymentDialog(method)
                    : null,
              ),
            ],
          ],
        ),

        if (prov.splitPayments.any((p) => p['method'] == method))
          Padding(
            padding: const EdgeInsets.only(
              top: 4,
              bottom: 4,
              left: 4,
              right: 10,
            ),
            child: Column(
              children: prov.splitPayments
                  .where((p) => p['method'] == method)
                  .map((payment) {
                    bool paid = payment['paid'] == true;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: paid
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: paid
                              ? Colors.green.shade300
                              : Colors.orange.shade300,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            payment['method'] == 'Upi'
                                ? Icons.qr_code
                                : Icons.credit_card,
                            color: paid
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "₹${payment['amount'].toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: paid
                                        ? Colors.green.shade900
                                        : Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  paid ? "Paid" : "Pending",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: paid
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!paid)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 24,
                              ),
                              tooltip: "Remove this pending payment",
                              onPressed: () => _removeSplitPayment(payment),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 24,
                              ),
                            ),
                          if (!paid)
                            IconButton(
                              icon: const Icon(
                                Icons.qr_code_scanner,
                                color: Colors.blue,
                                size: 24,
                              ),
                              tooltip: "Retry payment",
                              onPressed: () => _initiateSplitPayment(payment),
                            ),
                        ],
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
        // Only show extra options for Cash
        if (method == 'Cash' && extraOptions.isNotEmpty)
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

      if (controller == _customCashController) {
        double remaining = getRemainingForMethod('Cash');
        if (remaining > 0) {
          _selectPaymentOption('Cash', remaining.toStringAsFixed(0));
        }
      }
      // Auto-fill UPI/Card with remaining amount when focused
      else if (controller == _customUpiController && controller.text.isEmpty) {
        double remaining = getRemainingForMethod('Upi');
        if (remaining > 0) {
          _selectPaymentOption('Upi', remaining.toStringAsFixed(0));
        }
      } else if (controller == _customCardController &&
          controller.text.isEmpty) {
        double remaining = getRemainingForMethod('Card');
        if (remaining > 0) {
          _selectPaymentOption('Card', remaining.toStringAsFixed(0));
        }
      } else if (controller == _birthdayController) {
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

    // If current text is "0" or empty, replace it, otherwise append
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

  void _clearAllPayments({bool showSnackBar = true}) {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);

    stateProvider.updateCashAmount(0);
    stateProvider.updateUpiAmount(0);
    stateProvider.updateCardAmount(0);
    stateProvider.updateIsUpiPaid(false);

    _customCashController.clear();
    _customUpiController.clear();
    _customCardController.clear();

    qrProvider.isCardPaid = false;
    qrProvider.disconnectWebSocket();
    _updateBalance();
  }

  void _processControllerChange(TextEditingController controller) {
    if (controller == _discountController) {
      if (controller.text.isEmpty) {
        _applyDiscount('0');
      } else {
        _applyDiscount(controller.text);
      }
    } else if (controller == _customChargeController) {
      // NEW: Do NOT clear already paid digital payments
      double newCharge = double.tryParse(controller.text) ?? 0.0;

      // Recalculate total → protected recalc will handle excess
      _updateBalance(); // This will trigger _recalculatePaymentsOnTotalChange()

      // Only clear unprotected (unpaid) amounts if needed
      // But since _recalculatePaymentsOnTotalChange() already protects paid ones → safe!
    } else if (controller == _customCashController) {
      _selectPaymentOption(
        'Cash',
        controller.text.isEmpty ? '0' : controller.text,
      );
    } else if (controller == _customUpiController) {
      _selectPaymentOption(
        'Upi',
        controller.text.isEmpty ? '0' : controller.text,
      );
    } else if (controller == _customCardController) {
      _selectPaymentOption(
        'Card',
        controller.text.isEmpty ? '0' : controller.text,
      );
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

    _processControllerChange(currentController);
  }

  void _handleKeyboardOk() {
    final currentIndex = _currentFocusIndexNotifier.value;
    _moveToNextField(currentIndex);
  }

  bool _isSubmitting = false;

  Future<void> _printReceiptDetails() async {
    if (_isSubmitting) {
      developer.log('Print already in progress', name: 'SalesInvoice');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // === STOCK VALIDATION BEFORE PRINTING ===
      final globalManager = GlobalDataManager();
      final branchwiseItemsBox = await Hive.openBox('items');
      final branchwiseData = await branchwiseItemsBox.get(
        'branchwiseItems_$locationId',
      );
      debugPrint('branchwiseItems_ :$branchwiseData');

      Map<dynamic, dynamic>? branchwiseItems = {};
      if (branchwiseData is Map) {
        branchwiseItems = Map<dynamic, dynamic>.from(branchwiseData);
      }

      List<Map<String, dynamic>> stockCheckList = [];
      bool hasInsufficient = false;

      final cartProvider = Provider.of<CurrentSaleProvider>(
        context,
        listen: false,
      );
      final cartItems = cartProvider.currentSaleItems ?? [];

      for (var item in cartItems) {
        final itemName =
            item['itemName']?.toString() ??
            item['itemData']?['itemName']?.toString() ??
            '';
        final varianceName =
            item['varianceData']['varianceName']?.toString() ?? 'Unknown Item';
        final itemUom = (item['varianceData']['variance_Uom']?.toString() ?? '')
            .toLowerCase();
        final bool isKg = itemUom.contains('kg');

        double requiredQty = isKg
            ? (item['weight'] as num?)?.toDouble() ?? 0.0
            : (item['quantity'] as num?)?.toDouble() ?? 0.0;

        double liveStock = globalManager.getSystemStock(
          aliasname,
          varianceName,
        );
        debugPrint('stock :$liveStock');
        double availableStock = liveStock >= 0 ? liveStock : 0.0;

        if (liveStock < 0 &&
            branchwiseItems != null &&
            branchwiseItems['data']?[itemName] != null) {
          final itemData = branchwiseItems['data'][itemName];
          final varianceMap = itemData['variance'] as Map?;
          if (varianceMap != null) {
            for (var v in varianceMap.values) {
              if (v['varianceName']?.toString() == varianceName) {
                availableStock =
                    (v['branchwise']?[locationId]?['systemStock'] as num?)
                        ?.toDouble() ??
                    0.0;
                break;
              }
            }
          }
        }

        final bool sufficient = requiredQty <= availableStock + 0.001;
        if (!sufficient) hasInsufficient = true;

        stockCheckList.add({
          'item': varianceName,
          'required': requiredQty,
          'available': availableStock,
          'uom': isKg ? 'kg' : 'pcs',
          'status': sufficient ? 'OK' : 'Insufficient',
          'isKg': isKg,
        });
      }

      // === SHOW INSUFFICIENT STOCK DIALOG IF NEEDED ===
      if (hasInsufficient) {
        final List<Map<String, dynamic>> insufficientItems = stockCheckList
            .where((row) => row['status'] == 'Insufficient')
            .toList();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            alignment: Alignment.center,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 30,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              constraints: const BoxConstraints(maxHeight: 700),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey.shade50],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Insufficient Stock",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "The following items exceed available stock.",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body - Only Insufficient Items
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    "Item",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      "Required",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      "Available",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      "Shortage",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemCount: insufficientItems.length,
                              itemBuilder: (context, i) {
                                final row = insufficientItems[i];
                                final double shortage =
                                    (row['required'] as double) -
                                    (row['available'] as double);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.shade300,
                                      width: 1.8,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Text(
                                          row['item'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Text(
                                            "${row['required'].toStringAsFixed(row['isKg'] ? 3 : 0)} ${row['uom']}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Text(
                                            "${row['available'].toStringAsFixed(row['isKg'] ? 3 : 0)} ${row['uom']}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade600,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              "-${shortage.toStringAsFixed(row['isKg'] ? 3 : 0)}",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Close & Adjust Quantities",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        setState(() {
          _isSubmitting = false;
        });
        return; // Stop printing
      }

      // === ALL STOCK OK → PROCEED TO PRINT ===
      await saveInvoiceToHiveAndPrint1();

      //final cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
      cartProvider.clearItems();

      Navigator.of(context).pop();
    } catch (e, stack) {
      developer.log(
        'Print/Save failed',
        name: 'SalesInvoice',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      final stateProvider = Provider.of<SalesInvoiceState>(
        context,
        listen: false,
      );
      stateProvider.reset();

      final qrProvider = Provider.of<RazorpayQRProvider>(
        context,
        listen: false,
      );
      qrProvider.disconnectWebSocket();
      qrProvider.isCardPaid = false;
      qrProvider.errorMessage = null;

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('entered1');
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    return Stack(
      children: [
        Scaffold(
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
                        SizedBox(
                          width: 300,
                          child: Material(
                            elevation: 4,
                            shadowColor: Colors.black,
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            child: EmployeeSearch(
                              onEmpSelected: () {
                                _moveToNextField(0);
                                validateForm();
                              },
                              employeeController: _employeeNumberController,
                              employeeFocusNode: _getFocusNodeForController(
                                _employeeNumberController,
                              ),
                              readOnly: true,
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

                        Consumer<SalesInvoiceState>(
                          builder: (context, stateProv, _) {
                            return Expanded(
                              child: Material(
                                elevation: 4,
                                shadowColor: Colors.black,
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                child: TextField(
                                  showCursor: true,
                                  enabled: !stateProv.isUpiPaid,
                                  readOnly: stateProv.isUpiPaid,
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
                                    suffixIcon: stateProv.isUpiPaid
                                        ? Icon(
                                            Icons.lock,
                                            color: Colors.grey,
                                            size: 20,
                                          )
                                        : null,
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
                                      _discountController.text = value
                                          .substring(0, 2);
                                      _discountController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset: _discountController
                                                  .text
                                                  .length,
                                            ),
                                          );
                                      _applyDiscount(_discountController.text);
                                    } else {
                                      _applyDiscount(value);
                                    }
                                  },
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
                                        padding: const EdgeInsets.only(
                                          left: 10,
                                        ),
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
                                        padding: const EdgeInsets.only(
                                          left: 20,
                                        ),
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
                                        padding: const EdgeInsets.only(
                                          left: 10,
                                        ),
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
                                          focusNode:
                                              _focusNodes[currentFocusIndex],
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
                        // FIXED: Proper balance display logic
                        final double rawBalance = statesProvider.balanceAmount;
                        final String balanceDisplay;
                        if (rawBalance < 0) {
                          balanceDisplay =
                              "-₹${rawBalance.abs().toStringAsFixed(0)}";
                        } else if (rawBalance == 0) {
                          balanceDisplay = "₹0";
                        } else {
                          balanceDisplay = "₹${rawBalance.toStringAsFixed(0)}";
                        }

                        return Row(
                          children: [
                            _buildMiniCard(
                              title: "Total",
                              value:
                                  "₹${getTotalWithAdjustments().toStringAsFixed(0)}",
                              gradient: [Colors.blue[200]!, Colors.blue[500]!],
                            ),
                            const SizedBox(width: 5),
                            _buildMiniCard(
                              title: "Balance",
                              value: balanceDisplay,
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
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                        ),
                                      ),
                                  elevation: MaterialStateProperty.all(5.0),
                                ),
                                onPressed: !statesProvider.isPrintButtonEnabled
                                    ? () async {
                                        if (_employeeNumberController
                                            .text
                                            .isEmpty) {
                                          debugPrint('ec');
                                          CustomSnackBar.show(
                                            context,
                                            'Please select a Sales Person',
                                            type: SnackType.error,
                                          );
                                          return;
                                        }
                                        if (_customerNumberController
                                            .text
                                            .isEmpty) {
                                          CustomSnackBar.show(
                                            context,
                                            'Customer Number is required',
                                            type: SnackType.error,
                                          );
                                          return;
                                        }
                                        if (_customCashController
                                                .text
                                                .isEmpty ||
                                            _customCardController
                                                .text
                                                .isEmpty ||
                                            _customUpiController.text.isEmpty) {
                                          CustomSnackBar.show(
                                            context,
                                            'Please fill Payment Amounts',
                                            type: SnackType.error,
                                          );
                                          return;
                                        }
                                      }
                                    : () {
                                        Future.microtask(
                                          () => _printReceiptDetails(),
                                        );
                                      },

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
        ),
        if (_isSubmitting)
          Positioned.fill(
            child: Stack(
              children: [
                // Block touches but keep background visible
                const ModalBarrier(
                  dismissible: false,
                  color: Colors.transparent, // keep original background visible
                ),

                // Center loader
                const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                ),
              ],
            ),
          ),
      ],
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

// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:hive/hive.dart';
// import 'package:hive_ui/services/format-time/format_date.dart';
// import 'package:http/http.dart' as http;
// import 'package:provider/provider.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:yen_pos/Global/Provider/current_datetime.dart';
// import 'package:yen_pos/Global/Screen/camera_qr_screen.dart';
// import 'package:yen_pos/Global/Widget/custom_sized_box.dart';
// import 'package:yen_pos/Global/Widget/custom_textWidgets.dart';
// import 'package:yen_pos/Global/global_data_manager.dart';
// import 'package:yen_pos/Global/globals_data.dart';
// import 'package:yen_pos/Global/pos_detector.dart';
// import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
// import 'package:yen_pos/Hive_Manager/hive_service.dart';
// import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
// import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
// import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';
// import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/customer_search.dart';
// import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/invoiceNumberGenerator.dart';
// import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/pending_print.dart';
// import 'package:yen_pos/regular_mode_page/widget/emp_search.dart';

// import '../regular_mode_page/provider/cart_page_provider.dart';
// import 'package:intl/intl.dart';
// import 'dart:developer' as developer;
// import 'services/save_data_local.dart';
// import 'widgets/invoice_Print_Receipt.dart';
// import 'services/invoice_service.dart';
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:dio/dio.dart';
// import 'package:lottie/lottie.dart';

// class SalesInvoicePayAndPrint extends StatefulWidget {
//   final double totalAmount;
//   final String holdBillId;
//   final VoidCallback? onDismiss;
//   final String customerNumber;
//   const SalesInvoicePayAndPrint({
//     super.key,
//     required this.totalAmount,
//     required this.holdBillId,
//     this.customerNumber = '',
//     this.onDismiss,
//   });
//   @override
//   State<SalesInvoicePayAndPrint> createState() =>
//       SalesInvoicePayAndPrintState();
// }

// class SalesInvoicePayAndPrintState extends State<SalesInvoicePayAndPrint> {
//   final InvoiceService _invoiceService = InvoiceService();
//   final List<String> cashOptions = [];
//   final TextEditingController _customAmountController = TextEditingController();
//   final TextEditingController _employeeNumberController =
//       TextEditingController();
//   Map<String, Map<String, dynamic>> _allEmployees = {};
//   final TextEditingController _customerNumberController =
//       TextEditingController();
//   final TextEditingController _discountController = TextEditingController();
//   final TextEditingController _couponCodeController = TextEditingController();
//   final TextEditingController _customChargeController = TextEditingController();
//   final TextEditingController _customCashController = TextEditingController();
//   final TextEditingController _customUpiController = TextEditingController();
//   final TextEditingController _customCardController = TextEditingController();
//   final TextEditingController _birthdayController = TextEditingController();
//   late List<FocusNode> _focusNodes;
//   late ValueNotifier<int> _currentFocusIndexNotifier;
//   late List<TextEditingController> _keyboardControllers;
//   late WebSocketChannel _channel;
//   bool _isInitialSend = true;
//   SalesInvoiceState get prov =>
//       Provider.of<SalesInvoiceState>(context, listen: false);
//   bool _isPrinting = false; // ← Loading state

//   @override
//   void initState() {
//     super.initState();
//     // Connect WebSocket safely
//     final uri = Uri.parse('ws://$serverip:$port');
//     _channel = WebSocketChannel.connect(uri);
//     debugPrint("✅ WebSocket connected to $uri");

//     if (widget.customerNumber.isNotEmpty) {
//       _customerNumberController.text = widget.customerNumber;
//     }
//     if (prov.employee.text.isNotEmpty) {
//       _employeeNumberController.text = prov.employee.text;
//     }

//     // Setup controllers
//     _keyboardControllers = [
//       _employeeNumberController,
//       _customerNumberController,
//       _discountController,
//       _customChargeController,
//       _customCashController,
//       _customUpiController,
//       _customCardController,
//       _couponCodeController,
//       _birthdayController,
//     ];

//     // Setup focus nodes
//     _focusNodes = List.generate(
//       _keyboardControllers.length,
//       (_) => FocusNode(),
//     );
//     _currentFocusIndexNotifier = ValueNotifier<int>(0);

//     // Listen to focus changes (only once)
//     for (int i = 0; i < _focusNodes.length; i++) {
//       _focusNodes[i].addListener(() {
//         if (_focusNodes[i].hasFocus) {
//           _currentFocusIndexNotifier.value = i;
//         }
//       });
//     }

//     // WebSocket listener (store subscription if you want to cancel)
//     _channel.stream.listen(
//       (data) {
//         debugPrint("Received WebSocket data: $data");
//       },
//       onError: (error) {
//         debugPrint("❌ WebSocket error: $error");
//       },
//     );

//     // Setup providers
//     final saleState = Provider.of<SalesInvoiceState>(context, listen: false);
//     saleState.updateBalanceAmount(widget.totalAmount);
//     cashOptions.addAll(_generateCashOptions(widget.totalAmount));
//     _loadEmployees();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _sendState();
//     });
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();

//     // Remove any old listener first
//     _customerNumberController.removeListener(_safeCustomerNumberLimiter);

//     // Add NEW safe listener that NEVER touches "Mobile - Name
//     _customerNumberController.addListener(_safeCustomerNumberLimiter);
//   }

//   void _safeCustomerNumberLimiter() {
//     final currentText = _customerNumberController.text;

//     // CRITICAL: If customer is already selected (has " - Name"), DO NOT modify text!
//     if (currentText.contains(' - ') &&
//         currentText.split(' - ').length > 1 &&
//         currentText.split(' - ')[1].trim().isNotEmpty) {
//       return;
//     }

//     // Only limit digits when user is typing a fresh mobile number
//     String digitsOnly = currentText.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(0, 10);
//     }

//     if (digitsOnly != currentText) {
//       _customerNumberController.value = TextEditingValue(
//         text: digitsOnly,
//         selection: TextSelection.collapsed(offset: digitsOnly.length),
//       );
//     }
//   }

//   Timer? _debounce;
//   Map<String, dynamic> _lastSentData = {};
//   final Map<TextEditingController, Timer?> _debounceMap = {};
//   bool _listenersAdded = false;

//   void _sendState({
//     String type = 'state_update',
//     Map<String, dynamic>? extraData,
//   }) {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     final currentData = {
//       'isUpiPaid': stateProvider.isUpiPaid,
//       'isCardPaid': stateProvider.isCardPaid,
//       if (extraData != null) ...extraData,
//     };

//     final changedFields = <String, dynamic>{};
//     if (_isInitialSend) {
//       _isInitialSend = false;
//     } else {
//       currentData.forEach((key, value) {
//         if (_lastSentData[key] != value) {
//           changedFields[key] = value;
//         }
//       });
//     }

//     if (changedFields.isEmpty) return; // nothing changed

//     _lastSentData.addAll(changedFields);
//     final message = {
//       'message': 'changed_fields',
//       'type': type,
//       ...changedFields,
//     };

//     try {
//       final jsonData = jsonEncode(message);
//       sendataToServer(jsonDecode(jsonData));
//       developer.log('Sent: $jsonData', name: 'WebSocket');
//     } catch (e) {
//       debugPrint('❌ Error sending data: $e');
//     }
//   }

//   void _removeStateListeners() {
//     _employeeNumberController.removeListener(() {});
//     _customerNumberController.removeListener(() {});
//     _customAmountController.removeListener(() {});
//     _discountController.removeListener(() {});
//     _customChargeController.removeListener(() {});
//     _customCashController.removeListener(() {});
//     _customUpiController.removeListener(() {});
//     _customCardController.removeListener(() {});
//     _birthdayController.removeListener(() {});
//     _couponCodeController.removeListener(() {});
//   }

//   // ------------------- QR STATE -------------------
//   bool _isQrMode = false;
//   final FocusNode _qrFocusNode = FocusNode();
//   final TextEditingController _qrController = TextEditingController();
//   bool _isProcessingQr = false;

//   // ------------------- QR TOGGLE -------------------
//   Future<void> _toggleQrMode() async {
//     final isPOS = await POSDetector.isPOSDevice;
//     if (isPOS) {
//       _startHardwareScanner();
//     } else {
//       _startCameraScan();
//     }
//   }

//   // POS Hardware Scanner
//   void _startHardwareScanner() {
//     setState(() {
//       _isQrMode = true;
//       _qrFocusNode.requestFocus();
//     });
//   }

//   // Camera Scanner
//   Future<void> _startCameraScan() async {
//     final result = await Navigator.of(context).push<String>(
//       MaterialPageRoute(builder: (_) => const QRCodeScannerScreen()),
//     );
//     if (result != null && result.isNotEmpty) {
//       _handleQrInput(result);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No QR code scanned.'),
//           duration: Duration(seconds: 1),
//         ),
//       );
//     }
//   }

//   // ------------------- QR INPUT HANDLER -------------------
//   void _handleQrInput(String raw) async {
//     if (_isProcessingQr || !_isQrMode) return;
//     setState(() => _isProcessingQr = true);
//     try {
//       final data = _parseQrData(raw);
//       final name = data['Name']?.toString().trim();
//       if (name == null) throw Exception('Name not found');
//       final match = _allEmployees.entries.firstWhereOrNull(
//         (e) => e.key.contains(name),
//       );
//       if (match != null) {
//         _selectEmployee(match.key);
//         _employeeNumberController.selection = TextSelection.fromPosition(
//           TextPosition(offset: match.key.length),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Employee not found in list.')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('QR Error: $e')));
//     } finally {
//       _qrController.clear();
//       _qrFocusNode.unfocus();
//       setState(() {
//         _isProcessingQr = false;
//         _isQrMode = false;
//       });
//     }
//   }

//   // ------------------- QR PARSING -------------------
//   Map<String, dynamic> _parseQrData(String raw) {
//     try {
//       return json.decode(raw) as Map<String, dynamic>;
//     } catch (_) {
//       final map = <String, dynamic>{};
//       raw.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
//         final kv = pair.split(':');
//         if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
//       });
//       if (map.isEmpty) throw Exception('Invalid QR format');
//       return map;
//     }
//   }

//   @override
//   void dispose() {
//     _qrFocusNode.dispose();
//     _employeeNumberController.dispose();
//     _qrController.dispose();
//     debugPrint("🧹 Disposing Payment Screen...");
//     _removeStateListeners();
//     // Cancel debounce timers
//     for (var timer in _debounceMap.values) {
//       timer?.cancel();
//     }
//     _debounceMap.clear();
//     // Dispose controllers and focus nodes
//     for (final controller in _keyboardControllers) {
//       controller.dispose();
//     }
//     for (final node in _focusNodes) {
//       node.dispose();
//     }
//     _currentFocusIndexNotifier.dispose();
//     // Close WebSocket
//     try {
//       // _channel.sink.close();
//       debugPrint("🔌 WebSocket closed");
//     } catch (e) {
//       debugPrint("⚠️ Error closing WebSocket: $e");
//     }
//     // Reset providers
//     final saleProvider = Provider.of<CurrentSaleProvider>(
//       context,
//       listen: false,
//     );
//     saleProvider.discountPercentage = 0.0;
//     saleProvider.customCharge = 0.0;
//     saleProvider.calculateTotal();
//     final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
//     qrProvider.disconnectWebSocket();
//     qrProvider.isCardPaid = false;
//     qrProvider.errorMessage = null;
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     //stateProvider.reset(); // ✅ This clears all lingering state
//     _employeeNumberController.clear();
//     stateProvider.updateMultiple(
//       cashAmount: 0.0,
//       upiAmount: 0.0,
//       cardAmount: 0.0,
//       isUpiPaid: false,
//       isCardPaid: false,
//       balanceAmount: widget.totalAmount, // reset balance to current bill
//     );
//     super.dispose();
//   }

//   void setupListener(
//     TextEditingController controller, [
//     VoidCallback? extraAction,
//   ]) {
//     controller.addListener(() {
//       debugPrint('1 Listener triggered for ${controller.hashCode}');
//       extraAction?.call();
//       _debounceMap[controller]?.cancel();
//       _debounceMap[controller] = Timer(
//         const Duration(milliseconds: 200),
//         _sendState,
//       );
//     });
//   }

//   Future<void> _openDatePicker() async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate:
//           Provider.of<SalesInvoiceState>(
//             context,
//             listen: false,
//           ).selectedBirthday ??
//           DateTime.now(),
//       firstDate: DateTime(1900),
//       lastDate: DateTime.now(),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: Colors.blue,
//               onPrimary: Colors.white,
//               onSurface: Colors.black,
//             ),
//             dialogBackgroundColor: Colors.white,
//           ),
//           child: child!,
//         );
//       },
//     );
//     if (picked != null && mounted) {
//       Provider.of<SalesInvoiceState>(
//         context,
//         listen: false,
//       ).updateSelectedBirthday(picked);
//       _birthdayController.text = DateFormat('dd-MM-yyyy').format(picked);
//       _handleKeyboardOk();
//     } else {
//       _focusNodes[2].requestFocus();
//     }
//   }

//   void _handleCardPayment() {
//     final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     final cardAmountStr = _customCardController.text;
//     if (cardAmountStr.isNotEmpty) {
//       final cardAmount = double.tryParse(cardAmountStr);
//       if (cardAmount != null && cardAmount > 0) {
//         qrProvider.createOrderAndPay(cardAmount, (
//           String type,
//           Map<String, dynamic>? extraData,
//         ) {
//           _sendState(type: type, extraData: extraData);
//           _sendState(
//             type: 'start_card_payment',
//             extraData: {'amount': cardAmountStr},
//           );
//           if (type == 'card_payment_success') {
//             stateProvider.updateIsCardPaid(true);
//             _customCardController.text = stateProvider.cardAmount
//                 .toStringAsFixed(0);
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(
//                 content: Text('Card payment successful!'),
//                 backgroundColor: Colors.green,
//               ),
//             );
//           } else if (type == 'card_payment_error') {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                   'Card payment failed: ${extraData?['message'] ?? 'Unknown error'}',
//                 ),
//                 backgroundColor: Colors.red,
//               ),
//             );
//           }
//         });
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Please enter a valid card amount greater than 0.'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please enter a card amount first.'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//     }
//   }

//   final Set<String> _loggedInvoices = {};

//   void validateForm() {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     bool isEmployeeSelected =
//         stateProvider.selectedEmployeeFirstName != null &&
//         _employeeNumberController.text.isNotEmpty;
//     bool isCustomerNumberValid = _customerNumberController.text.isNotEmpty;
//     bool isBalanceZeroOrNegative = stateProvider.roundedBalance <= 0;
//     stateProvider.updateIsPrintButtonEnabled(
//       isEmployeeSelected && isCustomerNumberValid && isBalanceZeroOrNegative,
//     );
//   }

//   Future<void> _loadEmployees() async {
//     var box = await Hive.openBox('employeeBox');
//     List<dynamic> employees = box.get('employees', defaultValue: []);
//     // Update _allEmployees without setState
//     _allEmployees = {
//       for (var emp in employees)
//         '${(emp as Map)["employeeNumber"]} - ${(emp as Map)["firstName"]}':
//             (emp as Map).cast<String, dynamic>(),
//     };
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final stateProvider = Provider.of<SalesInvoiceState>(
//         context,
//         listen: false,
//       );
//       stateProvider.updateBalanceAmount(widget.totalAmount);
//       validateForm(); // Re-enable Print button if employee/customer already filled
//     });
//   }

//   void _selectEmployee(String selection) {
//     final employee = _allEmployees[selection];
//     if (employee != null) {
//       final stateProvider = Provider.of<SalesInvoiceState>(
//         context,
//         listen: false,
//       );
//       stateProvider.updateMultiple(
//         selectedEmployeeFirstName: employee['firstName'],
//         selectedEmployeeNumber: employee['employeeNumber'],
//       );
//       _employeeNumberController.text = selection;
//     }
//     validateForm();
//     _moveToNextField(0);
//   }

//   Set<String> _sentInvoices = {};

//   Future<void> loadSentInvoices() async {
//     var box = await Hive.openBox('sentInvoicesBox');
//     _sentInvoices = Set<String>.from(box.get('sentInvoices', defaultValue: []));
//   }

//   Future<void> saveSentInvoices() async {
//     var box = await Hive.openBox('sentInvoicesBox');
//     await box.put('sentInvoices', _sentInvoices.toList());
//   }

//   Future<void> sendBillToCustomer(
//     String invoiceNo,
//     Map<String, dynamic> invoiceData,
//   ) async {
//     final response = await http.post(
//       Uri.parse('https://yenerp.com/fluttertestapi/invoices/api/send-bill'),
//       headers: {'Content-Type': 'application/json'},
//       body: json.encode({'invoiceNo': invoiceNo, 'invoiceData': invoiceData}),
//     );
//     if (response.statusCode == 200) {
//       final result = json.decode(response.body);
//       print('Bill sent: ${result['pdfUrl']}');
//     } else {
//       print('Failed: ${response.body}');
//     }
//   }

//   Map<String, dynamic> normalizeItem(Map<String, dynamic> item) {
//     final variance = item['varianceData'] ?? {};
//     final itemData = item['itemData'] ?? {};

//     return {
//       "itemData": {
//         "itemName":
//             itemData["itemName"] ??
//             item["itemName"] ??
//             variance["varianceName"] ??
//             "Unknown",
//         "tax": itemData["tax"] ?? item["tax"] ?? variance["variancetax"] ?? 0,
//         "item_Uom":
//             itemData["item_Uom"] ??
//             item["uom"] ??
//             variance["variance_Uom"] ??
//             "N/A",
//         "hsnCode": itemData['hsnCode'] ?? item['hsnCode'] ?? 0,
//       },
//       "varianceData": variance,
//       "quantity": item["quantity"] ?? item["qty"] ?? 1,
//       "weight": item["weight"] ?? 0,
//       "itemName": item["itemName"] ?? variance["varianceName"] ?? "Unknown",
//     };
//   }

//   Future<void> saveInvoiceToHiveAndPrint1() async {
//     String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();

//     var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
//     var stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
//     var cartItems = cartProvider.currentSaleItems ?? [];

//     List<String> itemNames = [];
//     List<int> hsnCode = [];
//     List<String> varianceNames = [];
//     List<double> prices = [];
//     List<double> sellingPrices = [];
//     List<double> weights = [];
//     List<int> quantities = [];
//     List<double> amounts = [];
//     List<double> sellingAmounts = [];
//     List<double> taxes = [];
//     List<String> uoms = [];
//     List<String> varianceItemCode = [];
//     List<double> gstRates = [];
//     List<double> gstValues = [];

//     double discount_perc = _discountController.text.isNotEmpty
//         ? double.tryParse(_discountController.text) ?? 0.0
//         : 0.0;

//     List<double> customCharge = _customChargeController.text.isNotEmpty
//         ? [(double.tryParse(_customChargeController.text) ?? 0.0)]
//         : [];

//     double totalItemTotal = 0.0;
//     double totalNet = 0.0;
//     double totalCross = 0.0;
//     double totalDiscountAmount = 0.0;

//     for (var raw in cartItems) {
//       final item = normalizeItem(raw);

//       final itemName = item['itemData']['itemName'] ?? 'N/A';
//       final varianceName = item['varianceData']['varianceName'] ?? 'N/A';
//       final uom =
//           item['varianceData']['variance_Uom'] ??
//           item['itemData']['item_Uom'] ??
//           'N/A';

//       final rate =
//           item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0;

//       double weight = (item['weight'] ?? 0).toDouble();
//       int qty = (item['quantity'] ?? 0).round();

//       if (weight > 0 && qty == 0) qty = 1;

//       final tax = (item['itemData']['tax'] ?? 0).toDouble();

//       // ==============================
//       // ✅ FIXED PRICE CALCULATION
//       // ==============================
//       double actualUnitPrice = uom == "Kgs" ? rate * weight : rate;

//       actualUnitPrice = double.parse(actualUnitPrice.toStringAsFixed(2));

//       double grossAmount = uom == "Kgs"
//           ? actualUnitPrice
//           : actualUnitPrice * qty;

//       // Discount
//       double itemDiscount = grossAmount * (discount_perc / 100);
//       double discountedGross = grossAmount - itemDiscount;

//       // GST split
//       double taxRate = tax / 100;
//       double netExclusive = tax > 0
//           ? discountedGross / (1 + taxRate)
//           : discountedGross;
//       double gstAmount = discountedGross - netExclusive;

//       // Totals
//       totalDiscountAmount += itemDiscount;
//       totalItemTotal += discountedGross;
//       totalNet += netExclusive;

//       // ==============================
//       // PUSH VALUES (FIXED)
//       // ==============================
//       itemNames.add(itemName);
//       varianceNames.add(varianceName);
//       varianceItemCode.add(item['varianceData']['itemCode'] ?? 'N/A');
//       hsnCode.add(item['itemData']['hsnCode'] ?? 0);

//       prices.add(actualUnitPrice);
//       sellingPrices.add(
//         discount_perc > 0
//             ? double.parse(
//                 (actualUnitPrice * (1 - discount_perc / 100)).toStringAsFixed(
//                   2,
//                 ),
//               )
//             : actualUnitPrice,
//       );

//       weights.add(weight);
//       quantities.add(qty);

//       amounts.add(double.parse(grossAmount.toStringAsFixed(2)));
//       sellingAmounts.add(double.parse(discountedGross.toStringAsFixed(2)));

//       taxes.add(tax);
//       uoms.add(uom);
//       gstRates.add(tax);
//       gstValues.add(double.parse(gstAmount.toStringAsFixed(2)));
//     }

//     double totalCustomCharge = customCharge.fold(
//       0.0,
//       (sum, item) => sum + item,
//     );

//     totalCross = totalItemTotal + totalCustomCharge;

//     DateTime billDate = DateTime.now();

//     String uniqueIdentifier =
//         '${DateFormat('dd-MM-yyyy').format(billDate)}-$totalItemTotal-${_customerNumberController.text}';

//     // String customerPhone = _customerNumberController.text
//     //     .split(' - ')
//     //     .first
//     //     .trim();

//     int? customerPhone = int.tryParse(
//       _customerNumberController.text
//           .split(' - ')
//           .first
//           .trim()
//           .replaceAll(RegExp(r'[^0-9]'), ''),
//     );

//     String salesPersonId = stateProvider.selectedEmployeeNumber ?? '';
//     String salesPersonName = stateProvider.selectedEmployeeFirstName ?? '';

//     Map<String, dynamic> invoiceData = {
//       'HiveInvoiceId': hiveInvoiceId,
//       'itemName': itemNames,
//       'varianceitemCode': varianceItemCode,
//       'varianceName': varianceNames,
//       'price': prices,
//       'sellingPrice': sellingPrices,
//       'sellingAmount': sellingAmounts,
//       'weight': weights,
//       'qty': quantities,
//       'amount': amounts,
//       'tax': taxes,
//       'uom': uoms,
//       'salesPersonId': salesPersonId,
//       'salesPersonName': salesPersonName,
//       'customerPhoneNumber': customerPhone,
//       'discountPercentage': int.tryParse(_discountController.text) ?? 0,
//       'customCharge': customCharge,
//       'totalAmount': totalItemTotal,
//       'netAmount': totalNet,
//       'grossAmount': totalCross,
//       'invoiceDateTime': billDate.toIso8601String(),
//       'branchId': "$branchId",
//       'salesType': "TakeAway",
//       'branchName': "$branchName",
//       'aliasName': "$aliasname",
//       'cash': stateProvider.cashAmount > 0 ? stateProvider.cashAmount : null,
//       'card': stateProvider.cardAmount > 0 ? stateProvider.cardAmount : null,
//       'upi': stateProvider.upiAmount > 0 ? stateProvider.upiAmount : null,
//       'others': null,
//       'shiftNumber': int.tryParse(shiftNumber.value) ?? 0,
//       'shiftId': shiftId.value,
//       'invoiceNo': '',
//       'deviceNumber': 1,
//       'sync': "No",
//       'status': "active",
//       'uniqueIdentifier': uniqueIdentifier,
//       'gst': gstRates,
//       'gstValue': gstValues,
//       'discountAmount': totalDiscountAmount > 0 ? totalDiscountAmount : null,
//       'hsnCode': hsnCode,
//     };

//     debugPrint('posInvoice1');
//     // Wrap invoice into JSON
//     final invoiceJson = jsonEncode({
//       "salesOrderId": invoiceData,
//       "type": "invoice",
//       //"sync": "No",
//       "edit": "No",
//     });
//     // String jsonInvoiceData = jsonEncode({'data': invoiceData, 'type': 'posInvoice'});
//     debugPrint('posInvoice2');
//     await sendataToServer(jsonDecode(invoiceJson));
//     debugPrint('posInvoice3 $invoiceJson');

//     // Step 4: Log the invoice data only if it hasn't been logged before
//     if (!_loggedInvoices.contains(uniqueIdentifier)) {
//       _loggedInvoices.add(uniqueIdentifier);
//       developer.log('Invoice Data:', name: 'InvoiceLog');
//       developer.log(invoiceData.toString(), name: 'InvoiceLog');
//     }
//     try {
//       print("ok1233");
//       // Send SMS
//       String customerNumber = _customerNumberController.text;
//       // Extract only the phone number from customerNumber (e.g., "6985748963 - test" -> "6985748963")
//       String phoneNumber = customerNumber
//           .split(' - ')[0]
//           .trim(); // Get the part before " - "
//       if (RegExp(r'^\d{10}$').hasMatch(phoneNumber)) {
//         // Validate it's a 10-digit number
//         String totalAmount = totalItemTotal.toStringAsFixed(
//           0,
//         ); // Use discounted total
//         String billNumber = invoiceData['invoiceNo'];

//         // Send SMS
//         if (isSMSEnabled) {
//           String smsApiUrl =
//               'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK&senderid=BMUMMY&templateid=1707167058380400950&number=$phoneNumber&message=WELCOME TO BESTMUMMY BILL NO:$billNumber BILL AMOUNT: $totalAmount VISIT OUR 45 THANK YOU FOR VISITING AGAIN';

//           var smsResponse = await http.get(Uri.parse(smsApiUrl));
//           if (smsResponse.statusCode == 200) {
//             print('SMS sent successfully to $phoneNumber');
//           } else {
//             print('Failed to send SMS: ${smsResponse.body}');
//           }
//         }

//         // Send WhatsApp message
//         if (isWhatsAppEnabled) {
//           await sendBillToCustomer('', invoiceData);
//         }
//       } else {
//         print('Invalid phone number format: $phoneNumber');
//       }
//     } catch (e) {
//       print('Error posting invoice or sending message: $e');
//     }
//     print("web123");

//     print("web done");
//   }

//   void _applyDiscount(String discount) {
//     final saleProvider = Provider.of<CurrentSaleProvider>(
//       context,
//       listen: false,
//     );
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );

//     // Enforce max 2 digits
//     if (discount.length > 2) {
//       discount = discount.substring(0, 2);
//       _discountController.text = discount;
//       _discountController.selection = TextSelection.fromPosition(
//         TextPosition(offset: discount.length),
//       );
//     }

//     double discountValue = double.tryParse(discount) ?? 0.0;
//     if (discountValue > 99) discountValue = 99;

//     saleProvider.discountPercentage = discountValue;
//     saleProvider.calculateTotal();
//     double newTotal = getTotalWithAdjustments();
//     stateProvider.updateBalanceAmount(newTotal);
//     _recalculatePaymentsOnTotalChange();
//   }

//   // NEW METHOD: Update payment fields when discount changes
//   void _updatePaymentFieldsAfterDiscount() {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     final totalWithAdjustments = getTotalWithAdjustments();

//     // Recalculate payment amounts to maintain balance
//     double totalPayments =
//         stateProvider.cashAmount +
//         stateProvider.upiAmount +
//         stateProvider.cardAmount;

//     // If total payments exceed new total, adjust them
//     if (totalPayments > totalWithAdjustments) {
//       double excess = totalPayments - totalWithAdjustments;

//       // Reduce payments proportionally (simple approach: reduce cash first)
//       if (stateProvider.cashAmount >= excess) {
//         stateProvider.updateCashAmount(stateProvider.cashAmount - excess);
//         _customCashController.text = stateProvider.cashAmount.toStringAsFixed(
//           0,
//         );
//       } else {
//         double remainingExcess = excess - stateProvider.cashAmount;
//         stateProvider.updateCashAmount(0);
//         _customCashController.text = '0';

//         if (stateProvider.upiAmount >= remainingExcess) {
//           stateProvider.updateUpiAmount(
//             stateProvider.upiAmount - remainingExcess,
//           );
//           _customUpiController.text = stateProvider.upiAmount.toStringAsFixed(
//             0,
//           );
//         } else {
//           double finalExcess = remainingExcess - stateProvider.upiAmount;
//           stateProvider.updateUpiAmount(0);
//           _customUpiController.text = '0';

//           stateProvider.updateCardAmount(
//             stateProvider.cardAmount - finalExcess,
//           );
//           _customCardController.text = stateProvider.cardAmount.toStringAsFixed(
//             0,
//           );
//         }
//       }
//     }

//     _updateBalance();
//   }

//   double getTotalWithAdjustments() {
//     double discountValue =
//         (double.tryParse(_discountController.text) ?? 0.0) / 100;
//     double totalCharges =
//         (double.tryParse(_customChargeController.text) ?? 0.0);
//     return (widget.totalAmount * (1 - discountValue)) + totalCharges;
//   }

//   double getRemainingForMethod(String method) {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     double total = getTotalWithAdjustments();
//     double otherPayments = 0.0;

//     // For UPI/Card, exclude the method itself from other payments calculation
//     if (method != 'Cash') otherPayments += stateProvider.cashAmount;
//     if (method != 'Upi') otherPayments += stateProvider.upiAmount;
//     if (method != 'Card') otherPayments += stateProvider.cardAmount;

//     double remaining = total - otherPayments;

//     return remaining;
//   }

//   void _updateBalance() {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );

//     double totalPayments =
//         stateProvider.cashAmount +
//         stateProvider.cardAmount +
//         stateProvider.upiAmount;
//     double totalWithDiscount = getTotalWithAdjustments();

//     // FIXED: Use consistent calculation for balance
//     double rawBalance = totalWithDiscount - totalPayments;
//     stateProvider.updateBalanceAmount(rawBalance);

//     // FIXED: Generate cash options based on absolute remaining balance
//     double amountForOptions = rawBalance.abs();
//     cashOptions.clear();
//     cashOptions.addAll(_generateCashOptions(amountForOptions));

//     validateForm();
//   }

//   List<String> _generateCashOptions(double amount) {
//     if (amount <= 0) return ['0'];

//     List<String> options = [];
//     int exactAmount = amount.ceil();
//     options.add(exactAmount.toString());

//     List<int> denominations = [1, 2, 5, 10, 20, 50, 100, 200, 500];
//     int roundUpTo(int base, int denomination) {
//       return ((base + denomination - 1) ~/ denomination) * denomination;
//     }

//     for (int denom in denominations) {
//       int next = roundUpTo(exactAmount, denom);
//       if (next > exactAmount) {
//         options.add(next.toString());
//       }
//     }

//     options = options.toSet().toList();
//     options.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
//     return options;
//   }

//   void _selectPaymentOption(String method, String amount) {
//   final stateProvider = Provider.of<SalesInvoiceState>(
//     context,
//     listen: false,
//   );

//   double selectedAmount = double.tryParse(amount) ?? 0.0;

//   // Allow clearing the field
//   if (selectedAmount == 0) {
//     switch (method) {
//       case "Cash":
//         stateProvider.updateCashAmount(0);
//         _customCashController.text = '';
//         break;
//       case "Upi":
//         stateProvider.updateUpiAmount(0);
//         _customUpiController.text = '';
//         stateProvider.updateIsUpiPaid(false);
//         break;
//       case "Card":
//         stateProvider.updateCardAmount(0);
//         _customCardController.text = '';
//         final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
//         qrProvider.isCardPaid = false;
//         break;
//     }
//     _updateBalance();
//     return;
//   }

//   // Get current payment values (before applying new amount)
//   double currentCash = stateProvider.cashAmount;
//   double currentUpi = stateProvider.upiAmount;
//   double currentCard = stateProvider.cardAmount;

//   // Temporarily set current method to 0 to calculate "other payments"
//   if (method == "Cash") currentCash = 0;
//   if (method == "Upi") currentUpi = 0;
//   if (method == "Card") currentCard = 0;

//   double otherPayments = currentCash + currentUpi + currentCard;
//   double totalWithAdjustments = getTotalWithAdjustments();
//   double remainingBalance = totalWithAdjustments - otherPayments;

//   // NEW RULE: Check if any digital payment (UPI or Card) is already used
//   bool hasDigitalPayment = stateProvider.upiAmount > 0 || stateProvider.cardAmount > 0;

//   // If we're entering a digital payment now, it will be counted after update
//   if ((method == "Upi" || method == "Card") && selectedAmount > 0) {
//     hasDigitalPayment = true;
//   }

//   // Core Validation
//   if (method == "Upi" || method == "Card") {
//     // Digital payments NEVER allowed to exceed remaining
//     if (selectedAmount > remainingBalance + 0.01) {
//       String methodName = method == "Upi" ? "UPI" : "Card";

//       // Auto-correct to max allowed
//       selectedAmount = remainingBalance;
//       amount = remainingBalance.toStringAsFixed(0);

//       if (method == "Upi") {
//         _customUpiController.text = amount;
//         _customUpiController.selection = TextSelection.fromPosition(
//           TextPosition(offset: amount.length),
//         );
//       } else {
//         _customCardController.text = amount;
//         _customCardController.selection = TextSelection.fromPosition(
//           TextPosition(offset: amount.length),
//         );
//       }

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             "$methodName payment cannot exceed remaining ₹${remainingBalance.toStringAsFixed(0)}",
//           ),
//           backgroundColor: Colors.orange[700],
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     }
//   } 
//   else if (method == "Cash") {
//     // Cash logic: Depends on whether digital payment is involved
//     if (hasDigitalPayment) {
//       // Mixed payment → Cash cannot exceed remaining (no overpayment)
//       if (selectedAmount > remainingBalance + 0.01) {
//         // Auto-correct Cash to exact remaining
//         selectedAmount = remainingBalance;
//         amount = remainingBalance.toStringAsFixed(0);
//         _customCashController.text = amount;
//         _customCashController.selection = TextSelection.fromPosition(
//           TextPosition(offset: amount.length),
//         );

//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Cash cannot exceed remaining when UPI/Card is used"),
//             backgroundColor: Colors.orange,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     } else {
//       // Pure Cash → Allow overpayment
//       if (selectedAmount > remainingBalance + 5000) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("High cash amount entered. Please confirm."),
//             backgroundColor: Colors.orange,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//     }
//   }

//   // Prevent negative amounts
//   if (selectedAmount < 0) {
//     selectedAmount = 0;
//     amount = '0';
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text("Amount cannot be negative"),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }

//   // Apply corrected amount
//   switch (method) {
//     case "Cash":
//       stateProvider.updateCashAmount(selectedAmount);
//       _customCashController.text = selectedAmount.toStringAsFixed(0);
//       break;
//     case "Upi":
//       stateProvider.updateUpiAmount(selectedAmount);
//       _customUpiController.text = selectedAmount.toStringAsFixed(0);
//       break;
//     case "Card":
//       stateProvider.updateCardAmount(selectedAmount);
//       _customCardController.text = selectedAmount.toStringAsFixed(0);
//       break;
//   }

//   _updateBalance();
// }

//   void _recalculatePaymentsOnTotalChange() {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     final totalWithAdjustments = getTotalWithAdjustments();

//     double totalPayments =
//         stateProvider.cashAmount +
//         stateProvider.upiAmount +
//         stateProvider.cardAmount;

//     // FIXED: If total payments exceed new total, adjust ALL payments
//     if (totalPayments > totalWithAdjustments) {
//       double excess = totalPayments - totalWithAdjustments;

//       // FIXED: Clear all payments first and let user re-enter
//       stateProvider.updateCashAmount(0);
//       stateProvider.updateUpiAmount(0);
//       stateProvider.updateCardAmount(0);

//       _customCashController.text = '';
//       _customUpiController.text = '';
//       _customCardController.text = '';

//       // FIXED: Also reset payment status
//       stateProvider.updateIsUpiPaid(false);
//       final qrProvider = Provider.of<RazorpayQRProvider>(
//         context,
//         listen: false,
//       );
//       qrProvider.isCardPaid = false;
//     }

//     // FIXED: Always update balance after recalculation
//     _updateBalance();
//   }

//   void _showUpiQrDialog(double amount, {required VoidCallback onSuccess}) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<RazorpayQRProvider>(context, listen: false).createQR(amount);
//     });

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext qrDialogContext) {
//         return AlertDialog(
//           backgroundColor: Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           title: const Row(
//             children: [
//               Icon(Icons.qr_code, color: Colors.blue),
//               SizedBox(width: 8),
//               Text(
//                 'UPI QR Code',
//                 style: TextStyle(
//                   fontFamily: 'Poppins',
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           content: SizedBox(
//             height: 600,
//             width: 285,
//             child: Consumer2<RazorpayQRProvider, SalesInvoiceState>(
//               builder: (context, qrProvider, stateProvider, _) {
//                 if (qrProvider.isLoading) {
//                   return const Center(child: CircularProgressIndicator());
//                 } else if (qrProvider.errorMessage != null) {
//                   _sendState(
//                     type: 'upi_payment_error',
//                     extraData: {'message': qrProvider.errorMessage},
//                   );
//                   return Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Icon(Icons.error, color: Colors.red, size: 48),
//                       const SizedBox(height: 8),
//                       Text(
//                         qrProvider.errorMessage!,
//                         style: const TextStyle(
//                           fontFamily: 'Poppins',
//                           color: Colors.red,
//                           fontSize: 16,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 16),
//                       ElevatedButton.icon(
//                         icon: const Icon(Icons.close),
//                         label: const Text("Close"),
//                         onPressed: () {
//                           qrProvider.disconnectWebSocket();
//                           Navigator.pop(qrDialogContext);
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color.fromARGB(
//                             255,
//                             6,
//                             62,
//                             247,
//                           ),
//                           foregroundColor: Colors.white,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(7),
//                           ),
//                         ),
//                       ),
//                     ],
//                   );
//                 } else if (qrProvider.paymentSuccess) {
//                   //  Future.delayed(const Duration(milliseconds: 200));
//                   // Provider.of<SalesInvoiceState>(
//                   //   parentContext,
//                   //   listen: false,
//                   // ).updateIsUpiPaid(true);
//                   // // _customUpiController.text = stateProvider.upiAmount
//                   // //     .toStringAsFixed(0);
//                   // _sendState(type: 'upi_payment_success');
//                   // // if (mounted) {
//                   // //   setState(() {});
//                   // // }
//                   // // _updateBalance();
//                   // // validateForm();
//                   // // Future.delayed(const Duration(seconds: 2), () {
//                   // //   if (mounted && Navigator.canPop(qrDialogContext)) {
//                   // //     Navigator.pop(qrDialogContext);
//                   // //   }
//                   // // });
//                   // return Column(
//                   //   mainAxisAlignment: MainAxisAlignment.center,
//                   //   children: [
//                   //     // Lottie.asset(
//                   //     //   'assets/Payment Successful.json',
//                   //     //   repeat: false,
//                   //     //   height: 500,
//                   //     //   width: double.infinity,
//                   //     //   fit: BoxFit.contain,
//                   //     //   onLoaded: (composition) {
//                   //     //     Future.delayed(
//                   //     //       composition.duration + const Duration(seconds: 2),
//                   //     //       () {
//                   //     //         if (mounted) {
//                   //     //           Navigator.pop(context);
//                   //     //         }
//                   //     //       },
//                   //     //     );
//                   //     //   },
//                   //     // ),
//                   //     Column(
//                   //       children: [
//                   //         Center(
//                   //           child: const Text(
//                   //             'UPI Payment Successful!',
//                   //             style: TextStyle(
//                   //               fontFamily: 'Poppins',
//                   //               fontSize: 18,
//                   //               fontWeight: FontWeight.bold,
//                   //               color: Colors.green,
//                   //             ),
//                   //             textAlign: TextAlign.center,
//                   //           ),
//                   //         ),
//                   //         Expanded(
//                   //           child: ElevatedButton.icon(
//                   //             icon: const Icon(Icons.close),
//                   //             label: const Text("Close"),
//                   //             onPressed: () {
//                   //               Navigator.pop(qrDialogContext);
//                   //             },
//                   //             style: ElevatedButton.styleFrom(
//                   //               backgroundColor: const Color.fromARGB(
//                   //                 255,
//                   //                 6,
//                   //                 62,
//                   //                 247,
//                   //               ),
//                   //               foregroundColor: Colors.white,
//                   //               shape: RoundedRectangleBorder(
//                   //                 borderRadius: BorderRadius.circular(7),
//                   //               ),
//                   //             ),
//                   //           ),
//                   //         ),
//                   //       ],
//                   //     ),
//                   //   ],
//                   // );
//                   WidgetsBinding.instance.addPostFrameCallback((_) {
//                     // qrProvider.disconnectWebSocket();
//                     // Navigator.of(context, rootNavigator: true).pop();
//                     onSuccess();
//                     // 🔥 notify parent
//                   });

//                   return Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       // Lottie.asset(
//                       //   'assets/Payment Successful.json',
//                       //   repeat: false,
//                       //   height: 500,
//                       //   width: double.infinity,
//                       //   fit: BoxFit.contain,
//                       //   onLoaded: (composition) {
//                       //     Future.delayed(
//                       //       composition.duration + const Duration(seconds: 2),
//                       //       () {
//                       //         if (mounted) {
//                       //           Navigator.pop(context);
//                       //         }
//                       //       },
//                       //     );
//                       //   },
//                       // ),
//                       Column(
//                         children: [
//                           Center(
//                             child: const Text(
//                               'UPI Payment Successful!',
//                               style: TextStyle(
//                                 fontFamily: 'Poppins',
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.green,
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                           ),
//                           Expanded(
//                             child: ElevatedButton.icon(
//                               icon: const Icon(Icons.close),
//                               label: const Text("Close"),
//                               onPressed: () {
//                                 Navigator.pop(qrDialogContext);
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color.fromARGB(
//                                   255,
//                                   6,
//                                   62,
//                                   247,
//                                 ),
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(7),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   );
//                 } else if (qrProvider.qrImageUrl != null) {
//                   _sendState(
//                     type: 'show_upi_qr',
//                     extraData: {
//                       'qrUrl': qrProvider.qrImageUrl,
//                       'amount': amount,
//                     },
//                   );
//                   return Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Image.network(
//                         qrProvider.qrImageUrl!,
//                         height: 535,
//                         width: double.infinity,
//                         fit: BoxFit.fill,
//                         errorBuilder: (context, error, stackTrace) {
//                           _sendState(
//                             type: 'upi_payment_error',
//                             extraData: {'message': 'Failed to load QR code'},
//                           );
//                           return const Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(Icons.error, color: Colors.red, size: 48),
//                               SizedBox(height: 8),
//                               Text(
//                                 'Failed to load QR code',
//                                 style: TextStyle(
//                                   fontFamily: 'Poppins',
//                                   color: Colors.red,
//                                   fontSize: 16,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ],
//                           );
//                         },
//                       ),
//                       const SizedBox(height: 16),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton.icon(
//                               icon: const Icon(Icons.close),
//                               label: const Text("Close"),
//                               onPressed: () {
//                                 qrProvider.disconnectWebSocket();
//                                 Navigator.pop(qrDialogContext);
//                                 _sendState(type: 'upi_payment_cancelled');
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color.fromARGB(
//                                   255,
//                                   6,
//                                   62,
//                                   247,
//                                 ),
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(7),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   );
//                 } else {
//                   _sendState(
//                     type: 'upi_payment_error',
//                     extraData: {'message': 'No QR code generated'},
//                   );
//                   return const Center(child: Text('No QR generated'));
//                 }
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // In your payment option widget, update this part:
//   Widget _buildPaymentOption(String amount, String method) {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     bool isSelected = stateProvider.selectedPaymentOption == '$method: $amount';

//     TextEditingController controller = method == 'Cash'
//         ? _customCashController
//         : method == 'Upi'
//         ? _customUpiController
//         : _customCardController;

//     bool isUpiPaid = method == 'Upi' && stateProvider.isUpiPaid;
//     bool isCardPaid = method == 'Card' && stateProvider.isCardPaid;
//     bool shouldDisable = isUpiPaid || isCardPaid;

//     if (amount == 'Custom') {
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
//         child: SizedBox(
//           width: 130,
//           height: 50,
//           child: Material(
//             color: Colors.grey.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(8),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     readOnly: shouldDisable,
//                     enabled: !shouldDisable,
//                     controller: controller,
//                     focusNode: _getFocusNodeForController(controller),
//                     keyboardType: TextInputType.none,
//                     decoration: InputDecoration(
//                       enabledBorder: OutlineInputBorder(
//                         borderSide: BorderSide(color: Colors.white, width: 1.5),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: BorderSide(color: Colors.blue, width: 1),
//                       ),
//                       border: const OutlineInputBorder(),

//                       hintText: shouldDisable ? "Paid" : "Enter $method",
//                       fillColor: shouldDisable ? Colors.grey : Colors.grey[100],
//                       filled: true,
//                     ),
//                     onChanged: (v) =>
//                         _selectPaymentOption(method, v.isEmpty ? '0' : v),
//                     onTap: () => !shouldDisable
//                         ? setCurrentFocusForController(controller)
//                         : null,
//                   ),
//                 ),
//                 if (method == 'Upi' || method == 'Card')
//                   IconButton(
//                     icon: Icon(
//                       method == 'Upi' ? Icons.qr_code : Icons.credit_card,
//                       color: shouldDisable ? Colors.grey : Colors.blue,
//                     ),
//                     onPressed: isPaymentEnabled && !shouldDisable
//                         ? () {
//                             final val = controller.text;
//                             final amt = double.tryParse(val);
//                             if (val.isNotEmpty && amt != null && amt > 0) {
//                               method == 'Upi'
//                                   ? _showUpiQrDialog(
//                                       amt,
//                                       onSuccess: () {
//                                         // 🔥 NOW we are OUTSIDE dialog
//                                         Provider.of<SalesInvoiceState>(
//                                           context,
//                                           listen: false,
//                                         ).updateIsUpiPaid(true);

//                                         _customUpiController.text =
//                                             Provider.of<SalesInvoiceState>(
//                                               context,
//                                               listen: false,
//                                             ).upiAmount.toStringAsFixed(0);

//                                         _sendState(type: 'upi_payment_success');
//                                       },
//                                     )
//                                   : _handleCardPayment();
//                             } else {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: Text('Enter valid $method amount'),
//                                 ),
//                               );
//                             }
//                           }
//                         : null,
//                   ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     return Padding(
//       padding: const EdgeInsets.all(8),
//       child: GestureDetector(
//         onTap: shouldDisable
//             ? null
//             : () => _selectPaymentOption(method, amount),
//         child: Container(
//           height: 40,
//           padding: const EdgeInsets.symmetric(horizontal: 12),
//           decoration: BoxDecoration(
//             color: shouldDisable
//                 ? Colors.grey[300]
//                 : (isSelected ? Colors.blue : Colors.white),
//             borderRadius: BorderRadius.circular(6),
//             border: Border.all(
//               color: shouldDisable
//                   ? Colors.grey
//                   : (isSelected ? Colors.blue : Colors.grey.shade300),
//               width: 1.5,
//             ),
//           ),
//           child: Center(
//             child: Text(
//               amount,
//               style: TextStyle(
//                 color: shouldDisable
//                     ? Colors.grey[600]
//                     : (isSelected ? Colors.white : Colors.blue),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildPaymentSection(String method) {
//     double remaining = getRemainingForMethod(method);

//     // For all methods, show exact remaining amount as suggestion
//     String exactStr = remaining > 0 ? remaining.toStringAsFixed(0) : '0';

//     List<String> extraOptions = [];
//     if (method == 'Cash') {
//       final stateProvider = Provider.of<SalesInvoiceState>(
//         context,
//         listen: false,
//       );
//       double amountForOptions = stateProvider.balanceAmount > 0
//           ? stateProvider.balanceAmount
//           : 0.0;
//       extraOptions = _generateCashOptions(amountForOptions).skip(1).toList();
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.start,
//           children: [
//             CustomText(
//               text: method,
//               style: const TextStyle(
//                 fontFamily: 'Poppins',
//                 fontSize: 16,
//                 color: Colors.black,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const CustomSizedBox(width: 20),
//             _buildPaymentOption('Custom', method),
//             // Show exact amount button for all methods
//             _buildPaymentOption(exactStr, method),
//           ],
//         ),
//         // Only show extra options for Cash
//         if (method == 'Cash' && extraOptions.isNotEmpty)
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.start,
//               children: [
//                 for (var option in extraOptions)
//                   _buildPaymentOption(option, method),
//               ],
//             ),
//           ),
//       ],
//     );
//   }

//   FocusNode _getFocusNodeForController(TextEditingController controller) {
//     int index = _keyboardControllers.indexOf(controller);
//     return index >= 0 ? _focusNodes[index] : FocusNode();
//   }

//   void setCurrentFocusForController(TextEditingController controller) {
//     int index = _keyboardControllers.indexOf(controller);
//     if (index >= 0) {
//       _currentFocusIndexNotifier.value = index;
//       _focusNodes[index].requestFocus();

//       if (controller == _customCashController) {
//         double remaining = getRemainingForMethod('Cash');
//         if (remaining > 0) {
//           _selectPaymentOption('Cash', remaining.toStringAsFixed(0));
//         }
//       }
//       // Auto-fill UPI/Card with remaining amount when focused
//       else if (controller == _customUpiController && controller.text.isEmpty) {
//         double remaining = getRemainingForMethod('Upi');
//         if (remaining > 0) {
//           _selectPaymentOption('Upi', remaining.toStringAsFixed(0));
//         }
//       } else if (controller == _customCardController &&
//           controller.text.isEmpty) {
//         double remaining = getRemainingForMethod('Card');
//         if (remaining > 0) {
//           _selectPaymentOption('Card', remaining.toStringAsFixed(0));
//         }
//       } else if (controller == _birthdayController) {
//         _openDatePicker();
//       }
//     }
//   }

//   void _moveToNextField(int currentIndex) {
//     int nextIndex = currentIndex + 1;
//     if (nextIndex == 2 && currentIndex == 0) {
//       nextIndex = 3;
//     }
//     if (nextIndex < _keyboardControllers.length) {
//       _currentFocusIndexNotifier.value = nextIndex;
//       _focusNodes[nextIndex].requestFocus();
//     }
//   }

//   void _handleKeyboardTextInput(String text) {
//     final currentIndex = _currentFocusIndexNotifier.value;
//     final currentController = _keyboardControllers[currentIndex];

//     // If current text is "0" or empty, replace it, otherwise append
//     if (currentController.text == "0" || currentController.text.isEmpty) {
//       currentController.text = text;
//     } else {
//       currentController.text = currentController.text + text;
//     }

//     currentController.selection = TextSelection.fromPosition(
//       TextPosition(offset: currentController.text.length),
//     );

//     _processControllerChange(currentController);
//   }

//   void _clearAllPayments({bool showSnackBar = true}) {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);

//     stateProvider.updateCashAmount(0);
//     stateProvider.updateUpiAmount(0);
//     stateProvider.updateCardAmount(0);
//     stateProvider.updateIsUpiPaid(false);

//     _customCashController.clear();
//     _customUpiController.clear();
//     _customCardController.clear();

//     qrProvider.isCardPaid = false;
//     qrProvider.disconnectWebSocket();
//     _updateBalance();
//   }

//   void _processControllerChange(TextEditingController controller) {
//     if (controller == _discountController) {
//       if (controller.text.isEmpty) {
//         _applyDiscount('0');
//       } else {
//         _applyDiscount(controller.text);
//       }
//     } else if (controller == _customChargeController) {
//       _clearAllPayments();
//     } else if (controller == _customCashController) {
//       _selectPaymentOption(
//         'Cash',
//         controller.text.isEmpty ? '0' : controller.text,
//       );
//     } else if (controller == _customUpiController) {
//       _selectPaymentOption(
//         'Upi',
//         controller.text.isEmpty ? '0' : controller.text,
//       );
//     } else if (controller == _customCardController) {
//       _selectPaymentOption(
//         'Card',
//         controller.text.isEmpty ? '0' : controller.text,
//       );
//     } else {
//       validateForm();
//     }
//   }

//   void _handleKeyboardBackspace() {
//     final currentIndex = _currentFocusIndexNotifier.value;
//     final currentController = _keyboardControllers[currentIndex];

//     if (currentController.text.isNotEmpty) {
//       currentController.text = currentController.text.substring(
//         0,
//         currentController.text.length - 1,
//       );
//       currentController.selection = TextSelection.fromPosition(
//         TextPosition(offset: currentController.text.length),
//       );
//     }

//     _processControllerChange(currentController);
//   }

//   void _handleKeyboardOk() {
//     final currentIndex = _currentFocusIndexNotifier.value;
//     _moveToNextField(currentIndex);
//   }

//   bool _isSubmitting = false;

//   Future<void> _printReceiptDetails() async {
//     if (_isSubmitting) {
//       developer.log('Print already in progress', name: 'SalesInvoice');
//       return;
//     }

//     setState(() {
//       _isSubmitting = true;
//     });

//     try {
//       // === STOCK VALIDATION BEFORE PRINTING ===
//       final globalManager = GlobalDataManager();
//       final branchwiseItemsBox = await Hive.openBox('items');
//       final branchwiseData = await branchwiseItemsBox.get(
//         'branchwiseItems_$aliasname',
//       );

//       Map<dynamic, dynamic>? branchwiseItems = {};
//       if (branchwiseData is Map) {
//         branchwiseItems = Map<dynamic, dynamic>.from(branchwiseData);
//       }

//       List<Map<String, dynamic>> stockCheckList = [];
//       bool hasInsufficient = false;

//       final cartProvider = Provider.of<CurrentSaleProvider>(
//         context,
//         listen: false,
//       );
//       final cartItems = cartProvider.currentSaleItems ?? [];

//       for (var item in cartItems) {
//         final itemName =
//             item['itemName']?.toString() ??
//             item['itemData']?['itemName']?.toString() ??
//             '';
//         final varianceName =
//             item['varianceData']['varianceName']?.toString() ?? 'Unknown Item';
//         final itemUom = (item['varianceData']['variance_Uom']?.toString() ?? '')
//             .toLowerCase();
//         final bool isKg = itemUom.contains('kg');

//         double requiredQty = isKg
//             ? (item['weight'] as num?)?.toDouble() ?? 0.0
//             : (item['quantity'] as num?)?.toDouble() ?? 0.0;

//         double liveStock = globalManager.getSystemStock(
//           aliasname,
//           varianceName,
//         );
//         double availableStock = liveStock >= 0 ? liveStock : 0.0;

//         if (liveStock < 0 &&
//             branchwiseItems != null &&
//             branchwiseItems['data']?[itemName] != null) {
//           final itemData = branchwiseItems['data'][itemName];
//           final varianceMap = itemData['variance'] as Map?;
//           if (varianceMap != null) {
//             for (var v in varianceMap.values) {
//               if (v['varianceName']?.toString() == varianceName) {
//                 availableStock =
//                     (v['branchwise']?[aliasname]?['systemStock_$aliasname']
//                             as num?)
//                         ?.toDouble() ??
//                     0.0;
//                 break;
//               }
//             }
//           }
//         }

//         final bool sufficient = requiredQty <= availableStock + 0.001;
//         if (!sufficient) hasInsufficient = true;

//         stockCheckList.add({
//           'item': varianceName,
//           'required': requiredQty,
//           'available': availableStock,
//           'uom': isKg ? 'kg' : 'pcs',
//           'status': sufficient ? 'OK' : 'Insufficient',
//           'isKg': isKg,
//         });
//       }

//       // === SHOW INSUFFICIENT STOCK DIALOG IF NEEDED ===
//       if (hasInsufficient) {
//         final List<Map<String, dynamic>> insufficientItems = stockCheckList
//             .where((row) => row['status'] == 'Insufficient')
//             .toList();

//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (ctx) => Dialog(
//             alignment: Alignment.center,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//             ),
//             elevation: 30,
//             backgroundColor: Colors.transparent,
//             child: Container(
//               width: MediaQuery.of(context).size.width * 0.7,
//               constraints: const BoxConstraints(maxHeight: 700),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                   colors: [Colors.white, Colors.grey.shade50],
//                 ),
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.2),
//                     blurRadius: 30,
//                     offset: const Offset(0, 15),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Header
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.symmetric(
//                       vertical: 20,
//                       horizontal: 24,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.red.shade600,
//                       borderRadius: const BorderRadius.vertical(
//                         top: Radius.circular(20),
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(
//                           Icons.warning_amber_rounded,
//                           color: Colors.white,
//                           size: 40,
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 "Insufficient Stock",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 22,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 "The following items exceed available stock.",
//                                 style: TextStyle(
//                                   color: Colors.white.withOpacity(0.9),
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   // Body - Only Insufficient Items
//                   Flexible(
//                     child: Padding(
//                       padding: const EdgeInsets.all(24),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const SizedBox(height: 10),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               vertical: 14,
//                               horizontal: 12,
//                             ),
//                             decoration: BoxDecoration(
//                               color: Colors.red.shade700,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   flex: 5,
//                                   child: Text(
//                                     "Item",
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 15,
//                                     ),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 2,
//                                   child: Center(
//                                     child: Text(
//                                       "Required",
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 15,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 2,
//                                   child: Center(
//                                     child: Text(
//                                       "Available",
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 15,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 2,
//                                   child: Center(
//                                     child: Text(
//                                       "Shortage",
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 15,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                           Flexible(
//                             child: ListView.separated(
//                               shrinkWrap: true,
//                               separatorBuilder: (_, __) =>
//                                   const SizedBox(height: 10),
//                               itemCount: insufficientItems.length,
//                               itemBuilder: (context, i) {
//                                 final row = insufficientItems[i];
//                                 final double shortage =
//                                     (row['required'] as double) -
//                                     (row['available'] as double);
//                                 return Container(
//                                   padding: const EdgeInsets.symmetric(
//                                     vertical: 16,
//                                     horizontal: 12,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     color: Colors.red.shade50,
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(
//                                       color: Colors.red.shade300,
//                                       width: 1.8,
//                                     ),
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       Expanded(
//                                         flex: 5,
//                                         child: Text(
//                                           row['item'],
//                                           style: TextStyle(
//                                             fontWeight: FontWeight.w600,
//                                             fontSize: 15,
//                                             color: Colors.red.shade900,
//                                           ),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: Center(
//                                           child: Text(
//                                             "${row['required'].toStringAsFixed(row['isKg'] ? 3 : 0)} ${row['uom']}",
//                                             style: TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.red.shade800,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: Center(
//                                           child: Text(
//                                             "${row['available'].toStringAsFixed(row['isKg'] ? 3 : 0)} ${row['uom']}",
//                                             style: TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.red.shade800,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: Center(
//                                           child: Container(
//                                             padding: const EdgeInsets.symmetric(
//                                               horizontal: 16,
//                                               vertical: 8,
//                                             ),
//                                             decoration: BoxDecoration(
//                                               color: Colors.red.shade600,
//                                               borderRadius:
//                                                   BorderRadius.circular(20),
//                                             ),
//                                             child: Text(
//                                               "-${shortage.toStringAsFixed(row['isKg'] ? 3 : 0)}",
//                                               style: const TextStyle(
//                                                 color: Colors.white,
//                                                 fontWeight: FontWeight.bold,
//                                                 fontSize: 14,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   // Footer
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
//                     child: SizedBox(
//                       width: double.infinity,
//                       height: 56,
//                       child: ElevatedButton(
//                         onPressed: () => Navigator.pop(ctx),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.red.shade600,
//                           foregroundColor: Colors.white,
//                           elevation: 8,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(14),
//                           ),
//                         ),
//                         child: const Text(
//                           "Close & Adjust Quantities",
//                           style: TextStyle(
//                             fontSize: 17,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );

//         setState(() {
//           _isSubmitting = false;
//         });
//         return; // Stop printing
//       }

//       // === ALL STOCK OK → PROCEED TO PRINT ===
//       await saveInvoiceToHiveAndPrint1();

//       //final cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
//       cartProvider.clearItems();

//       Navigator.of(context).pop();
//     } catch (e, stack) {
//       developer.log(
//         'Print/Save failed',
//         name: 'SalesInvoice',
//         error: e,
//         stackTrace: stack,
//       );
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Print failed: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       final stateProvider = Provider.of<SalesInvoiceState>(
//         context,
//         listen: false,
//       );
//       stateProvider.reset();

//       final qrProvider = Provider.of<RazorpayQRProvider>(
//         context,
//         listen: false,
//       );
//       qrProvider.disconnectWebSocket();
//       qrProvider.isCardPaid = false;
//       qrProvider.errorMessage = null;

//       setState(() {
//         _isSubmitting = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     debugPrint('entered1');
//     return Stack(
//       children: [
//         Scaffold(
//           backgroundColor: Colors.white,
//           body: RepaintBoundary(
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CustomText(
//                       text: 'Payment Details',
//                       style: const TextStyle(
//                         fontFamily: 'Poppins',
//                         fontSize: 32,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black,
//                       ),
//                     ),
//                     const CustomSizedBox(height: 20),

//                     /// Sales Person + Birthday Row
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Consumer<SalesInvoiceState>(
//                           builder: (context, p, _) {
//                             return Expanded(
//                               flex: 2,
//                               child: Material(
//                                 elevation: 4,
//                                 shadowColor: Colors.black,
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 child: Stack(
//                                   children: [
//                                     Autocomplete<String>(
//                                       optionsMaxHeight: 120,
//                                       optionsViewBuilder:
//                                           (context, onSelected, options) {
//                                             return Material(
//                                               color: Colors.white,
//                                               shadowColor: Colors.black,
//                                               elevation: 4,
//                                               borderRadius:
//                                                   const BorderRadius.only(
//                                                     bottomLeft: Radius.circular(
//                                                       8,
//                                                     ),
//                                                     bottomRight:
//                                                         Radius.circular(8),
//                                                   ),
//                                               child: ListView.separated(
//                                                 separatorBuilder:
//                                                     (context, index) =>
//                                                         const Divider(
//                                                           thickness: 1,
//                                                           color: Colors.black12,
//                                                         ),
//                                                 shrinkWrap: true,
//                                                 itemCount: options.length,
//                                                 itemBuilder: (context, index) {
//                                                   final option = options
//                                                       .elementAt(index);
//                                                   return ListTile(
//                                                     title: Text(option),
//                                                     onTap: () =>
//                                                         onSelected(option),
//                                                   );
//                                                 },
//                                               ),
//                                             );
//                                           },
//                                       optionsBuilder: (textEditingValue) {
//                                         if (textEditingValue.text.isEmpty) {
//                                           return const Iterable<String>.empty();
//                                         }
//                                         final query = textEditingValue.text
//                                             .toLowerCase();
//                                         return _allEmployees.keys.where(
//                                           (key) =>
//                                               key.toLowerCase().contains(query),
//                                         );
//                                       },
//                                       onSelected: (String selection) =>
//                                           _selectEmployee(selection),
//                                       fieldViewBuilder:
//                                           (
//                                             context,
//                                             controllers,
//                                             focusNode,
//                                             onFieldSubmitted,
//                                           ) {
//                                             controllers.value =
//                                                 _employeeNumberController.value;
//                                             return TextFormField(
//                                               readOnly: true,
//                                               showCursor: true,
//                                               controller:
//                                                   _employeeNumberController,
//                                               focusNode: focusNode,
//                                               onTap: () =>
//                                                   setCurrentFocusForController(
//                                                     _employeeNumberController,
//                                                   ),
//                                               decoration: InputDecoration(
//                                                 labelText: "Sales Person",
//                                                 labelStyle: const TextStyle(
//                                                   fontFamily: 'Poppins',
//                                                   color: Colors.black54,
//                                                 ),
//                                                 border: OutlineInputBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(8),
//                                                 ),
//                                                 focusedBorder:
//                                                     OutlineInputBorder(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             8,
//                                                           ),
//                                                       borderSide:
//                                                           const BorderSide(
//                                                             color: Colors.blue,
//                                                             width: 1,
//                                                           ),
//                                                     ),
//                                                 enabledBorder:
//                                                     OutlineInputBorder(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             8,
//                                                           ),
//                                                       borderSide:
//                                                           const BorderSide(
//                                                             color:
//                                                                 Colors.black12,
//                                                           ),
//                                                     ),
//                                                 contentPadding:
//                                                     const EdgeInsets.symmetric(
//                                                       vertical: 15,
//                                                       horizontal: 10,
//                                                     ),
//                                                 suffixIcon: IconButton(
//                                                   icon: const Icon(
//                                                     Icons.qr_code_scanner,
//                                                   ),
//                                                   onPressed: _toggleQrMode,
//                                                   tooltip: 'Scan Employee QR',
//                                                 ),
//                                               ),
//                                             );
//                                           },
//                                     ),
//                                     if (_isQrMode)
//                                       Offstage(
//                                         offstage: true,
//                                         child: TextField(
//                                           focusNode: _qrFocusNode,
//                                           controller: _qrController,
//                                           keyboardType: TextInputType.none,
//                                           onSubmitted: _handleQrInput,
//                                           decoration: const InputDecoration(
//                                             border: InputBorder.none,
//                                           ),
//                                           style: const TextStyle(
//                                             fontFamily: 'Poppins',
//                                             fontSize: 0,
//                                           ),
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               controller: _birthdayController,
//                               focusNode: _getFocusNodeForController(
//                                 _birthdayController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _birthdayController,
//                               ),
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               decoration: InputDecoration(
//                                 labelText: "Birthday Date",
//                                 labelStyle: const TextStyle(
//                                   fontFamily: 'Poppins',
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               controller: _customChargeController,
//                               focusNode: _getFocusNodeForController(
//                                 _customChargeController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _customChargeController,
//                               ),
//                               inputFormatters: [
//                                 FilteringTextInputFormatter.digitsOnly,
//                               ],
//                               decoration: InputDecoration(
//                                 prefixText: "₹",
//                                 labelText: "Custom Charge",
//                                 labelStyle: const TextStyle(
//                                   fontFamily: 'Poppins',
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                               onChanged: (value) {
//                                 double charge = double.tryParse(value) ?? 0.0;
//                                 _updateBalance();
//                               },
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 20),

//                     /// Customer + Discount + Custom Charge Row
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         SizedBox(
//                           width: 300,
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: CustomerSearchDropdown(
//                               showTopProducts: false,
//                               customerNumberController:
//                                   _customerNumberController,
//                               focusNode: _getFocusNodeForController(
//                                 _customerNumberController,
//                               ),
//                               readOnly: true,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               controller: _discountController,
//                               focusNode: _getFocusNodeForController(
//                                 _discountController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _discountController,
//                               ),
//                               inputFormatters: [
//                                 FilteringTextInputFormatter.digitsOnly,
//                               ],
//                               decoration: InputDecoration(
//                                 prefixIcon: const Icon(Icons.percent),
//                                 labelText: "Discount",
//                                 labelStyle: const TextStyle(
//                                   fontFamily: 'Poppins',
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                               onChanged: (value) {
//                                 if (value.isEmpty) {
//                                   _applyDiscount('0');
//                                 } else if (value.length > 2) {
//                                   _discountController.text = value.substring(
//                                     0,
//                                     2,
//                                   );
//                                   _discountController
//                                       .selection = TextSelection.fromPosition(
//                                     TextPosition(
//                                       offset: _discountController.text.length,
//                                     ),
//                                   );
//                                   _applyDiscount(_discountController.text);
//                                 } else {
//                                   _applyDiscount(value);
//                                 }
//                               },
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               controller: _couponCodeController,
//                               focusNode: _getFocusNodeForController(
//                                 _couponCodeController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _couponCodeController,
//                               ),
//                               inputFormatters: [
//                                 FilteringTextInputFormatter.digitsOnly,
//                               ],
//                               decoration: InputDecoration(
//                                 prefixIcon: Icon(Icons.local_offer_outlined),
//                                 labelText: "Coupon Code",
//                                 labelStyle: const TextStyle(
//                                   fontFamily: 'Poppins',
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                               onChanged: (value) {
//                                 double charge = double.tryParse(value) ?? 0.0;
//                                 _updateBalance();
//                               },
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const CustomSizedBox(height: 20),

//                     /// Payment Section + Numeric Keyboard
//                     Consumer<SalesInvoiceState>(
//                       builder: (context, prov, _) {
//                         return Row(
//                           children: [
//                             Expanded(
//                               flex: 2,
//                               child: Column(
//                                 children: [
//                                   Padding(
//                                     padding: const EdgeInsets.only(
//                                       left: 10,
//                                       bottom: 20,
//                                     ),
//                                     child: Material(
//                                       elevation: 4,
//                                       shadowColor: Colors.black,
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(8),
//                                       child: Padding(
//                                         padding: const EdgeInsets.only(
//                                           left: 10,
//                                         ),
//                                         child: _buildPaymentSection('Cash'),
//                                       ),
//                                     ),
//                                   ),
//                                   Padding(
//                                     padding: const EdgeInsets.only(
//                                       left: 10,
//                                       bottom: 20,
//                                     ),
//                                     child: Material(
//                                       elevation: 4,
//                                       shadowColor: Colors.black,
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(8),
//                                       child: Padding(
//                                         padding: const EdgeInsets.only(
//                                           left: 20,
//                                         ),
//                                         child: _buildPaymentSection('Upi'),
//                                       ),
//                                     ),
//                                   ),
//                                   Padding(
//                                     padding: const EdgeInsets.only(
//                                       left: 10,
//                                       bottom: 20,
//                                     ),
//                                     child: Material(
//                                       elevation: 4,
//                                       shadowColor: Colors.black,
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(8),
//                                       child: Padding(
//                                         padding: const EdgeInsets.only(
//                                           left: 10,
//                                         ),
//                                         child: _buildPaymentSection('Card'),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const VerticalDivider(width: 20, thickness: 1),
//                             Expanded(
//                               flex: 2,
//                               child: ValueListenableBuilder<int>(
//                                 valueListenable: _currentFocusIndexNotifier,
//                                 builder: (context, currentFocusIndex, _) {
//                                   return Column(
//                                     children: [
//                                       Container(
//                                         constraints: const BoxConstraints(
//                                           maxWidth: 300,
//                                         ),
//                                         child: NumericKeyboard(
//                                           focusNode:
//                                               _focusNodes[currentFocusIndex],
//                                           controller:
//                                               _keyboardControllers[currentFocusIndex],
//                                           onTextInput: _handleKeyboardTextInput,
//                                           onBackspace: _handleKeyboardBackspace,
//                                           onOk: _handleKeyboardOk,
//                                           isLastField:
//                                               currentFocusIndex ==
//                                               _keyboardControllers.length - 1,
//                                         ),
//                                       ),
//                                       const SizedBox(height: 10),
//                                     ],
//                                   );
//                                 },
//                               ),
//                             ),
//                           ],
//                         );
//                       },
//                     ),
//                     const CustomSizedBox(height: 10),

//                     /// Mini Cards + Print Button
//                     Consumer2<CurrentSaleProvider, SalesInvoiceState>(
//                       builder: (context, salesProvider, statesProvider, _) {
//                         // FIXED: Proper balance display logic
//                         final double rawBalance = statesProvider.balanceAmount;
//                         final String balanceDisplay;
//                         if (rawBalance < 0) {
//                           balanceDisplay =
//                               "-₹${rawBalance.abs().toStringAsFixed(0)}";
//                         } else if (rawBalance == 0) {
//                           balanceDisplay = "₹0";
//                         } else {
//                           balanceDisplay = "₹${rawBalance.toStringAsFixed(0)}";
//                         }

//                         return Row(
//                           children: [
//                             _buildMiniCard(
//                               title: "Total",
//                               value:
//                                   "₹${getTotalWithAdjustments().toStringAsFixed(0)}",
//                               gradient: [Colors.blue[200]!, Colors.blue[500]!],
//                             ),
//                             const SizedBox(width: 5),
//                             _buildMiniCard(
//                               title: "Balance",
//                               value: balanceDisplay,
//                               gradient: [Colors.blue[200]!, Colors.blue[500]!],
//                             ),
//                             const SizedBox(width: 10),
//                             SizedBox(
//                               height: 75,
//                               width: 300,
//                               child: ElevatedButton(
//                                 style: ButtonStyle(
//                                   backgroundColor: MaterialStateProperty.all(
//                                     statesProvider.isPrintButtonEnabled
//                                         ? Colors.blue
//                                         : Colors.grey,
//                                   ),
//                                   foregroundColor: MaterialStateProperty.all(
//                                     Colors.white,
//                                   ),
//                                   padding: MaterialStateProperty.all(
//                                     const EdgeInsets.symmetric(
//                                       horizontal: 30.0,
//                                       vertical: 18.0,
//                                     ),
//                                   ),
//                                   shape:
//                                       MaterialStateProperty.all<
//                                         RoundedRectangleBorder
//                                       >(
//                                         RoundedRectangleBorder(
//                                           borderRadius: BorderRadius.circular(
//                                             8.0,
//                                           ),
//                                         ),
//                                       ),
//                                   elevation: MaterialStateProperty.all(5.0),
//                                 ),
//                                 onPressed: statesProvider.isPrintButtonEnabled
//                                     ? () async {
//                                         Future.microtask(
//                                           () => _printReceiptDetails(),
//                                         );
//                                       }
//                                     : null,
//                                 child: const CustomText(
//                                   text: "Print Receipt",
//                                   style: TextStyle(
//                                     fontFamily: 'Poppins',
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         );
//                       },
//                     ),
//                     const CustomSizedBox(height: 10),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//         if (_isSubmitting)
//           Positioned.fill(
//             child: Stack(
//               children: [
//                 // Block touches but keep background visible
//                 const ModalBarrier(
//                   dismissible: false,
//                   color: Colors.transparent, // keep original background visible
//                 ),

//                 // Center loader
//                 const Center(
//                   child: CircularProgressIndicator(color: Colors.blue),
//                 ),
//               ],
//             ),
//           ),
//       ],
//     );
//   }
// }

// Widget _buildMiniCard({
//   required String title,
//   required String value,
//   required List<Color> gradient,
// }) {
//   return Expanded(
//     child: Container(
//       height: 80,
//       margin: const EdgeInsets.symmetric(horizontal: 4),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: gradient,
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey[400]!,
//             offset: const Offset(2, 2),
//             blurRadius: 6,
//           ),
//           const BoxShadow(
//             color: Colors.white,
//             offset: Offset(-2, -2),
//             blurRadius: 6,
//           ),
//         ],
//       ),
//       padding: const EdgeInsets.all(8),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           FittedBox(
//             fit: BoxFit.scaleDown,
//             child: Text(
//               title,
//               style: const TextStyle(
//                 fontFamily: 'Poppins',
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.black87,
//               ),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           const SizedBox(height: 4),
//           FittedBox(
//             fit: BoxFit.scaleDown,
//             child: Text(
//               value,
//               style: const TextStyle(
//                 fontFamily: 'Poppins',
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// class SalesInvoicePayAndPrint extends StatefulWidget {
//   final double totalAmount;
//   final String holdBillId;
//   final VoidCallback? onDismiss;
//   final String customerNumber;
//   const SalesInvoicePayAndPrint({
//     super.key,
//     required this.totalAmount,
//     required this.holdBillId,
//     this.customerNumber = '',
//     this.onDismiss,
//   });
//   @override
//   State<SalesInvoicePayAndPrint> createState() =>
//       SalesInvoicePayAndPrintState();
// }
// class SalesInvoicePayAndPrintState extends State<SalesInvoicePayAndPrint> {
//   final InvoiceService _invoiceService = InvoiceService();
//   final List<String> cashOptions = [];
//   final TextEditingController _customAmountController = TextEditingController();
//   final TextEditingController _employeeNumberController =
//       TextEditingController();
//   Map<String, Map<String, dynamic>> _allEmployees = {};
//   final TextEditingController _customerNumberController =
//       TextEditingController();
//   final TextEditingController _discountController = TextEditingController();
//   final TextEditingController _couponCodeController = TextEditingController();
//   final TextEditingController _customChargeController = TextEditingController();
//   final TextEditingController _customCashController = TextEditingController();
//   final TextEditingController _customUpiController = TextEditingController();
//   final TextEditingController _customCardController = TextEditingController();
//   final TextEditingController _birthdayController = TextEditingController();
//   late List<FocusNode> _focusNodes;
//   late ValueNotifier<int> _currentFocusIndexNotifier;
//   late List<TextEditingController> _keyboardControllers;
//   late WebSocketChannel _channel;
//   bool _isInitialSend = true;
//   SalesInvoiceState get prov =>
//       Provider.of<SalesInvoiceState>(context, listen: false);
//   bool _isPrinting = false; // ← Loading state
//   @override
//   void initState() {
//     super.initState();
//     // Connect WebSocket safely
//     final uri = Uri.parse('ws://$serverip:$port');
//     _channel = WebSocketChannel.connect(uri);
//     debugPrint("✅ WebSocket connected to $uri");
//     if (widget.customerNumber.isNotEmpty) {
//       _customerNumberController.text = widget.customerNumber;
//     }
//     if (prov.employee.text.isNotEmpty) {
//       _employeeNumberController.text = prov.employee.text;
//     }
//     // Setup controllers
//     _keyboardControllers = [
//       _employeeNumberController,
//       _customerNumberController,
//       _discountController,
//       _customChargeController,
//       _customCashController,
//       _customUpiController,
//       _customCardController,
//       _couponCodeController,
//       _birthdayController,
//     ];
//     // Setup focus nodes
//     _focusNodes = List.generate(
//       _keyboardControllers.length,
//       (_) => FocusNode(),
//     );
//     _currentFocusIndexNotifier = ValueNotifier<int>(0);
//     // Listen to focus changes (only once)
//     for (int i = 0; i < _focusNodes.length; i++) {
//       _focusNodes[i].addListener(() {
//         if (_focusNodes[i].hasFocus) {
//           _currentFocusIndexNotifier.value = i;
//         }
//       });
//     }
//     // WebSocket listener (store subscription if you want to cancel)
//     _channel.stream.listen(
//       (data) {
//         debugPrint("Received WebSocket data: $data");
//       },
//       onError: (error) {
//         debugPrint("❌ WebSocket error: $error");
//       },
//     );
//     // Setup providers
//     final saleState = Provider.of<SalesInvoiceState>(context, listen: false);
//     saleState.updateBalanceAmount(widget.totalAmount);
//     cashOptions.addAll(_generateCashOptions(widget.totalAmount));
//     _loadEmployees();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _sendState();
//     });
//   }
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     // Remove any old listener first
//     _customerNumberController.removeListener(_safeCustomerNumberLimiter);
//     // Add NEW safe listener that NEVER touches "Mobile - Name
//     _customerNumberController.addListener(_safeCustomerNumberLimiter);
//   }
//   void _safeCustomerNumberLimiter() {
//     final currentText = _customerNumberController.text;
//     // CRITICAL: If customer is already selected (has " - Name"), DO NOT modify text!
//     if (currentText.contains(' - ') &&
//         currentText.split(' - ').length > 1 &&
//         currentText.split(' - ')[1].trim().isNotEmpty) {
//       return;
//     }
//     // Only limit digits when user is typing a fresh mobile number
//     String digitsOnly = currentText.replaceAll(RegExp(r'\D'), '');
//     if (digitsOnly.length > 10) {
//       digitsOnly = digitsOnly.substring(0, 10);
//     }
//     if (digitsOnly != currentText) {
//       _customerNumberController.value = TextEditingValue(
//         text: digitsOnly,
//         selection: TextSelection.collapsed(offset: digitsOnly.length),
//       );
//     }
//   }
//   Timer? _debounce;
//   Map<String, dynamic> _lastSentData = {};
//   final Map<TextEditingController, Timer?> _debounceMap = {};
//   bool _listenersAdded = false;
//   void _sendState({
//     String type = 'state_update',
//     Map<String, dynamic>? extraData,
//   }) {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     final currentData = {
//       'isUpiPaid': stateProvider.isUpiPaid,
//       'isCardPaid': stateProvider.isCardPaid,
//       if (extraData != null) ...extraData,
//     };
//     final changedFields = <String, dynamic>{};
//     if (_isInitialSend) {
//       _isInitialSend = false;
//     } else {
//       currentData.forEach((key, value) {
//         if (_lastSentData[key] != value) {
//           changedFields[key] = value;
//         }
//       });
//     }
//     if (changedFields.isEmpty) return; // nothing changed
//     _lastSentData.addAll(changedFields);
//     final message = {
//       'message': 'changed_fields',
//       'type': type,
//       ...changedFields,
//     };
//     try {
//       final jsonData = jsonEncode(message);
//       sendataToServer(jsonDecode(jsonData));
//       developer.log('Sent: $jsonData', name: 'WebSocket');
//     } catch (e) {
//       debugPrint('❌ Error sending data: $e');
//     }
//   }
//   void _removeStateListeners() {
//     _employeeNumberController.removeListener(() {});
//     _customerNumberController.removeListener(() {});
//     _customAmountController.removeListener(() {});
//     _discountController.removeListener(() {});
//     _customChargeController.removeListener(() {});
//     _customCashController.removeListener(() {});
//     _customUpiController.removeListener(() {});
//     _customCardController.removeListener(() {});
//     _birthdayController.removeListener(() {});
//     _couponCodeController.removeListener(() {});
//   }
//   // ------------------- QR STATE -------------------
//   bool _isQrMode = false;
//   final FocusNode _qrFocusNode = FocusNode();
//   final TextEditingController _qrController = TextEditingController();
//   bool _isProcessingQr = false;
//   // ------------------- QR TOGGLE -------------------
//   Future<void> _toggleQrMode() async {
//     final isPOS = await POSDetector.isPOSDevice;
//     if (isPOS) {
//       _startHardwareScanner();
//     } else {
//       _startCameraScan();
//     }
//   }
//   // POS Hardware Scanner
//   void _startHardwareScanner() {
//     setState(() {
//       _isQrMode = true;
//       _qrFocusNode.requestFocus();
//     });
//   }
//   // Camera Scanner
//   Future<void> _startCameraScan() async {
//     final result = await Navigator.of(context).push<String>(
//       MaterialPageRoute(builder: (_) => const QRCodeScannerScreen()),
//     );
//     if (result != null && result.isNotEmpty) {
//       _handleQrInput(result);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No QR code scanned.'),
//           duration: Duration(seconds: 1),
//         ),
//       );
//     }
//   }
//   // ------------------- QR INPUT HANDLER -------------------
//   void _handleQrInput(String raw) async {
//     if (_isProcessingQr || !_isQrMode) return;
//     setState(() => _isProcessingQr = true);
//     try {
//       final data = _parseQrData(raw);
//       final name = data['Name']?.toString().trim();
//       if (name == null) throw Exception('Name not found');
//       final match = _allEmployees.entries.firstWhereOrNull(
//         (e) => e.key.contains(name),
//       );
//       if (match != null) {
//         _selectEmployee(match.key);
//         _employeeNumberController.selection = TextSelection.fromPosition(
//           TextPosition(offset: match.key.length),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Employee not found in list.')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('QR Error: $e')));
//     } finally {
//       _qrController.clear();
//       _qrFocusNode.unfocus();
//       setState(() {
//         _isProcessingQr = false;
//         _isQrMode = false;
//       });
//     }
//   }
//   // ------------------- QR PARSING -------------------
//   Map<String, dynamic> _parseQrData(String raw) {
//     try {
//       return json.decode(raw) as Map<String, dynamic>;
//     } catch (_) {
//       final map = <String, dynamic>{};
//       raw.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
//         final kv = pair.split(':');
//         if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
//       });
//       if (map.isEmpty) throw Exception('Invalid QR format');
//       return map;
//     }
//   }
//   @override
//   void dispose() {
//     _qrFocusNode.dispose();
//     _employeeNumberController.dispose();
//     _qrController.dispose();
//     debugPrint("🧹 Disposing Payment Screen...");
//     _removeStateListeners();
//     // Cancel debounce timers
//     for (var timer in _debounceMap.values) {
//       timer?.cancel();
//     }
//     _debounceMap.clear();
//     // Dispose controllers and focus nodes
//     for (final controller in _keyboardControllers) {
//       controller.dispose();
//     }
//     for (final node in _focusNodes) {
//       node.dispose();
//     }
//     _currentFocusIndexNotifier.dispose();
//     // Close WebSocket
//     try {
//       // _channel.sink.close();
//       debugPrint("🔌 WebSocket closed");
//     } catch (e) {
//       debugPrint("⚠️ Error closing WebSocket: $e");
//     }
//     // Reset providers
//     final saleProvider = Provider.of<CurrentSaleProvider>(
//       context,
//       listen: false,
//     );
//     saleProvider.discountPercentage = 0.0;
//     saleProvider.customCharge = 0.0;
//     saleProvider.calculateTotal();
//     final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
//     qrProvider.disconnectWebSocket();
//     qrProvider.isCardPaid = false;
//     qrProvider.errorMessage = null;
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     stateProvider.reset(); // ✅ This clears all lingering state
//     _employeeNumberController.clear();
//     stateProvider.updateMultiple(
//       cashAmount: 0.0,
//       upiAmount: 0.0,
//       cardAmount: 0.0,
//       isUpiPaid: false,
//       isCardPaid: false,
//       balanceAmount: widget.totalAmount, // reset balance to current bill
//     );
//     super.dispose();
//   }
//   void setupListener(
//     TextEditingController controller, [
//     VoidCallback? extraAction,
//   ]) {
//     controller.addListener(() {
//       debugPrint('1 Listener triggered for ${controller.hashCode}');
//       extraAction?.call();
//       _debounceMap[controller]?.cancel();
//       _debounceMap[controller] = Timer(
//         const Duration(milliseconds: 200),
//         _sendState,
//       );
//     });
//   }
//   Future<void> _openDatePicker() async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate:
//           Provider.of<SalesInvoiceState>(
//             context,
//             listen: false,
//           ).selectedBirthday ??
//           DateTime.now(),
//       firstDate: DateTime(1900),
//       lastDate: DateTime.now(),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: Colors.blue,
//               onPrimary: Colors.white,
//               onSurface: Colors.black,
//             ),
//             dialogBackgroundColor: Colors.white,
//           ),
//           child: child!,
//         );
//       },
//     );
//     if (picked != null && mounted) {
//       Provider.of<SalesInvoiceState>(
//         context,
//         listen: false,
//       ).updateSelectedBirthday(picked);
//       _birthdayController.text = DateFormat('dd-MM-yyyy').format(picked);
//       _handleKeyboardOk();
//     } else {
//       _focusNodes[2].requestFocus();
//     }
//   }
//   void _handleCardPayment() {
//     final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     final cardAmountStr = _customCardController.text;
//     if (cardAmountStr.isNotEmpty) {
//       final cardAmount = double.tryParse(cardAmountStr);
//       if (cardAmount != null && cardAmount > 0) {
//         qrProvider.createOrderAndPay(cardAmount, (
//           String type,
//           Map<String, dynamic>? extraData,
//         ) {
//           _sendState(type: type, extraData: extraData);
//           _sendState(
//             type: 'start_card_payment',
//             extraData: {'amount': cardAmountStr},
//           );
//           if (type == 'card_payment_success') {
//             stateProvider.updateIsCardPaid(true);
//             qrProvider.isCardPaid = true; // Added for consistency
//             _customCardController.text = stateProvider.cardAmount
//                 .toStringAsFixed(0);
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(
//                 content: Text('Card payment successful!'),
//                 backgroundColor: Colors.green,
//               ),
//             );
//             _updateBalance();
//             validateForm();
//           } else if (type == 'card_payment_error') {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                   'Card payment failed: ${extraData?['message'] ?? 'Unknown error'}',
//                 ),
//                 backgroundColor: Colors.red,
//               ),
//             );
//           }
//         });
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Please enter a valid card amount greater than 0.'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please enter a card amount first.'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//     }
//   }
//   final Set<String> _loggedInvoices = {};
//  void validateForm() {
//     if (!mounted) return;
//     final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
//     bool isEmployeeSelected = stateProvider.selectedEmployeeFirstName != null && _employeeNumberController.text.isNotEmpty;
//     bool isCustomerValid = _customerNumberController.text.isNotEmpty;
//     bool isBalanceOk = stateProvider.balanceAmount <= 0.01;

//     stateProvider.updateIsPrintButtonEnabled(isEmployeeSelected && isCustomerValid && isBalanceOk);
//   }

//   Future<void> _loadEmployees() async {
//     var box = await Hive.openBox('employeeBox');
//     List<dynamic> employees = box.get('employees', defaultValue: []);
//     _allEmployees = {
//       for (var emp in employees)
//         '${(emp as Map)["employeeNumber"]} - ${(emp as Map)["firstName"]}': (emp as Map).cast<String, dynamic>(),
//     };
//     await box.close();

//     if (mounted) {
//       setState(() {}); // Force rebuild so Autocomplete sees updated _allEmployees
//     }

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       validateForm();
//     });
//   }

//   void _selectEmployee(String selection) {
//     final employee = _allEmployees[selection];
//     if (employee != null) {
//       final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
//       stateProvider.updateMultiple(
//         selectedEmployeeFirstName: employee['firstName'],
//         selectedEmployeeNumber: employee['employeeNumber'],
//       );
//       _employeeNumberController.text = selection;
//     }
//     validateForm();
//     _moveToNextField(0);
//   }
//   Set<String> _sentInvoices = {};
//   Future<void> loadSentInvoices() async {
//     var box = await Hive.openBox('sentInvoicesBox');
//     _sentInvoices = Set<String>.from(box.get('sentInvoices', defaultValue: []));
//   }
//   Future<void> saveSentInvoices() async {
//     var box = await Hive.openBox('sentInvoicesBox');
//     await box.put('sentInvoices', _sentInvoices.toList());
//   }
//   Future<void> sendBillToCustomer(
//     String invoiceNo,
//     Map<String, dynamic> invoiceData,
//   ) async {
//     final response = await http.post(
//       Uri.parse('https://yenerp.com/fluttertestapi/invoices/api/send-bill'),
//       headers: {'Content-Type': 'application/json'},
//       body: json.encode({'invoiceNo': invoiceNo, 'invoiceData': invoiceData}),
//     );
//     if (response.statusCode == 200) {
//       final result = json.decode(response.body);
//       print('Bill sent: ${result['pdfUrl']}');
//     } else {
//       print('Failed: ${response.body}');
//     }
//   }
//   Map<String, dynamic> normalizeItem(Map<String, dynamic> item) {
//     final variance = item['varianceData'] ?? {};
//     final itemData = item['itemData'] ?? {};
//     return {
//       "itemData": {
//         "itemName":
//             itemData["itemName"] ??
//             item["itemName"] ??
//             variance["varianceName"] ??
//             "Unknown",
//         "tax": itemData["tax"] ?? item["tax"] ?? variance["variancetax"] ?? 0,
//         "item_Uom":
//             itemData["item_Uom"] ??
//             item["uom"] ??
//             variance["variance_Uom"] ??
//             "N/A",
//         "hsnCode": itemData['hsnCode'] ?? item['hsnCode'] ?? 0,
//       },
//       "varianceData": variance,
//       "quantity": item["quantity"] ?? item["qty"] ?? 1,
//       "weight": item["weight"] ?? 0,
//       "itemName": item["itemName"] ?? variance["varianceName"] ?? "Unknown",
//     };
//   }
//   Future<void> saveInvoiceToHiveAndPrint1() async {
//     String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();
//     var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
//     var stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
//     var cartItems = cartProvider.currentSaleItems ?? [];
//     List<String> itemNames = [];
//     List<int> hsnCode = [];
//     List<String> varianceNames = [];
//     List<double> prices = [];
//     List<double> sellingPrices = [];
//     List<double> weights = [];
//     List<int> quantities = [];
//     List<double> amounts = [];
//     List<double> sellingAmounts = [];
//     List<double> taxes = [];
//     List<String> uoms = [];
//     List<String> varianceItemCode = [];
//     List<double> gstRates = [];
//     List<double> gstValues = [];
//     double discount_perc = _discountController.text.isNotEmpty
//         ? double.tryParse(_discountController.text) ?? 0.0
//         : 0.0;
//     double customCharge = _customChargeController.text.isNotEmpty
//         ? double.tryParse(_customChargeController.text) ?? 0.0
//         : 0.0;
//     double totalItemTotal = 0.0;
//     double totalNet = 0.0;
//     double totalCross = 0.0;
//     double totalDiscountAmount = 0.0;
//     for (var raw in cartItems) {
//       final item = normalizeItem(raw);
//       final itemName = item['itemData']['itemName'] ?? 'N/A';
//       final varianceName = item['varianceData']['varianceName'] ?? 'N/A';
//       final uom =
//           item['varianceData']['variance_Uom'] ??
//           item['itemData']['item_Uom'] ??
//           'N/A';
//       final rate =
//           item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0;
//       double weight = (item['weight'] ?? 0).toDouble();
//       int qty = (item['quantity'] ?? 0).round();
//       if (weight > 0 && qty == 0) qty = 1;
//       final tax = (item['itemData']['tax'] ?? 0).toDouble();
//       // ==============================
//       // ✅ FIXED PRICE CALCULATION
//       // ==============================
//       double actualUnitPrice = uom == "Kgs" ? rate * weight : rate;
//       actualUnitPrice = double.parse(actualUnitPrice.toStringAsFixed(2));
//       double grossAmount = uom == "Kgs"
//           ? actualUnitPrice
//           : actualUnitPrice * qty;
//       // Discount
//       double itemDiscount = grossAmount * (discount_perc / 100);
//       double discountedGross = grossAmount - itemDiscount;
//       // GST split
//       double taxRate = tax / 100;
//       double netExclusive = tax > 0
//           ? discountedGross / (1 + taxRate)
//           : discountedGross;
//       double gstAmount = discountedGross - netExclusive;
//       // Totals
//       totalDiscountAmount += itemDiscount;
//       totalItemTotal += discountedGross;
//       totalNet += netExclusive;
//       // ==============================
//       // PUSH VALUES (FIXED)
//       // ==============================
//       itemNames.add(itemName);
//       varianceNames.add(varianceName);
//       varianceItemCode.add(item['varianceData']['itemCode'] ?? 'N/A');
//       hsnCode.add(item['itemData']['hsnCode'] ?? 0);
//       prices.add(actualUnitPrice);
//       sellingPrices.add(
//         discount_perc > 0
//             ? double.parse(
//                 (actualUnitPrice * (1 - discount_perc / 100)).toStringAsFixed(
//                   2,
//                 ),
//               )
//             : actualUnitPrice,
//       );
//       weights.add(weight);
//       quantities.add(qty);
//       amounts.add(double.parse(grossAmount.toStringAsFixed(2)));
//       sellingAmounts.add(double.parse(discountedGross.toStringAsFixed(2)));
//       taxes.add(tax);
//       uoms.add(uom);
//       gstRates.add(tax);
//       gstValues.add(double.parse(gstAmount.toStringAsFixed(2)));
//     }
//     totalCross = totalItemTotal + customCharge;
//     DateTime billDate = DateTime.now();
//     String uniqueIdentifier =
//         '${DateFormat('dd-MM-yyyy').format(billDate)}-$totalItemTotal-${_customerNumberController.text}';
//     String customerPhone = _customerNumberController.text
//         .split(' - ')
//         .first
//         .trim();
//     String salesPersonId = stateProvider.selectedEmployeeNumber ?? '';
//     String salesPersonName = stateProvider.selectedEmployeeFirstName ?? '';
//     Map<String, dynamic> invoiceData = {
//       'HiveInvoiceId': hiveInvoiceId,
//       'itemName': itemNames,
//       'varianceitemCode': varianceItemCode,
//       'varianceName': varianceNames,
//       'price': prices,
//       'sellingPrice': sellingPrices,
//       'sellingAmount': sellingAmounts,
//       'weight': weights,
//       'qty': quantities,
//       'amount': amounts,
//       'tax': taxes,
//       'uom': uoms,
//       'salesPersonId': salesPersonId,
//       'salesPersonName': salesPersonName,
//       'customerPhoneNumber': customerPhone,
//       'discountPercentage': int.tryParse(_discountController.text) ?? 0,
//       'customCharge': customCharge.toInt(),
//       'totalAmount': totalItemTotal,
//       'netAmount': totalNet,
//       'grossAmount': totalCross,
//       'invoiceDateTime': billDate.toIso8601String(),
//       'branchId': "$branchId",
//       'salesType': "TakeAway",
//       'branchName': "$branchName",
//       'aliasName': "$aliasname",
//       'cash': stateProvider.cashAmount > 0 ? stateProvider.cashAmount : null,
//       'card': stateProvider.cardAmount > 0 ? stateProvider.cardAmount : null,
//       'upi': stateProvider.upiAmount > 0 ? stateProvider.upiAmount : null,
//       'others': null,
//       'shiftNumber': 1,
//       'shiftId': shiftId.value,
//       'invoiceNo': '',
//       'deviceNumber': 1,
//       'sync': "No",
//       'status': "active",
//       'uniqueIdentifier': uniqueIdentifier,
//       'gst': gstRates,
//       'gstValue': gstValues,
//       'discountAmount': totalDiscountAmount > 0 ? totalDiscountAmount : null,
//       'hsnCode': hsnCode,
//     };
//     debugPrint('posInvoice1');
//     // Wrap invoice into JSON
//     final invoiceJson = jsonEncode({
//       "salesOrderId": invoiceData,
//       "type": "invoice",
//       //"sync": "No",
//       "edit": "No",
//     });
//     // String jsonInvoiceData = jsonEncode({'data': invoiceData, 'type': 'posInvoice'});
//     debugPrint('posInvoice2');
//     await sendataToServer(jsonDecode(invoiceJson));
//     debugPrint('posInvoice3 $invoiceJson');
//     // Step 4: Log the invoice data only if it hasn't been logged before
//     if (!_loggedInvoices.contains(uniqueIdentifier)) {
//       _loggedInvoices.add(uniqueIdentifier);
//       developer.log('Invoice Data:', name: 'InvoiceLog');
//       developer.log(invoiceData.toString(), name: 'InvoiceLog');
//     }
//     try {
//       print("ok1233");
//       // Send SMS
//       String customerNumber = _customerNumberController.text;
//       // Extract only the phone number from customerNumber (e.g., "6985748963 - test" -> "6985748963")
//       String phoneNumber = customerNumber
//           .split(' - ')[0]
//           .trim(); // Get the part before " - "
//       if (RegExp(r'^\d{10}$').hasMatch(phoneNumber)) {
//         // Validate it's a 10-digit number
//         String totalAmount = totalItemTotal.toStringAsFixed(
//           0,
//         ); // Use discounted total
//         String billNumber = invoiceData['invoiceNo'];
//         // Send SMS
//         if (isSMSEnabled) {
//           String smsApiUrl =
//               'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK&senderid=BMUMMY&templateid=1707167058380400950&number=$phoneNumber&message=WELCOME TO BESTMUMMY BILL NO:$billNumber BILL AMOUNT: $totalAmount VISIT OUR 45 THANK YOU FOR VISITING AGAIN';
//           var smsResponse = await http.get(Uri.parse(smsApiUrl));
//           if (smsResponse.statusCode == 200) {
//             print('SMS sent successfully to $phoneNumber');
//           } else {
//             print('Failed to send SMS: ${smsResponse.body}');
//           }
//         }
//         // Send WhatsApp message
//         if (isWhatsAppEnabled) {
//           await sendBillToCustomer('', invoiceData);
//         }
//       } else {
//         print('Invalid phone number format: $phoneNumber');
//       }
//     } catch (e) {
//       print('Error posting invoice or sending message: $e');
//     }
//     print("web123");
//     print("web done");
//   }
//   void _applyDiscount(String discount) {
//     final saleProvider = Provider.of<CurrentSaleProvider>(
//       context,
//       listen: false,
//     );
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     // Enforce max 2 digits
//     if (discount.length > 2) {
//       discount = discount.substring(0, 2);
//       _discountController.text = discount;
//       _discountController.selection = TextSelection.fromPosition(
//         TextPosition(offset: discount.length),
//       );
//     }
//     double discountValue = double.tryParse(discount) ?? 0.0;
//     if (discountValue > 99) discountValue = 99;
//     saleProvider.discountPercentage = discountValue;
//     saleProvider.calculateTotal();
//     double newTotal = getTotalWithAdjustments();
//     stateProvider.updateBalanceAmount(newTotal);
//     _recalculatePaymentsOnTotalChange();
//   }
//   // NEW METHOD: Update payment fields when discount changes
//   void _updatePaymentFieldsAfterDiscount() {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     final totalWithAdjustments = getTotalWithAdjustments();
//     // Recalculate payment amounts to maintain balance
//     double totalPayments =
//         stateProvider.cashAmount +
//         stateProvider.upiAmount +
//         stateProvider.cardAmount;
//     // If total payments exceed new total, adjust them
//     if (totalPayments > totalWithAdjustments) {
//       double excess = totalPayments - totalWithAdjustments;
//       // Reduce payments proportionally (simple approach: reduce cash first)
//       if (stateProvider.cashAmount >= excess) {
//         stateProvider.updateCashAmount(stateProvider.cashAmount - excess);
//         _customCashController.text = stateProvider.cashAmount.toStringAsFixed(
//           0,
//         );
//       } else {
//         double remainingExcess = excess - stateProvider.cashAmount;
//         stateProvider.updateCashAmount(0);
//         _customCashController.text = '0';
//         if (stateProvider.upiAmount >= remainingExcess) {
//           stateProvider.updateUpiAmount(
//             stateProvider.upiAmount - remainingExcess,
//           );
//           _customUpiController.text = stateProvider.upiAmount.toStringAsFixed(
//             0,
//           );
//         } else {
//           double finalExcess = remainingExcess - stateProvider.upiAmount;
//           stateProvider.updateUpiAmount(0);
//           _customUpiController.text = '0';
//           stateProvider.updateCardAmount(
//             stateProvider.cardAmount - finalExcess,
//           );
//           _customCardController.text = stateProvider.cardAmount.toStringAsFixed(
//             0,
//           );
//         }
//       }
//     }
//     _updateBalance();
//   }
//  double getTotalWithAdjustments() {
//     double discountValue = (double.tryParse(_discountController.text) ?? 0.0) / 100;
//     double charges = double.tryParse(_customChargeController.text) ?? 0.0;
//     return (widget.totalAmount * (1 - discountValue)) + charges;
//   }

//   double getRemainingForMethod(String method) {
//     final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
//     double total = getTotalWithAdjustments();
//     double other = 0.0;
//     if (method != 'Cash') other += stateProvider.cashAmount;
//     if (method != 'Upi') other += stateProvider.upiAmount;
//     if (method != 'Card') other += stateProvider.cardAmount;
//     return total - other;
//   }

//   void _updateBalance() {
//     if (!mounted) return;
//     final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
//     double totalPayments = stateProvider.cashAmount + stateProvider.upiAmount + stateProvider.cardAmount;
//     double total = getTotalWithAdjustments();
//     double balance = total - totalPayments;
//     stateProvider.updateBalanceAmount(balance);
//     cashOptions.clear();
//     cashOptions.addAll(_generateCashOptions(balance.abs()));
//     validateForm();
//   }

//   List<String> _generateCashOptions(double amount) {
//     if (amount <= 0) return ['0'];
//     List<String> options = [];
//     int exact = amount.ceil();
//     options.add(exact.toString());
//     List<int> denoms = [1, 2, 5, 10, 20, 50, 100, 200, 500];
//     for (int d in denoms) {
//       int next = ((exact + d - 1) ~/ d) * d;
//       if (next > exact) options.add(next.toString());
//     }
//     options = options.toSet().toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
//     return options;
//   }
//  void _selectPaymentOption(String method, String amountStr) {
//     if (!mounted) return;
//     final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
//     double amount = double.tryParse(amountStr) ?? 0.0;

//     if (amount == 0) {
//       switch (method) {
//         case "Cash":
//           stateProvider.updateCashAmount(0);
//           _customCashController.clear();
//           break;
//         case "Upi":
//           stateProvider.updateUpiAmount(0);
//           _customUpiController.clear();
//           stateProvider.updateIsUpiPaid(false);
//           break;
//         case "Card":
//           stateProvider.updateCardAmount(0);
//           _customCardController.clear();
//           final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
//           qrProvider.isCardPaid = false;
//           stateProvider.updateIsCardPaid(false);
//           break;
//       }
//       _updateBalance();
//       return;
//     }

//     double remaining = getRemainingForMethod(method);
//     if (amount > remaining + 0.01) {
//       amount = remaining;
//       amountStr = remaining.toStringAsFixed(0);
//       if (method == "Upi") _customUpiController.text = amountStr;
//       if (method == "Card") _customCardController.text = amountStr;
//       if (method == "Cash") _customCashController.text = amountStr;
//     }

//     stateProvider.updateMultiple(selectedPaymentOption: '$method: ${amount.toStringAsFixed(0)}');
//     switch (method) {
//       case "Cash":
//         stateProvider.updateCashAmount(amount);
//         _customCashController.text = amount.toStringAsFixed(0);
//         break;
//       case "Upi":
//         stateProvider.updateUpiAmount(amount);
//         _customUpiController.text = amount.toStringAsFixed(0);
//         break;
//       case "Card":
//         stateProvider.updateCardAmount(amount);
//         _customCardController.text = amount.toStringAsFixed(0);
//         break;
//     }
//     _updateBalance();
//   }

//   void _showUpiQrDialog(double amount) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<RazorpayQRProvider>(context, listen: false).createQR(amount);
//     });

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//         return AlertDialog(
//           backgroundColor: Colors.white,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           title: const Row(children: [Icon(Icons.qr_code, color: Colors.blue), SizedBox(width: 8), Text('UPI QR Code', style: TextStyle(fontWeight: FontWeight.bold))]),
//           content: SizedBox(
//             height: 600,
//             width: 285,
//             child: Consumer2<RazorpayQRProvider, SalesInvoiceState>(
//               builder: (context, qrProvider, stateProvider, _) {
//                 if (qrProvider.isLoading) return const Center(child: CircularProgressIndicator());

//                 if (qrProvider.errorMessage != null) {
//                   return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//                     const Icon(Icons.error, color: Colors.red, size: 48),
//                     Text(qrProvider.errorMessage!, textAlign: TextAlign.center),
//                     ElevatedButton.icon(icon: const Icon(Icons.close), label: const Text("Close"), onPressed: () {
//                       qrProvider.disconnectWebSocket();
//                       Navigator.pop(context);
//                     })
//                   ]);
//                 }

//                 if (qrProvider.paymentSuccess) {
//                   stateProvider.updateIsUpiPaid(true);
//                   _customUpiController.text = stateProvider.upiAmount.toStringAsFixed(0);

//                   if (mounted) setState(() {}); // 🔥 FORCE REBUILD AFTER UPI SUCCESS
//                   _updateBalance();
//                   validateForm();

//                   return Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Lottie.asset('assets/Payment Successful.json', repeat: false, height: 500, fit: BoxFit.contain, onLoaded: (comp) {
//                         Future.delayed(comp.duration + const Duration(seconds: 2), () {
//                           if (mounted) Navigator.pop(context);
//                         });
//                       }),
//                       const Text('UPI Payment Successful!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
//                     ],
//                   );
//                 }

//                 if (qrProvider.qrImageUrl != null) {
//                   return Column(mainAxisSize: MainAxisSize.min, children: [
//                     Image.network(qrProvider.qrImageUrl!, height: 535, fit: BoxFit.fill),
//                     const SizedBox(height: 16),
//                     ElevatedButton.icon(icon: const Icon(Icons.close), label: const Text("Close"), onPressed: () {
//                       qrProvider.disconnectWebSocket();
//                       Navigator.pop(context);
//                     })
//                   ]);
//                 }

//                 return const Center(child: Text('No QR generated'));
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildPaymentOption(String amount, String method) {
//     final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
//     bool isSelected = stateProvider.selectedPaymentOption == '$method: $amount';

//     TextEditingController controller = method == 'Cash'
//         ? _customCashController
//         : method == 'Upi'
//             ? _customUpiController
//             : _customCardController;

//     bool isUpiPaid = method == 'Upi' && stateProvider.isUpiPaid;
//     bool isCardPaid = method == 'Card' && stateProvider.isCardPaid;
//     bool shouldDisable = isUpiPaid || isCardPaid;

//     if (amount == 'Custom') {
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
//         child: SizedBox(
//           width: 130,
//           height: 50,
//           child: Material(
//             color: Colors.grey.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(8),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     readOnly: shouldDisable,
//                     enabled: !shouldDisable,
//                     controller: controller,
//                     focusNode: _getFocusNodeForController(controller),
//                     keyboardType: TextInputType.none,
//                     decoration: InputDecoration(
//                       hintText: shouldDisable ? "Paid" : "Enter $method",
//                       fillColor: shouldDisable ? Colors.grey[200] : Colors.white,
//                       filled: true,
//                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                     ),
//                     onChanged: (v) => _selectPaymentOption(method, v.isEmpty ? '0' : v),
//                     onTap: () => !shouldDisable ? setCurrentFocusForController(controller) : null,
//                   ),
//                 ),
//                 if (method == 'Upi' || method == 'Card')
//                   IconButton(
//                     icon: Icon(method == 'Upi' ? Icons.qr_code : Icons.credit_card, color: shouldDisable ? Colors.grey : Colors.blue),
//                     onPressed: !shouldDisable
//                         ? () {
//                             final val = controller.text;
//                             final amt = double.tryParse(val);
//                             if (val.isNotEmpty && amt != null && amt > 0) {
//                               method == 'Upi' ? _showUpiQrDialog(amt) : _handleCardPayment();
//                             } else {
//                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter valid $method amount')));
//                             }
//                           }
//                         : null,
//                   ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     return Padding(
//       padding: const EdgeInsets.all(8),
//       child: GestureDetector(
//         onTap: shouldDisable ? null : () => _selectPaymentOption(method, amount),
//         child: Container(
//           height: 40,
//           padding: const EdgeInsets.symmetric(horizontal: 12),
//           decoration: BoxDecoration(
//             color: shouldDisable ? Colors.grey[300] : (isSelected ? Colors.blue : Colors.white),
//             borderRadius: BorderRadius.circular(6),
//             border: Border.all(color: shouldDisable ? Colors.grey : (isSelected ? Colors.blue : Colors.grey.shade300), width: 1.5),
//           ),
//           child: Center(child: Text(amount, style: TextStyle(color: shouldDisable ? Colors.grey[600] : (isSelected ? Colors.white : Colors.blue)))),
//         ),
//       ),
//     );
//   }
//   void _recalculatePaymentsOnTotalChange() {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     final totalWithAdjustments = getTotalWithAdjustments();
//     double totalPayments =
//         stateProvider.cashAmount +
//         stateProvider.upiAmount +
//         stateProvider.cardAmount;
//     // FIXED: If total payments exceed new total, adjust ALL payments
//     if (totalPayments > totalWithAdjustments) {
//       double excess = totalPayments - totalWithAdjustments;
//       // FIXED: Clear all payments first and let user re-enter
//       stateProvider.updateCashAmount(0);
//       stateProvider.updateUpiAmount(0);
//       stateProvider.updateCardAmount(0);
//       _customCashController.text = '';
//       _customUpiController.text = '';
//       _customCardController.text = '';
//       // FIXED: Also reset payment status
//       stateProvider.updateIsUpiPaid(false);
//       final qrProvider = Provider.of<RazorpayQRProvider>(
//         context,
//         listen: false,
//       );
//       qrProvider.isCardPaid = false;
//     }
//     // FIXED: Always update balance after recalculation
//     _updateBalance();
//   }
// //   void _showUpiQrDialog(double amount) {
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       Provider.of<RazorpayQRProvider>(context, listen: false).createQR(amount);
// //     });
// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (BuildContext context) {
// //         return AlertDialog(
// //           backgroundColor: Colors.white,
// //           shape: RoundedRectangleBorder(
// //             borderRadius: BorderRadius.circular(16),
// //           ),
// //           title: const Row(
// //             children: [
// //               Icon(Icons.qr_code, color: Colors.blue),
// //               SizedBox(width: 8),
// //               Text(
// //                 'UPI QR Code',
// //                 style: TextStyle(
// //                   fontFamily: 'Poppins',
// //                   fontWeight: FontWeight.bold,
// //                 ),
// //               ),
// //             ],
// //           ),
// //           content: SizedBox(
// //             height: 600,
// //             width: 285,
// //             child: Consumer2<RazorpayQRProvider, SalesInvoiceState>(
// //               builder: (context, qrProvider, stateProvider, _) {
// //                 if (qrProvider.isLoading) {
// //                   return const Center(child: CircularProgressIndicator());
// //                 } else if (qrProvider.errorMessage != null) {
// //                   _sendState(
// //                     type: 'upi_payment_error',
// //                     extraData: {'message': qrProvider.errorMessage},
// //                   );
// //                   return Column(
// //                     mainAxisAlignment: MainAxisAlignment.center,
// //                     children: [
// //                       const Icon(Icons.error, color: Colors.red, size: 48),
// //                       const SizedBox(height: 8),
// //                       Text(
// //                         qrProvider.errorMessage!,
// //                         style: const TextStyle(
// //                           fontFamily: 'Poppins',
// //                           color: Colors.red,
// //                           fontSize: 16,
// //                         ),
// //                         textAlign: TextAlign.center,
// //                       ),
// //                       const SizedBox(height: 16),
// //                       ElevatedButton.icon(
// //                         icon: const Icon(Icons.close),
// //                         label: const Text("Close"),
// //                         onPressed: () {
// //                           qrProvider.disconnectWebSocket();
// //                           Navigator.pop(context);
// //                         },
// //                         style: ElevatedButton.styleFrom(
// //                           backgroundColor: const Color.fromARGB(
// //                             255,
// //                             6,
// //                             62,
// //                             247,
// //                           ),
// //                           foregroundColor: Colors.white,
// //                           shape: RoundedRectangleBorder(
// //                             borderRadius: BorderRadius.circular(7),
// //                           ),
// //                         ),
// //                       ),
// //                     ],
// //                   );
// //                 } else if (qrProvider.paymentSuccess) {
// //                   Provider.of<SalesInvoiceState>(
// //                     context,
// //                     listen: false,
// //                   ).updateIsUpiPaid(true);
// //                   _customUpiController.text = stateProvider.upiAmount
// //                       .toStringAsFixed(0);
// //                   _sendState(type: 'upi_payment_success');
// //                   _updateBalance();
// //                   validateForm();
// //                   return Column(
// //                     mainAxisAlignment: MainAxisAlignment.center,
// //                     children: [
// //                       Lottie.asset(
// //                         'assets/Payment Successful.json',
// //                         repeat: false,
// //                         height: 500,
// //                         width: double.infinity,
// //                         fit: BoxFit.contain,
// //                         onLoaded: (composition) {
// //                           Future.delayed(
// //                             composition.duration + const Duration(seconds: 2),
// //                             () {
// //                               if (mounted) {
// //                                 Navigator.pop(context);
// //                               }
// //                             },
// //                           );
// //                         },
// //                       ),
// //                       const Text(
// //                         'UPI Payment Successful!',
// //                         style: TextStyle(
// //                           fontFamily: 'Poppins',
// //                           fontSize: 18,
// //                           fontWeight: FontWeight.bold,
// //                           color: Colors.green,
// //                         ),
// //                         textAlign: TextAlign.center,
// //                       ),
// //                     ],
// //                   );
// //                 } else if (qrProvider.qrImageUrl != null) {
// //                   _sendState(
// //                     type: 'show_upi_qr',
// //                     extraData: {
// //                       'qrUrl': qrProvider.qrImageUrl,
// //                       'amount': amount,
// //                     },
// //                   );
// //                   return Column(
// //                     mainAxisSize: MainAxisSize.min,
// //                     children: [
// //                       Image.network(
// //                         qrProvider.qrImageUrl!,
// //                         height: 535,
// //                         width: double.infinity,
// //                         fit: BoxFit.fill,
// //                         errorBuilder: (context, error, stackTrace) {
// //                           _sendState(
// //                             type: 'upi_payment_error',
// //                             extraData: {'message': 'Failed to load QR code'},
// //                           );
// //                           return const Column(
// //                             mainAxisAlignment: MainAxisAlignment.center,
// //                             children: [
// //                               Icon(Icons.error, color: Colors.red, size: 48),
// //                               SizedBox(height: 8),
// //                               Text(
// //                                 'Failed to load QR code',
// //                                 style: TextStyle(
// //                                   fontFamily: 'Poppins',
// //                                   color: Colors.red,
// //                                   fontSize: 16,
// //                                 ),
// //                                 textAlign: TextAlign.center,
// //                               ),
// //                             ],
// //                           );
// //                         },
// //                       ),
// //                       const SizedBox(height: 16),
// //                       Row(
// //                         children: [
// //                           Expanded(
// //                             child: ElevatedButton.icon(
// //                               icon: const Icon(Icons.close),
// //                               label: const Text("Close"),
// //                               onPressed: () {
// //                                 qrProvider.disconnectWebSocket();
// //                                 Navigator.pop(context);
// //                                 _sendState(type: 'upi_payment_cancelled');
// //                               },
// //                               style: ElevatedButton.styleFrom(
// //                                 backgroundColor: const Color.fromARGB(
// //                                   255,
// //                                   6,
// //                                   62,
// //                                   247,
// //                                 ),
// //                                 foregroundColor: Colors.white,
// //                                 shape: RoundedRectangleBorder(
// //                                   borderRadius: BorderRadius.circular(7),
// //                                 ),
// //                               ),
// //                             ),
// //                           ),
// //                         ],
// //                       ),
// //                     ],
// //                   );
// //                 } else {
// //                   _sendState(
// //                     type: 'upi_payment_error',
// //                     extraData: {'message': 'No QR code generated'},
// //                   );
// //                   return const Center(child: Text('No QR generated'));
// //                 }
// //               },
// //             ),
// //           ),
// //         );
// //       },
// //     );
// //   }
// //  // In your payment option widget, update this part:
// // Widget _buildPaymentOption(String amount, String method) {
// //   final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
// //   final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
// //   bool isSelected = stateProvider.selectedPaymentOption == '$method: $amount';
// //   TextEditingController controller;
// //   switch (method) {
// //     case 'Cash':
// //       controller = _customCashController;
// //       break;
// //     case 'Upi':
// //       controller = _customUpiController;
// //       break;
// //     case 'Card':
// //       controller = _customCardController;
// //       break;
// //     default:
// //       controller = _customAmountController;
// //   }
// //   // FIX: Check each method separately
// //   bool isUpiPaid = method == 'Upi' && stateProvider.isUpiPaid;
// //   bool isCardPaid = method == 'Card' && stateProvider.isCardPaid; // Changed to stateProvider for consistency
// //   bool isPaid = isUpiPaid || isCardPaid;
// //   // FIX: Only disable the specific method that's paid
// //   bool shouldDisableField = (method == 'Upi' && isUpiPaid) ||
// //                            (method == 'Card' && isCardPaid);
// //   if (amount == 'Custom') {
// //     return Padding(
// //       padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
// //       child: SizedBox(
// //         width: 130,
// //         height: 50,
// //         child: Material(
// //           color: Colors.grey.withOpacity(0.1),
// //           borderRadius: BorderRadius.circular(8),
// //           child: Row(
// //             children: [
// //               Expanded(
// //                 child: TextField(
// //                   showCursor: true,
// //                   readOnly: shouldDisableField, // Only disable if this method is paid
// //                   enabled: !shouldDisableField,
// //                   controller: controller,
// //                   focusNode: _getFocusNodeForController(controller),
// //                   keyboardType: TextInputType.none,
// //                   decoration: InputDecoration(
// //                     enabledBorder: OutlineInputBorder(
// //                       borderSide: BorderSide(color: Colors.white, width: 1.5),
// //                       borderRadius: BorderRadius.circular(8),
// //                     ),
// //                     focusedBorder: OutlineInputBorder(
// //                       borderRadius: BorderRadius.circular(8),
// //                       borderSide: BorderSide(color: Colors.blue, width: 1),
// //                     ),
// //                     border: const OutlineInputBorder(),
// //                     filled: isSelected,
// //                     hintText: shouldDisableField ? "Paid" : "Enter $method",
// //                     fillColor: shouldDisableField ? Colors.grey[200] : Colors.white,
// //                   ),
// //                   onChanged: (value) {
// //                     if (!shouldDisableField) {
// //                       _selectPaymentOption(
// //                         method,
// //                         value.isEmpty ? '0' : value,
// //                       );
// //                     }
// //                   },
// //                   onTap: () {
// //                     if (!shouldDisableField) {
// //                       setCurrentFocusForController(controller);
// //                     }
// //                   },
// //                 ),
// //               ),
// //               if (method == 'Upi' || method == 'Card')
// //                 Consumer<RazorpayQRProvider>(
// //                   builder: (context, qrProvider, _) {
// //                     return IconButton(
// //                       icon: Icon(
// //                         method == 'Upi' ? Icons.qr_code : Icons.credit_card,
// //                         color: shouldDisableField
// //                             ? Colors.grey
// //                             : (method == 'Upi' ? Colors.black : Colors.blue),
// //                         size: 24,
// //                       ),
// //                       onPressed: !shouldDisableField && isPaymentEnabled
// //                           ? () {
// //                               final amountStr = controller.text;
// //                               if (amountStr.isNotEmpty) {
// //                                 final amount = double.tryParse(amountStr);
// //                                 if (amount != null && amount > 0) {
// //                                   if (method == 'Upi') {
// //                                     _showUpiQrDialog(amount);
// //                                   } else {
// //                                     _handleCardPayment();
// //                                   }
// //                                 } else {
// //                                   ScaffoldMessenger.of(context).showSnackBar(
// //                                     SnackBar(
// //                                       content: Text(
// //                                         "Please enter a valid $method amount greater than 0",
// //                                       ),
// //                                       backgroundColor: Colors.red,
// //                                     ),
// //                                   );
// //                                 }
// //                               } else {
// //                                 ScaffoldMessenger.of(context).showSnackBar(
// //                                   SnackBar(
// //                                     content: Text(
// //                                       "Please enter a $method amount first",
// //                                     ),
// //                                     backgroundColor: Colors.orange,
// //                                   ),
// //                                 );
// //                               }
// //                             }
// //                           : null,
// //                     );
// //                   },
// //                 ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   } else {
// //     return Padding(
// //       padding: const EdgeInsets.all(8),
// //       child: GestureDetector(
// //         onTap: shouldDisableField
// //             ? null
// //             : () {
// //                 _selectPaymentOption(method, amount);
// //               },
// //         child: Container(
// //           height: 40,
// //           padding: const EdgeInsets.symmetric(horizontal: 12),
// //           decoration: BoxDecoration(
// //             color: shouldDisableField
// //                 ? Colors.grey[300]
// //                 : (isSelected ? Colors.blue : Colors.white),
// //             borderRadius: BorderRadius.circular(6),
// //             border: Border.all(
// //               color: shouldDisableField
// //                   ? Colors.grey
// //                   : (isSelected ? Colors.blue : Colors.grey.shade300),
// //               width: 1.5,
// //             ),
// //             boxShadow: [
// //               if (isSelected && !shouldDisableField)
// //                 BoxShadow(
// //                   color: Colors.blue.withOpacity(0.3),
// //                   blurRadius: 4,
// //                   offset: Offset(0, 2),
// //                 ),
// //             ],
// //           ),
// //           child: Center(
// //             child: Text(
// //               amount,
// //               style: TextStyle(
// //                 fontFamily: 'Poppins',
// //                 fontSize: 14,
// //                 color: shouldDisableField
// //                     ? Colors.grey[600]
// //                     : (isSelected ? Colors.white : Colors.blue),
// //                 fontWeight: FontWeight.w500,
// //               ),
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
//   Widget _buildPaymentSection(String method) {
//     double remaining = getRemainingForMethod(method);
//     // For all methods, show exact remaining amount as suggestion
//     String exactStr = remaining > 0 ? remaining.toStringAsFixed(0) : '0';
//     List<String> extraOptions = [];
//     if (method == 'Cash') {
//       final stateProvider = Provider.of<SalesInvoiceState>(
//         context,
//         listen: false,
//       );
//       double amountForOptions = stateProvider.balanceAmount > 0
//           ? stateProvider.balanceAmount
//           : 0.0;
//       extraOptions = _generateCashOptions(amountForOptions).skip(1).toList();
//     }
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.start,
//           children: [
//             CustomText(
//               text: method,
//               style: const TextStyle(
//                 fontFamily: 'Poppins',
//                 fontSize: 16,
//                 color: Colors.black,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const CustomSizedBox(width: 20),
//             _buildPaymentOption('Custom', method),
//             // Show exact amount button for all methods
//             _buildPaymentOption(exactStr, method),
//           ],
//         ),
//         // Only show extra options for Cash
//         if (method == 'Cash' && extraOptions.isNotEmpty)
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.start,
//               children: [
//                 for (var option in extraOptions)
//                   _buildPaymentOption(option, method),
//               ],
//             ),
//           ),
//       ],
//     );
//   }
//   FocusNode _getFocusNodeForController(TextEditingController controller) {
//     int index = _keyboardControllers.indexOf(controller);
//     return index >= 0 ? _focusNodes[index] : FocusNode();
//   }
//   void setCurrentFocusForController(TextEditingController controller) {
//     int index = _keyboardControllers.indexOf(controller);
//     if (index >= 0) {
//       _currentFocusIndexNotifier.value = index;
//       _focusNodes[index].requestFocus();
//       if (controller == _customCashController) {
//           double remaining = getRemainingForMethod('Cash');
//         if (remaining > 0) {
//           _selectPaymentOption('Cash', remaining.toStringAsFixed(0));
//         }
//       }
//       // Auto-fill UPI/Card with remaining amount when focused
//       else if (controller == _customUpiController && controller.text.isEmpty) {
//         double remaining = getRemainingForMethod('Upi');
//         if (remaining > 0) {
//           _selectPaymentOption('Upi', remaining.toStringAsFixed(0));
//         }
//       } else if (controller == _customCardController &&
//           controller.text.isEmpty) {
//         double remaining = getRemainingForMethod('Card');
//         if (remaining > 0) {
//           _selectPaymentOption('Card', remaining.toStringAsFixed(0));
//         }
//       } else if (controller == _birthdayController) {
//         _openDatePicker();
//       }
//     }
//   }
//   void _moveToNextField(int currentIndex) {
//     int nextIndex = currentIndex + 1;
//     if (nextIndex == 2 && currentIndex == 0) {
//       nextIndex = 3;
//     }
//     if (nextIndex < _keyboardControllers.length) {
//       _currentFocusIndexNotifier.value = nextIndex;
//       _focusNodes[nextIndex].requestFocus();
//     }
//   }
//   void _handleKeyboardTextInput(String text) {
//     final currentIndex = _currentFocusIndexNotifier.value;
//     final currentController = _keyboardControllers[currentIndex];
//     // If current text is "0" or empty, replace it, otherwise append
//     if (currentController.text == "0" || currentController.text.isEmpty) {
//       currentController.text = text;
//     } else {
//       currentController.text = currentController.text + text;
//     }
//     currentController.selection = TextSelection.fromPosition(
//       TextPosition(offset: currentController.text.length),
//     );
//     _processControllerChange(currentController);
//   }
//   void _clearAllPayments({bool showSnackBar = true}) {
//     final stateProvider = Provider.of<SalesInvoiceState>(
//       context,
//       listen: false,
//     );
//     final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
//     stateProvider.updateCashAmount(0);
//     stateProvider.updateUpiAmount(0);
//     stateProvider.updateCardAmount(0);
//     stateProvider.updateIsUpiPaid(false);
//     _customCashController.clear();
//     _customUpiController.clear();
//     _customCardController.clear();
//     qrProvider.isCardPaid = false;
//     stateProvider.updateIsCardPaid(false); // Added for consistency
//     qrProvider.disconnectWebSocket();
//     _updateBalance();
//   }
//   void _processControllerChange(TextEditingController controller) {
//     if (controller == _discountController) {
//       if (controller.text.isEmpty) {
//         _applyDiscount('0');
//       } else {
//         _applyDiscount(controller.text);
//       }
//     } else if (controller == _customChargeController) {
//       _clearAllPayments();
//     } else if (controller == _customCashController) {
//       _selectPaymentOption(
//         'Cash',
//         controller.text.isEmpty ? '0' : controller.text,
//       );
//     } else if (controller == _customUpiController) {
//       _selectPaymentOption(
//         'Upi',
//         controller.text.isEmpty ? '0' : controller.text,
//       );
//     } else if (controller == _customCardController) {
//       _selectPaymentOption(
//         'Card',
//         controller.text.isEmpty ? '0' : controller.text,
//       );
//     } else {
//       validateForm();
//     }
//   }
//   void _handleKeyboardBackspace() {
//     final currentIndex = _currentFocusIndexNotifier.value;
//     final currentController = _keyboardControllers[currentIndex];
//     if (currentController.text.isNotEmpty) {
//       currentController.text = currentController.text.substring(
//         0,
//         currentController.text.length - 1,
//       );
//       currentController.selection = TextSelection.fromPosition(
//         TextPosition(offset: currentController.text.length),
//       );
//     }
//     _processControllerChange(currentController);
//   }
//   void _handleKeyboardOk() {
//     final currentIndex = _currentFocusIndexNotifier.value;
//     _moveToNextField(currentIndex);
//   }
//   bool _isSubmitting = false;
//   Future<void> _printReceiptDetails() async {
//     if (_isSubmitting) {
//       developer.log('Print already in progress', name: 'SalesInvoice');
//       return;
//     }
//     setState(() {
//       _isSubmitting = true;
//     });
//     try {
//       // === STOCK VALIDATION BEFORE PRINTING ===
//       final globalManager = GlobalDataManager();
//       final branchwiseItemsBox = await Hive.openBox('items');
//       final branchwiseData = await branchwiseItemsBox.get(
//         'branchwiseItems_$aliasname',
//       );
//       Map<dynamic, dynamic>? branchwiseItems = {};
//       if (branchwiseData is Map) {
//         branchwiseItems = Map<dynamic, dynamic>.from(branchwiseData);
//       }
//       List<Map<String, dynamic>> stockCheckList = [];
//       bool hasInsufficient = false;
//       final cartProvider = Provider.of<CurrentSaleProvider>(
//         context,
//         listen: false,
//       );
//       final cartItems = cartProvider.currentSaleItems ?? [];
//       for (var item in cartItems) {
//         final itemName =
//             item['itemName']?.toString() ??
//             item['itemData']?['itemName']?.toString() ??
//             '';
//         final varianceName =
//             item['varianceData']['varianceName']?.toString() ?? 'Unknown Item';
//         final itemUom = (item['varianceData']['variance_Uom']?.toString() ?? '')
//             .toLowerCase();
//         final bool isKg = itemUom.contains('kg');
//         double requiredQty = isKg
//             ? (item['weight'] as num?)?.toDouble() ?? 0.0
//             : (item['quantity'] as num?)?.toDouble() ?? 0.0;
//         double liveStock = globalManager.getSystemStock(
//           aliasname,
//           varianceName,
//         );
//         double availableStock = liveStock >= 0 ? liveStock : 0.0;
//         if (liveStock < 0 &&
//             branchwiseItems != null &&
//             branchwiseItems['data']?[itemName] != null) {
//           final itemData = branchwiseItems['data'][itemName];
//           final varianceMap = itemData['variance'] as Map?;
//           if (varianceMap != null) {
//             for (var v in varianceMap.values) {
//               if (v['varianceName']?.toString() == varianceName) {
//                 availableStock =
//                     (v['branchwise']?[aliasname]?['systemStock_$aliasname']
//                             as num?)
//                         ?.toDouble() ??
//                     0.0;
//                 break;
//               }
//             }
//           }
//         }
//         final bool sufficient = requiredQty <= availableStock + 0.001;
//         if (!sufficient) hasInsufficient = true;
//         stockCheckList.add({
//           'item': varianceName,
//           'required': requiredQty,
//           'available': availableStock,
//           'uom': isKg ? 'kg' : 'pcs',
//           'status': sufficient ? 'OK' : 'Insufficient',
//           'isKg': isKg,
//         });
//       }
//       // === SHOW INSUFFICIENT STOCK DIALOG IF NEEDED ===
//       if (hasInsufficient) {
//         final List<Map<String, dynamic>> insufficientItems = stockCheckList
//             .where((row) => row['status'] == 'Insufficient')
//             .toList();
//         showDialog(
//           context: context,
//           barrierDismissible: false,
//           builder: (ctx) => Dialog(
//             alignment: Alignment.center,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//             ),
//             elevation: 30,
//             backgroundColor: Colors.transparent,
//             child: Container(
//               width: MediaQuery.of(context).size.width * 0.7,
//               constraints: const BoxConstraints(maxHeight: 700),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                   colors: [Colors.white, Colors.grey.shade50],
//                 ),
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.2),
//                     blurRadius: 30,
//                     offset: const Offset(0, 15),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Header
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.symmetric(
//                       vertical: 20,
//                       horizontal: 24,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.red.shade600,
//                       borderRadius: const BorderRadius.vertical(
//                         top: Radius.circular(20),
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(
//                           Icons.warning_amber_rounded,
//                           color: Colors.white,
//                           size: 40,
//                         ),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 "Insufficient Stock",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 22,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 "The following items exceed available stock.",
//                                 style: TextStyle(
//                                   color: Colors.white.withOpacity(0.9),
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   // Body - Only Insufficient Items
//                   Flexible(
//                     child: Padding(
//                       padding: const EdgeInsets.all(24),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const SizedBox(height: 10),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               vertical: 14,
//                               horizontal: 12,
//                             ),
//                             decoration: BoxDecoration(
//                               color: Colors.red.shade700,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   flex: 5,
//                                   child: Text(
//                                     "Item",
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 15,
//                                     ),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 2,
//                                   child: Center(
//                                     child: Text(
//                                       "Required",
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 15,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 2,
//                                   child: Center(
//                                     child: Text(
//                                       "Available",
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 15,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 2,
//                                   child: Center(
//                                     child: Text(
//                                       "Shortage",
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 15,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                           Flexible(
//                             child: ListView.separated(
//                               shrinkWrap: true,
//                               separatorBuilder: (_, __) =>
//                                   const SizedBox(height: 10),
//                               itemCount: insufficientItems.length,
//                               itemBuilder: (context, i) {
//                                 final row = insufficientItems[i];
//                                 final double shortage =
//                                     (row['required'] as double) -
//                                     (row['available'] as double);
//                                 return Container(
//                                   padding: const EdgeInsets.symmetric(
//                                     vertical: 16,
//                                     horizontal: 12,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     color: Colors.red.shade50,
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(
//                                       color: Colors.red.shade300,
//                                       width: 1.8,
//                                     ),
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       Expanded(
//                                         flex: 5,
//                                         child: Text(
//                                           row['item'],
//                                           style: TextStyle(
//                                             fontWeight: FontWeight.w600,
//                                             fontSize: 15,
//                                             color: Colors.red.shade900,
//                                           ),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: Center(
//                                           child: Text(
//                                             "${row['required'].toStringAsFixed(row['isKg'] ? 3 : 0)} ${row['uom']}",
//                                             style: TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.red.shade800,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: Center(
//                                           child: Text(
//                                             "${row['available'].toStringAsFixed(row['isKg'] ? 3 : 0)} ${row['uom']}",
//                                             style: TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.red.shade800,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: Center(
//                                           child: Container(
//                                             padding: const EdgeInsets.symmetric(
//                                               horizontal: 16,
//                                               vertical: 8,
//                                             ),
//                                             decoration: BoxDecoration(
//                                               color: Colors.red.shade600,
//                                               borderRadius:
//                                                   BorderRadius.circular(20),
//                                             ),
//                                             child: Text(
//                                               "-${shortage.toStringAsFixed(row['isKg'] ? 3 : 0)}",
//                                               style: const TextStyle(
//                                                 color: Colors.white,
//                                                 fontWeight: FontWeight.bold,
//                                                 fontSize: 14,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               },
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   // Footer
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
//                     child: SizedBox(
//                       width: double.infinity,
//                       height: 56,
//                       child: ElevatedButton(
//                         onPressed: () => Navigator.pop(ctx),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.red.shade600,
//                           foregroundColor: Colors.white,
//                           elevation: 8,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(14),
//                           ),
//                         ),
//                         child: const Text(
//                           "Close & Adjust Quantities",
//                           style: TextStyle(
//                             fontSize: 17,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//         setState(() {
//           _isSubmitting = false;
//         });
//         return; // Stop printing
//       }
//       // === ALL STOCK OK → PROCEED TO PRINT ===
//       await saveInvoiceToHiveAndPrint1();
//       //final cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
//       cartProvider.clearItems();
//       Navigator.of(context).pop();
//     } catch (e, stack) {
//       developer.log(
//         'Print/Save failed',
//         name: 'SalesInvoice',
//         error: e,
//         stackTrace: stack,
//       );
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Print failed: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       final stateProvider = Provider.of<SalesInvoiceState>(
//         context,
//         listen: false,
//       );
//       stateProvider.reset();
//       final qrProvider = Provider.of<RazorpayQRProvider>(
//         context,
//         listen: false,
//       );
//       qrProvider.disconnectWebSocket();
//       qrProvider.isCardPaid = false;
//       qrProvider.errorMessage = null;
//       setState(() {
//         _isSubmitting = false;
//       });
//     }
//   }
//   @override
//   Widget build(BuildContext context) {
//     debugPrint('entered1');
//     return Stack(
//       children: [
//         Scaffold(
//           backgroundColor: Colors.white,
//           body: RepaintBoundary(
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CustomText(
//                       text: 'Payment Details',
//                       style: const TextStyle(
//                         fontFamily: 'Poppins',
//                         fontSize: 32,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black,
//                       ),
//                     ),
//                     const CustomSizedBox(height: 20),
//                     /// Sales Person + Birthday Row
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Consumer<SalesInvoiceState>(
//                           builder: (context, p, _) {
//                             return Expanded(
//                               flex: 2,
//                               child: Material(
//                                 elevation: 4,
//                                 shadowColor: Colors.black,
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 child: Stack(
//                                   children: [
//                                     Autocomplete<String>(
//                                       optionsMaxHeight: 120,
//                                       optionsViewBuilder:
//                                           (context, onSelected, options) {
//                                             return Material(
//                                               color: Colors.white,
//                                               shadowColor: Colors.black,
//                                               elevation: 4,
//                                               borderRadius:
//                                                   const BorderRadius.only(
//                                                     bottomLeft: Radius.circular(
//                                                       8,
//                                                     ),
//                                                     bottomRight:
//                                                         Radius.circular(8),
//                                                   ),
//                                               child: ListView.separated(
//                                                 separatorBuilder:
//                                                     (context, index) =>
//                                                         const Divider(
//                                                           thickness: 1,
//                                                           color: Colors.black12,
//                                                         ),
//                                                 shrinkWrap: true,
//                                                 itemCount: options.length,
//                                                 itemBuilder: (context, index) {
//                                                   final option = options
//                                                       .elementAt(index);
//                                                   return ListTile(
//                                                     title: Text(option),
//                                                     onTap: () =>
//                                                         onSelected(option),
//                                                   );
//                                                 },
//                                               ),
//                                             );
//                                           },
//                                       optionsBuilder: (textEditingValue) {
//                                         if (textEditingValue.text.isEmpty) {
//                                           return const Iterable<String>.empty();
//                                         }
//                                         final query = textEditingValue.text
//                                             .toLowerCase();
//                                         return _allEmployees.keys.where(
//                                           (key) =>
//                                               key.toLowerCase().contains(query),
//                                         );
//                                       },
//                                       onSelected: (String selection) =>
//                                           _selectEmployee(selection),
//                                       fieldViewBuilder:
//                                           (
//                                             context,
//                                             controllers,
//                                             focusNode,
//                                             onFieldSubmitted,
//                                           ) {
//                                             controllers.value =
//                                                 _employeeNumberController.value;
//                                             return TextFormField(
//                                               readOnly: true,
//                                               showCursor: true,
//                                               controller:
//                                                   _employeeNumberController,
//                                               focusNode: focusNode,
//                                               onTap: () =>
//                                                   setCurrentFocusForController(
//                                                     _employeeNumberController,
//                                                   ),
//                                               decoration: InputDecoration(
//                                                 labelText: "Sales Person",
//                                                 labelStyle: const TextStyle(
//                                                   fontFamily: 'Poppins',
//                                                   color: Colors.black54,
//                                                 ),
//                                                 border: OutlineInputBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(8),
//                                                 ),
//                                                 focusedBorder:
//                                                     OutlineInputBorder(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             8,
//                                                           ),
//                                                       borderSide:
//                                                           const BorderSide(
//                                                             color: Colors.blue,
//                                                             width: 1,
//                                                           ),
//                                                     ),
//                                                 enabledBorder:
//                                                     OutlineInputBorder(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             8,
//                                                           ),
//                                                       borderSide:
//                                                           const BorderSide(
//                                                             color:
//                                                                 Colors.black12,
//                                                           ),
//                                                     ),
//                                                 contentPadding:
//                                                     const EdgeInsets.symmetric(
//                                                       vertical: 15,
//                                                       horizontal: 10,
//                                                     ),
//                                                 suffixIcon: IconButton(
//                                                   icon: const Icon(
//                                                     Icons.qr_code_scanner,
//                                                   ),
//                                                   onPressed: _toggleQrMode,
//                                                   tooltip: 'Scan Employee QR',
//                                                 ),
//                                               ),
//                                             );
//                                           },
//                                     ),
//                                     if (_isQrMode)
//                                       Offstage(
//                                         offstage: true,
//                                         child: TextField(
//                                           focusNode: _qrFocusNode,
//                                           controller: _qrController,
//                                           keyboardType: TextInputType.none,
//                                           onSubmitted: _handleQrInput,
//                                           decoration: const InputDecoration(
//                                             border: InputBorder.none,
//                                           ),
//                                           style: const TextStyle(
//                                             fontFamily: 'Poppins',
//                                             fontSize: 0,
//                                           ),
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               controller: _birthdayController,
//                               focusNode: _getFocusNodeForController(
//                                 _birthdayController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _birthdayController,
//                               ),
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               decoration: InputDecoration(
//                                 labelText: "Birthday Date",
//                                 labelStyle: const TextStyle(
//                                   fontFamily: 'Poppins',
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               controller: _customChargeController,
//                               focusNode: _getFocusNodeForController(
//                                 _customChargeController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _customChargeController,
//                               ),
//                               inputFormatters: [
//                                 FilteringTextInputFormatter.digitsOnly,
//                               ],
//                               decoration: InputDecoration(
//                                 prefixText: "₹",
//                                 labelText: "Custom Charge",
//                                 labelStyle: const TextStyle(
//                                   fontFamily: 'Poppins',
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                               onChanged: (value) {
//                                 double charge = double.tryParse(value) ?? 0.0;
//                                 _updateBalance();
//                               },
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 20),
//                     /// Customer + Discount + Custom Charge Row
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         SizedBox(
//                           width: 300,
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: CustomerSearchDropdown(
//                               showTopProducts: false,
//                               customerNumberController:
//                                   _customerNumberController,
//                               focusNode: _getFocusNodeForController(
//                                 _customerNumberController,
//                               ),
//                               readOnly: true,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               controller: _discountController,
//                               focusNode: _getFocusNodeForController(
//                                 _discountController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _discountController,
//                               ),
//                               inputFormatters: [
//                                 FilteringTextInputFormatter.digitsOnly,
//                               ],
//                               decoration: InputDecoration(
//                                 prefixIcon: const Icon(Icons.percent),
//                                 labelText: "Discount",
//                                 labelStyle: const TextStyle(
//                                   fontFamily: 'Poppins',
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                               onChanged: (value) {
//                                 if (value.isEmpty) {
//                                   _applyDiscount('0');
//                                 } else if (value.length > 2) {
//                                   _discountController.text = value.substring(
//                                     0,
//                                     2,
//                                   );
//                                   _discountController
//                                       .selection = TextSelection.fromPosition(
//                                     TextPosition(
//                                       offset: _discountController.text.length,
//                                     ),
//                                   );
//                                   _applyDiscount(_discountController.text);
//                                 } else {
//                                   _applyDiscount(value);
//                                 }
//                               },
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               controller: _couponCodeController,
//                               focusNode: _getFocusNodeForController(
//                                 _couponCodeController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _couponCodeController,
//                               ),
//                               inputFormatters: [
//                                 FilteringTextInputFormatter.digitsOnly,
//                               ],
//                               decoration: InputDecoration(
//                                 prefixIcon: Icon(Icons.local_offer_outlined),
//                                 labelText: "Coupon Code",
//                                 labelStyle: const TextStyle(
//                                   fontFamily: 'Poppins',
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                               onChanged: (value) {
//                                 double charge = double.tryParse(value) ?? 0.0;
//                                 _updateBalance();
//                               },
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const CustomSizedBox(height: 20),
//                     /// Payment Section + Numeric Keyboard
//                     Consumer<SalesInvoiceState>(
//                       builder: (context, prov, _) {
//                         return Row(
//                           children: [
//                             Expanded(
//                               flex: 2,
//                               child: Column(
//                                 children: [
//                                   Padding(
//                                     padding: const EdgeInsets.only(
//                                       left: 10,
//                                       bottom: 20,
//                                     ),
//                                     child: Material(
//                                       elevation: 4,
//                                       shadowColor: Colors.black,
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(8),
//                                       child: Padding(
//                                         padding: const EdgeInsets.only(
//                                           left: 10,
//                                         ),
//                                         child: _buildPaymentSection('Cash'),
//                                       ),
//                                     ),
//                                   ),
//                                   Padding(
//                                     padding: const EdgeInsets.only(
//                                       left: 10,
//                                       bottom: 20,
//                                     ),
//                                     child: Material(
//                                       elevation: 4,
//                                       shadowColor: Colors.black,
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(8),
//                                       child: Padding(
//                                         padding: const EdgeInsets.only(
//                                           left: 20,
//                                         ),
//                                         child: _buildPaymentSection('Upi'),
//                                       ),
//                                     ),
//                                   ),
//                                   Padding(
//                                     padding: const EdgeInsets.only(
//                                       left: 10,
//                                       bottom: 20,
//                                     ),
//                                     child: Material(
//                                       elevation: 4,
//                                       shadowColor: Colors.black,
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(8),
//                                       child: Padding(
//                                         padding: const EdgeInsets.only(
//                                           left: 10,
//                                         ),
//                                         child: _buildPaymentSection('Card'),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const VerticalDivider(width: 20, thickness: 1),
//                             Expanded(
//                               flex: 2,
//                               child: ValueListenableBuilder<int>(
//                                 valueListenable: _currentFocusIndexNotifier,
//                                 builder: (context, currentFocusIndex, _) {
//                                   return Column(
//                                     children: [
//                                       Container(
//                                         constraints: const BoxConstraints(
//                                           maxWidth: 300,
//                                         ),
//                                         child: NumericKeyboard(
//                                           focusNode:
//                                               _focusNodes[currentFocusIndex],
//                                           controller:
//                                               _keyboardControllers[currentFocusIndex],
//                                           onTextInput: _handleKeyboardTextInput,
//                                           onBackspace: _handleKeyboardBackspace,
//                                           onOk: _handleKeyboardOk,
//                                           isLastField:
//                                               currentFocusIndex ==
//                                               _keyboardControllers.length - 1,
//                                         ),
//                                       ),
//                                       const SizedBox(height: 10),
//                                     ],
//                                   );
//                                 },
//                               ),
//                             ),
//                           ],
//                         );
//                       },
//                     ),
//                     const CustomSizedBox(height: 10),
//                     /// Mini Cards + Print Button
//                     Consumer2<CurrentSaleProvider, SalesInvoiceState>(
//                       builder: (context, salesProvider, statesProvider, _) {
//                         // FIXED: Proper balance display logic
//                         final double rawBalance = statesProvider.balanceAmount;
//                         final String balanceDisplay;
//                         if (rawBalance < 0) {
//                           balanceDisplay =
//                               "-₹${rawBalance.abs().toStringAsFixed(0)}";
//                         } else if (rawBalance == 0) {
//                           balanceDisplay = "₹0";
//                         } else {
//                           balanceDisplay = "₹${rawBalance.toStringAsFixed(0)}";
//                         }
//                         return Row(
//                           children: [
//                             _buildMiniCard(
//                               title: "Total",
//                               value:
//                                   "₹${getTotalWithAdjustments().toStringAsFixed(0)}",
//                               gradient: [Colors.blue[200]!, Colors.blue[500]!],
//                             ),
//                             const SizedBox(width: 5),
//                             _buildMiniCard(
//                               title: "Balance",
//                               value: balanceDisplay,
//                               gradient: [Colors.blue[200]!, Colors.blue[500]!],
//                             ),
//                             const SizedBox(width: 10),
//                             SizedBox(
//                               height: 75,
//                               width: 300,
//                               child: ElevatedButton(
//                                 style: ButtonStyle(
//                                   backgroundColor: MaterialStateProperty.all(
//                                     statesProvider.isPrintButtonEnabled
//                                         ? Colors.blue
//                                         : Colors.grey,
//                                   ),
//                                   foregroundColor: MaterialStateProperty.all(
//                                     Colors.white,
//                                   ),
//                                   padding: MaterialStateProperty.all(
//                                     const EdgeInsets.symmetric(
//                                       horizontal: 30.0,
//                                       vertical: 18.0,
//                                     ),
//                                   ),
//                                   shape:
//                                       MaterialStateProperty.all<
//                                         RoundedRectangleBorder
//                                       >(
//                                         RoundedRectangleBorder(
//                                           borderRadius: BorderRadius.circular(
//                                             8.0,
//                                           ),
//                                         ),
//                                       ),
//                                   elevation: MaterialStateProperty.all(5.0),
//                                 ),
//                                 onPressed: statesProvider.isPrintButtonEnabled
//                                     ? () async {
//                                         Future.microtask(
//                                           () => _printReceiptDetails(),
//                                         );
//                                       }
//                                     : null,
//                                 child: const CustomText(
//                                   text: "Print Receipt",
//                                   style: TextStyle(
//                                     fontFamily: 'Poppins',
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         );
//                       },
//                     ),
//                     const CustomSizedBox(height: 10),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//         if (_isSubmitting)
//           Positioned.fill(
//             child: Stack(
//               children: [
//                 // Block touches but keep background visible
//                 const ModalBarrier(
//                   dismissible: false,
//                   color: Colors.transparent, // keep original background visible
//                 ),
//                 // Center loader
//                 const Center(
//                   child: CircularProgressIndicator(color: Colors.blue),
//                 ),
//               ],
//             ),
//           ),
//       ],
//     );
//   }
// }
// Widget _buildMiniCard({
//   required String title,
//   required String value,
//   required List<Color> gradient,
// }) {
//   return Expanded(
//     child: Container(
//       height: 80,
//       margin: const EdgeInsets.symmetric(horizontal: 4),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: gradient,
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey[400]!,
//             offset: const Offset(2, 2),
//             blurRadius: 6,
//           ),
//           const BoxShadow(
//             color: Colors.white,
//             offset: Offset(-2, -2),
//             blurRadius: 6,
//           ),
//         ],
//       ),
//       padding: const EdgeInsets.all(8),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           FittedBox(
//             fit: BoxFit.scaleDown,
//             child: Text(
//               title,
//               style: const TextStyle(
//                 fontFamily: 'Poppins',
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.black87,
//               ),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           const SizedBox(height: 4),
//           FittedBox(
//             fit: BoxFit.scaleDown,
//             child: Text(
//               value,
//               style: const TextStyle(
//                 fontFamily: 'Poppins',
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// class NumericKeyboard extends StatelessWidget {
//   final FocusNode focusNode;
//   final TextEditingController controller;
//   final Function(String)? onTextInput;
//   final VoidCallback? onBackspace;
//   final VoidCallback? onOk;
//   final bool isLastField;

//   const NumericKeyboard({
//     super.key,
//     required this.focusNode,
//     required this.controller,
//     this.onTextInput,
//     this.onBackspace,
//     this.onOk,
//     this.isLastField = false,
//   });

//   void _textInputHandler(String text) {
//     if (onTextInput != null) {
//       onTextInput!(text);
//     } else {
//       final currentText = controller.text;
//       final newText = currentText + text;
//       controller.text = newText;
//       controller.selection = TextSelection.collapsed(offset: newText.length);
//     }
//   }

//   void _backspaceHandler() {
//     if (onBackspace != null) {
//       onBackspace!();
//     } else {
//       final currentText = controller.text;
//       if (currentText.isNotEmpty) {
//         final newText = currentText.substring(0, currentText.length - 1);
//         controller.text = newText;
//         controller.selection = TextSelection.collapsed(offset: newText.length);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildKey('7', () => _textInputHandler('7')),
//             _buildKey('8', () => _textInputHandler('8')),
//             _buildKey('9', () => _textInputHandler('9')),
//           ],
//         ),
//         const SizedBox(height: 6),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildKey('4', () => _textInputHandler('4')),
//             _buildKey('5', () => _textInputHandler('5')),
//             _buildKey('6', () => _textInputHandler('6')),
//           ],
//         ),
//         const SizedBox(height: 6),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildKey('1', () => _textInputHandler('1')),
//             _buildKey('2', () => _textInputHandler('2')),
//             _buildKey('3', () => _textInputHandler('3')),
//           ],
//         ),
//         const SizedBox(height: 6),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildKey('0', () => _textInputHandler('0')),
//             _buildKey('C', () {
//               controller.clear();
//               if (onTextInput != null)
//                 onTextInput!(''); // optional: notify parent
//             }),
//             _buildKey('⌫', _backspaceHandler),
//           ],
//         ),

//         const SizedBox(height: 6),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [_buildKey('OK', onOk ?? () {}, isAction: true, flex: 1)],
//         ),
//       ],
//     );
//   }

//   Widget _buildKey(
//     String label,
//     VoidCallback onPressed, {
//     int flex = 1,
//     bool isAction = false,
//     bool isEnabled = true,
//   }) {
//     return Expanded(
//       flex: flex,
//       child: Container(
//         margin: const EdgeInsets.all(4),
//         child: ElevatedButton(
//           onPressed: isEnabled ? onPressed : null,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: isAction ? Colors.blue : Colors.white,
//             foregroundColor: isAction ? Colors.white : Colors.black,
//             padding: const EdgeInsets.symmetric(vertical: 12),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(8),
//               side: BorderSide(color: Colors.grey.shade300),
//             ),
//             disabledBackgroundColor: Colors.grey[200],
//             disabledForegroundColor: Colors.grey[400],
//           ),
//           child: Text(
//             label,
//             style: const TextStyle(
//               fontFamily: 'Poppins',
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class CustomNumberInputFormatter extends TextInputFormatter {
//   @override
//   TextEditingValue formatEditUpdate(
//     TextEditingValue oldValue,
//     TextEditingValue newValue,
//   ) {
//     // Allow only digits
//     if (newValue.text.isEmpty) {
//       return newValue;
//     }

//     // Check if all characters are digits
//     if (!RegExp(r'^[0-9]+$').hasMatch(newValue.text)) {
//       return oldValue;
//     }

//     // Limit to 10 digits
//     if (newValue.text.length > 10) {
//       return oldValue;
//     }

//     // Validate Indian mobile number format only when 10 digits are entered
//     if (newValue.text.length == 10) {
//       if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(newValue.text)) {
//         // If 10 digits but doesn't start with 6-9, keep the old value
//         return oldValue;
//       }
//     }

//     return newValue;
//   }
// }



  //  void _printReceiptDetails() async {
  //   if (_isSubmitting) return;
  //   _isSubmitting = true;

  //   try {
  //     // Step 1: Generate new invoice number
  //     var invoiceNumberGenerator = InvoiceNumberGenerator();
  //     String newInvoiceNumber = await invoiceNumberGenerator.generateInvoiceNumber();

  //     // Step 2: Save invoice to server + Hive
  //     await saveInvoiceToHiveAndPrint1(newInvoiceNumber);

  //     // Step 3: Get the GLOBAL pending box (FIXED!)
  //     final pendingBox = HiveService().pendingBox;

  //     // Step 4: Get all pending prints (oldest first)
  //     final List<PendingPrintInvoice> pendingInvoices = pendingBox.values.toList()
  //       ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  //     developer.log("Found ${pendingInvoices.length} pending bill(s) to reprint", name: 'PrintRecovery');

  //     // Step 5: Reprint ALL pending invoices FIRST
  //     for (var pending in pendingInvoices) {
  //       try {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text("Reprinting saved bill: ${pending.invoiceNo}"),
  //             backgroundColor: Colors.orange[700],
  //             duration: const Duration(seconds: 800),
  //           ),
  //         );

  //         await _reprintPendingInvoice(pending);
  //         //await pending.delete(); // Remove only after success
  //         await Future.delayed(const Duration(milliseconds: 1200)); // Prevent paper jam
  //       } catch (e) {
  //         developer.log("Failed to reprint pending: ${pending.invoiceNo} | Error: $e");
  //         // Don't delete if failed — will try again next time
  //       }
  //     }

  //     // Step 6: Now print the CURRENT (new) invoice
  //     if (isPrintEnabled) {
  //       final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);

  //       final printer = ReceiptPrinter(
  //         employeeNumberController: stateProvider.selectedEmployeeFirstName ?? "Staff",
  //         customerNumberController: _customerNumberController,
  //         discountController: _discountController,
  //         customChargeController: _customChargeController,
  //         selectedPaymentOptionValue: stateProvider.selectedPaymentOptionValue,
  //         totalAmount: widget.totalAmount,
  //         context: context,
  //         selectedPaymentOption: stateProvider.selectedPaymentOption,
  //         discountAmount: stateProvider.roundedDiscountAmount,
  //         invoiceNo: newInvoiceNumber,
  //         cashAmount: stateProvider.cashAmount,
  //         cardAmount: stateProvider.cardAmount,
  //         upiAmount: stateProvider.upiAmount,
  //         newInvoiceNumber: newInvoiceNumber,
  //       );

  //       await printer.printReceiptDetails();
  //     }

  //     // Success: Pop screen
  //     if (mounted) Navigator.of(context).pop();
  //   } catch (e, stack) {
  //     developer.log('Print/Save failed', name: 'SalesInvoice', error: e, stackTrace: stack);
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red),
  //       );
  //     }
  //   } finally {
  //     // Always reset state
  //     final stateProvider = Provider.of<SalesInvoiceState>(context, listen: false);
  //     stateProvider.reset();

  //     final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
  //     qrProvider.disconnectWebSocket();
  //     qrProvider.isCardPaid = false;
  //     qrProvider.errorMessage = null;

  //     final cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
  //     cartProvider.clearItems();

  //     _isSubmitting = false;
  //   }
  // }

  //  Future<void> _reprintPendingInvoice(PendingPrintInvoice pending) async {
  //   final data = pending.printData;

  //   final printer = ReceiptPrinter(
  //     employeeNumberController: data['employeeNumberController'] ?? "Staff",
  //     customerNumberController: TextEditingController(text: data['customerNumberController'] ?? ""),
  //     discountController: TextEditingController(text: data['discountController'] ?? "0"),
  //     customChargeController: TextEditingController(text: data['customChargeController'] ?? "0"),
  //     selectedPaymentOptionValue: data['selectedPaymentOptionValue'] ?? "",
  //     totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
  //     context: context,
  //     selectedPaymentOption: data['selectedPaymentOption'] ?? "",
  //     discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
  //     invoiceNo: pending.invoiceNo,
  //     cashAmount: (data['cashAmount'] as num?)?.toDouble() ?? 0.0,
  //     cardAmount: (data['cardAmount'] as num?)?.toDouble() ?? 0.0,
  //     upiAmount: (data['upiAmount'] as num?)?.toDouble() ?? 0.0,
  //     newInvoiceNumber: data['newInvoiceNumber'] ?? pending.invoiceNo,
  //   );

  //   await printer.printReceiptDetails();
  // }
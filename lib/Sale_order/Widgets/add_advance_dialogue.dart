import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Provider/connectivity_internet.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/allorderprint.dart';

import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Sale_order/Widgets/advance_amount_payment_keybaord.dart';
import 'package:yen_pos/Sale_order/Widgets/cheque_details.dart';
import 'package:yen_pos/Server_Client/handlers/saleorder_handlemessage.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';
import 'package:lottie/lottie.dart';

class AddAdvancePayment extends StatefulWidget {
  final SalesOrderDisplay salesOrder;

  const AddAdvancePayment({super.key, required this.salesOrder});

  @override
  State<AddAdvancePayment> createState() => _AddAdvancePaymentState();
}

class _AddAdvancePaymentState extends State<AddAdvancePayment> {
  // Controllers
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();
  final TextEditingController _chequeNumberController = TextEditingController();
  final TextEditingController _chequeAmountController = TextEditingController();
  final TextEditingController _chequeNameController = TextEditingController();
  final TextEditingController _chequeBankController = TextEditingController();
  final TextEditingController _chequeDateController = TextEditingController();
  final TextEditingController _employeeNumberController =
      TextEditingController();
  final TextEditingController _customerNumberController =
      TextEditingController();
  final TextEditingController _customAmountController = TextEditingController();

  // Additional controllers from original code
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customChargeController = TextEditingController();
  final TextEditingController _customCashController = TextEditingController();
  final TextEditingController _customUpiController = TextEditingController();
  final TextEditingController _customCardController = TextEditingController();
  final TextEditingController advanceController = TextEditingController();

  // Focus nodes
  final Map<String, FocusNode> _focusNodes = {
    'cash': FocusNode(),
    'upi': FocusNode(),
    'card': FocusNode(),
    'chequeNumber': FocusNode(),
    'chequeAmount': FocusNode(),
    'chequeName': FocusNode(),
    'chequeDate': FocusNode(),
  };

  // State variables
  bool _showChequeDetails = false;
  bool _isCompleteButtonEnabled = false;
  bool _isInitialSend = true;
  bool _isChequeSelected = false;
  bool isSubmitting = false;
  double _balanceAmount = 0.0;
  double _totalAmount = 0.0;
  double _originalAmount = 0.0;
  double _upiAndCashAmount = 0.0;
  String salesOrderId = '';
  String? _activePaymentMethod;
  String selectedPaymentMethod = 'Cash';

  // WebSocket and printer
  late salesInvoiceReceiptPrinter receiptPrinter;
  Map<String, dynamic> _lastSentData = {};
  OverlayEntry? _overlayEntry;

  // Lists
  late final List<String> _cashOptions;
  late final List<double> _totalAmountList;

  // Calculated getters
  double get _cashAmount => double.tryParse(_cashController.text) ?? 0;
  double get _upiAmount => double.tryParse(_upiController.text) ?? 0;
  double get _cardAmount => double.tryParse(_cardController.text) ?? 0;
  double get _chequeAmount =>
      double.tryParse(_chequeAmountController.text) ?? 0;

  double get _alreadyPaid =>
      widget.salesOrder.advanceAmount?.fold(0.0, (sum, e) => sum! + e) ?? 0.0;
  double get _remainingBalance =>
      (widget.salesOrder.totalAmount +
          (widget.salesOrder.totalCustomCharge ?? 0.0)) -
      _alreadyPaid;
  double get _newPayment =>
      _cashAmount + _upiAmount + _cardAmount + _chequeAmount;

  @override
  void initState() {
    super.initState();

    // Calculate initial values
    final alreadyPaid = _alreadyPaid;
    final customCharge = widget.salesOrder.totalCustomCharge ?? 0.0;

    _totalAmountList = List.from(widget.salesOrder.advanceAmount ?? []);
    _totalAmount = widget.salesOrder.totalAmount + customCharge;
    _balanceAmount = _totalAmount - alreadyPaid;
    _originalAmount = alreadyPaid;
    _upiAndCashAmount = alreadyPaid;
    salesOrderId = widget.salesOrder.saleOrderNo ?? '';

    // Generate cash options
    _cashOptions = _generateCashOptions(alreadyPaid);

    // Initialize controllers with listeners
    _initializeControllers();
  }

  void _initializeControllers() {
    // Setup validation for payment controllers
    void setupPaymentValidation(
      TextEditingController controller,
      String method,
    ) {
      controller.addListener(() {
        _validatePaymentAmount(controller, method);
        _validateForm();
      });
    }

    // Setup all controllers
    setupPaymentValidation(_cashController, "Cash");
    setupPaymentValidation(_upiController, "UPI");
    setupPaymentValidation(_cardController, "Card");
    setupPaymentValidation(_chequeAmountController, "Cheque");

    // Setup other controllers
    final otherControllers = [
      _employeeNumberController,
      _customerNumberController,
      _customAmountController,
      _discountController,
      _customChargeController,
      _customCashController,
      _customUpiController,
      _customCardController,
      advanceController,
    ];

    for (final controller in otherControllers) {
      controller.addListener(_validateForm);
    }
  }

  void _validatePaymentAmount(TextEditingController controller, String method) {
    final entered = double.tryParse(controller.text) ?? 0;
    final otherPayments = _calculateOtherPayments(method);
    final remainingBalance = _remainingBalance - otherPayments;

    if (entered > remainingBalance) {
      controller.text = remainingBalance.toStringAsFixed(0);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Entered $method amount exceeds remaining balance. Max allowed: ₹${remainingBalance.toStringAsFixed(0)}",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    _updateBalance();
  }

  double _calculateOtherPayments(String excludeMethod) {
    double total = 0;
    if (excludeMethod != "Cash") total += _cashAmount;
    if (excludeMethod != "UPI") total += _upiAmount;
    if (excludeMethod != "Card") total += _cardAmount;
    if (excludeMethod != "Cheque") total += _chequeAmount;
    return total;
  }

  void _validateForm() {
    final total = _newPayment;
    _isCompleteButtonEnabled = total > 0;
    if (mounted) setState(() {});
  }

  void _updateBalance() {
    if (!mounted) return;

    setState(() {
      if (_newPayment > _remainingBalance) {
        _showBalanceExceededWarning();
        _resetExcessPayments();
        _balanceAmount = 0;
      } else {
        _balanceAmount = _remainingBalance - _newPayment;
      }
    });
  }

  void _showBalanceExceededWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Entered amount exceeds remaining balance (₹${_remainingBalance.toStringAsFixed(0)})!",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetExcessPayments() {
    if (_cashAmount > _remainingBalance) _cashController.clear();
    if (_upiAmount > _remainingBalance) _upiController.clear();
    if (_cardAmount > _remainingBalance) _cardController.clear();
    if (_chequeAmount > _remainingBalance) _chequeAmountController.clear();
  }

  List<String> _generateCashOptions(double amount) {
    final options = <String>{};
    final exactAmount = amount.ceil();
    options.add(exactAmount.toString());

    final nextImmediateRound = (exactAmount % 50 == 0)
        ? exactAmount + 50
        : ((exactAmount / 50).ceil() * 50);
    options.add(nextImmediateRound.toString());

    final higherRoundFigure = (nextImmediateRound % 100 == 0)
        ? nextImmediateRound + 100
        : ((nextImmediateRound / 100).ceil() * 100);
    options.add(higherRoundFigure.toString());

    return options.toList();
  }

  String _getSuggestedAmount(String method) {
    final controller = _getControllerForMethod(method);
    if (controller.text.isNotEmpty) return "0";

    final remaining = _remainingBalance - _calculateOtherPayments(method);
    return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
  }

  TextEditingController _getControllerForMethod(String method) {
    switch (method) {
      case "Cash":
        return _cashController;
      case "UPI":
        return _upiController;
      case "Card":
        return _cardController;
      case "Cheque":
        return _chequeAmountController;
      default:
        return TextEditingController();
    }
  }

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

    if (changedFields.isEmpty) return;

    _lastSentData.addAll(changedFields);
    final message = {
      'message': 'changed_fields',
      'type': type,
      ...changedFields,
    };

    try {
      final jsonData = jsonEncode(message);
      sendataToServer(jsonDecode(jsonData));
    } catch (e) {
      // Handle error
    }
  }

  void _handleCardPayment() {
    final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    final cardAmountStr = _cardController.text;

    if (cardAmountStr.isNotEmpty) {
      final cardAmount = double.tryParse(cardAmountStr);
      if (cardAmount != null && cardAmount > 0) {
        qrProvider.createOrderAndPay(cardAmount, (
          String type,
          Map<String, dynamic>? extraData,
        ) {
          if (type == 'card_payment_success') {
            stateProvider.updateIsCardPaid(true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Card payment successful!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else if (type == 'card_payment_error') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Card payment failed: ${extraData?['message'] ?? 'Unknown error'}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid card amount greater than 0.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a card amount first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showUpiQrDialog(double amount, {required VoidCallback onSuccess}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RazorpayQRProvider>(context, listen: false).createQR(amount);
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
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onSuccess();
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

  Future<void> _submitAdvancePayment() async {
    if (isSubmitting) return;

    try {
      isSubmitting = true;
      if (mounted) setState(() {});

      print("▶️ Add Advance button pressed");

      // Validate total entered amount
      if (_newPayment > _remainingBalance) {
        _showBalanceExceededWarning();
        return;
      }

      // Prepare payment data
      final paymentData = _preparePaymentData();

      // Merge with existing data
      final updatedData = _mergeWithExistingData(paymentData);

      // Send to server
      await _sendPaymentToServer(updatedData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Advance payment updated successfully!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      print("🎉 Advance payment updated successfully");
    } catch (e, stack) {
      print("🔥 Exception occurred: $e");
      print("📍 StackTrace: $stack");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      isSubmitting = false;
      if (mounted) setState(() {});
    }
  }

  Map<String, dynamic> _preparePaymentData() {
    final paymentTypes = <String>[];
    final modeAmounts = <double>[];

    final payments = [
      {"method": "Cash", "amount": _cashAmount, "controller": _cashController},
      {"method": "Card", "amount": _cardAmount, "controller": _cardController},
      {"method": "UPI", "amount": _upiAmount, "controller": _upiController},
      {
        "method": "Cheque",
        "amount": _chequeAmount,
        "controller": _chequeAmountController,
      },
    ];

    for (final payment in payments) {
      final amount = payment["amount"] as double;
      if (amount > 0) {
        paymentTypes.add(payment["method"] as String);
        modeAmounts.add(amount);
      }
    }

    return {
      "paymentTypes": paymentTypes,
      "modeAmounts": modeAmounts,
      "totalEntered": _newPayment,
    };
  }

  Map<String, dynamic> _mergeWithExistingData(Map<String, dynamic> newPayment) {
    final existingAdvanceAmount = List<double>.from(
      widget.salesOrder.advanceAmount ?? [],
    );
    final existingPaymentType = List<List<String>>.from(
      widget.salesOrder.advancePaymentType ?? [],
    );
    final existingModeWiseAmount = List<List<double>>.from(
      widget.salesOrder.modeWiseAmount ?? [],
    );
    final existingDateTime = List<String>.from(
      widget.salesOrder.advanceDateTime ?? [],
    );

    existingAdvanceAmount.add(newPayment["totalEntered"] as double);
    existingPaymentType.add(newPayment["paymentTypes"] as List<String>);
    existingModeWiseAmount.add(newPayment["modeAmounts"] as List<double>);
    existingDateTime.add(DateTime.now().toIso8601String());

    final updatedRemainingBalance =
        (widget.salesOrder.totalAmount +
            (widget.salesOrder.totalCustomCharge ?? 0.0)) -
        (_alreadyPaid + newPayment["totalEntered"] as double);

    return {
      "advanceAmount": existingAdvanceAmount,
      "advanceDateTime": existingDateTime,
      "advancePaymentType": existingPaymentType,
      "modeWiseAmount": existingModeWiseAmount,
      "balanceAmount": updatedRemainingBalance,
    };
  }

  Future<void> _sendPaymentToServer(Map<String, dynamic> data) async {
    final requestBody = {
      "data": data,
      "saleOrderNo": widget.salesOrder.saleOrderNo,
      "type": "patchSaleOrder",
      "editAbout": "Add Advance",
      "sync": "No",
      "edit": "No",
    };

    final connectivityProvider = Provider.of<ConnectivityProvider>(
      context,
      listen: false,
    );

    if (connectivityProvider.isConnected) {
      await sendataToServer(requestBody);
    } else {
      handlePatchSaleOrder(requestBody);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        elevation: 3,
        centerTitle: true,
        title: Text(
          "Advance Paid: ₹${_alreadyPaid.toStringAsFixed(0)}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildPaymentMethods()),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Select Payment Method",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Cash + Card Row
          Row(
            children: [
              Expanded(
                child: _buildPaymentEntry(
                  "Cash",
                  _cashController,
                  _focusNodes['cash']!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPaymentEntry(
                  "Card",
                  _cardController,
                  _focusNodes['card']!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // UPI + Cheque Row
          Row(
            children: [
              Expanded(
                child: _buildPaymentEntry(
                  "UPI",
                  _upiController,
                  _focusNodes['upi']!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildChequeToggle()),
            ],
          ),

          // Cheque Details
          if (_showChequeDetails) ...[
            const SizedBox(height: 8),
            ChequeDetails(
              chequeNumberController: _chequeNumberController,
              chequeAmountController: _chequeAmountController,
              chequeNameController: _chequeNameController,
              chequeDateController: _chequeDateController,
              chequeNumberFocus: _focusNodes['chequeNumber']!,
              chequeAmountFocus: _focusNodes['chequeAmount']!,
              chequeNameFocus: _focusNodes['chequeName']!,
              chequeDateFocus: _focusNodes['chequeDate']!,
              onFocusChanged: (index) {},
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentEntry(
    String method,
    TextEditingController controller,
    FocusNode focus,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-2, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              method,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          _buildSuggestedAmountButton(method),
          const SizedBox(width: 10),

          Expanded(
            flex: 3,
            child: _buildAmountInput(method, controller, focus),
          ),

          if (method == 'UPI' || method == 'Card')
            _buildPaymentIconButton(method, controller),
        ],
      ),
    );
  }

  Widget _buildSuggestedAmountButton(String method) {
    return GestureDetector(
      onTap: () {
        final controller = _getControllerForMethod(method);
        controller.text = _getSuggestedAmount(method);
        _updateBalance();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal[50],
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.3),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          _getSuggestedAmount(method),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInput(
    String method,
    TextEditingController controller,
    FocusNode focus,
  ) {
    return TextField(
      controller: controller,
      focusNode: focus,
      readOnly: true,
      showCursor: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: Colors.grey[50],
        hintText: 'Enter $method',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      onTap: () {
        ActiveField.activate(
          context: context,
          ctrl: controller,
          node: focus,
          numeric: true,
        );
      },
    );
  }

  Widget _buildPaymentIconButton(
    String method,
    TextEditingController controller,
  ) {
    return Consumer2<SalesInvoiceState, RazorpayQRProvider>(
      builder: (context, stateProvider, qrProvider, _) {
        final isUpiPaid = method == 'UPI' && stateProvider.isUpiPaid;
        final isCardPaid = method == 'Card' && stateProvider.isCardPaid;
        final shouldDisable = isUpiPaid || isCardPaid;
        final isPaymentEnabled = true; // Assuming this should always be true

        return IconButton(
          icon: Icon(
            method == 'UPI' ? Icons.qr_code : Icons.credit_card,
            color: shouldDisable ? Colors.grey : Colors.blue,
          ),
          onPressed: isPaymentEnabled && !shouldDisable
              ? () {
                  final amount = double.tryParse(controller.text) ?? 0;
                  if (controller.text.isNotEmpty && amount > 0) {
                    if (method == 'UPI') {
                      _showUpiQrDialog(
                        amount,
                        onSuccess: () {
                          Provider.of<SalesInvoiceState>(
                            context,
                            listen: false,
                          ).updateIsUpiPaid(true);

                          _customUpiController.text =
                              Provider.of<SalesInvoiceState>(
                                context,
                                listen: false,
                              ).upiAmount.toStringAsFixed(0);

                          _sendState(type: 'upi_payment_success');
                        },
                      );
                    } else {
                      _handleCardPayment();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Enter valid $method amount')),
                    );
                  }
                }
              : null,
        );
      },
    );
  }

  Widget _buildChequeToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showChequeDetails = !_showChequeDetails;
          _isChequeSelected = _showChequeDetails;
          if (_isChequeSelected) {
            _cashController.clear();
            _upiController.clear();
            _cardController.clear();
            _updateBalance();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Cheque",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Icon(
              _showChequeDetails
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      height: 220,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        "Total",
                        '₹${_totalAmount.toStringAsFixed(0)}',
                        Icons.attach_money,
                        [Colors.green.shade400, Colors.green.shade700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryCard(
                        "Balance",
                        '₹${_balanceAmount.toStringAsFixed(0)}',
                        Icons.account_balance_wallet,
                        [Colors.blue.shade400, Colors.blue.shade700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCompleteButtonEnabled
                              ? Colors.green[400]
                              : Colors.grey[400],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isCompleteButtonEnabled && !isSubmitting
                            ? _submitAdvancePayment
                            : null,
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                "Add Advance",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: SizedBox(
                height: double.infinity,
                child: ValueListenableBuilder<TextEditingController?>(
                  valueListenable: ActiveField.controller,
                  builder: (_, ctrl, __) {
                    return AdvanceAmountKeyboardWidgetAll2(
                      controller: ctrl ?? TextEditingController(),
                      onChanged: _updateBalance,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.4),
            offset: const Offset(0, 8),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Colors.black12,
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    final controllers = [
      _cashController,
      _upiController,
      _cardController,
      _chequeNumberController,
      _chequeAmountController,
      _chequeNameController,
      _chequeBankController,
      _chequeDateController,
      _employeeNumberController,
      _customerNumberController,
      _customAmountController,
      _discountController,
      _customChargeController,
      _customCashController,
      _customUpiController,
      _customCardController,
      advanceController,
    ];

    for (final controller in controllers) {
      controller.dispose();
    }

    // Dispose all focus nodes
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }

    // Remove overlay
    _overlayEntry?.remove();

    super.dispose();
  }
}

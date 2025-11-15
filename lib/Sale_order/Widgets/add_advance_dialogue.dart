import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Global/salesorder_websocket_service.dart';
import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yenpos/Sale_order/Widgets/advance_amount_payment_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/cheque_details.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';

class AddAdvancePayment extends StatefulWidget {
  final SalesOrderDisplay salesOrder;

  const AddAdvancePayment({super.key, required this.salesOrder});

  @override
  State<AddAdvancePayment> createState() => _AddAdvancePaymentState();
}

class _AddAdvancePaymentState extends State<AddAdvancePayment> {
  final List<String> cashOptions = [];
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _employeeNumberController =
      TextEditingController();

  // Add a listener for WebSocket messages in initState (moved)
  // final TextEditingController _customerNumberController =
  final TextEditingController _customerNumberController =
      TextEditingController();
  bool _isChequeSelected = false; // tracks if cheque is selected
  double _balanceAmount = 0.0;
  int _cashAmount = 0;
  int _cardAmount = 0;
  int _upiAmount = 0;
  int _chequeAmount = 0;
  double _originalAmount = 0.0;
  double _upiAndCashAmount = 0.0;
  String salesOrderId = '';
  bool _isCompleteButtonEnabled = false; // default enabled

  late salesInvoiceReceiptPrinter receiptPrinter;

  final TextEditingController _customUpiController = TextEditingController();
  final TextEditingController _customCardController = TextEditingController();
  String selectedPaymentMethod = 'Cash';
  final TextEditingController chequeNumberController = TextEditingController();
  final TextEditingController chequeAmountController = TextEditingController();
  final TextEditingController chequeNameController = TextEditingController();
  final TextEditingController chequeBankController = TextEditingController();
  final TextEditingController chequeDateController = TextEditingController();
  OverlayEntry? _overlayEntry;

  final FocusNode _customCashFocusNode = FocusNode();
  final FocusNode _customUpiFocusNode = FocusNode();
  final FocusNode _customCardFocusNode = FocusNode();
  List<double> totalAmount = [0.0];
  // Cheque FocusNodes
  final FocusNode _chequeNumberFocus = FocusNode();
  final FocusNode _chequeAmountFocus = FocusNode();
  final FocusNode _chequeNameFocus = FocusNode();
  final FocusNode _chequeDateFocus = FocusNode();

  // from kot payment variable
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customChargeController = TextEditingController();
  final TextEditingController _customCashController = TextEditingController();

  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();

  bool isSubmitting = false;
  String? _activePaymentMethod; // null means split or no exact match

  // NEW: missing controllers/vars that were used in original code
  final TextEditingController advanceController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final initialAdvanceList = widget.salesOrder.advanceAmount ?? [];

    cashOptions.addAll(
      _generateCashOptions(initialAdvanceList.fold(0.0, (sum, e) => sum + e)),
    );

    totalAmount = List.from(initialAdvanceList);

    double alreadyPaid = initialAdvanceList.fold(0.0, (sum, e) => sum + e);

    _originalAmount = alreadyPaid;
    _upiAndCashAmount = alreadyPaid;
    _balanceAmount = widget.salesOrder.totalAmount - alreadyPaid;
    salesOrderId = widget.salesOrder.saleOrderNo ?? '';

    _employeeNumberController.addListener(_validateForm);
    _customerNumberController.addListener(_validateForm);
    _customAmountController.addListener(_validateForm);

    _cashController.addListener(() {
      _cashAmount = int.tryParse(_cashController.text) ?? 0;
      _validateAmount(_cashController, "Cash");
      _validateForm();
    });

    // 🔹 UPI validation
    _upiController.addListener(() {
      _upiAmount = int.tryParse(_upiController.text) ?? 0;
      _validateAmount(_upiController, "UPI");
      _validateForm();
    });

    // 🔹 Card validation
    _cardController.addListener(() {
      _cardAmount = int.tryParse(_cardController.text) ?? 0;
      _validateAmount(_cardController, "Card");
      _validateForm();
    });

    // 🔹 Cheque validation
    chequeAmountController.addListener(() {
      _chequeAmount = int.tryParse(chequeAmountController.text) ?? 0;
      _validateAmount(chequeAmountController, "Cheque");
      _validateForm();
    });
  }

  void _validateForm() {
    final cash = double.tryParse(_cashController.text) ?? 0;
    final upi = double.tryParse(_upiController.text) ?? 0;
    final card = double.tryParse(_cardController.text) ?? 0;
    final cheque = double.tryParse(chequeAmountController.text) ?? 0;

    // Enable button if any field has a value > 0
    _isCompleteButtonEnabled = (cash + upi + card + cheque) > 0;

    setState(() {});
  }

  void _validateAmount(TextEditingController controller, String method) {
    double entered = double.tryParse(controller.text) ?? 0;

    double alreadyPaid =
        widget.salesOrder.advanceAmount?.fold(0.0, (sum, e) => sum! + e) ?? 0.0;

    double otherPayments = 0.0;

    if (method != "Cash")
      otherPayments += double.tryParse(_cashController.text) ?? 0;
    if (method != "UPI")
      otherPayments += double.tryParse(_upiController.text) ?? 0;
    if (method != "Card")
      otherPayments += double.tryParse(_cardController.text) ?? 0;
    if (method != "Cheque")
      otherPayments += double.tryParse(chequeAmountController.text) ?? 0;

    double remainingBalance =
        widget.salesOrder.totalAmount - alreadyPaid - otherPayments;

    if (entered > remainingBalance) {
      controller.text = remainingBalance.toStringAsFixed(0);
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );

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

    _updateBalance(); // update balance after validation
    _validateForm(); // update button state
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _employeeNumberController.dispose();
    _customerNumberController.dispose();
    _discountController.dispose();
    _customChargeController.dispose();
    _customCashController.dispose();
    _customUpiController.dispose();
    _customCardController.dispose();
    chequeNumberController.dispose();
    chequeAmountController.dispose();
    chequeNameController.dispose();
    chequeBankController.dispose();
    chequeDateController.dispose();
    _customCashFocusNode.dispose();
    _customUpiFocusNode.dispose();
    _customCardFocusNode.dispose();
    _chequeNumberFocus.dispose();
    _chequeAmountFocus.dispose();
    _chequeNameFocus.dispose();
    _chequeDateFocus.dispose();
    _cashController.dispose();
    _upiController.dispose();
    _cardController.dispose();
    advanceController.dispose();

    _overlayEntry?.remove();
    super.dispose();
  }

  String _getSuggestedAmount(String method) {
    final cash = double.tryParse(_cashController.text) ?? 0;
    final upi = double.tryParse(_upiController.text) ?? 0;
    final card = double.tryParse(_cardController.text) ?? 0;

    final alreadyPaid =
        widget.salesOrder.advanceAmount?.fold(0.0, (sum, e) => sum + e) ?? 0.0;

    final remaining =
        widget.salesOrder.totalAmount - alreadyPaid - (cash + upi + card);

    // 🔎 Debug print

    if (method == "Cash" && _cashController.text.isEmpty) {
      return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
    }
    if (method == "UPI" && _upiController.text.isEmpty) {
      return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
    }
    if (method == "Card" && _cardController.text.isEmpty) {
      return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
    }

    return "0";
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
          //  _sendState(type: type, extraData: extraData);
          if (type == 'card_payment_success') {
            stateProvider.updateIsCardPaid(true);
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
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            height: 600,
            width: 285,
            child: Consumer<RazorpayQRProvider>(
              builder: (context, qrProvider, _) {
                if (qrProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (qrProvider.errorMessage != null) {
                  // Send error message to client
                  // _sendState(
                  //   type: 'upi_payment_error',
                  //   extraData: {'message': qrProvider.errorMessage},
                  // );
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        qrProvider.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
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
                  //_sendState(type: 'upi_payment_success');
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/Payment Successful.json',
                        repeat: false,
                        height: 580,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                } else if (qrProvider.qrImageUrl != null) {
                  // _sendState(type: 'show_upi_qr', extraData: {'qrUrl': qrProvider.qrImageUrl, 'amount': amount});
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
                          // _sendState(
                          //   type: 'upi_payment_error',
                          //   extraData: {'message': 'Failed to load QR code'},
                          // );
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.red, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load QR code',
                                style: TextStyle(
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
                                //_sendState(type: 'upi_payment_cancelled');
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
                  // _sendState(
                  //   type: 'upi_payment_error',
                  //   extraData: {'message': 'No QR code generated'},
                  // );
                  return const Center(child: Text('No QR generated'));
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _updateBalance() {
    setState(() {
      final cash = double.tryParse(_cashController.text) ?? 0;
      final upi = double.tryParse(_upiController.text) ?? 0;
      final card = double.tryParse(_cardController.text) ?? 0;
      final cheque = double.tryParse(chequeAmountController.text) ?? 0;

      double alreadyPaid =
          widget.salesOrder.advanceAmount?.fold(0.0, (sum, e) => sum! + e) ??
          0.0;
      double newPayment = cash + upi + card + cheque;
      final remainingBalance = widget.salesOrder.totalAmount - alreadyPaid;

      // 🔴 If total exceeds remaining balance
      if (newPayment > remainingBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Entered amount exceeds remaining balance (₹${remainingBalance.toStringAsFixed(0)})!",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        // 🔹 Clear the last entered field
        if (_cashController.text.isNotEmpty && cash > remainingBalance) {
          _cashController.clear();
        }
        if (_upiController.text.isNotEmpty && upi > remainingBalance) {
          _upiController.clear();
        }
        if (_cardController.text.isNotEmpty && card > remainingBalance) {
          _cardController.clear();
        }
        if (chequeAmountController.text.isNotEmpty &&
            cheque > remainingBalance) {
          chequeAmountController.clear();
        }

        newPayment = 0.0; // reset new payment to prevent negative balance
      }

      _balanceAmount = remainingBalance - newPayment;
      if (_balanceAmount < 0) _balanceAmount = 0;
    });
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

  // 👇 Add this
  bool _showChequeDetails = false;

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
          "Advance Paid: ₹${(widget.salesOrder.advanceAmount?.fold(0.0, (s, e) => s + e) ?? 0.0).toStringAsFixed(0)}",
          style: TextStyle(
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
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(8.0),
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

                    // 🔹 Cash + Card
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentEntry(
                            "Cash",
                            _cashController,
                            _customCashFocusNode,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentEntry(
                            "Card",
                            _cardController,
                            _customCardFocusNode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 🔹 UPI + Cheque
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentEntry(
                            "UPI",
                            _upiController,
                            _customUpiFocusNode,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                          ),
                        ),
                      ],
                    ),

                    if (_showChequeDetails) ...[
                      const SizedBox(height: 8),
                      ChequeDetails(
                        chequeNumberController: chequeNumberController,
                        chequeAmountController: chequeAmountController,
                        chequeNameController: chequeNameController,
                        chequeDateController: chequeDateController,
                        chequeNumberFocus: _chequeNumberFocus,
                        chequeAmountFocus: _chequeAmountFocus,
                        chequeNameFocus: _chequeNameFocus,
                        chequeDateFocus: _chequeDateFocus,
                        onFocusChanged: (index) {},
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 🔹 Bottom Panel: Summary + Keyboard
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                              child: _buildPremiumCardElegant(
                                title: "Total",
                                value:
                                    '₹${widget.salesOrder.totalAmount.toStringAsFixed(0)}',
                                icon: Icons.attach_money,
                                gradientColors: [
                                  Colors.green.shade400,
                                  Colors.green.shade700,
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPremiumCardElegant(
                                title: "Balance",
                                value: '₹${_balanceAmount.toStringAsFixed(0)}',
                                icon: Icons.account_balance_wallet,
                                gradientColors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade700,
                                ],
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _isCompleteButtonEnabled
                                    ? () async {
                                        try {
                                          // 1️⃣ Parse amounts
                                          final cash =
                                              double.tryParse(
                                                _cashController.text,
                                              ) ??
                                              0;
                                          final card =
                                              double.tryParse(
                                                _cardController.text,
                                              ) ??
                                              0;
                                          final upi =
                                              double.tryParse(
                                                _upiController.text,
                                              ) ??
                                              0;
                                          final cheque =
                                              double.tryParse(
                                                chequeAmountController.text,
                                              ) ??
                                              0;

                                          final totalEntered =
                                              cash + card + upi + cheque;

                                          // 2️⃣ Existing paid amount
                                          final alreadyPaid =
                                              widget.salesOrder.advanceAmount
                                                  ?.fold(
                                                    0.0,
                                                    (sum, e) => sum + e,
                                                  ) ??
                                              0;

                                          // 3️⃣ Remaining balance before this transaction
                                          final remainingBalanceBefore =
                                              widget.salesOrder.totalAmount -
                                              alreadyPaid;

                                          // 4️⃣ Validate entered amount
                                          if (totalEntered >
                                              remainingBalanceBefore) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "Entered amount exceeds remaining balance (₹${remainingBalanceBefore.toStringAsFixed(0)})!",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                backgroundColor: Colors.red,
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          // 5️⃣ Build payment types and amounts
                                          List<String> paymentTypes = [];
                                          List<double> modeAmounts = [];

                                          if (cash > 0) {
                                            paymentTypes.add("Cash");
                                            modeAmounts.add(cash);
                                          }
                                          if (card > 0) {
                                            paymentTypes.add("Card");
                                            modeAmounts.add(card);
                                          }
                                          if (upi > 0) {
                                            paymentTypes.add("UPI");
                                            modeAmounts.add(upi);
                                          }
                                          if (cheque > 0) {
                                            paymentTypes.add("Cheque");
                                            modeAmounts.add(cheque);
                                          }

                                          // 6️⃣ Merge with existing values
                                          List<double> existingAdvanceAmount =
                                              widget.salesOrder.advanceAmount ??
                                              [];
                                          List<List<String>>
                                          existingPaymentType =
                                              widget
                                                  .salesOrder
                                                  .advancePaymentType ??
                                              [];
                                          List<List<double>>
                                          existingModeWiseAmount =
                                              widget
                                                  .salesOrder
                                                  .modeWiseAmount ??
                                              [];
                                          List<String> existingDateTime =
                                              widget
                                                  .salesOrder
                                                  .advanceDateTime ??
                                              [];

                                          // ✅ Add new entry
                                          existingAdvanceAmount = [
                                            ...existingAdvanceAmount,
                                            totalEntered,
                                          ];
                                          existingPaymentType = [
                                            ...existingPaymentType,
                                            paymentTypes,
                                          ];
                                          existingModeWiseAmount = [
                                            ...existingModeWiseAmount,
                                            modeAmounts,
                                          ];
                                          existingDateTime = [
                                            ...existingDateTime,
                                            DateTime.now().toIso8601String(),
                                          ];

                                          // 7️⃣ Recalculate updated remaining balance
                                          final updatedAlreadyPaid =
                                              alreadyPaid + totalEntered;
                                          final updatedRemainingBalance =
                                              widget.salesOrder.totalAmount -
                                              updatedAlreadyPaid;

                                          // 8️⃣ Build API payload
                                          Map<String, dynamic> requestBody = {
                                            "advanceAmount":
                                                existingAdvanceAmount,
                                            "advanceDateTime": existingDateTime,
                                            "advancePaymentType":
                                                existingPaymentType,
                                            "modeWiseAmount":
                                                existingModeWiseAmount,
                                            "balanceAmount":
                                                updatedRemainingBalance,
                                          };

                                          Map<String, dynamic> patchPayload = {
                                            "data": requestBody,
                                            "saleOrderNo":
                                                widget.salesOrder.saleOrderNo,
                                            "type": "patchSaleOrder",
                                            "editAbout": "Add Advance",
                                            "sync": "No",
                                            "edit": "No",
                                          };

                                          // 9️⃣ Send via WebSocket
                                          await sendataToServer(patchPayload);

                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Advance payment updated successfully!',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        } catch (e, stack) {}
                                      }
                                    : null,
                                child: const Text(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentEntry(
    String method,
    TextEditingController controller,
    FocusNode focus,
  ) {
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            offset: const Offset(3, 3), // Shadow position for 3D effect
            blurRadius: 6,
          ),
          const BoxShadow(
            color: Colors.white, // Light reflection
            offset: Offset(-2, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Method Name
          Expanded(
            flex: 1,
            child: Text(
              method,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          // Suggested amount button
          GestureDetector(
            onTap: () {
              String suggested = _getSuggestedAmount(method);
              controller.text = suggested;
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
          ),

          const SizedBox(width: 10),

          // Amount Input (Custom Keyboard Only)
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              focusNode: focus,
              readOnly: true, // Prevent system keyboard
              showCursor: true, // Show blinking cursor
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
              onChanged: (value) {
                _updateBalance();
              },
            ),
          ),

          // UPI/Card Payment Icon
          if (method == 'UPI' || method == 'Card')
            Consumer<RazorpayQRProvider>(
              builder: (context, qrProvider, _) {
                return IconButton(
                  icon: Icon(
                    method == 'UPI' ? Icons.qr_code : Icons.credit_card,
                    color: method == 'UPI' ? Colors.black : Colors.blue,
                    size: 24,
                  ),
                  onPressed:
                      isPaymentEnabled &&
                          !(method == 'UPI'
                              ? stateProvider.isUpiPaid
                              : qrProvider.isCardPaid)
                      ? () {
                          final amountStr = controller.text;
                          if (amountStr.isNotEmpty) {
                            final amount = double.tryParse(amountStr);
                            if (amount != null && amount > 0) {
                              if (method == 'UPI') {
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
    );
  }

  Widget _buildPremiumCardElegant({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
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
}

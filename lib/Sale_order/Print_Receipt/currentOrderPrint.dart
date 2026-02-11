import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Provider/connectivity_internet.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Global/globals_data.dart' as globalsData;
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Sale_order/Widgets/advance_amount_payment_keybaord.dart';
import 'package:yen_pos/Sale_order/Widgets/cheque_details.dart';
import 'package:yen_pos/Sale_order/Widgets/customAll_keyboard.dart';
import 'package:yen_pos/Sale_order/Widgets/top_message.dart';
import 'package:yen_pos/Server_Client/handlers/invoice_handler.dart';
import 'package:yen_pos/Server_Client/handlers/saleorder_handlemessage.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/invoiceNumberGenerator.dart';

import '../../../Global/salesorder_websocket_service.dart';

class OrderManagementPayandPrint extends StatefulWidget {
  final double totalAmount;
  final String holdBillId;
  final String orderId;
  final String employee;
  final int discount;
  final String customerNumber;
  final SalesOrderDisplay salesOrder;

  const OrderManagementPayandPrint({
    super.key,
    required this.totalAmount,
    required this.holdBillId,
    required this.orderId,
    required this.employee,
    required this.discount,
    required this.customerNumber,
    required this.salesOrder,
  });

  @override
  State<OrderManagementPayandPrint> createState() =>
      _OrderManagementPayandPrintState();
}

class _OrderManagementPayandPrintState
    extends State<OrderManagementPayandPrint> {
  final List<String> cashOptions = [];
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _employeeNumberController =
      TextEditingController();

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
  bool _isInitialSend = true;
  Map<String, dynamic> _lastSentData = {};
  bool _isPrintButtonEnabled = true;
  late salesInvoiceReceiptPrinter receiptPrinter;
  bool _isCompleteButtonEnabled = false; // default enabled
  final TextEditingController _customUpiController = TextEditingController();
  final TextEditingController _customCardController = TextEditingController();

  final TextEditingController chequeNumberController = TextEditingController();
  final TextEditingController chequeAmountController = TextEditingController();
  final TextEditingController chequeNameController = TextEditingController();
  final TextEditingController chequeBankController = TextEditingController();
  final TextEditingController chequeDateController = TextEditingController();
  OverlayEntry? _overlayEntry;

  late final List<TextEditingController> controllers;
  final FocusNode _customCashFocusNode = FocusNode();
  final FocusNode _customUpiFocusNode = FocusNode();
  final FocusNode _customCardFocusNode = FocusNode();

  // Cheque FocusNodes
  final FocusNode _chequeNumberFocus = FocusNode();
  final FocusNode _chequeAmountFocus = FocusNode();
  final FocusNode _chequeNameFocus = FocusNode();
  final FocusNode _chequeDateFocus = FocusNode();
  //from kot payment variable

  final TextEditingController _customChargeController = TextEditingController();
  final TextEditingController _customCashController = TextEditingController();

  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();

  bool isSubmitting = false;
  String? _activePaymentMethod; // null means split or no exact match
  @override
  void initState() {
    super.initState();
    cashOptions.addAll(_generateCashOptions(widget.totalAmount));

    _originalAmount = widget.totalAmount;
    _upiAndCashAmount = widget.totalAmount;
    _balanceAmount = widget.totalAmount;
    salesOrderId = widget.orderId;

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

  @override
  void dispose() {
    _customAmountController.dispose();
    _employeeNumberController.dispose();
    _customerNumberController.dispose();

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
    _overlayEntry?.remove();
    super.dispose();
  }

  String _getSuggestedAmount(String method) {
    final cash = double.tryParse(_cashController.text) ?? 0;
    final upi = double.tryParse(_upiController.text) ?? 0;
    final card = double.tryParse(_cardController.text) ?? 0;
    final remaining = widget.totalAmount - (cash + upi + card);

    // Suggest remaining amount only if field is empty
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

  void _validateForm() {
    final cash = double.tryParse(_cashController.text) ?? 0;
    final upi = double.tryParse(_upiController.text) ?? 0;
    final card = double.tryParse(_cardController.text) ?? 0;
    final cheque = double.tryParse(chequeAmountController.text) ?? 0;

    final totalEntered = cash + upi + card + cheque;
    final totalAmount = widget.totalAmount;

    setState(() {
      // ✅ Enable Pay button only when entered amount == total
      _isCompleteButtonEnabled = (totalEntered == totalAmount);
    });
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

      TopMessage.show(
        context,
        message:
            "Entered $method amount exceeds remaining balance. Max allowed: ₹${remainingBalance.toStringAsFixed(0)}",
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }

    _updateBalance(); // update balance after validation
    _validateForm(); // update button state
  }

  void _updateBalance() {
    setState(() {
      final cash = double.tryParse(_cashController.text) ?? 0;
      final upi = double.tryParse(_upiController.text) ?? 0;
      final card = double.tryParse(_cardController.text) ?? 0;
      final cheque = double.tryParse(chequeAmountController.text) ?? 0;

      final totalEntered = cash + upi + card + cheque;
      _balanceAmount = widget.totalAmount - totalEntered;

      // Detect single active method
      if (cash == widget.totalAmount && upi == 0 && card == 0 && cheque == 0) {
        _activePaymentMethod = "Cash";
      } else if (upi == widget.totalAmount &&
          cash == 0 &&
          card == 0 &&
          cheque == 0) {
        _activePaymentMethod = "UPI";
      } else if (card == widget.totalAmount &&
          cash == 0 &&
          upi == 0 &&
          cheque == 0) {
        _activePaymentMethod = "Card";
      } else if (cheque == widget.totalAmount &&
          cash == 0 &&
          upi == 0 &&
          card == 0) {
        _activePaymentMethod = "Cheque";
      } else {
        _activePaymentMethod = null;
      }

      // ✅ Validation rule:
      // Only enable Pay button if totalEntered == totalAmount (no less or more)
      // Disable if totalEntered < totalAmount OR > totalAmount
      _isPrintButtonEnabled = (totalEntered == widget.totalAmount);
      if (totalEntered > widget.totalAmount) {
        TopMessage.show(
          context,
          message:
              "Entered amount ₹${totalEntered.toStringAsFixed(0)} exceeds total ₹${widget.totalAmount.toStringAsFixed(0)}",
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    });
    _validateForm();
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
    } catch (e) {}
  }

  double getTotalWithAdjustments() {
    double totalCharges =
        (double.tryParse(_customChargeController.text) ?? 0.0);
    return (widget.totalAmount) + totalCharges;
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

    bool isUpiPaid = method == 'Upi' && stateProvider.isUpiPaid;
    bool isCardPaid = method == 'Card' && stateProvider.isCardPaid;
    bool shouldDisable = isUpiPaid || isCardPaid;
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
            flex: 2,
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
                    method == 'Upi' ? Icons.qr_code : Icons.credit_card,
                    color: shouldDisable ? Colors.grey : Colors.blue,
                  ),
                  onPressed: isPaymentEnabled && !shouldDisable
                      ? () {
                          final val = controller.text;
                          final amt = double.tryParse(val);
                          if (val.isNotEmpty && amt != null && amt > 0) {
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

                                      _sendState(type: 'upi_payment_success');
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
                );
              },
            ),
        ],
      ),
    );
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
    double padding = MediaQuery.of(context).size.width * 0.04;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        elevation: 3,
        centerTitle: true,
        title: const Text(
          "Invoice",
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
            // 🔹 Scrollable Payment Section
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 🔹 Payment Section Title
                    const Text(
                      "Select Payment Method",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

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
                    const SizedBox(height: 12),

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
                                  // Clear other payment fields when cheque is selected
                                  _cashController.clear();
                                  _upiController.clear();
                                  _cardController.clear();
                                  _updateBalance();
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Cheque",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
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

                    // 🔹 Cheque Details Expand
                    if (_showChequeDetails) ...[
                      const SizedBox(height: 16),
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
                        // 🔹 Total & Balance Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildPremiumCardElegant(
                                title: "Total",
                                value:
                                    '₹${widget.totalAmount.toStringAsFixed(0)}',
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
                                      ? Colors.blue.shade700
                                      : Colors.grey,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _isCompleteButtonEnabled
                                    ? () async {
                                        setState(() => isSubmitting = true);
                                        try {
                                          markOrderAsCompleted(salesOrderId);
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Payment failed: $e',
                                              ),
                                            ),
                                          );
                                        } finally {
                                          setState(() => isSubmitting = false);
                                        }
                                      }
                                    : null,
                                child: Text(
                                  "Pay",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _isCompleteButtonEnabled
                                        ? Colors.white
                                        : Colors.black,
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

  void markOrderAsCompleted(String salesOrderId) async {
    final connectivityProvider = Provider.of<ConnectivityProvider>(
      context,
      listen: false,
    );
    final invoiceDate = DateTime.now().toIso8601String();
    final invoiceTime = DateTime.now().toIso8601String();

    final so = widget.salesOrder;

    // 🧮 Calculate total advance
    final totalAdvanceAmount =
        so.advanceAmount?.fold<double>(0.0, (sum, value) => sum + value) ?? 0.0;

    try {
      Map<String, dynamic> requestBody = {
        "salesOrderId": so.salesOrderId,
        "status": "Sales Completed",
        "invoiceDate": invoiceDate,
        "invoiceTime": invoiceTime,
      };
      final patchData = {
        "data": requestBody,
        "saleOrderNo": so.saleOrderNo,
        "type": "patchInvoiceSaleOrder",
        "sync": "No",
        "edit": "No",
      };

      if (connectivityProvider.isConnected) {
        await sendataToServer(patchData);
      } else {
        await handleInvoicePatchSaleOrder(patchData);
      }

      // ===================================================================================== //
      // 🧮 CALCULATIONS
      // ===================================================================================== //
      final Set<String> _loggedInvoices = {};
      double totalItemTotal = 0.0;
      double totalNet = 0.0;
      double totalCross = 0.0;
      double totalDiscountAmount = 0.0;

      List<double> sellingPrices = [];
      List<double> sellingAmounts = [];
      List<double> gstRates = [];
      List<double> gstValues = [];

      double discountPerc = so.discount.toDouble();

      double customCharge = _customChargeController.text.isNotEmpty
          ? double.tryParse(_customChargeController.text) ?? 0.0
          : 0.0;

      for (int i = 0; i < so.itemName.length; i++) {
        final itemName = so.itemName[i];
        final qty = (so.qty.length > i && so.qty[i] != null) ? so.qty[i] : 0;
        final price = (so.price.length > i && so.price[i] != null)
            ? so.price[i].toDouble()
            : 0.0;
        final tax = (so.tax.length > i && so.tax[i] != null)
            ? so.tax[i].toDouble()
            : 0.0;
        final amount = (so.amount.length > i && so.amount[i] != null)
            ? so.amount[i].toDouble()
            : 0.0;

        // Apply Discount
        final discountedPrice = price * (1 - discountPerc / 100);
        final subtotal = discountedPrice * qty;
        final taxAmount = subtotal * (tax / 100);
        final totalWithTax = subtotal + taxAmount;
        final itemDiscountAmt = amount * (discountPerc / 100);
        final discountedGross = amount - itemDiscountAmt;

        // Net exclusive & GST
        final taxRate = tax / 100.0;
        final netExclusive = tax > 0
            ? discountedGross / (1 + taxRate)
            : discountedGross;
        final gstAmount = discountedGross - netExclusive;

        // Round GST values
        final gstRateRounded = double.parse(tax.toStringAsFixed(1));
        final gstAmountRounded = double.parse(gstAmount.toStringAsFixed(2));

        // Update totals
        totalDiscountAmount += itemDiscountAmt;
        totalItemTotal += discountedGross;
        totalNet += netExclusive;

        // Store rounded GST info
        gstRates.add(gstRateRounded);
        gstValues.add(gstAmountRounded);

        sellingPrices.add(discountedPrice);
        sellingAmounts.add(discountedGross);
      }

      var invoiceNumberGenerator = InvoiceNumberGenerator.instance;
      String newInvoiceNumber = await invoiceNumberGenerator
          .generateInvoiceNumber();

      final employeeFull = so.employeeName; // "2548 - Paramasivan P"

      // Split by ' - '
      final employeeParts = employeeFull.split(' - ');

      // Extract ID and Name safely
      final employeeId = employeeParts.isNotEmpty
          ? employeeParts[0].trim()
          : '';
      final employeeName = employeeParts.length > 1
          ? employeeParts[1].trim()
          : '';

      // Convert the customerNumber string to int safely
      int customerPhoneNumber = int.tryParse(so.customerNumber) ?? 0;
      // ===================================================================================== //
      // 📦 BUILD FULL INVOICE BODY
      // ===================================================================================== //
      Map<String, dynamic> fullInvoiceBody = {
        "itemName": so.itemName,
        "varianceName": so.varianceName,
        "varianceitemCode": so.itemCode,
        "sellingPrice": sellingPrices,
        "sellingAmount": sellingAmounts,
        "price": so.price,
        "weight": so.weight,
        "qty": so.qty,
        "amount": so.amount,
        "tax": so.tax,
        "uom": so.uom,
        "totalAmount": totalItemTotal,
        "advanceAmount": totalAdvanceAmount,
        "advanceDate": invoiceDate,
        "status": "        ",
        "salesType": "Sales Order",
        "netAmount": totalNet.toStringAsFixed(2),
        "grossAmount": totalCross.toStringAsFixed(2),
        "customerPhoneNumber": customerPhoneNumber,
        "salesPersonName": employeeName,
        "salesPersonId": employeeId,
        "locationId": globals.locationId,
        "branchName": globals.branchName,
        "aliasName": globals.aliasname,
        "cash": _cashAmount,
        "card": _cardAmount,
        "upi": _upiAmount,
        "invoiceNo": newInvoiceNumber,
        "invoiceDateTime": DateTime.now().toIso8601String(),
        "shiftId": globalsData.shiftId.value.toString(),
        "totalCustomCharge": so.totalCustomCharge,
        "discountAmount": (totalNet * (discountPerc / 100)).toStringAsFixed(2),
        "discountPercentage": discountPerc,
        "salesOrderId": so.salesOrderId,
        "advanceDateTime": so.advanceDateTime,
        "gst": gstRates,
        "gstValue": gstValues,
        "saleOrderNo": so.saleOrderNo,
      };

      final invoiceJson = jsonEncode({
        "salesOrderId": fullInvoiceBody,
        "type": "posInvoice",
        "sync": "No",
        "edit": "No",
      });

      if (connectivityProvider.isConnected) {
        await sendataToServer(jsonDecode(invoiceJson));
      } else {
        await handleInvoice(jsonDecode(invoiceJson), clients);
      }

      // ===================================================================================== //
      // 📦 SAVE TO HIVE
      // ===================================================================================== //

      // DateTime billDate = DateTime.now();
      // String formattedDate = DateFormat('dd-MM-yyyy').format(billDate);
      // String uniqueIdentifier = '$formattedDate';

      // var box = await Hive.openBox('invoices');
      // if (!_loggedInvoices.contains(uniqueIdentifier)) {
      //   _loggedInvoices.add(uniqueIdentifier);
      //   developer.log('Invoice Data:', name: 'InvoiceLog');
      //   developer.log(fullInvoiceBody.toString(), name: 'InvoiceLog');
      // }

      // bool exists = box.values.any(
      //   (invoice) =>
      //       invoice is Map<String, dynamic> && invoice[' '] == uniqueIdentifier,
      // );

      // if (!exists) {
      //   await box.add(fullInvoiceBody);

      //   int i = 0;
      //   for (var invoice in box.values) {
      //     i++;
      //   }
      // } else {}
    } catch (e, stack) {}

    Navigator.pop(context);
  }
}

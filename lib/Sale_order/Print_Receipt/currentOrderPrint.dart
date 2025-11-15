import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Global/globals_data.dart' as globalsData;
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yenpos/Sale_order/Widgets/advance_amount_payment_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/cheque_details.dart';
import 'package:yenpos/Sale_order/Widgets/customAll_keyboard.dart';
import 'package:yenpos/Sale_order/Widgets/top_message.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';

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

  bool _isPrintButtonEnabled = true;
  late salesInvoiceReceiptPrinter receiptPrinter;
  bool _isCompleteButtonEnabled = false; // default enabled
  final TextEditingController _customUpiController = TextEditingController();
  final TextEditingController _customCardController = TextEditingController();
  String selectedPaymentMethod = 'Cash';
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
    final invoiceDate = DateTime.now().toIso8601String();
    final invoiceTime = DateTime.now().toIso8601String();

    final so = widget.salesOrder;

    // 🧮 Calculate total advance
    final totalAdvanceAmount =
        so.advanceAmount?.fold<double>(0.0, (sum, value) => sum + value) ?? 0.0;

    print(
      "🟢 [markOrderAsCompleted] STARTED for Sales Order ID: $salesOrderId",
    );
    print("🟢 Invoice Date: $invoiceDate, Invoice Time: $invoiceTime");
    print("🟢 Total Advance Amount: $totalAdvanceAmount");

    try {
      // 🔹 Patch order status
      final patchBody = {
        "salesOrderId": so.salesOrderId,
        "status": "Sales Completed",
        "invoiceDate": invoiceDate,
        "invoiceTime": invoiceTime,
      };

      await sendataToServer({
        "data": patchBody,
        "saleOrderNo": so.saleOrderNo,
        "type": "patchSaleOrder",
        "sync": "No",
        "edit": "No",
      });

      print("✅ Patch request sent successfully for $salesOrderId");

      // 🧮 Initialize totals
      double totalItemTotal = 0.0; // total after discount + tax
      double totalNet = 0.0; // total before tax
      double totalCross = 0.0; // gross total (if any extra charges)
      List<double> sellingPrices = [];
      List<double> sellingAmounts = [];
      List<String> gstRates = [];
      List<String> gstValues = [];
      double discount_perc = so.discount.toDouble();
      double customCharge = _customChargeController.text.isNotEmpty
          ? double.tryParse(_customChargeController.text) ?? 0.0
          : 0.0;
      double totalDiscountAmount = 0.0;

      for (int i = 0; i < so.itemName.length; i++) {
        final itemQty = (so.qty.length > i ? so.qty[i] : 0);
        final itemPrice = (so.price.length > i ? so.price[i].toDouble() : 0.0);
        final itemTax = (so.tax.length > i ? so.tax[i].toDouble() : 0.0);
        final itemAmount = (so.amount.length > i
            ? so.amount[i].toDouble()
            : 0.0);

        final discountedPrice = itemPrice * (1 - discount_perc / 100);
        final subtotal = discountedPrice * itemQty;
        final taxAmount = subtotal * (itemTax / 100);
        final totalWithTax = subtotal + taxAmount;

        double itemDiscountAmt = itemAmount * (discount_perc / 100);
        double discountedGross = itemAmount - itemDiscountAmt;

        double taxRate = itemTax / 100.0;
        double netExclusive = itemTax > 0
            ? discountedGross / (1 + taxRate)
            : discountedGross;
        double gstAmount = discountedGross - netExclusive;

        totalDiscountAmount += itemDiscountAmt;
        totalItemTotal += discountedGross;
        totalNet += netExclusive;

        gstRates.add(itemTax.toStringAsFixed(1));
        gstValues.add(gstAmount.toStringAsFixed(2));

        sellingPrices.add(discountedPrice);
        sellingAmounts.add(discountedGross);
      }

      // 🔹 Build invoice body
      final fullInvoiceBody = {
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
        "advanceTime": invoiceTime,
        "status": "Sales Completed",
        "salesType": "Sales Order",
        "netAmount": totalNet.toStringAsFixed(2),
        "crossAmount": totalCross.toStringAsFixed(2),
        "customerPhoneNumber": so.customerNumber,
        "salesPersonName": so.employeeName,
        "branchId": globals.branchId,
        "branchName": globals.branchName,
        "aliasName": globals.aliasname,
        "cash": _cashAmount,
        "card": _cardAmount,
        "upi": _upiAmount,
        "invoiceNo": so.orderInvoiceNo,
        "invoiceDateTime": DateTime.now().toIso8601String(),
        "shiftId": globalsData.shiftId.value,
        "customCharge": so.customCharge,
        "discountAmount": (totalNet * (discount_perc / 100)).toStringAsFixed(
          2,
        ), // total discount value
        "discountPercentage": discount_perc,
        "salesOrderId": so.salesOrderId,
        "advanceDateTime": so.advanceDateTime,
        'gst': gstRates,
        'gstValue': gstValues,
      };

      print("🟢 Full Invoice Body: $fullInvoiceBody");
      final invoiceJson = jsonEncode({
        "salesOrderId": fullInvoiceBody,
        "type": "posInvoice",
        "sync": "No",
        "edit": "No",
      });

      await sendataToServer(jsonDecode(invoiceJson));
      // 🔹 Send invoice
      DateTime billDate = DateTime.now();
      String formattedDate = DateFormat('dd-MM-yyyy').format(billDate);
      String formattedTime = DateFormat('hh:mm a').format(billDate);
      String uniqueIdentifier = '$formattedDate';

      var box = await Hive.openBox('invoices');
      bool exists = box.values.any(
        (invoice) =>
            invoice is Map<String, dynamic> && invoice[' '] == uniqueIdentifier,
      );
      if (!exists) {
        await box.add(fullInvoiceBody);
        developer.log('Invoice saved to Hive:', error: fullInvoiceBody);
      }

      print("✅ Invoice request sent successfully for $salesOrderId");
    } catch (e, stack) {
      print("❌ Error in markOrderAsCompleted: $e");
      print("❌ StackTrace: $stack");
    }

    print(
      "🟢 [markOrderAsCompleted] FINISHED for Sales Order ID: $salesOrderId",
    );
    Navigator.pop(context);
  }
}

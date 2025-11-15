import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Widgets/advance_amount_payment_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/bank_search_dropdown.dart';
import 'package:yenpos/Sale_order/Widgets/cheque_details.dart';
import 'package:yenpos/Sale_order/Widgets/customAll_keyboard.dart';
import 'package:yenpos/Sale_order/Widgets/employee_selection.dart';
import 'package:lottie/lottie.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart'; // For Lottie animation

class AdvanceAmountDialog extends StatefulWidget {
  final double advanceAmount;
  final String salesOrderId;
  final String saleOrderNo;

  const AdvanceAmountDialog({
    Key? key,
    required this.advanceAmount,
    required this.salesOrderId,
    required this.saleOrderNo,
  }) : super(key: key);
  @override
  State<AdvanceAmountDialog> createState() => _AdvanceAmountDialogState();
}

class _AdvanceAmountDialogState extends State<AdvanceAmountDialog> {
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _salesPersonController = TextEditingController();
  final TextEditingController _returnAmountController = TextEditingController();
  late final TextEditingController _amountController;
  final List<String> cashOptions = [];
  // Payment method controllers
  final TextEditingController chequeNumberController = TextEditingController();
  final TextEditingController chequeAmountController = TextEditingController();
  final TextEditingController chequeNameController = TextEditingController();
  final TextEditingController chequeBankController = TextEditingController();
  final TextEditingController chequeDateController = TextEditingController();

  String selectedPaymentMethod = 'Cash'; // Default payment method
  bool _isCompleteButtonEnabled = false; // default enabled
  // 👇 Add this
  bool _showChequeDetails = false;
  final FocusNode _customCashFocusNode = FocusNode();
  final FocusNode _customUpiFocusNode = FocusNode();
  final FocusNode _customCardFocusNode = FocusNode();

  // Cheque FocusNodes
  final FocusNode _chequeNumberFocus = FocusNode();
  final FocusNode _chequeAmountFocus = FocusNode();
  final FocusNode _chequeNameFocus = FocusNode();
  final FocusNode _chequeDateFocus = FocusNode();
  int _cashAmount = 0;
  int _cardAmount = 0;
  int _upiAmount = 0;
  int _chequeAmount = 0;
  double _originalAmount = 0.0;
  double _upiAndCashAmount = 0.0;
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();

  // Focus nodes
  FocusNode chequeNumberFocus = FocusNode();
  FocusNode chequeAmountFocus = FocusNode();
  FocusNode chequeNameFocus = FocusNode();
  FocusNode remarkFocus = FocusNode();
  FocusNode returnAmountFocus = FocusNode();
  FocusNode salespersonFocus = FocusNode();
  bool _isChequeSelected = false; // tracks if cheque is selected
  @override
  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(
      text: widget.advanceAmount.toString(),
    );
    _returnAmountController.text = widget.advanceAmount.toString();
    chequeAmountController.text = widget.advanceAmount.toString();

    double alreadyPaid = widget.advanceAmount;
    _originalAmount = alreadyPaid;
    _upiAndCashAmount = alreadyPaid;

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

    double alreadyPaid = widget.advanceAmount;

    double remainingBalance = alreadyPaid - entered;

    if (entered > alreadyPaid) {
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

    _updateBalance(); 
    _validateForm(); 
  }

  String _getSuggestedAmount(String method) {
    final cash = double.tryParse(_cashController.text) ?? 0;
    final upi = double.tryParse(_upiController.text) ?? 0;
    final card = double.tryParse(_cardController.text) ?? 0;

    final alreadyPaid = widget.advanceAmount;

    final remaining = alreadyPaid - (cash + upi + card);

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

  void _updateBalance() {
    setState(() {
      final cash = double.tryParse(_cashController.text) ?? 0;
      final upi = double.tryParse(_upiController.text) ?? 0;
      final card = double.tryParse(_cardController.text) ?? 0;
      final cheque = double.tryParse(chequeAmountController.text) ?? 0;

      double alreadyPaid = widget.advanceAmount;
      double newPayment = cash + upi + card + cheque;
      final remainingBalance = alreadyPaid - newPayment;

      // 🔴 If total exceeds remaining balance
      if (newPayment > alreadyPaid) {
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
    });
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
              setState(() {}); // 👈 trigger rebuild
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

  Future<bool> _handleCardPayment() async {
    final qrProvider = Provider.of<RazorpayQRProvider>(context, listen: false);
    final stateProvider = Provider.of<SalesInvoiceState>(
      context,
      listen: false,
    );
    final cardAmountStr = _returnAmountController.text;

    if (cardAmountStr.isNotEmpty) {
      final cardAmount = double.tryParse(cardAmountStr);
      if (cardAmount != null && cardAmount > 0) {
        try {
          await qrProvider.createOrderAndPay(cardAmount, (
            String type,
            Map<String, dynamic>? extraData,
          ) {
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
          return stateProvider.isCardPaid;
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Card payment error: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid card amount greater than 0.'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a card amount first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }
  }

  // UPI QR dialog
  Future<bool> _showUpiQrDialog(double amount) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RazorpayQRProvider>(context, listen: false).createQR(amount);
    });
    final result = await showDialog<bool>(
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
                          Navigator.pop(context, false);
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
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/Payment Successful.json',
                        repeat: false,
                        height: 580,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        onLoaded: (composition) {
                          Future.delayed(
                            composition.duration + const Duration(seconds: 2),
                            () {
                              if (mounted) {
                                Navigator.pop(context, true);
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
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(
                        qrProvider.qrImageUrl!,
                        height: 535,
                        width: double.infinity,
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) {
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
                                Navigator.pop(context, false);
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
                  return const Center(child: Text('No QR generated'));
                }
              },
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        elevation: 3,
        centerTitle: true,
        title: const Text(
          "Cancel Order",
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
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormField(
                            controller: _remarksController,
                            labelText: 'Remarks',
                            icon: Icons.comment,
                            hintText: 'Enter remarks or comments',
                            keyboardType: TextInputType.multiline,
                            focusNode: remarkFocus,
                            onTap: () {
                              ActiveField.activate(
                                context: context,
                                ctrl: _remarksController,
                                node: remarkFocus,
                                numeric: false,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Expanded(child: EmployeeSearchDropdown()),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                                onPressed: () async {
                                  // Step 1: Validate remarks
                                  if (_remarksController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please fill the Remarks',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  // Step 2: Handle UPI/Card payments
                                  bool paymentSuccess = true;
                                  if (selectedPaymentMethod == 'UPI' ||
                                      selectedPaymentMethod == 'Card') {
                                    final amountStr =
                                        _returnAmountController.text;

                                    if (amountStr.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Please enter a $selectedPaymentMethod amount',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    final amount = double.tryParse(amountStr);
                                    if (amount == null || amount <= 0) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Please enter a valid $selectedPaymentMethod amount greater than 0',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    // Process UPI or Card payment
                                    if (selectedPaymentMethod == 'UPI') {
                                      paymentSuccess = await _showUpiQrDialog(
                                        amount,
                                      );
                                    } else if (selectedPaymentMethod ==
                                        'Card') {
                                      paymentSuccess =
                                          await _handleCardPayment();
                                    }

                                    if (!paymentSuccess) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '$selectedPaymentMethod payment failed. Order cancellation aborted.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                  }

                                  // Step 3: Build approval details
                                  final approvalDetails = {
                                    "approvalType": "Cancel Order",
                                    "summary": "no",
                                  };

                                  final payload = {
                                    "status": "Waiting for approval",
                                    "cancelOrderRemark":
                                        _remarksController.text,
                                    "canceledPersonName":
                                        customerScreenProvider
                                            .searchController
                                            .text ??
                                        "",
                                    "saleOrderNo": widget.saleOrderNo,
                                    "returnAmount":
                                        _returnAmountController.text.isEmpty
                                        ? "0"
                                        : _returnAmountController.text,
                                    "canceledPaymentType":
                                        selectedPaymentMethod,
                                    "cancelOrderDate": DateTime.now()
                                        .toIso8601String(),
                                    "approvalDetails": [approvalDetails],
                                  };

                                  // Step 4: Call Provider method
                                  customerScreenProvider.cancelOrder(
                                    widget.saleOrderNo,
                                    payload,
                                  );

                                  Navigator.of(context).pop();

                                  // Step 5: Show success message and navigate back
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Cancel order submitted successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );

                                  Navigator.of(context).pop(payload);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  shadowColor: Colors.blue.shade300,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Submit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
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

  @override
  void dispose() {
    _remarksController.dispose();
    _amountController.dispose();
    _salesPersonController.dispose();
    _returnAmountController.dispose();
    chequeNumberController.dispose();
    chequeAmountController.dispose();
    chequeNameController.dispose();
    chequeBankController.dispose();
    chequeDateController.dispose();
    chequeNumberFocus.dispose();
    chequeAmountFocus.dispose();
    chequeNameFocus.dispose();
    remarkFocus.dispose();
    returnAmountFocus.dispose();
    salespersonFocus.dispose();
    super.dispose();
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = true,
    String? prefixText,
    VoidCallback? onTap,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      showCursor: true,
      keyboardType: keyboardType,
      onTap: onTap,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black87, fontSize: 14),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixText: prefixText,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

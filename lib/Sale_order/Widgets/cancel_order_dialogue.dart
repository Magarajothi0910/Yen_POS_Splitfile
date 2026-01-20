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
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yenpos/Sale_order/Widgets/advance_amount_payment_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/cheque_details.dart';
import 'package:yenpos/Sale_order/Widgets/employee_selection.dart';
import 'package:yenpos/Sale_order/Widgets/top_message.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';

class CancelOrderPayment extends StatefulWidget {
  const CancelOrderPayment({super.key, required this.salesOrder});

  final SalesOrderDisplay salesOrder;

  @override
  State<CancelOrderPayment> createState() => _CancelOrderPaymentState();
}

class _CancelOrderPaymentState extends State<CancelOrderPayment> {
  final List<String> cashOptions = [];
  final TextEditingController chequeAmountController = TextEditingController();
  FocusNode chequeAmountFocus = FocusNode();
  final TextEditingController chequeBankController = TextEditingController();
  final TextEditingController chequeDateController = TextEditingController();
  final TextEditingController chequeNameController = TextEditingController();
  FocusNode chequeNameFocus = FocusNode();
  final TextEditingController chequeNumberController = TextEditingController();
  FocusNode chequeNumberFocus = FocusNode();
  bool isSubmitting = false;
  late salesInvoiceReceiptPrinter receiptPrinter;
  FocusNode remarkFocus = FocusNode();
  FocusNode returnAmountFocus = FocusNode();
  String salesOrderId = '';
  FocusNode salespersonFocus = FocusNode();
  String selectedPaymentMethod = 'Cash';

  final TextEditingController _accountNoController = TextEditingController();
  final FocusNode _accountNoFocus = FocusNode();
  // Track active controller for keyboard
  TextEditingController _activeKeyboardController = TextEditingController();

  String? _activePaymentMethod;
  late final TextEditingController _amountController;
  double _balanceAmount = 0.0;
  final TextEditingController _bankNameController = TextEditingController();
  final FocusNode _bankNameFocus = FocusNode();
  final TextEditingController _branchController = TextEditingController();
  final FocusNode _branchFocus = FocusNode();
  int _cardAmount = 0;
  final TextEditingController _cardController = TextEditingController();
  int _cashAmount = 0;
  final TextEditingController _cashController = TextEditingController();
  int _chequeAmount = 0;
  final FocusNode _chequeAmountFocus = FocusNode();
  final FocusNode _chequeDateFocus = FocusNode();
  final FocusNode _chequeNameFocus = FocusNode();
  // Cheque FocusNodes
  final FocusNode _chequeNumberFocus = FocusNode();

  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _customCardController = TextEditingController();
  final FocusNode _customCardFocusNode = FocusNode();
  final TextEditingController _customCashController = TextEditingController();
  final FocusNode _customCashFocusNode = FocusNode();
  final TextEditingController _customChargeController = TextEditingController();
  final TextEditingController _customUpiController = TextEditingController();
  final FocusNode _customUpiFocusNode = FocusNode();
  final TextEditingController _customerNumberController =
      TextEditingController();

  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _employeeNumberController =
      TextEditingController();

  // Payment method details controllers
  final TextEditingController _holderNameController = TextEditingController();

  // Focus nodes for payment method details
  final FocusNode _holderNameFocus = FocusNode();

  final TextEditingController _ifscCodeController = TextEditingController();
  final FocusNode _ifscCodeFocus = FocusNode();
  bool _isChequeSelected = false;
  bool _isCompleteButtonEnabled = false;
  double _originalAmount = 0.0;
  OverlayEntry? _overlayEntry;
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _returnAmountController = TextEditingController();
  final TextEditingController _salesPersonController = TextEditingController();
  int _upiAmount = 0;
  final TextEditingController _upiController = TextEditingController();

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

    // Payment method detail controllers and focus nodes
    _holderNameController.dispose();
    _bankNameController.dispose();
    _accountNoController.dispose();
    _ifscCodeController.dispose();
    _branchController.dispose();
    _holderNameFocus.dispose();
    _bankNameFocus.dispose();
    _accountNoFocus.dispose();
    _ifscCodeFocus.dispose();
    _branchFocus.dispose();

    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final initialAdvanceList = widget.salesOrder.advanceAmount ?? [];
    double alreadyPaid = initialAdvanceList.fold(0.0, (sum, e) => sum + e);

    _originalAmount = alreadyPaid;
    _balanceAmount = alreadyPaid;

    // Initialize return amount with already paid amount
    _returnAmountController.text = alreadyPaid.toStringAsFixed(0);

    // Set the initial active controller to Return Amount
    _activeKeyboardController = _returnAmountController;

    _cashController.addListener(_updateBalance);
    _upiController.addListener(_updateBalance);
    _cardController.addListener(_updateBalance);
    chequeAmountController.addListener(_updateBalance);

    // Add listeners to validate form when fields change
    _returnAmountController.addListener(() {
      _validateReturnAmount();
      _validateForm();
    });

    // Add listeners to all required fields
    _holderNameController.addListener(_validateForm);
    _accountNoController.addListener(_validateForm);
    _ifscCodeController.addListener(_validateForm);
    _bankNameController.addListener(_validateForm);
    _branchController.addListener(_validateForm);
    _remarksController.addListener(_validateForm);

    _cashController.addListener(() {
      _cashAmount = int.tryParse(_cashController.text) ?? 0;
      _validateAmount(_cashController, "Cash");
      _validateForm();
    });

    _upiController.addListener(() {
      _upiAmount = int.tryParse(_upiController.text) ?? 0;
      _validateAmount(_upiController, "UPI");
      _validateForm();
    });

    _cardController.addListener(() {
      _cardAmount = int.tryParse(_cardController.text) ?? 0;
      _validateAmount(_cardController, "Card");
      _validateForm();
    });

    chequeAmountController.addListener(() {
      _chequeAmount = int.tryParse(chequeAmountController.text) ?? 0;
      _validateAmount(chequeAmountController, "Cheque");
      _validateForm();
    });

    // Setup focus listeners to track which field is active
    _setupFocusListeners();

    // Initial form validation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateForm();
    });
  }

  void _setupFocusListeners() {
    // Listen to all focus nodes
    List<FocusNode> allFocusNodes = [
      returnAmountFocus,
      _holderNameFocus,
      _bankNameFocus,
      _accountNoFocus,
      _ifscCodeFocus,
      _branchFocus,
      remarkFocus,
      chequeNumberFocus,
      chequeAmountFocus,
      chequeNameFocus,
      salespersonFocus,
      _customCashFocusNode,
      _customUpiFocusNode,
      _customCardFocusNode,
    ];

    for (var focusNode in allFocusNodes) {
      focusNode.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check which field has focus
      final Map<FocusNode, TextEditingController> focusMap = {
        returnAmountFocus: _returnAmountController,
        _holderNameFocus: _holderNameController,
        _bankNameFocus: _bankNameController,
        _accountNoFocus: _accountNoController,
        _ifscCodeFocus: _ifscCodeController,
        _branchFocus: _branchController,
        remarkFocus: _remarksController,
        chequeNumberFocus: chequeNumberController,
        chequeAmountFocus: chequeAmountController,
        chequeNameFocus: chequeNameController,
        salespersonFocus: _salesPersonController,
        _customCashFocusNode: _customCashController,
        _customUpiFocusNode: _customUpiController,
        _customCardFocusNode: _customCardController,
      };

      focusMap.forEach((focusNode, controller) {
        if (focusNode.hasFocus) {
          setState(() {
            _activeKeyboardController = controller;
          });
        }
      });
    });
  }

  void _validateReturnAmount() {
    double entered = double.tryParse(_returnAmountController.text) ?? 0;
    double alreadyPaid =
        widget.salesOrder.advanceAmount?.fold(0.0, (sum, e) => sum! + e) ?? 0.0;

    if (entered > alreadyPaid) {
      _returnAmountController.text = alreadyPaid.toStringAsFixed(0);
      _returnAmountController.selection = TextSelection.fromPosition(
        TextPosition(offset: _returnAmountController.text.length),
      );

      TopMessage.show(
        context,
        message:
            "Return amount cannot exceed already paid amount (₹${alreadyPaid.toStringAsFixed(0)})",
        backgroundColor: Colors.redAccent,
      );
    }
  }

  void _validateForm() {
    final returnAmount = double.tryParse(_returnAmountController.text) ?? 0;

    // Check if all required fields are filled
    final bool allRequiredFieldsFilled =
        _returnAmountController.text.isNotEmpty &&
        _returnAmountController.text != "0" &&
        _holderNameController.text.isNotEmpty &&
        _accountNoController.text.isNotEmpty &&
        _ifscCodeController.text.isNotEmpty &&
        _remarksController.text.isNotEmpty &&
        _bankNameController.text.isNotEmpty &&
        _branchController.text.isNotEmpty;

    // Enable button only when totalEntered equals returnAmount AND all required fields are filled
    _isCompleteButtonEnabled = returnAmount > 0 && allRequiredFieldsFilled;

    setState(() {});
  }

  void _validateAmount(TextEditingController controller, String method) {
    double entered = double.tryParse(controller.text) ?? 0;
    double returnAmount = double.tryParse(_returnAmountController.text) ?? 0;

    // Calculate sum of all other entered payments
    double otherPayments = 0.0;
    if (method != "Cash")
      otherPayments += double.tryParse(_cashController.text) ?? 0;
    if (method != "UPI")
      otherPayments += double.tryParse(_upiController.text) ?? 0;
    if (method != "Card")
      otherPayments += double.tryParse(_cardController.text) ?? 0;
    if (method != "Cheque")
      otherPayments += double.tryParse(chequeAmountController.text) ?? 0;

    // Remaining refundable amount (after other payments)
    double maxAllowedForThisMethod = returnAmount - otherPayments;
    if (maxAllowedForThisMethod < 0) maxAllowedForThisMethod = 0;

    if (entered > maxAllowedForThisMethod) {
      controller.text = maxAllowedForThisMethod.toStringAsFixed(0);
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );

      TopMessage.show(
        context,
        message:
            "Entered $method amount exceeds return amount. Max allowed: ₹${maxAllowedForThisMethod.toStringAsFixed(0)}",
        backgroundColor: Colors.redAccent,
      );
    }

    _updateBalance();
    _validateForm();
  }

  Future<bool> _handleCardPayment() async {
    try {
      final qrProvider = Provider.of<RazorpayQRProvider>(
        context,
        listen: false,
      );
      final stateProvider = Provider.of<SalesInvoiceState>(
        context,
        listen: false,
      );
      final cardAmountStr = _returnAmountController.text;

      if (cardAmountStr.isNotEmpty) {
        final cardAmount = double.tryParse(cardAmountStr);
        if (cardAmount != null && cardAmount > 0) {
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Card payment error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  void _updateBalance() {
    setState(() {
      final cash = double.tryParse(_cashController.text) ?? 0;
      final upi = double.tryParse(_upiController.text) ?? 0;
      final card = double.tryParse(_cardController.text) ?? 0;
      final cheque = double.tryParse(chequeAmountController.text) ?? 0;
      final returnAmount = double.tryParse(_returnAmountController.text) ?? 0;

      final double totalEntered = cash + upi + card + cheque;

      if (totalEntered > returnAmount) {
        TopMessage.show(
          context,
          message:
              "Entered ₹${totalEntered.toStringAsFixed(0)} exceeds return amount (₹${returnAmount.toStringAsFixed(0)}).",
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          duration: const Duration(seconds: 3),
        );
        _cashController.clear();
        _upiController.clear();
        _cardController.clear();
        chequeAmountController.clear();
        return;
      }
    });
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = true,
    bool enabled = true,

    String? prefixText,
    VoidCallback? onTap,
    FocusNode? focusNode,
    double fontSize = 14,
    Color borderColor = Colors.grey,
    Color focusedBorderColor = Colors.blueAccent,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      showCursor: true,
      enabled: enabled,
      keyboardType: keyboardType,
      onTap: () {
        setState(() {
          _activeKeyboardController = controller;
        });
        if (onTap != null) onTap();
      },
      onChanged: (value) {
        // Trigger validation when field changes
        _validateForm();
      },
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: Colors.black54,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixText: prefixText,
        prefixIcon: Icon(icon, color: Colors.blueGrey.shade600, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: focusedBorderColor, width: 1.8),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildPaymentMethodDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              // Return Amount (Single Field)
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: _buildFormField(
                        controller: _returnAmountController,
                        enabled: false,
                        labelText: 'Return Amount',
                        icon: Icons.monetization_on_outlined,
                        hintText: 'Enter amount to refund',
                        keyboardType: TextInputType.number,
                        focusNode: returnAmountFocus,
                        onTap: () {
                          ActiveField.activate(
                            context: context,
                            ctrl: _returnAmountController,
                            node: returnAmountFocus,
                            numeric: true,
                          );
                        },
                        fontSize: 15,
                        borderColor: Colors.grey.shade300,
                        focusedBorderColor: Colors.green,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: _buildFormField(
                        controller: _holderNameController,
                        labelText: 'Account Holder Name',
                        icon: Icons.person_outline,
                        hintText: 'Enter full name as in bank',
                        keyboardType: TextInputType.text,
                        focusNode: _holderNameFocus,
                        onTap: () {
                          ActiveField.activate(
                            context: context,
                            ctrl: _holderNameController,
                            node: _holderNameFocus,
                            numeric: false,
                          );
                        },
                        fontSize: 14,
                        borderColor: Colors.grey.shade300,
                        focusedBorderColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              // Row: Account No & IFSC Code
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: _buildFormField(
                        controller: _accountNoController,
                        labelText: 'Account Number',
                        icon: Icons.credit_card_outlined,
                        hintText: 'Enter account number',
                        keyboardType: TextInputType.number,
                        focusNode: _accountNoFocus,
                        onTap: () {
                          ActiveField.activate(
                            context: context,
                            ctrl: _accountNoController,
                            node: _accountNoFocus,
                            numeric: true,
                          );
                        },
                        fontSize: 14,
                        borderColor: Colors.grey.shade300,
                        focusedBorderColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: _buildFormField(
                        controller: _ifscCodeController,
                        labelText: 'IFSC Code',
                        icon: Icons.qr_code_scanner_outlined,
                        hintText: 'Bank IFSC code',
                        keyboardType: TextInputType.text,
                        focusNode: _ifscCodeFocus,
                        onTap: () {
                          ActiveField.activate(
                            context: context,
                            ctrl: _ifscCodeController,
                            node: _ifscCodeFocus,
                            numeric: false,
                          );
                        },
                        fontSize: 14,
                        borderColor: Colors.grey.shade300,
                        focusedBorderColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              // Row: Bank Name & Branch
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: _buildFormField(
                        controller: _bankNameController,
                        labelText: 'Bank Name',
                        icon: Icons.account_balance_outlined,
                        hintText: 'Enter bank name',
                        keyboardType: TextInputType.text,
                        focusNode: _bankNameFocus,
                        onTap: () {
                          ActiveField.activate(
                            context: context,
                            ctrl: _bankNameController,
                            node: _bankNameFocus,
                            numeric: false,
                          );
                        },
                        fontSize: 14,
                        borderColor: Colors.grey.shade300,
                        focusedBorderColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: _buildFormField(
                        controller: _branchController,
                        labelText: 'Branch',
                        icon: Icons.location_on_outlined,
                        hintText: 'Enter branch name',
                        keyboardType: TextInputType.text,
                        focusNode: _branchFocus,
                        onTap: () {
                          ActiveField.activate(
                            context: context,
                            ctrl: _branchController,
                            node: _branchFocus,
                            numeric: false,
                          );
                        },
                        fontSize: 14,
                        borderColor: Colors.grey.shade300,
                        focusedBorderColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              // Remarks & Sales Person Row
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: _buildFormField(
                        controller: _remarksController,
                        labelText: 'Remarks',
                        icon: Icons.comment_outlined,
                        hintText: 'Enter remarks for cancellation',
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
                        fontSize: 14,
                        borderColor: Colors.grey.shade300,
                        focusedBorderColor: Colors.orangeAccent,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade200, height: 1, thickness: 1.2),

              const SizedBox(height: 12),
              Consumer<CustomerScreenProvider>(
                builder: (context, provider, _) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blueAccent.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Refund will be processed to the above account',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.blueGrey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Submit logic
  Future<void> _submitCancellation() async {
    if (!_isCompleteButtonEnabled) return;

    // 🔴 FIX HERE: Add listen: false
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    setState(() {
      isSubmitting = true;
    });

    try {
      // Validate all required fields
      if (_holderNameController.text.isEmpty) {
        TopMessage.show(
          context,
          message: "Please enter account holder name",
          backgroundColor: Colors.redAccent,
        );
        return;
      }

      if (_accountNoController.text.isEmpty) {
        TopMessage.show(
          context,
          message: "Please enter account number",
          backgroundColor: Colors.redAccent,
        );
        return;
      }

      if (_ifscCodeController.text.isEmpty) {
        TopMessage.show(
          context,
          message: "Please enter IFSC code",
          backgroundColor: Colors.redAccent,
        );
        return;
      }

      if (_bankNameController.text.isEmpty) {
        TopMessage.show(
          context,
          message: "Please enter bank name",
          backgroundColor: Colors.redAccent,
        );
        return;
      }

      if (_branchController.text.isEmpty) {
        TopMessage.show(
          context,
          message: "Please enter branch name",
          backgroundColor: Colors.redAccent,
        );
        return;
      }

      // Step 3: Build approval details with banking information
      final approvalDetails = {
        "approvalType": "Cancel Order",
        "summary": "no",
        "accountHolderName": _holderNameController.text,
        "accountNumber": _accountNoController.text,
        "ifscCode": _ifscCodeController.text,
        "bankName": _bankNameController.text,
        "branchName": _branchController.text,
        "refundAmount": _returnAmountController.text.isEmpty
            ? 0
            : double.parse(_returnAmountController.text),
        "refundMethod": "Bank Transfer",
        "transactionDate": DateTime.now().toIso8601String(),
        "approvalRemarks": _remarksController.text,
      };

      final payload = {
        "status": "Waiting for approval",
        "cancelOrderRemark": _remarksController.text,
        "canceledPersonName":
            customerScreenProvider.searchController.text ?? "",
        "saleOrderNo": widget.salesOrder.saleOrderNo,
        "returnAmount": _returnAmountController.text.isEmpty
            ? "0"
            : _returnAmountController.text,
        "cancelOrderDate": DateTime.now().toIso8601String(),
        "approvalDetails": [approvalDetails],
      };

      // Step 4: Call Provider method
      customerScreenProvider.cancelOrder(
        widget.salesOrder.saleOrderNo,
        payload,
        context,
      );
      await Future.delayed(const Duration(seconds: 1));

      TopMessage.show(
        context,
        message: "Order cancelled successfully! Refund initiated.",
        backgroundColor: Colors.green,
      );

      // Navigate back
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      TopMessage.show(
        context,
        message: "Error cancelling order: $e",
        backgroundColor: Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(context);
    double alreadyPaid =
        widget.salesOrder.advanceAmount?.fold(0.0, (sum, e) => sum! + e) ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        elevation: 3,
        centerTitle: true,
        title: Text(
          "Cancel Order - Refund ₹${alreadyPaid.toStringAsFixed(0)}",
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Payment Method Details Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      shadowColor: Colors.blue.withOpacity(0.2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _buildPaymentMethodDetails(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Panel - ALWAYS show keyboard
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 3,
                    offset: const Offset(0, -4),
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: Colors.blueGrey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  foregroundColor: Colors.blueGrey.shade800,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                      },
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSubmitting
                                        ? Colors.grey
                                        : Colors.blueGrey.shade800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isCompleteButtonEnabled && !isSubmitting
                                      ? Colors.red.shade400
                                      : Colors.grey.shade400,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                  shadowColor: Colors.red.withOpacity(0.3),
                                ),
                                onPressed:
                                    _isCompleteButtonEnabled && !isSubmitting
                                    ? _submitCancellation
                                    : null,
                                child: isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        "Cancel Order",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
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
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: double.infinity,
                        child: AdvanceAmountKeyboardWidgetAll2(
                          controller: _activeKeyboardController,
                          onChanged: () {
                            _updateBalance();
                            _validateForm();
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
}

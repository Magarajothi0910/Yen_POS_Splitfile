import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yenpos/Sale_order/Widgets/cheque_details.dart';
import 'package:yenpos/Sale_order/Widgets/customAll_keyboard.dart';

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

  final TextEditingController _customUpiController = TextEditingController();
  final TextEditingController _customCardController = TextEditingController();
  String selectedPaymentMethod = 'Cash';
  final TextEditingController chequeNumberController = TextEditingController();
  final TextEditingController chequeAmountController = TextEditingController();
  final TextEditingController chequeNameController = TextEditingController();
  final TextEditingController chequeBankController = TextEditingController();
  final TextEditingController chequeDateController = TextEditingController();
  OverlayEntry? _overlayEntry;
  final GlobalSOWebSocketService _salesorder_webSocketService =
      GlobalSOWebSocketService();


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
  final TextEditingController _discountController = TextEditingController();
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

    controllers = [
      _cashController,
      _upiController,
      _cardController,
      chequeNumberController,
      chequeAmountController,
      chequeNameController,
      chequeBankController,
      chequeDateController,
    ];

    _customCashController.addListener(() {
      _cashAmount = int.tryParse(_customCashController.text) ?? 0;
      _updateBalance();
    });

    _customUpiController.addListener(() {
      _upiAmount = int.tryParse(_customUpiController.text) ?? 0;
      _updateBalance();
    });

    _customCardController.addListener(() {
      _cardAmount = int.tryParse(_customCardController.text) ?? 0;
      _updateBalance();
    });

    chequeAmountController.addListener(() {
      _chequeAmount = int.tryParse(chequeAmountController.text) ?? 0;
      _updateBalance();
    });

    _salesorder_webSocketService.initialize();
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

  void _updateBalance() {
    setState(() {
      final cash = double.tryParse(_cashController.text) ?? 0;
      final upi = double.tryParse(_upiController.text) ?? 0;
      final card = double.tryParse(_cardController.text) ?? 0;

      _cashAmount = cash.toInt();
      _upiAmount = upi.toInt();
      _cardAmount = card.toInt();

      _balanceAmount = widget.totalAmount - (cash + upi + card);

      // Detect if one method equals total amount and others are empty
      if (cash == widget.totalAmount && upi == 0 && card == 0) {
        _activePaymentMethod = "Cash";
      } else if (upi == widget.totalAmount && cash == 0 && card == 0) {
        _activePaymentMethod = "UPI";
      } else if (card == widget.totalAmount && cash == 0 && upi == 0) {
        _activePaymentMethod = "Card";
      } else {
        _activePaymentMethod = null; // split payment or not exact
      }
    });
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
              readOnly: true, // ❌ Prevent system keyboard
              showCursor: true, // ✅ Show blinking cursor
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
            ),
          ),
        ],
      ),
    );
  }

  void _validateForm() {
    _isPrintButtonEnabled = true;
    setState(() {});
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
        backgroundColor: Colors.indigoAccent.shade700,
        elevation: 3,
        centerTitle: true,
        title: const Text(
          "Sales Order",
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

            // 🔹 Static Footer Section (not scrollable)
            Container(
              padding: EdgeInsets.fromLTRB(padding, 12, padding, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 🔹 Total & Balance Row
                  Row(
                    children: [
                      _buildMiniCard(
                        title: "Total",
                        value: '₹${widget.totalAmount.toStringAsFixed(0)}',
                        gradient: [Colors.green[100]!, Colors.green[300]!],
                      ),
                      const SizedBox(width: 12),
                      _buildMiniCard(
                        title: "Balance",
                        value: '₹${_balanceAmount.toStringAsFixed(0)}',
                        gradient: [Colors.orange[100]!, Colors.orange[300]!],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 🔹 Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                            backgroundColor: Colors.green[400],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: (isSubmitting || _balanceAmount > 0)
                              ? null
                              : () async {
                                  setState(() => isSubmitting = true);
                                  try {
                                    markOrderAsCompleted(salesOrderId);
                                  } catch (e) {
                                  } finally {
                                    setState(() => isSubmitting = false);
                                  }
                                },
                          child: Text(
                            isSubmitting ? "Processing..." : "Print Receipt",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 🔹 Always visible Custom Keyboard
            Container(
              height: 170, // slightly compact
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: const Border(
                  top: BorderSide(color: Colors.black12, width: 1),
                ),
              ),

              child: SizedBox(
                height: 210,
                child: ValueListenableBuilder<TextEditingController?>(
                  valueListenable: ActiveField.controller,
                  builder: (_, ctrl, __) {
                    return Column(
                      children: [
                        const SizedBox(height: 8),
                        Expanded(
                          child: CustomKeyboardWidgetAll2(
                            controller: ctrl ?? TextEditingController(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  void markOrderAsCompleted(String salesOrderId) async {
    final invoiceDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final now = DateTime.now();

    final invoiceTime = DateFormat('hh:mm a').format(now); // e.g., 01:07 PM
    final so = widget.salesOrder;

    // Calculate total advance amount
    final totalAdvanceAmount = widget.salesOrder.advanceAmount!.fold<double>(
      0.0,
      (sum, value) => sum + value,
    );

    try {
      // Patch body
      final patchBody = {
        "salesOrderId": so.salesOrderId,
        "status": "Sales Completed",
        "invoiceDate": invoiceDate,
        "invoiceTime": invoiceTime, // <-- added
      };

      // Wrap patch into JSON
      final patchJson = jsonEncode({
        "data": patchBody,
        "saleOrderNo": so.saleOrderNo,
        "type": "patchSaleOrder",
        "sync": "No",
        "edit": "No",
      });

      await _salesorder_webSocketService.sendData(jsonDecode(patchJson));

      // Prepare full invoice body
      // ✅ 3️⃣ Prepare the full invoice body (all fields included)
      final fullInvoiceBody = {
        "itemName": so.itemName,
        "varianceName": so.varianceName,
        "varianceitemCode": so.itemCode,
        "price": so.price,
        "weight": so.weight,
        "qty": so.qty,
        "amount": so.amount,
        "tax": so.tax,
        "uom": so.uom,
        "totalAmount": so.totalAmount,
        "advanceAmount": totalAdvanceAmount,
        "advanceDate": invoiceDate,
        "advanceTime": invoiceTime,
        "status": "Sales Completed",
        "salesType": "Sales Order",
        "customerPhoneNumber": so.customerNumber,
        "salesPerson": so.employeeName,
        "branchId": so.branchId,
        "branchName": so.branchName,
        "aliasName": so.aliasName,
        "cash": so.cash ?? 0,
        "card": so.card ?? 0,
        "upi": so.upi ?? 0,
        "invoiceDate": invoiceDate,
        "invoiceTime": invoiceTime,
        "shiftId": so.shiftId,
        "customCharge": so.customCharge,
        "discountAmount": so.discountAmount,
        "discountPercentage": so.discount,
        "salesOrderId": so.salesOrderId,
        "advanceDateTime": so.advanceDateTime,
      };
      // Wrap invoice into JSON
      final invoiceJson = jsonEncode({
        "salesOrderId": fullInvoiceBody,
        "type": "posInvoice",
        "sync": "No",
        "edit": "No",
      });

      await _salesorder_webSocketService.sendData(jsonDecode(invoiceJson));
    } catch (e, stack) {}

    Navigator.pop(context);
  }
}

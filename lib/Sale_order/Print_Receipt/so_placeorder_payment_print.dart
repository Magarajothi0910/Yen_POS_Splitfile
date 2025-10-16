import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/discount_service.dart' as globaldiscount;
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Widgets/cheque_details.dart';
import 'package:yenpos/Sale_order/Widgets/paymentDetail_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/top_message.dart';

class PlaceOrderPaymentPrint extends StatefulWidget {
  final double totalAmount;
  final String holdBillId;
  final String orderId;
  final String remark;
  final double orderAmount;
  final double discount;
  final double totalAdvance;
  final double deductedAmount;
  final double customCharge;
  final String selectedStoreType;
  // 🔹 Extra fields you wanted
  final CartSelectionProvider cartSelectionProvider;
  final CartProvider cartProvider;
  final String? path;
  final ApiServiceSalesOrderProvider apiprovider;
  final File? img1;
  final File? img2;
  final String customerType;
  final String? audioOrderId;
  final String? holdId;

  const PlaceOrderPaymentPrint({
    super.key,
    required this.totalAmount,
    required this.totalAdvance,
    required this.deductedAmount,
    required this.customCharge,
    required this.holdBillId,
    required this.orderId,
    required this.discount,
    required this.cartSelectionProvider,
    required this.cartProvider,
    required this.apiprovider,
    required this.customerType,
    this.path,
    this.img1,
    this.img2,
    this.audioOrderId,
    this.holdId,
    required this.remark,
    required this.orderAmount,
    required this.selectedStoreType,
  });

  @override
  State<PlaceOrderPaymentPrint> createState() => _PlaceOrderPaymentPrintState();
}

class _PlaceOrderPaymentPrintState extends State<PlaceOrderPaymentPrint> {
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

  final ScrollController _scrollController = ScrollController();
  final GlobalKey keyboardKey = GlobalKey();

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
  // discount vars
  bool _isDiscountDisabled = false;
  double discount = 0;
  double deductedAmount = 0;
  double customCharge = 0;
  double totalAmount = 0;
  bool isSubmitting = false;
  String? _activePaymentMethod; // null means split or no exact match
  @override
  void initState() {
    super.initState();

    totalAmount = widget.totalAmount; // ✅ use widget.totalAmount instead of 0
    cashOptions.addAll(_generateCashOptions(widget.totalAmount));

    _originalAmount = widget.totalAmount;
    _upiAndCashAmount = widget.totalAmount;
    _balanceAmount = widget.totalAmount;

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
    // ✅ Disable discount field if item-wise discount applied
    final hasItemWiseDiscount = widget.cartProvider.cartItems.any(
      (item) => item.itemWiseDiscount != null && item.itemWiseDiscount! > 0,
    );
    _isDiscountDisabled = hasItemWiseDiscount;
    // 🔹 Cash validation
    _cashController.addListener(() {
      _cashAmount = int.tryParse(_cashController.text) ?? 0;
      _validateAmount(_cashController, "Cash");
    });

    // 🔹 UPI validation
    _upiController.addListener(() {
      _upiAmount = int.tryParse(_upiController.text) ?? 0;
      _validateAmount(_upiController, "UPI");
    });

    // 🔹 Card validation
    _cardController.addListener(() {
      _cardAmount = int.tryParse(_cardController.text) ?? 0;
      _validateAmount(_cardController, "Card");
    });

    // 🔹 Cheque validation
    chequeAmountController.addListener(() {
      _chequeAmount = int.tryParse(chequeAmountController.text) ?? 0;
      _validateAmount(chequeAmountController, "Cheque");
    });
    _discountController.addListener(() {
      final value = _discountController.text;
      _applyDiscount(value);
    });
  }

  /// ✅ Generic validation method (common for Cash, UPI, Card, Cheque)
  void _validateAmount(TextEditingController controller, String paymentType) {
    final entered = double.tryParse(controller.text) ?? 0;

    if (entered < 0) {
      controller.text = "0";
      TopMessage.show(
        context,
        message: "$paymentType amount cannot be negative",
        backgroundColor: Colors.redAccent,
      );
    } else if (entered > widget.totalAmount) {
      controller.text = widget.totalAmount.toStringAsFixed(0);
      TopMessage.show(
        context,
        message:
            "$paymentType amount cannot exceed total ₹${widget.totalAmount}",
        backgroundColor: Colors.orangeAccent,
      );
    }

    _updateBalance();
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
    final cheque = double.tryParse(chequeAmountController.text) ?? 0;

    // ✅ Use discounted totalAmount, not widget.totalAmount
    final remaining = totalAmount - (cash + upi + card + cheque);

    if (method == "Cash" && _cashController.text.isEmpty) {
      return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
    }
    if (method == "UPI" && _upiController.text.isEmpty) {
      return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
    }
    if (method == "Card" && _cardController.text.isEmpty) {
      return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
    }
    if (method == "Cheque" && chequeAmountController.text.isEmpty) {
      return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
    }

    return "0";
  }

  void _updateBalance() {
    setState(() {
      final cash =
          double.tryParse(
            _cashController.text.isNotEmpty
                ? _cashController.text
                : _customCashController.text,
          ) ??
          0;
      final upi =
          double.tryParse(
            _upiController.text.isNotEmpty
                ? _upiController.text
                : _customUpiController.text,
          ) ??
          0;
      final card =
          double.tryParse(
            _cardController.text.isNotEmpty
                ? _cardController.text
                : _customCardController.text,
          ) ??
          0;
      final cheque = double.tryParse(chequeAmountController.text) ?? 0;

      _cashAmount = cash.toInt();
      _upiAmount = upi.toInt();
      _cardAmount = card.toInt();
      _chequeAmount = cheque.toInt();

      // ✅ Use discounted totalAmount instead of widget.totalAmount
      _balanceAmount = totalAmount - (cash + upi + card + cheque);

      if (cash == totalAmount && upi == 0 && card == 0 && cheque == 0) {
        _activePaymentMethod = "Cash";
      } else if (upi == totalAmount && cash == 0 && card == 0 && cheque == 0) {
        _activePaymentMethod = "UPI";
      } else if (card == totalAmount && cash == 0 && upi == 0 && cheque == 0) {
        _activePaymentMethod = "Card";
      } else if (cheque == totalAmount && cash == 0 && upi == 0 && card == 0) {
        _activePaymentMethod = "Cheque";
      } else {
        _activePaymentMethod = null;
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
              onTap: () {
                ActiveField.activate(
                  ctrl: controller,
                  node: focus,
                  numeric: true,
                );
              },
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

  String _getItemWiseDiscountText() {
    final itemWiseDiscounts = widget.cartProvider.cartItems
        .where(
          (item) => item.itemWiseDiscount != null && item.itemWiseDiscount! > 0,
        )
        .map((item) => item.itemWiseDiscount!)
        .toList();

    if (itemWiseDiscounts.isNotEmpty) {
      // Calculate average discount
      final averageDiscount =
          itemWiseDiscounts.reduce((a, b) => a + b) / itemWiseDiscounts.length;
      // Round to 1 decimal for neat display
      final roundedDiscount = averageDiscount.toStringAsFixed(1);
      return '$roundedDiscount% item-wise discount applied';
    }
    return 'Item-wise discount applied';
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

  // ✅ Apply discount calculation
  void _applyDiscount(String value) {
    setState(() {
      // Step 1: Check if any cart item has item-wise discount
      final itemWiseDiscounts = widget.cartProvider.cartItems
          .where(
            (item) =>
                item.itemWiseDiscount != null && item.itemWiseDiscount! > 0,
          )
          .map((item) => item.itemWiseDiscount!)
          .toList();

      if (itemWiseDiscounts.isNotEmpty) {
        _discountController.text = ""; // clear entered discount

        // 🔹 Get maximum applied item-wise discount percentage
        final maxDiscount = itemWiseDiscounts.reduce((a, b) => a > b ? a : b);

        TopMessage.show(
          context,
          message:
              'Item-wise discount of $maxDiscount% already applied. Overall discount cannot be applied.',
          backgroundColor: Colors.redAccent,
        );
        return; // stop further discount application
      }

      // Step 2: Continue with normal discount logic
      discount = double.tryParse(value) ?? 0;

      deductedAmount = (discount / 100) * _originalAmount;

      totalAmount = _originalAmount + customCharge - deductedAmount;

      if (discount > globaldiscount.globalDiscountPercentage) {
        _discountController.text = "";
        TopMessage.show(
          context,
          message: 'Discount exceeds allowed limit. Please send for approval.',
          backgroundColor: Colors.orangeAccent,
        );
      }

      _updateBalance();
    });
  }

  // 👇 Add this
  bool _showChequeDetails = false;
  @override
  Widget build(BuildContext context) {
    double padding = MediaQuery.of(context).size.width * 0.04;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Scrollable Payment Section
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController, // ✅ attach controller
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
                    Container(
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
                        children: [
                          const Expanded(
                            flex: 2,
                            child: Text(
                              "Discount",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _discountController,
                              readOnly:
                                  true, // Always true (custom keyboard only)
                              enabled:
                                  !_isDiscountDisabled, // Disable only if item-wise discount exists
                              showCursor: !_isDiscountDisabled,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.percent,
                                  color: Colors.black,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                filled: true,
                                fillColor: _isDiscountDisabled
                                    ? Colors.grey[200]
                                    : Colors.grey[50],
                                hintText: _isDiscountDisabled
                                    ? _getItemWiseDiscountText() // dynamic hint text
                                    : 'Enter Discount',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onTap: () {
                                if (!_isDiscountDisabled) {
                                  ActiveField.activate(
                                    ctrl: _discountController,
                                    node: FocusNode(),
                                    numeric: true,
                                  );
                                }
                              },
                              onChanged: (value) {
                                if (!_isDiscountDisabled) {
                                  _applyDiscount(value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // 🔹 Show Deducted Amount
                          Text(
                            deductedAmount > 0
                                ? "- ₹${deductedAmount.round().toStringAsFixed(0)}"
                                : "",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                  // Clear other payment fields
                                  _cashController.clear();
                                  _upiController.clear();
                                  _cardController.clear();
                                  _updateBalance();

                                  // Auto scroll after the frame is built
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    _scrollController.animateTo(
                                      _scrollController
                                          .position
                                          .maxScrollExtent,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  });
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
                        keyboardKey: keyboardKey,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 🔹 Footer Section with Split Layout
            Container(
              padding: const EdgeInsets.all(12),
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
              height: 200, // adjust height as needed
              child: Row(
                children: [
                  // 🔹 Right Section: Keyboard
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: SizedBox(
                        height: double.infinity,
                        child: ValueListenableBuilder<TextEditingController?>(
                          valueListenable: ActiveField.controller,
                          builder: (_, ctrl, __) {
                            return PaymentDetailCustomKeyboardWidgetAll2(
                              controller: ctrl ?? TextEditingController(),
                              onChanged: _updateBalance,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // 🔹 Left Section: Total/Balance/Buttons\
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // Total and Balance Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildMiniCard(
                                title: "Total",
                                value: '₹${totalAmount.toStringAsFixed(0)}',
                                gradient: [
                                  Colors.green[100]!,
                                  Colors.green[300]!,
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMiniCard(
                                title: "Balance",
                                value: '₹${_balanceAmount.toStringAsFixed(0)}',
                                gradient: [
                                  Colors.orange[100]!,
                                  Colors.orange[300]!,
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Cancel & Complete Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  Map<String, double> payments = {};
                                  if (_cashController.text.isNotEmpty) {
                                    payments["Cash"] =
                                        double.tryParse(_cashController.text) ??
                                        0.0;
                                  }
                                  if (_cardController.text.isNotEmpty) {
                                    payments["Card"] =
                                        double.tryParse(_cardController.text) ??
                                        0.0;
                                  }
                                  if (_upiController.text.isNotEmpty) {
                                    payments["UPI"] =
                                        double.tryParse(_upiController.text) ??
                                        0.0;
                                  }
                                  if (chequeAmountController.text.isNotEmpty) {
                                    payments["Cheque"] =
                                        double.tryParse(
                                          chequeAmountController.text,
                                        ) ??
                                        0.0;
                                  }
                                  Navigator.pop(context);
                                  if (selectedPaymentMethod == 'Cheque') {
                                    await customerScreenProvider
                                        .sendForApproval(
                                          cartProvider,
                                          widget.totalAdvance,
                                          widget.orderAmount,
                                          discount,
                                          deductedAmount,
                                          widget.customCharge,
                                          totalAmount,
                                          widget.remark,
                                          widget.path,
                                          widget.apiprovider,
                                          widget.img1,
                                          widget.img2,
                                          widget.audioOrderId,
                                          widget.holdId,
                                          "Cheque",
                                          context,
                                          payments, // 👈 pass payments map
                                        );
                                    return;
                                  }

                                  showDialog(
                                    barrierDismissible: false,
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        title: Row(
                                          children: const [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 24,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Confirm Order',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: const Text(
                                          'Are you sure you want to complete the order?',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        actions: [
                                          OutlinedButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                color: Colors.red,
                                              ),
                                            ),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              await customerScreenProvider
                                                  .saveOrder(
                                                    cartProvider,
                                                    widget
                                                        .cartSelectionProvider,
                                                    widget.totalAdvance,
                                                    widget.orderAmount,
                                                    discount,
                                                    deductedAmount,
                                                    totalAmount,
                                                    widget.remark,
                                                    widget.path,
                                                    widget.apiprovider,
                                                    widget.img1,
                                                    widget.img2,
                                                    widget.audioOrderId,
                                                    widget.holdId,
                                                    widget.selectedStoreType,
                                                    context,
                                                    payments, // 👈 pass payments map
                                                  );

                                              Navigator.pop(
                                                context,
                                              ); // Close dialog
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.blueAccent,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Confirm'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  selectedPaymentMethod == 'Cheque'
                                      ? 'Send to Approval'
                                      : 'Complete Order',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}

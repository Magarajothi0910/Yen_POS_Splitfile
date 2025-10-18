import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenposapp/Global/globals_data.dart';
import 'package:yenposapp/Global/salesorder_websocket_service.dart';
import 'package:yenposapp/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenposapp/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yenposapp/Sale_order/Widgets/advance_amount_payment_keybaord.dart';
import 'package:yenposapp/Sale_order/Widgets/cheque_details.dart';

class AddAdvancePayment extends StatefulWidget {
  final SalesOrderDisplay salesOrder;

  const AddAdvancePayment({
    super.key,
    required this.salesOrder,
  });

  @override
  State<AddAdvancePayment> createState() => _AddAdvancePaymentState();
}

class _AddAdvancePaymentState extends State<AddAdvancePayment> {
  final List<String> cashOptions = [];
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _employeeNumberController =
      TextEditingController();
  // single keyboard key (removed duplicate)
  final GlobalKey keyboardKey = GlobalKey();

  // Make channel late-initialized so we can create it in initState
  late final WebSocketChannel _channel;

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
  // removed duplicate keyboardKey

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
  int _sendInvoiceCallCount = 0;

  Future<void> sendInvoiceDataToServer(Map<String, dynamic> invoiceData) async {
    _sendInvoiceCallCount++;
    print("_sendInvoiceCallCount++: ${_sendInvoiceCallCount++}");
    try {
      final jsonData = jsonEncode(invoiceData);
      _channel.sink.add(jsonData);
    } catch (e) {
      // handle/send logs if needed
    }
  }

  @override
  void initState() {
    super.initState();
    print("initState() called");

    _channel = WebSocketChannel.connect(
      Uri.parse('ws://$serverip:$port'),
    );
    print("WebSocket connected to ws://$serverip:$port");

    _channel.stream.listen(
      (data) {
        print("Received WebSocket data: $data");
      },
      onError: (error) {
        print("WebSocket error: $error");
      },
    );

    final initialAdvanceList = widget.salesOrder.advanceAmount ?? [];
    print("Initial advance list: $initialAdvanceList");

    cashOptions.addAll(_generateCashOptions(
        initialAdvanceList.fold(0.0, (sum, e) => sum + e)));
    print("Cash options generated: $cashOptions");

    totalAmount = List.from(initialAdvanceList);
    print("Total amount list initialized: $totalAmount");

    double alreadyPaid = initialAdvanceList.fold(0.0, (sum, e) => sum + e);
    print("Already paid: $alreadyPaid");

    _originalAmount = alreadyPaid;
    _upiAndCashAmount = alreadyPaid;
    _balanceAmount = widget.salesOrder.totalAmount - alreadyPaid;
    salesOrderId = widget.salesOrder.saleOrderNo ?? '';
    print("Original amount: $_originalAmount, Balance: $_balanceAmount, "
        "SalesOrderId: $salesOrderId");

    _employeeNumberController.addListener(_validateForm);
    _customerNumberController.addListener(_validateForm);
    _customAmountController.addListener(_validateForm);

    print("Listeners added to controllers");
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
          TextPosition(offset: controller.text.length));
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

    // close websocket
    try {
      _channel.sink.close();
    } catch (e) {
      // ignore
    }

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
    print("------ _getSuggestedAmount Debug ------");
    print("Method: $method");
    print("Cash Entered: $cash");
    print("UPI Entered: $upi");
    print("Card Entered: $card");
    print("Already Paid (from advance): $alreadyPaid");
    print("Total Amount: ${widget.salesOrder.totalAmount}");
    print("Remaining Balance (after cash/upi/card): $remaining");

    if (method == "Cash" && _cashController.text.isEmpty) {
      print(
          "Cash field empty → Suggested: ${remaining > 0 ? remaining.toStringAsFixed(0) : "0"}");
      return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
    }
    if (method == "UPI" && _upiController.text.isEmpty) {
      print(
          "UPI field empty → Suggested: ${remaining > 0 ? remaining.toStringAsFixed(0) : "0"}");
      return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
    }
    if (method == "Card" && _cardController.text.isEmpty) {
      print(
          "Card field empty → Suggested: ${remaining > 0 ? remaining.toStringAsFixed(0) : "0"}");
      return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
    }

    print("No suggestion → Returning 0");
    return "0";
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

      print("✅ Updated balance: $_balanceAmount");
    });
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

    print("🔄 Building Sales Order Screen");
    print("Current Balance: $_balanceAmount");
    print(
        "Already Paid: ${widget.salesOrder.advanceAmount?.fold(0.0, (s, e) => s + e) ?? 0.0}");
    print("Total Amount: ${widget.salesOrder.totalAmount}");

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
                              "Cash", _cashController, _customCashFocusNode),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentEntry(
                              "Card", _cardController, _customCardFocusNode),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 🔹 UPI + Cheque
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentEntry(
                              "UPI", _upiController, _customUpiFocusNode),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showChequeDetails = !_showChequeDetails;
                                _isChequeSelected = _showChequeDetails;

                                print(
                                    "📝 Cheque Toggled → $_showChequeDetails");

                                if (_isChequeSelected) {
                                  print(
                                      "✅ Cheque selected → Clearing Cash/UPI/Card fields");
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
                        onFocusChanged: (index) {
                          print("✍️ Cheque field $index focused");
                        },
                        keyboardKey: keyboardKey,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 🔹 Static Footer Section
            Container(
              padding: EdgeInsets.fromLTRB(padding, 12, padding, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildMiniCard(
                        title: "Total",
                        value:
                            '₹${widget.salesOrder.totalAmount.toStringAsFixed(0)}',
                        gradient: [Colors.green[100]!, Colors.green[300]!],
                      ),
                      const SizedBox(width: 12),
                      _buildMiniCard(
                        title: "Advance Paid",
                        value:
                            '₹${(widget.salesOrder.advanceAmount?.fold(0.0, (s, e) => s + e) ?? 0.0).toStringAsFixed(0)}',
                        gradient: [Colors.blue[100]!, Colors.blue[300]!],
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
                            print("❌ Cancel clicked");
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
                          onPressed: (isSubmitting)
                              ? null
                              : () async {
                                  setState(() => isSubmitting = true);

                                  try {
                                    print(
                                        "🔍 [DEBUG] ====== Advance Payment Process Started ======");

                                    // 1️⃣ Parse amounts
                                    final cash =
                                        double.tryParse(_cashController.text) ??
                                            0;
                                    final card =
                                        double.tryParse(_cardController.text) ??
                                            0;
                                    final upi =
                                        double.tryParse(_upiController.text) ??
                                            0;
                                    final cheque = double.tryParse(
                                            chequeAmountController.text) ??
                                        0;

                                    print(
                                        "💰 Entered Amounts → Cash: $cash | Card: $card | UPI: $upi | Cheque: $cheque");

                                    final totalEntered =
                                        cash + card + upi + cheque;
                                    print("📊 Total Entered: $totalEntered");

                                    // 2️⃣ Existing paid amount
                                    final alreadyPaid = widget
                                            .salesOrder.advanceAmount
                                            ?.fold(0.0, (sum, e) => sum + e) ??
                                        0;

                                    // 3️⃣ Remaining balance before this transaction
                                    final remainingBalanceBefore =
                                        widget.salesOrder.totalAmount -
                                            alreadyPaid;
                                    print(
                                        "🧮 Remaining Balance Before: $remainingBalanceBefore");

                                    // 4️⃣ Validate entered amount
                                    if (totalEntered > remainingBalanceBefore) {
                                      print(
                                          "❌ ERROR: Entered amount exceeds remaining balance!");
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Entered amount exceeds remaining balance (₹${remainingBalanceBefore.toStringAsFixed(0)})!",
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                      return; // exit early
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

                                    print(
                                        "💳 Payment Types Selected: $paymentTypes");
                                    print("📌 Mode Wise Amounts: $modeAmounts");

                                    // 6️⃣ Merge with existing values
                                    List<double> existingAdvanceAmount =
                                        widget.salesOrder.advanceAmount ?? [];
                                    List<List<String>> existingPaymentType =
                                        widget.salesOrder.advancePaymentType ??
                                            [];
                                    List<List<double>> existingModeWiseAmount =
                                        widget.salesOrder.modeWiseAmount ?? [];
                                    List<String> existingDateTime =
                                        widget.salesOrder.advanceDateTime ?? [];

                                    // ✅ Add new entry
                                    existingAdvanceAmount = [
                                      ...existingAdvanceAmount,
                                      totalEntered
                                    ];
                                    existingPaymentType = [
                                      ...existingPaymentType,
                                      paymentTypes
                                    ];
                                    existingModeWiseAmount = [
                                      ...existingModeWiseAmount,
                                      modeAmounts
                                    ];
                                    existingDateTime = [
                                      ...existingDateTime,
                                      DateTime.now().toIso8601String()
                                    ];

                                    // 7️⃣ Recalculate updated remaining balance
                                    final updatedAlreadyPaid =
                                        alreadyPaid + totalEntered;
                                    final updatedRemainingBalance =
                                        widget.salesOrder.totalAmount -
                                            updatedAlreadyPaid;
                                    print(
                                        "💰 Updated Remaining Balance: $updatedRemainingBalance");

                                    // 8️⃣ Build API payload
                                    Map<String, dynamic> requestBody = {
                                      "advanceAmount": existingAdvanceAmount,
                                      "advanceDateTime": existingDateTime,
                                      "advancePaymentType": existingPaymentType,
                                      "modeWiseAmount": existingModeWiseAmount,
                                      "balanceAmount": updatedRemainingBalance,
                                    };

                                    print(
                                        "📝 Request Body Built: $requestBody");

                                    Map<String, dynamic> patchPayload = {
                                      "data": requestBody,
                                      "saleOrderNo":
                                          widget.salesOrder.saleOrderNo,
                                      "type": "patchSaleOrder",
                                      "sync": "No",
                                      "edit": "No",
                                    };

                                    print(
                                        "📤 Final Payload Ready to Send → $patchPayload");

                                    // 9️⃣ Send via WebSocket
                                    await sendInvoiceDataToServer(patchPayload);
                                    Navigator.of(context).pop();
                                    print(
                                        "✅ Payload sent successfully via WebSocket");

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

                                    print(
                                        "🎉 Success: Advance Payment Updated");
                                  } catch (e, stack) {
                                    print("🔥 ERROR occurred: $e");
                                    print("📌 Stack Trace: $stack");
                                  } finally {
                                    if (mounted) {
                                      setState(() => isSubmitting = false);
                                      print(
                                          "🔄 [DEBUG] Reset isSubmitting = false");
                                    }
                                    print(
                                        "🔍 [DEBUG] ====== Advance Payment Process Ended ======");
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
                      )
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
                            child: AdvanceAmountKeyboardWidgetAll2(
                          controller: ctrl ?? TextEditingController(),
                          onChanged:
                              _updateBalance, // 👈 update balance when keys pressed
                        )),
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

  Widget _buildPaymentEntry(
      String method, TextEditingController controller, FocusNode focus) {
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
            flex: 2,
            child: Text(
              method,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: controller,
              focusNode: focus,
              readOnly: true,
              showCursor: true,
              onTap: () {
                print("✍️ $method field focused");
                ActiveField.activate(
                  ctrl: controller,
                  node: focus,
                  numeric: true,
                );
              },
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Enter $method',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                filled: true,
                fillColor: Colors.grey[100],
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

  Widget _buildMiniCard({
    required String title,
    required String value,
    required List<Color> gradient,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(2, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

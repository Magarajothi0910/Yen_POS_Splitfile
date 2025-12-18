import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/discount_service.dart'
    as globaldiscount;
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Widgets/cheque_details.dart';
import 'package:yenpos/Sale_order/Widgets/paymentDetail_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/top_message.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';

class OpPlaceOrderPaymentPrint extends StatefulWidget {
  final SalesOrderDisplay salesOrder;
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

  final CartProvider cartProvider;
  final String? path;
  final ApiServiceSalesOrderProvider apiprovider;
  final File? img1;
  final File? img2;
  final String customerType;
  final String? audioOrderId;
  final String? holdId;

  const OpPlaceOrderPaymentPrint({
    super.key,
    required this.salesOrder,
    required this.totalAmount,
    required this.totalAdvance,
    required this.deductedAmount,
    required this.customCharge,
    required this.holdBillId,
    required this.orderId,
    required this.discount,

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
  State<OpPlaceOrderPaymentPrint> createState() =>
      _OpPlaceOrderPaymentPrintState();
}

class _OpPlaceOrderPaymentPrintState extends State<OpPlaceOrderPaymentPrint> {
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
  String selectedChargeType = "Custom Charge";
  late salesInvoiceReceiptPrinter receiptPrinter;
  bool _isCompleteButtonEnabled = true; // default enabled
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
  final List<String> chargeTypes = [
    "Custom Charge",
    "Delivery Charge",
    "Packing Charge",
    "Service Charge",
  ];
  @override
  void initState() {
    super.initState();

    totalAmount = widget.totalAmount; // ✅ use widget.totalAmount instead of 0
    cashOptions.addAll(_generateCashOptions(widget.totalAmount));

    _originalAmount = widget.totalAmount;
    _upiAndCashAmount = widget.totalAmount;
    _balanceAmount = widget.totalAmount;

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
    _customChargeController.addListener(() {
      customCharge = double.tryParse(_customChargeController.text) ?? 0;
      _applyCustomCharge(_customChargeController.text);
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

      _cashAmount = cash.toInt();
      _upiAmount = upi.toInt();
      _cardAmount = card.toInt();
      _chequeAmount = cheque.toInt();

      final totalPaid = cash + upi + card + cheque;

      // Balance calculation
      _balanceAmount = totalAmount - totalPaid;

      // ✅ Always enabled unless overpaid
      if (totalPaid > totalAmount) {
        _isCompleteButtonEnabled = false;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Total payment exceeds total amount ₹${totalAmount.toStringAsFixed(0)}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        });
      } else {
        _isCompleteButtonEnabled = true;
      }

      // Optional: auto-detect main payment type
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
      customCharge = double.tryParse(_customChargeController.text) ?? 0;
      // Step 2: Continue with normal discount logic
      discount = double.tryParse(value) ?? 0;

      deductedAmount = (discount / 100) * _originalAmount;

      totalAmount = _originalAmount + customCharge - deductedAmount;

      if (discount > globaldiscount.globalDiscountPercentage) {
        // Don't clear, just mark for approval
        TopMessage.show(
          context,
          message: 'Discount exceeds allowed limit. Sending for approval.',
          backgroundColor: Colors.orangeAccent,
        );

        setState(() {
          selectedPaymentMethod = "Approval"; // 👈 Custom state trigger
        });
      }
      _updateBalance();
    });
  }

  void _applyCustomCharge(String value) {
    setState(() {
      customCharge = double.tryParse(value) ?? 0;

      // Prevent negative values
      if (customCharge < 0) {
        customCharge = 0;
        _customChargeController.text = "0";
        TopMessage.show(
          context,
          message: "Charge cannot be negative",
          backgroundColor: Colors.redAccent,
        );
      }

      // 🔥 Recalculate total (Original + Charge - Discount)
      totalAmount = _originalAmount + customCharge - deductedAmount;

      // Update balance after new total
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
                          // ================= DISCOUNT AMOUNT FIELD =================
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: _discountController,
                              readOnly: true,
                              enabled: !_isDiscountDisabled,
                              showCursor: !_isDiscountDisabled,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.percent,
                                  color: Colors.black,
                                ),
                                suffixText: deductedAmount > 0
                                    ? "- ₹${deductedAmount.round().toStringAsFixed(0)}"
                                    : null, // <-- Suffix shows deducted amount
                                suffixStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                filled: true,
                                fillColor: _isDiscountDisabled
                                    ? Colors.grey[200]
                                    : Colors.grey[50],
                                labelText: "Discount(%)",
                                labelStyle: TextStyle(
                                  color: _isDiscountDisabled
                                      ? Colors.grey
                                      : Colors.black,
                                ),
                                hintText: _isDiscountDisabled
                                    ? _getItemWiseDiscountText()
                                    : 'Enter Discount',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onTap: () {
                                if (!_isDiscountDisabled) {
                                  ActiveField.activate(
                                    context: context,
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
                          const SizedBox(width: 15),

                          // ================= CUSTOM CHARGE DROPDOWN =================
                          Expanded(
                            flex: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedChargeType,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 22,
                                  ),
                                  items: chargeTypes.map((value) {
                                    return DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    setState(() {
                                      selectedChargeType = newValue!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // ================= CUSTOM CHARGE AMOUNT FIELD =================
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _customChargeController,
                              readOnly: false,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.currency_rupee,
                                  color: Colors.black,
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                labelText: "Charge",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onTap: () {
                                ActiveField.activate(
                                  context: context,
                                  ctrl: _customChargeController,
                                  node: FocusNode(),
                                  numeric: true,
                                );
                              },
                              onChanged: _applyCustomCharge,
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

                  // 🔹 Left Section: Total/Balance/Buttons\
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildPremiumCardElegant(
                                title: "Total",
                                value: '₹${totalAmount.toStringAsFixed(0)}',
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
                                onPressed: _isCompleteButtonEnabled
                                    ? () async {
                                        Map<String, double> payments = {};
                                        if (_cashController.text.isNotEmpty) {
                                          payments["Cash"] =
                                              double.tryParse(
                                                _cashController.text,
                                              ) ??
                                              0.0;
                                        }
                                        if (_cardController.text.isNotEmpty) {
                                          payments["Card"] =
                                              double.tryParse(
                                                _cardController.text,
                                              ) ??
                                              0.0;
                                        }
                                        if (_upiController.text.isNotEmpty) {
                                          payments["UPI"] =
                                              double.tryParse(
                                                _upiController.text,
                                              ) ??
                                              0.0;
                                        }
                                        if (chequeAmountController
                                            .text
                                            .isNotEmpty) {
                                          payments["Cheque"] =
                                              double.tryParse(
                                                chequeAmountController.text,
                                              ) ??
                                              0.0;
                                        }
                                        Navigator.pop(context);
                                        if (selectedPaymentMethod == 'Cheque' ||
                                            selectedPaymentMethod ==
                                                'Approval') {
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
                                                selectedPaymentMethod ==
                                                        'Cheque'
                                                    ? "Cheque"
                                                    : "Discount", // label reason
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
                                                borderRadius:
                                                    BorderRadius.circular(15),
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                        foregroundColor:
                                                            Colors.red,
                                                        side: const BorderSide(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    await customerScreenProvider
                                                        .outletSaveOrder(
                                                          widget.salesOrder,

                                                          widget.totalAdvance,
                                                          widget.orderAmount,
                                                          discount,
                                                          deductedAmount,
                                                          totalAmount,
                                                          totalAmount,
                                                          widget.remark,

                                                          widget
                                                              .selectedStoreType,
                                                          context,
                                                          payments, // 👈 pass payments map
                                                          customCharge,
                                                          selectedChargeType,
                                                        );

                                                    // Clear UI and provider data

                                                    Navigator.pop(
                                                      context,
                                                    ); // Close dialog
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.blueAccent,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                  child: const Text('Confirm'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      }
                                    : null,
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
                                child: Text(
                                  selectedPaymentMethod == 'Cheque' ||
                                          selectedPaymentMethod == 'Approval'
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
                  const SizedBox(width: 12),
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
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yen_pos/Sale_order/Provider/cartProvider.dart';
import 'package:yen_pos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Sale_order/Provider/discount_service.dart'
    as globaldiscount;
import 'package:yen_pos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Sale_order/Widgets/cheque_details.dart';
import 'package:yen_pos/Sale_order/Widgets/paymentDetail_keybaord.dart';
import 'package:yen_pos/Sale_order/Widgets/printer_dialogue_configuration.dart';
import 'package:yen_pos/Sale_order/Widgets/top_message.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';

class PaymentInstance {
  final String paymentMethod;
  final String id;
  TextEditingController controller;
  FocusNode focusNode;

  PaymentInstance({
    required this.paymentMethod,
    required this.id,
    required this.controller,
    required this.focusNode,
  });
}

class PlaceOrderPaymentPrint extends StatefulWidget {
  final CartSelectionProvider cartSelectionProvider;
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

  const PlaceOrderPaymentPrint({
    super.key,
    required this.cartSelectionProvider,
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
  // List<String> selectedPayments = [];

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
  bool _isInitialSend = true;
  Map<String, dynamic> _lastSentData = {};
  final ScrollController _scrollController = ScrollController();

  late final List<TextEditingController> controllers;
  final FocusNode _customCashFocusNode = FocusNode();
  final FocusNode _customUpiFocusNode = FocusNode();
  final FocusNode _customCardFocusNode = FocusNode();
  String? selectedPayment; // Cash / Card / UPI / Cheque
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
  // Add these maps to store controllers for each payment instance
  final Map<String, TextEditingController> _cashControllers = {};
  final Map<String, TextEditingController> _upiControllers = {};
  final Map<String, TextEditingController> _cardControllers = {};
  final Map<String, TextEditingController> _chequeControllers = {};

  // Maps to store FocusNodes
  final Map<String, FocusNode> _cashFocusNodes = {};
  final Map<String, FocusNode> _upiFocusNodes = {};
  final Map<String, FocusNode> _cardFocusNodes = {};

  // Track payment instances with unique IDs
  List<PaymentInstance> selectedPayments = [];
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
  // Helper class to track payment instances

  // Generate unique ID for each payment instance
  String _generatePaymentId(String method) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000);
    return '${method}_${timestamp}_$random';
  }

  // Get controller for a specific payment instance
  TextEditingController _getControllerForPayment(PaymentInstance instance) {
    switch (instance.paymentMethod) {
      case 'Cash':
        return _cashControllers[instance.id] ?? TextEditingController();
      case 'UPI':
        return _upiControllers[instance.id] ?? TextEditingController();
      case 'Card':
        return _cardControllers[instance.id] ?? TextEditingController();
      case 'Cheque':
        return _chequeControllers[instance.id] ?? TextEditingController();
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
    } catch (e) {}
  }

  // Get focus node for a specific payment instance
  FocusNode _getFocusNodeForPayment(PaymentInstance instance) {
    switch (instance.paymentMethod) {
      case 'Cash':
        return _cashFocusNodes[instance.id] ?? FocusNode();
      case 'UPI':
        return _upiFocusNodes[instance.id] ?? FocusNode();
      case 'Card':
        return _cardFocusNodes[instance.id] ?? FocusNode();
      default:
        return FocusNode();
    }
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

  void _updateBalance() {
    setState(() {
      double totalPaid = 0;

      // Calculate total from all payment instances
      for (var payment in selectedPayments) {
        final amount = double.tryParse(payment.controller.text) ?? 0;
        totalPaid += amount;
      }

      // Balance calculation
      _balanceAmount = totalAmount - totalPaid;

      // Update button state
      _isCompleteButtonEnabled = totalPaid <= totalAmount;

      if (totalPaid > totalAmount) {
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
        selectedPaymentMethod = ""; // reset payment method
        return; // stop further discount application
      }

      // Step 2: Continue with normal discount logic
      discount = double.tryParse(value) ?? 0;
      deductedAmount = (discount / 100) * _originalAmount;
      totalAmount = _originalAmount + customCharge - deductedAmount.round();

      if (discount > globaldiscount.globalDiscountPercentage) {
        TopMessage.show(
          context,
          message: 'Discount exceeds allowed limit. Sending for approval.',
          backgroundColor: Colors.orangeAccent,
        );
        selectedPaymentMethod = "Approval"; // 👈 Custom state trigger
      } else {
        // ✅ Reset payment method when discount is valid
        selectedPaymentMethod = "";
      }

      _updateBalance();
    });
  }

  double getAdvancePercentageFromHive() {
    final box = HiveManager.advancePercent;

    if (box.isEmpty) {
      return 0;
    }

    final data = box.getAt(0);

    final advancePercent = (data['percentage'] ?? 0).toDouble();

    return advancePercent;
  }

  double calculateRequiredAdvance(double totalAmount) {
    final percentage = getAdvancePercentageFromHive();

    final requiredAdvance = (totalAmount * percentage) / 100;

    return requiredAdvance.round().toDouble();
  }

  // 👇 Add this
  bool _showChequeDetails = false;

  // Get payment method icon
  IconData _getPaymentMethodIconData(String method) {
    switch (method) {
      case "Cash":
        return Icons.money;
      case "Card":
        return Icons.credit_card;
      case "UPI":
        return Icons.qr_code;
      case "Cheque":
        return Icons.receipt_long;
      default:
        return Icons.payment;
    }
  }

  // Get payment method color
  Color _getPaymentMethodColor(String method) {
    switch (method) {
      case "Cash":
        return Colors.green;
      case "Card":
        return Colors.blue;
      case "UPI":
        return Colors.purple;
      case "Cheque":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Get total paid amount from all payment instances
  double getTotalPaidAmount() {
    double totalPaid = 0;

    for (var payment in selectedPayments) {
      // Get the correct controller for this payment instance
      TextEditingController controller;
      switch (payment.paymentMethod) {
        case "Cash":
          controller = _cashControllers[payment.id] ?? TextEditingController();
          break;
        case "UPI":
          controller = _upiControllers[payment.id] ?? TextEditingController();
          break;
        case "Card":
          controller = _cardControllers[payment.id] ?? TextEditingController();
          break;
        case "Cheque":
          controller =
              _chequeControllers[payment.id] ?? TextEditingController();
          break;
        default:
          controller = TextEditingController();
      }

      final amount = double.tryParse(controller.text) ?? 0;
      totalPaid += amount;
    }

    return totalPaid;
  }

  Map<String, double> _getAllPayments() {
    final Map<String, double> payments = {};
    final methodCount = <String, int>{};

    for (var payment in selectedPayments) {
      // Get the correct controller for this payment instance
      TextEditingController controller;
      switch (payment.paymentMethod) {
        case "Cash":
          controller = _cashControllers[payment.id] ?? TextEditingController();
          break;
        case "UPI":
          controller = _upiControllers[payment.id] ?? TextEditingController();
          break;
        case "Card":
          controller = _cardControllers[payment.id] ?? TextEditingController();
          break;
        case "Cheque":
          controller =
              _chequeControllers[payment.id] ?? TextEditingController();
          break;
        default:
          controller = TextEditingController();
      }

      final amount = double.tryParse(controller.text) ?? 0;
      if (amount > 0) {
        final method = payment.paymentMethod;
        methodCount[method] = (methodCount[method] ?? 0) + 1;
        final count = methodCount[method]!;
        final key = "$method $count";
        payments[key] = amount;
      }
    }

    return payments;
  }

  @override
  Widget build(BuildContext context) {
    double padding = MediaQuery.of(context).size.width * 0.04;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    final requiredAdvanceAmount = calculateRequiredAdvance(totalAmount);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT: Title
                  const Text(
                    "Select Payment Method",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                      ),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Minimum Amount to Pay",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "₹ ${requiredAdvanceAmount.round()}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message:
                              "This is the minimum advance payment required for this order.",
                          child: const Icon(
                            Icons.info_outline,
                            color: Colors.blueGrey,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ===== Top Section =====
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 🔹 DISCOUNT FIELD
                  // 🔹 Payment Section Title
                  SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Container(
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
                                    context: context,
                                    ctrl: _discountController,
                                    node: FocusNode(),
                                    numeric: true,
                                    fieldType: "discount",
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
                                ? "- ₹${deductedAmount.toStringAsFixed(0)}"
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
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          hint: Text(
                            "Select Payment Method",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          dropdownColor: Colors.white,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: "Cash",
                              child: Row(
                                children: [
                                  Icon(Icons.money, color: Colors.green),
                                  SizedBox(width: 10),
                                  Text("Cash"),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: "Card",
                              child: Row(
                                children: [
                                  Icon(Icons.credit_card, color: Colors.blue),
                                  SizedBox(width: 10),
                                  Text("Card"),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: "UPI",
                              child: Row(
                                children: [
                                  Icon(Icons.qr_code, color: Colors.purple),
                                  SizedBox(width: 10),
                                  Text("UPI"),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: "Cheque",
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 10),
                                  Text("Cheque"),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            setState(() {
                              // Generate unique ID for this payment instance
                              final paymentId = _generatePaymentId(value);

                              // Create new controller for this instance
                              switch (value) {
                                case "Cash":
                                  _cashControllers[paymentId] =
                                      TextEditingController();
                                  _cashFocusNodes[paymentId] = FocusNode();
                                  break;
                                case "UPI":
                                  _upiControllers[paymentId] =
                                      TextEditingController();
                                  _upiFocusNodes[paymentId] = FocusNode();
                                  break;
                                case "Card":
                                  _cardControllers[paymentId] =
                                      TextEditingController();
                                  _cardFocusNodes[paymentId] = FocusNode();
                                  break;
                                case "Cheque":
                                  _chequeControllers[paymentId] =
                                      TextEditingController();
                                  break;
                              }

                              // Add to selected payments with unique ID
                              selectedPayments.add(
                                PaymentInstance(
                                  paymentMethod: value,
                                  id: paymentId,
                                  controller: _getControllerForPayment(
                                    PaymentInstance(
                                      paymentMethod: value,
                                      id: paymentId,
                                      controller: TextEditingController(),
                                      focusNode: FocusNode(),
                                    ),
                                  ),
                                  focusNode: _getFocusNodeForPayment(
                                    PaymentInstance(
                                      paymentMethod: value,
                                      id: paymentId,
                                      controller: TextEditingController(),
                                      focusNode: FocusNode(),
                                    ),
                                  ),
                                ),
                              );

                              // Add listener to update balance when amount changes
                              final controller = _getControllerForPayment(
                                PaymentInstance(
                                  paymentMethod: value,
                                  id: paymentId,
                                  controller: TextEditingController(),
                                  focusNode: FocusNode(),
                                ),
                              );

                              controller.addListener(_updateBalance);

                              if (value == "Cheque") {
                                _showChequeDetails = true;
                                // Calculate suggested amount for cheque
                                _updateBalance();
                                // Scroll to show cheque details
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _scrollController.animateTo(
                                    _scrollController.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                });
                              }

                              _updateBalance();
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                ],
              ),
            ),

            const SizedBox(height: 8),
            // ===== Middle Section =====
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Builder(
                  builder: (context) {
                    List<Widget> rows = [];

                    // Group payments by 2 per row
                    for (int i = 0; i < selectedPayments.length; i += 2) {
                      final firstPayment = selectedPayments[i];
                      final secondPayment = i + 1 < selectedPayments.length
                          ? selectedPayments[i + 1]
                          : null;

                      List<Widget> rowChildren = [];

                      // First payment
                      rowChildren.add(
                        Expanded(
                          child: _buildPaymentWidget(
                            firstPayment,
                            showButtonOnly: true,
                          ),
                        ),
                      );

                      // Spacer
                      rowChildren.add(const SizedBox(width: 12));

                      // Second payment or empty space
                      if (secondPayment != null) {
                        rowChildren.add(
                          Expanded(
                            child: _buildPaymentWidget(
                              secondPayment,
                              showButtonOnly: true,
                            ),
                          ),
                        );
                      } else {
                        rowChildren.add(const Expanded(child: SizedBox()));
                      }

                      rows.add(Row(children: rowChildren));

                      // If first payment is cheque, show details in next row
                      if (firstPayment.paymentMethod == "Cheque" &&
                          _showChequeDetails) {
                        rows.add(
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildPaymentWidget(
                              firstPayment,
                              showButtonOnly: false,
                            ),
                          ),
                        );
                      }

                      // If second payment is cheque, show details in next row
                      if (secondPayment?.paymentMethod == "Cheque" &&
                          _showChequeDetails) {
                        rows.add(
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildPaymentWidget(
                              secondPayment!,
                              showButtonOnly: false,
                            ),
                          ),
                        );
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rows,
                    );
                  },
                ),
              ),
            ),
            // ===== Footer Section =====
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
                                  Colors.blue.shade400,
                                  Colors.blue.shade700,
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
                                        // Debug: Print all payment instances
                                        print(
                                          "=== DEBUG PAYMENT INSTANCES ===",
                                        );
                                        for (var payment in selectedPayments) {
                                          TextEditingController controller;
                                          switch (payment.paymentMethod) {
                                            case "Cash":
                                              controller =
                                                  _cashControllers[payment
                                                      .id] ??
                                                  TextEditingController();
                                              break;
                                            case "UPI":
                                              controller =
                                                  _upiControllers[payment.id] ??
                                                  TextEditingController();
                                              break;
                                            case "Card":
                                              controller =
                                                  _cardControllers[payment
                                                      .id] ??
                                                  TextEditingController();
                                              break;
                                            case "Cheque":
                                              controller =
                                                  _chequeControllers[payment
                                                      .id] ??
                                                  TextEditingController();
                                              break;
                                            default:
                                              controller =
                                                  TextEditingController();
                                          }
                                          print(
                                            "${payment.paymentMethod} (${payment.id}): ${controller.text}",
                                          );
                                        }

                                        final payments = _getAllPayments();
                                        final totalPaid = getTotalPaidAmount();
                                        print("Total Paid: $totalPaid");
                                        print("Payments Map: $payments");

                                        // 🔴 ADVANCE VALIDATION LOGIC
                                        final requiredAdvance =
                                            calculateRequiredAdvance(
                                              totalAmount,
                                            );

                                        // ❌ ZERO PAYMENT BLOCK
                                        if (totalPaid <= 0) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Payment amount cannot be zero',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        // ❌ MINIMUM ADVANCE BLOCK
                                        if (totalPaid < requiredAdvance) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Minimum ₹${requiredAdvance.round()} payment required',
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        // ✅ CHEQUE / APPROVAL FLOW
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

                                                widget.audioOrderId,
                                                widget.holdId,
                                                selectedPaymentMethod ==
                                                        'Cheque'
                                                    ? "Cheque"
                                                    : "Discount",
                                                context,
                                                payments,
                                              );
                                          return;
                                        }

                                        showDialog(
                                          barrierDismissible: false,
                                          context: context,
                                          builder: (context) {
                                            final totalPaid =
                                                getTotalPaidAmount();
                                            final requiredAdvance =
                                                calculateRequiredAdvance(
                                                  totalAmount,
                                                );

                                            return Dialog(
                                              backgroundColor:
                                                  Colors.transparent,
                                              insetPadding:
                                                  const EdgeInsets.all(16),
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  maxWidth: 380,
                                                  maxHeight:
                                                      MediaQuery.of(
                                                        context,
                                                      ).size.height *
                                                      0.85,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.15),
                                                      blurRadius: 32,
                                                      offset: const Offset(
                                                        0,
                                                        12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // 🔷 PREMIUM HEADER
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 24,
                                                            vertical: 20,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                              colors: [
                                                                Colors
                                                                    .blue
                                                                    .shade700,
                                                                Colors
                                                                    .indigo
                                                                    .shade600,
                                                              ],
                                                            ),
                                                        borderRadius:
                                                            const BorderRadius.only(
                                                              topLeft:
                                                                  Radius.circular(
                                                                    24,
                                                                  ),
                                                              topRight:
                                                                  Radius.circular(
                                                                    24,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 44,
                                                            height: 44,
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .white
                                                                      .withOpacity(
                                                                        0.2,
                                                                      ),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                            child: const Icon(
                                                              Icons
                                                                  .verified_outlined,
                                                              color:
                                                                  Colors.white,
                                                              size: 24,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                const Text(
                                                                  "Confirm Payment",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        20,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Text(
                                                                  "Review and confirm your payment",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .white
                                                                        .withOpacity(
                                                                          0.85,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    // Scrollable content area with fixed height
                                                    Flexible(
                                                      child: SingleChildScrollView(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 20,
                                                            ),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            // 💰 PAYMENT AMOUNT CARD - CHANGED TO BLUE
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        24,
                                                                  ),
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      20,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    begin: Alignment
                                                                        .topLeft,
                                                                    end: Alignment
                                                                        .bottomRight,
                                                                    colors: [
                                                                      Colors
                                                                          .blue
                                                                          .shade50,
                                                                      Colors
                                                                          .lightBlue
                                                                          .shade50,
                                                                    ],
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        18,
                                                                      ),
                                                                  border: Border.all(
                                                                    color: Colors
                                                                        .blue
                                                                        .shade100,
                                                                    width: 1.5,
                                                                  ),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: Colors
                                                                          .blue
                                                                          .withOpacity(
                                                                            0.08,
                                                                          ),
                                                                      blurRadius:
                                                                          16,
                                                                      offset:
                                                                          const Offset(
                                                                            0,
                                                                            6,
                                                                          ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: Column(
                                                                  children: [
                                                                    Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .account_balance_wallet_rounded,
                                                                          color: Colors
                                                                              .blue
                                                                              .shade600,
                                                                          size:
                                                                              24,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              10,
                                                                        ),
                                                                        Text(
                                                                          "PAYMENT AMOUNT",
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                14,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            color:
                                                                                Colors.blue.shade700,
                                                                            letterSpacing:
                                                                                1.2,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          12,
                                                                    ),
                                                                    RichText(
                                                                      text: TextSpan(
                                                                        children: [
                                                                          TextSpan(
                                                                            text:
                                                                                "₹ ",
                                                                            style: TextStyle(
                                                                              fontSize: 24,
                                                                              fontWeight: FontWeight.w500,
                                                                              color: Colors.blue.shade600,
                                                                            ),
                                                                          ),
                                                                          TextSpan(
                                                                            text: totalPaid.toStringAsFixed(
                                                                              0,
                                                                            ),
                                                                            style: TextStyle(
                                                                              fontSize: 42,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Colors.blue.shade700,
                                                                              height: 1.1,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 8,
                                                                    ),
                                                                    Text(
                                                                      "Amount entered for payment",
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        color: Colors
                                                                            .blue
                                                                            .shade600,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),

                                                            const SizedBox(
                                                              height: 16,
                                                            ),

                                                            // 📊 ADVANCE REQUIREMENT INFO
                                                            if (totalPaid <
                                                                requiredAdvance) ...[
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          24,
                                                                    ),
                                                                child: Container(
                                                                  padding:
                                                                      const EdgeInsets.all(
                                                                        16,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .orange
                                                                        .shade50,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          16,
                                                                        ),
                                                                    border: Border.all(
                                                                      color: Colors
                                                                          .orange
                                                                          .shade200,
                                                                    ),
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons
                                                                            .info_outline_rounded,
                                                                        color: Colors
                                                                            .orange
                                                                            .shade700,
                                                                        size:
                                                                            22,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            12,
                                                                      ),
                                                                      Expanded(
                                                                        child: Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Text(
                                                                              "Minimum Advance Required",
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: FontWeight.w600,
                                                                                color: Colors.orange.shade800,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(
                                                                              height: 4,
                                                                            ),
                                                                            Text(
                                                                              "₹${requiredAdvance.toStringAsFixed(0)} (${getAdvancePercentageFromHive()}%)",
                                                                              style: TextStyle(
                                                                                fontSize: 16,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: Colors.orange.shade900,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                            ],

                                                            // 🔘 PAYMENT METHODS SUMMARY
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        24,
                                                                  ),
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      16,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade50,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        16,
                                                                      ),
                                                                ),
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    const Text(
                                                                      "Payment Methods",
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        color: Colors
                                                                            .grey,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          10,
                                                                    ),
                                                                    Wrap(
                                                                      spacing:
                                                                          10,
                                                                      runSpacing:
                                                                          10,
                                                                      children: payments.entries.map((
                                                                        entry,
                                                                      ) {
                                                                        final method = entry
                                                                            .key
                                                                            .split(
                                                                              '_',
                                                                            )[0];
                                                                        final icon =
                                                                            _getPaymentMethodIconData(
                                                                              method,
                                                                            );
                                                                        final color =
                                                                            _getPaymentMethodColor(
                                                                              method,
                                                                            );
                                                                        return Container(
                                                                          padding: const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                14,
                                                                            vertical:
                                                                                8,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                Colors.white,
                                                                            borderRadius: BorderRadius.circular(
                                                                              12,
                                                                            ),
                                                                            border: Border.all(
                                                                              color: Colors.grey.shade200,
                                                                            ),
                                                                            boxShadow: [
                                                                              BoxShadow(
                                                                                color: Colors.black.withOpacity(
                                                                                  0.04,
                                                                                ),
                                                                                blurRadius: 8,
                                                                                offset: const Offset(
                                                                                  0,
                                                                                  2,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          child: Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            children: [
                                                                              Icon(
                                                                                icon,
                                                                                color: color,
                                                                                size: 18,
                                                                              ),
                                                                              const SizedBox(
                                                                                width: 8,
                                                                              ),
                                                                              Text(
                                                                                "${method}: ",
                                                                                style: const TextStyle(
                                                                                  fontSize: 14,
                                                                                  fontWeight: FontWeight.w500,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                "₹${entry.value.toStringAsFixed(0)}",
                                                                                style: const TextStyle(
                                                                                  fontSize: 14,
                                                                                  fontWeight: FontWeight.bold,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        );
                                                                      }).toList(),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),

                                                            const SizedBox(
                                                              height: 20,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),

                                                    // 🎯 ACTION BUTTONS - Fixed at bottom
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 24,
                                                            vertical: 20,
                                                          ),
                                                      child: Column(
                                                        children: [
                                                          Row(
                                                            children: [
                                                              // Cancel Button
                                                              Expanded(
                                                                child: Container(
                                                                  height: 52,
                                                                  decoration: BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          14,
                                                                        ),
                                                                    gradient: LinearGradient(
                                                                      colors: [
                                                                        Colors
                                                                            .grey
                                                                            .shade100,
                                                                        Colors
                                                                            .grey
                                                                            .shade200,
                                                                      ],
                                                                    ),
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: Colors
                                                                            .black
                                                                            .withOpacity(
                                                                              0.05,
                                                                            ),
                                                                        blurRadius:
                                                                            8,
                                                                        offset:
                                                                            const Offset(
                                                                              0,
                                                                              4,
                                                                            ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: Material(
                                                                    color: Colors
                                                                        .transparent,
                                                                    child: InkWell(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            14,
                                                                          ),
                                                                      onTap: () =>
                                                                          Navigator.pop(
                                                                            context,
                                                                          ),
                                                                      child: Center(
                                                                        child: Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.center,
                                                                          children: [
                                                                            Text(
                                                                              "Cancel",
                                                                              style: TextStyle(
                                                                                fontSize: 15,
                                                                                fontWeight: FontWeight.w600,
                                                                                color: Colors.grey.shade700,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 16,
                                                              ),

                                                              // Confirm Button - BLUE
                                                              Expanded(
                                                                child: Container(
                                                                  height: 52,
                                                                  decoration: BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          14,
                                                                        ),
                                                                    gradient: LinearGradient(
                                                                      begin: Alignment
                                                                          .topLeft,
                                                                      end: Alignment
                                                                          .bottomRight,
                                                                      colors: [
                                                                        Colors
                                                                            .blue
                                                                            .shade600,
                                                                        Colors
                                                                            .blue
                                                                            .shade800,
                                                                      ],
                                                                    ),
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: Colors
                                                                            .blue
                                                                            .shade400
                                                                            .withOpacity(
                                                                              0.4,
                                                                            ),
                                                                        blurRadius:
                                                                            12,
                                                                        offset:
                                                                            const Offset(
                                                                              0,
                                                                              6,
                                                                            ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: Material(
                                                                    color: Colors
                                                                        .transparent,
                                                                    child: InkWell(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            14,
                                                                          ),
                                                                      onTap: () async {
                                                                        // ✅ Show processing loading
                                                                        showDialog(
                                                                          context:
                                                                              context,
                                                                          barrierDismissible:
                                                                              false,
                                                                          builder:
                                                                              (
                                                                                context,
                                                                              ) => const Center(
                                                                                child: CircularProgressIndicator(),
                                                                              ),
                                                                        );

                                                                        try {
                                                                          // Order save செய்ய
                                                                          await customerScreenProvider.saveOrder(
                                                                            cartProvider,
                                                                            widget.cartSelectionProvider,
                                                                            widget.totalAdvance,
                                                                            widget.orderAmount,
                                                                            discount,
                                                                            deductedAmount,
                                                                            totalAmount,
                                                                            widget.remark,
                                                                            widget.path,
                                                                            widget.apiprovider,
                                                                            widget.audioOrderId,
                                                                            widget.holdId,
                                                                            widget.selectedStoreType,
                                                                            context,
                                                                            payments,
                                                                          );

                                                                          // Close processing loading
                                                                          Navigator.pop(
                                                                            context,
                                                                          );
                                                                        } catch (
                                                                          e
                                                                        ) {
                                                                          Navigator.pop(
                                                                            context,
                                                                          ); // Close loading if error
                                                                          ScaffoldMessenger.of(
                                                                            context,
                                                                          ).showSnackBar(
                                                                            SnackBar(
                                                                              content: Text(
                                                                                'Error: $e',
                                                                              ),
                                                                              backgroundColor: Colors.red,
                                                                            ),
                                                                          );
                                                                        }
                                                                      },
                                                                      child: const Center(
                                                                        child: Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.center,
                                                                          children: [
                                                                            Text(
                                                                              "Confirm Payment",
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: FontWeight.w600,
                                                                                color: Colors.white,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),

                                                          const SizedBox(
                                                            height: 16,
                                                          ),

                                                          // ℹ️ FOOTER NOTE
                                                          Text(
                                                            "Payment once confirmed cannot be undone",
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey
                                                                  .shade500,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
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

  Widget _buildPaymentWidget(
    PaymentInstance paymentInstance, {
    bool showButtonOnly = true,
  }) {
    // Get the correct controller for this payment instance
    TextEditingController controller;
    switch (paymentInstance.paymentMethod) {
      case "Cash":
        controller =
            _cashControllers[paymentInstance.id] ?? TextEditingController();
        break;
      case "UPI":
        controller =
            _upiControllers[paymentInstance.id] ?? TextEditingController();
        break;
      case "Card":
        controller =
            _cardControllers[paymentInstance.id] ?? TextEditingController();
        break;
      case "Cheque":
        controller =
            _chequeControllers[paymentInstance.id] ?? TextEditingController();
        break;
      default:
        controller = TextEditingController();
    }

    // Get the correct focus node
    FocusNode focusNode;
    switch (paymentInstance.paymentMethod) {
      case "Cash":
        focusNode = _cashFocusNodes[paymentInstance.id] ?? FocusNode();
        break;
      case "UPI":
        focusNode = _upiFocusNodes[paymentInstance.id] ?? FocusNode();
        break;
      case "Card":
        focusNode = _cardFocusNodes[paymentInstance.id] ?? FocusNode();
        break;
      default:
        focusNode = FocusNode();
    }

    // Calculate suggested amount for this payment instance
    String getSuggestedAmount() {
      double totalPaid = 0;

      // Calculate total from all payment instances except current one
      for (var payment in selectedPayments) {
        if (payment.id != paymentInstance.id) {
          // Get controller for other payment
          TextEditingController otherController;
          switch (payment.paymentMethod) {
            case "Cash":
              otherController =
                  _cashControllers[payment.id] ?? TextEditingController();
              break;
            case "UPI":
              otherController =
                  _upiControllers[payment.id] ?? TextEditingController();
              break;
            case "Card":
              otherController =
                  _cardControllers[payment.id] ?? TextEditingController();
              break;
            case "Cheque":
              otherController =
                  _chequeControllers[payment.id] ?? TextEditingController();
              break;
            default:
              otherController = TextEditingController();
          }

          final amount = double.tryParse(otherController.text) ?? 0;
          totalPaid += amount;
        }
      }

      final remaining = totalAmount - totalPaid;

      // If current field is empty and there's remaining amount, suggest it
      if (controller.text.isEmpty && remaining > 0) {
        return remaining.toStringAsFixed(0);
      }

      return "0";
    }

    Widget content;

    switch (paymentInstance.paymentMethod) {
      case "Cash":
        content = Container(
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
                  "Cash",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  controller.text = getSuggestedAmount();
                  _updateBalance();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                    getSuggestedAmount(),
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
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: true,
                  showCursor: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    hintText: 'Enter Cash',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () {
                    ActiveField.activate(
                      context: context,
                      ctrl: controller,
                      node: focusNode,
                      numeric: true,
                    );
                  },
                  onChanged: (_) => _updateBalance(),
                ),
              ),
            ],
          ),
        );
        break;

      case "Card":
        final stateProvider = Provider.of<SalesInvoiceState>(
          context,
          listen: false,
        );
        bool isCardPaid = stateProvider.isCardPaid;

        content = Container(
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
                  "Card",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  controller.text = getSuggestedAmount();
                  _updateBalance();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                    getSuggestedAmount(),
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
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: true,
                  showCursor: true,
                  enabled: !isCardPaid,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: isCardPaid ? Colors.grey[200] : Colors.grey[50],
                    hintText: 'Enter Card',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () {
                    if (!isCardPaid) {
                      ActiveField.activate(
                        context: context,
                        ctrl: controller,
                        node: focusNode,
                        numeric: true,
                      );
                    }
                  },
                  onChanged: (_) => _updateBalance(),
                ),
              ),
              Consumer<RazorpayQRProvider>(
                builder: (context, qrProvider, _) {
                  return IconButton(
                    icon: Icon(
                      Icons.credit_card,
                      color: isCardPaid ? Colors.grey : Colors.blue,
                    ),
                    onPressed: _isCompleteButtonEnabled && !isCardPaid
                        ? () {
                            final val = controller.text;
                            final amt = double.tryParse(val);
                            if (val.isNotEmpty && amt != null && amt > 0) {
                              _handleCardPayment();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter valid Card amount'),
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
        break;

      case "UPI":
        final stateProvider = Provider.of<SalesInvoiceState>(
          context,
          listen: false,
        );
        bool isUpiPaid = stateProvider.isUpiPaid;

        content = Container(
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
                  "UPI",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  controller.text = getSuggestedAmount();
                  _updateBalance();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                    getSuggestedAmount(),
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
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: true,
                  showCursor: true,
                  enabled: !isUpiPaid,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: isUpiPaid ? Colors.grey[200] : Colors.grey[50],
                    hintText: 'Enter UPI',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onTap: () {
                    if (!isUpiPaid) {
                      ActiveField.activate(
                        context: context,
                        ctrl: controller,
                        node: focusNode,
                        numeric: true,
                      );
                    }
                  },
                  onChanged: (_) => _updateBalance(),
                ),
              ),
              Consumer<RazorpayQRProvider>(
                builder: (context, qrProvider, _) {
                  return IconButton(
                    icon: Icon(
                      Icons.qr_code,
                      color: isUpiPaid ? Colors.grey : Colors.blue,
                    ),
                    onPressed: _isCompleteButtonEnabled && !isUpiPaid
                        ? () {
                            final val = controller.text;
                            final amt = double.tryParse(val);
                            if (val.isNotEmpty && amt != null && amt > 0) {
                              _showUpiQrDialog(
                                amt,
                                onSuccess: () {
                                  Provider.of<SalesInvoiceState>(
                                    context,
                                    listen: false,
                                  ).updateIsUpiPaid(true);
                                  _updateBalance();
                                },
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter valid UPI amount'),
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
        break;

      case "Cheque":
        if (showButtonOnly) {
          content = GestureDetector(
            onTap: () {
              setState(() {
                _showChequeDetails = !_showChequeDetails;
                _isChequeSelected = _showChequeDetails;
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Cheque",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    getSuggestedAmount(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          content = Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ChequeDetails(
              chequeNumberController: chequeNumberController,
              chequeAmountController: controller,
              chequeNameController: chequeNameController,
              chequeDateController: chequeDateController,
              chequeNumberFocus: _chequeNumberFocus,
              chequeAmountFocus: _chequeAmountFocus,
              chequeNameFocus: _chequeNameFocus,
              chequeDateFocus: _chequeDateFocus,
              onFocusChanged: (index) {},
            ),
          );
        }
        break;

      default:
        content = const SizedBox.shrink();
    }

    return Stack(
      children: [
        content,
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: () {
              setState(() {
                // Remove from selected payments
                selectedPayments.removeWhere((p) => p.id == paymentInstance.id);

                // Clean up controllers and focus nodes
                switch (paymentInstance.paymentMethod) {
                  case "Cash":
                    _cashControllers.remove(paymentInstance.id);
                    _cashFocusNodes.remove(paymentInstance.id);
                    break;
                  case "UPI":
                    _upiControllers.remove(paymentInstance.id);
                    _upiFocusNodes.remove(paymentInstance.id);
                    break;
                  case "Card":
                    _cardControllers.remove(paymentInstance.id);
                    _cardFocusNodes.remove(paymentInstance.id);
                    break;
                  case "Cheque":
                    _chequeControllers.remove(paymentInstance.id);
                    if (selectedPayments
                        .where((p) => p.paymentMethod == "Cheque")
                        .isEmpty) {
                      _showChequeDetails = false;
                    }
                    break;
                }

                // Dispose resources
                controller.dispose();
                focusNode.dispose();

                _updateBalance();
              });
            },
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
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

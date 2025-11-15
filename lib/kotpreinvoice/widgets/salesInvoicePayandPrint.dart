import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
import '../providers/razorpay_qr_provider.dart';
import '../providers/upi_provider.dart';
import 'package:web_socket_channel/io.dart';
import '../components/globalAppbar.dart';
import '../models/fetchDiningTax.dart';
import 'package:yenpos/Global/globals_data.dart';
import '../../kotpreinvoice/providers/bottomNavprovider.dart';
import '../providers/login_provider.dart';
import '../providers/order_provider.dart';
import '../providers/printer_provider.dart';
import '../screens/table_screen.dart';
import '../services/invoiceReceipt.dart';
import '../services/invoiceReceipt%20utility.dart';
import 'bottomNav.dart';

// 🔔 ChangeNotifier to manage SalesInvoicePayAndPrint state
class SalesInvoicePayAndPrintState extends ChangeNotifier {
  double _balanceAmount = 0.0;
  bool _isSubmitting = false;
  double _paymentAmount = 0.0;
  String? _activePaymentMethod;
  String? _razorpayPaymentId;

  double get balanceAmount => _balanceAmount;
  bool get isSubmitting => _isSubmitting;
  double get paymentAmount => _paymentAmount;
  String? get activePaymentMethod => _activePaymentMethod;
  String? get razorpayPaymentId => _razorpayPaymentId;

  void updateBalance({
    required double totalAmount,
    required double payment,
    String? method,
  }) {
    _paymentAmount = payment;
    _balanceAmount = totalAmount - payment;
    _activePaymentMethod = method;

    debugPrint(
      "💰 Updated balance: $_balanceAmount, Payment: $_paymentAmount, Active Method: $_activePaymentMethod",
    );
    notifyListeners();
  }

  void setRazorpayPaymentId(String? paymentId) {
    _razorpayPaymentId = paymentId;
    debugPrint("💳 Razorpay Payment ID: $_razorpayPaymentId");
    notifyListeners();
  }

  void resetPaymentState(double totalAmount) {
    _paymentAmount = 0.0;
    _balanceAmount = totalAmount;
    _activePaymentMethod = null;
    _razorpayPaymentId = null;
    debugPrint("🔄 Reset payment state: Balance=$_balanceAmount");
    notifyListeners();
  }

  void selectPaymentOption(String method, double amount, double totalAmount) {
    _activePaymentMethod = method;
    _paymentAmount = amount;
    updateBalance(
      totalAmount: totalAmount,
      payment: _paymentAmount,
      method: method,
    );
  }

  void setSubmitting(bool value) {
    _isSubmitting = value;
    debugPrint("⏳ Submitting state: $_isSubmitting");
    notifyListeners();
  }
}

class SalesInvoicePayAndPrint extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>> items;
  final String branchName;
  final String deviceCode;

  const SalesInvoicePayAndPrint({
    Key? key,
    required this.totalAmount,
    required this.items,
    required this.branchName,
    required this.deviceCode,
  }) : super(key: key);

  @override
  State<SalesInvoicePayAndPrint> createState() =>
      _SalesInvoicePayAndPrintState();
}

class _SalesInvoicePayAndPrintState extends State<SalesInvoicePayAndPrint> {
  final TextEditingController _employeeNumberController =
      TextEditingController();
  final TextEditingController _customerNumberController =
      TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customChargeController = TextEditingController();
  final TextEditingController _customUpiController = TextEditingController();
  final TextEditingController _customCardController = TextEditingController();

  final Razorpay _razorpay = Razorpay();
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "https://yenerp.com",
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  IOWebSocketChannel? _channel;
  late SalesInvoicePayAndPrintState state;
  ScaffoldMessengerState? _scaffoldMessenger;
  Timer? _paymentStatusTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    debugPrint("📌 ScaffoldMessenger reference saved");
  }

  @override
  void initState() {
    super.initState();
    state = SalesInvoicePayAndPrintState();
    state.updateBalance(totalAmount: widget.totalAmount, payment: 0);

    if (widget.items.isNotEmpty && widget.items.first.containsKey('waiter')) {
      _employeeNumberController.text = widget.items.first['waiter'] ?? '';
    }
    if (widget.items.isNotEmpty &&
        widget.items.first.containsKey('customerPhoneNumber')) {
      _customerNumberController.text =
          widget.items.first['customerPhoneNumber'] ?? '';
    }

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    try {
      _channel = IOWebSocketChannel.connect('ws://$serverip:$port');
      debugPrint("📡 WebSocket connected to ws://$serverip:$port");
    } catch (e) {
      debugPrint("❌ Failed to connect to WebSocket: $e");
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Text('Failed to connect to server: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _employeeNumberController.dispose();
    _customerNumberController.dispose();
    _discountController.dispose();
    _customChargeController.dispose();
    _customUpiController.dispose();
    _customCardController.dispose();
    _paymentStatusTimer?.cancel();
    _razorpay.clear();
    if (_channel != null) {
      _channel!.sink.close();
      debugPrint("🗑️ WebSocket channel closed");
    } else {
      debugPrint("⚠️ WebSocket channel was not initialized, skipping close");
    }
    state.dispose();
    super.dispose();
  }

  String _getSuggestedAmount() {
    final upiAmount = double.tryParse(_customUpiController.text) ?? 0.0;
    final cardAmount = double.tryParse(_customCardController.text) ?? 0.0;
    final totalEntered = upiAmount + cardAmount;
    final remaining = widget.totalAmount - totalEntered;
    return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
  }

  void _showCustomSnackBar(String message, {bool isSuccess = false}) {
    if (mounted && _scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showUpiQrDialog(double amount) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RazorpayProvider>(context, listen: false).createQR(amount);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true, // ✅ allow dialog to close on back or X button
          onPopInvoked: (didPop) {
            if (mounted) {
              state.setSubmitting(false); // ✅ reset submitting when closed
            }
          },
          child: AlertDialog(
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
              child: Consumer<RazorpayProvider>(
                builder: (context, qrProvider, _) {
                  if (qrProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (qrProvider.errorMessage != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      state.setSubmitting(false); // ❌ reset if error
                    });
                    return Text(
                      qrProvider.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    );
                  } else if (qrProvider.paymentSuccess) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      state.setSubmitting(false); // ✅ reset on success
                    });
                    return const Center(
                      child: Text(
                        'Payment Successful',
                        style: TextStyle(fontSize: 20, color: Colors.green),
                      ),
                    );
                  } else if (qrProvider.qrImageUrl != null) {
                    return Column(
                      children: [
                        Image.network(
                          qrProvider.qrImageUrl!,
                          height: 535,
                          width: 300,
                          fit: BoxFit.fill,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
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
          ),
        );
      },
    ).then((_) {
      if (mounted)
        state.setSubmitting(false); // ✅ also reset if closed manually
    });
  }

  Future<void> _createOrderAndPay() async {
    final amount = double.tryParse(_customCardController.text);
    if (amount == null || amount <= 0) {
      debugPrint("⚠️ Invalid card amount entered: $_customCardController.text");
      if (mounted) {
        _showCustomSnackBar('Enter a valid card amount', isSuccess: false);
      }
      return;
    }

    debugPrint(
      "💳 Creating Razorpay order for ₹${amount.toStringAsFixed(2)}...",
    );

    try {
      state.setSubmitting(true); // 🔹 Start submitting
      final response = await _dio.post(
        "/fastapi/razorPay/create_order/?price=$amount",
      );
      debugPrint("📦 Order Response: ${response.data}");

      final orderData = response.data;
      if (orderData == null || orderData['id'] == null) {
        debugPrint("⚠️ Invalid order response: $orderData");
        if (mounted) {
          _showCustomSnackBar(
            'Invalid order data from server',
            isSuccess: false,
          );
        }
        state.setSubmitting(false); // 🔹 Stop submitting on invalid order
        return;
      }

      // Razorpay expects the amount in paise
      final razorpayAmount = (amount * 100).toInt();
      String customerNumber = _customerNumberController.text.trim();

      final options = {
        'key': 'rzp_live_RSsJoT9ThF9zms',
        'amount': razorpayAmount,
        'name': 'YenKOT Payments',
        'description': 'Card Payment for ₹${amount.toStringAsFixed(2)}',
        'order_id': orderData['id'],
        'prefill': {'contact': customerNumber, 'method': 'card'},
        'theme': {'color': '#2E86DE', 'backdrop_color': '#ffffff'},
      };

      debugPrint("🚀 Opening Razorpay with options: $options");

      try {
        _razorpay.open(options);
        debugPrint("✅ Razorpay window triggered successfully");
      } catch (e) {
        debugPrint("❌ Error opening Razorpay: $e");
        _showCustomSnackBar('Could not open payment window.', isSuccess: false);
        state.setSubmitting(false);
      }
    } on DioException catch (e) {
      debugPrint("💥 DioException while creating order: ${e.message}");
      if (mounted) {
        _showCustomSnackBar('Network issue creating order.', isSuccess: false);
      }
      state.setSubmitting(false); // 🔹 Stop submitting on Dio error
    } catch (e, stack) {
      debugPrint("💥 Unexpected error creating order: $e");
      debugPrint("🧾 Stacktrace: $stack");
      if (mounted) {
        _showCustomSnackBar(
          'Unexpected error while creating order.',
          isSuccess: false,
        );
      }
      state.setSubmitting(false); // 🔹 Stop submitting on unexpected error
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    state.setSubmitting(true); // 🔹 Start verifying payment
    final verifyData = {
      "order_id": response.orderId,
      "payment_id": response.paymentId,
      "signature": response.signature,
    };

    try {
      final result = await _dio.post(
        "https://yenerp.com/fastapi/razorPay/verify_payment",
        data: verifyData,
      );

      if (result.data["status"] == "success") {
        state.setRazorpayPaymentId(response.paymentId);
        if (mounted) {
          _showCustomSnackBar(
            'Amount received! Processing invoice...',
            isSuccess: true,
          );
          _processInvoiceAndPrint();
        }
        state.setSubmitting(false); // 🔹 Stop after success
      } else {
        if (mounted) {
          _showCustomSnackBar('Payment verification failed', isSuccess: false);
          state.setSubmitting(false); // 🔹 Stop after verification fail
        }
      }
    } catch (e) {
      debugPrint("❌ Error verifying payment: $e");
      if (mounted) {
        _showCustomSnackBar('Error verifying payment: $e', isSuccess: false);
        state.setSubmitting(false); // 🔹 Stop after error
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("❌ Payment failed: ${response.code} | ${response.message}");
    if (mounted) {
      _showCustomSnackBar(
        'Payment failed: ${response.message}',
        isSuccess: false,
      );
      state.setSubmitting(false);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("💳 External Wallet: ${response.walletName}");
    state.setSubmitting(false); // 🔹 Stop in case of external wallet
  }

  Future<String> generatehiveInvoiceId(String branchName) async {
    final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final currentDate1 = DateFormat('ddMMyy').format(DateTime.now());

    var invoiceBox = await Hive.openBox('invoices');

    String lastInvoiceDate = invoiceBox.get(
      'lastInvoiceDate',
      defaultValue: "",
    );
    int invoiceCounter = invoiceBox.get('invoiceCounter', defaultValue: 0);

    // Reset or increment counter
    if (lastInvoiceDate != currentDate || invoiceCounter == 0) {
      invoiceCounter = 1;
    } else {
      invoiceCounter++;
    }

    String hiveInvoiceId =
        'BM/$branchName $currentDate1 KOTINVOICE${invoiceCounter.toString().padLeft(3, '0')}';

    // Save back to Hive
    await invoiceBox.put('invoiceCounter', invoiceCounter);
    await invoiceBox.put('lastInvoiceDate', currentDate);

    return hiveInvoiceId;
  }

  void _sendInvoiceDataToServer() async {
    debugPrint("📦 Preparing and grouping invoice data for server...");

    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final loggedInUserName = loginProvider.loggedInUserName ?? "";
    debugPrint("👤 Logged in user: $loggedInUserName");

    double diningTaxPercentage = getTaxPercentage();

    Map<String, Map<String, dynamic>> groupedItems = {};
    List<Map<String, dynamic>> kotAddOns = [];

    for (var item in widget.items) {
      if (item.isEmpty) {
        debugPrint("⚠️ Skipping null or empty item: $item");
        continue;
      }

      for (int i = 0; i < (item['varianceName']?.length ?? 0); i++) {
        String variance = item['varianceName']?[i] ?? "";

        if (!groupedItems.containsKey(variance)) {
          groupedItems[variance] = {
            "varianceName": variance,
            "itemName": item['itemName']?[i] ?? "",
            "price": item['price']?[i] ?? 0.0,
            "qty": 0.0,
            "weight": 0.0,
            "amount": 0.0,
            "tax": diningTaxPercentage,
            "uom": item['uom']?[i] ?? "",
          };
        }

        groupedItems[variance]!['qty'] += item['qty']?[i] ?? 0.0;
        groupedItems[variance]!['weight'] += item['weight']?[i] ?? 0.0;
        groupedItems[variance]!['amount'] += item['amount']?[i] ?? 0.0;

        if (item.containsKey('config') && item['config'] != null) {
          for (var configItem in item['config']) {
            String varianceName = configItem['varianceName'] ?? "";
            bool isAlreadyAdded = kotAddOns.any(
              (existingConfig) =>
                  existingConfig["varianceName"] == varianceName &&
                  existingConfig["configQty"].toString() ==
                      configItem["configQty"].toString(),
            );

            if (!isAlreadyAdded) {
              kotAddOns.add({
                "varianceName": varianceName,
                "weight": configItem['weight'] ?? 0,
                "configQty": List.from(configItem['configQty'] ?? []),
                "addOn": List.from(configItem['addOn'] ?? []),
                "addOnPrice": List.from(configItem['addOnPrice'] ?? []),
                "addOnQuantities": List.from(
                  configItem['addOnQuantities'] ?? [],
                ),
                "variance": List.from(configItem['variance'] ?? []),
                "type": List.from(configItem['type'] ?? []),
                "remark": List.from(configItem['remark'] ?? []),
              });

              debugPrint(
                "➕ Config added: variance=$varianceName, addOns=${configItem['addOn']}, prices=${configItem['addOnPrice']}, qty=${configItem['configQty']}",
              );
            }
          }
        }
      }
    }

    final invoiceNo = await generatehiveInvoiceId(widget.branchName);

    Map<String, dynamic> invoiceData = {
      "type": "invoiceKOT",
      "invoiceNo": invoiceNo,
      "seathiveOrderId": widget.items.first['seathiveOrderId'] ?? "",
      "varianceName": groupedItems.keys.toList(),
      "itemName": groupedItems.values.map((item) => item['itemName']).toList(),
      "price": groupedItems.values.map((item) => item['price']).toList(),
      "qty": groupedItems.values.map((item) => item['qty']).toList(),
      "weight": groupedItems.values.map((item) => item['weight']).toList(),
      "amount": groupedItems.values.map((item) => item['amount']).toList(),
      "tax": groupedItems.values.map((item) => item['tax']).toList(),
      "uom": groupedItems.values.map((item) => item['uom']).toList(),
      "totalAmount": widget.totalAmount,
      // "paymentType": state.activePaymentMethod,
      "card": state.activePaymentMethod == 'Card' ? widget.totalAmount : 0,
      "upi": state.activePaymentMethod == 'UPI' ? widget.totalAmount : 0,
      "razorpayPaymentId": state.razorpayPaymentId ?? "",
      "invoiceDate": DateFormat('dd-MM-yyyy').format(DateTime.now()),
      "invoiceTime": DateFormat('hh:mm a').format(DateTime.now()),
      "deviceCode": widget.deviceCode,
      "branchId": branchId,
      "branchName": widget.branchName,
      "salesPersonId": loggedInUserName,
      "salesPersonName": createdBy,
      "employeeNumber": _employeeNumberController.text.trim(),
      "customerNumber": _customerNumberController.text.trim(),
      "sync": "No",
      "salesType": ordertype,
      "kotaddOns": kotAddOns,
    };

    debugPrint("✅ Final invoice data prepared: $invoiceData");

    if (invoiceData['totalAmount'] <= 0.0) {
      debugPrint(
        "❌ Invoice data is invalid, total amount is zero or negative.",
      );
      if (mounted && _scaffoldMessenger != null) {
        _showCustomSnackBar(
          "Invalid invoice data, total amount is zero.",
          isSuccess: false,
        );
      }
      return;
    }

    try {
      if (_channel == null) {
        await _initializeWebSocket();
        if (_channel == null) {
          throw Exception('Failed to establish WebSocket connection');
        }
      }

      final serializedData = jsonEncode(invoiceData);
      debugPrint("📤 Sending serialized data: $serializedData");
      _channel!.sink.add(serializedData);

      debugPrint("🎉 Invoice data sent to server successfully!");
    } catch (e) {
      debugPrint("⚠️ Error sending invoice data: $e");
      if (mounted && _scaffoldMessenger != null) {
        _showCustomSnackBar("Error sending invoice data: $e", isSuccess: false);
      }
    }
  }

  void _processInvoiceAndPrint() async {
    try {
      final printerProvider = Provider.of<PrinterProviderDine>(
        context,
        listen: false,
      );
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      var printerIp = printerProvider.getInvoicePrinterIp();

      if (printerIp == null) {
        await invoicePromptForPrinterIp(context);
        printerIp = printerProvider.getInvoicePrinterIp();
        if (printerIp == null) {
          debugPrint("❌ Printer IP not set.");
          if (mounted && _scaffoldMessenger != null) {
            _showCustomSnackBar("Printer IP not set!", isSuccess: false);
          }
          state.setSubmitting(false);
          return;
        }
      }

      debugPrint("🚀 Invoice items count: ${widget.items.length}");
      _sendInvoiceDataToServer();

      String seathiveOrderId = widget.items.first['seathiveOrderId'] ?? '';
      String table = widget.items.first['table'] ?? '';
      String seat = widget.items.first['seat'] ?? '';

      if (seathiveOrderId.isNotEmpty) {
        orderProvider.patchOrderStatusBySeathiveOrderId(
          seathiveOrderId,
          'invoiced',
        );
        debugPrint(
          "✅ Patched order status for sale seatHiveOrderId=$seathiveOrderId",
        );
      }

      await ReceiptPrinter(
        employeeNumberController: _employeeNumberController,
        seathiveOrderId: seathiveOrderId,
        customerNumberController: _customerNumberController,
        discountController: _discountController,
        customChargeController: _customChargeController,
        selectedPaymentOptionValue: '',
        context: context,
        customAmountController: _customUpiController.text.isNotEmpty
            ? _customUpiController
            : _customCardController,
        selectedPaymentOption: state.activePaymentMethod ?? 'UPI',
        items: widget.items,
        branchName: widget.branchName,
        table: table,
        seat: seat,
        printerProvider: printerProvider,
      ).printReceiptDetails();

      if (mounted && _scaffoldMessenger != null) {
        debugPrint("Receipt printed.....");
      } else {
        debugPrint("⚠️ Widget not mounted or ScaffoldMessenger not available");
      }

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Provider.of<BottomNavProviderKOT>(
            context,
            listen: false,
          ).updateIndex(0);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const TableScreen()),
            (route) => false,
          );
          debugPrint("📤 Navigated to TableScreen");
        }
      }
    } catch (e, st) {
      debugPrint("❌ Error during invoice printing: $e\n$st");
      if (mounted && _scaffoldMessenger != null) {
        _showCustomSnackBar("Error: $e", isSuccess: false);
      }
    } finally {
      if (mounted) {
        state.setSubmitting(false);
      }
    }
  }

  Widget _buildPaymentEntry(String method, TextEditingController controller) {
    return Consumer<SalesInvoicePayAndPrintState>(
      builder: (context, state, _) {
        final String suggestion = _getSuggestedAmount();
        final double suggestedValue = double.tryParse(suggestion) ?? 0.0;
        final bool isDisabled =
            state.activePaymentMethod != null &&
            state.activePaymentMethod != method;

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
                onTap: isDisabled
                    ? null
                    : () {
                        if (suggestedValue > 0) {
                          controller.text = suggestion;
                          state.selectPaymentOption(
                            method,
                            suggestedValue,
                            widget.totalAmount,
                          );
                          if (method == 'UPI') {
                            _customCardController.clear();
                          } else if (method == 'Card') {
                            _customUpiController.clear();
                          }
                        } else {
                          controller.clear();
                          state.resetPaymentState(widget.totalAmount);
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDisabled ? Colors.grey[300] : Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: isDisabled
                            ? Colors.grey.withOpacity(0.2)
                            : Colors.teal.withOpacity(0.3),
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
                    suggestion,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDisabled ? Colors.grey : Colors.teal,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: controller,
                  enabled: !isDisabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                  ],
                  onChanged: (val) {
                    if (val.isNotEmpty) {
                      state.selectPaymentOption(
                        method,
                        double.tryParse(val) ?? 0,
                        widget.totalAmount,
                      );
                      if (method == 'UPI') {
                        _customCardController.clear();
                      } else if (method == 'Card') {
                        _customUpiController.clear();
                      }
                    } else {
                      state.resetPaymentState(widget.totalAmount);
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: isDisabled ? Colors.grey[200] : Colors.grey[50],
                    hintText: 'Enter $method Amount',
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double padding = MediaQuery.of(context).size.width * 0.04;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider(create: (_) => RazorpayProvider()),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const GlobalAppBar(title: "KOT invoice payment", elevation: 0),
        body: Consumer<SalesInvoicePayAndPrintState>(
          builder: (context, state, _) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: ListView(
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(vertical: padding / 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[100]!, Colors.green[300]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey[400]!,
                          offset: const Offset(6, 6),
                          blurRadius: 12,
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-6, -6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            '₹${widget.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: padding / 2),
                    padding: EdgeInsets.all(padding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey[400]!,
                          offset: const Offset(6, 6),
                          blurRadius: 12,
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-6, -6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _employeeNumberController,
                                decoration: InputDecoration(
                                  labelText: "Employee",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                enabled: false,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            SizedBox(width: padding),
                            Expanded(
                              child: TextFormField(
                                controller: _customerNumberController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "Customer Number",
                                  labelStyle: const TextStyle(
                                    color: Colors.teal,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: BorderSide(
                                      color: Colors.teal[50] ?? Colors.teal,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: const BorderSide(
                                      color: Colors.teal,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a customer number';
                                  } else if (value.length < 10) {
                                    return 'Number must be 10 digits';
                                  } else if (value.length > 10) {
                                    return 'Number cannot exceed 10 digits';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildPaymentEntry("UPI", _customUpiController),
                  _buildPaymentEntry("Card", _customCardController),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: padding / 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey[400]!,
                          offset: const Offset(6, 6),
                          blurRadius: 12,
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-6, -6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        children: [
                          const Text(
                            "Balance Amount",
                            style: TextStyle(fontSize: 18),
                          ),
                          Text(
                            '₹${state.balanceAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 5),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[400],
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                (state.isSubmitting || state.balanceAmount > 0)
                                ? null
                                : () async {
                                    state.setSubmitting(true);

                                    final upiAmount =
                                        double.tryParse(
                                          _customUpiController.text,
                                        ) ??
                                        0.0;
                                    final cardAmount =
                                        double.tryParse(
                                          _customCardController.text,
                                        ) ??
                                        0.0;
                                    final totalEntered = upiAmount + cardAmount;

                                    // ✅ Validate entered amount
                                    if (totalEntered != widget.totalAmount) {
                                      if (mounted &&
                                          _scaffoldMessenger != null) {
                                        _showCustomSnackBar(
                                          "Entered amount must equal total amount.",
                                          isSuccess: false,
                                        );
                                      }
                                      state.setSubmitting(false);
                                      return;
                                    }

                                    // ✅ Validate Invoice Printer IP
                                    final printerProvider =
                                        Provider.of<PrinterProviderDine>(
                                          context,
                                          listen: false,
                                        );

                                    var printerIp = printerProvider
                                        .getInvoicePrinterIp();

                                    if (printerIp == null) {
                                      await invoicePromptForPrinterIp(context);
                                      printerIp = printerProvider
                                          .getInvoicePrinterIp();

                                      if (printerIp == null) {
                                        debugPrint("❌ Printer IP not set.");
                                        if (mounted &&
                                            _scaffoldMessenger != null) {
                                          _showCustomSnackBar(
                                            "Printer IP not set!",
                                            isSuccess: false,
                                          );
                                        }
                                        state.setSubmitting(false);
                                        return;
                                      }
                                    }

                                    // ✅ Proceed based on payment method
                                    if (state.activePaymentMethod == 'UPI') {
                                      final upiProvider =
                                          Provider.of<UpiProviderDine>(
                                            context,
                                            listen: false,
                                          );

                                      // ✅ Check if UPI is enabled
                                      if (!upiProvider.isUpiEnabled) {
                                        _showCustomSnackBar(
                                          "UPI payment is currently disabled!",
                                          isSuccess: false,
                                        );
                                        state.setSubmitting(false);
                                        return;
                                      }

                                      // ✅ Continue with UPI QR flow
                                      _showUpiQrDialog(upiAmount);
                                    } else if (state.activePaymentMethod ==
                                        'Card') {
                                      final customerNumber =
                                          _customerNumberController.text.trim();
                                      if (customerNumber.isEmpty) {
                                        _showCustomSnackBar(
                                          "Please enter customer number before card payment.",
                                          isSuccess: false,
                                        );
                                        state.setSubmitting(false);
                                        return;
                                      } else if (customerNumber.length != 10) {
                                        _showCustomSnackBar(
                                          "Customer number must be 10 digits.",
                                          isSuccess: false,
                                        );
                                        state.setSubmitting(false);
                                        return;
                                      }

                                      _createOrderAndPay();
                                    } else {
                                      _showCustomSnackBar(
                                        "Please select a payment method.",
                                        isSuccess: false,
                                      );
                                      state.setSubmitting(false);
                                    }
                                  },
                            child: Text(
                              state.isSubmitting
                                  ? "Processing..."
                                  : "Proceed to payment",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: SizedBox(
          width: 40,
          height: 40,
          child: FloatingActionButton(
            backgroundColor: Colors.teal[100],
            onPressed: () {
              state.resetPaymentState(widget.totalAmount);
              _customUpiController.clear();
              _customCardController.clear();
            },
            tooltip: "Reset Payment",
            child: const Icon(Icons.refresh, color: Colors.teal),
          ),
        ),
        bottomNavigationBar: const GlobalBottomNav(),
      ),
    );
  }
}

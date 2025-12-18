// import 'dart:async';
// import 'dart:convert';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:hive/hive.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
// import '../providers/razorpay_qr_provider.dart';
// import '../providers/upi_provider.dart';
// import 'package:web_socket_channel/io.dart';
// import '../components/globalAppbar.dart';
// import '../models/fetchDiningTax.dart';
// import 'package:yenpos/Global/globals_data.dart';
// import '../../kotpreinvoice/providers/bottomNavprovider.dart';
// import '../providers/login_provider.dart';
// import '../providers/order_provider.dart';
// import '../providers/printer_provider.dart';
// import '../screens/table_screen.dart';
// import '../services/invoiceReceipt.dart';
// import '../services/invoiceReceipt%20utility.dart';
// import 'bottomNav.dart';

// // 🔔 ChangeNotifier to manage SalesInvoicePayAndPrint state
// class SalesInvoicePayAndPrintState extends ChangeNotifier {
//   double _balanceAmount = 0.0;
//   bool _isSubmitting = false;
//   double _paymentAmount = 0.0;
//   String? _activePaymentMethod;
//   String? _razorpayPaymentId;

//   double get balanceAmount => _balanceAmount;
//   bool get isSubmitting => _isSubmitting;
//   double get paymentAmount => _paymentAmount;
//   String? get activePaymentMethod => _activePaymentMethod;
//   String? get razorpayPaymentId => _razorpayPaymentId;

//   void updateBalance({
//     required double totalAmount,
//     required double payment,
//     String? method,
//   }) {
//     _paymentAmount = payment;
//     _balanceAmount = totalAmount - payment;
//     _activePaymentMethod = method;

//     debugPrint(
//       "💰 Updated balance: $_balanceAmount, Payment: $_paymentAmount, Active Method: $_activePaymentMethod",
//     );
//     notifyListeners();
//   }

//   void setRazorpayPaymentId(String? paymentId) {
//     _razorpayPaymentId = paymentId;
//     debugPrint("💳 Razorpay Payment ID: $_razorpayPaymentId");
//     notifyListeners();
//   }

//   void resetPaymentState(double totalAmount) {
//     _paymentAmount = 0.0;
//     _balanceAmount = totalAmount;
//     _activePaymentMethod = null;
//     _razorpayPaymentId = null;
//     debugPrint("🔄 Reset payment state: Balance=$_balanceAmount");
//     notifyListeners();
//   }

//   void selectPaymentOption(String method, double amount, double totalAmount) {
//     _activePaymentMethod = method;
//     _paymentAmount = amount;
//     updateBalance(
//       totalAmount: totalAmount,
//       payment: _paymentAmount,
//       method: method,
//     );
//   }

//   void setSubmitting(bool value) {
//     _isSubmitting = value;
//     debugPrint("⏳ Submitting state: $_isSubmitting");
//     notifyListeners();
//   }
// }

// class SalesInvoicePayAndPrint extends StatefulWidget {
//   final double totalAmount;
//   final List<Map<String, dynamic>> items;
//   final String branchName;
//   final String deviceCode;

//   const SalesInvoicePayAndPrint({
//     Key? key,
//     required this.totalAmount,
//     required this.items,
//     required this.branchName,
//     required this.deviceCode,
//   }) : super(key: key);

//   @override
//   State<SalesInvoicePayAndPrint> createState() =>
//       _SalesInvoicePayAndPrintState();
// }

// class _SalesInvoicePayAndPrintState extends State<SalesInvoicePayAndPrint> {
//   final TextEditingController _employeeNumberController =
//       TextEditingController();
//   final TextEditingController _customerNumberController =
//       TextEditingController();
//   final TextEditingController _discountController = TextEditingController();
//   final TextEditingController _customChargeController = TextEditingController();
//   final TextEditingController _customUpiController = TextEditingController();
//   final TextEditingController _customCardController = TextEditingController();

//   final Razorpay _razorpay = Razorpay();
//   final Dio _dio = Dio(
//     BaseOptions(
//       baseUrl: "https://yenerp.com",
//       connectTimeout: const Duration(seconds: 30),
//       receiveTimeout: const Duration(seconds: 30),
//       sendTimeout: const Duration(seconds: 30),
//     ),
//   );

//   IOWebSocketChannel? _channel;
//   late SalesInvoicePayAndPrintState state;
//   ScaffoldMessengerState? _scaffoldMessenger;
//   Timer? _paymentStatusTimer;

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
//     debugPrint("📌 ScaffoldMessenger reference saved");
//   }

//   @override
//   void initState() {
//     super.initState();
//     state = SalesInvoicePayAndPrintState();
//     state.updateBalance(totalAmount: widget.totalAmount, payment: 0);

//     if (widget.items.isNotEmpty && widget.items.first.containsKey('waiter')) {
//       _employeeNumberController.text = widget.items.first['waiter'] ?? '';
//     }
//     if (widget.items.isNotEmpty &&
//         widget.items.first.containsKey('customerPhoneNumber')) {
//       _customerNumberController.text =
//           widget.items.first['customerPhoneNumber'] ?? '';
//     }

//     _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
//     _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
//     _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

//     _initializeWebSocket();
//   }

//   Future<void> _initializeWebSocket() async {
//     try {
//       _channel = IOWebSocketChannel.connect('ws://$serverip:$port');
//       debugPrint("📡 WebSocket connected to ws://$serverip:$port");
//     } catch (e) {
//       debugPrint("❌ Failed to connect to WebSocket: $e");
//       if (mounted && _scaffoldMessenger != null) {
//         _scaffoldMessenger!.showSnackBar(
//           SnackBar(
//             content: Text('Failed to connect to server: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _employeeNumberController.dispose();
//     _customerNumberController.dispose();
//     _discountController.dispose();
//     _customChargeController.dispose();
//     _customUpiController.dispose();
//     _customCardController.dispose();
//     _paymentStatusTimer?.cancel();
//     _razorpay.clear();
//     if (_channel != null) {
//       _channel!.sink.close();
//       debugPrint("🗑️ WebSocket channel closed");
//     } else {
//       debugPrint("⚠️ WebSocket channel was not initialized, skipping close");
//     }
//     state.dispose();
//     super.dispose();
//   }

//   String _getSuggestedAmount() {
//     final upiAmount = double.tryParse(_customUpiController.text) ?? 0.0;
//     final cardAmount = double.tryParse(_customCardController.text) ?? 0.0;
//     final totalEntered = upiAmount + cardAmount;
//     final remaining = widget.totalAmount - totalEntered;
//     return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
//   }

//   void _showCustomSnackBar(String message, {bool isSuccess = false}) {
//     if (mounted && _scaffoldMessenger != null) {
//       _scaffoldMessenger!.showSnackBar(
//         SnackBar(
//           content: Row(
//             children: [
//               Icon(
//                 isSuccess ? Icons.check_circle : Icons.error,
//                 color: Colors.white,
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(message, style: const TextStyle(fontSize: 16)),
//               ),
//             ],
//           ),
//           backgroundColor: isSuccess ? Colors.green : Colors.red,
//           duration: const Duration(seconds: 3),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//         ),
//       );
//     }
//   }

//   void _showUpiQrDialog(double amount) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<RazorpayProvider>(context, listen: false).createQR(amount);
//     });

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return PopScope(
//           canPop: true, // ✅ allow dialog to close on back or X button
//           onPopInvoked: (didPop) {
//             if (mounted) {
//               state.setSubmitting(false); // ✅ reset submitting when closed
//             }
//           },
//           child: AlertDialog(
//             backgroundColor: Colors.white,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//             ),
//             title: const Row(
//               children: [
//                 Icon(Icons.qr_code, color: Colors.blue),
//                 SizedBox(width: 8),
//                 Text(
//                   'UPI QR Code',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//             content: SizedBox(
//               height: 600,
//               width: 285,
//               child: Consumer<RazorpayProvider>(
//                 builder: (context, qrProvider, _) {
//                   if (qrProvider.isLoading) {
//                     return const Center(child: CircularProgressIndicator());
//                   } else if (qrProvider.errorMessage != null) {
//                     WidgetsBinding.instance.addPostFrameCallback((_) {
//                       state.setSubmitting(false); // ❌ reset if error
//                     });
//                     return Text(
//                       qrProvider.errorMessage!,
//                       style: const TextStyle(color: Colors.red, fontSize: 16),
//                       textAlign: TextAlign.center,
//                     );
//                   } else if (qrProvider.paymentSuccess) {
//                     WidgetsBinding.instance.addPostFrameCallback((_) {
//                       state.setSubmitting(false); // ✅ reset on success
//                     });
//                     return const Center(
//                       child: Text(
//                         'Payment Successful',
//                         style: TextStyle(fontSize: 20, color: Colors.green),
//                       ),
//                     );
//                   } else if (qrProvider.qrImageUrl != null) {
//                     return Column(
//                       children: [
//                         Image.network(
//                           qrProvider.qrImageUrl!,
//                           height: 535,
//                           width: 300,
//                           fit: BoxFit.fill,
//                         ),
//                         Row(
//                           children: [
//                             Expanded(
//                               child: ElevatedButton.icon(
//                                 icon: const Icon(Icons.close),
//                                 label: const Text("Close"),
//                                 onPressed: () {
//                                   qrProvider.disconnectWebSocket();
//                                   Navigator.pop(context);
//                                 },
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: const Color.fromARGB(
//                                     255,
//                                     6,
//                                     62,
//                                     247,
//                                   ),
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(7),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     );
//                   } else {
//                     return const Center(child: Text('No QR generated'));
//                   }
//                 },
//               ),
//             ),
//           ),
//         );
//       },
//     ).then((_) {
//       if (mounted)
//         state.setSubmitting(false); // ✅ also reset if closed manually
//     });
//   }

//   Future<void> _createOrderAndPay() async {
//     final amount = double.tryParse(_customCardController.text);
//     if (amount == null || amount <= 0) {
//       debugPrint("⚠️ Invalid card amount entered: $_customCardController.text");
//       if (mounted) {
//         _showCustomSnackBar('Enter a valid card amount', isSuccess: false);
//       }
//       return;
//     }

//     debugPrint(
//       "💳 Creating Razorpay order for ₹${amount.toStringAsFixed(2)}...",
//     );

//     try {
//       state.setSubmitting(true); // 🔹 Start submitting
//       final response = await _dio.post(
//         "/fastapi/razorPay/create_order/?price=$amount",
//       );
//       debugPrint("📦 Order Response: ${response.data}");

//       final orderData = response.data;
//       if (orderData == null || orderData['id'] == null) {
//         debugPrint("⚠️ Invalid order response: $orderData");
//         if (mounted) {
//           _showCustomSnackBar(
//             'Invalid order data from server',
//             isSuccess: false,
//           );
//         }
//         state.setSubmitting(false); // 🔹 Stop submitting on invalid order
//         return;
//       }

//       // Razorpay expects the amount in paise
//       final razorpayAmount = (amount * 100).toInt();
//       String customerNumber = _customerNumberController.text.trim();

//       final options = {
//         'key': 'rzp_live_RSsJoT9ThF9zms',
//         'amount': razorpayAmount,
//         'name': 'YenKOT Payments',
//         'description': 'Card Payment for ₹${amount.toStringAsFixed(2)}',
//         'order_id': orderData['id'],
//         'prefill': {'contact': customerNumber, 'method': 'card'},
//         'theme': {'color': '#2E86DE', 'backdrop_color': '#ffffff'},
//       };

//       debugPrint("🚀 Opening Razorpay with options: $options");

//       try {
//         _razorpay.open(options);
//         debugPrint("✅ Razorpay window triggered successfully");
//       } catch (e) {
//         debugPrint("❌ Error opening Razorpay: $e");
//         _showCustomSnackBar('Could not open payment window.', isSuccess: false);
//         state.setSubmitting(false);
//       }
//     } on DioException catch (e) {
//       debugPrint("💥 DioException while creating order: ${e.message}");
//       if (mounted) {
//         _showCustomSnackBar('Network issue creating order.', isSuccess: false);
//       }
//       state.setSubmitting(false); // 🔹 Stop submitting on Dio error
//     } catch (e, stack) {
//       debugPrint("💥 Unexpected error creating order: $e");
//       debugPrint("🧾 Stacktrace: $stack");
//       if (mounted) {
//         _showCustomSnackBar(
//           'Unexpected error while creating order.',
//           isSuccess: false,
//         );
//       }
//       state.setSubmitting(false); // 🔹 Stop submitting on unexpected error
//     }
//   }

//   void _handlePaymentSuccess(PaymentSuccessResponse response) async {
//     state.setSubmitting(true); // 🔹 Start verifying payment
//     final verifyData = {
//       "order_id": response.orderId,
//       "payment_id": response.paymentId,
//       "signature": response.signature,
//     };

//     try {
//       final result = await _dio.post(
//         "https://yenerp.com/fastapi/razorPay/verify_payment",
//         data: verifyData,
//       );

//       if (result.data["status"] == "success") {
//         state.setRazorpayPaymentId(response.paymentId);
//         if (mounted) {
//           _showCustomSnackBar(
//             'Amount received! Processing invoice...',
//             isSuccess: true,
//           );
//           _processInvoiceAndPrint();
//         }
//         state.setSubmitting(false); // 🔹 Stop after success
//       } else {
//         if (mounted) {
//           _showCustomSnackBar('Payment verification failed', isSuccess: false);
//           state.setSubmitting(false); // 🔹 Stop after verification fail
//         }
//       }
//     } catch (e) {
//       debugPrint("❌ Error verifying payment: $e");
//       if (mounted) {
//         _showCustomSnackBar('Error verifying payment: $e', isSuccess: false);
//         state.setSubmitting(false); // 🔹 Stop after error
//       }
//     }
//   }

//   void _handlePaymentError(PaymentFailureResponse response) {
//     debugPrint("❌ Payment failed: ${response.code} | ${response.message}");
//     if (mounted) {
//       _showCustomSnackBar(
//         'Payment failed: ${response.message}',
//         isSuccess: false,
//       );
//       state.setSubmitting(false);
//     }
//   }

//   void _handleExternalWallet(ExternalWalletResponse response) {
//     debugPrint("💳 External Wallet: ${response.walletName}");
//     state.setSubmitting(false); // 🔹 Stop in case of external wallet
//   }

//   Future<String> generatehiveInvoiceId(String branchName) async {
//     final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
//     final currentDate1 = DateFormat('ddMMyy').format(DateTime.now());

//     var invoiceBox = await Hive.openBox('invoices');

//     String lastInvoiceDate = invoiceBox.get(
//       'lastInvoiceDate',
//       defaultValue: "",
//     );
//     int invoiceCounter = invoiceBox.get('invoiceCounter', defaultValue: 0);

//     // Reset or increment counter
//     if (lastInvoiceDate != currentDate || invoiceCounter == 0) {
//       invoiceCounter = 1;
//     } else {
//       invoiceCounter++;
//     }

//     String hiveInvoiceId =
//         'BM/$branchName $currentDate1 KOTINVOICE${invoiceCounter.toString().padLeft(3, '0')}';

//     // Save back to Hive
//     await invoiceBox.put('invoiceCounter', invoiceCounter);
//     await invoiceBox.put('lastInvoiceDate', currentDate);

//     return hiveInvoiceId;
//   }

//   void _sendInvoiceDataToServer() async {
//     debugPrint("📦 Preparing and grouping invoice data for server...");

//     final loginProvider = Provider.of<LoginProvider>(context, listen: false);
//     final loggedInUserName = loginProvider.loggedInUserName ?? "";
//     debugPrint("👤 Logged in user: $loggedInUserName");

//     double diningTaxPercentage = getTaxPercentage();

//     Map<String, Map<String, dynamic>> groupedItems = {};
//     List<Map<String, dynamic>> kotAddOns = [];

//     for (var item in widget.items) {
//       if (item.isEmpty) {
//         debugPrint("⚠️ Skipping null or empty item: $item");
//         continue;
//       }

//       for (int i = 0; i < (item['varianceName']?.length ?? 0); i++) {
//         String variance = item['varianceName']?[i] ?? "";

//         if (!groupedItems.containsKey(variance)) {
//           groupedItems[variance] = {
//             "varianceName": variance,
//             "itemName": item['itemName']?[i] ?? "",
//             "price": item['price']?[i] ?? 0.0,
//             "qty": 0.0,
//             "weight": 0.0,
//             "amount": 0.0,
//             "tax": diningTaxPercentage,
//             "uom": item['uom']?[i] ?? "",
//           };
//         }

//         groupedItems[variance]!['qty'] += item['qty']?[i] ?? 0.0;
//         groupedItems[variance]!['weight'] += item['weight']?[i] ?? 0.0;
//         groupedItems[variance]!['amount'] += item['amount']?[i] ?? 0.0;

//         if (item.containsKey('config') && item['config'] != null) {
//           for (var configItem in item['config']) {
//             String varianceName = configItem['varianceName'] ?? "";
//             bool isAlreadyAdded = kotAddOns.any(
//               (existingConfig) =>
//                   existingConfig["varianceName"] == varianceName &&
//                   existingConfig["configQty"].toString() ==
//                       configItem["configQty"].toString(),
//             );

//             if (!isAlreadyAdded) {
//               kotAddOns.add({
//                 "varianceName": varianceName,
//                 "weight": configItem['weight'] ?? 0,
//                 "configQty": List.from(configItem['configQty'] ?? []),
//                 "addOn": List.from(configItem['addOn'] ?? []),
//                 "addOnPrice": List.from(configItem['addOnPrice'] ?? []),
//                 "addOnQuantities": List.from(
//                   configItem['addOnQuantities'] ?? [],
//                 ),
//                 "variance": List.from(configItem['variance'] ?? []),
//                 "type": List.from(configItem['type'] ?? []),
//                 "remark": List.from(configItem['remark'] ?? []),
//               });

//               debugPrint(
//                 "➕ Config added: variance=$varianceName, addOns=${configItem['addOn']}, prices=${configItem['addOnPrice']}, qty=${configItem['configQty']}",
//               );
//             }
//           }
//         }
//       }
//     }

//     final invoiceNo = await generatehiveInvoiceId(widget.branchName);

//     Map<String, dynamic> invoiceData = {
//       "type": "invoiceKOT",
//       "invoiceNo": invoiceNo,
//       "seathiveOrderId": widget.items.first['seathiveOrderId'] ?? "",
//       "varianceName": groupedItems.keys.toList(),
//       "itemName": groupedItems.values.map((item) => item['itemName']).toList(),
//       "price": groupedItems.values.map((item) => item['price']).toList(),
//       "qty": groupedItems.values.map((item) => item['qty']).toList(),
//       "weight": groupedItems.values.map((item) => item['weight']).toList(),
//       "amount": groupedItems.values.map((item) => item['amount']).toList(),
//       "tax": groupedItems.values.map((item) => item['tax']).toList(),
//       "uom": groupedItems.values.map((item) => item['uom']).toList(),
//       "totalAmount": widget.totalAmount,
//       // "paymentType": state.activePaymentMethod,
//       "card": state.activePaymentMethod == 'Card' ? widget.totalAmount : 0,
//       "upi": state.activePaymentMethod == 'UPI' ? widget.totalAmount : 0,
//       "razorpayPaymentId": state.razorpayPaymentId ?? "",
//       "invoiceDate": DateFormat('dd-MM-yyyy').format(DateTime.now()),
//       "invoiceTime": DateFormat('hh:mm a').format(DateTime.now()),
//       "deviceCode": widget.deviceCode,
//       "branchId": branchId,
//       "branchName": widget.branchName,
//       "salesPersonId": loggedInUserName,
//       "salesPersonName": createdBy,
//       "employeeNumber": _employeeNumberController.text.trim(),
//       "customerNumber": _customerNumberController.text.trim(),
//       "sync": "No",
//       "salesType": ordertype,
//       "kotaddOns": kotAddOns,
//     };

//     debugPrint("✅ Final invoice data prepared: $invoiceData");

//     if (invoiceData['totalAmount'] <= 0.0) {
//       debugPrint(
//         "❌ Invoice data is invalid, total amount is zero or negative.",
//       );
//       if (mounted && _scaffoldMessenger != null) {
//         _showCustomSnackBar(
//           "Invalid invoice data, total amount is zero.",
//           isSuccess: false,
//         );
//       }
//       return;
//     }

//     try {
//       if (_channel == null) {
//         await _initializeWebSocket();
//         if (_channel == null) {
//           throw Exception('Failed to establish WebSocket connection');
//         }
//       }

//       final serializedData = jsonEncode(invoiceData);
//       debugPrint("📤 Sending serialized data: $serializedData");
//       _channel!.sink.add(serializedData);

//       debugPrint("🎉 Invoice data sent to server successfully!");
//     } catch (e) {
//       debugPrint("⚠️ Error sending invoice data: $e");
//       if (mounted && _scaffoldMessenger != null) {
//         _showCustomSnackBar("Error sending invoice data: $e", isSuccess: false);
//       }
//     }
//   }

//   void _processInvoiceAndPrint() async {
//     try {
//       final printerProvider = Provider.of<PrinterProviderDine>(
//         context,
//         listen: false,
//       );
//       final orderProvider = Provider.of<OrderProvider>(context, listen: false);

//       var printerIp = printerProvider.getInvoicePrinterIp();

//       if (printerIp == null) {
//         await invoicePromptForPrinterIp(context);
//         printerIp = printerProvider.getInvoicePrinterIp();
//         if (printerIp == null) {
//           debugPrint("❌ Printer IP not set.");
//           if (mounted && _scaffoldMessenger != null) {
//             _showCustomSnackBar("Printer IP not set!", isSuccess: false);
//           }
//           state.setSubmitting(false);
//           return;
//         }
//       }

//       debugPrint("🚀 Invoice items count: ${widget.items.length}");
//       _sendInvoiceDataToServer();

//       String seathiveOrderId = widget.items.first['seathiveOrderId'] ?? '';
//       String table = widget.items.first['table'] ?? '';
//       String seat = widget.items.first['seat'] ?? '';

//       if (seathiveOrderId.isNotEmpty) {
//         orderProvider.patchOrderStatusBySeathiveOrderId(
//           seathiveOrderId,
//           'invoiced',
//         );
//         debugPrint(
//           "✅ Patched order status for sale seatHiveOrderId=$seathiveOrderId",
//         );
//       }

//       await ReceiptPrinter(
//         employeeNumberController: _employeeNumberController,
//         seathiveOrderId: seathiveOrderId,
//         customerNumberController: _customerNumberController,
//         discountController: _discountController,
//         customChargeController: _customChargeController,
//         selectedPaymentOptionValue: '',
//         context: context,
//         customAmountController: _customUpiController.text.isNotEmpty
//             ? _customUpiController
//             : _customCardController,
//         selectedPaymentOption: state.activePaymentMethod ?? 'UPI',
//         items: widget.items,
//         branchName: widget.branchName,
//         table: table,
//         seat: seat,
//         printerProvider: printerProvider,
//       ).printReceiptDetails();

//       if (mounted && _scaffoldMessenger != null) {
//         debugPrint("Receipt printed.....");
//       } else {
//         debugPrint("⚠️ Widget not mounted or ScaffoldMessenger not available");
//       }

//       if (mounted) {
//         await Future.delayed(const Duration(milliseconds: 500));
//         if (mounted) {
//           Provider.of<BottomNavProviderKOT>(
//             context,
//             listen: false,
//           ).updateIndex(0);
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (_) => const TableScreen()),
//             (route) => false,
//           );
//           debugPrint("📤 Navigated to TableScreen");
//         }
//       }
//     } catch (e, st) {
//       debugPrint("❌ Error during invoice printing: $e\n$st");
//       if (mounted && _scaffoldMessenger != null) {
//         _showCustomSnackBar("Error: $e", isSuccess: false);
//       }
//     } finally {
//       if (mounted) {
//         state.setSubmitting(false);
//       }
//     }
//   }

//   Widget _buildPaymentEntry(String method, TextEditingController controller) {
//     return Consumer<SalesInvoicePayAndPrintState>(
//       builder: (context, state, _) {
//         final String suggestion = _getSuggestedAmount();
//         final double suggestedValue = double.tryParse(suggestion) ?? 0.0;
//         final bool isDisabled =
//             state.activePaymentMethod != null &&
//             state.activePaymentMethod != method;

//         return Container(
//           margin: const EdgeInsets.symmetric(vertical: 6),
//           padding: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.grey.withOpacity(0.3),
//                 offset: const Offset(3, 3),
//                 blurRadius: 6,
//               ),
//               const BoxShadow(
//                 color: Colors.white,
//                 offset: Offset(-2, -2),
//                 blurRadius: 6,
//               ),
//             ],
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 flex: 2,
//                 child: Text(
//                   method,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               GestureDetector(
//                 onTap: isDisabled
//                     ? null
//                     : () {
//                         if (suggestedValue > 0) {
//                           controller.text = suggestion;
//                           state.selectPaymentOption(
//                             method,
//                             suggestedValue,
//                             widget.totalAmount,
//                           );
//                           if (method == 'UPI') {
//                             _customCardController.clear();
//                           } else if (method == 'Card') {
//                             _customUpiController.clear();
//                           }
//                         } else {
//                           controller.clear();
//                           state.resetPaymentState(widget.totalAmount);
//                         }
//                       },
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 14,
//                     vertical: 8,
//                   ),
//                   decoration: BoxDecoration(
//                     color: isDisabled ? Colors.grey[300] : Colors.teal[50],
//                     borderRadius: BorderRadius.circular(8),
//                     boxShadow: [
//                       BoxShadow(
//                         color: isDisabled
//                             ? Colors.grey.withOpacity(0.2)
//                             : Colors.teal.withOpacity(0.3),
//                         offset: const Offset(2, 2),
//                         blurRadius: 4,
//                       ),
//                       const BoxShadow(
//                         color: Colors.white,
//                         offset: Offset(-2, -2),
//                         blurRadius: 4,
//                       ),
//                     ],
//                   ),
//                   child: Text(
//                     suggestion,
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       color: isDisabled ? Colors.grey : Colors.teal,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 flex: 3,
//                 child: TextField(
//                   controller: controller,
//                   enabled: !isDisabled,
//                   keyboardType: TextInputType.number,
//                   inputFormatters: [
//                     FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
//                   ],
//                   onChanged: (val) {
//                     if (val.isNotEmpty) {
//                       state.selectPaymentOption(
//                         method,
//                         double.tryParse(val) ?? 0,
//                         widget.totalAmount,
//                       );
//                       if (method == 'UPI') {
//                         _customCardController.clear();
//                       } else if (method == 'Card') {
//                         _customUpiController.clear();
//                       }
//                     } else {
//                       state.resetPaymentState(widget.totalAmount);
//                     }
//                   },
//                   decoration: InputDecoration(
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 8,
//                     ),
//                     filled: true,
//                     fillColor: isDisabled ? Colors.grey[200] : Colors.grey[50],
//                     hintText: 'Enter $method Amount',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: BorderSide.none,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     double padding = MediaQuery.of(context).size.width * 0.04;

//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider.value(value: state),
//         ChangeNotifierProvider(create: (_) => RazorpayProvider()),
//       ],
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         body: Consumer<SalesInvoicePayAndPrintState>(
//           builder: (context, state, _) {
//             // return ListView(
//             //   children: [
//             //     Padding(
//             //       padding: const EdgeInsets.only(top: 20, bottom: 20),
//             //       child: Center(
//             //         child: Container(
//             //           child: Text(
//             //             "Payment Details",
//             //             style: TextStyle(
//             //               fontSize: 30,
//             //               color: Colors.black,
//             //               fontWeight: FontWeight.bold,
//             //             ),
//             //           ),
//             //         ),
//             //       ),
//             //     ),
//             //     Padding(
//             //       padding: const EdgeInsets.symmetric(
//             //         vertical: 10,
//             //         horizontal: 15,
//             //       ),
//             //       child: Row(
//             //         children: [
//             //           Expanded(
//             //             flex: 3,
//             //             child: TextFormField(
//             //               controller: _customerNumberController,
//             //               keyboardType: TextInputType.number,
//             //               decoration: InputDecoration(
//             //                 labelText: "Sales Person",
//             //                 labelStyle: TextStyle(color: Colors.teal),
//             //                 enabledBorder: OutlineInputBorder(
//             //                   borderRadius: BorderRadius.circular(8.0),
//             //                   borderSide: BorderSide(
//             //                     color: Colors.teal[50] ?? Colors.teal,
//             //                     width: 1.5,
//             //                   ),
//             //                 ),
//             //                 focusedBorder: OutlineInputBorder(
//             //                   borderRadius: BorderRadius.circular(8.0),
//             //                   borderSide: BorderSide(
//             //                     color: Colors.teal,
//             //                     width: 2,
//             //                   ),
//             //                 ),
//             //               ),
//             //               inputFormatters: [
//             //                 FilteringTextInputFormatter.digitsOnly,
//             //                 LengthLimitingTextInputFormatter(10),
//             //               ],
//             //               validator: (value) {
//             //                 if (value == null || value.isEmpty) {
//             //                   return 'Please enter a customer number';
//             //                 } else if (value.length < 10) {
//             //                   return 'Number must be 10 digits';
//             //                 } else if (value.length > 10) {
//             //                   return 'Number cannot exceed 10 digits';
//             //                 }
//             //                 return null;
//             //               },
//             //             ),
//             //           ),
//             //           SizedBox(width: 20),
//             //           Expanded(
//             //             flex: 2,
//             //             child: TextFormField(
//             //               controller: _customerNumberController,
//             //               keyboardType: TextInputType.number,
//             //               decoration: InputDecoration(
//             //                 labelText: "Birthday Date",
//             //                 labelStyle: TextStyle(color: Colors.teal),
//             //                 enabledBorder: OutlineInputBorder(
//             //                   borderRadius: BorderRadius.circular(8.0),
//             //                   borderSide: BorderSide(
//             //                     color: Colors.teal[50] ?? Colors.teal,
//             //                     width: 1.5,
//             //                   ),
//             //                 ),
//             //                 focusedBorder: OutlineInputBorder(
//             //                   borderRadius: BorderRadius.circular(8.0),
//             //                   borderSide: BorderSide(
//             //                     color: Colors.teal,
//             //                     width: 2,
//             //                   ),
//             //                 ),
//             //               ),
//             //               inputFormatters: [
//             //                 FilteringTextInputFormatter.digitsOnly,
//             //                 LengthLimitingTextInputFormatter(10),
//             //               ],
//             //               validator: (value) {
//             //                 if (value == null || value.isEmpty) {
//             //                   return 'Please enter a customer number';
//             //                 } else if (value.length < 10) {
//             //                   return 'Number must be 10 digits';
//             //                 } else if (value.length > 10) {
//             //                   return 'Number cannot exceed 10 digits';
//             //                 }
//             //                 return null;
//             //               },
//             //             ),
//             //           ),
//             //           SizedBox(width: 10),
//             //           Expanded(
//             //             flex: 2,
//             //             child: TextFormField(
//             //               controller: _customerNumberController,
//             //               keyboardType: TextInputType.number,
//             //               decoration: InputDecoration(
//             //                 labelText: "Custom Charge",
//             //                 labelStyle: TextStyle(color: Colors.teal),
//             //                 enabledBorder: OutlineInputBorder(
//             //                   borderRadius: BorderRadius.circular(8.0),
//             //                   borderSide: BorderSide(
//             //                     color: Colors.teal[50] ?? Colors.teal,
//             //                     width: 1.5,
//             //                   ),
//             //                 ),
//             //                 focusedBorder: OutlineInputBorder(
//             //                   borderRadius: BorderRadius.circular(8.0),
//             //                   borderSide: BorderSide(
//             //                     color: Colors.teal,
//             //                     width: 2,
//             //                   ),
//             //                 ),
//             //               ),
//             //               inputFormatters: [
//             //                 FilteringTextInputFormatter.digitsOnly,
//             //                 LengthLimitingTextInputFormatter(10),
//             //               ],
//             //               validator: (value) {
//             //                 if (value == null || value.isEmpty) {
//             //                   return 'Please enter a customer number';
//             //                 } else if (value.length < 10) {
//             //                   return 'Number must be 10 digits';
//             //                 } else if (value.length > 10) {
//             //                   return 'Number cannot exceed 10 digits';
//             //                 }
//             //                 return null;
//             //               },
//             //             ),
//             //           ),
//             //         ],
//             //       ),
//             //     ),
//             //     Padding(
//             //       padding: const EdgeInsets.symmetric(
//             //         vertical: 10,
//             //         horizontal: 15,
//             //       ),
//             //       child: Row(
//             //         children: [
//             //           Expanded(
//             //             flex: 3,
//             //             child: TextFormField(
//             //               controller: _customerNumberController,
//             //               keyboardType: TextInputType.number,
//             //               decoration: InputDecoration(
//             //                 labelText: "Customer Mobile Number",
//             //                 labelStyle: TextStyle(color: Colors.teal),
//             //                 enabledBorder: OutlineInputBorder(
//             //                   borderRadius: BorderRadius.circular(8.0),
//             //                   borderSide: BorderSide(
//             //                     color: Colors.teal[50] ?? Colors.teal,
//             //                     width: 1.5,
//             //                   ),
//             //                 ),
//             //                 focusedBorder: OutlineInputBorder(
//             //                   borderRadius: BorderRadius.circular(8.0),
//             //                   borderSide: BorderSide(
//             //                     color: Colors.teal,
//             //                     width: 2,
//             //                   ),
//             //                 ),
//             //               ),
//             //               inputFormatters: [
//             //                 FilteringTextInputFormatter.digitsOnly,
//             //                 LengthLimitingTextInputFormatter(10),
//             //               ],
//             //               validator: (value) {
//             //                 if (value == null || value.isEmpty) {
//             //                   return 'Please enter a customer number';
//             //                 } else if (value.length < 10) {
//             //                   return 'Number must be 10 digits';
//             //                 } else if (value.length > 10) {
//             //                   return 'Number cannot exceed 10 digits';
//             //                 }
//             //                 return null;
//             //               },
//             //             ),
//             //           ),
//             //           SizedBox(width: 20),
//             //           Expanded(
//             //             flex: 2,
//             //             child: Container(
//             //               decoration: BoxDecoration(
//             //                 color: Colors
//             //                     .white, // background needed for shadow to show
//             //                 borderRadius: BorderRadius.circular(8.0),
//             //                 boxShadow: [
//             //                   BoxShadow(
//             //                     color: Colors.black.withOpacity(0.3),
//             //                     blurRadius: 3,
//             //                     spreadRadius: 1,
//             //                     offset: Offset(0, 1), // shadow direction
//             //                   ),
//             //                 ],
//             //               ),
//             //               child: TextFormField(
//             //                 controller: _customerNumberController,
//             //                 keyboardType: TextInputType.number,
//             //                 decoration: InputDecoration(
//             //                   labelText: "% Discount",
//             //                   labelStyle: TextStyle(color: Colors.teal),
//             //                   enabledBorder: OutlineInputBorder(
//             //                     borderRadius: BorderRadius.circular(8.0),
//             //                     borderSide: BorderSide(
//             //                       color: Colors.teal[50] ?? Colors.teal,
//             //                       width: 1.5,
//             //                     ),
//             //                   ),
//             //                   focusedBorder: OutlineInputBorder(
//             //                     borderRadius: BorderRadius.circular(8.0),
//             //                     borderSide: BorderSide(
//             //                       color: Colors.grey,
//             //                       width: 0,
//             //                     ),
//             //                   ),
//             //                   border: InputBorder
//             //                       .none, // <- important inside container
//             //                 ),
//             //                 inputFormatters: [
//             //                   FilteringTextInputFormatter.digitsOnly,
//             //                   LengthLimitingTextInputFormatter(10),
//             //                 ],
//             //                 validator: (value) {
//             //                   if (value == null || value.isEmpty) {
//             //                     return 'Please enter a customer number';
//             //                   } else if (value.length < 10) {
//             //                     return 'Number must be 10 digits';
//             //                   } else if (value.length > 10) {
//             //                     return 'Number cannot exceed 10 digits';
//             //                   }
//             //                   return null;
//             //                 },
//             //               ),
//             //             ),
//             //           ),

//             //           SizedBox(width: 10),
//             //           Expanded(
//             //             flex: 2,
//             //             child: TextFormField(
//             //               controller: _customerNumberController,
//             //               keyboardType: TextInputType.number,
//             //               decoration: InputDecoration(
//             //                 labelText: " 🧾 Coupoun",
//             //                 labelStyle: TextStyle(color: Colors.teal),
//             //                 enabledBorder: OutlineInputBorder(
//             //                   borderRadius: BorderRadius.circular(8.0),
//             //                   borderSide: BorderSide(
//             //                     color: Colors.teal[50] ?? Colors.teal,
//             //                     width: 1.5,
//             //                   ),
//             //                 ),
//             //                 focusedBorder: OutlineInputBorder(
//             //                   borderRadius: BorderRadius.circular(8.0),
//             //                   borderSide: BorderSide(
//             //                     color: Colors.teal,
//             //                     width: 2,
//             //                   ),
//             //                 ),
//             //               ),
//             //               inputFormatters: [
//             //                 FilteringTextInputFormatter.digitsOnly,
//             //                 LengthLimitingTextInputFormatter(10),
//             //               ],
//             //               validator: (value) {
//             //                 if (value == null || value.isEmpty) {
//             //                   return 'Please enter a customer number';
//             //                 } else if (value.length < 10) {
//             //                   return 'Number must be 10 digits';
//             //                 } else if (value.length > 10) {
//             //                   return 'Number cannot exceed 10 digits';
//             //                 }
//             //                 return null;
//             //               },
//             //             ),
//             //           ),
//             //         ],
//             //       ),
//             //     ),
//             //   ],
//             // );
//             return Padding(
//               padding: EdgeInsets.symmetric(horizontal: padding),
//               child: ListView(
//                 children: [
//                   Container(
//                     margin: EdgeInsets.symmetric(vertical: padding / 2),
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [Colors.green[100]!, Colors.green[300]!],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                       borderRadius: BorderRadius.circular(16),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.grey[400]!,
//                           offset: const Offset(6, 6),
//                           blurRadius: 12,
//                         ),
//                         const BoxShadow(
//                           color: Colors.white,
//                           offset: Offset(-6, -6),
//                           blurRadius: 12,
//                         ),
//                       ],
//                     ),
//                     child: Padding(
//                       padding: EdgeInsets.all(padding),
//                       child: Column(
//                         children: [
//                           const Text(
//                             'Total Amount',
//                             style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black),
//                           ),
//                           Text(
//                             '₹${widget.totalAmount.toStringAsFixed(0)}',
//                             style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   Container(
//                     margin: EdgeInsets.symmetric(vertical: padding / 2),
//                     padding: EdgeInsets.all(padding),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(16),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.grey[400]!,
//                           offset: const Offset(6, 6),
//                           blurRadius: 12,
//                         ),
//                         const BoxShadow(
//                           color: Colors.white,
//                           offset: Offset(-6, -6),
//                           blurRadius: 12,
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       children: [
//                         Row(
//                           children: [
//                             Expanded(
//                               child: TextField(
//                                 controller: _employeeNumberController,
//                                 decoration: InputDecoration(
//                                   labelText: "Employee",
//                                   border: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(8.0),
//                                   ),
//                                 ),
//                                 enabled: false,
//                                 style: const TextStyle(color: Colors.grey),
//                               ),
//                             ),
//                             SizedBox(width: padding),
//                             Expanded(
//                               child: TextFormField(
//                                 controller: _customerNumberController,
//                                 keyboardType: TextInputType.number,
//                                 decoration: InputDecoration(
//                                   labelText: "Customer Number",
//                                   labelStyle: const TextStyle(color: Colors.teal),
//                                   enabledBorder: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(8.0),
//                                     borderSide: BorderSide(
//                                       color: Colors.teal[50] ?? Colors.teal,
//                                       width: 1.5,
//                                     ),
//                                   ),
//                                   focusedBorder: OutlineInputBorder(
//                                     borderRadius: BorderRadius.circular(8.0),
//                                     borderSide: const BorderSide(
//                                       color: Colors.teal,
//                                       width: 2,
//                                     ),
//                                   ),
//                                 ),
//                                 inputFormatters: [
//                                   FilteringTextInputFormatter.digitsOnly,
//                                   LengthLimitingTextInputFormatter(10),
//                                 ],
//                                 validator: (value) {
//                                   if (value == null || value.isEmpty) {
//                                     return 'Please enter a customer number';
//                                   } else if (value.length < 10) {
//                                     return 'Number must be 10 digits';
//                                   } else if (value.length > 10) {
//                                     return 'Number cannot exceed 10 digits';
//                                   }
//                                   return null;
//                                 },
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   _buildPaymentEntry("UPI", _customUpiController),
//                   _buildPaymentEntry("Card", _customCardController),
//                   Container(
//                     margin: EdgeInsets.symmetric(vertical: padding / 2),
//                     decoration: BoxDecoration(
//                       color: Colors.green[100],
//                       borderRadius: BorderRadius.circular(16),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.grey[400]!,
//                           offset: const Offset(6, 6),
//                           blurRadius: 12,
//                         ),
//                         const BoxShadow(
//                           color: Colors.white,
//                           offset: Offset(-6, -6),
//                           blurRadius: 12,
//                         ),
//                       ],
//                     ),
//                     child: Padding(
//                       padding: EdgeInsets.all(padding),
//                       child: Column(
//                         children: [
//                           const Text(
//                             "Balance Amount",
//                             style: TextStyle(fontSize: 18),
//                           ),
//                           Text(
//                             '₹${state.balanceAmount.toStringAsFixed(0)}',
//                             style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
//                           ),
//                           const SizedBox(height: 5),
//                           ElevatedButton(
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.green[400],
//                               elevation: 2,
//                               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                             onPressed: (state.isSubmitting || state.balanceAmount > 0)
//                                 ? null
//                                 : () async {
//                                     state.setSubmitting(true);

//                                     final upiAmount = double.tryParse(_customUpiController.text) ?? 0.0;
//                                     final cardAmount = double.tryParse(_customCardController.text) ?? 0.0;
//                                     final totalEntered = upiAmount + cardAmount;

//                                     // ✅ Validate entered amount
//                                     if (totalEntered != widget.totalAmount) {
//                                       if (mounted && _scaffoldMessenger != null) {
//                                         _showCustomSnackBar(
//                                           "Entered amount must equal total amount.",
//                                           isSuccess: false,
//                                         );
//                                       }
//                                       state.setSubmitting(false);
//                                       return;
//                                     }

//                                     // ✅ Validate Invoice Printer IP
//                                     final printerProvider = Provider.of<PrinterProviderDine>(context, listen: false);

//                                     var printerIp = printerProvider.getInvoicePrinterIp();

//                                     if (printerIp == null) {
//                                       await invoicePromptForPrinterIp(context);
//                                       printerIp = printerProvider.getInvoicePrinterIp();

//                                       if (printerIp == null) {
//                                         debugPrint("❌ Printer IP not set.");
//                                         if (mounted && _scaffoldMessenger != null) {
//                                           _showCustomSnackBar("Printer IP not set!", isSuccess: false);
//                                         }
//                                         state.setSubmitting(false);
//                                         return;
//                                       }
//                                     }

//                                     // ✅ Proceed based on payment method
//                                     if (state.activePaymentMethod == 'UPI') {
//                                       final upiProvider = Provider.of<UpiProviderDine>(context, listen: false);

//                                       // ✅ Check if UPI is enabled
//                                       if (!upiProvider.isUpiEnabled) {
//                                         _showCustomSnackBar(
//                                           "UPI payment is currently disabled!",
//                                           isSuccess: false,
//                                         );
//                                         state.setSubmitting(false);
//                                         return;
//                                       }

//                                       // ✅ Continue with UPI QR flow
//                                       _showUpiQrDialog(upiAmount);
//                                     } else if (state.activePaymentMethod == 'Card') {
//                                       final customerNumber = _customerNumberController.text.trim();
//                                       if (customerNumber.isEmpty) {
//                                         _showCustomSnackBar(
//                                           "Please enter customer number before card payment.",
//                                           isSuccess: false,
//                                         );
//                                         state.setSubmitting(false);
//                                         return;
//                                       } else if (customerNumber.length != 10) {
//                                         _showCustomSnackBar(
//                                           "Customer number must be 10 digits.",
//                                           isSuccess: false,
//                                         );
//                                         state.setSubmitting(false);
//                                         return;
//                                       }

//                                       _createOrderAndPay();
//                                     } else {
//                                       _showCustomSnackBar(
//                                         "Please select a payment method.",
//                                         isSuccess: false,
//                                       );
//                                       state.setSubmitting(false);
//                                     }
//                                   },
//                             child: Text(
//                               state.isSubmitting ? "Processing..." : "Proceed to payment",
//                               style: const TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.black,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//         floatingActionButton: SizedBox(
//           width: 40,
//           height: 40,
//           child: FloatingActionButton(
//             backgroundColor: Colors.teal[100],
//             onPressed: () {
//               state.resetPaymentState(widget.totalAmount);
//               _customUpiController.clear();
//               _customCardController.clear();
//             },
//             tooltip: "Reset Payment",
//             child: const Icon(Icons.refresh, color: Colors.teal),
//           ),
//         ),
//         // bottomNavigationBar: const GlobalBottomNav(),
//       ),
//     );
//   }
// }

// import 'dart:async';
// import 'dart:convert';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:hive/hive.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:yenpos/Global/Provider/bottomNavprovider.dart';
// import 'package:yenpos/Global/Screen/camera_qr_screen.dart';
// import 'package:yenpos/Global/pos_detector.dart';
// import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
// import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
// import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
// import 'package:yenpos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
// import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/customer_search.dart';
// import 'package:yenpos/kotpreinvoice/providers/cartprovider.dart';
// import 'package:yenpos/kotpreinvoice/providers/timerProvider.dart';
// import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
// import 'package:yenpos/regular_mode_page/widget/emp_search.dart';
// import '../providers/razorpay_qr_provider.dart';
// import '../providers/upi_provider.dart';
// import 'package:web_socket_channel/io.dart';
// import '../components/globalAppbar.dart';
// import '../models/fetchDiningTax.dart';
// import 'package:yenpos/Global/globals_data.dart';
// import '../../kotpreinvoice/providers/bottomNavprovider.dart';
// import '../providers/login_provider.dart';
// import '../providers/order_provider.dart';
// import '../providers/printer_provider.dart';
// import '../screens/table_screen.dart';
// import '../services/invoiceReceipt.dart';
// import '../services/invoiceReceipt%20utility.dart';
// import 'bottomNav.dart';

// // 🔔 ChangeNotifier to manage SalesInvoicePayAndPrint state
// class SalesInvoicePayAndPrintState extends ChangeNotifier {
//   double _balanceAmount = 0.0;
//   bool _isSubmitting = false;
//   double _paymentAmount = 0.0;
//   String? _activePaymentMethod;
//   String? _razorpayPaymentId;

//   double get balanceAmount => _balanceAmount;
//   bool get isSubmitting => _isSubmitting;
//   double get paymentAmount => _paymentAmount;
//   String? get activePaymentMethod => _activePaymentMethod;
//   String? get razorpayPaymentId => _razorpayPaymentId;

//   void updateBalance({
//     required double totalAmount,
//     required double payment,
//     String? method,
//   }) {
//     _paymentAmount = payment;
//     _balanceAmount = totalAmount - payment;
//     _activePaymentMethod = method;

//     debugPrint(
//       "💰 Updated balance: $_balanceAmount, Payment: $_paymentAmount, Active Method: $_activePaymentMethod",
//     );
//     notifyListeners();
//   }

//   void setRazorpayPaymentId(String? paymentId) {
//     _razorpayPaymentId = paymentId;
//     debugPrint("💳 Razorpay Payment ID: $_razorpayPaymentId");
//     notifyListeners();
//   }

//   void resetPaymentState(double totalAmount) {
//     _paymentAmount = 0.0;
//     _balanceAmount = totalAmount;
//     _activePaymentMethod = null;
//     _razorpayPaymentId = null;
//     debugPrint("🔄 Reset payment state: Balance=$_balanceAmount");
//     notifyListeners();
//   }

//   void selectPaymentOption(String method, double amount, double totalAmount) {
//     _activePaymentMethod = method;
//     _paymentAmount = amount;
//     updateBalance(
//       totalAmount: totalAmount,
//       payment: _paymentAmount,
//       method: method,
//     );
//   }

//   void setSubmitting(bool value) {
//     _isSubmitting = value;
//     debugPrint("⏳ Submitting state: $_isSubmitting");
//     notifyListeners();
//   }
// }

// class SalesInvoicePayAndPrint extends StatefulWidget {
//   final double totalAmount;
//   final List<Map<String, dynamic>> items;
//   final String branchName;
//   final String deviceCode;

//   const SalesInvoicePayAndPrint({
//     Key? key,
//     required this.totalAmount,
//     required this.items,
//     required this.branchName,
//     required this.deviceCode,
//   }) : super(key: key);

//   @override
//   State<SalesInvoicePayAndPrint> createState() =>
//       _SalesInvoicePayAndPrintState();
// }

// class _SalesInvoicePayAndPrintState extends State<SalesInvoicePayAndPrint> {
//   final TextEditingController _employeeNumberController =
//       TextEditingController();
//   final TextEditingController _customerNumberController =
//       TextEditingController();
//   final TextEditingController _discountController = TextEditingController();
//   final TextEditingController _customChargeController = TextEditingController();
//   final TextEditingController _customUpiController = TextEditingController();
//   final TextEditingController _customCardController = TextEditingController();
//   final TextEditingController _couponCodeController = TextEditingController();
//   final TextEditingController _birthdayController = TextEditingController();
//   final TextEditingController _customCashController = TextEditingController();

//   Map<String, Map<String, dynamic>> _allEmployees = {};

//   final Razorpay _razorpay = Razorpay();
//   final Dio _dio = Dio(
//     BaseOptions(
//       baseUrl: "https://yenerp.com",
//       connectTimeout: const Duration(seconds: 30),
//       receiveTimeout: const Duration(seconds: 30),
//       sendTimeout: const Duration(seconds: 30),
//     ),
//   );

//   IOWebSocketChannel? _channel;
//   late SalesInvoicePayAndPrintState state;
//   ScaffoldMessengerState? _scaffoldMessenger;
//   Timer? _paymentStatusTimer;

//   late List<FocusNode> _focusNodes;
//   late ValueNotifier<int> _currentFocusIndexNotifier;
//   late List<TextEditingController> _keyboardControllers;
//   late Box ordersBox;

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
//     debugPrint("📌 ScaffoldMessenger reference saved");
//   }

//   @override
//   void initState() {
//     super.initState();
//     state = SalesInvoicePayAndPrintState();
//     _loadEmployees();
//     state.updateBalance(totalAmount: widget.totalAmount, payment: 0);

//     if (widget.items.isNotEmpty && widget.items.first.containsKey('waiter')) {
//       _employeeNumberController.text = widget.items.first['waiter'] ?? '';
//     }
//     if (widget.items.isNotEmpty &&
//         widget.items.first.containsKey('customerPhoneNumber')) {
//       _customerNumberController.text =
//           widget.items.first['customerPhoneNumber'] ?? '';
//     }

//     // Setup controllers and focus nodes
//     _keyboardControllers = [
//       _employeeNumberController,
//       _customerNumberController,
//       _discountController,
//       _customChargeController,
//       _customCashController, // Add this line
//       _customUpiController,
//       _customCardController,
//       _couponCodeController,
//       _birthdayController,
//     ];

//     _focusNodes = List.generate(
//       _keyboardControllers.length,
//       (_) => FocusNode(),
//     );
//     _currentFocusIndexNotifier = ValueNotifier<int>(0);

//     // Listen to focus changes
//     for (int i = 0; i < _focusNodes.length; i++) {
//       _focusNodes[i].addListener(() {
//         if (_focusNodes[i].hasFocus) {
//           _currentFocusIndexNotifier.value = i;
//         }
//       });
//     }

//     _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
//     _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
//     _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

//     _initializeWebSocket();
//   }

//   Future<void> _initializeWebSocket() async {
//     try {
//       _channel = IOWebSocketChannel.connect('ws://$serverip:$port');
//       debugPrint("📡 WebSocket connected to ws://$serverip:$port");
//     } catch (e) {
//       debugPrint("❌ Failed to connect to WebSocket: $e");
//       if (mounted && _scaffoldMessenger != null) {
//         _scaffoldMessenger!.showSnackBar(
//           SnackBar(
//             content: Text('Failed to connect to server: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _employeeNumberController.dispose();
//     _customerNumberController.dispose();
//     _discountController.dispose();
//     _customChargeController.dispose();
//     _customUpiController.dispose();
//     _customCardController.dispose();
//     _couponCodeController.dispose();
//     _birthdayController.dispose();
//     _paymentStatusTimer?.cancel();
//     _razorpay.clear();

//     // Dispose focus nodes
//     for (final node in _focusNodes) {
//       node.dispose();
//     }
//     _currentFocusIndexNotifier.dispose();

//     if (_channel != null) {
//       _channel!.sink.close();
//       debugPrint("🗑️ WebSocket channel closed");
//     } else {
//       debugPrint("⚠️ WebSocket channel was not initialized, skipping close");
//     }
//     state.dispose();
//     super.dispose();
//   }

//   String _getSuggestedAmount() {
//     final cashAmount =
//         double.tryParse(_customCashController.text) ?? 0.0; // Add this
//     // print("cashAmount is ..... ${cashAmount}");
//     final upiAmount = double.tryParse(_customUpiController.text) ?? 0.0;
//     final cardAmount = double.tryParse(_customCardController.text) ?? 0.0;
//     final totalEntered = cashAmount + upiAmount + cardAmount; // Update this
//     final remaining = widget.totalAmount - totalEntered;
//     return remaining > 0 ? remaining.toStringAsFixed(0) : "0";
//   }

//   void _showCustomSnackBar(String message, {bool isSuccess = false}) {
//     if (mounted && _scaffoldMessenger != null) {
//       _scaffoldMessenger!.showSnackBar(
//         SnackBar(
//           content: Row(
//             children: [
//               Icon(
//                 isSuccess ? Icons.check_circle : Icons.error,
//                 color: Colors.white,
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(message, style: const TextStyle(fontSize: 16)),
//               ),
//             ],
//           ),
//           backgroundColor: isSuccess ? Colors.green : Colors.red,
//           duration: const Duration(seconds: 3),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//         ),
//       );
//     }
//   }

//   Future<void> _loadEmployees() async {
//     var box = await Hive.openBox('employeeBox');
//     List<dynamic> employees = box.get('employees', defaultValue: []);
//     // Update _allEmployees without setState
//     _allEmployees = {
//       for (var emp in employees)
//         '${(emp as Map)["employeeNumber"]} - ${(emp as Map)["firstName"]}':
//             (emp as Map).cast<String, dynamic>(),
//     };
//     // print("_allEmployees $_allEmployees");
//   }

//   // void _selectEmployee(String selection) {
//   //   final employee = _allEmployees[selection];
//   //   if (employee != null) {
//   //     Provider.of<SalesInvoiceState>(context, listen: false).updateMultiple(selectedEmployeeFirstName: employee['firstName']);
//   //     prov.employee.text = selection;
//   //   }
//   //   validateForm();
//   //   _moveToNextField(0);
//   // }

//   void _selectEmployee(String selection) {
//     final employee = _allEmployees[selection];
//     if (employee != null) {
//       final stateProvider = Provider.of<SalesInvoiceState>(
//         context,
//         listen: false,
//       );

//       stateProvider.updateMultiple(
//         selectedEmployeeFirstName: employee['firstName'],
//         selectedEmployeeNumber: employee['employeeNumber'], // <-- NEW
//       );

//       _employeeNumberController.text =
//           selection; // UI text (kept for Autocomplete)
//     }

//     // validateForm();
//     // _moveToNextField(0);
//   }

//   bool _isQrMode = false;
//   final FocusNode _qrFocusNode = FocusNode();
//   final TextEditingController _qrController = TextEditingController();
//   bool _isProcessingQr = false;

//   // ------------------- QR TOGGLE -------------------
//   Future<void> _toggleQrMode() async {
//     final isPOS = await POSDetector.isPOSDevice;

//     if (isPOS) {
//       _startHardwareScanner();
//     } else {
//       _startCameraScan();
//     }
//   }

//   // POS Hardware Scanner
//   void _startHardwareScanner() {
//     setState(() {
//       _isQrMode = true;
//       _qrFocusNode.requestFocus();
//     });
//   }

//   // Camera Scanner
//   Future<void> _startCameraScan() async {
//     final result = await Navigator.of(context).push<String>(
//       MaterialPageRoute(builder: (_) => const QRCodeScannerScreen()),
//     );

//     if (result != null && result.isNotEmpty) {
//       _handleQrInput(result);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No QR code scanned.'),
//           duration: Duration(seconds: 1),
//         ),
//       );
//     }
//   }

//   // ------------------- QR INPUT HANDLER -------------------
//   void _handleQrInput(String raw) async {
//     if (_isProcessingQr || !_isQrMode) return;
//     setState(() => _isProcessingQr = true);

//     try {
//       final data = _parseQrData(raw);
//       final name = data['Name']?.toString().trim();
//       if (name == null) throw Exception('Name not found');

//       final match = _allEmployees.entries.firstWhereOrNull(
//         (e) => e.key.contains(name),
//       );

//       if (match != null) {
//         _selectEmployee(match.key);
//         _employeeNumberController.selection = TextSelection.fromPosition(
//           TextPosition(offset: match.key.length),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Employee not found in list.')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('QR Error: $e')));
//     } finally {
//       _qrController.clear();
//       _qrFocusNode.unfocus();
//       setState(() {
//         _isProcessingQr = false;
//         _isQrMode = false;
//       });
//     }
//   }

//   // ------------------- QR PARSING -------------------
//   Map<String, dynamic> _parseQrData(String raw) {
//     try {
//       return json.decode(raw) as Map<String, dynamic>;
//     } catch (_) {
//       final map = <String, dynamic>{};
//       raw.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
//         final kv = pair.split(':');
//         if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
//       });
//       if (map.isEmpty) throw Exception('Invalid QR format');
//       return map;
//     }
//   }

//   void _showUpiQrDialog(double amount) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<RazorpayProvider>(context, listen: false).createQR(amount);
//     });

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return PopScope(
//           canPop: true,
//           onPopInvoked: (didPop) {
//             if (mounted) {
//               state.setSubmitting(false);
//             }
//           },
//           child: AlertDialog(
//             backgroundColor: Colors.white,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//             ),
//             title: const Row(
//               children: [
//                 Icon(Icons.qr_code, color: Colors.blue),
//                 SizedBox(width: 8),
//                 Text(
//                   'UPI QR Code',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//             content: SizedBox(
//               height: 600,
//               width: 285,
//               child: Consumer<RazorpayProvider>(
//                 builder: (context, qrProvider, _) {
//                   if (qrProvider.isLoading) {
//                     return const Center(child: CircularProgressIndicator());
//                   } else if (qrProvider.errorMessage != null) {
//                     WidgetsBinding.instance.addPostFrameCallback((_) {
//                       state.setSubmitting(false);
//                     });
//                     return Text(
//                       qrProvider.errorMessage!,
//                       style: const TextStyle(color: Colors.red, fontSize: 16),
//                       textAlign: TextAlign.center,
//                     );
//                   } else if (qrProvider.paymentSuccess) {
//                     WidgetsBinding.instance.addPostFrameCallback((_) {
//                       state.setSubmitting(false);
//                     });
//                     return const Center(
//                       child: Text(
//                         'Payment Successful',
//                         style: TextStyle(fontSize: 20, color: Colors.green),
//                       ),
//                     );
//                   } else if (qrProvider.qrImageUrl != null) {
//                     return Column(
//                       children: [
//                         Image.network(
//                           qrProvider.qrImageUrl!,
//                           height: 535,
//                           width: 300,
//                           fit: BoxFit.fill,
//                         ),
//                         Row(
//                           children: [
//                             Expanded(
//                               child: ElevatedButton.icon(
//                                 icon: const Icon(Icons.close),
//                                 label: const Text("Close"),
//                                 onPressed: () {
//                                   qrProvider.disconnectWebSocket();
//                                   Navigator.pop(context);
//                                 },
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: const Color.fromARGB(
//                                     255,
//                                     6,
//                                     62,
//                                     247,
//                                   ),
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(7),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     );
//                   } else {
//                     return const Center(child: Text('No QR generated'));
//                   }
//                 },
//               ),
//             ),
//           ),
//         );
//       },
//     ).then((_) {
//       if (mounted) state.setSubmitting(false);
//     });
//   }

//   Future<void> _createOrderAndPay() async {
//     final amount = double.tryParse(_customCardController.text);
//     if (amount == null || amount <= 0) {
//       debugPrint("⚠️ Invalid card amount entered: $_customCardController.text");
//       if (mounted) {
//         _showCustomSnackBar('Enter a valid card amount', isSuccess: false);
//       }
//       return;
//     }

//     debugPrint(
//       "💳 Creating Razorpay order for ₹${amount.toStringAsFixed(2)}...",
//     );

//     try {
//       state.setSubmitting(true);
//       final response = await _dio.post(
//         "/fastapi/razorPay/create_order/?price=$amount",
//       );
//       debugPrint("📦 Order Response: ${response.data}");

//       final orderData = response.data;
//       if (orderData == null || orderData['id'] == null) {
//         debugPrint("⚠️ Invalid order response: $orderData");
//         if (mounted) {
//           _showCustomSnackBar(
//             'Invalid order data from server',
//             isSuccess: false,
//           );
//         }
//         state.setSubmitting(false);
//         return;
//       }

//       final razorpayAmount = (amount * 100).toInt();
//       String customerNumber = _customerNumberController.text.trim();

//       final options = {
//         'key': 'rzp_live_RSsJoT9ThF9zms',
//         'amount': razorpayAmount,
//         'name': 'YenKOT Payments',
//         'description': 'Card Payment for ₹${amount.toStringAsFixed(2)}',
//         'order_id': orderData['id'],
//         'prefill': {'contact': customerNumber, 'method': 'card'},
//         'theme': {'color': '#2E86DE', 'backdrop_color': '#ffffff'},
//       };

//       debugPrint("🚀 Opening Razorpay with options: $options");

//       try {
//         _razorpay.open(options);
//         debugPrint("✅ Razorpay window triggered successfully");
//       } catch (e) {
//         debugPrint("❌ Error opening Razorpay: $e");
//         _showCustomSnackBar('Could not open payment window.', isSuccess: false);
//         state.setSubmitting(false);
//       }
//     } on DioException catch (e) {
//       debugPrint("💥 DioException while creating order: ${e.message}");
//       if (mounted) {
//         _showCustomSnackBar('Network issue creating order.', isSuccess: false);
//       }
//       state.setSubmitting(false);
//     } catch (e, stack) {
//       debugPrint("💥 Unexpected error creating order: $e");
//       debugPrint("🧾 Stacktrace: $stack");
//       if (mounted) {
//         _showCustomSnackBar(
//           'Unexpected error while creating order.',
//           isSuccess: false,
//         );
//       }
//       state.setSubmitting(false);
//     }
//   }

//   void _handlePaymentSuccess(PaymentSuccessResponse response) async {
//     state.setSubmitting(true);
//     final verifyData = {
//       "order_id": response.orderId,
//       "payment_id": response.paymentId,
//       "signature": response.signature,
//     };

//     try {
//       final result = await _dio.post(
//         "https://yenerp.com/fastapi/razorPay/verify_payment",
//         data: verifyData,
//       );

//       if (result.data["status"] == "success") {
//         state.setRazorpayPaymentId(response.paymentId);
//         if (mounted) {
//           _showCustomSnackBar(
//             'Amount received! Processing invoice...',
//             isSuccess: true,
//           );
//           _processInvoiceAndPrint();
//         }
//         state.setSubmitting(false);
//       } else {
//         if (mounted) {
//           _showCustomSnackBar('Payment verification failed', isSuccess: false);
//           state.setSubmitting(false);
//         }
//       }
//     } catch (e) {
//       debugPrint("❌ Error verifying payment: $e");
//       if (mounted) {
//         _showCustomSnackBar('Error verifying payment: $e', isSuccess: false);
//         state.setSubmitting(false);
//       }
//     }
//   }

//   void _handlePaymentError(PaymentFailureResponse response) {
//     debugPrint("❌ Payment failed: ${response.code} | ${response.message}");
//     if (mounted) {
//       _showCustomSnackBar(
//         'Payment failed: ${response.message}',
//         isSuccess: false,
//       );
//       state.setSubmitting(false);
//     }
//   }

//   void _handleExternalWallet(ExternalWalletResponse response) {
//     debugPrint("💳 External Wallet: ${response.walletName}");
//     state.setSubmitting(false);
//   }

//   Future<String> generatehiveInvoiceId(String branchName) async {
//     final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
//     final currentDate1 = DateFormat('ddMMyy').format(DateTime.now());

//     var invoiceBox = await Hive.openBox('invoices');

//     String lastInvoiceDate = invoiceBox.get(
//       'lastInvoiceDate',
//       defaultValue: "",
//     );
//     int invoiceCounter = invoiceBox.get('invoiceCounter', defaultValue: 0);

//     if (lastInvoiceDate != currentDate || invoiceCounter == 0) {
//       invoiceCounter = 1;
//     } else {
//       invoiceCounter++;
//     }

//     String hiveInvoiceId =
//         'BM/$branchName $currentDate1 KOTINVOICE${invoiceCounter.toString().padLeft(3, '0')}';

//     await invoiceBox.put('invoiceCounter', invoiceCounter);
//     await invoiceBox.put('lastInvoiceDate', currentDate);

//     return hiveInvoiceId;
//   }

//   void _sendInvoiceDataToServer() async {
//     debugPrint("📦 Preparing and grouping invoice data for server...");

//     final loginProvider = Provider.of<LoginProvider>(context, listen: false);
//     final loggedInUserName = loginProvider.loggedInUserName ?? "";
//     debugPrint("👤 Logged in user: $loggedInUserName");

//     double diningTaxPercentage = getTaxPercentage();

//     Map<String, Map<String, dynamic>> groupedItems = {};
//     List<Map<String, dynamic>> kotAddOns = [];

//     for (var item in widget.items) {
//       if (item.isEmpty) {
//         debugPrint("⚠️ Skipping null or empty item: $item");
//         continue;
//       }

//       print("items are ..... $item");
//       for (int i = 0; i < (item['varianceName']?.length ?? 0); i++) {
//         String variance = item['varianceName']?[i] ?? "";

//         if (!groupedItems.containsKey(variance)) {
//           groupedItems[variance] = {
//             "varianceName": variance,
//             "varianceitemCode": item['varianceitemCode']?[i] ?? "",
//             "itemName": item['itemName']?[i] ?? "",
//             "price": item['price']?[i] ?? 0.0,
//             "qty": 0.0,
//             "weight": 0.0,
//             "amount": 0.0,
//             "tax": diningTaxPercentage,
//             "uom": item['uom']?[i] ?? "",
//           };
//         }

//         groupedItems[variance]!['qty'] += item['qty']?[i] ?? 0.0;
//         groupedItems[variance]!['weight'] += item['weight']?[i] ?? 0.0;
//         groupedItems[variance]!['amount'] += item['amount']?[i] ?? 0.0;

//         if (item.containsKey('config') && item['config'] != null) {
//           for (var configItem in item['config']) {
//             String varianceName = configItem['varianceName'] ?? "";
//             bool isAlreadyAdded = kotAddOns.any(
//               (existingConfig) =>
//                   existingConfig["varianceName"] == varianceName &&
//                   existingConfig["configQty"].toString() ==
//                       configItem["configQty"].toString(),
//             );

//             if (!isAlreadyAdded) {
//               kotAddOns.add({
//                 "varianceName": varianceName,
//                 "weight": configItem['weight'] ?? 0,
//                 "configQty": List.from(configItem['configQty'] ?? []),
//                 "addOn": List.from(configItem['addOn'] ?? []),
//                 "addOnPrice": List.from(configItem['addOnPrice'] ?? []),
//                 "addOnQuantities": List.from(
//                   configItem['addOnQuantities'] ?? [],
//                 ),
//                 "variance": List.from(configItem['variance'] ?? []),
//                 "type": List.from(configItem['type'] ?? []),
//                 "remark": List.from(configItem['remark'] ?? []),
//               });

//               debugPrint(
//                 "➕ Config added: variance=$varianceName, addOns=${configItem['addOn']}, prices=${configItem['addOnPrice']}, qty=${configItem['configQty']}",
//               );
//             }
//           }
//         }
//       }
//     }
//     // print("groupedItems is ${}");
//     final invoiceNo = await generatehiveInvoiceId(widget.branchName);

//     final beforeEmployeeNumber = _employeeNumberController.text.trim();
//     final beforeEmployeeNumberValue = beforeEmployeeNumber.split(' - ');

//     final employeeNumber = beforeEmployeeNumberValue.isNotEmpty
//         ? beforeEmployeeNumberValue[0]
//         : '';
//     final employeeName = beforeEmployeeNumberValue.length > 1
//         ? beforeEmployeeNumberValue[1]
//         : '';

//     final beforeCustomerNumber = _customerNumberController.text.trim();
//     final beforeCustomerNumberValue = beforeCustomerNumber.split(' - ');

//     final customerNumber = beforeCustomerNumberValue.isNotEmpty
//         ? beforeCustomerNumberValue[0]
//         : '';
//     final customerName = beforeCustomerNumberValue.length > 1
//         ? beforeCustomerNumberValue[1]
//         : '';

//     final cashAmount = double.tryParse(_customCashController.text) ?? 0.0;

//     Map<String, dynamic> invoiceData = {
//       "type": "invoiceKOT",
//       "invoiceNo": invoiceNo,
//       "seathiveOrderId": widget.items.first['seathiveOrderId'] ?? "",
//       "varianceitemCode": groupedItems.values
//           .map((item) => item['varianceitemCode'])
//           .toList(),
//       "varianceName": groupedItems.keys.toList(),
//       "itemName": groupedItems.values.map((item) => item['itemName']).toList(),
//       "price": groupedItems.values.map((item) => item['price']).toList(),
//       "qty": groupedItems.values.map((item) => item['qty']).toList(),
//       "weight": groupedItems.values.map((item) => item['weight']).toList(),
//       "amount": groupedItems.values.map((item) => item['amount']).toList(),
//       "tax": groupedItems.values.map((item) => item['tax']).toList(),
//       "uom": groupedItems.values.map((item) => item['uom']).toList(),
//       "totalAmount": widget.totalAmount,
//       "sellingPrice": groupedItems.values.map((item) => item['amount']).toList(),
//       "sellingAmount": groupedItems.values.map((item) => item['amount']).toList(),
//       // "paymentType":""
//       "cash": cashAmount,
//       "card": state.activePaymentMethod == 'Card' ? widget.totalAmount : 0,
//       "upi": state.activePaymentMethod == 'UPI' ? widget.totalAmount : 0,
//       "razorpayPaymentId": state.razorpayPaymentId ?? "",
//       "invoiceDate": DateFormat('dd-MM-yyyy').format(DateTime.now()),
//       "invoiceTime": DateFormat('hh:mm a').format(DateTime.now()),
//       "deviceCode": widget.deviceCode,
//       "branchId": branchId,
//       "branchName": widget.branchName,
//       "aliasName": aliasname,
//       "salesPersonId": loggedInUserName,
//       "salesPersonName": employeeName,
//       "employeeNumber": employeeNumber,
//       "customerPhoneNumber": customerNumber,
//       "sync": "No",
//       "salesType": ordertype,
//       "kotaddOns": kotAddOns,
//       "shiftId": shiftId.value,
//       "gst": groupedItems.values.map((item) => item['tax']).toList(),
//     };

//     debugPrint("✅ Final invoice data prepared: $invoiceData");

//     if (invoiceData['totalAmount'] <= 0.0) {
//       debugPrint(
//         "❌ Invoice data is invalid, total amount is zero or negative.",
//       );
//       if (mounted && _scaffoldMessenger != null) {
//         _showCustomSnackBar(
//           "Invalid invoice data, total amount is zero.",
//           isSuccess: false,
//         );
//       }
//       return;
//     }

//     try {
//       if (_channel == null) {
//         await _initializeWebSocket();
//         if (_channel == null) {
//           throw Exception('Failed to establish WebSocket connection');
//         }
//       }

//       final serializedData = jsonEncode(invoiceData);
//       debugPrint("📤 Sending serialized data: $serializedData");
//       _channel!.sink.add(serializedData);

//       debugPrint("🎉 Invoice data sent to server successfully!");
//     } catch (e) {
//       debugPrint("⚠️ Error sending invoice data: $e");
//       if (mounted && _scaffoldMessenger != null) {
//         _showCustomSnackBar("Error sending invoice data: $e", isSuccess: false);
//       }
//     }
//   }

//   void _processInvoiceAndPrint() async {
//     try {
//       // final printerProvider = Provider.of<PrinterProviderDine>(
//       //   context,
//       //   listen: false,
//       // );
//       final orderProvider = Provider.of<OrderProvider>(context, listen: false);
//       final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);

//       // var printerIp = printerProvider.getInvoicePrinterIp();

//       // if (printerIp == null) {
//       //   await invoicePromptForPrinterIp(context);
//       //   printerIp = printerProvider.getInvoicePrinterIp();
//       //   if (printerIp == null) {
//       //     debugPrint("❌ Printer IP not set.");
//       //     if (mounted && _scaffoldMessenger != null) {
//       //       _showCustomSnackBar("Printer IP not set!", isSuccess: false);
//       //     }
//       //     state.setSubmitting(false);
//       //     return;
//       //   }
//       // }

//       // debugPrint("🚀 Invoice items count: ${widget.items.length}");
//       _sendInvoiceDataToServer();

//       String seathiveOrderId = widget.items.first['seathiveOrderId'] ?? '';
//       String table = widget.items.first['table'] ?? '';
//       String seat = widget.items.first['seat'] ?? '';

//       if (seathiveOrderId.isNotEmpty) {
//         orderProvider.patchOrderStatusBySeathiveOrderId(
//           seathiveOrderId,
//           'invoiced',
//           table,
//           seat,
//         );
//         debugPrint(
//           "✅ Patched order status for sale seatHiveOrderId=$seathiveOrderId",
//         );
//         final timerProvider = Provider.of<TimerProvider>(
//           context,
//           listen: false,
//         );
//         timerProvider.stopTimer(table, seat);
//       }

//       cartProvider.clearCart();

//       Navigator.of(context).pop();

//       // await ReceiptPrinter(
//       //   employeeNumberController: _employeeNumberController,
//       //   seathiveOrderId: seathiveOrderId,
//       //   customerNumberController: _customerNumberController,
//       //   discountController: _discountController,
//       //   customChargeController: _customChargeController,
//       //   selectedPaymentOptionValue: '',
//       //   context: context,
//       //   customAmountController: _customUpiController.text.isNotEmpty
//       //       ? _customUpiController
//       //       : _customCardController,
//       //   selectedPaymentOption: state.activePaymentMethod ?? 'UPI',
//       //   items: widget.items,
//       //   branchName: widget.branchName,
//       //   table: table,
//       //   seat: seat,
//       //   printerProvider: printerProvider,
//       // ).printReceiptDetails();

//       if (mounted && _scaffoldMessenger != null) {
//         debugPrint("Receipt printed.....");
//       } else {
//         debugPrint("⚠️ Widget not mounted or ScaffoldMessenger not available");
//       }

//       if (mounted) {
//         await Future.delayed(const Duration(milliseconds: 500));
//         if (mounted) {
//           Provider.of<BottomNavProvider>(context, listen: false).updateIndex(2);
//           debugPrint("📤 Navigated to TableScreen");
//         }
//       }
//     } catch (e, st) {
//       debugPrint("❌ Error during invoice printing: $e\n$st");
//       if (mounted && _scaffoldMessenger != null) {
//         _showCustomSnackBar("Error: $e", isSuccess: false);
//       }
//     } finally {
//       if (mounted) {
//         state.setSubmitting(false);
//       }
//     }
//   }

//   // NEW UI COMPONENTS

//   Widget _buildPaymentOption(String amount, String method) {
//     return Consumer<SalesInvoicePayAndPrintState>(
//       builder: (context, state, _) {
//         final bool isSelected = state.activePaymentMethod == method;
//         TextEditingController controller;

//         switch (method) {
//           case 'Cash': // Add this case
//             controller = _customCashController;
//             break;
//           case 'UPI':
//             controller = _customUpiController;
//             break;
//           case 'Card':
//             controller = _customCardController;
//             break;
//           default:
//             controller = TextEditingController();
//         }

//         if (amount == 'Custom') {
//           return Padding(
//             padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
//             child: SizedBox(
//               width: 130,
//               height: 50,
//               child: Material(
//                 color: Colors.grey.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//                 child: TextField(
//                   showCursor: true,
//                   readOnly: true,
//                   controller: controller,
//                   focusNode: _getFocusNodeForController(controller),
//                   keyboardType: TextInputType.none,
//                   decoration: InputDecoration(
//                     enabledBorder: OutlineInputBorder(
//                       borderSide: const BorderSide(
//                         color: Colors.white,
//                         width: 1.5,
//                       ),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                       borderSide: const BorderSide(
//                         color: Colors.blue,
//                         width: 1,
//                       ),
//                     ),
//                     border: const OutlineInputBorder(),
//                     filled: isSelected,
//                     hintText: "Enter $method",
//                     fillColor: Colors.white,
//                   ),
//                   onTap: () => {setCurrentFocusForController(controller)},
//                   onChanged: (value) {
//                     if (value.isNotEmpty) {
//                       final amountValue = double.tryParse(value) ?? 0.0;
//                       state.selectPaymentOption(
//                         method,
//                         amountValue,
//                         widget.totalAmount,
//                       );
//                     }
//                   },
//                 ),
//               ),
//             ),
//           );
//         } else {
//           return Padding(
//             padding: const EdgeInsets.all(8),
//             child: GestureDetector(
//               onTap: () {
//                 final amountValue = double.tryParse(amount) ?? 0.0;
//                 state.selectPaymentOption(
//                   method,
//                   amountValue,
//                   widget.totalAmount,
//                 );
//                 controller.text = amount;
//               },
//               child: Container(
//                 height: 40,
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 decoration: BoxDecoration(
//                   color: isSelected ? Colors.blue : Colors.white,
//                   borderRadius: BorderRadius.circular(6),
//                   border: Border.all(
//                     color: isSelected ? Colors.blue : Colors.grey.shade300,
//                     width: 1.5,
//                   ),
//                   boxShadow: [
//                     if (isSelected)
//                       BoxShadow(
//                         color: Colors.blue.withOpacity(0.3),
//                         blurRadius: 4,
//                         offset: const Offset(0, 2),
//                       ),
//                   ],
//                 ),
//                 child: Center(
//                   child: Text(
//                     amount,
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: isSelected ? Colors.white : Colors.blue,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           );
//         }
//       },
//     );
//   }

//   Widget _buildPaymentSection(String method) {
//     double remaining = widget.totalAmount;
//     String exactStr = remaining.toStringAsFixed(0);
//     List<String> extraOptions = [];

//     if (method == 'Cash') {
//       // final stateProvider = Provider.of<SalesInvoiceState>(
//       //   context,
//       //   listen: false,
//       // );
//       // double amountForOptions = stateProvider.balanceAmount > 0
//       //     ? stateProvider.balanceAmount
//       //     : getTotalWithAdjustments();
//       extraOptions = _generateCashOptions(widget.totalAmount).skip(1).toList();
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.start,
//           children: [
//             Text(
//               method,
//               style: const TextStyle(
//                 fontSize: 16,
//                 color: Colors.black,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(width: 20),
//             _buildPaymentOption('Custom', method),
//             _buildPaymentOption(exactStr, method),
//           ],
//         ),
//         if (extraOptions.isNotEmpty)
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.start,
//               children: [
//                 for (var option in extraOptions)
//                   _buildPaymentOption(option, method),
//               ],
//             ),
//           ),
//       ],
//     );
//   }

//   List<String> _generateCashOptions(double amount) {
//     List<String> options = [];
//     int exactAmount = amount.ceil();

//     options.add(exactAmount.toString());

//     List<int> denominations = [1, 2, 5, 10, 20, 50, 100, 200, 500];

//     int roundUpTo(int base, int denomination) {
//       return ((base + denomination - 1) ~/ denomination) * denomination;
//     }

//     for (int denom in denominations) {
//       int next = roundUpTo(exactAmount, denom);
//       if (next > exactAmount) {
//         options.add(next.toString());
//       }
//     }

//     options = options.toSet().toList();
//     options.sort((a, b) => int.parse(a).compareTo(int.parse(b)));

//     return options;
//   }

//   FocusNode _getFocusNodeForController(TextEditingController controller) {
//     int index = _keyboardControllers.indexOf(controller);
//     return index >= 0 ? _focusNodes[index] : FocusNode();
//   }

//   void setCurrentFocusForController(TextEditingController controller) {
//     int index = _keyboardControllers.indexOf(controller);
//     if (index >= 0) {
//       _currentFocusIndexNotifier.value = index;
//       _focusNodes[index].requestFocus();
//     }
//   }

//   void _handleKeyboardTextInput(String text) {
//     final currentIndex = _currentFocusIndexNotifier.value;
//     final currentController = _keyboardControllers[currentIndex];

//     currentController.text = currentController.text + text;
//     currentController.selection = TextSelection.fromPosition(
//       TextPosition(offset: currentController.text.length),
//     );
//   }

//   void _handleKeyboardBackspace() {
//     final currentIndex = _currentFocusIndexNotifier.value;
//     final currentController = _keyboardControllers[currentIndex];

//     if (currentController.text.isNotEmpty) {
//       currentController.text = currentController.text.substring(
//         0,
//         currentController.text.length - 1,
//       );
//       currentController.selection = TextSelection.fromPosition(
//         TextPosition(offset: currentController.text.length),
//       );
//     }
//   }

//   void _handleKeyboardOk() {
//     final currentIndex = _currentFocusIndexNotifier.value;
//     if (currentIndex < _keyboardControllers.length - 1) {
//       _currentFocusIndexNotifier.value = currentIndex + 1;
//       _focusNodes[currentIndex + 1].requestFocus();
//     }
//   }

//   Widget _buildMiniCard({
//     required String title,
//     required String value,
//     required List<Color> gradient,
//   }) {
//     return Expanded(
//       child: Container(
//         height: 80,
//         margin: const EdgeInsets.symmetric(horizontal: 4),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: gradient,
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//           borderRadius: BorderRadius.circular(14),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey[400]!,
//               offset: const Offset(2, 2),
//               blurRadius: 6,
//             ),
//             const BoxShadow(
//               color: Colors.white,
//               offset: Offset(-2, -2),
//               blurRadius: 6,
//             ),
//           ],
//         ),
//         padding: const EdgeInsets.all(8),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             FittedBox(
//               fit: BoxFit.scaleDown,
//               child: Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                   color: Colors.black87,
//                 ),
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//             const SizedBox(height: 4),
//             FittedBox(
//               fit: BoxFit.scaleDown,
//               child: Text(
//                 value,
//                 style: const TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black,
//                 ),
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider.value(value: state),
//         ChangeNotifierProvider(create: (_) => RazorpayProvider()),
//       ],
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         body: Consumer<SalesInvoicePayAndPrintState>(
//           builder: (context, state, _) {
//             return Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text(
//                       'Payment Details',
//                       style: TextStyle(
//                         fontSize: 32,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black,
//                       ),
//                     ),
//                     const SizedBox(height: 15),

//                     /// Sales Person + Birthday Row
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Consumer<SalesInvoicePayAndPrintState>(
//                           builder: (context, p, _) {
//                             return Expanded(
//                               flex: 2,
//                               child: Material(
//                                 elevation: 4,
//                                 shadowColor: Colors.black,
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(8),
//                                 child: Stack(
//                                   children: [
//                                     // ------------------- AUTOCOMPLETE WITH QR -------------------
//                                     Autocomplete<String>(
//                                       optionsMaxHeight: 120,
//                                       optionsViewBuilder:
//                                           (context, onSelected, options) {
//                                             return Material(
//                                               color: Colors.white,
//                                               shadowColor: Colors.black,
//                                               elevation: 4,
//                                               borderRadius:
//                                                   const BorderRadius.only(
//                                                     bottomLeft: Radius.circular(
//                                                       8,
//                                                     ),
//                                                     bottomRight:
//                                                         Radius.circular(8),
//                                                   ),
//                                               child: ListView.separated(
//                                                 separatorBuilder:
//                                                     (context, index) =>
//                                                         const Divider(
//                                                           thickness: 1,
//                                                           color: Colors.black12,
//                                                         ),
//                                                 shrinkWrap: true,
//                                                 itemCount: options.length,
//                                                 itemBuilder: (context, index) {
//                                                   final option = options
//                                                       .elementAt(index);
//                                                   return ListTile(
//                                                     title: Text(option),
//                                                     onTap: () =>
//                                                         onSelected(option),
//                                                   );
//                                                 },
//                                               ),
//                                             );
//                                           },
//                                       optionsBuilder: (textEditingValue) {
//                                         if (textEditingValue.text.isEmpty) {
//                                           return const Iterable<String>.empty();
//                                         }
//                                         final query = textEditingValue.text
//                                             .toLowerCase();
//                                         return _allEmployees.keys.where(
//                                           (key) =>
//                                               key.toLowerCase().contains(query),
//                                         );
//                                       },
//                                       onSelected: (String selection) =>
//                                           _selectEmployee(selection),
//                                       fieldViewBuilder:
//                                           (
//                                             context,
//                                             controllers,
//                                             focusNode,
//                                             onFieldSubmitted,
//                                           ) {
//                                             _employeeNumberController
//                                                 .addListener(() {
//                                                   controllers.value =
//                                                       _employeeNumberController
//                                                           .value;
//                                                 });
//                                             return TextFormField(
//                                               readOnly: true,
//                                               showCursor: true,
//                                               controller:
//                                                   _employeeNumberController,
//                                               focusNode: focusNode,
//                                               onTap: () =>
//                                                   setCurrentFocusForController(
//                                                     _employeeNumberController,
//                                                   ),
//                                               decoration: InputDecoration(
//                                                 labelText: "Sales Person",
//                                                 labelStyle: const TextStyle(
//                                                   fontFamily: 'Poppins',
//                                                   color: Colors.black54,
//                                                 ),
//                                                 border: OutlineInputBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(8),
//                                                 ),
//                                                 focusedBorder:
//                                                     OutlineInputBorder(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             8,
//                                                           ),
//                                                       borderSide:
//                                                           const BorderSide(
//                                                             color: Colors.blue,
//                                                             width: 1,
//                                                           ),
//                                                     ),
//                                                 enabledBorder:
//                                                     OutlineInputBorder(
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             8,
//                                                           ),
//                                                       borderSide:
//                                                           const BorderSide(
//                                                             color:
//                                                                 Colors.black12,
//                                                           ),
//                                                     ),
//                                                 contentPadding:
//                                                     const EdgeInsets.symmetric(
//                                                       vertical: 15,
//                                                       horizontal: 10,
//                                                     ),
//                                                 // QR ICON
//                                                 suffixIcon: IconButton(
//                                                   icon: const Icon(
//                                                     Icons.qr_code_scanner,
//                                                   ),
//                                                   onPressed: _toggleQrMode,
//                                                   tooltip: 'Scan Employee QR',
//                                                 ),
//                                               ),
//                                             );
//                                           },
//                                     ),

//                                     // ------------------- HIDDEN QR FIELD (POS Hardware Scanner) -------------------
//                                     if (_isQrMode)
//                                       Offstage(
//                                         offstage: true,
//                                         child: TextField(
//                                           focusNode: _qrFocusNode,
//                                           controller: _qrController,
//                                           keyboardType: TextInputType.none,
//                                           onSubmitted: _handleQrInput,
//                                           decoration: const InputDecoration(
//                                             border: InputBorder.none,
//                                           ),
//                                           style: const TextStyle(
//                                             fontFamily: 'Poppins',
//                                             fontSize: 0,
//                                           ),
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               controller: _birthdayController,
//                               focusNode: _getFocusNodeForController(
//                                 _birthdayController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _birthdayController,
//                               ),
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               decoration: InputDecoration(
//                                 labelText: "Birthday Date",
//                                 labelStyle: const TextStyle(
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               controller: _customChargeController,
//                               focusNode: _getFocusNodeForController(
//                                 _customChargeController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _customChargeController,
//                               ),
//                               inputFormatters: [
//                                 FilteringTextInputFormatter.digitsOnly,
//                               ],
//                               decoration: InputDecoration(
//                                 prefixText: "₹",
//                                 labelText: "Custom Charge",
//                                 labelStyle: const TextStyle(
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 15),

//                     /// Customer + Discount + Coupon Row
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         SizedBox(
//                           width: 300,
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: CustomerSearchDropdown(
//                               showTopProducts: false,
//                               customerNumberController:
//                                   _customerNumberController,
//                               focusNode: _getFocusNodeForController(
//                                 _customerNumberController,
//                               ),
//                               readOnly: true,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               controller: _discountController,
//                               focusNode: _getFocusNodeForController(
//                                 _discountController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _discountController,
//                               ),
//                               inputFormatters: [
//                                 FilteringTextInputFormatter.digitsOnly,
//                               ],
//                               decoration: InputDecoration(
//                                 prefixIcon: const Icon(Icons.percent),
//                                 labelText: "Discount",
//                                 labelStyle: const TextStyle(
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 20),
//                         Expanded(
//                           child: Material(
//                             elevation: 4,
//                             shadowColor: Colors.black,
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             child: TextField(
//                               showCursor: true,
//                               readOnly: true,
//                               keyboardType: TextInputType.none,
//                               controller: _couponCodeController,
//                               focusNode: _getFocusNodeForController(
//                                 _couponCodeController,
//                               ),
//                               onTap: () => setCurrentFocusForController(
//                                 _couponCodeController,
//                               ),
//                               inputFormatters: [
//                                 FilteringTextInputFormatter.digitsOnly,
//                               ],
//                               decoration: InputDecoration(
//                                 prefixIcon: const Icon(
//                                   Icons.local_offer_outlined,
//                                 ),
//                                 labelText: "Coupon Code",
//                                 labelStyle: const TextStyle(
//                                   color: Colors.black54,
//                                 ),
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 focusedBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.blue,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 enabledBorder: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                   borderSide: const BorderSide(
//                                     color: Colors.black12,
//                                   ),
//                                 ),
//                                 contentPadding: const EdgeInsets.symmetric(
//                                   vertical: 15,
//                                   horizontal: 10,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 15),

//                     /// Payment Section + Numeric Keyboard
//                     Row(
//                       children: [
//                         Expanded(
//                           flex: 2,
//                           child: Column(
//                             children: [
//                               Padding(
//                                 padding: const EdgeInsets.only(
//                                   left: 5,
//                                   bottom: 10,
//                                 ),
//                                 child: Material(
//                                   elevation: 4,
//                                   shadowColor: Colors.black,
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.circular(8),
//                                   child: Padding(
//                                     padding: const EdgeInsets.only(left: 10),
//                                     child: _buildPaymentSection(
//                                       'Cash',
//                                     ), // Add this
//                                   ),
//                                 ),
//                               ),
//                               Padding(
//                                 padding: const EdgeInsets.only(
//                                   left: 5,
//                                   bottom: 10,
//                                 ),
//                                 child: Material(
//                                   elevation: 4,
//                                   shadowColor: Colors.black,
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.circular(8),
//                                   child: Padding(
//                                     padding: const EdgeInsets.only(left: 10),
//                                     child: _buildPaymentSection('UPI'),
//                                   ),
//                                 ),
//                               ),
//                               Padding(
//                                 padding: const EdgeInsets.only(
//                                   left: 5,
//                                   bottom: 10,
//                                 ),
//                                 child: Material(
//                                   elevation: 4,
//                                   shadowColor: Colors.black,
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.circular(8),
//                                   child: Padding(
//                                     padding: const EdgeInsets.only(left: 10),
//                                     child: _buildPaymentSection('Card'),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const VerticalDivider(width: 15, thickness: 1),
//                         Expanded(
//                           flex: 2,
//                           child: ValueListenableBuilder<int>(
//                             valueListenable: _currentFocusIndexNotifier,
//                             builder: (context, currentFocusIndex, _) {
//                               return Column(
//                                 children: [
//                                   Container(
//                                     constraints: const BoxConstraints(
//                                       maxWidth: 300,
//                                     ),
//                                     child: NumericKeyboard(
//                                       focusNode: _focusNodes[currentFocusIndex],
//                                       controller:
//                                           _keyboardControllers[currentFocusIndex],
//                                       onTextInput: _handleKeyboardTextInput,
//                                       onBackspace: _handleKeyboardBackspace,
//                                       onOk: _handleKeyboardOk,
//                                       isLastField:
//                                           currentFocusIndex ==
//                                           _keyboardControllers.length - 1,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 10),
//                                 ],
//                               );
//                             },
//                           ),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 10),

//                     /// Mini Cards + Print Button
//                     Row(
//                       children: [
//                         _buildMiniCard(
//                           title: "Total",
//                           value: "₹${widget.totalAmount.toStringAsFixed(0)}",
//                           gradient: [Colors.blue[200]!, Colors.blue[500]!],
//                         ),
//                         const SizedBox(width: 5),
//                         _buildMiniCard(
//                           title: "Balance",
//                           value: state.balanceAmount < 0
//                               ? "-₹${state.balanceAmount.abs().toStringAsFixed(0)}"
//                               : "₹${state.balanceAmount.toStringAsFixed(0)}",
//                           gradient: [Colors.blue[200]!, Colors.blue[500]!],
//                         ),
//                         const SizedBox(width: 10),
//                         SizedBox(
//                           height: 75,
//                           width: 300,
//                           child: ElevatedButton(
//                             style: ButtonStyle(
//                               backgroundColor: MaterialStateProperty.all(
//                                 state.balanceAmount <= 0
//                                     ? Colors.blue
//                                     : Colors.grey,
//                               ),
//                               foregroundColor: MaterialStateProperty.all(
//                                 Colors.white,
//                               ),
//                               padding: MaterialStateProperty.all(
//                                 const EdgeInsets.symmetric(
//                                   horizontal: 30.0,
//                                   vertical: 18.0,
//                                 ),
//                               ),
//                               shape:
//                                   MaterialStateProperty.all<
//                                     RoundedRectangleBorder
//                                   >(
//                                     RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(8.0),
//                                     ),
//                                   ),
//                               elevation: MaterialStateProperty.all(5.0),
//                             ),
//                             onPressed:
//                                 (state.isSubmitting || state.balanceAmount > 0)
//                                 ? null
//                                 : () async {
//                                     // ordersBox = await Hive.openBox('orders');
//                                     // print("OrderBox od orders are ${ordersBox.values}");
//                                     // print("OrderBox od orders are ${ordersBox.length}");
//                                     _processInvoiceAndPrint();
//                                     // _sendInvoiceDataToServer();

//                                     //     _sendInvoiceDataToServer();
//                                     // state.setSubmitting(true);

//                                     //     final cashAmount =
//                                     //         double.tryParse(
//                                     //           _customCashController.text,
//                                     //         ) ??
//                                     //         0.0; // Add this

//                                     //     print("cashAmount is : $cashAmount");
//                                     //     final upiAmount =
//                                     //         double.tryParse(
//                                     //           _customUpiController.text,
//                                     //         ) ??
//                                     //         0.0;
//                                     //     final cardAmount =
//                                     //         double.tryParse(
//                                     //           _customCardController.text,
//                                     //         ) ??
//                                     //         0.0;
//                                     //     final totalEntered =
//                                     //         cashAmount +
//                                     //         upiAmount +
//                                     //         cardAmount; // Update this

//                                     //     if (totalEntered != widget.totalAmount) {
//                                     //       if (mounted &&
//                                     //           _scaffoldMessenger != null) {
//                                     //         _showCustomSnackBar(
//                                     //           "Entered amount must equal total amount.",
//                                     //           isSuccess: false,
//                                     //         );
//                                     //       }
//                                     //       state.setSubmitting(false);
//                                     //       return;
//                                     //     }

//                                     //     final printerProvider =
//                                     //         Provider.of<PrinterProviderDine>(
//                                     //           context,
//                                     //           listen: false,
//                                     //         );
//                                     //     var printerIp = printerProvider
//                                     //         .getInvoicePrinterIp();

//                                     //     if (printerIp == null) {
//                                     //       await invoicePromptForPrinterIp(context);
//                                     //       printerIp = printerProvider
//                                     //           .getInvoicePrinterIp();

//                                     //       if (printerIp == null) {
//                                     //         debugPrint("❌ Printer IP not set.");
//                                     //         if (mounted &&
//                                     //             _scaffoldMessenger != null) {
//                                     //           _showCustomSnackBar(
//                                     //             "Printer IP not set!",
//                                     //             isSuccess: false,
//                                     //           );
//                                     //         }
//                                     //         state.setSubmitting(false);
//                                     //         return;
//                                     //       }
//                                     //     }

//                                     //         if (state.activePaymentMethod == 'UPI') {
//                                     //           final upiProvider =
//                                     //               Provider.of<UpiProviderDine>(
//                                     //                 context,
//                                     //                 listen: false,
//                                     //               );

//                                     //           if (!upiProvider.isUpiEnabled) {
//                                     //             _showCustomSnackBar(
//                                     //               "UPI payment is currently disabled!",
//                                     //               isSuccess: false,
//                                     //             );
//                                     //             state.setSubmitting(false);
//                                     //             return;
//                                     //           }

//                                     //           _showUpiQrDialog(upiAmount);
//                                     //         } else if (state.activePaymentMethod ==
//                                     //             'Card') {
//                                     //           final customerNumber =
//                                     //               _customerNumberController.text.trim();
//                                     //           if (customerNumber.isEmpty) {
//                                     //             _showCustomSnackBar(
//                                     //               "Please enter customer number before card payment.",
//                                     //               isSuccess: false,
//                                     //             );
//                                     //             state.setSubmitting(false);
//                                     //             return;
//                                     //           } else if (customerNumber.length != 10) {
//                                     //             _showCustomSnackBar(
//                                     //               "Customer number must be 10 digits.",
//                                     //               isSuccess: false,
//                                     //             );
//                                     //             state.setSubmitting(false);
//                                     //             return;
//                                     //           }

//                                     //           _createOrderAndPay();
//                                     //         } else {
//                                     //           _showCustomSnackBar(
//                                     //             "Please select a payment method.",
//                                     //             isSuccess: false,
//                                     //           );
//                                     // state.setSubmitting(false);
//                                     //         }
//                                   },
//                             child: Text(
//                               state.isSubmitting
//                                   ? "Processing..."
//                                   : "Proceed to payment",
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 10),
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// class NumericKeyboard extends StatelessWidget {
//   final FocusNode focusNode;
//   final TextEditingController controller;
//   final Function(String)? onTextInput;
//   final VoidCallback? onBackspace;
//   final VoidCallback? onOk;
//   final bool isLastField;

//   const NumericKeyboard({
//     super.key,
//     required this.focusNode,
//     required this.controller,
//     this.onTextInput,
//     this.onBackspace,
//     this.onOk,
//     this.isLastField = false,
//   });

//   void _textInputHandler(String text) {
//     if (onTextInput != null) {
//       onTextInput!(text);
//     } else {
//       final currentText = controller.text;
//       final newText = currentText + text;
//       controller.text = newText;
//       controller.selection = TextSelection.collapsed(offset: newText.length);
//     }
//   }

//   void _backspaceHandler() {
//     if (onBackspace != null) {
//       onBackspace!();
//     } else {
//       final currentText = controller.text;
//       if (currentText.isNotEmpty) {
//         final newText = currentText.substring(0, currentText.length - 1);
//         controller.text = newText;
//         controller.selection = TextSelection.collapsed(offset: newText.length);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildKey('7', () => _textInputHandler('7')),
//             _buildKey('8', () => _textInputHandler('8')),
//             _buildKey('9', () => _textInputHandler('9')),
//           ],
//         ),
//         const SizedBox(height: 6),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildKey('4', () => _textInputHandler('4')),
//             _buildKey('5', () => _textInputHandler('5')),
//             _buildKey('6', () => _textInputHandler('6')),
//           ],
//         ),
//         const SizedBox(height: 6),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildKey('1', () => _textInputHandler('1')),
//             _buildKey('2', () => _textInputHandler('2')),
//             _buildKey('3', () => _textInputHandler('3')),
//           ],
//         ),
//         const SizedBox(height: 6),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildKey('0', () => _textInputHandler('0')),
//             _buildKey('C', () {
//               controller.clear();
//               if (onTextInput != null) onTextInput!('');
//             }),
//             _buildKey('⌫', _backspaceHandler),
//           ],
//         ),
//         const SizedBox(height: 6),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [_buildKey('OK', onOk ?? () {}, isAction: true, flex: 1)],
//         ),
//       ],
//     );
//   }

//   Widget _buildKey(
//     String label,
//     VoidCallback onPressed, {
//     int flex = 1,
//     bool isAction = false,
//     bool isEnabled = true,
//   }) {
//     return Expanded(
//       flex: flex,
//       child: Container(
//         margin: const EdgeInsets.all(4),
//         child: ElevatedButton(
//           onPressed: isEnabled ? onPressed : null,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: isAction ? Colors.blue : Colors.white,
//             foregroundColor: isAction ? Colors.white : Colors.black,
//             padding: const EdgeInsets.symmetric(vertical: 12),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(8),
//               side: BorderSide(color: Colors.grey.shade300),
//             ),
//             disabledBackgroundColor: Colors.grey[200],
//             disabledForegroundColor: Colors.grey[400],
//           ),
//           child: Text(
//             label,
//             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:yenpos/Global/Provider/bottomNavprovider.dart';
import 'package:yenpos/Global/Screen/camera_qr_screen.dart';
import 'package:yenpos/Global/pos_detector.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/customer_search.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/invoiceNumberGenerator.dart';
import 'package:yenpos/kotpreinvoice/providers/cartprovider.dart';
import 'package:yenpos/kotpreinvoice/providers/timerProvider.dart';
import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
import 'package:yenpos/regular_mode_page/widget/emp_search.dart';
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
  bool _isUpiPaid = false;
  bool _isCardPaid = false;
  bool _isSelected = false;

  double get balanceAmount => _balanceAmount;
  bool get isSubmitting => _isSubmitting;
  double get paymentAmount => _paymentAmount;
  String? get activePaymentMethod => _activePaymentMethod;
  String? get razorpayPaymentId => _razorpayPaymentId;
  bool get isUpiPaid => _isUpiPaid;
  bool get isCardPaid => _isCardPaid;

  bool get isSelected => _isSelected;

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
    _isUpiPaid = false;
    _isCardPaid = false;
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

  void setSelected(bool value) {
    _isSelected = value;
    debugPrint("⏳ Submitting state: $_isSelected");
    notifyListeners();
  }

  void updateIsUpiPaid(bool value) {
    _isUpiPaid = value;
    notifyListeners();
  }

  void updateIsCardPaid(bool value) {
    _isCardPaid = value;
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
  final TextEditingController _couponCodeController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _customCashController = TextEditingController();

  Map<String, Map<String, dynamic>> _allEmployees = {};

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
  List<String> cashOptions = [];

  late List<FocusNode> _focusNodes;
  late ValueNotifier<int> _currentFocusIndexNotifier;
  late List<TextEditingController> _keyboardControllers;
  late Box ordersBox;

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
    _loadEmployees();
    state.updateBalance(totalAmount: widget.totalAmount, payment: 0);

    if (widget.items.isNotEmpty && widget.items.first.containsKey('waiter')) {
      _employeeNumberController.text = widget.items.first['waiter'] ?? '';
    }
    if (widget.items.isNotEmpty &&
        widget.items.first.containsKey('customerPhoneNumber')) {
      _customerNumberController.text =
          widget.items.first['customerPhoneNumber'] ?? '';
    }

    // Setup controllers and focus nodes
    _keyboardControllers = [
      _employeeNumberController,
      _customerNumberController,
      _discountController,
      _customChargeController,
      _customCashController,
      _customUpiController,
      _customCardController,
      _couponCodeController,
      _birthdayController,
    ];

    _focusNodes = List.generate(
      _keyboardControllers.length,
      (_) => FocusNode(),
    );
    _currentFocusIndexNotifier = ValueNotifier<int>(0);

    // Listen to focus changes
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          _currentFocusIndexNotifier.value = i;
        }
      });
    }

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _initializeWebSocket();

    // Generate initial cash options
    cashOptions.addAll(_generateCashOptions(widget.totalAmount));
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
    _couponCodeController.dispose();
    _birthdayController.dispose();
    _paymentStatusTimer?.cancel();
    _razorpay.clear();

    // Dispose focus nodes
    for (final node in _focusNodes) {
      node.dispose();
    }
    _currentFocusIndexNotifier.dispose();

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
    final cashAmount = double.tryParse(_customCashController.text) ?? 0.0;
    final upiAmount = double.tryParse(_customUpiController.text) ?? 0.0;
    final cardAmount = double.tryParse(_customCardController.text) ?? 0.0;
    final totalEntered = cashAmount + upiAmount + cardAmount;
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

  Future<void> _loadEmployees() async {
    var box = await Hive.openBox('employeeBox');
    List<dynamic> employees = box.get('employees', defaultValue: []);
    _allEmployees = {
      for (var emp in employees)
        '${(emp as Map)["employeeNumber"]} - ${(emp as Map)["firstName"]}':
            (emp as Map).cast<String, dynamic>(),
    };
  }

  void _selectEmployee(String selection) {
    final employee = _allEmployees[selection];
    if (employee != null) {
      final stateProvider = Provider.of<SalesInvoiceState>(
        context,
        listen: false,
      );

      stateProvider.updateMultiple(
        selectedEmployeeFirstName: employee['firstName'],
        selectedEmployeeNumber: employee['employeeNumber'],
      );

      _employeeNumberController.text = selection;
    }
  }

  bool _isQrMode = false;
  final FocusNode _qrFocusNode = FocusNode();
  final TextEditingController _qrController = TextEditingController();
  bool _isProcessingQr = false;

  Future<void> _toggleQrMode() async {
    final isPOS = await POSDetector.isPOSDevice;

    if (isPOS) {
      _startHardwareScanner();
    } else {
      _startCameraScan();
    }
  }

  void _startHardwareScanner() {
    setState(() {
      _isQrMode = true;
      _qrFocusNode.requestFocus();
    });
  }

  Future<void> _startCameraScan() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QRCodeScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      _handleQrInput(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No QR code scanned.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _handleQrInput(String raw) async {
    if (_isProcessingQr || !_isQrMode) return;
    setState(() => _isProcessingQr = true);

    try {
      final data = _parseQrData(raw);
      final name = data['Name']?.toString().trim();
      if (name == null) throw Exception('Name not found');

      final match = _allEmployees.entries.firstWhereOrNull(
        (e) => e.key.contains(name),
      );

      if (match != null) {
        _selectEmployee(match.key);
        _employeeNumberController.selection = TextSelection.fromPosition(
          TextPosition(offset: match.key.length),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee not found in list.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QR Error: $e')));
    } finally {
      _qrController.clear();
      _qrFocusNode.unfocus();
      setState(() {
        _isProcessingQr = false;
        _isQrMode = false;
      });
    }
  }

  Map<String, dynamic> _parseQrData(String raw) {
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      final map = <String, dynamic>{};
      raw.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
        final kv = pair.split(':');
        if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
      });
      if (map.isEmpty) throw Exception('Invalid QR format');
      return map;
    }
  }

  // 🔵 CASH VALIDATION METHODS
  double getRemainingForMethod(String method) {
    final totalAmount = widget.totalAmount;
    double otherPayments = 0.0;

    if (method != 'Cash') {
      otherPayments += double.tryParse(_customCashController.text) ?? 0.0;
    }
    if (method != 'UPI') {
      otherPayments += double.tryParse(_customUpiController.text) ?? 0.0;
    }
    if (method != 'Card') {
      otherPayments += double.tryParse(_customCardController.text) ?? 0.0;
    }

    return totalAmount - otherPayments;
  }

  void _selectPaymentOption(String method, String amount) {
    double selectedAmount = double.tryParse(amount) ?? 0.0;

    // VALIDATION FOR ALL METHODS
    if (selectedAmount == 0) {
      // Clear this payment method
      switch (method) {
        case "Cash":
          _customCashController.text = '';
          break;
        case "UPI":
          _customUpiController.text = '';
          state.updateIsUpiPaid(false);
          break;
        case "Card":
          _customCardController.text = '';
          final qrProvider = Provider.of<RazorpayProvider>(
            context,
            listen: false,
          );
          // Reset card payment status if needed
          break;
      }
      _updateBalance();
      return;
    }

    // VALIDATION FOR UPI/CARD
    if (method == "UPI" || method == "Card") {
      double remainingBalance = getRemainingForMethod(method);

      if (selectedAmount > remainingBalance + 0.01) {
        String methodName = method == "UPI" ? "UPI" : "Card";
        _showCustomSnackBar(
          "$methodName payment cannot exceed ₹${remainingBalance.toStringAsFixed(0)}",
          isSuccess: false,
        );

        selectedAmount = remainingBalance;
        amount = remainingBalance.toStringAsFixed(0);

        if (method == "UPI") {
          _customUpiController.text = amount;
        } else {
          _customCardController.text = amount;
        }
      }

      if (selectedAmount < 0) {
        _showCustomSnackBar(
          "$method amount cannot be negative",
          isSuccess: false,
        );
        selectedAmount = 0;
        amount = '0';

        if (method == "UPI") {
          _customUpiController.text = '';
        } else {
          _customCardController.text = '';
        }
        return;
      }
    }
    // VALIDATION FOR CASH
    else if (method == "Cash") {
      double remainingBalance = getRemainingForMethod(method);

      if (selectedAmount > remainingBalance + 5000) {
        _showCustomSnackBar(
          "Cash amount seems very high. Please double-check.",
          isSuccess: false,
        );
      }

      if (selectedAmount < 0) {
        _showCustomSnackBar("Cash amount cannot be negative", isSuccess: false);
        selectedAmount = 0;
        amount = '0';
        _customCashController.text = '';
        return;
      }
    }

    // UPDATE THE FIELD
    switch (method) {
      case "Cash":
        _customCashController.text = selectedAmount.toStringAsFixed(0);
        break;
      case "UPI":
        _customUpiController.text = selectedAmount.toStringAsFixed(0);
        break;
      case "Card":
        _customCardController.text = selectedAmount.toStringAsFixed(0);
        break;
    }

    // UPDATE STATE
    state.selectPaymentOption(method, selectedAmount, widget.totalAmount);
  }

  void _clearAllPayments({bool showSnackBar = true}) {
    _customCashController.clear();
    _customUpiController.clear();
    _customCardController.clear();

    state.resetPaymentState(widget.totalAmount);

    if (showSnackBar && mounted) {
      _showCustomSnackBar("Payments cleared", isSuccess: false);
    }
  }

  void _processControllerChange(TextEditingController controller) {
    if (controller == _customCashController) {
      _selectPaymentOption(
        'Cash',
        controller.text.isEmpty ? '0' : controller.text,
      );
    } else if (controller == _customUpiController) {
      _selectPaymentOption(
        'UPI',
        controller.text.isEmpty ? '0' : controller.text,
      );
    } else if (controller == _customCardController) {
      _selectPaymentOption(
        'Card',
        controller.text.isEmpty ? '0' : controller.text,
      );
    } else if (controller == _discountController ||
        controller == _customChargeController) {
      _clearAllPayments(showSnackBar: false);
    }
  }

  void _updateBalance() {
    final cashAmount = double.tryParse(_customCashController.text) ?? 0.0;
    final upiAmount = double.tryParse(_customUpiController.text) ?? 0.0;
    final cardAmount = double.tryParse(_customCardController.text) ?? 0.0;

    final totalPayments = cashAmount + upiAmount + cardAmount;

    state.updateBalance(
      totalAmount: widget.totalAmount,
      payment: totalPayments,
      method: state.activePaymentMethod,
    );

    // Regenerate cash options based on remaining balance
    double remainingBalance = widget.totalAmount - totalPayments;
    if (remainingBalance < 0) remainingBalance = 0;
    cashOptions.clear();
    cashOptions.addAll(_generateCashOptions(remainingBalance));
  }

  List<String> _generateCashOptions(double amount) {
    if (amount <= 0) return ['0'];

    List<String> options = [];
    int exactAmount = amount.ceil();
    options.add(exactAmount.toString());

    List<int> denominations = [1, 2, 5, 10, 20, 50, 100, 200, 500];
    int roundUpTo(int base, int denomination) {
      return ((base + denomination - 1) ~/ denomination) * denomination;
    }

    for (int denom in denominations) {
      int next = roundUpTo(exactAmount, denom);
      if (next > exactAmount) {
        options.add(next.toString());
      }
    }

    options = options.toSet().toList();
    options.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return options;
  }

  void _handleKeyboardTextInput(String text) {
    final currentIndex = _currentFocusIndexNotifier.value;
    final currentController = _keyboardControllers[currentIndex];

    if (currentController.text == "0" || currentController.text.isEmpty) {
      currentController.text = text;
    } else {
      currentController.text = currentController.text + text;
    }

    currentController.selection = TextSelection.fromPosition(
      TextPosition(offset: currentController.text.length),
    );

    _processControllerChange(currentController);
  }

  void _handleKeyboardBackspace() {
    final currentIndex = _currentFocusIndexNotifier.value;
    final currentController = _keyboardControllers[currentIndex];

    if (currentController.text.isNotEmpty) {
      currentController.text = currentController.text.substring(
        0,
        currentController.text.length - 1,
      );
      currentController.selection = TextSelection.fromPosition(
        TextPosition(offset: currentController.text.length),
      );
    }

    _processControllerChange(currentController);
  }

  void _handleKeyboardOk() {
    final currentIndex = _currentFocusIndexNotifier.value;
    if (currentIndex < _keyboardControllers.length - 1) {
      _currentFocusIndexNotifier.value = currentIndex + 1;
      _focusNodes[currentIndex + 1].requestFocus();
    }
  }

  // REST OF YOUR EXISTING METHODS (UpiQrDialog, createOrderAndPay, etc.)
  void _showUpiQrDialog(double amount) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RazorpayProvider>(context, listen: false).createQR(amount);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) {
            if (mounted) {
              state.setSubmitting(false);
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
                      state.setSubmitting(false);
                    });
                    return Text(
                      qrProvider.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    );
                  } else if (qrProvider.paymentSuccess) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      state.setSubmitting(false);
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
      if (mounted) state.setSubmitting(false);
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
      state.setSubmitting(true);
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
        state.setSubmitting(false);
        return;
      }

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
      state.setSubmitting(false);
    } catch (e, stack) {
      debugPrint("💥 Unexpected error creating order: $e");
      debugPrint("🧾 Stacktrace: $stack");
      if (mounted) {
        _showCustomSnackBar(
          'Unexpected error while creating order.',
          isSuccess: false,
        );
      }
      state.setSubmitting(false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    state.setSubmitting(true);
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
        state.setSubmitting(false);
      } else {
        if (mounted) {
          _showCustomSnackBar('Payment verification failed', isSuccess: false);
          state.setSubmitting(false);
        }
      }
    } catch (e) {
      debugPrint("❌ Error verifying payment: $e");
      if (mounted) {
        _showCustomSnackBar('Error verifying payment: $e', isSuccess: false);
        state.setSubmitting(false);
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
    state.setSubmitting(false);
  }

  // ... (Keep all your existing methods like generatehiveInvoiceId, _sendInvoiceDataToServer, etc.)

  // NEW UI COMPONENTS
  Widget _buildPaymentOption(String amount, String method) {
    return Consumer<SalesInvoicePayAndPrintState>(
      builder: (context, state, _) {
        final bool isSelected = state.activePaymentMethod == method;
        TextEditingController controller;

        switch (method) {
          case 'Cash':
            controller = _customCashController;
            break;
          case 'UPI':
            controller = _customUpiController;
            break;
          case 'Card':
            controller = _customCardController;
            break;
          default:
            controller = TextEditingController();
        }

        bool isPaid =
            (method == 'UPI' && state.isUpiPaid) ||
            (method == 'Card' && state.isCardPaid);

        if (amount == 'Custom') {
          return Padding(
            padding: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
            child: SizedBox(
              width: 130,
              height: 50,
              child: Material(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        showCursor: true,
                        readOnly: false,
                        enabled: !isPaid,
                        controller: controller,
                        focusNode: _getFocusNodeForController(controller),
                        keyboardType: TextInputType.none,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 1,
                            ),
                          ),
                          border: const OutlineInputBorder(),
                          filled: isSelected,
                          hintText: isPaid ? "Paid" : "Enter $method",
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          if (!isPaid) {
                            _selectPaymentOption(
                              method,
                              value.isEmpty ? '0' : value,
                            );
                          }
                        },
                        onTap: () {
                          if (!isPaid) {
                            setCurrentFocusForController(controller);
                          }
                        },
                      ),
                    ),
                    if (method == 'UPI' || method == 'Card')
                      IconButton(
                        icon: Icon(
                          method == 'UPI' ? Icons.qr_code : Icons.credit_card,
                          color: isPaid
                              ? Colors.grey
                              : (method == 'UPI' ? Colors.black : Colors.blue),
                          size: 24,
                        ),
                        onPressed: !isPaid
                            ? () {
                                final amountStr = controller.text;
                                if (amountStr.isNotEmpty) {
                                  final amount = double.tryParse(amountStr);
                                  if (amount != null && amount > 0) {
                                    if (method == 'UPI') {
                                      _showUpiQrDialog(amount);
                                    } else {
                                      _createOrderAndPay();
                                    }
                                  } else {
                                    _showCustomSnackBar(
                                      "Please enter a valid $method amount greater than 0",
                                      isSuccess: false,
                                    );
                                  }
                                } else {
                                  _showCustomSnackBar(
                                    "Please enter a $method amount first",
                                    isSuccess: false,
                                  );
                                }
                              }
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: isPaid
                  ? null
                  : () {
                      _selectPaymentOption(method, amount);
                    },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.grey
                      : (isSelected ? Colors.blue : Colors.white),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPaid
                        ? Colors.grey
                        : (isSelected ? Colors.blue : Colors.grey.shade300),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (isSelected && !isPaid)
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Center(
                  child: Text(
                    amount,
                    style: TextStyle(
                      fontSize: 14,
                      color: isPaid
                          ? Colors.white
                          : (isSelected ? Colors.white : Colors.blue),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildPaymentSection(String method) {
    double remaining = getRemainingForMethod(method);
    String exactStr = remaining > 0 ? remaining.toStringAsFixed(0) : '0';

    List<String> extraOptions = [];
    if (method == 'Cash') {
      double amountForOptions = state.balanceAmount > 0
          ? state.balanceAmount
          : 0.0;
      extraOptions = _generateCashOptions(amountForOptions).skip(1).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              method,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 20),
            _buildPaymentOption('Custom', method),
            _buildPaymentOption(exactStr, method),
          ],
        ),
        if (method == 'Cash' && extraOptions.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                for (var option in extraOptions)
                  _buildPaymentOption(option, method),
              ],
            ),
          ),
      ],
    );
  }

  FocusNode _getFocusNodeForController(TextEditingController controller) {
    int index = _keyboardControllers.indexOf(controller);
    return index >= 0 ? _focusNodes[index] : FocusNode();
  }

  void setCurrentFocusForController(TextEditingController controller) {
    int index = _keyboardControllers.indexOf(controller);
    if (index >= 0) {
      _currentFocusIndexNotifier.value = index;
      _focusNodes[index].requestFocus();

      // Auto-fill UPI/Card with remaining amount when focused
      if (controller == _customUpiController && controller.text.isEmpty) {
        double remaining = getRemainingForMethod('UPI');
        if (remaining > 0) {
          _selectPaymentOption('UPI', remaining.toStringAsFixed(0));
        }
      } else if (controller == _customCardController &&
          controller.text.isEmpty) {
        double remaining = getRemainingForMethod('Card');
        if (remaining > 0) {
          _selectPaymentOption('Card', remaining.toStringAsFixed(0));
        }
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider(create: (_) => RazorpayProvider()),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Consumer<SalesInvoicePayAndPrintState>(
          builder: (context, state, _) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 15),

                    /// Sales Person + Birthday Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Consumer<SalesInvoicePayAndPrintState>(
                          builder: (context, p, _) {
                            return Expanded(
                              flex: 2,
                              child: Material(
                                elevation: 4,
                                shadowColor: Colors.black,
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    Autocomplete<String>(
                                      optionsMaxHeight: 120,
                                      optionsViewBuilder:
                                          (context, onSelected, options) {
                                            return Material(
                                              color: Colors.white,
                                              shadowColor: Colors.black,
                                              elevation: 4,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    bottomLeft: Radius.circular(
                                                      8,
                                                    ),
                                                    bottomRight:
                                                        Radius.circular(8),
                                                  ),
                                              child: ListView.separated(
                                                separatorBuilder:
                                                    (context, index) =>
                                                        const Divider(
                                                          thickness: 1,
                                                          color: Colors.black12,
                                                        ),
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                itemBuilder: (context, index) {
                                                  final option = options
                                                      .elementAt(index);
                                                  return ListTile(
                                                    title: Text(option),
                                                    onTap: () =>
                                                        onSelected(option),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                      optionsBuilder: (textEditingValue) {
                                        if (textEditingValue.text.isEmpty) {
                                          return const Iterable<String>.empty();
                                        }
                                        final query = textEditingValue.text
                                            .toLowerCase();
                                        return _allEmployees.keys.where(
                                          (key) =>
                                              key.toLowerCase().contains(query),
                                        );
                                      },
                                      onSelected: (String selection) => {
                                        _selectEmployee(selection),
                                        p.setSelected(true),
                                      },
                                      fieldViewBuilder:
                                          (
                                            context,
                                            controllers,
                                            focusNode,
                                            onFieldSubmitted,
                                          ) {
                                            _employeeNumberController
                                                .addListener(() {
                                                  controllers.value =
                                                      _employeeNumberController
                                                          .value;
                                                });
                                            return TextFormField(
                                              readOnly: true,
                                              showCursor: true,
                                              controller:
                                                  _employeeNumberController,
                                              focusNode: focusNode,
                                              onTap: () =>
                                                  setCurrentFocusForController(
                                                    _employeeNumberController,
                                                  ),
                                              decoration: InputDecoration(
                                                labelText: "Sales person",
                                                labelStyle: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.black54,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Colors.blue,
                                                            width: 1,
                                                          ),
                                                    ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color:
                                                                Colors.black12,
                                                          ),
                                                    ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 15,
                                                      horizontal: 10,
                                                    ),
                                                suffixIcon: IconButton(
                                                  icon: const Icon(
                                                    Icons.qr_code_scanner,
                                                  ),
                                                  onPressed: _toggleQrMode,
                                                  tooltip: 'Scan Employee QR',
                                                ),
                                              ),
                                            );
                                          },
                                    ),

                                    if (_isQrMode)
                                      Offstage(
                                        offstage: true,
                                        child: TextField(
                                          focusNode: _qrFocusNode,
                                          controller: _qrController,
                                          keyboardType: TextInputType.none,
                                          onSubmitted: _handleQrInput,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                          ),
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 0,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: true,
                            child: Material(
                              elevation: 4,
                              shadowColor: Colors.black,
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              child: TextField(
                                showCursor: true,
                                controller: _birthdayController,
                                focusNode: _getFocusNodeForController(
                                  _birthdayController,
                                ),
                                onTap: () => setCurrentFocusForController(
                                  _birthdayController,
                                ),
                                readOnly: true,
                                keyboardType: TextInputType.none,
                                decoration: InputDecoration(
                                  labelText: "Birthday Date",
                                  labelStyle: const TextStyle(
                                    color: Colors.black54,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black12,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: true,
                            child: Material(
                              elevation: 4,
                              shadowColor: Colors.black,
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              child: TextField(
                                showCursor: true,
                                readOnly: true,
                                keyboardType: TextInputType.none,
                                controller: _customChargeController,
                                focusNode: _getFocusNodeForController(
                                  _customChargeController,
                                ),
                                onTap: () => setCurrentFocusForController(
                                  _customChargeController,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  prefixText: "₹",
                                  labelText: "Custom Charge",
                                  labelStyle: const TextStyle(
                                    color: Colors.black54,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black12,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    /// Customer + Discount + Coupon Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          child: Material(
                            elevation: 4,
                            shadowColor: Colors.black,
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            child: CustomerSearchDropdown(
                              showTopProducts: false,
                              customerNumberController:
                                  _customerNumberController,
                              focusNode: _getFocusNodeForController(
                                _customerNumberController,
                              ),
                              readOnly: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: true,
                            child: Material(
                              elevation: 4,
                              shadowColor: Colors.black,
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              child: TextField(
                                showCursor: true,
                                readOnly: true,
                                keyboardType: TextInputType.none,
                                controller: _discountController,
                                focusNode: _getFocusNodeForController(
                                  _discountController,
                                ),
                                onTap: () => setCurrentFocusForController(
                                  _discountController,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.percent),
                                  labelText: "Discount",
                                  labelStyle: const TextStyle(
                                    color: Colors.black54,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black12,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: true,
                            child: Material(
                              elevation: 4,
                              shadowColor: Colors.black,
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              child: TextField(
                                showCursor: true,
                                readOnly: true,
                                keyboardType: TextInputType.none,
                                controller: _couponCodeController,
                                focusNode: _getFocusNodeForController(
                                  _couponCodeController,
                                ),
                                onTap: () => setCurrentFocusForController(
                                  _couponCodeController,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.local_offer_outlined,
                                  ),
                                  labelText: "Coupon Code",
                                  labelStyle: const TextStyle(
                                    color: Colors.black54,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black12,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    /// Payment Section + Numeric Keyboard
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 5,
                                  bottom: 10,
                                ),
                                child: Material(
                                  elevation: 4,
                                  shadowColor: Colors.black,
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: _buildPaymentSection('Cash'),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 5,
                                  bottom: 10,
                                ),
                                child: Material(
                                  elevation: 4,
                                  shadowColor: Colors.black,
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: _buildPaymentSection('UPI'),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 5,
                                  bottom: 10,
                                ),
                                child: Material(
                                  elevation: 4,
                                  shadowColor: Colors.black,
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: _buildPaymentSection('Card'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 15, thickness: 1),
                        Expanded(
                          flex: 2,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _currentFocusIndexNotifier,
                            builder: (context, currentFocusIndex, _) {
                              return Column(
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 300,
                                    ),
                                    child: NumericKeyboard(
                                      focusNode: _focusNodes[currentFocusIndex],
                                      controller:
                                          _keyboardControllers[currentFocusIndex],
                                      onTextInput: _handleKeyboardTextInput,
                                      onBackspace: _handleKeyboardBackspace,
                                      onOk: _handleKeyboardOk,
                                      isLastField:
                                          currentFocusIndex ==
                                          _keyboardControllers.length - 1,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    /// Mini Cards + Print Button
                    Row(
                      children: [
                        _buildMiniCard(
                          title: "Total",
                          value: "₹${widget.totalAmount.toStringAsFixed(0)}",
                          gradient: [Colors.blue[200]!, Colors.blue[500]!],
                        ),
                        const SizedBox(width: 5),
                        _buildMiniCard(
                          title: "Balance",
                          value: state.balanceAmount < 0
                              ? "-₹${state.balanceAmount.abs().toStringAsFixed(0)}"
                              : "₹${state.balanceAmount.toStringAsFixed(0)}",
                          gradient: [Colors.blue[200]!, Colors.blue[500]!],
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 75,
                          width: 300,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                state.balanceAmount <= 0 && state.isSelected
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              foregroundColor: MaterialStateProperty.all(
                                Colors.white,
                              ),
                              padding: MaterialStateProperty.all(
                                const EdgeInsets.symmetric(
                                  horizontal: 30.0,
                                  vertical: 18.0,
                                ),
                              ),
                              shape:
                                  MaterialStateProperty.all<
                                    RoundedRectangleBorder
                                  >(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                              elevation: MaterialStateProperty.all(5.0),
                            ),
                            onPressed:
                                (state.balanceAmount <= 0 && state.isSelected)
                                ? () async {
                                    _processInvoiceAndPrint();
                                  }
                                : null,
                            child: Text(
                              state.isSubmitting
                                  ? "Processing..."
                                  : "Proceed to payment",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Keep all your existing methods here...
  Future<String> generatehiveInvoiceId(String branchName) async {
    final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final currentDate1 = DateFormat('ddMMyy').format(DateTime.now());

    var invoiceBox = await Hive.openBox('invoices');

    String lastInvoiceDate = invoiceBox.get(
      'lastInvoiceDate',
      defaultValue: "",
    );
    int invoiceCounter = invoiceBox.get('invoiceCounter', defaultValue: 0);

    if (lastInvoiceDate != currentDate || invoiceCounter == 0) {
      invoiceCounter = 1;
    } else {
      invoiceCounter++;
    }

    String hiveInvoiceId =
        'BM/$branchName $currentDate1 KOTINVOICE${invoiceCounter.toString().padLeft(3, '0')}';

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

      print("items are ..... $item");
      for (int i = 0; i < (item['varianceName']?.length ?? 0); i++) {
        String variance = item['varianceName']?[i] ?? "";

        if (!groupedItems.containsKey(variance)) {
          groupedItems[variance] = {
            "varianceName": variance,
            "varianceitemCode": item['varianceitemCode']?[i] ?? "",
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
    // print("groupedItems is ${}");
    //  final invoiceNumberGenerator = InvoiceNumberGenerator().generateInvoiceNumber();

    // final invoiceNo = await invoiceNumberGenerator;
    // print("invoiceNo is $invoiceNo");
    final invoiceNo = await generatehiveInvoiceId(widget.branchName);

    final beforeEmployeeNumber = _employeeNumberController.text.trim();
    final beforeEmployeeNumberValue = beforeEmployeeNumber.split(' - ');

    final employeeNumber = beforeEmployeeNumberValue.isNotEmpty
        ? beforeEmployeeNumberValue[0]
        : '';
    final employeeName = beforeEmployeeNumberValue.length > 1
        ? beforeEmployeeNumberValue[1]
        : '';

    final beforeCustomerNumber = _customerNumberController.text.trim();
    final beforeCustomerNumberValue = beforeCustomerNumber.split(' - ');

    final customerNumber = beforeCustomerNumberValue.isNotEmpty
        ? beforeCustomerNumberValue[0]
        : '';
    final customerName = beforeCustomerNumberValue.length > 1
        ? beforeCustomerNumberValue[1]
        : '';

    final cashAmount = double.tryParse(_customCashController.text) ?? 0.0;

    Map<String, dynamic> invoiceData = {
      "type": "invoiceKOT",
      "invoiceNo": invoiceNo,
      "seathiveOrderId": widget.items.first['seathiveOrderId'] ?? "",
      "varianceitemCode": groupedItems.values
          .map((item) => item['varianceitemCode'])
          .toList(),
      "varianceName": groupedItems.keys.toList(),
      "itemName": groupedItems.values.map((item) => item['itemName']).toList(),
      "price": groupedItems.values.map((item) => item['price']).toList(),
      "qty": groupedItems.values.map((item) => item['qty']).toList(),
      "weight": groupedItems.values.map((item) => item['weight']).toList(),
      "amount": groupedItems.values.map((item) => item['amount']).toList(),
      "tax": groupedItems.values.map((item) => item['tax']).toList(),
      "uom": groupedItems.values.map((item) => item['uom']).toList(),
      "totalAmount": widget.totalAmount,
      "sellingPrice": groupedItems.values
          .map((item) => item['amount'])
          .toList(),
      "sellingAmount": groupedItems.values
          .map((item) => item['amount'])
          .toList(),
      "paymentType": [state.activePaymentMethod],
      "cash": cashAmount,
      "card": state.activePaymentMethod == 'Card' ? widget.totalAmount : 0,
      "upi": state.activePaymentMethod == 'UPI' ? widget.totalAmount : 0,
      "razorpayPaymentId": state.razorpayPaymentId ?? "",
      "invoiceDate": DateFormat('dd-MM-yyyy').format(DateTime.now()),
      "invoiceTime": DateFormat('hh:mm a').format(DateTime.now()),
      "deviceCode": widget.deviceCode,
      "branchId": branchId,
      "branchName": widget.branchName,
      "aliasName": aliasname,
      "salesPersonId": loggedInUserName,
      "salesPersonName": employeeName,
      "employeeNumber": employeeNumber,
      "customerPhoneNumber": customerNumber,
      "sync": "No",
      "salesType": ordertype,
      "kotaddOns": kotAddOns,
      "shiftId": shiftId.value,
      "gst": groupedItems.values.map((item) => item['tax']).toList(),
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
      // final printerProvider = Provider.of<PrinterProviderDine>(
      //   context,
      //   listen: false,
      // );
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);

      // var printerIp = printerProvider.getInvoicePrinterIp();

      // if (printerIp == null) {
      //   await invoicePromptForPrinterIp(context);
      //   printerIp = printerProvider.getInvoicePrinterIp();
      //   if (printerIp == null) {
      //     debugPrint("❌ Printer IP not set.");
      //     if (mounted && _scaffoldMessenger != null) {
      //       _showCustomSnackBar("Printer IP not set!", isSuccess: false);
      //     }
      //     state.setSubmitting(false);
      //     return;
      //   }
      // }

      // debugPrint("🚀 Invoice items count: ${widget.items.length}");
      _sendInvoiceDataToServer();

      String seathiveOrderId = widget.items.first['seathiveOrderId'] ?? '';
      String table = widget.items.first['table'] ?? '';
      String seat = widget.items.first['seat'] ?? '';

      if (seathiveOrderId.isNotEmpty) {
        final result = orderProvider.patchOrderStatusBySeathiveOrderId(
          seathiveOrderId,
          'invoiced',
          table,
          seat,
        );

        debugPrint("final result od patch method is $result");
        debugPrint(
          "✅ Patched order status for sale seatHiveOrderId=$seathiveOrderId",
        );
        final timerProvider = Provider.of<TimerProvider>(
          context,
          listen: false,
        );
        timerProvider.stopTimer(table, seat);
      }

      cartProvider.clearCart();

      Navigator.of(context).pop();

      // await ReceiptPrinter(
      //   employeeNumberController: _employeeNumberController,
      //   seathiveOrderId: seathiveOrderId,
      //   customerNumberController: _customerNumberController,
      //   discountController: _discountController,
      //   customChargeController: _customChargeController,
      //   selectedPaymentOptionValue: '',
      //   context: context,
      //   customAmountController: _customUpiController.text.isNotEmpty
      //       ? _customUpiController
      //       : _customCardController,
      //   selectedPaymentOption: state.activePaymentMethod ?? 'UPI',
      //   items: widget.items,
      //   branchName: widget.branchName,
      //   table: table,
      //   seat: seat,
      //   printerProvider: printerProvider,
      // ).printReceiptDetails();

      if (mounted && _scaffoldMessenger != null) {
        debugPrint("Receipt printed.....");
      } else {
        debugPrint("⚠️ Widget not mounted or ScaffoldMessenger not available");
      }

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Provider.of<BottomNavProvider>(context, listen: false).updateIndex(2);
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
}

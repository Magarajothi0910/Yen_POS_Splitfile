// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:yenposapp/screens/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';

// class CustomPaymentPage extends StatefulWidget {
//   final int amount;
//   const CustomPaymentPage({super.key, required this.amount});

//   @override
//   State<CustomPaymentPage> createState() => _CustomPaymentPageState();
// }

// class _CustomPaymentPageState extends State<CustomPaymentPage> {
//   late Razorpay _razorpay;
//   String? _orderId;
//   RazorpayQRProvider get prov => Provider.of<RazorpayQRProvider>(context, listen: false);

//   @override
//   void initState() {
//     super.initState();
//     _razorpay = Razorpay();

//     _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
//     _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
//     _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

//     _createOrder();
//   }

//   Future<void> _createOrder() async {
//     _orderId = await prov.createOrder(); // Call Step 1 function
//   }

//   void _openCheckout() {
//     if (_orderId == null) return;

//     var options = {
//       'key': 'rzp_test_YourKey',
//       'amount': widget.amount,
//       'name': 'My App Store',
//       'order_id': _orderId,
//       'description': 'Payment for Order',
//       'prefill': {'contact': '9999999999', 'email': 'test@example.com'},
//       'theme': {'color': '#3399cc'},
//     };

//     _razorpay.open(options);
//   }

//   void _handlePaymentSuccess(PaymentSuccessResponse response) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Payment Success: ${response.paymentId}")),
//     );
//   }

//   void _handlePaymentError(PaymentFailureResponse response) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("Payment Failed")),
//     );
//   }

//   void _handleExternalWallet(ExternalWalletResponse response) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text("External Wallet Selected")),
//     );
//   }

//   @override
//   void dispose() {
//     _razorpay.clear();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Checkout")),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: _openCheckout,
//           child: const Text("Pay Now ₹500"),
//         ),
//       ),
//     );
//   }
// }

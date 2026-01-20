
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayQRProvider extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;
  String? qrImageUrl;
  bool paymentSuccess = false;
  bool isCardPaid = false;

  WebSocketChannel? _channel;
  final Razorpay _razorpay = Razorpay();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "https://yenerp.com/fastapi",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  RazorpayQRProvider() {
    _setupRazorpayListeners();
  }

  void _setupRazorpayListeners() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // UPI QR Code Generation
  Future<void> createQR(double price) async {
    isLoading = true;
    errorMessage = null;
    qrImageUrl = null;
    paymentSuccess = false;
    notifyListeners();

    try {
      final response = await _dio.post("/razorPay/create_qr/?price=$price");

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data["image_url"] != null && data["qr_id"] != null) {
          qrImageUrl = data["image_url"];
          // Start WebSocket to listen for payment
          _listenPaymentStatus(data["qr_id"]);
        } else {
          errorMessage = "Response does not contain image_url or qr_id";
        }
      } else {
        errorMessage = "Failed to generate QR: Status ${response.statusCode}";
      }
    } on DioException catch (e) {
      errorMessage = "Network Error: ${e.message}";
    } catch (e) {
      errorMessage = "Unexpected error: $e";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Card Payment
  Future<void> createOrderAndPay(double amount, Function(String type, Map<String, dynamic>? extraData) sendState) async {
    if (amount <= 0) {
      throw Exception("Enter a valid card amount");
    }

    sendState('start_card_payment', {'amount': amount});

    try {
      final response = await _dio.post("/razorPay/create_order/?price=$amount");
      final orderData = response.data;
      sendState('start_card_payment', {'amount': amount});

      var options = {
        'key': 'rzp_live_R6lA4ZV2bwPFPL',
        'amount': (amount * 100).toInt(),
        'name': 'YenPOS Payments',
        'description': 'Card Payment for ₹${amount.toStringAsFixed(2)}',
        'order_id': orderData['id'],
        'prefill': {'contact': '9384250027', 'email': 'test@example.com', 'method': 'card'},
        'theme': {'color': '#2E86DE'},
      };

      _razorpay.open(options);
    } catch (e) {
      sendState('card_payment_error', {'message': e.toString()});
      throw Exception("Failed to create order: $e");
    }
  }

  // Payment Success Handler
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final verifyData = {"order_id": response.orderId, "payment_id": response.paymentId, "signature": response.signature};

      final result = await Dio().post("https://yenerp.com/fastapi/razorPay/verify_payment", data: verifyData);

      if (result.data["status"] == "success") {
        isCardPaid = true;
        paymentSuccess = true;
        notifyListeners();
      } else {
        errorMessage = "Payment verification failed";
        notifyListeners();
      }
    } catch (e) {
      errorMessage = "Verification error: $e";
      notifyListeners();
    }
  }

  // Payment Error Handler
  void _handlePaymentError(PaymentFailureResponse response) {
    errorMessage = "Payment failed: ${response.message}";
    notifyListeners();
  }

  // External Wallet Handler
  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet if needed
  }

  // WebSocket for UPI Payment Status
  void _listenPaymentStatus(String qrId) {
    final url = "wss://yenerp.com/fastapi/razorPay/ws/$qrId";

    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen(
      (message) {
        final data = json.decode(message);
        if (data["status"] == "success") {
          paymentSuccess = true;
          isCardPaid = true;
        } else if (data["status"] == "failed") {
          errorMessage = "Payment Failed: ${data["reason"]}";
        }
        notifyListeners();
      },
      onError: (error) {
        errorMessage = "WebSocket Error: $error";
        notifyListeners();
      },
      onDone: () {
      },
    );
  }

  // Reset payment state
  void resetPaymentState() {
    isLoading = false;
    errorMessage = null;
    qrImageUrl = null;
    paymentSuccess = false;
    isCardPaid = false;
    notifyListeners();
  }

  void disconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    disconnectWebSocket();
    _razorpay.clear();
    super.dispose();
  }
}

// import 'dart:convert';

// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'dart:developer' as developer;

// import 'package:razorpay_flutter/razorpay_flutter.dart';

// class RazorpayQRProvider extends ChangeNotifier {
//   String? qrImageUrl;
//   String? orderId;
//   bool isLoading = false;
//   String? errorMessage;
//   final Razorpay _razorpay = Razorpay();

//   final Dio _dio = Dio(BaseOptions(
//     baseUrl: "http://192.168.1.113:8888", // 🔹 Your backend base URL
//     connectTimeout: const Duration(seconds: 10),
//     receiveTimeout: const Duration(seconds: 10),
//   ));

//   Future<void> createQR(double price) async {
//     isLoading = true;
//     errorMessage = null;
//     qrImageUrl = null;
//     notifyListeners();

//     try {
//       final response = await _dio.post(
//         "/razorPay/create_qr/?price=$price",
//       );
//       developer.log('QR Response: ${response.data}', name: 'RazorpayQR');
//       developer.log('QR Status Code: ${response.statusCode}', name: 'RazorpayQR');

//       if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
//         final data = response.data as Map<String, dynamic>;
//         if (data["image_url"] != null) {
//           qrImageUrl = data["image_url"];
//           developer.log('QR URL: $qrImageUrl', name: 'RazorpayQR');
//         } else {
//           errorMessage = "Response does not contain image_url";
//           developer.log('Error: No image_url in response', name: 'RazorpayQR');
//         }
//       } else {
//         errorMessage = "Failed to generate QR: Status ${response.statusCode}";
//         developer.log('Error: Invalid status code ${response.statusCode}', name: 'RazorpayQR');
//       }
//     } on DioException catch (e) {
//       if (e.response != null && e.response!.data != null) {
//         developer.log('Error Response: ${e.response!.data}', name: 'RazorpayQR');
//         if (e.response!.data is Map<String, dynamic>) {
//           errorMessage = (e.response!.data as Map<String, dynamic>)["error"]?.toString() ?? "Unknown server error";
//         } else if (e.response!.data is String) {
//           errorMessage = e.response!.data.toString();
//         } else if (e.response!.data is List) {
//           errorMessage = (e.response!.data as List).isNotEmpty ? e.response!.data[0].toString() : "Empty error response";
//         } else {
//           errorMessage = "Unexpected error format";
//         }
//       } else {
//         errorMessage = "Network Error: ${e.message}";
//       }
//       developer.log('DioException: $errorMessage', name: 'RazorpayQR');
//     } catch (e) {
//       errorMessage = "Unexpected error: $e";
//       developer.log('Unexpected Error: $e', name: 'RazorpayQR');
//     } finally {
//       isLoading = false;
//       notifyListeners();
//     }
//   }

//   Future<void> createOrderAndPay(double price) async {
//     isLoading = true;
//     errorMessage = null;
//     orderId = null;
//     notifyListeners();

//     try {
//       // 🔹 Step 1: Create order from your FastAPI backend
//       final response = await _dio.post(
//         "/cakeId/create_order/?price=$price",
//         // data: {"price": price},
//       );

//       developer.log('Order Response: ${response.data}', name: 'RazorpayCard');
//       developer.log('Order Status Code: ${response.statusCode}', name: 'RazorpayCard');

//       if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
//         final data = response.data as Map<String, dynamic>;
//         if (data["id"] != null) {
//           orderId = data["id"];
//           developer.log('✅ Order Created | ID: $orderId', name: 'RazorpayCard');

//           // 🔹 Step 2: Configure Razorpay checkout
//           var options = {
//             'key': 'rzp_test_RQT7UUh9ZzwMq2', // Replace with your Razorpay key
//             'amount': (price * 100).toInt(), // Razorpay uses paise
//             'currency': 'INR',
//             'name': 'YenPOS Payments',
//             'description': 'Card Payment for ₹${price.toStringAsFixed(2)}',
//             'order_id': orderId,
//             'prefill': {
//               'contact': '9999999999',
//               'email': 'test@example.com',
//             },
//             'theme': {'color': '#2E86DE'},
//           };

//           // 🔹 Step 3: Open Razorpay checkout
//           _razorpay.open(options);
//         } else {
//           errorMessage = "Response missing order ID";
//           developer.log('❌ Error: Missing order ID in response', name: 'RazorpayCard');
//         }
//       } else {
//         errorMessage = "Failed to create order: ${response.statusCode}";
//         developer.log('❌ Error: Invalid status code ${response.statusCode}', name: 'RazorpayCard');
//       }
//     } on DioException catch (e) {
//       if (e.response != null && e.response!.data != null) {
//         developer.log('Error Response: ${e.response!.data}', name: 'RazorpayCard');

//         if (e.response!.data is Map<String, dynamic>) {
//           errorMessage = (e.response!.data as Map<String, dynamic>)["error"]?.toString() ?? "Unknown server error";
//         } else if (e.response!.data is String) {
//           errorMessage = e.response!.data.toString();
//         } else if (e.response!.data is List) {
//           errorMessage = (e.response!.data as List).isNotEmpty ? e.response!.data[0].toString() : "Empty error response";
//         } else {
//           errorMessage = "Unexpected error format";
//         }
//       } else {
//         errorMessage = "Network Error: ${e.message}";
//       }
//       developer.log('DioException: $errorMessage', name: 'RazorpayCard');
//     } catch (e) {
//       errorMessage = "Unexpected error: $e";
//       developer.log('Unexpected Error: $e', name: 'RazorpayCard');
//     } finally {
//       isLoading = false;
//       notifyListeners();
//     }
//   }

//   Future<String> createOrder() async {
//     final basicAuth = 'Basic ' + base64Encode(utf8.encode('rzp_test_RQT7UUh9ZzwMq2:Z1nURVRDyrAbLI6ipZEue0eC')); // Replace keys

//     final response = await Dio().post(
//       'https://api.razorpay.com/v1/orders',
//       options: Options(headers: {'Authorization': basicAuth}),
//       data: {
//         "amount": 50000, // in paise = ₹500
//         "currency": "INR",
//         "receipt": "receipt#1",
//       },
//     );

//     return response.data['id']; // e.g., order_Jn24k93s...
//   }
// }

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:dio/dio.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:yenposapp/Global/globals_data.dart';

// class RazorpayQRProvider extends ChangeNotifier {
//   bool isLoading = false;
//   String? errorMessage;
//   String? qrImageUrl;
//   bool paymentSuccess = false;

//   WebSocketChannel? _channel;

//   final Dio _dio = Dio(BaseOptions(
//     baseUrl: "https://yenerp.com/fastapi", // 🔹 Your backend base URL
//     connectTimeout: const Duration(seconds: 10),
//     receiveTimeout: const Duration(seconds: 10),
//   ));

//   Future<void> createQR(double price) async {
//     isLoading = true;
//     errorMessage = null;
//     qrImageUrl = null;
//     paymentSuccess = false;
//     notifyListeners();

//     try {
//       final response = await _dio.post("/razorPay/create_qr/?price=$price");

//       if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
//         final data = response.data as Map<String, dynamic>;
//         if (data["image_url"] != null && data["qr_id"] != null) {
//           qrImageUrl = data["image_url"];
//           // Start WebSocket to listen for payment
//           _listenPaymentStatus(data["qr_id"]);
//         } else {
//           errorMessage = "Response does not contain image_url or qr_id";
//         }
//       } else {
//         errorMessage = "Failed to generate QR: Status ${response.statusCode}";
//       }
//     } on DioException catch (e) {
//       errorMessage = "Network Error: ${e.message}";
//     } catch (e) {
//       errorMessage = "Unexpected error: $e";
//     } finally {
//       isLoading = false;
//       notifyListeners();
//     }
//   }

//   void _listenPaymentStatus(String qrId) {
//     final url = "wss://yenerp.com/fastapi/razorPay/ws/$qrId";
//     print("Connecting to WebSocket: $url");

//     _channel = WebSocketChannel.connect(Uri.parse(url));

//     _channel!.stream.listen(
//       (message) {
//         final data = json.decode(message);
//         if (data["status"] == "success") {
//           paymentSuccess = true;
//         } else if (data["status"] == "failed") {
//           errorMessage = "Payment Failed: ${data["reason"]}";
//         }
//         notifyListeners();
//       },
//       onError: (error) {
//         errorMessage = "WebSocket Error: $error";
//         notifyListeners();
//       },
//       onDone: () {
//         print("🔌 WebSocket closed by server");
//       },
//     );
//   }

//   void disconnectWebSocket() {
//     _channel?.sink.close();
//     _channel = null;
//   }

//   @override
//   void dispose() {
//     disconnectWebSocket();
//     super.dispose();
//   }

// }

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
  Future<void> createOrderAndPay(
    double amount,
    Function(String type, Map<String, dynamic>? extraData) sendState,
  ) async {
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
        'prefill': {
          'contact': '9384250027',
          'email': 'test@example.com',
          'method': 'card',
        },
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
      final verifyData = {
        "order_id": response.orderId,
        "payment_id": response.paymentId,
        "signature": response.signature,
      };

      final result = await Dio().post(
        "https://yenerp.com/fastapi/razorPay/verify_payment",
        data: verifyData,
      );

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
    print("💳 External Wallet: ${response.walletName}");
  }

  // WebSocket for UPI Payment Status
  void _listenPaymentStatus(String qrId) {
    final url = "wss://yenerp.com/fastapi/razorPay/ws/$qrId";
    print("Connecting to WebSocket: $url");

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
        print("🔌 WebSocket closed by server");
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

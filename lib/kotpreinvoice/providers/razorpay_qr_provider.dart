import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:web_socket_channel/web_socket_channel.dart';

class RazorpayProvider extends ChangeNotifier {
  String? qrImageUrl;
  String? qrId;
  bool isLoading = false;
  String? errorMessage;
  bool paymentSuccess = false;

  WebSocketChannel? _channel;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "https://yenerp.com/fastapi",
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  // ----------------------------------------------------
  // 🧾 CREATE QR METHOD
  // ----------------------------------------------------
  Future<void> createQR(double price) async {
    isLoading = true;
    errorMessage = null;
    qrImageUrl = null;
    qrId = null;
    paymentSuccess = false;
    notifyListeners();

    debugPrint("💰 Creating QR for ₹${price.toStringAsFixed(2)}...");

    try {
      final response = await _dio.post("/razorPay/create_qr/?price=$price");

      developer.log('📦 Response Data: ${response.data}', name: 'RazorpayQR');
      developer.log(
        '📡 Status Code: ${response.statusCode}',
        name: 'RazorpayQR',
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data["image_url"] != null && data["qr_id"] != null) {
          qrImageUrl = data["image_url"];
          qrId = data["qr_id"];
          debugPrint("✅ QR Created Successfully — ID: $qrId");
          _listenPaymentStatus(qrId!);
        } else {
          errorMessage = "⚠️ Invalid response: missing image_url or qr_id";
          debugPrint("🚫 $errorMessage");
        }
      } else {
        errorMessage = "❌ Failed: Server returned ${response.statusCode}";
        debugPrint("🚫 $errorMessage");
      }
    } on DioException catch (e) {
      // 💥 Dio-specific errors
      if (e.response != null && e.response!.data != null) {
        developer.log(
          '🧾 Error Response: ${e.response!.data}',
          name: 'RazorpayQR',
        );

        if (e.response!.data is Map<String, dynamic>) {
          errorMessage =
              (e.response!.data as Map<String, dynamic>)["error"]?.toString() ??
              "Unknown server error ⚠️";
        } else if (e.response!.data is String) {
          errorMessage = e.response!.data.toString();
        } else {
          errorMessage = "Unexpected error format 🌀";
        }
      } else {
        errorMessage = "🌐 Network Error: ${e.message}";
      }

      debugPrint("💥 DioException: $errorMessage");
    } catch (e, stack) {
      // 🧩 Unexpected errors
      errorMessage = "Unexpected error: $e";
      developer.log('💥 Exception: $e', name: 'RazorpayQR');
      developer.log('🧾 Stacktrace: $stack', name: 'RazorpayQR');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------
  // 🔁 WEBSOCKET LISTENER
  // ----------------------------------------------------
  void _listenPaymentStatus(String qrId) {
    _channel = WebSocketChannel.connect(
      Uri.parse("wss://yenerp.com/fastapi/razorPay/ws/$qrId"),
    );

    _channel!.stream.listen(
      (message) {
        final data = json.decode(message);
        if (data["status"] == "success") {
          paymentSuccess = true;
          notifyListeners();

          // Auto close WebSocket after success
          disconnectWebSocket();
        } else if (data["status"] == "failed") {
          errorMessage = "Payment Failed: ${data["reason"]}";
          notifyListeners();

          // Optionally close WebSocket after failure
          disconnectWebSocket();
        }
      },
      onError: (error) {
        errorMessage = "WebSocket Error: $error";
        notifyListeners();
      },
    );
  }

  void disconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    debugPrint("🧹 Closing WebSocket connection...");
    _channel?.sink.close();
    super.dispose();
  }
}

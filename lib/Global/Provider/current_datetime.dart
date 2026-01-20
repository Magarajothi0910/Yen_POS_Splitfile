import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:yenpos/Global/globals_data.dart';

class CurrentDatetimeService with ChangeNotifier {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Singleton pattern — so only one instance is used app-wide
  static final CurrentDatetimeService _instance =
      CurrentDatetimeService._internal();
  factory CurrentDatetimeService() => _instance;
  CurrentDatetimeService._internal();

  /// Fetches the current date and time from the API and updates global variables.
  Future<void> fetchCurrentDateTime() async {
    const url = 'https://yenerp.com/liveapi/datetime';
    try {
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        // Handle both JSON or plain-string responses safely
        final data = response.data is String
            ? jsonDecode(response.data)
            : response.data;
        currentDate.value = data["current_date"];
        currentTime.value = data["current_time"];

        notifyListeners();
      } else {
      }
    } catch (e) {
    }
  }
}

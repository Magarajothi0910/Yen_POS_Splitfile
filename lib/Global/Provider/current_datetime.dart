import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:yen_pos/Global/globals_data.dart';

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
      debugPrint('Response data: ${response.data}');

      if (response.statusCode == 200) {
        // Handle both JSON or plain-string responses safely
        final data = response.data is String
            ? jsonDecode(response.data)
            : response.data;
        currentDate.value = data["current_date"];
        currentTime.value = data["current_time"];

        notifyListeners();
      } else {
        debugPrint(
          '⚠️ Failed to fetch Current Date/Time. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching Current Date/Time: $e');
    }
  }
}

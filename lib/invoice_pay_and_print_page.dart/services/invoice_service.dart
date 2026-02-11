import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class InvoiceService {
  final String hiveBoxName = 'invoiceBox';
  final String apiUrl = 'https://yenerp.com/fluttertestapi/invoices/';

  /// Generate a shorter HiveInvoiceId
  String generateShortHiveInvoiceId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6); // Shortened timestamp
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123454549'; // Alphanumeric characters
    final randomId = List<int>.generate(
      6,
      (_) => random.nextInt(characters.length),
    ).map((index) => characters[index]).join(); // Generate a 6-character random ID
    return '$timestamp-$randomId'; // Combines timestamp and random alphanumeric ID
  }

  Future<void> saveInvoiceToHive(Map<String, dynamic> invoiceData) async {
    final box = await Hive.openBox(hiveBoxName);
    await box.add(invoiceData);
  }

  Future<Response> postInvoiceToFastAPI(Map<String, dynamic> invoiceData) async {
    final Dio dio = Dio(
      BaseOptions(
        // baseUrl: 'https://your-base-url.com', // optional, if you have a base URL
        connectTimeout: const Duration(seconds: 3), // connection timeout
        receiveTimeout: const Duration(seconds: 3), // response timeout
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      ),
    );

    try {
      debugPrint("Posting invoice data to    : $invoiceData");
      

      final response = await dio.post(
        apiUrl, // replace with your actual endpoint or use full URL directly
        data: invoiceData,
      );

      debugPrint("Invoice Posted Successfully: ${response.statusCode}");
      return response;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        debugPrint("Connection Timeout Exception");
      } else if (e.type == DioExceptionType.receiveTimeout) {
        debugPrint("Receive Timeout Exception");
      } else if (e.type == DioExceptionType.badResponse) {
        debugPrint("Bad Response: ${e.response?.statusCode}");
      } else {
        debugPrint("Unexpected Error: $e");
      }
      rethrow; // rethrow to handle outside if needed
    }
  }

  /// Retrieve all saved invoices from Hive
  Future<List<Map<String, dynamic>>> getAllInvoicesFromHive() async {
    final box = await Hive.openBox(hiveBoxName);
    final invoices = box.values.toList().cast<Map<String, dynamic>>();
    return invoices;
  }
}

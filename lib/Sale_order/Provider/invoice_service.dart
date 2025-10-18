import 'dart:convert';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class InvoiceService {
  final String hiveBoxName = 'invoiceBox';
  final String apiUrl = 'https://yenerp.com/fastapi/invoices/';

  /// Generate a shorter HiveInvoiceId
  String generateShortHiveInvoiceId() {
    final random = Random();
    final timestamp = DateTime.now()
        .millisecondsSinceEpoch
        .toString()
        .substring(6); // Shortened timestamp
    const characters =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123334419'; // Alphanumeric characters
    final randomId =
        List<int>.generate(6, (_) => random.nextInt(characters.length))
            .map((index) => characters[index])
            .join(); // Generate a 6-character random ID
    return '$timestamp-$randomId'; // Combines timestamp and random alphanumeric ID
  }

  Future<void> saveInvoiceToHive(Map<String, dynamic> invoiceData) async {
    final box = await Hive.openBox(hiveBoxName);
    await box.add(invoiceData);
  }

  /// Post the invoice to FastAPI
  Future<http.Response> postInvoiceToFastAPI(
      Map<String, dynamic> invoiceData) async {
    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(invoiceData),
    );
    return response;
  }

  /// Retrieve all saved invoices from Hive
  Future<List<Map<String, dynamic>>> getAllInvoicesFromHive() async {
    final box = await Hive.openBox(hiveBoxName);
    final invoices = box.values.toList().cast<Map<String, dynamic>>();
    return invoices;
  }
}

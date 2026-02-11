// customer_top_products_provider.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CustomerTopProductsProvider with ChangeNotifier {
  List<Map<String, dynamic>> _topProducts = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get topProducts => _topProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchTopProducts(String customerPhone) async {
    if (customerPhone.isEmpty) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Extract only digits from phone number
      String cleanPhone = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
      
      final response = await http.get(
        Uri.parse('https://yenerp.com/fastapi/invoices/customers/top-products?customerPhone=$cleanPhone'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          _topProducts = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('products')) {
          _topProducts = List<Map<String, dynamic>>.from(data['products']);
        } else {
          _topProducts = [];
        }
      } else {
        _error = 'Failed to fetch top products: ${response.statusCode}';
        _topProducts = [];
      }
    } catch (e) {
      _error = 'Error fetching top products: $e';
      _topProducts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearTopProducts() {
    _topProducts = [];
    _error = null;
    notifyListeners();
  }
}
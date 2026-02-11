import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CustomerProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _ledger = [];
  bool _isLoading = false;
  bool _isSearching = false;

  List<Map<String, dynamic>> get customers => _customers;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  List<Map<String, dynamic>> get ledger => _ledger;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;

  // Fetch all customers
  Future<void> fetchCustomers() async {
    _isLoading = true;
    notifyListeners();

    const url = 'https://yenerp.com/fastapi/customers/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _customers = data.cast<Map<String, dynamic>>().reversed.toList();
      }
    } catch (e) {
      debugPrint("Error fetching customers: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCustomer(String name, String phone) async {
    const url = 'https://yenerp.com/fastapi/customers/';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'customerName': name,
          'customerPhoneNumber': phone,
          'status': '1',
        }),
      );
      if (response.statusCode == 200) await fetchCustomers();
    } catch (e) {
      debugPrint("Error adding customer: $e");
    }
  }

  Future<void> updateCustomer(
    String customerId,
    String name,
    String phone,
  ) async {
    final url = 'https://yenerp.com/fastapi/customers/$customerId';
    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'customerName': name, 'customerPhoneNumber': phone}),
      );
      if (response.statusCode == 200) await fetchCustomers();
    } catch (e) {
      debugPrint("Error updating customer: $e");
    }
  }

  // Search customer by phone number
  Future<void> searchCustomer(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    final url =
        'http://10.0.2.2:8888/fastapi/customers/by-customer?customerPhoneNumber=$phoneNumber'; // Update for emulator/device

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint('Search response: ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _searchResults = data.cast<Map<String, dynamic>>();
      } else {
        _searchResults = [];
      }
    } catch (e) {
      debugPrint('Search error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> fetchLedger(String customerPhoneNumber) async {
    _isLoading = true;
    notifyListeners();

    final url =
        'http://192.168.1.117:8888/fastapi/customers/ledger/$customerPhoneNumber';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['data']?['ledgerEntries'] != null) {
          _ledger = (responseData['data']['ledgerEntries'] as List)
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
        } else {
          _ledger = [];
        }
      } else {
        _ledger = [];
      }
    } catch (e) {
      _ledger = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../hiveGlobal/hiveProvider.dart';

class EmployeeSearchProvider extends ChangeNotifier {
  List<Map<String, dynamic>> suggestions = [];
  final HiveProvider hiveProvider;
  final String boxName;
  TextEditingController bankNameController = TextEditingController();

  EmployeeSearchProvider(this.hiveProvider, {required this.boxName});

  Future<void> fetchSuggestions(String query) async {
    // Early exit if query is empty
    if (query.isEmpty) {
      suggestions = [];
      notifyListeners();
      return;
    }

    try {
      // Load cached data from Hive first
      final cachedData = hiveProvider.data[boxName];

      // Check if cached data contains banks
      final banks = cachedData?['items'];
      if (banks is List) {
        suggestions = banks
            .where((bank) =>
                bank['bankName']?.toLowerCase().contains(query.toLowerCase()) ??
                false)
            .map((bank) => {
                  'bankName': bank['bankName']?.toString() ?? '',
                })
            .toList();
      } else {
        suggestions = [];
      }

      notifyListeners();
    } catch (e) {
      suggestions = [];
      notifyListeners();
    }
  }

  Future<bool> addBank(String bankName) async {
    try {
      // Add new bank to remote API
      final response = await http.post(
        Uri.parse('https://yenerp.com/masterapi/bankmasters/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bankName': bankName,
          'status': '1',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newBank = {
          'bankId': response.body,
          'bankName': bankName,
          'status': '1',
        };

        // Ensure the data structure exists
        hiveProvider.data[boxName] ??= {'banks': []};

        if (hiveProvider.data[boxName]!['banks'] == null) {
          hiveProvider.data[boxName]!['banks'] = [];
        }

        // Add the new bank to the cached list
        (hiveProvider.data[boxName]!['banks'] as List).add(newBank);

        // Persist the updated data to Hive
        await hiveProvider.addData(boxName, newBank);

        // Update suggestions with the new bank
        suggestions.add({
          'bankName': bankName,
        });

        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}

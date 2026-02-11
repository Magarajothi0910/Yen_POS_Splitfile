import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:yen_pos/Hive_Manager/hiveProvider.dart';

class BankSearchProvider extends ChangeNotifier {
  List<Map<String, dynamic>> suggestions = [];
  final HiveProvider hiveProvider;
  final String boxName;
  TextEditingController bankNameController = TextEditingController();
  final FocusNode bankFocusNode = FocusNode();

  BankSearchProvider(this.hiveProvider, {required this.boxName}) {
    fetchSuggestions(bankNameController.text);
  }

  void updateBankName(String bankName) {
    bankNameController.text = bankName;
    notifyListeners();
  }

  @override
  void dispose() {
    bankNameController.dispose();
    super.dispose();
  }

  /// ✅ Fetch suggestions from Hive cache
  Future<void> fetchSuggestions(String query) async {
    if (query.isEmpty) {
      suggestions = [];
      notifyListeners();
      return;
    }

    try {
      // Load cached data from Hive
      final cachedData = hiveProvider.data[boxName];
      // ✅ Banks are stored under 'items'
      final banks = cachedData?['items'];
      if (banks is List) {
        suggestions = banks
            .where((bank) {
              final name = (bank['bankName']?.toLowerCase() ?? '');
              final contains = name.contains(query.toLowerCase());
              return contains;
            })
            .map(
              (bank) => {
                'bankName': bank['bankName'] ?? '',
                'bankMasterId': bank['bankMasterId'] ?? '',
              },
            )
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

  /// ✅ Add new bank to API + Hive
  Future<bool> addBank(String bankName) async {
    try {
      final url = Uri.parse('https://yenerp.com/masterapi/bankmasters/');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bankName': bankName, 'status': 'active'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resJson = jsonDecode(response.body);

        final newBank = {
          'bankMasterId': resJson['bankMasterId'] ?? '',
          'bankName': bankName,
          'status': 'active',
        };

        // ✅ Ensure Hive structure exists
        hiveProvider.data[boxName] ??= {'items': []};
        hiveProvider.data[boxName]!['items'] ??= [];

        // Add to cached banks
        (hiveProvider.data[boxName]!['items'] as List).add(newBank);

        // Persist into Hive
        await hiveProvider.addData(boxName, hiveProvider.data[boxName]!);

        // Update UI suggestions
        suggestions.add({
          'bankName': bankName,
          'bankMasterId': newBank['bankMasterId'],
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

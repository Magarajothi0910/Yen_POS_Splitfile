import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hiveProvider.dart';

class CustomerSearchProvider extends ChangeNotifier {
  List<Map<String, dynamic>> suggestions = [];
  final HiveProvider hiveProvider;
  String boxName = 'customerBox';

  CustomerSearchProvider(this.hiveProvider, {this.boxName = 'customerBox'}) {
    hiveProvider.fetchData(boxName); // ⬅️ Ensure data is fetched
    fetchSuggestions(''); // Fetch initial suggestions with empty query
  }

  void clearSuggestions() {
    suggestions.clear();
    notifyListeners();
  }

  Future<void> refreshCustomersFromHive() async {
    var customerBox = await Hive.openBox('customerBox');
    List<Map<String, dynamic>> customers = customerBox.values.map((e) {
      return Map<String, dynamic>.from(e);
    }).toList();

    suggestions = customers; // or whatever list you use internally
    notifyListeners();
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.isEmpty) {
      suggestions = [];
      notifyListeners();
      return;
    }

    try {
      await hiveProvider.fetchData(boxName); // ⬅️ Ensure data is fetched
      final cachedData = hiveProvider.data[boxName];

      final customers = cachedData?['items'];
      if (customers is List) {
        suggestions = customers
            .where(
              (customer) =>
                  customer['customerPhoneNumber']?.toString().contains(query) ??
                  false,
            )
            .map(
              (customer) => {
                'mobile': customer['customerPhoneNumber']?.toString() ?? '',
                'name': customer['customerName']?.toString() ?? '',
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
}

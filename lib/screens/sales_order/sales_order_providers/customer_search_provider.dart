import 'package:flutter/material.dart';
import '../../../hiveGlobal/hiveProvider.dart';

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
            .where((customer) =>
                customer['customerPhoneNumber']?.toString().contains(query) ??
                false)
            .map((customer) => {
                  'mobile': customer['customerPhoneNumber']?.toString() ?? '',
                  'name': customer['customerName']?.toString() ?? '',
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
}

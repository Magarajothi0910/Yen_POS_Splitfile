import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hiveProvider.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';

class CustomerSearchProvider extends ChangeNotifier {
  List<Map<String, dynamic>> suggestions = [];
  final HiveProvider hiveProvider;
  String boxName = 'customerBox';

  CustomerSearchProvider(this.hiveProvider, {this.boxName = 'customerBox'}) {
    hiveProvider.fetchData(boxName); // ⬅️ Ensure data is fetched
    fetchSuggestions(''); // Fetch initial suggestions with empty query
    refreshCustomersFromHive();
  }

  void clearSuggestions() {
    suggestions.clear();
    notifyListeners();
  }

  Future<void> refreshCustomersFromHive() async {
    var box = HiveManager.customers;

    final List<Map<String, dynamic>> customers = box.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (customers.isEmpty) {
      return;
    }

    // Get last stored entry
    final lastCustomer = customers.last;

    lastCustomer.forEach((key, value) {});

    // Update suggestions list
    suggestions
      ..clear()
      ..addAll(customers);

    notifyListeners();
  }

  Future<void> fetchSuggestions(String query) async {
    suggestions.clear();

    var customerBox = HiveManager.customers;

    final List<Map<String, dynamic>> customers = [];

    // 🔥 Parse & normalize ALL hive entries
    for (var entry in customerBox.values) {
      if (entry is List) {
        // If stored as a list, flatten it
        for (var item in entry) {
          if (item is Map) {
            customers.add({
              'customerPhoneNumber':
                  item['customerPhoneNumber'] ?? item['mobile'],
              'customerName': item['customerName'] ?? item['name'],
            });
          }
        }
      } else if (entry is Map) {
        // Single customer entry
        customers.add({
          'customerPhoneNumber':
              entry['customerPhoneNumber'] ?? entry['mobile'],
          'customerName': entry['customerName'] ?? entry['name'],
        });
      }
    }

    // If no query
    if (query.isEmpty) {
      suggestions = [];
      notifyListeners();
      return;
    }

    // 🔥 Filter using normalized keys
    suggestions = customers
        .where(
          (customer) => (customer['customerPhoneNumber']?.toString() ?? "")
              .contains(query),
        )
        .map(
          (customer) => {
            'mobile': customer['customerPhoneNumber'].toString(),
            'name': customer['customerName'] ?? '',
          },
        )
        .toList();

    notifyListeners();
  }
}

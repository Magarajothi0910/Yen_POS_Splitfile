import 'package:flutter/material.dart';

class SearchProviderDine with ChangeNotifier {
  String _searchQuery = '';

  String get searchQuery => _searchQuery;

  void updateSearchQuery(String query) {
    _searchQuery = query.replaceAll(RegExp(r'\s+'), '');
    print("_searchQuery is $_searchQuery");
    notifyListeners();
  }

  void clearSearchQuery() {
    _searchQuery = '';
    notifyListeners();
  }
}

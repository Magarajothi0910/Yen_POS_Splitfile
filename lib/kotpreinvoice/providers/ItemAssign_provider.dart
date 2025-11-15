import 'package:flutter/material.dart';

class SelectedItemsProvider extends ChangeNotifier {
  final List<String> _selectedItems = [];

  List<String> get selectedItems => _selectedItems;

  void toggleItem(String itemId) {
    if (_selectedItems.contains(itemId)) {
      _selectedItems.remove(itemId);
    } else {
      _selectedItems.add(itemId);
    }
    notifyListeners();
  }

  void clearSelectedItems() {
    _selectedItems.clear();
    notifyListeners();
  }
}


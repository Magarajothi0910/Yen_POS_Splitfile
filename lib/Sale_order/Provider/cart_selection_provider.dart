import 'package:flutter/material.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';

class CartSelectionProvider extends ChangeNotifier {
  final Map<String, bool> _itemSelectionState = {};
  bool _showCheckBoxes = false;

  Map<String, bool> get itemSelectionState => _itemSelectionState;
  bool get showCheckBoxes => _showCheckBoxes;

  /// key → varianceName_isBoxItem

  String _key(CartItem item) => '${item.varianceName}_${item.isBoxItem}';

  bool isSelected(CartItem item) {
    return itemSelectionState[_key(item)] ?? false;
  }

  void selectItem(CartItem item) {
    itemSelectionState[_key(item)] = true;
    notifyListeners();
  }

  void unselectItem(CartItem item) {
    itemSelectionState.remove(_key(item));
    notifyListeners();
  }

  void clear() {
    itemSelectionState.clear();
    notifyListeners();
  }

  // bool isSelected(dynamic item) {
  //   final key = '${item.varianceName}_${item.isBoxItem}';
  //   return itemSelectionState[key] ?? false;
  // }

  // void selectItem(dynamic item) {
  //   final key = '${item.varianceName}_${item.isBoxItem}';
  //   itemSelectionState[key] = true;
  //   notifyListeners();
  // }

  // void unselectItem(dynamic item) {
  //   final key = '${item.varianceName}_${item.isBoxItem}';
  //   itemSelectionState.remove(key);
  //   notifyListeners();
  // }

  // void clear() {
  //   itemSelectionState.clear();
  //   notifyListeners();
  // }

  // Toggle selection for a single item
  void toggleItemSelection(String key, bool value) {
    _itemSelectionState[key] = value;
    notifyListeners();
  }

  void setShowCheckBoxes(bool value) {
    _showCheckBoxes = value;
    notifyListeners();
  }

  // Toggle selection for ALL items (select/unselect all)
  void toggleAllItemsSelection(bool value, List<String> itemKeys) {
    for (final key in itemKeys) {
      _itemSelectionState[key] = value;
    }
    _showCheckBoxes = value; // Show checkboxes only if items are selected
    notifyListeners();
  }

  void toggleCheckBoxVisibility() {
    if (_showCheckBoxes) {
      // If checkboxes are visible, hide them and clear all selections
      _showCheckBoxes = false;
      _itemSelectionState.clear();
    } else {
      // If checkboxes are hidden, just show them (don't select anything)
      _showCheckBoxes = true;
    }
    notifyListeners();
  }

  // Clear all selections
  void clearSelections() {
    _itemSelectionState.clear();
    _showCheckBoxes = false; // Hide checkboxes when cleared
    notifyListeners();
  }
}

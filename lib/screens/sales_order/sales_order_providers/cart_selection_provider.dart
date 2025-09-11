// import 'package:flutter/material.dart';

// class CartSelectionProvider extends ChangeNotifier {
//   final Map<String, bool> _itemSelectionState = {};
//   bool _showCheckBoxes = false;

//   Map<String, bool> get itemSelectionState => _itemSelectionState;
//   bool get showCheckBoxes => _showCheckBoxes;

//   void toggleItemSelection(String key, bool value) {
//     _itemSelectionState[key] = value;
//     notifyListeners();
//   }

//   void toggleCheckBoxVisibility() {
//     _showCheckBoxes = !_showCheckBoxes;
//     notifyListeners();
//   }

//   void clearSelections() {
//     _itemSelectionState.clear();
//     notifyListeners();
//   }
// }

import 'package:flutter/material.dart';

class CartSelectionProvider extends ChangeNotifier {
  final Map<String, bool> _itemSelectionState = {};
  bool _showCheckBoxes = false;

  Map<String, bool> get itemSelectionState => _itemSelectionState;
  bool get showCheckBoxes => _showCheckBoxes;

  // Toggle selection for a single item
  void toggleItemSelection(String key, bool value) {
    _itemSelectionState[key] = value;
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

  // // Toggle checkbox visibility (optional, if needed separately)
  // void toggleCheckBoxVisibility() {
  //   _showCheckBoxes = !_showCheckBoxes;
  //   notifyListeners();
  // }

// Call this whenever cart items change

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

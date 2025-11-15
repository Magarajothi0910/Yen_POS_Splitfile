import 'package:flutter/material.dart';

class PaxProviderDine extends ChangeNotifier {
  String _selectedPax = "1";

  String get selectedPax => _selectedPax;

  void setSelectedPax(String value) {
    _selectedPax = value;
    notifyListeners();
  }

  void resetPax() {
    _selectedPax = '1'; // Reset to default value
    notifyListeners();
  }
}

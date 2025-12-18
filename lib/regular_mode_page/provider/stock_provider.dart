import 'package:flutter/material.dart';

class StockProvider extends ChangeNotifier {
  Map<String, int> _branchStock = {}; // key: "$branchAlias|$varianceCode"

  void updateStock(String branchAlias, String varianceName, int newStock) {
    final key = "$branchAlias|$varianceName";
    if (_branchStock[key] != newStock) {
      _branchStock[key] = newStock;
      notifyListeners(); // This triggers UI rebuild
    }
  }

  int getStock(String branchAlias, String varianceName) {
    return _branchStock["$branchAlias|$varianceName"] ?? 0;
  }
}
import 'package:flutter/material.dart';

class SaleOrderQuantityProvider extends ChangeNotifier {
  double quantity = 1;

  void increment() {
    quantity++;
    notifyListeners();
  }

  void decrement() {
    if (quantity > 1) {
      quantity--;
      notifyListeners();
    }
  }

  void setQuantity(double val) {
    quantity = val > 0 ? val : 1;
    notifyListeners();
  }

  void reset() {
    quantity = 1;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';

class OrderTypeProviderDine with ChangeNotifier {
  String _orderType = 'Dine In';

  String get orderType => _orderType;

  void setOrderType(String orderType) {
    _orderType = orderType;
    notifyListeners();
  }
}

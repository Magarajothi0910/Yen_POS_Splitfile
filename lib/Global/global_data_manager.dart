import 'package:flutter/material.dart';

class GlobalDataManager extends ChangeNotifier{
  static final GlobalDataManager _instance = GlobalDataManager._internal();

  factory GlobalDataManager() {
    return _instance;
  }

  GlobalDataManager._internal();

  dynamic _branchwiseItems;
  dynamic _salesorders;

  dynamic _branches;
  dynamic _customers;

  dynamic _events;
  dynamic _deliveryTypes;
  dynamic _charges;

  dynamic _billReceiptSettings;
  dynamic _mixboxData; // Add this field for mixbox data

  // Getter and setter for branchwiseItems
  //dynamic get branchwiseItems => _branchwiseItems;

  // set branchwiseItems(dynamic value) {
  //   _branchwiseItems = value;
  // }

  // Getter and setter for branchwiseItems
  dynamic get salesorders => _salesorders;

  set salesorders(dynamic value) {
    _salesorders = value;
  }

final Map<String, double> _liveStockCache = <String, double>{};

// void updateStockLive({
//   required String branchAlias,
//   required String varianceName,  // ← Now uses NAME
//   required double newStock,
// }) {
//   final key = '$branchAlias|$varianceName';  // e.g. "AR|SPL MIXTURE 250g"
//   _liveStockCache[key] = newStock;
//   print("LIVE STOCK → $key = $newStock");  
//   notifyListeners();
// }

void updateStockLive({
  required String branchAlias,
  required String varianceName,
  required double systemStock,
  required double soStock,
}) {
  final key = '$branchAlias|$varianceName';
  final effectiveStock = (systemStock - soStock).clamp(0.0, double.infinity);
  _liveStockCache[key] = effectiveStock;
  print("LIVE STOCK → $key = $effectiveStock (system: $systemStock, SO: $soStock)");
  notifyListeners();
}

double getLiveStock(String branchAlias, String varianceName) {
  final key = '$branchAlias|$varianceName';
  return _liveStockCache[key] ?? -1;
}

  // Getter and setter for branches
  dynamic get branches => _branches;

  set branches(dynamic value) {
    _branches = value;
  }

  // Getter and setter for customers
  dynamic get customers => _customers;

  set customers(dynamic value) {
    _customers = value;
  }

  // Getter and setter for branches
  dynamic get events => _events;

  set events(dynamic value) {
    _events = value;
  }

  dynamic get deliveryTypes => _deliveryTypes;

  set deliveryTypes(dynamic value) {
    _deliveryTypes = value;
  }

  dynamic get charges => _charges;

  set charges(dynamic value) {
    _charges = value;
  }

  // Getter and setter for billReceiptSettings
  dynamic get billReceiptSettings => _billReceiptSettings;

  set billReceiptSettings(dynamic value) {
    _billReceiptSettings = value;
  }

  // Getter and setter for mixboxData
  dynamic get mixboxData => _mixboxData;

  set mixboxData(dynamic value) {
    _mixboxData = value;
  }
}

String ipAddress = '';

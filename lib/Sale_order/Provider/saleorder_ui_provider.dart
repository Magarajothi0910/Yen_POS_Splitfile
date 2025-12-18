// lib/Sale_order/Provider/sales_order_ui_provider.dart

import 'package:flutter/material.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;

class SalesOrderUIProvider with ChangeNotifier {
  bool isStoreTypeDialogShowing = false;
  bool isStoreTypeSelected = false;
  String selectedStoreType = 'Warehouse';
  bool showCheckBoxes = false;
  
  // Text Controllers
  final TextEditingController allBoxQtyController = TextEditingController();
  final TextEditingController bulkDiscountController = TextEditingController();
  final Map<String, TextEditingController> boxQtyControllers = {};
  final Map<String, TextEditingController> discountControllers = {};
  final Map<String, FocusNode> discountFocusNodes = {};
  
  // Focus Nodes
  final FocusNode allBoxQtyFocus = FocusNode();
  final FocusNode customChargeFocus = FocusNode();
  
  bool _isDialogShownToday = false;
  bool _isInternalUpdate = false;

  // Getters
  bool get isDialogShownToday => _isDialogShownToday;
  bool get isInternalUpdate => _isInternalUpdate;

  // Setters
  set isDialogShownToday(bool value) {
    _isDialogShownToday = value;
    notifyListeners();
  }

  set isInternalUpdate(bool value) {
    _isInternalUpdate = value;
  }

  void setStoreTypeSelected(bool value) {
    isStoreTypeSelected = value;
    notifyListeners();
  }

  void setStoreType(String type) {
    selectedStoreType = type;
    isStoreTypeSelected = true;
    notifyListeners();
  }

  void setStoreTypeDialogShowing(bool value) {
    isStoreTypeDialogShowing = value;
    notifyListeners();
  }

  void initializeItemControllers(String key) {
    if (!boxQtyControllers.containsKey(key)) {
      boxQtyControllers[key] = TextEditingController();
    }
    if (!discountControllers.containsKey(key)) {
      discountControllers[key] = TextEditingController();
    }
    if (!discountFocusNodes.containsKey(key)) {
      discountFocusNodes[key] = FocusNode();
    }
  }

  void removeItemControllers(String key) {
    boxQtyControllers.remove(key)?.dispose();
    discountControllers.remove(key)?.dispose();
    discountFocusNodes.remove(key)?.dispose();
  }

  void clearAllControllers() {
    allBoxQtyController.clear();
    bulkDiscountController.clear();
    
    for (final controller in boxQtyControllers.values) {
      controller.clear();
    }
    for (final controller in discountControllers.values) {
      controller.clear();
    }
  }

  @override
  void dispose() {
    allBoxQtyController.dispose();
    bulkDiscountController.dispose();
    allBoxQtyFocus.dispose();
    customChargeFocus.dispose();
    
    for (final controller in boxQtyControllers.values) {
      controller.dispose();
    }
    for (final controller in discountControllers.values) {
      controller.dispose();
    }
    for (final node in discountFocusNodes.values) {
      node.dispose();
    }
    
    super.dispose();
  }
}
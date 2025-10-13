library;

import 'package:flutter/material.dart';

import 'screens/model/sales_invoicemodel.dart';
import 'sales_order_providers/cartProvider.dart';
import 'sales_order_providers/modifyOrderProvider.dart';

List<CartItem> cartItems = [];
int cartItemCount = 0;
List<SalesOrderItem> invoiceItems = [];
List<modifyCartItem> modifyItems = [];
String deviceName = 'POS001';
// Global TextEditingController
TextEditingController commonController =
    TextEditingController(); // we’ll init it once
late FocusNode commonFocusNode;
late ValueNotifier<Map<int, double>> quantityChangesNotifier;

class ActiveField {
  static final ValueNotifier<TextEditingController?> controller =
      ValueNotifier<TextEditingController?>(null);

  static final ValueNotifier<FocusNode?> focus =
      ValueNotifier<FocusNode?>(null);

  static final ValueNotifier<bool> isNumeric = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> isDiscount = ValueNotifier<bool>(false);

  // ✅ NEW: custom charge flag
  static final ValueNotifier<bool> isCustomCharge = ValueNotifier<bool>(false);

  static void activate({
    required TextEditingController ctrl,
    required FocusNode node,
    bool numeric = false,
    bool discount = false,
    bool customCharge = false, // ✅ param
    void Function(String)? onChanged, // ✅ Add this
  }) {
    focus.value?.unfocus();

    controller.value = ctrl;
    focus.value = node;
    isNumeric.value = numeric;
    isDiscount.value = discount;
    isCustomCharge.value = customCharge; // ✅ set here

    node.requestFocus();
    ctrl.addListener(() {
      if (onChanged != null) {
        onChanged(ctrl.text); // ✅ trigger suggestions
      }
    });
  }

  static void clear() {
    focus.value?.unfocus();
    controller.value = null;
    focus.value = null;
    isNumeric.value = false;
    isDiscount.value = false;
    isCustomCharge.value = false; // ✅ reset
  }
}

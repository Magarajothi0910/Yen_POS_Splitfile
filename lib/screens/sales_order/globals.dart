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

  static final ValueNotifier<bool> isCustomCharge = ValueNotifier<bool>(false);

  // ✅ NEW: store type like "customer number"
  static final ValueNotifier<String?> type = ValueNotifier<String?>(null);

  static final Map<TextEditingController, VoidCallback> _listenerMap = {};

  static void activate({
    required TextEditingController ctrl,
    required FocusNode node,
    bool numeric = false,
    bool discount = false,
    bool customCharge = false,
    String? fieldType, // "customer number"
    void Function(String)? onChanged,
  }) {
    focus.value?.unfocus();

    controller.value = ctrl;
    focus.value = node;
    isNumeric.value = numeric;
    isDiscount.value = discount;
    isCustomCharge.value = customCharge;
    type.value = fieldType; // ✅ store type for later use

    node.requestFocus();

    // Remove previous listener
    if (_listenerMap.containsKey(ctrl)) {
      ctrl.removeListener(_listenerMap[ctrl]!);
    }

    void listener() {
      if (type.value == "customer number") {
        // Handle customer number logic (max 10 digits)
        if (ctrl.text.contains('-')) return;

        final digitsOnly = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (digitsOnly.length > 10) {
          ctrl.text = digitsOnly.substring(0, 10);
          ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: ctrl.text.length),
          );
        } else if (digitsOnly != ctrl.text) {
          ctrl.text = digitsOnly;
          ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: ctrl.text.length),
          );
        }
      } else if (type.value == "custom charge") {
        // ✅ Handle custom charge: max 5 digits
        final digitsOnly = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (digitsOnly.length > 5) {
          ctrl.text = digitsOnly.substring(0, 5);
          ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: ctrl.text.length),
          );
        } else if (digitsOnly != ctrl.text) {
          ctrl.text = digitsOnly;
          ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: ctrl.text.length),
          );
        }
      }

      if (onChanged != null) onChanged(ctrl.text);
    }

    ctrl.addListener(listener);
    _listenerMap[ctrl] = listener;
  }

  static void clear() {
    focus.value?.unfocus();
    controller.value = null;
    focus.value = null;
    isNumeric.value = false;
    isDiscount.value = false;
    isCustomCharge.value = false;
    type.value = null; // ✅ reset type
  }
}

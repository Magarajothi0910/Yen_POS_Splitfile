import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/cartprovider.dart';
import 'package:yen_pos/kotpreinvoice/providers/hold_order.dart';
import 'package:yen_pos/main.dart';

import '../providers/order_provider.dart';

class AutoHoldOrderService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.yenposapp/autosave',
  );

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'autoSaveHoldOrder') {
        // await performAutoSave();
      } else if (call.method == 'autoPrintOnClose') {
        await _performAutoPrint(); // ← NEW
      }
    });
  }

  static Future<void> _performAutoPrint() async {}

  static void autoSaveHoldOrder(BuildContext context) {
    try {
      final holdOrderProvider = Provider.of<HoldOrderProvider>(
        context,
        listen: false,
      );

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);

      final currentTable = cartProvider.currentTableNumber.value;
      final currentSeat = cartProvider.currentSeat.value;
      final currentArea = cartProvider.currentAreaName.value;

      if (currentTable.isEmpty ||
          currentSeat.isEmpty ||
          cartProvider.cart.isEmpty) {
        return;
      }

      final ordersForSeat = orderProvider.getRunningOrdersForSeat(
        currentTable,
        currentSeat,
      );

      final bool hasActiveOrder = ordersForSeat.any(
        (order) =>
            order['status'] == 'confirm' &&
            currentTable == order['table'] &&
            currentSeat == order['seat'],
      );

      if (hasActiveOrder) return;

      // Clone cart data to avoid mutation issues
      final Map<String, dynamic> cartDataToSave = Map<String, dynamic>.from(
        cartProvider.cart,
      );

      holdOrderProvider.saveHoldOrder(
        currentTable,
        currentSeat,
        cartDataToSave,
        areaName: currentArea,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error in autoSaveHoldOrder: $e');
      debugPrint(stackTrace.toString());
    }
  }
}

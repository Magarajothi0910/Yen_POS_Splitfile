import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/kotpreinvoice/providers/cartprovider.dart';
import 'package:yenpos/kotpreinvoice/providers/hold_order.dart';
import 'package:yenpos/main.dart';

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

  static Future<void> _performAutoPrint() async {
    debugPrint("App Succesfully Swiped or killed");
  }

  /// Private method that uses global navigator context
  // static Future<void> performAutoSave() async {
  //   final BuildContext? context = MyApp.navigatorKey.currentContext;

  //   debugPrint('app is swipped');

  //   if (context == null) {
  //     debugPrint(
  //       '❌ AutoHoldOrderService: No context available – app likely fully terminated',
  //     );
  //     return;
  //   }

  //   if (!context.mounted) {
  //     debugPrint('❌ AutoHoldOrderService: Context no longer mounted');
  //     return;
  //   }

  //   try {
  //     final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);
  //     final orderProvider = Provider.of<OrderProvider>(context, listen: false);
  //     final holdOrderProvider = Provider.of<HoldOrderProvider>(
  //       context,
  //       listen: false,
  //     );

  //     final currentTable = cartProvider.currentTableNumber.value;
  //     final currentSeat = cartProvider.currentSeat.value;
  //     final currentArea = cartProvider.currentAreaName.value;

  //     // Basic validation
  //     if (currentTable.isEmpty ||
  //         currentSeat.isEmpty ||
  //         cartProvider.cart.isEmpty) {
  //       debugPrint('ℹ️ No active cart to hold – skipping auto-save');
  //       return;
  //     }

  //     // Check if there's already an active order
  //     final ordersForSeat = orderProvider.getRunningOrdersForSeat(
  //       currentTable,
  //       currentSeat,
  //     );

  //     final hasActiveOrder = ordersForSeat.any(
  //       (order) => order['status'] == 'active',
  //     );

  //     if (hasActiveOrder) {
  //       debugPrint(
  //         'ℹ️ Active order exists for Table $currentTable Seat $currentSeat – skipping hold',
  //       );
  //       return;
  //     }

  //     debugPrint(
  //       '💾 Auto-saving hold order on app swipe-away: Table $currentTable, Seat $currentSeat',
  //     );

  //     // Deep clone cart to prevent any reference issues
  //     final cartCopy = Map<String, dynamic>.from(cartProvider.cart);

  //     // Save the hold order
  //     holdOrderProvider.saveHoldOrder(
  //       currentTable,
  //       currentSeat,
  //       cartCopy,
  //       areaName: currentArea,
  //     );

  //     debugPrint('✅ Hold order successfully auto-saved on app close!');
  //   } catch (e, stack) {
  //     debugPrint('❌ Error in AutoHoldOrderService._performAutoSave: $e');
  //     debugPrint(stack.toString());
  //   }
  // }

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

      debugPrint(
        "currentTable is $currentTable :: currentSeat is $currentSeat :: cartProvider.cart is ${cartProvider.cart}",
      );

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

      debugPrint("ordersForSeat $ordersForSeat");
      debugPrint("hasActiveOrder $hasActiveOrder");

      if (hasActiveOrder) return;

      debugPrint(
        '💾 Auto-saving hold order for $currentTable - Seat $currentSeat',
      );

      // Clone cart data to avoid mutation issues
      final Map<String, dynamic> cartDataToSave = Map<String, dynamic>.from(
        cartProvider.cart,
      );

      debugPrint('📦 Cart data being saved:');
      cartDataToSave.forEach((productName, productData) {
        debugPrint('   - $productName: $productData');
      });

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

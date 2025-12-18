import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // for safer date formatting
import 'package:yenpos/Global/Widget/scaffold_global.dart';
import 'package:yenpos/Sale_order/Models/held_order_model.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/detailsProvider.dart';

bool _isRestoringHeldOrder = false;
Future<void> restoreHeldOrderData(BuildContext context, HeldOrder order) async {
  if (_isRestoringHeldOrder) return;
  _isRestoringHeldOrder = true;

  try {
    print("🟦 Restoring held order…");

    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final selectionProvider = Provider.of<CartSelectionProvider>(
      context,
      listen: false,
    );

    // ---------------------- RESET UI ----------------------
    cartProvider.clearCart();
    selectionProvider.clearSelections();
    customerProvider.resetControllers();

    // ---------------------- RESTORE CUSTOMER ----------------------
    customerProvider.customerNameController.text = order.customerName ?? "";
    customerProvider.mobileNoController.text = order.customerNumber ?? "";

    // 🔥 FIXED: Combined controller also updated
    customerProvider.customerCombinedController.text =
        "${order.customerNumber ?? ''} - ${order.customerName ?? ''}";

    // 🔥 FIXED: salesperson restore
    customerProvider.searchController.text = order.employeeName ?? "";

    customerProvider.addressController.text = order.address ?? "";
    customerProvider.landmarkController.text = order.landmark ?? "";
    customerProvider.remarkController.text = order.remark ?? "";
    customerProvider.setSelectedEvent(order.event);
    customerProvider.setSelectedDeliveryType(order.deliveryType);

    customerProvider.patchHoldOrderId = order.holdOrderId ?? "";
    customerProvider.selectedChargeType = order.customChargeType;

    customerProvider.customChargeController.text =
        order.customCharge?.toString() ?? "";

    // Delivery Date
    if (order.deliveryDate != null && order.deliveryDate!.trim().isNotEmpty) {
      try {
        DateTime d = DateTime.parse(order.deliveryDate!);
        customerProvider.dateController.text = DateFormat(
          'dd-MM-yyyy',
        ).format(d);
        customerProvider.timeController.text = DateFormat('hh:mm a').format(d);
      } catch (_) {}
    }

    // Event Date
    if (order.eventDate != null && order.eventDate!.trim().isNotEmpty) {
      try {
        DateTime ev = DateTime.parse(order.eventDate!);
        customerProvider.birthdaydateController.text = DateFormat(
          'dd-MM-yyyy',
        ).format(ev);
      } catch (_) {}
    }

    // ---------------------- RESTORE ITEMS ----------------------
    int itemCount = order.itemName.length;
    bool hasBoxItem = false;

    for (int i = 0; i < itemCount; i++) {
      bool isBoxItem = (order.isBoxItem?[i].toString().toLowerCase() == "yes");

      CartItem item = CartItem(
        rowId: UniqueKey().toString(), // 🔥 NEVER reuse
        itemName: order.itemName[i],
        varianceName: order.varianceName[i],
        itemCode: order.itemCode[i],
        uom: order.uom[i],
        quantity: order.qty[i],
        weight: order.weight[i],
        pricePerKg: order.price[i],
        tax: order.tax[i],

        itemWiseDiscount: order.itemWiseDiscount?[i] ?? 0,
        itemWiseDiscountAmount: order.itemWiseDiscountAmount?[i] ?? 0,

        // ⭐ FIXED: box qty restored
        boxQuantity: isBoxItem ? (order.boxQty ?? 0) : 0,
      );

      cartProvider.addItemToCart(item);

      if (isBoxItem) hasBoxItem = true;
    }

    // ---------------------- ENABLE GIFT MODE ----------------------
    // ---------------------- ENABLE GIFT MODE IF NEEDED ----------------------
    if (hasBoxItem) {
      print("🎁 Gifted items detected -> enabling checkbox mode");

      // Use the provider's public setter (avoid direct field assignment)
      // (This method should call notifyListeners() inside provider; we still ensure UI rebuild below.)
      selectionProvider.setShowCheckBoxes(true);

      for (int i = 0; i < itemCount; i++) {
        if (order.isBoxItem?[i].toString().toLowerCase() == "yes") {
          final varName = order.varianceName[i];
          // ensure a valid map/set entry exists
          selectionProvider.itemSelectionState[varName] = true;
        }
      }

      // Ensure UI updates (safe because CartSelectionProvider extends ChangeNotifier)
      try {
        selectionProvider.notifyListeners();
      } catch (e) {
        // If notifyListeners isn't accessible for some reason, ignore — provider's setter should have already notified.
        print("ℹ️ selectionProvider.notifyListeners() failed: $e");
      }
    }

    // ---------------------- FORCE COMPLETE UI REFRESH ----------------------
    cartProvider.updateCart();
    customerProvider.updateCartItems();
    customerProvider.updateCartCount();

    // ⭐ FIXED: notify all listeners
    customerProvider.notifyListeners();
    cartProvider.notifyListeners();

    GlobalScaffold.showMessage(
      message: 'Held order restored successfully',
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );

    print("✅ Restoration completed");
  } catch (e, s) {
    print("❌ Error: $e\n$s");
    GlobalScaffold.showMessage(
      message: 'Failed to restore held order',
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  } finally {
    _isRestoringHeldOrder = false;
  }
}

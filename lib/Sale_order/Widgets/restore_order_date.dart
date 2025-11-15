import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Audio%20Player/audio_provider.dart';
import 'package:yenpos/Global/Widget/scaffold_global.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Sale_order/Models/held_order_model.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/detailsProvider.dart';
import 'package:yenpos/Sale_order/Provider/photoProvider.dart';

bool _isRestoringHeldOrder = false; // Prevent concurrent restores

Future<void> restoreHeldOrderData(BuildContext context, HeldOrder order) async {
  globals.cartItems = [];
  if (_isRestoringHeldOrder) return; // 🚫 Prevent multiple calls
  _isRestoringHeldOrder = true;

  try {
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final detailsProvider = Provider.of<DetailsProvider>(
      context,
      listen: false,
    );

    // 🔹 STEP 2: Restore customer & order details
    customerScreenProvider.dateController.text = order.deliveryDate ?? '';
    customerScreenProvider.timeController.text = order.deliveryTime ?? '';
    customerScreenProvider.setSelectedEvent(order.event);
    customerScreenProvider.setSelectedDeliveryType(order.deliveryType);
    customerScreenProvider.landmarkController.text = order.landmark ?? '';
    customerScreenProvider.addressController.text = order.address ?? '';
    customerScreenProvider.birthdaydateController.text = order.eventDate ?? '';
    customerScreenProvider.remarkController.text = order.remark ?? '';
    customerScreenProvider.patchHoldOrderId = order.holdOrderId ?? '';
    customerScreenProvider.setSelectedHoldOrderId(order.holdOrderId);
    customerScreenProvider.birthdaydateController.text = order.eventDate ?? '';
    // Customer info
    customerScreenProvider.customerNameController.text =
        order.customerName ?? '';
    customerScreenProvider.mobileNoController.text = order.customerNumber ?? '';

    final mobile = customerScreenProvider.mobileNoController.text.trim();
    final name = customerScreenProvider.customerNameController.text.trim();
    customerScreenProvider.combinedController.text =
        (mobile.isNotEmpty && name.isNotEmpty)
        ? '$mobile - $name'
        : mobile.isNotEmpty
        ? mobile
        : name.isNotEmpty
        ? name
        : '';

    // Employee
    customerScreenProvider.searchController.text = order.employeeName ?? '';
    detailsProvider.filteredEmployeeFirstNames.clear();
    customerScreenProvider.birthdaydateController.text = order.eventDate ?? '';

    // 🔹 STEP 3: Restore cart items
    if (order.itemName.isNotEmpty) {
      for (int i = 0; i < order.itemName.length; i++) {
        try {
          cartProvider.addItemToCart(
            CartItem(
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
              boxQuantity: order.boxQty,
            ),
          );
        } catch (itemError) {
          debugPrint('⚠️ Error restoring item at index $i: $itemError');
        }
      }
    }

    // 🔹 STEP 4: Success message
    if (context.mounted) {
      GlobalScaffold.showMessage(
        message: '✅ Held order restored successfully',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      Navigator.of(context).pop();
    }
  } catch (e, stack) {
    debugPrint('❌ Error restoring held order: $e\n$stack');
    if (context.mounted) {
      GlobalScaffold.showMessage(
        message: 'Failed to restore held order',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  } finally {
    _isRestoringHeldOrder = false;
  }
}

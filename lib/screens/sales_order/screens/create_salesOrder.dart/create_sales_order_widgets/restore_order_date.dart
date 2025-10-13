import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/Audio%20Player/audio_provider.dart';
import 'package:yenposapp/Global/scaffold_global.dart';
import 'package:yenposapp/screens/sales_order/sales_order_providers/cartProvider.dart';
import 'package:yenposapp/screens/sales_order/sales_order_providers/customerScreen_provider.dart';
import 'package:yenposapp/screens/sales_order/sales_order_providers/detailsProvider.dart';
import 'package:yenposapp/screens/sales_order/sales_order_providers/photoProvider.dart';
import 'package:yenposapp/screens/sales_order/screens/create_salesOrder.dart/models/held_order_model.dart';

bool isRequestInProgress = false; // Added variable definition
Future<void> restoreHeldOrderData(BuildContext context, HeldOrder order) async {
  if (isRequestInProgress) {
    return;
  }

  isRequestInProgress = true;

  try {
    await Future.microtask(() {
      final customerScreenProvider =
          Provider.of<CustomerScreenProvider>(context, listen: false);
      final audioprovider = Provider.of<AudioProvider>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final detailsProvider =
          Provider.of<DetailsProvider>(context, listen: false);
      final photoProvider = Provider.of<PhotoProvider>(context, listen: false);

      cartProvider.clearCart();

      customerScreenProvider.dateController.text = order.deliveryDate ?? '';

      customerScreenProvider.timeController.text = order.deliveryTime ?? '';

      customerScreenProvider.setSelectedEvent(order.event);

      customerScreenProvider.setSelectedDeliveryType(order.deliveryType);

      customerScreenProvider.landmarkController.text = order.landmark ?? '';

      customerScreenProvider.addressController.text = order.address ?? '';
      customerScreenProvider.birthdaydateController.text =
          order.eventDate ?? '';
      customerScreenProvider.remarkController.text = order.remarks ?? '';

      customerScreenProvider.customerNameController.text =
          order.customerName ?? '';
      customerScreenProvider.remarkController.text = order.remarks ?? '';

      customerScreenProvider.mobileNoController.text =
          order.customerNumber ?? '';
      final mobile = customerScreenProvider.mobileNoController.text;
      final name = customerScreenProvider.customerNameController.text;
      customerScreenProvider.combinedController.text =
          (mobile.isNotEmpty && name.isNotEmpty)
              ? '$mobile - $name'
              : mobile.isNotEmpty
                  ? mobile
                  : '';
      customerScreenProvider.searchController.text = order.employeeName;

      detailsProvider.filteredEmployeeFirstNames.clear();

      customerScreenProvider.setSelectedHoldOrderId(order.holdOrderId);

      for (int index = 0; index < order.itemName.length; index++) {
        cartProvider.addItemToCart(CartItem(
          varianceName: order.varianceName[index],
          itemName: order.itemName[index],
          pricePerKg: order.price[index],
          tax: order.tax[index],
          itemCode: order.itemCode[index],
          uom: order.uom[index],
          quantity: order.qty[index],
          weight: order.weight[index],
          itemWiseDiscountAmount: order.itemWiseDiscountAmount![index],
          itemWiseDiscount: order.itemWiseDiscount![index],
        ));
      }
    });

    if (context.mounted) {
      GlobalScaffold.showMessage(
        message: 'Order data restored to form',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    }

    await Future.delayed(const Duration(milliseconds: 100));
    Navigator.pop(context);
  } catch (e, stackTrace) {
  } finally {
    isRequestInProgress = false;
  }
}

// lib/Sale_order/Screens/sales_order_appbar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Sale_order/Widgets/saleorder_widget/create_order_widgets.dart';

class SalesOrderAppBar {
  static PreferredSizeWidget build(BuildContext context) {
    final selectionProvider = Provider.of<CartSelectionProvider>(context);
    final orderTypeProvider = Provider.of<CustomerScreenProvider>(context);

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text('Create Orders', style: TextStyle(color: Colors.black)),
        ],
      ),
      centerTitle: false,
      flexibleSpace: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SalesOrderWidgets.buildNavButton(
                        label: 'Current Orders',
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/current-orders'),
                      ),
                      const SizedBox(width: 10),
                      SalesOrderWidgets.buildNavButton(
                        label: 'All Orders',
                        onPressed: () async {
                          Navigator.of(context).pushNamed('/all-orders');
                        },
                      ),
                      const SizedBox(width: 10),
                      SalesOrderWidgets.buildCreateOrderButton(
                        selectionProvider,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ✅ Toggle Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: Text('Inhouse'),
                  selected: orderTypeProvider.orderType == 'Inhouse',
                  onSelected: (selected) {
                    if (selected) orderTypeProvider.setOrderType('Inhouse');
                  },
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: orderTypeProvider.orderType == 'Inhouse'
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: Text('Warehouse'),
                  selected: orderTypeProvider.orderType == 'Warehouse',
                  onSelected: (selected) {
                    if (selected) orderTypeProvider.setOrderType('Warehouse');
                  },
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: orderTypeProvider.orderType == 'Warehouse'
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      toolbarHeight: kToolbarHeight * 2, // taller to fit toggle
    );
  }
}

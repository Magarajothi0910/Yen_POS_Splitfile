// lib/Sale_order/Screens/sales_order_appbar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Widgets/saleorder_widget/create_order_widgets.dart';


class SalesOrderAppBar {
  static PreferredSizeWidget build(BuildContext context) {
    final selectionProvider = Provider.of<CartSelectionProvider>(context);
    
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
        child: Row(
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
                  SalesOrderWidgets.buildCreateOrderButton(selectionProvider),
                ],
              ),
            ),
            _buildStoreTypeToggle(context),
          ],
        ),
      ),
      toolbarHeight: kToolbarHeight,
    );
  }

  static Widget _buildStoreTypeToggle(BuildContext context) {
    final customerProvider = Provider.of<CustomerScreenProvider>(context);

    return ToggleButtons(
      constraints: BoxConstraints(minHeight: 40.0, minWidth: 80.0),
      borderRadius: BorderRadius.circular(8.0),
      borderWidth: 2,
      borderColor: Colors.blueGrey,
      selectedBorderColor: Colors.blue,
      fillColor: Colors.blue,
      splashColor: Colors.blue.withOpacity(0.3),
      color: Colors.black,
      selectedColor: Colors.white,
      isSelected: [
        customerProvider.selectedStoreType == 'Inhouse',
        customerProvider.selectedStoreType == 'Warehouse',
      ],
      onPressed: (index) {
        final type = index == 0 ? 'Inhouse' : 'Warehouse';
        customerProvider.saveStoreType(type);
      },
      children: [
        SalesOrderWidgets.buildToggleButtonLabel('Inhouse'),
        SalesOrderWidgets.buildToggleButtonLabel('Warehouse'),
      ],
    );
  }
}
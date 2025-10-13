import 'package:flutter/material.dart';

import '../../all_orders_page/services/get_sales_order_service.dart';
import '../../model/sales_order_display_model.dart';
import 'empty_order_state.dart';
import 'order_actions.dart';
import 'order_header.dart';
import 'order_items_list.dart';
import 'order_summary.dart';

class OrderDetails extends StatelessWidget {
  final List<SalesOrderDisplay> orders;
  final int? selectedIndex;
  final ApiServiceSalesOrderProvider apiService;

  const OrderDetails({
    super.key,
    required this.orders,
    required this.selectedIndex,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == null || orders.isEmpty) {
      return const EmptyOrderState();
    }

    final salesOrder = orders[selectedIndex!];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderHeader(salesOrder: salesOrder),
          Divider(color: Colors.grey[400]),
          OrderItemsList(salesOrder: salesOrder),
          OrderSummary(salesOrder: salesOrder),
          OrderActions(salesOrder: salesOrder),
        ],
      ),
    );
  }
}

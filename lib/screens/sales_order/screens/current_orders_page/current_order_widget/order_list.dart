import 'package:flutter/material.dart';

import '../../../../../Global/smartsearchtextfield.dart';
import '../../all_orders_page/services/get_sales_order_service.dart';
import '../../model/sales_order_display_model.dart';

class OrderList extends StatelessWidget {
  final List<SalesOrderDisplay> orders;
  final ApiServiceSalesOrderProvider apiService;
  final int? selectedIndex;
  final ValueChanged<int> onOrderSelected;

  const OrderList({
    super.key,
    required this.orders,
    required this.apiService,
    required this.selectedIndex,
    required this.onOrderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController _searchController = TextEditingController();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          // child: SmartSearchField(),
          child: SmartSearchField(
            controller: _searchController,
            onSearch: (query) {
              apiService.searchOrders(query);
            },
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? const Center(
                  child: Text("No orders available"),
                )
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];

                    return Card(
                      color: order.status == "dispatched"
                          ? Colors.red[200]
                          : Colors.white,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    order.orderType ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Order ID',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700]),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Order Taken By',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Status',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ListTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text(order.saleOrderNo)),
                                  Expanded(
                                      child: Text(order.employeeName ?? 'N/A')),
                                  Expanded(child: Text(order.status)),
                                ],
                              ),
                              selected: selectedIndex == index,
                              onTap: () {
                                onOrderSelected(index);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

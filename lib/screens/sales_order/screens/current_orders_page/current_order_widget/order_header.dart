import 'package:flutter/material.dart';

import '../../model/sales_order_display_model.dart';

class OrderHeader extends StatelessWidget {
  final SalesOrderDisplay salesOrder;

  const OrderHeader({super.key, required this.salesOrder});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Type',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(salesOrder.paymentType, style: const TextStyle(fontSize: 11)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order ID',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(
              salesOrder.salesOrderId.length > 5
                  ? salesOrder.salesOrderId
                      .substring(salesOrder.salesOrderId.length - 5)
                  : salesOrder.salesOrderId,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

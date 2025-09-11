import 'package:flutter/material.dart';
import '../../model/sales_order_model.dart';

class OrderSummary extends StatelessWidget {
  final SalesOrderDisplay salesOrder;

  const OrderSummary({super.key, required this.salesOrder});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (salesOrder.discount > 0)
            Text(
              'Discount: ${salesOrder.discountAmount}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          if (salesOrder.customCharge > 0)
            Text(
              'Custom Charge: ₹${salesOrder.customCharge.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          Text(
            'Total Amount: ₹${salesOrder.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            'Advance Amount: ₹${salesOrder.advanceAmount}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../model/sales_order_display_model.dart';

class OrderItemTile extends StatelessWidget {
  final SalesOrderDisplay salesOrder;
  final int index;
  final bool showAsBoxItem;

  const OrderItemTile({
    super.key,
    required this.salesOrder,
    required this.index,
    required this.showAsBoxItem,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        salesOrder.varianceName[index],
        style: TextStyle(
          fontSize: 12,
          color: showAsBoxItem ? Colors.blue[800] : Colors.grey,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            salesOrder.uom[index] != 'Kgs'
                ? '${salesOrder.qty[index]} ${salesOrder.uom[index]} x ${salesOrder.price[index]}'
                : '${salesOrder.weight[index]} ${salesOrder.uom[index]} x ${salesOrder.price[index]}',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '₹${salesOrder.amount[index].toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: showAsBoxItem ? Colors.blue[800] : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

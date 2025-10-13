import 'package:flutter/material.dart';
import '../../model/sales_order_display_model.dart';
import 'box_items_card.dart';
import 'order_item_tile.dart';

class OrderItemsList extends StatelessWidget {
  final SalesOrderDisplay salesOrder;

  const OrderItemsList({super.key, required this.salesOrder});

  @override
  Widget build(BuildContext context) {
    if (salesOrder.isBoxItem == null ||
        salesOrder.varianceName == null ||
        salesOrder.isBoxItem!.length != salesOrder.varianceName.length) {
      return const Center(child: Text('Data is incomplete or invalid'));
    }

    List<int> boxItemIndices = [];
    List<int> nonBoxItemIndices = [];

    for (int i = 0; i < salesOrder.varianceName.length; i++) {
      if (salesOrder.isBoxItem![i].toLowerCase() == 'yes') {
        boxItemIndices.add(i);
      } else {
        nonBoxItemIndices.add(i);
      }
    }

    int itemCount =
        nonBoxItemIndices.length + (boxItemIndices.isNotEmpty ? 1 : 0);

    if (itemCount == 0) {
      return const SizedBox();
    }

    return Expanded(
      child: ListView.separated(
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (boxItemIndices.isNotEmpty && index == 0) {
            return BoxItemsCard(
              salesOrder: salesOrder,
              boxIndices: boxItemIndices,
            );
          }

          final adjustedIndex = index - (boxItemIndices.isNotEmpty ? 1 : 0);
          if (adjustedIndex >= nonBoxItemIndices.length) {
            return const SizedBox();
          }

          return OrderItemTile(
            salesOrder: salesOrder,
            index: nonBoxItemIndices[adjustedIndex],
            showAsBoxItem: false,
          );
        },
      ),
    );
  }
}

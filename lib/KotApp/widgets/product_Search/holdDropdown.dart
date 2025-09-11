import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../kotproviders/cartprovider.dart';
import '../../kotproviders/hold_order.dart';
import '../../screens/productsCard.dart';

Widget buildHoldOrdersDropdown(
    BuildContext context, String currentTable, String currentSeat) {
  final holdOrderProvider =
      Provider.of<HoldOrderProvider>(context, listen: false);
  final cartProvider = Provider.of<CartProviderkot>(context, listen: false);
  final holdOrders = holdOrderProvider.getAllHoldOrders();

  // Remove current table and seat from the dropdown list
  final filteredOrders = holdOrders
      .where((order) =>
          order['table'] != currentTable || order['seat'] != currentSeat)
      .toList();
  filteredOrders.sort((a, b) {
    final RegExp numberRegex = RegExp(r'\d+');
    final tableA = a['table'];
    final tableB = b['table'];
    final seatA = a['seat'];
    final seatB = b['seat'];

    final int tableNumA =
        int.tryParse(numberRegex.firstMatch(tableA)?.group(0) ?? '0') ?? 0;
    final int tableNumB =
        int.tryParse(numberRegex.firstMatch(tableB)?.group(0) ?? '0') ?? 0;

    final int tableComparison = tableNumA.compareTo(tableNumB);
    if (tableComparison == 0) {
      return seatA.compareTo(seatB);
    } else {
      return tableComparison;
    }
  });
  bool hasOrders = filteredOrders.isNotEmpty;
  int holdOrderCount = filteredOrders.length;

  return IntrinsicWidth(
    child: SizedBox(
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12, width: 1.5),
              borderRadius: BorderRadius.circular(8.0),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: false,
                icon: const Icon(Icons.arrow_drop_down, size: 18),
                hint: const Text(
                  'Hold Orders',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                dropdownColor: Colors.white,
                items: hasOrders
                    ? holdOrders.map<DropdownMenuItem<String>>((order) {
                        final table = order['table'];
                        final seat = order['seat'];
                        return DropdownMenuItem<String>(
                          value: '$table|$seat',
                          child: Text(
                            '$table - Seat $seat',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList()
                    : null,
                onChanged: hasOrders
                    ? (value) {
                        if (value != null) {
                          final parts = value.split('|');
                          final table = parts[0];
                          final seat = parts[1];

                          final holdOrder =
                              holdOrderProvider.loadHoldOrder(table, seat);

                          if (holdOrder != null) {
                            cartProvider.loadCart(holdOrder);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductCardScreen(
                                  tableNumber: table,
                                  seat: seat,
                                  seathiveOrderId: null,
                                ),
                              ),
                            );
                          }
                        }
                      }
                    : null,
              ),
            ),
          ),
          if (holdOrderCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(4.0),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4.0,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$holdOrderCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

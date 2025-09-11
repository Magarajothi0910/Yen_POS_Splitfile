import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../kotproviders/order_provider.dart';
import '../kotproviders/order_type_provider.dart';
import '../kotproviders/printer_provider.dart';

class CanceledOrdersScreen extends StatefulWidget {
  const CanceledOrdersScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CanceledOrdersScreenState createState() => _CanceledOrdersScreenState();
}

class _CanceledOrdersScreenState extends State<CanceledOrdersScreen> {
  String? storedDeviceCode;
  @override
  void initState() {
    super.initState();
    loadDeviceCode();
  }

  Future<void> loadDeviceCode() async {
    var box = await Hive.openBox('deviceData');
    setState(() {
      storedDeviceCode = box.get('deviceCode');
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final printerProvider = Provider.of<PrinterProvider>(context);
    final orderTypeProvider =
        Provider.of<OrderTypeProvider>(context, listen: false);

    Future<void> initHive() async {
      await orderProvider.initializeHive();
    }

    initHive();

    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        // final orders = orderProvider.orders; //dispalying all client orders

        final orders = orderProvider.orders
            .where((order) =>
                //  order['deviceId'] == storedDeviceCode &&
                order['status'] == "cancelled")
            .toList();
        final Map<String, Set<String>> tableseats = {};
        String seathiveOrderId = "";
        for (var order in orders) {
          final String tableNumber = order['table'].toString();
          final String seat = order['seat'];
          tableseats.putIfAbsent(tableNumber, () => {}).add(seat);
        }

        final sortedTables = tableseats.keys.toList()..sort();

        return Scaffold(
          // appBar: AppBar(
          //   leading: IconButton(
          //     icon: const Icon(Icons.home), // Use home icon
          //     onPressed: () {
          //       // Navigate to the home screen or root of navigation
          //       Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //           builder: (context) => TableScreen(),
          //         ),
          //       );
          //     },
          //   ),
          //   title: const Text('------ Cancelled orders ------'),
          //   backgroundColor: const Color(0xFFDBF0F7),
          // ),
          body: Container(
            color: const Color(0xFFDBF0F7), // Set background color to blue
            child: ListView.builder(
              itemCount: sortedTables.length,
              itemBuilder: (context, index) {
                final tableNumber = sortedTables[index];

                final seats = tableseats[tableNumber]!.toList();
                double tableTotal = seats.fold(
                  0.0,
                  (previousValue, seat) {
                    final cancelledOrders = orderProvider
                        .getCancelledOrdersForSeat(tableNumber, seat)
                        .where((order) => order['status'] == 'cancelled')
                        .toList();

                    // Sum the totalAmount field
                    final seatTotal = cancelledOrders.fold(0.0, (sum, order) {
                      return sum + (order['totalAmount'] ?? 0.0);
                    });

                    return previousValue + seatTotal;
                  },
                );

                return Card(
                  margin: const EdgeInsets.all(10.0),
                  color: Colors.white, // Card background color to white
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor:
                          Colors.transparent, // Makes dividers transparent
                    ),
                    child: ExpansionTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ' $tableNumber',
                            style: const TextStyle(
                              color: Colors
                                  .red, // Set the total text color to green
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Total: ₹${tableTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors
                                  .green, // Set the total text color to green
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      children: seats.map((seat) {
                        final seatOrders = orderProvider
                            .getCancelledOrdersForSeat(tableNumber, seat)
                            .where((order) =>
                                order['status'] ==
                                "cancelled") // Filter only active orders
                            .toList();
                        final total = seatOrders.fold(0.0, (sum, order) {
                          return sum + (order['totalAmount'] ?? 0.0);
                        });

                        if (seatOrders.isEmpty) {
                          return const SizedBox
                              .shrink(); // Skip rendering if no active orders
                        }

                        return Card(
                          margin: const EdgeInsets.all(10.0),
                          color: const Color(0xFFF4FDFF),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('SEAT $seat',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold)),

                                    // Update UI after cancellation
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: seatOrders.map((order) {
                                    int orderIndex =
                                        seatOrders.indexOf(order) + 1;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Order $orderIndex: TknNo ${order['tokenNo']}',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const Divider(),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: Column(
                                            children: [
                                              // Header Row
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 4.0),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        'Item',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 10),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        'Qty',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 10),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        'Wt',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 10),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        'Price',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 10),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        'Total',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 10),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Divider(),

                                              // Data Rows
                                              ...List.generate(
                                                  order['varianceNames'].length,
                                                  (i) {
                                                final String varianceNames =
                                                    order['varianceNames'][i];
                                                final double price =
                                                    order['prices'][i];
                                                final double quantity =
                                                    order['quantities'][i];
                                                final double weight =
                                                    order['weights'][i] ?? 0.0;
                                                final String uom = order['uoms']
                                                        [i]
                                                    .toString()
                                                    .toLowerCase();

                                                // Calculate total based on UOM
                                                final double itemTotal = (uom ==
                                                            'kg' ||
                                                        uom == 'kgs')
                                                    ? price * quantity * weight
                                                    : price * quantity;

                                                return Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 4.0),
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          // Item Name Column
                                                          Expanded(
                                                            flex: 4,
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                    '${order['varianceNames'][i]}',
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            10)),
                                                              ],
                                                            ),
                                                          ),

                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                                '${quantity.toInt()}',
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            10)),
                                                          ),

                                                          // Unit Column
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                                weight > 0
                                                                    ? weight
                                                                        .toStringAsFixed(
                                                                            2)
                                                                    : '-',
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            10)),
                                                          ),

                                                          // Quantity Column

                                                          Expanded(
                                                            flex: 3,
                                                            child: Text(
                                                                '₹${price.toInt()}',
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            10)),
                                                          ),
                                                          Text(
                                                              '₹${itemTotal.toInt()}',
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          10)),
                                                          // Actions Column (Edit and Cancel Icons)
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Total: ₹$total',
                                  style: const TextStyle(
                                      color: Colors
                                          .green, // Set the total text color to green
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                //Text(seatOrders.toString()),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

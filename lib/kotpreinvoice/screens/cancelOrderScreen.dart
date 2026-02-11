// // ignore_for_file: unused_local_variable

// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import '../providers/order_type_provider.dart';
// import 'package:provider/provider.dart';
// import '../providers/order_provider.dart';
// import '../providers/printer_provider.dart';

// class CanceledOrdersScreen extends StatefulWidget {
//   const CanceledOrdersScreen({super.key});

//   @override
//   // ignore: library_private_types_in_public_api
//   _CanceledOrdersScreenState createState() => _CanceledOrdersScreenState();
// }

// class _CanceledOrdersScreenState extends State<CanceledOrdersScreen> {
//   String? storedDeviceCode;
//   @override
//   @override
//   Widget build(BuildContext context) {
//     final orderProvider = Provider.of<OrderProvider>(context, listen: false);
//     final printerProvider = Provider.of<PrinterProviderDine>(context);
//     final orderTypeProvider =
//         Provider.of<OrderTypeProviderDine>(context, listen: false);

//     Future<void> initHive() async {
//       await orderProvider.initializeHive();
//     }

//     initHive();

//     return Consumer<OrderProvider>(
//       builder: (context, orderProvider, _) {
//         // final orders = orderProvider.orders; //dispalying all client orders

//         final orders = orderProvider.orders
//             .where((order) => order['status'] == "cancelled")
//             .toList();
//         final Map<String, Set<String>> tableseats = {};
//         for (var order in orders) {
//           // final String tableNumber = order['table'].toString();
//           // final String seat = order['seat'];
//           // tableseats.putIfAbsent(tableNumber, () => {}).add(seat);
//           final String actualTableNumber = order['table'].toString();
//           final String baseTableNumber =
//               actualTableNumber.replaceAll(RegExp(r'\([A-Z]\)$'), '');
//           final String seat = order['seat'];
//           tableseats.putIfAbsent(baseTableNumber, () => {}).add(seat);
//         }

//         final sortedTables = tableseats.keys.toList()
//           ..sort((a, b) {
//             final RegExp regExp = RegExp(r'\d+');
//             final int numA =
//                 int.tryParse(regExp.firstMatch(a)?.group(0) ?? '0') ?? 0;
//             final int numB =
//                 int.tryParse(regExp.firstMatch(b)?.group(0) ?? '0') ?? 0;
//             return numA.compareTo(numB);
//           });

//         return Scaffold(
//           backgroundColor: Colors.white,
//           body: Container(
//             color: Colors.white,
//             // decoration: BoxDecoration(
//             //   borderRadius: BorderRadius.circular(10.0),
//             //   boxShadow: [
//             //     BoxShadow(
//             //       spreadRadius: 5,
//             //       blurRadius: 7,
//             //       offset: const Offset(0, 4),
//             //     ),
//             //   ],
//             // ),
//             child: ListView.builder(
//               itemCount: sortedTables.length,
//               itemBuilder: (context, index) {
//                 final tableNumber = sortedTables[index];

//                 final seats = tableseats[tableNumber]!.toList();

//                 double tableTotal = seats.fold(
//                   0.0,
//                   (previousValue, seat) {
//                     final cancelledOrders = orderProvider
//                         .getCancelledOrdersForSeat(tableNumber, seat)
//                         .where((order) => order['status'] == 'cancelled')
//                         .toList();

//                     // Sum the totalAmount field
//                     final seatTotal = cancelledOrders.fold(0.0, (sum, order) {
//                       return sum + (order['totalAmount'] ?? 0.0);
//                     });

//                     return previousValue + seatTotal;
//                   },
//                 );

//                 return Card(
//                   margin: const EdgeInsets.all(10.0),
//                   color: Colors.white, // Card background color to white
//                   child: Theme(
//                     data: Theme.of(context).copyWith(
//                       dividerColor:
//                           Colors.transparent, // Makes dividers transparent
//                     ),
//                     child: ExpansionTile(
//                       title: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             ' $tableNumber',
//                             style: const TextStyle(
//                               color: Colors
//                                   .red, // Set the total text color to green
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(width: 5),
//                           Text(
//                             'Total: ₹${tableTotal.toStringAsFixed(0)}',
//                             style: const TextStyle(
//                               color: Colors
//                                   .green, // Set the total text color to green
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                       children: seats.map((seat) {
//                         final seatOrders = orderProvider
//                             .getCancelledOrdersForSeat(tableNumber, seat)
//                             .where((order) =>
//                                 order['status'] ==
//                                 "cancelled") // Filter only active orders
//                             .toList();
//                         final total = seatOrders.fold(0.0, (sum, order) {
//                           return sum + (order['totalAmount'] ?? 0.0);
//                         });

//                         if (seatOrders.isEmpty) {
//                           return const SizedBox
//                               .shrink(); // Skip rendering if no active orders
//                         }

//                         return Card(
//                           margin: const EdgeInsets.all(10.0),
//                           color: Colors.white,
//                           child: Padding(
//                             padding: const EdgeInsets.all(8.0),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text('SEAT $seat',
//                                         style: const TextStyle(
//                                             fontSize: 15,
//                                             fontWeight: FontWeight.bold)),

//                                     // Update UI after cancellation
//                                   ],
//                                 ),
//                                 const SizedBox(height: 5),
//                                 Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: seatOrders.map((order) {
//                                     int orderIndex =
//                                         seatOrders.indexOf(order) + 1;
//                                     print("order33..");
//                                     print(orderIndex);
//                                     print(order);
//                                     print(
//                                         "seatOrders in order summary screen ");
//                                     print(seatOrders);
//                                     return Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           'Order $orderIndex: TknNo ${order['tokenNo']}',
//                                           style: const TextStyle(
//                                               fontSize: 13,
//                                               fontWeight: FontWeight.bold),
//                                         ),
//                                         const Divider(),
//                                         Padding(
//                                           padding: const EdgeInsets.symmetric(
//                                               vertical: 8.0),
//                                           child: Column(
//                                             children: [
//                                               // Header Row
//                                               const Padding(
//                                                 padding: EdgeInsets.symmetric(
//                                                     vertical: 4.0),
//                                                 child: Row(
//                                                   children: [
//                                                     Expanded(
//                                                       flex: 3,
//                                                       child: Text(
//                                                         'Item',
//                                                         style: TextStyle(
//                                                             fontWeight:
//                                                                 FontWeight.bold,
//                                                             fontSize: 10),
//                                                       ),
//                                                     ),
//                                                     Expanded(
//                                                       flex: 2,
//                                                       child: Text(
//                                                         'Qty',
//                                                         style: TextStyle(
//                                                             fontWeight:
//                                                                 FontWeight.bold,
//                                                             fontSize: 10),
//                                                       ),
//                                                     ),
//                                                     Expanded(
//                                                       flex: 2,
//                                                       child: Text(
//                                                         'Wt',
//                                                         style: TextStyle(
//                                                             fontWeight:
//                                                                 FontWeight.bold,
//                                                             fontSize: 10),
//                                                       ),
//                                                     ),
//                                                     Expanded(
//                                                       flex: 2,
//                                                       child: Text(
//                                                         'Price',
//                                                         style: TextStyle(
//                                                             fontWeight:
//                                                                 FontWeight.bold,
//                                                             fontSize: 10),
//                                                       ),
//                                                     ),
//                                                     Expanded(
//                                                       flex: 2,
//                                                       child: Text(
//                                                         'Total',
//                                                         style: TextStyle(
//                                                             fontWeight:
//                                                                 FontWeight.bold,
//                                                             fontSize: 10),
//                                                       ),
//                                                     ),
//                                                   ],
//                                                 ),
//                                               ),
//                                               const Divider(),

//                                               // Data Rows
//                                               ...List.generate(
//                                                   order['varianceNames'].length,
//                                                   (i) {
//                                                 final String varianceNames =
//                                                     order['varianceNames'][i];
//                                                 final double price =
//                                                     order['prices'][i];
//                                                 final double quantity =
//                                                     order['quantities'][i];
//                                                 final double weight =
//                                                     order['weights'][i] ?? 0.0;
//                                                 final String uom = order['uoms']
//                                                         [i]
//                                                     .toString()
//                                                     .toLowerCase();

//                                                 // Calculate total based on UOM
//                                                 final double itemTotal = (uom ==
//                                                             'kg' ||
//                                                         uom == 'Kgs')
//                                                     ? price * quantity * weight
//                                                     : price * quantity;

//                                                 return Padding(
//                                                   padding: const EdgeInsets
//                                                       .symmetric(vertical: 4.0),
//                                                   child: Column(
//                                                     children: [
//                                                       Row(
//                                                         children: [
//                                                           // Item Name Column
//                                                           Expanded(
//                                                             flex: 4,
//                                                             child: Column(
//                                                               crossAxisAlignment:
//                                                                   CrossAxisAlignment
//                                                                       .start,
//                                                               children: [
//                                                                 Text(
//                                                                     '${order['varianceNames'][i]}',
//                                                                     style: const TextStyle(
//                                                                         fontSize:
//                                                                             10)),
//                                                               ],
//                                                             ),
//                                                           ),

//                                                           Expanded(
//                                                             flex: 2,
//                                                             child: Text(
//                                                                 '${quantity.toInt()}',
//                                                                 style:
//                                                                     const TextStyle(
//                                                                         fontSize:
//                                                                             10)),
//                                                           ),

//                                                           // Unit Column
//                                                           Expanded(
//                                                             flex: 2,
//                                                             child: Text(
//                                                                 weight > 0
//                                                                     ? weight
//                                                                         .toStringAsFixed(
//                                                                             2)
//                                                                     : '-',
//                                                                 style:
//                                                                     const TextStyle(
//                                                                         fontSize:
//                                                                             10)),
//                                                           ),

//                                                           // Quantity Column

//                                                           Expanded(
//                                                             flex: 3,
//                                                             child: Text(
//                                                                 '₹${price.toInt()}',
//                                                                 style:
//                                                                     const TextStyle(
//                                                                         fontSize:
//                                                                             10)),
//                                                           ),
//                                                           Text(
//                                                               '₹${itemTotal.toInt()}',
//                                                               style:
//                                                                   const TextStyle(
//                                                                       fontSize:
//                                                                           10)),
//                                                           // Actions Column (Edit and Cancel Icons)
//                                                         ],
//                                                       ),
//                                                     ],
//                                                   ),
//                                                 );
//                                               }),
//                                             ],
//                                           ),
//                                         ),
//                                         const SizedBox(height: 10),
//                                       ],
//                                     );
//                                   }).toList(),
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Text(
//                                   'Total: ₹$total',
//                                   style: const TextStyle(
//                                       color: Colors
//                                           .green, // Set the total text color to green
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 15),
//                                 ),
//                                 //Text(seatOrders.toString()),
//                                 const SizedBox(height: 10),
//                               ],
//                             ),
//                           ),
//                         );
//                       }).toList(),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yen_pos/kotpreinvoice/providers/order_type_provider.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/printer_provider.dart';

class CanceledOrdersScreen extends StatefulWidget {
  const CanceledOrdersScreen({super.key});

  @override
  _CanceledOrdersScreenState createState() => _CanceledOrdersScreenState();
}

class _CanceledOrdersScreenState extends State<CanceledOrdersScreen> {
  final double fontScale = 1;

  String? storedDeviceCode;

  Future<List<Map<String, dynamic>>> _getCancelledOrders() async {
    try {
      final cancelledBox = await Hive.openBox('cancelledOrderBox');
      return cancelledBox.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      print("❌ Error reading cancelledOrderBox: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final printerProvider = Provider.of<PrinterProviderDine>(context);
    final orderTypeProvider = Provider.of<OrderTypeProviderDine>(
      context,
      listen: false,
    );

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getCancelledOrders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Text(
                "No cancelled orders found",
                style: TextStyle(fontSize: 16 * fontScale),
              ),
            ),
          );
        }

        final Map<String, Set<String>> tableseats = {};
        for (var order in orders) {
          print("order of full cancel orders are  $order");
          final String actualTableNumber = order['table'].toString();
          final String baseTableNumber = actualTableNumber.replaceAll(
            RegExp(r'\([A-Z]\)$'),
            '',
          );
          final String seat = order['seat'] ?? '';
          tableseats.putIfAbsent(baseTableNumber, () => {}).add(seat);
        }

        final sortedTables = tableseats.keys.toList()
          ..sort((a, b) {
            final reg = RegExp(r'\d+');
            final int numA =
                int.tryParse(reg.firstMatch(a)?.group(0) ?? '0') ?? 0;
            final int numB =
                int.tryParse(reg.firstMatch(b)?.group(0) ?? '0') ?? 0;
            return numA.compareTo(numB);
          });

        return Scaffold(
          backgroundColor: Colors.white,
          body: ListView.builder(
            itemCount: sortedTables.length,
            itemBuilder: (context, index) {
              final tableNumber = sortedTables[index];
              final seats = tableseats[tableNumber]!.toList();

              double tableTotal = seats.fold(0.0, (previous, seat) {
                final cancelledOrders = orders
                    .where(
                      (order) =>
                          order['table'].toString().replaceAll(
                                RegExp(r'\([A-Z]\)$'),
                                '',
                              ) ==
                              tableNumber &&
                          order['seat'] == seat,
                    )
                    .toList();

                final seatTotal = cancelledOrders.fold(
                  0.0,
                  (sum, order) => sum + (order['totalAmount'] ?? 0.0),
                );

                return previous + seatTotal;
              });

              return Card(
                margin: const EdgeInsets.all(10),
                color: Colors.white,
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ' $tableNumber',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16 * fontScale,
                          ),
                        ),
                        Text(
                          'Total: ₹${tableTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16 * fontScale,
                          ),
                        ),
                      ],
                    ),
                    children: seats.map((seat) {
                      final seatOrders = orders
                          .where(
                            (order) =>
                                order['table'].toString().replaceAll(
                                      RegExp(r'\([A-Z]\)$'),
                                      '',
                                    ) ==
                                    tableNumber &&
                                order['seat'] == seat,
                          )
                          .toList();

                      final total = seatOrders.fold(
                        0.0,
                        (sum, order) => sum + (order['totalAmount'] ?? 0.0),
                      );

                      if (seatOrders.isEmpty) return const SizedBox.shrink();

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.all(10),

                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SEAT $seat',
                                style: TextStyle(
                                  fontSize: 15 * fontScale,
                                  fontWeight: FontWeight.bold,
                                ),
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
                                        style: TextStyle(
                                          fontSize: 13 * fontScale,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Divider(),

                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      'Item',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            14 * fontScale,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'Qty',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            14 * fontScale,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'Wt',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            14 * fontScale,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'Price',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            14 * fontScale,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'Total',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            14 * fontScale,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Divider(),

                                            // ✅ FIXED ALIGNMENT HERE
                                            ...List.generate(
                                              order['varianceNames'].length,
                                              (i) {
                                                final String varianceName =
                                                    order['varianceNames'][i];

                                                final double price =
                                                    (order['prices'][i] ?? 0)
                                                        .toDouble();
                                                final double quantity =
                                                    (order['quantities'][i] ??
                                                            0)
                                                        .toDouble();
                                                final double weight =
                                                    (order['weights'][i] ?? 0)
                                                        .toDouble();
                                                final String uom =
                                                    order['uoms'][i]
                                                        .toString()
                                                        .toLowerCase();

                                                final double itemTotal =
                                                    (uom == 'Kgs')
                                                    ? price * quantity * weight
                                                    : price * quantity;

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 4,
                                                        child: Text(
                                                          varianceName,
                                                          style: TextStyle(
                                                            fontSize:
                                                                12 * fontScale,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          '${quantity.toInt()}',
                                                          style: TextStyle(
                                                            fontSize:
                                                                12 * fontScale,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          weight > 0
                                                              ? weight
                                                                    .toStringAsFixed(
                                                                      2,
                                                                    )
                                                              : '-',
                                                          style: TextStyle(
                                                            fontSize:
                                                                12 * fontScale,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                          '₹${price.toInt()}',
                                                          style: TextStyle(
                                                            fontSize:
                                                                12 * fontScale,
                                                          ),
                                                        ),
                                                      ),

                                                      /// ✅ FIXED: WRAP TOTAL INSIDE EXPANDED
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          '₹${itemTotal.toInt()}',
                                                          style: TextStyle(
                                                            fontSize:
                                                                12 * fontScale,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
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
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15 * fontScale,
                                ),
                              ),
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
        );
      },
    );
  }
}

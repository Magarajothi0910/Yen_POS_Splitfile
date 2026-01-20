// import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:yenpos/Global/globals_data.dart' as globals;
// import 'package:yenpos/Server_Client/websocketService.dart';
// import 'package:yenpos/kotpreinvoice/providers/order_provider.dart';
import 'package:yenpos/kotpreinvoice/screens/products_card_screen.dart';
// import 'package:yenpos/kotpreinvoice/services/hive_service.dart';
// import 'package:yenpos/kotpreinvoice/services/sendDataToClients.dart';
// import 'package:yenpos/kotpreinvoice/services/table_actions_service.dart';
import '../providers/hold_order.dart';
import '../providers/cartprovider.dart';
// import '../screens/viewtocart.dart';

class HoldOrdersDropdown extends StatefulWidget {
  final ValueNotifier<Map<String, dynamic>>? productCardDataNotifier;
  final ValueNotifier<bool>? showProductCardNotifier;

  const HoldOrdersDropdown({
    Key? key,
    this.productCardDataNotifier,
    this.showProductCardNotifier,
  }) : super(key: key);

  @override
  State<HoldOrdersDropdown> createState() => HoldOrdersDropdownState();
}

class HoldOrdersDropdownState extends State<HoldOrdersDropdown> {
  final ValueNotifier<bool> showProductCardNotifier = ValueNotifier(true);
  final ValueNotifier<Map<String, dynamic>> productCardDataNotifier =
      ValueNotifier<Map<String, dynamic>>({});

  void _showHoldOrdersDialog(BuildContext context) {
    final holdOrderProvider = Provider.of<HoldOrderProvider>(
      context,
      listen: false,
    );
    final holdOrders = holdOrderProvider.getAllHoldOrders();

    // Sort the hold orders
    holdOrders.sort((a, b) {
      final numberRegex = RegExp(r'\d+');
      final int tableA =
          int.tryParse(numberRegex.firstMatch(a['table'])?.group(0) ?? '0') ??
          0;
      final int tableB =
          int.tryParse(numberRegex.firstMatch(b['table'])?.group(0) ?? '0') ??
          0;
      return tableA == tableB
          ? a['seat'].compareTo(b['seat'])
          : tableA.compareTo(tableB);
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.5,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hold Orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${holdOrders.length}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Orders List
              Expanded(
                child: holdOrders.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No hold orders available',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        shrinkWrap: true,
                        itemCount: holdOrders.length,
                        itemBuilder: (context, index) {
                          final order = holdOrders[index];

                          final table = (order['table'] ?? '').toString();
                          final seat = (order['seat'] ?? '').toString();
                          final areaName = (order['areaName'] ?? '').toString();

                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            elevation: 2,
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              title: Text(
                                '$table - Seat $seat',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: areaName.isNotEmpty
                                  ? Text(
                                      'Area: $areaName',
                                      style: const TextStyle(fontSize: 12),
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 25,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  _deleteHoldOrder(context, table, seat, index);
                                },
                              ),

                              // onTap: () {
                              //   // Get the providers
                              //   final cartProvider =
                              //       Provider.of<CartProviderKOT>(
                              //         context,
                              //         listen: false,
                              //       );
                              //   final holdOrderProvider =
                              //       Provider.of<HoldOrderProvider>(
                              //         context,
                              //         listen: false,
                              //       );

                              //   // Clear current cart first
                              //   cartProvider.clearCart();

                              //   // Load hold order into cart
                              //   final holdOrder = holdOrderProvider
                              //       .loadHoldOrder(table, seat);
                              //   if (holdOrder != null) {
                              //     holdOrder.forEach((key, value) {
                              //       cartProvider.cart[key] = value;
                              //     });
                              //     debugPrint(
                              //       "✅ Hold order loaded into cart for $table - Seat $seat",
                              //     );
                              //   }

                              //   // Update cart provider with table info
                              //   cartProvider.currentTableNumber.value = table;
                              //   cartProvider.currentSeat.value = seat;
                              //   cartProvider.currentAreaName.value = areaName;
                              //   cartProvider.currentSeathiveOrderId.value =
                              //       ''; // Hold orders don't have seathiveOrderId

                              //   // Use the parent's notifiers instead of local ones
                              //   final productCardDataNotifier =
                              //       widget.productCardDataNotifier ??
                              //       this.productCardDataNotifier;
                              //   final showProductCardNotifier =
                              //       widget.showProductCardNotifier ??
                              //       this.showProductCardNotifier;

                              //   // Update the notifiers that the parent is listening to
                              //   productCardDataNotifier.value = {
                              //     'tableNumber': table,
                              //     'areaName': areaName,
                              //     'seat': seat,
                              //     'seathiveOrderId': '',
                              //   };
                              //   showProductCardNotifier.value = true;

                              //   TableActionsService.sendSeatActionToServer(
                              //     context: context,
                              //     tableNumber: table,
                              //     seat: seat,
                              //     areaName: areaName,
                              //     productCardDataNotifier:
                              //         productCardDataNotifier,
                              //     showProductCardNotifier:
                              //         showProductCardNotifier,
                              //   );

                              //   Navigator.of(context).pop();

                              //   debugPrint(
                              //     "➡️ Product screen overlay should now be visible for hold order",
                              //   );
                              // },
                              onTap: () {
                                debugPrint(
                                  "🟢 Tapped hold order: $table - Seat $seat",
                                );

                                // Get the providers
                                final cartProvider =
                                    Provider.of<CartProviderKOT>(
                                      context,
                                      listen: false,
                                    );
                                final holdOrderProvider =
                                    Provider.of<HoldOrderProvider>(
                                      context,
                                      listen: false,
                                    );
                                final eventProvider =
                                    Provider.of<ProductEventProvider>(
                                      context,
                                      listen: false,
                                    );

                                // Clear current cart first
                                cartProvider.clearCart();
                                debugPrint("🧹 Cart cleared");

                                // Load hold order into cart
                                final holdOrder = holdOrderProvider
                                    .loadHoldOrder(table, seat);
                                if (holdOrder != null) {
                                  holdOrder.forEach((key, value) {
                                    cartProvider.cart[key] = value;
                                  });
                                  debugPrint(
                                    "✅ Hold order loaded into cart. Items: ${holdOrder.length}",
                                  );
                                } else {
                                  debugPrint(
                                    "⚠️ No hold order found for $table - Seat $seat",
                                  );
                                }

                                // Update cart provider with table info
                                cartProvider.currentTableNumber.value = table;
                                cartProvider.currentSeat.value = seat;
                                cartProvider.currentAreaName.value = areaName;
                                cartProvider.currentSeathiveOrderId.value = '';

                                debugPrint("📝 Cart provider updated:");
                                debugPrint(
                                  "   - Table: ${cartProvider.currentTableNumber.value}",
                                );
                                debugPrint(
                                  "   - Seat: ${cartProvider.currentSeat.value}",
                                );
                                debugPrint(
                                  "   - Area: ${cartProvider.currentAreaName.value}",
                                );

                                // Send event to TableScreen to show overlay
                                eventProvider.addEvent(
                                  ProductEvent(
                                    action: 'show_overlay',
                                    tableNumber: table,
                                    seat: seat,
                                    areaName: areaName,
                                    productData: {
                                      'isHoldOrder': true,
                                    }, // Mark as hold order
                                  ),
                                );

                                Navigator.of(context).pop();
                                debugPrint(
                                  "➡️ Event sent to show overlay for hold order",
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),

              // Close Button at Bottom Right
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        minimumSize: const Size(100, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteHoldOrder(
    BuildContext context,
    String table,
    String seat,
    int index,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Hold Order'),
          content: Text(
            'Are you sure you want to delete the hold order for $table - Seat $seat?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final holdOrderProvider = Provider.of<HoldOrderProvider>(
                  context,
                  listen: false,
                );

                holdOrderProvider.removeHoldOrder(table, seat);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hold order for $table - Seat $seat deleted'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );

                Navigator.of(context).pop();
                Navigator.of(context).pop();

                // _showHoldOrdersDialog(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   final holdOrderProvider = Provider.of<HoldOrderProvider>(
  //     context,
  //     listen: false,
  //   );
  //   final holdOrders = holdOrderProvider.getAllHoldOrders();

  //   return SizedBox(
  //     // width: double.infinity,
  //     child: Stack(
  //       clipBehavior: Clip.none,
  //       children: [
  //         ElevatedButton(
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.white70,
  //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  //             padding: const EdgeInsets.symmetric(vertical: 17),
  //             minimumSize: const Size(double.infinity, 40),
  //           ),
  //           onPressed: () {
  //             if (holdOrders.isNotEmpty) {
  //               _showHoldOrdersDialog(context);
  //             }
  //           },
  //           child: const Text(
  //             "Hold Orders (",
  //             style: TextStyle(
  //               fontSize: 15,
  //               letterSpacing: 0.5,
  //               color: Colors.blue,
  //             ),
  //           ),
  //         ),

  //         if (holdOrders.isNotEmpty)
  //           Positioned(
  //             top: -6,
  //             left: -6,
  //             child: Container(
  //               padding: const EdgeInsets.all(4),
  //               decoration: const BoxDecoration(
  //                 color: Colors.red,
  //                 shape: BoxShape.circle,
  //                 boxShadow: [
  //                   BoxShadow(
  //                     color: Colors.black26,
  //                     blurRadius: 4,
  //                     offset: Offset(2, 2),
  //                   ),
  //                 ],
  //               ),
  //               child: Text(
  //                 '${holdOrders.length}',
  //                 style: const TextStyle(
  //                   color: Colors.white,
  //                   fontSize: 12,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final holdOrderProvider = Provider.of<HoldOrderProvider>(
      context,
      listen: false,
    );
    final holdOrders = holdOrderProvider.getAllHoldOrders();

    return SizedBox(
      // width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          shadowColor: Colors.black,
          elevation: 1,
          backgroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(vertical: 19),
          minimumSize: const Size(double.infinity, 40),
        ),
        onPressed: () {
          if (holdOrders.isNotEmpty) {
            _showHoldOrdersDialog(context);
          }
        },
        child: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Hold Orders ',
                style: TextStyle(
                  fontSize: 17,
                  letterSpacing: 0.5,
                  color: Colors.blue,
                ),
              ),
              if (holdOrders.isNotEmpty)
                TextSpan(
                  text: '(${holdOrders.length})',
                  style: const TextStyle(
                    fontSize: 17,
                    letterSpacing: 0.5,
                    color: Colors.blue, // Red color for the count
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

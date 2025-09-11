// ignore: file_names
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../Helper/RemarkTextfield.dart';
import '../../screens/order_summary_screen.dart';
import '../../kotservices/CancelOrder_Patch.dart';
import '../../kotservices/CancellationReceipt.dart';
import '../../kotservices/preInv Utility.dart';
import '../../kotservices/preInvociePrint_services.dart';
import '../../../screens/kot_screen/global/globals.dart';
import '../../models/printer.dart';
import '../../kotproviders/bottomNavprovider.dart';
import '../../kotproviders/order_provider.dart';
import '../../kotproviders/printer_provider.dart';
import '../../kotproviders/product_provider.dart';
import '../capitalizeWord.dart';

class OrderSummaryCard extends StatefulWidget {
  final String tableNumber;
  final String seat;
  final List<Map<String, dynamic>> seatOrders;
  final double seatTotal;
  final String waiter;
  final String loggedInUserName;

  const OrderSummaryCard({
    Key? key,
    required this.tableNumber,
    required this.seat,
    required this.seatOrders,
    required this.seatTotal,
    required this.waiter,
    required this.loggedInUserName,
  }) : super(key: key);

  @override
  _OrderSummaryCardState createState() => _OrderSummaryCardState();
}

class _OrderSummaryCardState extends State<OrderSummaryCard> {
  late WebSocketChannel channel;
  Map<int, String?> selectedVariants = {};
  late final OrderProvider orderProvider;

  @override
  void initState() {
    super.initState();

    // Initialize the WebSocket channel
    channel = WebSocketChannel.connect(
      Uri.parse('ws://$serverip:$port'),
    );

    // Optionally listen to incoming messages
    channel.stream.listen((message) {});
    // orderProvider.channel.stream.listen((message) {
    //   // Check if the widget is still mounted before calling any context-based methods.
    //   if (mounted) {
    //     orderProvider.handleIncomingMessage(message);
    //   }
    // });
  }

  void didChangeDependencies() {
    super.didChangeDependencies();
    orderProvider = context.read<OrderProvider>();
  }

  @override
  void dispose() {
    // now safe to close if you really must:
    orderProvider.channel?.sink.close();
    super.dispose();
  }

  Future<void> reverseCancellation(
      int index, Map<String, dynamic> order) async {
    // Ensure lists are double
    List<double> quantities = (order['quantities'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    List<double> cancelledQty = (order['cancelledQty'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    List<double> amounts =
        (order['amounts'] as List).map((e) => (e as num).toDouble()).toList();

    // Swap back for the single index
    double restoredQty = cancelledQty[index];
    cancelledQty[index] = 0.0;
    quantities[index] = restoredQty;

    // Recalculate total amount
    double totalAmount = 0.0;
    for (int i = 0; i < quantities.length; i++) {
      totalAmount += quantities[i] * amounts[i];
    }

    // Update order object
    order['quantities'] = quantities;
    order['cancelledQty'] = cancelledQty;
    order['totalAmount'] = totalAmount;
    order['partiallycancelled'] = cancelledQty.any((q) => q > 0.0);

    // Only send the updated index info
    final Map<String, dynamic> dataToSend = {
      'action': 'reverseCancelOrderItem',
      'hiveOrderId': order['hiveOrderId'],
      'updatedIndex': index, // New field to indicate affected index
      'updatedQuantity': quantities[index],
      'updatedCancelledQty': cancelledQty[index],
      'totalAmount': totalAmount,
      'partiallycancelled': order['partiallycancelled'],
    };

    await sendMessage(dataToSend);
  }

  Future<void> sendMessage(Map<String, dynamic> configDetails) async {
    try {
      final jsonData = jsonEncode(configDetails);
      channel.sink.add(jsonData);
    } catch (error) {
    }
  }

  @override
  Widget build(BuildContext context) {

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final printerProvider = Provider.of<PrinterProvider>(context);
    // Future<void> patchStatusConfirm(
    //     String tableNumber,
    //     String seat,
    //     List<Map<String, dynamic>> seatOrders,
    //     OrderProvider orderProvider) async {
    //   final uniqueSeatHiveOrderIds = <String>{};
    //   print("patchStatusConfirm function...${seatOrders.length}");
    //   for (var order in seatOrders) {
    //     print("patchStatusConfirm function1...${seatOrders.length}");

    //     final seathiveOrderId = order['seathiveOrderId'];
    //     if (seathiveOrderId != null && seathiveOrderId.isNotEmpty) {
    //       uniqueSeatHiveOrderIds.add(seathiveOrderId);
    //     }
    //   }

    //   for (final seathiveOrderId in uniqueSeatHiveOrderIds) {
    //     await orderProvider.patchOrderStatusBySeathiveOrderId(
    //         seathiveOrderId, "confirm");
    //   }
    // }
    Future<void> patchStatusConfirm(
      String tableNumber,
      String seat,
      List<Map<String, dynamic>> seatOrders,
      OrderProvider orderProvider,
    ) async {
      for (var order in seatOrders) {
        final id = order['seathiveOrderId'] as String?;
        if (id != null && id.isNotEmpty) {
          await orderProvider.patchOrderStatusBySeathiveOrderId(id, "confirm");
        } else {
        }
      }
    }

    return Card(
      margin: const EdgeInsets.all(10.0),
      // color: const Color(0xFFF4FDFF),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.seatOrders.map((order) {
                int orderIndex = widget.seatOrders.indexOf(order) + 1;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order $orderIndex: TknNo ${order['tokenNo']}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Sts ${order['status']} - ${order['seathiveOrderId']}/${order['hiveOrderId']}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: [
                          // Header Row
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    'ItemName',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    ' Qty',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                // if (order['weights'] != null &&
                                //     (order['weights'] as List<double>)
                                //             .reduce((a, b) => a + b) >
                                //         0.0)
                                //   const Expanded(
                                //     flex: 2,
                                //     child: Text(
                                //       '  Wt',
                                //       style: TextStyle(
                                //           fontWeight: FontWeight.bold),
                                //     ),
                                //   ),
                                // const Expanded(
                                //   flex: 3,
                                //   child: Text(
                                //     '    Price',
                                //     style:
                                //         TextStyle(fontWeight: FontWeight.bold),
                                //   ),
                                // ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Amount',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Action',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          // Data Rows
                          ...List.generate(order['varianceNames'].length, (i) {
                            final String varianceNames =
                                order['varianceNames'][i];
                            final double price = order['prices'][i];
                            final double quantity = order['quantities'][i];
                            final double amounts = order['amounts'][i];
                            final double weight = order['weights'][i] ?? 0.0;
                            final bool isPartiallyCancelled =
                                order['partiallycancelled'] ?? false;

                            final Map<String, dynamic> config =
                                order['config'][i];
                            final int configQtyLength =
                                order['config']?[i]?['configQty']?.length ?? 0;
                            final int addOnLength =
                                order['config']?[i]?['addOn']?.length ?? 0;
                            final int addOnPriceLength =
                                order['config']?[i]?['addOn']?.length ?? 0;
                            final int varianceLength =
                                order['config']?[i]?['variance']?.length ?? 0;
                            final List<dynamic> configQtyList =
                                order['config']?[i]?['configQty'] ?? [];
                            final double totalConfigQty = configQtyList.fold(
                                0.0,
                                (prev, element) =>
                                    prev +
                                    (element is num
                                        ? element.toDouble()
                                        : 0.0));

                            Map<String, dynamic> groupedConfig = {};
                            for (int j = 0; j < config['addOn'].length; j++) {
                              bool hasConfig = (config['addOn'] != null &&
                                      j < config['addOn'].length &&
                                      config['addOn'][j].isNotEmpty) ||
                                  (config['variance'] != null &&
                                      j < config['variance'].length &&
                                      config['variance'][j].isNotEmpty &&
                                      config['variance'][j] !=
                                          'Default'.toLowerCase()) ||
                                  (config['type'] != null &&
                                      j < config['type'].length &&
                                      config['type'][j].isNotEmpty) ||
                                  (config['remark'] != null &&
                                      j < config['remark'].length &&
                                      config['remark'][j].isNotEmpty);

                              if (hasConfig) {
                                final key =
                                    '${j < config['addOn'].length ? config['addOn'][j] : ''}|${j < config['addOnPrice'].length ? config['addOnPrice'][j] : ''}|${j < config['variance'].length ? config['variance'][j] : ''}|${j < config['type'].length ? config['type'][j] : ''}|${j < config['remark'].length ? config['remark'][j] : ''}|${j < config['configQty'].length ? config['configQty'][j] : ''}';

                                groupedConfig[key] =
                                    groupedConfig.containsKey(key)
                                        ? groupedConfig[key] + 1
                                        : 1;
                              }
                            }

                            List<String> selectedAddOns = [];

                            final productProvider =
                                Provider.of<ProductProvider>(context);
                            final addOns = productProvider.addons ??
                                []; // Null safety check
                            // Filter add-ons that contain the current variance name
                            final filteredAddOns = addOns.where((addon) {
                              final items = addon['addOnItems'] ??
                                  []; // Null safety check
                              return items.contains(varianceNames);
                            }).toList();

                            List<String> allAddOns = filteredAddOns
                                .map((e) => e['addOn'].toString())
                                .toList();
                            Map<int, int> reducedQuantities =
                                {}; // Key: item index, Value: sum of reduced quantities

                            return Padding(
                              padding: const EdgeInsets.all(1.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${capitalizeWords(order['varianceNames'][i])}',
                                              style: (order['quantities'][i]) ==
                                                      0
                                                  ? const TextStyle(
                                                      fontSize: 12,
                                                      decoration: TextDecoration
                                                          .lineThrough,
                                                      color: Colors.red,
                                                    )
                                                  : const TextStyle(
                                                      fontSize: 12),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(3.0),
                                              child: RichText(
                                                text: TextSpan(
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black54),
                                                  children: [
                                                    const TextSpan(
                                                      text: '(',
                                                    ),
                                                    TextSpan(
                                                      text:
                                                          ' ₹${price.toInt()}',
                                                    ),
                                                    if (weight >
                                                        0) // Only add weight if it is greater than 0
                                                      TextSpan(
                                                        text:
                                                            ' / ${weight.toStringAsFixed(2)} kg',
                                                      ),
                                                    const TextSpan(
                                                      text: ')',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (order['cancelledQty'] != null &&
                                                order['cancelledQty'][i] > 0)
                                              Text(
                                                'Canceled Qty: ${order['cancelledQty'][i]}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  color: Colors.red,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '   ${quantity.toInt()}',
                                          style: quantity == 0
                                              ? const TextStyle(
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  color: Colors.red,
                                                )
                                              : const TextStyle(
                                                  fontSize:
                                                      12, // Set font size to 10
                                                ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '  ₹${amounts.toInt()}',
                                          style: quantity == 0
                                              ? const TextStyle(
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  color: Colors.red,
                                                )
                                              : const TextStyle(
                                                  fontSize:
                                                      12, // Set font size to 10
                                                ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: IconButton(
                                          icon: Icon(
                                            (order['quantities'][i] ==
                                                    0.0) // Check if the quantity for this item is 0
                                                ? Icons
                                                    .undo // Show undo icon if quantity is 0 (partially cancelled)
                                                : Icons
                                                    .cancel, // Show cancel icon otherwise
                                            color: (order['quantities'][i] ==
                                                    0.0) // Color based on the item quantity
                                                ? Colors.green // Green for undo
                                                : Colors.red, // Red for cancel
                                          ),
                                          onPressed: () async {
                                            if (order['quantities'][i] == 0.0) {
                                              final bool confirm =
                                                  await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                                'Revert Cancelled Item'),
                                                            content: const Text(
                                                              'Are you sure you want to revert the cancelled item?',
                                                            ),
                                                            actions: [
                                                              ElevatedButton(
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      const Color(
                                                                          0xFFA5D6A7),
                                                                ),
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(
                                                                            true),
                                                                child:
                                                                    const Text(
                                                                  'Yes',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .black),
                                                                ),
                                                              ),
                                                              ElevatedButton(
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .redAccent,
                                                                ),
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(
                                                                            false),
                                                                child:
                                                                    const Text(
                                                                  'No',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ) ??
                                                      false;

                                              if (confirm) {
                                                await reverseCancellation(
                                                    i, order);
                                              }
                                            } else
                                            // Create a TextEditingController for the remark.
                                            {
                                              final TextEditingController
                                                  itemremarkController =
                                                  TextEditingController();

                                              // Ask the user for confirmation and remark before canceling the item.
                                              final bool confirm =
                                                  await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                                'Cancel Item'),
                                                            content: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text(
                                                                    'Are you sure you want to cancel this item?'),
                                                                const SizedBox(
                                                                    height: 8),
                                                                RemarkTextField(
                                                                    controller:
                                                                        itemremarkController),
                                                              ],
                                                            ),
                                                            actions: [
                                                              ElevatedButton(
                                                                onPressed: () {
                                                                  // Check if the remark field is empty, if so, do not allow clicking Yes
                                                                  if (itemremarkController
                                                                      .text
                                                                      .isEmpty) {
                                                                    // Optionally show a snackbar or dialog if needed
                                                                    Flushbar(
                                                                      message:
                                                                          'Please enter a remark before confirming',
                                                                      duration: const Duration(
                                                                          seconds:
                                                                              2),
                                                                      backgroundColor: Colors.red[
                                                                              600] ??
                                                                          Colors
                                                                              .red,
                                                                      flushbarPosition:
                                                                          FlushbarPosition
                                                                              .BOTTOM,
                                                                      margin: const EdgeInsets
                                                                          .all(
                                                                          8),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              20),
                                                                    ).show(
                                                                        context);
                                                                    return;
                                                                  }

                                                                  if (itemremarkController
                                                                          .text
                                                                          .length >
                                                                      kMaxRemarkLength) {
                                                                    Flushbar(
                                                                      message:
                                                                          'Remark cannot exceed $kMaxRemarkLength characters',
                                                                      duration: const Duration(
                                                                          seconds:
                                                                              2),
                                                                      backgroundColor: Colors.orange[
                                                                              800] ??
                                                                          Colors
                                                                              .orange,
                                                                      flushbarPosition:
                                                                          FlushbarPosition
                                                                              .BOTTOM,
                                                                      margin: const EdgeInsets
                                                                          .all(
                                                                          8),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              20),
                                                                    ).show(
                                                                        context);
                                                                    return;
                                                                  }
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop(
                                                                          true); // Proceed if remarks are provided
                                                                },
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      const Color(
                                                                          0xFFA5D6A7),
                                                                ),
                                                                child:
                                                                    const Text(
                                                                  'Yes',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                      color: Colors
                                                                          .black),
                                                                ),
                                                              ),
                                                              ElevatedButton(
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .redAccent,
                                                                ),
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(
                                                                            false),
                                                                child:
                                                                    const Text(
                                                                  'No',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ) ??
                                                      false;
                                              if (!confirm) return;

                                              // Suppose the current index of the item is given by 'i'
                                              int itemIndex =
                                                  i; // Ensure that this 'i' corresponds to the current item index

                                              // Convert lists to List<double> if needed.
                                              order['quantities'] =
                                                  (order['quantities'] as List)
                                                      .map((e) =>
                                                          (e as num).toDouble())
                                                      .toList();
                                              if (order['amounts'] != null) {
                                                order['amounts'] =
                                                    (order['amounts'] as List)
                                                        .map((e) => (e as num)
                                                            .toDouble())
                                                        .toList();
                                              }
                                              if (order['cancelledQty'] !=
                                                  null) {
                                                order['cancelledQty'] =
                                                    (order['cancelledQty']
                                                            as List)
                                                        .map((e) => (e as num)
                                                            .toDouble())
                                                        .toList();
                                              } else {
                                                order['cancelledQty'] =
                                                    List.filled(
                                                        order['quantities']
                                                            .length,
                                                        0.0);
                                              }
                                              order['totalAmount'] =
                                                  ((order['totalAmount'] ?? 0)
                                                          as num)
                                                      .toDouble();

                                              // Retrieve the current quantity for the item as double.
                                              final double currentQuantity =
                                                  (order['quantities']
                                                          [itemIndex] as num)
                                                      .toDouble();

                                              // Set cancelled quantity at this index to the current quantity.
                                              order['cancelledQty'][itemIndex] =
                                                  currentQuantity;

                                              // Cancel the item by setting its quantity to 0.0.
                                              order['quantities'][itemIndex] =
                                                  0.0;

                                              // Update the total amount by subtracting this item's amount.
                                              final double itemAmount =
                                                  (order['amounts'][itemIndex]
                                                          as num)
                                                      .toDouble();
                                              order['totalAmount'] =
                                                  order['totalAmount'] -
                                                      itemAmount;

                                              // Mark the order as partially cancelled.
                                              order['partiallycancelled'] =
                                                  true;
                                              final String itemName =
                                                  order['varianceNames'][i]
                                                          ?.toString()
                                                          .trim()
                                                          .toLowerCase() ??
                                                      '';

// 2. Use a cache to store/reuse the IP for this item
                                              String? printerIp =
                                                  order['printerIpMap']
                                                      ?[itemName];

// 3. If not cached, get from provider and store
                                              if (printerIp == null) {
                                                // ignore: use_build_context_synchronously
                                                printerIp = Provider.of<
                                                            PrinterProvider>(
                                                        context,
                                                        listen: false)
                                                    .getPrinterIpForItem(
                                                        itemName);
                                                if (printerIp != null) {
                                                  order['printerIpMap'] =
                                                      (order['printerIpMap'] ??
                                                          {})
                                                        ..[itemName] =
                                                            printerIp;
                                                } else {
                                                  return; // or use fallback logic
                                                }
                                              }
                                              // Prepare the update packet to send to the server. Notice the new 'itemRemark' field.
                                              final Map<String, dynamic>
                                                  dataToSend = {
                                                'action': 'cancelOrderItem',
                                                'hiveOrderId':
                                                    order['hiveOrderId'],
                                                'cancelledQty':
                                                    order['cancelledQty'],
                                                'totalAmount':
                                                    order['totalAmount'],
                                                'quantities':
                                                    order['quantities'],
                                                'itemRemark': itemremarkController
                                                    .text, // Include the remark.
                                                'partiallycancelled': true,
                                              };

                                              // First, send the updated details to the server.
                                              await sendMessage(dataToSend);

                                              // Build trimmed order with only the cancelled item index
                                              final filteredOrder = {
                                                ...order,
                                                'quantities': [
                                                  order['quantities'][itemIndex]
                                                ],
                                                'cancelledQty': [
                                                  order['cancelledQty']
                                                      [itemIndex]
                                                ],
                                                'amounts': [
                                                  order['amounts'][itemIndex]
                                                ],
                                                'prices': [
                                                  order['prices'][itemIndex]
                                                ],
                                                'weights': [
                                                  order['weights'][itemIndex]
                                                ],
                                                'varianceNames': [
                                                  order['varianceNames']
                                                      [itemIndex]
                                                ],
                                                'config': [
                                                  order['config'][itemIndex]
                                                ],
                                              };

// Only include the cancelled item in receipt
                                              await CancelPrinterService
                                                  .printUniversalReceipt(
                                                ipAddress: printerIp,
                                                tableNumber:
                                                    order['table'] ?? '',
                                                seat: order['seat'] ?? '',
                                                userName:
                                                    order['userName'] ?? '',
                                                waiter: order['waiter'] ?? '',
                                                seatOrders: [
                                                  filteredOrder
                                                ], // ✅ Only cancelled item
                                                receiptType: 'ITEM CANCELLED',
                                              );
                                            }
                                          },
                                        ),
                                      )
                                    ],
                                  ),
                                  Column(
                                    children:
                                        groupedConfig.entries.map((entry) {
                                      final parts = entry.key.split('|');
                                      final isStriked = parts[5] ==
                                          '0'; // Check if quantity is 0

                                      return Column(
                                        children: [
                                          Row(
                                            // mainAxisAlignment:
                                            //     MainAxisAlignment.spaceBetween,
                                            children: [
                                              SizedBox(
                                                width: 60,
                                                child: Column(
                                                  children: [
                                                    Text(
                                                        capitalizeWords(
                                                            varianceNames),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                          decoration: isStriked
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : null,
                                                        )),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width: 20,
                                                child: Column(
                                                  children: [
                                                    if (parts[5].isNotEmpty)
                                                      Text(
                                                          totalConfigQty
                                                              .toStringAsFixed(
                                                                  0),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                            decoration: isStriked
                                                                ? TextDecoration
                                                                    .lineThrough
                                                                : null,
                                                          )),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(
                                                width: 20,
                                              ),
                                              SizedBox(
                                                width: 150,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (parts[0].isNotEmpty &&
                                                        parts[0] != '[]') ...[
                                                      const Text(
                                                        'Add-on:',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
                                                      ),
                                                      // Display each add-on vertically
                                                      ...parts[0]
                                                          .replaceAll('[', '')
                                                          .replaceAll(']', '')
                                                          .toLowerCase()
                                                          .split(',')
                                                          .map((addon) => Text(
                                                                addon
                                                                    .trim(), // Display each addon on a new line
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey,
                                                                  decoration: isStriked
                                                                      ? TextDecoration
                                                                          .lineThrough
                                                                      : null,
                                                                ),
                                                              ))
                                                          .toList(),
                                                    ],
                                                    if (parts[2].isNotEmpty &&
                                                        parts[2] != 'Default')
                                                      Text(
                                                          'Variants: ${parts[2]}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                            decoration: isStriked
                                                                ? TextDecoration
                                                                    .lineThrough
                                                                : null,
                                                          )),
                                                    if (parts[3].isNotEmpty)
                                                      Text('Type: ${parts[3]}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                            decoration: isStriked
                                                                ? TextDecoration
                                                                    .lineThrough
                                                                : null,
                                                          )),
                                                    if (parts[4].isNotEmpty)
                                                      Text(
                                                          'Remarks: ${parts[4]}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                            decoration: isStriked
                                                                ? TextDecoration
                                                                    .lineThrough
                                                                : null,
                                                          )),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width: 50,
                                                child: Column(
                                                  children: [
                                                    if (parts[1].isNotEmpty &&
                                                        parts[1] != '[]') ...[
                                                      const Text(
                                                        'Price:',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey),
                                                      ),
                                                      // Display each add-on vertically
                                                      ...parts[1]
                                                          .replaceAll('[', '')
                                                          .replaceAll(']', '')
                                                          .toLowerCase()
                                                          .split(',')
                                                          .map((addonPrice) =>
                                                              Text(
                                                                addonPrice
                                                                    .trim(), // Display each addon on a new line
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey,
                                                                  decoration: isStriked
                                                                      ? TextDecoration
                                                                          .lineThrough
                                                                      : null,
                                                                ),
                                                              ))
                                                          .toList(),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(), // Add a horizontal line after each Row
                                        ],
                                      );
                                    }).toList(),
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
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                  ),
                  child: const Text(
                    "Cancel Order",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final TextEditingController remarkController =
                        TextEditingController();
                    final bool confirm = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Cancel All Items?'),
                              content:
                                  RemarkTextField(controller: remarkController),
                              actions: [
                                ElevatedButton(
                                  onPressed: () {
                                    // Check if the remark field is empty, if so, do not allow clicking Yes
                                    if (remarkController.text.isEmpty) {
                                      // Optionally show a snackbar or dialog if needed
                                      Flushbar(
                                        message:
                                            'Please enter a remark before confirming',
                                        duration: const Duration(seconds: 2),
                                        backgroundColor:
                                            Colors.red[600] ?? Colors.red,
                                        flushbarPosition:
                                            FlushbarPosition.BOTTOM,
                                        margin: const EdgeInsets.all(8),
                                        borderRadius: BorderRadius.circular(20),
                                      ).show(context);
                                      return;
                                    }
                                    // if (remarkController.text.length <
                                    //     kMinRemarkLength) {
                                    //   Flushbar(
                                    //     message:
                                    //         'Remark must be at least $kMinRemarkLength characters long',
                                    //     duration: const Duration(seconds: 2),
                                    //     backgroundColor:
                                    //         Colors.orange[800] ?? Colors.orange,
                                    //     flushbarPosition:
                                    //         FlushbarPosition.BOTTOM,
                                    //     margin: const EdgeInsets.all(8),
                                    //     borderRadius: BorderRadius.circular(20),
                                    //   ).show(context);
                                    //   return;
                                    // }

                                    if (remarkController.text.length >
                                        kMaxRemarkLength) {
                                      Flushbar(
                                        message:
                                            'Remark cannot exceed $kMaxRemarkLength characters',
                                        duration: const Duration(seconds: 2),
                                        backgroundColor:
                                            Colors.orange[800] ?? Colors.orange,
                                        flushbarPosition:
                                            FlushbarPosition.BOTTOM,
                                        margin: const EdgeInsets.all(8),
                                        borderRadius: BorderRadius.circular(20),
                                      ).show(context);
                                      return;
                                    }
                                    Navigator.of(context).pop(
                                        true); // Proceed if remarks are provided
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFA5D6A7),
                                  ),
                                  child: const Text(
                                    'Yes',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color.fromARGB(255, 239, 72, 72),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            );
                          },
                        ) ??
                        false;

                    if (confirm) {
                      final orderProvider =
                          Provider.of<OrderProvider>(context, listen: false);
                      // Loop through orders for this seat (or however your logic identifies orders)
                      for (var order in widget.seatOrders) {
                        final String seathiveOrderId = order['seathiveOrderId'];
                        await OrderPatchService.patchOrderCancellation(
                          seathiveOrderId: seathiveOrderId,
                          remark: remarkController.text,
                          channel: orderProvider.channel!,
                          inMemoryOrders: orderProvider.orders, // optional
                        );
                        var printerIp = printerProvider.getPrinterIpForItem(
                            widget.seatOrders.first['varianceNames'].first
                                .toString());

                        if (printerIp == null) {
                          await promptForPrinterIp(context);
                          printerIp = printerProvider.getPrinterIpForItem(widget
                              .seatOrders.first['varianceNames'].first
                              .toString());
                          if (printerIp == null) {
                            return;
                          }
                        }

                        await CancelPrinterService.printUniversalReceipt(
                          ipAddress: printerIp.toString(),
                          tableNumber: widget.seatOrders.first['table'],
                          seat: widget.seatOrders.first['seat'],
                          userName: widget.seatOrders.first['captain'] ?? "",
                          waiter: widget.seatOrders.first['waiter'] ?? "",
                          seatOrders: widget.seatOrders,
                          receiptType: "Full Order Cancelled",
                        );
                      }
                    }
                  },
                ),
                ElevatedButton(
                  onPressed: () async {
                    var printerIp =
                        Provider.of<PrinterProvider>(context, listen: false)
                            .getPreInvoicePrinterIp();

                    if (printerIp == null) {
                      await promptForPrinterIp(context);
                      // Re-check after potentially setting the IP
                      printerIp =
                          Provider.of<PrinterProvider>(context, listen: false)
                              .getPreInvoicePrinterIp();
                      if (printerIp == null) {
                        return; // Exit if still not set to avoid proceeding without a printer IP
                      }
                    }

                    // ignore: use_build_context_synchronously
                    bool confirm = await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(15.0)),
                          ),
                          title: const Text(
                            'Confirmation ',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            'Are you sure? you want to generate the Pre invoice for\n ${widget.tableNumber} - ${widget.seat}?',
                            style: const TextStyle(
                                fontSize: 15, color: Colors.black87),
                          ),
                          actions: <Widget>[
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromARGB(255, 239, 72, 72),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA5D6A7),
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirm == true) {

                      await patchStatusConfirm(widget.tableNumber, widget.seat,
                          widget.seatOrders, orderProvider);

                      final preInvoicePrinter =
                          printerProvider.printers.firstWhere(
                        (printer) => printer.type == 'PreInvoice',
                        orElse: () {
                          return Printer(
                            name: 'default_printer_name',
                            ipAddress: 'default_ip',
                            type: 'default_type',
                          );
                        },
                      );

                      await PreInvoicePrinter.printReceipt(
                        ipAddress: preInvoicePrinter.ipAddress,
                        tableNumber: widget.tableNumber,
                        seat: widget.seat,
                        seatOrders: widget.seatOrders,
                        userName: widget.loggedInUserName,
                        waiter: widget.waiter,
                        receiptType: 'PreInvoice',
                      );


                      // ignore: use_build_context_synchronously
                      Provider.of<BottomNavProvider>(context, listen: false)
                          .updateIndex(0);
                      // ignore: invalid_use_of_protected_member
                      orderProvider.notifyListeners(); // ensure UI update

                      // ignore: use_build_context_synchronously
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const OrderSummaryScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA5D6A7),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                  ),
                  child: const Text(
                    'Generate preInvoice',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: file_names
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/kotpreinvoice/services/invoice_number_service.dart';

import '../../providers/submissionProvider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../Helper/RemarkTextfield.dart';
import '../../Helper/addStock_utils.dart';
import '../../Helper/decreaseStock_utils.dart';
import '../../components/flushbar.dart';
import '../../screens/order_summary_screen.dart';
import '../../services/CancelOrder_Patch.dart';
import '../../services/CancellationReceipt.dart';
import '../../services/preInv Utility.dart';
import '../../services/preInvociePrint_services.dart';
import 'package:yenpos/Global/globals_data.dart';
import '../../models/printer.dart';
import '../../../kotpreinvoice/providers/bottomNavprovider.dart';
import '../../providers/order_provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/product_provider.dart';
import '../../components/capitalizeWord.dart';

class OrderSummaryCard extends StatefulWidget {
  final String tableNumber;
  final String seat;
  final List<Map<String, dynamic>> seatOrders;
  final double seatTotal;
  final String waiter;
  final String loggedInUserName;
  final String areaName;
  final String seathiveOrderId;

  const OrderSummaryCard({
    Key? key,
    required this.tableNumber,
    required this.seat,
    required this.seatOrders,
    required this.seatTotal,
    required this.waiter,
    required this.loggedInUserName,
    required this.areaName,
    required this.seathiveOrderId,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _OrderSummaryCardState createState() => _OrderSummaryCardState();
}

class _OrderSummaryCardState extends State<OrderSummaryCard> {
  WebSocketChannel? channel;
  Map<int, String?> selectedVariants = {};
  late final OrderProvider orderProvider;
  late ValueNotifier<List<Map<String, dynamic>>> seatOrdersNotifier;

  @override
  void initState() {
    super.initState();
    seatOrdersNotifier = ValueNotifier<List<Map<String, dynamic>>>(List.from(widget.seatOrders));

    // Initialize the WebSocket channel
    channel = WebSocketChannel.connect(
      Uri.parse('ws://$serverip:$port'),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    orderProvider = context.read<OrderProvider>();
  }

  @override
  void dispose() {
    // now safe to close if you really must:
    channel?.sink.close();
    super.dispose();
  }

  Future<void> reverseCancellation(int index, Map<String, dynamic> order) async {
    try {
      print("🔄 Starting reverse cancellation for index: $index, OrderID: ${order['hiveOrderId']}");

      // ✅ Validate index range
      if (index < 0 || index >= (order['quantities'] as List).length) {
        print("❌ Invalid index: $index. Cannot reverse cancellation.");
        return;
      }

      // Ensure lists are double
      List<double> quantities = (order['quantities'] as List).map((e) => (e as num).toDouble()).toList();
      List<double> cancelledQty = (order['cancelledQty'] as List).map((e) => (e as num).toDouble()).toList();
      List<double> prices = (order['prices'] as List).map((e) => (e as num).toDouble()).toList();

      // ✅ Prevent restoring if already 0
      if (cancelledQty[index] == 0.0) {
        print("⚠️ Item at index $index is not cancelled. Nothing to restore.");
        return;
      }

      // Swap back for the single index
      double restoredQty = cancelledQty[index];
      cancelledQty[index] = 0.0;
      quantities[index] = restoredQty;

      print("✅ Restored quantity: $restoredQty for item at index: $index");

      // Recalculate total amount
      double totalAmount = 0.0;
      for (int i = 0; i < quantities.length; i++) {
        totalAmount += quantities[i] * prices[i];
      }

      // Update order object
      order['quantities'] = quantities;
      order['cancelledQty'] = cancelledQty;
      order['totalAmount'] = totalAmount;
      order['partiallycancelled'] = cancelledQty.any((q) => q > 0.0);

      print("📝 Updated order total: $totalAmount, Partial cancel: ${order['partiallycancelled']}");

      // Update in local storage / provider
      orderProvider.updateOrderByHiveOrderId(order['hiveOrderId'], order);
      updateOrderInNotifier(order);

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
      print("📤 Sent reverse cancellation update for index: $index");
    } catch (e, stack) {
      print("💥 Error in reverseCancellation: $e");
      print("📌 Stacktrace: $stack");
    }
  }

  Future<void> sendMessage(Map<String, dynamic> configDetails) async {
    try {
      if (channel == null) {
        print("⚠️ WebSocket channel is not initialized. Message not sent.");
        return;
      }

      final jsonData = jsonEncode(configDetails);
      channel?.sink.add(jsonData);
      print("📤 Message sent: $jsonData");
    } catch (error, stack) {
      print("💥 Error sending message: $error");
      print("📌 Stacktrace: $stack");
    }
  }

  void updateOrderInNotifier(Map<String, dynamic> updatedOrder) {
    try {
      print("🔄 Updating order in notifier: ${updatedOrder['hiveOrderId']}");

      int index = seatOrdersNotifier.value.indexWhere(
        (element) => element['hiveOrderId'] == updatedOrder['hiveOrderId'],
      );

      if (index != -1) {
        seatOrdersNotifier.value[index] = {...updatedOrder}; // Fresh reference
        seatOrdersNotifier.value = List<Map<String, dynamic>>.from(seatOrdersNotifier.value);

        print("✅ Order updated successfully at index $index");
      } else {
        print("⚠️ Order with hiveOrderId ${updatedOrder['hiveOrderId']} not found in notifier.");
      }
    } catch (e, stack) {
      print("💥 Error in updateOrderInNotifier: $e");
      print("📌 Stacktrace: $stack");
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final printerProvider = Provider.of<PrinterProviderDine>(context, listen: false);
    final submissionProvider = Provider.of<SubmissionProviderDine>(context, listen: false);

    Future<void> patchStatusConfirm(
      String tableNumber,
      String seat,
      List<Map<String, dynamic>> seatOrders,
      OrderProvider orderProvider,
    ) async {
      try {
        print("🔄 patchStatusConfirm started for table $tableNumber, seat $seat");
        print("📝 Total seatOrders: ${seatOrders.length}");

        final uniqueSeatHiveOrderIds = <String>{};

        for (var order in seatOrders) {
          try {
            final seathiveOrderId = order['seathiveOrderId'];
            if (seathiveOrderId != null && seathiveOrderId.toString().isNotEmpty) {
              uniqueSeatHiveOrderIds.add(seathiveOrderId.toString());
            }

            // ✅ Handle add-ons inside config
            if (order['config'] != null && order['config'] is Map) {
              final config = order['config'] as Map<String, dynamic>;

              // 🔹 Case 1: config['addOn'] contains nested lists
              if (config['addOn'] != null && config['addOn'] is List) {
                for (int i = 0; i < config['addOn'].length; i++) {
                  final addOnList = config['addOn'][i];
                  if (addOnList is List) {
                    for (var addOn in addOnList) {
                      if (addOn is Map && addOn['seathiveOrderId'] != null && addOn['seathiveOrderId'].toString().isNotEmpty) {
                        uniqueSeatHiveOrderIds.add(addOn['seathiveOrderId'].toString());
                      }
                    }
                  }
                }
              }

              // 🔹 Case 2: config['addOnConfig'] contains list of maps
              if (config['addOnConfig'] != null && config['addOnConfig'] is List) {
                for (var addOnItem in config['addOnConfig']) {
                  if (addOnItem is Map && addOnItem['seathiveOrderId'] != null && addOnItem['seathiveOrderId'].toString().isNotEmpty) {
                    uniqueSeatHiveOrderIds.add(addOnItem['seathiveOrderId'].toString());
                  }
                }
              }
            }
          } catch (orderError, stack) {
            print("⚠️ Error processing order: $orderError");
            print("📌 Stacktrace: $stack");
          }
        }

        print("✅ Unique seathiveOrderIds collected: $uniqueSeatHiveOrderIds");

        // 🔄 Patch each order status
        for (final seathiveOrderId in uniqueSeatHiveOrderIds) {
          try {
            print("📤 Patching status=confirm for seathiveOrderId: $seathiveOrderId");
            await orderProvider.patchOrderStatusBySeathiveOrderId(seathiveOrderId, "confirm" , tableNumber , seat);
            print("✅ Status patched successfully for: $seathiveOrderId");
          } catch (patchError, stack) {
            print("❌ Failed to patch status for $seathiveOrderId: $patchError");
            print("📌 Stacktrace: $stack");
          }
        }

        orderProvider.notifyListeners();
        print("🔔 Listeners notified.");
      } catch (e, stack) {
        print("💥 Fatal error in patchStatusConfirm: $e");
        print("📌 Stacktrace: $stack");
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
              children: [
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: seatOrdersNotifier,
                  builder: (context, seatOrders, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: seatOrders.asMap().entries.map((entry) {
                        final int orderIndex = entry.key + 1;
                        final Map<String, dynamic> order = entry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order $orderIndex: TknNo ${order['tokenNo']} ',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            // Text(
                            //   '${order['seathiveOrderId']}-${order['hiveOrderId']}',
                            //   style: const TextStyle(
                            //       fontSize: 15, fontWeight: FontWeight.bold),
                            // ),
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
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            ' Qty',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Amount',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Action',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(),
                                  // Data Rows
                                  ...List.generate(order['varianceNames'].length, (i) {
                                    final String varianceNames = order['varianceNames'][i];
                                    final double price = order['prices'][i];
                                    final double quantity = order['quantities'][i];
                                    final double amounts = order['amounts'][i];
                                    final double weight = order['weights'][i] ?? 0.0;

                                    final Map<String, dynamic> config = order['config'][i];
                                    //
                                    final List<dynamic> configQtyList = order['config']?[i]?['configQty'] ?? [];
                                    final double totalConfigQty = configQtyList.fold(0.0, (prev, element) => prev + (element is num ? element.toDouble() : 0.0));

                                    Map<String, dynamic> groupedConfig = {};
                                    for (int j = 0; j < config['addOn'].length; j++) {
                                      bool hasConfig = (config['addOn'] != null && j < config['addOn'].length && config['addOn'][j].isNotEmpty) ||
                                          (config['variance'] != null && j < config['variance'].length && config['variance'][j].isNotEmpty && config['variance'][j] != 'Default'.toLowerCase()) ||
                                          (config['type'] != null && j < config['type'].length && config['type'][j].isNotEmpty) ||
                                          (config['remark'] != null && j < config['remark'].length && config['remark'][j].isNotEmpty);

                                      if (hasConfig) {
                                        final key =
                                            '${j < config['addOn'].length ? config['addOn'][j] : ''}|${j < config['addOnPrice'].length ? config['addOnPrice'][j] : ''}|${j < config['variance'].length ? config['variance'][j] : ''}|${j < config['type'].length ? config['type'][j] : ''}|${j < config['remark'].length ? config['remark'][j] : ''}|${j < config['configQty'].length ? config['configQty'][j] : ''}';

                                        groupedConfig[key] = groupedConfig.containsKey(key) ? groupedConfig[key] + 1 : 1;
                                      }
                                    }

                                    List<String> selectedAddOns = [];

                                    final productProvider = Provider.of<ProductProvider>(context);
                                    final addOns = productProvider.addons ?? []; // Null safety check
                                    // Filter add-ons that contain the current variance name
                                    final filteredAddOns = addOns.where((addon) {
                                      final items = addon['addOnItems'] ?? []; // Null safety check
                                      return items.contains(varianceNames);
                                    }).toList();

                                    List<String> allAddOns = filteredAddOns.map((e) => e['addOn'].toString()).toList();
                                    Map<int, int> reducedQuantities = {}; // Key: item index, Value: sum of reduced quantities

                                    return Padding(
                                      padding: const EdgeInsets.all(1.0),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                flex: 5,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      capitalizeWords(order['varianceNames'][i]),
                                                      style: (order['quantities'][i]) == 0
                                                          ? const TextStyle(
                                                              fontSize: 12,
                                                              decoration: TextDecoration.lineThrough,
                                                              color: Colors.red,
                                                            )
                                                          : const TextStyle(fontSize: 12),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.all(3.0),
                                                      child: RichText(
                                                        text: TextSpan(
                                                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                          children: [
                                                            const TextSpan(
                                                              text: '(',
                                                            ),
                                                            TextSpan(
                                                              text: ' ₹${price.toInt()}',
                                                            ),
                                                            if (weight > 0) // Only add weight if it is greater than 0
                                                              TextSpan(
                                                                text: ' / ${weight.toStringAsFixed(2)} kg',
                                                              ),
                                                            const TextSpan(
                                                              text: ')',
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if (order['cancelledQty'] != null && order['cancelledQty'][i] > 0)
                                                      Text(
                                                        'Canceled Qty: ${order['cancelledQty'][i]}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          decoration: TextDecoration.lineThrough,
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
                                                          decoration: TextDecoration.lineThrough,
                                                          color: Colors.red,
                                                        )
                                                      : const TextStyle(
                                                          fontSize: 12, // Set font size to 10
                                                        ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  '  ₹${amounts.toInt()}',
                                                  style: quantity == 0
                                                      ? const TextStyle(
                                                          decoration: TextDecoration.lineThrough,
                                                          color: Colors.red,
                                                        )
                                                      : const TextStyle(
                                                          fontSize: 12, // Set font size to 10
                                                        ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: IconButton(
                                                  icon: Icon(
                                                    (order['quantities'][i] == 0.0) // Check if the quantity for this item is 0
                                                        ? Icons.undo // Show undo icon if quantity is 0 (partially cancelled)
                                                        : Icons.cancel, // Show cancel icon otherwise
                                                    color: (order['quantities'][i] == 0.0) // Color based on the item quantity
                                                        ? Colors.green // Green for undo
                                                        : Colors.red, // Red for cancel
                                                  ),
                                                  onPressed: () async {
                                                    if (order['quantities'][i] == 0.0) {
                                                      final bool confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (context) {
                                                              return AlertDialog(
                                                                backgroundColor: Colors.white,
                                                                title: const Text('Revert Cancelled Item'),
                                                                content: const Text(
                                                                  'Are you sure you want to revert the cancelled item?',
                                                                ),
                                                                actions: [
                                                                  ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: const Color(0xFFA5D6A7),
                                                                    ),
                                                                    onPressed: () => Navigator.of(context).pop(true),
                                                                    child: const Text(
                                                                      'Yes',
                                                                      style: TextStyle(color: Colors.black),
                                                                    ),
                                                                  ),
                                                                  ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: Colors.redAccent,
                                                                    ),
                                                                    onPressed: () => Navigator.of(context).pop(false),
                                                                    child: const Text(
                                                                      'No',
                                                                      style: TextStyle(color: Colors.white),
                                                                    ),
                                                                  ),
                                                                ],
                                                              );
                                                            },
                                                          ) ??
                                                          false;

                                                      if (confirm) {
                                                        await reverseCancellation(i, order);
                                                        updateOrderInNotifier(order);

                                                        final double restoredQty = (order['quantities'][i] as num).toDouble();

                                                        sendDecreaseStockUpdateGlobally(
                                                          context: context,
                                                          channel: channel!,
                                                          varianceNames: [order['varianceNames'][i]],
                                                          varianceItemCodes: [order['varianceItemCodes'][i]],
                                                          quantities: [restoredQty.toInt()],
                                                        );
                                                        // Build trimmed order with only the cancelled item index
                                                        final filteredOrder = {
                                                          ...order,
                                                          'quantities': [order['quantities'][i]],
                                                          'cancelledQty': [order['cancelledQty'][i]],
                                                          'amounts': [order['amounts'][i]],
                                                          'prices': [order['prices'][i]],
                                                          'weights': [order['weights'][i]],
                                                          'varianceNames': [order['varianceNames'][i]],
                                                          'varianceItemCodes': [order['varianceItemCodes'][i]],
                                                          'config': [order['config'][i]],
                                                        };
                                                        final String itemName = order['varianceNames'][i]?.toString().trim().toLowerCase() ?? '';
                                                        String printerIp = order['printerIpMap']?[itemName];
                                                        // Only include the cancelled item in receipt
                                                        await CancelPrinterService.printUniversalReceipt(
                                                          ipAddress: printerIp,
                                                          tableNumber: order['table'] ?? '',
                                                          seat: order['seat'] ?? '',
                                                          userName: order['userName'] ?? '',
                                                          waiter: order['waiter'] ?? '',
                                                          seatOrders: [filteredOrder], // ✅ Only cancelled item
                                                          receiptType: 'ITEM REVERTED',
                                                        );
                                                      }
                                                    } else
                                                    // Create a TextEditingController for the remark.
                                                    {
                                                      final TextEditingController itemremarkController = TextEditingController();

                                                      // Ask the user for confirmation and remark before canceling the item.
                                                      final bool confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (context) {
                                                              return AlertDialog(
                                                                backgroundColor: Colors.white,
                                                                title: const Text('Cancel Item'),
                                                                content: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const Text('Are you sure you want to cancel this item?'),
                                                                    const SizedBox(height: 8),
                                                                    RemarkTextField(controller: itemremarkController),
                                                                  ],
                                                                ),
                                                                actions: [
                                                                  ElevatedButton(
                                                                    onPressed: () {
                                                                      // Check if the remark field is empty, if so, do not allow clicking Yes
                                                                      if (itemremarkController.text.isEmpty) {
                                                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                                                          showCustomFlushbar(
                                                                            context,
                                                                            'Please enter a remark before confirming',
                                                                            type: FlushbarType.warning,
                                                                          );
                                                                        });
                                                                        return;
                                                                      }

                                                                      if (itemremarkController.text.length > kMaxRemarkLength) {
                                                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                                                          showCustomFlushbar(
                                                                            context,
                                                                            'Remark cannot exceed $kMaxRemarkLength characters',
                                                                            type: FlushbarType.warning,
                                                                          );
                                                                        });
                                                                        return;
                                                                      }

                                                                      Navigator.of(context).pop(true); // Proceed if remarks are provided
                                                                    },
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: const Color(0xFFA5D6A7),
                                                                      elevation: 2,
                                                                      shape: RoundedRectangleBorder(
                                                                        borderRadius: BorderRadius.circular(12),
                                                                      ),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                                    ),
                                                                    child: const Text(
                                                                      'Yes',
                                                                      style: TextStyle(fontSize: 16, color: Colors.black),
                                                                    ),
                                                                  ),
                                                                  ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: Colors.redAccent,
                                                                      elevation: 2,
                                                                      shape: RoundedRectangleBorder(
                                                                        borderRadius: BorderRadius.circular(12),
                                                                      ),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                                    ),
                                                                    onPressed: () => Navigator.of(context).pop(false),
                                                                    child: const Text(
                                                                      'No',
                                                                      style: TextStyle(fontSize: 16, color: Colors.white),
                                                                    ),
                                                                  ),
                                                                ],
                                                              );
                                                            },
                                                          ) ??
                                                          false;
                                                      if (!confirm) return;

                                                      // Suppose the current index of the item is given by 'i'
                                                      int itemIndex = i; // Ensure that this 'i' corresponds to the current item index

                                                      // Convert lists to List<double> if needed.
                                                      order['quantities'] = (order['quantities'] as List).map((e) => (e as num).toDouble()).toList();
                                                      if (order['amounts'] != null) {
                                                        order['amounts'] = (order['amounts'] as List).map((e) => (e as num).toDouble()).toList();
                                                      }
                                                      if (order['cancelledQty'] != null) {
                                                        order['cancelledQty'] = (order['cancelledQty'] as List).map((e) => (e as num).toDouble()).toList();
                                                      } else {
                                                        order['cancelledQty'] = List.filled(order['quantities'].length, 0.0);
                                                      }
                                                      order['totalAmount'] = ((order['totalAmount'] ?? 0) as num).toDouble();

                                                      // Retrieve the current quantity for the item as double.
                                                      final double currentQuantity = (order['quantities'][itemIndex] as num).toDouble();

                                                      // Set cancelled quantity at this index to the current quantity.
                                                      order['cancelledQty'][itemIndex] = currentQuantity;

                                                      // Cancel the item by setting its quantity to 0.0.
                                                      order['quantities'][itemIndex] = 0.0;

                                                      // Update the total amount by subtracting this item's amount.
                                                      final double itemAmount = (order['amounts'][itemIndex] as num).toDouble();
                                                      order['totalAmount'] = order['totalAmount'] - itemAmount;

                                                      // Mark the order as partially cancelled.
                                                      order['partiallycancelled'] = true;
                                                      final String itemName = order['varianceNames'][i]?.toString().trim().toLowerCase() ?? '';

                                                      // 2. Use a cache to store/reuse the IP for this item
                                                      String? printerIp = order['printerIpMap']?[itemName];

                                                      // 3. If not cached, get from provider and store
                                                      if (printerIp == null) {
                                                        // ignore: use_build_context_synchronously
                                                        printerIp = Provider.of<PrinterProviderDine>(context, listen: false).getPrinterIpForItem(itemName);
                                                        if (printerIp != null) {
                                                          order['printerIpMap'] = (order['printerIpMap'] ?? {})..[itemName] = printerIp;
                                                        } else {
                                                          return; // or use fallback logic
                                                        }
                                                      }
                                                      // Prepare the update packet to send to the server. Notice the new 'itemRemark' field.
                                                      final Map<String, dynamic> dataToSend = {
                                                        'action': 'cancelOrderItem',
                                                        'hiveOrderId': order['hiveOrderId'],
                                                        'cancelledQty': order['cancelledQty'],
                                                        'totalAmount': order['totalAmount'],
                                                        'quantities': order['quantities'],
                                                        'itemRemark': itemremarkController.text, // Include the remark.
                                                        'partiallycancelled': true,
                                                      };

                                                      // First, send the updated details to the server.
                                                      await sendMessage(dataToSend);

                                                      sendAddStockUpdateGlobally(
                                                        context: context,
                                                        channel: channel!,
                                                        varianceNames: [order['varianceNames'][itemIndex]],
                                                        varianceItemCodes: [order['varianceItemCodes'][itemIndex]],
                                                        quantities: [currentQuantity.toInt()],
                                                      );

                                                      // Build trimmed order with only the cancelled item index
                                                      final filteredOrder = {
                                                        ...order,
                                                        'quantities': [order['quantities'][itemIndex]],
                                                        'cancelledQty': [order['cancelledQty'][itemIndex]],
                                                        'amounts': [order['amounts'][itemIndex]],
                                                        'prices': [order['prices'][itemIndex]],
                                                        'weights': [order['weights'][itemIndex]],
                                                        'varianceNames': [order['varianceNames'][itemIndex]],
                                                        'config': [order['config'][itemIndex]],
                                                      };

// Only include the cancelled item in receipt
                                                      await CancelPrinterService.printUniversalReceipt(
                                                        ipAddress: printerIp,
                                                        tableNumber: order['table'] ?? '',
                                                        seat: order['seat'] ?? '',
                                                        userName: order['userName'] ?? '',
                                                        waiter: order['waiter'] ?? '',
                                                        seatOrders: [filteredOrder], // ✅ Only cancelled item
                                                        receiptType: 'ITEM CANCELLED',
                                                      );
                                                    }
                                                  },
                                                ),
                                              )
                                            ],
                                          ),
                                          Column(
                                            children: groupedConfig.entries.map((entry) {
                                              final parts = entry.key.split('|');
                                              final isStriked = parts[5] == '0'; // Check if quantity is 0

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
                                                            Text(capitalizeWords(varianceNames),
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.grey,
                                                                  decoration: isStriked ? TextDecoration.lineThrough : null,
                                                                )),
                                                          ],
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 20,
                                                        child: Column(
                                                          children: [
                                                            if (parts[5].isNotEmpty)
                                                              Text(totalConfigQty.toStringAsFixed(0),
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: Colors.grey,
                                                                    decoration: isStriked ? TextDecoration.lineThrough : null,
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
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            if (parts[0].isNotEmpty && parts[0] != '[]') ...[
                                                              const Text(
                                                                'Add-on:',
                                                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                                              ),
                                                              // Display each add-on vertically
                                                              ...parts[0]
                                                                  .replaceAll('[', '')
                                                                  .replaceAll(']', '')
                                                                  .toLowerCase()
                                                                  .split(',')
                                                                  .map((addon) => Text(
                                                                        addon.trim(), // Display each addon on a new line
                                                                        style: TextStyle(
                                                                          fontSize: 12,
                                                                          color: Colors.grey,
                                                                          decoration: isStriked ? TextDecoration.lineThrough : null,
                                                                        ),
                                                                      ))
                                                                  .toList(),
                                                            ],
                                                            if (parts[2].isNotEmpty && parts[2] != 'Default')
                                                              Text('Variants: ${parts[2]}',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: Colors.grey,
                                                                    decoration: isStriked ? TextDecoration.lineThrough : null,
                                                                  )),
                                                            if (parts[3].isNotEmpty)
                                                              Text('Type: ${parts[3]}',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: Colors.grey,
                                                                    decoration: isStriked ? TextDecoration.lineThrough : null,
                                                                  )),
                                                            if (parts[4].isNotEmpty)
                                                              Text('Remarks: ${parts[4]}',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: Colors.grey,
                                                                    decoration: isStriked ? TextDecoration.lineThrough : null,
                                                                  )),
                                                          ],
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 50,
                                                        child: Column(
                                                          children: [
                                                            if (parts[1].isNotEmpty && parts[1] != '[]') ...[
                                                              const Text(
                                                                'Price:',
                                                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                                              ),
                                                              // Display each add-on vertically
                                                              ...parts[1]
                                                                  .replaceAll('[', '')
                                                                  .replaceAll(']', '')
                                                                  .toLowerCase()
                                                                  .split(',')
                                                                  .map((addonPrice) => Text(
                                                                        addonPrice.trim(), // Display each addon on a new line
                                                                        style: TextStyle(
                                                                          fontSize: 12,
                                                                          color: Colors.grey,
                                                                          decoration: isStriked ? TextDecoration.lineThrough : null,
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
                    );
                  },
                )
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text(
                    "Cancel Order",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final TextEditingController remarkController = TextEditingController();
                    final bool confirm = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: Colors.white,
                              title: const Text('Cancel All Items?'),
                              content: RemarkTextField(controller: remarkController),
                              actions: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 2,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: const Color.fromARGB(255, 239, 72, 72),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(fontSize: 16, color: Colors.white),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    // Check if the remark field is empty
                                    if (remarkController.text.isEmpty) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        showCustomFlushbar(
                                          context,
                                          'Please enter a remark before confirming',
                                          type: FlushbarType.warning,
                                        );
                                      });
                                      return;
                                    }

                                    // Check if the remark exceeds max length
                                    if (remarkController.text.length > kMaxRemarkLength) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        showCustomFlushbar(
                                          context,
                                          'Remark cannot exceed $kMaxRemarkLength characters',
                                          type: FlushbarType.warning,
                                        );
                                      });
                                      return;
                                    }

                                    // Proceed if remark is valid
                                    Navigator.of(context).pop(true);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 2,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: const Color(0xFFA5D6A7),
                                  ),
                                  child: const Text(
                                    'Yes',
                                    style: TextStyle(fontSize: 16, color: Colors.black),
                                  ),
                                ),
                              ],
                            );
                          },
                        ) ??
                        false;

                    if (confirm) {
                      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                      // Loop through orders for this seat (or however your logic identifies orders)
                      for (var order in widget.seatOrders) {
                        final String seathiveOrderId = order['seathiveOrderId'];
                        await OrderPatchService.patchOrderCancellation(
                          seathiveOrderId: seathiveOrderId,
                          remark: remarkController.text,
                          channel: orderProvider.channel,
                          inMemoryOrders: orderProvider.orders, // optional
                        );

                        var printerIp = printerProvider.getPrinterIpForItem(widget.seatOrders.first['varianceNames'].first.toString());

                        if (printerIp == null) {
                          await promptForPrinterIp(context);
                          printerIp = printerProvider.getPrinterIpForItem(widget.seatOrders.first['varianceNames'].first.toString());
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
                        ); // ✅ Group and send combined stock update per seathiveOrderId
                        final Map<String, List<Map<String, dynamic>>> groupedOrders = {};

                        // Group orders by seathiveOrderId
                        for (var order in widget.seatOrders) {
                          final id = order['seathiveOrderId'];
                          groupedOrders.putIfAbsent(id, () => []).add(order);
                        }

                        // For each seathiveOrderId, accumulate all varianceNames and quantities and send stock update
                        groupedOrders.forEach((seathiveOrderId, orders) {
                          final List<String> combinedVarianceNames = [];
                          final List<String> combinedVarianceItemCodes = [];
                          final List<int> combinedQuantities = [];

                          for (var order in orders) {
                            final names = List<String>.from(order['varianceNames'] ?? []);
                            final itemCodes = List<String>.from(order['varianceItemCodes'] ?? []);
                            final qtys = (order['quantities'] as List).map((e) => (e is int) ? e : (e as double).toInt()).toList();

                            combinedVarianceNames.addAll(names);
                            combinedVarianceItemCodes.addAll(itemCodes);
                            combinedQuantities.addAll(qtys);
                          }

                          // ✅ Send combined stock update
                          sendAddStockUpdateGlobally(
                            context: context,
                            channel: orderProvider.channel,
                            varianceNames: combinedVarianceNames,
                            varianceItemCodes: combinedVarianceItemCodes,
                            quantities: combinedQuantities,
                          );
                        });
                      }
                    }
                  },
                ),
                ElevatedButton(
                  onPressed: () async {
                    var printerIp = Provider.of<PrinterProviderDine>(context, listen: false).getPreInvoicePrinterIp();

                    if (printerIp == null) {
                      await promptForPrinterIp(context);
                      // Re-check after potentially setting the IP
                      printerIp = Provider.of<PrinterProviderDine>(context, listen: false).getPreInvoicePrinterIp();
                      if (printerIp == null) {
                        return; // Exit if still not set to avoid proceeding without a printer IP
                      }
                    }

                    // ignore: use_build_context_synchronously
                    bool confirm = await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(15.0)),
                          ),
                          title: const Text(
                            'Confirmation ',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            'Are you sure? you want to generate the Pre invoice for\n ${widget.tableNumber} - ${widget.seat}?',
                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                          ),
                          actions: <Widget>[
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 239, 72, 72),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA5D6A7),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(fontSize: 16, color: Colors.black),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirm == true) {
                      submissionProvider.startSubmitting();
                      try {
                        await patchStatusConfirm(widget.tableNumber, widget.seat, widget.seatOrders, orderProvider);

                        final preInvoicePrinter = printerProvider.printers.firstWhere(
                          (printer) => printer.type == 'PreInvoice',
                          orElse: () {
                            return Printer(
                              name: 'default_printer_name',
                              ipAddress: 'default_ip',
                              type: 'default_type',
                            );
                          },
                        );

                        await requestAndPrintPreInvoice(
                            channel: channel!,
                            areaName: widget.areaName,
                            ipAddress: preInvoicePrinter.ipAddress,
                            seat: widget.seat,
                            seatOrders: widget.seatOrders,
                            tableNumber: widget.tableNumber,
                            userName: widget.loggedInUserName,
                            waiter: widget.waiter,
                            seathiveOrderId: widget.seathiveOrderId);

                        if (!context.mounted) return;

                        // Provider.of<BottomNavProviderKOT>(context, listen: false).updateIndex(0);
                        // ignore: invalid_use_of_protected_member
                        orderProvider.notifyListeners(); // ensure UI update

                        // ignore: use_build_context_synchronously
                        if (!context.mounted) return; // ✅ double-check before navigation
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OrderSummaryScreen()),
                        );
                        // Provider.of<BottomNavProviderKOT>(context, listen: false).updateIndex(1);
                      } catch (e) {
                        print("Submission error: $e");
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Something went wrong!")));
                        }
                      } finally {
                        submissionProvider.stopSubmitting();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA5D6A7),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

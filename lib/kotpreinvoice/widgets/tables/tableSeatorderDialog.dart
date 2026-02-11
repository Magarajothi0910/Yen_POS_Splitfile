import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../../Global/globals_data.dart';
import '../../../Sale_order/Widgets/Send_data_to_server.dart';
import '../../../invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import '../../../kotpreinvoice/Helper/RemarkTextfield.dart';
import '../../../kotpreinvoice/Helper/addStock_utils.dart';
import '../../../kotpreinvoice/services/CancellationReceipt.dart';
import '../../../kotpreinvoice/services/invoice_number_service.dart';
import '../../widgets/cancel_order_approve.dart';
import '../../components/flushbar.dart';
import '../../providers/order_provider.dart';
import '../../providers/submissionProvider.dart';
import '../../services/preInv Utility.dart';
import '../../components/capitalizeWord.dart';
import '../../services/CancelOrder_Patch.dart';
import '../../providers/printer_provider.dart';

class SeatOrderDetailsDialog {
  static Future<void> _cancelSingleItem({
    required BuildContext context,
    required Map<String, dynamic> order,
    required int itemIndex,
    required OrderProvider orderProvider,
    required PrinterProviderDine printerProvider,
  }) async {
    debugPrint('================ START _cancelSingleItem ================');
    try {
      debugPrint('Step 1: Initializing validation flags');
      bool isQtyValid = false;
      String? qtyError;

      debugPrint('Step 2: Reading order lists');
      final List quantities = order['quantities'] ?? [];
      final List varianceNames = order['varianceNames'] ?? [];
      final List amounts = order['amounts'] ?? [];

      debugPrint('quantities => $quantities');
      debugPrint('varianceNames => $varianceNames');
      debugPrint('amounts => $amounts');

      debugPrint('Step 3: Validating itemIndex = $itemIndex');
      if (itemIndex < 0 ||
          itemIndex >= quantities.length ||
          itemIndex >= varianceNames.length) {
        debugPrint('❌ Invalid itemIndex detected');
        showCustomFlushbar(
          context,
          "Invalid item index",
          type: FlushbarType.error,
        );
        return;
      }

      debugPrint('Step 4: Reading current quantity');
      final double currentQty = (quantities[itemIndex] as num).toDouble();
      debugPrint('currentQty => $currentQty');

      debugPrint('Step 5: Initializing controllers');
      final TextEditingController remarkController = TextEditingController();
      final TextEditingController cancelQtyController = TextEditingController(
        text: currentQty.toString(),
      );

      if (currentQty <= 0) {
        debugPrint('❌ Item already cancelled');
        showCustomFlushbar(
          context,
          "Item already cancelled",
          type: FlushbarType.warning,
        );
        return;
      }

      debugPrint('Step 6: Showing confirmation dialog');
      final bool confirm =
          await showDialog<bool>(
            context: context,
            builder: (ctx) {
              debugPrint('Dialog opened');
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Cancel Item Quantity',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Available Qty: $currentQty',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),

                    StatefulBuilder(
                      builder: (context, setState) {
                        return TextField(
                          controller: cancelQtyController,
                          readOnly: currentQty == 1,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*$'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Cancel Quantity',
                            border: const OutlineInputBorder(),
                            errorText: qtyError,
                          ),
                          onChanged: (value) {
                            debugPrint('Qty field changed => "$value"');

                            final double? enteredQty = double.tryParse(value);
                            debugPrint('Parsed enteredQty => $enteredQty');

                            if (value.isEmpty) {
                              qtyError = 'Enter quantity';
                              isQtyValid = false;
                            } else if (enteredQty == null) {
                              qtyError = 'Invalid number';
                              isQtyValid = false;
                            } else if (enteredQty <= 0) {
                              qtyError = 'Quantity must be greater than 0';
                              isQtyValid = false;
                            } else if (enteredQty > currentQty) {
                              debugPrint(
                                'Entered qty > currentQty, auto correcting',
                              );
                              cancelQtyController.text = currentQty.toString();
                              qtyError = 'Max available: $currentQty';
                              isQtyValid = false;
                            } else {
                              qtyError = null;
                              isQtyValid = true;
                            }

                            debugPrint(
                              'qtyError => $qtyError | isQtyValid => $isQtyValid',
                            );
                            setState(() {});
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 10),
                    RemarkTextField(controller: remarkController),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      debugPrint('Dialog cancelled by user');
                      Navigator.pop(ctx, false);
                    },
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      debugPrint('Confirm button pressed');

                      final double cancelQty =
                          double.tryParse(cancelQtyController.text) ?? 0;

                      debugPrint('cancelQty entered => $cancelQty');

                      if (cancelQty <= 0 || cancelQty > currentQty) {
                        debugPrint('❌ Invalid cancel quantity');
                        showCustomFlushbar(
                          context,
                          'Invalid cancel quantity',
                          type: FlushbarType.warning,
                        );
                        return;
                      }

                      if (remarkController.text.isEmpty) {
                        debugPrint('❌ Remark empty');
                        showCustomFlushbar(
                          context,
                          'Please enter remark',
                          type: FlushbarType.warning,
                        );
                        return;
                      }

                      debugPrint('Dialog confirmed');
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              );
            },
          ) ??
          false;

      debugPrint('Dialog result => $confirm');
      if (!confirm) return;

      debugPrint('Step 7: Performing calculations');
      final double cancelQty = double.parse(cancelQtyController.text);
      debugPrint('cancelQty final => $cancelQty');

      final List<double> quantitiesList = quantities
          .map((e) => (e as num).toDouble())
          .toList();
      debugPrint('quantitiesList before => $quantitiesList');

      final List<double> cancelledQtyList =
          ((order['cancelledQty'] as List?) ?? [])
              .map((e) => (e as num).toDouble())
              .toList();
      debugPrint('cancelledQtyList before => $cancelledQtyList');

      while (cancelledQtyList.length <= itemIndex) {
        cancelledQtyList.add(0.0);
      }

      final double itemAmount = (amounts[itemIndex] as num).toDouble();
      debugPrint('itemAmount => $itemAmount');

      final double unitPrice = itemAmount / currentQty;
      debugPrint('unitPrice => $unitPrice');

      final double cancelAmount = unitPrice * cancelQty;
      debugPrint('cancelAmount => $cancelAmount');

      final double currentTotal = (order['totalAmount'] as num).toDouble();
      debugPrint('currentTotal => $currentTotal');

      quantitiesList[itemIndex] = currentQty - cancelQty;
      cancelledQtyList[itemIndex] += cancelQty;

      final double newTotal = currentTotal - cancelAmount;
      debugPrint('newTotal => $newTotal');

      debugPrint('Step 8: Printer lookup');
      final String itemName = varianceNames[itemIndex].toString().toLowerCase();
      debugPrint('itemName => $itemName');

      String? printerIp =
          order['printerIpMap']?[itemName] ??
          printerProvider.getPrinterIpForItem(itemName);

      debugPrint('printerIp => $printerIp');

      if (printerIp == null || printerIp.isEmpty) {
        debugPrint('❌ Printer not configured');
        showCustomFlushbar(
          context,
          'Printer not configured for $itemName',
          type: FlushbarType.error,
        );
        return;
      }

      debugPrint('Step 9: Preparing server payload');
      final Map<String, dynamic> dataToSend = {
        'action': 'cancelOrderItem',
        'hiveOrderId': order['hiveOrderId'],
        'itemIndex': itemIndex,
        'configIndex': itemIndex,
        'quantities': quantitiesList,
        'cancelledQty': cancelledQtyList,
        'cancelQty': cancelQty,
        'cancelAmount': cancelAmount,
        'totalAmount': newTotal,
        'itemRemark': remarkController.text,
        'partiallycancelled': quantitiesList[itemIndex] > 0,
        'ipAddress': printerIp,
      };

      debugPrint('dataToSend => $dataToSend');
      sendataToServer(dataToSend);

      debugPrint('Step 10: Updating local state');
      order['quantities'] = quantitiesList;
      order['cancelledQty'] = cancelledQtyList;
      order['totalAmount'] = newTotal;
      order['partiallycancelled'] = true;

      orderProvider.notifyListeners();

      debugPrint('✅ Item cancellation successful');
      showCustomFlushbar(
        context,
        'Item cancelled successfully',
        type: FlushbarType.success,
      );
    } catch (e, stack) {
      debugPrint('💥 ERROR in _cancelSingleItem => $e');
      debugPrint('📌 STACKTRACE => $stack');

      showCustomFlushbar(
        context,
        'Error cancelling item',
        type: FlushbarType.error,
      );
    } finally {
      debugPrint('================ END _cancelSingleItem ================');
    }
  }

  static Future<void> _reverseSingleItem({
    required BuildContext context,
    required Map<String, dynamic> order,
    required int itemIndex,
    required OrderProvider orderProvider,
    required PrinterProviderDine printerProvider,
  }) async {
    try {
      print("🔄 Starting reverse cancellation for index: $itemIndex");
      print("order of revert is : $order");

      // === 1. Validation (keep your safe checks) ===
      final List<dynamic> quantitiesDyn = order['quantities'] ?? [];
      final List<dynamic> weightsDyn = order['weights'] ?? [];
      final List<dynamic> varianceNames = order['varianceNames'] ?? [];
      final List<dynamic> cancelledQtyDyn = order['cancelledQty'] ?? [];
      final List<dynamic> pricesDyn = order['prices'] ?? [];

      print(
        "order of revert is : $quantitiesDyn , $varianceNames , $cancelledQtyDyn , $pricesDyn , weight is $weightsDyn",
      );

      if (itemIndex < 0 ||
          itemIndex >= quantitiesDyn.length ||
          itemIndex >= varianceNames.length ||
          itemIndex >= cancelledQtyDyn.length) {
        // _showError(context, "Invalid item index or incomplete data");
        return;
      }

      // Convert to double lists safely
      final List<double> quantitiesList = quantitiesDyn
          .map((e) => (e is num) ? e.toDouble() : 0.0)
          .toList();
      final List<double> cancelledQtyList = cancelledQtyDyn
          .map((e) => (e is num) ? e.toDouble() : 0.0)
          .toList();
      final List<double> pricesList = pricesDyn
          .map((e) => (e is num) ? e.toDouble() : 0.0)
          .toList();

      final double currentCancelledQty = cancelledQtyList[itemIndex];

      if (currentCancelledQty <= 0) {
        // _showWarning(context, "Item is not cancelled. Nothing to revert.");
        return;
      }

      // === 2. Confirmation Dialog (keep yours) ===
      final bool confirm =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Revert Cancelled Item'),
              content: Text(
                'Are you sure you want to revert "${varianceNames[itemIndex]}" (Qty: $currentCancelledQty)?',
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'No',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA5D6A7),
                  ),
                  onPressed: () {
                    Navigator.pop(context, true);
                    Navigator.pop(context);
                  },

                  child: const Text(
                    'Yes',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirm) return;

      // === 3. Restore quantity (same as old) ===
      final double restoredQty = currentCancelledQty;
      cancelledQtyList[itemIndex] = 0.0;
      quantitiesList[itemIndex] = restoredQty;

      // === 4. RECALCULATE TOTAL PROPERLY (CRITICAL FIX) ===
      // double newTotal = 0.0;
      // for (int i = 0; i < quantitiesList.length; i++) {
      //   newTotal += quantitiesList[i] * pricesList[i];
      // }
      double newTotal = 0.0;

      for (int i = 0; i < quantitiesList.length; i++) {
        final double qty = quantitiesList[i];
        final double price = pricesList[i];
        final double weight = (i < weightsDyn.length) ? weightsDyn[i] : 0.0;

        if (qty <= 0) continue;

        // ✅ WEIGHT PRODUCT
        if (weight > 0) {
          newTotal += price * weight * qty;
        }
        // ✅ PCS PRODUCT
        else {
          newTotal += price * qty;
        }
        debugPrint(
          "RECALC [$i] → "
          "qty=$qty | weight=$weight | price=$price | "
          "amount=${weight > 0 ? price * weight * qty : price * qty}",
        );
      }

      final bool stillPartiallyCancelled = cancelledQtyList.any((q) => q > 0.0);

      // === 5. Update order map ===
      order['quantities'] = quantitiesList;
      order['cancelledQty'] = cancelledQtyList;
      order['totalAmount'] = newTotal;
      order['partiallycancelled'] = stillPartiallyCancelled;

      // Clear remark for this item
      if (order['itemRemark'] is List<dynamic>) {
        final remarks = order['itemRemark'] as List<dynamic>;
        while (remarks.length <= itemIndex) remarks.add('');
        remarks[itemIndex] = '';
      }
      final List<String> variancesNames = List<String>.from(
        order['varianceNames'] ?? [],
      );

      final List<String> varianceItemCodes = List<String>.from(
        order['varianceitemCodes'] ?? [],
      );

      final List<String> uoms = List<String>.from(order['uoms'] ?? []);

      final List<double> weights = List<double>.from(order['weights'] ?? []);

      // === 8. Print reversal receipt (keep your logic) ===
      String itemName =
          (varianceNames[itemIndex]?.toString().trim().toLowerCase()) ?? '';
      String? printerIp =
          order['printerIpMap']?[itemName] ??
          printerProvider.getPrinterIpForItem(itemName);

      // };
      final Map<String, dynamic> dataToSend = {
        'action': 'reverseCancelOrderItem',
        'hiveOrderId': order['hiveOrderId'],

        // ✅ single item only
        'varianceName': variancesNames[itemIndex],
        'varianceItemCode': varianceItemCodes[itemIndex],
        'uom': uoms[itemIndex],
        'weight': weights[itemIndex],

        'updatedIndex': itemIndex,
        'updatedQuantity': quantitiesList[itemIndex],
        'updatedCancelledQty': cancelledQtyList[itemIndex],
        'totalAmount': newTotal,
        'partiallycancelled': stillPartiallyCancelled,
        'ipAddress': printerIp,
      };

      debugPrint('_reverseSingleItem dataToSend :  $dataToSend  , $itemIndex');

      sendataToServer(dataToSend); // or however your main send works

      // if (printerIp != null && printerIp.isNotEmpty) {
      //   final filteredOrder = {
      //     ...order,
      //     'quantities': [quantitiesList[itemIndex]],
      //     'cancelledQty': [0.0],
      //     'amounts': [restoredQty * pricesList[itemIndex]],
      //     'prices': [pricesList[itemIndex]],
      //     'varianceNames': [varianceNames[itemIndex]],
      //     // add other needed fields...
      //   };

      //   try {
      //     await CancelPrinterService.printUniversalReceipt(
      //       ipAddress: printerIp,
      //       tableNumber: order['table'] ?? '',
      //       seat: order['seat'] ?? '',
      //       userName: order['userName'] ?? '',
      //       waiter: order['waiter'] ?? '',
      //       seatOrders: [filteredOrder],
      //       receiptType: 'ITEM REVERTED',
      //     );
      //   } catch (e) {
      //     print("❌ Print failed: $e");
      //   }
      // }

      // === 9. Update provider & UI – FORCE REFRESH LIKE OLD CODE ===
      orderProvider.updateOrderByHiveOrderId(
        order['hiveOrderId'],
        order,
      ); // if you have this method
      orderProvider.notifyListeners();

      // _showSuccess(context, "Item reverted successfully!");
    } catch (e, stack) {
      print("💥 Error in _reverseSingleItem: $e\n$stack");
      // _showError(context, "Error reverting item: $e");
    }
  }

  static void showSeatOrderDetails({
    required BuildContext context,
    required BuildContext rootContext,
    required OrderProvider orderProvider,
    required String tableNumber,
    required String seat,
    required List<dynamic> ordersForSeat,
    required printerIp,
  }) {
    try {
      final totalPrice = orderProvider.getseatTotalPrice(tableNumber, seat);
      final submissionProvider = Provider.of<SubmissionProviderDine>(
        context,
        listen: false,
      );
      final printerProvider = Provider.of<PrinterProviderDine>(
        context,
        listen: false,
      );
      final prov = Provider.of<SalesInvoiceState>(context, listen: false);

      final bool isActiveOrder = ordersForSeat.any(
        (order) => order['status'] == 'active',
      );
      Widget _approvalStatusBadge(String status) {
        late Color color;
        late IconData icon;
        late String text;

        switch (status) {
          case 'approved':
            color = Colors.green;
            icon = Icons.check;
            text = 'Approved';
            break;

          case 'pending':
            color = Colors.orange;
            icon = Icons.hourglass_top;
            text = 'Pending';
            break;

          case 'declined':
            color = Colors.red;
            icon = Icons.close;
            text = 'Declined';
            break;

          default:
            return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            // boxShadow: const [
            //   BoxShadow(
            //     color: Colors.black26,
            //     blurRadius: 2,
            //     offset: Offset(0, 1),
            //   ),
            // ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        );
      }

      String? getApprovalStatus({
        required Box box,
        required String tableNumber,
        required String seat,
        required String seathiveOrderId,
      }) {
        for (final value in box.values) {
          if (value is Map) {
            if (value['tableNumber'] == tableNumber &&
                value['seat'] == seat &&
                value['seathiveOrderId'] == seathiveOrderId) {
              return value['status']?.toString();
            }
          }
        }
        return null;
      }

      final activeOrders = orderProvider.orders
          .where(
            (order) =>
                order['table'] == tableNumber &&
                    order['seat'] == seat &&
                    order['status'] == 'active' ||
                order['status'] == 'confirm',
          )
          .toList();

      if (activeOrders.isEmpty) {
        debugPrint(
          '⚠️ No activeOrders orders found for $tableNumber seat $seat',
        );
        return;
      }

      final firstOrder = activeOrders.first;
      if (activeOrders.isNotEmpty) {
        createdBy = firstOrder['waiter'];
      }

      showDialog(
        context: context,
        builder: (BuildContext confirmationContext) {
          final screenWidth = MediaQuery.of(confirmationContext).size.width;
          final screenHeight = MediaQuery.of(confirmationContext).size.height;
          final dialogWidth = screenWidth > 600 ? 800.0 : screenWidth * 0.8;

          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(24),
            child: Container(
              width: dialogWidth,
              height: screenHeight * 0.85,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$tableNumber  •  Seat $seat",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Total: ₹${totalPrice.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(confirmationContext),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  /// ORDERS LIST
                  Expanded(
                    child: ordersForSeat.isEmpty
                        ? const Center(
                            child: Text(
                              "No active orders for this seat",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: ordersForSeat.map((order) {
                                try {
                                  return Card(
                                    color: Colors.white,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: buildOrderDetails(
                                        items: order['varianceNames'] ?? [],
                                        prices: order['prices'] ?? [],
                                        uoms: order['uoms'] ?? [],
                                        weights: order['weights'] ?? [],
                                        quantities: order['quantities'] ?? [],
                                        amounts: order['amounts'] ?? [],
                                        config: order['config'] ?? [],
                                        tokenNo:
                                            order['tokenNo']?.toString() ??
                                            'N/A',
                                        context: confirmationContext,
                                        orderProvider: orderProvider,
                                        printerProvider: printerProvider,
                                        order: order,
                                        status: order['status'] ?? '',
                                      ),
                                    ),
                                  );
                                } catch (_) {
                                  return const SizedBox.shrink();
                                }
                              }).toList(),
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  /// ACTION BAR
                  Row(
                    children: [
                      /// CLOSE
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(confirmationContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Close"),
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// CANCEL ORDER (STATUS AWARE)
                      Expanded(
                        child: AbsorbPointer(
                          absorbing: !isActiveOrder,
                          child: ValueListenableBuilder<Box>(
                            valueListenable: Hive.box(
                              'approvelOrdersKOT',
                            ).listenable(),
                            builder: (context, box, _) {
                              // final String? status = 'approved';
                              final String? status = box.isNotEmpty
                                  ? getApprovalStatus(
                                      box: box,
                                      tableNumber: tableNumber,
                                      seat: seat,
                                      seathiveOrderId: ordersForSeat.isNotEmpty
                                          ? ordersForSeat
                                                .first['seathiveOrderId']
                                          : null,
                                    )
                                  : null;

                              return SizedBox(
                                height: 48, // ✅ standard button height
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    /// 🔘 Button (perfect bounds)
                                    Positioned.fill(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isActiveOrder
                                              ? Colors.redAccent[200]
                                              : Colors.grey[400],
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 3,
                                        ),
                                        onPressed: !isActiveOrder
                                            ? null
                                            : () async {
                                                String remark = '';
                                                for (final value
                                                    in box.values) {
                                                  if (value is Map) {
                                                    if (value['tableNumber'] ==
                                                            tableNumber &&
                                                        value['seat'] == seat &&
                                                        value['seathiveOrderId'] ==
                                                            (ordersForSeat
                                                                    .isNotEmpty
                                                                ? ordersForSeat
                                                                      .first['seathiveOrderId']
                                                                : null)) {
                                                      remark =
                                                          value['remark'] ?? '';
                                                    }
                                                  }
                                                }
                                                debugPrint(
                                                  "remark data is $remark",
                                                );
                                                switch (status) {
                                                  case 'approved':
                                                    await _cancelOrder(
                                                      context:
                                                          confirmationContext,
                                                      rootContext: rootContext,
                                                      orderProvider:
                                                          orderProvider,
                                                      printerProvider:
                                                          printerProvider,
                                                      tableNumber: tableNumber,
                                                      seat: seat,
                                                      ordersForSeat:
                                                          ordersForSeat,
                                                      remark: remark,
                                                    );
                                                    break;

                                                  case 'pending':
                                                  case null:
                                                    await sendApprove(
                                                      confirmationContext,
                                                      ordersForSeat,
                                                      tableNumber,
                                                      seat,
                                                      remark,
                                                    );
                                                    break;

                                                  case 'declined':
                                                    WidgetsBinding.instance
                                                        .addPostFrameCallback((
                                                          _,
                                                        ) {
                                                          showCustomFlushbar(
                                                            context,
                                                            'Order cancellation was declined by management.',
                                                            type: FlushbarType
                                                                .error,
                                                          );
                                                        });
                                                    break;
                                                }
                                              },
                                        child: const Text(
                                          'Cancel Order',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                    /// 🏷️ Badge (pixel-perfect)
                                    if (status != null)
                                      Positioned(
                                        top: 1,
                                        right: 3,
                                        child: _approvalStatusBadge(status),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// PRE-INVOICE
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isActiveOrder
                              ? () async {
                                  Navigator.pop(confirmationContext);
                                  await _generatePreInvoice(
                                    rootContext: rootContext,
                                    orderProvider: orderProvider,
                                    submissionProvider: submissionProvider,
                                    tableNumber: tableNumber,
                                    seat: seat,
                                    ordersForSeat: ordersForSeat,
                                    printerIp: printerIp,
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActiveOrder
                                ? Colors.blue
                                : Colors.grey[400],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Pre-Invoice"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (err) {
      print("❌ showSeatOrderDetails error: $err");
    }
  }

  static Future<void> _generatePreInvoice({
    required BuildContext rootContext,
    required OrderProvider orderProvider,
    required SubmissionProviderDine submissionProvider,
    required String tableNumber,
    required String seat,
    required List<dynamic> ordersForSeat,
    required String? printerIp,
  }) async {
    submissionProvider.startSubmitting();

    try {
      print("🟢 Confirming orders for seat $seat");

      if (printerIp == null || printerIp.isEmpty) {
        promptForPrinterIp(rootContext);
        return;
      }

      sendPreInvoiceToServer(
        context: rootContext,
        tableNumber: tableNumber,
        seat: seat,
        areaName: ordersForSeat.first['areaName'],
        seatOrders: ordersForSeat as List<Map<String, dynamic>>,
        ipAddress: printerIp,
        userName: userName,
        waiter: createdBy,
        seathiveOrderId: ordersForSeat.isNotEmpty
            ? ordersForSeat.first['seathiveOrderId']
            : '',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomFlushbar(
          rootContext,
          "Invoice generated successfully!",
          type: FlushbarType.success,
        );
      });
    } catch (printErr) {
      debugPrint("❌ Printing error: $printErr");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomFlushbar(
          rootContext,
          "Printing error: $printErr",
          type: FlushbarType.error,
        );
      });
    } finally {
      submissionProvider.stopSubmitting();
      print("🟡 Submission process finished for seat $seat");
    }
  }

  static Future<void> _cancelOrder({
    required BuildContext context,
    required BuildContext rootContext,
    required OrderProvider orderProvider,
    required PrinterProviderDine printerProvider,
    required String tableNumber,
    required String seat,
    required List<dynamic> ordersForSeat,
    required String remark,
  }) async {
    try {
      // Create a TextEditingController for the remark
      // final TextEditingController remarkController = TextEditingController();

      // Show confirmation dialog with remark field
      final bool confirm =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Cancel All Items?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Are you sure you want to cancel all items for this order?',
                    ),
                    // const SizedBox(height: 16),
                    // RemarkTextField(controller: remarkController),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(false);
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
                      Navigator.of(dialogContext).pop(true);
                      Navigator.of(dialogContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: const Color(0xFFA5D6A7),
                    ),
                    child: const Text(
                      'Yes, Cancel Order',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (confirm) {
        FocusManager.instance.primaryFocus?.unfocus();
        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );
        // Loop through orders for this seat (or however your logic identifies orders)
        for (var order in ordersForSeat) {
          final String seathiveOrderId = order['seathiveOrderId'];

          await OrderPatchService.patchOrderCancellation(
            seathiveOrderId: seathiveOrderId,
            remark: 'Cancelled from seat order dialog',
            channel: orderProvider.channel,
            inMemoryOrders: orderProvider.orders, // optional
          );

          var printerIp = printerProvider.getPrinterIpForItem(
            ordersForSeat.first['varianceNames'].first.toString(),
          );

          if (printerIp == null) {
            await promptForPrinterIp(context);
            printerIp = printerProvider.getPrinterIpForItem(
              ordersForSeat.first['varianceNames'].first.toString(),
            );
            if (printerIp == null) {
              return;
            }
          }

          await CancelPrinterService.printUniversalReceipt(
            ipAddress: printerIp.toString(),
            tableNumber: ordersForSeat.first['table'],
            seat: ordersForSeat.first['seat'],
            userName: ordersForSeat.first['captain'] ?? "",
            waiter: ordersForSeat.first['waiter'] ?? "",
            seatOrders: ordersForSeat.cast<Map<String, dynamic>>(),
            receiptType: "Full Order Cancelled",
          ); // ✅ Group and send combined stock update per seathiveOrderId
          final Map<String, List<Map<String, dynamic>>> groupedOrders = {};

          // Group orders by seathiveOrderId
          for (var order in ordersForSeat) {
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
              final itemCodes = List<String>.from(
                order['varianceitemCodes'] ?? [],
              );
              final qtys = (order['quantities'] as List)
                  .map((e) => (e is int) ? e : (e as double).toInt())
                  .toList();

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
          orderProvider.notifyListeners();
        }
        FocusManager.instance.primaryFocus?.unfocus();
      }
    } catch (e, stack) {
      print("💥 Error cancelling order: $e");
      print("📌 Stacktrace: $stack");

      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   showCustomFlushbar(
      //     rootContext,
      //     "Error cancelling order: $e",
      //     type: FlushbarType.error,
      //   );
      // });
    }
  }

  // static Widget buildOrderDetails({
  //   required List items,
  //   required List prices,
  //   required List weights,
  //   required List uoms,
  //   required List quantities,
  //   required List amounts,
  //   required List config,
  //   required String tokenNo,
  //   required BuildContext context,
  //   required OrderProvider orderProvider,
  //   required PrinterProviderDine printerProvider,
  //   required Map<String, dynamic> order,
  //   required String status,
  // }) {
  //   try {
  //     debugPrint("config data is $config");

  //     return Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         /// ================= HEADER =================
  //         Container(
  //           padding: const EdgeInsets.all(8),
  //           decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               const Text(
  //                 "Order",
  //                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  //               ),
  //               Text(
  //                 "Token: $tokenNo",
  //                 style: const TextStyle(fontWeight: FontWeight.bold),
  //               ),
  //             ],
  //           ),
  //         ),

  //         const SizedBox(height: 8),

  //         /// ================= ITEMS =================
  //         Column(
  //           children: List.generate(items.length, (i) {
  //             try {
  //               final String itemName = items[i];

  //               /// ---------- CONFIG LOOKUP ----------
  //               final Map<String, dynamic> itemConfig = config
  //                   .whereType<Map>() // accept Map<dynamic, dynamic>
  //                   .map((e) => Map<String, dynamic>.from(e)) // convert safely
  //                   .firstWhere(
  //                     (c) => c['varianceName'] == itemName,
  //                     orElse: () => <String, dynamic>{},
  //                   );

  //               /// ---------- EXTRACT ALL ADDONS (PER QTY) ----------
  //               final List<String> allAddOnNames = [];
  //               final List<num> allAddOnQty = [];
  //               final List<num> allAddOnPrices = [];

  //               if (itemConfig['addOn'] is List) {
  //                 final List addOnGroups = itemConfig['addOn'];
  //                 final List qtyGroups = itemConfig['addOnQuantities'] ?? [];
  //                 final List priceGroups = itemConfig['addOnPrice'] ?? [];

  //                 for (int q = 0; q < addOnGroups.length; q++) {
  //                   final List addonsForQty = addOnGroups[q] is List
  //                       ? addOnGroups[q]
  //                       : [];
  //                   final List qtyForQty = q < qtyGroups.length
  //                       ? qtyGroups[q] ?? []
  //                       : [];
  //                   final List priceForQty = q < priceGroups.length
  //                       ? priceGroups[q] ?? []
  //                       : [];

  //                   for (int a = 0; a < addonsForQty.length; a++) {
  //                     allAddOnNames.add(addonsForQty[a].toString());
  //                     allAddOnQty.add(a < qtyForQty.length ? qtyForQty[a] : 1);
  //                     allAddOnPrices.add(
  //                       a < priceForQty.length ? priceForQty[a] : 0,
  //                     );
  //                   }
  //                 }
  //               }

  //               /// ---------- BASIC VALUES ----------
  //               final String uom = uoms[i];
  //               final double price = prices.length > i
  //                   ? prices[i].toDouble()
  //                   : 0.0;
  //               final double weight = weights.length > i
  //                   ? weights[i].toDouble()
  //                   : 0.0;
  //               final double quantity = quantities.length > i
  //                   ? quantities[i].toDouble()
  //                   : 0.0;
  //               final double amount = amounts.length > i
  //                   ? amounts[i].toDouble()
  //                   : 0.0;

  //               /// ---------- CANCEL LOGIC ----------
  //               final bool isCancelled =
  //                   quantity == 0.0 &&
  //                   order['cancelledQty'] != null &&
  //                   order['cancelledQty'].length > i &&
  //                   order['cancelledQty'][i] > 0;

  //               return Padding(
  //                 padding: const EdgeInsets.symmetric(vertical: 6),
  //                 child: Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     /// ========== ITEM DETAILS ==========
  //                     Expanded(
  //                       flex: 3,
  //                       child: Column(
  //                         crossAxisAlignment: CrossAxisAlignment.start,
  //                         children: [
  //                           /// ITEM NAME
  //                           Text(
  //                             capitalizeWords(itemName),
  //                             style: isCancelled
  //                                 ? const TextStyle(
  //                                     decoration: TextDecoration.lineThrough,
  //                                     color: Colors.red,
  //                                   )
  //                                 : null,
  //                           ),

  //                           /// PRICE / UOM
  //                           Text(
  //                             "₹${price.toStringAsFixed(0)} / ${uom == "kgs" ? weight : ''} $uom",
  //                             style: const TextStyle(
  //                               fontSize: 12,
  //                               color: Colors.grey,
  //                             ),
  //                           ),

  //                           /// ADDONS (ALL)
  //                           if (allAddOnNames.isNotEmpty)
  //                             Padding(
  //                               padding: const EdgeInsets.only(left: 8, top: 4),
  //                               child: Column(
  //                                 crossAxisAlignment: CrossAxisAlignment.start,
  //                                 children: List.generate(
  //                                   allAddOnNames.length,
  //                                   (a) => Text(
  //                                     "• ${allAddOnNames[a]}  x${allAddOnQty[a]}  ₹${allAddOnPrices[a]}",
  //                                     style: TextStyle(
  //                                       fontSize: 12,
  //                                       color: isCancelled
  //                                           ? Colors.red
  //                                           : Colors.grey,
  //                                       decoration: isCancelled
  //                                           ? TextDecoration.lineThrough
  //                                           : null,
  //                                     ),
  //                                   ),
  //                                 ),
  //                               ),
  //                             ),

  //                           /// CANCELLED QTY
  //                           if (isCancelled)
  //                             Text(
  //                               'Canceled Qty: ${order['cancelledQty'][i]}',
  //                               style: const TextStyle(
  //                                 fontSize: 12,
  //                                 decoration: TextDecoration.lineThrough,
  //                                 color: Colors.red,
  //                               ),
  //                             ),
  //                         ],
  //                       ),
  //                     ),

  //                     /// ========== QUANTITY ==========
  //                     Expanded(
  //                       flex: 1,
  //                       child: Text(
  //                         quantity.toStringAsFixed(0),
  //                         textAlign: TextAlign.center,
  //                         style: isCancelled
  //                             ? const TextStyle(
  //                                 decoration: TextDecoration.lineThrough,
  //                                 color: Colors.red,
  //                               )
  //                             : null,
  //                       ),
  //                     ),

  //                     /// ========== AMOUNT ==========
  //                     Expanded(
  //                       flex: 1,
  //                       child: Text(
  //                         "₹${amount.toStringAsFixed(0)}",
  //                         textAlign: TextAlign.right,
  //                         style: isCancelled
  //                             ? const TextStyle(
  //                                 decoration: TextDecoration.lineThrough,
  //                                 color: Colors.red,
  //                               )
  //                             : null,
  //                       ),
  //                     ),

  //                     /// ========== CANCEL / UNDO ==========
  //                     if (status == "active")
  //                       Expanded(
  //                         flex: 1,
  //                         child: IconButton(
  //                           icon: Icon(
  //                             isCancelled ? Icons.undo : Icons.cancel,
  //                             color: isCancelled ? Colors.green : Colors.red,
  //                             size: 20,
  //                           ),
  //                           onPressed: () async {
  //                             debugPrint(
  //                               "order data before cancel/undo: $order",
  //                             );
  //                             if (isCancelled) {
  //                               await _reverseSingleItem(
  //                                 context: context,
  //                                 order: order,
  //                                 itemIndex: i,
  //                                 orderProvider: orderProvider,
  //                                 printerProvider: printerProvider,
  //                               );
  //                             } else {
  //                               await _cancelSingleItem(
  //                                 context: context,
  //                                 order: order,
  //                                 itemIndex: i,
  //                                 orderProvider: orderProvider,
  //                                 printerProvider: printerProvider,
  //                               );
  //                             }
  //                           },
  //                         ),
  //                       ),
  //                   ],
  //                 ),
  //               );
  //             } catch (rowErr) {
  //               debugPrint("❌ Error building row $i: $rowErr");
  //               return const SizedBox.shrink();
  //             }
  //           }),
  //         ),
  //       ],
  //     );
  //   } catch (err) {
  //     debugPrint("❌ Error in buildOrderDetails: $err");
  //     return const SizedBox.shrink();
  //   }
  // }
  static Widget buildOrderDetails({
    required List items,
    required List prices,
    required List weights,
    required List uoms,
    required List quantities,
    required List amounts,
    required List config,
    required String tokenNo,
    required BuildContext context,
    required OrderProvider orderProvider,
    required PrinterProviderDine printerProvider,
    required Map<String, dynamic> order,
    required String status,
  }) {
    try {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= HEADER =================
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Order",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "Token: $tokenNo",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ================= ITEMS =================
          Column(
            children: List.generate(items.length, (i) {
              try {
                final String itemName = items[i];

                // ---------- CONFIG LOOKUP ----------
                final Map<String, dynamic> itemConfig = config
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .firstWhere(
                      (c) => c['varianceName'] == itemName,
                      orElse: () => <String, dynamic>{},
                    );

                // ---------- CONFIG QTY LOGIC ----------
                final List<int> configQty =
                    (itemConfig['configQty'] as List? ?? [])
                        .map((e) => (e as num).toInt())
                        .toList();

                final int totalQty = configQty.isNotEmpty
                    ? configQty.length
                    : quantities[i].toInt();

                final int remainingQty = configQty.isNotEmpty
                    ? configQty.where((q) => q > 0).length
                    : quantities[i].toInt();

                final int cancelledQty = totalQty - remainingQty;

                final bool isFullyCancelled = remainingQty == 0;
                final bool isPartiallyCancelled =
                    cancelledQty > 0 && remainingQty > 0;

                // ---------- BASIC VALUES ----------
                final String uom = uoms[i];
                final double price = prices.length > i
                    ? prices[i].toDouble()
                    : 0.0;
                final double weight = weights.length > i
                    ? weights[i].toDouble()
                    : 0.0;
                final double amount = amounts.length > i
                    ? amounts[i].toDouble()
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ========== ITEM DETAILS ==========
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ITEM NAME
                            Text(
                              capitalizeWords(itemName),
                              style: isFullyCancelled
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.red,
                                    )
                                  : null,
                            ),

                            // PRICE / UOM
                            Text(
                              "₹${price.toStringAsFixed(0)} / ${uom == "kgs" ? weight : ''} $uom",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),

                            // CONFIG VISUAL DOTS
                            if (configQty.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 4,
                                  children: List.generate(
                                    configQty.length,
                                    (index) => Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: configQty[index] > 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                              ),

                            // CANCEL INFO
                            if (isPartiallyCancelled)
                              Text(
                                "Cancelled: $cancelledQty / $totalQty",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // ========== QUANTITY ==========
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Text(
                              "$remainingQty",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isFullyCancelled
                                    ? Colors.red
                                    : isPartiallyCancelled
                                    ? Colors.orange
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ========== AMOUNT ==========
                      Expanded(
                        flex: 1,
                        child: Text(
                          "₹${amount.toStringAsFixed(0)}",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isFullyCancelled
                                ? Colors.red
                                : isPartiallyCancelled
                                ? Colors.orange
                                : Colors.black,
                            decoration: isFullyCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),

                      // ========== CANCEL / UNDO ==========
                      if (status == "active")
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: Icon(
                              isFullyCancelled ? Icons.undo : Icons.cancel,
                              color: isFullyCancelled
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                            onPressed: () async {
                              if (isFullyCancelled) {
                                await _reverseSingleItem(
                                  context: context,
                                  order: order,
                                  itemIndex: i,
                                  orderProvider: orderProvider,
                                  printerProvider: printerProvider,
                                );
                              } else {
                                await _cancelSingleItem(
                                  context: context,
                                  order: order,
                                  itemIndex: i,
                                  orderProvider: orderProvider,
                                  printerProvider: printerProvider,
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                );
              } catch (rowErr) {
                debugPrint("❌ Row error $i => $rowErr");
                return const SizedBox.shrink();
              }
            }),
          ),
        ],
      );
    } catch (err) {
      debugPrint("❌ buildOrderDetails error => $err");
      return const SizedBox.shrink();
    }
  }
}

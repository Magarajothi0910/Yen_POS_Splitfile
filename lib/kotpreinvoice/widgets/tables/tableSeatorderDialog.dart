import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/kotpreinvoice/Helper/RemarkTextfield.dart';
import 'package:yenpos/kotpreinvoice/Helper/addStock_utils.dart';
import 'package:yenpos/kotpreinvoice/Helper/decreaseStock_utils.dart';
import 'package:yenpos/kotpreinvoice/providers/timerProvider.dart';
import 'package:yenpos/kotpreinvoice/services/CancellationReceipt.dart';
import 'package:yenpos/kotpreinvoice/services/invoice_number_service.dart';

import '../../components/flushbar.dart';
import '../../providers/order_provider.dart';
import '../../providers/submissionProvider.dart';
import '../../services/preInv Utility.dart';
import '../../services/preInvociePrint_services.dart';
import '../../components/capitalizeWord.dart';
import '../../services/CancelOrder_Patch.dart';
import '../../providers/printer_provider.dart';

class SeatOrderDetailsDialog {
  static WebSocketChannel channel = IOWebSocketChannel.connect(
    'ws://$serverip:$port',
  );
  // Add this method to SeatOrderDetailsDialog class
  // static Future<void> _cancelSingleItem({
  //   required BuildContext context,
  //   required Map<String, dynamic> order,
  //   required int itemIndex,
  //   required OrderProvider orderProvider,
  //   required PrinterProviderDine printerProvider,
  // }) async {
  //   try {
  //     final TextEditingController itemremarkController =
  //         TextEditingController();

  //     // Ask the user for confirmation and remark before canceling the item.
  //     final bool confirm =
  //         await showDialog<bool>(
  //           context: context,
  //           builder: (context) {
  //             return AlertDialog(
  //               backgroundColor: Colors.white,
  //               title: const Text('Cancel Item'),
  //               content: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   const Text('Are you sure you want to cancel this item?'),
  //                   const SizedBox(height: 8),
  //                   RemarkTextField(controller: itemremarkController),
  //                 ],
  //               ),
  //               actions: [
  //                 ElevatedButton(
  //                   onPressed: () {
  //                     // Check if the remark field is empty, if so, do not allow clicking Yes
  //                     if (itemremarkController.text.isEmpty) {
  //                       WidgetsBinding.instance.addPostFrameCallback((_) {
  //                         showCustomFlushbar(
  //                           context,
  //                           'Please enter a remark before confirming',
  //                           type: FlushbarType.warning,
  //                         );
  //                       });
  //                       return;
  //                     }

  //                     if (itemremarkController.text.length > kMaxRemarkLength) {
  //                       WidgetsBinding.instance.addPostFrameCallback((_) {
  //                         showCustomFlushbar(
  //                           context,
  //                           'Remark cannot exceed $kMaxRemarkLength characters',
  //                           type: FlushbarType.warning,
  //                         );
  //                       });
  //                       return;
  //                     }

  //                     Navigator.of(
  //                       context,
  //                     ).pop(true); // Proceed if remarks are provided
  //                   },
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: const Color(0xFFA5D6A7),
  //                     elevation: 2,
  //                     shape: RoundedRectangleBorder(
  //                       borderRadius: BorderRadius.circular(12),
  //                     ),
  //                     padding: const EdgeInsets.symmetric(
  //                       horizontal: 16,
  //                       vertical: 10,
  //                     ),
  //                   ),
  //                   child: const Text(
  //                     'Yes',
  //                     style: TextStyle(fontSize: 16, color: Colors.black),
  //                   ),
  //                 ),
  //                 ElevatedButton(
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: Colors.redAccent,
  //                     elevation: 2,
  //                     shape: RoundedRectangleBorder(
  //                       borderRadius: BorderRadius.circular(12),
  //                     ),
  //                     padding: const EdgeInsets.symmetric(
  //                       horizontal: 16,
  //                       vertical: 10,
  //                     ),
  //                   ),
  //                   onPressed: () => Navigator.of(context).pop(false),
  //                   child: const Text(
  //                     'No',
  //                     style: TextStyle(fontSize: 16, color: Colors.white),
  //                   ),
  //                 ),
  //               ],
  //             );
  //           },
  //         ) ??
  //         false;

  //     if (!confirm) return;

  //     // Convert lists to List<double> if needed.
  //     order['quantities'] = (order['quantities'] as List)
  //         .map((e) => (e as num).toDouble())
  //         .toList();
  //     if (order['amounts'] != null) {
  //       order['amounts'] = (order['amounts'] as List)
  //           .map((e) => (e as num).toDouble())
  //           .toList();
  //     }
  //     if (order['cancelledQty'] != null) {
  //       order['cancelledQty'] = (order['cancelledQty'] as List)
  //           .map((e) => (e as num).toDouble())
  //           .toList();
  //     } else {
  //       order['cancelledQty'] = List.filled(order['quantities'].length, 0.0);
  //     }
  //     order['totalAmount'] = ((order['totalAmount'] ?? 0) as num).toDouble();

  //     // Retrieve the current quantity for the item as double.
  //     final double currentQuantity = (order['quantities'][itemIndex] as num)
  //         .toDouble();

  //     // Set cancelled quantity at this index to the current quantity.
  //     order['cancelledQty'][itemIndex] = currentQuantity;

  //     // Cancel the item by setting its quantity to 0.0.
  //     order['quantities'][itemIndex] = 0.0;

  //     // Update the total amount by subtracting this item's amount.
  //     final double itemAmount = (order['amounts'][itemIndex] as num).toDouble();
  //     order['totalAmount'] = order['totalAmount'] - itemAmount;

  //     // Mark the order as partially cancelled.
  //     order['partiallycancelled'] = true;
  //     final String itemName =
  //         order['varianceNames'][itemIndex]?.toString().trim().toLowerCase() ??
  //         '';

  //     // Get printer IP for the item
  //     String? printerIp = order['printerIpMap']?[itemName];
  //     if (printerIp == null) {
  //       printerIp = printerProvider.getPrinterIpForItem(itemName);
  //       if (printerIp != null) {
  //         order['printerIpMap'] = (order['printerIpMap'] ?? {})
  //           ..[itemName] = printerIp;
  //       } else {
  //         // Show error if no printer IP found
  //         WidgetsBinding.instance.addPostFrameCallback((_) {
  //           showCustomFlushbar(
  //             context,
  //             'Printer IP not found for item: $itemName',
  //             type: FlushbarType.error,
  //           );
  //         });
  //         return;
  //       }
  //     }

  //     // Prepare the update packet to send to the server.
  //     final Map<String, dynamic> dataToSend = {
  //       'action': 'cancelOrderItem',
  //       'hiveOrderId': order['hiveOrderId'],
  //       'cancelledQty': order['cancelledQty'],
  //       'totalAmount': order['totalAmount'],
  //       'quantities': order['quantities'],
  //       'itemRemark': itemremarkController.text,
  //       'partiallycancelled': true,
  //     };

  //     // Send the updated details to the server.
  //     orderProvider.channel.sink.add(jsonEncode(dataToSend));

  //     // Send stock update
  //     sendAddStockUpdateGlobally(
  //       context: context,
  //       channel: orderProvider.channel,
  //       varianceNames: [order['varianceNames'][itemIndex]],
  //       varianceItemCodes: [order['varianceItemCodes'][itemIndex]],
  //       quantities: [currentQuantity.toInt()],
  //     );

  //     // Build trimmed order with only the cancelled item index
  //     final filteredOrder = {
  //       ...order,
  //       'quantities': [order['quantities'][itemIndex]],
  //       'cancelledQty': [order['cancelledQty'][itemIndex]],
  //       'amounts': [order['amounts'][itemIndex]],
  //       'prices': [order['prices'][itemIndex]],
  //       'weights': [order['weights'][itemIndex]],
  //       'varianceNames': [order['varianceNames'][itemIndex]],
  //       'config': [order['config'][itemIndex]],
  //     };

  //     // Print cancellation receipt for the single item
  //     await CancelPrinterService.printUniversalReceipt(
  //       ipAddress: printerIp,
  //       tableNumber: order['table'] ?? '',
  //       seat: order['seat'] ?? '',
  //       userName: order['userName'] ?? '',
  //       waiter: order['waiter'] ?? '',
  //       seatOrders: [filteredOrder],
  //       receiptType: 'ITEM CANCELLED',
  //     );

  //     // Show success message
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       showCustomFlushbar(
  //         context,
  //         "Item cancelled successfully!",
  //         type: FlushbarType.success,
  //       );
  //     });

  //     // Notify listeners to update UI
  //     orderProvider.notifyListeners();
  //   } catch (e, stack) {
  //     print("💥 Error in _cancelSingleItem: $e");
  //     print("📌 Stacktrace: $stack");

  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       showCustomFlushbar(
  //         context,
  //         "Error cancelling item: $e",
  //         type: FlushbarType.error,
  //       );
  //     });
  //   }
  // }

  static Future<void> _reverseSingleItem({
    required BuildContext context,
    required Map<String, dynamic> order,
    required int itemIndex,
    required OrderProvider orderProvider,
    required PrinterProviderDine printerProvider,
  }) async {
    WebSocketChannel? tempChannel;

    try {
      print("🔄 Starting reverse cancellation for index: $itemIndex");

      // 1. Validate indices first
      if (itemIndex < 0 ||
          itemIndex >= (order['quantities']?.length ?? 0) ||
          itemIndex >= (order['varianceNames']?.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCustomFlushbar(
            context,
            "Invalid item index",
            type: FlushbarType.error,
          );
        });
        return;
      }

      // 2. Get current values with safe access
      final List<dynamic> quantities = order['quantities'] ?? [];
      final List<dynamic> varianceNames = order['varianceNames'] ?? [];
      final List<dynamic> cancelledQty = order['cancelledQty'] ?? [];

      if (itemIndex >= quantities.length ||
          itemIndex >= varianceNames.length ||
          itemIndex >= cancelledQty.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCustomFlushbar(
            context,
            "Item data incomplete",
            type: FlushbarType.error,
          );
        });
        return;
      }

      // 3. Check if item is actually cancelled
      final double currentCancelledQty = (cancelledQty[itemIndex] is num)
          ? (cancelledQty[itemIndex] as num).toDouble()
          : 0.0;

      if (currentCancelledQty <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCustomFlushbar(
            context,
            "Item is not cancelled. Nothing to revert.",
            type: FlushbarType.warning,
          );
        });
        return;
      }

      // 4. Ask for confirmation
      final bool confirm =
          await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Revert Cancelled Item'),
                content: Text(
                  'Are you sure you want to revert the cancelled item "${varianceNames[itemIndex]}" (Qty: $currentCancelledQty)?',
                ),
                actions: [
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
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA5D6A7),
                    ),
                    child: const Text(
                      'Yes',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirm) return;

      // 5. Safe type conversion for all lists
      final List<double> quantitiesList = quantities
          .map((e) => (e is num) ? e.toDouble() : 0.0)
          .toList();

      final List<double> amountsList = ((order['amounts'] as List?) ?? [])
          .map((e) => (e is num) ? e.toDouble() : 0.0)
          .toList();

      final List<double> cancelledQtyList = cancelledQty
          .map((e) => (e is num) ? e.toDouble() : 0.0)
          .toList();

      final List<double> pricesList = ((order['prices'] as List?) ?? [])
          .map((e) => (e is num) ? e.toDouble() : 0.0)
          .toList();

      // 6. Reverse the cancellation
      final double restoredQty = cancelledQtyList[itemIndex];
      cancelledQtyList[itemIndex] = 0.0;
      quantitiesList[itemIndex] = restoredQty;

      // 7. Recalculate total
      final double currentTotal = (order['totalAmount'] is num)
          ? (order['totalAmount'] as num).toDouble()
          : 0.0;
      final double itemPrice = pricesList.length > itemIndex
          ? pricesList[itemIndex]
          : 0.0;
      final double restoredAmount = restoredQty * itemPrice;
      final double newTotal = currentTotal + restoredAmount;

      // 8. Check if still partially cancelled
      final bool stillPartiallyCancelled = cancelledQtyList.any((q) => q > 0.0);

      // 9. Get printer IP
      final String itemName =
          varianceNames[itemIndex]?.toString().trim().toLowerCase() ?? '';
      String? printerIp = order['printerIpMap']?[itemName];
      if (printerIp == null) {
        printerIp = printerProvider.getPrinterIpForItem(itemName);
      }

      if (printerIp == null || printerIp.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCustomFlushbar(
            context,
            'Printer not configured for item: ${varianceNames[itemIndex]}',
            type: FlushbarType.error,
          );
        });
        return;
      }

      // 10. Send update to server
      final Map<String, dynamic> dataToSend = {
        'action': 'reverseCancelOrderItem',
        'hiveOrderId': order['hiveOrderId'],
        'cancelledQty': cancelledQtyList,
        'totalAmount': newTotal,
        'quantities': quantitiesList,
        'partiallycancelled': stillPartiallyCancelled,
        'itemIndex': itemIndex,
        'itemRemark': '', // Clear remark for reversed item
      };

      // Try main channel first
      bool mainChannelFailed = false;
      try {
        orderProvider.channel.sink.add(jsonEncode(dataToSend));
        print("✅ Used main channel for reverse cancellation");
      } catch (e) {
        print("⚠️ Main channel failed: $e");
        mainChannelFailed = true;
      }

      // If main channel failed, use fresh channel
      if (mainChannelFailed) {
        try {
          tempChannel = IOWebSocketChannel.connect('ws://$serverip:$port');
          tempChannel.sink.add(jsonEncode(dataToSend));
          print("🔄 Used fresh channel for reverse cancellation");
        } catch (e) {
          print("❌ Fresh channel also failed: $e");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCustomFlushbar(
              context,
              "Network error. Please check connection and try again.",
              type: FlushbarType.error,
            );
          });
          return;
        }
      }

      // 11. Send stock update (decrease stock since item is back)
      final stockUpdateChannel = mainChannelFailed
          ? tempChannel!
          : orderProvider.channel;

      sendDecreaseStockUpdateGlobally(
        context: context,
        channel: stockUpdateChannel,
        varianceNames: [varianceNames[itemIndex]],
        varianceItemCodes: [order['varianceItemCodes']?[itemIndex]],
        quantities: [restoredQty.toInt()],
      );

      // 12. Update local state
      order['quantities'] = quantitiesList;
      order['cancelledQty'] = cancelledQtyList;
      order['totalAmount'] = newTotal;
      order['partiallycancelled'] = stillPartiallyCancelled;

      // Clear item remark if exists
      if (order['itemRemark'] != null &&
          itemIndex < order['itemRemark'].length) {
        order['itemRemark'][itemIndex] = '';
      }

      // 13. Build filtered order for printing
      final filteredOrder = {
        ...order,
        'quantities': [quantitiesList[itemIndex]],
        'cancelledQty': [cancelledQtyList[itemIndex]],
        'amounts': [
          amountsList.length > itemIndex ? amountsList[itemIndex] : 0.0,
        ],
        'prices': [pricesList[itemIndex]],
        'weights': [order['weights']?[itemIndex] ?? 0.0],
        'varianceNames': [varianceNames[itemIndex]],
        'config': [order['config']?[itemIndex] ?? ''],
      };

      // 14. Print reversal receipt
      print(
        "🖨️ Printing reversal receipt for item: ${varianceNames[itemIndex]}",
      );
      try {
        await CancelPrinterService.printUniversalReceipt(
          ipAddress: printerIp,
          tableNumber: order['table'] ?? '',
          seat: order['seat'] ?? '',
          userName: order['userName'] ?? '',
          waiter: order['waiter'] ?? '',
          seatOrders: [filteredOrder],
          receiptType: 'ITEM REVERTED',
        );
        print("✅ Reversal receipt printed successfully");
      } catch (printError) {
        print("❌ Printer error: $printError");
      }

      // 15. Close temp channel if used
      if (mainChannelFailed && tempChannel != null) {
        await Future.delayed(Duration(milliseconds: 500));
        tempChannel.sink.close();
      }

      // 16. Show success message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomFlushbar(
          context,
          "Item reverted successfully!",
          type: FlushbarType.success,
        );
      });

      // 17. Force UI refresh
      orderProvider.notifyListeners();
    } catch (e, stack) {
      print("💥 Error in _reverseSingleItem: $e");
      print("📌 Stacktrace: $stack");

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomFlushbar(
          context,
          "Error reverting item: ${e.toString()}",
          type: FlushbarType.error,
        );
      });
    } finally {
      // Ensure temp channel is closed
      if (tempChannel != null) {
        try {
          tempChannel.sink.close();
        } catch (e) {
          print("⚠️ Error closing temp channel: $e");
        }
      }
    }
  }

  static Future<void> _cancelSingleItem({
    required BuildContext context,
    required Map<String, dynamic> order,
    required int itemIndex,
    required OrderProvider orderProvider,
    required PrinterProviderDine printerProvider,
  }) async {
    WebSocketChannel? tempChannel;

    try {
      final TextEditingController itemremarkController =
          TextEditingController();

      // 1. Validate indices first
      if (itemIndex < 0 ||
          itemIndex >= (order['quantities']?.length ?? 0) ||
          itemIndex >= (order['varianceNames']?.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCustomFlushbar(
            context,
            "Invalid item index",
            type: FlushbarType.error,
          );
        });
        return;
      }

      // 2. Get current values with safe access
      final List<dynamic> quantities = order['quantities'] ?? [];
      final List<dynamic> varianceNames = order['varianceNames'] ?? [];

      if (itemIndex >= quantities.length || itemIndex >= varianceNames.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCustomFlushbar(
            context,
            "Item data incomplete",
            type: FlushbarType.error,
          );
        });
        return;
      }

      // 3. Safe type conversion
      final double currentQuantity = (quantities[itemIndex] is num)
          ? (quantities[itemIndex] as num).toDouble()
          : 0.0;

      if (currentQuantity <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCustomFlushbar(
            context,
            "Item already cancelled or invalid quantity",
            type: FlushbarType.warning,
          );
        });
        return;
      }
      // 4. Ask for confirmation
      final bool confirm =
          await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Cancel Item'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text(
                    //   'Cancel "${varianceNames[itemIndex]}" (Qty: $currentQuantity)?',
                    // ),
                    const SizedBox(height: 8),
                    RemarkTextField(controller: itemremarkController),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      if (itemremarkController.text.isEmpty) {
                        showCustomFlushbar(
                          context,
                          'Please enter a remark before confirming',
                          type: FlushbarType.warning,
                        );
                        return;
                      }
                      if (itemremarkController.text.length > kMaxRemarkLength) {
                        showCustomFlushbar(
                          context,
                          'Remark cannot exceed $kMaxRemarkLength characters',
                          type: FlushbarType.warning,
                        );
                        return;
                      }
                      Navigator.of(context).pop(true);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA5D6A7),
                    ),
                    child: const Text(
                      'Yes',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
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

      if (!confirm) return;

      final List<double> quantitiesList = quantities
          .map((e) => (e is num) ? e.toDouble() : 0.0)
          .toList();

      final List<double> amountsList = ((order['amounts'] as List?) ?? [])
          .map((e) => (e is num) ? e.toDouble() : 0.0)
          .toList();

      final List<double> cancelledQtyList =
          ((order['cancelledQty'] as List?) ?? [])
              .map((e) => (e is num) ? e.toDouble() : 0.0)
              .toList();

      // Ensure lists are long enough
      while (cancelledQtyList.length <= itemIndex) {
        cancelledQtyList.add(0.0);
      }

      // 6. Update quantities and amounts
      final double itemAmount = amountsList.length > itemIndex
          ? amountsList[itemIndex]
          : 0.0;
      final double currentTotal = (order['totalAmount'] is num)
          ? (order['totalAmount'] as num).toDouble()
          : 0.0;

      quantitiesList[itemIndex] = 0.0;
      cancelledQtyList[itemIndex] = currentQuantity;
      final double newTotal = currentTotal - itemAmount;

      // 7. Get printer IP with fallback
      final String itemName =
          varianceNames[itemIndex]?.toString().trim().toLowerCase() ?? '';
      String? printerIp = order['printerIpMap']?[itemName];

      if (printerIp == null) {
        printerIp = printerProvider.getPrinterIpForItem(itemName);
      }

      if (printerIp == null || printerIp.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCustomFlushbar(
            context,
            'Printer not configured for item: ${varianceNames[itemIndex]}',
            type: FlushbarType.error,
          );
        });
        return;
      }

      // 8. Send update to server with safe channel check
      final Map<String, dynamic> dataToSend = {
        'action': 'cancelOrderItem',
        'hiveOrderId': order['hiveOrderId'],
        'cancelledQty': cancelledQtyList,
        'totalAmount': newTotal,
        'quantities': quantitiesList,
        'itemRemark': itemremarkController.text,
        'partiallycancelled': true,
        'itemIndex': itemIndex,
      };

      // Try using the main channel first
      bool mainChannelFailed = false;
      try {
        orderProvider.channel.sink.add(jsonEncode(dataToSend));
        print("✅ Used main channel for cancellation");
      } catch (e) {
        print("⚠️ Main channel failed: $e");
        mainChannelFailed = true;
      }

      // If main channel failed, use fresh channel
      if (mainChannelFailed) {
        try {
          tempChannel = IOWebSocketChannel.connect('ws://$serverip:$port');
          tempChannel.sink.add(jsonEncode(dataToSend));
          print("🔄 Used fresh channel for cancellation");
        } catch (e) {
          print("❌ Fresh channel also failed: $e");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCustomFlushbar(
              context,
              "Network error. Please check connection and try again.",
              type: FlushbarType.error,
            );
          });
          return;
        }
      }

      // 9. Send stock update with appropriate channel
      final stockUpdateChannel = mainChannelFailed
          ? tempChannel!
          : orderProvider.channel;

      sendAddStockUpdateGlobally(
        context: context,
        channel: stockUpdateChannel,
        varianceNames: [varianceNames[itemIndex]],
        varianceItemCodes: [order['varianceItemCodes']?[itemIndex]],
        quantities: [currentQuantity.toInt()],
      );

      // 10. Update local state immediately
      order['quantities'] = quantitiesList;
      order['cancelledQty'] = cancelledQtyList;
      order['totalAmount'] = newTotal;
      order['partiallycancelled'] = true;

      // if (order['itemRemarks'] == null) {
      //   order['itemRemarks'] = List.filled(quantitiesList.length, '');
      // }
      // // Ensure the list is long enough
      // while (order['itemRemarks'].length <= itemIndex) {
      //   order['itemRemarks'].add('');
      // }
      // order['itemRemarks'][itemIndex] = itemremarkController.text;

      if (order['itemRemark'] == null) {
        order['itemRemark'] = List.filled(quantitiesList.length, '');
      }

      while (order['itemRemark'].length <= itemIndex) {
        order['itemRemark'].add('');
      }

      order['itemRemark'][itemIndex] = itemremarkController.text;

      // 11. Build filtered order for printing
      final filteredOrder = {
        ...order,
        'quantities': [quantitiesList[itemIndex]],
        'cancelledQty': [cancelledQtyList[itemIndex]],
        'amounts': [
          amountsList.length > itemIndex ? amountsList[itemIndex] : 0.0,
        ],
        'prices': [order['prices']?[itemIndex] ?? 0.0],
        'weights': [order['weights']?[itemIndex] ?? 0.0],
        'varianceNames': [varianceNames[itemIndex]],
        'config': [order['config']?[itemIndex] ?? ''],
        'itemRemark': [itemremarkController.text], // Make sure this is included
      };

      print("filteredOrder itemremark is ${filteredOrder['itemRemark']}");
      // 12. Print cancellation receipt
      print(
        "🖨️ Printing cancellation receipt for item: ${varianceNames[itemIndex]}",
      );
      try {
        await CancelPrinterService.printUniversalReceipt(
          ipAddress: printerIp,
          tableNumber: order['table'] ?? '',
          seat: order['seat'] ?? '',
          userName: order['userName'] ?? '',
          waiter: order['waiter'] ?? '',
          seatOrders: [filteredOrder],
          receiptType: 'ITEM CANCELLED',
        );
        print("✅ Cancellation receipt printed successfully");
      } catch (printError) {
        print("❌ Printer error: $printError");
        // Don't return here - still update UI even if printing fails
      }

      // 13. Close temp channel if we used one
      if (mainChannelFailed && tempChannel != null) {
        await Future.delayed(Duration(milliseconds: 500));
        tempChannel.sink.close();
      }

      // 14. Show success message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomFlushbar(
          context,
          "Item cancelled successfully!",
          type: FlushbarType.success,
        );
      });

      // 15. Force UI refresh
      orderProvider.notifyListeners();
    } catch (e, stack) {
      print("💥 Error in _cancelSingleItem: $e");
      print("📌 Stacktrace: $stack");

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomFlushbar(
          context,
          "Error cancelling item: ${e.toString()}",
          type: FlushbarType.error,
        );
      });
    } finally {
      // Ensure temp channel is closed
      if (tempChannel != null) {
        try {
          tempChannel.sink.close();
        } catch (e) {
          print("⚠️ Error closing temp channel: $e");
        }
      }
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
      final bool isActiveOrder = ordersForSeat.any(
        (order) => order['status'] == 'active',
      );

      showDialog(
        context: context,
        builder: (BuildContext confirmationContext) {
          // final screenWidth = MediaQuery.of(context).size.width;
          final screenWidth = MediaQuery.of(confirmationContext).size.width;

          return Dialog(
            backgroundColor: Colors.white, // Full white background
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width:
                  screenWidth * 0.7, // 80% of screen width (adjust as needed)
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Section
                  Text(
                    "$tableNumber - Seat $seat",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black, // Full black text
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Total: ₹${totalPrice.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Full black text
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Content (Orders list or message)
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      child: ordersForSeat.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  "No active orders for this seat.",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: ordersForSeat.map((order) {
                                try {
                                  final tokenNo =
                                      order['tokenNo']?.toString() ?? 'N/A';
                                  final items = order['varianceNames'] ?? [];
                                  final prices = order['prices'] ?? [];
                                  final weights = order['weights'] ?? [];
                                  final quantities = order['quantities'] ?? [];
                                  final amounts = order['amounts'] ?? [];
                                  final config = order['config'] ?? [];
                                  final status = order['status'] ?? '';

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 16.0,
                                    ),
                                    child: buildOrderDetails(
                                      items: items,
                                      prices: prices,
                                      weights: weights,
                                      quantities: quantities,
                                      amounts: amounts,
                                      config: config,
                                      tokenNo: tokenNo,
                                      context: confirmationContext,
                                      orderProvider: orderProvider,
                                      printerProvider: printerProvider,
                                      order: order,
                                      status: status,
                                    ),
                                  );
                                } catch (err) {
                                  print(
                                    "❌ Error while building order details: $err",
                                  );
                                  return const SizedBox.shrink();
                                }
                              }).toList(),
                            ),
                    ),
                  ),

                  // Actions Buttons
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.grey,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () => Navigator.pop(confirmationContext),
                        child: const Text(
                          "Close",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      AbsorbPointer(
                        absorbing: !isActiveOrder,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: isActiveOrder
                                ? Colors.red
                                : Colors.grey[400]!,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () async {
                            await _cancelOrder(
                              context: confirmationContext,
                              rootContext: rootContext,
                              orderProvider: orderProvider,
                              printerProvider: printerProvider,
                              tableNumber: tableNumber,
                              seat: seat,
                              ordersForSeat: ordersForSeat,
                            );
                          },
                          child: const Text(
                            "Cancel Order",
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: isActiveOrder
                              ? Colors.green
                              : Colors.grey[400]!,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onPressed: isActiveOrder
                            ? () async {
                                Navigator.of(confirmationContext).pop();
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
                        child: const Text(
                          "Generate Pre-Invoice",
                          style: TextStyle(fontSize: 12, color: Colors.black),
                          textAlign: TextAlign.center,
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
      print("❌ Unexpected error in showSeatOrderDetails: $err");
    }
  }

  // Separate method for pre-invoice generation to handle async operations cleanly
  // static Future<void> _generatePreInvoice({
  //   required BuildContext rootContext,
  //   required OrderProvider orderProvider,
  //   required SubmissionProviderDine submissionProvider,
  //   required String tableNumber,
  //   required String seat,
  //   required List<dynamic> ordersForSeat,
  //   required String? printerIp,
  // }) async {
  //   submissionProvider.startSubmitting();

  //   try {
  //     print("🟢 Confirming orders for seat $seat");

  //     if (printerIp == null || printerIp.isEmpty) {
  //       print("⚠️ Missing printer IP for seat $seat");
  //       promptForPrinterIp(rootContext);
  //       return;
  //     }

  //     print("🖨️ Using printer IP: $printerIp");

  //     // Update order statuses first
  //     for (var order in ordersForSeat) {
  //       if (order['seathiveOrderId'] != null) {
  //         print("🔄 Updating order ${order['seathiveOrderId']} status to confirm");
  //         await orderProvider.patchOrderStatusBySeathiveOrderId(
  //           order['seathiveOrderId'],
  //           "confirm",
  //         );
  //       }
  //     }

  //     print("🖨️ Printing receipt for seat $seat");

  //     // Use a fresh WebSocket channel for each request to avoid subscription conflicts
  //     final freshChannel = IOWebSocketChannel.connect('ws://$serverip:$port');

  //     await requestAndPrintPreInvoice(
  //       areaName: ordersForSeat.first['areaName'],
  //       channel: freshChannel,
  //       ipAddress: printerIp,
  //       seat: seat,
  //       seatOrders: ordersForSeat as List<Map<String, dynamic>>,
  //       seathiveOrderId: ordersForSeat.isNotEmpty
  //           ? ordersForSeat.first['seathiveOrderId']
  //           : '',
  //       tableNumber: tableNumber,
  //       userName: userName,
  //       waiter: createdBy,
  //     );

  //     // Close the fresh channel
  //     freshChannel.sink.close();

  //     print("✅ Receipt printed successfully for seat $seat");

  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       showCustomFlushbar(
  //         rootContext,
  //         "Invoice generated successfully!",
  //         type: FlushbarType.success,
  //       );
  //     });

  //     // Notify listeners after successful operation
  //     orderProvider.notifyListeners();

  //   } catch (printErr) {
  //     debugPrint("❌ Printing error: $printErr");
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       showCustomFlushbar(
  //         rootContext,
  //         "Printing error: $printErr",
  //         type: FlushbarType.error,
  //       );
  //     });
  //   } finally {
  //     submissionProvider.stopSubmitting();
  //     print("🟡 Submission process finished for seat $seat");
  //   }
  // }

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
        print("⚠️ Missing printer IP for seat $seat");
        promptForPrinterIp(rootContext);
        return;
      }

      print("🖨️ Using printer IP: $printerIp");

      // Update order statuses first
      for (var order in ordersForSeat) {
        if (order['seathiveOrderId'] != null) {
          print(
            "🔄 Updating order ${order['seathiveOrderId']} status to confirm",
          );
          await orderProvider.patchOrderStatusBySeathiveOrderId(
            order['seathiveOrderId'],
            "confirm",
            tableNumber,
            seat,
          );
        }
      }

      print("🖨️ Printing receipt for seat $seat");

      // Use a fresh WebSocket channel for each request to avoid subscription conflicts
      final freshChannel = IOWebSocketChannel.connect('ws://$serverip:$port');

      await requestAndPrintPreInvoice(
        areaName: ordersForSeat.first['areaName'],
        channel: freshChannel,
        ipAddress: printerIp,
        seat: seat,
        seatOrders: ordersForSeat as List<Map<String, dynamic>>,
        seathiveOrderId: ordersForSeat.isNotEmpty
            ? ordersForSeat.first['seathiveOrderId']
            : '',
        tableNumber: tableNumber,
        userName: userName,
        waiter: createdBy,
      );

      final timerProvider = Provider.of<TimerProvider>(
        rootContext,
        listen: false,
      );
      timerProvider.startTimer(tableNumber, seat);

      // Close the fresh channel
      freshChannel.sink.close();

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

  // Add this new method for cancel order functionality
  static Future<void> _cancelOrder({
    required BuildContext context,
    required BuildContext rootContext,
    required OrderProvider orderProvider,
    required PrinterProviderDine printerProvider,
    required String tableNumber,
    required String seat,
    required List<dynamic> ordersForSeat,
  }) async {
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    try {
      // Create a TextEditingController for the remark
      final TextEditingController remarkController = TextEditingController();

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
                    const SizedBox(height: 16),
                    RemarkTextField(controller: remarkController),
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
                      // Validate remark
                      if (remarkController.text.isEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          showCustomFlushbar(
                            dialogContext,
                            'Please enter a remark before confirming',
                            type: FlushbarType.warning,
                          );
                        });
                        return;
                      }

                      if (remarkController.text.length > kMaxRemarkLength) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          showCustomFlushbar(
                            dialogContext,
                            'Remark cannot exceed $kMaxRemarkLength characters',
                            type: FlushbarType.warning,
                          );
                        });
                        return;
                      }

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

      // if (confirm) {
      //   // Get printer IP for cancellation receipt
      //   var printerIp = printerProvider.getPrinterIpForItem(
      //     ordersForSeat.isNotEmpty &&
      //             ordersForSeat.first['varianceNames'].isNotEmpty
      //         ? ordersForSeat.first['varianceNames'].first.toString()
      //         : '',
      //   );

      //   if (printerIp == null) {
      //     await promptForPrinterIp(rootContext);
      //     printerIp = printerProvider.getPrinterIpForItem(
      //       ordersForSeat.isNotEmpty &&
      //               ordersForSeat.first['varianceNames'].isNotEmpty
      //           ? ordersForSeat.first['varianceNames'].first.toString()
      //           : '',
      //     );
      //     if (printerIp == null) {
      //       showCustomFlushbar(
      //         rootContext,
      //         "Printer IP not set. Cannot cancel order.",
      //         type: FlushbarType.error,
      //       );
      //       return;
      //     }
      //   }

      //   // Cancel each order for this seat
      //   for (var order in ordersForSeat) {
      //     final String seathiveOrderId = order['seathiveOrderId'];
      //     if (seathiveOrderId != null && seathiveOrderId.isNotEmpty) {
      //       await OrderPatchService.patchOrderCancellation(
      //         seathiveOrderId: seathiveOrderId,
      //         remark: remarkController.text,
      //         channel: orderProvider.channel,
      //         inMemoryOrders: orderProvider.orders,
      //       );
      //     }
      //   }

      //   // Print cancellation receipt
      //   await CancelPrinterService.printUniversalReceipt(
      //     ipAddress: printerIp.toString(),
      //     tableNumber: ordersForSeat.isNotEmpty
      //         ? ordersForSeat.first['table'] ?? ''
      //         : '',
      //     seat: ordersForSeat.isNotEmpty
      //         ? ordersForSeat.first['seat'] ?? ''
      //         : '',
      //     userName: ordersForSeat.isNotEmpty
      //         ? ordersForSeat.first['captain'] ?? ""
      //         : "",
      //     waiter: ordersForSeat.isNotEmpty
      //         ? ordersForSeat.first['waiter'] ?? ""
      //         : "",
      //     seatOrders: ordersForSeat.cast<Map<String, dynamic>>(),
      //     receiptType: "Full Order Cancelled",
      //   );

      //   // Send stock updates for all cancelled items
      //   final Map<String, List<Map<String, dynamic>>> groupedOrders = {};

      //   // Group orders by seathiveOrderId
      //   for (var order in ordersForSeat) {
      //     final id = order['seathiveOrderId'];
      //     groupedOrders.putIfAbsent(id, () => []).add(order);
      //   }

      //   // For each seathiveOrderId, accumulate all varianceNames and quantities and send stock update
      //   groupedOrders.forEach((seathiveOrderId, orders) {
      //     final List<String> combinedVarianceNames = [];
      //     final List<String> combinedVarianceItemCodes = [];
      //     final List<int> combinedQuantities = [];

      //     for (var order in orders) {
      //       final names = List<String>.from(order['varianceNames'] ?? []);
      //       final itemCodes = List<String>.from(
      //         order['varianceItemCodes'] ?? [],
      //       );
      //       final qtys = (order['quantities'] as List)
      //           .map((e) => (e is int) ? e : (e as double).toInt())
      //           .toList();

      //       combinedVarianceNames.addAll(names);
      //       combinedVarianceItemCodes.addAll(itemCodes);
      //       combinedQuantities.addAll(qtys);
      //     }

      //     // Send combined stock update
      //     sendAddStockUpdateGlobally(
      //       context: rootContext,
      //       channel: orderProvider.channel,
      //       varianceNames: combinedVarianceNames,
      //       varianceItemCodes: combinedVarianceItemCodes,
      //       quantities: combinedQuantities,
      //     );
      //   });

      //   // Close the dialog
      //   if (Navigator.of(context).canPop()) {
      //     Navigator.of(context).pop();
      //   }

      //   // Show success message
      //   WidgetsBinding.instance.addPostFrameCallback((_) {
      //     showCustomFlushbar(
      //       rootContext,
      //       "Order cancelled successfully!",
      //       type: FlushbarType.success,
      //     );
      //   });

      //   // Notify listeners to update UI

      //   timerProvider.stopTimer(tableNumber, seat);
      //   orderProvider.notifyListeners();
      // }

      if (confirm) {
        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );
        // Loop through orders for this seat (or however your logic identifies orders)
        for (var order in ordersForSeat) {
          final String seathiveOrderId = order['seathiveOrderId'];
          timerProvider.stopTimer(tableNumber, seat);

          await OrderPatchService.patchOrderCancellation(
            seathiveOrderId: seathiveOrderId,
            remark: remarkController.text,
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
                order['varianceItemCodes'] ?? [],
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
  //   required List quantities,
  //   required List amounts,
  //   required List config,
  //   required String tokenNo,
  //   required BuildContext context, // Add context parameter
  //   required OrderProvider orderProvider, // Add orderProvider parameter
  //   required PrinterProviderDine
  //   printerProvider, // Add printerProvider parameter
  //   required Map<String, dynamic> order, // Add the full order object
  //   required String status,
  // }) {
  //   try {
  //     print("order of config is ${order['config']}");
  //     return Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Container(
  //           padding: const EdgeInsets.all(8),
  //           decoration: BoxDecoration(
  //             color: Colors.grey[200],
  //             borderRadius: BorderRadius.circular(6),
  //           ),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Text(
  //                 "Order",
  //                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  //               ),
  //               Text(
  //                 "Token: $tokenNo ",
  //                 style: const TextStyle(fontWeight: FontWeight.bold),
  //               ),
  //             ],
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //         Column(
  //           children: List.generate(items.length, (i) {
  //             try {
  //               String itemName = items[i];
  //               double price = prices.length > i ? prices[i].toDouble() : 0.0;
  //               double weight = weights.length > i
  //                   ? weights[i].toDouble()
  //                   : 0.0;
  //               double quantity = quantities.length > i
  //                   ? quantities[i].toDouble()
  //                   : 0.0;
  //               double amount = amounts.length > i
  //                   ? amounts[i].toDouble()
  //                   : 0.0;

  //               return Padding(
  //                 padding: const EdgeInsets.symmetric(vertical: 6.0),
  //                 child: Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     Expanded(
  //                       flex: 3,
  //                       child: Column(
  //                         crossAxisAlignment: CrossAxisAlignment.start,
  //                         children: [
  //                           Text(capitalizeWords(itemName)),
  //                           Text(
  //                             "₹${price.toStringAsFixed(0)} / ${weight > 0 ? "$weight kg" : "No Weight"}",
  //                             style: const TextStyle(
  //                               fontSize: 12,
  //                               color: Colors.grey,
  //                             ),
  //                           ),
  //                           if (order['cancelledQty'] != null &&
  //                               order['cancelledQty'].length > i &&
  //                               order['cancelledQty'][i] > 0)
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
  //                     Expanded(
  //                       flex: 1,
  //                       child: Text(
  //                         quantity.toStringAsFixed(0),
  //                         textAlign: TextAlign.center,
  //                         style: quantity == 0
  //                             ? const TextStyle(
  //                                 decoration: TextDecoration.lineThrough,
  //                                 color: Colors.red,
  //                               )
  //                             : null,
  //                       ),
  //                     ),
  //                     Expanded(
  //                       flex: 1,
  //                       child: Text(
  //                         "₹${amount.toStringAsFixed(0)}",
  //                         textAlign: TextAlign.right,
  //                         style: quantity == 0
  //                             ? const TextStyle(
  //                                 decoration: TextDecoration.lineThrough,
  //                                 color: Colors.red,
  //                               )
  //                             : null,
  //                       ),
  //                     ),
  //                     if (status == "active") ...[
  //                       Expanded(
  //                         flex: 1,
  //                         child: IconButton(
  //                           icon: Icon(
  //                             Icons.cancel,
  //                             color: status == "active"
  //                                 ? Colors.red
  //                                 : Colors.grey,
  //                             size: 20,
  //                           ),
  //                           onPressed: status == "active"
  //                               ? () async {
  //                                   await _cancelSingleItem(
  //                                     context: context,
  //                                     order: order,
  //                                     itemIndex: i,
  //                                     orderProvider: orderProvider,
  //                                     printerProvider: printerProvider,
  //                                   );
  //                                 }
  //                               : null,
  //                         ),
  //                       ),
  //                     ],
  //                   ],
  //                 ),
  //               );
  //             } catch (rowErr) {
  //               print("❌ Error building row $i: $rowErr");
  //               return const SizedBox.shrink();
  //             }
  //           }),
  //         ),
  //       ],
  //     );
  //   } catch (err) {
  //     print("❌ Error in buildOrderDetails: $err");
  //     return const SizedBox.shrink();
  //   }
  // }

  static Widget buildOrderDetails({
    required List items,
    required List prices,
    required List weights,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "Token: $tokenNo ",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: List.generate(items.length, (i) {
              try {
                String itemName = items[i];
                double price = prices.length > i ? prices[i].toDouble() : 0.0;
                double weight = weights.length > i
                    ? weights[i].toDouble()
                    : 0.0;
                double quantity = quantities.length > i
                    ? quantities[i].toDouble()
                    : 0.0;
                double amount = amounts.length > i
                    ? amounts[i].toDouble()
                    : 0.0;

                // Check if item is cancelled (quantity = 0, cancelledQty > 0)
                bool isCancelled =
                    quantity == 0.0 &&
                    order['cancelledQty'] != null &&
                    order['cancelledQty'].length > i &&
                    order['cancelledQty'][i] > 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              capitalizeWords(itemName),
                              style: isCancelled
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.red,
                                    )
                                  : null,
                            ),
                            Text(
                              "₹${price.toStringAsFixed(0)} / ${weight > 0 ? "$weight kg" : "No Weight"}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            if (isCancelled)
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
                        flex: 1,
                        child: Text(
                          quantity.toStringAsFixed(0),
                          textAlign: TextAlign.center,
                          style: isCancelled
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.red,
                                )
                              : null,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "₹${amount.toStringAsFixed(0)}",
                          textAlign: TextAlign.right,
                          style: isCancelled
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.red,
                                )
                              : null,
                        ),
                      ),
                      if (status == "active") ...[
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: Icon(
                              isCancelled ? Icons.undo : Icons.cancel,
                              color: isCancelled ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            onPressed: status == "active"
                                ? () async {
                                    if (isCancelled) {
                                      // REVERSE CANCELLATION
                                      await _reverseSingleItem(
                                        context: context,
                                        order: order,
                                        itemIndex: i,
                                        orderProvider: orderProvider,
                                        printerProvider: printerProvider,
                                      );
                                    } else {
                                      // NORMAL CANCELLATION (existing code)
                                      await _cancelSingleItem(
                                        context: context,
                                        order: order,
                                        itemIndex: i,
                                        orderProvider: orderProvider,
                                        printerProvider: printerProvider,
                                      );
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              } catch (rowErr) {
                print("❌ Error building row $i: $rowErr");
                return const SizedBox.shrink();
              }
            }),
          ),
        ],
      );
    } catch (err) {
      print("❌ Error in buildOrderDetails: $err");
      return const SizedBox.shrink();
    }
  }
}

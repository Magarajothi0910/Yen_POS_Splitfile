import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/kotpreinvoice/Helper/RemarkTextfield.dart';
import 'package:yenpos/kotpreinvoice/Helper/addStock_utils.dart';
import 'package:yenpos/kotpreinvoice/Helper/decreaseStock_utils.dart';
import 'package:yenpos/kotpreinvoice/providers/timerProvider.dart';
import 'package:yenpos/kotpreinvoice/services/CancellationReceipt.dart';
import 'package:yenpos/kotpreinvoice/services/hive_service.dart';
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

  // static Future<void> _reverseSingleItem({
  //   required BuildContext context,
  //   required Map<String, dynamic> order,
  //   required int itemIndex,
  //   required OrderProvider orderProvider,
  //   required PrinterProviderDine printerProvider,
  // }) async {
  //   WebSocketChannel? tempChannel;

  //   try {
  //     print("🔄 Starting reverse cancellation for index: $itemIndex");

  //     // === 1. Validation (keep your safe checks) ===
  //     final List<dynamic> quantitiesDyn = order['quantities'] ?? [];
  //     final List<dynamic> varianceNames = order['varianceNames'] ?? [];
  //     final List<dynamic> cancelledQtyDyn = order['cancelledQty'] ?? [];
  //     final List<dynamic> pricesDyn = order['prices'] ?? [];

  //     if (itemIndex < 0 ||
  //         itemIndex >= quantitiesDyn.length ||
  //         itemIndex >= varianceNames.length ||
  //         itemIndex >= cancelledQtyDyn.length) {
  //       // _showError(context, "Invalid item index or incomplete data");
  //       return;
  //     }

  //     // Convert to double lists safely
  //     final List<double> quantitiesList = quantitiesDyn
  //         .map((e) => (e is num) ? e.toDouble() : 0.0)
  //         .toList();
  //     final List<double> cancelledQtyList = cancelledQtyDyn
  //         .map((e) => (e is num) ? e.toDouble() : 0.0)
  //         .toList();
  //     final List<double> pricesList = pricesDyn
  //         .map((e) => (e is num) ? e.toDouble() : 0.0)
  //         .toList();

  //     final double currentCancelledQty = cancelledQtyList[itemIndex];

  //     if (currentCancelledQty <= 0) {
  //       // _showWarning(context, "Item is not cancelled. Nothing to revert.");
  //       return;
  //     }

  //     // === 2. Confirmation Dialog (keep yours) ===
  //     final bool confirm =
  //         await showDialog<bool>(
  //           context: context,
  //           builder: (_) => AlertDialog(
  //             backgroundColor: Colors.white,
  //             title: const Text('Revert Cancelled Item'),
  //             content: Text(
  //               'Are you sure you want to revert "${varianceNames[itemIndex]}" (Qty: $currentCancelledQty)?',
  //             ),
  //             actions: [
  //               ElevatedButton(
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: Colors.redAccent,
  //                 ),
  //                 onPressed: () => Navigator.pop(context, false),
  //                 child: const Text(
  //                   'No',
  //                   style: TextStyle(color: Colors.white),
  //                 ),
  //               ),
  //               ElevatedButton(
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: const Color(0xFFA5D6A7),
  //                 ),
  //                 onPressed: () => {
  //                   Navigator.pop(context, true),
  //                   Navigator.of(context).pop(),
  //                 },
  //                 child: const Text(
  //                   'Yes',
  //                   style: TextStyle(color: Colors.black),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ) ??
  //         false;

  //     if (!confirm) return;

  //     // === 3. Restore quantity (same as old) ===
  //     final double restoredQty = currentCancelledQty;
  //     cancelledQtyList[itemIndex] = 0.0;
  //     quantitiesList[itemIndex] = restoredQty;

  //     // === 4. RECALCULATE TOTAL PROPERLY (CRITICAL FIX) ===
  //     double newTotal = 0.0;
  //     for (int i = 0; i < quantitiesList.length; i++) {
  //       newTotal += quantitiesList[i] * pricesList[i];
  //     }

  //     final bool stillPartiallyCancelled = cancelledQtyList.any((q) => q > 0.0);

  //     // === 5. Update order map ===
  //     order['quantities'] = quantitiesList;
  //     order['cancelledQty'] = cancelledQtyList;
  //     order['totalAmount'] = newTotal;
  //     order['partiallycancelled'] = stillPartiallyCancelled;

  //     // Clear remark for this item
  //     if (order['itemRemark'] is List<dynamic>) {
  //       final remarks = order['itemRemark'] as List<dynamic>;
  //       while (remarks.length <= itemIndex) remarks.add('');
  //       remarks[itemIndex] = '';
  //     }

  //     // === 6. Send to server – USE MINIMAL DATA LIKE OLD CODE ===
  //     // final Map<String, dynamic> dataToSend = {
  //     //   'action': 'reverseCancelOrderItem',
  //     //   'hiveOrderId': order['hiveOrderId'],
  //     //   'updatedIndex': itemIndex,
  //     //   'updatedQuantity': quantitiesList[itemIndex],
  //     //   'updatedCancelledQty': cancelledQtyList[itemIndex],
  //     //   'totalAmount': newTotal,
  //     //   'partiallycancelled': stillPartiallyCancelled,
  //     // };

  //     // final revertVarianceNames = order['varianceNames'];
  //     // final revertVarianceItemCodes = order['varianceitemCodes'];
  //     // final revertUoms = order['uoms'];
  //     // final revertWeights = order['weights'];

  //     final List<String> variancesNames = List<String>.from(
  //       order['varianceNames'] ?? [],
  //     );

  //     final List<String> varianceItemCodes = List<String>.from(
  //       order['varianceitemCodes'] ?? [],
  //     );

  //     final List<String> uoms = List<String>.from(order['uoms'] ?? []);

  //     final List<double> weights = List<double>.from(order['weights'] ?? []);

  //     // === 6. Send to server – USE MINIMAL DATA LIKE OLD CODE ===
  //     // final Map<String, dynamic> dataToSend = {
  //     //   'action': 'reverseCancelOrderItem',
  //     //   'hiveOrderId': order['hiveOrderId'],
  //     //   'varianceNames': order['varianceNames']?[itemIndex],
  //     //   'varianceitemCodes': order['varianceitemCodes']?[itemIndex],
  //     //   'uoms': order['uoms']?[itemIndex],
  //     //   'weights': order['weights']?[itemIndex],
  //     //   'updatedIndex': itemIndex,
  //     //   'updatedQuantity': quantitiesList[itemIndex],
  //     //   'updatedCancelledQty': cancelledQtyList[itemIndex],
  //     //   'totalAmount': newTotal,
  //     //   'partiallycancelled': stillPartiallyCancelled,
  //     // };
  //     final Map<String, dynamic> dataToSend = {
  //       'action': 'reverseCancelOrderItem',
  //       'hiveOrderId': order['hiveOrderId'],

  //       // ✅ single item only
  //       'varianceName': variancesNames[itemIndex],
  //       'varianceItemCode': varianceItemCodes[itemIndex],
  //       'uom': uoms[itemIndex],
  //       'weight': weights[itemIndex],

  //       'updatedIndex': itemIndex,
  //       'updatedQuantity': quantitiesList[itemIndex],
  //       'updatedCancelledQty': cancelledQtyList[itemIndex],
  //       'totalAmount': newTotal,
  //       'partiallycancelled': stillPartiallyCancelled,
  //     };

  //     debugPrint('_reverseSingleItem dataToSend :  $dataToSend  , $itemIndex');
  //     // debugPrint('_reverseSingleItem dataToSend :  $order');

  //     // Try main channel first, fallback to fresh
  //     bool sent = false;
  //     try {
  //       sendataToServer(dataToSend); // or however your main send works
  //       print("✅ Sent via main channel");
  //       sent = true;
  //     } catch (e) {
  //       print("⚠️ Main channel failed: $e");
  //     }

  //     if (!sent) {
  //       try {
  //         tempChannel = IOWebSocketChannel.connect('ws://$serverip:$port');
  //         tempChannel.sink.add(jsonEncode(dataToSend));
  //         print("🔄 Sent via fresh channel");
  //         sent = true;
  //       } catch (e) {
  //         print("❌ Fresh channel failed: $e");
  //         // _showError(context, "Network error. Could not revert item.");
  //         return;
  //       }
  //     }

  //     // === 7. Stock update (keep your logic) ===
  //     final channelForStock = sent && tempChannel != null
  //         ? tempChannel
  //         : orderProvider.channel;
  //     sendDecreaseStockUpdateGlobally(
  //       context: context,
  //       channel: channelForStock,
  //       varianceNames: [varianceNames[itemIndex]],
  //       varianceItemCodes: [order['varianceitemCodes']?[itemIndex]],
  //       quantities: [restoredQty.toInt()],
  //     );

  //     // === 8. Print reversal receipt (keep your logic) ===
  //     String itemName =
  //         (varianceNames[itemIndex]?.toString().trim().toLowerCase()) ?? '';
  //     String? printerIp =
  //         order['printerIpMap']?[itemName] ??
  //         printerProvider.getPrinterIpForItem(itemName);

  //     if (printerIp != null && printerIp.isNotEmpty) {
  //       final filteredOrder = {
  //         ...order,
  //         'quantities': [quantitiesList[itemIndex]],
  //         'cancelledQty': [0.0],
  //         'amounts': [restoredQty * pricesList[itemIndex]],
  //         'prices': [pricesList[itemIndex]],
  //         'varianceNames': [varianceNames[itemIndex]],
  //         // add other needed fields...
  //       };

  //       try {
  //         await CancelPrinterService.printUniversalReceipt(
  //           ipAddress: printerIp,
  //           tableNumber: order['table'] ?? '',
  //           seat: order['seat'] ?? '',
  //           userName: order['userName'] ?? '',
  //           waiter: order['waiter'] ?? '',
  //           seatOrders: [filteredOrder],
  //           receiptType: 'ITEM REVERTED',
  //         );
  //       } catch (e) {
  //         print("❌ Print failed: $e");
  //       }
  //     }

  //     // === 9. Update provider & UI – FORCE REFRESH LIKE OLD CODE ===
  //     orderProvider.updateOrderByHiveOrderId(
  //       order['hiveOrderId'],
  //       order,
  //     ); // if you have this method
  //     // OR if using a ValueNotifier<List<Map>>:
  //     // updateOrderInNotifier(order); // use the same function from old code

  //     // Fallback
  //     orderProvider.notifyListeners();

  //     // _showSuccess(context, "Item reverted successfully!");
  //   } catch (e, stack) {
  //     print("💥 Error in _reverseSingleItem: $e\n$stack");
  //     // _showError(context, "Error reverting item: $e");
  //   } finally {
  //     if (tempChannel != null) {
  //       await Future.delayed(const Duration(milliseconds: 500));
  //       tempChannel.sink.close();
  //     }
  //   }
  // }

  // Helper methods to avoid repetition
  void _showError(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCustomFlushbar(context, message, type: FlushbarType.error);
    });
  }

  void _showWarning(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCustomFlushbar(context, message, type: FlushbarType.warning);
    });
  }

  void _showSuccess(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCustomFlushbar(context, message, type: FlushbarType.success);
    });
  }

  // static Future<void> _reverseSingleItem({
  //   required BuildContext context,
  //   required Map<String, dynamic> order,
  //   required int itemIndex,
  //   required OrderProvider orderProvider,
  //   required PrinterProviderDine printerProvider,
  // }) async {
  //   WebSocketChannel? tempChannel;

  //   try {
  //     print("🔄 Starting reverse cancellation for index: $itemIndex");

  //     /* -------------------- 1. BASIC INDEX VALIDATION -------------------- */
  //     final quantitiesRaw = order['quantities'];
  //     final varianceNamesRaw = order['varianceNames'];
  //     final cancelledQtyRaw = order['cancelledQty'];

  //     if (quantitiesRaw is! List ||
  //         varianceNamesRaw is! List ||
  //         cancelledQtyRaw is! List ||
  //         itemIndex < 0 ||
  //         itemIndex >= quantitiesRaw.length ||
  //         itemIndex >= varianceNamesRaw.length ||
  //         itemIndex >= cancelledQtyRaw.length) {
  //       showCustomFlushbar(
  //         context,
  //         "Invalid item data",
  //         type: FlushbarType.error,
  //       );
  //       return;
  //     }

  //     /* -------------------- 2. NORMALIZE LIST TYPES -------------------- */
  //     final List<double> quantitiesList = quantitiesRaw
  //         .map((e) => (e is num) ? e.toDouble() : 0.0)
  //         .toList();

  //     final List<double> cancelledQtyList = cancelledQtyRaw
  //         .map((e) => (e is num) ? e.toDouble() : 0.0)
  //         .toList();

  //     final List<double> pricesList = (order['prices'] as List? ?? [])
  //         .map((e) => (e is num) ? e.toDouble() : 0.0)
  //         .toList();

  //     final List<double> amountsList = (order['amounts'] as List? ?? [])
  //         .map((e) => (e is num) ? e.toDouble() : 0.0)
  //         .toList();

  //     final List<String> varianceNames = varianceNamesRaw
  //         .map((e) => e?.toString() ?? '')
  //         .toList();

  //     /* -------------------- 3. NORMALIZE itemRemark SAFELY -------------------- */
  //     List<String> itemRemarks;
  //     if (order['itemRemark'] is List) {
  //       itemRemarks = List<String>.from(
  //         order['itemRemark'].map((e) => e?.toString() ?? ''),
  //       );
  //     } else if (order['itemRemark'] is String) {
  //       // legacy data fallback
  //       itemRemarks = List.generate(
  //         quantitiesList.length,
  //         (_) => order['itemRemark'].toString(),
  //       );
  //     } else {
  //       itemRemarks = List.filled(quantitiesList.length, '');
  //     }

  //     /* -------------------- 4. CHECK CANCELLED QTY -------------------- */
  //     final double cancelledQty = cancelledQtyList[itemIndex];
  //     if (cancelledQty <= 0) {
  //       showCustomFlushbar(
  //         context,
  //         "Item is not cancelled",
  //         type: FlushbarType.warning,
  //       );
  //       return;
  //     }

  //     /* -------------------- 5. CONFIRMATION -------------------- */
  //     final confirm =
  //         await showDialog<bool>(
  //           context: context,
  //           builder: (_) => AlertDialog(
  //             title: const Text('Revert Cancelled Item'),
  //             content: Text(
  //               'Revert "${varianceNames[itemIndex]}" (Qty: $cancelledQty)?',
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.pop(context, false),
  //                 child: const Text('No'),
  //               ),
  //               ElevatedButton(
  //                 onPressed: () => Navigator.pop(context, true),
  //                 child: const Text('Yes'),
  //               ),
  //             ],
  //           ),
  //         ) ??
  //         false;

  //     if (!confirm) return;

  //     /* -------------------- 6. REVERSE CANCEL -------------------- */
  //     cancelledQtyList[itemIndex] = 0.0;
  //     quantitiesList[itemIndex] = cancelledQty;

  //     final double itemPrice = itemIndex < pricesList.length
  //         ? pricesList[itemIndex]
  //         : 0.0;

  //     final double restoredAmount = cancelledQty * itemPrice;
  //     final double currentTotal =
  //         (order['totalAmount'] as num?)?.toDouble() ?? 0.0;

  //     final double newTotal = currentTotal + restoredAmount;

  //     final bool stillPartiallyCancelled = cancelledQtyList.any((q) => q > 0);

  //     /* -------------------- 7. CLEAR ITEM REMARK SAFELY -------------------- */
  //     if (itemIndex < itemRemarks.length) {
  //       itemRemarks[itemIndex] = '';
  //     }

  //     /* -------------------- 8. PRINTER IP -------------------- */
  //     final itemKey = varianceNames[itemIndex].trim().toLowerCase();
  //     String? printerIp =
  //         order['printerIpMap']?[itemKey] ??
  //         printerProvider.getPrinterIpForItem(itemKey);

  //     if (printerIp == null || printerIp.isEmpty) {
  //       showCustomFlushbar(
  //         context,
  //         'Printer not configured',
  //         type: FlushbarType.error,
  //       );
  //       return;
  //     }

  //     /* -------------------- 9. SEND TO SERVER -------------------- */
  //     final payload = {
  //       'action': 'reverseCancelOrderItem',
  //       'hiveOrderId': order['hiveOrderId'],
  //       'quantities': quantitiesList,
  //       'cancelledQty': cancelledQtyList,
  //       'totalAmount': newTotal,
  //       'partiallycancelled': stillPartiallyCancelled,
  //       'itemIndex': itemIndex,
  //       'itemRemark': '',
  //     };

  //     try {

  //       debugPrint("payload is $payload");
  //       sendataToServer(payload);

  //     } catch (_) {
  //       tempChannel = IOWebSocketChannel.connect('ws://$serverip:$port');
  //       tempChannel.sink.add(jsonEncode(payload));
  //     }

  //     /* -------------------- 10. STOCK UPDATE -------------------- */
  //     sendDecreaseStockUpdateGlobally(
  //       context: context,
  //       channel: tempChannel ?? orderProvider.channel,
  //       varianceNames: [varianceNames[itemIndex]],
  //       varianceItemCodes: [order['varianceitemCodes']?[itemIndex]],
  //       quantities: [cancelledQty.toInt()],
  //     );

  //     /* -------------------- 11. UPDATE LOCAL ORDER -------------------- */
  //     order['quantities'] = quantitiesList;
  //     order['cancelledQty'] = cancelledQtyList;
  //     order['totalAmount'] = newTotal;
  //     order['partiallycancelled'] = stillPartiallyCancelled;
  //     order['itemRemark'] = itemRemarks;

  //     orderProvider.notifyListeners();

  //     showCustomFlushbar(
  //       context,
  //       "Item reverted successfully",
  //       type: FlushbarType.success,
  //     );
  //   } catch (e, stack) {
  //     print("💥 Error in _reverseSingleItem: $e");
  //     print(stack);
  //     showCustomFlushbar(
  //       context,
  //       "Error reverting item",
  //       type: FlushbarType.error,
  //     );
  //   } finally {
  //     try {
  //       tempChannel?.sink.close();
  //     } catch (_) {}
  //   }
  // }

  // static Future<void> _cancelSingleItem({
  //   required BuildContext context,
  //   required Map<String, dynamic> order,
  //   required int itemIndex,
  //   required OrderProvider orderProvider,
  //   required PrinterProviderDine printerProvider,
  // }) async {
  //   WebSocketChannel? tempChannel;

  //   debugPrint(" _cancelSingleItem : $order");

  //   try {
  //     final TextEditingController itemremarkController =
  //         TextEditingController();

  //     // 1. Validate indices first
  //     if (itemIndex < 0 ||
  //         itemIndex >= (order['quantities']?.length ?? 0) ||
  //         itemIndex >= (order['varianceNames']?.length ?? 0)) {
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         showCustomFlushbar(
  //           context,
  //           "Invalid item index",
  //           type: FlushbarType.error,
  //         );
  //       });
  //       return;
  //     }

  //     // 2. Get current values with safe access
  //     final List<dynamic> quantities = order['quantities'] ?? [];
  //     final List<dynamic> varianceNames = order['varianceNames'] ?? [];

  //     debugPrint("varianceNames :: $varianceNames");

  //     if (itemIndex >= quantities.length || itemIndex >= varianceNames.length) {
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         showCustomFlushbar(
  //           context,
  //           "Item data incomplete",
  //           type: FlushbarType.error,
  //         );
  //       });
  //       return;
  //     }

  //     // 3. Safe type conversion
  //     final double currentQuantity = (quantities[itemIndex] is num)
  //         ? (quantities[itemIndex] as num).toDouble()
  //         : 0.0;

  //     if (currentQuantity <= 0) {
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         showCustomFlushbar(
  //           context,
  //           "Item already cancelled or invalid quantity",
  //           type: FlushbarType.warning,
  //         );
  //       });
  //       return;
  //     }
  //     // 4. Ask for confirmation
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
  //                   // Text(
  //                   //   'Cancel "${varianceNames[itemIndex]}" (Qty: $currentQuantity)?',
  //                   // ),
  //                   const SizedBox(height: 8),
  //                   RemarkTextField(controller: itemremarkController),
  //                 ],
  //               ),
  //               actions: [
  //                 ElevatedButton(
  //                   onPressed: () {
  //                     if (itemremarkController.text.isEmpty) {
  //                       showCustomFlushbar(
  //                         context,
  //                         'Please enter a remark before confirming',
  //                         type: FlushbarType.warning,
  //                       );
  //                       return;
  //                     }
  //                     if (itemremarkController.text.length > kMaxRemarkLength) {
  //                       showCustomFlushbar(
  //                         context,
  //                         'Remark cannot exceed $kMaxRemarkLength characters',
  //                         type: FlushbarType.warning,
  //                       );
  //                       return;
  //                     }
  //                     Navigator.of(context).pop(true);
  //                     Navigator.of(context).pop();
  //                   },
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: const Color(0xFFA5D6A7),
  //                   ),
  //                   child: const Text(
  //                     'Yes',
  //                     style: TextStyle(color: Colors.black),
  //                   ),
  //                 ),
  //                 ElevatedButton(
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: Colors.redAccent,
  //                   ),
  //                   onPressed: () {
  //                     Navigator.of(context).pop(false);
  //                   },
  //                   child: const Text(
  //                     'No',
  //                     style: TextStyle(color: Colors.white),
  //                   ),
  //                 ),
  //               ],
  //             );
  //           },
  //         ) ??
  //         false;

  //     if (!confirm) return;

  //     final List<double> quantitiesList = quantities
  //         .map((e) => (e is num) ? e.toDouble() : 0.0)
  //         .toList();

  //     final List<double> amountsList = ((order['amounts'] as List?) ?? [])
  //         .map((e) => (e is num) ? e.toDouble() : 0.0)
  //         .toList();

  //     final List<double> cancelledQtyList =
  //         ((order['cancelledQty'] as List?) ?? [])
  //             .map((e) => (e is num) ? e.toDouble() : 0.0)
  //             .toList();

  //     // Ensure lists are long enough
  //     while (cancelledQtyList.length <= itemIndex) {
  //       cancelledQtyList.add(0.0);
  //     }

  //     // 6. Update quantities and amounts
  //     final double itemAmount = amountsList.length > itemIndex
  //         ? amountsList[itemIndex]
  //         : 0.0;
  //     final double currentTotal = (order['totalAmount'] is num)
  //         ? (order['totalAmount'] as num).toDouble()
  //         : 0.0;

  //     quantitiesList[itemIndex] = 0.0;
  //     cancelledQtyList[itemIndex] = currentQuantity;
  //     final double newTotal = currentTotal - itemAmount;

  //     // 7. Get printer IP with fallback
  //     final String itemName =
  //         varianceNames[itemIndex]?.toString().trim().toLowerCase() ?? '';
  //     String? printerIp = order['printerIpMap']?[itemName];

  //     if (printerIp == null) {
  //       printerIp = printerProvider.getPrinterIpForItem(itemName);
  //     }

  //     if (printerIp == null || printerIp.isEmpty) {
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         showCustomFlushbar(
  //           context,
  //           'Printer not configured for item: ${varianceNames[itemIndex]}',
  //           type: FlushbarType.error,
  //         );
  //       });
  //       return;
  //     }

  //     // 8. Send update to server with safe channel check
  //     final Map<String, dynamic> dataToSend = {
  //       'action': 'cancelOrderItem',
  //       'hiveOrderId': order['hiveOrderId'],
  //       'varianceitemCodes': order['varianceitemCodes'],
  //       'varianceNames': order['varianceNames'],
  //       'uoms': order['uoms'],
  //       'weight': order['weights'],
  //       'cancelledQty': cancelledQtyList,
  //       'totalAmount': newTotal,
  //       'quantities': quantitiesList,
  //       'itemRemark': itemremarkController.text,
  //       'partiallycancelled': true,
  //       'itemIndex': itemIndex,
  //     };

  //     print("dataToSend for _cancelSingleItem $dataToSend");

  //     // Try using the main channel first
  //     bool mainChannelFailed = false;
  //     try {
  //       sendataToServer(dataToSend);
  //       print("✅ Used main channel for cancellation");
  //     } catch (e) {
  //       print("⚠️ Main channel failed: $e");
  //       mainChannelFailed = true;
  //     }

  //     // If main channel failed, use fresh channel
  //     if (mainChannelFailed) {
  //       try {
  //         tempChannel = IOWebSocketChannel.connect('ws://$serverip:$port');
  //         tempChannel.sink.add(jsonEncode(dataToSend));
  //         print("🔄 Used fresh channel for cancellation");
  //       } catch (e) {
  //         print("❌ Fresh channel also failed: $e");
  //         WidgetsBinding.instance.addPostFrameCallback((_) {
  //           showCustomFlushbar(
  //             context,
  //             "Network error. Please check connection and try again.",
  //             type: FlushbarType.error,
  //           );
  //         });
  //         return;
  //       }
  //     }

  //     // 9. Send stock update with appropriate channel
  //     final stockUpdateChannel = mainChannelFailed
  //         ? tempChannel!
  //         : orderProvider.channel;

  //     sendAddStockUpdateGlobally(
  //       context: context,
  //       channel: stockUpdateChannel,
  //       varianceNames: [varianceNames[itemIndex]],
  //       varianceItemCodes: [order['varianceitemCodes']?[itemIndex]],
  //       quantities: [currentQuantity.toInt()],
  //     );

  //     // 10. Update local state immediately
  //     order['quantities'] = quantitiesList;
  //     order['cancelledQty'] = cancelledQtyList;
  //     order['totalAmount'] = newTotal;
  //     order['partiallycancelled'] = true;

  //     // if (order['itemRemarks'] == null) {
  //     //   order['itemRemarks'] = List.filled(quantitiesList.length, '');
  //     // }
  //     // // Ensure the list is long enough
  //     // while (order['itemRemarks'].length <= itemIndex) {
  //     //   order['itemRemarks'].add('');
  //     // }
  //     // order['itemRemarks'][itemIndex] = itemremarkController.text;

  //     if (order['itemRemark'] == null) {
  //       order['itemRemark'] = List.filled(quantitiesList.length, '');
  //     }

  //     while (order['itemRemark'].length <= itemIndex) {
  //       order['itemRemark'].add('');
  //     }

  //     order['itemRemark'][itemIndex] = itemremarkController.text;

  //     // 11. Build filtered order for printing
  //     final filteredOrder = {
  //       ...order,
  //       'quantities': [quantitiesList[itemIndex]],
  //       'cancelledQty': [cancelledQtyList[itemIndex]],
  //       'amounts': [
  //         amountsList.length > itemIndex ? amountsList[itemIndex] : 0.0,
  //       ],
  //       'prices': [order['prices']?[itemIndex] ?? 0.0],
  //       'weights': [order['weights']?[itemIndex] ?? 0.0],
  //       'varianceNames': [varianceNames[itemIndex]],
  //       'config': [order['config']?[itemIndex] ?? ''],
  //       'itemRemark': [itemremarkController.text], // Make sure this is included
  //     };

  //     print("filteredOrder of itemwise cancel is $filteredOrder}");
  //     // 12. Print cancellation receipt
  //     print(
  //       "🖨️ Printing cancellation receipt for item: ${varianceNames[itemIndex]}",
  //     );
  //     try {
  //       await CancelPrinterService.printUniversalReceipt(
  //         ipAddress: printerIp,
  //         tableNumber: order['table'] ?? '',
  //         seat: order['seat'] ?? '',
  //         userName: order['userName'] ?? '',
  //         waiter: order['waiter'] ?? '',
  //         seatOrders: [filteredOrder],
  //         receiptType: 'ITEM CANCELLED',
  //       );
  //       print("✅ Cancellation receipt printed successfully");
  //     } catch (printError) {
  //       print("❌ Printer error: $printError");
  //       // Don't return here - still update UI even if printing fails
  //     }

  //     // 13. Close temp channel if we used one
  //     if (mainChannelFailed && tempChannel != null) {
  //       await Future.delayed(Duration(milliseconds: 500));
  //       tempChannel.sink.close();
  //     }

  //     // 14. Show success message
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       showCustomFlushbar(
  //         context,
  //         "Item cancelled successfully!",
  //         type: FlushbarType.success,
  //       );
  //     });

  //     // 15. Force UI refresh
  //     orderProvider.notifyListeners();
  //   } catch (e, stack) {
  //     print("💥 Error in _cancelSingleItem: $e");
  //     print("📌 Stacktrace: $stack");

  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       showCustomFlushbar(
  //         context,
  //         "Error cancelling item: ${e.toString()}",
  //         type: FlushbarType.error,
  //       );
  //     });
  //   } finally {
  //     // Ensure temp channel is closed
  //     if (tempChannel != null) {
  //       try {
  //         tempChannel.sink.close();
  //       } catch (e) {
  //         print("⚠️ Error closing temp channel: $e");
  //       }
  //     }
  //   }
  // }

  static Future<void> _cancelSingleItem({
    required BuildContext context,
    required Map<String, dynamic> order,
    required int itemIndex,
    required OrderProvider orderProvider,
    required PrinterProviderDine printerProvider,
  }) async {
    // WebSocketChannel? tempChannel;

    debugPrint(" _cancelSingleItem : $order");

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

      debugPrint("varianceNames :: $varianceNames");

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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: const [
                    Icon(Icons.cancel_outlined, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Cancel Item',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please provide a reason for cancellation',
                      style: TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    RemarkTextField(controller: itemremarkController),
                  ],
                ),
                actionsPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                actions: [
                  // ❌ NO (Secondary)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('No'),
                  ),

                  // ✅ YES (Primary)
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
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.w600),
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

      printerIp ??= printerProvider.getPrinterIpForItem(itemName);

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
        'varianceitemCodes': order['varianceitemCodes'],
        'varianceNames': order['varianceNames'],
        'uoms': order['uoms'],
        'weight': order['weights'],
        'cancelledQty': cancelledQtyList,
        'totalAmount': newTotal,
        'quantities': quantitiesList,
        'itemRemark': itemremarkController.text,
        'partiallycancelled': true,
        'itemIndex': itemIndex,
        'ipAddress': printerIp,
      };

      print("dataToSend for _cancelSingleItem $dataToSend");

      sendataToServer(dataToSend);
      print("✅ Used main channel for cancellation");
      // 10. Update local state immediately
      order['quantities'] = quantitiesList;
      order['cancelledQty'] = cancelledQtyList;
      order['totalAmount'] = newTotal;
      order['partiallycancelled'] = true;

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

      // === 1. Validation (keep your safe checks) ===
      final List<dynamic> quantitiesDyn = order['quantities'] ?? [];
      final List<dynamic> varianceNames = order['varianceNames'] ?? [];
      final List<dynamic> cancelledQtyDyn = order['cancelledQty'] ?? [];
      final List<dynamic> pricesDyn = order['prices'] ?? [];

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
                  onPressed: () => {Navigator.pop(context, true)},
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
      double newTotal = 0.0;
      for (int i = 0; i < quantitiesList.length; i++) {
        newTotal += quantitiesList[i] * pricesList[i];
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

      // Get seathiveOrderId from first order
      final firstOrder = activeOrders.first;

      if (activeOrders.isNotEmpty) {
        createdBy = firstOrder['waiter'];
      }
      // showDialog(
      //   context: context,
      //   builder: (BuildContext confirmationContext) {
      //     // final screenWidth = MediaQuery.of(context).size.width;
      //     final screenWidth = MediaQuery.of(confirmationContext).size.width;

      //     return Dialog(
      //       backgroundColor: Colors.white, // Full white background
      //       shape: RoundedRectangleBorder(
      //         borderRadius: BorderRadius.circular(12),
      //       ),
      //       child: Container(
      //         width:
      //             screenWidth * 0.7, // 80% of screen width (adjust as needed)
      //         padding: const EdgeInsets.all(16),
      //         child: Column(
      //           mainAxisSize: MainAxisSize.min,
      //           crossAxisAlignment: CrossAxisAlignment.start,
      //           children: [
      //             // Title Section
      //             Text(
      //               "$tableNumber - Seat $seat",
      //               style: const TextStyle(
      //                 fontWeight: FontWeight.bold,
      //                 fontSize: 18,
      //                 color: Colors.black, // Full black text
      //               ),
      //             ),
      //             const SizedBox(height: 6),
      //             Text(
      //               "Total: ₹${totalPrice.toStringAsFixed(0)}",
      //               style: const TextStyle(
      //                 fontWeight: FontWeight.bold,
      //                 color: Colors.black, // Full black text
      //                 fontSize: 16,
      //               ),
      //             ),
      //             const SizedBox(height: 12),

      //             // Content (Orders list or message)
      //             SizedBox(
      //               width: double.infinity,
      //               child: SingleChildScrollView(
      //                 child: ordersForSeat.isEmpty
      //                     ? const Padding(
      //                         padding: EdgeInsets.symmetric(vertical: 12),
      //                         child: Center(
      //                           child: Text(
      //                             "No active orders for this seat.",
      //                             style: TextStyle(
      //                               color: Colors.red,
      //                               fontSize: 16,
      //                             ),
      //                           ),
      //                         ),
      //                       )
      //                     : Column(
      //                         mainAxisSize: MainAxisSize.min,
      //                         children: ordersForSeat.map((order) {
      //                           try {
      //                             final tokenNo =
      //                                 order['tokenNo']?.toString() ?? 'N/A';
      //                             final items = order['varianceNames'] ?? [];
      //                             final prices = order['prices'] ?? [];
      //                             final weights = order['weights'] ?? [];
      //                             final quantities = order['quantities'] ?? [];
      //                             final amounts = order['amounts'] ?? [];
      //                             final config = order['config'] ?? [];
      //                             final status = order['status'] ?? '';
      //                             final uoms = order['uoms'] ?? [];

      //                             return Padding(
      //                               padding: const EdgeInsets.only(
      //                                 bottom: 16.0,
      //                               ),
      //                               child: buildOrderDetails(
      //                                 items: items,
      //                                 prices: prices,
      //                                 uoms: uoms,
      //                                 weights: weights,
      //                                 quantities: quantities,
      //                                 amounts: amounts,
      //                                 config: config,
      //                                 tokenNo: tokenNo,
      //                                 context: confirmationContext,
      //                                 orderProvider: orderProvider,
      //                                 printerProvider: printerProvider,
      //                                 order: order,
      //                                 status: status,
      //                               ),
      //                             );
      //                           } catch (err) {
      //                             print(
      //                               "❌ Error while building order details: $err",
      //                             );
      //                             return const SizedBox.shrink();
      //                           }
      //                         }).toList(),
      //                       ),
      //               ),
      //             ),

      //             // Actions Buttons
      //             const SizedBox(height: 8),
      //             Row(
      //               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      //               children: [
      //                 ElevatedButton(
      //                   style: ElevatedButton.styleFrom(
      //                     foregroundColor: Colors.white,
      //                     backgroundColor: Colors.grey,
      //                     elevation: 2,
      //                     shape: RoundedRectangleBorder(
      //                       borderRadius: BorderRadius.circular(12),
      //                     ),
      //                     padding: const EdgeInsets.symmetric(
      //                       horizontal: 16,
      //                       vertical: 10,
      //                     ),
      //                   ),
      //                   onPressed: () => Navigator.pop(confirmationContext),
      //                   child: const Text(
      //                     "Close",
      //                     style: TextStyle(color: Colors.black),
      //                   ),
      //                 ),
      //                 AbsorbPointer(
      //                   absorbing: !isActiveOrder,
      //                   child: ElevatedButton(
      //                     style: ElevatedButton.styleFrom(
      //                       foregroundColor: Colors.white,
      //                       backgroundColor: isActiveOrder
      //                           ? Colors.red
      //                           : Colors.grey[400]!,
      //                       elevation: 2,
      //                       shape: RoundedRectangleBorder(
      //                         borderRadius: BorderRadius.circular(12),
      //                       ),
      //                       padding: const EdgeInsets.symmetric(
      //                         horizontal: 16,
      //                         vertical: 10,
      //                       ),
      //                     ),
      //                     onPressed: () async {
      //                       await _cancelOrder(
      //                         context: confirmationContext,
      //                         rootContext: rootContext,
      //                         orderProvider: orderProvider,
      //                         printerProvider: printerProvider,
      //                         tableNumber: tableNumber,
      //                         seat: seat,
      //                         ordersForSeat: ordersForSeat,
      //                       );
      //                     },
      //                     child: const Text(
      //                       "Cancel Order",
      //                       style: TextStyle(color: Colors.black),
      //                     ),
      //                   ),
      //                 ),
      //                 ElevatedButton(
      //                   style: ElevatedButton.styleFrom(
      //                     foregroundColor: Colors.white,
      //                     backgroundColor: isActiveOrder
      //                         ? Colors.green
      //                         : Colors.grey[400]!,
      //                     elevation: 2,
      //                     shape: RoundedRectangleBorder(
      //                       borderRadius: BorderRadius.circular(12),
      //                     ),
      //                     padding: const EdgeInsets.symmetric(
      //                       horizontal: 16,
      //                       vertical: 10,
      //                     ),
      //                   ),
      //                   onPressed: isActiveOrder
      //                       ? () async {
      //                           Navigator.of(confirmationContext).pop();
      //                           await _generatePreInvoice(
      //                             rootContext: rootContext,
      //                             orderProvider: orderProvider,
      //                             submissionProvider: submissionProvider,
      //                             tableNumber: tableNumber,
      //                             seat: seat,
      //                             ordersForSeat: ordersForSeat,
      //                             printerIp: printerIp,
      //                           );
      //                         }
      //                       : null,
      //                   child: const Text(
      //                     "Generate Pre-Invoice",
      //                     style: TextStyle(fontSize: 12, color: Colors.black),
      //                     textAlign: TextAlign.center,
      //                   ),
      //                 ),
      //               ],
      //             ),
      //           ],
      //         ),
      //       ),
      //     );
      //   },
      // );
      showDialog(
        context: context,
        builder: (BuildContext confirmationContext) {
          final screenWidth = MediaQuery.of(confirmationContext).size.width;
          final screenHeight = MediaQuery.of(confirmationContext).size.height;

          // Reduced width: max 400px, or 60% of screen (whichever is smaller)
          final dialogWidth = screenWidth > 600 ? 800.0 : screenWidth * 0.8;

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: dialogWidth,
              height: screenHeight * 0.8, // Still limit height for safety
              padding: const EdgeInsets.all(20), // Slightly more padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header - Larger fonts
                  Text(
                    "$tableNumber - Seat $seat",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22, // Increased from 18
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Total: ₹${totalPrice.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20, // Increased from 16
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Scrollable Order List
                  Expanded(
                    child: ordersForSeat.isEmpty
                        ? const Center(
                            child: Text(
                              "No active orders for this seat.",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 18, // Larger empty message
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
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
                                  final uoms = order['uoms'] ?? [];

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 20.0,
                                    ),
                                    child: buildOrderDetails(
                                      items: items,
                                      prices: prices,
                                      uoms: uoms,
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

                  const SizedBox(height: 20),

                  // Action Buttons - Larger text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.grey[300],
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () => Navigator.pop(confirmationContext),
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      AbsorbPointer(
                        absorbing: !isActiveOrder,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActiveOrder
                                ? Colors.redAccent[200]
                                : Colors.grey[400],
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          onPressed: isActiveOrder
                              ? () async {
                                  await _cancelOrder(
                                    context: confirmationContext,
                                    rootContext: rootContext,
                                    orderProvider: orderProvider,
                                    printerProvider: printerProvider,
                                    tableNumber: tableNumber,
                                    seat: seat,
                                    ordersForSeat: ordersForSeat,
                                  );
                                }
                              : null,
                          child: const Text(
                            "Cancel Order",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActiveOrder
                              ? Colors.blue
                              : Colors.grey[400],
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
        promptForPrinterIp(rootContext);
        return;
      }

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

      // await requestAndPrintPreInvoice(
      //   areaName: ordersForSeat.first['areaName'],
      //   channel: freshChannel,
      //   ipAddress: printerIp,
      //   seat: seat,
      //   seatOrders: ordersForSeat as List<Map<String, dynamic>>,
      //   seathiveOrderId: ordersForSeat.isNotEmpty
      //       ? ordersForSeat.first['seathiveOrderId']
      //       : '',
      //   tableNumber: tableNumber,
      //   userName: userName,
      //   waiter: createdBy,
      // );

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
                String uom = uoms[i];
                debugPrint("uom is $uom");
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
                debugPrint(
                  "weight is $weight , price is $price , amount is $amount ",
                );

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
                              "₹${price.toStringAsFixed(0)} / ${uom == "kgs" ? weight : ''} $uom",
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

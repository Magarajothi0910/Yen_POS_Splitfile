import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/kotpreinvoice/services/invoice_number_service.dart';

import '../../components/flushbar.dart';
import '../../providers/order_provider.dart';
import '../../providers/submissionProvider.dart';
import '../../services/preInv Utility.dart';
import '../../services/preInvociePrint_services.dart';
import '../../components/capitalizeWord.dart';

class SeatOrderDetailsDialog {
  static WebSocketChannel channel = IOWebSocketChannel.connect('ws://$serverip:$port');
 
  static void  showSeatOrderDetails({
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
      final submissionProvider = Provider.of<SubmissionProviderDine>(context, listen: false);
      final bool isActiveOrder = ordersForSeat.any((order) => order['status'] == 'active');
 
      showDialog(
        context: context,
        builder: (BuildContext confirmationContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$tableNumber - Seat $seat", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                Text("Total: ₹${totalPrice.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: ordersForSeat.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: Text("No active orders for this seat.", style: TextStyle(color: Colors.red, fontSize: 16))),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: ordersForSeat.map((order) {
                          try {
                            final tokenNo = order['tokenNo']?.toString() ?? 'N/A';
                            final items = order['varianceNames'] ?? [];
                            final prices = order['prices'] ?? [];
                            final weights = order['weights'] ?? [];
                            final quantities = order['quantities'] ?? [];
                            final amounts = order['amounts'] ?? [];
                            final config = order['config'] ?? [];
 
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: buildOrderDetails(
                                items: items,
                                prices: prices,
                                weights: weights,
                                quantities: quantities,
                                amounts: amounts,
                                config: config,
                                tokenNo: tokenNo,
                              ),
                            );
                          } catch (err) {
                            print("❌ Error while building order details: $err");
                            return const SizedBox.shrink();
                          }
                        }).toList(),
                      ),
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () => Navigator.pop(confirmationContext),
                    child: const Column(
                      children: [Icon(Icons.cancel), Text("Close")],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: isActiveOrder ? Colors.green : Colors.grey[400], // disable when inactive
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () async {
                      submissionProvider.startSubmitting();
                      try {
                        print("🟢 Confirming orders for seat $seat");
 
                        if (!isActiveOrder) {
                          Navigator.of(confirmationContext).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            showCustomFlushbar(
                              rootContext,
                              "Pre-Invoice already generated for this seat.",
                              type: FlushbarType.warning,
                            );
                          });
 
                          debugPrint("⚠️ No active order found for seat $seat");
                          return;
                        }
 
                        print("📋 Active orders for seat $seat: $ordersForSeat");
 
                        if (printerIp == null || printerIp.isEmpty) {
                          print("⚠️ Missing printer IP for seat $seat");
                          promptForPrinterIp(rootContext);
                          return;
                        }
 
                        print("🖨️ Using printer IP: $printerIp");
 
                        final loadingContext = Navigator.of(rootContext, rootNavigator: true).context;
 
                        try {
                          for (var order in ordersForSeat) {
                            if (order['seathiveOrderId'] != null) {
                              print("🔄 Updating order ${order['seathiveOrderId']} status to confirm");
                              await orderProvider.patchOrderStatusBySeathiveOrderId(
                                order['seathiveOrderId'],
                                "confirm",
                              );
                            }
                          }
 
                          print("🖨️ Printing receipt for seat $seat");
 
                          requestAndPrintPreInvoice(
                              areaName: ordersForSeat.first['areaName'],
                              channel: channel,
                              ipAddress: printerIp,
                              seat: seat,
                              seatOrders: ordersForSeat as List<Map<String, dynamic>>,
                              seathiveOrderId: ordersForSeat.isNotEmpty ? ordersForSeat.first['seathiveOrderId'] : '',
                              tableNumber: tableNumber,
                              userName: userName,
                              waiter: createdBy);
 
                          print("✅ Receipt printed successfully for seat $seat");
 
                          if (Navigator.of(loadingContext, rootNavigator: true).canPop()) {
                            Navigator.of(loadingContext, rootNavigator: true).pop();
                          }
                          if (Navigator.of(confirmationContext).canPop()) {
                            Navigator.of(confirmationContext).pop();
                          }
 
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            showCustomFlushbar(
                              rootContext,
                              "Invoice generated successfully!",
                              type: FlushbarType.success,
                            );
                          });
                          orderProvider.notifyListeners();
                        } catch (printErr) {
                          debugPrint("❌ Printing error: $printErr");
                          Navigator.of(loadingContext, rootNavigator: true).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            showCustomFlushbar(
                              rootContext,
                              "Printing error: $printErr",
                              type: FlushbarType.error,
                            );
                          });
                        }
                      } catch (e) {
                        print("❌ Seat order details error: $e");
                      } finally {
                        submissionProvider.stopSubmitting();
                        print("🟡 Submission process finished for seat $seat");
                      }
                    },
                    child: const Column(
                      children: [
                        Icon(Icons.print, size: 15),
                        SizedBox(height: 4),
                        Text(
                          "Generate Pre-Invoice",
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } catch (err) {
      print("❌ Unexpected error in showSeatOrderDetails: $err");
    }
  }
 
  static Widget buildOrderDetails({
    required List items,
    required List prices,
    required List weights,
    required List quantities,
    required List amounts,
    required List config,
    required String tokenNo,
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
                const Text("Order Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Token: $tokenNo", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: List.generate(items.length, (i) {
              try {
                String itemName = items[i];
                double price = prices.length > i ? prices[i].toDouble() : 0.0;
                double weight = weights.length > i ? weights[i].toDouble() : 0.0;
                double quantity = quantities.length > i ? quantities[i].toDouble() : 0.0;
                double amount = amounts.length > i ? amounts[i].toDouble() : 0.0;
 
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
                            Text(capitalizeWords(itemName)),
                            Text(
                              "₹${price.toStringAsFixed(0)} / ${weight > 0 ? "$weight kg" : "No Weight"}",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(quantity.toStringAsFixed(0), textAlign: TextAlign.center),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text("₹${amount.toStringAsFixed(0)}", textAlign: TextAlign.right),
                      ),
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/kotpreinvoice/services/invoice_number_service.dart';
import '../../models/printer.dart';
import '../../../kotpreinvoice/providers/bottomNavprovider.dart';
import '../../services/preInv%20Utility.dart';
import '../../services/preInvociePrint_services.dart';
import '../../widgets/settingsScreen.dart';

import '../../Helper/order_helper.dart';
import '../../components/flushbar.dart';
import '../../providers/order_provider.dart';
import '../../providers/printer_provider.dart';
import '../../screens/customerScreen file/seat_transfer.dart';
import '../../components/tableProperties.dart';
import 'printreceiptfrombottomsheet.dart';
import 'tableSeatorderDialog.dart';

void showCustomerActions({
  required BuildContext context,
  required OrderProvider orderProvider,
  required String tableNumber,
  required List<dynamic> seatOrders,
  required String areaName,
  required String selectedSeat,
  required VoidCallback addExtraSeat,
  WebSocketChannel? channel,
}) {
  bool isActiveOrder = seatOrders.any((order) => order['status'] == 'active');
  showModalBottomSheet(
    backgroundColor: Colors.white,
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
    ),
    builder: (BuildContext context) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chair, color: Colors.blueGrey[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "$tableNumber Actions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[900],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: buildActionButton(
                    icon: Icons.visibility,
                    color: Colors.blue,
                    title: "View Kot Order",
                    onTap: () {
                      final rootContext = Navigator.of(context, rootNavigator: true).context;
                      final ordersForSeat = orderProvider
                          .getActiveOrdersForSeat(tableNumber, selectedSeat)
                          .where((o) => o['table'] == tableNumber && o['seat'] == selectedSeat && (o['status'] == "active" || o['status'] == "confirm"))
                          .toList();

                      if (ordersForSeat.isNotEmpty) {
                        Navigator.pop(context);
                        print("view kot order for seat: $selectedSeat");
                        SeatOrderDetailsDialog.showSeatOrderDetails(
                          context: context,
                          rootContext: rootContext,
                          orderProvider: orderProvider,
                          tableNumber: tableNumber,
                          seat: selectedSeat,
                          ordersForSeat: ordersForSeat,
                          printerIp: Provider.of<PrinterProviderDine>(context, listen: false).getPreInvoicePrinterIp(),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildActionButton(
                    icon: Icons.swap_horiz,
                    color: isActiveOrder ? Colors.green : Colors.grey,
                    title: "Transfer Table",
                    onTap: () {
                      Navigator.pop(context);

                      if (isActiveOrder) {
                        final activeOrder = seatOrders.firstWhere(
                          (order) => order['seat'] == selectedSeat && order['status'] == 'active',
                          orElse: () => <String, dynamic>{},
                        );

                        if (activeOrder.isNotEmpty) {
                          showAvailableTablesForTransfer(
                            context,
                            tableNumber,
                            activeOrder["seat"],
                            activeOrder["seathiveOrderId"],
                          );
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            showCustomFlushbar(
                              context,
                              "Pre-Invoice generated, no need to transfer seat.",
                              type: FlushbarType.info,
                            );
                          });
                        }
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          showCustomFlushbar(
                            context,
                            "Pre-Invoice generated, no need to transfer seat.",
                            type: FlushbarType.info,
                          );
                        });

                        return;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: buildActionButton(
                      icon: Icons.print,
                      color: isActiveOrder ? Colors.red : Colors.grey,
                      title: "Generate Pre-Invoice",
                      onTap: () async {
                        final rootContext = Navigator.of(context, rootNavigator: true).context;
                        Navigator.pop(context);

                        final printerProvider = Provider.of<PrinterProviderDine>(rootContext, listen: false);

                        // 🟡 Step 1: Check if Pre-Invoice printer is configured
                        final preInvoicePrinter = printerProvider.printers.firstWhere(
                          (printer) => printer.type == 'PreInvoice',
                          orElse: () => Printer(name: '', ipAddress: '', type: ''),
                        );

                        if (preInvoicePrinter.ipAddress.isEmpty) {
                          // 🟥 Printer not configured → show your reusable dialog
                          await promptForPrinterIp(rootContext);

                          // 🟢 Re-check after user potentially set the printer
                          final updatedPrinter = printerProvider.printers.firstWhere(
                            (printer) => printer.type == 'PreInvoice',
                            orElse: () => Printer(name: '', ipAddress: '', type: ''),
                          );

                          if (updatedPrinter.ipAddress.isEmpty) {
                            return;
                          }
                        }

                        // ✅ Step 2: Proceed only if Pre-Invoice printer exists
                        if (isActiveOrder) {
                          showDialog(
                            context: rootContext,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Confirm Pre-Invoice"),
                              content: const Text("Are you sure you want to generate the Pre-Invoice?"),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade100,
                                    foregroundColor: Colors.red,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                  ),
                                ),
                                // ElevatedButton(
                                //   style: ElevatedButton.styleFrom(
                                //     backgroundColor: const Color(0xFFE0F2F1),
                                //     foregroundColor: Colors.teal,
                                //     elevation: 2,
                                //     shape: RoundedRectangleBorder(
                                //       borderRadius: BorderRadius.circular(12),
                                //     ),
                                //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                //   ),
                                //   onPressed: () async {
                                //     Navigator.of(ctx).pop();

                                //     final filteredOrders = filterValidSeatOrders(
                                //       allOrders: seatOrders,
                                //       tableNumber: tableNumber,
                                //       seat: selectedSeat,
                                //     );

                                //     if (filteredOrders.isEmpty) {
                                //       WidgetsBinding.instance.addPostFrameCallback((_) {
                                //         showCustomFlushbar(
                                //           rootContext,
                                //           "No valid orders found to print.",
                                //           type: FlushbarType.info,
                                //         );
                                //       });
                                //       return;
                                //     }

                                //     // 🧾 Step 3: Generate pre-invoice data
                                //     await PrintReceiptService.generatePreInvoice(
                                //       context: rootContext,
                                //       orderProvider: orderProvider,
                                //       tableNumber: tableNumber,
                                //       seat: selectedSeat,
                                //       seatOrders: filteredOrders,
                                //       areaName: areaName,
                                //     );

                                //     WidgetsBinding.instance.addPostFrameCallback((_) {
                                //       showCustomFlushbar(
                                //         rootContext,
                                //         "Pre-Invoice generated successfully!",
                                //         type: FlushbarType.success,
                                //       );
                                //     });
                                //   },
                                //   child: const Text(
                                //     "Confirm",
                                //     style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                //   ),
                                // ),
                                 ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE0F2F1),
                                    foregroundColor: Colors.teal,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  onPressed: () async {
                                    Navigator.of(ctx).pop();
 
                                    final filteredOrders = filterValidSeatOrders(
                                      allOrders: seatOrders,
                                      tableNumber: tableNumber,
                                      seat: selectedSeat,
                                    );
 
                                    if (filteredOrders.isEmpty) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        showCustomFlushbar(
                                          rootContext,
                                          "No valid orders found to print.",
                                          type: FlushbarType.info,
                                        );
                                      });
                                      return;
                                    }
 
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
 
                                    requestAndPrintPreInvoice(
                                      areaName: areaName,
                                      channel: channel!,
                                      ipAddress: preInvoicePrinter.ipAddress,
                                      seat: selectedSeat,
                                      seatOrders: seatOrders as List<Map<String, dynamic>>,
                                      seathiveOrderId: seatOrders.first['seathiveOrderId'],
                                      tableNumber: tableNumber,
                                      userName: userName,
                                      waiter: createdBy,
                                    );
 
                                   
 
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      showCustomFlushbar(
                                        rootContext,
                                        "Invoice generated successfully!",
                                        type: FlushbarType.success,
                                      );
                                    });
                                    orderProvider.notifyListeners();
                                  },
                                  child: const Text(
                                    "Confirm",
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            showCustomFlushbar(
                              context,
                              "Already the table is pre-invoiced.",
                              type: FlushbarType.warning,
                            );
                          });
                        }
                      }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildActionButton(
                    icon: Icons.chair,
                    color: Colors.teal,
                    title: "  Add Extra Seat  ",
                    onTap: () {
                      Navigator.pop(context);
                      addExtraSeat();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

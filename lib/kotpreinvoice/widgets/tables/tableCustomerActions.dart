import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/kotpreinvoice/providers/submissionProvider.dart';
import 'package:yen_pos/kotpreinvoice/services/hive_service.dart';
import 'package:yen_pos/kotpreinvoice/services/invoice_number_service.dart';
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

void showTableActionsDialog({
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

  showDialog(
    context: context,
    barrierDismissible: true, // tap outside to close

    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 12.0,
            ),
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
                        Icon(
                          Icons.chair,
                          color: Colors.blueGrey[700],
                          size: 20,
                        ),
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
                          final rootContext = Navigator.of(
                            context,
                            rootNavigator: true,
                          ).context;

                          final ordersForSeat = orderProvider
                              .getActiveOrdersForSeat(tableNumber, selectedSeat)
                              .where(
                                (o) =>
                                    o['table'] == tableNumber &&
                                    o['seat'] == selectedSeat &&
                                    (o['status'] == "active" ||
                                        o['status'] == "confirm"),
                              )
                              .toList();

                          if (ordersForSeat.isNotEmpty) {
                            Navigator.pop(context);

                            SeatOrderDetailsDialog.showSeatOrderDetails(
                              context: context,
                              rootContext: rootContext,
                              orderProvider: orderProvider,
                              tableNumber: tableNumber,
                              seat: selectedSeat,
                              ordersForSeat: ordersForSeat,
                              printerIp: Provider.of<PrinterProviderDine>(
                                context,
                                listen: false,
                              ).getPreInvoicePrinterIp(),
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
                          if (isActiveOrder) {
                            final activeOrder = seatOrders.firstWhere(
                              (order) =>
                                  order['seat'] == selectedSeat &&
                                  order['status'] == 'active',
                              orElse: () => <String, dynamic>{},
                            );

                            print("activeOrder is $activeOrder");

                            if (activeOrder.isNotEmpty) {
                              Navigator.of(context).pop();

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
                      child: AbsorbPointer(
                        absorbing: !isActiveOrder,
                        child: buildActionButton(
                          icon: Icons.print,
                          color: isActiveOrder ? Colors.red : Colors.grey,
                          title: "Generate Pre-Invoice",
                          onTap: () async {
                            final Context = Navigator.of(
                              context,
                              rootNavigator: true,
                            ).context;
                            Navigator.pop(context);

                            final printerProvider =
                                Provider.of<PrinterProviderDine>(
                                  Context,
                                  listen: false,
                                );

                            final submissionProvider =
                                Provider.of<SubmissionProviderDine>(
                                  Context,
                                  listen: false,
                                );

                            final preInvoicePrinter = printerProvider.printers
                                .firstWhere(
                                  (printer) => printer.type == 'PreInvoice',
                                  orElse: () {
                                    return Printer(
                                      name: 'default_printer_name',
                                      ipAddress: 'default_ip',
                                      type: 'default_type',
                                    );
                                  },
                                );

                            try {
                              print(
                                "🟢 Confirming orders for seat $selectedSeat",
                              );

                              if (preInvoicePrinter.ipAddress == null ||
                                  preInvoicePrinter.ipAddress.isEmpty) {
                                print(
                                  "⚠️ Missing printer IP for seat $selectedSeat",
                                );
                                promptForPrinterIp(Context);
                                return;
                              }

                              print(
                                "🖨️ Using printer IP: ${preInvoicePrinter.ipAddress}",
                              );

                              sendPreInvoiceToServer(
                                context: Context,
                                tableNumber: tableNumber,
                                seat: selectedSeat,
                                areaName: areaName,
                                seatOrders:
                                    seatOrders as List<Map<String, dynamic>>,
                                ipAddress: preInvoicePrinter.ipAddress,
                                userName: userName,
                                waiter: createdBy,
                                seathiveOrderId:
                                    seatOrders.first['seathiveOrderId'],
                              );

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                showCustomFlushbar(
                                  Context,
                                  "Invoice generated successfully!",
                                  type: FlushbarType.success,
                                );
                              });
                            } catch (printErr) {
                              debugPrint("❌ Printing error: $printErr");
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                showCustomFlushbar(
                                  Context,
                                  "Printing error: $printErr",
                                  type: FlushbarType.error,
                                );
                              });
                            } finally {
                              submissionProvider.stopSubmitting();
                              print(
                                "🟡 Submission process finished for seat $selectedSeat",
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: !isActiveOrder,
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

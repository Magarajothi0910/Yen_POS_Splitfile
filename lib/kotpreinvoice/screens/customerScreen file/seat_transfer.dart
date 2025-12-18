import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/websocketService.dart';
import 'package:yenpos/kotpreinvoice/providers/timerProvider.dart';
import '../../providers/printer_provider.dart';
import '../../services/transfer_seat_print_service.dart';
import 'package:yenpos/Global/globals_data.dart';
import '../../providers/order_provider.dart';
import '../../services/websocketService.dart';

void showAvailableTablesForTransfer(
  BuildContext context,
  String currentTable,
  String currentSeat,
  String seathiveOrderId,
) {
  final orderProvider = Provider.of<OrderProvider>(context, listen: false);
  const double cardWidth = 100;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 900,
          height: 600,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.table_restaurant, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Available Tables',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.builder(
                    itemCount: tables.length,
                    itemBuilder: (context, areaIndex) {
                      final area = tables[areaIndex];
                      final areaName = area['areaName'];
                      final areaTables =
                          area['tables'] as List<Map<String, dynamic>>;

                      final availableTables = areaTables.where((table) {
                        final tableNumber = table['tableNumber'].toString();
                        final total = orderProvider.getTableTotalPrice(
                          tableNumber,
                        );
                        return total == 0 && tableNumber != currentTable;
                      }).toList();

                      if (availableTables.isEmpty) return const SizedBox();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Area Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            child: Text(
                              areaName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),

                          // Tables Grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 8,
                                  childAspectRatio: 1.2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: availableTables.length,
                            itemBuilder: (context, index) {
                              final table = availableTables[index];
                              final tableNumber = table['tableNumber'];

                              return GestureDetector(
                                onTap: () {
                                  // Navigator.of(
                                  //   context,
                                  // ).pop(); // Close table selection dialog

                                  showDialog(
                                    context: context,
                                    builder: (BuildContext dialogContext) {
                                      return AlertDialog(
                                        backgroundColor: Colors.white,
                                        title: const Row(
                                          children: [
                                            Icon(
                                              Icons.swap_horiz,
                                              color: Colors.blue,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "Confirm Transfer",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          "Transfer from $currentTable to $tableNumber?",
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                            ),
                                            onPressed: () {
                                              Navigator.of(dialogContext).pop();
                                            },
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                            ),
                                            onPressed: () async {
                                              print(
                                                "🪑 Seat transfer initiated...",
                                              );
                                              Navigator.of(dialogContext).pop();
                                              Navigator.of(dialogContext).pop();

                                              final webSocketService =
                                                  Provider.of<WebSocketService>(
                                                    context,
                                                    listen: false,
                                                  );
                                              final orderProvider =
                                                  Provider.of<OrderProvider>(
                                                    context,
                                                    listen: false,
                                                  );
                                              final printerProvider =
                                                  Provider.of<
                                                    PrinterProviderDine
                                                  >(context, listen: false);

                                              final timerProvider =
                                                  Provider.of<TimerProvider>(
                                                    context,
                                                    listen: false,
                                                  );

                                              print(
                                                "🌐 Sending seat transfer request...",
                                              );
                                              final success =
                                                  await webSocketService
                                                      .sendSeatTransfer(
                                                        currentTable:
                                                            currentTable,
                                                        currentSeat:
                                                            currentSeat,
                                                        targetTable:
                                                            tableNumber,
                                                        targetSeat: 'A',
                                                        seathiveOrderId:
                                                            seathiveOrderId,
                                                      );

                                              if (!success) {
                                                print(
                                                  "❌ Seat transfer failed — WebSocket server not connected.",
                                                );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Failed to transfer seat: Server not connected',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              print(
                                                "✅ Seat transfer request sent: {currentTable: $currentTable, currentSeat: $currentSeat, targetTable: $tableNumber, targetSeat: A, seathiveOrderId: $seathiveOrderId}",
                                              );

                                              timerProvider.stopTimer(
                                                currentTable,
                                                currentSeat,
                                              );
                                              timerProvider.startTimer(
                                                tableNumber,
                                                currentSeat,
                                              );
                                              // 🔍 Fetch order details
                                              final seatOrders = orderProvider
                                                  .getActiveOrdersForSeat(
                                                    currentTable,
                                                    currentSeat,
                                                  );
                                              print(
                                                "📦 Orders fetched for seat $currentSeat at table $currentTable → ${seatOrders.length} orders",
                                              );

                                              final areaName =
                                                  getAreaNameForTable(
                                                    tableNumber,
                                                  );
                                              final waiter = createdBy;
                                              final ipAddress = printerProvider
                                                  .getOverallPrinterIp();

                                              print(
                                                "🧾 Preparing print receipt: area=$areaName, waiter=$waiter, ip=$ipAddress",
                                              );

                                              if (ipAddress == null ||
                                                  ipAddress.isEmpty) {
                                                print(
                                                  "⚠️ Cannot print — No printer IP configured!",
                                                );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      "⚠️ No printer IP configured",
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              // 🖨️ Print the receipt
                                              print(
                                                "🖨️ Sending print job to printer ($ipAddress)...",
                                              );
                                              final result =
                                                  SeatTransferPrinter.printReceipt(
                                                    ipAddress: ipAddress,
                                                    tableNumber: tableNumber,
                                                    seat: 'A',
                                                    seatOrders: seatOrders,
                                                    receiptType: 'TRANSFER',
                                                    userName: userName,
                                                    waiter: waiter,
                                                    areaName: areaName,
                                                    fromTable: currentTable,
                                                    fromSeat: currentSeat,
                                                  );

                                              print("✅ Print result: $result");
                                            },
                                            child: const Text("Confirm"),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    // border: Border.all(
                                    //   color: Colors.grey,
                                    // ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color.fromARGB(76, 0, 0, 0),
                                        blurRadius: 4,
                                        offset: Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.table_restaurant,
                                          color: Colors.black12,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          tableNumber,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // const SizedBox(height: 16), // Spacing between areas
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Footer with close button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String getAreaNameForTable(String tableNumber) {
  for (var area in tables) {
    List<dynamic> tables = area['tables'];
    for (var table in tables) {
      if (table['tableNumber'] == tableNumber) {
        return area['areaName'];
      }
    }
  }
  return '';
}

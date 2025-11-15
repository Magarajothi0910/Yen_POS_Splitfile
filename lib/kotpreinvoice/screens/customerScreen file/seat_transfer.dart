import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/websocketService.dart';
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

  showModalBottomSheet(
    backgroundColor: Colors.white,
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
    ),
    builder: (BuildContext context) {
      final screenHeight = MediaQuery.of(context).size.height;

      return SizedBox(
        height: screenHeight * 0.8,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                'Available Tables',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: tables.length,
                itemBuilder: (context, areaIndex) {
                  final area = tables[areaIndex];
                  final areaName = area['areaName'];
                  final areaTables = area['tables'] as List<Map<String, dynamic>>;

                  final availableTables = areaTables.where((table) {
                    final tableNumber = table['tableNumber'].toString();
                    final total = orderProvider.getTableTotalPrice(tableNumber);
                    return total == 0 && tableNumber != currentTable;
                  }).toList();

                  if (availableTables.isEmpty) return const SizedBox();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        child: Text(
                          areaName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final int columns = (constraints.maxWidth / cardWidth).floor();

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns > 0 ? columns : 1,
                              childAspectRatio: cardWidth / 100,
                            ),
                            itemCount: availableTables.length,
                            itemBuilder: (context, index) {
                              final table = availableTables[index];
                              final tableNumber = table['tableNumber'];

                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext dialogContext) {
                                      return AlertDialog(
                                        backgroundColor: Colors.white,
                                        title: const Row(
                                          children: [
                                            Icon(Icons.swap_horiz, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text(
                                              "Confirm Transfer",
                                              style: TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        content: Text("Transfer from $currentTable to $tableNumber?"),
                                        actions: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            ),
                                            onPressed: () async {
                                              print("🪑 Seat transfer initiated...");
                                              Navigator.of(dialogContext).pop();
                                              Navigator.pop(context);

                                              final webSocketService = Provider.of<WebSocketService>(context, listen: false);
                                              final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                                              final printerProvider = Provider.of<PrinterProviderDine>(context, listen: false);

                                              print("🌐 Sending seat transfer request...");
                                              final success = await webSocketService.sendSeatTransfer(
                                                currentTable: currentTable,
                                                currentSeat: currentSeat,
                                                targetTable: tableNumber,
                                                targetSeat: 'A',
                                                seathiveOrderId: seathiveOrderId,
                                              );

                                              if (!success) {
                                                print("❌ Seat transfer failed — WebSocket server not connected.");
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Failed to transfer seat: Server not connected')),
                                                );
                                                return;
                                              }

                                              print(
                                                  "✅ Seat transfer request sent: {currentTable: $currentTable, currentSeat: $currentSeat, targetTable: $tableNumber, targetSeat: A, seathiveOrderId: $seathiveOrderId}");

                                              // 🔍 Fetch order details
                                              final seatOrders = orderProvider.getActiveOrdersForSeat(currentTable, currentSeat);
                                              print("📦 Orders fetched for seat $currentSeat at table $currentTable → ${seatOrders.length} orders");

                                              final areaName = getAreaNameForTable(tableNumber);
                                              final waiter = createdBy;
                                              final ipAddress = printerProvider.getOverallPrinterIp();

                                              print("🧾 Preparing print receipt: area=$areaName, waiter=$waiter, ip=$ipAddress");

                                              if (ipAddress == null || ipAddress.isEmpty) {
                                                print("⚠️ Cannot print — No printer IP configured!");
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("⚠️ No printer IP configured")),
                                                );
                                                return;
                                              }

                                              // 🖨️ Print the receipt
                                              print("🖨️ Sending print job to printer ($ipAddress)...");
                                              final result = SeatTransferPrinter.printReceipt(
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
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            tableNumber,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
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

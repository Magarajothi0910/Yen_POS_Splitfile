import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../screens/kot_screen/global/globals.dart';
import '../../Helper/generateSeatLables.dart';
import '../../kotservices/kotwebsocketService.dart';
import '../../models/globals.dart';
import '../../kotproviders/order_provider.dart';

void showTransferDialog(
  BuildContext context,
  OrderProvider orderProvider,
  String currentTable,
  String seat,
  String seathiveOrderId,
) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      TextEditingController searchController = TextEditingController();

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(
              'Transfer - $currentTable (Seat $seat)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 400, // ✅ Reduce the height of the popup
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Search by Table Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    for (var table in filterTables(searchController.text))
                      if (table["tableNumber"] != currentTable)
                        _buildTableItem(
                          context,
                          orderProvider,
                          currentTable,
                          table["tableNumber"], // ✅ Pass table number correctly
                          seat,
                          table[
                              "seats"], // ✅ Pass the correct seat count dynamically
                          seathiveOrderId,
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildTableItem(
  BuildContext context,
  OrderProvider orderProvider,
  String currentTable,
  String targetTable,
  String currentSeat,
  int seats,
  String seathiveOrderId,
) {
  final occupiedSeats = orderProvider.getOccupiedSeats(targetTable);

  List<String> availableSeats = List.generate(seats, (index) {
    final seatLabel = generateSeatLabel(index);

    return occupiedSeats.contains(seatLabel) ? null : seatLabel;
  }).where((seat) => seat != null).cast<String>().toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        ' $targetTable (Seats: $seats):',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 4, // Adjust to fit your design
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2, // Adjusts width/height ratio for alignment
        children: availableSeats.map((seat) {
          bool isOccupied = occupiedSeats.contains(seat);

          return GestureDetector(
            onTap: () {
              if (!isOccupied) {
                confirmSeatTransfer(
                  context,
                  currentTable,
                  currentSeat,
                  targetTable,
                  seat,
                  seathiveOrderId,
                );
              }
            },
            child: Container(
              width: 70, // Fixed width
              height: 50, // Fixed height to align properly
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 138, 216, 141),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                'Seat $seat',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
    ],
  );
}

void confirmSeatTransfer(
  BuildContext context,
  String currentTable,
  String currentSeat,
  String targetTable,
  String targetSeat,
  String seathiveOrderId,
) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent accidental closing
    builder: (BuildContext dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0)), // ✅ Rounded corners
        child: SizedBox(
          width: MediaQuery.of(context).size.width *
              0.7, // ✅ Reduce width to 70% of screen
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Confirm Seat Transfer",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure want to transfer from $currentTable (Seat $currentSeat) to $targetTable (Seat $targetSeat)?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                            dialogContext); // ❌ Only close confirmation dialog
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 239, 72, 72),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                            dialogContext); // ✅ Close confirmation dialog
                        Navigator.pop(
                            context); // ✅ Close transfer UI after confirmation

                        sendTransferSeatActionToServer(
                          context: context, // ✅ Now passing context properly

                          currentTable: currentTable,
                          currentSeat: currentSeat,
                          targetTable: targetTable,
                          targetSeat: targetSeat,
                          seathiveOrderId: seathiveOrderId,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA5D6A7),
                      ),
                      child: const Text(
                        "Confirm",
                        style: TextStyle(fontSize: 16, color: Colors.black),
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

void sendTransferSeatActionToServer({
  required BuildContext context, // ✅ Pass context for Provider lookup

  required String currentTable,
  required String currentSeat,
  required String targetTable,
  required String targetSeat,
  required String seathiveOrderId,
}) {
  final webSocketService =
      Provider.of<WebSocketServicekot>(context, listen: false);
  final data = {
    'action': 'seat_transfer',
    'currentTable': currentTable,
    'currentSeat': currentSeat,
    'targetTable': targetTable,
    'targetSeat': targetSeat,
    'seathiveOrderId': seathiveOrderId,
  };
  webSocketService.channel.sink.add(jsonEncode(data));
}

List<Map<String, dynamic>> filterTables(String query) {
  List<Map<String, dynamic>> filteredTables = [];

  for (var area in tables) {
    for (var table in area['tables']) {
      String tableNumber = table["tableNumber"];
      int seats = table["seats"]; // ✅ Get correct seat count

      if (query.isEmpty || tableNumber.contains(query)) {
        filteredTables.add({
          "tableNumber": tableNumber,
          "seats": seats, // ✅ Return actual seat count
        });
      }
    }
  }
  return filteredTables;
}

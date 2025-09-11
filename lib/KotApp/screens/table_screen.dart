import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import '../../../screens/kot_screen/global/globals.dart';
import '../../services/branchwise_item_fetch.dart';
import '../kotproviders/order_provider.dart';
import '../kotproviders/product_provider.dart';
import '../models/globals.dart' as globals;
import '../widgets/bottomNav.dart';
import '../widgets/globalAppbar.dart';

import 'customer_screen.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  _TableScreenState createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  IOWebSocketChannel? channel;
  Timer? _refreshTimer; // Timer variable for auto refreshing

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      // if the widget is gone, stop the timer
      if (!mounted) {
        timer.cancel();
        return;
      }
      Provider.of<OrderProvider>(context, listen: false)
          .requestDataFromServer();
    });
    initWebSocketAndData();
  }

  Future<void> initWebSocketAndData() async {
    if (serverip.isNotEmpty) {
      final uri = 'ws://$serverip:$port';

      channel = IOWebSocketChannel.connect(uri);

      Provider.of<ItemProvider>(context, listen: false).fetchDataIfNeeded();

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      // ✅ Wait until WebSocket and Hive are fully initialized
      await orderProvider.initializeHive();


      // ✅ Safe to call now
      orderProvider.requestDataFromServer();
    } else {
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();

    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    const double cardWidth = 100; // Desired card width
    const double cardHeight = 100; // Desired card height
    final int columns = (screenWidth / cardWidth).floor();

    int fullyBookedCount = 0;
    int partiallyBookedCount = 0;
    int availableCount = 0;

    List<String> fullyBookedTables = [];
    List<String> partiallyBookedTables = [];
    List<String> availableTables = [];

    for (var area in tables) {
      for (var table in area['tables'] as List<Map<String, dynamic>>) {
        final tableNumber = table['tableNumber'].toString();
        final seats = table['seats'];

        final activeOrders = orderProvider.orders
            .where((order) =>
                order['table'].toString() == tableNumber &&
                (order['status'] == 'active' || order['status'] == 'confirm'))
            .toList();

        final Set<String> bookedSeats =
            activeOrders.map((order) => order['seat'] as String).toSet();

        final int uniqueBookedSeats = bookedSeats.length;

        if (uniqueBookedSeats == seats) {
          fullyBookedCount++;
          fullyBookedTables.add(tableNumber.toString());
        } else if (uniqueBookedSeats > 0) {
          partiallyBookedCount++;
          partiallyBookedTables.add(tableNumber.toString());
        } else {
          availableCount++;
          availableTables.add(tableNumber.toString());
        }
      }
    }

    // _sendTableStatus(fullyBookedCount, partiallyBookedCount, availableCount,
    //     fullyBookedTables, partiallyBookedTables, availableTables);
    return Scaffold(
      appBar: GlobalAppBar(
        title: ' KOT  Tables ',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              orderProvider.requestDataFromServer();
            },
            tooltip: 'Refresh',
          ),
          // Text(serverIP,
          //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          // SizedBox(height: 20),
          // ElevatedButton(
          //   onPressed: fetchServerIP,
          //   child: Text('Server'),
          // ),
        ],
      ),
      body: Column(
        children: [
          // Booking counts and legend with indicators
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendIndicatorWithCount(
                    const Color(0xFFFD563F), "Fully Booked", fullyBookedCount),
                _buildLegendIndicatorWithCount(const Color(0xFFFFB74D),
                    "Partially Booked", partiallyBookedCount),
                _buildLegendIndicatorWithCount(
                    const Color(0xFFA5D6A7), "Available", availableCount),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListView.builder(
                itemCount: tables.length,
                itemBuilder: (context, areaIdx) {
                  final area = tables[areaIdx];
                  final areaName = area['areaName'] as String? ?? 'Unnamed';
                  final areaTables =
                      (area['tables'] as List?)?.cast<Map<String, dynamic>>() ??
                          [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Area header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: Text(areaName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),

                      // ── Plain list of that area's tables
                      ...areaTables.map(
                        (tbl) => ListTile(
                          title: Text('Table ${tbl['tableNumber']}'),
                          subtitle: Text('${tbl['seats']} seats'),
                          onTap: () {
                            // quick demo tap handler
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    'Tapped table ${tbl['tableNumber']}')));
                          },
                        ),
                      ),
                      const Divider(thickness: 1),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      //bottomNavigationBar: const GlobalBottomNav(),
    );
  }

// Legend Indicator with Count Widget
  Widget _buildLegendIndicatorWithCount(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "$label:",
          style: const TextStyle(fontSize: 10),
        ),
        Text(
          "$count",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _sendTableStatus(
      int fullyBookedCount,
      int partiallyBookedCount,
      int availableCount,
      List<String> fullyBookedTables,
      List<String> partiallyBookedTables,
      List<String> availableTables) {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);
    final formattedTime = DateFormat('hh:mm:ss a').format(now);
    final data = {
      "action": "kotTableStatusUpdated",
      "fullyBookedSeatCount": fullyBookedCount,
      "partiallyBookedSeatCount": partiallyBookedCount,
      "availableSeatCount": availableCount,
      "fullyBookedTables": fullyBookedTables,
      "partiallyBookedTables": partiallyBookedTables,
      "availableTables": availableTables,
      "branchName": branchName,
      "status": "kotTableStatusUpdated",
      "updatedDate": formattedDate,
      "updatedTime": formattedTime,
    };

    channel!.sink.add(jsonEncode(data));
  }
}

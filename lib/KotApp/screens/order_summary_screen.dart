import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../kotproviders/login_provider.dart';
import '../kotproviders/order_provider.dart';
import '../widgets/bottomNav.dart';
import '../widgets/circularLoadingindicator.dart';
import '../widgets/globalAppbar.dart';
import '../widgets/ordersSummary/orders_ Card.dart';

class OrderSummaryScreen extends StatefulWidget {
  const OrderSummaryScreen({super.key});

  @override
  _OrderSummaryScreenState createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeProvider();
  }

  Future<void> initializeProvider() async {
    final orderDataProvider =
        Provider.of<OrderProvider>(context, listen: false);
    orderDataProvider.requestDataFromServer();

    setState(() {
      _isLoading = false;
    });
  }

  // Map to track selected seat per table
  Map<String, String?> selectedSeatMap = {};

  @override
  Widget build(BuildContext context) {

    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    final loggedInUserName = loginProvider.loggedInUserName ?? "";

    if (_isLoading) {
      return Scaffold(
        appBar: const GlobalAppBar(title: '--Orders Summary--'),
        body: Center(child: CircularLoadingIndicator()),
      );
    }

    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final orders = orderProvider.orders
            .where((order) =>
                order['status'] == "active" &&
                order['status'] != "invoiced" &&
                order['status'] != "cancelled")
            .toList();

        final Map<String, Set<String>> tableseats = {};
        for (var order in orders) {
          final String tableNumber = order['table'].toString();
          final String seat = order['seat'];
          tableseats.putIfAbsent(tableNumber, () => {}).add(seat);
        }

        final sortedTables = tableseats.keys.toList()
          ..sort((a, b) {
            final RegExp regExp = RegExp(r'\d+');
            final int numA =
                int.tryParse(regExp.firstMatch(a)?.group(0) ?? '0') ?? 0;
            final int numB =
                int.tryParse(regExp.firstMatch(b)?.group(0) ?? '0') ?? 0;
            return numA.compareTo(numB);
          });

        return Scaffold(
          appBar: const GlobalAppBar(title: '------ Order Summary ------'),
          body: Container(
            color: const Color(0xFFDBF0F7), // Background color
            child: ListView.builder(
              itemCount: sortedTables.length,
              itemBuilder: (context, index) {
                final tableNumber = sortedTables[index];
                final seats = tableseats[tableNumber]!.toList()..sort();
                double tableTotal = seats.fold(
                  0.0,
                  (previousValue, seat) {
                    final cancelledOrders = orderProvider
                        .getRunningOrdersForSeat(tableNumber, seat)
                        .where((order) => order['status'] == 'active')
                        .toList();
                    // Sum the totalAmount field
                    final seatTotal = cancelledOrders.fold(0.0, (sum, order) {
                      return sum + (order['totalAmount'] ?? 0.0);
                    });

                    return previousValue + seatTotal;
                  },
                );
                return Card(
                  margin: const EdgeInsets.all(10.0),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor:
                          Colors.transparent, // Makes dividers transparent
                    ),
                    child: ExpansionTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ' $tableNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[300],
                            ),
                          ),
                          Text(
                            'Total : $tableTotal',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[300],
                            ),
                          ),
                        ],
                      ),
                      children: seats.map((seat) {
                        bool isSelected = selectedSeatMap[tableNumber] == seat;

                        final seatOrders = orderProvider
                            .getActiveOrdersForSeat(tableNumber, seat)
                            .where((order) => order['status'] == "active")
                            .toList();

                        final seatTotal = seatOrders.fold(0.0, (sum, order) {
                          return sum + (order['totalAmount'] ?? 0.0);
                        });

                        return Column(
                          children: [
                            ListTile(
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Seat $seat',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.green[300]
                                            : Colors.black54),
                                  ),
                                  Text(
                                    'Total : $seatTotal',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.green[300]
                                            : Colors.black54),
                                  ),
                                ],
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.expand_less,
                                      color: Colors.green)
                                  : const Icon(Icons.expand_more),
                              onTap: () {
                                setState(() {
                                  if (selectedSeatMap[tableNumber] == seat) {
                                    selectedSeatMap[tableNumber] = null;
                                  } else {
                                    selectedSeatMap[tableNumber] = seat;
                                  }
                                });
                              },
                            ),
                            if (isSelected) ...[
                              OrderSummaryCard(
                                tableNumber: tableNumber,
                                seat: seat,
                                seatOrders: seatOrders,
                                seatTotal: seatTotal,
                                waiter: seatOrders.isNotEmpty
                                    ? seatOrders.first['waiter']
                                    : '',
                                loggedInUserName: loggedInUserName,
                              ),
                            ],
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
          //bottomNavigationBar: const GlobalBottomNav(),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
import 'package:yenpos/Global/globals_data.dart';
import '../providers/login_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/bottomNav.dart';
import '../components/circularLoadingindicator.dart';
import '../components/globalAppbar.dart';
import '../widgets/ordersSummary/orders_ Card.dart';
import 'customerScreen file/seat_transfer.dart';

// 🔔 ChangeNotifier to manage OrderSummaryScreen state
class OrderSummaryState extends ChangeNotifier {
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, String?> _selectedSeatMap = {};
  final BuildContext context;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, String?> get selectedSeatMap => _selectedSeatMap;

  OrderSummaryState(this.context) {
    _initialize(); // 🚀 Automatically start initialization
  }

  Future<void> _initialize() async {
    debugPrint('🚀 OrderSummaryState initialized.');
    await initializeProvider();
  }

  // 📡 Fetch data from server with error handling and debug logs
  Future<void> initializeProvider() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('📡 Fetching order data from server...');
      final orderDataProvider = Provider.of<OrderProvider>(context, listen: false);

      if (appType != "server") {
        await orderDataProvider.requestDataFromServer();
        debugPrint('✅ Order data successfully fetched.');
      } else {
        debugPrint('⚙️ App type is "server" — skipping remote fetch.');
      }

      _isLoading = false;
      _errorMessage = null;
    } catch (e, st) {
      _isLoading = false;
      _errorMessage = '❌ Failed to load orders: $e';
      debugPrint('❌ Exception in initializeProvider: $e\n$st');
    } finally {
      notifyListeners();
    }
  }

  // 🪑 Toggle seat selection for a table
  void toggleSeatSelection(String tableNumber, String seat) {
    try {
      if (_selectedSeatMap[tableNumber] == seat) {
        debugPrint('🔄 Unselecting seat $seat at table $tableNumber');
        _selectedSeatMap[tableNumber] = null;
      } else {
        debugPrint('✅ Selecting seat $seat at table $tableNumber');
        _selectedSeatMap[tableNumber] = seat;
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('⚠️ Error toggling seat selection: $e\n$st');
    }
  }
}

class OrderSummaryScreen extends StatelessWidget {
  const OrderSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🧭 Building OrderSummaryScreen...');
    return ChangeNotifierProvider(
      create: (ctx) => OrderSummaryState(ctx),
      child: Consumer<OrderSummaryState>(
        builder: (context, state, _) {
          final loginProvider = Provider.of<LoginProvider>(context, listen: false);
          final loggedInUserName = loginProvider.loggedInUserName ?? "";

          if (state.isLoading) {
            debugPrint('⏳ Orders are loading...');
            return const Scaffold(
              appBar: GlobalAppBar(title: '--Orders Summary--'),
              body: Center(child: CircularLoadingIndicator()),
            );
          }

          if (state.errorMessage != null) {
            debugPrint('🚨 Error in OrderSummaryState: ${state.errorMessage}');
            return Scaffold(
              appBar: const GlobalAppBar(title: '--Orders Summary--'),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        debugPrint('🔁 Retrying order fetch...');
                        await state.initializeProvider();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // 📊 Build UI after successful data load
          return Consumer<OrderProvider>(
            builder: (context, orderProvider, _) {
              try {
                final orders = orderProvider.orders.where((order) => order['status'] == "active" && order['status'] != "invoiced" && order['status'] != "cancelled").toList();

                debugPrint('📋 Loaded ${orders.length} active orders.');

                // 🟡 Show "No orders placed" if empty
                if (orders.isEmpty) {
                  return const Scaffold(
                    backgroundColor: Colors.white,
                    appBar: GlobalAppBar(title: 'Kot Order Summary'),
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No orders placed yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    bottomNavigationBar: GlobalBottomNav(),
                  );
                }

                final Map<String, Set<String>> tableseats = {};
                for (var order in orders) {
                  final String actualTableNumber = order['table'].toString();
                  final String baseTableNumber = actualTableNumber.replaceAll(RegExp(r'\([A-Z]\)$'), '');
                  final String seat = order['seat'];
                  tableseats.putIfAbsent(baseTableNumber, () => {}).add(seat);
                }

                final sortedTables = tableseats.keys.toList()
                  ..sort((a, b) {
                    final RegExp regExp = RegExp(r'\d+');
                    final int numA = int.tryParse(regExp.firstMatch(a)?.group(0) ?? '0') ?? 0;
                    final int numB = int.tryParse(regExp.firstMatch(b)?.group(0) ?? '0') ?? 0;
                    return numA.compareTo(numB);
                  });

                return Scaffold(
                  backgroundColor: Colors.white,
                  appBar: const GlobalAppBar(title: 'Kot Order Summary'),
                  body: ListView.builder(
                    itemCount: sortedTables.length,
                    itemBuilder: (context, index) {
                      final tableNumber = sortedTables[index];
                      final seats = tableseats[tableNumber]!.toList()..sort();

                      double tableTotal = seats.fold(
                        0.0,
                        (previousValue, seat) {
                          final seatOrders = orderProvider.orders
                              .where((order) => order['status'] == 'active' && order['seat'] == seat && order['table'].toString().replaceAll(RegExp(r'\([A-Z]\)$'), '') == tableNumber)
                              .toList();

                          final seatTotal = seatOrders.fold(0.0, (sum, order) {
                            return sum + (order['totalAmount'] ?? 0.0);
                          });

                          return previousValue + seatTotal;
                        },
                      );

                      return Card(
                        color: Colors.white,
                        shadowColor: Colors.grey.withOpacity(0.5),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(10.0),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(' $tableNumber', style: TextStyle(color: Colors.grey[800])),
                                Text('Total: ₹$tableTotal', style: const TextStyle(color: Colors.black87)),
                              ],
                            ),
                            children: seats.map((seat) {
                              bool isSelected = state.selectedSeatMap[tableNumber] == seat;

                              final seatOrders = orderProvider.orders
                                  .where((order) => order['status'] == "active" && order['seat'] == seat && order['table'].toString().replaceAll(RegExp(r'\([A-Z]\)$'), '') == tableNumber)
                                  .toList();

                              final seatTotal = seatOrders.fold(0.0, (sum, order) {
                                return sum + (order['totalAmount'] ?? 0.0);
                              });

                              return Column(
                                children: [
                                  ListTile(
                                    title: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Seat $seat'),
                                        Text('Total : ₹$seatTotal'),
                                      ],
                                    ),
                                    trailing: isSelected ? const Icon(Icons.expand_less, color: Colors.green) : const Icon(Icons.expand_more),
                                    onTap: () {
                                      state.toggleSeatSelection(tableNumber, seat);
                                    },
                                  ),
                                  if (isSelected)
                                    OrderSummaryCard(
                                      seathiveOrderId: seatOrders.first['seathiveOrderId'],
                                      tableNumber: tableNumber,
                                      seat: seat,
                                      seatOrders: seatOrders,
                                      seatTotal: seatTotal,
                                      waiter: seatOrders.isNotEmpty ? seatOrders.first['waiter'] : '',
                                      loggedInUserName: loggedInUserName,
                                      areaName: seatOrders.isNotEmpty && seatOrders.first['areaName'] != null ? seatOrders.first['areaName'] : getAreaNameForTable(tableNumber),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  bottomNavigationBar: const GlobalBottomNav(),
                );
              } catch (e, st) {
                debugPrint('💥 Error building OrderSummaryScreen UI: $e\n$st');
                return const Scaffold(
                  body: Center(
                    child: Text(
                      'An unexpected error occurred while building orders.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

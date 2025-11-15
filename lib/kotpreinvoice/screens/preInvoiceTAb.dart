import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
import '../components/flushbar.dart';
import '../providers/upi_provider.dart';
import '../components/time_formater.dart';
import 'package:yenpos/Global/globals_data.dart';
import '../components/globalAppbar.dart';
import 'package:provider/provider.dart';
import '../services/preInvociePrint_services.dart';
import '../models/printer.dart';
import '../providers/login_provider.dart';
import '../providers/order_provider.dart';
import '../providers/printer_provider.dart';
import '../widgets/bottomNav.dart';
import '../components/capitalizeWord.dart';
import '../widgets/salesInvoicePayandPrint.dart';
import 'customerScreen file/legend_item.dart';

// 🧮 Calculate total amount for a seat
double calculateSeatTotalAmount(
  List<dynamic> confirmedOrders,
  Map<String, dynamic> preInvoice,
) {
  // 📌 Filter orders for the specified seat and table
  final seatOrders = confirmedOrders
      .where(
        (order) =>
            order['seat'] == preInvoice['seat'] &&
            order['table'] == preInvoice['table'],
      )
      .toList();

  // 💰 Sum the totalAmount field
  final total = seatOrders.fold(0.0, (sum, order) {
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    return sum + totalAmount;
  });

  return total;
}

// 🔔 ChangeNotifier to manage PreInvoiceScreen state
class PreInvoiceState extends ChangeNotifier {
  String? _storedDeviceCode;
  String? _errorMessage;
  Timer? _timer;

  String? get storedDeviceCode => _storedDeviceCode;
  String? get errorMessage => _errorMessage;

  PreInvoiceState() {
    debugPrint('🟢 PreInvoiceState initialized');
    _initState();
  }

  // 🔹 Initialize data safely
  Future<void> _initState() async {
    try {
      await loadDeviceCode();
      startTimer();
    } catch (e, stack) {
      _errorMessage = 'Initialization failed: $e';
      debugPrint('❌ Error during initialization: $e');
      debugPrint(stack.toString());
      notifyListeners();
    }
  }

  // 📡 Load device code from Hive with error handling
  Future<void> loadDeviceCode() async {
    debugPrint('📥 Loading device code from Hive...');
    try {
      final box = await Hive.openBox('deviceData');
      final code = box.get('deviceCode', defaultValue: 'UnknownDevice');
      _storedDeviceCode = code?.toString();
      debugPrint('✅ Device code loaded: $_storedDeviceCode');
    } on HiveError catch (hiveError) {
      _errorMessage = 'Hive error: ${hiveError.message}';
      debugPrint('🚨 HiveError: ${hiveError.message}');
    } catch (e, stack) {
      _errorMessage = 'Failed to load device code: $e';
      debugPrint('❌ Exception while loading device code: $e');
      debugPrint(stack.toString());
    }
    notifyListeners();
  }

  // ⏲️ Start periodic timer to update UI
  void startTimer() {
    try {
      _timer?.cancel(); // Cancel previous timer if any
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        debugPrint(
          '⏱️ Timer tick: ${DateTime.now()} | Device: $_storedDeviceCode',
        );
        notifyListeners();
      });
      debugPrint('✅ Timer started successfully');
    } catch (e, stack) {
      _errorMessage = 'Failed to start timer: $e';
      debugPrint('❌ Error starting timer: $e');
      debugPrint(stack.toString());
      notifyListeners();
    }
  }

  // 🧹 Clean up resources safely
  @override
  void dispose() {
    debugPrint('🧹 Disposing PreInvoiceState...');
    try {
      _timer?.cancel();
      debugPrint('🛑 Timer cancelled successfully');
    } catch (e, stack) {
      debugPrint('⚠️ Error cancelling timer: $e');
      debugPrint(stack.toString());
    }
    super.dispose();
  }
}

class PreInvoiceScreen extends StatelessWidget {
  const PreInvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 Building PreInvoiceScreen...');

    return ChangeNotifierProvider(
      create: (_) {
        debugPrint('🆕 Creating PreInvoiceState provider...');
        return PreInvoiceState();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: GlobalAppBar(
            title: '---Confirmed Orders---',
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBBDEFB),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.blue,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorColor: Colors.transparent,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt, size: 18),
                          SizedBox(width: 2),
                          Text("Make Invoice"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.print, size: 18),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "RePrint Pre-Invoices",
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Consumer<PreInvoiceState>(
            builder: (context, state, _) {
              debugPrint(
                '🔄 Consumer rebuild triggered | '
                'DeviceCode: ${state.storedDeviceCode} | '
                'Error: ${state.errorMessage}',
              );

              // 🚨 Error state
              if (state.errorMessage != null) {
                debugPrint('❌ Displaying error UI: ${state.errorMessage}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          debugPrint('🔁 Retry button pressed');
                          await state.loadDeviceCode();
                        },
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              // ⏳ Loading state
              if (state.storedDeviceCode == null) {
                debugPrint('⏳ Device code still loading...');
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.blue,
                    strokeWidth: 3,
                  ),
                );
              }

              // ✅ Success state
              debugPrint(
                '✅ Device code loaded successfully: ${state.storedDeviceCode}',
              );
              return TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  InvoiceList(storedDeviceCode: state.storedDeviceCode),
                  PreInvoiceList(storedDeviceCode: state.storedDeviceCode),
                ],
              );
            },
          ),
          bottomNavigationBar: const GlobalBottomNav(),
        ),
      ),
    );
  }
}

class PreInvoiceList extends StatelessWidget {
  final String? storedDeviceCode;

  const PreInvoiceList({super.key, required this.storedDeviceCode});

  @override
  Widget build(BuildContext context) {
    debugPrint('🧾 Building PreInvoiceList | Device: $storedDeviceCode');

    final orderProvider = Provider.of<OrderProvider>(context);
    final printerProvider = Provider.of<PrinterProviderDine>(context);
    final loginProvider = Provider.of<LoginProvider>(context);
    final loggedInUserName = loginProvider.loggedInUserName ?? "Unknown User";

    // Defensive null check
    if (orderProvider.orders.isEmpty) {
      debugPrint('⚠️ No orders found in OrderProvider.');
      return const Center(child: Text('No confirmed orders available.'));
    }

    // Filter confirmed orders safely
    final confirmedOrders = orderProvider.orders
        .where(
          (order) => order['status']?.toString().toLowerCase() == 'confirm',
        )
        .toList();

    debugPrint('📦 Confirmed Orders Count: ${confirmedOrders.length}');

    if (confirmedOrders.isEmpty) {
      return const Center(child: Text('No confirmed pre-invoices found.'));
    }

    // Group by table
    final Map<String, List<dynamic>> groupedPreInvoices = {};
    String waiter = "";

    try {
      for (var preInvoice in confirmedOrders) {
        final tableNumber = preInvoice['table']?.toString() ?? 'Unknown';
        waiter = preInvoice['waiter']?.toString() ?? 'Unknown';

        groupedPreInvoices.putIfAbsent(tableNumber, () => []);
        groupedPreInvoices[tableNumber]!.add(preInvoice);
      }
      debugPrint('✅ Grouped pre-invoices by table: ${groupedPreInvoices.keys}');
    } catch (e, stack) {
      debugPrint('❌ Error grouping pre-invoices: $e');
      debugPrint(stack.toString());
      return Center(child: Text('Error grouping invoices: $e'));
    }

    // Sort by table number numerically
    final sortedTableNumbers = groupedPreInvoices.keys.toList()
      ..sort((a, b) {
        final regExp = RegExp(r'\d+');
        final numA = int.tryParse(regExp.firstMatch(a)?.group(0) ?? '0') ?? 0;
        final numB = int.tryParse(regExp.firstMatch(b)?.group(0) ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

    debugPrint('📋 Sorted Table Numbers: $sortedTableNumbers');

    return ListView(
      padding: const EdgeInsets.all(10.0),
      children: sortedTableNumbers.map((tableNumber) {
        final tablePreInvoices = groupedPreInvoices[tableNumber]!;
        final uniqueSeats = <String>{};
        debugPrint(
          '📂 Rendering table: $tableNumber | Invoices: ${tablePreInvoices.length}',
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 20.0),
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.0),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$tableNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              ...tablePreInvoices
                  .where((preInvoice) {
                    final seat = preInvoice['seat'] ?? 'Unknown';
                    if (uniqueSeats.contains(seat)) {
                      debugPrint('⚠️ Duplicate seat skipped: $seat');
                      return false;
                    }
                    uniqueSeats.add(seat);
                    return true;
                  })
                  .map((preInvoice) {
                    final seat = preInvoice['seat'] ?? 'Unknown';
                    final seatOrders = confirmedOrders
                        .where(
                          (order) =>
                              order['seat'] == preInvoice['seat'] &&
                              order['table'] == preInvoice['table'],
                        )
                        .toList();

                    double total = 0;
                    try {
                      total = calculateSeatTotalAmount(
                        confirmedOrders,
                        preInvoice,
                      );
                    } catch (e, stack) {
                      debugPrint(
                        '⚠️ Failed to calculate total for seat $seat: $e',
                      );
                      debugPrint(stack.toString());
                    }

                    return Card(
                      margin: const EdgeInsets.all(10.0),
                      color: const Color(0xFFF4FDFF),
                      child: ExpansionTile(
                        title: Text(
                          'SEAT $seat',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (seatOrders.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: seatOrders.map((order) {
                                      final orderIndex =
                                          seatOrders.indexOf(order) + 1;
                                      final tokenNo = order['tokenNo'] ?? 'N/A';
                                      final itemCount =
                                          order['itemNames']?.length ?? 0;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Order $orderIndex: Token No $tokenNo ($itemCount Items)',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Divider(),
                                          if (itemCount == 0)
                                            const Text(
                                              'No items found for this order.',
                                            ),
                                          if (itemCount > 0)
                                            Table(
                                              columnWidths: const {
                                                0: FlexColumnWidth(2),
                                                1: FlexColumnWidth(1),
                                                2: FlexColumnWidth(1),
                                              },
                                              children: [
                                                const TableRow(
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.all(
                                                        4.0,
                                                      ),
                                                      child: Text(
                                                        'Item Details',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsets.all(
                                                        4.0,
                                                      ),
                                                      child: Text(
                                                        'Qty',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsets.all(
                                                        4.0,
                                                      ),
                                                      child: Text(
                                                        'Amt',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                for (
                                                  int i = 0;
                                                  i < itemCount;
                                                  i++
                                                )
                                                  TableRow(
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4.0,
                                                            ),
                                                        child: Text(
                                                          capitalizeWords(
                                                            order['varianceNames'][i],
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            decoration:
                                                                order['quantities'][i] ==
                                                                    0
                                                                ? TextDecoration
                                                                      .lineThrough
                                                                : null,
                                                            color:
                                                                order['quantities'][i] ==
                                                                    0
                                                                ? Colors.red
                                                                : Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4.0,
                                                            ),
                                                        child: Text(
                                                          '${order['quantities'][i].toStringAsFixed(0)}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                order['quantities'][i] ==
                                                                    0
                                                                ? Colors.red
                                                                : Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4.0,
                                                            ),
                                                        child: Text(
                                                          '${order['amounts'][i].toStringAsFixed(0)}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                order['quantities'][i] ==
                                                                    0
                                                                ? Colors.red
                                                                : Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                        ],
                                      );
                                    }).toList(),
                                  )
                                else
                                  const Text('No orders found for this seat.'),
                                const SizedBox(height: 10),
                                Text(
                                  'Total: ₹${total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    _showReprintDialog(
                                      context,
                                      preInvoice,
                                      seatOrders,
                                      printerProvider,
                                      loggedInUserName,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: const Color(0xFFA5D6A7),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    'RePrint PreInvoice',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showReprintDialog(
    BuildContext context,
    dynamic preInvoice,
    List<dynamic> seatOrders,
    PrinterProviderDine printerProvider,
    String loggedInUserName,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Confirm Re-Print",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Are you sure you want to reprint the Pre-Invoice?",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        "Confirm Re-Print",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      content: const Text(
                        "Are you sure you want to reprint the Pre-Invoice?",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      actionsPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop(); // Cancel
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: const BorderSide(
                              color: Colors.blue,
                              width: 1,
                            ), // 🔵 Blue theme
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            "CANCEL",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue, // 🔵 Blue theme
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop(); // Close dialog

                            try {
                              final preInvoicePrinter = printerProvider.printers
                                  .firstWhere(
                                    (printer) => printer.type == 'PreInvoice',
                                    orElse: () => Printer(
                                      name: 'default_printer_name',
                                      ipAddress: 'default_ip',
                                      type: 'default_type',
                                    ),
                                  );

                              await InvoicePrinter.printReceipt(
                                ipAddress: preInvoicePrinter.ipAddress,
                                tableNumber: preInvoice['table'],
                                seat: preInvoice['seat'],
                                waiter: preInvoice['waiter'],
                                userName: loggedInUserName,
                                seatOrders: seatOrders,
                                areaName: preInvoice['areaName'] ?? 'Unknown',
                                invoiceNo: preInvoice['invoiceNo'] ?? '',
                              );

                              // 🔔 Success feedback
                              if (context.mounted) {
                                showCustomFlushbar(
                                  context,
                                  'Pre-Invoice reprinted successfully!',
                                  type: FlushbarType.success,
                                );
                              }
                            } catch (e) {
                              debugPrint('❌ Print error: $e');
                              if (context.mounted) {
                                showCustomFlushbar(
                                  context,
                                  'Failed to reprint Pre-Invoice: $e',
                                  type: FlushbarType.error,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, // 🔵 Blue theme
                            foregroundColor:
                                Colors.white, // 🔵 White text for contrast
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            "CONFIRM",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                backgroundColor: Colors.blue, // 🔵 Blue theme
              ),
              child: const Text(
                'RePrint PreInvoice',
                style: TextStyle(color: Colors.white), // 🔵 White text
              ),
            ),
          ],
        );
      },
    );
  }
}

class InvoiceList extends StatelessWidget {
  final String? storedDeviceCode;

  const InvoiceList({super.key, required this.storedDeviceCode});

  @override
  Widget build(BuildContext context) {
    return Consumer<PreInvoiceState>(
      builder: (context, state, _) {
        try {
          final orderProvider = Provider.of<OrderProvider>(context);
          String areaName = '';

          if (orderProvider.orders.isEmpty) {
            debugPrint('⚠️ No orders found in OrderProvider.');
            return const Center(child: Text('No confirmed orders available.'));
          }

          // 📌 Filter orders safely
          final confirmedOrders = orderProvider.orders
              .where((order) => order['status'] == 'confirm')
              .toList();

          debugPrint('✅ Found ${confirmedOrders.length} confirmed orders.');

          // 📊 Group orders by area and table
          final Map<String, Map<String, List<dynamic>>> groupedByArea = {};
          for (var order in confirmedOrders) {
            try {
              areaName = order['areaName'] ?? 'Unknown Area';
              final tableNumber = order['table'] ?? 'Unknown Table';
              groupedByArea.putIfAbsent(areaName, () => {});
              groupedByArea[areaName]!.putIfAbsent(tableNumber, () => []);
              groupedByArea[areaName]![tableNumber]!.add(order);
            } catch (e) {
              debugPrint('❌ Error grouping order: $e');
            }
          }

          if (groupedByArea.isEmpty) {
            debugPrint('⚠️ Grouped data is empty after filtering.');
            return const Center(child: Text('No confirmed orders to show.'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    buildLegendIndicatorForSeconds(
                      const Color.fromARGB(255, 139, 209, 141),
                      "0–2 min",
                    ),
                    buildLegendIndicatorForSeconds(
                      const Color(0xFFFFB74D),
                      "3–6 min",
                    ),
                    buildLegendIndicatorForSeconds(
                      const Color.fromARGB(255, 247, 103, 84),
                      "6+ min",
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(10.0),
                  itemCount: groupedByArea.keys.length,
                  itemBuilder: (context, areaIndex) {
                    try {
                      areaName = groupedByArea.keys.elementAt(areaIndex);
                      final tableMap = groupedByArea[areaName]!;
                      final List<dynamic> areaOrders = tableMap.values
                          .expand((e) => e)
                          .toList();

                      // 📌 Remove duplicate seats
                      final uniqueSeatKeys = <String>{};
                      final filteredAreaOrders = areaOrders.where((order) {
                        final key = '${order['table']}-${order['seat']}';
                        return uniqueSeatKeys.add(key);
                      }).toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20.0),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              areaName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        MediaQuery.of(context).size.width > 600
                                        ? 4
                                        : 3,
                                    childAspectRatio: 1.1,
                                    crossAxisSpacing: 10.0,
                                    mainAxisSpacing: 10.0,
                                  ),
                              itemCount: filteredAreaOrders.length,
                              itemBuilder: (context, index) {
                                try {
                                  final invoice = filteredAreaOrders[index];
                                  final seat = invoice['seat'] ?? '';
                                  final tableNumber = invoice['table'] ?? '';
                                  final seatOrders = areaOrders
                                      .where(
                                        (o) =>
                                            o['seat'] == seat &&
                                            o['table'] == tableNumber,
                                      )
                                      .toList();

                                  final preinvoiceTime =
                                      invoice['preinvoiceTime'] ?? '';
                                  double total = calculateSeatTotalAmount(
                                    areaOrders,
                                    invoice,
                                  );

                                  int elapsedSeconds = preinvoiceTime.isNotEmpty
                                      ? calculateElapsedTime(preinvoiceTime)
                                      : 0;
                                  String formattedElapsedTime =
                                      formatElapsedTime(elapsedSeconds);
                                  Color cardColor = getCardColor(
                                    elapsedSeconds,
                                  );

                                  return GestureDetector(
                                    onTap: () async {
                                      final upiProvider =
                                          Provider.of<UpiProviderDine>(
                                            context,
                                            listen: false,
                                          );
                                      if (upiProvider.isUpiEnabled) {
                                        try {
                                          debugPrint(
                                            '🧾 Opening invoice for $tableNumber - Seat $seat',
                                          );
                                          final double totalAmount = total;

                                          // 🧠 Convert every order map safely to Map<String, dynamic>
                                          final List<Map<String, dynamic>>
                                          items = seatOrders.map<Map<String, dynamic>>((
                                            order,
                                          ) {
                                            try {
                                              final computedAmounts = List.generate(
                                                (order['prices'] as List?)
                                                        ?.length ??
                                                    0,
                                                (i) =>
                                                    ((order['prices']?[i] ??
                                                                0.0)
                                                            as num)
                                                        .toDouble() *
                                                    ((order['quantities']?[i] ??
                                                                0.0)
                                                            as num)
                                                        .toDouble(),
                                              );

                                              final mappedOrder =
                                                  <String, dynamic>{
                                                    'itemName':
                                                        order['itemNames'] ??
                                                        [],
                                                    'varianceName':
                                                        order['varianceNames'] ??
                                                        [],
                                                    'qty':
                                                        order['quantities'] ??
                                                        [],
                                                    'weight':
                                                        order['weights'] ?? [],
                                                    'tax': order['taxes'] ?? [],
                                                    'uom': order['uoms'] ?? [],
                                                    'table':
                                                        order['table'] ?? '',
                                                    'seat': order['seat'] ?? '',
                                                    'hiveOrderId':
                                                        order['hiveOrderId'] ??
                                                        '',
                                                    'waiter':
                                                        order['waiter'] ?? '',
                                                    'price':
                                                        order['prices'] ?? [],
                                                    'amount': computedAmounts,
                                                  };

                                              debugPrint(
                                                '✅ Mapped order successfully: ${mappedOrder['itemName']}',
                                              );
                                              return mappedOrder;
                                            } catch (e, st) {
                                              debugPrint(
                                                '⚠️ Error mapping order item: $e\n$st',
                                              );
                                              return <String, dynamic>{};
                                            }
                                          }).toList();

                                          debugPrint(
                                            '📦 Prepared ${items.length} items for invoice.',
                                          );

                                          if (context.mounted) {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    SalesInvoicePayAndPrint(
                                                      totalAmount: totalAmount,
                                                      items:
                                                          items, // ✅ Now properly typed
                                                      branchName: branchName,
                                                      deviceCode:
                                                          state
                                                              .storedDeviceCode ??
                                                          '',
                                                    ),
                                              ),
                                            );
                                          }
                                        } catch (e, st) {
                                          debugPrint(
                                            '❌ Error opening invoice: $e\n$st',
                                          );
                                          if (context.mounted) {
                                            showCustomFlushbar(
                                              context,
                                              'Failed to open invoice: $e',
                                              type: FlushbarType.error,
                                            );
                                          }
                                        }
                                      } else {
                                        debugPrint('⚠️ UPI is disabled.');
                                        if (context.mounted) {
                                          showCustomFlushbar(
                                            context,
                                            'Please enable UPI to proceed.',
                                            type: FlushbarType.error,
                                          );
                                        }
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(5.0),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '$tableNumber',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          Text(
                                            'Seat $seat',
                                            style: const TextStyle(
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            '₹${total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            formattedElapsedTime,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } catch (e, st) {
                                  debugPrint(
                                    '❌ Error building grid item: $e\n$st',
                                  );
                                  return const SizedBox.shrink();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    } catch (e, st) {
                      debugPrint('❌ Error building area section: $e\n$st');
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ],
          );
        } catch (e, st) {
          debugPrint('🔥 Critical error in InvoiceList: $e\n$st');
          return const Center(
            child: Text('Something went wrong while loading invoices.'),
          );
        }
      },
    );
  }
}

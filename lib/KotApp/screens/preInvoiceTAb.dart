import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../screens/kot_screen/global/globals.dart';
import '../widgets/globalAppbar.dart';
import '../widgets/time_formater.dart';

import 'package:provider/provider.dart';
import '../kotservices/preInvociePrint_services.dart';
import '../models/printer.dart';
import '../kotproviders/login_provider.dart';
import '../kotproviders/order_provider.dart';
import '../kotproviders/printer_provider.dart';
import '../widgets/bottomNav.dart';
import '../widgets/capitalizeWord.dart';
import '../widgets/salesInvoicePayandPrint.dart';

double calculateSeatTotalAmount(
    List<dynamic> confirmedOrders, Map<String, dynamic> preInvoice) {
  // Filter orders for the specified seat and table
  final seatOrders = confirmedOrders
      .where((order) =>
          order['seat'] == preInvoice['seat'] &&
          order['table'] == preInvoice['table'])
      .toList();

  // Sum the totalAmount field
  final total = seatOrders.fold(0.0, (sum, order) {
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    return sum + totalAmount;
  });

  return total;
}

class PreInvoiceScreen extends StatefulWidget {
  const PreInvoiceScreen({super.key});

  @override
  _PreInvoiceScreenState createState() => _PreInvoiceScreenState();
}

class _PreInvoiceScreenState extends State<PreInvoiceScreen> {
  String? storedDeviceCode;
  @override
  @override
  void initState() {
    super.initState();
    loadDeviceCode();
  }

  Future<void> loadDeviceCode() async {
    var box = await Hive.openBox('deviceData');
    setState(() {
      storedDeviceCode = box.get('deviceCode', defaultValue: 'UnknownDevice');
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const GlobalAppBar(
          title: '---Confirmed Orders---',
          bottom: TabBar(
            tabs: [
              Tab(text: 'Make Invoice'),
              Tab(text: 'RePrint Pre-Invoices'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            InvoiceList(
              storedDeviceCode: storedDeviceCode,
            ),
            PreInvoiceList(
              storedDeviceCode: storedDeviceCode,
            ),
          ],
        ),
        //bottomNavigationBar: const GlobalBottomNav(),
      ),
    );
  }
}

class PreInvoiceList extends StatelessWidget {
  final String? storedDeviceCode;

  const PreInvoiceList({super.key, required this.storedDeviceCode});
  final bool _isButtonDisabled = false; // Track button state

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final printerProvider = Provider.of<PrinterProvider>(context);
    final loginProvider = Provider.of<LoginProvider>(context);
    final loggedInUserName = loginProvider.loggedInUserName ?? "Unknown User";
    final confirmedOrders = orderProvider.orders
        .where((order) => order['status'] == 'confirm'
            //&&
            // order['deviceId'] == storedDeviceCode
            )
        .toList();
    String waiter = "";
    // Group pre-invoices by table number
    Map<String, List<dynamic>> groupedPreInvoices = {};
    for (var preInvoice in confirmedOrders) {
      final tableNumber = preInvoice['table']?.toString() ?? 'Unknown';
      waiter = preInvoice['waiter']?.toString() ?? 'Unknown';

      if (groupedPreInvoices[tableNumber] == null) {
        groupedPreInvoices[tableNumber] = [];
      }
      groupedPreInvoices[tableNumber]?.add(preInvoice);
    }
    final sortedTableNumbers = groupedPreInvoices.keys.toList()
      ..sort((a, b) {
        final RegExp regExp = RegExp(r'\d+'); // Extract numbers
        final int numA =
            int.tryParse(regExp.firstMatch(a)?.group(0) ?? '0') ?? 0;
        final int numB =
            int.tryParse(regExp.firstMatch(b)?.group(0) ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

    return ListView(
      padding: const EdgeInsets.all(10.0),
      children: sortedTableNumbers.map((tableNumber) {
        final tablePreInvoices = groupedPreInvoices[tableNumber]!;
        final uniqueSeats = <String>{};

        return Container(
          margin: const EdgeInsets.only(bottom: 20.0),
          padding: const EdgeInsets.all(10.0),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$tableNumber',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ...tablePreInvoices.where((preInvoice) {
                final seat = preInvoice['seat'] ?? 'Unknown';

                // Check if seat is already displayed; skip if duplicate
                if (uniqueSeats.contains(seat)) {
                  return false;
                }
                uniqueSeats.add(seat); // Mark this seat as displayed
                return true;
              }).map((preInvoice) {
                // Continue with UI for each unique seat as before
                final seatOrders = confirmedOrders
                    .where((order) =>
                        order['seat'] == preInvoice['seat'] &&
                        order['table'] == preInvoice['table'])
                    .toList();

                //   final preInvoiceId = preInvoice['preInvoiceId'];
                final seat = preInvoice['seat'] ?? '';
                double total =
                    calculateSeatTotalAmount(confirmedOrders, preInvoice);
                return Card(
                  margin: const EdgeInsets.all(10.0),
                  color: const Color(0xFFF4FDFF),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor:
                          Colors.transparent, // Makes dividers transparent
                    ),
                    child: ExpansionTile(
                      title: Text('SEAT $seat',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (seatOrders.isNotEmpty) ...[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: seatOrders.map<Widget>((order) {
                                    int orderIndex =
                                        seatOrders.indexOf(order) + 1;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        //    Text(order['status']),
                                        Text(
                                            'Order $orderIndex: Token No ${order['tokenNo']}: (${order['itemNames']?.length ?? 0} Items)',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                        const Divider(),
                                        Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(2),
                                            1: FlexColumnWidth(1),
                                            2: FlexColumnWidth(1),
                                            3: FlexColumnWidth(1),
                                          },
                                          children: [
                                            const TableRow(children: [
                                              Padding(
                                                padding: EdgeInsets.all(4.0),
                                                child: Text('Item Details',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(4.0),
                                                child: Text('Qty',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(4.0),
                                                child: Text('Amt',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            ]),
                                            for (int i = 0;
                                                i < order['itemNames']?.length;
                                                i++)
                                              TableRow(children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(4.0),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '${capitalizeWords(order['varianceNames'][i])}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      if (order['prices'][i] >
                                                              0 &&
                                                          order['weights'][i] >
                                                              0)
                                                        Text(
                                                          '(₹${order['prices'][i].toStringAsFixed(0)} / ${order['weights'][i]} kg)',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      if (order['prices'][i] >
                                                              0 &&
                                                          order['weights'][i] <=
                                                              0)
                                                        Text(
                                                          '(₹${order['prices'][i].toStringAsFixed(0)})',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      if (order['weights'][i] >
                                                              0 &&
                                                          order['prices'][i] <=
                                                              0)
                                                        Text(
                                                          '(${order['weights'][i]} kg)',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(4.0),
                                                  child: Text(
                                                    '${order['quantities'][i].toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                      fontSize:
                                                          12, // Set font size to 10
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(4.0),
                                                  child: Text(
                                                    '${order['amounts'][i].toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                      fontSize:
                                                          12, // Set font size to 10
                                                    ),
                                                  ),
                                                ),
                                              ]),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ] else
                                const Text('No items available.'),
                              const SizedBox(height: 10),
                              Text('Total: ₹$total',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () async {
                                  final preInvoicePrinter =
                                      printerProvider.printers.firstWhere(
                                    (printer) => printer.type == 'PreInvoice',
                                    orElse: () => Printer(
                                        name: 'default_printer_name',
                                        ipAddress: 'default_ip',
                                        type: 'default_type'),
                                  );

                                  await PreInvoicePrinter.printReceipt(
                                    ipAddress: preInvoicePrinter.ipAddress,
                                    tableNumber: preInvoice['table'],
                                    seat: preInvoice['seat'],
                                    waiter: preInvoice['waiter'],
                                    userName: loggedInUserName,
                                    seatOrders: seatOrders,
                                    receiptType: 'PreInvoice',
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFA5D6A7),
                                ),
                                child: const Text(
                                  'Print PreInvoice',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class InvoiceList extends StatefulWidget {
  final String? storedDeviceCode;

  const InvoiceList({super.key, required this.storedDeviceCode});

  @override
  // ignore: library_private_types_in_public_api
  _InvoiceListState createState() => _InvoiceListState();
}

class _InvoiceListState extends State<InvoiceList> {
  late Timer _timer;
  String? storedDeviceCode;

  @override
  void initState() {
    super.initState();
    // Update the UI every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // Force rebuild to update elapsed time
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final printerProvider = Provider.of<PrinterProvider>(context);

    // Filter orders with the status 'confirm'
    final confirmedOrders = orderProvider.orders
        .where((order) => order['status'] == 'confirm')
        .toList();

    // Group orders by table number
    Map<String, List<dynamic>> groupedInvoices = {};
    for (var invoice in confirmedOrders) {
      final tableNumber = invoice['table']?.toString() ?? 'Unknown';
      if (groupedInvoices[tableNumber] == null) {
        groupedInvoices[tableNumber] = [];
      }
      groupedInvoices[tableNumber]?.add(invoice);
    }

    final sortedTableNumbers = groupedInvoices.keys.toList()
      ..sort((a, b) {
        final RegExp regExp = RegExp(r'\d+'); // Extract numbers
        final int numA =
            int.tryParse(regExp.firstMatch(a)?.group(0) ?? '0') ?? 0;
        final int numB =
            int.tryParse(regExp.firstMatch(b)?.group(0) ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(10.0),
      itemCount: sortedTableNumbers.length,
      itemBuilder: (context, index) {
        final tableNumber = sortedTableNumbers[index];
        final tableInvoices = groupedInvoices[tableNumber]!;

        // Filter unique seats
        final uniqueSeats = <String>{};
        final filteredInvoices = tableInvoices.where((invoice) {
          final seat = invoice['seat'] ?? 'Unknown';
          return uniqueSeats.add(seat); // Add only unique seats
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
                '$tableNumber',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 10.0,
                ),
                itemCount: filteredInvoices.length,
                itemBuilder: (context, index) {
                  final invoice = filteredInvoices[index];
                  final seatOrders = confirmedOrders
                      .where((order) =>
                          order['seat'] == invoice['seat'] &&
                          order['table'] == invoice['table'])
                      .toList();
                  final seat = invoice['seat'] ?? 'Unknown';
                  final preinvoiceTime = invoice['preinvoiceTime'] ?? 'Unknown';
                  double total =
                      calculateSeatTotalAmount(confirmedOrders, invoice);
                  int elapsedSeconds = 0;
                  if (preinvoiceTime != '') {
                    try {
                      DateTime preInvoiceDateTime =
                          DateFormat('hh:mm:ss a').parse(preinvoiceTime);
                      DateTime now = DateTime.now();
                      elapsedSeconds =
                          now.difference(preInvoiceDateTime).inSeconds;
                    } catch (e) {
                      elapsedSeconds = 0; // Fallback if parsing fails
                    }
                  }
                  elapsedSeconds = preinvoiceTime.isNotEmpty
                      ? calculateElapsedTime(preinvoiceTime)
                      : 0;

// Format elapsed time for UI display
                  String formattedElapsedTime =
                      formatElapsedTime(elapsedSeconds);
                  Color cardColor = getCardColor(elapsedSeconds);

                  return GestureDetector(
                    onTap: () {
                      // Show dialog with seat details
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical:
                                            4), // Adds padding around the text
                                    // decoration: BoxDecoration(
                                    //   color: Colors.blue[
                                    //       100], // Light blue background for contrast
                                    //   borderRadius: BorderRadius.circular(
                                    //       4), // Rounded corners for a smooth look
                                    // ),
                                    child: Text(
                                      ' $tableNumber - Seat: $seat',
                                      style: TextStyle(
                                        fontSize:
                                            20, // Slightly larger text to draw attention
                                        fontWeight: FontWeight
                                            .bold, // Bold font weight for emphasis
                                        color: Colors.blue[
                                            900], // Dark blue color for high contrast
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(
                                                0.5), // Shadow for better legibility
                                            offset: const Offset(1, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical:
                                            2), // Adds padding around the text
                                    // decoration: BoxDecoration(
                                    //   color: Colors
                                    //       .green[100], // Soft green background
                                    //   borderRadius: BorderRadius.circular(
                                    //       4), // Rounded corners
                                    // ),
                                    child: Text(
                                      ' Total: ₹${total.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 18, // Larger text
                                        color: Colors.green[
                                            900], // Dark green color for high contrast
                                        fontWeight: FontWeight
                                            .w900, // Heaviest font weight
                                        shadows: [
                                          Shadow(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            offset: const Offset(2, 2),
                                            blurRadius: 2,
                                          ),
                                        ], // Text shadow
                                      ),
                                    ),
                                  ),
                                ),
                                const Divider(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: seatOrders.isNotEmpty
                                      ? seatOrders.map<Widget>((order) {
                                          final orderItems = List.generate(
                                              order['itemNames']?.length ?? 0,
                                              (i) {
                                            return {
                                              'varianceName':
                                                  order['varianceNames'][i],
                                              'price': order['prices'][i],
                                              'quantity': order['quantities']
                                                  [i],
                                              'weight': order['weights'][i],
                                              'amount': order['amounts'][i],
                                            };
                                          });

                                          int orderIndex =
                                              seatOrders.indexOf(order) + 1;

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Order $orderIndex: Token No ${order['tokenNo'] ?? ''} (${order['itemNames']?.length ?? 0} Items)',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const Divider(),
                                              Table(
                                                columnWidths: const {
                                                  0: FlexColumnWidth(2),
                                                  1: FlexColumnWidth(1),
                                                  2: FlexColumnWidth(1),
                                                  3: FlexColumnWidth(1),
                                                },
                                                children: [
                                                  const TableRow(children: [
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(4.0),
                                                      child: Text(
                                                          'Item Details',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12)),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(4.0),
                                                      child: Text('Qty',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12)),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.all(4.0),
                                                      child: Text('Amt',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12)),
                                                    ),
                                                  ]),
                                                  for (var item in orderItems)
                                                    TableRow(children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(4.0),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              '${capitalizeWords(item['varianceName'])}',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            if (item['price'] >
                                                                    0 &&
                                                                item['weight'] >
                                                                    0)
                                                              Text(
                                                                '(₹${item['price'].toStringAsFixed(0)} / ${item['weight']} kg)',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 10,
                                                                ),
                                                              ),
                                                            if (item['price'] >
                                                                    0 &&
                                                                item['weight'] <=
                                                                    0)
                                                              Text(
                                                                '(₹${item['price'].toStringAsFixed(0)})',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 10,
                                                                ),
                                                              ),
                                                            if (item['weight'] >
                                                                    0 &&
                                                                item['price'] <=
                                                                    0)
                                                              Text(
                                                                '(${item['weight']} kg)',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 10,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(4.0),
                                                        child: Text(
                                                          '${item['quantity'].toString()}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(4.0),
                                                        child: Text(
                                                          '₹${item['amount'].toStringAsFixed(0)}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ]),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                            ],
                                          );
                                        }).toList()
                                      : [const Text('No items available.')],
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromARGB(255, 239, 72, 72),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final double totalAmount = total;
                                // Prepare items list with detailed information
                                final items = seatOrders.map((order) {

                                  return {
                                    'itemName': order['itemNames'],
                                    'varianceName': order['varianceNames'],
                                    'qty': order['quantities'],
                                    'weight': order['weights'],
                                    'tax': order['taxes'],
                                    'uom': order['uoms'],
                                    'hiveOrderId': order['hiveOrderId'],
                                    'seathiveOrderId': order['seathiveOrderId'],
                                    'waiter': order['waiter'],
                                    'customerPhoneNumber':
                                        order['customerPhoneNumber'],

                                    'price': order['prices'],
                                    'amount': List.generate(
                                        order['prices'].length,
                                        (i) =>
                                            order['prices'][i] *
                                            order['quantities'][i]),
                                    'totalAmount': order['totalAmount'],
                                    'config': order['config'] ??
                                        [], // ✅ Include config here
                                  };
                                }).toList();

                                // Navigate to SalesInvoicePayAndPrint with all details
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SalesInvoicePayAndPrint(
                                      totalAmount: totalAmount,
                                      items: items, // Pass the items list
                                      branchName:
                                          branchName, // Pass branch name
                                      deviceCode: storedDeviceCode ?? '',
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA5D6A7),
                              ),
                              child: const Text(
                                ' Pay ',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: cardColor, // 🟢🟠🔴 Color changes dynamically
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 5),
                          Text('SEAT $seat',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                          const SizedBox(height: 5),
                          Text(' ₹${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                          // Text(preinvoiceTime),
                          Text('${formattedElapsedTime}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

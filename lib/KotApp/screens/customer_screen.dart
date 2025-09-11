import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:yenposapp/screens/kot_screen/global/globals.dart';

import '../Helper/generateSeatLables.dart';
import '../kotservices/preInv Utility.dart';
import '../kotservices/preInvociePrint_services.dart';
import '../models/printer.dart';
import '../kotproviders/bottomNavprovider.dart';
import '../kotproviders/printer_provider.dart';
import '../widgets/capitalizeWord.dart';
import '../widgets/circularLoadingindicator.dart';

import 'package:provider/provider.dart';
import '../kotservices/kotwebsocketService.dart';
import '../kotproviders/cartprovider.dart';
import '../kotproviders/hold_order.dart';
import '../kotproviders/order_provider.dart';
import '../widgets/bottomNav.dart';
import '../widgets/globalAppbar.dart';
import 'customerScreen file/legend_item.dart';
import 'customerScreen file/seat_transfer.dart';
import 'productsCard.dart';

class seatScreen extends StatefulWidget {
  final String tableNumber;
  final int seats;

  const seatScreen({super.key, required this.tableNumber, required this.seats});

  @override
  _seatScreenState createState() => _seatScreenState();
}

class _seatScreenState extends State<seatScreen> {
  @override
  void initState() {
    super.initState();
    // Load initial orders from Hive asynchronously
    Provider.of<OrderProvider>(context, listen: false).loadOrdersFromHive();
  }

  void sendseatActionToServer(String seat) {

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final holdOrderProvider =
        Provider.of<HoldOrderProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProviderkot>(context, listen: false);
    final ordersForSeat = orderProvider
        .getActiveOrdersForSeat(widget.tableNumber, seat)
        .where((order) =>
            order['table'] == widget.tableNumber && order['seat'] == seat)
        .toList();

    // Check if the seat has active or confirmed orders
    final isOccupied = ordersForSeat.any((order) =>
        (order['status'] == 'active' || order['status'] == 'confirm') &&
        order['seat'] == seat &&
        order['table'] == widget.tableNumber);

    // Get the appropriate seathiveOrderId
    final seathiveOrderId =
        isOccupied ? ordersForSeat.first['seathiveOrderId'] ?? '' : '';
    // Log for debugging

    // Debug print for selected table seat order
    for (var order in ordersForSeat) {
    }

    final webSocketService =
        Provider.of<WebSocketServicekot>(context, listen: false);
    final data = {
      'action': 'seat_tapped',
      'tableNumber': widget.tableNumber,
      'seat': seat,
      'seathiveOrderId': seathiveOrderId,
    };

    webSocketService.channel.sink.add(jsonEncode(data));
    // Load hold order if it exists
    final holdOrder = holdOrderProvider.loadHoldOrder(widget.tableNumber, seat);

    // Clear cart before loading any hold order
    cartProvider.clearCart();

    if (holdOrder != null) {
      // Add hold order items to the cart
      holdOrder.forEach((key, value) {
        cartProvider.cart[key] = value;
      });
    } else {
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductCardScreen(
          tableNumber: widget.tableNumber,
          seat: seat,
          seathiveOrderId: seathiveOrderId,
        ),
      ),
    ).then((_) {
      // Send the seat returned action only after returning to the seat screen
      sendSeatReturnedActionToServer(seat);
    });
  }

  void sendSeatReturnedActionToServer(String seat) {
    final webSocketService =
        Provider.of<WebSocketServicekot>(context, listen: false);
    final returnData = {
      'action': 'seat_returned',
      'tableNumber': widget.tableNumber,
      'seat': seat,
    };
    webSocketService.channel.sink.add(jsonEncode(returnData));
  }

  void sendTransferSeatActionToServer({
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double cardWidth = 140;
    const double cardHeight = 140;
    final int columns = (screenWidth / cardWidth).floor();

    return Scaffold(
      backgroundColor: const Color(0xFFDBF0F7),
      appBar: GlobalAppBar(title: ' ${widget.tableNumber} - seats'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      left: 15.0, bottom: 8.0, right: 2.0),
                  child: buildLegend(),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15.0, right: 2.0),
                  child: buildLegend1(),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<void>(
              future: Provider.of<OrderProvider>(context, listen: false)
                  .loadOrdersFromHive(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularLoadingIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error loading data'));
                } else {
                  return Consumer<OrderProvider>(
                    builder: (context, orderProvider, child) {
                      // final activeOrdersForThisTable = orderProvider.orders
                      //     .where((order) =>
                      //         order['table'] == widget.tableNumber &&
                      //         (order['status'] == 'active' ||
                      //             order['status'] == 'confirm'))
                      //     .toList();
                      return Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Container(
                          width: double.infinity,
                          height: 800,
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
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              childAspectRatio: cardWidth / cardHeight,
                            ),
                            itemCount: widget.seats,
                            itemBuilder: (context, index) {
                              final seat = generateSeatLabel(index);
                              final activeOrdersForThisTable = orderProvider
                                  .orders
                                  .where((order) =>
                                      order['table'] == widget.tableNumber &&
                                      (order['status'] == 'active'
                                      //  ||
                                      //     order['status'] == 'confirm'
                                      ))
                                  .toList();
                              final isOccupied = activeOrdersForThisTable.any(
                                  (order) =>
                                      order['seat'] == seat &&
                                      order['table'] == widget.tableNumber);
                              final holdOrderProvider =
                                  Provider.of<HoldOrderProvider>(context,
                                      listen: false);

                              // Check if this seat has hold orders
                              final hasHoldOrder = holdOrderProvider
                                  .hasHoldOrder(widget.tableNumber, seat);

                              final ordersForSeat =
                                  orderProvider.getRunningOrdersForSeat(
                                      widget.tableNumber, seat);
                              final seathiveOrderId = isOccupied
                                  ? ordersForSeat.first['seathiveOrderId'] ?? ''
                                  : '';

                              final totalPrice = orderProvider
                                  .getseatTotalPrice(widget.tableNumber, seat);
                              final String waiterName = ordersForSeat.isNotEmpty
                                  ? ordersForSeat.first['waiter']
                                  : "";

                              bool isSeatBooked =
                                  Provider.of<WebSocketServicekot>(context,
                                          listen: false)
                                      .receivedActions
                                      .any((action) =>
                                          action['tableNumber'] ==
                                              widget.tableNumber &&
                                          action['seat'] == seat &&
                                          action['action'] == 'seat_tapped');
                              bool hasActiveOrders = ordersForSeat.any(
                                (order) =>
                                    order['table'] == widget.tableNumber &&
                                    order['seat'] == seat &&
                                    order['status'] == 'active',
                              );
                              return GestureDetector(
                                onLongPress: () {
                                  bool hasConfirmOrders = orderProvider.orders
                                      .any((order) =>
                                          order['table'] ==
                                              widget.tableNumber &&
                                          order['seat'] == seat &&
                                          order['status'] == 'confirm');

                                  if (isOccupied || hasConfirmOrders) {
                                    // _showTransferDialog(
                                    //     context,
                                    //     orderProvider,
                                    //     widget.tableNumber,
                                    //     seat,
                                    //     seathiveOrderId);

                                    _showBottomSheetActions(
                                        context,
                                        orderProvider,
                                        widget.tableNumber,
                                        seat,
                                        ordersForSeat,
                                        seathiveOrderId);
                                  }
                                },
                                onTap: () {
                                  final ordersForSeat1 =
                                      orderProvider.getActiveOrdersForSeat(
                                          widget.tableNumber, seat);
                                  bool hasOrdersForSeat = ordersForSeat1.any(
                                    (order) =>
                                        order['table'] == widget.tableNumber &&
                                        order['seat'] == seat,
                                  );

                                  // ✅ Check if this seat has active orders
                                  bool hasConfirmOrders = orderProvider.orders
                                      .any((order) =>
                                          order['table'] ==
                                              widget.tableNumber &&
                                          order['seat'] == seat &&
                                          order['status'] == 'confirm');
                                  if (!hasOrdersForSeat) {
                                    // ✅ If no orders exist for this seat, allow access (available seat)
                                    // sendSeatActionToServer(
                                    //     context, widget.tableNumber, seat);
                                    sendseatActionToServer(seat);
                                  } else if (!hasActiveOrders &&
                                      hasConfirmOrders) {
                                    Flushbar(
                                      message:
                                          "Please generate an invoice for ${widget.tableNumber} - $seat,\n the seat is locked.",
                                      duration: const Duration(seconds: 2),
                                      backgroundColor:
                                          Colors.red[600] ?? Colors.red,
                                      flushbarPosition: FlushbarPosition.BOTTOM,
                                      margin: const EdgeInsets.all(8),
                                      borderRadius: BorderRadius.circular(20),
                                    ).show(context);
                                    return;
                                  } else {
                                    // ✅ If there are active orders, proceed with the seat action
                                    // sendSeatActionToServer(
                                    //     context, widget.tableNumber, seat);
                                    sendseatActionToServer(seat);
                                  }
                                },
                                child: Card(
                                  color: hasHoldOrder
                                      ? const Color.fromARGB(255, 216, 197,
                                          143) // Aesthetic blue for hold orders
                                      : isOccupied
                                          ? const Color.fromARGB(255, 241, 90,
                                              70) // Red for occupied seats
                                          : orderProvider.orders.any((o) =>
                                                  o['table'] ==
                                                      widget.tableNumber &&
                                                  o['seat'] == seat &&
                                                  o['status'] == 'confirm')
                                              ? const Color.fromARGB(
                                                  255,
                                                  143,
                                                  183,
                                                  216) // Blue for confirmed status
                                              : const Color(
                                                  0xFFA5D6A7), // Default green color
                                  // Default green color
                                  // Default green color
                                  // Green for available seats
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'SEAT $seat $serverip',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (isOccupied ||
                                                orderProvider.orders.any((o) =>
                                                    o['table'] ==
                                                        widget.tableNumber &&
                                                    o['seat'] == seat &&
                                                    o['status'] == 'confirm'))
                                              Text(
                                                'Total: ₹${totalPrice.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isOccupied ||
                                          orderProvider.orders.any((o) =>
                                              o['table'] ==
                                                  widget.tableNumber &&
                                              o['seat'] == seat &&
                                              o['status'] == 'confirm'))
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Align(
                                            alignment: Alignment
                                                .bottomRight, // Explicit alignment to bottom right
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                // color: Colors.black54,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  const CircleAvatar(
                                                    backgroundColor:
                                                        Colors.blue,
                                                    radius: 10,
                                                    child: Icon(Icons.person,
                                                        size: 15,
                                                        color: Colors.white),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'User: ${waiterName.split(" ")[0]}', // Only displays the first name
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (orderProvider.orders.any((o) =>
                                          o['table'] == widget.tableNumber &&
                                          o['seat'] == seat &&
                                          o['status'] == 'confirm'))
                                        const Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Icon(
                                            Icons
                                                .lock_clock, // ⏳ Lock-clock icon instead of normal lock
                                            color: Colors.black,
                                            size: 20,
                                          ),
                                        ),
                                      if (isSeatBooked)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            width: 15,
                                            height: 15,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  _showSeatOrderDetails(BuildContext context, OrderProvider orderProvider,
      String tableNumber, String seat) {
    final List<dynamic> ordersForSeat = orderProvider
        .getActiveOrdersForSeat(tableNumber, seat)
        .where((order) =>
            order['table'] == tableNumber &&
            order['seat'] == seat &&
            (order['status'] == "active" || order['status'] == "confirm"))
        .toList();

    final totalPrice = orderProvider.getseatTotalPrice(tableNumber, seat);
    bool isActiveOrder =
        ordersForSeat.any((order) => order['status'] == 'active');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$tableNumber - Seat $seat",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                "Total: ₹${totalPrice.toStringAsFixed(0)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: ordersForSeat.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          "No active orders for this seat.",
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: ordersForSeat.map((order) {
                        final tokenNo = order['tokenNo']?.toString() ?? 'N/A';
                        final items = order['varianceNames'] ?? [];
                        final prices = order['prices'] ?? [];
                        final weights = order['weights'] ?? [];
                        final quantities = order['quantities'] ?? [];
                        final amounts = order['amounts'] ?? [];
                        final config = order['config'] ?? [];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Header
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        "Order #${ordersForSeat.indexOf(order) + 1}",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Text("Token: $tokenNo",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Divider(),

                              // Table Headers
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text("Item",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text("Qty",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text("Amt",
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),

                              // Items List
                              Column(
                                children: List.generate(items.length, (i) {
                                  String itemName = items[i];
                                  String price = prices.length > i
                                      ? "₹${prices[i].toStringAsFixed(0)}"
                                      : "-";
                                  String weight = (weights.length > i &&
                                          weights[i] > 0)
                                      ? "${weights[i].toStringAsFixed(2)} kg"
                                      : "";

                                  List<dynamic> variantsList =
                                      (config.isNotEmpty &&
                                              config.length > i &&
                                              config[i] != null &&
                                              config[i]['variance'] is List)
                                          ? List.from(config[i]['variance'])
                                          : [];
                                  List<dynamic> configQtyList =
                                      (config.isNotEmpty &&
                                              config.length > i &&
                                              config[i] != null &&
                                              config[i]['configQty'] is List)
                                          ? List.from(config[i]['configQty'])
                                          : (config[i]['configQty'] != null
                                              ? [config[i]['configQty']]
                                              : []);
                                  Map<String, int> accumulatedVariants = {};

                                  bool hasValidVariants =
                                      variantsList.isNotEmpty &&
                                          variantsList.any((v) =>
                                              v.toString().trim().isNotEmpty);
                                  if (hasValidVariants) {
                                    // ✅ Accumulate Variants with ConfigQty

                                    for (int j = 0;
                                        j < variantsList.length;
                                        j++) {
                                      String variant =
                                          variantsList[j].toString();
                                      int qty = (configQtyList.length > j)
                                          ? int.tryParse(configQtyList[j]
                                                  .toString()) ??
                                              1
                                          : 1;

                                      if (variant.trim().isNotEmpty) {
                                        accumulatedVariants[variant] =
                                            (accumulatedVariants[variant] ??
                                                    0) +
                                                qty;
                                      }
                                    }
                                  }
                                  List<dynamic> addOnsList =
                                      (config.isNotEmpty &&
                                              config.length > i &&
                                              config[i] != null &&
                                              config[i]['addOn'] is List)
                                          ? List.from(config[i]['addOn'])
                                          : (config[i]['addOn'] != null
                                              ? [config[i]['addOn']]
                                              : []);
                                  List<dynamic> addOnPriceList =
                                      (config.isNotEmpty &&
                                              config.length > i &&
                                              config[i] != null &&
                                              config[i]['addOnPrice'] is List)
                                          ? List.from(config[i]['addOnPrice'])
                                          : (config[i]['addOnPrice'] != null
                                              ? [config[i]['addOnPrice']]
                                              : []);
                                  bool hasValidAddOns = addOnsList.isNotEmpty &&
                                      addOnsList.any((a) =>
                                          a is List &&
                                          a.isNotEmpty &&
                                          a.any((addOn) => addOn
                                              .toString()
                                              .trim()
                                              .isNotEmpty));

                                  Map<String, int> accumulatedAddOns = {};

                                  Map<String, Map<String, int>>
                                      accumulatedAddOnsWithPrice = {};

                                  if (hasValidAddOns) {
                                    for (int j = 0;
                                        j < addOnsList.length;
                                        j++) {
                                      List<dynamic> addOns =
                                          addOnsList[j] is List
                                              ? addOnsList[j]
                                              : [addOnsList[j]];
                                      List<dynamic> addOnPrices =
                                          (addOnPriceList.length > j &&
                                                  addOnPriceList[j] is List)
                                              ? addOnPriceList[j]
                                              : [addOnPriceList[j]];

                                      List<dynamic> configQty =
                                          configQtyList.length > j
                                              ? (configQtyList[j] is List
                                                  ? configQtyList[j]
                                                  : [configQtyList[j]])
                                              : [];

                                      for (int k = 0; k < addOns.length; k++) {
                                        String addOn = addOns[k].toString();
                                        int qty = (configQty.length > k)
                                            ? int.tryParse(
                                                    configQty[k].toString()) ??
                                                1
                                            : 1;
                                        int addOnPrice =
                                            (addOnPrices.length > k)
                                                ? int.tryParse(addOnPrices[k]
                                                        .toString()) ??
                                                    0
                                                : 0;

                                        if (addOn.trim().isNotEmpty) {
                                          if (!accumulatedAddOnsWithPrice
                                              .containsKey(addOn)) {
                                            accumulatedAddOnsWithPrice[addOn] =
                                                {"qty": 0, "price": addOnPrice};
                                          }
                                          accumulatedAddOnsWithPrice[addOn]![
                                                  "qty"] =
                                              (accumulatedAddOnsWithPrice[
                                                          addOn]!["qty"] ??
                                                      0) +
                                                  qty;
                                        }
                                      }
                                    }
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Item Details
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "${i + 1}. ${capitalizeWords(itemName)}", // ✅ Adds index before item name
                                                    style: const TextStyle(
                                                        fontSize: 14),
                                                  ),
                                                  Row(
                                                    children: [
                                                      if (weight.isEmpty)
                                                        Text(
                                                          "  (₹${prices.length > i ? prices[i].toStringAsFixed(0) : '0'})",
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .grey,
                                                                  fontSize: 12),
                                                        ),
                                                      if (weight.isNotEmpty)
                                                        Text(
                                                          "(₹${prices.length > i ? prices[i].toStringAsFixed(0) : '0'}/${weight})",
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .grey,
                                                                  fontSize: 12),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                quantities.length > i
                                                    ? quantities[i]
                                                        .toStringAsFixed(0)
                                                    : '0',
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                "₹${amounts.length > i ? amounts[i].toStringAsFixed(0) : '0.0'}",
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // **Show Variants & Add-ons only if they exist**
                                        if (hasValidVariants || hasValidAddOns)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 10, top: 4),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // **Variant Section**
                                                if (hasValidVariants)

                                                  // ✅ Display Variants with Accumulated ConfigQty
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        "Variant:",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                      Column(
                                                        children:
                                                            accumulatedVariants
                                                                .entries
                                                                .map((entry) {
                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        2),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  flex: 3,
                                                                  child: Text(
                                                                    entry
                                                                        .key, // ✅ Variant Name
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            12),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  flex: 1,
                                                                  child: Text(
                                                                    "x${entry.value}", // ✅ Accumulated ConfigQty
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            12),
                                                                  ),
                                                                ),
                                                                const Expanded(
                                                                  flex: 1,
                                                                  child: Text(
                                                                    "", // ✅ Accumulated ConfigQty
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            12),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ],
                                                  ),

                                                if (hasValidAddOns)
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        "Add-ons:",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12),
                                                      ),
                                                      Column(
                                                        children:
                                                            accumulatedAddOnsWithPrice
                                                                .entries
                                                                .map((entry) {
                                                          String addOnName =
                                                              capitalizeWords(
                                                                  entry.key);
                                                          int qty = entry.value[
                                                                  "qty"] ??
                                                              1;
                                                          int addOnPrice = entry
                                                                      .value[
                                                                  "price"] ??
                                                              0;
                                                          int totalPrice =
                                                              qty * addOnPrice;

                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        2),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  flex: 3,
                                                                  child: Text(
                                                                    "$addOnName \n(₹$addOnPrice)", // ✅ Add-on Name + Individual Price
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            12),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  flex: 1,
                                                                  child: Text(
                                                                    "x$qty", // ✅ Accumulated Quantity
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            12),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  flex: 1,
                                                                  child: Text(
                                                                    "₹$totalPrice", // ✅ Total Price (Quantity * Price)
                                                                    textAlign:
                                                                        TextAlign
                                                                            .right,
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            12),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red, // Text & icon color
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cancel, size: 15),
                        SizedBox(height: 4),
                        Text("Close", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: isActiveOrder
                          ? Colors.green
                          : Colors.grey[400], // Disable color
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      var printerIp =
                          Provider.of<PrinterProvider>(context, listen: false)
                              .getPreInvoicePrinterIp();

                      if (printerIp == null) {
                        promptForPrinterIp(context);
                        // Re-check after potentially setting the IP
                        printerIp =
                            Provider.of<PrinterProvider>(context, listen: false)
                                .getPreInvoicePrinterIp();
                        if (printerIp == null) {
                          return; // Exit if still not set to avoid proceeding without a printer IP
                        }
                      }
                      if (isActiveOrder) {
                        _showPreInvoiceConfirmation(context, orderProvider,
                            tableNumber, seat, ordersForSeat);
                      } else {
                        Flushbar(
                          message: "Already Pre-Invoice generated",
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.red[600] ?? Colors.red,
                          flushbarPosition: FlushbarPosition.BOTTOM,
                          margin: const EdgeInsets.all(8),
                          borderRadius: BorderRadius.circular(20),
                        ).show(context);
                        return;
                      }
                    },
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.print, size: 15),
                        SizedBox(height: 4),
                        Text(
                          "Generate Pre-Invoice",
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> patchStatusConfirm(
      OrderProvider orderProvider, // ✅ Pass orderProvider as a parameter
      String tableNumber,
      String seat,
      List<Map<String, dynamic>> seatOrders) async {
    for (var order in seatOrders) {
      if (order.containsKey('seathiveOrderId') &&
          order['seathiveOrderId'] != null) {
        await orderProvider.patchOrderStatusBySeathiveOrderId(
            order['seathiveOrderId'],
            "confirm"); // ✅ Ensure it waits for each API call

      } else {
      }
    }
  }

  _generatePreInvoice(BuildContext context, OrderProvider orderProvider,
      String tableNumber, String seat, List<dynamic> seatOrders) async {
    final printerProvider =
        Provider.of<PrinterProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    final preInvoicePrinter = printerProvider.printers.firstWhere(
      (printer) => printer.type == 'PreInvoice',
      orElse: () => Printer(
          name: 'default_printer',
          ipAddress: '192.168.1.100',
          type: 'PreInvoice'),
    );

    final String hiveOrderId =
        seatOrders.isNotEmpty ? seatOrders.first['seathiveOrderId'] : '';
    await patchStatusConfirm(orderProvider, tableNumber, seat,
        seatOrders.cast<Map<String, dynamic>>());

    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    orderProvider.notifyListeners();
    // Extract total price for seat
    final double total = orderProvider.getseatTotalPrice(tableNumber, seat);

    await PreInvoicePrinter.printReceipt(
      ipAddress: preInvoicePrinter.ipAddress,
      tableNumber: tableNumber,
      seat: seat,
      seatOrders: seatOrders,
      userName: "User",
      waiter: seatOrders.isNotEmpty ? seatOrders.first['waiter'] : '',
      receiptType: 'PreInvoice',
    );


    // ignore: use_build_context_synchronously
    Provider.of<BottomNavProvider>(context, listen: false).updateIndex(0);
  }

  void _showPreInvoiceConfirmation(
      BuildContext context,
      OrderProvider orderProvider,
      String tableNumber,
      String seat,
      List<dynamic> seatOrders) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Pre-Invoice"),
          content:
              const Text("Are you sure you want to generate the pre-invoice?"),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
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
              onPressed: () async {
                try {
                  await _generatePreInvoice(
                      context, orderProvider, tableNumber, seat, seatOrders);
                  Navigator.of(context).pop(); // Close the dialog
                } catch (e) {
                  Navigator.of(context)
                      .pop(); // Ensure dialog closes even if an error occurs
                }
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
        );
      },
    );
  }

  void _showBottomSheetActions(
      BuildContext context,
      OrderProvider orderProvider,
      String currentTable,
      String seat,
      List<dynamic> seatOrders,
      String seathiveOrderId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
      ),
      builder: (BuildContext context) {
        bool isActiveOrder =
            seatOrders.any((order) => order['status'] == 'active');

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔹 Title Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color:
                        Colors.blueGrey[100], // Light background for contrast
                    borderRadius: BorderRadius.circular(12), // Rounded corners
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chair,
                          color: Colors.blueGrey[700], size: 20), // Seat icon
                      const SizedBox(width: 8), // Space between icon & text
                      Text(
                        "$currentTable - Seat $seat Actions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors
                              .blueGrey[900], // Darker text for readability
                          letterSpacing: 0.5, // Slight spacing for elegance
                        ),
                      ),
                    ],
                  ),
                )),
              ),
              const SizedBox(height: 16),

              // 🔹 First Row (2 Buttons Side by Side)
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.visibility,
                      color: Colors.blue,
                      title: "View Kot Order",
                      onTap: () {
                        Navigator.pop(context);
                        _showSeatOrderDetails(
                            context, orderProvider, currentTable, seat);
                        //Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12), // Space between buttons
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.swap_horiz,
                      color: isActiveOrder ? Colors.green : Colors.grey,
                      title: "Transfer Seat",
                      onTap: () {
                        Navigator.pop(context);
                        if (isActiveOrder) {
                          showTransferDialog(context, orderProvider,
                              currentTable, seat, seathiveOrderId);
                        } else {
                          Flushbar(
                            message:
                                "Pre-Invoice generated no need to transfer seat",
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.red[600] ?? Colors.red,
                            flushbarPosition: FlushbarPosition.BOTTOM,
                            margin: const EdgeInsets.all(8),
                            borderRadius: BorderRadius.circular(20),
                          ).show(context);
                          return;
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 🔹 Second Row (Single Button Centered)
              Center(
                child: _buildActionButton(
                  icon: Icons.print,
                  color: isActiveOrder ? Colors.red : Colors.grey,
                  title: "     Print Receipt     ",
                  onTap: () {
                    var printerIp =
                        Provider.of<PrinterProvider>(context, listen: false)
                            .getPreInvoicePrinterIp();

                    if (printerIp == null) {
                      promptForPrinterIp(context);
                      // Re-check after potentially setting the IP
                      printerIp =
                          Provider.of<PrinterProvider>(context, listen: false)
                              .getPreInvoicePrinterIp();
                      if (printerIp == null) {
                        return; // Exit if still not set to avoid proceeding without a printer IP
                      }
                    }
                    if (isActiveOrder) {
                      _showPreInvoiceConfirmation(context, orderProvider,
                          currentTable, seat, seatOrders);
                    } else {
                      Flushbar(
                        message: "Already Pre-Invoice generated..",
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.red[600] ?? Colors.red,
                        flushbarPosition: FlushbarPosition.BOTTOM,
                        margin: const EdgeInsets.all(8),
                        borderRadius: BorderRadius.circular(20),
                      ).show(context);
                      return;
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

// 🔹 Common Button Builder Function
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        elevation: 3,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}

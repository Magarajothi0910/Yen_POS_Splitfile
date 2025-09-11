import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../screens/kot_screen/global/globals.dart';
import '../../services/branchwise_item_fetch.dart';
import '../kotproviders/cartprovider.dart';
import '../kotservices/kotwebsocketService.dart';
import '../widgets/product_Search/holdDropdown.dart';
import '../widgets/seatReturnBottomNav.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/fetchDiningTax.dart';
import '../models/globals.dart';
import '../models/product.dart';
import '../kotproviders/employee_provider.dart';
import '../kotproviders/hold_order.dart';
import '../kotproviders/order_provider.dart';
import '../kotproviders/product_provider.dart';
import '../kotproviders/order_type_provider.dart';
import '../kotproviders/search_provider.dart';
import '../kotproviders/submissionProvider.dart';
import '../widgets/product_Search/idle_keyboard_hide.dart';
import 'product_search_screen.dart';
import 'table_screen.dart';
import 'viewtocart.dart';

class ProductCardScreen extends StatefulWidget {
  final String tableNumber;
  final String seat;
  final String? seathiveOrderId;

  const ProductCardScreen(
      {super.key,
      required this.tableNumber,
      required this.seat,
      required this.seathiveOrderId});

  @override
  _ProductCardScreenState createState() => _ProductCardScreenState();
}

class _ProductCardScreenState extends State<ProductCardScreen> {
  final _searchController = TextEditingController();
  late WebSocketChannel channel;
  final String _selectedPax = "1"; // Default value for pax
  String? storedDeviceId;
  Duration debounceDuration = const Duration(milliseconds: 300);
  Timer? _debounce;
  String? selectedEmployee;
  late ScrollController _scrollController; // Add ScrollController
  // Add this at the top inside your _CartItemsState class
  bool _showViewToCartButton = false;
  String? _selectedItemName; // Track the selected item name
  bool isToggled = false;
  String? _customerPhoneNumber;

  @override
  void initState() {
    super.initState();
    String url = 'ws://$serverip:$port';
    channel = IOWebSocketChannel.connect(url);
    loadDeviceCode();

    _scrollController = ScrollController();

    _searchController.addListener(_onSearchChanged);
    _searchController.clear();
    submitflag = false;
  }

  Future<void> loadDeviceCode() async {
    var box = await Hive.openBox('deviceData');
    setState(() {
      storedDeviceId = box.get('deviceCode');
    });
  }

  Future sendDataToServer(Map<String, dynamic> data) async {
    final jsonData = jsonEncode(data);
    channel.sink.add(jsonData);
    _sendStockUpdates();
  }

  bool submitflag = false;

  void _submitOrder(String phoneNumber) {
    final holdOrderProvider =
        Provider.of<HoldOrderProvider>(context, listen: false);

    final submissionProvider =
        Provider.of<SubmissionProvider>(context, listen: false);

    final employeeProvider =
        Provider.of<EmployeeProvider>(context, listen: false);

    final waiter = selectedEmployee ?? employeeProvider.selectedWaiter;

    // if (waiter == null || waiter.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content: Text('Please Choose a waiter before submitting the order!'),
    //       duration: Duration(seconds: 1),
    //     ),
    //   );
    //   return;
    // }
    if (Provider.of<CartProviderkot>(context, listen: false).cart.isEmpty) {
      Flushbar(
        message: 'Please add items to the cart!',
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red[600] ?? Colors.red,
        flushbarPosition: FlushbarPosition.BOTTOM,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(20),
      ).show(context);
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Confirm Submission..",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
              "Are you sure you want to submit the order for Table ${widget.tableNumber}- Seat ${widget.seat}?"),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red, // Red background for "Cancel" button
                foregroundColor: Colors.black, // White text color
              ),
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA5D6A7),
                foregroundColor: Colors.black,
              ),
              onPressed: submissionProvider.isSubmitting
                  ? null
                  : () async {
                      submissionProvider.startSubmitting();
                      count = 0;
                      count2 = 0;
                      count3 = 0;

                      await _processOrder(phoneNumber);

                      // Navigate directly to the TableScreen and replace current screen
                      // ignore: use_build_context_synchronously
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const TableScreen()),
                      );


                      holdOrderProvider.removeHoldOrder(
                          widget.tableNumber, widget.seat);
                      submissionProvider.stopSubmitting();

                      setState(() {
                        _searchController.clear();
                      });
                      Provider.of<SearchProvider>(context, listen: false)
                          .clearSearchQuery();
                      Provider.of<OrderTypeProvider>(context, listen: false)
                          .setOrderType('');
                    },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  // Define lists to store values
  List<String> itemNames = [];
  List<String> varianceNames = [];
  List<double> prices = [];
  List<double> weights = [];
  List<int> quantities = [];

  List<double> amounts = [];
  List<double> taxes = [];
  List<String> uoms = [];
  List<Map<String, dynamic>> parcelItems = [];
  List<String> itemRemark = [];
  String? orderRemark = "";
  String? partiallyCancelled = "";
  List<Map<String, dynamic>> addOnsList = []; // To store add-ons per product

  Future<void> _processOrder(String phoneNumber) async {
    final cartProvider = Provider.of<CartProviderkot>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final orderTypeProvider =
        Provider.of<OrderTypeProvider>(context, listen: false);
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);
    final formattedTime = DateFormat('hh:mm:ss a').format(now);
    double totalAddonsAmount = 0.0; // To accumulate addon totals
    double diningTaxPercentage = getTaxPercentage();
    List<Map<String, dynamic>> configs = [];
    Map<String, double> varianceWeights = {};

    for (var entry in cartProvider.cart.entries) {
      final product = productProvider.products.firstWhere(
        (product) => product.varianceName == entry.key,
      );

      itemNames.add(product.name ?? '');
      varianceNames.add(product.varianceName ?? '');
      double price = product.price.toDouble() ?? 0.0;
      prices.add(price);
      int quantity = (entry.value['qty'] ?? 0);
      quantities.add(quantity);
      String uom = product.variance_Uom ?? "";
      uoms.add(uom);
      double total = 0.0;
      double weight = (entry.value['weight']?.toDouble() ?? 0.0);
      if (uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'kgs') {
        weight /= 1000; // Convert grams to kg
      }
      weights.add(weight);
      if (uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'kgs') {
        total = price * quantity * weight;
      } else {
        total = price * quantity;
      }
      amounts.add(total);
      taxes.add(diningTaxPercentage);
      List<List<String>> addons = List.generate(
        quantity.toInt(),
        (i) => (entry.value['addons']?.length ?? 0) > i
            ? entry.value['addons'][i]
            : [],
      );
      List<String> variants = List.generate(
        quantity.toInt(),
        (i) => (entry.value['variants']?.length ?? 0) > i
            ? entry.value['variants'][i]
            : "",
      );

      List<String> type = List.generate(
        quantity.toInt(),
        (i) => (entry.value['type']?.length ?? 0) > i
            ? entry.value['type'][i]
            : "",
      );
      List<String> remarks = List.generate(
        quantity.toInt(),
        (i) => (entry.value['remarks']?.length ?? 0) > i
            ? entry.value['remarks'][i]
            : "", // Fetch remarks for each item
      );
      varianceWeights[product.varianceName] = weight;

      double itemWeight = varianceWeights[product.varianceName] ?? 0.0;
      // Processing addons and their prices

      List<List<int>> addOnPrices = List.generate(
        quantity.toInt(),
        (i) => addons[i].map((addonName) {
          var addonData = productProvider.addons.firstWhere(
            (addOn) => addOn['addOn'].toString() == addonName,
            orElse: () => {'value': 0}, // Default value if addon not found
          );
          return addonData['value'] as int; // Get the price of the addon
        }).toList(),
      );

      // Accumulate total addon amount for order
      for (var addonList in addOnPrices) {
        totalAddonsAmount += addonList.fold(0, (sum, item) => sum + item);
      }

      Map<String, dynamic> config = {
        "varianceName": product.varianceName,
        "weight": itemWeight, // Store weight as a float, not a list

        // Check if quantity is provided, otherwise default to empty list
        "configQty":
            quantity > 0 ? List.generate(quantity.toInt(), (i) => 1) : [],

        // Post empty string if addons are empty
        "addOn": addons.isEmpty ? [""] : addons,
        "addOnPrice": addOnPrices.isEmpty ? [[]] : addOnPrices,

        // Post empty string if variance is 'Default'
        "variance": variants.contains('Default') ? [""] : variants,

        // Post empty string if type is ''
        "type": type == '' ? "" : type,

        // Post empty string for remarks if none are provided
        "remark": remarks.isEmpty ? "" : remarks,
      };
      configs.add(config); // Add each config to the list
    }
    final double totalAmount =
        amounts.fold(0.0, (sum, item) => sum + item) + totalAddonsAmount;
    final employeeProvider =
        Provider.of<EmployeeProvider>(context, listen: false);
    final order = {
      'type': 'order',
      'date': formattedDate,
      'time': formattedTime,
      'preinvoiceTime': "",
      'branchName': aliasname,
      'table': widget.tableNumber,
      'seat': widget.seat,
      'deviceId': storedDeviceId,
      'itemNames': itemNames,
      'varianceNames': varianceNames,
      'prices': prices,
      'weights': weights,
      'quantities': quantities,
      'cancelledQty':
          List.filled(itemNames.length, 0.0), // Initialize with correct length
      'amounts': amounts,
      'taxes': taxes,
      'uoms': uoms,
      // 'addOns': addOnsList,
      // 'parcelItems': parcelItems, // Include parcel items here
      'pax': _selectedPax,
      'status': "active",
      'waiter': employeeProvider.selectedWaiter ?? "",
      'orderType': orderTypeProvider.orderType,
      'totalAmount': totalAmount, // Add the calculated total amount here
      'seathiveOrderId':
          widget.seathiveOrderId ?? '', // Include seathiveOrderId
      'itemRemark': itemRemark ?? "",
      'orderRemark': orderRemark,
      'partiallyCancelled': partiallyCancelled,
      'config': configs, // Send all configs as a list
      'customerPhoneNumber': phoneNumber, // ✅ Include phone number
      'sync': "No",
      'edit': "No",
      'statusEdited': "false",
      'fieldsEdited': "false",
    };

    await sendDataToServer(order);
    // await Future.delayed(const Duration(microseconds: 10));

    Navigator.pop(context);

    cartProvider.clearCart();
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

  Future<void> _sendStockUpdates() async {
    final alias = aliasname;
    final cart = Provider.of<CartProviderkot>(context, listen: false).cart;

    // 1) Pull raw Hive data as a dynamic Map, then rebuild as Map<String,dynamic>
    final box = await Hive.openBox('branchwise_items');
    final rawDynamic = box.get('data') as Map;
    final raw = Map<String, dynamic>.from(rawDynamic);

    // 2) Extract the 'data' field and rebuild
    final itemsDynamic = raw['data'] as Map;
    final items = Map<String, dynamic>.from(itemsDynamic);

    // 3) Build your updates list
    final updates = <Map<String, dynamic>>[];
    for (final cartEntry in cart.entries) {
      final varName = cartEntry.key;
      final data = cartEntry.value;
      final qty = (data['qty'] as num? ?? 0).toDouble();
      final weight = (data['weight'] as num? ?? 1.0).toDouble();

      // 4) Find the matching variance entry inside your Hive map
      Map<String, dynamic>? varJson;
      for (final itemValue in items.values) {
        final itemMap = Map<String, dynamic>.from(itemValue as Map);
        final varsMap = Map<String, dynamic>.from(itemMap['variance'] as Map);

        if (varsMap.containsKey(varName)) {
          varJson = Map<String, dynamic>.from(varsMap[varName] as Map);
          break;
        }
      }
      if (varJson == null) {
        throw Exception('No variance $varName in branchwise_items');
      }

      // 5) Compute soldQty
      final code = varJson['varianceitemCode']?.toString() ?? '';
      final name = varJson['varianceName']?.toString() ?? varName;
      final uom = varJson['variance_Uom']?.toString().toLowerCase() ?? '';
      final soldQty = (uom == 'kg' || uom == 'kgs') ? qty * weight : qty;

      updates.add({
        'varianceitemCode': code,
        'varianceName': name,
        'branch': alias,
        'quantity': soldQty,
      });
    }


    // 6) Send to server
    channel.sink.add(jsonEncode({
      'action': 'updateLocalStock',
      'updates': updates,
    }));

  }

  @override
  void dispose() {
    _debounce?.cancel();

    _scrollController.dispose(); // Dispose ScrollController
    _searchController.dispose();
    channel.sink.close();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(debounceDuration, () {
      Stopwatch stopwatch = Stopwatch()..start();

      var searchText = _searchController.text;
      Provider.of<SearchProvider>(context, listen: false)
          .updateSearchQuery(searchText);

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }

      stopwatch.stop();
    });
  }

  List<Product> _filteredProducts(List<Product> products, String query) {
    if (query.isEmpty) {
      return products;
    }
    final lowerQuery = query.toLowerCase();
    return products.where((product) {
      return product.name.toLowerCase().contains(lowerQuery) ||
          product.varianceName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  late CartProviderkot _cartProvider;
  late HoldOrderProvider _holdOrderProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache references to providers
    _cartProvider = Provider.of<CartProviderkot>(context, listen: false);
    _holdOrderProvider = Provider.of<HoldOrderProvider>(context, listen: false);
  }

  void _autoSaveHoldOrder() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    // Fetch current orders for the seat
    final ordersForSeat =
        orderProvider.getRunningOrdersForSeat(widget.tableNumber, widget.seat);

    // Check if any active orders exist for the seat
    bool hasActiveOrder =
        ordersForSeat.any((order) => order['status'] == 'active');
    if (_cartProvider.cart.isNotEmpty && !hasActiveOrder) {
      _holdOrderProvider.saveHoldOrder(
        widget.tableNumber,
        widget.seat,
        _cartProvider.cart, // Save the updated cart
      );
    }
  }

  // void _autoSaveHoldOrder() {
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (_cartProvider.cart.isNotEmpty) {
  //       _holdOrderProvider.saveHoldOrder(
  //         widget.tableNumber,
  //         widget.seat,
  //         _cartProvider.cart,
  //       );
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final cartProvider = Provider.of<CartProviderkot>(context);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    final ordersForSeat =
        orderProvider.getActiveOrdersForSeat(widget.tableNumber, widget.seat);
    _showViewToCartButton =
        cartProvider.cart.values.any((item) => item['qty'] > 0);
    _showViewToCartButton = true;
    // Check if the seat has active or confirmed orders
    final isOccupied = ordersForSeat.any((order) =>
        (order['status'] == 'active' || order['status'] == 'confirm') &&
        order['seat'] == widget.seat &&
        order['table'] == widget.tableNumber);

    // Get the appropriate seathiveOrderId
    final seathiveOrderId =
        isOccupied ? ordersForSeat.first['seathiveOrderId'] ?? '' : '';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Hides the back arrow
        backgroundColor: const Color(0xFFDBF0F7),

        title: Text(
          ' ${widget.tableNumber} - ${widget.seat}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          buildHoldOrdersDropdown(context, widget.tableNumber, widget.seat),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await Provider.of<ItemProvider>(context, listen: false)
                  .fetchDataIfNeeded();
            },
          ),
          ToggleButtons(
            isSelected: [
              isToggled
            ], // Use a single-element list for ToggleButtons
            onPressed: (index) async {
              setState(() {
                isToggled = !isToggled; // Toggle the state
              });

              if (isToggled) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductSearchScreen(
                      tableNumber: widget.tableNumber,
                      seat: widget.seat,
                      seathiveOrderId: seathiveOrderId,
                    ),
                  ),
                );

                // After returning from ProductSearchScreen, update toggle state
                if (result != null && result == 'toggle_off') {
                  setState(() {
                    isToggled = false; // Turn off the toggle button
                  });
                }
              }
            },
            children: const [
              Icon(Icons.toggle_on), // Toggle icon
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 1.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Expanded(
                //   flex: 2,
                //   child: TextField(
                //     controller: _searchController,
                //     decoration: InputDecoration(
                //       hintText: 'Search Products',
                //       prefixIcon: const Icon(Icons.search),
                //       suffixIcon: IconButton(
                //         icon: const Icon(Icons.clear),
                //         onPressed: () {
                //           Provider.of<SearchProvider>(context, listen: false)
                //               .clearSearchQuery();
                //           _searchController.clear();
                //         },
                //       ),
                //       // Adding border properties
                //       border: OutlineInputBorder(
                //         borderRadius: BorderRadius.circular(10.0),
                //         borderSide: const BorderSide(
                //           color: Colors.grey,
                //           width: 2.0, // Border width
                //         ),
                //       ),
                //       focusedBorder: OutlineInputBorder(
                //         borderRadius:
                //             BorderRadius.circular(10.0), // Same rounded corners
                //         borderSide: const BorderSide(
                //           color: Color(0xFFA5D6A7),
                //           width: 2.0, // Border width when focused
                //         ),
                //       ),
                //     ),
                //   ),
                // ),

                const SizedBox(
                  width: 5,
                ),
                Expanded(
                  flex: 2,
                  child: IdleKeyboardHide(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Products',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          Provider.of<SearchProvider>(context, listen: false)
                              .clearSearchQuery();
                          _searchController.clear();
                          FocusScope.of(context)
                              .unfocus(); // Immediate hide keyboard
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8.0), // Rounded border
                        borderSide:
                            const BorderSide(color: Colors.black12, width: 2.0),
                      ),
                    ),
                    idleDuration: const Duration(
                        seconds: 2), // Customize the idle duration
                  ),
                ),
                //waiter_dropdown.dart
              ],
            ),
          ),
          Expanded(
            child: Consumer<SearchProvider>(
              builder: (context, searchProvider, child) {
                final products = _filteredProducts(
                    productProvider.products, searchProvider.searchQuery);

                if (products.isEmpty) {
                  return const Center(child: Text('No products found.'));
                }

                return GridView.builder(
                  controller: _scrollController, // Attach ScrollController
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    childAspectRatio:
                        MediaQuery.of(context).size.width > 600 ? 4 / 3 : 3 / 2,
                    crossAxisSpacing: 10, // Horizontal spacing
                    mainAxisSpacing: 10, // Vertical spacing
                  ),
                  padding: const EdgeInsets.all(10),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isInCart =
                        cartProvider.cart.containsKey(product.varianceName);
                    final quantity = isInCart
                        ? cartProvider.cart[product.varianceName]['qty']
                        : 0;
                    // final Color cardColor = quantity > 0
                    //     ? Color.fromARGB(255, 218, 236, 218)!
                    //     : Colors.white;
// Define productId safely

                    return StatefulBuilder(
                      builder: (context, setState) {
                        return GestureDetector(
                          onTap: () {
                            if (product.variance_Uom.toLowerCase() == "kg" ||
                                product.variance_Uom.toLowerCase() == "kgs") {
                              cartProvider.addToCart(
                                product.varianceName,
                                weight: 50,
                              );

                              _autoSaveHoldOrder();
                            } else {
                              cartProvider.addToCart(product.varianceName);

                              _autoSaveHoldOrder();
                            }
                          },
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            color: Colors.white, //cardColor
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 5,
                                      top: 20.0,
                                      right: 38.0), // Reserve space for icons
                                  child: Column(
                                    // crossAxisAlignment:
                                    //     CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        product.varianceName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '₹${product.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      // Text(
                                      //   'In Stock: ${product.localStock.toStringAsFixed(0)}',
                                      //   style: TextStyle(
                                      //       fontSize: 12,
                                      //       color: Colors.black54),
                                      // ),
                                    ],
                                  ),
                                ),
                                if (quantity > 0)
                                  Stack(
                                    clipBehavior: Clip
                                        .none, // Allows positioning outside the parent widget
                                    alignment: Alignment.center,
                                    children: [
                                      // Your main card widget

                                      // Positioned badge (half inside, half outside)
                                      Positioned(
                                        top:
                                            -15, // Move half of the badge outside
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          width: 30.0, // Adjust size if needed
                                          height: 30.0,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.red[400],
                                            shape: BoxShape.circle,
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 4.0,
                                                spreadRadius: 1.0,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            quantity.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (quantity > 0)
                                  Stack(
                                    children: [
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.mode_edit,
                                            color: Colors.blue[300],
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            final productId =
                                                product.varianceName;
                                            final hasAddOns =
                                                productProvider.hasAddOns(
                                                    product.varianceName);
                                            final hasVariants =
                                                productProvider.hasVariants(
                                                    product.varianceName);
                                            final weight = cartProvider
                                                .cart[productId]['weight'];

                                            final isWeight = product
                                                        .variance_Uom
                                                        .toLowerCase() ==
                                                    "kg" ||
                                                product.variance_Uom
                                                        .toLowerCase() ==
                                                    "kgs";
                                            List<List<String>> addons = List.generate(
                                                quantity,
                                                (i) => List.from(cartProvider
                                                                        .cart[
                                                                    productId]
                                                                ['addons'] !=
                                                            null &&
                                                        cartProvider
                                                                .cart[productId]
                                                                    ['addons']
                                                                .length >
                                                            i
                                                    ? cartProvider
                                                            .cart[productId]
                                                        ['addons'][i]
                                                    : []));
                                            List<String> variants = List.generate(
                                                quantity,
                                                (i) => cartProvider.cart[
                                                                    productId]
                                                                ['variants'] !=
                                                            null &&
                                                        cartProvider
                                                                .cart[productId]
                                                                    ['variants']
                                                                .length >
                                                            i
                                                    ? cartProvider
                                                            .cart[productId]
                                                        ['variants'][i]
                                                    : "Default");

                                            List<String> type = List.generate(
                                                quantity,
                                                (i) => cartProvider.cart[
                                                                    productId]
                                                                ['type'] !=
                                                            null &&
                                                        cartProvider
                                                                .cart[productId]
                                                                    ['type']
                                                                .length >
                                                            i
                                                    ? cartProvider
                                                            .cart[productId]
                                                        ['type'][i]
                                                    : "");
                                            cartProvider.syncConfigWithQuantity(
                                                productId, quantity);

                                            // Initialize states after syncing
                                            List<bool> toggleRemarks =
                                                cartProvider.getToggleRemarks(
                                                    productId, quantity);
                                            List<TextEditingController>
                                                remarkControllers =
                                                List.generate(
                                              quantity,
                                              (i) => TextEditingController(
                                                text: cartProvider.getRemarks(
                                                    productId, quantity)[i],
                                              ),
                                            );

                                            Map<String, dynamic> config = {
                                              "configQty": List.generate(
                                                  quantity, (i) => 1),
                                              "addOn": addons,
                                              "variance": variants,
                                              "type": type,
                                              "remarks": toggleRemarks
                                            };
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      product.varianceName,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                content: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxHeight:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.7,
                                                  ),
                                                  child: Scrollbar(
                                                    thumbVisibility: true,
                                                    child:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          ...List.generate(
                                                              quantity, (i) {
                                                            String itemName =
                                                                '  ${i + 1} .   ${product.varianceName} ';

                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          1.0),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  // First Row: Item Name
                                                                  Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Flexible(
                                                                        child:
                                                                            Text(
                                                                          itemName,
                                                                          style: const TextStyle(
                                                                              fontSize: 12,
                                                                              fontWeight: FontWeight.bold),
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                      if (!hasAddOns &&
                                                                          !hasVariants)
                                                                        Column(
                                                                          children: [
                                                                            StatefulBuilder(
                                                                              builder: (context, setStateInner) {
                                                                                return Checkbox(
                                                                                  value: type[i] == "Parcel",
                                                                                  onChanged: (value) {
                                                                                    type[i] = value! ? "Parcel" : "";
                                                                                    // Debugging output
                                                                                    setStateInner(() {}); // Update state
                                                                                  },
                                                                                  activeColor: Colors.teal, // For active color
                                                                                  checkColor: Colors.white, // For tick mark color inside checkbox
                                                                                  side: const BorderSide(color: Colors.teal, width: 1.5), // Border color
                                                                                );
                                                                              },
                                                                            ),
                                                                            const Text("Parcel",
                                                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                                                                          ],
                                                                        ),
                                                                      if (!hasAddOns &&
                                                                          !hasVariants)
                                                                        Column(
                                                                          children: [
                                                                            if (toggleRemarks.length >
                                                                                i)
                                                                              Switch(
                                                                                value: toggleRemarks[i],
                                                                                onChanged: (value) {
                                                                                  toggleRemarks[i] = value;
                                                                                  (context as Element).markNeedsBuild();
                                                                                },
                                                                                activeColor: Colors.teal, // For active color
                                                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduced size
                                                                              ),
                                                                            const Text("Remark",
                                                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal))
                                                                          ],
                                                                        ),
                                                                    ],
                                                                  ),

                                                                  // Second Row: Add-ons (if present)
                                                                  if (hasAddOns)
                                                                    Row(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Column(
                                                                          children: [
                                                                            SizedBox(
                                                                              width: 120,
                                                                              child: StatefulBuilder(
                                                                                builder: (context, setStateInner) {
                                                                                  // Filter add-ons based on the selected varianceName
                                                                                  List<Map<String, dynamic>> filteredAddons = productProvider.addons.where((addOn) {
                                                                                    var items = addOn['addOnItems'];
                                                                                    if (items is List) {
                                                                                      return items.map((e) => e.toString().trim().toLowerCase()).contains(product.varianceName.trim().toLowerCase());
                                                                                    }
                                                                                    return items.toString().trim().toLowerCase() == product.varianceName.trim().toLowerCase();
                                                                                  }).toList();

                                                                                  // Extract the list of add-on names
                                                                                  List<String> filteredAddonNames = filteredAddons.map((addOn) => addOn['addOn'].toString()).toList();

                                                                                  // Map of add-on name to its value (price)
                                                                                  Map<String, dynamic> addonPrices = {
                                                                                    for (var addOn in filteredAddons) addOn['addOn']: addOn['value']
                                                                                  };


                                                                                  return DropdownButtonFormField<String>(
                                                                                    decoration: const InputDecoration(
                                                                                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                                                                      hintStyle: TextStyle(fontSize: 12),
                                                                                      border: OutlineInputBorder(
                                                                                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                                                                                        borderSide: BorderSide(color: Colors.grey, width: 1.0),
                                                                                      ),
                                                                                      enabledBorder: OutlineInputBorder(
                                                                                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                                                                                        borderSide: BorderSide(color: Colors.grey, width: 1.0),
                                                                                      ),
                                                                                      focusedBorder: OutlineInputBorder(
                                                                                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                                                                                        borderSide: BorderSide(color: Colors.teal, width: 1.5),
                                                                                      ),
                                                                                    ),
                                                                                    isExpanded: true,
                                                                                    hint: Text(
                                                                                      addons[i].isEmpty ? 'Select Add-ons' : "${addons[i].length} selected",
                                                                                      style: const TextStyle(fontSize: 12, color: Colors.teal),
                                                                                    ),
                                                                                    items: filteredAddonNames.map((String addOn) {
                                                                                      return DropdownMenuItem<String>(
                                                                                        value: addOn,
                                                                                        child: StatefulBuilder(
                                                                                          builder: (context, setStateCheckbox) {
                                                                                            return GestureDetector(
                                                                                              onTap: () {
                                                                                                setStateInner(() {
                                                                                                  if (addons[i].contains(addOn)) {
                                                                                                    addons[i].remove(addOn);
                                                                                                  } else {
                                                                                                    addons[i].add(addOn);
                                                                                                  }
                                                                                                });
                                                                                                setStateCheckbox(() {}); // Ensures immediate checkbox UI update
                                                                                              },
                                                                                              child: Row(
                                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                children: [
                                                                                                  Expanded(
                                                                                                    child: Text(
                                                                                                      "$addOn (₹${addonPrices[addOn]})",
                                                                                                      style: const TextStyle(fontSize: 12),
                                                                                                      // overflow: TextOverflow.ellipsis,
                                                                                                    ),
                                                                                                  ),
                                                                                                  Checkbox(
                                                                                                    value: addons[i].contains(addOn),
                                                                                                    onChanged: (bool? selected) {
                                                                                                      setStateInner(() {
                                                                                                        if (selected == true) {
                                                                                                          addons[i].add(addOn);
                                                                                                        } else {
                                                                                                          addons[i].remove(addOn);
                                                                                                        }
                                                                                                      });
                                                                                                      setStateCheckbox(() {}); // Ensures immediate checkbox UI update
                                                                                                    },
                                                                                                    activeColor: Colors.teal,
                                                                                                  ),
                                                                                                ],
                                                                                              ),
                                                                                            );
                                                                                          },
                                                                                        ),
                                                                                      );
                                                                                    }).toList(),
                                                                                    onChanged: (_) {
                                                                                      // Ensures the dropdown reflects changes when closed
                                                                                      setStateInner(() {});
                                                                                    },
                                                                                  );
                                                                                },
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        Column(
                                                                          children: [
                                                                            StatefulBuilder(
                                                                              builder: (context, setStateInner) {
                                                                                return Checkbox(
                                                                                  value: type[i] == "Parcel",
                                                                                  onChanged: (value) {
                                                                                    type[i] = value! ? "Parcel" : "";
                                                                                    // Debugging output
                                                                                    setStateInner(() {}); // Update local state
                                                                                  },
                                                                                  activeColor: Colors.teal, // For active color
                                                                                  checkColor: Colors.white, // For tick mark color inside checkbox
                                                                                  side: const BorderSide(color: Colors.teal, width: 1.5), // Border color
                                                                                );
                                                                              },
                                                                            ),
                                                                            const Text("Parcel",
                                                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                                                                          ],
                                                                        ),
                                                                        Column(
                                                                          children: [
                                                                            if (toggleRemarks.length >
                                                                                i)
                                                                              Switch(
                                                                                value: toggleRemarks[i],
                                                                                onChanged: (value) {
                                                                                  toggleRemarks[i] = value;
                                                                                  (context as Element).markNeedsBuild();
                                                                                },
                                                                                activeColor: Colors.teal, // For active color
                                                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduced size
                                                                              ),
                                                                            const Text("Remark",
                                                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal))
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),

                                                                  // Third Row: Variants (if present) with Parcel Checkbox
                                                                  if (hasVariants)
                                                                    Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Flexible(
                                                                          child:
                                                                              StatefulBuilder(
                                                                            builder:
                                                                                (context, setStateInner) {
                                                                              return DropdownButtonFormField(
                                                                                decoration: const InputDecoration(
                                                                                  labelText: 'Variants',
                                                                                  border: OutlineInputBorder(),
                                                                                ),
                                                                                items: [
                                                                                  const DropdownMenuItem(
                                                                                    value: "Default",
                                                                                    child: Text("Default", style: TextStyle(fontSize: 12)),
                                                                                  ),
                                                                                  ...productProvider.variants
                                                                                      .map((v) => DropdownMenuItem(
                                                                                            value: v['variant'],
                                                                                            child: Text(v['variant'], style: const TextStyle(fontSize: 12)),
                                                                                          ))
                                                                                      .toList(),
                                                                                ],
                                                                                onChanged: (value) {
                                                                                  variants[i] = value.toString();
                                                                                  // Debugging output
                                                                                  setStateInner(() {});
                                                                                },
                                                                                value: variants[i], // Default to 'No Variant'
                                                                              );
                                                                            },
                                                                          ),
                                                                        ),
                                                                        Column(
                                                                          children: [
                                                                            StatefulBuilder(
                                                                              builder: (context, setStateInner) {
                                                                                return Checkbox(
                                                                                  value: type[i] == "Parcel",
                                                                                  onChanged: (value) {
                                                                                    type[i] = value! ? "Parcel" : "";
                                                                                    // Debugging output
                                                                                    setStateInner(() {}); // Update state
                                                                                  },
                                                                                  activeColor: Colors.teal, // For active color
                                                                                  checkColor: Colors.white, // For tick mark color inside checkbox
                                                                                  side: const BorderSide(color: Colors.teal, width: 1.5), // Border color
                                                                                );
                                                                              },
                                                                            ),
                                                                            const Text("Parcel",
                                                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                                                                          ],
                                                                        ),
                                                                        Column(
                                                                          children: [
                                                                            if (toggleRemarks.length >
                                                                                i)
                                                                              Switch(
                                                                                value: toggleRemarks[i],
                                                                                onChanged: (value) {
                                                                                  toggleRemarks[i] = value;
                                                                                  (context as Element).markNeedsBuild();
                                                                                },
                                                                                activeColor: Colors.teal, // For active color
                                                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduced size
                                                                              ),
                                                                            const Text("Remark",
                                                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal))
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  if (toggleRemarks[
                                                                      i])
                                                                    TextField(
                                                                      controller:
                                                                          remarkControllers[
                                                                              i],
                                                                      decoration:
                                                                          const InputDecoration(
                                                                        labelText:
                                                                            'Remark',
                                                                        border:
                                                                            OutlineInputBorder(),
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                            );
                                                          }),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                actions: [
                                                  ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.red,
                                                      foregroundColor:
                                                          Colors.white,
                                                    ),
                                                    child: const Text('Cancel'),
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.green,
                                                      foregroundColor:
                                                          Colors.white,
                                                    ),
                                                    child: const Text('OK'),
                                                    onPressed: () {

                                                      List<String> remarks =
                                                          remarkControllers
                                                              .map(
                                                                  (c) => c.text)
                                                              .toList();
                                                      // Perform further actions like saving to database or passing data
                                                      cartProvider.updateCart(
                                                          productId,
                                                          addons,
                                                          variants,
                                                          type,
                                                          remarks, // Save remarks
                                                          toggleRemarks); // Save updated data

                                                      Navigator.of(context)
                                                          .pop(); // Close the dialog

                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Positioned(
                                        top:
                                            40, // Adjust spacing between buttons
                                        right: 0,
                                        child: IconButton(
                                          icon: Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.red[200]),
                                          onPressed: () {
                                            cartProvider.removeItemFromCard(
                                                context,
                                                product.varianceName,
                                                widget.tableNumber,
                                                widget.seat);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (cartProvider.cart.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cart: (${cartProvider.cart.length} Items)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => productCardViewList(
                            tableNumber: widget.tableNumber,
                            seat: widget.seat,
                            onSubmit: _submitOrder, // Pass the method here
                          ),
                        ), // Example
                      );
                    },
                    child: Text(
                      'View to Cart >>',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.green[900],
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      // bottomNavigationBar: GlobalBottomNavReturn(
      //   onSelected: () {
      //     sendSeatReturnedActionToServer(
      //         widget.seat); // `currentSeat` should be tracked in state
      //   },
      // ),
    );
  }

  void showHintDialog(BuildContext context, String itemName) {
    showModalBottomSheet(
      context: context,
      isDismissible: false, // Prevent closing by tapping outside
      enableDrag: false, // Disable dragging to dismiss
      backgroundColor:
          Colors.transparent, // Transparent background for custom design
      builder: (context) {
        // Auto close the bottom sheet after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          // Use mounted check before calling Navigator
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Tap the itemName in cart to add Variants and Add-ons & Parcel.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // Close the bottom sheet
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

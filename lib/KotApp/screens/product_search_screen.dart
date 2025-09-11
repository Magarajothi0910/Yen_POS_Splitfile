import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../screens/kot_screen/global/globals.dart';
import '../kotproviders/cartprovider.dart';
import '../widgets/product_Search/holdDropdown.dart';

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
import '../widgets/bottomNav.dart';
import '../widgets/product_Search/cartItems_listview.dart';
import '../widgets/product_Search/idle_keyboard_hide.dart';
import '../widgets/product_Search/waiter_dropdown.dart';
import '../widgets/product_Search/pax_dropdown.dart';
import 'productsCard.dart';
import 'table_screen.dart';

class ProductSearchScreen extends StatefulWidget {
  final String tableNumber;
  final String seat;
  final String? seathiveOrderId;

  const ProductSearchScreen(
      {super.key,
      required this.tableNumber,
      required this.seat,
      required this.seathiveOrderId});

  @override
  // ignore: library_private_types_in_public_api
  _ProductSearchScreenState createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _searchController = TextEditingController();
  late WebSocketChannel channel;
  final String _selectedPax = "1"; // Default value for pax
  String? storedDeviceId;
  Duration debounceDuration = const Duration(milliseconds: 300);
  Timer? _debounce;
  String? selectedEmployee;
  late ScrollController _scrollController; // Add ScrollController
  // Add this at the top inside your _CartItemsState class
  bool isToggled = false;

  @override
  void initState() {
    super.initState();
    String url = 'ws://$serverip:$port';
    channel = IOWebSocketChannel.connect(url);
    loadDeviceCode();

    _scrollController = ScrollController(); // Initialize ScrollController

    _searchController.addListener(_onSearchChanged);
    Provider.of<SearchProvider>(context, listen: false).clearSearchQuery();
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
  }

  bool submitflag = false;

  void _submitOrder() {
    final holdOrderProvider =
        Provider.of<HoldOrderProvider>(context, listen: false);

    final submissionProvider =
        Provider.of<SubmissionProvider>(context, listen: false);

    final employeeProvider =
        Provider.of<EmployeeProvider>(context, listen: false);

    final waiter = selectedEmployee ?? employeeProvider.selectedWaiter;

    if (waiter == null || waiter.isEmpty) {
      Flushbar(
        message: 'Please Choose a waiter before submitting the order!',
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red[600] ?? Colors.red,
        flushbarPosition: FlushbarPosition.BOTTOM,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(20),
      ).show(context);
      return;
    }
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

                      try {
                        // Send data to server
                        await _processOrder(); // Replace this with your API call

                        // Clear hold orders and reset states
                        holdOrderProvider.removeHoldOrder(
                            widget.tableNumber, widget.seat);
                        submissionProvider.stopSubmitting();

                        setState(() {
                          _searchController.clear(); // Clear search input
                        });
                        Provider.of<SearchProvider>(context, listen: false)
                            .clearSearchQuery();
                        Provider.of<OrderTypeProvider>(context, listen: false)
                            .setOrderType('');

                        // Navigate to TableScreen after server response
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const TableScreen()),
                        );
                      } catch (error) {
                        // Handle errors
                        submissionProvider.stopSubmitting();

                        // ignore: use_build_context_synchronously
                        Flushbar(
                          message: 'Order submission failed: $error',
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.red[600] ?? Colors.red,
                          flushbarPosition: FlushbarPosition.BOTTOM,
                          margin: const EdgeInsets.all(8),
                          borderRadius: BorderRadius.circular(20),
                        ).show(context);
                        return;
                      }
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
  List<double> quantities = [];

  List<double> amounts = [];
  List<double> taxes = [];
  List<String> uoms = [];
  List<Map<String, dynamic>> parcelItems = [];
  List<String> itemRemark = [];
  String? orderRemark = "";
  String? partiallyCancelled = "";
  List<Map<String, dynamic>> addOnsList = []; // To store add-ons per product
  Future<void> _processOrder() async {
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
      double quantity = (entry.value['qty']?.toDouble() ?? 0.0);
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
      Map<String, dynamic> config = {
        "varianceName": product.varianceName,
        "weight": itemWeight, // Store weight as a float, not a list

        // Check if quantity is provided, otherwise default to empty list
        "configQty":
            quantity > 0 ? List.generate(quantity.toInt(), (i) => 1) : [],

        // Post empty string if addons are empty
        "addOn": addons.isEmpty ? [""] : addons,

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
      Provider.of<SearchProvider>(context, listen: false)
          .updateSearchQuery(_searchController.text);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
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

    if (_cartProvider.cart.isNotEmpty) {
      _holdOrderProvider.saveHoldOrder(
        widget.tableNumber,
        widget.seat,
        _cartProvider.cart,
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

    // Check if the seat has active or confirmed orders
    final isOccupied = ordersForSeat.any((order) =>
        (order['status'] == 'active' || order['status'] == 'confirm') &&
        order['seat'] == widget.seat &&
        order['table'] == widget.tableNumber);

    // Get the appropriate seathiveOrderId
    final seathiveOrderId =
        isOccupied ? ordersForSeat.first['seathiveOrderId'] ?? '' : '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Hides the back arrow
        backgroundColor: const Color(0xFFDBF0F7),

        title: Text(
          ' ${widget.tableNumber} - ${widget.seat}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: buildHoldOrdersDropdown(
                context, widget.tableNumber, widget.seat),
          ),

          SizedBox(
              height: 40, // Adjust the width as needed
              child: buildPaxDropdown(context)), //pax_dropdown.dart

          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   onPressed: () async {
          //     await Provider.of<ProductProvider>(context, listen: false)
          //         .fetchDataAndSaveInHive();
          //   },
          // ),
          SizedBox(
            width: 2,
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
                // Navigate to ProductSearchScreen and wait for result
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductCardScreen(
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
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 3.0),
            child: Row(
              //  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

                // SizedBox(
                //     width: 130,
                //     height: 50,
                //     child: buildWaiterDropdown(context)),

                Expanded(child: buildWaiterDropdown(context)),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
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
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(
                              color: Colors.black12, width: 2.0),
                        ),
                      ),
                      idleDuration: const Duration(
                          seconds: 2), // Customize the idle duration
                    ),
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

                return ListView.builder(
                  controller: _scrollController, // Attach ScrollController

                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isInCart =
                        cartProvider.cart.containsKey(product.varianceName);
                    final quantity = isInCart
                        ? cartProvider.cart[product.varianceName]['qty']
                        : 0;
                    bool isHintShown = false;

                    return ListTile(
                      title: GestureDetector(
                        onTap: () {
                          if (product.variance_Uom.toLowerCase() == "kg" ||
                              product.variance_Uom.toLowerCase() == "kgs") {
                            // showDialog(
                            //   context: context,
                            //   builder: (BuildContext context) {
                            //     return WeightSelectionDialog(
                            //       product: product,
                            //     );
                            //     // Use the new class
                            //   },
                            // );
                            cartProvider.addToCart(
                              product.varianceName,
                              weight: 50,
                            );
                            if (!isHintShown &&
                                cartProvider.cart.length == 1 &&
                                cartProvider.cart.values.first['qty'] == 1) {
                              showHintDialog(context, product.varianceName);
                              isHintShown =
                                  true; // Set the flag to true so it doesn't show again
                            }
                            _autoSaveHoldOrder();
                          } else {
                            cartProvider.addToCart(product.varianceName);
                            if (!isHintShown &&
                                cartProvider.cart.length == 1 &&
                                cartProvider.cart.values.first['qty'] == 1) {
                              showHintDialog(context, product.varianceName);
                              isHintShown =
                                  true; // Set the flag to true so it doesn't show again
                            }
                            _autoSaveHoldOrder();
                          }
                        },
                        child: Text(
                          "${product.name} - ${product.varianceName}",
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      subtitle:
                          Text('₹${product.price.toStringAsFixed(2) ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip
                                .none, // Allows the badge to appear outside the button
                            children: [
                              SizedBox(
                                height: 40,
                                width: 60,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (product.variance_Uom.toLowerCase() ==
                                            "kg" ||
                                        product.variance_Uom.toLowerCase() ==
                                            "kgs") {
                                      // showDialog(
                                      //   context: context,
                                      //   builder: (BuildContext context) {
                                      //     return WeightSelectionDialog(
                                      //       product: product,
                                      //     );
                                      //   },
                                      // );

                                      cartProvider.addToCart(
                                        product.varianceName,
                                        weight: 50,
                                      );
                                      if (!isHintShown &&
                                          cartProvider.cart.length == 1 &&
                                          cartProvider
                                                  .cart.values.first['qty'] ==
                                              1) {
                                        showHintDialog(
                                            context, product.varianceName);
                                        isHintShown =
                                            true; // Set the flag to true so it doesn't show again
                                      }
                                      _autoSaveHoldOrder();
                                    } else {
                                      cartProvider
                                          .addToCart(product.varianceName);
                                      if (!isHintShown &&
                                          cartProvider.cart.length == 1 &&
                                          cartProvider
                                                  .cart.values.first['qty'] ==
                                              1) {
                                        showHintDialog(
                                            context, product.varianceName);
                                        isHintShown =
                                            true; // Set the flag to true so it doesn't show again
                                      }
                                      _autoSaveHoldOrder();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.blue, // Button background color
                                    foregroundColor: Colors.white, // Text color
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0), // Padding
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          8.0), // Rounded corners
                                    ),
                                  ),
                                  child: const Text("Add"),
                                ),
                              ),
                              if (isInCart && quantity > 0)
                                Positioned(
                                  top:
                                      -10, // Adjust this to position the badge vertically
                                  right:
                                      -10, // Adjust this to position the badge horizontally
                                  child: Container(
                                    width: 24.0, // Fixed width for the badge
                                    height: 24.0, // Fixed height for the badge
                                    alignment: Alignment
                                        .center, // Centers the text inside the badge
                                    decoration: BoxDecoration(
                                      color: Colors
                                          .red, // Background color for the badge
                                      shape: BoxShape
                                          .circle, // Makes the badge circular
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(
                                              2, 2), // Adds a subtle shadow
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '$quantity',
                                      style: const TextStyle(
                                        color: Colors.white, // Text color
                                        fontSize:
                                            12, // Font size for the badge text
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            child: CartItems(
              tableNumber: widget.tableNumber,
              seat: widget.seat,
              onSubmit: _submitOrder, // Pass the method here
            ), //cartItems_listview.dart
          ),
        ],
      ),
      // bottomNavigationBar: const GlobalBottomNav(noSelection: true),
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

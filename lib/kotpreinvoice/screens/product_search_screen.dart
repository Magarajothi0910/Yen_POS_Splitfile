import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yenpos/Global/Provider/employee_provider.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import '../../kotpreinvoice/providers/bottomNavprovider.dart';
import '../components/flushbar.dart';
import '../widgets/product_Search/holdDropdown.dart';
import '../providers/cartprovider.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/fetchDiningTax.dart';
import 'package:yenpos/Global/globals_data.dart';
import '../models/product.dart';
import '../providers/employee_provider.dart';
import '../providers/hold_order.dart';
import '../providers/product_provider.dart';
import '../providers/order_type_provider.dart';
import '../providers/search_provider.dart';
import '../providers/submissionProvider.dart';
import '../providers/pax_provider.dart';
import '../widgets/bottomNav.dart';
import '../widgets/product_Search/cartItems_listview.dart';
import '../widgets/product_Search/idle_keyboard_hide.dart';
import '../widgets/product_Search/waiter_dropdown.dart';
import '../widgets/product_Search/pax_dropdown.dart';
import 'products_card_screen.dart';
import 'table_screen.dart';

// 🔔 ChangeNotifier to manage ProductSearchScreen state
class ProductSearchState extends ChangeNotifier {
  final TextEditingController _searchController = TextEditingController();
  // late WebSocketChannel channel;
  String _selectedPax = "1"; // Default value for pax
  String? storedDeviceId;
  String? _errorMessage; // 📌 Store error messages for UI display
  Duration debounceDuration = const Duration(milliseconds: 300);
  Timer? _debounce;
  String? selectedEmployee;
  late ScrollController _scrollController;
  bool isToggled = false;
  bool submitflag = false;

  // 📡 Getters for reactive state
  TextEditingController get searchController => _searchController;
  String get selectedPax => _selectedPax;
  String? get errorMessage => _errorMessage;
  ScrollController get scrollController => _scrollController;
  bool get submitFlag => submitflag;

  // 🛠️ Constructor with context for provider access
  ProductSearchState(
    BuildContext context, {
    required String tableNumber,
    required String seat,
    required String areaName,
    required String? seathiveOrderId,
  }) {
    _tableNumber = tableNumber;
    _seat = seat;
    _areaName = areaName;
    _seathiveOrderId = seathiveOrderId;
    _init(context);
  }

  // 📌 Private fields for widget params
  late final String _tableNumber;
  late final String _seat;
  late final String _areaName;
  late final String? _seathiveOrderId;

  // 🚀 Initialize state with error handling
  Future<void> _init(BuildContext context) async {
    try {
      // 🔌 Connect WebSocket with error handling
      // channel = IOWebSocketChannel.connect("ws://$serverip:$port");
      print('🔌 WebSocket connected successfully');

      // 💾 Load device code with error handling
      await loadDeviceCode();

      // 🎯 Setup search listener
      _searchController.addListener(() => _onSearchChanged(context));

      // 🧹 Clear initial search
      Provider.of<SearchProviderDine>(
        context,
        listen: false,
      ).clearSearchQuery();
      _searchController.clear();

      // 🧹 Initialize pax from provider
      final paxProvider = Provider.of<PaxProviderDine>(context, listen: false);
      _selectedPax = paxProvider.selectedPax;
      submitflag = false;
      _scrollController = ScrollController();

      notifyListeners(); // 🔔 Initial UI update
    } catch (e) {
      _errorMessage = 'Initialization failed: $e';
      print('❌ Init error: $e');
      notifyListeners(); // 🔔 Notify error state
    }
  }

  // 💾 Load device code from Hive with error handling
  Future<void> loadDeviceCode() async {
    try {
      var box = await Hive.openBox('deviceData'); // 📦 Ensure box is open
      storedDeviceId = box.get('deviceCode', defaultValue: 'UnknownDevice');
      print('💾 Device ID loaded: $storedDeviceId');
    } catch (e) {
      _errorMessage = 'Failed to load device code: $e';
      storedDeviceId = 'UnknownDevice'; // 📌 Fallback value
      print('❌ Hive error: $e');
    }
    notifyListeners(); // 🔔 Update UI if device ID changes
  }

  // 📤 Send data to server via WebSocket with error handling
  // Future<void> sendDataToServer(Map<String, dynamic> data) async {
  //   try {
  //     final jsonData = jsonEncode(data);
  //     channel.sink.add(jsonData);
  //     print('📤 Data sent to server: $jsonData');
  //   } catch (e) {
  //     _errorMessage = 'Failed to send data: $e';
  //     print('❌ Send error: $e');
  //     notifyListeners(); // 🔔 Notify error
  //     rethrow; // 🔄 Re-throw for caller handling
  //   }
  // }

  // 🔄 Toggle state and handle navigation
  Future<void> toggleState(BuildContext context) async {
    isToggled = !isToggled;
    notifyListeners(); // 🔔 Update toggle UI

    if (isToggled) {
      // 🚀 Navigate to ProductCardScreen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductCardScreen(
            tableNumber: _tableNumber,
            seat: _seat,
            areaName: _areaName,
            seathiveOrderId: _seathiveOrderId,
          ),
        ),
      );

      // 🔄 Handle return result
      if (result != null && result == 'toggle_off') {
        isToggled = false;
        notifyListeners(); // 🔔 Update UI
      }
    }
  }

  // 🎯 Handle search changes with debounce
  void _onSearchChanged(BuildContext context) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(debounceDuration, () {
      final searchProvider = Provider.of<SearchProviderDine>(
        context,
        listen: false,
      );
      searchProvider.updateSearchQuery(_searchController.text.trim());
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      notifyListeners(); // 🔔 Scroll and search update
    });
  }

  // 🧹 Clear search query
  void clearSearch(BuildContext context) {
    Provider.of<SearchProviderDine>(context, listen: false).clearSearchQuery();
    _searchController.clear();
    FocusScope.of(context).unfocus();
    notifyListeners(); // 🔔 UI refresh
  }

  // 👤 Update selected employee
  void updateSelectedEmployee(String? employee, BuildContext context) {
    if (employee != null) {
      selectedEmployee = employee;
      Provider.of<EmployeeProvider>(
        context,
        listen: false,
      ).setSelectedWaiter(employee); // 📌 Sync with EmployeeProvider
      notifyListeners(); // 🔔 Update waiter dropdown
      print('👤 Selected employee updated: $selectedEmployee');
    }
  }

  // 👥 Update selected pax
  void updateSelectedPax(String? pax, BuildContext context) {
    if (pax != null) {
      _selectedPax = pax;
      Provider.of<PaxProviderDine>(
        context,
        listen: false,
      ).setSelectedPax(pax); // 📌 Sync with PaxProvider
      notifyListeners(); // 🔔 Update pax dropdown
      print('👥 Selected pax updated: $_selectedPax');
    }
  }

  // 💾 Auto-save hold order
  void _autoSaveHoldOrder(BuildContext context) {
    final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);
    final holdOrderProvider = Provider.of<HoldOrderProvider>(
      context,
      listen: false,
    );
    if (cartProvider.cart.isNotEmpty) {
      holdOrderProvider.saveHoldOrder(_tableNumber, _seat, cartProvider.cart);
      print('💾 Hold order saved for table $_tableNumber, seat $_seat');
    }
  }

  // 🗑️ Cleanup resources
  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    // channel.sink.close();
    super.dispose();
    print('🗑️ ProductSearchState disposed');
  }

  // 📤 Submit order with validation and error handling
  void _submitOrder(BuildContext context) {
    final holdOrderProvider = Provider.of<HoldOrderProvider>(
      context,
      listen: false,
    );
    final submissionProvider = Provider.of<SubmissionProviderDine>(
      context,
      listen: false,
    );
    final employeeProvider = Provider.of<EmployeeProvider>(
      context,
      listen: false,
    );
    final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);

    final waiter = selectedEmployee ?? employeeProvider.selectedWaiter;

    // 👨‍🍳 Waiter validation
    if (waiter == null || waiter.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomFlushbar(
          context,
          'Please choose a waiter before submitting the order!',
          type: FlushbarType.warning,
        );
      });
      debugPrint('🚨 Waiter validation failed');
      return;
    }

    // 🛒 Cart validation
    if (cartProvider.cart.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomFlushbar(
          context,
          'Please add items to the cart!',
          type: FlushbarType.warning,
        );
      });
      debugPrint('🚨 Cart validation failed');
      return;
    }

    // 🔍 Pax validation
    if (_selectedPax.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomFlushbar(
          context,
          'Please select a valid pax number!',
          type: FlushbarType.warning,
        );
      });
      debugPrint('🚨 Pax validation failed');
      return;
    }

    // 💬 Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          "Confirm Submission..",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to submit the order for $_tableNumber?",
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: Colors.red,
              foregroundColor: Colors.black,
            ),
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: const Color(0xFFA5D6A7),
              foregroundColor: Colors.black,
            ),
            onPressed: submissionProvider.isSubmitting
                ? null
                : () async {
                    submissionProvider.startSubmitting();
                    submitflag = true;
                    notifyListeners(); // 🔔 Update submission state

                    try {
                      // 📦 Process and send order
                      await _processOrder(context);

                      // 🧹 Cleanup after success
                      holdOrderProvider.removeHoldOrder(_tableNumber, _seat);
                      submissionProvider.stopSubmitting();
                      submitflag = false;
                      _searchController.clear();
                      Provider.of<SearchProviderDine>(
                        context,
                        listen: false,
                      ).clearSearchQuery();
                      Provider.of<OrderTypeProviderDine>(
                        context,
                        listen: false,
                      ).setOrderType('');

                      // 🔄 Navigate to TableScreen
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        // Navigator.pushReplacement(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) => const TableScreen(),
                        //   ),
                        // );
                        print('🔄 Navigated to TableScreen');
                        // Provider.of<BottomNavProviderKOT>(context, listen: false).updateIndex(0);
                      }
                    } catch (e, stack) {
                      // ❌ Handle submission error
                      submissionProvider.stopSubmitting();
                      submitflag = false;

                      // Show flushbar safely
                      if (context.mounted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          showCustomFlushbar(
                            context,
                            'Order submission failed: $e',
                            type: FlushbarType.error,
                          );
                        });
                      } else {
                        debugPrint('⚠️ Skipped flushbar, context disposed');
                      }

                      debugPrint('❌ Submission error: $e\n$stack');

                      // Close the dialog safely
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    }

                    notifyListeners(); // 🔔 Refresh UI after submission
                  },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  // 🔄 Process order data with error handling
  Future<void> _processOrder(BuildContext context) async {
    final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final orderTypeProvider = Provider.of<OrderTypeProviderDine>(
      context,
      listen: false,
    );
    final employeeProvider = Provider.of<EmployeeProvider>(
      context,
      listen: false,
    );

    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('dd-MM-yyyy').format(now);
      final formattedTime = DateFormat('hh:mm:ss a').format(now);
      double totalAddonsAmount = 0.0;
      double diningTaxPercentage = getTaxPercentage();
      List<Map<String, dynamic>> configs = [];
      Map<String, double> varianceWeights = {};

      // 📊 Build order data
      List<String> itemNames = [];
      List<String> varianceNames = [];
      List<String> varianceItemCodes = [];
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

      for (var entry in cartProvider.cart.entries) {
        final product = productProvider.products.firstWhere(
          (product) => product.varianceName == entry.key,
          orElse: () => throw Exception(
            'Product not found: ${entry.key}',
          ), // 🔍 Error if product missing
        );

        itemNames.add(product.name);
        varianceNames.add(product.varianceName);
        varianceItemCodes.add(product.varianceitemCode);
        double price = product.price.toDouble();
        prices.add(price);
        double quantity = (entry.value['qty']?.toDouble() ?? 0.0);
        quantities.add(quantity);
        String uom = product.variance_Uom;
        uoms.add(uom);
        double total = 0.0;
        double weight = (entry.value['weight']?.toDouble() ?? 0.0);
        if (uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'Kgs') {
          weight /= 1000;
        }
        weights.add(weight);
        if (uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'Kgs') {
          total = price * quantity * weight;
        } else {
          total = price * quantity;
        }
        amounts.add(total);
        taxes.add(diningTaxPercentage);

        // 🛠️ Build configs for addons/variants
        List<List<String>> addons = List.generate(quantity.toInt(), (i) {
          if (entry.value['addons'] != null &&
              entry.value['addons'].length > i) {
            final addon = entry.value['addons'][i];
            return addon is List<String> ? addon : [addon.toString()];
          }
          return <String>[];
        });

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
              : "",
        );

        varianceWeights[product.varianceName] = weight;

        double itemWeight = varianceWeights[product.varianceName] ?? 0.0;
        Map<String, dynamic> config = {
          "varianceName": product.varianceName,
          "weight": itemWeight,
          "configQty": quantity > 0
              ? List.generate(quantity.toInt(), (i) => 1)
              : [],
          "addOn": addons.isEmpty ? [""] : addons,
          "variance": variants.contains('Default') ? [""] : variants,
          "type": type.isEmpty ? [""] : type,
          "remark": remarks.isEmpty ? [""] : remarks,
        };
        configs.add(config);
      }

      final double totalAmount =
          amounts.fold(0.0, (sum, item) => sum + item) + totalAddonsAmount;

      // 📦 Prepare final order payload
      final order = {
        'type': 'order',
        'date': formattedDate,
        'time': formattedTime,
        'branchName': branchName,
        'aliasName': aliasname,
        'table': _tableNumber,
        'seat': _seat,
        'areaName': _areaName,
        'deviceId': storedDeviceId,
        'itemNames': itemNames,
        'varianceNames': varianceNames,
        'varianceitemCodes': varianceItemCodes,
        'prices': prices,
        'weights': weights,
        'quantities': quantities,
        'cancelledQty': List.filled(itemNames.length, 0.0),
        'amounts': amounts,
        'taxes': taxes,
        'uoms': uoms,
        'pax': _selectedPax,
        'status': "active",
        'waiter': createdBy,
        'orderType': orderTypeProvider.orderType,
        'totalAmount': totalAmount,
        'seathiveOrderId': _seathiveOrderId ?? '',
        'itemRemark': itemRemark,
        'orderRemark': orderRemark,
        'partiallyCancelled': partiallyCancelled,
        'config': configs,
        'sync': "No",
        'edit': "No",
        'statusEdited': "false",
        'fieldsEdited': "false",
        'userName': userName,
      };

      // 📤 Send if not server mode
      if (appType != 'server') {
        await sendataToServer(order);
      }

      // 🧹 Clear cart after success
      cartProvider.clearCart();
      print('✅ Order processed and sent successfully');
    } catch (e) {
      print('❌ Process order error: $e');
      rethrow; // 🔄 Pass error up
    }
  }

  // 💬 Show hint dialog for first cart item
  void showHintDialog(BuildContext context, String itemName) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        // ⏱️ Auto-close after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Tap the itemName in cart to add Variants and Add-ons & Parcel.",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
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

  // 📊 Filter products based on query
  List<Product> _filteredProducts(List<Product> products, String query) {
    if (query.isEmpty) return products;
    final lowerQuery = query.toLowerCase();
    return products
        .where(
          (product) =>
              product.name.toLowerCase().contains(lowerQuery) ||
              product.varianceName.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  // 🔄 Retry initialization on error
  Future<void> retryInit(BuildContext context) async {
    _errorMessage = null;
    await _init(context);
    notifyListeners(); // 🔔 Refresh UI after retry
  }
}

// 🖼️ Main StatelessWidget
class ProductSearchScreen extends StatelessWidget {
  final String tableNumber;
  final String seat;
  final String areaName;
  final String? seathiveOrderId;

  const ProductSearchScreen({
    super.key,
    required this.tableNumber,
    required this.seat,
    required this.areaName,
    required this.seathiveOrderId,
  });

  @override
  Widget build(BuildContext context) {
    // 🛠️ Provide state to widget tree
    return ChangeNotifierProvider(
      create: (ctx) => ProductSearchState(
        ctx,
        tableNumber: tableNumber,
        seat: seat,
        areaName: areaName,
        seathiveOrderId: seathiveOrderId,
      ),
      child: Consumer<ProductSearchState>(
        builder: (context, state, _) {
          // 🚨 Show error screen if initialization failed
          if (state.errorMessage != null) {
            return Scaffold(
              appBar: AppBar(
                title: Text('$tableNumber - $seat'),
                backgroundColor: Colors.white,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => state.retryInit(context),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // ⏳ Show loading if device ID not loaded
          if (state.storedDeviceId == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return _buildMainUI(context, state);
        },
      ),
    );
  }

  // 🏗️ Build main UI scaffold
  Widget _buildMainUI(BuildContext context, ProductSearchState state) {
    final productProvider = Provider.of<ProductProvider>(context);
    final cartProvider = Provider.of<CartProviderKOT>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          '$tableNumber - $seat',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          Flexible(
            fit: FlexFit.loose,
            child: Padding(
              padding: const EdgeInsets.only(right: 5.0),
              // child: buildHoldOrdersDropdown`(context, tableNumber, seat),
            ),
          ),
          // SizedBox(
          //   width: 90,
          //   child: buildPaxDropdown(context, onChanged: (value) {
          //     state.updateSelectedPax(value, context);
          //   }),
          // ),
          const SizedBox(width: 2),
          Flexible(
            fit: FlexFit.loose,
            child: ToggleButtons(
              isSelected: [state.isToggled],
              onPressed: (_) => state.toggleState(context),
              borderColor: Colors.transparent,
              selectedBorderColor: Colors.transparent,
              fillColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              children: [
                Icon(
                  Icons.toggle_on,
                  color: state.isToggled ? Colors.green : Colors.grey,
                  size: 36,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search row with waiter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 3.0),
            child: Row(
              children: [
                Expanded(
                  child: buildWaiterDropdown(
                    context,
                    onChanged: (value) {
                      state.updateSelectedEmployee(value, context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: IdleKeyboardHide(
                      controller: state.searchController,
                      decoration: InputDecoration(
                        hintText: 'Search Products',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => state.clearSearch(context),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(
                            color: Colors.black12,
                            width: 2.0,
                          ),
                        ),
                      ),
                      idleDuration: const Duration(seconds: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 📱 Product list
          Expanded(
            child: Consumer<SearchProviderDine>(
              builder: (context, searchProvider, child) {
                final products = state._filteredProducts(
                  productProvider.products,
                  searchProvider.searchQuery,
                );
                if (products.isEmpty) {
                  return const Center(child: Text('No products found.'));
                }
                return ListView.builder(
                  controller: state.scrollController,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isInCart = cartProvider.cart.containsKey(
                      product.varianceName,
                    );
                    final quantity = isInCart
                        ? cartProvider.cart[product.varianceName]!['qty'] ?? 0
                        : 0;
                    bool isHintShown = false;
                    return ListTile(
                      title: GestureDetector(
                        onTap: () {
                          _addToCart(
                            context,
                            state,
                            cartProvider,
                            product,
                            isHintShown,
                          );
                          state._autoSaveHoldOrder(context);
                        },
                        child: Text(
                          "${product.name} - ${product.varianceName}",
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      subtitle: Text('₹${product.price.toStringAsFixed(2)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SizedBox(
                                height: 40,
                                width: 60,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _addToCart(
                                      context,
                                      state,
                                      cartProvider,
                                      product,
                                      isHintShown,
                                    );
                                    state._autoSaveHoldOrder(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text("Add"),
                                ),
                              ),
                              if (isInCart && quantity > 0)
                                Positioned(
                                  top: -10,
                                  right: -10,
                                  child: Container(
                                    width: 24.0,
                                    height: 24.0,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '$quantity',
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
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // 🛒 Cart section (conditional, scrollable, limited to half screen)
          Consumer<CartProviderKOT>(
            builder: (context, cartProvider, child) {
              if (cartProvider.cart.isEmpty) {
                return const SizedBox.shrink(); // Hide if cart is empty
              }
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height *
                      0.5, // Limit to half screen height
                ),
                child: SingleChildScrollView(
                  child: CartItems(
                    tableNumber: tableNumber,
                    seat: seat,
                    onSubmit: () => state._submitOrder(context),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // bottomNavigationBar: const GlobalBottomNav(noSelection: true),
    );
  }

  // ➕ Helper to add item to cart with hint logic
  void _addToCart(
    BuildContext context,
    ProductSearchState state,
    CartProviderKOT cartProvider,
    Product product,
    bool isHintShown,
  ) {
    final uom = product.variance_Uom.toLowerCase();
    if (uom == "kg" || uom == "Kgs") {
      cartProvider.addToCart(product.varianceName, weight: 50);
    } else {
      cartProvider.addToCart(product.varianceName);
    }

    // 💡 Show hint for first item
    if (!isHintShown &&
        cartProvider.cart.length == 1 &&
        cartProvider.cart.values.first['qty'] == 1) {
      state.showHintDialog(context, product.varianceName);
      print('💡 Hint dialog shown for ${product.varianceName}');
    }
  }
}

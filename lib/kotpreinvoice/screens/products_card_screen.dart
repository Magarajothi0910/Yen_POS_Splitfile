import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Server_Client/websocketService.dart';
import '../utils/custom_snackbar.dart';
import '../services/websocketService.dart';
import '../widgets/product_Search/holdDropdown.dart';
import '../widgets/seatReturnBottomNav.dart';
import '../providers/cartprovider.dart';
import '../models/product.dart';
import '../providers/hold_order.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/product_Search/idle_keyboard_hide.dart';
import 'product_search_screen.dart';
import 'viewtocart.dart';

// Product Event Model for communication
class ProductEvent {
  final String action;
  final String tableNumber;
  final String seat;
  final String areaName;
  final String? productName;
  final Map<String, dynamic>? productData;

  ProductEvent({
    required this.action,
    required this.tableNumber,
    required this.seat,
    required this.areaName,
    this.productName,
    this.productData,
  });

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'tableNumber': tableNumber,
      'seat': seat,
      'areaName': areaName,
      'productName': productName,
      'productData': productData,
    };
  }

  factory ProductEvent.fromJson(Map<String, dynamic> json) {
    return ProductEvent(
      action: json['action'],
      tableNumber: json['tableNumber'],
      seat: json['seat'],
      areaName: json['areaName'],
      productName: json['productName'],
      productData: json['productData'],
    );
  }
}

// Event Provider for cross-screen communication
class ProductEventProvider extends ChangeNotifier {
  final List<ProductEvent> _events = [];
  final Map<String, List<Map<String, dynamic>>> _tableProducts = {};

  List<ProductEvent> get events => _events;

  Map<String, List<Map<String, dynamic>>> get tableProducts => _tableProducts;

  void addEvent(ProductEvent event) {
    _events.add(event);
    _updateTableProducts(event);
    notifyListeners();
  }

  void clearEvents() {
    _events.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> getProductsForTable(
    String tableNumber,
    String seat,
  ) {
    final key = '$tableNumber-$seat';
    return _tableProducts[key] ?? [];
  }

  void _updateTableProducts(ProductEvent event) {
    final key = '${event.tableNumber}-${event.seat}';

    if (!_tableProducts.containsKey(key)) {
      _tableProducts[key] = [];
    }

    final products = _tableProducts[key]!;

    switch (event.action) {
      case 'add':
      case 'update':
        if (event.productData != null) {
          final varianceName = event.productData!['varianceName'];
          final newQuantity = event.productData!['quantity'] ?? 1;
          final price =
              event.productData!['price'] ?? 0.0; // Ensure price is included

          // Check if product already exists
          final existingIndex = products.indexWhere(
            (p) => p['varianceName'] == varianceName,
          );

          if (existingIndex != -1) {
            // Update quantity and price if exists
            products[existingIndex]['quantity'] = newQuantity;
            products[existingIndex]['price'] = price; // Update price too
            products[existingIndex]['name'] =
                event.productData!['name'] ?? products[existingIndex]['name'];
          } else {
            // Add new product with price
            products.add({
              ...event.productData!,
              'quantity': newQuantity,
              'price': price, // Ensure price is set
              'addedAt': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }
        break;

      case 'remove':
        if (event.productName != null) {
          products.removeWhere((p) => p['varianceName'] == event.productName);
        }
        break;

      case 'clear':
        products.clear();
        break;
    }

    // Sort by addition time
    products.sort((a, b) => (a['addedAt'] ?? 0).compareTo(b['addedAt'] ?? 0));
    notifyListeners();
  }

  void removeProduct(String tableNumber, String seat, String productName) {
    final key = '$tableNumber-$seat';
    if (_tableProducts.containsKey(key)) {
      _tableProducts[key]!.removeWhere((p) => p['varianceName'] == productName);
      notifyListeners();
    }
  }

  void clearTableProducts(String tableNumber, String seat) {
    final key = '$tableNumber-$seat';
    if (_tableProducts.containsKey(key)) {
      _tableProducts[key]!.clear();
      notifyListeners();
    }
  }
}

// Cart Item Dialog State
class CartItemDialogState extends ChangeNotifier {
  List<List<String>> addons;
  List<List<int>> addonQuantities;
  List<String> variants;
  List<String> type;
  List<bool> toggleRemarks;
  List<String> remarks;
  List<int> configQty;
  TextEditingController remarkController;
  FocusNode focusNode;

  CartItemDialogState({
    required this.addons,
    required this.addonQuantities,
    required this.variants,
    required this.type,
    required this.toggleRemarks,
    required this.remarks,
    required this.configQty,
    required this.remarkController,
    required this.focusNode,
  });

  void updateAddOn(int index, String addOnName, bool add, int quantity) {
    if (add) {
      addons[index].add(addOnName);
      addonQuantities[index].add(quantity);
    } else {
      final addOnIndex = addons[index].indexOf(addOnName);
      if (addOnIndex != -1) {
        addons[index].removeAt(addOnIndex);
        addonQuantities[index].removeAt(addOnIndex);
      }
    }
    notifyListeners();
  }

  void updateAddOnQuantity(int itemIndex, int addOnIndex, int newQuantity) {
    if (addOnIndex < addonQuantities[itemIndex].length) {
      addonQuantities[itemIndex][addOnIndex] = newQuantity;
      notifyListeners();
    }
  }

  void updateVariant(int index, String variant) {
    variants[index] = variant;
    notifyListeners();
  }

  void updateType(int index, bool isParcel) {
    type[index] = isParcel ? "Parcel" : "";
    notifyListeners();
  }

  void updateToggleRemark(int index, bool value) {
    toggleRemarks[index] = value;
    if (!value) {
      remarks[index] = "";
    }
    notifyListeners();
  }

  void updateRemark(int index, String remark) {
    remarks[index] = remark;
    notifyListeners();
  }

  @override
  void dispose() {
    remarkController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

class ProductCardScreen extends StatefulWidget {
  final String tableNumber;
  final String seat;
  final String areaName;
  final String? seathiveOrderId;
  final VoidCallback? onClose;

  const ProductCardScreen({
    super.key,
    required this.tableNumber,
    required this.seat,
    required this.areaName,
    required this.seathiveOrderId,
    this.onClose,
  });

  @override
  _ProductCardScreenState createState() => _ProductCardScreenState();
}

class _ProductCardScreenState extends State<ProductCardScreen> {
  final _searchController = TextEditingController();
  WebSocketChannel? channel;
  String? storedDeviceId;
  Duration debounceDuration = const Duration(milliseconds: 300);
  Timer? _debounce;

  late CartProviderKOT _cartProvider;
  late HoldOrderProvider _holdOrderProvider;
  late ProductEventProvider _eventProvider;
  late ScrollController _scrollController;
  bool submitflag = false;

  Box? quickAccessBox;

  // Helper method to create fallback product with all required parameters
  Product _createFallbackProduct(
    String varianceName, {
    String category = 'Unknown',
    double price = 0.0,
  }) {
    return Product(
      id: 'fallback_${varianceName}_${DateTime.now().millisecondsSinceEpoch}',
      name: varianceName,
      varianceitemCode: 'fallback_$varianceName',
      variance_Uom: 'pcs',
      weight: 0.0,
      price: price.toInt(),
      tax: 0,
      varianceName: varianceName,
      category: category,
      localHiveStock: 0,
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _searchController.addListener(_onSearchChanged);
    _searchController.clear();
    submitflag = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Provider.of<CartProviderKOT>(context, listen: false).setToggled(false);
        print('✅ CartProvider.isToggled initialized to false after build');

        // Send initial products to table screen
        _sendInitialProductsToTable();
      } catch (e) {
        print('❌ Error initializing CartProvider.isToggled: $e');
      }
    });
  }

  void _sendInitialProductsToTable() {
    final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);
    final eventProvider = Provider.of<ProductEventProvider>(
      context,
      listen: false,
    );

    // Clear existing products for this table-seat
    eventProvider.addEvent(
      ProductEvent(
        action: 'clear',
        tableNumber: widget.tableNumber,
        seat: widget.seat,
        areaName: widget.areaName,
      ),
    );

    // Send all current cart products
    cartProvider.cart.forEach((productName, productData) {
      final currentQuantity = productData['qty'] ?? 0;
      final product = ProductEvent(
        action: 'add',
        tableNumber: widget.tableNumber,
        seat: widget.seat,
        areaName: widget.areaName,
        productName: productName,
        productData: {
          'varianceName': productName,
          'name': productData['name'] ?? productName,
          'price': productData['price'] ?? 0.0,
          'quantity': currentQuantity,
          'addons': productData['addons'] ?? [],
          'variants': productData['variants'] ?? [],
        },
      );
      eventProvider.addEvent(product);
    });
  }

  void _sendProductEvent(
    String action,
    String productName, [
    Map<String, dynamic>? productData,
  ]) {
    final eventProvider = Provider.of<ProductEventProvider>(
      context,
      listen: false,
    );

    final event = ProductEvent(
      action: action,
      tableNumber: widget.tableNumber,
      seat: widget.seat,
      areaName: widget.areaName,
      productName: productName,
      productData: productData,
    );

    eventProvider.addEvent(event);
    print('📤 Sent product event: $action for $productName');
  }

  void _showQuickAccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer<QuickAccessProvider>(
          builder: (context, quickAccessProvider, _) {
            final quickAccessProducts = quickAccessProvider.quickAccessProducts;
            final productProvider = Provider.of<ProductProvider>(
              context,
              listen: false,
            );

            return AlertDialog(
              title: const Text(
                'Quick Access Products',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: quickAccessProducts.isEmpty
                    ? const Center(
                        child: Text(
                          'No quick access products.\nLong-press a product to add.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: quickAccessProducts.length,
                        itemBuilder: (ctx, i) {
                          final varianceName = quickAccessProducts[i];
                          final product = productProvider.products.firstWhere(
                            (p) => p.varianceName == varianceName,
                            orElse: () => _createFallbackProduct(
                              varianceName,
                              category: 'Quick Access',
                            ),
                          );

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            elevation: 2,
                            child: ListTile(
                              leading: const Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 18,
                              ),
                              title: Text(
                                product.varianceName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '₹${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  await quickAccessProvider
                                      .removeFromQuickAccess(
                                        varianceName,
                                        context,
                                      );
                                },
                              ),
                              onTap: () {
                                try {
                                  if (product.variance_Uom.toLowerCase() ==
                                          "kg" ||
                                      product.variance_Uom.toLowerCase() ==
                                          "kgs") {
                                    _cartProvider.addToCart(
                                      varianceName,
                                      weight: 50,
                                    );
                                  } else {
                                    _cartProvider.addToCart(varianceName);
                                  }
                                  _autoSaveHoldOrder();

                                  // Send product add event
                                  _sendProductEvent('add', varianceName, {
                                    'varianceName': varianceName,
                                    'name': product.name,
                                    'price': product.price.toDouble(),
                                    'quantity': 1,
                                  });

                                  Navigator.of(ctx).pop();
                                } catch (e) {
                                  debugPrint(
                                    '❌ Error adding quick access to cart: $e',
                                  );
                                  CustomSnackBar.show(
                                    context,
                                    'Error adding to cart: $e',
                                    type: SnackType.error,
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void sendSeatReturnedActionToServer(String seat) {
    final webSocketService = Provider.of<WebSocketService>(
      context,
      listen: false,
    );
    final returnData = {
      'action': 'seat_returned',
      'tableNumber': widget.tableNumber,
      'seat': seat,
    };
    webSocketService.channel!.sink.add(jsonEncode(returnData));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    channel?.sink.close();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(debounceDuration, () {
      Stopwatch stopwatch = Stopwatch()..start();

      var searchText = _searchController.text;
      Provider.of<SearchProviderDine>(
        context,
        listen: false,
      ).updateSearchQuery(searchText);

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

  List<Product> _filterBySubcategory(
    List<Product> products,
    String? selectedCategory,
  ) {
    if (selectedCategory == null) {
      return products;
    }

    // Handle Favorites category
    if (selectedCategory == 'Favorites') {
      final quickAccessProvider = Provider.of<QuickAccessProvider>(
        context,
        listen: false,
      );
      final favoriteProducts = quickAccessProvider.quickAccessProducts;

      return products.where((product) {
        return favoriteProducts.contains(product.varianceName);
      }).toList();
    }

    // Regular category filtering
    return products
        .where((product) => product.category == selectedCategory)
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cartProvider = Provider.of<CartProviderKOT>(context, listen: false);
    _holdOrderProvider = Provider.of<HoldOrderProvider>(context, listen: false);
    _eventProvider = Provider.of<ProductEventProvider>(context, listen: false);
  }

  void _autoSaveHoldOrder() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final ordersForSeat = orderProvider.getRunningOrdersForSeat(
      widget.tableNumber,
      widget.seat,
    );

    bool hasActiveOrder = ordersForSeat.any(
      (order) => order['status'] == 'active',
    );
    if (_cartProvider.cart.isNotEmpty && !hasActiveOrder) {
      _holdOrderProvider.saveHoldOrder(
        widget.tableNumber,
        widget.seat,
        _cartProvider.cart,
      );
    }
  }

  // ENHANCED: Add to cart with incremental quantity
  // ENHANCED: Add to cart with incremental quantity and proper data
  void _addToCartWithEvent(String varianceName, {int? weight}) {
    try {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      final product = productProvider.products.firstWhere(
        (p) => p.varianceName == varianceName,
        orElse: () => _createFallbackProduct(varianceName),
      );

      // Get current quantity from cart
      final currentQuantity = _cartProvider.cart[varianceName]?['qty'] ?? 0;
      final newQuantity = currentQuantity + 1;

      // Add to cart (this should handle incremental quantity in your cart provider)
      if (weight != null) {
        _cartProvider.addToCart(varianceName, weight: weight);
      } else {
        _cartProvider.addToCart(varianceName);
      }

      _autoSaveHoldOrder();

      // Send product update event with COMPLETE product data
      _sendProductEvent('update', varianceName, {
        'varianceName': varianceName,
        'name': product.name,
        'price': product.price.toDouble(),
        'quantity': newQuantity,
        'addons': _cartProvider.cart[varianceName]?['addons'] ?? [],
        'variants': _cartProvider.cart[varianceName]?['variants'] ?? [],
      });

      print('➕ Increased $varianceName quantity to $newQuantity');
    } catch (e) {
      print('❌ Error adding to cart: $e');
      CustomSnackBar.show(
        context,
        'Error adding to cart: $e',
        type: SnackType.error,
      );
    }
  }

  void _removeFromCartWithEvent(String varianceName) {
    try {
      // Get current quantity from cart
      final currentQuantity = _cartProvider.cart[varianceName]?['qty'] ?? 0;

      if (currentQuantity > 1) {
        // Decrease quantity by 1
        final newQuantity = currentQuantity - 1;

        // Update cart with decreased quantity
        _updateCartQuantity(varianceName, newQuantity);

        // Get product data for the event
        final productProvider = Provider.of<ProductProvider>(
          context,
          listen: false,
        );
        final product = productProvider.products.firstWhere(
          (p) => p.varianceName == varianceName,
          orElse: () => _createFallbackProduct(varianceName),
        );

        // Send product update event with CORRECT product data
        _sendProductEvent('update', varianceName, {
          'varianceName': varianceName,
          'name': product.name,
          'price': product.price.toDouble(),
          'quantity': newQuantity,
          'addons': _cartProvider.cart[varianceName]?['addons'] ?? [],
          'variants': _cartProvider.cart[varianceName]?['variants'] ?? [],
        });

        print('➖ Decreased $varianceName quantity to $newQuantity');
      } else {
        // Remove product completely if quantity is 1
        _cartProvider.removeItemFromCard(
          context,
          varianceName,
          widget.tableNumber,
          widget.seat,
        );

        // Send product remove event
        _sendProductEvent('remove', varianceName);

        print('🗑️ Removed $varianceName from cart');
      }

      _autoSaveHoldOrder();
    } catch (e) {
      print('❌ Error removing item from cart: $e');
      CustomSnackBar.show(
        context,
        'Error removing item: $e',
        type: SnackType.error,
      );
    }
  }

  // Helper method to update cart quantity
  void _updateCartQuantity(String productName, int newQuantity) {
    if (_cartProvider.cart.containsKey(productName)) {
      if (newQuantity > 0) {
        _cartProvider.cart[productName]!['qty'] = newQuantity;
        _cartProvider.notifyListeners();
      } else {
        // Remove product if quantity becomes 0
        _cartProvider.cart.remove(productName);
        _cartProvider.notifyListeners();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final productProvider = Provider.of<ProductProvider>(context);
      final cartProvider = Provider.of<CartProviderKOT>(context);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(context);

      print(
        '✅ Building widget for Table ${widget.tableNumber}, Seat ${widget.seat}, Area ${widget.areaName}',
      );

      final ordersForSeat = orderProvider.getActiveOrdersForSeat(
        widget.tableNumber,
        widget.seat,
      );
      final isOccupied = ordersForSeat.any((order) {
        try {
          return (order['status'] == 'active' ||
                  order['status'] == 'confirm') &&
              order['seat'] == widget.seat &&
              order['table'] == widget.tableNumber;
        } catch (e) {
          print('❌ Error checking order status: $e');
          return false;
        }
      });

      final seathiveOrderId = isOccupied
          ? ordersForSeat.first['seathiveOrderId'] ?? ''
          : '';
      print(
        'ℹ️ Seat occupation status: ${isOccupied ? "Occupied" : "Free"} (OrderID: $seathiveOrderId)',
      );

      final Set<String> subcategories = productProvider.products
          .map((p) => p.category)
          .where((category) => category != null && category.isNotEmpty)
          .toSet();

      // Add Favorites to subcategories if there are any favorites
      final quickAccessProvider = Provider.of<QuickAccessProvider>(context);
      if (quickAccessProvider.quickAccessProducts.isNotEmpty) {
        subcategories.add('Favorites');
      }

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () {
              widget.onClose?.call();
            },
          ),
          title: Text(
            ' ${widget.tableNumber} - Seat ${widget.seat}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () => _showQuickAccessDialog(context),
              tooltip: 'Quick Access',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                try {
                  print('🔄 Refreshing data...');
                  final productProvider = Provider.of<ProductProvider>(
                    context,
                    listen: false,
                  );
                  await productProvider.fetchDataAndSaveInHive(context);
                  print('✅ Successfully refreshed server data');
                } catch (e) {
                  print('❌ Error during refresh: $e');
                  CustomSnackBar.show(
                    context,
                    'Error refreshing data: $e',
                    type: SnackType.error,
                  );
                }
              },
            ),
            Consumer<CartProviderKOT>(
              builder: (context, cartProvider, child) {
                return ToggleButtons(
                  isSelected: [cartProvider.isToggled],
                  onPressed: (index) async {
                    try {
                      cartProvider.setToggled(!cartProvider.isToggled);
                      print('🔧 Toggled state: ${cartProvider.isToggled}');

                      if (cartProvider.isToggled) {
                        print('➡️ Navigating to ProductSearchScreen');
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductSearchScreen(
                              tableNumber: widget.tableNumber,
                              seat: widget.seat,
                              areaName: widget.areaName,
                              seathiveOrderId: seathiveOrderId,
                            ),
                          ),
                        );

                        if (result != null && result == 'toggle_off') {
                          cartProvider.setToggled(false);
                          print(
                            '🔙 Returned from ProductSearchScreen, toggle set to off',
                          );
                        }
                      } else {
                        print('⬅️ Toggle OFF, staying on current screen');
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }
                    } catch (e) {
                      print('❌ Error in toggle button action: $e');
                      CustomSnackBar.show(
                        context,
                        'Error in toggle action: $e',
                        type: SnackType.error,
                      );
                    }
                  },
                  borderColor: Colors.transparent,
                  selectedBorderColor: Colors.transparent,
                  fillColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  children: [
                    Icon(
                      cartProvider.isToggled
                          ? Icons.toggle_on
                          : Icons.toggle_off,
                      color: cartProvider.isToggled
                          ? Colors.green
                          : Colors.grey,
                      size: 36,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Subcategory Filter Bar
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Row(
                children: [
                  // Remove Expanded and directly use IdleKeyboardHide wrapped with SizedBox (optional)
                  Expanded(
                    child: SizedBox(
                      height: 40, // Adjust height as needed to reduce
                      child: IdleKeyboardHide(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search Products',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              try {
                                Provider.of<SearchProviderDine>(
                                  context,
                                  listen: false,
                                ).clearSearchQuery();
                                _searchController.clear();
                                FocusScope.of(context).unfocus();
                                print('🧹 Cleared search query');
                              } catch (e) {
                                print('❌ Error clearing search: $e');
                              }
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(
                              color: Colors.black12,
                              width: 2.0,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                        ),
                        
                        idleDuration: const Duration(seconds: 2),
                      ),
                    ),
                  ),

                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Padding(
                          //   padding: const EdgeInsets.only(right: 8.0),
                          //   child: ChoiceChip(
                          //     label: const Text('All'),
                          //     backgroundColor: Colors.white,
                          //     selectedColor: Colors.blue,
                          //     side: BorderSide.none, // ✅ Remove border
                          //     labelStyle: TextStyle(
                          //       color: categoryProvider.selectedCategory == null
                          //           ? Colors.white
                          //           : Colors.black,
                          //     ),
                          //     selected:
                          //         categoryProvider.selectedCategory == null,
                          //     onSelected: (selected) {
                          //       if (selected) {
                          //         categoryProvider.selectCategory(null);
                          //       }
                          //     },
                          //   ),
                          // ),
                          ChoiceChip(
                            label: const Text('Favorites'),
                             labelStyle: TextStyle(
                                  color:
                                      categoryProvider.selectedCategory == "Favorites"
                                      ? Colors.white
                                      : Colors.black,
                                ),
                            backgroundColor: Colors.white,
                            selectedColor: Colors.blue,
                            side: BorderSide.none, // ✅
                            showCheckmark: false,

                            selected:
                                categoryProvider.selectedCategory ==
                                'Favorites',
                            onSelected: (selected) {
                              if (selected) {
                                categoryProvider.selectCategory('Favorites');
                              }
                            },
                          ),
                          ...subcategories.map(
                            (sub) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(sub),
                                backgroundColor: Colors.white,
                                selectedColor: Colors.blue,
                                side: BorderSide.none, // ✅ Remove border
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color:
                                      categoryProvider.selectedCategory == sub
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                selected:
                                    categoryProvider.selectedCategory == sub,
                                onSelected: (selected) {
                                  if (selected) {
                                    categoryProvider.selectCategory(sub);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // SizedBox(
            //   height: 20,
            // )   ,
            Expanded(
              child: Consumer<SearchProviderDine>(
                builder: (context, searchProvider, child) {
                  try {
                    var products = productProvider.products;
                    products = _filterBySubcategory(
                      products,
                      categoryProvider.selectedCategory,
                    );
                    final searchedProducts = _filteredProducts(
                      products,
                      searchProvider.searchQuery,
                    );
                    print(
                      '📋 Found ${searchedProducts.length} products after filtering',
                    );

                    if (searchedProducts.isEmpty) {
                      return const Center(
                        child: Text(
                          'No products found.\nTry a different search term.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    return GridView.builder(
                      controller: _scrollController,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 600
                            ? 5
                            : 2,
                        childAspectRatio:
                            MediaQuery.of(context).size.width > 600
                            ? 4 / 3
                            : 3 / 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      padding: const EdgeInsets.all(10),
                      itemCount: searchedProducts.length,
                      itemBuilder: (context, index) {
                        try {
                          final product = searchedProducts[index];
                          final isInCart = cartProvider.cart.containsKey(
                            product.varianceName,
                          );
                          final int quantity = isInCart
                              ? (cartProvider.cart[product
                                            .varianceName]?['qty'] ??
                                        0)
                                    as int
                              : 0;

                          final quickAccessProvider =
                              Provider.of<QuickAccessProvider>(context);

                          return Consumer<CartProviderKOT>(
                            builder: (context, cartProvider, child) {
                              final isQuickAccess = quickAccessProvider
                                  .quickAccessProducts
                                  .contains(product.varianceName);
                              return GestureDetector(
                                onTap: () {
                                  print(
                                    "Tapped product: ${product.varianceName}",
                                  );
                                  _addToCartWithEvent(product.varianceName);
                                },
                                onLongPress: () {
                                  quickAccessProvider.addToQuickAccess(
                                    product.varianceName,
                                    context,
                                  );
                                },
                                child: Card(
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  color: Colors.white,
                                  child: Container(
                                    clipBehavior: Clip.none,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 5,
                                            top: 5.0,
                                            right: 38.0,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Align(
                                                alignment: Alignment.topLeft,
                                                child: Text(
                                                  '₹${product.price.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Align(
                                                alignment: Alignment.center,
                                                child: Text(
                                                  product.varianceName,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    letterSpacing: 0.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isQuickAccess)
                                          const Positioned(
                                            bottom: 5,
                                            left: 5,
                                            child: Icon(
                                              Icons.favorite,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                          ),
                                        if (quantity > 0)
                                          Stack(
                                            clipBehavior: Clip.none,
                                            alignment: Alignment.center,
                                            children: [
                                              Positioned(
                                                top: -15,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 30.0,
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                    _showEditDialog(
                                                      product,
                                                      cartProvider,
                                                    );
                                                  },
                                                ),
                                              ),
                                              Positioned(
                                                top: 40,
                                                right: 0,
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.remove_circle_outline,
                                                    color: Colors.red[200],
                                                  ),
                                                  onPressed: () {
                                                    _removeFromCartWithEvent(
                                                      product.varianceName,
                                                    );
                                                  },
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
                        } catch (e) {
                          print(
                            '❌ Error building product card at index $index: $e',
                          );
                          return const SizedBox();
                        }
                      },
                    );
                  } catch (e) {
                    print('❌ Error in Consumer<SearchProvider>: $e');
                    return const Center(child: Text('Error loading products.'));
                  }
                },
              ),
            ),
            // if (cartProvider.cart.isNotEmpty)
            //   Container(
            //     margin: const EdgeInsets.symmetric(
            //       horizontal: 15,
            //       vertical: 10,
            //     ),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //       children: [
            //         Text(
            //           'Total Items: ${_calculateTotalItems(cartProvider.cart)}',
            //           style: const TextStyle(
            //             fontWeight: FontWeight.bold,
            //             color: Colors.black,
            //             fontSize: 16,
            //           ),
            //         ),
            //         TextButton(
            //           onPressed: () {
            //             try {
            //               print(
            //                 '➡️ Navigating to cart view with Table : ${widget.tableNumber}, Seat : ${widget.seat}, Area : ${widget.areaName}',
            //               );
            //               Navigator.push(
            //                 context,
            //                 MaterialPageRoute(
            //                   builder: (context) => productCardViewList(
            // tableNumber: widget.tableNumber,
            // seat: widget.seat,
            // areaName: widget.areaName,
            // seathiveOrderId: widget.seathiveOrderId,
            //                   ),
            //                 ),
            //               );
            //             } catch (e) {
            //               print('❌ Error navigating to cart view: $e');
            //               CustomSnackBar.show(
            //                 context,
            //                 'Error navigating to cart: $e',
            //                 type: SnackType.error,
            //               );
            //             }
            //           },
            //           child: Text(
            //             'View Cart >>',
            //             style: TextStyle(
            //               fontSize: 16,
            //               color: Colors.green[900],
            //               fontWeight: FontWeight.bold,
            //             ),
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
          ],
        ),
       // bottomNavigationBar: const GlobalBottomNavReturn(),
      );
    } catch (e) {
      print('❌ Fatal error in build method: $e');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error building UI: $e',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Helper method to calculate total items in cart
  int _calculateTotalItems(Map<String, dynamic> cart) {
    int total = 0;
    cart.forEach((key, value) {
      total += (value['qty'] ?? 0) as int;
    });
    return total;
  }

  void _showEditDialog(Product product, CartProviderKOT cartProvider) {
    try {
      print("Our product is ${product.varianceName}");
      final productId = product.varianceName;
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      final hasAddOns = productProvider.hasAddOns(product.varianceName);
      final hasVariants = productProvider.hasVariants(product.varianceName);

      print(
        '✏️ Editing product: $productId (AddOns: $hasAddOns, Variants: $hasVariants)',
      );

      // Validate cart data
      if (!cartProvider.cart.containsKey(productId) ||
          cartProvider.cart[productId]?['qty'] == null) {
        print('❌ Invalid cart data for $productId');
        CustomSnackBar.show(
          context,
          'Error: Invalid cart data for $productId',
          type: SnackType.error,
        );
        return;
      }

      final quantity = cartProvider.cart[productId]?['qty'] ?? 0;

      // Sync cart data with quantity
      cartProvider.syncConfigWithQuantity(productId, quantity);

      // Extract all data from cart
      List<bool> toggleRemarks = List.generate(quantity, (i) {
        final cartToggleRemarks =
            cartProvider.cart[productId]?['toggleRemarks'] as List?;
        return (cartToggleRemarks != null && i < cartToggleRemarks.length)
            ? (cartToggleRemarks[i] as bool?) ?? false
            : false;
      });

      List<String> remarks = List.generate(quantity, (i) {
        final cartRemarks = cartProvider.cart[productId]?['remarks'] as List?;
        return (cartRemarks != null && i < cartRemarks.length)
            ? (cartRemarks[i] as String?) ?? ""
            : "";
      });

      List<List<String>> addons = List.generate(quantity, (i) {
        final cartAddons = cartProvider.cart[productId]?['addons'] as List?;
        return (cartAddons != null && i < cartAddons.length)
            ? List<String>.from(cartAddons[i] ?? [])
            : <String>[];
      });

      List<List<int>> addonQuantities = List.generate(quantity, (i) {
        final cartAddonQuantities =
            cartProvider.cart[productId]?['addonQuantities'] as List?;
        return (cartAddonQuantities != null && i < cartAddonQuantities.length)
            ? List<int>.from(cartAddonQuantities[i] ?? [])
            : <int>[];
      });

      List<String> variants = List.generate(quantity, (i) {
        final cartVariants = cartProvider.cart[productId]?['variants'] as List?;
        return (cartVariants != null && i < cartVariants.length)
            ? (cartVariants[i] as String?) ?? "Default"
            : "Default";
      });

      List<String> type = List.generate(quantity, (i) {
        final cartType = cartProvider.cart[productId]?['type'] as List?;
        return (cartType != null && i < cartType.length)
            ? (cartType[i] as String?) ?? ""
            : "";
      });

      List<int> configQty = List.generate(quantity, (i) {
        final cartConfigQty =
            cartProvider.cart[productId]?['configQty'] as List?;
        return (cartConfigQty != null && i < cartConfigQty.length)
            ? (cartConfigQty[i] as int?) ?? 1
            : 1;
      });

      // Find the first index where toggleRemarks is true to pre-fill the remark controller
      int remarkIndex = toggleRemarks.indexWhere((r) => r);
      String initialRemarkText = remarkIndex != -1 ? remarks[remarkIndex] : '';

      final dialogState = CartItemDialogState(
        type: type,
        addons: addons,
        addonQuantities: addonQuantities,
        variants: variants,
        toggleRemarks: toggleRemarks,
        remarks: remarks,
        configQty: configQty,
        remarkController: TextEditingController(text: initialRemarkText),
        focusNode: FocusNode(),
      );

      showDialog(
        context: context,
        builder: (context) => ChangeNotifierProvider.value(
          value: dialogState,
          child: AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.varianceName,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Consumer<CartItemDialogState>(
                    builder: (context, dialogState, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(quantity, (i) {
                            if (i >= dialogState.addons.length ||
                                i >= dialogState.addonQuantities.length ||
                                i >= dialogState.variants.length ||
                                i >= dialogState.type.length ||
                                i >= dialogState.toggleRemarks.length ||
                                i >= dialogState.remarks.length ||
                                i >= dialogState.configQty.length) {
                              print('❌ Index $i out of bounds in dialogState');
                              return const SizedBox();
                            }

                            String itemName =
                                '  ${i + 1} .   ${product.varianceName} ';
                            String? selectedAddOn;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          itemName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (hasAddOns)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4.0,
                                          ),
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: DropdownButtonFormField<String>(
                                                  decoration: const InputDecoration(
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 10,
                                                        ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.all(
                                                            Radius.circular(
                                                              8.0,
                                                            ),
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: Colors.grey,
                                                        width: 1.0,
                                                      ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                Radius.circular(
                                                                  8.0,
                                                                ),
                                                              ),
                                                          borderSide:
                                                              BorderSide(
                                                                color:
                                                                    Colors.grey,
                                                                width: 1.0,
                                                              ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                Radius.circular(
                                                                  8.0,
                                                                ),
                                                              ),
                                                          borderSide:
                                                              BorderSide(
                                                                color:
                                                                    Colors.blue,
                                                                width: 1.5,
                                                              ),
                                                        ),
                                                  ),
                                                  isExpanded: true,
                                                  hint: Text(
                                                    dialogState
                                                            .addons[i]
                                                            .isEmpty
                                                        ? 'Select Add-ons'
                                                        : "${dialogState.addons[i].length} selected",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                  items: [
                                                    const DropdownMenuItem(
                                                      value: null,
                                                      child: Text(
                                                        "Select Add-ons",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    ...productProvider.addons
                                                        .where((addOn) {
                                                          var items =
                                                              addOn['addOnItems'];
                                                          if (items is List) {
                                                            return items
                                                                .map(
                                                                  (e) => e
                                                                      .toString()
                                                                      .trim()
                                                                      .toLowerCase(),
                                                                )
                                                                .contains(
                                                                  product
                                                                      .varianceName
                                                                      .trim()
                                                                      .toLowerCase(),
                                                                );
                                                          }
                                                          return items
                                                                  .toString()
                                                                  .trim()
                                                                  .toLowerCase() ==
                                                              product
                                                                  .varianceName
                                                                  .trim()
                                                                  .toLowerCase();
                                                        })
                                                        .map(
                                                          (
                                                            addOn,
                                                          ) => DropdownMenuItem(
                                                            value:
                                                                addOn['addOn']
                                                                    .toString(),
                                                            child: Text(
                                                              "${addOn['addOn']} (₹${addOn['value']})",
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                  ],
                                                  value: selectedAddOn,
                                                  onChanged: (value) {
                                                    if (value != null &&
                                                        !dialogState.addons[i]
                                                            .contains(value)) {
                                                      dialogState.updateAddOn(
                                                        i,
                                                        value,
                                                        true,
                                                        1,
                                                      );
                                                      cartProvider.updateCart(
                                                        productId,
                                                        dialogState.addons,
                                                        dialogState
                                                            .addonQuantities,
                                                        dialogState.variants,
                                                        dialogState.type,
                                                        dialogState.remarks,
                                                        dialogState
                                                            .toggleRemarks,
                                                      );
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Checkbox(
                                                    value:
                                                        dialogState.type[i] ==
                                                        "Parcel",
                                                    onChanged: (value) {
                                                      dialogState.updateType(
                                                        i,
                                                        value!,
                                                      );
                                                      cartProvider.updateCart(
                                                        productId,
                                                        dialogState.addons,
                                                        dialogState
                                                            .addonQuantities,
                                                        dialogState.variants,
                                                        dialogState.type,
                                                        dialogState.remarks,
                                                        dialogState
                                                            .toggleRemarks,
                                                      );
                                                    },
                                                    activeColor: Colors.blue,
                                                    checkColor: Colors.white,
                                                    side: const BorderSide(
                                                      color: Colors.blue,
                                                      width: 1.5,
                                                    ),
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  const Text(
                                                    "Parcel",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 8),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Switch(
                                                    value: dialogState
                                                        .toggleRemarks[i],
                                                    onChanged: (value) {
                                                      dialogState
                                                          .updateToggleRemark(
                                                            i,
                                                            value,
                                                          );
                                                      cartProvider.updateCart(
                                                        productId,
                                                        dialogState.addons,
                                                        dialogState
                                                            .addonQuantities,
                                                        dialogState.variants,
                                                        dialogState.type,
                                                        dialogState.remarks,
                                                        dialogState
                                                            .toggleRemarks,
                                                      );
                                                    },
                                                    activeColor: Colors.blue,
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  const Text(
                                                    "Remark",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        ...dialogState.addons[i].asMap().entries.map((
                                          entry,
                                        ) {
                                          final addOnIndex = entry.key;
                                          final addOnName = entry.value;
                                          final addOnValue = productProvider
                                              .addons
                                              .firstWhere(
                                                (addOn) =>
                                                    addOn['addOn'].toString() ==
                                                    addOnName,
                                              )['value'];

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    "$addOnName (₹$addOnValue)",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.remove,
                                                        size: 18,
                                                        color: Colors.redAccent,
                                                      ),
                                                      onPressed: () {
                                                        if (dialogState
                                                                .addonQuantities[i][addOnIndex] >
                                                            1) {
                                                          dialogState
                                                              .updateAddOnQuantity(
                                                                i,
                                                                addOnIndex,
                                                                dialogState
                                                                        .addonQuantities[i][addOnIndex] -
                                                                    1,
                                                              );
                                                        } else {
                                                          dialogState
                                                              .updateAddOn(
                                                                i,
                                                                addOnName,
                                                                false,
                                                                0,
                                                              );
                                                        }
                                                        cartProvider.updateCart(
                                                          productId,
                                                          dialogState.addons,
                                                          dialogState
                                                              .addonQuantities,
                                                          dialogState.variants,
                                                          dialogState.type,
                                                          dialogState.remarks,
                                                          dialogState
                                                              .toggleRemarks,
                                                        );
                                                      },
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                    ),
                                                    SizedBox(
                                                      width: 30,
                                                      child: Text(
                                                        "${dialogState.addonQuantities[i][addOnIndex]}",
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.add,
                                                        size: 18,
                                                        color: Colors.blue,
                                                      ),
                                                      onPressed: () {
                                                        dialogState
                                                            .updateAddOnQuantity(
                                                              i,
                                                              addOnIndex,
                                                              dialogState
                                                                      .addonQuantities[i][addOnIndex] +
                                                                  1,
                                                            );
                                                        cartProvider.updateCart(
                                                          productId,
                                                          dialogState.addons,
                                                          dialogState
                                                              .addonQuantities,
                                                          dialogState.variants,
                                                          dialogState.type,
                                                          dialogState.remarks,
                                                          dialogState
                                                              .toggleRemarks,
                                                        );
                                                      },
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  if (hasVariants)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          child: DropdownButtonFormField(
                                            decoration: const InputDecoration(
                                              hintText: 'Select variant',
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 10,
                                                  ),
                                            ),
                                            items: [
                                              const DropdownMenuItem(
                                                value: "Default",
                                                child: Text(
                                                  "Default",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              ...productProvider.variants
                                                  .map(
                                                    (v) => DropdownMenuItem(
                                                      value: v['variant'],
                                                      child: Text(
                                                        v['variant'],
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ],
                                            onChanged: (value) {
                                              dialogState.updateVariant(
                                                i,
                                                value.toString(),
                                              );
                                              cartProvider.updateCart(
                                                productId,
                                                dialogState.addons,
                                                dialogState.addonQuantities,
                                                dialogState.variants,
                                                dialogState.type,
                                                dialogState.remarks,
                                                dialogState.toggleRemarks,
                                              );
                                            },
                                            value: dialogState.variants[i],
                                            isExpanded: true,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Checkbox(
                                              value:
                                                  dialogState.type[i] ==
                                                  "Parcel",
                                              onChanged: (value) {
                                                dialogState.updateType(
                                                  i,
                                                  value!,
                                                );
                                                cartProvider.updateCart(
                                                  productId,
                                                  dialogState.addons,
                                                  dialogState.addonQuantities,
                                                  dialogState.variants,
                                                  dialogState.type,
                                                  dialogState.remarks,
                                                  dialogState.toggleRemarks,
                                                );
                                              },
                                              activeColor: Colors.blue,
                                              checkColor: Colors.white,
                                              side: const BorderSide(
                                                color: Colors.blue,
                                                width: 1.5,
                                              ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            const Text(
                                              "Parcel",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Switch(
                                              value:
                                                  dialogState.toggleRemarks[i],
                                              onChanged: (value) {
                                                dialogState.updateToggleRemark(
                                                  i,
                                                  value,
                                                );
                                                cartProvider.updateCart(
                                                  productId,
                                                  dialogState.addons,
                                                  dialogState.addonQuantities,
                                                  dialogState.variants,
                                                  dialogState.type,
                                                  dialogState.remarks,
                                                  dialogState.toggleRemarks,
                                                );
                                              },
                                              activeColor: Colors.blue,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            const Text(
                                              "Remark",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  if (!hasAddOns && !hasVariants)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Checkbox(
                                                value:
                                                    dialogState.type[i] ==
                                                    "Parcel",
                                                onChanged: (value) {
                                                  dialogState.updateType(
                                                    i,
                                                    value!,
                                                  );
                                                  cartProvider.updateCart(
                                                    productId,
                                                    dialogState.addons,
                                                    dialogState.addonQuantities,
                                                    dialogState.variants,
                                                    dialogState.type,
                                                    dialogState.remarks,
                                                    dialogState.toggleRemarks,
                                                  );
                                                },
                                                activeColor: Colors.blue,
                                                checkColor: Colors.white,
                                                side: const BorderSide(
                                                  color: Colors.blue,
                                                  width: 1.5,
                                                ),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              const Text(
                                                "Parcel",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Switch(
                                                value: dialogState
                                                    .toggleRemarks[i],
                                                onChanged: (value) {
                                                  dialogState
                                                      .updateToggleRemark(
                                                        i,
                                                        value,
                                                      );
                                                  cartProvider.updateCart(
                                                    productId,
                                                    dialogState.addons,
                                                    dialogState.addonQuantities,
                                                    dialogState.variants,
                                                    dialogState.type,
                                                    dialogState.remarks,
                                                    dialogState.toggleRemarks,
                                                  );
                                                },
                                                activeColor: Colors.blue,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              const Text(
                                                "Remark",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
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
                          if (dialogState.toggleRemarks.any((r) => r))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: TextField(
                                controller: dialogState.remarkController,
                                focusNode: dialogState.focusNode,
                                decoration: const InputDecoration(
                                  hintText: 'Enter remark',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                                onChanged: (value) {
                                  final remarkIndex = dialogState.toggleRemarks
                                      .indexWhere((r) => r);
                                  if (remarkIndex != -1) {
                                    dialogState.updateRemark(
                                      remarkIndex,
                                      value,
                                    );
                                    cartProvider.updateCart(
                                      productId,
                                      dialogState.addons,
                                      dialogState.addonQuantities,
                                      dialogState.variants,
                                      dialogState.type,
                                      dialogState.remarks,
                                      dialogState.toggleRemarks,
                                    );
                                  }
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel'),
                onPressed: () {
                  dialogState.dispose();
                  Navigator.of(context).pop();
                  print('🚫 Dialog cancelled');
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
                onPressed: () {
                  try {
                    cartProvider.updateCart(
                      productId,
                      dialogState.addons,
                      dialogState.addonQuantities,
                      dialogState.variants,
                      dialogState.type,
                      dialogState.remarks,
                      dialogState.toggleRemarks,
                    );
                    print('✅ Updated cart with new config for $productId');

                    // Send product update event
                    _sendProductEvent('update', productId, {
                      'varianceName': productId,
                      'name': product.name,
                      'price': product.price.toDouble(),
                      'quantity': quantity,
                      'addons': dialogState.addons,
                      'variants': dialogState.variants,
                      'type': dialogState.type,
                    });

                    dialogState.dispose();
                    Navigator.of(context).pop();
                  } catch (e) {
                    print('❌ Error updating cart: $e');
                    CustomSnackBar.show(
                      context,
                      'Error updating cart: $e',
                      type: SnackType.error,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Error opening edit dialog: $e');
      CustomSnackBar.show(
        context,
        'Error opening edit dialog: $e',
        type: SnackType.error,
      );
    }
  }

  void showHintDialog(BuildContext context, String itemName) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
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
                      Navigator.of(context).pop();
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

class QuickAccessProvider extends ChangeNotifier {
  List<String> _quickAccessProducts = [];
  Box? _quickAccessBox;

  List<String> get quickAccessProducts => _quickAccessProducts;

  QuickAccessProvider() {
    _initBox();
  }

  Future<void> _initBox() async {
    try {
      if (!Hive.isBoxOpen('quickAccessBox')) {
        _quickAccessBox = await Hive.openBox('quickAccessBox');
      } else {
        _quickAccessBox = Hive.box('quickAccessBox');
      }

      final storedProducts =
          _quickAccessBox
              ?.get('products', defaultValue: <String>[])
              ?.cast<String>() ??
          [];
      _quickAccessProducts = List<String>.from(storedProducts);

      debugPrint(
        '✅ QuickAccessProvider initialized with ${_quickAccessProducts.length} items',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to initialize QuickAccessProvider: $e');
    }
  }

  Future<void> addToQuickAccess(
    String varianceName,
    BuildContext context,
  ) async {
    if (!_quickAccessProducts.contains(varianceName)) {
      _quickAccessProducts.add(varianceName);
      await _saveToBox();

      CustomSnackBar.show(
        context,
        'Added $varianceName to quick access',
        type: SnackType.success,
      );

      debugPrint('⭐ Added $varianceName to quick access');
      notifyListeners();
    }
  }

  Future<void> removeFromQuickAccess(
    String varianceName,
    BuildContext context,
  ) async {
    if (_quickAccessProducts.contains(varianceName)) {
      _quickAccessProducts.remove(varianceName);
      await _saveToBox();

      CustomSnackBar.show(
        context,
        'Removed $varianceName from quick access',
        type: SnackType.warning,
      );

      debugPrint('🗑️ Removed $varianceName from quick access');
      notifyListeners();
    } else {
      CustomSnackBar.show(
        context,
        '$varianceName not found in quick access',
        type: SnackType.error,
      );
    }
  }

  Future<void> _saveToBox() async {
    try {
      await _quickAccessBox?.put('products', _quickAccessProducts);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Failed to save quick access data: $e');
    }
  }
}

class CategoryProvider extends ChangeNotifier {
  String? _selectedCategory =  'Favorites';

  String? get selectedCategory => _selectedCategory;

  void selectCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Add this method to check if favorites are selected
  bool get isFavoritesSelected => _selectedCategory == 'Favorites';
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Screens/salesorder_Customerdetails.dart';
import 'package:yenpos/Sale_order/Widgets/disposable_builder.dart';
import 'package:yenpos/Sale_order/Widgets/numeric_Calculator.dart';
import 'package:yenpos/Sale_order/Widgets/search_drop_filed.dart';
import 'package:yenpos/Sale_order/Widgets/selected_items_dialogue.dart';
import 'package:yenpos/Sale_order/Widgets/storetype_selection_dialogue.dart';
import 'package:yenpos/Sale_order/Widgets/top_message.dart';

class SalesOrderScreen extends StatefulWidget {
  const SalesOrderScreen({super.key});

  @override
  SalesOrderScreenState createState() => SalesOrderScreenState();
}

class SalesOrderScreenState extends State<SalesOrderScreen> {
  bool isStoreTypeSelected = false;
  String selectedStoreType = 'Warehouse';
  final TextEditingController _allBoxQtyController = TextEditingController();
  final Map<String, TextEditingController> _boxQtyControllers = {};
  bool isStoreTypeDialogShowing = false;
  bool _isDialogShownToday = false;
  final Map<String, TextEditingController> _discountControllers = {};
  final TextEditingController _bulkDiscountController = TextEditingController();
  bool showCheckBoxes = false; // To control if checkboxes should be shown
  List<bool> itemSelections = []; // List to track selection state of each item
  final Map<String, FocusNode> _discountFocusNodes = {};
  final FocusNode customChargeFocus = FocusNode(); // 👈 new
  final FocusNode _allBoxQtyFocus = FocusNode(); // 👈 new

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customerProvider = Provider.of<CustomerScreenProvider>(
        context,
        listen: false,
      );
      customerProvider.checkAndShowStoreTypeDialog(context);
    });

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.customChargeController.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        cartProvider.getTotalAmount(); // safe
      });
    });
    cartProvider.clearCart();
    _allBoxQtyController.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyBulkBoxQtyUpdate(_allBoxQtyController.text);
      });
    });

    _bulkDiscountController.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyBulkDiscount(_bulkDiscountController.text);
      });
    });
  }

  @override
  void dispose() {
    _allBoxQtyController.dispose();
    for (final controller in _boxQtyControllers.values) {
      controller.dispose();
    }
    for (final controller in _discountControllers.values) {
      controller.dispose();
    }
    _bulkDiscountController.dispose();
    super.dispose();
  }

  Future<void> _saveStoreType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

    await prefs.setString('storeType', type);
    await prefs.setInt('lastShownTimestamp', currentTimestamp);

    setState(() {
      selectedStoreType = type;
      isStoreTypeSelected = true;
    });
  }

  Future<void> _showStoreTypeDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          StoreTypeSelectionDialog(onStoreTypeSelected: _saveStoreType),
    );
  }

  void _initializeItemIfNeeded(String key) {
    if (!_boxQtyControllers.containsKey(key)) {
      _boxQtyControllers[key] = TextEditingController();
    }
    if (!_discountControllers.containsKey(key)) {
      _discountControllers[key] = TextEditingController();
    }
  }

  void _removeItemState(String key) {
    final selectionProvider = Provider.of<CartSelectionProvider>(
      context,
      listen: false,
    );
    selectionProvider.toggleItemSelection(
      key,
      false,
    ); // Explicitly unselect the item
    _boxQtyControllers.remove(key)?.dispose();
    _discountControllers.remove(key)?.dispose();
  }

  Future<void> _showClearCartConfirmationDialog(
    CartProvider cartProvider,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(minHeight: 180, maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Clear Cart',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              // Content
              const Text(
                'Are you sure you want to clear the cart? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 25),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel Button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Clear Button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        clearCartAndResetState(cartProvider);
                        _bulkDiscountController.clear();
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void applySingleItemDiscount(String key, String value) {
    if (value.isEmpty) {
      setState(() {
        _discountControllers[key]?.text = '';
        final itemIndex = globals.cartItems.indexWhere(
          (item) => item.varianceName == key,
        );
        if (itemIndex != -1) {
          globals.cartItems[itemIndex].itemWiseDiscount = 0.0;
          globals.cartItems[itemIndex].itemWiseDiscountAmount = 0.0;
          globals.cartItems[itemIndex].finalPrice = null;
        }
        Provider.of<CartProvider>(context, listen: false).notifyListeners();
      });
      return;
    }

    double? discount = double.tryParse(value);
    if (discount != null && discount >= 0) {
      setState(() {
        _discountControllers[key]?.text = value;
        final itemIndex = globals.cartItems.indexWhere(
          (item) => item.varianceName == key,
        );

        if (itemIndex != -1) {
          final item = globals.cartItems[itemIndex];
          item.itemWiseDiscount = discount;

          // ✅ FIX: Compute originalPrice based on UOM
          num originalPrice = (item.uom == 'Kg' || item.uom == 'Kgs')
              ? (item.quantity * item.pricePerKg * item.weight)
              : (item.quantity * item.pricePerKg);

          double discountAmount = originalPrice * (discount / 100);
          item.itemWiseDiscountAmount = discountAmount;
          item.finalPrice = originalPrice - discountAmount;
        }
      });
    }
  }

  void _applyBulkDiscount(String value) {
    final selectionProvider = Provider.of<CartSelectionProvider>(
      context,
      listen: false,
    );

    if (value.isEmpty) {
      setState(() {
        selectionProvider.itemSelectionState.forEach((key, isSelected) {
          if (isSelected) {
            // Avoid triggering onChanged by using value directly
            _discountControllers[key]?.value = _discountControllers[key]!.value
                .copyWith(
                  text: '',
                  selection: TextSelection.collapsed(offset: 0),
                );

            final itemIndex = globals.cartItems.indexWhere(
              (item) => item.varianceName == key,
            );
            if (itemIndex != -1) {
              var item = globals.cartItems[itemIndex];
              item.itemWiseDiscount = 0.0;
              item.itemWiseDiscountAmount = 0.0;
              item.finalPrice = null;
            }
          }
        });
      });
      return;
    }

    double? discountPercent = double.tryParse(value);
    if (discountPercent != null && discountPercent >= 0) {
      setState(() {
        selectionProvider.itemSelectionState.forEach((key, isSelected) {
          if (isSelected) {
            final itemIndex = globals.cartItems.indexWhere(
              (item) => item.varianceName == key,
            );
            if (itemIndex != -1) {
              var item = globals.cartItems[itemIndex];

              // Calculate originalAmount based on UOM
              double originalAmount = (item.uom == 'Kgs' || item.uom == 'Kg')
                  ? (item.weight?.toDouble() ?? 0.0) *
                        item.quantity.toDouble() *
                        item.pricePerKg.toDouble()
                  : item.quantity.toDouble() * item.pricePerKg.toDouble();

              // Calculate discount
              double discountAmount = (originalAmount * discountPercent) / 100;
              double finalPrice = originalAmount - discountAmount;

              // Assign values
              item.itemWiseDiscount = discountPercent;
              item.itemWiseDiscountAmount = discountAmount;
              item.finalPrice = finalPrice;

              // Update the controller without triggering onChanged
              _discountControllers[key]?.value = _discountControllers[key]!
                  .value
                  .copyWith(
                    text: discountPercent.toStringAsFixed(2),
                    selection: TextSelection.collapsed(
                      offset: discountPercent.toStringAsFixed(2).length,
                    ),
                  );
            }
          }
        });
      });
    }
  }

  void clearCartAndResetState(CartProvider cartProvider) {
    cartProvider.clearCart();
    _allBoxQtyController.clear();
    _bulkDiscountController.clear();
    Provider.of<CartSelectionProvider>(
      context,
      listen: false,
    ).clearSelections();
    for (final controller in _boxQtyControllers.values) {
      controller.clear();
    }
    for (final controller in _discountControllers.values) {
      controller.clear();
    }
  }

  void _applyBulkBoxQtyUpdate(String value) {
    int? newQty = int.tryParse(value);
    if (newQty != null && newQty > 0) {
      setState(() {
        final selectionProvider = Provider.of<CartSelectionProvider>(
          context,
          listen: false,
        );
        final cartProvider = Provider.of<CartProvider>(context, listen: false);

        selectionProvider.itemSelectionState.forEach((key, isSelected) {
          if (isSelected) {
            final itemIndex = globals.cartItems.indexWhere(
              (item) => item.varianceName == key,
            );
            if (itemIndex != -1) {
              globals.cartItems[itemIndex].quantity = newQty;
              globals.cartItems[itemIndex].boxQuantity = newQty;
            }
          }
        });

        // ✅ After updating qty, reapply bulk discount if present
        if (_bulkDiscountController.text.isNotEmpty) {
          _applyBulkDiscount(_bulkDiscountController.text);
        }

        // ignore: invalid_use_of_protected_member
        cartProvider.notifyListeners();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // final cartProvider = Provider.of<CartProvider>(context);
    final selectionProvider = Provider.of<CartSelectionProvider>(context);
    final apiService = Provider.of<ApiServiceSalesOrderProvider>(
      context,
      listen: false,
    );
    if (!isStoreTypeSelected && _isDialogShownToday == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isStoreTypeDialogShowing) {
          isStoreTypeDialogShowing = true;
          _showStoreTypeDialog().then((_) {
            isStoreTypeDialogShowing = false;
          });
        }
      });
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushNamed('/all-orders');
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(context, apiService, selectionProvider),
        body: Row(
          children: [
            Expanded(
              flex: 2,
              child: Consumer<CartProvider>(
                builder: (context, cartProvider, child) {
                  return _buildLeftSideContent(
                    context,
                    cartProvider,
                    selectionProvider,
                  );
                },
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1, color: Colors.grey),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CustomerDetails(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ApiServiceSalesOrderProvider apiService,
    CartSelectionProvider selectionProvider,
  ) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text('Create Orders', style: TextStyle(color: Colors.black)),
        ],
      ),
      centerTitle: false,
      flexibleSpace: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildNavButton(
                    label: 'Current Orders',
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/current-orders'),
                  ),
                  const SizedBox(width: 10),
                  _buildNavButton(
                    label: 'All Orders',
                    onPressed: () async {
                      // apiService.clearAllOrders();
                      // await apiService.fetchAllOrders();
                      Navigator.of(context).pushNamed('/all-orders');
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildCreateOrderButton(selectionProvider),
                ],
              ),
            ),
            _buildStoreTypeToggle(),
          ],
        ),
      ),
      toolbarHeight: kToolbarHeight,
    );
  }

  Widget _buildNavButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      child: Text(label),
    );
  }

  Widget _buildCreateOrderButton(CartSelectionProvider selectionProvider) {
    return ElevatedButton(
      onPressed: () {
        // selectionProvider.toggleCheckBoxVisibility();
      },
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        elevation: 2,
      ),
      child: Text('Create Order'),
    );
  }

  Widget _buildStoreTypeToggle() {
    final customerProvider = Provider.of<CustomerScreenProvider>(context);

    return ToggleButtons(
      constraints: BoxConstraints(minHeight: 40.0, minWidth: 80.0),
      borderRadius: BorderRadius.circular(8.0),
      borderWidth: 2,
      borderColor: Colors.blueGrey,
      selectedBorderColor: Colors.blue,
      fillColor: Colors.blue,
      splashColor: Colors.blue.withOpacity(0.3),
      color: Colors.black,
      selectedColor: Colors.white,
      isSelected: [
        customerProvider.selectedStoreType == 'Inhouse',
        customerProvider.selectedStoreType == 'Warehouse',
      ],
      onPressed: (index) {
        final type = index == 0 ? 'Inhouse' : 'Warehouse';
        customerProvider.saveStoreType(type);
      },
      children: [
        _buildToggleButtonLabel('Inhouse'),
        _buildToggleButtonLabel('Warehouse'),
      ],
    );
  }

  Widget _buildToggleButtonLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLeftSideContent(
    BuildContext context,
    CartProvider cartProvider,
    CartSelectionProvider selectionProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchDropdown(key: widget.key),
          const SizedBox(height: 16.0),
          _buildCartDetailsHeader(selectionProvider),
          const Divider(),
          Flexible(
            child: Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                return _buildCartItemsList(selectionProvider);
              },
            ),
            // _buildCartItemsList(cartProvider, selectionProvider),
          ),
          const SizedBox(height: 16.0),
          _buildCartFooter(cartProvider, selectionProvider),
        ],
      ),
    );
  }

  Widget _buildCartDetailsHeader(CartSelectionProvider selectionProvider) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cartItemCountNotifier = ValueNotifier<int>(globals.cartItems.length);

    void updateCartCount() {
      cartItemCountNotifier.value = globals.cartItems.length;
    }

    cartProvider.addListener(updateCartCount);

    return ValueListenableBuilder<int>(
      valueListenable: cartItemCountNotifier,
      builder: (context, cartItemCount, child) {
        final selectedCount = selectionProvider.itemSelectionState.values
            .where((isSelected) => isSelected)
            .length;

        return Row(
          children: [
            Text(
              'Cart Details $cartItemCount ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                final wasShowing = selectionProvider.showCheckBoxes;

                selectionProvider.toggleCheckBoxVisibility();

                if (wasShowing) {
                  // When turning OFF gifted mode (unselecting), reset unselected items
                  for (var item in globals.cartItems) {
                    final isSelected =
                        selectionProvider.itemSelectionState[item
                            .varianceName] ??
                        false;
                    if (!isSelected) {
                      item.quantity = 1;
                      item.boxQuantity = null; // Or 0, based on your default
                      _allBoxQtyController.clear();
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
              child: Text(
                selectionProvider.showCheckBoxes
                    ? 'UNSELECT ITEMS'
                    : 'GIFTED ITEMS',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (selectionProvider.showCheckBoxes) ...[
              SizedBox(width: 10),
              Text(
                '$selectedCount selected',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
            SizedBox(width: 10),
            IconButton(
              onPressed: globals.cartItems.isNotEmpty
                  ? () {
                      _showClearCartConfirmationDialog(cartProvider);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: globals.cartItems.isNotEmpty
                    ? Colors.red
                    : Colors.red,
              ),
              icon: Icon(
                Icons.delete,
                color: globals.cartItems.isNotEmpty
                    ? Colors.white
                    : Colors.grey,
              ),
            ),
          ],
        );
      },
      child: DisposableBuilder(
        onDispose: () {
          cartProvider.removeListener(updateCartCount);
          cartItemCountNotifier.dispose();
        },
      ),
    );
  }

  Widget _buildAllBoxQtyField(String key) {
    _allBoxQtyController.addListener(() {
      final value = _allBoxQtyController.text;
      applySingleItemDiscount(key, value);
    });
    return SizedBox(
      width: 90,
      child: TextField(
        readOnly: true,
        showCursor: true,
        controller: _allBoxQtyController,
        decoration: InputDecoration(
          labelText: 'Box Qty',

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.blue.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          labelStyle: TextStyle(color: Colors.blue.shade700),
        ),
        onTap: () {
          ActiveField.activate(
            context: context,
            ctrl: _allBoxQtyController,
            node: _allBoxQtyFocus,
            numeric: true,
            fieldType: "custom charge",
          );
        },
        keyboardType: TextInputType.number,
        onChanged: _applyBulkBoxQtyUpdate,
      ),
    );
  }

  Widget _buildCartItemsList(CartSelectionProvider selectionProvider) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Create a ValueNotifier for cart item count
    final cartItemsNotifier = ValueNotifier<int>(globals.cartItems.length);

    // Update notifier when cart changes
    void updateCartItems() {
      cartItemsNotifier.value = globals.cartItems.length;
    }

    // Add listener
    cartProvider.addListener(updateCartItems);

    return ValueListenableBuilder<int>(
      valueListenable: cartItemsNotifier,
      builder: (context, cartItemCount, child) {
        return Builder(
          builder: (context) {
            final reversedCartItems = globals.cartItems.reversed.toList();

            final selectedItems = reversedCartItems
                .where(
                  (item) =>
                      selectionProvider.itemSelectionState[item.varianceName] ??
                      false,
                )
                .toList();

            final unselectedItems = reversedCartItems
                .where(
                  (item) =>
                      !(selectionProvider.itemSelectionState[item
                              .varianceName] ??
                          false),
                )
                .toList();

            // Calculate base amount from selected items
            // Calculate base amount from selected items
            double baseAmount = selectedItems.fold(0, (sum, item) {
              double itemTotal = 0;

              if (item.finalPrice != null) {
                // If finalPrice is already given, use it directly
                itemTotal = item.finalPrice!;
              } else {
                // Check UOM type and calculate accordingly
                if (item.uom.toLowerCase() == 'kg' ||
                    item.uom.toLowerCase() == 'kgs') {
                  itemTotal = item.weight * item.quantity * item.pricePerKg;
                } else if (item.uom.toLowerCase() == 'pcs' ||
                    item.uom.toLowerCase() == 'pkt') {
                  itemTotal = item.quantity.toDouble() * item.pricePerKg;
                } else {
                  // Default fallback if UOM is something else
                  itemTotal = item.quantity.toDouble() * item.pricePerKg;
                }
              }

              return sum + itemTotal;
            });

            // Get custom charge
            final customCharge =
                double.tryParse(cartProvider.customChargeController.text) ?? 0;

            // Add to selected total
            double selectedTotalAmount = baseAmount + customCharge;

            return ListView(
              children: [
                if (selectedItems.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(10.0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.blue.shade100,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "Selected Items",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: selectionProvider.showCheckBoxes ? 2 : 3,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: selectedItems.map((item) {
                                  final key = item.varianceName;
                                  _initializeItemIfNeeded(key);
                                  final originalIndex = globals.cartItems
                                      .indexOf(item);
                                  return _buildCartItemTile(
                                    item: item,
                                    key: key,
                                    originalIndex: originalIndex,
                                    cartProvider: cartProvider,
                                    selectionProvider: selectionProvider,
                                  );
                                }).toList(),
                              ),
                            ),
                            if (selectionProvider.showCheckBoxes)
                              const SizedBox(width: 12),
                            if (selectionProvider.showCheckBoxes)
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildAllBoxQtyField("bulk_box_qty"),
                                    const SizedBox(height: 10),
                                    _buildBulkDiscountField(),
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: Text(
                                        "Total Box Amount: ₹${selectedTotalAmount.toStringAsFixed(0)}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ...unselectedItems.map((item) {
                  final key = item.varianceName;
                  _initializeItemIfNeeded(key);
                  final originalIndex = globals.cartItems.indexOf(item);
                  return _buildCartItemTile(
                    item: item,
                    key: key,
                    originalIndex: originalIndex,
                    cartProvider: cartProvider,
                    selectionProvider: selectionProvider,
                  );
                }).toList(),
              ],
            );
          },
        );
      },
      child: DisposableBuilder(
        onDispose: () {
          cartProvider.removeListener(updateCartItems);
          cartItemsNotifier.dispose();
        },
      ),
    );
  }

  Widget _buildBulkDiscountField() {
    return SizedBox(
      width: 90,
      child: TextField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Discount',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.blue.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          labelStyle: TextStyle(color: Colors.blue.shade700, fontSize: 11),
          suffixIcon: Icon(Icons.percent, size: 17),
        ),
        controller: _bulkDiscountController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d{0,2})?$')),
        ],
        onTap: () {
          ActiveField.activate(
            context: context,
            ctrl: _bulkDiscountController,
            node: FocusNode(),
            numeric: true,
            fieldType: "discount",
          );
        },
        onChanged: _applyBulkDiscount,
      ),
    );
  }

  Widget _buildCartItemTile({
    required dynamic item,
    required String key,
    required int originalIndex,
    required CartProvider cartProvider,
    required CartSelectionProvider selectionProvider,
  }) {
    return Dismissible(
      key: Key(key),
      onDismissed: (direction) {
        cartProvider.removeItemFromCart(originalIndex);
        _removeItemState(key);
      },
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildCartItemContent(
          item: item,
          key: key,
          originalIndex: originalIndex,
          cartProvider: cartProvider,
          selectionProvider: selectionProvider,
        ),
      ),
    );
  }

  Widget _buildCartItemContent({
    required dynamic item,
    required String key,
    required int originalIndex,
    required CartProvider cartProvider,
    required CartSelectionProvider selectionProvider,
  }) {
    return GestureDetector(
      onTap: () {
        if (item.uom == 'Kgs' || item.uom == 'Kg') {
          showDialog(
            context: context,
            builder: (context) => NumericCalculator(
              varianceName: item.varianceName,
              onValueSelected: (double newValue) {
                setState(() {
                  item.weight = newValue;
                });
              },
            ),
          );
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                if (selectionProvider.showCheckBoxes)
                  Checkbox(
                    value: selectionProvider.itemSelectionState[key] ?? false,
                    onChanged: (bool? value) {
                      selectionProvider.toggleItemSelection(
                        key,
                        value ?? false,
                      );
                      if (value == true) {
                        item.isBoxItem = 'yes';
                        item.itemWiseDiscount = 0.0;
                        item.itemWiseDiscountAmount = 0.0;

                        // Apply current bulk values to the newly selected item
                        if (_allBoxQtyController.text.isNotEmpty) {
                          _applyBulkBoxQtyUpdate(_allBoxQtyController.text);
                        }
                        if (_bulkDiscountController.text.isNotEmpty) {
                          _applyBulkDiscount(_bulkDiscountController.text);
                        }
                      } else {
                        item.isBoxItem = 'no';
                        item.itemWiseDiscount = 0.0;
                        item.itemWiseDiscountAmount = 0.0;
                        _discountControllers[key]?.clear();
                      }
                    },
                  ),
                const SizedBox(width: 6),
                Expanded(child: _buildItemDetails(item)),
                // if (selectionProvider.itemSelectionState[key] == false &&
                //     selectionProvider.showCheckBoxes)
                if (!selectionProvider.showCheckBoxes &&
                        (selectionProvider.itemSelectionState[key] ?? false) ||
                    (selectionProvider.showCheckBoxes &&
                        !(selectionProvider.itemSelectionState[key] ?? false)))
                  _buildDiscountField(key),
                _buildItemPriceAndControls(
                  item: item,
                  originalIndex: originalIndex,
                  cartProvider: cartProvider,
                  key: key,
                  selectionProvider: selectionProvider,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetails(dynamic item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.varianceName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getItemPriceDescription(item),
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  String _getItemPriceDescription(dynamic item) {
    String priceDescription;
    if (item.uom == 'Kgs' || item.uom == 'Kg') {
      priceDescription = item.weight >= 1
          ? '${item.weight.toStringAsFixed(2)} kg × Rs.${item.pricePerKg.toStringAsFixed(0)}/kg'
          : '${(item.weight * 1000).toStringAsFixed(0)} grams × Rs.${item.pricePerKg.toStringAsFixed(0)}/kg';
    } else {
      priceDescription =
          '${item.quantity.toStringAsFixed(0)} ${item.uom} × Rs.${item.pricePerKg.toStringAsFixed(0)}/${item.uom}';
    }

    if (item.itemWiseDiscount != null && item.itemWiseDiscount != 0) {
      priceDescription +=
          '\nDiscount: ${item.itemWiseDiscount}% (Rs.${item.itemWiseDiscountAmount?.toStringAsFixed(0)})';
    }

    return priceDescription;
  }

  Widget _buildItemPriceAndControls({
    required dynamic item,
    required int originalIndex,
    required CartProvider cartProvider,
    required String key,
    required CartSelectionProvider selectionProvider,
  }) {
    int originalPrice =
        ((item.uom == 'Kg' || item.uom == 'Kgs')
                ? (item.quantity * item.pricePerKg * item.weight)
                : (item.quantity * item.pricePerKg))
            .toInt();
    // final originalPrice = item.quantity * item.pricePerKg;
    final discountPercent = item.itemWiseDiscount ?? 0; // Handle null case
    // final discountAmount =
    //     discountPercent > 0 ? originalPrice * (discountPercent / 100) : 0;
    // final finalPrice = item.itemWiseDiscountAmount ?? originalPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!selectionProvider.showCheckBoxes) _buildDiscountField(key),
            SizedBox(width: 10),
            _buildQuantityControls(
              originalIndex: originalIndex,
              cartProvider: cartProvider,
              key: key,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Original Price
            Text(
              'Rs.${originalPrice.round()}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                decoration: discountPercent > 0
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),

            // Discount Information (only shown if discount exists)
            if (discountPercent > 0) ...[
              Text(
                'Discount:  -Rs.${item.itemWiseDiscountAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
              Text(
                'Final Price: Rs.${item.finalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDiscountField(String key) {
    // Ensure controller and focus node exist for this key
    _discountControllers.putIfAbsent(key, () {
      return TextEditingController();
    });

    _discountFocusNodes.putIfAbsent(key, () {
      return FocusNode();
    });

    final ctrl = _discountControllers[key]!;
    final node = _discountFocusNodes[key]!;

    // Listener to track live changes
    ctrl.addListener(() {
      final value = ctrl.text;
      applySingleItemDiscount(key, value);
    });

    return SizedBox(
      width: 100,
      child: TextField(
        showCursor: true,
        readOnly: true,
        controller: ctrl,
        decoration: InputDecoration(
          labelText: 'Discount%',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.blue.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          labelStyle: TextStyle(color: Colors.blue.shade700, fontSize: 11),
          suffixIcon: Icon(Icons.percent, size: 17),
        ),
        onTap: () {
          ActiveField.activate(
            context: context,
            ctrl: ctrl,
            node: node,
            numeric: true,
            discount: true,
          );
        },
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          // Allow only numbers with optional 2 decimals
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?$')),

          // Restrict max value = 100
          TextInputFormatter.withFunction((oldValue, newValue) {
            if (newValue.text.isEmpty) {
              return newValue;
            }

            final value = double.tryParse(newValue.text);
            if (value == null) {
              return oldValue;
            }

            if (value > 100) {
              return oldValue;
            }

            return newValue;
          }),
        ],
        onChanged: (value) {
          if (value.isEmpty) {
            applySingleItemDiscount(key, '');
            return;
          }

          final discount = double.tryParse(value);
          if (discount == null || discount <= 0) {
            _discountControllers[key]?.clear();
            applySingleItemDiscount(key, '');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Discount must be between 1 and 100"),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          applySingleItemDiscount(key, value);
        },
      ),
    );
  }

  Widget _buildQuantityControls({
    required int originalIndex,
    required CartProvider cartProvider,
    required String key,
  }) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final item = cartProvider.cartItems[originalIndex];

        return Row(
          children: [
            _buildQuantityButton(
              icon: Icons.remove,
              onPressed: () {
                setState(() {
                  if (item.boxQuantity == null || item.boxQuantity == 0) {
                    if (item.quantity > 0) {
                      if (item.quantity == 1) {
                        cartProvider.removeItemFromCart(originalIndex);
                      } else {
                        cartProvider.updateQuantity(
                          originalIndex,
                          item.quantity - 1,
                        );
                      }
                    }

                    // 🔹 Re-apply discount after dialog update
                    final ctrl = _discountControllers[key];
                    if (ctrl != null && ctrl.text.isNotEmpty) {
                      applySingleItemDiscount(key, ctrl.text);
                    }
                  } else {
                    TopMessage.show(
                      context,
                      message:
                          "Quantity can't be edited when box quantity is applied.",
                      backgroundColor: Colors.redAccent,
                    );
                  }
                });
              },
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  if (item.boxQuantity == null || item.boxQuantity == 0) {
                    cartProvider.showQuantityDialog(
                      context,
                      originalIndex,
                      item.quantity,
                      item.uom,
                    );

                    // 🔹 Re-apply discount after dialog update
                    final ctrl = _discountControllers[key];
                    if (ctrl != null && ctrl.text.isNotEmpty) {
                      applySingleItemDiscount(key, ctrl.text);
                    }
                  } else {
                    TopMessage.show(
                      context,
                      message:
                          "Quantity can't be edited when box quantity is applied.",
                      backgroundColor: Colors.redAccent,
                    );
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.quantity.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildQuantityButton(
              icon: Icons.add,
              onPressed: () {
                setState(() {
                  if (item.boxQuantity == null || item.boxQuantity == 0) {
                    cartProvider.updateQuantity(
                      originalIndex,
                      item.quantity + 1,
                    );

                    // 🔹 Re-apply discount after dialog update
                    final ctrl = _discountControllers[key];
                    if (ctrl != null && ctrl.text.isNotEmpty) {
                      applySingleItemDiscount(key, ctrl.text);
                    }
                  } else {
                    TopMessage.show(
                      context,
                      message:
                          "Quantity can't be edited when box quantity is applied.",
                      backgroundColor: Colors.redAccent,
                    );
                  }

                  cartProvider.calculateSubtotal();
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.blue),
        iconSize: 16,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  void _showSelectedItemsDialog(CartSelectionProvider selectionProvider) {
    showDialog(
      context: context,
      builder: (context) => SelectedItemsDialog(
        itemSelectionState: selectionProvider.itemSelectionState,
        cartItems: globals.cartItems,
      ),
    );
  }

  Widget _buildCartFooter(
    CartProvider cartProvider,
    CartSelectionProvider selectionProvider,
  ) {
    final List<String> chargeTypes = [
      "Custom Charge",
      "Delivery Charge",
      "Other Charges",
    ];

    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          // ========================= LEFT DROPDOWN + INPUT ==========================
          Expanded(
            flex: 4,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blueAccent, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Row(
                    children: [
                      // ---------------------- Dropdown -----------------------
                      Expanded(
                        flex: 5,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: customerProvider.selectedChargeType,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            icon: const Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 22,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            items: chargeTypes.map((value) {
                              return DropdownMenuItem(
                                value: value,
                                child: Row(
                                  children: [
                                    Icon(
                                      value == "Custom Charge"
                                          ? Icons.price_change_rounded
                                          : value == "Delivery Charge"
                                          ? Icons.local_shipping_rounded
                                          : Icons.attach_money_rounded,
                                      size: 18,
                                      color: Colors.blueAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(value),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                customerProvider.selectedChargeType = newValue!;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // ---------------------- Input Field -----------------------
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          readOnly: true,
                          showCursor: true,
                          controller: cartProvider.customChargeController,
                          focusNode: customChargeFocus,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.blue.shade300,
                                width: 1,
                              ),
                            ),
                          ),
                          onTap: () {
                            ActiveField.activate(
                              context: context,
                              ctrl: cartProvider.customChargeController,
                              node: customChargeFocus,
                              numeric: true,
                              customCharge: true,
                              fieldType: "custom charge",
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ========================== VIEW BUTTON ==========================
          SizedBox(
            width: 80,
            height: 45,
            child: ElevatedButton(
              onPressed:
                  globals.cartItems.any(
                    (item) => item.boxQuantity != null && item.boxQuantity! > 0,
                  )
                  ? () {
                      _showSelectedItemsDialog(selectionProvider);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                "View",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ========================== TOTAL AMOUNT ==========================
          Expanded(
            flex: 3,
            child: Consumer<CartProvider>(
              builder: (context, cartProvider, _) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: CustomText(
                    text:
                        'Total ₹${cartProvider.getTotalAmount().toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

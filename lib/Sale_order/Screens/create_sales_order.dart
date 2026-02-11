import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yen_pos/Global/Widget/custom_textWidgets.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Sale_order/Provider/cartProvider.dart';
import 'package:yen_pos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yen_pos/Sale_order/Screens/salesorder_Customerdetails.dart';
import 'package:yen_pos/Sale_order/Widgets/customAll_keyboard.dart';
import 'package:yen_pos/Sale_order/Widgets/custom_qty_keyboard.dart';
import 'package:yen_pos/Sale_order/Widgets/customcharge_keybaord.dart';
import 'package:yen_pos/Sale_order/Widgets/disposable_builder.dart';
import 'package:yen_pos/Sale_order/Widgets/numeric_Calculator.dart';
import 'package:yen_pos/Sale_order/Widgets/printer_dialogue_configuration.dart';
import 'package:yen_pos/Sale_order/Widgets/search_drop_filed.dart';
import 'package:yen_pos/Sale_order/Widgets/selected_items_dialogue.dart';
import 'package:yen_pos/Sale_order/Widgets/storetype_selection_dialogue.dart';
import 'package:yen_pos/Sale_order/Widgets/top_message.dart';
import 'package:yen_pos/printer_screen/provider/printer_config_provider.dart';

class SalesOrderScreen extends StatefulWidget {
  const SalesOrderScreen({super.key});

  @override
  SalesOrderScreenState createState() => SalesOrderScreenState();
}

class SalesOrderScreenState extends State<SalesOrderScreen> {
  // ==================== State Variables ====================
  late FocusNode customChargeFocus;
  late FocusNode allBoxQtyFocus;
  late TextEditingController allBoxQtyController;
  late TextEditingController bulkDiscountController;

  bool isStoreTypeDialogShowing = false;
  bool isStoreTypeSelected = false;
  bool showCheckBoxes = false;
  bool _isDialogShownToday = false;
  bool _isInternalUpdate = false;
  bool _isDisposed = false;
  bool _isBuildInProgress = false; // ✅ NEW: Prevent setState during build
  bool _isPrinterDialogShowing = false;
  bool _hasShownPrinterDialogOnce = false;
  String selectedStoreType = 'Warehouse';

  final Map<String, TextEditingController> boxQtyControllers = {};
  final Map<String, TextEditingController> discountControllers = {};
  final Map<String, FocusNode> discountFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupProviders();
    _setupListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _checkPrinterIpAndAlert();
      }
    });
  }

  /// Initialize all text editing controllers and focus nodes
  void _initializeControllers() {
    allBoxQtyController = TextEditingController();
    bulkDiscountController = TextEditingController();
    customChargeFocus = FocusNode();
    allBoxQtyFocus = FocusNode();
  }

  /// Setup provider instances and initial state
  void _setupProviders() {
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    customerProvider.setSelectedCustomCharge("Custom Charges");

    _initializeCartNotifiers(customerProvider);
  }

  void _initializeCartNotifiers(CustomerScreenProvider customerProvider) {
    customerProvider.cartItemCountNotifier = ValueNotifier<int>(
      globals.cartItems.length,
    );
    customerProvider.cartItemsNotifier = ValueNotifier<int>(
      globals.cartItems.length,
    );

    globals.cartItems.clear();
  }

  /// Setup listeners for controllers and providers
  void _setupListeners() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    cartProvider.addListener(customerProvider.updateCartCount);
    cartProvider.addListener(customerProvider.updateCartItems);

    allBoxQtyController.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed && !_isBuildInProgress) {
          _applyBulkBoxQtyUpdate(allBoxQtyController.text);
        }
      });
    });

    bulkDiscountController.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed && !_isBuildInProgress) {
          _applyBulkDiscount(bulkDiscountController.text);
        }
      });
    });
  }

  // ==================== Price Calculation Methods ====================

  /// Update gifted item price based on quantity and discount
  void updateGiftedItemPrice(CartItem item) {
    if (item.isBoxItem != 'yes' || item.boxQuantity == null) return;

    final basePrice = _calculateBasePrice(item);
    item.sellingAmount = basePrice;
    item.sellingPrice = item.pricePerKg;

    if (item.itemWiseDiscount != null && item.itemWiseDiscount! > 0) {
      item.itemWiseDiscountAmount = basePrice * (item.itemWiseDiscount! / 100);
      item.finalPrice = basePrice - item.itemWiseDiscountAmount!;
    } else {
      item.itemWiseDiscountAmount = 0;
      item.finalPrice = basePrice;
    }
  }

  /// Calculate base price for an item considering UOM and weight
  double _calculateBasePrice(CartItem item) {
    if (item.isBoxItem == 'yes' && item.boxQuantity != null) {
      if (item.uom?.toLowerCase() == 'kg' || item.uom?.toLowerCase() == 'kgs') {
        return (item.weight * item.boxQuantity! * item.pricePerKg).toDouble();
      } else {
        return (item.boxQuantity! * item.pricePerKg).toDouble();
      }
    } else {
      if (item.uom == 'Kg' || item.uom == 'Kgs') {
        return (item.quantity.value * item.pricePerKg * item.weight).toDouble();
      } else {
        return (item.quantity.value * item.pricePerKg).toDouble();
      }
    }
  }

  /// Calculate total for selected items
  double _calculateSelectedItemsTotal(List<CartItem> selectedItems) {
    double total = 0.0;

    for (var item in selectedItems) {
      double baseAmount = _calculateBasePrice(item);

      if (item.itemWiseDiscount != null && item.itemWiseDiscount! > 0) {
        double discountAmount = baseAmount * (item.itemWiseDiscount! / 100);
        baseAmount -= discountAmount;
      }

      total += baseAmount;
    }

    return total;
  }

  /// Apply discount to a single item
  void applySingleItemDiscount(String key, String value) {
    if (value.isEmpty) {
      _handleEmptyDiscount(key);
      return;
    }

    final discount = double.tryParse(value);
    if (discount == null || discount < 0) return;

    final itemIndex = globals.cartItems.indexWhere(
      (item) => item.varianceName == key,
    );

    if (itemIndex != -1) {
      _applyDiscountToItem(globals.cartItems[itemIndex], discount);
      if (mounted && !_isDisposed && !_isBuildInProgress) {
        // ✅ FIXED: Use post frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed) {
            Provider.of<CartProvider>(context, listen: false).updateCart();
          }
        });
      }
    }
  }

  /// Handle empty discount input
  void _handleEmptyDiscount(String key) {
    if (!mounted || _isDisposed) return;

    // ✅ FIXED: Use post frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed || _isBuildInProgress) return;

      setState(() {
        discountControllers[key]?.text = '';

        final itemIndex = globals.cartItems.indexWhere(
          (item) => item.varianceName == key,
        );

        if (itemIndex != -1) {
          final item = globals.cartItems[itemIndex];
          item.itemWiseDiscount = 0.0;
          item.itemWiseDiscountAmount = 0.0;
          item.finalPrice = null;
          _recalculateSellingAmount(item);
          Provider.of<CartProvider>(context, listen: false).updateCart();
        }
      });
    });
  }

  /// Apply discount calculation to item
  void _applyDiscountToItem(CartItem item, double discount) {
    item.sellingPrice = item.pricePerKg;

    num sellingAmount = _calculateSellingAmountBeforeDiscount(item);
    item.sellingAmount = sellingAmount.toDouble();

    item.itemWiseDiscount = discount;
    double discountAmount = sellingAmount * (discount / 100);
    item.itemWiseDiscountAmount = discountAmount;
    item.finalPrice = sellingAmount - discountAmount;
  }

  /// Recalculate selling amount for item
  void _recalculateSellingAmount(CartItem item) {
    if (item.isBoxItem == 'yes' && item.boxQuantity != null) {
      if (item.uom?.toLowerCase() == 'kg' || item.uom?.toLowerCase() == 'kgs') {
        item.sellingAmount = (item.weight * item.boxQuantity! * item.pricePerKg)
            .toDouble();
      } else {
        item.sellingAmount = (item.boxQuantity! * item.pricePerKg).toDouble();
      }
    } else {
      num sellingAmount = (item.uom == 'Kg' || item.uom == 'Kgs')
          ? (item.quantity.value * item.pricePerKg * item.weight)
          : (item.quantity.value * item.pricePerKg);
      item.sellingAmount = sellingAmount.toDouble();
    }
    item.sellingPrice = item.pricePerKg;
  }

  // ==================== Cart Management Methods ====================

  /// Clear cart and reset all UI state
  void clearCartAndResetState(CartProvider cartProvider) {
    if (!mounted || _isDisposed) return;

    cartProvider.clearCart();
    allBoxQtyController.clear();
    bulkDiscountController.clear();
    Provider.of<CartSelectionProvider>(
      context,
      listen: false,
    ).clearSelections();

    for (final controller in boxQtyControllers.values) {
      controller.clear();
    }
    for (final controller in discountControllers.values) {
      controller.clear();
    }
  }

  /// Apply bulk discount to selected items
  void _applyBulkDiscount(String value) {
    if (!mounted || _isDisposed || _isBuildInProgress) return;

    final selectionProvider = Provider.of<CartSelectionProvider>(
      context,
      listen: false,
    );

    // 1️⃣ Trim value and check if empty
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      // Clear discount for all selected items
      _clearBulkDiscount(selectionProvider);
      // Also update cart
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          Provider.of<CartProvider>(context, listen: false).updateCart();
        }
      });
      return;
    }

    // 2️⃣ Parse the discount percent
    final discountPercent = double.tryParse(trimmedValue);
    if (discountPercent == null || discountPercent < 0) {
      // Invalid input, ignore
      return;
    }

    // 3️⃣ Apply discount to all selected items
    _applyBulkDiscountToSelected(selectionProvider, discountPercent);

    // 4️⃣ Update cart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        Provider.of<CartProvider>(context, listen: false).updateCart();
      }
    });
  }

  /// Clear bulk discount for all selected items
  void _clearBulkDiscount(CartSelectionProvider selectionProvider) {
    selectionProvider.itemSelectionState.forEach((key, isSelected) {
      if (!isSelected) return;

      // Clear the text field for this key
      discountControllers[key]?.value = discountControllers[key]!.value
          .copyWith(
            text: '',
            selection: const TextSelection.collapsed(offset: 0),
          );

      // Loop through all cart items with the same varianceName
      final matchingItems = globals.cartItems.where(
        (item) => item.varianceName == key,
      );

      for (var item in matchingItems) {
        item.itemWiseDiscount = 0.0;
        item.itemWiseDiscountAmount = 0.0;
        item.finalPrice = null;
      }
    });
  }

  /// Apply bulk discount to selected items
  void _applyBulkDiscountToSelected(
    CartSelectionProvider selectionProvider,
    double discountPercent,
  ) {
    selectionProvider.itemSelectionState.forEach((key, isSelected) {
      if (!isSelected) return;

      // Loop through all cart items with the same varianceName
      final matchingItems = globals.cartItems.where(
        (item) => item.varianceName == key,
      );

      for (var item in matchingItems) {
        // ✅ Calculate original amount including box & unit quantities
        double originalAmount = _calculateSellingAmountBeforeDiscount(item);

        // ✅ Apply discount
        double discountAmount = (originalAmount * discountPercent) / 100;
        double finalPrice = originalAmount - discountAmount;

        // Update item
        item.itemWiseDiscount = discountPercent;
        item.itemWiseDiscountAmount = discountAmount;
        item.finalPrice = finalPrice;
      }

      // Update controller UI for that key
      String discountText = discountPercent.toString();
      discountControllers[key]?.value = discountControllers[key]!.value
          .copyWith(
            text: discountText,
            selection: TextSelection.collapsed(offset: discountText.length),
          );
    });
  }

  double _calculateSellingAmountBeforeDiscount(CartItem item) {
    // Determine total quantity
    int totalUnits = item.quantity.value; // single unit quantity

    // If the item is a box item, multiply by boxQuantity
    if ((item.isBoxItem ?? '') == 'yes' && (item.boxQuantity ?? 0) > 0) {
      totalUnits = (item.boxQuantity ?? 0) * item.quantity.value;
    }

    // Use sellingPrice if available, otherwise pricePerKg
    double unitPrice = (item.sellingPrice ?? item.pricePerKg).toDouble();

    // Return total amount
    return totalUnits * unitPrice;
  }

  /// Apply bulk box quantity update to selected items
  void _applyBulkBoxQtyUpdate(String value) {
    int? newQty = int.tryParse(value);
    if (newQty == null || newQty <= 0) return;

    if (!mounted || _isDisposed || _isBuildInProgress) return;

    // ✅ FIXED: Use post frame callback instead of direct setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;

      setState(() {
        final selectionProvider = Provider.of<CartSelectionProvider>(
          context,
          listen: false,
        );
        final cartProvider = Provider.of<CartProvider>(context, listen: false);

        selectionProvider.itemSelectionState.forEach((key, isSelected) {
          if (!isSelected) return;

          for (var item in globals.cartItems.where(
            (i) => i.varianceName == key,
          )) {
            item.quantity.value = newQty;
            item.boxQuantity = newQty;
            item.isBoxItem = 'yes';

            double total = _calculateBasePrice(item);

            if (item.itemWiseDiscount != null && item.itemWiseDiscount! > 0) {
              item.itemWiseDiscountAmount =
                  total * (item.itemWiseDiscount! / 100);
              item.finalPrice = total - item.itemWiseDiscountAmount!;
            } else {
              item.finalPrice = total;
              item.itemWiseDiscountAmount = 0;
            }
          }
        });

        if (bulkDiscountController.text.isNotEmpty) {
          _applyBulkDiscount(bulkDiscountController.text);
          cartProvider.updateCart();
        }
      });
    });
  }

  Future<void> _checkPrinterIpAndAlert() async {
    if (!mounted || _isDisposed) return;
    try {
      final printerProvider = Provider.of<PrinterProviderpos>(
        context,
        listen: false,
      );
      await printerProvider.initializeHive();
      final String? printerIp = printerProvider.getPrinterIpFromHive(
        type: 'Overall',
      );
      if (kDebugMode) {
        print("Printer IP from Hive: '$printerIp'");
      }
      // ✅ DIRECT CHECK
      if (printerIp == null || printerIp.isEmpty || printerIp == '0.0.0.0') {
        if (!mounted || _isDisposed) return;
        // ✅ SHOW DIALOG DIRECTLY
        await showPrinterConfigDialog(context);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Printer check error: $e');
      }
    }
  }

  /// Show store type selection dialog
  Future<void> _showStoreTypeDialog() {
    if (!mounted) return Future.value();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          StoreTypeSelectionDialog(onStoreTypeSelected: _saveStoreType),
    );
  }

  /// Save selected store type to preferences
  Future<void> _saveStoreType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

    await prefs.setString('storeType', type);
    await prefs.setInt('lastShownTimestamp', currentTimestamp);

    if (!mounted || _isDisposed) return;

    setState(() {
      selectedStoreType = type;
      isStoreTypeSelected = true;
    });
  }

  /// Show clear cart confirmation dialog
  Future<void> _showClearCartConfirmationDialog(
    CartProvider cartProvider,
  ) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _buildClearCartDialog(dialogContext, cartProvider);
      },
    );
  }

  Widget _buildClearCartDialog(
    BuildContext dialogContext,
    CartProvider cartProvider,
  ) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 400, // 🔥 control dialog width here
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// 🔴 ICON BADGE
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.redAccent.shade200,
                        Colors.redAccent.shade400,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Clear Cart',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),

                const SizedBox(height: 12),

                const Text(
                  'This will remove all items from your cart.\nThis action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          clearCartAndResetState(cartProvider);
                          bulkDiscountController.clear();
                          Navigator.of(dialogContext).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 6,
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Clear Cart',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }

  /// Show selected items dialog
  void _showSelectedItemsDialog(CartSelectionProvider selectionProvider) {
    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      builder: (context) => SelectedItemsDialog(
        itemSelectionState: selectionProvider.itemSelectionState,
        cartItems: globals.cartItems,
      ),
    );
  }

  /// Show custom charge dialog
  void _showCustomChargeDialog(
    CartProvider cartProvider,
    CustomerScreenProvider customerProvider,
  ) {
    if (!mounted || _isDisposed) return;

    final controllers = _initializeChargeControllers(cartProvider);
    var chargeValues = _initializeChargeValues();
    final keyboardProvider = context.read<CustomchargeKeyboardProvider>();
    final clearedControllers = <String>{};

    _registerChargeControllers(keyboardProvider, controllers);

    String selectedChargeType = _getInitialChargeType(customerProvider);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return _buildCustomChargeDialog(
            controllers,
            chargeValues,
            clearedControllers,
            selectedChargeType,
            keyboardProvider,
            setStateDialog,
            (newType) {
              selectedChargeType = newType;
              customerProvider.selectedChargeType = newType;
            },
            () {
              _applyCustomCharges(
                cartProvider,
                customerProvider,
                controllers,
                chargeValues,
              );
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  /// Initialize charge controllers
  Map<String, TextEditingController> _initializeChargeControllers(
    CartProvider cartProvider,
  ) {
    Map<String, TextEditingController> controllers = {};

    for (var charge in GlobalDataManager().charges) {
      final chargeType = charge['chargeType'];

      if (cartProvider.customChargeControllers.containsKey(chargeType)) {
        controllers[chargeType] =
            cartProvider.customChargeControllers[chargeType]!;
      } else {
        final controller = TextEditingController(
          text: (charge['amount'] ?? 0).toStringAsFixed(0),
        );
        controllers[chargeType] = controller;
        cartProvider.customChargeControllers[chargeType] = controller;
      }
    }

    return controllers;
  }

  /// Initialize charge values map
  Map<String, double> _initializeChargeValues() {
    return {
      for (var charge in GlobalDataManager().charges)
        charge['chargeType']: (charge['amount'] ?? 0).toDouble(),
    };
  }

  /// Register charge controllers in keyboard provider
  void _registerChargeControllers(
    CustomchargeKeyboardProvider keyboardProvider,
    Map<String, TextEditingController> controllers,
  ) {
    controllers.forEach((key, controller) {
      keyboardProvider.registerController(key, controller);
    });
  }

  /// Get initial charge type
  String _getInitialChargeType(CustomerScreenProvider customerProvider) {
    return customerProvider.selectedChargeType ??
        (GlobalDataManager().charges.isNotEmpty
            ? GlobalDataManager().charges.first['chargeType']
            : "");
  }

  /// Apply custom charges and update cart
  void _applyCustomCharges(
    CartProvider cartProvider,
    CustomerScreenProvider customerProvider,
    Map<String, TextEditingController> controllers,
    Map<String, double> chargeValues,
  ) {
    if (!mounted || _isDisposed) return;

    for (var charge in GlobalDataManager().charges) {
      final chargeType = charge['chargeType'];
      final controller = controllers[chargeType];

      if (controller != null) {
        final textValue = controller.text.isEmpty ? '0.00' : controller.text;
        final value = double.tryParse(textValue) ?? 0.0;
        chargeValues[chargeType] = value;
        charge['amount'] = value;
      }
    }

    double totalCustomCharges = chargeValues.values.fold(
      0.0,
      (sum, value) => sum + value,
    );

    setState(() {
      customerProvider.selectedChargeType = customerProvider.selectedChargeType;
      cartProvider.customCharge.value = totalCustomCharges;
      _updateCustomChargeCollections(cartProvider, chargeValues);
      _storeControllers(cartProvider, controllers);
    });
  }

  /// Update custom charge type and value collections
  void _updateCustomChargeCollections(
    CartProvider cartProvider,
    Map<String, double> chargeValues,
  ) {
    cartProvider.customChargeTypes.clear();
    cartProvider.customChargeValues.clear();

    chargeValues.forEach((type, value) {
      if (value > 0) {
        cartProvider.customChargeTypes.add(type);
        cartProvider.customChargeValues.add(value);
      }
    });
  }

  /// Store all controllers in cart provider
  void _storeControllers(
    CartProvider cartProvider,
    Map<String, TextEditingController> controllers,
  ) {
    for (var entry in controllers.entries) {
      cartProvider.customChargeControllers[entry.key] = entry.value;
    }
  }

  /// Clear custom charge dialogue
  void _clearCustomChargeDialogue() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    for (var controller in cartProvider.customChargeControllers.values) {
      controller?.clear();
    }

    cartProvider.customChargeControllers.clear();

    for (var charge in GlobalDataManager().charges) {
      charge['amount'] = 0.0;
    }

    cartProvider.customCharge.value = 0.0;
    cartProvider.customChargeTypes.clear();
    cartProvider.customChargeValues.clear();
  }

  // ==================== UI Building Methods ====================

  /// Build app bar
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ApiServiceSalesOrderProvider apiService,
    CartSelectionProvider selectionProvider,
    CustomerScreenProvider customerScreenProvider,
  ) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      title: const Row(
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
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/all-orders'),
                  ),
                  const SizedBox(width: 10),
                  _buildCreateOrderButton(selectionProvider),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOrderTypeChip(
                  label: 'Inhouse',
                  isSelected: customerScreenProvider.orderType == 'Inhouse',
                  onSelected: (selected) {
                    if (selected) {
                      customerScreenProvider.setOrderType('Inhouse');
                    }
                  },
                ),
                const SizedBox(width: 10),
                _buildOrderTypeChip(
                  label: 'Warehouse',
                  isSelected: customerScreenProvider.orderType == 'Warehouse',
                  onSelected: (selected) {
                    if (selected) {
                      customerScreenProvider.setOrderType('Warehouse');
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      toolbarHeight: kToolbarHeight,
    );
  }

  /// Build navigation button
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

  /// Build create order button
  Widget _buildCreateOrderButton(CartSelectionProvider selectionProvider) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        elevation: 2,
      ),
      child: const Text('Create Order'),
    );
  }

  /// Build order type choice chip
  Widget _buildOrderTypeChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: Colors.blue,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }

  /// Build left side content (cart)
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
          ),
          const SizedBox(height: 16.0),
          _buildCartFooter(cartProvider, selectionProvider),
        ],
      ),
    );
  }

  /// Build cart details header
  Widget _buildCartDetailsHeader(CartSelectionProvider selectionProvider) {
    final cartProvider = context.read<CartProvider>();
    final customerProvider = context.read<CustomerScreenProvider>();

    return ValueListenableBuilder<int>(
      valueListenable: customerProvider.cartItemCountNotifier,
      builder: (context, cartItemCount, _) {
        final selectedCount = selectionProvider.itemSelectionState.values
            .where((isSelected) => isSelected)
            .length;

        return Row(
          children: [
            Text(
              'Cart Details $cartItemCount',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Spacer(),
            _buildGiftedItemsButton(selectionProvider),
            if (selectionProvider.showCheckBoxes) ...[
              const SizedBox(width: 10),
              Text(
                '$selectedCount selected',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(width: 10),
            _buildClearCartButton(cartProvider),
          ],
        );
      },
    );
  }

  /// Build gifted items toggle button
  Widget _buildGiftedItemsButton(CartSelectionProvider selectionProvider) {
    return ElevatedButton(
      onPressed: () {
        final wasShowing = selectionProvider.showCheckBoxes;
        selectionProvider.toggleCheckBoxVisibility();

        if (wasShowing) {
          for (var item in globals.cartItems) {
            final isSelected =
                selectionProvider.itemSelectionState[item.varianceName] ??
                false;
            if (!isSelected) {
              item.quantity.value = 1;
              item.boxQuantity = null;
              allBoxQtyController.clear();
            }
          }
        }
      },
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      child: Text(
        selectionProvider.showCheckBoxes ? 'UNSELECT ITEMS' : 'GIFTED ITEMS',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  /// Build clear cart button
  Widget _buildClearCartButton(CartProvider cartProvider) {
    return IconButton(
      onPressed: globals.cartItems.isNotEmpty
          ? () {
              _showClearCartConfirmationDialog(cartProvider);
            }
          : null,
      icon: Icon(
        Icons.delete,
        color: globals.cartItems.isNotEmpty ? Colors.red : Colors.grey,
      ),
    );
  }

  /// Build cart items list
  /// ✅ FIXED: Marked build to prevent setState during build
  Widget _buildCartItemsList(CartSelectionProvider selectionProvider) {
    _isBuildInProgress = true; // ✅ Mark build in progress

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    final widget = ValueListenableBuilder<int>(
      valueListenable: customerProvider.cartItemsNotifier,
      builder: (context, _, child) {
        if (globals.cartItems.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No items in cart'),
            ),
          );
        }

        final selectedItems = _getSelectedItems(selectionProvider);
        final unselectedItems = _getUnselectedItems(selectionProvider);
        final selectedTotal = _calculateSelectedItemsTotal(selectedItems);

        return ListView(
          children: [
            if (selectedItems.isNotEmpty)
              _buildSelectedItemsSection(
                selectedItems,
                selectedTotal,
                cartProvider,
                selectionProvider,
              ),
            for (var item in unselectedItems)
              if (_isValidItem(item))
                _buildItemTileWrapper(
                  item: item,
                  cartProvider: cartProvider,
                  selectionProvider: selectionProvider,
                ),
          ],
        );
      },
      child: DisposableBuilder(
        onDispose: () {
          _isBuildInProgress = false; // ✅ Mark build complete
          if (mounted) {
            cartProvider.removeListener(customerProvider.updateCartCount);
            cartProvider.updateCart();
            customerProvider.cartItemCountNotifier.dispose();
          }
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isBuildInProgress = false; // ✅ Mark build complete after frame
    });

    return widget;
  }

  /// Get selected items from cart
  List<CartItem> _getSelectedItems(CartSelectionProvider selectionProvider) {
    return globals.cartItems.where((item) {
      return selectionProvider.itemSelectionState[item.varianceName] ?? false;
    }).toList();
  }

  /// Get unselected items from cart
  List<CartItem> _getUnselectedItems(CartSelectionProvider selectionProvider) {
    return globals.cartItems.where((item) {
      return !(selectionProvider.itemSelectionState[item.varianceName] ??
          false);
    }).toList();
  }

  Widget _buildSelectedItemsSection(
    List<CartItem> selectedItems,
    double selectedTotal,
    CartProvider cartProvider,
    CartSelectionProvider selectionProvider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 4.0,
        vertical: 8.0,
      ), // reduced bottom margin
      padding: const EdgeInsets.all(12.0), // reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.08),
            blurRadius: 12.0, // smaller blur
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.04),
            blurRadius: 4.0,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.blue.shade50, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28.0, // slightly smaller
                    height: 28.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      size: 16.0, // smaller icon
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(width: 8.0), // reduced spacing
                  const Text(
                    "Gift Items",
                    style: TextStyle(
                      fontSize: 14.0, // smaller text
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A237E),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      "${selectedItems.length} item${selectedItems.length > 1 ? 's' : ''}",
                      style: const TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                "₹${selectedTotal.round()}",
                style: const TextStyle(
                  fontSize: 16.0, // slightly smaller
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A237E),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8.0), // tighter spacing
          // Bulk controls
          _buildBulkControlsSection(),

          const SizedBox(height: 8.0),

          // Items list
          Column(
            children: [
              for (var item in selectedItems)
                if (_isValidItem(item))
                  _buildItemTileWrapper(
                    item: item,
                    cartProvider: cartProvider,
                    selectionProvider: selectionProvider,
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkControlsSection() {
    return Container(
      padding: const EdgeInsets.all(8.0), // reduced padding
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE3F2FD), width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(child: _buildAllBoxQtyField("bulk_box_qty")),
          const SizedBox(width: 8.0), // reduced spacing
          Expanded(child: _buildBulkDiscountField()),
        ],
      ),
    );
  }

  Widget _buildAllBoxQtyField(String key) {
    return SizedBox(
      width: 80, // slightly smaller width
      child: TextField(
        readOnly: true,
        showCursor: true,
        controller: allBoxQtyController,
        decoration: InputDecoration(
          labelText: 'Box Qty',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          filled: true,
          fillColor: Colors.blue.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10.0,
            vertical: 6.0,
          ),
        ),
        onTap: () {
          ActiveField.activate(
            context: context,
            ctrl: allBoxQtyController,
            node: allBoxQtyFocus,
            numeric: true,
            fieldType: "boxQty",
          );
        },
        keyboardType: TextInputType.number,
        onChanged: _applyBulkBoxQtyUpdate,
      ),
    );
  }

  Widget _buildBulkDiscountField() {
    return SizedBox(
      width: 80,
      child: TextField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Discount',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.blue.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10.0,
            vertical: 6.0,
          ),
          labelStyle: TextStyle(color: Colors.blue.shade700, fontSize: 10),
          suffixIcon: Icon(Icons.percent, size: 16),
        ),
        controller: bulkDiscountController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d{0,2})?$')),
        ],
        onTap: () {
          ActiveField.activate(
            context: context,
            ctrl: bulkDiscountController,
            node: FocusNode(),
            numeric: true,
            fieldType: "discount",
          );
        },
        onChanged: _applyBulkDiscount,
      ),
    );
  }

  /// Check if item is valid
  bool _isValidItem(dynamic item) {
    try {
      return item != null &&
          item.varianceName != null &&
          item.varianceName.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Build item tile wrapper with safety checks
  Widget _buildItemTileWrapper({
    required dynamic item,
    required CartProvider cartProvider,
    required CartSelectionProvider selectionProvider,
  }) {
    final key = item.varianceName;

    int originalIndex = -1;
    try {
      originalIndex = globals.cartItems.indexWhere(
        (e) => e.varianceName == item.varianceName,
      );
    } catch (e) {
      // Ignore error
    }

    if (originalIndex < 0 || originalIndex >= globals.cartItems.length) {
      return SizedBox.shrink();
    }

    return _buildCartItemTile(
      context: context,
      item: item,
      keyValue: key,
      originalIndex: originalIndex,
      cartProvider: cartProvider,
      selectionProvider: selectionProvider,
    );
  }

  /// Build individual cart item tile
  /// ✅ FIXED: Safe removal without setState issues
  Widget _buildCartItemTile({
    required BuildContext context,
    required CartItem item,
    required String keyValue,
    required int originalIndex,
    required CartProvider cartProvider,
    required CartSelectionProvider selectionProvider,
  }) {
    return Dismissible(
      key: ValueKey(item.rowId),
      direction: DismissDirection.endToStart,

      /// ✅ DIRECT DELETE (NO CONFIRMATION)
      onDismissed: (_) {
        cartProvider.removeItemByRowId(item.rowId);

        final selectionKey = '${item.varianceName}_${item.isBoxItem}';
        selectionProvider.itemSelectionState.remove(selectionKey);
      },

      /// 🔴 DELETE BACKGROUND
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),

      /// 🧾 CART ITEM UI
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildCartItemContent(
          item: item,
          key: keyValue,
          originalIndex: originalIndex,
          cartProvider: cartProvider,
          selectionProvider: selectionProvider,
        ),
      ),
    );
  }

  /// Build cart item content
  Widget _buildCartItemContent({
    required CartItem item,
    required String key,
    required int originalIndex,
    required CartProvider cartProvider,
    required CartSelectionProvider selectionProvider,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          if (selectionProvider.showCheckBoxes)
            Checkbox(
              value: selectionProvider.itemSelectionState[key] ?? false,
              onChanged: (bool? value) {
                _handleCheckboxChange(
                  value,
                  key,
                  item,
                  cartProvider,
                  selectionProvider,
                );
              },
            ),
          const SizedBox(width: 6),
          Expanded(child: _buildItemDetails(item)),
          if ((!selectionProvider.showCheckBoxes &&
                  (selectionProvider.itemSelectionState[key] ?? false)) ||
              (selectionProvider.showCheckBoxes &&
                  !(selectionProvider.itemSelectionState[key] ?? false)))
            _buildDiscountField(key, item),
          _buildItemPriceAndControls(
            item: item,
            originalIndex: originalIndex,
            cartProvider: cartProvider,
            key: key,
            selectionProvider: selectionProvider,
          ),
        ],
      ),
    );
  }

  /// Handle checkbox state change
  void _handleCheckboxChange(
    bool? value,
    String key,
    CartItem item,
    CartProvider cartProvider,
    CartSelectionProvider selectionProvider,
  ) {
    if (!mounted || _isDisposed || _isBuildInProgress) return;

    selectionProvider.toggleItemSelection(key, value ?? false);

    if (value == true) {
      item.isBoxItem = 'yes';
      item.itemWiseDiscount = 0.0;
      item.itemWiseDiscountAmount = 0.0;
      item.boxQuantity = int.tryParse(allBoxQtyController.text) ?? 0;
      boxQtyControllers[key]?.text = item.boxQuantity.toString();
      item.quantity.value = int.tryParse(allBoxQtyController.text) ?? 0;
    } else {
      item.isBoxItem = 'no';
      item.itemWiseDiscount = 0.0;
      item.itemWiseDiscountAmount = 0.0;
      item.boxQuantity = 1;
      boxQtyControllers[key]?.text = '1';
      discountControllers[key]?.clear();
      item.quantity.value = 1;
    }

    setState(() {
      cartProvider.updateCart();
    });
  }

  /// Build item details section
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
        GestureDetector(
          onTap: () {
            if (item.uom == 'Kg' || item.uom == 'Kgs') {
              _showWeightCalculator(context, item);
            }
          },
          child: Text(
            _getItemPriceDescription(item),
            style: TextStyle(
              fontSize: 13,
              color: (item.uom == 'Kg' || item.uom == 'Kgs')
                  ? Colors.blue
                  : Colors.grey,
              decoration: (item.uom == 'Kg' || item.uom == 'Kgs')
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  /// Show weight calculator dialog
  void _showWeightCalculator(BuildContext context, CartItem item) {
    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      builder: (_) => NumericCalculator(
        varianceName: item.varianceName,
        initialValue: item.weight ?? 1.0,
        onValueSelected: (double newValue) {
          if (mounted && !_isDisposed) {
            setState(() {
              item.weight = newValue;

              if (item.quantity != null && item.pricePerKg != null) {
                double total = newValue * item.quantity.value * item.pricePerKg;

                if (item.itemWiseDiscount != null &&
                    item.itemWiseDiscount! > 0) {
                  item.itemWiseDiscountAmount =
                      total * (item.itemWiseDiscount! / 100);
                  item.finalPrice = total - item.itemWiseDiscountAmount!;
                } else {
                  item.finalPrice = total;
                }
              }

              Provider.of<CartProvider>(context, listen: false).updateCart();
            });
          }
        },
      ),
    );
  }

  /// Get item price description
  String _getItemPriceDescription(dynamic item) {
    String priceDescription;

    if (item.uom == 'Kgs' || item.uom == 'Kg') {
      String weightText = item.weight >= 1
          ? '${item.weight} kg'
          : '${(item.weight * 1000)} grams';
      String priceText = ' × Rs.${item.pricePerKg}/kg';
      priceDescription = '$weightText$priceText';
    } else {
      priceDescription =
          '${item.quantity.value} ${item.uom} × Rs.${item.pricePerKg}/${item.uom}';
    }

    if (item.itemWiseDiscount != null && item.itemWiseDiscount != 0) {
      priceDescription +=
          '\nDiscount: ${item.itemWiseDiscount}% (Rs.${item.itemWiseDiscountAmount.round()})';
    }

    return priceDescription;
  }

  /// Format weight display
  String _formatOverallWeight(double totalWeightKg) {
    if (totalWeightKg >= 1) {
      if (totalWeightKg % 1 == 0) {
        return 'Total: ${totalWeightKg.toInt()} kg';
      } else {
        return 'Total: ${totalWeightKg.toStringAsFixed(3)} kg';
      }
    } else {
      double grams = totalWeightKg * 1000;
      if (grams % 1 == 0) {
        return 'Total: ${grams.toInt()} grams';
      } else {
        return 'Total: ${grams.toStringAsFixed(0)} grams';
      }
    }
  }

  /// Build item price and controls section
  Widget _buildItemPriceAndControls({
    required CartItem item,
    required int originalIndex,
    required CartProvider cartProvider,
    required String key,
    required CartSelectionProvider selectionProvider,
  }) {
    final discountPercent = item.itemWiseDiscount ?? 0;
    double total = _calculateBasePrice(item);

    if (discountPercent > 0) {
      item.itemWiseDiscountAmount = total * (discountPercent / 100);
      item.finalPrice = total - item.itemWiseDiscountAmount!;
    } else {
      item.finalPrice = total;
      item.itemWiseDiscountAmount = 0;
    }

    final originalPrice = total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!selectionProvider.showCheckBoxes)
              _buildDiscountField(key, item),
            const SizedBox(width: 10),
            _buildQuantityControls(
              originalIndex: originalIndex,
              cartProvider: cartProvider,
              key: key,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildPriceDisplay(
          item: item,
          originalPrice: originalPrice,
          discountPercent: discountPercent,
        ),
      ],
    );
  }

  /// Build price display section
  Widget _buildPriceDisplay({
    required CartItem item,
    required double originalPrice,
    required double discountPercent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.uom == 'Kg' || item.uom == 'Kgs')
                    Text(
                      _formatOverallWeight(item.weight * item.quantity.value),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
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
            ],
          ),
        ),
        if (discountPercent > 0) ...[
          Text(
            'Discount:  -Rs.${item.itemWiseDiscountAmount?.round() ?? 0}',
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
          Text(
            'Final Price: Rs.${item.finalPrice?.round() ?? originalPrice.round()}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  /// Build discount field for item
  Widget _buildDiscountField(String key, CartItem item) {
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: true,
    );

    bool isRestoring = customerProvider.isRestoringOrder;
    bool isApprovalOrder =
        customerProvider.isRestoringApprovalOrder ||
        (customerProvider.originalApprovalStatus?.toLowerCase().contains(
                  'approved',
                ) ==
                true ||
            customerProvider.originalApprovalStatus?.toLowerCase().contains(
                  'pending',
                ) ==
                true);

    bool isDisabled = isRestoring || isApprovalOrder;

    if (!discountControllers.containsKey(key)) {
      final controller = TextEditingController();
      if (item.itemWiseDiscount > 0) {
        controller.text = item.itemWiseDiscount.toStringAsFixed(0);
      }
      discountControllers[key] = controller;
    }

    _updateDiscountController(key, item);
    discountFocusNodes.putIfAbsent(key, () => FocusNode());

    final ctrl = discountControllers[key]!;
    final node = discountFocusNodes[key]!;

    return SizedBox(
      width: 130,
      child: AbsorbPointer(
        absorbing: isDisabled,
        child: Opacity(
          opacity: isDisabled ? 0.6 : 1.0,
          child: TextFormField(
            showCursor: !isDisabled,
            readOnly: true,
            controller: ctrl,
            focusNode: node,
            decoration: InputDecoration(
              labelText: 'Discount%',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: isDisabled
                      ? Colors.grey.shade400
                      : Colors.blue.shade700,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: isDisabled
                      ? Colors.grey.shade400
                      : Colors.blue.shade700,
                  width: 2.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: isDisabled
                      ? Colors.grey.shade300
                      : Colors.blue.shade300,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: isDisabled
                  ? Colors.grey.shade100
                  : Colors.blue.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              labelStyle: TextStyle(
                color: isDisabled ? Colors.grey.shade600 : Colors.blue.shade700,
                fontSize: 11,
              ),
              suffixIcon: Icon(
                Icons.percent,
                size: 17,
                color: isDisabled ? Colors.grey.shade500 : Colors.blue,
              ),
              hintText: isDisabled
                  ? (isApprovalOrder ? 'Approval Order' : 'Restoring...')
                  : null,
            ),
            onTap: isDisabled
                ? null
                : () {
                    ActiveField.activate(
                      context: context,
                      ctrl: ctrl,
                      node: node,
                      numeric: true,
                      discount: true,
                      fieldType: "discount",
                      onChanged: (value) {
                        _handleDiscountChange(value, key, ctrl);
                      },
                    );
                  },
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ),
    );
  }

  /// Update discount controller value
  void _updateDiscountController(String key, CartItem item) {
    if (!discountControllers.containsKey(key)) return;

    final controller = discountControllers[key]!;

    if (_isInternalUpdate) return;

    if (item.itemWiseDiscount > 0) {
      final newText = item.itemWiseDiscount.toStringAsFixed(0);

      if (controller.text != newText) {
        controller.value = controller.value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    } else if (controller.text.isNotEmpty) {
      controller.clear();
    }
  }

  /// Handle discount input change
  void _handleDiscountChange(
    String value,
    String key,
    TextEditingController ctrl,
  ) {
    if (_isInternalUpdate) return;

    _isInternalUpdate = true;

    if (value.isEmpty) {
      ctrl.clear();
      applySingleItemDiscount(key, '');
      _isInternalUpdate = false;
      return;
    }

    final discount = double.tryParse(value);
    if (discount == null || discount <= 0 || discount > 100) {
      ctrl.clear();
      applySingleItemDiscount(key, '');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Discount must be between 1 and 100"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      final discountValue = discount.toStringAsFixed(0);
      ctrl.text = discountValue;
      applySingleItemDiscount(key, discountValue);
    }

    _isInternalUpdate = false;
  }

  /// Build quantity controls
  Widget _buildQuantityControls({
    required int originalIndex,
    required CartProvider cartProvider,
    required String key,
  }) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final item = cartProvider.cartItems[originalIndex];
        final isBoxItem = item.isBoxItem == 'yes';

        return Row(
          children: [
            if (!isBoxItem)
              _buildQuantityButton(
                icon: Icons.remove,
                onPressed: () {
                  if (!mounted || _isDisposed || _isBuildInProgress) return;

                  setState(() {
                    if (item.quantity.value > 0) {
                      if (item.quantity.value == 1) {
                        cartProvider.removeItemFromCart(originalIndex);
                      } else {
                        cartProvider.updateQuantity(
                          originalIndex,
                          item.quantity.value - 1,
                        );
                      }
                    }
                    final ctrl = discountControllers[key];
                    if (ctrl != null && ctrl.text.isNotEmpty) {
                      applySingleItemDiscount(key, ctrl.text);
                    }
                  });
                },
              ),
            if (!isBoxItem) const SizedBox(width: 8),
            ValueListenableBuilder(
              valueListenable: item.quantity,
              builder: (context, qty, _) {
                return GestureDetector(
                  onTap: () {
                    if (!isBoxItem) {
                      cartProvider.showQuantityDialog(
                        context,
                        originalIndex,
                        qty,
                        item.uom,
                      );
                      final ctrl = discountControllers[key];
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
                      qty.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (!isBoxItem) const SizedBox(width: 8),
            if (!isBoxItem)
              _buildQuantityButton(
                icon: Icons.add,
                onPressed: () {
                  if (!mounted || _isDisposed || _isBuildInProgress) return;

                  setState(() {
                    cartProvider.updateQuantity(
                      originalIndex,
                      item.quantity.value + 1,
                    );
                    final ctrl = discountControllers[key];
                    if (ctrl != null && ctrl.text.isNotEmpty) {
                      applySingleItemDiscount(key, ctrl.text);
                    }
                    cartProvider.updateCart();
                  });
                },
              ),
          ],
        );
      },
    );
  }

  /// Build quantity button
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

  /// Build cart footer
  Widget _buildCartFooter(
    CartProvider cartProvider,
    CartSelectionProvider selectionProvider,
  ) {
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: () {
                _showCustomChargeDialog(cartProvider, customerProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                cartProvider.customCharge.value != 0
                    ? "Custom Charge: ₹${cartProvider.customCharge.value.toStringAsFixed(0)}"
                    : "Custom Charge",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
          Expanded(
            flex: 3,
            child: ValueListenableBuilder<double>(
              valueListenable: cartProvider.totalAmount,
              builder: (context, providerTotal, _) {
                final correctTotal = _calculateCorrectTotal(
                  selectionProvider,
                  cartProvider,
                );

                return Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total ₹${correctTotal.round()}',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate correct total including gifts and custom charges
  double _calculateCorrectTotal(
    CartSelectionProvider selectionProvider,
    CartProvider cartProvider,
  ) {
    double total = 0.0;

    // Normal items total
    for (var item in globals.cartItems) {
      final isGifted =
          selectionProvider.itemSelectionState[item.varianceName] ?? false;

      if (!isGifted) {
        if (item.finalPrice != null && item.finalPrice! > 0) {
          total += item.finalPrice!;
        } else {
          double itemTotal = _calculateBasePrice(item);
          total += itemTotal;
        }
      }
    }

    // Gifted items total
    final selectedItems = _getSelectedItems(selectionProvider);
    double giftedTotal = _calculateSelectedItemsTotal(selectedItems);
    total += giftedTotal;

    // Add custom charges
    total += cartProvider.customCharge.value;

    return total;
  }

  /// Build custom charge dialog
  Widget _buildCustomChargeDialog(
    Map<String, TextEditingController> controllers,
    Map<String, double> chargeValues,
    Set<String> clearedControllers,
    String selectedChargeType,
    CustomchargeKeyboardProvider keyboardProvider,
    StateSetter setStateDialog,
    Function(String) onChargeTypeChanged,
    VoidCallback onApplyPressed,
  ) {
    final mergedControllers = Listenable.merge(controllers.values);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: Colors.blueAccent.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildChargeDialogHeader(mergedControllers, controllers),
            const SizedBox(height: 16),
            _buildChargeList(
              controllers,
              clearedControllers,
              selectedChargeType,
              setStateDialog,
              onChargeTypeChanged,
            ),
            const SizedBox(height: 12),
            _buildChargeKeyboard(
              selectedChargeType,
              controllers,
              keyboardProvider,
            ),
            const SizedBox(height: 12),
            _buildChargeDialogButtons(onApplyPressed),
          ],
        ),
      ),
    );
  }

  /// Build charge dialog header
  Widget _buildChargeDialogHeader(
    Listenable mergedControllers,
    Map<String, TextEditingController> controllers,
  ) {
    return AnimatedBuilder(
      animation: mergedControllers,
      builder: (context, _) {
        double totalCustomCharges = controllers.values.fold(0.0, (sum, ctrl) {
          final value = double.tryParse(ctrl.text) ?? 0.0;
          return sum + value;
        });

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Charges: Rs.${totalCustomCharges.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build charge list
  Widget _buildChargeList(
    Map<String, TextEditingController> controllers,
    Set<String> clearedControllers,
    String selectedChargeType,
    StateSetter setStateDialog,
    Function(String) onChargeTypeChanged,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: GlobalDataManager().charges.length,
        separatorBuilder: (_, __) =>
            Divider(color: Colors.grey.shade300, height: 1),
        itemBuilder: (context, index) {
          final charge = GlobalDataManager().charges[index];
          final controller = controllers[charge['chargeType']]!;
          final isSelected = selectedChargeType == charge['chargeType'];

          final shouldShowZero =
              !clearedControllers.contains(charge['chargeType']) &&
              (controller.text.isEmpty || controller.text == '0.00');

          return _buildChargeListItem(
            charge,
            controller,
            isSelected,
            shouldShowZero,
            setStateDialog,
            onChargeTypeChanged,
            clearedControllers,
          );
        },
      ),
    );
  }

  /// Build individual charge list item
  Widget _buildChargeListItem(
    Map<String, dynamic> charge,
    TextEditingController controller,
    bool isSelected,
    bool shouldShowZero,
    StateSetter setStateDialog,
    Function(String) onChargeTypeChanged,
    Set<String> clearedControllers,
  ) {
    return GestureDetector(
      onTap: () {
        setStateDialog(() {
          onChargeTypeChanged(charge['chargeType']);
          controller.clear();
          clearedControllers.add(charge['chargeType']);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent.withOpacity(0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              charge['chargeType'],
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(
              width: 90,
              child: IgnorePointer(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    String displayText = value.text;
                    if (shouldShowZero && value.text.isEmpty) {
                      displayText = '0.00';
                    }

                    return TextFormField(
                      controller: controller,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 10,
                        ),
                        filled: true,
                        fillColor: isSelected
                            ? Colors.blue.shade50
                            : Colors.grey.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.blueAccent,
                            width: 2,
                          ),
                        ),
                        hintText: shouldShowZero ? '0.00' : null,
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build charge keyboard
  Widget _buildChargeKeyboard(
    String selectedChargeType,
    Map<String, TextEditingController> controllers,
    CustomchargeKeyboardProvider keyboardProvider,
  ) {
    return Container(
      height: 220,
      margin: const EdgeInsets.only(top: 8),
      child: Consumer<CustomchargeKeyboardProvider>(
        builder: (context, provider, _) {
          if (selectedChargeType.isEmpty) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Select a charge to edit',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            );
          }

          final controller = controllers[selectedChargeType];
          if (controller == null) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Selected charge not found',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            );
          }

          return CustomchargeKeyboardWidgetAll2(
            controller: controller,
            controllerKey: selectedChargeType,
            onClose: () => Navigator.pop(context),
          );
        },
      ),
    );
  }

  /// Build charge dialog buttons
  Widget _buildChargeDialogButtons(VoidCallback onApplyPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.black54),
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          onPressed: onApplyPressed,
          child: const Text(
            "Apply All",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ==================== Main Build Method ====================

  @override
  Widget build(BuildContext context) {
    final selectionProvider = Provider.of<CartSelectionProvider>(context);
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(context);
    final apiService = Provider.of<ApiServiceSalesOrderProvider>(
      context,
      listen: false,
    );

    if (!isStoreTypeSelected && _isDialogShownToday == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isStoreTypeDialogShowing && mounted && !_isDisposed) {
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
        appBar: _buildAppBar(
          context,
          apiService,
          selectionProvider,
          customerScreenProvider,
        ),
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

  @override
  void dispose() {
    _isDisposed = true;

    allBoxQtyController.dispose();
    bulkDiscountController.dispose();
    customChargeFocus.dispose();
    allBoxQtyFocus.dispose();

    for (final controller in boxQtyControllers.values) {
      controller.dispose();
    }
    for (final controller in discountControllers.values) {
      controller.dispose();
    }
    for (final node in discountFocusNodes.values) {
      node.dispose();
    }

    super.dispose();
  }
}

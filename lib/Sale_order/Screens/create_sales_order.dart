import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Screens/salesorder_Customerdetails.dart';
import 'package:yenpos/Sale_order/Widgets/customAll_keyboard.dart';
import 'package:yenpos/Sale_order/Widgets/custom_qty_keyboard.dart';
import 'package:yenpos/Sale_order/Widgets/customcharge_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/disposable_builder.dart';
import 'package:yenpos/Sale_order/Widgets/numeric_Calculator.dart';
import 'package:yenpos/Sale_order/Widgets/printer_dialogue_configuration.dart';
import 'package:yenpos/Sale_order/Widgets/search_drop_filed.dart';
import 'package:yenpos/Sale_order/Widgets/selected_items_dialogue.dart';
import 'package:yenpos/Sale_order/Widgets/storetype_selection_dialogue.dart';
import 'package:yenpos/Sale_order/Widgets/top_message.dart';
import 'package:yenpos/printer_screen/provider/printer_config_provider.dart';

class SalesOrderScreen extends StatefulWidget {
  const SalesOrderScreen({super.key});

  @override
  SalesOrderScreenState createState() => SalesOrderScreenState();
}

class SalesOrderScreenState extends State<SalesOrderScreen> {
  final FocusNode customChargeFocus = FocusNode(); // 👈 new
  bool isStoreTypeDialogShowing = false;
  bool isStoreTypeSelected = false;
  List<bool> itemSelections = []; // List to track selection state of each item
  String selectedStoreType = 'Warehouse';
  bool showCheckBoxes = false; // To control if checkboxes should be shown

  final TextEditingController _allBoxQtyController = TextEditingController();
  final FocusNode _allBoxQtyFocus = FocusNode(); // 👈 new
  final Map<String, TextEditingController> _boxQtyControllers = {};
  final TextEditingController _bulkDiscountController = TextEditingController();
  final Map<String, TextEditingController> _discountControllers = {};
  final Map<String, FocusNode> _discountFocusNodes = {};
  bool _isDialogShownToday = false;
  // Prevent listener loop
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );
    customerProvider.setSelectedCustomCharge("Custom Charges");

    // Use read() instead of watch()
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (globals.cartItems.isEmpty) {
      cartProvider.clearCart();
      globals.cartItems.clear();
      cartProvider.clearCustomCharges();
      cartProvider.updateCart();
      _clearCustomChargeDialogue();
    }
    customerProvider.cartItemCountNotifier = ValueNotifier<int>(
      globals.cartItems.length,
    );
    customerProvider.cartItemsNotifier = ValueNotifier<int>(
      globals.cartItems.length,
    );

    cartProvider.addListener(customerProvider.updateCartCount);
    cartProvider.addListener(customerProvider.updateCartItems);

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
    // Add listener only once
    _allBoxQtyController.addListener(() {
      final value = _allBoxQtyController.text;
      // Make sure to call discount update only if needed
      applySingleItemDiscount("bulk_box_qty", value);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPrinterIpAndAlert();
    });
  }

  // CartProvider-ல் புதிய method
  void updateGiftedItemPrice(CartItem item) {
    if (item.isBoxItem == 'yes' && item.boxQuantity != null) {
      // Recalculate for box items
      double basePrice = 0.0;

      if (item.uom.toLowerCase() == 'kg' || item.uom.toLowerCase() == 'kgs') {
        basePrice = (item.weight * item.boxQuantity! * item.pricePerKg)
            .toDouble();
      } else {
        basePrice = (item.boxQuantity! * item.pricePerKg).toDouble();
      }

      // Store selling amount (before discount) - This is the TOTAL amount
      item.sellingAmount = basePrice;

      // ✅ FIXED: Store selling price (per unit price)
      item.sellingPrice = item.pricePerKg;

      // Apply discount if any
      if (item.itemWiseDiscount != null && item.itemWiseDiscount! > 0) {
        item.itemWiseDiscountAmount =
            basePrice * (item.itemWiseDiscount! / 100);
        item.finalPrice = basePrice - item.itemWiseDiscountAmount!;
      } else {
        item.itemWiseDiscountAmount = 0;
        item.finalPrice = basePrice;
      }
    }
  }

  void applySingleItemDiscount(String key, String value) {
    if (value.isEmpty) {
      setState(() {
        _discountControllers[key]?.text = '';

        final itemIndex = globals.cartItems.indexWhere(
          (item) => item.varianceName == key,
        );

        if (itemIndex != -1) {
          final item = globals.cartItems[itemIndex];

          item.itemWiseDiscount = 0.0;
          item.itemWiseDiscountAmount = 0.0;
          item.finalPrice = null;

          // reset price fields - FIXED: Keep the original pricePerKg

          // Recalculate selling amount based on quantity
          if (item.isBoxItem == 'yes' && item.boxQuantity != null) {
            // For box items
            if (item.uom.toLowerCase() == 'kg' ||
                item.uom.toLowerCase() == 'kgs') {
              item.sellingAmount =
                  (item.weight * item.boxQuantity! * item.pricePerKg)
                      .toDouble();
              item.sellingPrice = item.pricePerKg; // ✅ Store the unit price
            } else {
              item.sellingAmount = (item.boxQuantity! * item.pricePerKg)
                  .toDouble();
              item.sellingPrice = item.pricePerKg; // ✅ Store the unit price
            }
          } else {
            num sellingAmount = (item.uom == 'Kg' || item.uom == 'Kgs')
                ? (item.quantity.value * item.pricePerKg * item.weight)
                : (item.quantity.value * item.pricePerKg);

            item.sellingAmount = sellingAmount
                .toDouble(); // ✅ Convert to double
            item.sellingPrice = item.pricePerKg; // ✅ Store the unit price
          }
        }

        Provider.of<CartProvider>(context, listen: false).updateCart();
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

          // ----------------------------------------------------
          // 🔥 1️⃣ SELLING PRICE BEFORE DISCOUNT (unit price)
          // ----------------------------------------------------
          // ✅ FIXED: Always store the unit price, not calculated amount
          item.sellingPrice = item.pricePerKg;

          // ----------------------------------------------------
          // 🔥 2️⃣ SELLING AMOUNT BEFORE DISCOUNT (full amount)
          // ----------------------------------------------------
          num sellingAmount = 0;

          // Check if it's a box item
          if (item.isBoxItem == 'yes' && item.boxQuantity != null) {
            if (item.uom.toLowerCase() == 'kg' ||
                item.uom.toLowerCase() == 'kgs') {
              sellingAmount =
                  (item.weight * item.boxQuantity! * item.pricePerKg);
            } else {
              sellingAmount = (item.boxQuantity! * item.pricePerKg);
            }
          } else {
            // Regular items
            sellingAmount = (item.uom == 'Kg' || item.uom == 'Kgs')
                ? (item.quantity.value * item.pricePerKg * item.weight)
                : (item.quantity.value * item.pricePerKg);
          }

          item.sellingAmount = sellingAmount.toDouble();

          // ----------------------------------------------------
          // 🔥 3️⃣ DISCOUNT CALCULATION
          // ----------------------------------------------------
          item.itemWiseDiscount = discount;

          double discountAmount = sellingAmount * (discount / 100);
          item.itemWiseDiscountAmount = discountAmount;

          // ----------------------------------------------------
          // 🔥 4️⃣ FINAL PRICE AFTER DISCOUNT
          // ----------------------------------------------------
          item.finalPrice = sellingAmount - discountAmount;
        }

        Provider.of<CartProvider>(context, listen: false).updateCart();
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

  Future<void> _checkPrinterIpAndAlert() async {
    final printerProvider = Provider.of<PrinterProviderpos>(
      context,
      listen: false,
    );

    await printerProvider.initializeHive();

    String? printerIp = printerProvider.getPrinterIpFromHive(type: 'Overall');

    // If IP is already set, do nothing
    if (printerIp != null && printerIp.isNotEmpty) return;

    // Show dialog once
    await showPrinterConfigDialog();

    // After dialog closes, check again
    printerIp = printerProvider.getPrinterIpFromHive(type: 'Overall');

    if (printerIp == null || printerIp.isEmpty) {
      // Give user some time (e.g., 5 seconds) before showing again
      await Future.delayed(const Duration(seconds: 5));

      // Optionally, you can prompt again if needed, but now it's not aggressive
      if (mounted) {
        await _checkPrinterIpAndAlert(); // recursive, but with delay
      }
    }
  }

  double _calculateSelectedItemsTotal(List<CartItem> selectedItems) {
    double total = 0.0;

    for (var item in selectedItems) {
      // 1️⃣ Base amount calculation (discount க்கு முன்)
      double baseAmount = 0.0;

      if (item.isBoxItem == 'yes' &&
          item.boxQuantity != null &&
          item.boxQuantity! > 0) {
        // Box item-க்கு
        int boxQty = item.boxQuantity!;
        if (item.uom?.toLowerCase() == "kg" ||
            item.uom?.toLowerCase() == "kgs") {
          baseAmount = (item.weight ?? 1.0) * boxQty * item.pricePerKg;
        } else {
          baseAmount = boxQty.toDouble() * item.pricePerKg;
        }
      } else {
        // Normal item-க்கு
        if (item.uom?.toLowerCase() == "kg" ||
            item.uom?.toLowerCase() == "kgs") {
          baseAmount =
              (item.weight ?? 1.0) * item.quantity.value * item.pricePerKg;
        } else {
          baseAmount = item.quantity.value.toDouble() * item.pricePerKg;
        }
      }

      // 2️⃣ Discount calculation
      if (item.itemWiseDiscount != null && item.itemWiseDiscount! > 0) {
        double discountAmount = baseAmount * (item.itemWiseDiscount! / 100);
        baseAmount -= discountAmount;
      }

      total += baseAmount;
    }

    return total;
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

  void _applyBulkDiscount(String value) {
    final selectionProvider = Provider.of<CartSelectionProvider>(
      context,
      listen: false,
    );

    if (value.isEmpty) {
      selectionProvider.itemSelectionState.forEach((key, isSelected) {
        if (isSelected) {
          _discountControllers[key]?.value = _discountControllers[key]!.value
              .copyWith(
                text: '',
                selection: const TextSelection.collapsed(offset: 0),
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
      return;
    }

    double? discountPercent = double.tryParse(value);
    if (discountPercent == null || discountPercent < 0) return; // ✅ Safe exit

    selectionProvider.itemSelectionState.forEach((key, isSelected) {
      if (isSelected) {
        final itemIndex = globals.cartItems.indexWhere(
          (item) => item.varianceName == key,
        );
        if (itemIndex != -1) {
          var item = globals.cartItems[itemIndex];
          double originalAmount = (item.uom == 'Kgs' || item.uom == 'Kg')
              ? (item.weight?.toDouble() ?? 0.0) *
                    item.quantity.value.toDouble() *
                    item.pricePerKg.toDouble()
              : item.quantity.value.toDouble() * item.pricePerKg.toDouble();

          double discountAmount = (originalAmount * discountPercent) / 100;
          double finalPrice = originalAmount - discountAmount;

          item.itemWiseDiscount = discountPercent;
          item.itemWiseDiscountAmount = discountAmount;
          item.finalPrice = finalPrice;

          // ✅ Prevent null crash
          String discountText = discountPercent.toString();
          _discountControllers[key]?.value = _discountControllers[key]!.value
              .copyWith(
                text: discountText,
                selection: TextSelection.collapsed(offset: discountText.length),
              );
        }
      }
    });

    Provider.of<CartProvider>(context, listen: false).updateCart();
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
            for (var item in globals.cartItems.where(
              (i) => i.varianceName == key,
            )) {
              item.quantity.value = newQty;
              item.boxQuantity = newQty;
              item.isBoxItem = 'yes';

              double total = 0;
              if (item.uom?.toLowerCase() == "kg" ||
                  item.uom?.toLowerCase() == "kgs") {
                total = item.weight! * item.quantity.value * item.pricePerKg;
              } else {
                total =
                    item.quantity.value.toDouble() * item.pricePerKg.toDouble();
              }

              if (item.itemWiseDiscount != null && item.itemWiseDiscount! > 0) {
                item.itemWiseDiscountAmount =
                    total * (item.itemWiseDiscount! / 100);
                item.finalPrice = total - item.itemWiseDiscountAmount!;
              } else {
                item.finalPrice = total;
                item.itemWiseDiscountAmount = 0;
              }
            }
          }
        });

        if (_bulkDiscountController.text.isNotEmpty) {
          _applyBulkDiscount(_bulkDiscountController.text);
          cartProvider.updateCart();
        }
      });
    }
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ApiServiceSalesOrderProvider apiService,
    CartSelectionProvider selectionProvider,
    CustomerScreenProvider customerScreenProvider,
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
                      Navigator.of(context).pushNamed('/all-orders');
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildCreateOrderButton(selectionProvider),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: Text('Inhouse'),
                  selected: customerScreenProvider.orderType == 'Inhouse',
                  onSelected: (selected) {
                    if (selected)
                      customerScreenProvider.setOrderType('Inhouse');
                  },
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: customerScreenProvider.orderType == 'Inhouse'
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: Text('Warehouse'),
                  selected: customerScreenProvider.orderType == 'Warehouse',
                  onSelected: (selected) {
                    if (selected)
                      customerScreenProvider.setOrderType('Warehouse');
                  },
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: customerScreenProvider.orderType == 'Warehouse'
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ],
            ),
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

  Widget _buildCartDetailsHeader(CartSelectionProvider selectionProvider) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    return ValueListenableBuilder<int>(
      valueListenable: customerProvider.cartItemCountNotifier,
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
                      item.quantity.value = 1;
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
          cartProvider.removeListener(customerProvider.updateCartCount);
          cartProvider.removeListener(customerProvider.updateCartItems);
          cartProvider.updateCart();
          customerProvider.cartItemCountNotifier.dispose();
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
          filled: true,
          fillColor: Colors.blue.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 8.0,
          ),
        ),
        onTap: () {
          ActiveField.activate(
            context: context,
            ctrl: _allBoxQtyController,
            node: _allBoxQtyFocus,
            numeric: true,
            fieldType: "boxQty",
          );
        },
        keyboardType: TextInputType.number,
        onChanged: _applyBulkBoxQtyUpdate,
      ),
    );
  }

  // =================

  Widget _buildCartItemsList(CartSelectionProvider selectionProvider) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    return ValueListenableBuilder<int>(
      valueListenable: customerProvider.cartItemsNotifier,
      builder: (context, _, child) {
        // CRITICAL: Check if cart is empty
        if (globals.cartItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('No items in cart'),
            ),
          );
        }

        final selectedItems = globals.cartItems.where((item) {
          return selectionProvider.itemSelectionState[item.varianceName] ??
              false;
        }).toList();

        final unselectedItems = globals.cartItems.where((item) {
          return !(selectionProvider.itemSelectionState[item.varianceName] ??
              false);
        }).toList();

        // Base amount calculation with safety checks
        double baseAmount = selectedItems.fold(0, (sum, item) {
          try {
            double total = 0;
            if (item.finalPrice != null && item.finalPrice! > 0) {
              total = item.finalPrice!;
            } else if (item.quantity != null && item.quantity.value != null) {
              if (item.uom?.toLowerCase() == "kg" ||
                  item.uom?.toLowerCase() == "kgs") {
                total =
                    (item.weight ?? 0) *
                    (item.quantity.value ?? 0) *
                    (item.pricePerKg ?? 0);
              } else {
                total =
                    (item.quantity.value ?? 0).toDouble() *
                    (item.pricePerKg ?? 0);
              }
            }
            return sum + total;
          } catch (e) {
            return sum;
          }
        });

        // ✅ புதிய method-ஐ use செய்யவும்
        double selectedTotal = _calculateSelectedItemsTotal(selectedItems);

        // Custom charges add செய்யவும்
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        double customCharge = cartProvider.customCharge.value;
        double finalTotal = selectedTotal + customCharge;

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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Selected Gift Items",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: selectionProvider.showCheckBoxes ? 2 : 3,
                          child: Column(
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
                        ),
                        if (selectionProvider.showCheckBoxes)
                          const SizedBox(width: 10),
                        if (selectionProvider.showCheckBoxes) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                if (selectionProvider.showCheckBoxes)
                                  _buildAllBoxQtyField("bulk_box_qty"),
                                const SizedBox(height: 10),
                                _buildBulkDiscountField(),
                                const SizedBox(height: 10),
                                // ✅ புதிய total display
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Total Box Amount: ₹${selectedTotal.round()}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            // UNSELECTED ITEMS
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
          cartProvider.removeListener(customerProvider.updateCartCount);
          cartProvider.updateCart();
          customerProvider.cartItemCountNotifier.dispose();
        },
      ),
    );
  }

  bool _isValidItem(dynamic item) {
    try {
      return item != null &&
          item.varianceName != null &&
          item.varianceName.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // HELPER: Build tile with safety wrapper
  Widget _buildItemTileWrapper({
    required dynamic item,
    required CartProvider cartProvider,
    required CartSelectionProvider selectionProvider,
  }) {
    final key = item.varianceName;

    // Find original index safely
    int originalIndex = -1;
    try {
      originalIndex = globals.cartItems.indexWhere(
        (e) => e.varianceName == item.varianceName,
      );
    } catch (e) {}

    // If not found or invalid, skip this item
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

  Future<bool> _showDeleteConfirmationDialog(
    BuildContext context,
    CartItem item,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 350, // smaller width
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    const Text(
                      'Delete Item',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Content
                    Text(
                      'Do you want to remove "${item.varianceName}" from your cart?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Cancel
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        // Delete
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
  }

  Widget _buildCartItemTile({
    required BuildContext context,
    required CartItem item,
    required String keyValue,
    required int originalIndex,
    required CartProvider cartProvider,
    required CartSelectionProvider selectionProvider,
  }) {
    return Dismissible(
      key: ValueKey(item.rowId), // ✅ stable key
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async =>
          await _showDeleteConfirmationDialog(context, item),
      onDismissed: (_) {
        cartProvider.removeItemByRowId(item.rowId); // remove by stable ID
        final selectionKey = '${item.varianceName}_${item.isBoxItem}';
        selectionProvider.itemSelectionState.remove(selectionKey);
      },
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
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

  // =====================
  // Also update the GestureDetector in _buildCartItemContent:
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
                selectionProvider.toggleItemSelection(key, value ?? false);

                if (value == true) {
                  item.isBoxItem = 'yes';
                  item.itemWiseDiscount = 0.0;
                  item.itemWiseDiscountAmount = 0.0;
                  item.boxQuantity =
                      int.tryParse(_allBoxQtyController.text) ?? 0;
                  _boxQtyControllers[key]?.text = item.boxQuantity.toString();
                  item.quantity.value =
                      int.tryParse(_allBoxQtyController.text) ?? 0;
                } else {
                  item.isBoxItem = 'no';
                  item.itemWiseDiscount = 0.0;
                  item.itemWiseDiscountAmount = 0.0;
                  item.boxQuantity = 1;
                  _boxQtyControllers[key]?.text = '1';
                  _discountControllers[key]?.clear();
                  item.quantity.value = 1;
                }

                setState(() {
                  cartProvider.updateCart();
                });
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
        // Make the entire price description clickable if it's a weight item
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
                  ? Colors
                        .blue // Make weight items blue to indicate they're clickable
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

  void _showWeightCalculator(BuildContext context, CartItem item) {
    showDialog(
      context: context,
      builder: (_) => NumericCalculator(
        varianceName: item.varianceName,
        initialValue: item.weight ?? 1.0,
        onValueSelected: (double newValue) {
          if (mounted) {
            setState(() {
              item.weight = newValue;

              // Recalculate price after weight change
              if (item.quantity != null && item.pricePerKg != null) {
                double total = newValue * item.quantity.value * item.pricePerKg;

                // Reapply discount if exists
                if (item.itemWiseDiscount != null &&
                    item.itemWiseDiscount! > 0) {
                  item.itemWiseDiscountAmount =
                      total * (item.itemWiseDiscount! / 100);
                  item.finalPrice = total - item.itemWiseDiscountAmount!;
                } else {
                  item.finalPrice = total;
                }
              }

              // Update cart
              Provider.of<CartProvider>(context, listen: false).updateCart();
            });
          }
        },
      ),
    );
  }

  String _getItemPriceDescription(dynamic item) {
    String priceDescription;
    if (item.uom == 'Kgs' || item.uom == 'Kg') {
      // Weight mattum blue color la varanum, so separate pannanum
      String weightText = item.weight >= 1
          ? '${item.weight} kg'
          : '${(item.weight * 1000)} grams';

      String priceText = ' × Rs.${item.pricePerKg}/kg';

      // Return a single string, but we'll handle color in the widget
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

  // =====================
  String _formatOverallWeight(double totalWeightKg) {
    if (totalWeightKg >= 1) {
      // If weight is 1 kg or more, show in kg
      if (totalWeightKg % 1 == 0) {
        return 'Total: ${totalWeightKg.toInt()} kg';
      } else {
        return 'Total: ${totalWeightKg.toStringAsFixed(3)} kg';
      }
    } else {
      // If weight is less than 1 kg, show in grams
      double grams = totalWeightKg * 1000;
      if (grams % 1 == 0) {
        return 'Total: ${grams.toInt()} grams';
      } else {
        return 'Total: ${grams.toStringAsFixed(0)} grams';
      }
    }
  }

  Widget _buildItemPriceAndControls({
    required CartItem item,
    required int originalIndex,
    required CartProvider cartProvider,
    required String key,
    required CartSelectionProvider selectionProvider,
  }) {
    final discountPercent = item.itemWiseDiscount ?? 0;
    double total = 0;

    if (item.uom?.toLowerCase() == "kg" || item.uom?.toLowerCase() == "kgs") {
      total =
          item.quantity.value.toDouble() *
          item.pricePerKg.toDouble() *
          (item.weight ?? 1).toDouble();
    } else {
      total = item.quantity.value.toDouble() * item.pricePerKg.toDouble();
    }

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
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 200),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Overall info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.uom == 'Kg' || item.uom == 'Kgs')
                        Text(
                          _formatOverallWeight(
                            item.weight * item.quantity.value,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),

                  // Original price
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
        ),
      ],
    );
  }

  void _updateDiscountController(String key, CartItem item) {
    if (!_discountControllers.containsKey(key)) return;

    final controller = _discountControllers[key]!;

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

  Widget _buildDiscountField(String key, CartItem item) {
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: true,
    );

    // Check both conditions
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

    if (!_discountControllers.containsKey(key)) {
      final controller = TextEditingController();
      if (item.itemWiseDiscount > 0) {
        controller.text = item.itemWiseDiscount.toStringAsFixed(0);
      }
      _discountControllers[key] = controller;
    }

    _updateDiscountController(key, item);

    _discountFocusNodes.putIfAbsent(key, () => FocusNode());

    final ctrl = _discountControllers[key]!;
    final node = _discountFocusNodes[key]!;

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
      print('Setting discount to: $discountValue');
      ctrl.text = discountValue;
      applySingleItemDiscount(key, discountValue);
    }

    _isInternalUpdate = false;
  }

  // =====================
  Widget _buildQuantityControls({
    required int originalIndex,
    required CartProvider cartProvider,
    required String key,
  }) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final item = cartProvider.cartItems[originalIndex];
        final isBoxItem = item.isBoxItem == 'yes'; // convert String? to bool

        return Row(
          children: [
            if (!isBoxItem)
              _buildQuantityButton(
                icon: Icons.remove,
                onPressed: () {
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
                    final ctrl = _discountControllers[key];
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
                  setState(() {
                    cartProvider.updateQuantity(
                      originalIndex,
                      item.quantity.value + 1,
                    );
                    final ctrl = _discountControllers[key];
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
    final customerProvider = Provider.of<CustomerScreenProvider>(
      context,
      listen: false,
    );

    // Calculate correct total
    double calculateCorrectTotal() {
      double total = 0.0;

      // 1️⃣ Normal items (non-gifted) total
      for (var item in globals.cartItems) {
        final isGifted =
            selectionProvider.itemSelectionState[item.varianceName] ?? false;

        if (!isGifted) {
          // Normal item calculation
          if (item.finalPrice != null && item.finalPrice! > 0) {
            total += item.finalPrice!;
          } else {
            double itemTotal = 0.0;
            if (item.uom?.toLowerCase() == "kg" ||
                item.uom?.toLowerCase() == "kgs") {
              itemTotal =
                  (item.weight ?? 1.0) * item.quantity.value * item.pricePerKg;
            } else {
              itemTotal = item.quantity.value.toDouble() * item.pricePerKg;
            }
            total += itemTotal;
          }
        }
      }

      // 2️⃣ Gifted items total (box items)
      final selectedItems = globals.cartItems.where((item) {
        return selectionProvider.itemSelectionState[item.varianceName] ?? false;
      }).toList();

      double giftedTotal = _calculateSelectedItemsTotal(selectedItems);
      total += giftedTotal;

      // 3️⃣ Add custom charges
      total += cartProvider.customCharge.value;

      return total;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          // ---------------------- Custom Charge Button -----------------------
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: () {
                _showCustomChargeDialog(
                  cartProvider,
                  customerProvider,
                  setState,
                );
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
            child: ValueListenableBuilder<double>(
              valueListenable: cartProvider.totalAmount,
              builder: (context, providerTotal, _) {
                // Calculate correct total
                final correctTotal = calculateCorrectTotal();

                // Debug log

                // If mismatch, update the provider
                if ((providerTotal - correctTotal).abs() > 0.01) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // You may need to manually update the provider
                  });
                }

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

  void _showCustomChargeDialog(
    CartProvider cartProvider,
    CustomerScreenProvider customerProvider,
    void Function(void Function()) setState,
  ) {
    // Get controllers from cartProvider instead of creating new ones
    Map<String, TextEditingController> controllers = {};

    // Initialize controllers from cartProvider if they exist, otherwise create new ones
    for (var charge in GlobalDataManager().charges) {
      final chargeType = charge['chargeType'];

      if (cartProvider.customChargeControllers.containsKey(chargeType)) {
        // Use existing controller from cartProvider
        controllers[chargeType] =
            cartProvider.customChargeControllers[chargeType]!;
      } else {
        // Create new controller and add it to cartProvider
        final controller = TextEditingController(
          text: (charge['amount'] ?? 0).toStringAsFixed(0),
        );
        controllers[chargeType] = controller;
        cartProvider.customChargeControllers[chargeType] = controller;
      }
    }

    // Initialize chargeValues map with current values
    Map<String, double> chargeValues = {
      for (var charge in GlobalDataManager().charges)
        charge['chargeType']: (charge['amount'] ?? 0).toDouble(),
    };

    // Track which controllers have been cleared by user selection
    Set<String> clearedControllers = {};

    // Register controllers in keyboard provider
    final keyboardProvider = context.read<CustomchargeKeyboardProvider>();
    controllers.forEach((key, controller) {
      keyboardProvider.registerController(key, controller);
      print(
        'Registered controller for $key with initial value ${controller.text}',
      );
    });

    final mergedControllers = Listenable.merge(controllers.values);

    String selectedChargeType =
        customerProvider.selectedChargeType ??
        (GlobalDataManager().charges.isNotEmpty
            ? GlobalDataManager().charges.first['chargeType']
            : "");
    print('Initial selectedChargeType: $selectedChargeType');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
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
                    // Header
                    AnimatedBuilder(
                      animation: mergedControllers,
                      builder: (context, _) {
                        double totalCustomCharges = controllers.values.fold(
                          0.0,
                          (sum, ctrl) {
                            final value = double.tryParse(ctrl.text) ?? 0.0;
                            return sum + value;
                          },
                        );

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Total Charges: Rs.${totalCustomCharges.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Charge list
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: GlobalDataManager().charges.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.grey.shade300, height: 1),
                        itemBuilder: (context, index) {
                          final charge = GlobalDataManager().charges[index];
                          final controller = controllers[charge['chargeType']]!;
                          final isSelected =
                              selectedChargeType == charge['chargeType'];

                          // Check if this controller should show 0.00 or be empty
                          final shouldShowZero =
                              !clearedControllers.contains(
                                charge['chargeType'],
                              ) &&
                              (controller.text.isEmpty ||
                                  controller.text == '0.00');

                          return GestureDetector(
                            onTap: () {
                              setStateDialog(() {
                                selectedChargeType = charge['chargeType'];
                                customerProvider.selectedChargeType =
                                    selectedChargeType;
                                keyboardProvider.setActiveController(
                                  charge['chargeType'],
                                );

                                // Clear the controller when selecting
                                controller.clear();
                                // Mark this controller as cleared
                                clearedControllers.add(charge['chargeType']);
                                // Update chargeValues
                                chargeValues[charge['chargeType']] = 0.0;

                                print(
                                  'Selected charge: $selectedChargeType, controller cleared',
                                );
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blueAccent.withOpacity(0.5)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    charge['chargeType'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: IgnorePointer(
                                      child: ValueListenableBuilder<TextEditingValue>(
                                        valueListenable: controller,
                                        builder: (context, value, _) {
                                          // Show 0.00 if controller is empty and hasn't been cleared by user
                                          String displayText = value.text;
                                          if (shouldShowZero &&
                                              value.text.isEmpty) {
                                            displayText = '0.00';
                                          }

                                          print(
                                            'Controller ${charge['chargeType']} updated to: ${value.text}, displaying: $displayText',
                                          );

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
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 10,
                                                  ),
                                              filled: true,
                                              fillColor: isSelected
                                                  ? Colors.blue.shade50
                                                  : Colors.grey.withOpacity(
                                                      0.1,
                                                    ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide.none,
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: Colors.blueAccent,
                                                  width: 2,
                                                ),
                                              ),
                                              hintText: shouldShowZero
                                                  ? '0.00'
                                                  : null,
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
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Keyboard
                    Container(
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
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
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
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          }

                          print(
                            'Rendering keyboard for controller: $selectedChargeType, current value: ${controller.text}',
                          );

                          return CustomchargeKeyboardWidgetAll2(
                            controller: controller,
                            controllerKey: selectedChargeType,
                            onClose: () {
                              print('Keyboard closed for $selectedChargeType');
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black54,
                          ),
                          onPressed: () {
                            print('Dialog canceled');
                            Navigator.pop(context);
                          },
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () {
                            print('Apply All pressed');

                            // Update the chargeValues map with current controller values
                            for (var charge in GlobalDataManager().charges) {
                              final chargeType = charge['chargeType'];
                              final controller = controllers[chargeType];
                              if (controller != null) {
                                // If controller is empty but hasn't been cleared by user, use 0.00
                                final textValue =
                                    controller.text.isEmpty &&
                                        !clearedControllers.contains(chargeType)
                                    ? '0.00'
                                    : controller.text;

                                final value = double.tryParse(textValue) ?? 0.0;
                                chargeValues[chargeType] = value;

                                final index = GlobalDataManager().charges
                                    .indexWhere(
                                      (c) => c['chargeType'] == chargeType,
                                    );
                                if (index != -1) {
                                  GlobalDataManager().charges[index]['amount'] =
                                      value;
                                  print('Saved $chargeType with value $value');
                                }
                              }
                            }

                            double totalCustomCharges = chargeValues.values
                                .fold(0.0, (sum, value) => sum + value);

                            print('Total custom charges: $totalCustomCharges');

                            // Store charges in cartProvider
                            setState(() {
                              customerProvider.selectedChargeType =
                                  selectedChargeType;
                              cartProvider.customCharge.value =
                                  totalCustomCharges;

                              // Store individual charge types and values
                              cartProvider.customChargeTypes.clear();
                              cartProvider.customChargeValues.clear();

                              chargeValues.forEach((type, value) {
                                if (value > 0) {
                                  cartProvider.customChargeTypes.add(type);
                                  cartProvider.customChargeValues.add(value);
                                }
                              });

                              // IMPORTANT: Ensure all controllers are in cartProvider
                              for (var entry in controllers.entries) {
                                cartProvider.customChargeControllers[entry
                                        .key] =
                                    entry.value;
                              }
                            });

                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Apply All",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
  }

  void _clearCustomChargeDialogue() {
    // Clear all custom charge controllers
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Clear all controllers
    for (var controller in cartProvider.customChargeControllers.values) {
      controller?.clear();
    }

    // Clear the list of controllers
    cartProvider.customChargeControllers.clear();

    // Reset GlobalDataManager charges
    for (var charge in GlobalDataManager().charges) {
      charge['amount'] = 0.0;
    }

    // Reset custom charge in cart provider
    cartProvider.customCharge.value = 0.0;

    // Clear types and values
    cartProvider.customChargeTypes.clear();
    cartProvider.customChargeValues.clear();
  }

  @override
  Widget build(BuildContext context) {
    // final cartProvider = Provider.of<CartProvider>(context);
    final selectionProvider = Provider.of<CartSelectionProvider>(context);
    final customerScreenProvider = Provider.of<CustomerScreenProvider>(context);

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
    _allBoxQtyController.dispose();
    for (final controller in _boxQtyControllers.values) {
      controller.dispose();
    }
    for (final controller in _discountControllers.values) {
      controller.dispose();
    }
    _bulkDiscountController.dispose();
    super.dispose();

    super.dispose();
  }
}

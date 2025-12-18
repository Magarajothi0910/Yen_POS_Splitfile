import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Provider/bottomNavprovider.dart';
import '../../../kotpreinvoice/providers/bottomNavprovider.dart';
import '../../providers/cartprovider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/product_provider.dart';
import '../settingsScreen.dart';

// 🔔 ChangeNotifier to manage dialog state
class CartItemDialogState extends ChangeNotifier {
  List<String> type;
  List<List<String>> addons;
  List<List<int>> addonQuantities;
  List<String> variants;
  List<bool> toggleRemarks;
  List<String> remarks;

  CartItemDialogState({
    required this.type,
    required this.addons,
    required this.addonQuantities,
    required this.variants,
    required this.toggleRemarks,
    required this.remarks,
  });

  // 🔔 Update type (Parcel checkbox)
  void updateType(int index, bool value) {
    type[index] = value ? "Parcel" : "";
    debugPrint("📦 Type for item $index: ${type[index]}");
    notifyListeners();
  }

  // 🔔 Update add-ons
  void updateAddOn(int index, String addOn, bool add) {
    if (add) {
      addons[index].add(addOn);
    } else {
      addons[index].remove(addOn);
    }
    debugPrint("🍔 Addons for item $index: ${addons[index]}");
    notifyListeners();
  }

  // 🔔 Update variants
  void updateVariant(int index, String variant) {
    variants[index] = variant;
    debugPrint("🔧 Variant for item $index: ${variants[index]}");
    notifyListeners();
  }

  // 🔔 Update toggleRemarks (Switch)
  void updateToggleRemark(int index, bool value) {
    toggleRemarks[index] = value;
    debugPrint("💬 ToggleRemark for item $index: ${toggleRemarks[index]}");
    notifyListeners();
  }

  // 🔔 Update remark
  void updateRemark(int index, String remark) {
    remarks[index] = remark;
    debugPrint("📝 Remark for item $index: ${remarks[index]}");
    notifyListeners();
  }
}

// 🔔 StatefulWidget for the dialog
class CartItemDialog extends StatefulWidget {
  final String productId;
  final dynamic product;
  final int quantity;
  final bool hasAddOns;
  final bool hasVariants;
  final List<String> type;
  final List<List<String>> addons;
  final List<List<int>> addonQuantities;
  final List<String> variants;
  final List<bool> toggleRemarks;
  final List<TextEditingController> remarkControllers;

  const CartItemDialog({
    super.key,
    required this.productId,
    required this.product,
    required this.quantity,
    required this.hasAddOns,
    required this.hasVariants,
    required this.type,
    required this.addons,
    required this.addonQuantities,
    required this.variants,
    required this.toggleRemarks,
    required this.remarkControllers,
  });

  @override
  _CartItemDialogState createState() => _CartItemDialogState();
}

class _CartItemDialogState extends State<CartItemDialog> {
  late CartItemDialogState dialogState;

  @override
  void initState() {
    super.initState();
    // 🔔 Initialize ChangeNotifier
    dialogState = CartItemDialogState(
      type: widget.type,
      addons: widget.addons,
      addonQuantities: widget.addonQuantities,
      variants: widget.variants,
      toggleRemarks: widget.toggleRemarks,
      remarks: widget.remarkControllers.map((c) => c.text).toList(),
    );
  }

  @override
  void dispose() {
    // 🧹 Dispose controllers and ChangeNotifier
    for (var controller in widget.remarkControllers) {
      controller.dispose();
    }
    dialogState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final cartProvider = Provider.of<CartProviderKOT>(context);

    return ChangeNotifierProvider.value(
      value: dialogState,
      child: AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.product.varianceName,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Consumer<CartItemDialogState>(
                builder: (context, dialogState, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(widget.quantity, (i) {
                        String itemName =
                            '  ${i + 1} .   ${widget.product.varianceName} ';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // First Row: Item Name
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
                                  if (!widget.hasAddOns && !widget.hasVariants)
                                    Column(
                                      children: [
                                        Checkbox(
                                          value:
                                              dialogState.type[i] == "Parcel",
                                          onChanged: (value) {
                                            dialogState.updateType(i, value!);
                                          },
                                          activeColor: Colors.blue,
                                          checkColor: Colors.white,
                                          side: const BorderSide(
                                            color: Colors.blue,
                                            width: 1.5,
                                          ),
                                        ),
                                        const Text(
                                          "Parcel",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (!widget.hasAddOns && !widget.hasVariants)
                                    Column(
                                      children: [
                                        Switch(
                                          value: dialogState.toggleRemarks[i],
                                          onChanged: (value) {
                                            dialogState.updateToggleRemark(
                                              i,
                                              value,
                                            );
                                          },
                                          activeColor: Colors.blue,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const Text(
                                          "Remark",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),

                              // Second Row: Add-ons (if present)
                              if (widget.hasAddOns)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          child: DropdownButtonFormField<String>(
                                            decoration: const InputDecoration(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 12,
                                                  ),
                                              hintStyle: TextStyle(
                                                fontSize: 12,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(8.0),
                                                ),
                                                borderSide: BorderSide(
                                                  color: Colors.grey,
                                                  width: 1.0,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(8.0),
                                                ),
                                                borderSide: BorderSide(
                                                  color: Colors.grey,
                                                  width: 1.0,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(8.0),
                                                ),
                                                borderSide: BorderSide(
                                                  color: Colors.blue,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                            isExpanded: true,
                                            hint: Text(
                                              dialogState.addons[i].isEmpty
                                                  ? 'Select Add-ons'
                                                  : "${dialogState.addons[i].length} selected",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            items: productProvider.addons
                                                .map(
                                                  (
                                                    addOn,
                                                  ) => DropdownMenuItem<String>(
                                                    value: addOn['addOn']
                                                        .toString(),
                                                    child: Consumer<CartItemDialogState>(
                                                      builder: (context, dialogState, _) {
                                                        bool
                                                        isSelected = dialogState
                                                            .addons[i]
                                                            .contains(
                                                              addOn['addOn']
                                                                  .toString(),
                                                            );
                                                        return GestureDetector(
                                                          onTap: () {
                                                            dialogState
                                                                .updateAddOn(
                                                                  i,
                                                                  addOn['addOn']
                                                                      .toString(),
                                                                  !isSelected,
                                                                );
                                                          },
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  "${addOn['addOn'].toString()} (₹${addOn['value']})  ",
                                                                  style:
                                                                      const TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                ),
                                                              ),
                                                              Checkbox(
                                                                value:
                                                                    isSelected,
                                                                onChanged: (bool? selected) {
                                                                  dialogState.updateAddOn(
                                                                    i,
                                                                    addOn['addOn']
                                                                        .toString(),
                                                                    selected ??
                                                                        false,
                                                                  );
                                                                },
                                                                activeColor:
                                                                    Colors.blue,
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (_) {},
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Checkbox(
                                          value:
                                              dialogState.type[i] == "Parcel",
                                          onChanged: (value) {
                                            dialogState.updateType(i, value!);
                                          },
                                          activeColor: Colors.blue,
                                          checkColor: Colors.white,
                                          side: const BorderSide(
                                            color: Colors.blue,
                                            width: 1.5,
                                          ),
                                        ),
                                        const Text(
                                          "Parcel",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Switch(
                                          value: dialogState.toggleRemarks[i],
                                          onChanged: (value) {
                                            dialogState.updateToggleRemark(
                                              i,
                                              value,
                                            );
                                          },
                                          activeColor: Colors.blue,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const Text(
                                          "Remark",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                              // Third Row: Variants (if present)
                              if (widget.hasVariants)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: DropdownButtonFormField(
                                        decoration: const InputDecoration(
                                          labelText: 'Variants',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          const DropdownMenuItem(
                                            value: "Default",
                                            child: Text(
                                              "Default",
                                              style: TextStyle(fontSize: 12),
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
                                        },
                                        value: dialogState.variants[i],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Checkbox(
                                          value:
                                              dialogState.type[i] == "Parcel",
                                          onChanged: (value) {
                                            dialogState.updateType(i, value!);
                                          },
                                          activeColor: Colors.blue,
                                          checkColor: Colors.white,
                                          side: const BorderSide(
                                            color: Colors.blue,
                                            width: 1.5,
                                          ),
                                        ),
                                        const Text(
                                          "Parcel",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Switch(
                                          value: dialogState.toggleRemarks[i],
                                          onChanged: (value) {
                                            dialogState.updateToggleRemark(
                                              i,
                                              value,
                                            );
                                          },
                                          activeColor: Colors.blue,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const Text(
                                          "Remark",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                              // Remark TextField
                              if (dialogState.toggleRemarks[i])
                                TextField(
                                  controller: widget.remarkControllers[i],
                                  decoration: const InputDecoration(
                                    labelText: 'Remark',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    dialogState.updateRemark(i, value);
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
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
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
            onPressed: () {
              debugPrint(
                "💾 Before Save - ToggleRemarks: ${dialogState.toggleRemarks}",
              );
              debugPrint("💾 Before Save - Remarks: ${dialogState.remarks}");
              debugPrint("💾 Final Addons: ${dialogState.addons}");
              debugPrint(
                "💾 Final Addons Quantities: ${dialogState.addonQuantities}",
              );
              debugPrint("💾 Final Variants: ${dialogState.variants}");
              debugPrint("💾 Final Types: ${dialogState.type}");

              // Save to CartProvider
              cartProvider.updateCart(
                widget.productId,
                dialogState.addons,
                dialogState.addonQuantities,
                dialogState.variants,
                dialogState.type,
                dialogState.remarks,
                dialogState.toggleRemarks,
              );

              Navigator.of(context).pop();

              debugPrint(
                "💾 Saved ToggleRemarks: ${cartProvider.cart[widget.productId]['toggleRemarks']}",
              );
              debugPrint(
                "💾 Saved Remarks: ${cartProvider.cart[widget.productId]['remarks']}",
              );
            },
          ),
        ],
      ),
    );
  }
}

class CartItems extends StatefulWidget {
  final String tableNumber;
  final String seat;
  final VoidCallback onSubmit;

  const CartItems({
    super.key,
    required this.tableNumber,
    required this.seat,
    required this.onSubmit,
  });

  @override
  _CartItemsState createState() => _CartItemsState();
}

class _CartItemsState extends State<CartItems> {
  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProviderKOT>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final printerProvider = Provider.of<PrinterProviderDine>(context);

    final products = productProvider.products;

    void handleSubmit(BuildContext context, cartProvider, printerProvider) {
      List<String> missingItemIps = [];
      bool hasOverallPrinter = printerProvider.getOverallPrinterIp() != null;

      cartProvider.cart.forEach((productId, cartItem) {
        final itemName = productId;
        final ip = printerProvider.getPrinterIpForItem(itemName);
        if (ip == null) {
          missingItemIps.add(itemName);
        }
      });

      if (!hasOverallPrinter || missingItemIps.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Missing Printer Configuration'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasOverallPrinter)
                  const Text('Please set an overall printer IP address.'),
                if (missingItemIps.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Missing IP for the following items:'),
                        ...missingItemIps
                            .map((item) => Text('- $item'))
                            .toList(),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.green[200],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Set IP'),
                onPressed: () {
                  Provider.of<BottomNavProvider>(
                    context,
                    listen: false,
                  ).updateIndex(5);
                  Navigator.pop(context);

                  // Navigator.pushAndRemoveUntil(
                  //   context,
                  //   MaterialPageRoute(builder: (context) => const settingsScreen()),
                  //   (Route<dynamic> route) => false,
                  // );
                },
              ),
            ],
          ),
        );
      } else {
        widget.onSubmit();
      }
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      color: const Color(0xFFF4FDFF),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Shrink-wrap the Column
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Static header
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFA5D6A7),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    handleSubmit(context, cartProvider, printerProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[900],
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Cart: (${cartProvider.cart.length} Items)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
                Builder(
                  builder: (context) {
                    double totalAmount = 0.0;
                    cartProvider.cart.forEach((productId, cartItem) {
                      final product = products.firstWhere(
                        (product) => product.varianceName == productId,
                      );
                      final quantity = cartItem['qty'];
                      final weight = cartItem['weight'];
                      final price = product.price;
                      final isWeight =
                          product.variance_Uom.toLowerCase() == "kg" ||
                          product.variance_Uom.toLowerCase() == "Kgs";

                      if (isWeight) {
                        totalAmount += (price * (weight / 1000)) * quantity;
                      } else {
                        totalAmount += price * quantity;
                      }
                    });

                    return Text(
                      'Total: ₹${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Scrollable cart items
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 200, // Limit height to ~3-5 items (adjust as needed)
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: ListView.builder(
                  shrinkWrap: true, // Shrink-wrap the ListView
                  physics:
                      const NeverScrollableScrollPhysics(), // Disable ListView scrolling
                  reverse: true,
                  itemCount: cartProvider.cart.length,
                  itemBuilder: (context, index) {
                    final productId = cartProvider.cart.keys.toList()[index];
                    final product = products.firstWhere(
                      (product) => product.varianceName == productId,
                    );
                    final quantity = cartProvider.cart[productId]['qty'];
                    final hasAddOns = productProvider.hasAddOns(
                      product.varianceName,
                    );
                    final hasVariants = productProvider.hasVariants(
                      product.varianceName,
                    );
                    final weight = cartProvider.cart[productId]['weight'];

                    final isWeight =
                        product.variance_Uom.toLowerCase() == "kg" ||
                        product.variance_Uom.toLowerCase() == "Kgs";
                    List<List<String>> addons = List.generate(
                      quantity,
                      (i) => List.from(
                        cartProvider.cart[productId]['addons'] != null &&
                                cartProvider.cart[productId]['addons'].length >
                                    i
                            ? cartProvider.cart[productId]['addons'][i]
                            : [],
                      ),
                    );

                    List<List<int>> addonQuantities = List.generate(
                      quantity,
                      (i) => List.from(
                        cartProvider.cart[productId]['addonQuantities'] !=
                                    null &&
                                cartProvider
                                        .cart[productId]['addonQuantities']
                                        .length >
                                    i
                            ? cartProvider.cart[productId]['addonQuantities'][i]
                            : [],
                      ),
                    );

                    List<String> variants = List.generate(
                      quantity,
                      (i) =>
                          cartProvider.cart[productId]['variants'] != null &&
                              cartProvider.cart[productId]['variants'].length >
                                  i
                          ? cartProvider.cart[productId]['variants'][i]
                          : "Default",
                    );

                    List<String> type = List.generate(
                      quantity,
                      (i) =>
                          cartProvider.cart[productId]['type'] != null &&
                              cartProvider.cart[productId]['type'].length > i
                          ? cartProvider.cart[productId]['type'][i]
                          : "",
                    );

                    cartProvider.syncConfigWithQuantity(productId, quantity);

                    List<bool> toggleRemarks = cartProvider.getToggleRemarks(
                      productId,
                      quantity,
                    );
                    List<TextEditingController> remarkControllers =
                        List.generate(
                          quantity,
                          (i) => TextEditingController(
                            text: cartProvider.getRemarks(
                              productId,
                              quantity,
                            )[i],
                          ),
                        );

                    return Dismissible(
                      key: Key(productId),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        cartProvider.removeFromCart(
                          context,
                          productId,
                          widget.tableNumber,
                          widget.seat,
                        );
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        title: GestureDetector(
                          onTap: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              cartProvider.syncConfigWithQuantity(
                                productId,
                                quantity,
                              );
                            });

                            showDialog(
                              context: context,
                              builder: (context) => CartItemDialog(
                                productId: productId,
                                product: product,
                                quantity: quantity,
                                hasAddOns: hasAddOns,
                                hasVariants: hasVariants,
                                type: type,
                                addons: addons,
                                addonQuantities: addonQuantities,
                                variants: variants,
                                toggleRemarks: toggleRemarks,
                                remarkControllers: remarkControllers,
                              ),
                            );
                          },
                          child: Text(
                            "${product.varianceName} \n ₹${product.price} ${isWeight ? '/ ${weight}g' : ''}",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.remove,
                                  color: Colors.red[600],
                                  size: 20,
                                ),
                                onPressed: () {
                                  cartProvider.removeItemFromCart(
                                    context,
                                    product.varianceName,
                                    widget.tableNumber,
                                    widget.seat,
                                  );
                                  cartProvider.syncConfigWithQuantity(
                                    productId,
                                    quantity - 1,
                                  );
                                },
                              ),
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                child: Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add,
                                  color: Colors.green[600],
                                  size: 20,
                                ),
                                onPressed: () {
                                  cartProvider.addToCart(product.varianceName);
                                  cartProvider.syncConfigWithQuantity(
                                    productId,
                                    quantity + 1,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

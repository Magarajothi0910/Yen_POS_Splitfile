import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kotproviders/cartprovider.dart';
import '../../kotproviders/printer_provider.dart';
import '../../kotproviders/product_provider.dart';
import '../settingsScreen.dart';

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
    final cartProvider = Provider.of<CartProviderkot>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final printerProvider = Provider.of<PrinterProvider>(context);

    final products = productProvider.products;
    Map<String, bool> selectedAddOns = {};
    void handleSubmit(BuildContext context, cartProvider, printerProvider) {
      List<String> missingItemIps = [];
      bool hasOverallPrinter = printerProvider.getOverallPrinterIp() != null;

      // Check each item in the cart
      cartProvider.cart.forEach((productId, cartItem) {
        final itemName = productId; // Assuming productId is the item name
        final ip = printerProvider.getPrinterIpForItem(itemName);
        if (ip == null) {
          missingItemIps.add(itemName);
        }
      });

      // Display dialog if IP addresses are missing
      if (!hasOverallPrinter || missingItemIps.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
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
                  backgroundColor: Colors.green[200],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Set IP'),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const settingsScreen()),
                    (Route<dynamic> route) =>
                        false, // Removes all previous routes
                  );
                },
              ),
            ],
          ),
        );
      } else {
        // Proceed with submission logic if no issues
        widget.onSubmit();
      }
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      color: const Color(0xFFF4FDFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFA5D6A7),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    handleSubmit(context, cartProvider, printerProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[900],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
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
                      fontWeight: FontWeight.bold, color: Colors.black),
                ),
                Builder(
                  builder: (context) {
                    double totalAmount = 0.0;
                    cartProvider.cart.forEach((productId, cartItem) {
                      final product = products.firstWhere(
                          (product) => product.varianceName == productId);
                      final quantity = cartItem['qty'];
                      final weight = cartItem['weight'];
                      final price = product.price;
                      final isWeight =
                          product.variance_Uom.toLowerCase() == "kg" ||
                              product.variance_Uom.toLowerCase() == "kgs";

                      if (isWeight) {
                        totalAmount += (price * (weight / 1000)) * quantity;
                      } else {
                        totalAmount += price * quantity;
                      }
                    });

                    return Text(
                      'Total: ₹${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              reverse: true,
              itemCount: cartProvider.cart.length,
              itemBuilder: (context, index) {
                final productId = cartProvider.cart.keys.toList()[index];
                final product = products
                    .firstWhere((product) => product.varianceName == productId);
                final quantity = cartProvider.cart[productId]['qty'];
                final hasAddOns =
                    productProvider.hasAddOns(product.varianceName);
                final hasVariants =
                    productProvider.hasVariants(product.varianceName);
                final weight = cartProvider.cart[productId]['weight'];

                final isWeight = product.variance_Uom.toLowerCase() == "kg" ||
                    product.variance_Uom.toLowerCase() == "kgs";
                List<List<String>> addons = List.generate(
                    quantity,
                    (i) => List.from(cartProvider.cart[productId]['addons'] !=
                                null &&
                            cartProvider.cart[productId]['addons'].length > i
                        ? cartProvider.cart[productId]['addons'][i]
                        : []));

                List<String> variants = List.generate(
                    quantity,
                    (i) => cartProvider.cart[productId]['variants'] != null &&
                            cartProvider.cart[productId]['variants'].length > i
                        ? cartProvider.cart[productId]['variants'][i]
                        : "Default");

                List<String> type = List.generate(
                    quantity,
                    (i) => cartProvider.cart[productId]['type'] != null &&
                            cartProvider.cart[productId]['type'].length > i
                        ? cartProvider.cart[productId]['type'][i]
                        : "");
                cartProvider.syncConfigWithQuantity(productId, quantity);

// Initialize states after syncing
                List<bool> toggleRemarks =
                    cartProvider.getToggleRemarks(productId, quantity);
                List<TextEditingController> remarkControllers = List.generate(
                  quantity,
                  (i) => TextEditingController(
                    text: cartProvider.getRemarks(productId, quantity)[i],
                  ),
                );

                Map<String, dynamic> config = {
                  "configQty": List.generate(quantity, (i) => 1),
                  "addOn": addons,
                  "variance": variants,
                  "type": type,
                  "remarks": toggleRemarks
                };

                // Debugging config structure
                return Dismissible(
                  key: Key(productId),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    cartProvider.removeFromCart(
                        context, productId, widget.tableNumber, widget.seat);
                    // Reset hint flag when clearing the cart
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  child: ListTile(
                    title: GestureDetector(
                      onTap: () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          cartProvider.syncConfigWithQuantity(
                              productId, quantity);
                        });

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                    MediaQuery.of(context).size.height * 0.7,
                              ),
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ...List.generate(quantity, (i) {
                                        String itemName =
                                            '  ${i + 1} .   ${product.varianceName} ';

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 1.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // First Row: Item Name
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      itemName,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (!hasAddOns &&
                                                      !hasVariants)
                                                    Column(
                                                      children: [
                                                        StatefulBuilder(
                                                          builder: (context,
                                                              setStateInner) {
                                                            return Checkbox(
                                                              value: type[i] ==
                                                                  "Parcel",
                                                              onChanged:
                                                                  (value) {
                                                                type[i] = value!
                                                                    ? "Parcel"
                                                                    : "";
                                                                // Debugging output
                                                                setStateInner(
                                                                    () {}); // Update state
                                                              },
                                                              activeColor: Colors
                                                                  .teal, // For active color
                                                              checkColor: Colors
                                                                  .white, // For tick mark color inside checkbox
                                                              side: const BorderSide(
                                                                  color: Colors
                                                                      .teal,
                                                                  width:
                                                                      1.5), // Border color
                                                            );
                                                          },
                                                        ),
                                                        const Text("Parcel",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .teal)),
                                                      ],
                                                    ),
                                                  if (!hasAddOns &&
                                                      !hasVariants)
                                                    Column(
                                                      children: [
                                                        if (toggleRemarks
                                                                .length >
                                                            i)
                                                          Switch(
                                                            value:
                                                                toggleRemarks[
                                                                    i],
                                                            onChanged: (value) {
                                                              toggleRemarks[i] =
                                                                  value;
                                                              (context
                                                                      as Element)
                                                                  .markNeedsBuild();
                                                            },
                                                            activeColor: Colors
                                                                .teal, // For active color
                                                            materialTapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap, // Reduced size
                                                          ),
                                                        const Text("Remark",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .teal))
                                                      ],
                                                    ),
                                                ],
                                              ),

                                              // Second Row: Add-ons (if present)
                                              if (hasAddOns)
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Column(
                                                      children: [
                                                        SizedBox(
                                                          width: 120,
                                                          child:
                                                              StatefulBuilder(
                                                            builder: (context,
                                                                setStateInner) {
                                                              return DropdownButtonFormField<
                                                                  String>(
                                                                decoration:
                                                                    const InputDecoration(
                                                                  contentPadding:
                                                                      EdgeInsets.symmetric(
                                                                          vertical:
                                                                              8,
                                                                          horizontal:
                                                                              12),
                                                                  hintStyle:
                                                                      TextStyle(
                                                                          fontSize:
                                                                              12),
                                                                  border:
                                                                      OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.all(
                                                                            Radius.circular(8.0)),
                                                                    borderSide: BorderSide(
                                                                        color: Colors
                                                                            .grey,
                                                                        width:
                                                                            1.0),
                                                                  ),
                                                                  enabledBorder:
                                                                      OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.all(
                                                                            Radius.circular(8.0)),
                                                                    borderSide: BorderSide(
                                                                        color: Colors
                                                                            .grey,
                                                                        width:
                                                                            1.0),
                                                                  ),
                                                                  focusedBorder:
                                                                      OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.all(
                                                                            Radius.circular(8.0)),
                                                                    borderSide: BorderSide(
                                                                        color: Colors
                                                                            .teal,
                                                                        width:
                                                                            1.5),
                                                                  ),
                                                                ),
                                                                isExpanded:
                                                                    true,
                                                                hint: Text(
                                                                  addons[i]
                                                                          .isEmpty
                                                                      ? 'Select Add-ons'
                                                                      : "${addons[i].length} selected",
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                          .teal),
                                                                ),
                                                                items: productProvider
                                                                    .addons
                                                                    .map((addOn) =>
                                                                        DropdownMenuItem<
                                                                            String>(
                                                                          value:
                                                                              addOn['addOn'].toString(),
                                                                          child:
                                                                              StatefulBuilder(
                                                                            builder:
                                                                                (context, setStateCheckbox) {
                                                                              bool isSelected = addons[i].contains(addOn['addOn'].toString());
                                                                              return GestureDetector(
                                                                                onTap: () {
                                                                                  setStateInner(() {
                                                                                    if (isSelected) {
                                                                                      addons[i].remove(addOn['addOn'].toString());
                                                                                    } else {
                                                                                      addons[i].add(addOn['addOn'].toString());
                                                                                    }
                                                                                  });
                                                                                  setStateCheckbox(() {}); // Force rebuild checkbox
                                                                                },
                                                                                child: Row(
                                                                                  children: [
                                                                                    Expanded(
                                                                                      child: Text(
                                                                                        "${addOn['addOn'].toString()} (₹${addOn['value']})  ",
                                                                                        style: const TextStyle(fontSize: 12),
                                                                                      ),
                                                                                    ),
                                                                                    Checkbox(
                                                                                      value: isSelected,
                                                                                      onChanged: (bool? selected) {
                                                                                        setStateInner(() {
                                                                                          if (selected == true) {
                                                                                            addons[i].add(addOn['addOn'].toString());
                                                                                          } else {
                                                                                            addons[i].remove(addOn['addOn'].toString());
                                                                                          }
                                                                                        });
                                                                                        setStateCheckbox(() {}); // Refresh checkbox UI
                                                                                      },
                                                                                      activeColor: Colors.teal,
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              );
                                                                            },
                                                                          ),
                                                                        ))
                                                                    .toList(),
                                                                onChanged:
                                                                    (_) {},
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Column(
                                                      children: [
                                                        StatefulBuilder(
                                                          builder: (context,
                                                              setStateInner) {
                                                            return Checkbox(
                                                              value: type[i] ==
                                                                  "Parcel",
                                                              onChanged:
                                                                  (value) {
                                                                type[i] = value!
                                                                    ? "Parcel"
                                                                    : "";
                                                                // Debugging output
                                                                setStateInner(
                                                                    () {}); // Update local state
                                                              },
                                                              activeColor: Colors
                                                                  .teal, // For active color
                                                              checkColor: Colors
                                                                  .white, // For tick mark color inside checkbox
                                                              side: const BorderSide(
                                                                  color: Colors
                                                                      .teal,
                                                                  width:
                                                                      1.5), // Border color
                                                            );
                                                          },
                                                        ),
                                                        const Text("Parcel",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .teal)),
                                                      ],
                                                    ),
                                                    Column(
                                                      children: [
                                                        if (toggleRemarks
                                                                .length >
                                                            i)
                                                          Switch(
                                                            value:
                                                                toggleRemarks[
                                                                    i],
                                                            onChanged: (value) {
                                                              toggleRemarks[i] =
                                                                  value;
                                                              (context
                                                                      as Element)
                                                                  .markNeedsBuild();
                                                            },
                                                            activeColor: Colors
                                                                .teal, // For active color
                                                            materialTapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap, // Reduced size
                                                          ),
                                                        const Text("Remark",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .teal))
                                                      ],
                                                    ),
                                                  ],
                                                ),

                                              // Third Row: Variants (if present) with Parcel Checkbox
                                              if (hasVariants)
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  children: [
                                                    Flexible(
                                                      child: StatefulBuilder(
                                                        builder: (context,
                                                            setStateInner) {
                                                          return DropdownButtonFormField(
                                                            decoration:
                                                                const InputDecoration(
                                                              labelText:
                                                                  'Variants',
                                                              border:
                                                                  OutlineInputBorder(),
                                                            ),
                                                            items: [
                                                              const DropdownMenuItem(
                                                                value:
                                                                    "Default",
                                                                child: Text(
                                                                    "Default",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            12)),
                                                              ),
                                                              ...productProvider
                                                                  .variants
                                                                  .map((v) =>
                                                                      DropdownMenuItem(
                                                                        value: v[
                                                                            'variant'],
                                                                        child: Text(
                                                                            v['variant'],
                                                                            style: const TextStyle(fontSize: 12)),
                                                                      ))
                                                                  .toList(),
                                                            ],
                                                            onChanged: (value) {
                                                              variants[i] = value
                                                                  .toString();
                                                              // Debugging output
                                                              setStateInner(
                                                                  () {});
                                                            },
                                                            value: variants[
                                                                i], // Default to 'No Variant'
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    Column(
                                                      children: [
                                                        StatefulBuilder(
                                                          builder: (context,
                                                              setStateInner) {
                                                            return Checkbox(
                                                              value: type[i] ==
                                                                  "Parcel",
                                                              onChanged:
                                                                  (value) {
                                                                type[i] = value!
                                                                    ? "Parcel"
                                                                    : "";
                                                                // Debugging output
                                                                setStateInner(
                                                                    () {}); // Update state
                                                              },
                                                              activeColor: Colors
                                                                  .teal, // For active color
                                                              checkColor: Colors
                                                                  .white, // For tick mark color inside checkbox
                                                              side: const BorderSide(
                                                                  color: Colors
                                                                      .teal,
                                                                  width:
                                                                      1.5), // Border color
                                                            );
                                                          },
                                                        ),
                                                        const Text("Parcel",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .teal)),
                                                      ],
                                                    ),
                                                    Column(
                                                      children: [
                                                        if (toggleRemarks
                                                                .length >
                                                            i)
                                                          Switch(
                                                            value:
                                                                toggleRemarks[
                                                                    i],
                                                            onChanged: (value) {
                                                              toggleRemarks[i] =
                                                                  value;
                                                              (context
                                                                      as Element)
                                                                  .markNeedsBuild();
                                                            },
                                                            activeColor: Colors
                                                                .teal, // For active color
                                                            materialTapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap, // Reduced size
                                                          ),
                                                        const Text("Remark",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .teal))
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              if (toggleRemarks[i])
                                                TextField(
                                                  controller:
                                                      remarkControllers[i],
                                                  decoration:
                                                      const InputDecoration(
                                                    labelText: 'Remark',
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
                                style: ElevatedButton.styleFrom(
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
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('OK'),
                                onPressed: () {

                                  List<String> remarks = remarkControllers
                                      .map((c) => c.text)
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
                      child: Text(
                        "${product.varianceName} \n ₹${product.price} ${isWeight ? '/ ${weight}g' : ''}",
                        style: const TextStyle(
                          fontSize: 13,
                        ),
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
                                  widget.seat);
                              cartProvider.syncConfigWithQuantity(
                                  productId, quantity - 1); // Sync state
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
                                  productId, quantity + 1); // Sync state
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

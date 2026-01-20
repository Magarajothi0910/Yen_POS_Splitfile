import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';
import 'package:yenpos/Global/Widget/glassmorphisom.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Mode_page/Regular_mode/Provider/regular_mode_screen_provider.dart';
import 'package:yenpos/Sale_order/Widgets/numeric_Calculator.dart';
import 'package:yenpos/regular_mode_page/widget/custom_reusable_widget/quantity_dialog.dart';
import 'package:yenpos/regular_mode_page/widget/custom_reusable_widget/scafflodMesseger.dart';

import '../../more_page/providers/bt_provide2.dart';
import '../model/variance.dart';
import '../provider/cart_page_provider.dart';
import '../provider/quantity_provider.dart';

void disposeLargeObjects(BuildContext context) {
  selectedVariances.clear();
  Provider.of<QuantityProvider>(context, listen: false).setQuantity(1);
}

String weight2 = "";
Map<String, bool> selectedVariances = {};

final ScrollController _scrollController = ScrollController();

dynamic deepCastMap(dynamic value) {
  if (value is Map) {
    final Map<String, dynamic> newMap = {};
    value.forEach((key, val) {
      newMap[key.toString()] = deepCastMap(val);
    });
    return newMap;
  }

  if (value is List) {
    return value.map((item) => deepCastMap(item)).toList();
  }

  return value;
}

Future<Map<String, dynamic>?> loadItemFromHive(
  String itemName,
  String branchAlias,
) async {
  final lazyBox = await Hive.openBox('items');
  final raw = await lazyBox.get('branchwiseItems_$branchAlias');

  if (raw == null) return null;

  final data = deepCastMap(raw)['data'] as Map<String, dynamic>;

  if (!data.containsKey(itemName)) return null;

  return deepCastMap(data[itemName]) as Map<String, dynamic>;
}

void showVarianceDialog(
  BuildContext context,
  List<Variance> variances,
  String itemName,
) {
  // -----------------------------------------------------------------
  // 1. Initialise the selection map (outside the builder – runs once)
  // -----------------------------------------------------------------
  for (Variance variance in variances) {
    if (!selectedVariances.containsKey(variance.varianceName)) {
      selectedVariances[variance.varianceName] = false;
    }
  }

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) {
          return AlertDialog(
            alignment: Alignment.centerLeft,
            backgroundColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            content: GlassMorphism(
              blur: 10.0,
              opacity: 0.2,
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ------------------- Header -------------------
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            itemName,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.8),
                              fontFamily: "Poppins",
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          // Expanded(
                          //   flex: 2,
                          //   child: Text(itemName, style: const TextStyle(color: Colors.black, fontSize: 30)),
                          // ),
                          // IconButton(
                          //   onPressed: () {
                          //     Navigator.of(context).pop();
                          //     // disposeLargeObjects(context);
                          //   },
                          //   icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          // ),
                        ],
                      ),
                    ),
                    const Divider(thickness: 1, color: Colors.black26),

                    // ------------------- Grid -------------------
                    SizedBox(
                      height: 400,
                      width: 700,
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        thickness: 8,
                        radius: Radius.circular(10),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 4,
                              ),
                          itemCount: variances.length,
                          itemBuilder: (context, index) {
                            final variance = variances[index];
                            final provider = Provider.of<RegularModeProvider>(
                              context,
                              listen: false,
                            );
                            final varianceData = provider.getVarianceDetails(
                              variance.varianceName,
                            );
                            final varianceUOM =
                                provider.getUOMForVariance(
                                  variance.varianceName,
                                ) ??
                                'Unknown UOM';

                            // -------------------------------------------------
                            // Helper: add to cart with quantity = 1
                            // -------------------------------------------------
                            Future<void> _addDirectlyToCart() async {
                              // final itemData = GlobalDataManager()
                              //     .branchwiseItems['data']?[itemName];
                              // final varianceDataFromMap =
                              //     itemData?['variance']?[variance.varianceName];
                              final itemData = await loadItemFromHive(
                                itemName,
                                aliasname,
                              );
                              if (itemData == null) return;

                              final cleanItem =
                                  deepCastMap(itemData) as Map<String, dynamic>;
                              final varianceDataFromMap =
                                  cleanItem['variance'][variance.varianceName];

                              final String itemId =
                                  "${itemName}_${variance.varianceName}";

                              final Map<String, dynamic> newItem = {
                                'itemData': {
                                  ...itemData['item'],
                                  'itemId': itemId,
                                },
                                'varianceData': varianceDataFromMap,
                                'quantity': 1.0,
                                'totalPrice':
                                    1.0 * variance.varianceDefaultPrice,
                                'id': itemId,
                                'itemName': itemName,
                              };

                              final processed = _processCartItem(newItem);
                              await Provider.of<CurrentSaleProvider>(
                                context,
                                listen: false,
                              ).addItemToCart(processed);
                              disposeLargeObjects(context);
                              Navigator.of(context).pop(); // close dialog
                            }

                            return GestureDetector(
                              onTap: () async {
                                // ---- 1. Update selection UI ----
                                setState(() {
                                  selectedVariances.updateAll(
                                    (key, value) => false,
                                  );
                                  selectedVariances[variance.varianceName] =
                                      !selectedVariances[variance
                                          .varianceName]!;
                                });

                                // ---- 2. If NOT selected → do nothing ----
                                if (!selectedVariances[variance
                                    .varianceName]!) {
                                  return;
                                }

                                // ---- 3. Determine UOM (once) ----
                                // final String varianceUOM = GlobalDataManager()
                                //     .branchwiseItems['data']
                                //     .entries
                                //     .firstWhere(
                                //       (entry) =>
                                //           entry.value['variance'] != null &&
                                //           entry.value['variance'].values.any(
                                //             (v) =>
                                //                 v['varianceName'] ==
                                //                 variance.varianceName,
                                //           ),
                                //       orElse: () =>
                                //           MapEntry('', {'variance': {}}),
                                //     )
                                //     .value['variance']
                                //     .entries
                                //     .firstWhere(
                                //       (v) =>
                                //           v.value['varianceName'] ==
                                //           variance.varianceName,
                                //       orElse: () =>
                                //           MapEntry('', {'variance_Uom': 'Pcs'}),
                                //     )
                                //     .value['variance_Uom'];
                                final itemData = await loadItemFromHive(
                                  itemName,
                                  aliasname,
                                );
                                if (itemData == null) return;

                                final cleanItem =
                                    deepCastMap(itemData)
                                        as Map<String, dynamic>;
                                final varianceDataFromMap =
                                    cleanItem['variance'][variance
                                        .varianceName];

                                final varianceUOM =
                                    varianceDataFromMap['variance_Uom'] ??
                                    'Pcs';

                                // -------------------------------------------------
                                // 4. **KG / KGS** → always show weight dialog
                                // -------------------------------------------------
                                if (varianceUOM.toLowerCase() == 'kg' ||
                                    varianceUOM.toLowerCase() == 'kgs') {
                                  showWeightDialog(
                                    context,
                                    itemName,
                                    variance.varianceName,
                                    variance.varianceDefaultPrice,
                                    onWeightSelected: (weight) {
                                      Navigator.of(
                                        context,
                                      ).pop(); // close variance dialog
                                    },
                                  );
                                  return;
                                }

                                // -------------------------------------------------
                                // 5. **NON-KG** – decide based on flag
                                // -------------------------------------------------
                                if (isCartEnabled) {
                                  // ---- Direct add (qty = 1) ----
                                  await _addDirectlyToCart();
                                } else {
                                  // ---- Show quantity picker dialog ----
                                  showCommonQuantityDialog(
                                    context: context,
                                    itemName: itemName,
                                    varianceName: variance.varianceName,
                                    price: variance.varianceDefaultPrice,
                                    initialQuantity: 1.0,
                                    onAddToCart: (quantity) async {
                                      final itemData = await loadItemFromHive(
                                        itemName,
                                        aliasname,
                                      );
                                      if (itemData == null) return;

                                      final cleanItem =
                                          deepCastMap(itemData)
                                              as Map<String, dynamic>;
                                      final varianceDataFromMap =
                                          cleanItem['variance'][variance
                                              .varianceName];

                                      // final itemData = GlobalDataManager()
                                      //     .branchwiseItems['data']?[itemName];
                                      // final varianceDataFromMap =
                                      //     itemData?['variance']?[variance
                                      //         .varianceName];

                                      final String itemId =
                                          "${itemName}_${variance.varianceName}";

                                      final Map<String, dynamic> newItem = {
                                        'itemData': {
                                          ...itemData['item'],
                                          'itemId': itemId,
                                        },
                                        'varianceData': varianceDataFromMap,
                                        'quantity': quantity,
                                        'totalPrice':
                                            quantity *
                                            variance.varianceDefaultPrice,
                                        'id': itemId,
                                        'itemName': itemName,
                                      };

                                      final processed = _processCartItem(
                                        newItem,
                                      );
                                      await Provider.of<CurrentSaleProvider>(
                                        context,
                                        listen: false,
                                      ).addItemToCart(processed);
                                      disposeLargeObjects(context);
                                      Navigator.of(context).pop();
                                    },
                                  );
                                }
                              },
                              child: buildVarianceTile(
                                variance,
                                deepCastMap(varianceData)
                                    as Map<String, dynamic>, // FIXED
                                varianceUOM,
                                itemName,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// Widget buildVarianceTile(
//   Variance variance,
//   Map<String, dynamic> varianceData,
//   String varianceUOM,
//   String itemName,
// ) {
//   // bool isSelected = selectedVariances[variance.varianceName] ?? false;
//   //final stock = (varianceData['branchwise']?[aliasname]?['systemStock_$aliasname'] as num?)?.toDouble() ?? 0.0;

//   return Consumer<GlobalDataManager>(
//     builder: (context, globalManager, child) {
//       bool isSelected = selectedVariances[variance.varianceName] ?? false;
//       final stock =
//           (varianceData['branchwise']?[aliasname]?['systemStock_$aliasname']
//                   as num?)
//               ?.toDouble() ??
//           0.0;

//       //bool isSelected = selectedVariances[variance.varianceName] ?? false;
//       return RepaintBoundary(
//         child: Container(
//           margin: const EdgeInsets.all(8),
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
//           decoration: BoxDecoration(
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 spreadRadius: 2,
//                 blurRadius: 8,
//                 offset: Offset(0, 4), // changes shadow position
//               ),
//             ],

//             color: isSelected
//                 ? CustomColors.blueColor
//                 : CustomColors.whiteColor,

//             border: Border.all(
//               color: isSelected
//                   ? CustomColors.blueColor
//                   : CustomColors.whiteColor,
//             ),
//           ),
//           alignment: Alignment.centerLeft,
//           child: Column(
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: CustomText(
//                       text: variance.varianceName,

//                       fontWeight: FontWeight.bold,
//                       style: TextStyle(
//                         fontFamily: "Poppins",
//                         fontSize: 14,
//                         color: isSelected
//                             ? CustomColors.whiteColor
//                             : CustomColors.black.withOpacity(0.7),
//                       ),
//                     ),
//                   ),
//                   CustomText(
//                     text: '₹ ${variance.varianceDefaultPrice}',
//                     style: TextStyle(
//                       fontFamily: "Poppins",
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                       color: isSelected
//                           ? CustomColors.whiteColor
//                           : CustomColors.black.withOpacity(0.7),
//                     ),
//                   ),
//                 ],
//               ),
//               Row(
//                 children: [
//                   CustomText(
//                     text: 'Stock: $stock',
//                     style: TextStyle(
//                       fontFamily: "Poppins",
//                       fontSize: 12,
//                       color: isSelected
//                           ? CustomColors.whiteColor
//                           : CustomColors.black,
//                     ),
//                   ),
//                   SizedBox(width: 5),
//                   CustomText(
//                     text: '$varianceUOM',
//                     style: TextStyle(
//                       fontFamily: "Poppins",
//                       fontSize: 12,
//                       color: isSelected
//                           ? CustomColors.whiteColor
//                           : CustomColors.black,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       );
//     },
//   );
// }
Widget buildVarianceTile(
  Variance variance,
  Map<String, dynamic> varianceData,
  String varianceUOM,
  String itemName,
) {
  final String varianceName = variance.varianceName;

  return Consumer<GlobalDataManager>(
    // key: ValueKey('stock_${aliasname}_$varianceName'), // THIS IS THE MAGIC
    builder: (context, globalManager, child) {
      final bool isSelected = selectedVariances[varianceName] ?? false;

      // LIVE STOCK USING NAME
      final double liveStock = globalManager.getSystemStock(
        aliasname,
        varianceName,
      );

      double displayStock = liveStock >= 0
          ? liveStock
          : (varianceData['branchwise']?[aliasname]?['systemStock_$aliasname']
                        as num?)
                    ?.toDouble() ??
                0.0;

      print(
        "REBUILDING TILE → $varianceName = $displayStock",
      ); // You WILL see this in log

      return RepaintBoundary(
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 8,
                offset: Offset(0, 4), // changes shadow position
              ),
            ],

            color: isSelected
                ? CustomColors.blueColor
                : CustomColors.whiteColor,

            border: Border.all(
              color: isSelected
                  ? CustomColors.blueColor
                  : CustomColors.whiteColor,
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: CustomText(
                      text: variance.varianceName,

                      fontWeight: FontWeight.bold,
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 14,
                        color: isSelected
                            ? CustomColors.whiteColor
                            : CustomColors.black.withOpacity(0.7),
                      ),
                    ),
                  ),
                  CustomText(
                    text: '₹ ${variance.varianceDefaultPrice}',
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? CustomColors.whiteColor
                          : CustomColors.black.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  CustomText(
                    text:
                        //'Stock: ${displayStock.toStringAsFixed(displayStock.truncateToDouble() == displayStock ? 0 : 1)}',
                        'Stock: ${displayStock.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 12,
                      color: isSelected
                          ? CustomColors.whiteColor
                          : CustomColors.black,
                    ),
                  ),
                  SizedBox(width: 5),
                  CustomText(
                    text: '$varianceUOM',
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 12,
                      color: isSelected
                          ? CustomColors.whiteColor
                          : CustomColors.black,
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
}

void showWeightDialog(
  BuildContext context,
  String itemName,
  String varianceName,
  double price, {
  Function(double)? onWeightSelected,
}) {
  final bluetoothProvider2 = Provider.of<BluetoothProvider2>(
    context,
    listen: false,
  );

  if (!bluetoothProvider2.isConnected) {
    // Show NumericCalculator if Bluetooth is not connected
    showDialog(
      context: context,
      builder: (context) {
        bool isAdding = false; // Flag to prevent multiple additions

        return NumericCalculator(
          varianceName: varianceName,
          onValueSelected: (weight) async {
            if (isAdding) return; // Prevent multiple calls
            if (weight > 0) {
              // FIRST: Validate stock before adding
              final lazyBox = await Hive.openBox('items');
              final branchData = await lazyBox.get(
                'branchwiseItems_$aliasname',
              );
              final itemData = branchData?['data']?[itemName];

              if (itemData == null ||
                  itemData['variance'] == null ||
                  itemData['variance'][varianceName] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Item or variance data not found."),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              final varianceData = itemData['variance'][varianceName];
              final double systemStock =
                  (varianceData['branchwise']?[aliasname]?['systemStock_$aliasname']
                          as num?)
                      ?.toDouble() ??
                  0.0;

              // Validate stock for weight items
              if (weight > systemStock) {
                showAutoDismissMessage(
                  context,
                  "Selected weight (${weight.toStringAsFixed(3)} kg) exceeds available stock (${systemStock.toStringAsFixed(3)} kg)",
                  backgroundColor: Color.fromARGB(255, 231, 63, 61),
                );
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text(
                //       "Selected weight (${weight.toStringAsFixed(3)} kg) exceeds available stock (${systemStock.toStringAsFixed(3)} kg).",
                //     ),
                //     backgroundColor: Colors.red,
                //     duration: const Duration(seconds: 2),
                //   ),
                // );
                return;
              }

              isAdding = true;
              await _addWeightItemToCart(
                context,
                itemName,
                varianceName,
                price,
                weight,
                onWeightSelected,
              );
              Provider.of<CurrentSaleProvider>(
                context,
                listen: false,
              ).loadCartItems();
              disposeLargeObjects(context);
              // Navigator.of(context).pop(); // Close numeric calculator
              isAdding = false;
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Invalid weight. Please enter a valid weight."),
                ),
              );
            }
          },
        );
      },
    );
    return;
  }

  // Show Bluetooth weight dialog if connected
  showDialog(
    context: context,
    builder: (BuildContext context) {
      bool isAdding = false; // Flag to prevent multiple additions

      return AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: CustomColors.whiteColor,
        title: CustomText(
          text: varianceName,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Consumer<BluetoothProvider2>(
          builder: (context, bluetoothProvider2, child) {
            double weight = bluetoothProvider2.weight;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weight <= 0
                      ? "Waiting for weight..."
                      : "Weight: ${weight.toStringAsFixed(3)} kg",
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 24),
                ),
                if (weight <= 0) const CircularProgressIndicator(),
              ],
            );
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close only weight dialog
            },
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', color: CustomColors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (isAdding) return; // Prevent multiple clicks

              double weight = Provider.of<BluetoothProvider2>(
                context,
                listen: false,
              ).weight;

              if (weight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Invalid weight. Please wait for a valid weight reading.",
                    ),
                  ),
                );
                return;
              }

              // ADD STOCK VALIDATION FOR BLUETOOTH TOO
              final lazyBox = await Hive.openBox('items');
              final branchData = await lazyBox.get(
                'branchwiseItems_$aliasname',
              );
              final itemData = branchData?['data']?[itemName];

              if (itemData == null ||
                  itemData['variance'] == null ||
                  itemData['variance'][varianceName] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Item or variance data not found."),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              final varianceData = itemData['variance'][varianceName];
              final double systemStock =
                  (varianceData['branchwise']?[aliasname]?['systemStock_$aliasname']
                          as num?)
                      ?.toDouble() ??
                  0.0;

              // Validate stock for weight items
              if (weight > systemStock) {
                showAutoDismissMessage(
                  context,
                  "Selected weight (${weight.toStringAsFixed(3)} kg) exceeds available stock (${systemStock.toStringAsFixed(3)} kg)",
                  backgroundColor: Color.fromARGB(255, 231, 63, 61),
                );
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text(
                //       "Selected weight (${weight.toStringAsFixed(3)} kg) exceeds available stock (${systemStock.toStringAsFixed(3)} kg).",
                //     ),
                //     backgroundColor: Colors.red,
                //     duration: const Duration(seconds: 2),
                //   ),
                // );
                return;
              }

              isAdding = true;
              await _addWeightItemToCart(
                context,
                itemName,
                varianceName,
                price,
                weight,
                onWeightSelected,
              );

              Navigator.of(context).pop(); // Close only weight dialog
              isAdding = false;
            },
            style: ButtonStyle(
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              backgroundColor: WidgetStateProperty.all(CustomColors.blueColor),
            ),
            child: const CustomText(
              text: 'Add',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: CustomColors.whiteColor,
              ),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _addWeightItemToCart(
  BuildContext context,
  String itemName,
  String varianceName,
  double price,
  double weight,
  Function(double)? onWeightSelected,
) async {
  try {
    //final itemData = GlobalDataManager().branchwiseItems['data']?[itemName];
    final lazyBox = await Hive.openBox('items');
    final branchData = await lazyBox.get('branchwiseItems_$aliasname');
    final itemData = branchData?['data']?[itemName];

    if (itemData == null ||
        itemData['variance'] == null ||
        itemData['variance'][varianceName] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Item or variance data not found."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final varianceData = itemData['variance'][varianceName];
    double totalPrice = price * weight;

    print(
      "DEBUG: _addWeightItemToCart - Adding item: $itemName, Variance: $varianceName, Weight: $weight, TotalPrice: $totalPrice",
    );

    // Create item with proper type safety
    Map<String, dynamic> newItem = {
      'itemData': {
        ...itemData['item'],
        'itemId':
            itemData['item']['itemId']?.toString() ??
            itemData['item']['hsnCode']?.toString(),
        'itemName': itemName,
        'item_Uom': varianceData['variance_Uom']?.toString() ?? 'Kgs',
      },
      'varianceData': {
        ...varianceData,
        'varianceName': varianceName,
        'variance_Defaultprice': price is String
            ? double.tryParse(price as String) ?? 0.0
            : price,
        'variance_Uom': varianceData['variance_Uom']?.toString() ?? 'Kgs',
      },
      'itemName': itemName,
      'uom': varianceData['variance_Uom']?.toString() ?? 'Kgs',
      'quantity': weight,
      'weight': weight,
      'totalPrice': totalPrice,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'tax':
          (itemData['item']['tax'] is String
              ? double.tryParse(itemData['item']['tax'])
              : (itemData['item']['tax'] as num?)?.toDouble()) ??
          0.0,
      'itemWiseDiscountAmount': 0.0,
      'itemWiseDiscount': 0.0,
      'isBoxItem': 'no',
    };

    // Process the item to ensure proper types
    final processedItem = _processCartItem(newItem);

    await Provider.of<CurrentSaleProvider>(
      context,
      listen: false,
    ).addItemToCart(processedItem);

    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(
    //       "Added $varianceName (${weight.toStringAsFixed(3)} kg) to cart",
    //     ),
    //   ),
    // );

    if (onWeightSelected != null) {
      onWeightSelected(weight);
    }
  } catch (e) {
    print("DEBUG: _addWeightItemToCart - Error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error adding to cart: $e"),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

void showQuantityDialog(
  BuildContext context,
  String itemName,
  String varianceName,
  double price,
  Function(double) onAddToCart,
) {
  double quantity = 1.0;
  final TextEditingController _controller = TextEditingController(
    text: quantity.toInt().toString(),
  );

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext dialogContext, StateSetter setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            backgroundColor: CustomColors.whiteColor,
            title: Text(
              "$varianceName - ₹${price.toStringAsFixed(2)}",
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 40,
                      onPressed: () {
                        if (quantity > 1) {
                          setState(() {
                            quantity--;
                            _controller.text = quantity.toInt().toString();
                          });
                        }
                      },
                      icon: const Icon(
                        Icons.remove_circle,
                        color: CustomColors.blueColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      shadowColor: CustomColors.black,
                      elevation: 4,
                      color: CustomColors.whiteColor,
                      child: SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          onChanged: (value) {
                            if (value.isEmpty) {
                              setState(() {
                                quantity = 1.0;
                                _controller.text = '1';
                              });
                            } else {
                              final int? newValue = int.tryParse(value);
                              if (newValue != null && newValue > 0) {
                                setState(() {
                                  quantity = newValue.toDouble();
                                });
                              } else {
                                setState(() {
                                  quantity = 1.0;
                                  _controller.text = '1';
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      iconSize: 40,
                      onPressed: () {
                        setState(() {
                          quantity++;
                          _controller.text = quantity.toInt().toString();
                        });
                      },
                      icon: const Icon(
                        Icons.add_circle,
                        color: CustomColors.blueColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: CustomColors.grey.withOpacity(0.1),
                  foregroundColor: CustomColors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  //disposeLargeObjects(context);
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  "Cancel",
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (quantity <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid quantity.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // Validate stock
                  // final itemData =
                  //     GlobalDataManager().branchwiseItems['data']?[itemName];
                  final lazyBox = await Hive.openBox('items');
                  final branchData = await lazyBox.get(
                    'branchwiseItems_$aliasname',
                  );
                  final itemData = branchData?['data']?[itemName];
                  if (itemData == null ||
                      itemData['variance'] == null ||
                      itemData['variance'][varianceName] == null) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Item or variance data not found for $varianceName.",
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  final varianceData = itemData['variance'][varianceName];
                  final double systemStock =
                      (varianceData['branchwise']?[aliasname]?['systemStock_$aliasname']
                              as num?)
                          ?.toDouble() ??
                      0.0;
                  print(
                    "DEBUG: showQuantityDialog - Selected quantity: $quantity, System stock: $systemStock",
                  );

                  if (quantity > systemStock) {
                    showAutoDismissMessage(
                      context,
                      "Selected quantity ($quantity) exceeds available stock ($systemStock)",
                      backgroundColor:Color.fromARGB(255, 231, 63, 61),
                    );
                    // ScaffoldMessenger.of(dialogContext).showSnackBar(
                    //   SnackBar(
                    //     content: Text(
                    //       "Selected quantity ($quantity) exceeds available stock ($systemStock).",
                    //     ),
                    //     backgroundColor: Colors.red,
                    //     duration: const Duration(seconds: 2),
                    //   ),
                    // );
                    // return;
                  }

                  // Calculate total price
                  double totalPrice = quantity * price;

                  // Add item to cart with proper type conversion
                  Map<String, dynamic> newItem = {
                    'itemData': {
                      ...itemData['item'],
                      'itemId':
                          itemData['item']['itemId']?.toString() ??
                          itemData['item']['hsnCode']?.toString(),
                    },
                    'varianceData': varianceData,
                    'quantity': quantity,
                    'totalPrice': totalPrice,
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  };
                  print(
                    "DEBUG: showQuantityDialog - Adding item: $itemName, Variance: $varianceName, Quantity: $quantity, TotalPrice: $totalPrice",
                  );

                  try {
                    // Ensure all numeric values are properly typed
                    final processedItem = _processCartItem(newItem);

                    final currentSaleProvider =
                        Provider.of<CurrentSaleProvider>(
                          dialogContext,
                          listen: false,
                        );
                    await currentSaleProvider.addItemToCart(processedItem);
                    await currentSaleProvider.loadCartItems();

                    final quantityProvider = Provider.of<QuantityProvider>(
                      dialogContext,
                      listen: false,
                    );
                    quantityProvider.setQuantity(quantity.toInt());

                    onAddToCart(quantity);
                    disposeLargeObjects(context);
                    Navigator.of(dialogContext).pop();
                  } catch (e) {
                    print(
                      "DEBUG: showQuantityDialog - Error accessing providers: $e",
                    );
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text("Error adding item to cart: $e"),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: CustomColors.blueColor.withOpacity(0.1),
                  foregroundColor: CustomColors.whiteColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Add to Cart',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

// Helper function to ensure proper data types
Map<String, dynamic> _processCartItem(Map<String, dynamic> item) {
  // Ensure quantity and totalPrice are doubles
  if (item['quantity'] is String) {
    item['quantity'] = double.tryParse(item['quantity']) ?? 1.0;
  }

  if (item['totalPrice'] is String) {
    item['totalPrice'] = double.tryParse(item['totalPrice']) ?? 0.0;
  }

  // Ensure all numeric fields in itemData are proper types
  if (item['itemData'] is Map) {
    final itemData = Map<String, dynamic>.from(item['itemData']);
    _convertNumericFields(itemData);
    item['itemData'] = itemData;
  }

  // Ensure all numeric fields in varianceData are proper types
  if (item['varianceData'] is Map) {
    final varianceData = Map<String, dynamic>.from(item['varianceData']);
    _convertNumericFields(varianceData);
    item['varianceData'] = varianceData;
  }

  return item;
}

void _convertNumericFields(Map<String, dynamic> data) {
  data.forEach((key, value) {
    if (value is String) {
      // Try to convert string to double if it's numeric
      final numericValue = double.tryParse(value);
      if (numericValue != null) {
        data[key] = numericValue;
      }
    } else if (value is Map) {
      _convertNumericFields(Map<String, dynamic>.from(value));
    }
  });
}

void showWeightDialogformixed(
  BuildContext context,
  String itemName,
  String varianceName,
  double price, {
  required Function(double) onWeightSelected,
}) {
  final bluetoothProvider2 = Provider.of<BluetoothProvider2>(
    context,
    listen: false,
  );

  if (!bluetoothProvider2.isConnected) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Bluetooth Not Connected"),
          content: const Text(
            "Please connect to a Bluetooth device to proceed.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
    return;
  }
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: CustomColors.whiteColor,
        title: Text(
          varianceName,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Consumer<BluetoothProvider2>(
          builder: (context, bluetoothProvider2, child) {
            double weight = bluetoothProvider2.weight;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Weight: ${weight.toStringAsFixed(2)} kg",
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 24),
                ),
              ],
            );
          },
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () async {
              double weight = Provider.of<BluetoothProvider2>(
                context,
                listen: false,
              ).weight;
              if (weight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Invalid weight. Please wait for a valid weight reading.",
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
                return;
              }
              // Validate stock
              // final itemData =
              //     GlobalDataManager().branchwiseItems['data']?[itemName];
              final lazyBox = await Hive.openBox('items');
              final branchData = await lazyBox.get(
                'branchwiseItems_$aliasname',
              );
              final itemData = branchData?['data']?[itemName];
              if (itemData == null ||
                  itemData['variance'] == null ||
                  itemData['variance'][varianceName] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Item or variance data not found for $varianceName.",
                    ),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 1),
                  ),
                );
                return;
              }
              final varianceData = itemData['variance'][varianceName];
              final double systemStock =
                  (varianceData['branchwise']?['${aliasname}']?['systemStock_${aliasname}']
                          as num?)
                      ?.toDouble() ??
                  0.0;
              if (weight > systemStock) {
                showAutoDismissMessage(
                  context,
                  "Selected weight ($weight kg) exceeds available stock ($systemStock kg).",
                  backgroundColor:Color.fromARGB(255, 231, 63, 61),
                );
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text(
                //       "Selected weight ($weight kg) exceeds available stock ($systemStock kg).",
                //     ),
                //     backgroundColor: Colors.red,
                //     duration: Duration(seconds: 1),
                //   ),
                // );
                return;
              }
              double totalPrice = price * weight;
              onWeightSelected(weight);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              backgroundColor: CustomColors.blueColor,
            ),
            child: const Text(
              'Add',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: CustomColors.whiteColor,
              ),
            ),
          ),
        ],
      );
    },
  );
}

void showWeightDialogforVariances(
  BuildContext context,
  String itemName,
  String varianceName,
  double price, {
  required Function(double) onWeightSelected,
}) {
  final bluetoothProvider2 = Provider.of<BluetoothProvider2>(
    context,
    listen: false,
  );

  if (!bluetoothProvider2.isConnected) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Bluetooth Not Connected"),
          content: const Text(
            "Please connect to a Bluetooth device to proceed.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
    return;
  }
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: CustomColors.whiteColor,
        title: Text(
          varianceName,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Consumer<BluetoothProvider2>(
          builder: (context, bluetoothProvider2, child) {
            double weight = bluetoothProvider2.weight;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Weight: ${weight.toStringAsFixed(2)} kg",
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 24),
                ),
              ],
            );
          },
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () async {
              double weight = Provider.of<BluetoothProvider2>(
                context,
                listen: false,
              ).weight;
              if (weight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Invalid weight. Please wait for a valid weight reading.",
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
                return;
              }
              // Validate stock
              // final itemData =
              //     GlobalDataManager().branchwiseItems['data']?[itemName];
              final lazyBox = await Hive.openBox('items');
              final branchData = await lazyBox.get(
                'branchwiseItems_$aliasname',
              );
              final itemData = branchData?['data']?[itemName];
              if (itemData == null ||
                  itemData['variance'] == null ||
                  itemData['variance'][varianceName] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Item or variance data not found for $varianceName.",
                    ),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 1),
                  ),
                );
                return;
              }
              final varianceData = itemData['variance'][varianceName];
              final double systemStock =
                  (varianceData['branchwise']?['${aliasname}']?['systemStock_${aliasname}']
                          as num?)
                      ?.toDouble() ??
                  0.0;
              if (weight > systemStock) {
                showAutoDismissMessage(
                  context,
                  "Selected weight ($weight kg) exceeds available stock ($systemStock kg).",
                  backgroundColor: Color.fromARGB(255, 231, 63, 61),
                );
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text(
                //       "Selected weight ($weight kg) exceeds available stock ($systemStock kg).",
                //     ),
                //     backgroundColor: CustomColors.redColor,
                //     duration: Duration(seconds: 1),
                //   ),
                // );
                return;
              }
              double totalPrice = price * weight;
              onWeightSelected(weight);
              disposeLargeObjects(context);
              //                                         Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              backgroundColor: CustomColors.blueColor,
            ),
            child: const Text(
              'Add',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    },
  );
}

// void showVarianceDialog(BuildContext context, List<Variance> variances, String itemName) {
//   showDialog(
//     context: context,
//     builder: (BuildContext context) {
//       for (Variance variance in variances) {
//         if (!selectedVariances.containsKey(variance.varianceName)) {
//           selectedVariances[variance.varianceName] = false;
//         }
//       }

//       return StatefulBuilder(
//         builder: (BuildContext context, StateSetter setState) {
//           return AlertDialog(
//             alignment: Alignment.centerLeft,
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
//             content: GlassMorphism(
//               blur: 10.0,
//               opacity: 0.2,
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12.0),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Expanded(
//                             flex: 2,
//                             child: Text(itemName, style: const TextStyle(color: Colors.black, fontSize: 30)),
//                           ),
//                           IconButton(
//                             onPressed: () {
//                               disposeLargeObjects(context);
//                               Navigator.of(context).pop();
//                             },
//                             icon: const Icon(Icons.close, color: Colors.black, size: 30),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Divider(thickness: 1, color: Colors.black26),
//                     SizedBox(
//                       height: 400,
//                       width: 700,
//                       child: GridView.builder(
//                         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 4),
//                         itemCount: variances.length,
//                         itemBuilder: (context, index) {
//                           final variance = variances[index];
//                           final provider = Provider.of<RegularModeProvider>(context, listen: false);
//                           final varianceData = provider.getVarianceDetails(variance.varianceName);
//                           final varianceUOM = provider.getUOMForVariance(variance.varianceName) ?? 'Unknown UOM';
//                           return GestureDetector(
//                             onTap: () async {
//                               setState(() {
//                                 selectedVariances.updateAll((key, value) => false);
//                                 selectedVariances[variance.varianceName] = !selectedVariances[variance.varianceName]!;
//                               });

//                               if (selectedVariances[variance.varianceName]!) {
//                                 final varianceUOM = GlobalDataManager().branchwiseItems['data'].entries
//                                     .firstWhere(
//                                       (entry) =>
//                                           entry.value['variance'] != null &&
//                                           entry.value['variance'].values.any((v) => v['varianceName'] == variance.varianceName),
//                                       orElse: () => MapEntry('', {'variance': {}}),
//                                     )
//                                     .value['variance']
//                                     .entries
//                                     .firstWhere(
//                                       (v) => v.value['varianceName'] == variance.varianceName,
//                                       orElse: () => MapEntry('', {'variance_Uom': 'Pcs'}),
//                                     )
//                                     .value['variance_Uom'];

//                                 if (varianceUOM.toLowerCase() == 'kg' || varianceUOM.toLowerCase() == 'kgs') {
//                                   showWeightDialog(
//                                     context,
//                                     itemName,
//                                     variance.varianceName,
//                                     variance.varianceDefaultPrice,
//                                     onWeightSelected: (weight) {
//                                       Navigator.of(context).pop(); // Close variance dialog
//                                     },
//                                   );
//                                 } else {
//                                   // Inside showVarianceDialog → GridView → onTap

//                                   if (varianceUOM.toLowerCase() != 'kg' && varianceUOM.toLowerCase() != 'kgs') {
//                                     showCommonQuantityDialog(
//                                       context: context,
//                                       itemName: itemName,
//                                       varianceName: variance.varianceName,
//                                       price: variance.varianceDefaultPrice,
//                                       initialQuantity: 1.0,
//                                       onAddToCart: (quantity) async {
//                                         final itemData = GlobalDataManager().branchwiseItems['data']?[itemName];
//                                         final varianceData = itemData?['variance']?[variance.varianceName];

//                                         // ✅ Use same consistent ID
//                                         final String itemId = "${itemName}_${variance.varianceName}";

//                                         final Map<String, dynamic> newItem = {
//                                           'itemData': {...itemData['item'], 'itemId': itemId},
//                                           'varianceData': varianceData,
//                                           'quantity': quantity,
//                                           'totalPrice': quantity * variance.varianceDefaultPrice,
//                                           'id': itemId, // Optional: can keep same key name
//                                           'itemName': itemName,
//                                         };

//                                         final processed = _processCartItem(newItem);
//                                         await Provider.of<CurrentSaleProvider>(context, listen: false).addItemToCart(processed);
//                                         disposeLargeObjects(context);
//                                         Navigator.of(context).pop();
//                                       },
//                                     );
//                                   }
//                                 }
//                               }
//                             },
//                             child: buildVarianceTile(variance, varianceData, varianceUOM),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       );
//     },
//   );
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yen_pos/Global/Widget/custom_colors.dart';
import 'package:yen_pos/Global/Widget/custom_textWidgets.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/regular_mode_page/widget/search_drop_filed.dart';
import 'provider/cart_page_provider.dart';
import 'provider/regular_mode_screen_provider.dart';
import 'widget/current_sale_section.dart';
import 'widget/favoritePage_widget.dart';
import 'widget/mixedBox_page_widget.dart';
import 'widget/my_grid_view.dart';

// class RegularModeScreen extends StatefulWidget {
//   const RegularModeScreen({super.key});

//   @override
//   State<RegularModeScreen> createState() => _RegularModeScreenState();
// }

// class _RegularModeScreenState extends State<RegularModeScreen> {
//   final FocusNode _focusNode = FocusNode();
//   final TextEditingController _textController = TextEditingController();
//   bool _isProcessing = false;

//   @override
//   void initState() {
//     super.initState();
//     Future.delayed(Duration(milliseconds: 300), () {
//       _focusNode.requestFocus();
//     });
//   }

//   @override
//   void dispose() {
//     _focusNode.dispose();
//     _textController.dispose();
//     super.dispose();
//   }

//   double parseNum(dynamic value) {
//     if (value is num) return value.toDouble();
//     if (value is String) return double.tryParse(value) ?? 0.0;
//     return 0.0;
//   }

//   Map<String, dynamic> _parseScannedData(String value) {
//     try {
//       return json.decode(value);
//     } catch (_) {
//       final Map<String, dynamic> parsed = {};
//       value.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
//         final kv = pair.split(':');
//         if (kv.length == 2) parsed[kv[0].trim()] = kv[1].trim();
//       });
//       return parsed;
//     }
//   }

//   void _handleInput(String value) async {
//     if (_isProcessing || value.isEmpty) return;

//     setState(() => _isProcessing = true);

//     try {
//       final Map<String, dynamic> scannedData = _parseScannedData(value);

//       if (scannedData.containsKey('ItemCode')) {
//         final itemCode = scannedData['ItemCode'];
//         final quantity = scannedData['Qty'] ?? 1;
//         final uom = scannedData['UOM'] ?? '';

//         final itemProvider = Provider.of<ItemProvider>(context, listen: false);
//         final result = itemProvider.checkVarianceItemCode(itemCode);

//         if (result.isNotEmpty) {
//           final saleProvider = Provider.of<CurrentSaleProvider>(
//             context,
//             listen: false,
//           );

//           final itemData = result.first;

//           // ─────────────────────────────────────────
//           // ⭐ STOCK VALIDATION (ADDED HERE)
//           // ─────────────────────────────────────────
//           final stock = parseNum(
//             itemData["varianceData"]["variance_Stock"] ?? 0,
//           );

//           final scannedQty = parseNum(quantity);

//           if (stock <= 0) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 backgroundColor: Colors.red,
//                 content: Text(
//                   "Out of Stock: ${itemData['varianceData']['varianceName']}",
//                   style: const TextStyle(color: Colors.white),
//                 ),
//               ),
//             );
//             return;
//           }

//           if (scannedQty > stock) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 backgroundColor: Colors.orange,
//                 content: Text(
//                   "Only $stock available, but scanned qty = $scannedQty",
//                   style: const TextStyle(color: Colors.white),
//                 ),
//               ),
//             );
//             return;
//           }
//           // ─────────────────────────────────────────

//           // Add to cart if valid
//           saleProvider.addItemToCart({
//             ...itemData,
//             'quantity': scannedQty,
//             'uom': uom,
//             'varianceData': {
//               ...itemData['varianceData'],
//               'variance_Defaultprice': parseNum(
//                 itemData['varianceData']['variance_Defaultprice'],
//               ),
//             },
//           });

//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               backgroundColor: CustomColors.blueColor,
//               content: Text(
//                 "Item added: ${itemData['varianceData']['varianceName']}",
//                 style: const TextStyle(color: Colors.white),
//               ),
//               duration: const Duration(milliseconds: 800),
//             ),
//           );
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Item not found for scanned code."),
//               duration: Duration(milliseconds: 800),
//             ),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Invalid QR/barcode data."),
//             duration: Duration(milliseconds: 800),
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error: $e")));
//     } finally {
//       _textController.clear();
//       Future.delayed(const Duration(milliseconds: 200), () {
//         _focusNode.requestFocus();
//       });
//       setState(() => _isProcessing = false);
//     }
//   }

//   String toTitleCase(String text) {
//     if (text.isEmpty) return text;
//     return text[0].toUpperCase() + text.substring(1).toLowerCase();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) => RegularModeProvider(),
//       child: MaterialApp(
//         debugShowCheckedModeBanner: false,
//         home: SafeArea(
//           child: Scaffold(
//             backgroundColor: Colors.white,
//             body: Stack(
//               children: [
//                 Consumer<RegularModeProvider>(
//                   builder: (context, provider, child) {
//                     return Column(
//                       children: [
//                         Expanded(
//                           child: Row(
//                             children: [
//                               Expanded(
//                                 flex: 2,
//                                 child: Column(
//                                   children: [
//                                     Padding(
//                                       padding: const EdgeInsets.all(8.0),
//                                       child: Row(
//                                         children: [
//                                           Expanded(child: SearchDropdown()),
//                                           const SizedBox(width: 10),
//                                           Expanded(
//                                             flex: 3,
//                                             child: SingleChildScrollView(
//                                               controller:
//                                                   provider.scrollController,
//                                               scrollDirection: Axis.horizontal,
//                                               child: Row(
//                                                 children: [
//                                                   TextButton(
//                                                     onPressed: () {
//                                                       provider.setFavorite(
//                                                         true,
//                                                       );
//                                                     },
//                                                     child: Text(
//                                                       "Favorite",
//                                                       style: TextStyle(
//                                                         fontFamily: 'Poppins',
//                                                         fontSize: 18,
//                                                         color: CustomColors
//                                                             .blueColor,
//                                                         fontWeight:
//                                                             FontWeight.bold,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                   TextButton(
//                                                     onPressed: () {
//                                                       provider.setMixed(
//                                                         true,
//                                                       ); // Set Mixed as selected
//                                                     },
//                                                     child: Text(
//                                                       "Mixed",
//                                                       style: TextStyle(
//                                                         fontFamily: 'Poppins',
//                                                         fontSize: 18,
//                                                         color: CustomColors
//                                                             .blueColor,
//                                                         fontWeight:
//                                                             FontWeight.bold,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                   ...provider.categories.map((
//                                                     category,
//                                                   ) {
//                                                     return TextButton(
//                                                       onPressed: () {
//                                                         provider
//                                                             .filterItemsByCategory(
//                                                               category,
//                                                             );
//                                                       },
//                                                       style: ButtonStyle(
//                                                         shape: const WidgetStatePropertyAll(
//                                                           RoundedRectangleBorder(
//                                                             borderRadius:
//                                                                 BorderRadius.all(
//                                                                   Radius.circular(
//                                                                     5,
//                                                                   ),
//                                                                 ),
//                                                           ),
//                                                         ),
//                                                         backgroundColor:
//                                                             WidgetStateProperty.resolveWith<
//                                                               Color
//                                                             >((
//                                                               Set<WidgetState>
//                                                               states,
//                                                             ) {
//                                                               return category ==
//                                                                       provider
//                                                                           .selectedCategory
//                                                                   ? CustomColors
//                                                                         .blueColor
//                                                                   : CustomColors
//                                                                         .whiteColor;
//                                                             }),
//                                                         foregroundColor:
//                                                             WidgetStateProperty.resolveWith<
//                                                               Color
//                                                             >((
//                                                               Set<WidgetState>
//                                                               states,
//                                                             ) {
//                                                               return toTitleCase(
//                                                                         category,
//                                                                       ) ==
//                                                                       toTitleCase(
//                                                                         provider
//                                                                             .selectedCategory,
//                                                                       )
//                                                                   ? CustomColors
//                                                                         .whiteColor
//                                                                   : CustomColors
//                                                                         .black
//                                                                         .withOpacity(
//                                                                           0.7,
//                                                                         );
//                                                             }),
//                                                       ),
//                                                       child: CustomText(
//                                                         text: toTitleCase(
//                                                           category,
//                                                         ),
//                                                         style: const TextStyle(
//                                                           fontFamily: 'Poppins',
//                                                           fontSize: 18,
//                                                           fontWeight:
//                                                               FontWeight.bold,
//                                                         ),
//                                                       ),

//                                                       //child: CustomText(text: category, style: TextStyle(fontFamily: 'Poppins',fontSize: 18,fontWeight: FontWeight.bold,)),
//                                                     );
//                                                   }),
//                                                 ],
//                                               ),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: RepaintBoundary(
//                                         child: provider.isLoading
//                                             ? const Center(
//                                                 child:
//                                                     CircularProgressIndicator(),
//                                               )
//                                             : provider.isFavoriteSelected
//                                             ? const FavoritePageWidget()
//                                             : provider.isMixedSelected
//                                             ? const MixedboxPageWidget()
//                                             : MyGridView(items: provider.items),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               const VerticalDivider(width: 1),
//                               Expanded(
//                                 flex: 1,
//                                 child: RepaintBoundary(
//                                   child: CurrentSaleSection(),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     );
//                   },
//                 ),

//                 /// 🔹 Hidden input field to receive USB scanner data
//                 Positioned(
//                   bottom: 0,
//                   left: 0,
//                   width: 1,
//                   height: 1,
//                   child: TextField(
//                     focusNode: _focusNode,
//                     controller: _textController,
//                     showCursor: false,
//                     enableInteractiveSelection: false,
//                     keyboardType: TextInputType.none,
//                     autofocus: true,
//                     onSubmitted: (value) => _handleInput(value.trim()),
//                     onChanged: (value) {
//                       if (value.endsWith('\n') || value.endsWith('\r')) {
//                         _handleInput(value.trim());
//                         _textController.clear();
//                       }
//                     },
//                     decoration: const InputDecoration(border: InputBorder.none),
//                     style: const TextStyle(
//                       fontFamily: 'Poppins',
//                       fontSize: 1,
//                       color: Colors.transparent,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// void _handleInput(String value) async {
//   if (_isProcessing || value.isEmpty) return;

//   setState(() => _isProcessing = true);

//   try {
//     final Map<String, dynamic> scannedData = _parseScannedData(value);
//     if (scannedData.containsKey('ItemCode')) {
//       final itemCode = scannedData['ItemCode'];
//       final quantity = scannedData['Qty'] ?? 1;
//       final uom = scannedData['UOM'] ?? '';

//       final itemProvider = Provider.of<ItemProvider>(context, listen: false);
//       final result = itemProvider.checkVarianceItemCode(itemCode);

//       if (result.isNotEmpty) {
//         final saleProvider = Provider.of<CurrentSaleProvider>(
//           context,
//           listen: false,
//         );
//         final itemData = result.first;

//         saleProvider.addItemToCart({
//           ...itemData,
//           'quantity': parseNum(quantity),
//           'uom': uom,
//           'varianceData': {
//             ...itemData['varianceData'],
//             'variance_Defaultprice': parseNum(
//               itemData['varianceData']['variance_Defaultprice'],
//             ),
//           },
//         });

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             backgroundColor: CustomColors.blueColor,
//             content: Text(
//               "Item added: ${itemData['varianceData']['varianceName']}",
//               style: const TextStyle(color: Colors.white),
//             ),
//             duration: const Duration(milliseconds: 800),
//           ),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Item not found for scanned code."),
//             duration: Duration(milliseconds: 800),
//           ),
//         );
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Invalid QR/barcode data."),
//           duration: Duration(milliseconds: 800),
//         ),
//       );
//     }
//   } catch (e) {
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text("Error: $e")));
//   } finally {
//     _textController.clear();
//     Future.delayed(const Duration(milliseconds: 200), () {
//       _focusNode.requestFocus();
//     });
//     setState(() => _isProcessing = false);
//   }
// }

class RegularModeScreen extends StatefulWidget {
  const RegularModeScreen({super.key});
  @override
  State<RegularModeScreen> createState() => _RegularModeScreenState();
}

class _RegularModeScreenState extends State<RegularModeScreen> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 300), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  double parseNum(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> _parseScannedData(String value) {
    try {
      return json.decode(value);
    } catch (_) {
      final Map<String, dynamic> parsed = {};
      value.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
        final kv = pair.split(':');
        if (kv.length == 2) parsed[kv[0].trim()] = kv[1].trim();
      });
      return parsed;
    }
  }

  void _handleInput(String value) async {
    if (_isProcessing || value.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final Map<String, dynamic> scannedData = _parseScannedData(value);
      if (scannedData.containsKey('ItemCode')) {
        final itemCode = scannedData['ItemCode'];
        final quantity = scannedData['Qty'] ?? 1;
        final uom = scannedData['UOM'] ?? '';
        final itemProvider = Provider.of<ItemProvider>(context, listen: false);
        final result = await itemProvider.checkVarianceItemCode(
          locationId,
          itemCode,
        );
        if (result.isNotEmpty) {
          final itemData = result.first;
          // STOCK VALIDATION
          final stock = parseNum(
            itemData["varianceData"]["variance_Stock"] ?? 0,
          );
          final scannedQty = parseNum(quantity);
          if (stock <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text(
                  "Out of Stock: ${itemData['varianceData']['varianceName']}",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
            return;
          }
          if (scannedQty > stock) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.orange,
                content: Text(
                  "Only $stock available, but scanned qty = $scannedQty",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
            return;
          }
          // Add to cart
          final saleProvider = Provider.of<CurrentSaleProvider>(
            context,
            listen: false,
          );
          saleProvider.addItemToCart({
            ...itemData,
            'quantity': scannedQty,
            'uom': uom,
            'varianceData': {
              ...itemData['varianceData'],
              'variance_Defaultprice': parseNum(
                itemData['varianceData']['variance_Defaultprice'],
              ),
            },
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: CustomColors.blueColor,
              content: Text(
                "Item added: ${itemData['varianceData']['varianceName']}",
              ),
              duration: const Duration(milliseconds: 800),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Item not found for scanned code."),
              duration: Duration(milliseconds: 800),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid QR/barcode data."),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      _textController.clear();
      Future.delayed(const Duration(milliseconds: 200), () {
        _focusNode.requestFocus();
      });
      setState(() => _isProcessing = false);
    }
  }

  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegularModeProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SafeArea(
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                Consumer<RegularModeProvider>(
                  builder: (context, provider, child) {
                    return Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Expanded(child: SearchDropdown()),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 2,
                                            child: SingleChildScrollView(
                                              controller:
                                                  provider.scrollController,
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children: [
                                                  TextButton(
                                                    style: TextButton.styleFrom(
                                                      backgroundColor:
                                                          provider
                                                              .isFavoriteSelected
                                                          ? CustomColors
                                                                .blueColor
                                                          : CustomColors
                                                                .whiteColor,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadiusGeometry.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    onPressed: () => provider
                                                        .setFavorite(true),
                                                    child: Text(
                                                      "Favorite",
                                                      style: TextStyle(
                                                        fontFamily: 'Poppins',
                                                        fontSize: 18,
                                                        color:
                                                            provider
                                                                .isFavoriteSelected
                                                            ? CustomColors
                                                                  .whiteColor
                                                            : CustomColors
                                                                  .blueColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  TextButton(
                                                    style: TextButton.styleFrom(
                                                      backgroundColor:
                                                          provider
                                                              .isMixedSelected
                                                          ? CustomColors
                                                                .blueColor
                                                          : CustomColors
                                                                .whiteColor,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadiusGeometry.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    onPressed: () =>
                                                        provider.setMixed(true),
                                                    child: Text(
                                                      "Mixed",
                                                      style: TextStyle(
                                                        fontFamily: 'Poppins',
                                                        fontSize: 18,
                                                        color:
                                                            provider
                                                                .isMixedSelected
                                                            ? CustomColors
                                                                  .whiteColor
                                                            : CustomColors
                                                                  .blueColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  ...provider.categories.map((
                                                    category,
                                                  ) {
                                                    return TextButton(
                                                      onPressed: () {
                                                        provider
                                                            .filterItemsByCategory(
                                                              category,
                                                            );
                                                      },
                                                      style: ButtonStyle(
                                                        shape: const WidgetStatePropertyAll(
                                                          RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.all(
                                                                  Radius.circular(
                                                                    5,
                                                                  ),
                                                                ),
                                                          ),
                                                        ),
                                                        backgroundColor: WidgetStateProperty.all(
                                                          // FIXED: Direct comparison, no toTitleCase
                                                          category ==
                                                                      provider
                                                                          .selectedCategory &&
                                                                  !provider
                                                                      .isFavoriteSelected &&
                                                                  !provider
                                                                      .isMixedSelected
                                                              ? CustomColors
                                                                    .blueColor
                                                              : CustomColors
                                                                    .whiteColor,
                                                        ),
                                                        foregroundColor: WidgetStateProperty.all(
                                                          // FIXED: Direct comparison
                                                          category ==
                                                                      provider
                                                                          .selectedCategory &&
                                                                  !provider
                                                                      .isFavoriteSelected &&
                                                                  !provider
                                                                      .isMixedSelected
                                                              ? CustomColors
                                                                    .whiteColor
                                                              : CustomColors
                                                                    .black
                                                                    .withOpacity(
                                                                      0.7,
                                                                    ),
                                                        ),
                                                      ),
                                                      child: CustomText(
                                                        text: toTitleCase(
                                                          category,
                                                        ),
                                                        style: const TextStyle(
                                                          fontFamily: 'Poppins',
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: RepaintBoundary(
                                        child: provider.isLoading
                                            ? const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              )
                                            : provider.isFavoriteSelected
                                            ? const FavoritePageWidget()
                                            : provider.isMixedSelected
                                            ? const MixedboxPageWidget()
                                            : MyGridView(items: provider.items),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                flex: 1,
                                child: RepaintBoundary(
                                  child: CurrentSaleSection(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  width: 1,
                  height: 1,
                  child: TextField(
                    focusNode: _focusNode,
                    controller: _textController,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    keyboardType: TextInputType.none,
                    autofocus: true,
                    onSubmitted: (value) => _handleInput(value.trim()),
                    onChanged: (value) {
                      if (value.endsWith('\n') || value.endsWith('\r')) {
                        _handleInput(value.trim());
                        _textController.clear();
                      }
                    },
                    decoration: const InputDecoration(border: InputBorder.none),
                    style: const TextStyle(
                      fontSize: 1,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

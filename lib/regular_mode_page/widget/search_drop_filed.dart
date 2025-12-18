// search_drop_filed.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';

import 'package:yenpos/Sale_order/Widgets/numeric_Calculator.dart';
import 'package:yenpos/more_page/providers/bt_provide2.dart';
import 'package:yenpos/regular_mode_page/provider/cart_page_provider.dart';
import 'package:yenpos/regular_mode_page/widget/custom_reusable_widget/quantity_dialog.dart';

import '../../../regular_mode_page/provider/regular_mode_screen_provider.dart';

final FocusNode focusNode = FocusNode();

class SearchDropdown extends StatefulWidget {
  const SearchDropdown({Key? key}) : super(key: key);

  @override
  _SearchDropdownState createState() => _SearchDropdownState();
}

class _SearchDropdownState extends State<SearchDropdown> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _hiddenController = TextEditingController();
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isQrMode = false;
  bool _isProcessing = false;
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateOverlay);
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _controller.removeListener(_updateOverlay);
    _controller.clear();
    _controller.dispose();
    _hiddenController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _updateOverlay() {
    final provider = Provider.of<RegularModeProvider>(context, listen: false);
    provider.filterVarianceNamesBySearchQuery(_controller.text.trim());

    if (_controller.text.isEmpty) {
      _removeOverlay();
      return;
    }

    if (_overlayEntry == null) {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 3.0),
                child: Material(
                  elevation: 6.0,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: Consumer<RegularModeProvider>(
                    builder: (_, provider, __) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.blue.shade100.withOpacity(0.6), blurRadius: 6, offset: Offset(0, 2)),
                          ],
                        ),
                        constraints: BoxConstraints(maxHeight: 200),
                        child: provider.filteredVarianceNames.isNotEmpty
                            ? ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: provider.filteredVarianceNames.length,
                                itemBuilder: (_, index) {
                                  final varianceName = provider.filteredVarianceNames[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    title: CustomText(
                                      text: varianceName,
                                      style: TextStyle(fontFamily: "Poppins",fontSize: 14, color: Colors.blue.shade700, fontWeight: FontWeight.w400),
                                    ),
                                    hoverColor: Colors.blue.shade50,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    onTap: () async {
                                      if (index < provider.filteredVarianceNames.length) {
                                        final selectedItem = provider.getVarianceDetails(varianceName);
                                        if (selectedItem != null) {
                                          final varianceData = provider.getVarianceDetails(varianceName);
                                          final itemName = await _getItemNameForVariance(varianceName, aliasname) ?? 'Unknown Item';
                                          final varianceUOM = provider.getUOMForVariance(varianceName) ?? 'Unknown UOM';
                                          await _handleItemSelection(selectedItem, varianceData, itemName, varianceUOM);
                                          _removeOverlay();
                                        }
                                      }
                                    },
                                  );
                                },
                              )
                            : Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text("No results found", style: TextStyle(fontFamily: "Poppins",fontSize: 12)),
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
      ),
    );
  }


  Future<String?> _getItemNameForVariance(String varianceName, String branchAlias) async {
  // Open the Hive box
  final lazyBox = await Hive.openBox('items');

  // Fetch branchwiseItems from Hive for the current branch
  final branchwiseData = (await lazyBox.get('branchwiseItems_$branchAlias'))?['data'] as Map<dynamic, dynamic>?;

  if (branchwiseData == null) {
    print('DEBUG: _getItemNameForVariance - branchwiseItems is null');
    return null;
  }

  for (var entry in branchwiseData.entries) {
    final itemName = entry.key.toString();
    final itemData = entry.value as Map<dynamic, dynamic>?;

    if (itemData != null && itemData['variance'] != null) {
      final varianceMap = itemData['variance'] as Map<dynamic, dynamic>;
      if (varianceMap.values.any((v) => (v as Map<dynamic, dynamic>)['varianceName']?.toString() == varianceName)) {
        return itemName;
      }
    }
  }

  print('DEBUG: _getItemNameForVariance - No item found for variance: $varianceName');
  return null;
}


//   Future<void> _handleItemSelection(
//   Map<String, dynamic> selectedItem,
//   Map<String, dynamic> varianceData,
//   String itemName,
//   String varianceUOM,
// ) async {
//   final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
//   final bluetoothProvider2 = Provider.of<BluetoothProvider2>(context, listen: false);

//   String varianceName = selectedItem['varianceName'] ?? 'Unknown Variance';
//   String itemCode = varianceData['varianceItemCode']?.toString() ?? varianceName;
//   double price = (varianceData['branchwise']?['${aliasname}']?['Price_${aliasname}'] as num?)?.toDouble() ?? 0.0;

//   Map<String, dynamic>? itemData;
//   double tax = 0.0;
//   double systemStock = 0.0;

//   // --- Fetch from Hive ---
//   final lazyBox = await Hive.openBox('items');
//   final branchwiseItemsData = await lazyBox.get('branchwiseItems_$aliasname');
//   final branchwiseItems = branchwiseItemsData != null
//       ? branchwiseItemsData['data'] as Map<dynamic, dynamic>?
//       : null;

//   if (branchwiseItems != null && branchwiseItems.containsKey(itemName)) {
//     final rawItemData = branchwiseItems[itemName]?['item'] as Map<dynamic, dynamic>?;
//     if (rawItemData != null) {
//       itemData = rawItemData.map((key, value) => MapEntry(key.toString(), value));
//       tax = (rawItemData['tax'] as num?)?.toDouble() ?? 0.0;
//     }
//     systemStock = (varianceData['branchwise']?['${aliasname}']?['systemStock_${aliasname}'] as num?)?.toDouble() ?? 0.0;
//   }

//     bool isWeightItem = (varianceUOM.toLowerCase() == 'kgs' || varianceUOM.toLowerCase() == 'kg');

//     // Consistent itemId rule
//     String itemId = "${itemName}_${varianceName}";

//     // Base item structure
//     Map<String, dynamic> itemToAdd = {
//       'itemData': {
//         'itemId': itemId,
//         'itemName': itemName,
//         'itemCode': itemCode,
//         'tax': tax,
//         'item_Uom': varianceUOM,
//         'category': itemData?['category']?.toString() ?? varianceData['category']?.toString() ?? 'Unknown',
//       },
//       'varianceData': {
//         'varianceName': varianceName,
//         'variance_Defaultprice': price,
//         'variance_Uom': varianceUOM,
//         'variancetax': tax,
//         'varianceItemCode': itemCode,
//       },
//       'itemName': itemName,
//       'uom': varianceUOM,
//       'quantity': 1,
//       'weight': 0.0,
//       'itemCode': itemCode,
//       'tax': tax,
//       'itemWiseDiscountAmount': 0.0,
//       'itemWiseDiscount': 0.0,
//       'isBoxItem': 'no',
//       'totalPrice': price,
//     };

//     // Helper: Add to cart directly with qty = 1
//     void _addDirectlyToCart() {
//       if (1 > systemStock) {
//         _showErrorSnackbar(context, "Insufficient stock for $varianceName. Available: $systemStock.");
//         _clearSelection();
//         return;
//       }
//       saleProvider.addItemToCart(itemToAdd);
//       _showSuccessSnackbar(context, varianceName);
//       _clearSelection();
//     }

//     try {
//       if (isWeightItem) {
//         // Weight items: always show dialog (even if isCartEnabled)
//         if (bluetoothProvider2.isConnected) {
//           _showBluetoothWeightDialog(context, itemName, varianceName, price, itemToAdd, saleProvider, systemStock);
//         } else {
//           _showNumericCalculatorDialog(context, varianceName, price, itemToAdd, saleProvider, systemStock);
//         }
//       } else if (varianceUOM == 'Pcs' || varianceUOM == 'Pkt') {
//         // Quantity-based items
//         if (isCartEnabled) {
//           _addDirectlyToCart();
//         } else {
//           _showQuantityDialog(context, varianceName, price, itemToAdd, saleProvider, systemStock);
//         }
//       } else {
//         // Other UOMs (like Ltr, Ml, etc.) – previously added directly
//         if (isCartEnabled) {
//           _addDirectlyToCart();
//         } else {
//           if (1 > systemStock) {
//             _showErrorSnackbar(context, "Insufficient stock for $varianceName. Available: $systemStock.");
//             _clearSelection();
//             return;
//           }
//           saleProvider.addItemToCart(itemToAdd);
//           _showSuccessSnackbar(context, varianceName);
//         }
//       }
//     } catch (e) {
//       _showErrorSnackbar(context, e.toString());
//     }

//     // Final cleanup (only if not opening a dialog)
//     if (!isWeightItem && (isCartEnabled || !(varianceUOM == 'Pcs' || varianceUOM == 'Pkt'))) {
//       // Already cleared inside _addDirectlyToCart or success path
//     } else {
//       // Dialogs will handle their own cleanup
//     }
//   }

Future<void> _handleItemSelection(
  Map<String, dynamic> selectedItem,
  Map<String, dynamic> varianceData,
  String itemName,
  String varianceUOM,
) async {
  final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
  final bluetoothProvider2 = Provider.of<BluetoothProvider2>(context, listen: false);

  String varianceName = selectedItem['varianceName'] ?? 'Unknown Variance';
  String itemCode = varianceData['varianceItemCode']?.toString() ?? varianceName;
  double price = (varianceData['branchwise']?['${aliasname}']?['Price_${aliasname}'] as num?)?.toDouble() ?? 0.0;

  Map<String, dynamic>? itemData;
  double tax = 0.0;
  double systemStock = 0.0;

  // --- Fetch from Hive ---
  final lazyBox = await Hive.openBox('items');
  final branchwiseItemsData = await lazyBox.get('branchwiseItems_$aliasname');
  final branchwiseItems = branchwiseItemsData != null
      ? branchwiseItemsData['data'] as Map<dynamic, dynamic>?
      : null;

  if (branchwiseItems != null && branchwiseItems.containsKey(itemName)) {
    final rawItemData = branchwiseItems[itemName]?['item'] as Map<dynamic, dynamic>?;
    if (rawItemData != null) {
      itemData = rawItemData.map((key, value) => MapEntry(key.toString(), value));
      tax = (rawItemData['tax'] as num?)?.toDouble() ?? 0.0;
    }
    systemStock = (varianceData['branchwise']?['${aliasname}']?['systemStock_${aliasname}'] as num?)?.toDouble() ?? 0.0;
  }

  bool isWeightItem = (varianceUOM.toLowerCase() == 'kgs' || varianceUOM.toLowerCase() == 'kg');
  String itemId = "${itemName}_$varianceName";

  Map<String, dynamic> itemToAdd = {
    'itemData': {
      'itemId': itemId,
      'itemName': itemName,
      'itemCode': itemCode,
      'tax': tax,
      'item_Uom': varianceUOM,
      'category': itemData?['category']?.toString() ?? varianceData['category']?.toString() ?? 'Unknown',
    },
    'varianceData': {
      'varianceName': varianceName,
      'variance_Defaultprice': price,
      'variance_Uom': varianceUOM,
      'variancetax': tax,
      'varianceItemCode': itemCode,
    },
    'itemName': itemName,
    'uom': varianceUOM,
    'quantity': 1,
    'weight': 0.0,
    'itemCode': itemCode,
    'tax': tax,
    'itemWiseDiscountAmount': 0.0,
    'itemWiseDiscount': 0.0,
    'isBoxItem': 'no',
    'totalPrice': price,
  };

  // Helper: Add directly to cart
  void _addDirectlyToCart() {
    if (1 > systemStock) {
      _showErrorSnackbar(context, "Insufficient stock for $varianceName. Available: $systemStock.");
      return;
    }
    saleProvider.addItemToCart(itemToAdd);
    _showSuccessSnackbar(context, varianceName);
  }

  // CLEAR TEXT IMMEDIATELY AFTER SELECTION — THIS IS THE KEY FIX
  _clearSelection();  // ADD THIS LINE HERE

  try {
    if (isWeightItem) {
      if (bluetoothProvider2.isConnected) {
        _showBluetoothWeightDialog(context, itemName, varianceName, price, itemToAdd, saleProvider, systemStock);
      } else {
        _showNumericCalculatorDialog(context, varianceName, price, itemToAdd, saleProvider, systemStock);
      }
    } else if (varianceUOM == 'Pcs' || varianceUOM == 'Pkt') {
      if (isCartEnabled) {
        _addDirectlyToCart();
      } else {
        _showQuantityDialog(context, varianceName, price, itemToAdd, saleProvider, systemStock);
      }
    } else {
      if (isCartEnabled) {
        _addDirectlyToCart();
      } else {
        if (1 > systemStock) {
          _showErrorSnackbar(context, "Insufficient stock for $varianceName. Available: $systemStock.");
          return;
        }
        saleProvider.addItemToCart(itemToAdd);
        _showSuccessSnackbar(context, varianceName);
      }
    }
  } catch (e) {
    _showErrorSnackbar(context, e.toString());
  }
}

  void _showBluetoothWeightDialog(
    BuildContext context,
    String itemName,
    String varianceName,
    double price,
    Map<String, dynamic> itemToAdd,
    CurrentSaleProvider saleProvider,
    double systemStock,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          backgroundColor: Colors.white,
          title: CustomText(
            text: varianceName,
            style: const TextStyle(fontFamily: "Poppins",fontSize: 18.0, fontWeight: FontWeight.bold),
          ),
          content: Consumer<BluetoothProvider2>(
            builder: (context, bluetoothProvider2, child) {
              double weight = bluetoothProvider2.weight;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weight <= 0 ? "Waiting for weight..." : "Weight: ${weight.toStringAsFixed(3)} kg",
                    style: const TextStyle(fontFamily: "Poppins",fontSize: 24),
                  ),
                  if (weight <= 0) const Padding(padding: EdgeInsets.only(top: 16.0), child: CircularProgressIndicator()),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                double weight = Provider.of<BluetoothProvider2>(dialogContext, listen: false).weight;

                if (weight <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text("Invalid weight. Please wait for a valid weight reading."),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                // Validate stock after weight input
                if (weight > systemStock) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Selected weight (${weight.toStringAsFixed(3)} kg) exceeds available stock (${systemStock.toStringAsFixed(3)} kg).",
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                itemToAdd['weight'] = weight;
                itemToAdd['quantity'] = 1;
                itemToAdd['totalPrice'] = weight * price;

                print('DEBUG: _showBluetoothWeightDialog - Adding weight item: $itemToAdd');
                saleProvider.addItemToCart(itemToAdd);

                _showSuccessSnackbar(dialogContext, "$varianceName (${weight.toStringAsFixed(3)} Kg)");
                Navigator.of(dialogContext).pop();
              },
              style: ButtonStyle(
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                backgroundColor: WidgetStateProperty.all(Colors.blue),
              ),
              child: const CustomText(
                text: 'Add to Cart',
                style: TextStyle(fontFamily: "Poppins",fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNumericCalculatorDialog(
    BuildContext context,
    String varianceName,
    double price,
    Map<String, dynamic> itemToAdd,
    CurrentSaleProvider saleProvider,
    double systemStock,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return NumericCalculator(
          varianceName: varianceName,
          onValueSelected: (weight) {
            print('DEBUG: NumericCalculator - Selected Weight: $weight');
            if (weight <= 0) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text("Invalid weight. Please enter a valid weight."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }

            // Validate stock after weight input
            if (weight > systemStock) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text(
                    "Selected weight (${weight.toStringAsFixed(3)} kg) exceeds available stock (${systemStock.toStringAsFixed(3)} kg).",
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
              return;
            }

            itemToAdd['weight'] = weight;
            itemToAdd['quantity'] = 1;
            itemToAdd['totalPrice'] = weight * price;
            print('DEBUG: _showNumericCalculatorDialog - Adding weight item: $itemToAdd');
            saleProvider.addItemToCart(itemToAdd);
            _showSuccessSnackbar(dialogContext, "$varianceName (${weight.toStringAsFixed(2)} Kg)");
          },
        );
      },
    );
  }

  void _showQuantityDialog(
    BuildContext context,
    String varianceName,
    double price,
    Map<String, dynamic> itemToAdd,
    CurrentSaleProvider saleProvider,
    double systemStock,
  ) {
    showCommonQuantityDialog(
      context: context,
      itemName: itemToAdd['itemName'],
      varianceName: varianceName,
      price: price,
      initialQuantity: 1.0,
      systemStockOverride: systemStock,
      onAddToCart: (quantity) {
        itemToAdd['quantity'] = quantity;
        itemToAdd['totalPrice'] = quantity * price;
        saleProvider.addItemToCart(itemToAdd);
        //_showSuccessSnackbar(context, "$varianceName ($quantity Pcs)");
      },
    );
  }

  void _showSuccessSnackbar(BuildContext context, String itemName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.blue,
        content: Text("Item added to cart: $itemName", style: TextStyle(fontFamily: "Poppins",color: Colors.white)),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to add item: $error"), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
    );
  }

  void _clearSelection() {
    _controller.clear();
    _searchFocus.unfocus();
    _removeOverlay();
  }

  void _toggleQrMode() {
    setState(() {
      _isQrMode = !_isQrMode;
      if (_isQrMode) {
        focusNode.requestFocus();
      } else {
        focusNode.unfocus();
      }
    });
  }

  void _handleInput(String value) async {
    if (_isProcessing || !_isQrMode || value.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final Map<String, dynamic> scannedData = _parseScannedData(value);

      if (scannedData.containsKey('ItemCode')) {
        final itemCode = scannedData['ItemCode']?.toString() ?? "";
        final quantity = parseToDouble(scannedData['Qty'] ?? 1);
        final uom = scannedData['UOM']?.toString() ?? '';

        final itemProvider = Provider.of<ItemProvider>(context, listen: false);
        final provider = Provider.of<RegularModeProvider>(context, listen: false);
        final result = await itemProvider.checkVarianceItemCode(itemCode,aliasname);

        if (result.isNotEmpty) {
          final itemData = result.first;
          final varianceName = itemData['varianceData']['varianceName']?.toString() ?? '';
          final selectedItem = provider.getVarianceDetails(varianceName);
          if (selectedItem != null) {
            final varianceData = provider.getVarianceDetails(varianceName);
            final itemName = await _getItemNameForVariance(varianceName, aliasname) ?? 'Unknown Item';
            final varianceUOM = provider.getUOMForVariance(varianceName)?.toString() ?? 'Unknown UOM';
            // Validate stock for QR code scanned items
            double systemStock =
                (varianceData['branchwise']?['${aliasname}']?['systemStock_${aliasname}'] as num?)?.toDouble() ?? 0.0;
            if (quantity > systemStock) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Scanned quantity (${quantity.toInt()}) exceeds available stock (${systemStock.toInt()})."),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
              return;
            }
            await _handleItemSelection(selectedItem, varianceData, itemName, varianceUOM);
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Item details not found."), duration: Duration(milliseconds: 500)));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item not found for the scanned code."), duration: Duration(milliseconds: 500)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid QR data. 'ItemCode' not found."), duration: Duration(milliseconds: 500)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}"), duration: const Duration(milliseconds: 500)));
    } finally {
      _controller.clear();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Map<String, dynamic> _parseScannedData(String value) {
    try {
      final decoded = json.decode(value);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      return {};
    } catch (_) {
      final Map<String, dynamic> parsedData = {};
      value.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          parsedData[keyValue[0].trim()] = keyValue[1].trim();
        }
      });
      return parsedData;
    }
  }

  double parseToDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _removeOverlay();
        focusNode.unfocus();
        _searchFocus.unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FocusScope(
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) {
                        _removeOverlay();
                      }
                    },
                    child: TextField(
                      showCursor: true,
                      cursorColor: Colors.blue,
                      focusNode: _searchFocus,
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Search items',
                        prefixIcon: Icon(Icons.search, color: Colors.blue),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2.0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        fillColor: Colors.blue.shade50,
                        filled: true,
                        labelStyle: TextStyle(fontFamily: "Poppins",color: Colors.blue),
                        hintStyle: TextStyle(fontFamily: "Poppins",color: Colors.blue),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]+'))],
                      style: TextStyle(fontFamily: "Poppins",color: Colors.blue),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _handleInput(value);
                          _updateOverlay();
                        }
                      },
                      onTap: () => ActiveField.activate(ctrl: _controller, node: _searchFocus, context: context),
                    ),
                  ),
                ),
              ],
            ),
            Offstage(
              offstage: !_isQrMode,
              child: TextField(
                controller: _hiddenController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 0.0),
                  isDense: true,
                  fillColor: Colors.transparent,
                  filled: true,
                ),
                style: const TextStyle(fontFamily: "Poppins",fontSize: 0),
                keyboardType: TextInputType.none,
                onSubmitted: _handleInput,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




  // void _handleItemSelection(
  //   Map<String, dynamic> selectedItem,
  //   Map<String, dynamic> varianceData,
  //   String itemName,
  //   String varianceUOM,
  // ) {
  //   final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
  //   final bluetoothProvider2 = Provider.of<BluetoothProvider2>(context, listen: false);

  //   String varianceName = selectedItem['varianceName'] ?? 'Unknown Variance';
  //   String itemCode = varianceData['varianceItemCode']?.toString() ?? varianceName;
  //   double price = (varianceData['branchwise']?['${aliasname}']?['Price_${aliasname}'] as num?)?.toDouble() ?? 0.0;
  //   print('DEBUG: varianceData branchwise → ${jsonEncode(varianceData['branchwise'])}');
  //   print('DEBUG: aliasname: $aliasname');

  //   // Fetch itemData and system stock
  //   Map<String, dynamic>? itemData;
  //   double tax = 0.0;
  //   double systemStock = 0.0;
  //   final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map<dynamic, dynamic>?;
  //   if (itemName != 'Unknown Item' && branchwiseItems != null && branchwiseItems.containsKey(itemName)) {
  //     final rawItemData = branchwiseItems[itemName]?['item'] as Map<dynamic, dynamic>?;
  //     if (rawItemData != null) {
  //       itemData = rawItemData.map((key, value) => MapEntry(key.toString(), value));
  //       tax = (rawItemData['tax'] as num?)?.toDouble() ?? 0.0;
  //     }
  //     systemStock = (varianceData['branchwise']?['${aliasname}']?['systemStock_${aliasname}'] as num?)?.toDouble() ?? 0.0;
  //   } else {
  //     print('DEBUG: _handleItemSelection - Invalid itemName: $itemName or branchwiseItems[\'data\'] is null');
  //   }

  //   bool isWeightItem = (varianceUOM.toLowerCase() == 'kgs' || varianceUOM.toLowerCase() == 'kg');

  //   print('DEBUG: _handleItemSelection - Variance Data: $varianceData');
  //   print('DEBUG: _handleItemSelection - Item Data: $itemData');
  //   print('DEBUG: _handleItemSelection - IsWeightItem: $isWeightItem, UOM: $varianceUOM, Tax: $tax, System Stock: $systemStock');
  //   print('DEBUG: _handleItemSelection - Bluetooth Connected: ${bluetoothProvider2.isConnected}');

  //   Map<String, dynamic> itemToAdd = {
  //     'itemData': {
  //       'itemId': itemData?['itemId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
  //       'itemName': itemName,
  //       'itemCode': itemCode,
  //       'tax': tax,
  //       'item_Uom': varianceUOM,
  //       'category': itemData?['category']?.toString() ?? varianceData['category']?.toString() ?? 'Unknown',
  //     },
  //     'varianceData': {
  //       'varianceName': varianceName,
  //       'variance_Defaultprice': price,
  //       'variance_Uom': varianceUOM,
  //       'variancetax': tax,
  //       'varianceItemCode': itemCode,
  //     },
  //     'itemName': itemName,
  //     'uom': varianceUOM,
  //     'quantity': isWeightItem ? 1 : 1,
  //     'weight': 0.0,
  //     'itemCode': itemCode,
  //     'tax': tax,
  //     'itemWiseDiscountAmount': 0.0,
  //     'itemWiseDiscount': 0.0,
  //     'isBoxItem': 'no',
  //     'totalPrice': price,
  //   };

  //   try {
  //     if (isWeightItem) {
  //       if (bluetoothProvider2.isConnected) {
  //         _showBluetoothWeightDialog(context, itemName, varianceName, price, itemToAdd, saleProvider, systemStock);
  //       } else {
  //         _showNumericCalculatorDialog(context, varianceName, price, itemToAdd, saleProvider, systemStock);
  //       }
  //     } else if (varianceUOM == 'Pcs' || varianceUOM == 'Pkt') {
  //       _showQuantityDialog(context, varianceName, price, itemToAdd, saleProvider, systemStock);
  //     } else {
  //       // For other item types, validate stock for quantity=1
  //       if (1 > systemStock) {
  //         _showErrorSnackbar(context, "Insufficient stock for $varianceName. Available: $systemStock.");
  //         _clearSelection();
  //         return;
  //       }
  //       print('DEBUG: _handleItemSelection - Adding default item: $itemToAdd');
  //       saleProvider.addItemToCart(itemToAdd);
  //       _showSuccessSnackbar(context, varianceName);
  //     }
  //   } catch (e) {
  //     _showErrorSnackbar(context, e);
  //   }

  //   _clearSelection();
  // }
  //   void _handleItemSelection(
  //   Map<String, dynamic> selectedItem,
  //   Map<String, dynamic> varianceData,
  //   String itemName,
  //   String varianceUOM,
  // ) {
  //   final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
  //   final bluetoothProvider2 = Provider.of<BluetoothProvider2>(context, listen: false);

  //   String varianceName = selectedItem['varianceName'] ?? 'Unknown Variance';
  //   String itemCode = varianceData['varianceItemCode']?.toString() ?? varianceName;
  //   double price = (varianceData['branchwise']?['${aliasname}']?['Price_${aliasname}'] as num?)?.toDouble() ?? 0.0;

  //   Map<String, dynamic>? itemData;
  //   double tax = 0.0;
  //   double systemStock = 0.0;

  //   final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map<dynamic, dynamic>?;
  //   if (branchwiseItems != null && branchwiseItems.containsKey(itemName)) {
  //     final rawItemData = branchwiseItems[itemName]?['item'] as Map<dynamic, dynamic>?;
  //     if (rawItemData != null) {
  //       itemData = rawItemData.map((key, value) => MapEntry(key.toString(), value));
  //       tax = (rawItemData['tax'] as num?)?.toDouble() ?? 0.0;
  //     }
  //     systemStock = (varianceData['branchwise']?['${aliasname}']?['systemStock_${aliasname}'] as num?)?.toDouble() ?? 0.0;
  //   }

  //   bool isWeightItem = (varianceUOM.toLowerCase() == 'kgs' || varianceUOM.toLowerCase() == 'kg');

  //   // ✅ Consistent itemId rule
  //   String itemId = "${itemName}_${varianceName}";

  //   Map<String, dynamic> itemToAdd = {
  //     'itemData': {
  //       'itemId': itemId,
  //       'itemName': itemName,
  //       'itemCode': itemCode,
  //       'tax': tax,
  //       'item_Uom': varianceUOM,
  //       'category': itemData?['category']?.toString() ?? varianceData['category']?.toString() ?? 'Unknown',
  //     },
  //     'varianceData': {
  //       'varianceName': varianceName,
  //       'variance_Defaultprice': price,
  //       'variance_Uom': varianceUOM,
  //       'variancetax': tax,
  //       'varianceItemCode': itemCode,
  //     },
  //     'itemName': itemName,
  //     'uom': varianceUOM,
  //     'quantity': 1,
  //     'weight': 0.0,
  //     'itemCode': itemCode,
  //     'tax': tax,
  //     'itemWiseDiscountAmount': 0.0,
  //     'itemWiseDiscount': 0.0,
  //     'isBoxItem': 'no',
  //     'totalPrice': price,
  //   };

  //   try {
  //     if (isWeightItem) {
  //       if (bluetoothProvider2.isConnected) {
  //         _showBluetoothWeightDialog(context, itemName, varianceName, price, itemToAdd, saleProvider, systemStock);
  //       } else {
  //         _showNumericCalculatorDialog(context, varianceName, price, itemToAdd, saleProvider, systemStock);
  //       }
  //     } else if (varianceUOM == 'Pcs' || varianceUOM == 'Pkt') {
  //       _showQuantityDialog(context, varianceName, price, itemToAdd, saleProvider, systemStock);
  //     } else {
  //       if (1 > systemStock) {
  //         _showErrorSnackbar(context, "Insufficient stock for $varianceName. Available: $systemStock.");
  //         _clearSelection();
  //         return;
  //       }
  //       saleProvider.addItemToCart(itemToAdd);
  //       _showSuccessSnackbar(context, varianceName);
  //     }
  //   } catch (e) {
  //     _showErrorSnackbar(context, e);
  //   }

  //   _clearSelection();
  // }

  // void _handleItemSelection(
  //   Map<String, dynamic> selectedItem,
  //   Map<String, dynamic> varianceData,
  //   String itemName,
  //   String varianceUOM,
  // ) {
  //   final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
  //   final bluetoothProvider2 = Provider.of<BluetoothProvider2>(context, listen: false);

  //   String varianceName = selectedItem['varianceName'] ?? 'Unknown Variance';
  //   String itemCode = varianceData['varianceItemCode']?.toString() ?? varianceName;
  //   double price = (varianceData['branchwise']?['${aliasname}']?['Price_${aliasname}'] as num?)?.toDouble() ?? 0.0;

  //   Map<String, dynamic>? itemData;
  //   double tax = 0.0;
  //   double systemStock = 0.0;

  //   final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map<dynamic, dynamic>?;
    
  //   if (branchwiseItems != null && branchwiseItems.containsKey(itemName)) {
  //     final rawItemData = branchwiseItems[itemName]?['item'] as Map<dynamic, dynamic>?;
  //     if (rawItemData != null) {
  //       itemData = rawItemData.map((key, value) => MapEntry(key.toString(), value));
  //       tax = (rawItemData['tax'] as num?)?.toDouble() ?? 0.0;
  //     }
  //     systemStock = (varianceData['branchwise']?['${aliasname}']?['systemStock_${aliasname}'] as num?)?.toDouble() ?? 0.0;
  //   }

    // String? _getItemNameForVariance(String varianceName) {
  //   final branchwiseItems = GlobalDataManager().branchwiseItems['data'];
  //   if (branchwiseItems == null) {
  //     print('DEBUG: _getItemNameForVariance - branchwiseItems[\'data\'] is null');
  //     return null;
  //   }

  //   final items = branchwiseItems as Map<dynamic, dynamic>;
  //   for (var entry in items.entries) {
  //     final itemName = entry.key.toString();
  //     final itemData = entry.value as Map<dynamic, dynamic>?;
  //     if (itemData != null && itemData['variance'] != null) {
  //       final varianceMap = itemData['variance'] as Map<dynamic, dynamic>;
  //       if (varianceMap.values.any((v) => (v as Map<dynamic, dynamic>)['varianceName']?.toString() == varianceName)) {
  //         return itemName;
  //       }
  //     }
  //   }
  //   print('DEBUG: _getItemNameForVariance - No item found for variance: $varianceName');
  //   return null;
  // }

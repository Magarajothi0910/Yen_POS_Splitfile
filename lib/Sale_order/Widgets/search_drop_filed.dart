import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Mode_page/Regular_mode/Provider/regular_mode_screen_provider.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import '../../Global/Widget/custom_textWidgets.dart';
import 'numeric_Calculator.dart';

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
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
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
                            BoxShadow(
                              color: Colors.blue.shade100.withOpacity(0.6),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(maxHeight: 200),
                        child: provider.filteredVarianceNames.isNotEmpty
                            ? ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount:
                                    provider.filteredVarianceNames.length,
                                itemBuilder: (_, index) {
                                  final varianceName =
                                      provider.filteredVarianceNames[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 4.0,
                                      horizontal: 8.0,
                                    ),
                                    title: CustomText(
                                      text: varianceName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    hoverColor: Colors.blue.shade50,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        if (index <
                                            provider
                                                .filteredVarianceNames
                                                .length) {
                                          final selectedItem = provider
                                              .getVarianceDetails(varianceName);
                                          if (selectedItem != null) {
                                            final varianceData = provider
                                                .getVarianceDetails(
                                                  varianceName,
                                                );
                                            final itemName =
                                                varianceData['itemName'] ??
                                                'Unknown Item';
                                            final varianceUOM =
                                                provider.getUOMForVariance(
                                                  varianceName,
                                                ) ??
                                                'Unknown UOM';
                                            _handleItemSelection(
                                              selectedItem,
                                              varianceData,
                                              varianceUOM,
                                            );
                                            _removeOverlay();
                                          }
                                        }
                                      });
                                    },
                                  );
                                },
                              )
                            : Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    "No results found",
                                    style: TextStyle(fontSize: 12),
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
      ),
    );
  }

  void _handleItemSelection(
    Map<String, dynamic> selectedItem,
    Map<String, dynamic> variancedata,
    String? varianceUOM,
  ) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    String varianceName = selectedItem['varianceName']?.toString() ?? '';
    String itemCode =
        selectedItem['varianceItemCode']?.toString() ??
        variancedata['varianceItemCode']?.toString() ??
        variancedata['varianceitemCode']?.toString() ??
        '';
    String itemName = variancedata['itemName']?.toString() ?? '';
    varianceUOM = varianceUOM ?? '';

    double price = 0.0;
    final rawPrice =
        selectedItem['varianceDefaultPrice'] ??
        variancedata['variance_Defaultprice'];
    if (rawPrice is num) {
      price = rawPrice.toDouble();
    } else if (rawPrice is String && rawPrice.trim().isNotEmpty) {
      price = double.tryParse(rawPrice) ?? 0.0;
    }

    final tax = variancedata['variancetax'] ?? 0;

    if (varianceUOM == 'Kgs' || varianceUOM == 'Kg') {
      showDialog(
        context: context,
        builder: (context) {
          return NumericCalculator(
            varianceName: varianceName,
            onValueSelected: (weight) {
              cartProvider.addItemToCart(
                CartItem(
                  varianceName: varianceName,
                  pricePerKg: price.toInt(),
                  itemName: itemName,
                  uom: varianceUOM!,
                  weight: weight,
                  quantity: 1,
                  isBoxItem: 'no',
                  tax: tax,
                  itemCode: itemCode,
                  itemWiseDiscountAmount: 0.0,
                  itemWiseDiscount: 0.0,
                ),
              );
            },
          );
        },
      );
    } else {
      cartProvider.addItemToCart(
        CartItem(
          varianceName: varianceName,
          pricePerKg: price.toInt(),
          itemName: itemName,
          uom: varianceUOM,
          weight: 0,
          quantity: 1,
          isBoxItem: 'no',
          tax: tax,
          itemCode: itemCode,
          itemWiseDiscountAmount: 0.0,
          itemWiseDiscount: 0.0,
        ),
      );
    }
    setState(() {});
    _clearSelection();
  }

  void _clearSelection() {
    _controller.clear();
    focusNode.unfocus();
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
        final itemCode = scannedData['ItemCode'] ?? "";
        final quantity = parseToDouble(scannedData['Qty'] ?? 1);
        final uom = scannedData['UOM'] ?? '';

        final itemProvider = Provider.of<ItemProvider>(context, listen: false);
        final provider = Provider.of<RegularModeProvider>(
          context,
          listen: false,
        );
        final result = itemProvider.checkVarianceItemCode(itemCode);

        if (result.isNotEmpty) {
          final itemData = result.first;
          final varianceName = itemData['varianceData']['varianceName'] ?? '';
          final selectedItem = provider.getVarianceDetails(varianceName);
          if (selectedItem != null) {
            final varianceData = provider.getVarianceDetails(varianceName);
            final itemName = varianceData['itemName'] ?? 'Unknown Item';
            final varianceUOM =
                provider.getUOMForVariance(varianceName) ?? 'Unknown UOM';
            _handleItemSelection(selectedItem, varianceData, varianceUOM);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Item not found for the scanned code."),
              duration: Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid QR data. 'ItemCode' not found."),
            duration: Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          duration: const Duration(milliseconds: 500),
        ),
      );
    } finally {
      _controller.clear();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Map<String, dynamic> _parseScannedData(String value) {
    try {
      return json.decode(value);
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
                      if (!hasFocus) _removeOverlay();
                    },
                    child: TextField(
                      readOnly: true,
                      showCursor: true,
                      focusNode: _searchFocus,
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Search items',
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.blue.shade700,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.blue.shade700,
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.blue.shade300,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        fillColor: Colors.blue.shade50,
                        filled: true,
                        labelStyle: TextStyle(color: Colors.blue.shade700),
                        hintStyle: TextStyle(color: Colors.blue.shade300),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9\s]+'),
                        ),
                      ],
                      style: TextStyle(color: Colors.blue.shade900),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _handleInput(value);
                          _updateOverlay();
                        }
                      },
                      onTap: () => ActiveField.activate(
                        context: context,
                        ctrl: _controller,
                        node: _searchFocus,
                        numeric: false,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isQrMode ? Icons.qr_code_scanner : Icons.qr_code,
                    color: _isQrMode ? Colors.green : Colors.blue.shade700,
                  ),
                  onPressed: _toggleQrMode,
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
                ),
                style: const TextStyle(fontSize: 0),
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

void showQuantityDialog(
  BuildContext context,
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
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              "$varianceName ₹${price.toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
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
                      icon: const Icon(Icons.remove_circle, color: Colors.blue),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _controller,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        onChanged: (value) {
                          if (value.isEmpty) {
                            setState(() {
                              quantity = 0.0;
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
                                _controller.text = quantity.toInt().toString();
                              });
                            }
                          }
                        },
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
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancel", style: TextStyle(fontSize: 16)),
              ),
              TextButton(
                onPressed: () {
                  if (quantity > 0) {
                    Navigator.of(context).pop();
                    onAddToCart(quantity);
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  foregroundColor: Colors.blueAccent,
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
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

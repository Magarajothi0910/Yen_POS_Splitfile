import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../Global/custom_textWidgets.dart';
import '../../../../services/branchwise_item_fetch.dart';
import '../../../regular_mode_page/provider/regular_mode_screen_provider.dart';
import '../../globals.dart';
import '../../sales_order_providers/cartProvider.dart';
import 'numeric_Calculator.dart';

final FocusNode focusNode = FocusNode(); // Add FocusNode

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

  bool _isQrMode = false; // QR mode toggle
  bool _isProcessing = false; // To prevent overlapping processing
  final FocusNode _searchFocus = FocusNode();
  @override
  void initState() {
    super.initState();

    // text-change listener stays the same
    _controller.addListener(_updateOverlay);
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _controller.removeListener(_updateOverlay);
    _controller.clear(); // Clear the text controller
    _controller.dispose();
    _hiddenController.dispose(); // Dispose the hidden controller

    _removeOverlay();
    super.dispose();
  }

  void _updateOverlay() {
    final provider = Provider.of<RegularModeProvider>(context, listen: false);

    provider.filterVarianceNamesBySearchQuery(_controller.text.trim());

    if (_controller.text.isEmpty) {
      // Only remove if there’s no text
      _removeOverlay();
      return;
    }

    if (_overlayEntry == null) {
      // Show once
      _showOverlay();
    } else {
      // Just refresh UI without removing
    }
  }

  void _showOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {}
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
        behavior:
            HitTestBehavior.translucent, // Allows detection of outside taps

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
                                                .filteredVarianceNames.length) {
                                          final selectedItem = provider
                                              .getVarianceDetails(varianceName);
                                          if (selectedItem != null) {
                                            final varianceData =
                                                provider.getVarianceDetails(
                                                    varianceName);
                                            final itemName =
                                                varianceData['itemName'] ??
                                                    'Unknown Item';
                                            final varianceUOM =
                                                provider.getUOMForVariance(
                                                        varianceName) ??
                                                    'Unknown UOM';
                                            // _handleItemSelection(selectedItem,
                                            //     varianceData, varianceUOM);
                                            setState(() {
                                              // Update state variables here if needed
                                              // For example, store selected item or update UI-related variables
                                              _handleItemSelection(selectedItem,
                                                  varianceData, varianceUOM);
                                              _removeOverlay(); // Close overlay on selection
                                            });
                                            // _removeOverlay(); // Close overlay on selection
                                          } else {}
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

    // Extract data safely
    String varianceName = selectedItem['varianceName']?.toString() ?? '';
    String itemCode = selectedItem['varianceItemCode']?.toString() ??
        variancedata['varianceItemCode']?.toString() ??
        variancedata['varianceitemCode']?.toString() ??
        '';
    String itemName = variancedata['itemName']?.toString() ?? '';
    varianceUOM = varianceUOM ?? '';

    print("🧾 Selected Variance: $varianceName");
    print("📦 Selected Item Code: $itemCode");
    print("📄 Item Name: $itemName");
    print("⚖️ UOM: $varianceUOM");

    // Determine price safely
    double price = 0.0;
    final rawPrice = selectedItem['varianceDefaultPrice'] ??
        variancedata['variance_Defaultprice'];
    if (rawPrice is num) {
      price = rawPrice.toDouble();
    } else if (rawPrice is String && rawPrice.trim().isNotEmpty) {
      price = double.tryParse(rawPrice) ?? 0.0;
    }

    // Determine tax (optional fallback)
    final tax = variancedata['variancetax'] ?? 0;

    // Handle UOM types
    if (varianceUOM == 'Kgs' || varianceUOM == 'Kg') {
      showDialog(
        context: context,
        builder: (context) {
          return NumericCalculator(
            varianceName: varianceName,
            onValueSelected: (weight) {
              cartProvider.addItemToCart(CartItem(
                varianceName: varianceName,
                pricePerKg: price.toInt(),
                itemName: itemName,
                uom: varianceUOM!,
                weight: weight,
                quantity: 1,
                isBoxItem: 'no',
                tax: tax,
                itemCode: itemCode, // ✅ Correct varianceitemCode stored
                itemWiseDiscountAmount: 0.0,
                itemWiseDiscount: 0.0,
              ));
            },
          );
        },
      );
    } else {
      // For Pcs, Pkt, etc.
      cartProvider.addItemToCart(CartItem(
        varianceName: varianceName,
        pricePerKg: price.toInt(),
        itemName: itemName,
        uom: varianceUOM,
        weight: 0,
        quantity: 1,
        isBoxItem: 'no',
        tax: tax,
        itemCode: itemCode, // ✅ Correct varianceitemCode stored
        itemWiseDiscountAmount: 0.0,
        itemWiseDiscount: 0.0,
      ));
    }

    setState(() {}); // if any UI update needed
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
        focusNode.requestFocus(); // Ensure focus on the hidden field
      } else {
        focusNode.unfocus();
      }
    });
  }

  void _handleInput(String value) async {
    if (_isProcessing || !_isQrMode || value.isEmpty) return;

    setState(() {
      _isProcessing = true; // Prevent overlapping scans
    });

    try {
      // Parse the scanned data
      final Map<String, dynamic> scannedData = _parseScannedData(value);

      if (scannedData.containsKey('ItemCode')) {
        final itemCode = scannedData['ItemCode'] ?? "";
        final quantity = parseToDouble(scannedData['Qty'] ?? 1);
        final uom = scannedData['UOM'] ?? '';

        // Access the item provider and check for the item
        final itemProvider = Provider.of<ItemProvider>(context, listen: false);
        final provider =
            Provider.of<RegularModeProvider>(context, listen: false);
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
      // Clear the input field and refocus for the next scan
      _controller.clear();
      // focusNode.requestFocus();
      setState(() {
        _isProcessing = false; // Al0ow new scans
      });
    }
  }

  Map<String, dynamic> _parseScannedData(String value) {
    try {
      return json.decode(value); // Try parsing JSON
    } catch (_) {
      // Parse key-value format if not JSON
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
        _removeOverlay(); // Hide the overlay when tapped outside
        focusNode.unfocus(); // Remove focus from the text field
        _searchFocus.unfocus(); // ✅ defocus Search box
      },
      behavior: HitTestBehavior
          .translucent, // Ensures the tap is detected even on empty space
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
                      readOnly: true, // ✅ allow typing
                      showCursor: true,
                      focusNode: _searchFocus,
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Search items',
                        prefixIcon:
                            Icon(Icons.search, color: Colors.blue.shade700),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.blue.shade700, width: 2.0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.blue.shade300, width: 1.5),
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
                      // ✅ pressing enter now works properly
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _handleInput(value); // first handle value
                          _updateOverlay(); // then trigger overlay suggestion
                        }
                      },
                      onTap: () => ActiveField.activate(
                          ctrl: _controller,
                          node: _searchFocus,
                          numeric: false),
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
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 0.0), // Reduced height
                  isDense: true, // Reduces overall height
                  fillColor: Colors.transparent,
                  filled: true,
                ),
                style: const TextStyle(fontSize: 0), // Keep font size minimal
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

void showQuantityDialog(BuildContext context, String varianceName, double price,
    Function(double) onAddToCart) {
  double quantity = 1.0; // Default quantity
  final TextEditingController _controller =
      TextEditingController(text: quantity.toInt().toString());

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(
              "$varianceName   ₹${price.toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Decrement Button
                    IconButton(
                      iconSize: 40,
                      onPressed: () {
                        if (quantity > 1) {
                          setState(() {
                            quantity--;
                            _controller.text =
                                quantity.toInt().toString(); // Update TextField
                          });
                        }
                      },
                      icon: const Icon(Icons.remove_circle, color: Colors.blue),
                    ),
                    const SizedBox(width: 10),

                    // Quantity TextField
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _controller,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                        onChanged: (value) {
                          if (value.isEmpty) {
                            // If field is cleared, temporarily set quantity to 0
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
                              // Reset to 1 if invalid input
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

                    // Increment Button
                    IconButton(
                      iconSize: 40,
                      onPressed: () {
                        setState(() {
                          quantity++;
                          _controller.text =
                              quantity.toInt().toString(); // Update TextField
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: const Text("Cancel", style: TextStyle(fontSize: 16)),
              ),
              // Add to Cart Button
              TextButton(
                onPressed: () {
                  if (quantity > 0) {
                    Navigator.of(context).pop();
                    onAddToCart(quantity); // Callback to add item to cart
                  }
                  // _controller.clear();
                  // focusNode.unfocus(); // Unfocus the TextField
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  foregroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
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

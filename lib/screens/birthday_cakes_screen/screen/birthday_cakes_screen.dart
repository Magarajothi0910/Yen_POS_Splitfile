import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../Global/custom_colors.dart';
import '../../../Global/custom_textWidgets.dart';
// import '../../../Global/search_drop_filed.dart';
import '../../../services/branchwise_item_fetch.dart';
import '../../regular_mode_page/provider/cart_page_provider.dart';
import '../../regular_mode_page/provider/regular_mode_screen_provider.dart';
import '../../regular_mode_page/widget/current_sale_section.dart';
import '../../regular_mode_page/widget/favoritePage_widget.dart';
import '../../regular_mode_page/widget/mixedBox_page_widget.dart';
import '../../regular_mode_page/widget/my_grid_view.dart';
import '../../sales_order/screens/create_salesOrder.dart/search_drop_filed.dart';

class BirthdayCakesScreen extends StatefulWidget {
  const BirthdayCakesScreen({super.key});

  @override
  State<BirthdayCakesScreen> createState() => _BirthdayCakesScreenState();
}

class _BirthdayCakesScreenState extends State<BirthdayCakesScreen> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  bool _isQrMode = false; // QR mode toggle
  bool _isProcessing = false; // To prevent overlapping processing
  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _toggleQrMode() {
    setState(() {
      _isQrMode = !_isQrMode;
      if (_isQrMode) {
        _focusNode.requestFocus(); // Ensure focus on the hidden field
      } else {
        _focusNode.unfocus();
      }
    });
  }

  void _handleInput(String value) async {

    // Check conditions that would prevent processing the input
    if (_isProcessing || !_isQrMode || value.isEmpty) {
      return;
    }

    // Indicate that processing has begun
    setState(() {
      _isProcessing = true; // Prevent overlapping scans
    });

    try {
      // Parse the scanned data
      final Map<String, dynamic> scannedData = _parseScannedData(value);

      if (scannedData.containsKey('ItemCode')) {
        final itemCode = scannedData['ItemCode'];
        final quantity = scannedData['Qty'] ?? 1;
        final uom = scannedData['UOM'] ?? '';

        // Access the item provider and check for the item
        final itemProvider = Provider.of<ItemProvider>(context, listen: false);
        final result = itemProvider.checkVarianceItemCode(itemCode);

        if (result.isNotEmpty) {
          final saleProvider =
              Provider.of<CurrentSaleProvider>(context, listen: false);
          final itemData = result.first;

          // Add the item to the cart
          saleProvider.addItemToCart({
            ...itemData,
            'quantity': parseToDouble(quantity),
            'uom': uom,
          });

          // Provide feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Item added to cart: ${itemData['varianceData']['varianceName']}"),
              duration: const Duration(milliseconds: 500),
            ),
          );
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
      _textController.clear();
      _focusNode.requestFocus();
      setState(() {
        _isProcessing = false; // Allow new scans
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

// today date funtion i want to use this function in my code
  String getTodayDate() {
    final DateTime now = DateTime.now();
    final String formattedDate = "${now.day}-${now.month}-${now.year}";
    return formattedDate;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegularModeProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SafeArea(
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                Consumer<RegularModeProvider>(
                  builder: (context, provider, child) {
                    // Delay calling updateItemsForSelectedCategory until after the current build phase
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      provider.updateItemsForSelectedCategory();
                    });

                    return Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: GestureDetector(
                                  onHorizontalDragEnd:
                                      (DragEndDetails details) {
                                    if (details.primaryVelocity! < 0) {
                                      // User swiped Left
                                      provider.changeCategory(
                                          1); // Move to next category
                                    } else if (details.primaryVelocity! > 0) {
                                      // User swiped Right
                                      provider.changeCategory(
                                          -1); // Move to previous category
                                    }
                                  },
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16.0),
                                                child: Column(
                                                  children: [
                                                    SearchDropdown(),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.qr_code_scanner,
                                                      size: 32,
                                                      color: _isQrMode
                                                          ? Colors.green
                                                          : Colors.grey,
                                                    ),
                                                    onPressed: _toggleQrMode,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: SingleChildScrollView(
                                                controller:
                                                    provider.scrollController,
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  children: [
                                                    // TextButton(
                                                    //   onPressed: () {
                                                    //     provider
                                                    //         .setFavorite(true);
                                                    //   },
                                                    //   child: const Text(
                                                    //     "Favorite",
                                                    //     style: TextStyle(
                                                    //         fontSize: 18,
                                                    //         color: Colors
                                                    //             .lightBlue),
                                                    //   ),
                                                    // ),
                                                    // TextButton(
                                                    //   onPressed: () {
                                                    //     provider.setMixed(
                                                    //         true); // Set Mixed as selected
                                                    //   },
                                                    //   child: const Text(
                                                    //     "Mixed",
                                                    //     style: TextStyle(
                                                    //         fontSize: 18,
                                                    //         color: Colors
                                                    //             .lightBlue),
                                                    //   ),
                                                    // ),
                                                    ...provider.categories
                                                        .map((category) {
                                                      return TextButton(
                                                        onPressed: () {
                                                          provider
                                                              .filterItemsByCategory(
                                                                  category);
                                                          provider
                                                              .updateItemsForSelectedCategory();
                                                        },
                                                        style: ButtonStyle(
                                                          shape:
                                                              const WidgetStatePropertyAll(
                                                            RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .all(Radius
                                                                          .circular(
                                                                              5)),
                                                            ),
                                                          ),
                                                          backgroundColor:
                                                              WidgetStateProperty
                                                                  .resolveWith<
                                                                      Color>(
                                                            (Set<WidgetState>
                                                                states) {
                                                              return category ==
                                                                      provider
                                                                          .selectedCategory
                                                                  ? const Color
                                                                      .fromARGB(
                                                                      255,
                                                                      4,
                                                                      170,
                                                                      247)
                                                                  : Colors
                                                                      .white;
                                                            },
                                                          ),
                                                          foregroundColor:
                                                              WidgetStateProperty
                                                                  .resolveWith<
                                                                      Color>(
                                                            (Set<WidgetState>
                                                                states) {
                                                              return category ==
                                                                      provider
                                                                          .selectedCategory
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black;
                                                            },
                                                          ),
                                                        ),
                                                        child: CustomText(
                                                          text: category,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 18,
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
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 12),
                                            child: Text(
                                              "${getTodayDate()}",
                                              style: TextStyle(fontSize: 15),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: RepaintBoundary(
                                          child: provider.isLoading
                                              ? const Center(
                                                  child:
                                                      CircularProgressIndicator())
                                              : provider.isFavoriteSelected
                                                  ? const FavoritePageWidget() // Show Favorite page if selected
                                                  : provider.isMixedSelected
                                                      ? const MixedboxPageWidget() // Show Mixed page if selected
                                                      : MyCakesGridView(
                                                          items: provider
                                                              .items), // Otherwise, show grid view
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              const Expanded(
                                flex: 1,
                                child: RepaintBoundary(
                                    child: CurrentSaleSection()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Container(
                  width: 0,
                  height: 0, // Width and height of the hidden field
                  child: TextField(
                    focusNode: _focusNode,
                    controller: _textController,
                    keyboardType: TextInputType.none, // Prevent system keyboard
                    onSubmitted: _handleInput,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 0), // Invisible
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: _isQrMode
                      ? Column(
                          children: [
                            SizedBox(
                              width: 0,
                              height: 0, // Width of the custom keyboard
                              child: CustomKeyboard(
                                onTextInput: _handleInput,
                                onBackspace: () {},
                                onClose: () {
                                  setState(() {
                                    _isQrMode = false; // Close keyboard
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Keyboard Widget
class CustomKeyboard extends StatefulWidget {
  final Function(String) onTextInput;
  final Function onBackspace;
  final Function onClose;

  const CustomKeyboard({
    required this.onTextInput,
    required this.onBackspace,
    required this.onClose,
    super.key,
  });

  @override
  _CustomKeyboardState createState() => _CustomKeyboardState();
}

class _CustomKeyboardState extends State<CustomKeyboard> {
  bool _isUppercase = true;

  void _toggleCase() {
    setState(() {
      _isUppercase = !_isUppercase;
    });
  }

  void _textInputHandler(String text) => widget.onTextInput.call(text);

  void _backspaceHandler() => widget.onBackspace.call();

  void _closeHandler() => widget.onClose.call();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 220,
      color: CustomColors.whiteColor,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Expanded(
            child: _buildRow('1234567890'),
          ),
          Expanded(
            child: _buildRow('QWERTYUIOP'),
          ),
          Expanded(
            child: _buildRow('ASDFGHJKL'),
          ),
          Expanded(
            child: _buildRow('ZXCVBNM'),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildKey(
                    _isUppercase
                        ? 'Caps'
                        : 'caps', // Toggle between Caps and caps
                    _toggleCase,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _buildKey(
                    'Space',
                    () => _textInputHandler(' '),
                  ),
                ),
                Expanded(
                  child: _buildKey(
                    '.',
                    () => _textInputHandler('.'),
                  ),
                ),
                Expanded(
                  child: _buildKey(
                    '<-',
                    _backspaceHandler,
                  ),
                ),
                Expanded(
                  child: _buildKey(
                    'close',
                    _closeHandler,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: letters.split('').map((letter) {
        return Expanded(
          child: _buildKey(
            _isUppercase ? letter : letter.toLowerCase(),
            () =>
                _textInputHandler(_isUppercase ? letter : letter.toLowerCase()),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKey(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: CustomColors.whiteColor,
          border: Border.all(color: CustomColors.grey),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

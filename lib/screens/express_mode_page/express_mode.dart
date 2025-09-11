import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Global/custom_textWidgets.dart';
import '../regular_mode_page/provider/regular_mode_screen_provider.dart';

import 'dart:convert';

import '../../services/branchwise_item_fetch.dart';
import '../regular_mode_page/provider/cart_page_provider.dart';

import 'screens/curren_section_express_mode.dart'; // Assuming you have a custom color class

class ExpressModeScreen extends StatefulWidget {
  const ExpressModeScreen({Key? key}) : super(key: key);

  @override
  State<ExpressModeScreen> createState() => _ExpressModeScreenState();
}

class _ExpressModeScreenState extends State<ExpressModeScreen> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  bool _isQrMode = false; // QR mode toggle
  bool _isProcessing = false; // To prevent overlapping processing

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus(); // Focus on the text field immediately
  }

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
    if (_isProcessing || !_isQrMode || value.isEmpty) return;

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
          saleProvider.addItemToCartExpressMode({
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
            body: GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              child: Stack(
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.qr_code_scanner,
                                                size: 52,
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
                                        child: provider.isLoading
                                            ? const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              )
                                            : provider.items.isEmpty
                                                ? const Center(
                                                    child: CustomText(
                                                      text:
                                                          "Please scan the items",
                                                      style: TextStyle(
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.blueGrey,
                                                      ),
                                                    ),
                                                  )
                                                : const Center(
                                                    child: Text(
                                                      "Scan to Add items",
                                                      style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                      ),
                                      TextField(
                                        focusNode: _focusNode,
                                        controller: _textController,
                                        keyboardType: TextInputType
                                            .none, // Prevent system keyboard
                                        onSubmitted: _handleInput,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                        style: const TextStyle(
                                            fontSize: 0), // Invisible
                                      ),
                                    ],
                                  ),
                                ),
                                const VerticalDivider(width: 1),
                                const Expanded(
                                  flex: 1,
                                  child: RepaintBoundary(
                                    child: CurrentSaleSectionExpressMode(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Invisible TextField to capture QR input, but not displayed
                        ],
                      );
                    },
                  ),
                  // Custom Keyboard positioned at the bottom left corner
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: _isQrMode
                        ? SizedBox(
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
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
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
      color: Colors.white,
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
          color: Colors.white,
          border: Border.all(color: Colors.grey),
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




















// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../regular_mode_page/provider/regular_mode_screen_provider.dart';
// import '../regular_mode_page/widget/current_sale_section.dart';

// import '../../services/branchwise_item_fetch.dart';
// import '../regular_mode_page/provider/cart_page_provider.dart';
// import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';

// class ExpressModeScreen extends StatefulWidget {
//   const ExpressModeScreen({Key? key}) : super(key: key);

//   @override
//   State<ExpressModeScreen> createState() => _ExpressModeScreenState();
// }

// class _ExpressModeScreenState extends State<ExpressModeScreen> {
//   final TextEditingController _textController = TextEditingController();
//   bool _isQrMode = false; // QR mode toggle
//   bool _isProcessing = false; // To prevent overlapping processing

//   @override
//   void dispose() {
//     _textController.dispose();
//     super.dispose();
//   }

//   // Toggle QR Mode
//   void _toggleQrMode() {
//     setState(() {
//       _isQrMode = !_isQrMode;
//       _textController.clear(); // Clear text field when toggled
//     });
//   }

//   // Handle scanned input and add item to cart
//   void _handleInput(String value) async {
//     if (_isProcessing || !_isQrMode || value.isEmpty) return;

//     setState(() {
//       _isProcessing = true; // Prevent overlapping scans
//     });

//     try {
//       // Parse the scanned data
//       final Map<String, dynamic> scannedData = _parseScannedData(value);

//       if (scannedData.containsKey('ItemCode')) {
//         final itemCode = scannedData['ItemCode'];
//         final quantity = scannedData['Qty'] ?? 1;
//         final uom = scannedData['UOM'] ?? '';

//         // Access the item provider and check for the item
//         final itemProvider = Provider.of<ItemProvider>(context, listen: false);
//         final result = itemProvider.checkVarianceItemCode(itemCode);

//         if (result.isNotEmpty) {
//           final saleProvider =
//               Provider.of<CurrentSaleProvider>(context, listen: false);
//           final itemData = result.first;

//           // Add item to cart
//           saleProvider.addItemToCart({
//             ...itemData,
//             'quantity': parseToDouble(quantity),
//             'uom': uom,
//           });

//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                   "Item added: ${itemData['varianceData']['varianceName']}"),
//               duration: const Duration(milliseconds: 1500),
//             ),
//           );
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Item not found for the scanned code."),
//               duration: Duration(milliseconds: 1500),
//             ),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Invalid QR data. 'ItemCode' not found."),
//             duration: Duration(milliseconds: 1500),
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error: ${e.toString()}")),
//       );
//     } finally {
//       _textController.clear(); // Clear input
//       setState(() {
//         _isProcessing = false; // Allow new scans
//       });
//     }
//   }

//   // Parse scanned data
//   Map<String, dynamic> _parseScannedData(String value) {
//     debugPrint("Raw Scanned Data: $value");

//     // Step 1: Normalize the scanned string by removing unwanted characters, adjusting separators and spaces
//     value = value.replaceAll('Û', ''); // Remove unwanted characters
//     value = value.replaceAll('Ý', ''); // Remove unwanted characters
//     value = value.replaceAll('¼', ','); // Replace field separator if needed
//     value = value.replaceAll('º', ':'); // Replace key-value separator if needed
//     value = value.replaceAll(
//         RegExp(r'[\s]+'), ' '); // Reduce multiple spaces to single space
//     value = value.trim(); // Trim spaces from the beginning and end

//     debugPrint("Normalized Data: $value");

//     // Step 2: Initialize a map to hold the parsed data
//     final Map<String, dynamic> parsedData = {};

//     // Step 3: Process each key-value pair in the normalized string
//     value.split(',').forEach((pair) {
//       var keyValue = pair.split(':');
//       if (keyValue.length == 2) {
//         String key = keyValue[0].trim();
//         String val = keyValue[1].trim();

//         // Standardize the keys
//         if (key.toUpperCase() == "ITEM CODE") key = "ItemCode";
//         if (key.toUpperCase() == "UOM") key = "UOM";
//         if (key.toUpperCase() == "QTY") key = "Qty";
//         if (key.toUpperCase() == "ROW ID") key = "RowId";

//         // Remove all internal spaces from 'ItemCode' value
//         if (key == "ItemCode") val = val.replaceAll(' ', '');

//         // Ensure consistent casing for 'UOM'
//         if (key == "UOM") val = val == "PCS" ? "Pcs" : val;

//         // Store the cleaned key and value in the parsed data map
//         parsedData[key] = val;
//       }
//     });

//     debugPrint("Parsed Data After Cleaning: $parsedData");
//     return parsedData;
//   }

//   double parseToDouble(dynamic value) {
//     if (value is num) return value.toDouble();
//     if (value is String) return double.tryParse(value) ?? 0.0;
//     return 0.0;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) => RegularModeProvider(),
//       child: MaterialApp(
//         debugShowCheckedModeBanner: false,
//         home: SafeArea(
//           child: Scaffold(
//             appBar: AppBar(
//               title: const Text('Express Mode Screen'),
//               backgroundColor: Colors.blue,
//               leading: IconButton(
//                 icon: const Icon(Icons.arrow_back),
//                 onPressed: () {
//                   Navigator.pop(context);
//                 },
//               ),
//             ),
//             resizeToAvoidBottomInset: false,
//             backgroundColor: Colors.white,

//             // Barcode Listener for Scanning
//             body: BarcodeKeyboardListener(
//               bufferDuration:
//                   const Duration(milliseconds: 200), // Scanner input speed
//               onBarcodeScanned: (barcode) {
//                 if (_isQrMode) {
//                   _handleInput(barcode); // Process scanned data
//                 }
//               },
//               child: Stack(
//                 children: [
//                   Consumer<RegularModeProvider>(
//                     builder: (context, provider, child) {
//                       return Column(
//                         children: [
//                           Expanded(
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   flex: 2,
//                                   child: Column(
//                                     children: [
//                                       Padding(
//                                         padding: const EdgeInsets.all(8.0),
//                                         child: Row(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.spaceAround,
//                                           children: [
//                                             IconButton(
//                                               icon: Icon(
//                                                 Icons.qr_code_scanner,
//                                                 size: 32,
//                                                 color: _isQrMode
//                                                     ? Colors.green
//                                                     : Colors.grey,
//                                               ),
//                                               onPressed: _toggleQrMode,
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 const VerticalDivider(width: 1),
//                                 const Expanded(
//                                   flex: 1,
//                                   child: RepaintBoundary(
//                                     child: CurrentSaleSection(),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class ExpressModeScreen extends StatefulWidget {
//   const ExpressModeScreen({super.key});

//   @override
//   State<ExpressModeScreen> createState() => _ExpressModeScreenState();
// }

// class _ExpressModeScreenState extends State<ExpressModeScreen> {
//   final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) => RegularModeProvider(),
//       child: MaterialApp(
//         debugShowCheckedModeBanner: false,
//         home: SafeArea(
//           child: Scaffold(
//             resizeToAvoidBottomInset: false,
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
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceAround,
//                                         children: [
//                                           Expanded(
//                                             flex: 1,
//                                             child: Padding(
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 16.0),
//                                               child: SearchDropdown(),
//                                             ),
//                                           ),
// //                                          IconButton(
// //   icon: const Icon(Icons.qr_code_scanner, size: 32),
// //   onPressed: () async {
// //     Navigator.of(context).push(MaterialPageRoute(builder: (context) => ScannerView()));
// //   },
// // ),
//                                         ],
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: provider.isLoading
//                                           ? const Center(
//                                               child:
//                                                   CircularProgressIndicator(),
//                                             )
//                                           : provider.items.isEmpty
//                                               ? const Center(
//                                                   child: CustomText(
//                                                     text:
//                                                         "Please scan the items",
//                                                     style: TextStyle(
//                                                       fontSize: 24,
//                                                       fontWeight:
//                                                           FontWeight.bold,
//                                                       color: Colors.blueGrey,
//                                                     ),
//                                                   ),
//                                                 )
//                                               : Text("Scan to Add items"),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               const VerticalDivider(width: 1),
//                               const Expanded(
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
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
// import 'package:yenpos/Global/Widget/custom_textWidgets.dart';
// import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
// import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/customer_search.dart';
// import 'package:yenpos/regular_mode_page/widget/current_sale_section.dart';

// import '../regular_mode_page/provider/regular_mode_screen_provider.dart';

// import 'dart:convert';

// import '../regular_mode_page/provider/cart_page_provider.dart';

// import 'screens/curren_section_express_mode.dart'; // Assuming you have a custom color class

// class ExpressModeScreen extends StatefulWidget {
//   const ExpressModeScreen({Key? key}) : super(key: key);

//   @override
//   State<ExpressModeScreen> createState() => _ExpressModeScreenState();
// }

// class _ExpressModeScreenState extends State<ExpressModeScreen> {
//   SalesInvoiceState get prov =>
//       Provider.of<SalesInvoiceState>(context, listen: false);
//   final FocusNode _focusNode = FocusNode();
//   final TextEditingController _textController = TextEditingController();
//   final TextEditingController _controller = TextEditingController();
//   final TextEditingController customerController = TextEditingController();
//   bool _isQrMode = false; // QR mode toggle
//   bool _isProcessing = false; // To prevent overlapping processing

//   @override
//   void initState() {
//     super.initState();
//     Future.delayed(const Duration(milliseconds: 300), () {
//       if (_isQrMode) {
//         _focusNode.requestFocus();
//       }
//     });
//     _focusNode.requestFocus(); // Focus on the text field immediately

//     _keyboardControllers = [
//       _controller,
//       prov.customerNumberController];
//     _focusNodes = List.generate(
//       _keyboardControllers.length,
//       (_) => FocusNode(),
//     );
//     _currentFocusIndexNotifier = ValueNotifier<int>(0);

//     // Listen to focus changes (only once)
//     for (int i = 0; i < _focusNodes.length; i++) {
//       _focusNodes[i].addListener(() {
//         if (_focusNodes[i].hasFocus) {
//           _currentFocusIndexNotifier.value = i;
//         }
//       });
//     }

//   }

//   @override
//   void dispose() {
//     _focusNode.dispose();
//     _textController.dispose();
//     super.dispose();
//   }

//     late List<FocusNode> _focusNodes;
//     late ValueNotifier<int> _currentFocusIndexNotifier;
//     late List<TextEditingController> _keyboardControllers;
//    FocusNode _getFocusNodeForController(TextEditingController controller) {
//       int index = _keyboardControllers.indexOf(controller);
//       return index >= 0 ? _focusNodes[index] : FocusNode();
//     }

//   void _onTextInput(String text) {
//     final value = prov.customerNumberController.text;
//     final selection = prov.customerNumberController.selection;
//     final newText = value.replaceRange(selection.start, selection.end, text);
//     final cursorPosition = selection.start + text.length;
//     prov.customerNumberController.value = TextEditingValue(
//       text: newText,
//       selection: TextSelection.collapsed(offset: cursorPosition),
//     );
//   }

//   //  void _onTextInput(String text) {
//   //   final currentIndex = _currentFocusIndexNotifier.value;
//   //   final currentController = _keyboardControllers[currentIndex];

//   //   currentController.text = currentController.text + text;
//   //   currentController.selection = TextSelection.fromPosition(TextPosition(offset: currentController.text.length));

//   //   if (currentController == _controller) {
//   //    currentController.text= _controller.text;
//   //   } else {
//   //     currentController.text = prov.customerNumberController.text;
//   //   }
//   //   }

//   void _onBackspace() {
//     final value = _controller.text;
//     final selection = _controller.selection;
//     if (selection.start > 0) {
//       final newText = value.replaceRange(
//         selection.start - 1,
//         selection.start,
//         '',
//       );
//       final cursorPosition = selection.start - 1;
//       _controller.value = TextEditingValue(
//         text: newText,
//         selection: TextSelection.collapsed(offset: cursorPosition),
//       );
//     }
//   }

//   void _toggleQrMode() {
//     setState(() {
//       _isQrMode = !_isQrMode;
//       if (_isQrMode) {
//         _focusNode.requestFocus(); // Ensure focus on the hidden field
//       } else {
//         _focusNode.unfocus();
//       }
//     });
//   }

//   double parseNum(dynamic value) {
//     if (value is num) return value.toDouble();
//     if (value is String) return double.tryParse(value) ?? 0.0;
//     return 0.0;
//   }

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
//           final saleProvider = Provider.of<CurrentSaleProvider>(
//             context,
//             listen: false,
//           );
//           final itemData = result.first;

//           // Add the item to the cart
//           saleProvider.addItemToCartExpressMode({
//             ...itemData,
//             'quantity': parseToDouble(quantity),
//             'uom': uom,
//             'varianceData': {
//               ...itemData['varianceData'],
//               'variance_Defaultprice': parseToDouble(
//                 itemData['varianceData']['variance_Defaultprice'],
//               ),
//             },
//           });

//           // Provide feedback
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               backgroundColor: Colors.white,
//               content: Text(
//                 "Item added to cart: ${itemData['varianceData']['varianceName']}",
//                 style: const TextStyle(color: Colors.white),
//               ),
//               duration: const Duration(milliseconds: 500),
//             ),
//           );
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Item not found for the scanned code."),
//               duration: Duration(milliseconds: 500),
//             ),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Invalid QR data. 'ItemCode' not found."),
//             duration: Duration(milliseconds: 500),
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Error: ${e.toString()}"),
//           duration: const Duration(milliseconds: 500),
//         ),
//       );
//     } finally {
//       // Clear the input field and refocus for the next scan
//       _textController.clear();
//       _focusNode.requestFocus();
//       setState(() {
//         _isProcessing = false; // Allow new scans
//       });
//     }
//   }

//   Map<String, dynamic> _parseScannedData(String value) {
//     try {
//       return json.decode(value); // Try parsing JSON
//     } catch (_) {
//       // Parse key-value format if not JSON
//       final Map<String, dynamic> parsedData = {};
//       value.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
//         final keyValue = pair.split(':');
//         if (keyValue.length == 2) {
//           parsedData[keyValue[0].trim()] = keyValue[1].trim();
//         }
//       });
//       return parsedData;
//     }
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
//             resizeToAvoidBottomInset: false,
//             backgroundColor: Colors.white,
//             body: GestureDetector(
//               onTap: () => _focusNode.requestFocus(),
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
//                                           //mainAxisAlignment: MainAxisAlignment.spaceAround,
//                                           children: [
//                                             Expanded(
//                                               flex: 1,
//                                               child: TextField(
//                                                 readOnly: true,
//                                                 showCursor: true,
//                                                 controller: _controller,
//                                                 decoration:
//                                                     const InputDecoration(
//                                                       labelText: "Type here",
//                                                       border:
//                                                           OutlineInputBorder(),
//                                                     ),
//                                               ),
//                                             ),
//                                             Expanded(
//                                               flex: 1,
//                                               child: IconButton(
//                                                 icon: Icon(
//                                                   Icons.qr_code_scanner,
//                                                   size: 52,
//                                                   color: _isQrMode
//                                                       ? Colors.green
//                                                       : Colors.grey,
//                                                 ),
//                                                 onPressed: _toggleQrMode,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       Expanded(
//                                         child: provider.isLoading
//                                             ? const Center(
//                                                 child:
//                                                     CircularProgressIndicator(),
//                                               )
//                                             : provider.items.isEmpty
//                                             ? const Center(
//                                                 child: CustomText(
//                                                   text: "Please scan the items",
//                                                   style: TextStyle(
//                                                     fontSize: 24,
//                                                     fontWeight: FontWeight.bold,
//                                                     color: Colors.blueGrey,
//                                                   ),
//                                                 ),
//                                               )
//                                             : const Center(
//                                                 child: Text(
//                                                   "Scan to Add items",
//                                                   style: TextStyle(
//                                                     fontSize: 20,
//                                                     fontWeight: FontWeight.w600,
//                                                   ),
//                                                 ),
//                                               ),
//                                       ),

//                                       SizedBox(
//                                         width: 300,
//                                         child: Material(
//                                           elevation: 4,
//                                           shadowColor: Colors.black,
//                                           color: Colors.white,
//                                           borderRadius: BorderRadius.circular(
//                                             8,
//                                           ),
//                                           child: CustomerSearchDropdown(
//                                             customerNumberController:
//                                                 prov.customerNumberController,
//                                             focusNode:
//                                                 _getFocusNodeForController(
//                                                   prov.customerNumberController,
//                                                 ),
//                                           ),
//                                         ),
//                                       ),

//                                       TextField(
//                                         key: const Key('posScannerField'),
//                                         focusNode: _focusNode,
//                                         controller: _textController,
//                                         readOnly: true,
//                                         showCursor: false,
//                                         enableInteractiveSelection: false,
//                                         decoration: const InputDecoration(
//                                           border: InputBorder.none,
//                                         ),
//                                         style: const TextStyle(
//                                           fontSize: 1,
//                                           color: Colors.transparent,
//                                         ),
//                                         autofocus: true,

//                                         // ✅ Detect scanner "Enter" key or end of scan
//                                         onChanged: (value) {
//                                           if (value.endsWith('\n') ||
//                                               value.endsWith('\r')) {
//                                             final scannedValue = value.trim();
//                                             if (scannedValue.isNotEmpty) {
//                                               _handleInput(scannedValue);
//                                             }
//                                             _textController.clear();
//                                             Future.delayed(
//                                               const Duration(milliseconds: 100),
//                                               () {
//                                                 _focusNode
//                                                     .requestFocus(); // Refocus for continuous scanning
//                                               },
//                                             );
//                                           }
//                                         },

//                                         onSubmitted: (value) {
//                                           final scannedValue = value.trim();
//                                           if (scannedValue.isNotEmpty) {
//                                             _handleInput(scannedValue);
//                                           }
//                                           _textController.clear();
//                                           Future.delayed(
//                                             const Duration(milliseconds: 100),
//                                             () {
//                                               _focusNode.requestFocus();
//                                             },
//                                           );
//                                         },
//                                       ),

//                                       SizedBox(
//                                         height: 300,
//                                         width: 850,
//                                         // height: 0,
//                                         // width: 0,
//                                         child: CustomKeyboard(
//                                           onTextInput: _onTextInput,
//                                           onBackspace: _onBackspace,
//                                           onClose: () {},
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 const VerticalDivider(width: 1),
//                                 Expanded(
//                                   flex: 1,
//                                   child: RepaintBoundary(
//                                     child: CurrentSaleSection(),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           // Invisible TextField to capture QR input, but not displayed
//                         ],
//                       );
//                     },
//                   ),
//                   // Custom Keyboard positioned at the bottom left corner
//                   Positioned(
//                     bottom: 0,
//                     left: 0,
//                     child: _isQrMode
//                         ? SizedBox(
//                             width: 0,
//                             height: 0, // Width of the custom keyboard
//                             child: CustomKeyboard(
//                               onTextInput: _handleInput,
//                               onBackspace: () {},
//                               onClose: () {
//                                 setState(() {
//                                   _isQrMode = false; // Close keyboard
//                                 });
//                               },
//                             ),
//                           )
//                         : const SizedBox.shrink(),
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

// // Custom Keyboard Widget
// class CustomKeyboard extends StatefulWidget {
//   final Function(String) onTextInput;
//   final Function onBackspace;
//   final Function onClose;

//   const CustomKeyboard({
//     required this.onTextInput,
//     required this.onBackspace,
//     required this.onClose,
//     super.key,
//   });

//   @override
//   _CustomKeyboardState createState() => _CustomKeyboardState();
// }

// class _CustomKeyboardState extends State<CustomKeyboard> {
//   bool _isUppercase = true;

//   void _toggleCase() {
//     setState(() {
//       _isUppercase = !_isUppercase;
//     });
//   }

//   void _textInputHandler(String text) => widget.onTextInput.call(text);

//   void _backspaceHandler() => widget.onBackspace.call();

//   void _closeHandler() => widget.onClose.call();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 250,
//       height: 220,
//       color: Colors.white,
//       padding: const EdgeInsets.symmetric(vertical: 20),
//       child: Column(
//         children: [
//           Expanded(child: _buildRow('1234545490')),
//           Expanded(child: _buildRow('QWERTYUIOP')),
//           Expanded(child: _buildRow('ASDFGHJKL')),
//           Expanded(child: _buildRow('ZXCVBNM')),
//           Expanded(
//             child: Row(
//               children: [
//                 Expanded(
//                   child: _buildKey(
//                     _isUppercase
//                         ? 'Caps'
//                         : 'caps', // Toggle between Caps and caps
//                     _toggleCase,
//                   ),
//                 ),
//                 Expanded(
//                   flex: 3,
//                   child: _buildKey('Space', () => _textInputHandler(' ')),
//                 ),
//                 Expanded(child: _buildKey('.', () => _textInputHandler('.'))),
//                 Expanded(child: _buildKey('<-', _backspaceHandler)),
//                 Expanded(child: _buildKey('close', _closeHandler)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRow(String letters) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: letters.split('').map((letter) {
//         return Expanded(
//           child: _buildKey(
//             _isUppercase ? letter : letter.toLowerCase(),
//             () =>
//                 _textInputHandler(_isUppercase ? letter : letter.toLowerCase()),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildKey(String label, VoidCallback onPressed) {
//     return GestureDetector(
//       onTap: onPressed,
//       child: Container(
//         margin: const EdgeInsets.all(2),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           border: Border.all(color: Colors.grey),
//           borderRadius: BorderRadius.circular(5),
//         ),
//         child: Center(
//           child: Text(
//             label,
//             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//         ),
//       ),
//     );
//   }
// }

// express_mode_screen.dart
// express_mode_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/regular_mode_page/provider/regular_mode_screen_provider.dart';
import 'package:yenpos/regular_mode_page/provider/cart_page_provider.dart';
import 'package:yenpos/regular_mode_page/widget/current_sale_section.dart';

class ExpressModeScreen extends StatefulWidget {
  const ExpressModeScreen({Key? key}) : super(key: key);
  @override
  State<ExpressModeScreen> createState() => _ExpressModeScreenState();
}

class _ExpressModeScreenState extends State<ExpressModeScreen> {
  // ──────────────────────────────────────────────────────────────
  //  Hidden scanner field (always focused, off-screen)
  // ──────────────────────────────────────────────────────────────
  final FocusNode _scannerFocus = FocusNode();
  final TextEditingController _scannerController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Keep focus forever
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scannerFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scannerFocus.dispose();
    _scannerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  //  Beep sound (optional but nice)
  // ──────────────────────────────────────────────────────────────
  Future<void> _playBeep() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('beep.mp3'));
    } catch (e) {
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Parse QR / barcode
  // ──────────────────────────────────────────────────────────────
  Map<String, dynamic> _parse(String raw) {
    try {
      return json.decode(raw);
    } catch (_) {
      final map = <String, dynamic>{};
      raw.replaceAll('{', '').replaceAll('}', '').split(',').forEach((pair) {
        final kv = pair.split(':');
        if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
      });
      return map;
    }
  }

  double _toDouble(dynamic v) =>
      (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0);

  // ──────────────────────────────────────────────────────────────
  //  Main scan handler
  // ──────────────────────────────────────────────────────────────
  // Future<void> _handleScan(String raw) async {
  //   if (_isProcessing || raw.isEmpty) return;
  //   setState(() => _isProcessing = true);

  //   await _playBeep();

  //   try {
  //     final data = _parse(raw);
  //     if (!data.containsKey('ItemCode')) {
  //       _snack('Invalid QR – no ItemCode');
  //       return;
  //     }

  //     final itemCode = data['ItemCode'];
  //     final qty = data['Qty'] ?? 1;
  //     final uom = data['UOM'] ?? '';

  //     final itemProvider = Provider.of<ItemProvider>(context, listen: false);
  //     final matches = itemProvider.checkVarianceItemCode(itemCode);

  //     if (matches.isEmpty) {
  //       _snack('Item not found: $itemCode');
  //       return;
  //     }

  //     final item = matches.first;
  //     final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);

  //     saleProvider.addItemToCartExpressMode({
  //       ...item,
  //       'quantity': _toDouble(qty),
  //       'uom': uom,
  //       'varianceData': {
  //         ...item['varianceData'],
  //         'variance_Defaultprice': _toDouble(item['varianceData']['variance_Defaultprice']),
  //       },
  //     });

  //     _snack('Added: ${item['varianceData']['varianceName']} × ${_toDouble(qty)}');
  //   } catch (e) {
  //     _snack('Error: $e');
  //   } finally {
  //     _scannerController.clear();
  //     _scannerFocus.requestFocus();
  //     setState(() => _isProcessing = false);
  //   }
  // }

  Future<void> _handleScan(String raw) async {
    if (_isProcessing || raw.isEmpty) return;
    setState(() => _isProcessing = true);

    await _playBeep();

    try {
      final data = _parse(raw);
      if (!data.containsKey('ItemCode')) {
        _snack('Invalid QR – no ItemCode');
        return;
      }

      final itemCode = data['ItemCode'];
      final qty = data['Qty'] ?? 1;
      final uom = data['UOM'] ?? '';

      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      final matches = await itemProvider.checkVarianceItemCode(
        itemCode,
        aliasname,
      );

      if (matches.isEmpty) {
        _snack('Item not found: $itemCode');
        return;
      }

      final item = matches.first;

      // ─────────────────────────────────────────────
      // ⭐ STOCK VALIDATION HERE ⭐
      // ─────────────────────────────────────────────
      final stock = _toDouble(item['varianceData']['variance_Stock'] ?? 0);

      if (stock <= 0) {
        _snack('Out of Stock: ${item['varianceData']['varianceName']}');
        return;
      }

      if (_toDouble(qty) > stock) {
        _snack('Only $stock available, but scanned qty = ${_toDouble(qty)}');
        return;
      }
      // ─────────────────────────────────────────────

      final saleProvider = Provider.of<CurrentSaleProvider>(
        context,
        listen: false,
      );

      saleProvider.addItemToCartExpressMode({
        ...item,
        'quantity': _toDouble(qty),
        'uom': uom,
        'varianceData': {
          ...item['varianceData'],
          'variance_Defaultprice': _toDouble(
            item['varianceData']['variance_Defaultprice'],
          ),
        },
      });

      _snack(
        'Added: ${item['varianceData']['varianceName']} × ${_toDouble(qty)}',
      );
    } catch (e) {
      _snack('Error: $e');
    } finally {
      _scannerController.clear();
      _scannerFocus.requestFocus();
      setState(() => _isProcessing = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  UI
  // ──────────────────────────────────────────────────────────────
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
              // Keep scanner focused when user taps anywhere
              onTap: () => _scannerFocus.requestFocus(),
              child: Stack(
                children: [
                  // ───── MAIN LAYOUT ─────
                  Consumer<RegularModeProvider>(
                    builder: (context, provider, _) {
                      return Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                // ─── LEFT PANEL ───
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 16),

                                      // Loading / Empty
                                      Expanded(
                                        child: provider.isLoading
                                            ? const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              )
                                            : provider.items.isEmpty
                                            ? const Center(
                                                child: CustomText(
                                                  text: "Please scan the items",
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                              )
                                            : const Center(
                                                child: Text(
                                                  "Scan to add items",
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),

                                const VerticalDivider(width: 1),

                                // ─── RIGHT PANEL (CART) ───
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

                  // ───── HIDDEN SCANNER FIELD (OFF-SCREEN) ─────
                  Positioned(
                    left: -100,
                    top: -100,
                    child: Opacity(
                      opacity: 0,
                      child: SizedBox(
                        width: 1,
                        height: 1,
                        child: TextField(
                          key: const Key('expressScannerField'),
                          controller: _scannerController,
                          focusNode: _scannerFocus,
                          autofocus: true,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          // ←←← IMPORTANT: allow real keyboard (USB scanner)
                          keyboardType: TextInputType.none,
                          style: const TextStyle(
                            fontSize: 1,
                            color: Colors.transparent,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),

                          // Most USB scanners send Enter → onSubmitted
                          onSubmitted: (v) => _handleScan(v.trim()),

                          // Fallback: some send \n inside the string
                          onChanged: (v) {
                            if (v.contains('\n') || v.contains('\r')) {
                              final clean = v
                                  .replaceAll(RegExp(r'[\n\r]'), '')
                                  .trim();
                              if (clean.isNotEmpty) _handleScan(clean);
                              _scannerController.clear();
                            }
                          },
                        ),
                      ),
                    ),
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

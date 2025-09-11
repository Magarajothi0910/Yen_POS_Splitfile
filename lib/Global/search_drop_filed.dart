// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:yenposapp/Global/custom_textWidgets.dart';
// import '../screens/regular_mode_page/provider/cart_page_provider.dart';
// import '../screens/regular_mode_page/provider/regular_mode_screen_provider.dart';
// import '../screens/regular_mode_page/widget/variance_dialog.dart';

// final FocusNode focusNode = FocusNode(); // Add FocusNode

// class Debouncer {
//   final int milliseconds;
//   Timer? _timer;

//   Debouncer({this.milliseconds = 300});

//   void run(VoidCallback action) {
//     _timer?.cancel();
//     _timer = Timer(Duration(milliseconds: milliseconds), action);
//   }

//   void dispose() {
//     _timer?.cancel();
//   }
// }

// class SearchDropdown extends StatefulWidget {
//   const SearchDropdown({Key? key}) : super(key: key);

//   @override
//   _SearchDropdownState createState() => _SearchDropdownState();
// }

// class _SearchDropdownState extends State<SearchDropdown> {
//   final TextEditingController _controller = TextEditingController();
//   OverlayEntry? _overlayEntry;
//   final LayerLink _layerLink = LayerLink();
//   final Debouncer debouncer = Debouncer(milliseconds: 300);

//   @override
//   void initState() {
//     super.initState();
//     _controller.addListener(_updateOverlay);
//   }

//   @override
//   void dispose() {
//     print("SearchDropdown dispose called");

//     _controller.removeListener(_updateOverlay);
//     _controller.clear(); // Clear the text controller
//     _controller.dispose();

//     debouncer.dispose(); // Dispose the debouncer
//     _overlayEntry?.remove();
//     _overlayEntry = null;

//     super.dispose();
//   }

//   void _updateOverlay() {
//     final provider = Provider.of<RegularModeProvider>(context, listen: false);

//     debouncer.run(() {
//       provider.filterVarianceNamesBySearchQuery(_controller.text);

//       if (_controller.text.isNotEmpty && _overlayEntry == null) {
//         _overlayEntry = _createOverlayEntry();
//         Overlay.of(context).insert(_overlayEntry!);
//       } else if (_controller.text.isEmpty) {
//         _removeOverlay();
//       } else {
//         _overlayEntry?.markNeedsBuild();
//       }
//     });
//   }

//   void _removeOverlay() {
//     _overlayEntry?.remove();
//     _overlayEntry = null;
//   }

//   OverlayEntry _createOverlayEntry() {
//     RenderBox renderBox = context.findRenderObject() as RenderBox;
//     var size = renderBox.size;

//     return OverlayEntry(
//       builder: (context) => Positioned(
//         width: size.width,
//         child: CompositedTransformFollower(
//           link: _layerLink,
//           showWhenUnlinked: false,
//           offset: Offset(0, size.height + 5.0),
//           child: Material(
//             elevation: 8.0,
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             child: Consumer<RegularModeProvider>(
//               builder: (_, provider, __) => Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.blue.shade100.withOpacity(0.8),
//                       blurRadius: 8,
//                       offset: Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 constraints: BoxConstraints(maxHeight: 300),
//                 child: ListView.builder(
//                   padding: EdgeInsets.zero,
//                   itemCount: provider.filteredVarianceNames.length,
//                   itemBuilder: (_, index) {
//                     final varianceName = provider.filteredVarianceNames[index];
//                     // final varianceUOM =
//                     //     provider.getUOMForVariance(varianceName);

//                     return ListTile(
//                         title: CustomText(
//                           text: varianceName,
//                           style: TextStyle(
//                             color: Colors.blue.shade700,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         hoverColor: Colors.blue.shade50,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         onTap: () {
//                           final currentSaleProvider =
//                               Provider.of<CurrentSaleProvider>(context,
//                                   listen: false);

//                           final itemData =
//                               provider.getItemDataForVariance(varianceName);
//                           final varianceData =
//                               provider.getVarianceDetails(varianceName);

//                           final varianceUOM =
//                               provider.getUOMForVariance(varianceName);

//                           print("Tapped Variance: $varianceName");
//                           print("Retrieved UOM: $varianceUOM");

//                           if (varianceUOM.toLowerCase() == 'pcs' ||
//                               varianceUOM.toLowerCase() == 'pkt') {
//                             // Show quantity selection dialog
//                             showQuantityDialog(context, varianceName,
//                                 varianceData['varianceDefaultPrice'] ?? 0.0,
//                                 (selectedQuantity) {
//                               final cartItem = {
//                                 'itemData': {
//                                   'itemName': itemData['name'] ?? 'Unknown',
//                                   'category': itemData['category'] ?? 'Unknown',
//                                   'item_Uom':
//                                       varianceData['varianceUOM'] ?? 'Pcs',
//                                   'item_Defaultprice':
//                                       varianceData['varianceDefaultPrice'] ??
//                                           0.0,
//                                   'tax': itemData['tax'] ?? 0,
//                                 },
//                                 'varianceData': {
//                                   'varianceName':
//                                       varianceData['varianceName'] ?? '',
//                                   'variance_Defaultprice':
//                                       varianceData['varianceDefaultPrice'] ??
//                                           0.0,
//                                   'variance_Uom':
//                                       varianceData['varianceUOM'] ?? 'Pcs',
//                                   'varianceitemCode':
//                                       varianceData['varianceitemCode'] ?? '',
//                                 },
//                                 'quantity': selectedQuantity,
//                               };

//                               currentSaleProvider.addItemToCart(cartItem);
//                               print(
//                                   "Added $varianceName (${varianceData['varianceUOM']}) "
//                                   "with quantity $selectedQuantity to cart.");
//                             });
//                           } else if (varianceUOM.toLowerCase() == 'kg' ||
//                               varianceUOM.toLowerCase() == 'kgs') {
//                             // showWeightDialogforVariances(
//                             //   context,
//                             //   itemData['name'],
//                             //   varianceName,
//                             //   varianceData['varianceDefaultPrice'] ?? 0.0,
//                             //   onWeightSelected: (weight) {
//                             //     final cartItem = {
//                             //       'itemData': {
//                             //         'itemName': itemData['name'] ?? 'Unknown',
//                             //         'category':
//                             //             itemData['category'] ?? 'Unknown',
//                             //         'item_Uom':
//                             //             varianceData['varianceUOM'] ?? 'Kg',
//                             //         'item_Defaultprice':
//                             //             varianceData['varianceDefaultPrice'] ??
//                             //                 0.0,
//                             //         'tax': itemData['tax'] ?? 0,
//                             //       },
//                             //       'varianceData': {
//                             //         'varianceName':
//                             //             varianceData['varianceName'] ?? '',
//                             //         'variance_Defaultprice':
//                             //             varianceData['varianceDefaultPrice'] ??
//                             //                 0.0,
//                             //         'variance_Uom':
//                             //             varianceData['varianceUOM'] ?? 'Kg',
//                             //         'varianceitemCode':
//                             //             varianceData['varianceitemCode'] ?? '',
//                             //       },
//                             //       'quantity': weight,
//                             //     };

//                             //     currentSaleProvider.addItemToCart(cartItem);
//                             //     print(
//                             //         "Added $varianceName with weight $weight to cart.");
//                             //   },
//                             // );
//                           } else {
//                             print(
//                                 "Warning: UOM for $varianceName is unhandled: $varianceUOM");
//                           }
//                           _controller.clear();
//                           focusNode.unfocus(); // Unfocus the TextField
//                           _removeOverlay();
//                         });
//                   },
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return CompositedTransformTarget(
//       link: _layerLink,
//       child: TextField(
//         controller: _controller,
//         focusNode: focusNode,
//         decoration: InputDecoration(
//           labelText: 'Search items',
//           prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
//           focusedBorder: OutlineInputBorder(
//             borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           fillColor: Colors.blue.shade50,
//           filled: true,
//           labelStyle: TextStyle(color: Colors.blue.shade700),
//           hintStyle: TextStyle(color: Colors.blue.shade300),
//         ),
//         cursorColor: Colors.blue.shade700,
//         style: TextStyle(color: Colors.blue.shade900),
//       ),
//     );
//   }
// }

// void showQuantityDialog(BuildContext context, String varianceName, double price,
//     Function(double) onAddToCart) {
//   double quantity = 1.0; // Default quantity
//   final TextEditingController _controller =
//       TextEditingController(text: quantity.toInt().toString());

//   showDialog(
//     context: context,
//     builder: (BuildContext context) {
//       return StatefulBuilder(
//         builder: (BuildContext context, StateSetter setState) {
//           return AlertDialog(
//             title: Text(
//               "$varianceName   ₹${price.toStringAsFixed(2)}",
//               style: const TextStyle(fontWeight: FontWeight.bold),
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const SizedBox(height: 10),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     // Decrement Button
//                     IconButton(
//                       iconSize: 40,
//                       onPressed: () {
//                         if (quantity > 1) {
//                           setState(() {
//                             quantity--;
//                             _controller.text =
//                                 quantity.toInt().toString(); // Update TextField
//                           });
//                         }
//                       },
//                       icon: const Icon(Icons.remove_circle, color: Colors.blue),
//                     ),
//                     const SizedBox(width: 10),

//                     // Quantity TextField
//                     SizedBox(
//                       width: 60,
//                       child: TextField(
//                         controller: _controller,
//                         keyboardType: TextInputType.number,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                             fontSize: 22, fontWeight: FontWeight.bold),
//                         onChanged: (value) {
//                           if (value.isEmpty) {
//                             // If field is cleared, temporarily set quantity to 0
//                             setState(() {
//                               quantity = 0.0;
//                             });
//                           } else {
//                             final int? newValue = int.tryParse(value);
//                             if (newValue != null && newValue > 0) {
//                               setState(() {
//                                 quantity = newValue.toDouble();
//                               });
//                             } else {
//                               // Reset to 1 if invalid input
//                               setState(() {
//                                 quantity = 1.0;
//                                 _controller.text = quantity.toInt().toString();
//                               });
//                             }
//                           }
//                         },
//                       ),
//                     ),
//                     const SizedBox(width: 10),

//                     // Increment Button
//                     IconButton(
//                       iconSize: 40,
//                       onPressed: () {
//                         setState(() {
//                           quantity++;
//                           _controller.text =
//                               quantity.toInt().toString(); // Update TextField
//                         });
//                       },
//                       icon: const Icon(Icons.add_circle, color: Colors.blue),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 style: TextButton.styleFrom(
//                   backgroundColor: Colors.redAccent.withOpacity(0.1),
//                   foregroundColor: Colors.redAccent,
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 onPressed: () {
//                   Navigator.of(context).pop(); // Close the dialog
//                 },
//                 child: const Text("Cancel", style: TextStyle(fontSize: 16)),
//               ),
//               // Add to Cart Button
//               TextButton(
//                 onPressed: () {
//                   if (quantity > 0) {
//                     Navigator.of(context).pop();
//                     onAddToCart(quantity); // Callback to add item to cart
//                   }
//                   _controller.clear();
//                   focusNode.unfocus(); // Unfocus the TextField
//                 },
//                 style: TextButton.styleFrom(
//                   backgroundColor: Colors.blueAccent.withOpacity(0.1),
//                   foregroundColor: Colors.blueAccent,
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: const Text(
//                   'Add to Cart',
//                   style: TextStyle(fontSize: 16),
//                 ),
//               ),
//             ],
//           );
//         },
//       );
//     },
//   );
// }

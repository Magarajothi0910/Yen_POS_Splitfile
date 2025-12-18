// // lib/Sale_order/Screens/cart_item_tile.dart

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:yenpos/Global/globals_data.dart';
// import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
// import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
// import 'package:yenpos/Sale_order/Provider/discount_manager.dart';
// import 'package:yenpos/Sale_order/Provider/quantity_manager.dart';
// import 'package:yenpos/Sale_order/Provider/saleorder_ui_provider.dart';
// import 'package:yenpos/Sale_order/Provider/sales_order_ui_provider.dart';
// import 'package:yenpos/Sale_order/Widgets/numeric_Calculator.dart';
// import 'package:yenpos/Sale_order/Widgets/saleorder_widget/create_order_widgets.dart';
// import 'package:yenpos/Sale_order/Widgets/sales_order_widgets.dart';
// import 'package:yenpos/Sale_order/Widgets/top_message.dart';

// class CartItemTile extends StatelessWidget {
//   final dynamic item;
//   final String itemKey;
//   final int originalIndex;

//   const CartItemTile({
//     Key? key,
//     required this.item,
//     required this.itemKey,
//     required this.originalIndex,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final cartProvider = Provider.of<CartProvider>(context, listen: false);
//     final uiProvider = Provider.of<SalesOrderUIProvider>(
//       context,
//       listen: false,
//     );

//     return Dismissible(
//       key: Key(itemKey),
//       onDismissed: (direction) {
//         cartProvider.removeItemFromCart(originalIndex);
//         uiProvider.removeItemControllers(itemKey);
//       },
//       background: Container(
//         decoration: BoxDecoration(
//           color: Colors.red,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         alignment: Alignment.centerRight,
//         padding: const EdgeInsets.symmetric(horizontal: 20.0),
//         child: const Icon(Icons.delete, color: Colors.white, size: 28),
//       ),
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.1),
//               spreadRadius: 2,
//               blurRadius: 8,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: _buildCartItemContent(context),
//       ),
//     );
//   }

//   Widget _buildCartItemContent(BuildContext context) {
//     final selectionProvider = Provider.of<CartSelectionProvider>(context);
//     final quantityManager = Provider.of<QuantityManager>(
//       context,
//       listen: false,
//     );

//     return GestureDetector(
//       onTap: () {
//         if (item.uom == 'Kgs' || item.uom == 'Kg') {
//           showDialog(
//             context: context,
//             builder: (context) => NumericCalculator(
//               varianceName: item.varianceName,
//               onValueSelected: (double newValue) {
//                 quantityManager.updateItemWeight(originalIndex, newValue);
//               },
//             ),
//           );
//         }
//       },
//       child: Padding(
//         padding: const EdgeInsets.all(12.0),
//         child: Row(
//           children: [
//             if (selectionProvider.showCheckBoxes)
//               _buildCheckbox(context, selectionProvider),
//             const SizedBox(width: 6),
//             Expanded(child: _buildItemDetails()),
//             if (!selectionProvider.showCheckBoxes &&
//                     (selectionProvider.itemSelectionState[itemKey] ?? false) ||
//                 (selectionProvider.showCheckBoxes &&
//                     !(selectionProvider.itemSelectionState[itemKey] ?? false)))
//               _buildDiscountField(context),
//             _buildItemPriceAndControls(context),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCheckbox(
//     BuildContext context,
//     CartSelectionProvider selectionProvider,
//   ) {
//     final uiProvider = Provider.of<SalesOrderUIProvider>(
//       context,
//       listen: false,
//     );
//     final discountManager = Provider.of<DiscountManager>(
//       context,
//       listen: false,
//     );
//     final quantityManager = Provider.of<QuantityManager>(
//       context,
//       listen: false,
//     );

//     return Checkbox(
//       value: selectionProvider.itemSelectionState[itemKey] ?? false,
//       onChanged: (bool? value) {
//         selectionProvider.toggleItemSelection(itemKey, value ?? false);

//         if (value == true) {
//           item.isBoxItem = 'yes';
//           item.itemWiseDiscount = 0.0;
//           item.itemWiseDiscountAmount = 0.0;

//           if (uiProvider.allBoxQtyController.text.isNotEmpty) {
//             quantityManager.applyBulkBoxQtyUpdate(
//               uiProvider.allBoxQtyController.text,
//               selectionProvider.itemSelectionState,
//               (discountValue) => discountManager.applyBulkDiscount(
//                 discountValue,
//                 selectionProvider.itemSelectionState,
//                 uiProvider.discountControllers,
//               ),
//               uiProvider.bulkDiscountController.text,
//             );
//           }
//           if (uiProvider.bulkDiscountController.text.isNotEmpty) {
//             discountManager.applyBulkDiscount(
//               uiProvider.bulkDiscountController.text,
//               selectionProvider.itemSelectionState,
//               uiProvider.discountControllers,
//             );
//           }
//         } else {
//           item.isBoxItem = 'no';
//           item.itemWiseDiscount = 0.0;
//           item.itemWiseDiscountAmount = 0.0;
//           uiProvider.discountControllers[itemKey]?.clear();
//         }
//       },
//     );
//   }

//   Widget _buildItemDetails() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           item.varianceName,
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 15,
//             color: Colors.black87,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           SalesOrderWidgets.getItemPriceDescription(item),
//           style: const TextStyle(fontSize: 13, color: Colors.grey),
//         ),
//       ],
//     );
//   }

//   Widget _buildDiscountField(BuildContext context) {
//     final uiProvider = Provider.of<SalesOrderUIProvider>(
//       context,
//       listen: false,
//     );
//     final discountManager = Provider.of<DiscountManager>(
//       context,
//       listen: false,
//     );

//     if (!uiProvider.discountControllers.containsKey(itemKey)) {
//       uiProvider.initializeItemControllers(itemKey);
//     }

//     final ctrl = uiProvider.discountControllers[itemKey]!;
//     final node = uiProvider.discountFocusNodes[itemKey]!;

//     return SizedBox(
//       width: 130,
//       child: TextFormField(
//         showCursor: true,
//         readOnly: true,
//         controller: ctrl,
//         focusNode: node,
//         decoration: InputDecoration(
//           labelText: 'Discount%',
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12.0),
//             borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12.0),
//             borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12.0),
//             borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
//           ),
//           filled: true,
//           fillColor: Colors.blue.shade50,
//           contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
//           labelStyle: TextStyle(color: Colors.blue.shade700, fontSize: 11),
//           suffixIcon: Icon(Icons.percent, size: 17),
//         ),
//         onTap: () {
//           ActiveField.activate(
//             context: context,
//             ctrl: ctrl,
//             node: node,
//             numeric: true,
//             discount: true,
//             fieldType: "discount",
//             onChanged: (value) {
//               if (uiProvider.isInternalUpdate) return;

//               uiProvider.isInternalUpdate = true;

//               if (value.isEmpty) {
//                 ctrl.clear();
//                 discountManager.applySingleItemDiscount(
//                   itemKey,
//                   '',
//                   uiProvider.discountControllers,
//                 );
//                 uiProvider.isInternalUpdate = false;
//                 return;
//               }

//               final discount = double.tryParse(value);
//               if (discount == null || discount <= 0 || discount > 100) {
//                 ctrl.clear();
//                 discountManager.applySingleItemDiscount(
//                   itemKey,
//                   '',
//                   uiProvider.discountControllers,
//                 );
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text("Discount must be between 1 and 100"),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//               } else {
//                 discountManager.applySingleItemDiscount(
//                   itemKey,
//                   value,
//                   uiProvider.discountControllers,
//                 );
//               }

//               uiProvider.isInternalUpdate = false;
//             },
//           );
//         },
//         keyboardType: TextInputType.numberWithOptions(decimal: true),
//       ),
//     );
//   }

//   Widget _buildItemPriceAndControls(BuildContext context) {
//     final selectionProvider = Provider.of<CartSelectionProvider>(context);

//     int originalPrice =
//         ((item.uom == 'Kg' || item.uom == 'Kgs')
//                 ? (item.quantity.value * item.pricePerKg * item.weight)
//                 : (item.quantity.value * item.pricePerKg))
//             .toInt();

//     final discountPercent = item.itemWiseDiscount ?? 0;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.end,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.end,
//           children: [
//             if (!selectionProvider.showCheckBoxes) _buildDiscountField(context),
//             SizedBox(width: 10),
//             _buildQuantityControls(context),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             Text(
//               'Rs.${originalPrice.round()}',
//               style: TextStyle(
//                 fontSize: 11,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//                 decoration: discountPercent > 0
//                     ? TextDecoration.lineThrough
//                     : TextDecoration.none,
//               ),
//             ),
//             if (discountPercent > 0) ...[
//               Text(
//                 'Discount:  -Rs.${item.itemWiseDiscountAmount}',
//                 style: const TextStyle(fontSize: 12, color: Colors.red),
//               ),
//               Text(
//                 'Final Price: Rs.${item.finalPrice.toString()}',
//                 style: const TextStyle(
//                   fontSize: 12,
//                   color: Colors.green,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildQuantityControls(BuildContext context) {
//     final cartProvider = Provider.of<CartProvider>(context);
//     final quantityManager = Provider.of<QuantityManager>(
//       context,
//       listen: false,
//     );
//     final discountManager = Provider.of<DiscountManager>(
//       context,
//       listen: false,
//     );
//     final uiProvider = Provider.of<SalesOrderUIProvider>(
//       context,
//       listen: false,
//     );

//     return Consumer<CartProvider>(
//       builder: (context, cartProvider, _) {
//         final item = cartProvider.cartItems[originalIndex];

//         return Row(
//           children: [
//             SalesOrderWidgets.buildQuantityButton(
//               icon: Icons.remove,
//               onPressed: () {
//                 if (quantityManager.canEditQuantity(originalIndex)) {
//                   if (item.quantity.value == 1) {
//                     cartProvider.removeItemFromCart(originalIndex);
//                   } else {
//                     quantityManager.decrementQuantity(originalIndex);
//                   }

//                   final ctrl = uiProvider.discountControllers[itemKey];
//                   if (ctrl != null && ctrl.text.isNotEmpty) {
//                     discountManager.applySingleItemDiscount(
//                       itemKey,
//                       ctrl.text,
//                       uiProvider.discountControllers,
//                     );
//                   }
//                 } else {
//                   TopMessage.show(
//                     context,
//                     message:
//                         "Quantity can't be edited when box quantity is applied.",
//                     backgroundColor: Colors.redAccent,
//                   );
//                 }
//               },
//             ),
//             const SizedBox(width: 8),
//             ValueListenableBuilder(
//               valueListenable: item.quantity,
//               builder: (context, qty, _) {
//                 return GestureDetector(
//                   onTap: () {
//                     if (quantityManager.canEditQuantity(originalIndex)) {
//                       cartProvider.showQuantityDialog(
//                         context,
//                         originalIndex,
//                         qty,
//                         item.uom,
//                       );

//                       final ctrl = uiProvider.discountControllers[itemKey];
//                       if (ctrl != null && ctrl.text.isNotEmpty) {
//                         discountManager.applySingleItemDiscount(
//                           itemKey,
//                           ctrl.text,
//                           uiProvider.discountControllers,
//                         );
//                       }
//                     } else {
//                       TopMessage.show(
//                         context,
//                         message:
//                             "Quantity can't be edited when box quantity is applied.",
//                         backgroundColor: Colors.redAccent,
//                       );
//                     }
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 6,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Text(
//                       qty.toString(),
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.blue,
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//             const SizedBox(width: 8),
//             SalesOrderWidgets.buildQuantityButton(
//               icon: Icons.add,
//               onPressed: () {
//                 if (quantityManager.canEditQuantity(originalIndex)) {
//                   quantityManager.incrementQuantity(originalIndex);

//                   final ctrl = uiProvider.discountControllers[itemKey];
//                   if (ctrl != null && ctrl.text.isNotEmpty) {
//                     discountManager.applySingleItemDiscount(
//                       itemKey,
//                       ctrl.text,
//                       uiProvider.discountControllers,
//                     );
//                   }
//                 } else {
//                   TopMessage.show(
//                     context,
//                     message:
//                         "Quantity can't be edited when box quantity is applied.",
//                     backgroundColor: Colors.redAccent,
//                   );
//                 }
//                 cartProvider.calculateSubtotal();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

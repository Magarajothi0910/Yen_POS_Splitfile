// // lib/Sale_order/Screens/selected_items_box.dart

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:yen_pos/Global/globals_data.dart' as globals;
// import 'package:yen_pos/Sale_order/Provider/cartProvider.dart';
// import 'package:yen_pos/Sale_order/Provider/cart_selection_provider.dart';
// import 'package:yen_pos/Sale_order/Provider/saleorder_ui_provider.dart';
// import 'package:yen_pos/Sale_order/Widgets/saleorder_widget/cart_item_tile_widget.dart';
// import 'package:yen_pos/Sale_order/Widgets/saleorder_widget/create_order_widgets.dart';

// class SelectedItemsBox extends StatelessWidget {
//   final List<dynamic> selectedItems;

//   const SelectedItemsBox({Key? key, required this.selectedItems})
//     : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final cartProvider = Provider.of<CartProvider>(context);
//     final selectionProvider = Provider.of<CartSelectionProvider>(context);
//     final uiProvider = Provider.of<SalesOrderUIProvider>(context);
//     final discountManager = Provider.of<DiscountManager>(context);
//     final quantityManager = Provider.of<QuantityManager>(context);

//     final customCharge =
//         double.tryParse(cartProvider.customChargeController.text) ?? 0;
//     final selectedTotalAmount = discountManager.calculateSelectedTotal(
//       selectedItems,
//       customCharge,
//     );

//     return Container(
//       margin: const EdgeInsets.all(10.0),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.2),
//             spreadRadius: 2,
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//         border: Border.all(color: Colors.blue.shade100, width: 1.5),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Padding(
//             padding: EdgeInsets.only(bottom: 8.0),
//             child: Text(
//               "Selected Items",
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//           ),
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Expanded(
//                 flex: selectionProvider.showCheckBoxes ? 2 : 3,
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: selectedItems.map((item) {
//                     final key = item.varianceName;
//                     WidgetsBinding.instance.addPostFrameCallback((_) {
//                       uiProvider.initializeItemControllers(key);
//                     });
//                     final originalIndex = globals.cartItems.indexWhere(
//                       (e) => e.varianceName == item.varianceName,
//                     );
//                     return CartItemTile(
//                       item: item,
//                       itemKey: key,
//                       originalIndex: originalIndex,
//                     );
//                   }).toList(),
//                 ),
//               ),
//               if (selectionProvider.showCheckBoxes) const SizedBox(width: 12),
//               if (selectionProvider.showCheckBoxes)
//                 Expanded(
//                   flex: 1,
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       SalesOrderWidgets.buildAllBoxQtyField(
//                         context,
//                         uiProvider,
//                         (value) {
//                           quantityManager.applyBulkBoxQtyUpdate(
//                             value,
//                             selectionProvider.itemSelectionState,
//                             (discountValue) =>
//                                 discountManager.applyBulkDiscount(
//                                   discountValue,
//                                   selectionProvider.itemSelectionState,
//                                   uiProvider.discountControllers,
//                                 ),
//                             uiProvider.bulkDiscountController.text,
//                           );
//                         },
//                       ),
//                       const SizedBox(height: 10),
//                       SalesOrderWidgets.buildBulkDiscountField(
//                         context,
//                         uiProvider,
//                         (value) {
//                           discountManager.applyBulkDiscount(
//                             value,
//                             selectionProvider.itemSelectionState,
//                             uiProvider.discountControllers,
//                           );
//                         },
//                       ),
//                       const SizedBox(height: 10),
//                       Padding(
//                         padding: const EdgeInsets.only(top: 10.0),
//                         child: Text(
//                           "Total Box Amount: ₹${selectedTotalAmount.toStringAsFixed(2)}",
//                           style: TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.green[700],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

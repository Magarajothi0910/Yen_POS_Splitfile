// import 'package:flutter/material.dart';

// import '../../sales_order_providers/editcustomerscreenProvider.dart';
// import '../model/sales_order_model.dart';

// class OrderItemWidget extends StatelessWidget {
//   final SalesOrderDisplay salesOrder;
//   final int index;
//   final EditCustomerScreenProvider customerProvider;

//   const OrderItemWidget({
//     required this.salesOrder,
//     required this.index,
//     required this.customerProvider,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isKg = salesOrder.uom[index].toLowerCase() == 'kg' ||
//         salesOrder.uom[index].toLowerCase() == 'kgs';
//     final quantity = isKg
//         ? salesOrder.qty[index].toStringAsFixed(3)
//         : salesOrder.qty[index].toStringAsFixed(0);
//     final isBoxItem = salesOrder.isBoxItem != null &&
//         salesOrder.isBoxItem!.length > index &&
//         salesOrder.isBoxItem![index].toLowerCase() == "yes";

//     Map<String, dynamic>? modifiedItem;
//     bool hasIncrease = false;
//     bool hasDecrease = false;

//     if (customerProvider.isModifyMode) {
//       final increasedIndex = customerProvider.increasedItems.indexWhere(
//           (element) =>
//               element['varianceName'] == salesOrder.varianceName[index]);
//       if (increasedIndex != -1) {
//         modifiedItem = customerProvider.increasedItems[increasedIndex];
//         hasIncrease = true;
//       } else {
//         final decreasedIndex = customerProvider.decreasedItems.indexWhere(
//             (element) =>
//                 element['varianceName'] == salesOrder.varianceName[index]);
//         if (decreasedIndex != -1) {
//           modifiedItem = customerProvider.decreasedItems[decreasedIndex];
//           hasDecrease = true;
//         }
//       }
//     }

//     String newQuantityText = '';
//     String newAmountText = '';
//     Color modificationColor = Colors.green;

//     final currentQty = salesOrder.qty[index];
//     final currentWeight = isKg ? salesOrder.weight[index] : 0.0;
//     final currentAmount = salesOrder.amount[index];

//     if (modifiedItem != null) {
//       if (isKg) {
//         final modifiedWeight = modifiedItem['weight'] ?? 0.0;
//         final newWeight = hasIncrease
//             ? currentWeight + modifiedWeight
//             : currentWeight - modifiedWeight;
//         newQuantityText = newWeight.toStringAsFixed(2);
//         final modifiedAmount = modifiedItem['amount'] ?? 0.0;
//         final newAmount = hasIncrease
//             ? currentAmount + modifiedAmount
//             : currentAmount - modifiedAmount;
//         newAmountText = '₹${newAmount.toStringAsFixed(2)}';
//         modificationColor = hasIncrease ? Colors.green : Colors.red;
//       } else {
//         final modifiedQty = modifiedItem['quantity'] ?? 0.0;
//         final newQty = hasIncrease
//             ? currentQty + modifiedQty
//             : currentQty - modifiedQty;
//         newQuantityText = newQty.toStringAsFixed(0);
//         final modifiedAmount = modifiedItem['amount'] ?? 0.0;
//         final newAmount = hasIncrease
//             ? currentAmount + modifiedAmount
//             : currentAmount - modifiedAmount;
//         newAmountText = '₹${newAmount.toStringAsFixed(2)}';
//         modificationColor = hasIncrease ? Colors.green : Colors.red;
//       }
//     }

//     Map<String, dynamic> _createItemMap() {
//       return {
//         'varianceName': salesOrder.varianceName[index],
//         'itemName': salesOrder.itemName != null &&
//                 salesOrder.itemName!.length > index
//             ? salesOrder.itemName![index]
//             : salesOrder.varianceName[index],
//         'varianceUom': salesOrder.uom[index],
//         'variancePrice': salesOrder.price[index],
//         'variancetax': salesOrder.tax != null && salesOrder.tax!.length > index
//             ? salesOrder.tax![index]
//             : 0,
//         'varianceitemCode':
//             salesOrder.itemCode != null && salesOrder.itemCode!.length > index
//                 ? salesOrder.itemCode![index]
//                 : '',
//         'existingQuantity': salesOrder.qty[index],
//         'existingWeight': isKg ? salesOrder.weight[index] : 0.0,
//         'existingAmount': salesOrder.amount[index],
//       };
//     }

//     if (!customerProvider.isModifyMode) {
//       return Column(
//         children: [
//           ListTile(
//             contentPadding: EdgeInsets.zero,
//             title: Text(
//               salesOrder.varianceName[index],
//               style: TextStyle(
//                 fontSize: 11,
//                 color: isBoxItem ? Colors.blue : Colors.grey,
//                 fontWeight: isBoxItem ? FontWeight.bold : FontWeight.normal,
//               ),
//             ),
//             subtitle: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   !isKg
//                       ? '$quantity ${salesOrder.uom[index]} x ₹${salesOrder.price[index]} RS'
//                       : '${salesOrder.weight[index].toStringAsFixed(2)} ${salesOrder.uom[index]} ${salesOrder.qty[index]}qty x ₹${salesOrder.price[index]} RS',
//                   style: TextStyle(fontSize: 11, color: Colors.grey),
//                 ),
//               ],
//             ),
//             trailing: Text(
//               '₹${salesOrder.amount[index].toStringAsFixed(2)}',
//               style: TextStyle(
//                 fontSize: 11,
//                 color: isBoxItem ? Colors.blue : Colors.black,
//               ),
//             ),
//           ),
//         ],
//       );
//     }

//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 salesOrder.varianceName[index],
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                   color: isBoxItem ? Colors.blue : Colors.black,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text("Ex Qty", style: TextStyle(fontSize: 10, color: Colors.grey)),
//                       Text(
//                         isKg
//                             ? '${currentWeight.toStringAsFixed(2)} ${salesOrder.uom[index]}'
//                             : '$currentQty ${salesOrder.uom[index]}',
//                         style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
//                       ),
//                     ],
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Text("New Qty", style: TextStyle(fontSize: 10, color: Colors.grey)),
//                       Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           GestureDetector(
//                             onTap: () => _updateQuantity(1, context),
//                             child: Container(
//                               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                               decoration: BoxDecoration(
//                                 color: Colors.green.withOpacity(0.1),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Icon(Icons.add, size: 28, color: Colors.green),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           GestureDetector(
//                             onTap: () => _showQuantityDialog(context),
//                             child: Container(
//                               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                               decoration: BoxDecoration(
//                                 border: Border.all(color: Colors.grey),
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               child: Text(
//                                 _getModifiedQuantityText(),
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                   color: modificationColor,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           GestureDetector(
//                             onTap: () => _updateQuantity(-1, context),
//                             child: Container(
//                               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                               decoration: BoxDecoration(
//                                 color: Colors.red.withOpacity(0.1),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Icon(Icons.remove, size: 28, color: Colors.red),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text("Amt", style: TextStyle(fontSize: 10, color: Colors.grey)),
//                       Text(
//                         '₹${currentAmount.toStringAsFixed(2)}',
//                         style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
//                       ),
//                     ],
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Text("New Amt", style: TextStyle(fontSize: 10, color: Colors.grey)),
//                       Text(
//                         modifiedItem != null ? newAmountText : '-',
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.bold,
//                           color: modificationColor,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         const Divider(height: 1),
//       ],
//     );
//   }

//   String _getModifiedQuantityText() {
//     final isKg = salesOrder.uom[index].toLowerCase() == 'kg' ||
//         salesOrder.uom[index].toLowerCase() == 'kgs';
//     final currentValue = isKg ? salesOrder.weight[index] : salesOrder.qty[index];
    
//     if (customerProvider.isModifyMode) {
//       final modifiedItem = customerProvider.getModifiedItem(salesOrder.varianceName[index]);
//       if (modifiedItem != null) {
//         final modifiedValue = isKg ? modifiedItem['weight'] : modifiedItem['quantity'];
//         return isKg 
//             ? (modifiedItem['type'] == 'increase'
//                 ? (currentValue + modifiedValue).toStringAsFixed(2)
//                 : (currentValue - modifiedValue).toStringAsFixed(2))
//             : (modifiedItem['type'] == 'increase'
//                 ? (currentValue + modifiedValue).toStringAsFixed(0)
//                 : (currentValue - modifiedValue).toStringAsFixed(0));
//       }
//     }
//     return isKg 
//         ? currentValue.toStringAsFixed(2)
//         : currentValue.toStringAsFixed(0);
//   }

//   Future<void> _showQuantityDialog(BuildContext context) async {
//     final isKg = salesOrder.uom[index].toLowerCase() == 'kg' ||
//         salesOrder.uom[index].toLowerCase() == 'kgs';
//     final originalValue = isKg 
//         ? salesOrder.weight[index]
//         : salesOrder.qty[index].toDouble();

//     final result = await showDialog<double>(
//       context: context,
//       builder: (context) => QuantityInputDialog(
//         initialValue: isKg 
//             ? (customerProvider.getModifiedValue(index, 'weight') ?? originalValue
//             : (customerProvider.getModifiedValue(index, 'quantity') ?? originalValue),
//         isKg: isKg,
//         uom: salesOrder.uom[index],
//       ),
//     );

//     if (result != null && result >= 0) {
//       final delta = result - originalValue;
//       customerProvider.updateItemInOrder(
//         _createItemMap(),
//         delta,
//         index,
//       );
//     }
//   }

//   void _updateQuantity(int direction, BuildContext context) {
//     final isKg = salesOrder.uom[index].toLowerCase() == 'kg' ||
//         salesOrder.uom[index].toLowerCase() == 'kgs';
//     final increment = direction * (isKg ? 0.1 : 1.0);
//     final currentValue = isKg ? salesOrder.weight[index] : salesOrder.qty[index];
    
//     if (direction < 0 && currentValue + increment < 0) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Quantity cannot be negative')),
//       );
//       return;
//     }

//     customerProvider.updateItemInOrder(
//       _createItemMap(),
//       increment,
//       index,
//     );
//   }
// }

// class QuantityInputDialog extends StatelessWidget {
//   final double initialValue;
//   final bool isKg;
//   final String uom;

//   const QuantityInputDialog({
//     required this.initialValue,
//     required this.isKg,
//     required this.uom,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final controller = TextEditingController(
//       text: isKg ? initialValue.toStringAsFixed(2) : initialValue.toStringAsFixed(0),
//     );

//     return AlertDialog(
//       title: const Text('Enter Quantity'),
//       content: TextField(
//         controller: controller,
//         keyboardType: TextInputType.numberWithOptions(decimal: isKg),
//         decoration: InputDecoration(
//           suffixText: isKg ? 'kg' : uom,
//           border: const OutlineInputBorder(),
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Cancel'),
//         ),
//         TextButton(
//           onPressed: () {
//             final value = double.tryParse(controller.text);
//             if (value != null && value >= 0) {
//               Navigator.pop(context, value);
//             } else {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Please enter a valid quantity')),
//               );
//             }
//           },
//           child: const Text('OK'),
//         ),
//       ],
//     );
//   }
// }
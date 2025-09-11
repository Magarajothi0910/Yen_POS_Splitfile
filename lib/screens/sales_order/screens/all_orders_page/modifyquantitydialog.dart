// // import 'package:flutter/material.dart';

// // import '../model/sales_invoicemodel.dart';

// // class ModifyQuantityDialog extends StatefulWidget {
// //   final SalesOrderItem orderItem;

// //   ModifyQuantityDialog({required this.orderItem});

// //   @override
// //   _ModifyQuantityDialogState createState() => _ModifyQuantityDialogState();
// // }

// // class _ModifyQuantityDialogState extends State<ModifyQuantityDialog> {
// //   late int _quantity;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _quantity = widget.orderItem.qty;
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Dialog(
// //       child: Padding(
// //         padding: const EdgeInsets.all(16.0),
// //         child: Column(
// //           mainAxisSize: MainAxisSize.min,
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text('Modify Quantity for ${widget.orderItem.itemName}'),
// //             TextField(
// //               controller: TextEditingController(text: _quantity.toString()),
// //               keyboardType: TextInputType.number,
// //               decoration: InputDecoration(labelText: 'Quantity'),
// //               onChanged: (value) {
// //                 setState(() {
// //                   _quantity = int.tryParse(value) ?? _quantity;
// //                 });
// //               },
// //             ),
// //             SizedBox(height: 20),
// //             Row(
// //               mainAxisAlignment: MainAxisAlignment.end,
// //               children: [
// //                 ElevatedButton(
// //                   onPressed: () {
// //                     // Update the item quantity
// //                     Navigator.of(context).pop(_quantity);
// //                   },
// //                   child: Text('Save'),
// //                 ),
// //               ],
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }

// import 'package:flutter/material.dart';

// import '../model/sales_order_model.dart';

// class ModifiedOrderDialog extends StatefulWidget {
//   final SalesOrderDisplay salesOrder;

//   const ModifiedOrderDialog({
//     super.key,
//     required this.salesOrder,
//   });

//   @override
//   _ModifiedOrderDialogState createState() => _ModifiedOrderDialogState();
// }

// class _ModifiedOrderDialogState extends State<ModifiedOrderDialog> {
//   Map<int, double> quantityChanges = {};
//   List<Map<String, dynamic>> increasedItems = [];
//   List<Map<String, dynamic>> decreasedItems = [];

//   void _showQuantityDialog(int index, String itemName, double currentQty) {
//     TextEditingController quantityController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Modify Quantity'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text('Item: $itemName'),
//               Text('Current Quantity: $currentQty'),
//               TextField(
//                 controller: quantityController,
//                 keyboardType: TextInputType.numberWithOptions(decimal: true),
//                 decoration: InputDecoration(
//                   labelText: 'New Quantity',
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('Cancel'),
//             ),
//             TextButton(
//               onPressed: () {
//                 double? newQty = double.tryParse(quantityController.text);
//                 if (newQty != null) {
//                   setState(() {
//                     double difference = newQty - currentQty;
//                     quantityChanges[index] = difference;

//                     // Create item entry
//                     Map<String, dynamic> item = {
//                       'itemName': widget.salesOrder.itemName[index],
//                       'quantity': difference.abs(),
//                       'uom': widget.salesOrder.uom[index],
//                       'price': widget.salesOrder.price[index],
//                       'amount':
//                           difference.abs() * widget.salesOrder.price[index],
//                     };

//                     // Add to appropriate list
//                     if (difference > 0) {
//                       increasedItems.add(item);
//                     } else if (difference < 0) {
//                       decreasedItems.add(item);
//                     }
//                   });
//                 }
//                 Navigator.pop(context);
//               },
//               child: Text('Save'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       child: Container(
//         width: MediaQuery.of(context).size.width * 0.8,
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Order Modification',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 20),

//             // Increased Items Section
//             if (increasedItems.isNotEmpty) ...[
//               Text(
//                 'Order 2 (Increased Items)',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//               ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: increasedItems.length,
//                 itemBuilder: (context, index) {
//                   final item = increasedItems[index];
//                   return ListTile(
//                     title: Text(item['itemName']),
//                     subtitle: Text(
//                       '${item['quantity']} ${item['uom']} x ₹${item['price']}',
//                     ),
//                     trailing: Text('₹${item['amount'].toStringAsFixed(2)}'),
//                   );
//                 },
//               ),
//               Divider(),
//             ],

//             // Decreased Items Section
//             if (decreasedItems.isNotEmpty) ...[
//               Text(
//                 'Decreased Items',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//               ListView.builder(
//                 shrinkWrap: true,
//                 itemCount: decreasedItems.length,
//                 itemBuilder: (context, index) {
//                   final item = decreasedItems[index];
//                   return ListTile(
//                     title: Text(item['itemName']),
//                     subtitle: Text(
//                       '${item['quantity']} ${item['uom']} x ₹${item['price']}',
//                     ),
//                     trailing: Text('-₹${item['amount'].toStringAsFixed(2)}'),
//                   );
//                 },
//               ),
//               Divider(),
//             ],

//             // Original Order Items
//             Text(
//               'Original Order',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: widget.salesOrder.itemName.length,
//                 itemBuilder: (context, index) {
//                   return InkWell(
//                     onTap: () => _showQuantityDialog(
//                       index,
//                       widget.salesOrder.itemName[index],
//                       widget.salesOrder.qty[index].toDouble(),
//                     ),
//                     child: ListTile(
//                       title: Text(widget.salesOrder.itemName[index]),
//                       subtitle: Text(
//                         '${widget.salesOrder.qty[index]} ${widget.salesOrder.uom[index]} x ₹${widget.salesOrder.price[index]}',
//                       ),
//                       trailing: Text(
//                         '₹${widget.salesOrder.amount[index].toStringAsFixed(2)}',
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),

//             // Action Buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text('Cancel'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     // Handle save modifications
//                     // You'll need to implement the logic to save these changes
//                     Navigator.pop(context, {
//                       'increasedItems': increasedItems,
//                       'decreasedItems': decreasedItems,
//                       'quantityChanges': quantityChanges,
//                     });
//                   },
//                   child: Text('Save Changes'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

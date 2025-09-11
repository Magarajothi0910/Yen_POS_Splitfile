// import 'package:flutter/material.dart';
// import 'package:server/handlers/ItemWiseCancel.dart';
// import '/providers/printer_provider.dart';
// import 'package:provider/provider.dart';
// import '../providers/order_provider.dart';

// import 'CancellationReceipt.dart';

// class CancellationHandler {
//   static Future<void> handleCancelAll(
//       BuildContext context, List<Map<String, dynamic>> seatOrders) async {
//     TextEditingController remarkController1 = TextEditingController();
//     final confirm = await showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Column(
//             children: [
//               Text('Cancel All Items?'),
//               SizedBox(height: 10),
//               Text(
//                 'Are you sure you want to cancel all items for  ?',
//                 style: TextStyle(fontSize: 15),
//               )
//             ],
//           ),
//           content: SizedBox(
//             width: 300,
//             child: TextField(
//               controller: remarkController1,
//               decoration: const InputDecoration(
//                 hintText: 'Reason for Cancellation',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ),
//           actions: [
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//               onPressed: () => Navigator.of(context).pop(true),
//               child: const Text('Yes', style: TextStyle(color: Colors.white)),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//               onPressed: () => Navigator.of(context).pop(false),
//               child: const Text('No', style: TextStyle(color: Colors.white)),
//             ),
//           ],
//         );
//       },
//     );

//     if (confirm == true) {
//       final orderProvider = Provider.of<OrderProvider>(context, listen: false);
//       final printerProvider =
//           Provider.of<PrinterProvider>(context, listen: false);

//       // Print cancellation receipt
//       print("Preparing to print cancel receipt...");
//       await CancelPrinterService.printUniversalReceipt(
//         ipAddress: printerProvider
//             .getPrinterIpForItem(
//                 seatOrders.first['varianceNames'].first.toString())
//             .toString(),
//         tableNumber: seatOrders.first['table'],
//         seat: seatOrders.first['seat'],
//         userName: seatOrders.first['captain'] ?? "",
//         waiter: seatOrders.first['waiter'] ?? "",
//         seatOrders: seatOrders,
//         receiptType: "Full Order Cancelled",
//       );
//     }
//   }

//   // static Future<void> handleEditQuantitys(
//   //   BuildContext context,
//   //   Map<String, dynamic> order,
//   //   int index,
//   //   List<double> quantities,
//   //   List<double?> cancelledQty, // Changed to allow nullable values
//   //   List<String> itemRemark,
//   //   String partiallyCancelled,
//   //   String userName,
//   // ) async {
//   //   print("handleEditQuantitys...");

//   //   // Ensure list size matches the required index
//   //   while (cancelledQty.length <= index) {
//   //     cancelledQty.add(0.0);
//   //   }

//   //   while (itemRemark.length <= index) {
//   //     itemRemark.add("");
//   //   }

//   //   // Handle null values in cancelledQty
//   //   double initialCancelledQty = cancelledQty[index] ?? 0.0;

//   //   TextEditingController cancelledQtyController = TextEditingController(
//   //     text: initialCancelledQty.toInt().toString(),
//   //   );

//   //   TextEditingController remarkController2 = TextEditingController(
//   //     text: itemRemark[index],
//   //   );

//   //   print("handleEditQuantitys1...");

//   //   await showDialog(
//   //     context: context,
//   //     builder: (context) {
//   //       return AlertDialog(
//   //         title: const Text('Edit Quantity'),
//   //         content: Column(
//   //           mainAxisSize: MainAxisSize.min,
//   //           children: [
//   //             TextFormField(
//   //               initialValue: order['varianceNames'][index],
//   //               decoration: const InputDecoration(
//   //                 labelText: 'Item Name',
//   //                 border: OutlineInputBorder(),
//   //               ),
//   //               enabled: false,
//   //             ),
//   //             const SizedBox(height: 10),
//   //             Row(
//   //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   //               children: [
//   //                 SizedBox(
//   //                   width: 100,
//   //                   child: TextField(
//   //                     enabled: false,
//   //                     controller: TextEditingController(
//   //                       text: quantities[index].toInt().toString(),
//   //                     ),
//   //                     decoration: const InputDecoration(
//   //                       labelText: 'Order Qty',
//   //                       border: OutlineInputBorder(),
//   //                     ),
//   //                     style: const TextStyle(color: Colors.black54),
//   //                   ),
//   //                 ),
//   //                 SizedBox(
//   //                   width: 100,
//   //                   child: TextField(
//   //                     controller: cancelledQtyController,
//   //                     keyboardType: TextInputType.number,
//   //                     inputFormatters: <TextInputFormatter>[
//   //                       FilteringTextInputFormatter.digitsOnly,
//   //                       NoLeadingZeroAndZeroTextInputFormatter(),
//   //                       CancelQuantityValidator(quantities[index]),
//   //                     ],
//   //                     decoration: const InputDecoration(
//   //                       labelText: 'Cancel Qty',
//   //                       border: OutlineInputBorder(),
//   //                     ),
//   //                   ),
//   //                 ),
//   //               ],
//   //             ),
//   //             const SizedBox(height: 10),
//   //             SizedBox(
//   //               width: 300,
//   //               child: TextField(
//   //                 controller: remarkController2,
//   //                 decoration: const InputDecoration(
//   //                   hintText: 'Reason for Cancellation',
//   //                   border: OutlineInputBorder(),
//   //                 ),
//   //               ),
//   //             ),
//   //           ],
//   //         ),
//   //         actions: [
//   //           ElevatedButton(
//   //             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//   //             onPressed: () {
//   //               Navigator.of(context).pop();
//   //             },
//   //             child: const Text('Cancel'),
//   //           ),
//   //           ElevatedButton(
//   //             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//   //             onPressed: () async {
//   //               print("handleEditQuantitys3...");

//   //               double newQuantity = double.tryParse(
//   //                     cancelledQtyController.text,
//   //                   ) ??
//   //                   0.0;

//   //               // Validate quantity
//   //               if (newQuantity > quantities[index]) {
//   //                 ScaffoldMessenger.of(context).showSnackBar(
//   //                   const SnackBar(
//   //                     content: Text(
//   //                       'Cancel quantity exceeds available quantity',
//   //                     ),
//   //                   ),
//   //                 );
//   //                 return;
//   //               }
//   //               print("handleEditQuantitys4...");

//   //               // Update the cancelled quantities
//   //               cancelledQty[index] = newQuantity;

//   //               itemRemark[index] = remarkController2.text;

//   //               partiallyCancelled = "Yes";

//   //               final orderProvider =
//   //                   Provider.of<OrderProvider>(context, listen: false);

//   //               await orderProvider.patchOrderCancelQuantity(
//   //                 order['hiveOrderId'],
//   //                 order['seathiveOrderId'],
//   //                 order['quantities'],
//   //                 cancelledQty.map((e) => e ?? 0.0).toList(), // Handle nulls
//   //                 List.generate(
//   //                     quantities.length, (i) => i == index ? newQuantity : 0.0),
//   //                 order['prices'],
//   //                 itemRemark,
//   //                 partiallyCancelled,
//   //               );
//   //               print("handleEditQuantitys5...");

//   //               orderProvider.notifyListeners();

//   //               final printerProvider =
//   //                   Provider.of<PrinterProvider>(context, listen: false);

//   //               await CancelPrinterService.printUniversalReceipt(
//   //                 ipAddress: printerProvider
//   //                     .getPrinterIpForItem(order['varianceNames'][index])
//   //                     .toString(),
//   //                 tableNumber: order['table'],
//   //                 seat: order['seat'],
//   //                 userName: userName,
//   //                 waiter: order['waiter'],
//   //                 seatOrders: [
//   //                   {
//   //                     'varianceNames': [order['varianceNames'][index]],
//   //                     'quantities': [quantities[index]],
//   //                     'cancelledQty': [newQuantity],
//   //                   }
//   //                 ],
//   //                 receiptType: "Quantity Cancelled",
//   //               );
//   //               print("handleEditQuantitys6...");

//   //               Navigator.of(context).pop();
//   //             },
//   //             child: const Text('Save'),
//   //           ),
//   //         ],
//   //       );
//   //     },
//   //   );
//   // }
//   // Within your CancellationHandler, e.g. in handleCancelItem:]
// }

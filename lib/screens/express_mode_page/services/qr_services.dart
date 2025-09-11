// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'dart:convert';

// import '../../../services/branchwise_item_fetch.dart';
// import '../../regular_mode_page/provider/cart_page_provider.dart';

// class QRCodeHandler {
//   static void handleQrScan(BuildContext context, String value) async {
//     if (value.isEmpty) return;

//     try {
//       // Parse scanned data
//       final Map<String, dynamic> scannedData = _parseScannedData(value);

//       if (scannedData.containsKey('ItemCode')) {
//         final itemCode = scannedData['ItemCode'];
//         final quantity = scannedData['Qty'] ?? 1;
//         final uom = scannedData['UOM'] ?? '';

//         // Access Item Provider
//         final itemProvider = Provider.of<ItemProvider>(context, listen: false);
//         final result = itemProvider.checkVarianceItemCode(itemCode);

//         if (result.isNotEmpty) {
//           final saleProvider =
//               Provider.of<CurrentSaleProvider>(context, listen: false);
//           final itemData = result.first;

//           // Add the item to the cart
//           saleProvider.addItemToCart({
//             ...itemData,
//             'quantity': double.tryParse(quantity.toString()) ?? 1.0,
//             'uom': uom,
//           });

//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                   "Item added to cart: ${itemData['varianceData']['varianceName']}"),
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
//     }
//   }

//   static Map<String, dynamic> _parseScannedData(String value) {
//     try {
//       return json.decode(value); // Parse JSON
//     } catch (_) {
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
// }
// // FG001
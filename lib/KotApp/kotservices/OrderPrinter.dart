// import 'dart:async';
// import 'package:hive/hive.dart';
// import 'printer_services.dart';
// import '../providers/printer_provider.dart';
// import '../providers/login_provider.dart';

// class OrderPrinterService {
//   final PrinterProvider printerProvider;
//   final LoginProvider loginProvider;

//   Set<String> processedOrderIds = {};

//   OrderPrinterService(this.printerProvider, this.loginProvider);

//   Future<void> printOrder(Map<String, dynamic> orderData) async {
//     final String hiveOrderId = orderData['hiveOrderId']?.toString() ?? "";
//     var ordersBox = await Hive.openBox('orders');
//     var savedOrder = ordersBox.get(hiveOrderId);

//     List<Map<String, dynamic>> seatOrders = _prepareSeatOrders(orderData);

//     String? overallPrinterIp = printerProvider.getOverallPrinterIp();
//     final userName = loginProvider.loggedInUserName ?? "";

//     if (overallPrinterIp != null) {
//       await PrinterService.printReceipt(
//         ipAddress: overallPrinterIp,
//         tableNumber: int.tryParse(orderData['table']?.toString() ?? '0') ?? 0,
//         seat: orderData['seat']?.toString() ?? '',
//         date: orderData['date']?.toString() ?? '',
//         time: orderData['time']?.toString() ?? '',
//         waiter: orderData['waiter']?.toString() ?? '',
//         total:
//             double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0,
//         seatOrders: seatOrders,
//         tokenNumber: orderData['tokenNo'].toString(),
//         isOverall: true,
//         userName: userName,
//         orderType: orderData['orderType']?.toString() ?? '',
//       );
//     }

//     Map<String, List<Map<String, dynamic>>> groupedItemsByPrinter =
//         _groupItemsByPrinter(seatOrders);

//     for (String ip in groupedItemsByPrinter.keys) {
//       await PrinterService.printReceipt(
//         ipAddress: ip,
//         tableNumber: int.tryParse(orderData['table']?.toString() ?? '0') ?? 0,
//         seat: orderData['seat']?.toString() ?? '',
//         date: orderData['date']?.toString() ?? '',
//         time: orderData['time']?.toString() ?? '',
//         waiter: orderData['waiter']?.toString() ?? '',
//         total:
//             double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0,
//         seatOrders: groupedItemsByPrinter[ip]!,
//         tokenNumber: orderData['tokenNo'].toString(),
//         userName: userName,
//         isOverall: false,
//         orderType: orderData['orderType']?.toString() ?? '',
//       );
//     }

//     savedOrder['printed'] = true;
//     await ordersBox.put(hiveOrderId, savedOrder);
//     print("Order $hiveOrderId marked as printed.");

//     // Verify update
//     var updatedOrder = ordersBox.get(hiveOrderId);
//     print("Updated order from Hive: $updatedOrder");
//   }

//   List<Map<String, dynamic>> _prepareSeatOrders(
//       Map<String, dynamic> orderData) {
//     List<Map<String, dynamic>> seatOrders = [];
//     List<String> itemNames = List<String>.from(orderData['itemNames'] ?? []);
//     List<String> varianceNames =
//         List<String>.from(orderData['varianceNames'] ?? []);
//     List<double> prices = List<double>.from(orderData['prices'] ?? []);
//     List<double> quantities = List<double>.from(orderData['quantities'] ?? []);
//     List<double> weights = List<double>.from(orderData['weights'] ?? []);
//     List<double> amounts = List<double>.from(orderData['amounts'] ?? []);
//     List<Map<String, dynamic>> addOns =
//         List<Map<String, dynamic>>.from(orderData['addOns'] ?? []);

//     Map<String, List<Map<String, dynamic>>> groupedAddOns = {};
//     for (var addOn in addOns) {
//       String varianceName = addOn['varianceName'] ?? '';
//       groupedAddOns.putIfAbsent(varianceName, () => []).add(addOn);
//     }

//     for (int i = 0; i < itemNames.length; i++) {
//       String varianceName = varianceNames.length > i ? varianceNames[i] : '';
//       double itemQuantity = quantities.length > i ? quantities[i] : 0.0;

//       if (groupedAddOns.containsKey(varianceName)) {
//         for (var addOn in groupedAddOns[varianceName]!) {
//           seatOrders.add({
//             'itemName': '${varianceName}(${addOn['addOnName']})',
//             'varianceName': '',
//             'price': addOn['price'] ?? 0.0,
//             'quantity': addOn['quantity'] ?? 0.0,
//             'weights': addOn['weights'] ?? 0.0,
//             'amount': (addOn['price'] ?? 0.0) * (addOn['quantity'] ?? 1.0),
//           });
//           itemQuantity -= addOn['quantity'] ?? 0.0;
//         }
//       }

//       if (itemQuantity > 0) {
//         seatOrders.add({
//           'itemName': varianceName,
//           'varianceName': varianceName,
//           'price': prices.length > i ? prices[i] : 0.0,
//           'quantity': itemQuantity,
//           'weights': weights.length > i ? weights[i] : 0.0,
//           'amount': amounts.length > i ? amounts[i] : 0.0,
//         });
//       }
//     }
//     return seatOrders;
//   }

//   Map<String, List<Map<String, dynamic>>> _groupItemsByPrinter(
//       List<Map<String, dynamic>> seatOrders) {
//     Map<String, List<Map<String, dynamic>>> groupedItemsByPrinter = {};
//     for (var item in seatOrders) {
//       final String? itemPrinterIp = printerProvider
//           .getPrinterIpForItem(item['varianceName']?.toString() ?? '');

//       if (itemPrinterIp != null) {
//         groupedItemsByPrinter.putIfAbsent(itemPrinterIp, () => []).add(item);
//       }
//     }
//     return groupedItemsByPrinter;
//   }
// }

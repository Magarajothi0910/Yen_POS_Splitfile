// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../../servicess/websocketService.dart';
// import '../../providers/cartprovider.dart';
// import '../../providers/hold_order.dart';
// import '../../providers/order_provider.dart';
// import '../productsCard.dart';

// void sendSeatActionToServer(
//     BuildContext context, String tableNumber, String seat) {
//   final orderProvider = Provider.of<OrderProvider>(context, listen: false);
//   final holdOrderProvider =
//       Provider.of<HoldOrderProvider>(context, listen: false);
//   final cartProvider = Provider.of<CartProvider>(context, listen: false);
//   final webSocketService =
//       Provider.of<WebSocketService>(context, listen: false);

//   final ordersForSeat = orderProvider.getActiveOrdersForSeat(tableNumber, seat);
//   final isOccupied = ordersForSeat.any(
//       (order) => order['status'] == 'active' || order['status'] == 'confirm');
//   final seathiveOrderId =
//       isOccupied ? ordersForSeat.first['seathiveOrderId'] ?? '' : '';

//   final data = {
//     'action': 'seat_tapped',
//     'tableNumber': tableNumber,
//     'seat': seat,
//     'seathiveOrderId': seathiveOrderId,
//   };

//   webSocketService.channel?.sink.add(jsonEncode(data));
//   cartProvider.clearCart();

//   final holdOrder = holdOrderProvider.loadHoldOrder(tableNumber, seat);
//   if (holdOrder != null) {
//     holdOrder.forEach((key, value) {
//       cartProvider.cart[key] = value;
//     });
//   }
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => ProductCardScreen(
//         tableNumber: tableNumber,
//         seat: seat,
//         seathiveOrderId: seathiveOrderId,
//       ),
//     ),
//   ).then((_) {
//     // Send the seat returned action only after returning to the seat screen
//     sendSeatReturnedActionToServer(context, seat, tableNumber);
//   });
// }

// void sendSeatReturnedActionToServer(
//     BuildContext context, String seat, String tableNumber) {
//   final webSocketService =
//       Provider.of<WebSocketService>(context, listen: false);
//   final returnData = {
//     'action': 'seat_returned',
//     'tableNumber': tableNumber,
//     'seat': seat,
//   };
//   webSocketService.channel.sink.add(jsonEncode(returnData));
// }

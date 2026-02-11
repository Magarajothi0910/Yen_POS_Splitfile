// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/cartprovider.dart';
// import '../../providers/hold_order.dart';
// import '../../screens/viewtocart.dart';

// OverlayEntry? _overlayEntry;

// Widget buildHoldOrdersDropdown(
//   BuildContext context,
//   String currentTable,
//   String currentSeat,
// ) {
//   final holdOrderProvider = Provider.of<HoldOrderProvider>(
//     context,
//     listen: false,
//   );
//   final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);

//   // Get all hold orders with proper debugging
//   final holdOrders = holdOrderProvider.getAllHoldOrders();
//   debugPrint('📋 Total hold orders: ${holdOrders.length}');

//   // Filter out the current table + seat
//   final filteredOrders = holdOrders.where((order) {
//     final isCurrent =
//         order['table'] == currentTable && order['seat'] == currentSeat;
//     if (!isCurrent) {
//       debugPrint(
//         '🎯 Available hold order: ${order['table']} - Seat ${order['seat']}',
//       );
//     }
//     return !isCurrent;
//   }).toList();

//   debugPrint('✅ Filtered hold orders: ${filteredOrders.length}');

//   filteredOrders.sort((a, b) {
//     final numberRegex = RegExp(r'\d+');
//     final tableA = a['table'];
//     final tableB = b['table'];
//     final seatA = a['seat'];
//     final seatB = b['seat'];

//     final int tableNumA =
//         int.tryParse(numberRegex.firstMatch(tableA)?.group(0) ?? '0') ?? 0;
//     final int tableNumB =
//         int.tryParse(numberRegex.firstMatch(tableB)?.group(0) ?? '0') ?? 0;

//     final int tableComparison = tableNumA.compareTo(tableNumB);
//     return tableComparison == 0 ? seatA.compareTo(seatB) : tableComparison;
//   });

//   final GlobalKey dropdownKey = GlobalKey();
//   bool hasOrders = filteredOrders.isNotEmpty;
//   int holdOrderCount = filteredOrders.length;

//   void hideOverlay() {
//     _overlayEntry?.remove();
//     _overlayEntry = null;
//   }

//   void showOverlay() {
//     final RenderBox renderBox =
//         dropdownKey.currentContext?.findRenderObject() as RenderBox;
//     final Offset offset = renderBox.localToGlobal(Offset.zero);
//     final Size size = renderBox.size;

//     _overlayEntry = OverlayEntry(
//       builder: (context) => Stack(
//         children: [
//           GestureDetector(
//             onTap: hideOverlay,
//             behavior: HitTestBehavior.translucent,
//             child: Container(
//               color: Colors.transparent,
//               width: double.infinity,
//               height: double.infinity,
//             ),
//           ),
//           Positioned(
//             left: offset.dx,
//             top: offset.dy + size.height + 5,
//             width: 180,
//             child: Material(
//               elevation: 4,
//               borderRadius: BorderRadius.circular(8),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: ListView.builder(
//                   padding: const EdgeInsets.all(8),
//                   shrinkWrap: true,
//                   itemCount: filteredOrders.length,
//                   itemBuilder: (context, index) {
//                     final order = filteredOrders[index];
//                     final table = order['table'];
//                     final seat = order['seat'];
//                     final areaName = order['areaName'];

//                     return ListTile(
//                       dense: true,
//                       title: Text(
//                         '$table - Seat $seat',
//                         style: const TextStyle(fontSize: 12),
//                       ),
//                       onTap: () {
//                         hideOverlay();
//                         final holdOrder = holdOrderProvider.loadHoldOrder(
//                           table,
//                           seat,
//                         );
//                         if (holdOrder != null) {
//                           cartProvider.loadCart(holdOrder);
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => productCardViewList(
//                                 tableNumber: table,
//                                 seat: seat,
//                                 areaName: areaName,
//                                 seathiveOrderId: null,
//                               ),
//                             ),
//                           );
//                         }
//                       },
//                     );
//                   },
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );

//     Overlay.of(context).insert(_overlayEntry!);
//   }

//   return IntrinsicWidth(
//     child: SizedBox(
//       height: 40,
//       child: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           GestureDetector(
//             key: dropdownKey,
//             onTap: () {
//               if (_overlayEntry != null) {
//                 hideOverlay();
//               } else {
//                 if (hasOrders) showOverlay();
//               }
//             },
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.black12, width: 1.5),
//                 borderRadius: BorderRadius.circular(8.0),
//                 color: Colors.white,
//               ),
//               child: const Row(
//                 children: [
//                   Text(
//                     'Hold Orders',
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 13,
//                     ),
//                   ),
//                   SizedBox(width: 4),
//                   Icon(Icons.arrow_drop_down, size: 18),
//                 ],
//               ),
//             ),
//           ),
//           if (holdOrderCount > 0)
//             Positioned(
//               top: -6,
//               right: -6,
//               child: Container(
//                 padding: const EdgeInsets.all(4.0),
//                 decoration: const BoxDecoration(
//                   color: Colors.red,
//                   shape: BoxShape.circle,
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black26,
//                       blurRadius: 4.0,
//                       offset: Offset(2, 2),
//                     ),
//                   ],
//                 ),
//                 child: Text(
//                   '$holdOrderCount',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 12,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     ),
//   );
// }

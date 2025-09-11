// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../providers/hold_order.dart';
// import '../providers/cartprovider.dart';
// import '../screens/productsCard.dart';

// class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
//   final String title;
//   final List<Widget>? actions;
//   final PreferredSizeWidget? bottom; // Add bottom property
//   final double elevation; // Add elevation property

//   const GlobalAppBar({
//     Key? key,
//     required this.title,
//     this.actions,
//     this.bottom, // Initialize bottom
//     this.elevation = 6.0, // Default elevation value
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return AppBar(
//       automaticallyImplyLeading: false, // Hides the back arrow

//       title: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//           ),
//           _buildHoldOrdersDropdown(context),
//         ],
//       ),

//       // centerTitle: true,
//       backgroundColor: const Color(0xFFDBF0F7),
//       actions: actions,
//       elevation: elevation, // Apply elevation
//       bottom: bottom,
//     );
//   }

//   Widget _buildHoldOrdersDropdown(BuildContext context) {
//     final holdOrderProvider =
//         Provider.of<HoldOrderProvider>(context, listen: false);
//     final cartProvider = Provider.of<CartProvider>(context, listen: false);
//     final holdOrders = holdOrderProvider.getAllHoldOrders();

//     bool hasOrders = holdOrders.isNotEmpty;
//     int holdOrderCount = holdOrders.length;

//     // Sort the holdOrders list in ascending order (table first, then seat)
//     holdOrders.sort((a, b) {
//       final RegExp regExp = RegExp(r'\d+'); // Extract numbers
//       final String tableA = a['table'];
//       final String tableB = b['table'];

//       final int tableNumA =
//           int.tryParse(regExp.firstMatch(tableA)?.group(0) ?? '0') ?? 0;
//       final int tableNumB =
//           int.tryParse(regExp.firstMatch(tableB)?.group(0) ?? '0') ?? 0;

//       int tableComparison = tableNumA.compareTo(tableNumB);
//       if (tableComparison != 0) return tableComparison;

//       return a['seat'].compareTo(b['seat']);
//     });

//     return SizedBox(
//       width: 100,
//       height: 40, // Adjust the width as needed
//       child: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           Container(
//             decoration: BoxDecoration(
//               border: Border.all(
//                 color: Colors.black12, // Border color
//                 width: 1.5,
//               ),
//               borderRadius: BorderRadius.circular(8.0), // Rounded border
//               color: Colors.white, // Dropdown background color
//             ),
//             child: DropdownButtonHideUnderline(
//               child: DropdownButton<String>(
//                 isExpanded: true,
//                 icon: const SizedBox.shrink(), // Remove the arrow icon
//                 hint: const Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 8.0),
//                   child: Text(
//                     'Hold Orders',
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 13,
//                     ),
//                   ),
//                 ),
//                 dropdownColor: Colors.white,
//                 items: hasOrders
//                     ? holdOrders.map<DropdownMenuItem<String>>((order) {
//                         final table = order['table'];
//                         final seat = order['seat'];
//                         return DropdownMenuItem<String>(
//                           value: '$table-$seat',
//                           child: Text(
//                             '$table -  Seat $seat',
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(fontSize: 10),
//                           ),
//                         );
//                       }).toList()
//                     : null,
//                 onChanged: hasOrders
//                     ? (value) {
//                         if (value != null) {
//                           final table = value.split('-')[0];
//                           final seat = value.split('-')[1];

//                           final holdOrder =
//                               holdOrderProvider.loadHoldOrder(table, seat);

//                           if (holdOrder != null) {
//                             cartProvider.loadCart(holdOrder);
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => ProductCardScreen(
//                                   tableNumber: table,
//                                   seat: seat,
//                                   seathiveOrderId: null,
//                                 ),
//                               ),
//                             );
//                           }
//                         }
//                       }
//                     : null,
//               ),
//             ),
//           ),
//           // Badge to show hold order count
//           if (holdOrderCount > 0)
//             Positioned(
//               top: -6,
//               right: -6,
//               child: Container(
//                 padding: const EdgeInsets.all(4.0),
//                 decoration: const BoxDecoration(
//                   color: Colors.red, // Badge background color
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
//     );
//   }

//   @override
//   Size get preferredSize {
//     // Add bottom's height to kToolbarHeight
//     final bottomHeight = bottom?.preferredSize.height ?? 0.0;
//     return Size.fromHeight(kToolbarHeight + bottomHeight);
//   }
// }
// //  if (hold == false) {
// //                              holdOrder =
// //                                 holdOrderProvider.loadHoldOrder(table, seat);
// //                           }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../kotproviders/hold_order.dart';
import '../kotproviders/cartprovider.dart';
import '../screens/productsCard.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double elevation;

  const GlobalAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.bottom,
    this.elevation = 6.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          IntrinsicWidth(child: _buildHoldOrdersDropdown(context)),
        ],
      ),
      backgroundColor: const Color(0xFFDBF0F7),
      actions: actions,
      elevation: elevation,
      bottom: bottom,
    );
  }

  Widget _buildHoldOrdersDropdown(BuildContext context) {
    final holdOrderProvider =
        Provider.of<HoldOrderProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProviderkot>(context, listen: false);
    final holdOrders = holdOrderProvider.getAllHoldOrders();

    bool hasOrders = holdOrders.isNotEmpty;
    int holdOrderCount = holdOrders.length;

    // Sort hold orders by table number (numeric), then seat (alphabetic)
    holdOrders.sort((a, b) {
      final RegExp numberRegex = RegExp(r'\d+');

      // Extract numeric part from table strings
      final tableA = a['table'];
      final tableB = b['table'];
      final seatA = a['seat'];
      final seatB = b['seat'];

      final int tableNumA =
          int.tryParse(numberRegex.firstMatch(tableA)?.group(0) ?? '0') ?? 0;
      final int tableNumB =
          int.tryParse(numberRegex.firstMatch(tableB)?.group(0) ?? '0') ?? 0;

      // First sort by table number
      final int tableComparison = tableNumA.compareTo(tableNumB);

      // If table numbers are equal, sort by seat alphabetically
      if (tableComparison == 0) {
        return seatA.toString().compareTo(seatB.toString());
      } else {
        return tableComparison;
      }
    });

    return IntrinsicWidth(
      child: SizedBox(
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12, width: 1.5),
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: false,
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  hint: const Text(
                    'Hold Orders',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  dropdownColor: Colors.white,
                  items: hasOrders
                      ? holdOrders.map<DropdownMenuItem<String>>((order) {
                          final table = order['table'];
                          final seat = order['seat'];
                          return DropdownMenuItem<String>(
                            value: '$table|$seat',
                            child: Text(
                              '$table - Seat $seat',
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList()
                      : null,
                  onChanged: hasOrders
                      ? (value) {
                          if (value != null) {
                            final parts = value.split('|');
                            final table = parts[0];
                            final seat = parts[1];

                            final holdOrder =
                                holdOrderProvider.loadHoldOrder(table, seat);

                            if (holdOrder != null) {
                              cartProvider.loadCart(holdOrder);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductCardScreen(
                                    tableNumber: table,
                                    seat: seat,
                                    seathiveOrderId: null,
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      : null,
                ),
              ),
            ),
            if (holdOrderCount > 0)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4.0,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '$holdOrderCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }
}

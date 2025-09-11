// import 'package:flutter/material.dart';
// import '../Dashboard/tableDashboard.dart';
// import '../kotproviders/bottomNavprovider.dart';

// import 'package:provider/provider.dart';

// import '../screens/order_summary_screen.dart';
// import '../screens/preInvoiceTAb.dart';
// import '../screens/table_screen.dart';
// import 'settingsScreen.dart';

// class GlobalBottomNavReturn extends StatelessWidget {
//   final Function()? onSelected;

//   const GlobalBottomNavReturn({
//     Key? key,
//     this.onSelected,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final bottomNavProvider = Provider.of<BottomNavProvider>(context);

//     void onBottomNavTap(int index) {
//       bottomNavProvider.updateIndex(index);

//       switch (index) {
//         case 0:
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const DashboardScreen()),
//             (Route<dynamic> route) => false, // Removes all previous routes
//           );
//           break;
//         case 1:
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const TableScreen()),
//             (Route<dynamic> route) => false, // Removes all previous routes
//           );
//           break;
//         case 2:
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const OrderSummaryScreen()),
//             (Route<dynamic> route) => false, // Removes all previous routes
//           );
//           break;
//         case 3:
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const PreInvoiceScreen()),
//             (Route<dynamic> route) => false, // Removes all previous routes
//           );
//           break;
//         case 4:
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const settingsScreen()),
//             (Route<dynamic> route) => false, // Removes all previous routes
//           );
//           break;
//       }
//     }

//     return BottomNavigationBar(
//       onTap: (index) {
//         // Invoke the callback when a specific part of the bar is clicked
//         onSelected?.call();

//         // if (noSelection) {
//         //   bottomNavProvider.updateIndex(index);
//         // }
//         onBottomNavTap(index);
//       },
//       selectedItemColor: Colors.grey,
//       unselectedItemColor: Colors.grey,
//       type: BottomNavigationBarType.fixed,
//       selectedLabelStyle: const TextStyle(fontSize: 10),
//       unselectedLabelStyle: const TextStyle(fontSize: 8),
//       items: const [
//         BottomNavigationBarItem(
//           icon: Icon(Icons.dashboard),
//           label: "Dashboard",
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.local_mall),
//           label: "New Orders",
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.list_alt),
//           label: "Orders",
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.receipt_long),
//           label: "Pre-Invoice",
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.settings),
//           label: "Settings",
//         ),
//       ],
//     );
//   }
// }

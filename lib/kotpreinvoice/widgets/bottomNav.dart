// import 'package:flutter/material.dart';
// import '../../kotpreinvoice/providers/bottomNavprovider.dart';

// import 'package:provider/provider.dart';

// import '../screens/order_summary_screen.dart';
// import '../screens/preInvoiceTAb.dart';
// import '../screens/table_screen.dart';
// import 'settingsScreen.dart';

// class GlobalBottomNav extends StatelessWidget {
//   final bool noSelection; // Flag to control initial selection

//   const GlobalBottomNav({Key? key, this.noSelection = false}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final bottomNavProvider = Provider.of<BottomNavProviderKOT>(context);
//     final currentIndex = noSelection ? -1 : bottomNavProvider.currentIndex;

//     void onBottomNavTap(int index) {
//       if (index == currentIndex) return;

//       bottomNavProvider.updateIndex(index);

//       switch (index) {
//         case 0:
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const TableScreen()),
//             (Route<dynamic> route) => false, // Removes all previous routes
//           );
//           break;
//         case 1:
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const OrderSummaryScreen()),
//             (Route<dynamic> route) => false, // Removes all previous routes
//           );
//           break;
//         case 2:
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const PreInvoiceScreen()),
//             (Route<dynamic> route) => false, // Removes all previous routes
//           );
//           break;
//         case 3:
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const settingsScreen()),
//             (Route<dynamic> route) => false, // Removes all previous routes
//           );
//           break;
//       }
//     }

//     return BottomNavigationBar(
//       backgroundColor: Colors.white,
//       currentIndex: currentIndex == -1 ? 0 : currentIndex, // Default to 0 if no selection
//       onTap: (index) {
//         if (noSelection) {
//           bottomNavProvider.updateIndex(index);
//         }
//         onBottomNavTap(index);
//       },
//       selectedItemColor: noSelection ? Colors.grey : Colors.blue,
//       unselectedItemColor: Colors.grey,
//       type: BottomNavigationBarType.fixed,
//       selectedLabelStyle: const TextStyle(fontSize: 15),
//       unselectedLabelStyle: const TextStyle(fontSize: 10),
//       items: const [
//         // BottomNavigationBarItem(
//         //   icon: Icon(Icons.dashboard),
//         //   label: "Dashboard",
//         // ),
//         BottomNavigationBarItem(
//           icon: Icon(
//             Icons.local_mall,
//           ),
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

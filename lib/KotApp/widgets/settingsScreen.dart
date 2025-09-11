import 'package:flutter/material.dart';
import 'package:yenposapp/KotApp/widgets/globalAppbar.dart';

import '../../server/Screen/serverScreen.dart';
import '../screens/Unprinted receipt/unprinted_orders_screen.dart';
import '../screens/cancelOrderScreen.dart';
import '../screens/loginScreen.dart';
import '../screens/printer_settings_screen.dart';
import '../screens/serverScreen.dart';
import '../screens/transactionScreen.dart';

import 'bottomNav.dart';

class settingsScreen extends StatefulWidget {
  const settingsScreen({super.key});

  @override
  _settingsScreenState createState() => _settingsScreenState();
}

class _settingsScreenState extends State<settingsScreen> {
  String _selectedMenu = 'Printer'; // Default menu selection

  Widget _getSelectedMenuContent() {
    switch (_selectedMenu) {
      case 'Printer':
        return const PrinterSettingsScreen(); // Your Printer Settings Content
      case 'Transaction':
        return const TransactionScreen(); // Replace with actual screen
      case 'Canceled':
        return const CanceledOrdersScreen(); // Your Cancel Orders Content
      // case 'Set serverIP':
      //   return const ServerIPScreen();
      case 'RePrint Orders':
        return const UnprintedOrdersScreen();
      case 'Logout':
        return const Center(
            child: Text('You have logged out')); // Optional logout screen
      default:
        return const Center(child: Text('Select a menu'));
    }
  }

  void _handleLogout() {
    // Handle logout logic here
    // For example, navigate to login screen
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout Confirmation'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Navigate to login screen or perform logout
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: GlobalAppBar(
        title: "Settings -  $_selectedMenu",
        elevation: 0,
      ),
      body: Row(
        children: [
          // Sidebar Menu
          Container(
            width: isMobile
                ? 80
                : 250, // Adjust sidebar width based on screen size
            color: const Color(0xFFFAFAFA),
            child: ListView(
              children: [
                _buildMenuItem('Printer', Icons.print),
                _buildMenuItem('Transaction', Icons.receipt_long),
                _buildMenuItem('Canceled', Icons.list_alt),
                //  _buildMenuItem('Set serverIP', Icons.network_cell),
                _buildMenuItem('RePrint Orders', Icons.print_disabled_rounded),
                _buildLogoutMenuItem('Logout', Icons.logout),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(3),
              child: _getSelectedMenuContent(),
            ),
          ),
        ],
      ),
      //bottomNavigationBar: const GlobalBottomNav(),
    );
  }

  Widget _buildMenuItem(String menu, IconData icon) {
    final bool isSelected = _selectedMenu == menu;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMenu = menu;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDBF0F7) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 24),
            const SizedBox(height: 4), // Spacing between icon and text
            Text(
              menu,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: isMobile ? 8 : 16, // Adjust font size for mobile
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutMenuItem(String menu, IconData icon) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: () {
        _handleLogout();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.red, size: 24),
            const SizedBox(height: 4), // Spacing between icon and text
            Text(
              menu,
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 8 : 16, // Adjust font size for mobile
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import '../screens/cancelOrderScreen.dart';
// import '../screens/printer_settings_screen.dart';

// class settingsScreen extends StatefulWidget {
//   const settingsScreen({super.key});

//   @override
//   _settingsScreenState createState() => _settingsScreenState();
// }

// class _settingsScreenState extends State<settingsScreen> {
//   String _selectedMenu = 'Printer'; // Default menu selection

//   Widget _getSelectedMenuContent() {
//     switch (_selectedMenu) {
//       case 'Printer':
//         return PrintersettingsScreen();
//       case 'Transaction':
//         return const Center(
//             child: Text('Transaction Content')); // Replace with actual screen
//       case 'Canceled':
//         return CanceledOrdersScreen();
//       default:
//         return const Center(child: Text('Select a menu'));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isMobile = MediaQuery.of(context).size.width < 600;

//     return Scaffold(
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               "Settings",
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             Text(
//               _selectedMenu,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.normal,
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: const Color(0xFFDBF0F7),
//       ),
//       body: isMobile
//           ? Column(
//               children: [
//                 // Sidebar Menu
//                 Container(
//                   color: Colors.white,
//                   child: ListView(
//                     shrinkWrap: true,
//                     children: [
//                       _buildMenuItem('Printer', Icons.print),
//                       _buildMenuItem('Transaction', Icons.receipt_long),
//                       _buildMenuItem('Canceled', Icons.cancel),
//                     ],
//                   ),
//                 ),
//                 // Main Content
//                 Expanded(
//                   child: Container(
//                     color: Colors.white,
//                     child: _getSelectedMenuContent(),
//                   ),
//                 ),
//               ],
//             )
//           : Row(
//               children: [
//                 // Sidebar Menu
//                 Container(
//                   width: MediaQuery.of(context).size.width * 0.25,
//                   color: Colors.white,
//                   child: ListView(
//                     children: [
//                       _buildMenuItem('Printer', Icons.print),
//                       _buildMenuItem('Transaction', Icons.receipt_long),
//                       _buildMenuItem('Canceled', Icons.cancel),
//                     ],
//                   ),
//                 ),
//                 // Main Content
//                 Expanded(
//                   child: Container(
//                     color: Colors.white,
//                     child: _getSelectedMenuContent(),
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }

//   Widget _buildMenuItem(String menu, IconData icon) {
//     final bool isSelected = _selectedMenu == menu;

//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 4),
//       child: ListTile(
//         leading: Icon(icon, color: isSelected ? Colors.blue : Colors.black),
//         title: Text(
//           menu,
//           style: TextStyle(
//             color: isSelected ? Colors.blue : Colors.black,
//             fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//           ),
//         ),
//         tileColor: isSelected ? const Color(0xFFDBF0F7) : Colors.white,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//         onTap: () {
//           setState(() {
//             _selectedMenu = menu;
//           });
//         },
//       ),
//     );
//   }
// }

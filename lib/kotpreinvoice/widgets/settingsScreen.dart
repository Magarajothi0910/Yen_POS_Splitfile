import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Server_Client/serverScreen.dart';
import '../screens/setting_screens/payment_screen.dart';
import '../screens/Unprinted receipt/unprinted_orders_screen.dart';
import '../screens/cancelOrderScreen.dart';
import '../screens/printer_settings_screen.dart';
import '../screens/serverScreen.dart';
import '../screens/transactionScreen.dart';
import '../components/globalAppbar.dart';
import 'bottomNav.dart';

// 🔔 ChangeNotifier to manage SettingsScreen state
class SettingsScreenState extends ChangeNotifier {
  String _selectedMenu = 'Printer'; // Default menu selection

  String get selectedMenu => _selectedMenu;

  // 🔔 Update selected menu
  void setSelectedMenu(String menu) {
    _selectedMenu = menu;
    debugPrint("🛠️ Selected menu updated: $_selectedMenu");
    notifyListeners();
  }
}

class settingsScreen extends StatefulWidget {
  const settingsScreen({super.key});

  @override
  _settingsScreenState createState() => _settingsScreenState();
}

class _settingsScreenState extends State<settingsScreen> {
  late SettingsScreenState state;

  @override
  void initState() {
    super.initState();
    state = SettingsScreenState(); // 🔔 Initialize ChangeNotifier
  }

  @override
  void dispose() {
    state.dispose(); // 🧹 Dispose ChangeNotifier
    super.dispose();
  }

  Widget _getSelectedMenuContent(String selectedMenu) {
    switch (selectedMenu) {
      case 'Printer':
        return const PrinterSettingsScreen();
      case 'Transaction':
        return const TransactionScreen();
      case 'Payment': // 🔔 Added case for Payment
        return const PaymentScreen();
      case 'Canceled':
        return const CanceledOrdersScreen();
      // case 'Set serverIP':
      //   return const ServerIPScreen();
      case 'RePrint Orders':
        return const UnprintedOrdersScreen();
      case 'Logout':
        return const Center(child: Text('You have logged out'));
      default:
        return const Center(child: Text('Select a menu'));
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Logout Confirmation'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              style: ElevatedButton.styleFrom(
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Navigate to login screen and remove all previous screens
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

    return ChangeNotifierProvider.value(
      value: state,
      child: Scaffold(
        appBar: GlobalAppBar(
          title: "Settings -  ${state.selectedMenu}",
          elevation: 0,
        ),
        body: Row(
          children: [
            // Sidebar Menu
            Container(
              width: isMobile ? 80 : 250,
              color: const Color(0xFFFAFAFA),
              child: ListView(
                children: [
                  _buildMenuItem('Printer', Icons.print),
                  _buildMenuItem('Transaction', Icons.receipt_long),
                  _buildMenuItem('Payment', Icons.payment), // 🔔 Added Payment menu item
                  _buildMenuItem('Canceled', Icons.list_alt),
                  // _buildMenuItem('Set serverIP', Icons.network_cell),
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
                child: Consumer<SettingsScreenState>(
                  builder: (context, state, _) {
                    return _getSelectedMenuContent(state.selectedMenu);
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: const GlobalBottomNav(),
      ),
    );
  }

  Widget _buildMenuItem(String menu, IconData icon) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Consumer<SettingsScreenState>(
      builder: (context, state, _) {
        final bool isSelected = state.selectedMenu == menu;
        return GestureDetector(
          onTap: () {
            state.setSelectedMenu(menu);
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
                const SizedBox(height: 4),
                Text(
                  menu,
                  style: TextStyle(
                    color: isSelected ? Colors.blue : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: isMobile ? 8 : 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoutMenuItem(String menu, IconData icon) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: _handleLogout,
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
            const SizedBox(height: 4),
            Text(
              menu,
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 8 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../screens/Unprinted receipt/unprinted_orders_screen.dart';
import 'settingsScreen.dart';

class settingDrawer extends StatelessWidget {
  const settingDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Text(
              'Menu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Printer setting '),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const settingsScreen()),
                (Route<dynamic> route) => false, // Removes all previous routes
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Transaction'),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const settingsScreen()),
                (Route<dynamic> route) => false, // Removes all previous routes
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.cancel),
            title: const Text('Canceled Orders'),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const settingsScreen()),
                (Route<dynamic> route) => false, // Removes all previous routes
              );
            },
          ),
          // ListTile(
          //   leading: const Icon(Icons.important_devices_rounded),
          //   title: const Text('Set serverIp'),
          //   onTap: () {
          //     Navigator.pushAndRemoveUntil(
          //       context,
          //       MaterialPageRoute(builder: (context) => const settingsScreen()),
          //       (Route<dynamic> route) => false, // Removes all previous routes
          //     );
          //   },
          // ),
          ListTile(
            leading: const Icon(Icons.print_disabled),
            title: const Text('RePrint Orders'),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const UnprintedOrdersScreen()),
                (Route<dynamic> route) => false, // Removes all previous routes
              );
            },
          ),
        ],
      ),
    );
  }
}

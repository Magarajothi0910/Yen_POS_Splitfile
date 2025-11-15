import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kotpreinvoice/providers/bottomNavprovider.dart';

import '../widgets/settingsScreen.dart';

Future<void> invoicePromptForPrinterIp(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Missing Invoice Printer Configuration!',
          style: TextStyle(fontSize: 17),
        ),
        content: const Text('Please set Invoice printer IP address.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: Colors.red,
              foregroundColor: Colors.black,
            ),
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: Colors.green[200],
              foregroundColor: Colors.black,
            ),
            child: const Text('Set IP'),
            onPressed: () {
              Provider.of<BottomNavProviderKOT>(context, listen: false).updateIndex(3);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const settingsScreen()),
                (Route<dynamic> route) => false, // Removes all previous routes
              );
            },
          ),
        ],
      );
    },
  );
}

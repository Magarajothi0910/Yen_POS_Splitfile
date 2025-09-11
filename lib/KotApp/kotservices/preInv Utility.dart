import 'package:flutter/material.dart';

import '../widgets/settingsScreen.dart';

Future<void> promptForPrinterIp(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text(
          'Missing Pre-Invoice Printer Configuration!',
          style: TextStyle(fontSize: 17),
        ),
        content: const Text('Please set pre-Invoice printer IP address.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
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
              backgroundColor: Colors.green[200],
              foregroundColor: Colors.black,
            ),
            child: const Text('Set IP'),
            onPressed: () {
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

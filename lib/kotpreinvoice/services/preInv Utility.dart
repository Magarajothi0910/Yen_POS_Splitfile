import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Provider/bottomNavprovider.dart';
import '../../kotpreinvoice/providers/bottomNavprovider.dart';

import '../widgets/settingsScreen.dart';

Future<void> promptForPrinterIp(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Missing Pre-Invoice Printer Configuration!',
          style: TextStyle(fontSize: 17),
        ),
        content: const Text('Please set pre-Invoice printer IP address.'),
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
              Navigator.pop(context);
              Provider.of<BottomNavProvider>(
                context,
                listen: false,
              ).updateIndex(5);
            },
          ),
        ],
      );
    },
  );
}

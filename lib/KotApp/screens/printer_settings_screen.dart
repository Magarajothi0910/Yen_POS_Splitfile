// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../screens/kot_screen/global/globals.dart';
import '../../server/Screen/serverScreen.dart';
import '../kotservices/kotwebsocketService.dart';
import '../kotproviders/printer_provider.dart';
import '../models/printer.dart';
import 'item_assignment_screen.dart';
import 'loginScreen.dart';
import 'serverScreen.dart';
import 'package:another_flushbar/flushbar.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  String _selectedType = 'Overall';

  void _showAddPrinterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'ADD PRINTER',
            style: TextStyle(fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Printer Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
                items: <String>['Overall', 'Item wise', 'PreInvoice', 'Invoice']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: 'Printer Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 239, 72, 72),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isEmpty ||
                    _ipController.text.isEmpty) {
                  Flushbar(
                    title: 'All Fields Required',
                    message: 'Please enter both Name and IP Address',
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.red[600] ?? Colors.red,
                    flushbarPosition: FlushbarPosition.BOTTOM,
                    margin: const EdgeInsets.all(8),
                    borderRadius: BorderRadius.circular(20),
                  ).show(context);
                  return;
                }
                final enteredIp = _ipController.text.trim();

                final newPrinter = Printer(
                  name: _nameController.text,
                  ipAddress: _ipController.text,
                  type: _selectedType,
                  items: [],
                );

                final printerProvider =
                    Provider.of<PrinterProvider>(context, listen: false);
                final webSocketService =
                    Provider.of<WebSocketServicekot>(context, listen: false);

                if (enteredIp.isNotEmpty && _validateIpAddress(enteredIp)) {
                  printerProvider.addPrinter(newPrinter);
                  webSocketService.sendPrinterDetails(newPrinter);
                  _nameController.clear();
                  _ipController.clear();
                  setState(() {
                    _selectedType = 'Overall';
                  });
                  Navigator.of(context).pop();
                } else {
                  Flushbar(
                    message: 'Invalid IP Address',
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.red[600] ?? Colors.red,
                    flushbarPosition: FlushbarPosition.BOTTOM,
                    margin: const EdgeInsets.all(8),
                    borderRadius: BorderRadius.circular(20),
                  ).show(context);
                  return;
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA5D6A7),
              ),
              child: const Text(
                'Add Printer',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRemovePrinterDialog(
      BuildContext context,
      PrinterProvider printerProvider,
      WebSocketServicekot webSocketService,
      int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove PrinterIp'),
          content:
              const Text('Are you sure you want to remove this printerIp?'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 239, 72, 72),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final printer = printerProvider.printers[index];
                printerProvider.removePrinter(index);
                webSocketService.sendRemovePrinter(printer.name);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA5D6A7),
              ),
              child: const Text(
                'Remove',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout Confirmation'),
          content: const Text('Are you sure you want to Exit?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Perform logout and navigate to the login screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA5D6A7),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final printerProvider = Provider.of<PrinterProvider>(context);
    final webSocketService =
        Provider.of<WebSocketServicekot>(context, listen: false);

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // Check if printers list is empty
                  if (printerProvider.printers.isEmpty)
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 50),
                          Icon(Icons.info_outline,
                              size: 40, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No printers added yet.",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Tap the '+' icon to add printer details.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 50.0),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: printerProvider.printers.length,
                        itemBuilder: (context, index) {
                          final printer = printerProvider.printers[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 3,
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors
                                    .transparent, // Makes dividers transparent
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                expandedCrossAxisAlignment:
                                    CrossAxisAlignment.start,
                                title: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFFA5D6A7),
                                      radius: 12,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            printer.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${printer.ipAddress} - ${printer.type}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  if (printer.type == 'Item wise')
                                    printer.items.isNotEmpty
                                        ? Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Items:',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                    maxHeight: 200,
                                                  ),
                                                  child: Scrollbar(
                                                    thumbVisibility: true,
                                                    child: ListView.builder(
                                                      shrinkWrap: true,
                                                      physics:
                                                          const AlwaysScrollableScrollPhysics(),
                                                      itemCount:
                                                          printer.items.length,
                                                      itemBuilder:
                                                          (context, itemIndex) {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical:
                                                                      4.0),
                                                          child: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons.circle,
                                                                size: 8,
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Text(
                                                                printer.items[
                                                                    itemIndex],
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            14),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16.0),
                                            child: Text(
                                              'No items assigned',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (printer.type == 'Item wise')
                                        if (printer.type == 'Item wise')
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              if (appType != 'server') {
                                                Flushbar(
                                                  title: 'Access Denied',
                                                  message:
                                                      'Only server device can modify printer details.',
                                                  duration: const Duration(
                                                      seconds: 2),
                                                  backgroundColor:
                                                      Colors.red[600] ??
                                                          Colors.red,
                                                  flushbarPosition:
                                                      FlushbarPosition.BOTTOM,
                                                  margin:
                                                      const EdgeInsets.all(8),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ).show(context);
                                                return;
                                              }
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ItemAssignmentScreen(
                                                          printerIndex: index),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.assignment),
                                            label: const Text(
                                              'Assign Items',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                      // IconButton(
                                      //   icon: const Icon(Icons.edit,
                                      //       color: Colors.green),
                                      //   onPressed: () {
                                      //     if (appType != 'server') {
                                      //       ScaffoldMessenger.of(context)
                                      //           .showSnackBar(
                                      //         const SnackBar(
                                      //           content: Text(
                                      //               'Only server device can modify printer details.'),
                                      //         ),
                                      //       );
                                      //       return;
                                      //     }
                                      //     _showEditPrinterDialog(
                                      //         context, index);
                                      //   },
                                      //   tooltip: 'Edit Printer',
                                      // ),
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.green),
                                        onPressed: () {
                                          if (appType != 'server') {
                                            Flushbar(
                                              title: 'Access Denied',
                                              message:
                                                  'Only server device can modify printer details.',
                                              duration:
                                                  const Duration(seconds: 2),
                                              backgroundColor:
                                                  Colors.red[600] ?? Colors.red,
                                              flushbarPosition:
                                                  FlushbarPosition.BOTTOM,
                                              margin: const EdgeInsets.all(8),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ).show(context);
                                            return;
                                          }
                                          _showEditPrinterDialog(
                                              context, index);
                                        },
                                        tooltip: 'Edit Printer',
                                      ),

                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () {
                                          if (appType != 'server') {
                                            Flushbar(
                                              title: 'Access Denied',
                                              message:
                                                  'Only server device can modify printer details.',
                                              duration:
                                                  const Duration(seconds: 2),
                                              backgroundColor:
                                                  Colors.red[600] ?? Colors.red,
                                              flushbarPosition:
                                                  FlushbarPosition.BOTTOM,
                                              margin: const EdgeInsets.all(8),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ).show(context);
                                            return;
                                          }
                                          _showRemovePrinterDialog(
                                            context,
                                            printerProvider,
                                            webSocketService,
                                            index,
                                          );
                                        },
                                        tooltip: 'Delete Printer',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          //   Text("apptype $appType $serverip"),
          // Positioned widget in your Scaffold
          Positioned(
            top: 5, // Adjust position as needed
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                // Check if app type is not server
                if (appType != 'server') {
                  Flushbar(
                    title: 'Access Denied',
                    message: 'Only server device can modify printer details.',
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.red[600] ?? Colors.red,
                    flushbarPosition: FlushbarPosition.BOTTOM,
                    margin: const EdgeInsets.all(8),
                    borderRadius: BorderRadius.circular(20),
                  ).show(context);
                  return;
                }
                // Otherwise, show the add printer dialog
                _showAddPrinterDialog(context);
              },
              backgroundColor: const Color(0xFFA5D6A7),
              child: const Icon(
                Icons.add,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPrinterDialog(BuildContext context, int index) {
    final printerProvider =
        Provider.of<PrinterProvider>(context, listen: false);
    final webSocketService =
        Provider.of<WebSocketServicekot>(context, listen: false);
    final Printer printer = printerProvider.printers[index];

    // Pre-fill the dialog with the existing printer details
    _nameController.text = printer.name;
    _ipController.text = printer.ipAddress;
    _selectedType = printer.type;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'EDIT PRINTER',
            style: TextStyle(fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Printer Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
                items: <String>['Overall', 'Item wise', 'PreInvoice', 'Invoice']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: 'Printer Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 239, 72, 72),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isEmpty ||
                    _ipController.text.isEmpty) {
                  Flushbar(
                    title: 'All Fields Required',
                    message: 'Please enter both Name and IP Address',
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.red[600] ?? Colors.red,
                    flushbarPosition: FlushbarPosition.BOTTOM,
                    margin: const EdgeInsets.all(8),
                    borderRadius: BorderRadius.circular(20),
                  ).show(context);
                  return;
                }

                final updatedPrinter = Printer(
                  name: _nameController.text,
                  ipAddress: _ipController.text,
                  type: _selectedType,
                  items: printer.items,
                );
                final enteredIp = _ipController.text.trim();

                if (enteredIp.isNotEmpty && _validateIpAddress(enteredIp)) {
                  printerProvider.updatePrinter(updatedPrinter);
                  webSocketService.sendPrinterDetails(updatedPrinter);

                  _nameController.clear();

                  _ipController.clear();
                  setState(() {
                    _selectedType = 'Overall';
                  });
                  Navigator.of(context).pop();
                } else {
                  Flushbar(
                    message: 'Invalid IP Address',
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.red[600] ?? Colors.red,
                    flushbarPosition: FlushbarPosition.BOTTOM,
                    margin: const EdgeInsets.all(8),
                    borderRadius: BorderRadius.circular(20),
                  ).show(context);
                  return;
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA5D6A7),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _validateIpAddress(String ip) {
    final RegExp ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$',
    );
    return ipRegex.hasMatch(ip);
  }
}

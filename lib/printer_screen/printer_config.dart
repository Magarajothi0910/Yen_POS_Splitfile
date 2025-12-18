// // lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/printer_screen/screen/item_asign.dart';

import '../Global/Widget/custom_button_reuse.dart';
import '../Global/Widget/custom_sized_box.dart';

import 'model/printer_model.dart';
import 'provider/printer_config_provider.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.

// ignore: use_key_in_widget_constructors
class PrinterSettingsScreen extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  String _selectedType = 'Overall';

  bool _showUsbDevices =
      false; // State to toggle between USB devices and printers list


  @override
  void initState() {
    super.initState();
    final printerProvider =
        Provider.of<PrinterProviderpos>(context, listen: false);
    printerProvider.initializeHive();
  }

  void _showIPDialog(String deviceId) {
    final _ipTextController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter IP Address for Device'),
          content: TextField(
            controller: _ipTextController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '192.168.1.XXX',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                if (_ipTextController.text.isNotEmpty) {
                  setState(() {
                    Provider.of<PrinterProviderpos>(context, listen: false)
                        .deviceIps[deviceId] = _ipTextController.text;
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddPrinterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'ADD PRINTER',
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
                keyboardType: TextInputType.text, // Use default system keyboard
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType:
                    TextInputType.number, // Use default system keyboard
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: Colors.white,
                value: _selectedType,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
                items: <String>['Overall', 'Item-wise', 'POS', 'Invoice']
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
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isEmpty ||
                    _ipController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter both Name and IP Address'),
                    ),
                  );
                  return;
                }

                final newPrinter = Printer(
                  name: _nameController.text,
                  ipAddress: _ipController.text,
                  type: _selectedType,
                  items: [],
                );

                final printerProvider =
                    Provider.of<PrinterProviderpos>(context, listen: false);

                printerProvider.addPrinter(newPrinter);

                _nameController.clear();
                _ipController.clear();
                setState(() {
                  _selectedType = 'Overall';
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'Add Printer',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRemovePrinterDialog(
      BuildContext context, PrinterProviderpos printerProvider, int index) {
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
                backgroundColor: Colors.lightBlue,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // final printer = printerProvider.printers[index];
                printerProvider.removePrinter(index);

                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
              ),
              child: const Text(
                'Remove',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Example receipt print function
  void testReceipt(NetworkPrinter printer) {
    printer.text(
      'Sample Data',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    printer.feed(2);
    printer.cut();
  }

  @override
  Widget build(BuildContext context) {
    final printerProvider = Provider.of<PrinterProviderpos>(context);

    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Printer Settings'),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            CustomButton(
              text: "Add IP Printer",
              onPressed: () {
                setState(() {
                  _showUsbDevices = false;
                });
              },
              backgroundColor: Colors.blue, // You can customize this if needed
              textColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              fontSize: 16,
            ),
            CustomSizedBox(
              width: 10,
            ),
            CustomButton(
              text: "Add USB Printer",
              onPressed: () {
                setState(() {
                  _showUsbDevices =
                      !_showUsbDevices; // Toggle between showing USB devices or printers
                });
              },
              backgroundColor: Colors.blue, // Keep consistent styling
              textColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              fontSize: 16,
            ),
            CustomSizedBox(
              width: 10,
            ),
            CustomButton(
              text: "Add Bluetooth Printer",
              onPressed: () {
                // Implement functionality for Bluetooth printer setup
                // _showAddBluetoothPrinterDialog(context);
              },
              backgroundColor: Colors.blue, // Keep consistent styling
              textColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              fontSize: 16,
            ),
          ]),
      backgroundColor:
          Colors.white, // Light blue background for the entire Scaffold

      body: printerProvider.printers.isEmpty
          ? Center(
              child: Text(
                'No Printer Config',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const CustomSizedBox(height: 20),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: printerProvider.printers.length,
                      itemBuilder: (context, index) {
                        final printer = printerProvider.printers[index];
                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.all(10.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                const Icon(
                                  Icons.print,
                                  color: Colors.blue,
                                ),
                                const CustomSizedBox(width: 10),
                                Text(
                                  printer.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            subtitle:
                                Text('${printer.ipAddress} - ${printer.type}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (printer.type == 'Item-wise')
                                  IconButton(
                                    icon: const Icon(Icons.assignment),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ItemAssignmentScreen(
                                                  printerIndex: index),
                                        ),
                                      );
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () {
                                    _showEditPrinterDialog(
                                        context, printer, index);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    _showDeleteConfirmationDialog(
                                        context, printerProvider, index);
                                  },
                                ),
                              ],
                            ),
                            children: [
                              if (printer.items.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: Column(
                                    children: printer.items
                                        .map((item) => ListTile(
                                              title: Text(item),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              if (printer.items.isEmpty)
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 16.0),
                                  child: ListTile(
                                    title: Text('No items assigned'),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () {
          _showAddPrinterDialog(context);
        },
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, PrinterProviderpos printerProvider, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this printer?'),
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
                // Perform the delete action
                printerProvider.removePrinter(index);
                Navigator.of(context).pop(); // Close the dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA5D6A7),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditPrinterDialog(
      BuildContext context, Printer printer, int index) {
    _nameController.text = printer.name;
    _ipController.text = printer.ipAddress;
    _selectedType = printer.type;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Edit Printer - ${printer.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Printer Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'IP Address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: Colors.white,
                  value: _selectedType,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedType = newValue!;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Printer Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: <String>['Overall', 'Item-wise', 'POS', 'Invoice']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel',style: TextStyle(color: Colors.black),),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedPrinter = Printer(
                  name: _nameController.text,
                  ipAddress: _ipController.text,
                  type: _selectedType,
                  items: printer.items,
                );

                final printerProvider =
                    Provider.of<PrinterProviderpos>(context, listen: false);
                printerProvider.updatePrinterEdit(index, updatedPrinter);

                _nameController.clear();
                _ipController.clear();
                setState(() {});
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: Text(
                'Update Printer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void snackMessage(BuildContext context, String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }
}

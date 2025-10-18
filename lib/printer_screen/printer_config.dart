// // lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/printer_screen/screen/item_asign.dart';

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
                                  color: Color(0xFFA5D6A7),
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
              child: Text('Cancel'),
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

// class FlutterUsbPrinter {
//   static const MethodChannel _channel =
//       const MethodChannel('flutter_usb_printer');

//   /// [getUSBDeviceList]
//   /// get list of available usb device on android
//   static Future<List<Map<String, dynamic>>> getUSBDeviceList() async {
//     if (Platform.isAndroid) {
//       List<dynamic> devices = await _channel.invokeMethod('getUSBDeviceList');
//       print(devices);
//       var result = devices
//           .cast<Map<dynamic, dynamic>>()
//           .map((e) => Map<String, dynamic>.from(e))
//           .toList();
//       return result;
//     } else {
//       return <Map<String, dynamic>>[];
//     }
//   }

//   /// [connect]
//   /// connect to a printer vai vendorId and productId
//   Future<bool?> connect(int vendorId, int productId) async {
//     Map<String, dynamic> params = {
//       "vendorId": vendorId,
//       "productId": productId
//     };
//     final bool? result = await _channel.invokeMethod('connect', params);
//     return result;
//   }

//   /// [close]
//   /// close the connection after print with usb printer
//   Future<bool?> close() async {
//     final bool? result = await _channel.invokeMethod('close');
//     return result;
//   }

//   /// [printText]
//   /// print text
//   Future<bool?> printText(String text) async {
//     Map<String, dynamic> params = {"text": text};
//     final bool? result = await _channel.invokeMethod('printText', params);
//     return result;
//   }

//   /// [printRawText]
//   /// print raw text
//   Future<bool?> printRawText(String text) async {
//     Map<String, dynamic> params = {"raw": text};
//     final bool? result = await _channel.invokeMethod('printRawText', params);
//     return result;
//   }

//   /// [write]
//   /// write data byte
//   Future<bool?> write(Uint8List data) async {
//     Map<String, dynamic> params = {"data": data};
//     final bool? result = await _channel.invokeMethod('write', params);
//     return result;
//   }
// }
// class USBPrinterService {
//   static Future<void> printSimpleReceipt(
//       UsbDevice device, BuildContext context) async {
//     UsbPort? port;
//     try {
//       port = await device.create();
//       if (!await port!.open()) {
//         throw Exception('Failed to open port');
//       }

//       // Configure port parameters (make sure these match your printer specs)
//       await port.setDTR(true);
//       await port.setRTS(true);
//       await port.setPortParameters(
//           9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

//       // Simple ESC/POS commands
//       Uint8List init = Uint8List.fromList([
//         27, 64, // ESC @ - Initialize printer
//         27, 97, 1, // ESC a 1 - Center alignment
//         27, 33, 0, // ESC ! 0 - Character font A (default)
//       ]);
//       String message = "Hello, USB Printer!\n";
//       Uint8List text = Uint8List.fromList(utf8.encode(message));
//       Uint8List cut =
//           Uint8List.fromList([29, 86, 66, 0]); // GS V B 0 - Partial cut

//       // Write commands to the printer
//       await port.write(init);
//       await port.write(text);
//       await port.write(cut);

//       print('Data written to printer');
//     } catch (e) {
//       print('Error during printing: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error during printing: ${e.toString()}')),
//       );
//     } finally {
//       await port!.close();
//     }
//   }
// }



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:usb_serial/usb_serial.dart';
// import 'provider/printer_config_provider.dart'; // Adjust the import path as necessary

// class PrinterSettingsScreen extends StatefulWidget {
//   @override
//   _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
// }

// class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
//   List<UsbDevice>? devices;

//   @override
//   void initState() {
//     super.initState();
//     _listDevices();
//   }

//   void _listDevices() async {
//     try {
//       var results = await UsbSerial.listDevices();
//       setState(() {
//         devices = results;
//       });
//     } catch (e) {
//       print("Error listing devices: $e");
//     }
//   }

//   void _showIPDialog(String deviceId) {
//     final _ipTextController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Enter IP Address for Device'),
//           content: TextField(
//             controller: _ipTextController,
//             keyboardType: TextInputType.number,
//             decoration: InputDecoration(
//               hintText: '192.168.1.XXX',
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             TextButton(
//               child: Text('Save'),
//               onPressed: () {
//                 if (_ipTextController.text.isNotEmpty) {
//                   setState(() {
//                     Provider.of<PrinterProvider>(context, listen: false)
//                         .deviceIps[deviceId] = _ipTextController.text;
//                   });
//                   Navigator.of(context).pop();
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('USB Serial Devices'),
//       ),
//       body: devices == null
//           ? Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: devices!.length,
//               itemBuilder: (context, index) {
//                 UsbDevice device = devices![index];
//                 String deviceId = '${device.vid}:${device.pid}';
//                 return ListTile(
//                   leading: Icon(Icons.usb),
//                   title: Text(device.productName ?? "Unknown Device"),
//                   subtitle: Text(
//                       'Vendor ID: ${device.vid}, Product ID: ${device.pid}'),
//                   trailing: Text(Provider.of<PrinterProvider>(context)
//                           .deviceIps[deviceId] ??
//                       'No IP Set'),
//                   onTap: () => _showIPDialog(deviceId),
//                 );
//               },
//             ),
//     );
//   }
// }






















// import 'package:flutter/material.dart';
// import 'package:yenposapp//screens/printer_screen/find_network_config_provider.dart';

// class PrinterSettingsScreen extends StatefulWidget {
//   @override
//   _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
// }

// class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
//   List<String> _detectedPrinters = [];
//   bool _isScanning = false;

//   void _scanForPrinters() async {
//     setState(() {
//       _isScanning = true;
//     });

//     try {
//       final printers = await NetworkPrinterScanner.discoverPrinters(9100);
//       setState(() {
//         _detectedPrinters = printers;
//         _isScanning = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isScanning = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error scanning for printers: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Printer Settings'),
//       ),
//       body: _isScanning
//           ? const Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: _detectedPrinters.length,
//               itemBuilder: (context, index) {
//                 final printerIp = _detectedPrinters[index];
//                 return ListTile(
//                   title: Text(printerIp),
//                   trailing: IconButton(
//                     icon: const Icon(Icons.add),
//                     onPressed: () {
//                       // Logic to add this printer IP
//                       print('Selected Printer: $printerIp');
//                     },
//                   ),
//                 );
//               },
//             ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _scanForPrinters,
//         child: const Icon(Icons.search),
//       ),
//     );
//   }
// }
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:multicast_dns/multicast_dns.dart';
// import 'package:ping_discover_network_forked/ping_discover_network_forked.dart';

// void main() {
//   runApp(MaterialApp(
//     home: PrinterSettingsScreen(),
//   ));
// }

// class PrinterSettingsScreen extends StatefulWidget {
//   final String? title;

//   const PrinterSettingsScreen({Key? key, this.title}) : super(key: key);

//   @override
//   State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
// }

// class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
//   final List<String> _printerIPs = [];
//   final int _printerPort = 9100; // Common port for network printers

//   @override
//   void initState() {
//     super.initState();
//     discoverNetworkPrinters();
//   }

//   void discoverNetworkPrinters() async {
//     final String subnet = '192.168.1';
//     final int subnetMask = 24; // Assuming a subnet mask of 255.255.255.0

//     // This stream will handle network discovery for printers.
//     final stream = NetworkAnalyzer.discover2(
//       subnet,
//       _printerPort,
//       timeout: Duration(milliseconds: 5000),
//     );

//     stream.listen((NetworkAddress addr) {
//       if (addr.exists) {
//         setState(() {
//           _printerIPs.add('${addr.ip}:$_printerPort');
//         });
//       }
//     }).onDone(() {
//       print('Network scan complete. Found ${_printerIPs.length} devices.');
//       discoverPrintersWithMDns(); // Proceed to discover printers using mDNS after network scan is complete.
//     });
//   }

//   void discoverPrintersWithMDns() async {
//     final MDnsClient client = MDnsClient();
//     try {
//       await client.start();

//       await for (PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
//           ResourceRecordQuery.serverPointer('_ipp._tcp'))) {
//         await for (final SrvResourceRecord srv
//             in client.lookup<SrvResourceRecord>(
//                 ResourceRecordQuery.service(ptr.domainName))) {
//           setState(() {
//             _printerIPs.add('${srv.target}:${srv.port}');
//           });
//         }
//       }
//     } catch (e) {
//       print('Error during mDNS discovery: $e');
//     } finally {
//       client.stop();
//       print('mDNS discovery complete.');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.title ?? 'Printer IPs'),
//       ),
//       body: _printerIPs.isEmpty
//           ? Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: _printerIPs.length,
//               itemBuilder: (context, index) {
//                 return ListTile(
//                   title: Text(_printerIPs[index]),
//                 );
//               },
//             ),
//     );
//   }
// }
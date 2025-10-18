// import 'dart:async';
// import 'dart:developer';
// import 'dart:io';

// import 'package:esc_pos_utils/esc_pos_utils.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatefulWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   State<MyApp> createState() => _MyAppState();
// }


// class _MyAppState extends State<MyApp> {
//   final printerManager = PrinterManager.instance;

//   List<BluetoothPrinter> devices = [];
//   BluetoothPrinter? selectedPrinter;
//   bool _isConnected = false;
//   List<int>? pendingTask;

//   @override
//   void initState() {
//     super.initState();
//     _scanForUSBPrinters();
//   }

//   @override
//   void dispose() {
//     super.dispose();
//   }

//   /// Scan for USB printers
//   void _scanForUSBPrinters() {
//     devices.clear();
//     printerManager.discovery(type: PrinterType.usb).listen((device) {
//       devices.add(BluetoothPrinter(
//         deviceName: device.name,
//         vendorId: device.vendorId,
//         productId: device.productId,
//         typePrinter: PrinterType.usb,
//       ));
//       setState(() {});
//     });
//   }

//   /// Select a USB printer
//   void selectDevice(BluetoothPrinter device) async {
//     if (selectedPrinter != null && selectedPrinter!.vendorId != device.vendorId) {
//       await printerManager.disconnect(type: PrinterType.usb);
//     }

//     selectedPrinter = device;
//     setState(() {});
//   }

//   /// Connect to the selected USB printer
//   Future<void> _connectToUSBPrinter() async {
//     if (selectedPrinter == null) return;

//     await printerManager.connect(
//       type: PrinterType.usb,
//       model: UsbPrinterInput(
//         name: selectedPrinter!.deviceName,
//         productId: selectedPrinter!.productId,
//         vendorId: selectedPrinter!.vendorId,
//       ),
//     );
//     setState(() {
//       _isConnected = true;
//     });
//   }

//   /// Disconnect from the printer
//   Future<void> _disconnectPrinter() async {
//     if (selectedPrinter == null) return;

//     await printerManager.disconnect(type: PrinterType.usb);
//     setState(() {
//       _isConnected = false;
//     });
//   }

//   /// Test print function
//   Future<void> _printTest() async {
//     if (selectedPrinter == null) return;

//     final profile = await CapabilityProfile.load();
//     final generator = Generator(PaperSize.mm80, profile);

//     List<int> bytes = [];
//     bytes += generator.text(
//       'Test Print',
//       styles: const PosStyles(align: PosAlign.center, bold: true),
//     );
//     bytes += generator.text('Product 1');
//     bytes += generator.text('Product 2');
//     bytes += generator.feed(2);
//     bytes += generator.cut();

//     await printerManager.send(
//       type: PrinterType.usb,
//       bytes: bytes,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('USB Printer Example')),
//         body: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             children: [
//               ElevatedButton(
//                 onPressed: _scanForUSBPrinters,
//                 child: const Text('Scan for USB Printers'),
//               ),
//               const SizedBox(height: 10),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: devices.length,
//                   itemBuilder: (context, index) {
//                     final device = devices[index];
//                     return ListTile(
//                       title: Text(device.deviceName ?? 'Unknown Printer'),
//                       subtitle: Text('Vendor ID: ${device.vendorId}, Product ID: ${device.productId}'),
//                       trailing: OutlinedButton(
//                         onPressed: selectedPrinter == device && _isConnected
//                             ? _printTest
//                             : null,
//                         child: const Text('Print Test'),
//                       ),
//                       onTap: () {
//                         selectDevice(device);
//                         _connectToUSBPrinter();
//                       },
//                       leading: selectedPrinter == device
//                           ? const Icon(Icons.check, color: Colors.green)
//                           : null,
//                     );
//                   },
//                 ),
//               ),
//               ElevatedButton(
//                 onPressed: _isConnected ? _disconnectPrinter : null,
//                 child: const Text('Disconnect Printer'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class BluetoothPrinter {
//   String? deviceName;
//   String? vendorId;
//   String? productId;
//   PrinterType typePrinter;

//   BluetoothPrinter({
//     this.deviceName,
//     this.vendorId,
//     this.productId,
//     required this.typePrinter,
//   });
// }


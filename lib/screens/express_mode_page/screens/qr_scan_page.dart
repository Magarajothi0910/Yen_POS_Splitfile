// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';

// class SimpleSalesOrderScreen extends StatefulWidget {
//   @override
//   _SimpleSalesOrderScreenState createState() => _SimpleSalesOrderScreenState();
// }

// class _SimpleSalesOrderScreenState extends State<SimpleSalesOrderScreen> {
//   TextEditingController searchController = TextEditingController();
//   MobileScannerController scannerController = MobileScannerController(
//     detectionSpeed: DetectionSpeed.noDuplicates,
//   );

//   bool isProcessingScan = false; // To handle duplicate scans
//   Timer? debounceTimer; // Debounce mechanism

//   Future<void> _startScanning() async {
//     await Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (context) => Scaffold(
//           appBar: AppBar(
//             title: const Text('Scan QR Code'),
//             backgroundColor: Colors.blue,
//           ),
//           body: Column(
//             children: [
//               Expanded(
//                 child: AiBarcodeScanner(
//                   controller: scannerController,
//                   hideGalleryButton: true,
//                   onDispose: () {
//                     debugPrint("Scanner disposed");
//                   },
//                   onDetect: (BarcodeCapture capture) async {
//                     if (isProcessingScan) return;

//                     // Debounce mechanism to handle duplicate scans
//                     debounceTimer?.cancel();
//                     debounceTimer =
//                         Timer(const Duration(milliseconds: 300), () {
//                       isProcessingScan = true;

//                       if (capture.barcodes.isNotEmpty) {
//                         final scannedValue = capture.barcodes.first.rawValue;

//                         if (scannedValue != null) {
//                           debugPrint("Scanned QR Code: $scannedValue");
//                         } else {
//                           debugPrint("Invalid QR code scanned.");
//                         }
//                       }

//                       setState(() {
//                         isProcessingScan = false;
//                       });
//                     });
//                   },
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: ElevatedButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: const Text('Close Scanner'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Simple Sales Order Screen'),
//         backgroundColor: Colors.blue,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // Search Bar
//             TextField(
//               controller: searchController,
//               decoration: InputDecoration(
//                 labelText: 'Search Item',
//                 border: OutlineInputBorder(),
//                 prefixIcon: const Icon(Icons.search),
//                 suffixIcon: IconButton(
//                   icon: const Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       searchController.clear();
//                     });
//                   },
//                 ),
//               ),
//               onChanged: (value) {
//                 debugPrint("Search query: $value");
//               },
//             ),
//             const SizedBox(height: 20),

//             // QR Scanner Button
//             ElevatedButton.icon(
//               onPressed: _startScanning,
//               icon: const Icon(Icons.qr_code_scanner),
//               label: const Text('Scan QR Code'),
//               style: ElevatedButton.styleFrom(
//                 padding:
//                     const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

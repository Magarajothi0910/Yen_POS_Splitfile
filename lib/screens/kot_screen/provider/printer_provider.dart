// // import 'package:flutter/material.dart';
// // import 'package:hive/hive.dart';
// // import '../models/printer.dart';

// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';

// class Printer {
//   final String name;
//   final String ipAddress;
//   final String type;
//   List<String> items; // Stores item names instead of IDs
//   late Map<String, String> itemIpMap;

//   Printer({
//     required this.name,
//     required this.ipAddress,
//     required this.type,
//     List<String>? items, // Pass item names directly
//   }) : items = items ?? [] {
//     itemIpMap = {};
//     for (var item in this.items) {
//       itemIpMap[item] = ipAddress;
//     }
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'name': name,
//       'ipAddress': ipAddress,
//       'type': type,
//       'items': items,
//     };
//   }

//   factory Printer.fromJson(Map<String, dynamic> json) {
//     return Printer(
//       name: json['name'],
//       ipAddress: json['ipAddress'],
//       type: json['type'],
//       items: List<String>.from(json['items'] ?? []),
//     );
//   }
// }

// class KotPrinterProvider with ChangeNotifier {
//   late Box _printerBox;
//   List<Printer> _printers = [];
//   List<Printer> get printers => _printers;
//   String? _clientIp;

//   String? get clientIp => _clientIp;
//   Future<void> initializeHive() async {
//     print("init hive");

//     try {
//       _printerBox = await Hive.openBox('printers');
//       _clientIp = _printerBox.get('clientIp');
//       print('Retrieved Client IP from Hive: $_clientIp');

//       _loadPrintersFromHive();
//     } catch (e) {
//       print("Error opening Hive box: $e");
//     }
//   }

//   Future<void> saveClientIp(String? clientIp) async {
//     _clientIp = clientIp;
//     await _printerBox.put('clientIp', clientIp);
//     print('Client IP saved to Hive: $clientIp');
//     notifyListeners();
//   }

//   void _loadPrintersFromHive() {
//     print("LOAD.. hive");

//     try {
//       final data = _printerBox.get('data');
//       print("Retrieved data from Hive: $data");

//       if (data != null && data is List) {
//         _printers = data
//             .map((json) {
//               if (json is Map) {
//                 final map = Map<String, dynamic>.from(json);
//                 return Printer.fromJson(map);
//               } else {
//                 print("Invalid data format: $json");
//                 return null;
//               }
//             })
//             .whereType<Printer>()
//             .toList();

//         notifyListeners();
//         print("_printers....4");
//         print(_printers);
//       } else {
//         print("No data found in Hive or data is not a list");
//       }
//     } catch (e) {
//       print("Error loading data from Hive: $e");
//     }
//   }

//   void addPrinter(Printer printer) {
//     if (_printers.any((p) => p.name == printer.name)) {
//       print("Printer already exists: ${printer.name}");
//       return;
//     }
//     print("Adding printer: ${printer.name}");

//     final newPrinter = Printer(
//       name: printer.name,
//       ipAddress: printer.ipAddress,
//       type: printer.type,
//       items: printer.items,
//     );

//     _printers.add(newPrinter);
//     _savePrintersToHive();
//   }

//   // void updatePrinter(Printer updatedPrinter) {
//   //   final index =
//   //       _printers.indexWhere((printer) => printer.name == updatedPrinter.name);
//   //   if (index != -1) {
//   //     _printers[index] = updatedPrinter;
//   //     _savePrintersToHive();
//   //   }
//   // }
//   void updatePrinter(Printer updatedPrinter) {
//     final index =
//         _printers.indexWhere((printer) => printer.name == updatedPrinter.name);
//     if (index != -1) {
//       _printers[index] = updatedPrinter;
//       _savePrintersToHive(); // Save updated printers to Hive storage
//       notifyListeners(); // Notify listeners to update UI
//     }
//   }

//   void removePrinter(var index) {
//     _printers.removeAt(index);
//     _savePrintersToHive();
//   }

//   void removePrinterByName(String printerName) {
//     final index =
//         _printers.indexWhere((printer) => printer.name == printerName);
//     if (index != -1) {
//       _printers.removeAt(index);
//       _savePrintersToHive();
//       notifyListeners();
//     }
//   }

//   void _savePrintersToHive() {
//     final data = _printers.map((printer) => printer.toJson()).toList();
//     _printerBox.put('data', data);
//     print("Data saved to Hive: ${_printerBox.get('data')}");
//     notifyListeners();
//   }

//   String? getPrinterIpForItem(String itemName) {
//     itemName = itemName.trim().toLowerCase(); // Normalize the item name
//     for (final printer in _printers) {
//       print("priinter itemnaem..");
//       print(itemName);
//       print(printer.ipAddress);
//       for (final item in printer.items) {
//         print("Checking item: $item"); // Add this line for debugging
//         if (item.trim().toLowerCase() == itemName) {
//           return printer.ipAddress;
//         }
//       }
//     }
//     return null;
//   }

//   String? getOverallPrinterIp() {
//     for (var printer in _printers) {
//       if (printer.type == 'Overall') {
//         return printer.ipAddress;
//       }
//     }
//     return null;
//   }
// }

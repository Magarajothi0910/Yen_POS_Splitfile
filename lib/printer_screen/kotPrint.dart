// import 'package:flutter/material.dart';
// import 'package:yenpos/Global/globals_data.dart';
// import 'package:provider/provider.dart';
// import '../providers/upi_provider.dart';
// import '../components/flushbar.dart';
// import '../services/validateIpAddress.dart';
// import '../services/websocketService.dart';
// import '../providers/printer_provider.dart';
// import '../models/printer.dart';
// import 'item_assignment_screen.dart';

// class PrinterSettingsScreen extends StatefulWidget {
//   const PrinterSettingsScreen({super.key});

//   @override
//   _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
// }

// class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
//   final _nameController = TextEditingController();
//   final _ipController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();

//   // Helper to check if appType is server
//   bool _isServerApp() => appType == 'server';

//   @override
//   void initState() {
//     super.initState();
//     UpiProviderDine upiProvider = Provider.of<UpiProviderDine>(context, listen: false);
//     print('🛠️ Initializing PrinterSettingsScreen');
//   }

//   @override
//   void dispose() {
//     try {
//       _nameController.dispose();
//       _ipController.dispose();
//       _scrollController.dispose();
//       print('🧹 Disposed controllers successfully');
//     } catch (e) {
//       print('❌ Failed to dispose controllers: $e');
//     }
//     super.dispose();
//   }

//   void _showAddPrinterDialog(BuildContext context) {
//     if (_isServerApp()) {
//       print('🔒 Access denied: App type is not server');
//       showCustomFlushbar(
//         context,
//         "Only server device can modify printer details.",
//         type: FlushbarType.accessDenied,
//       );
//       return;
//     }

//     try {
//       print('📝 Showing add printer dialog');
//       final printerProvider = Provider.of<PrinterProviderDine>(context, listen: false);
//       printerProvider.setSelectedType('Overall');

//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             backgroundColor: Colors.white,
//             title: const Text(
//               'ADD PRINTER',
//               style: TextStyle(fontSize: 18),
//             ),
//             content: Consumer<PrinterProviderDine>(
//               builder: (context, provider, child) {
//                 return Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const SizedBox(height: 2),
//                     TextField(
//                       controller: _nameController,
//                       decoration: InputDecoration(
//                         labelText: 'Printer Name',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     TextField(
//                       keyboardType: TextInputType.number,
//                       controller: _ipController,
//                       decoration: InputDecoration(
//                         labelText: 'IP Address',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     DropdownButtonFormField<String>(
//                       value: provider.selectedType,
//                       onChanged: (String? newValue) {
//                         try {
//                           provider.setSelectedType(newValue!);
//                           print('🔄 Printer type updated to: $newValue');
//                         } catch (e) {
//                           print('❌ Failed to update printer type to $newValue: $e');
//                           showCustomFlushbar(
//                             context,
//                             'Failed to update printer type',
//                             type: FlushbarType.error,
//                           );
//                         }
//                       },
//                       items: <String>['Overall', 'Item wise', 'PreInvoice', 'Invoice'].map<DropdownMenuItem<String>>((String value) {
//                         return DropdownMenuItem<String>(
//                           value: value,
//                           child: Text(value),
//                         );
//                       }).toList(),
//                       decoration: InputDecoration(
//                         labelText: 'Printer Type',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                     ),
//                   ],
//                 );
//               },
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   print('🚫 Add printer dialog cancelled');
//                   Navigator.of(context).pop();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                   backgroundColor: const Color.fromARGB(255, 239, 72, 72),
//                 ),
//                 child: const Text(
//                   'Cancel',
//                   style: TextStyle(color: Colors.black),
//                 ),
//               ),
//               ElevatedButton(
//                 onPressed: () async {
//                   try {
//                     if (_nameController.text.isEmpty || _ipController.text.isEmpty) {
//                       print('⚠️ Validation failed: Printer name or IP address is empty');
//                       if (!mounted) return;
//                       showCustomFlushbar(
//                         context,
//                         'Please enter both Name and IP Address',
//                         type: FlushbarType.warning,
//                       );
//                       return;
//                     }

//                     final enteredIp = _ipController.text.trim();
//                     if (!validateIpAddress(enteredIp)) {
//                       print('⚠️ Invalid IP address format: $enteredIp');
//                       if (!mounted) return;
//                       showCustomFlushbar(
//                         context,
//                         'Invalid IP address format',
//                         type: FlushbarType.error,
//                       );
//                       return;
//                     }

//                     final newPrinter = Printer(
//                       name: _nameController.text.trim(),
//                       ipAddress: enteredIp,
//                       type: printerProvider.selectedType,
//                       items: [],
//                     );

//                     print("🖨️ Creating new printer: ${newPrinter.toJson()}");
//                     final webSocketService = Provider.of<WebSocketServiceDine>(context, listen: false);
//                     printerProvider.addPrinter(newPrinter);
//                     print('🖨️ Added printer: ${newPrinter.name} (IP: ${newPrinter.ipAddress}, Type: ${newPrinter.type})');

//                     try {
//                       webSocketService.sendPrinterDetails(newPrinter);
//                       print('📤 Sent printer details for ${newPrinter.name} via WebSocket');
//                     } catch (e) {
//                       print('⚠️ Failed to send WebSocket update for ${newPrinter.name}: $e');
//                       // Continue execution even if WebSocket fails
//                     }

//                     _nameController.clear();
//                     _ipController.clear();
//                     printerProvider.setSelectedType('Overall');
//                     print('🟢 Add printer dialog completed successfully');
//                     if (!mounted) return;
//                     Navigator.of(context).pop();

//                     // Verify the printer was added
//                     print("🔍 Verifying printers after adding: ${printerProvider.printers.map((p) => p.toJson())}");
//                   } catch (e) {
//                     print('❌ Failed to add printer ${_nameController.text} (IP: ${_ipController.text}): $e');
//                     if (!mounted) return;
//                     showCustomFlushbar(
//                       context,
//                       'Failed to add printer: $e',
//                       type: FlushbarType.error,
//                     );
//                   }
//                 },
//                 style: ElevatedButton.styleFrom(
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                   backgroundColor: const Color(0xFFA5D6A7),
//                 ),
//                 child: const Text(
//                   'Add Printer',
//                   style: TextStyle(color: Colors.black),
//                 ),
//               ),
//             ],
//           );
//         },
//       );
//     } catch (e) {
//       print('❌ Failed to show add printer dialog: $e');
//       if (!mounted) return;
//       showCustomFlushbar(
//         context,
//         'Failed to open add printer dialog',
//         type: FlushbarType.error,
//       );
//     }
//   }

//   void _showRemovePrinterDialog(BuildContext context, PrinterProviderDine printerProvider, WebSocketServiceDine webSocketService, int index) {
//     if (!_isServerApp()) {
//       print('🔒 Access denied: App type is not server');
//       showCustomFlushbar(
//         context,
//         'Only server device can modify printer details.',
//         type: FlushbarType.accessDenied,
//       );
//       return;
//     }

//     try {
//       final printer = printerProvider.printers[index];
//       print('📝 Showing remove printer dialog for ${printer.name}');
//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             backgroundColor: Colors.white,
//             title: const Text('Remove Printer'),
//             content: Text('Are you sure you want to remove printer "${printer.name}"?'),
//             actions: [
//               ElevatedButton(
//                 onPressed: () {
//                   print('🚫 Remove printer dialog cancelled for ${printer.name}');
//                   Navigator.of(context).pop();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                   backgroundColor: const Color.fromARGB(255, 239, 72, 72),
//                 ),
//                 child: const Text(
//                   'Cancel',
//                   style: TextStyle(color: Colors.black),
//                 ),
//               ),
//               ElevatedButton(
//                 onPressed: () async {
//                   try {
//                     printerProvider.removePrinter(index);
//                     print('🗑️ Removed printer: ${printer.name}');
//                     webSocketService.sendRemovePrinter(printer.name);
//                     print('📤 Sent remove request for printer ${printer.name} via WebSocket');
//                     Navigator.of(context).pop();
//                   } catch (e) {
//                     print('❌ Failed to remove printer ${printer.name}: $e');

//                     if (context.mounted) {
//                       WidgetsBinding.instance.addPostFrameCallback(
//                         (_) => showCustomFlushbar(
//                           context,
//                           'Failed to remove printer: $e',
//                           type: FlushbarType.error,
//                         ),
//                       );
//                     } else {
//                       print('⚠️ Skipped flushbar, context disposed');
//                     }
//                   }
//                 },
//                 style: ElevatedButton.styleFrom(
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                   backgroundColor: const Color(0xFFA5D6A7),
//                 ),
//                 child: const Text(
//                   'Remove',
//                   style: TextStyle(color: Colors.black),
//                 ),
//               ),
//             ],
//           );
//         },
//       );
//     } catch (e) {
//       print('❌ Failed to show remove printer dialog for index $index: $e');

//       if (context.mounted) {
//         WidgetsBinding.instance.addPostFrameCallback(
//           (_) => showCustomFlushbar(
//             context,
//             'Failed to open remove printer dialog',
//             type: FlushbarType.error,
//           ),
//         );
//       } else {
//         print('⚠️ Skipped flushbar, context disposed');
//       }
//     }
//   }

//   void _showEditPrinterDialog(BuildContext context, int index) {
//     if (!_isServerApp()) {
//       print('🔒 Access denied: App type is not server');

//       if (context.mounted) {
//         WidgetsBinding.instance.addPostFrameCallback(
//           (_) => showCustomFlushbar(
//             context,
//             'Only server device can modify printer details',
//             type: FlushbarType.accessDenied,
//           ),
//         );
//       } else {
//         print('⚠️ Skipped flushbar, context disposed');
//       }

//       return;
//     }

//     try {
//       final printerProvider = Provider.of<PrinterProviderDine>(context, listen: false);
//       final webSocketService = Provider.of<WebSocketServiceDine>(context, listen: false);
//       final Printer printer = printerProvider.printers[index];
//       print('📝 Showing edit printer dialog for ${printer.name}');

//       _nameController.text = printer.name;
//       _ipController.text = printer.ipAddress;
//       printerProvider.setSelectedType(printer.type);

//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             backgroundColor: Colors.white,
//             title: const Text(
//               'EDIT PRINTER',
//               style: TextStyle(fontSize: 18),
//             ),
//             content: Consumer<PrinterProviderDine>(
//               builder: (context, provider, child) {
//                 return Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const SizedBox(height: 16),
//                     TextField(
//                       controller: _nameController,
//                       decoration: InputDecoration(
//                         labelText: 'Printer Name',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     TextField(
//                       keyboardType: TextInputType.number,
//                       controller: _ipController,
//                       decoration: InputDecoration(
//                         labelText: 'IP Address',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     DropdownButtonFormField<String>(
//                       value: provider.selectedType,
//                       onChanged: (String? newValue) {
//                         try {
//                           provider.setSelectedType(newValue!);
//                           print('🔄 Printer type updated to: $newValue');
//                         } catch (e) {
//                           print('❌ Failed to update printer type to $newValue: $e');

//                           if (context.mounted) {
//                             WidgetsBinding.instance.addPostFrameCallback(
//                               (_) => showCustomFlushbar(
//                                 context,
//                                 'Failed to update printer type',
//                                 type: FlushbarType.error,
//                               ),
//                             );
//                           } else {
//                             print('⚠️ Skipped flushbar, context disposed');
//                           }
//                         }
//                       },
//                       items: <String>['Overall', 'Item wise', 'PreInvoice', 'Invoice'].map<DropdownMenuItem<String>>((String value) {
//                         return DropdownMenuItem<String>(
//                           value: value,
//                           child: Text(value),
//                         );
//                       }).toList(),
//                       decoration: InputDecoration(
//                         labelText: 'Printer Type',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                     ),
//                   ],
//                 );
//               },
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   print('🚫 Edit printer dialog cancelled for ${printer.name}');
//                   Navigator.of(context).pop();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                   backgroundColor: const Color.fromARGB(255, 239, 72, 72),
//                 ),
//                 child: const Text(
//                   'Cancel',
//                   style: TextStyle(color: Colors.black),
//                 ),
//               ),
//               ElevatedButton(
//                 onPressed: () async {
//                   try {
//                     if (_nameController.text.isEmpty || _ipController.text.isEmpty) {
//                       debugPrint('⚠️ Validation failed: Printer name or IP address is empty');

//                       if (context.mounted) {
//                         WidgetsBinding.instance.addPostFrameCallback(
//                           (_) => showCustomFlushbar(
//                             context,
//                             'Please enter both Name and IP Address',
//                             type: FlushbarType.error,
//                           ),
//                         );
//                       } else {
//                         debugPrint('⚠️ Skipped flushbar, context disposed');
//                       }

//                       return;
//                     }

//                     final enteredIp = _ipController.text.trim();
//                     if (!validateIpAddress(enteredIp)) {
//                       debugPrint('⚠️ Invalid IP address format: $enteredIp');
//                       if (context.mounted) {
//                         WidgetsBinding.instance.addPostFrameCallback((_) {
//                           showCustomFlushbar(
//                             context,
//                             'Invalid IP address format',
//                             type: FlushbarType.error,
//                           );
//                         });
//                       } else {
//                         debugPrint('⚠️ Skipped flushbar, context disposed');
//                       }
//                       return;
//                     }

//                     final updatedPrinter = Printer(
//                       name: _nameController.text,
//                       ipAddress: enteredIp,
//                       type: printerProvider.selectedType,
//                       items: printer.items,
//                     );

//                     // FIXED: Pass both index and updatedPrinter to the update method
//                     printerProvider.updatePrinter(index, updatedPrinter);
//                     print('🖨️ Updated printer at index $index: ${updatedPrinter.name} (IP: ${updatedPrinter.ipAddress}, Type: ${updatedPrinter.type})');
//                     webSocketService.sendPrinterDetails(updatedPrinter);
//                     print('📤 Sent updated printer details for ${updatedPrinter.name} via WebSocket');

//                     _nameController.clear();
//                     _ipController.clear();
//                     printerProvider.setSelectedType('Overall');
//                     print('🟢 Edit printer dialog completed successfully');
//                     Navigator.of(context).pop();
//                   } catch (e, st) {
//                     debugPrint('❌ Failed to update printer ${_nameController.text} (IP: ${_ipController.text}): $e\n$st');

//                     if (context.mounted) {
//                       WidgetsBinding.instance.addPostFrameCallback((_) {
//                         showCustomFlushbar(
//                           context,
//                           'Failed to update printer: $e',
//                           type: FlushbarType.error,
//                         );
//                       });
//                     } else {
//                       debugPrint('⚠️ Skipped flushbar, context disposed');
//                     }
//                   }
//                 },
//                 style: ElevatedButton.styleFrom(
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                   backgroundColor: const Color(0xFFA5D6A7),
//                 ),
//                 child: const Text(
//                   'Save Changes',
//                   style: TextStyle(color: Colors.black),
//                 ),
//               ),
//             ],
//           );
//         },
//       );
//     } catch (e, st) {
//       debugPrint('❌ Failed to show edit printer dialog for index $index: $e\n$st');

//       if (context.mounted) {
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           showCustomFlushbar(
//             context,
//             'Failed to open edit printer dialog',
//             type: FlushbarType.error,
//           );
//         });
//       } else {
//         debugPrint('⚠️ Skipped flushbar, context disposed');
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     try {
//       print('🏗️ Building PrinterSettingsScreen');
//       final printerProvider = Provider.of<PrinterProviderDine>(context);
//       try {
//         printerProvider.loadPrintersFromHive();
//         print('📂 Loaded printers from Hive successfully');
//       } catch (e, st) {
//         debugPrint('❌ Failed to load printers from Hive: $e\n$st');

//         if (context.mounted) {
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             showCustomFlushbar(
//               context,
//               'Failed to load printers from storage',
//               type: FlushbarType.error,
//             );
//           });
//         } else {
//           debugPrint('⚠️ Skipped flushbar, context disposed');
//         }
//       }

//       final webSocketService = Provider.of<WebSocketServiceDine>(context, listen: false);

//       return Scaffold(
//         backgroundColor: Colors.white,
//         body: Stack(
//           children: [
//             SingleChildScrollView(
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   children: [
//                     if (printerProvider.printers.isEmpty)
//                       const Center(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             SizedBox(height: 50),
//                             Icon(Icons.info_outline, size: 40, color: Colors.grey),
//                             SizedBox(height: 16),
//                             Text(
//                               "No printers added yet.",
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.grey,
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             Text(
//                               "Tap the '+' icon to add printer details.",
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 color: Colors.grey,
//                               ),
//                             ),
//                           ],
//                         ),
//                       )
//                     else
//                       Padding(
//                         padding: const EdgeInsets.only(top: 50.0),
//                         child: ListView.builder(
//                           shrinkWrap: true,
//                           physics: const NeverScrollableScrollPhysics(),
//                           itemCount: printerProvider.printers.length,
//                           itemBuilder: (context, index) {
//                             try {
//                               final printer = printerProvider.printers[index];
//                               print('📋 Building card for printer: ${printer.name}');
//                               return Card(
//                                 color: Colors.white,
//                                 margin: const EdgeInsets.symmetric(vertical: 8.0),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(10),
//                                 ),
//                                 elevation: 3,
//                                 child: Theme(
//                                   data: Theme.of(context).copyWith(
//                                     dividerColor: Colors.transparent,
//                                   ),
//                                   child: ExpansionTile(
//                                     tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
//                                     expandedCrossAxisAlignment: CrossAxisAlignment.start,
//                                     title: Row(
//                                       children: [
//                                         CircleAvatar(
//                                           backgroundColor: Colors.blue[100],
//                                           radius: 12,
//                                           child: Text(
//                                             '${index + 1}',
//                                             style: const TextStyle(
//                                               color: Colors.blue,
//                                               fontSize: 12,
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                           ),
//                                         ),
//                                         const SizedBox(width: 10),
//                                         Expanded(
//                                           child: Column(
//                                             crossAxisAlignment: CrossAxisAlignment.start,
//                                             children: [
//                                               Text(
//                                                 printer.name,
//                                                 style: const TextStyle(
//                                                   fontWeight: FontWeight.bold,
//                                                   fontSize: 16,
//                                                 ),
//                                               ),
//                                               const SizedBox(height: 4),
//                                               Text(
//                                                 '${printer.ipAddress} - ${printer.type}',
//                                                 style: const TextStyle(
//                                                   fontSize: 14,
//                                                   color: Colors.blue,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                     children: [
//                                       if (printer.type == 'Item wise')
//                                         printer.items.isNotEmpty
//                                             ? Padding(
//                                                 padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                                                 child: Column(
//                                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                                   children: [
//                                                     const Text(
//                                                       'Items:',
//                                                       style: TextStyle(
//                                                         fontSize: 14,
//                                                         fontWeight: FontWeight.bold,
//                                                       ),
//                                                     ),
//                                                     const SizedBox(height: 8),
//                                                     Container(
//                                                       constraints: const BoxConstraints(maxHeight: 200),
//                                                       child: Scrollbar(
//                                                         thumbVisibility: true,
//                                                         controller: _scrollController,
//                                                         child: ListView.builder(
//                                                           shrinkWrap: true,
//                                                           controller: _scrollController,
//                                                           physics: const AlwaysScrollableScrollPhysics(),
//                                                           itemCount: printer.items.length,
//                                                           itemBuilder: (context, itemIndex) {
//                                                             return Padding(
//                                                               padding: const EdgeInsets.symmetric(vertical: 4.0),
//                                                               child: SingleChildScrollView(
//                                                                 scrollDirection: Axis.horizontal,
//                                                                 child: Row(
//                                                                   children: [
//                                                                     const Icon(
//                                                                       Icons.circle,
//                                                                       size: 8,
//                                                                       color: Colors.black,
//                                                                     ),
//                                                                     const SizedBox(width: 8),
//                                                                     Text(
//                                                                       printer.items[itemIndex],
//                                                                       style: const TextStyle(fontSize: 14),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                               ),
//                                                             );
//                                                           },
//                                                         ),
//                                                       ),
//                                                     ),
//                                                   ],
//                                                 ),
//                                               )
//                                             : const Padding(
//                                                 padding: EdgeInsets.symmetric(horizontal: 16.0),
//                                                 child: Text(
//                                                   'No items assigned',
//                                                   style: TextStyle(
//                                                     fontSize: 14,
//                                                     fontStyle: FontStyle.italic,
//                                                     color: Colors.grey,
//                                                   ),
//                                                 ),
//                                               ),
//                                       Row(
//                                         mainAxisAlignment: MainAxisAlignment.end,
//                                         children: [
//                                           if (printer.type == 'Item wise')
//                                             ElevatedButton.icon(
//                                               onPressed: () {
//                                                 if (!_isServerApp()) {
//                                                   debugPrint('🔒 Access denied: App type is not server for item assignment');

//                                                   if (context.mounted) {
//                                                     WidgetsBinding.instance.addPostFrameCallback((_) {
//                                                       showCustomFlushbar(
//                                                         context,
//                                                         'Only server device can modify item assignment',
//                                                         type: FlushbarType.accessDenied,
//                                                       );
//                                                     });
//                                                   } else {
//                                                     debugPrint('⚠️ Skipped flushbar, context disposed');
//                                                   }

//                                                   return;
//                                                 }

//                                                 try {
//                                                   print('📋 Navigating to ItemAssignmentScreen for ${printer.name}');
//                                                   Navigator.push(
//                                                     context,
//                                                     MaterialPageRoute(
//                                                       builder: (context) => ItemAssignmentScreen(printerIndex: index),
//                                                     ),
//                                                   );
//                                                 } catch (e, stack) {
//                                                   debugPrint('❌ Failed to navigate to ItemAssignmentScreen for ${printer.name}: $e\n$stack');

//                                                   if (context.mounted) {
//                                                     WidgetsBinding.instance.addPostFrameCallback((_) {
//                                                       showCustomFlushbar(
//                                                         context,
//                                                         'Failed to open item assignment',
//                                                         type: FlushbarType.error,
//                                                       );
//                                                     });
//                                                   } else {
//                                                     debugPrint('⚠️ Skipped flushbar, context disposed');
//                                                   }
//                                                 }
//                                               },
//                                               icon: const Icon(Icons.assignment),
//                                               label: const Text(
//                                                 'Assign Items',
//                                                 style: TextStyle(fontSize: 12),
//                                               ),
//                                               style: ElevatedButton.styleFrom(
//                                                 elevation: 2,
//                                                 shape: RoundedRectangleBorder(
//                                                   borderRadius: BorderRadius.circular(12),
//                                                 ),
//                                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                                                 backgroundColor: Colors.blue,
//                                                 foregroundColor: Colors.white,
//                                               ),
//                                             ),
//                                           IconButton(
//                                             icon: const Icon(Icons.edit, color: Colors.green),
//                                             onPressed: () => _showEditPrinterDialog(context, index),
//                                             tooltip: 'Edit Printer',
//                                           ),
//                                           IconButton(
//                                             icon: const Icon(Icons.delete, color: Colors.red),
//                                             onPressed: () => _showRemovePrinterDialog(context, printerProvider, webSocketService, index),
//                                             tooltip: 'Delete Printer',
//                                           ),
//                                         ],
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             } catch (e) {
//                               print('❌ Failed to build printer card at index $index: $e');
//                               return const SizedBox.shrink();
//                             }
//                           },
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//             Positioned(
//               top: 5,
//               right: 16,
//               child: FloatingActionButton(
//                 onPressed: () => _showAddPrinterDialog(context),
//                 backgroundColor: Colors.blue[100],
//                 child: const Icon(
//                   Icons.add,
//                   color: Colors.blue,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );
//     } catch (e, stack) {
//       debugPrint('❌ Failed to build PrinterSettingsScreen: $e\n$stack');

//       if (context.mounted) {
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           showCustomFlushbar(
//             context,
//             'Failed to load printer settings screen',
//             type: FlushbarType.error,
//           );
//         });
//       } else {
//         debugPrint('⚠️ Skipped flushbar, context disposed');
//       }

//       return const Scaffold(
//         body: Center(child: Text('Error loading screen')),
//       );
//     }
//   }
// }

import 'package:flutter/material.dart';
import 'package:yenpos/Server_Client/websocketService.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/kotpreinvoice/components/flushbar.dart';
import 'package:yenpos/kotpreinvoice/providers/printer_provider.dart';
import 'package:yenpos/kotpreinvoice/screens/item_assignment_screen.dart';
import 'package:yenpos/kotpreinvoice/services/validateIpAddress.dart';
import '../kotpreinvoice/models/printer.dart';


class KOTPrinterSettingsScreen extends StatefulWidget {
  const KOTPrinterSettingsScreen({super.key});

  @override
  _KOTPrinterSettingsScreenState createState() =>
      _KOTPrinterSettingsScreenState();
}

class _KOTPrinterSettingsScreenState extends State<KOTPrinterSettingsScreen> {
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;

  // Helper to check if appType is server
  // bool _isServerApp() => appType == 'server';
  bool _isServerApp() => true;

  @override
  void initState() {
    super.initState();
    print('🛠️ Initializing PrinterSettingsScreen');
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    try {
      // Initialize printer provider
      final printerProvider = Provider.of<PrinterProviderDine>(
        context,
        listen: false,
      );
      await printerProvider.printerInitializeHive();

      print(
        '✅ Printer provider initialized: ${printerProvider.printers.length} printers',
      );
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('❌ Failed to initialize providers: $e');
    }
  }

  @override
  void dispose() {
    try {
      _nameController.dispose();
      _ipController.dispose();
      _scrollController.dispose();
      print('🧹 Disposed controllers successfully');
    } catch (e) {
      print('❌ Failed to dispose controllers: $e');
    }
    super.dispose();
  }

  void _showAddPrinterDialog(BuildContext context) {
    if (!_isServerApp()) {
      print('🔒 Access denied: App type is not server');
      showCustomFlushbar(
        context,
        "Only server device can modify printer details.",
        type: FlushbarType.accessDenied,
      );
      return;
    }

    try {
      print('📝 Showing add printer dialog');
      final printerProvider = Provider.of<PrinterProviderDine>(
        context,
        listen: false,
      );

      // Reset to default type
      printerProvider.setSelectedType('Overall');
      _nameController.clear();
      _ipController.clear();

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text(
                  'ADD PRINTER',
                  style: TextStyle(fontSize: 18),
                ),
                content: Consumer<PrinterProviderDine>(
                  builder: (context, provider, child) {
                    return Column(
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
                          value: provider.selectedType,
                          onChanged: (String? newValue) {
                            setDialogState(() {
                              provider.setSelectedType(newValue!);
                              print('🔄 Printer type updated to: $newValue');
                            });
                          },
                          items:
                              <String>[
                                'Overall',
                                'Item wise',
                                'PreInvoice',
                                'Invoice',
                              ].map<DropdownMenuItem<String>>((String value) {
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
                    );
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      print('🚫 Add printer dialog cancelled');
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      backgroundColor: const Color.fromARGB(255, 239, 72, 72),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _addPrinter(printerProvider, context);
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      backgroundColor: const Color(0xFFA5D6A7),
                    ),
                    child: const Text(
                      'Add Printer',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      print('❌ Failed to show add printer dialog: $e');
      if (!mounted) return;
      showCustomFlushbar(
        context,
        'Failed to open add printer dialog',
        type: FlushbarType.error,
      );
    }
  }

  Future<void> _addPrinter(
    PrinterProviderDine printerProvider,
    BuildContext context,
  ) async {
    try {
      final name = _nameController.text.trim();
      final ip = _ipController.text.trim();

      // Validation
      if (name.isEmpty || ip.isEmpty) {
        print('⚠️ Validation failed: Printer name or IP address is empty');
        if (!mounted) return;
        showCustomFlushbar(
          context,
          'Please enter both Name and IP Address',
          type: FlushbarType.warning,
        );
        return;
      }

      if (!validateIpAddress(ip)) {
        print('⚠️ Invalid IP address format: $ip');
        if (!mounted) return;
        showCustomFlushbar(
          context,
          'Invalid IP address format',
          type: FlushbarType.error,
        );
        return;
      }

      // Check for duplicate names
      final existingPrinter = printerProvider.printers.firstWhere(
        (p) => p.name == name,
        orElse: () => Printer(name: '', ipAddress: '', type: '', items: []),
      );

      if (existingPrinter.name.isNotEmpty) {
        print('⚠️ Printer with name "$name" already exists');
        if (!mounted) return;
        showCustomFlushbar(
          context,
          'Printer with name "$name" already exists',
          type: FlushbarType.warning,
        );
        return;
      }

      // Create and add printer
      final newPrinter = Printer(
        name: name,
        ipAddress: ip,
        type: printerProvider.selectedType,
        items: [],
      );

      print("🖨️ Creating new printer: ${newPrinter.toJson()}");

      // Add to provider
      printerProvider.addPrinter(newPrinter);
      print('✅ Added printer to provider: ${newPrinter.name}');

      // Send via WebSocket if available
      try {
        final webSocketService = Provider.of<WebSocketService>(
          context,
          listen: false,
        );
        webSocketService.sendPrinterDetails(newPrinter);
        print('📤 Sent printer details for ${newPrinter.name} via WebSocket');
      } catch (e) {
        print('⚠️ Failed to send WebSocket update for ${newPrinter.name}: $e');
        // Continue execution even if WebSocket fails
      }

      // Clean up and close
      _nameController.clear();
      _ipController.clear();

      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success message
      showCustomFlushbar(
        context,
        'Printer "${newPrinter.name}" added successfully',
        type: FlushbarType.success,
      );

      // Verify the printer was added
      print(
        "🔍 Current printers after adding: ${printerProvider.printers.length}",
      );
      for (var printer in printerProvider.printers) {
        print("  - ${printer.name} (${printer.ipAddress})");
      }
    } catch (e) {
      print('❌ Failed to add printer: $e');
      if (!mounted) return;
      showCustomFlushbar(
        context,
        'Failed to add printer: $e',
        type: FlushbarType.error,
      );
    }
  }

  void _showRemovePrinterDialog(BuildContext context, int index) {
    if (!_isServerApp()) {
      print('🔒 Access denied: App type is not server');
      showCustomFlushbar(
        context,
        'Only server device can modify printer details.',
        type: FlushbarType.accessDenied,
      );
      return;
    }

    try {
      final printerProvider = Provider.of<PrinterProviderDine>(
        context,
        listen: false,
      );
      final webSocketService = Provider.of<WebSocketService>(
        context,
        listen: false,
      );
      final printer = printerProvider.printers[index];

      print('📝 Showing remove printer dialog for ${printer.name}');
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Remove Printer'),
            content: Text(
              'Are you sure you want to remove printer "${printer.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  print(
                    '🚫 Remove printer dialog cancelled for ${printer.name}',
                  );
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  backgroundColor: const Color.fromARGB(255, 239, 72, 72),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    printerProvider.removePrinter(index);
                    print('🗑️ Removed printer: ${printer.name}');

                    // Send WebSocket update
                    webSocketService.sendRemovePrinter(printer.name);
                    print(
                      '📤 Sent remove request for printer ${printer.name} via WebSocket',
                    );

                    Navigator.of(context).pop();

                    // Show success message
                    showCustomFlushbar(
                      context,
                      'Printer "${printer.name}" removed successfully',
                      type: FlushbarType.success,
                    );
                  } catch (e) {
                    print('❌ Failed to remove printer ${printer.name}: $e');
                    if (context.mounted) {
                      showCustomFlushbar(
                        context,
                        'Failed to remove printer: $e',
                        type: FlushbarType.error,
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  backgroundColor: const Color(0xFFA5D6A7),
                ),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('❌ Failed to show remove printer dialog for index $index: $e');
      if (context.mounted) {
        showCustomFlushbar(
          context,
          'Failed to open remove printer dialog',
          type: FlushbarType.error,
        );
      }
    }
  }

  void _showEditPrinterDialog(BuildContext context, int index) {
    if (!_isServerApp()) {
      print('🔒 Access denied: App type is not server');
      showCustomFlushbar(
        context,
        'Only server device can modify printer details',
        type: FlushbarType.accessDenied,
      );
      return;
    }

    try {
      final printerProvider = Provider.of<PrinterProviderDine>(
        context,
        listen: false,
      );
      final webSocketService = Provider.of<WebSocketService>(
        context,
        listen: false,
      );
      final Printer printer = printerProvider.printers[index];
      print('📝 Showing edit printer dialog for ${printer.name}');

      _nameController.text = printer.name;
      _ipController.text = printer.ipAddress;
      printerProvider.setSelectedType(printer.type);

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text(
                  'EDIT PRINTER',
                  style: TextStyle(fontSize: 18),
                ),
                content: Consumer<PrinterProviderDine>(
                  builder: (context, provider, child) {
                    return Column(
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
                          value: provider.selectedType,
                          onChanged: (String? newValue) {
                            setDialogState(() {
                              provider.setSelectedType(newValue!);
                              print('🔄 Printer type updated to: $newValue');
                            });
                          },
                          items:
                              <String>[
                                'Overall',
                                'Item wise',
                                'PreInvoice',
                                'Invoice',
                              ].map<DropdownMenuItem<String>>((String value) {
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
                    );
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      print(
                        '🚫 Edit printer dialog cancelled for ${printer.name}',
                      );
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      backgroundColor: const Color.fromARGB(255, 239, 72, 72),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _updatePrinter(
                        printerProvider,
                        webSocketService,
                        index,
                        context,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      backgroundColor: const Color(0xFFA5D6A7),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e, st) {
      debugPrint(
        '❌ Failed to show edit printer dialog for index $index: $e\n$st',
      );
      if (context.mounted) {
        showCustomFlushbar(
          context,
          'Failed to open edit printer dialog',
          type: FlushbarType.error,
        );
      }
    }
  }

  Future<void> _updatePrinter(
    PrinterProviderDine printerProvider,
    WebSocketService webSocketService,
    int index,
    BuildContext context,
  ) async {
    try {
      final name = _nameController.text.trim();
      final ip = _ipController.text.trim();
      final originalPrinter = printerProvider.printers[index];

      // Validation
      if (name.isEmpty || ip.isEmpty) {
        print('⚠️ Validation failed: Printer name or IP address is empty');
        showCustomFlushbar(
          context,
          'Please enter both Name and IP Address',
          type: FlushbarType.warning,
        );
        return;
      }

      if (!validateIpAddress(ip)) {
        print('⚠️ Invalid IP address format: $ip');
        showCustomFlushbar(
          context,
          'Invalid IP address format',
          type: FlushbarType.error,
        );
        return;
      }

      // Check for duplicate names (excluding current printer)
      final existingPrinterIndex = printerProvider.printers.indexWhere(
        (p) => p.name == name && p.name != originalPrinter.name,
      );
      if (existingPrinterIndex != -1) {
        print('⚠️ Printer with name "$name" already exists');
        showCustomFlushbar(
          context,
          'Printer with name "$name" already exists',
          type: FlushbarType.warning,
        );
        return;
      }

      final updatedPrinter = Printer(
        name: name,
        ipAddress: ip,
        type: printerProvider.selectedType,
        items: originalPrinter.items, // Keep existing items
      );

      // Update printer
      printerProvider.updatePrinter(index, updatedPrinter);
      print('🖨️ Updated printer at index $index: ${updatedPrinter.name}');

      // Send WebSocket update
      webSocketService.sendPrinterDetails(updatedPrinter);
      print(
        '📤 Sent updated printer details for ${updatedPrinter.name} via WebSocket',
      );

      // Clean up
      _nameController.clear();
      _ipController.clear();

      Navigator.of(context).pop();

      // Show success message
      showCustomFlushbar(
        context,
        'Printer "${updatedPrinter.name}" updated successfully',
        type: FlushbarType.success,
      );
    } catch (e) {
      print('❌ Failed to update printer: $e');
      showCustomFlushbar(
        context,
        'Failed to update printer: $e',
        type: FlushbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      print('🏗️ Building PrinterSettingsScreen');

      if (!_isInitialized) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing printer settings...'),
              ],
            ),
          ),
        );
      }

      final printerProvider = Provider.of<PrinterProviderDine>(context);

      return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    if (printerProvider.printers.isEmpty)
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 50),
                            Icon(
                              Icons.info_outline,
                              size: 40,
                              color: Colors.grey,
                            ),
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
                            try {
                              final printer = printerProvider.printers[index];
                              return Card(
                                color: Colors.white,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 3,
                                child: Theme(
                                  data: Theme.of(
                                    context,
                                  ).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    expandedCrossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    title: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.blue[100],
                                          radius: 12,
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.blue,
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Assigned Items:',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                                        controller:
                                                            _scrollController,
                                                        child: ListView.builder(
                                                          shrinkWrap: true,
                                                          controller:
                                                              _scrollController,
                                                          physics:
                                                              const AlwaysScrollableScrollPhysics(),
                                                          itemCount: printer
                                                              .items
                                                              .length,
                                                          itemBuilder: (context, itemIndex) {
                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        4.0,
                                                                  ),
                                                              child: SingleChildScrollView(
                                                                scrollDirection:
                                                                    Axis.horizontal,
                                                                child: Row(
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .circle,
                                                                      size: 8,
                                                                      color: Colors
                                                                          .black,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Text(
                                                                      printer
                                                                          .items[itemIndex],
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
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
                                                  horizontal: 16.0,
                                                ),
                                                child: Text(
                                                  'No items assigned',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 8.0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (printer.type == 'Item wise')
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  if (!_isServerApp()) {
                                                    showCustomFlushbar(
                                                      context,
                                                      'Only server device can modify item assignment',
                                                      type: FlushbarType
                                                          .accessDenied,
                                                    );
                                                    return;
                                                  }
                                                  try {
                                                    // print('📋 Navigating to ItemAssignmentScreen for ${printer.name}');
                                                    // Navigator.push(
                                                    //   context,
                                                    //   MaterialPageRoute(
                                                    //     builder: (context) => ItemAssignmentScreen(printerIndex: index),
                                                    //   ),
                                                    // );
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => Dialog(
                                                        backgroundColor:
                                                            Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                15,
                                                              ), // 👉 your border radius
                                                        ),
                                                        insetPadding:
                                                            const EdgeInsets.all(
                                                              20,
                                                            ), // dialog margin
                                                        child: SizedBox(
                                                          width:
                                                              700, // optional fixed width
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  10.0,
                                                                ),
                                                            child:
                                                                ItemAssignmentScreen(
                                                                  printerIndex:
                                                                      index,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    print(
                                                      '❌ Failed to navigate to ItemAssignmentScreen: $e',
                                                    );
                                                    showCustomFlushbar(
                                                      context,
                                                      'Failed to open item assignment',
                                                      type: FlushbarType.error,
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.assignment,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Assign Items',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  elevation: 2,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  backgroundColor: Colors.blue,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.green,
                                              ),
                                              onPressed: () =>
                                                  _showEditPrinterDialog(
                                                    context,
                                                    index,
                                                  ),
                                              tooltip: 'Edit Printer',
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () =>
                                                  _showRemovePrinterDialog(
                                                    context,
                                                    index,
                                                  ),
                                              tooltip: 'Delete Printer',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } catch (e) {
                              print(
                                '❌ Failed to build printer card at index $index: $e',
                              );
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 5,
              right: 16,
              child: FloatingActionButton(
                onPressed: () => _showAddPrinterDialog(context),
                backgroundColor: Colors.blue[100],
                child: const Icon(Icons.add, color: Colors.blue),
              ),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint('❌ Failed to build PrinterSettingsScreen: $e\n$stack');
      return const Scaffold(body: Center(child: Text('Error loading screen')));
    }
  }
}

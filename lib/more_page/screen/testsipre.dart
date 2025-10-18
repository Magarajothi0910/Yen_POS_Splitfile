// import 'dart:typed_data';

// import 'package:esc_pos_utils/esc_pos_utils.dart';
// import 'package:esc_pos_printer/esc_pos_printer.dart';
// import 'package:intl/intl.dart'; // Import for date formatting

// class SIPreInvoicePrinter {
//   static Future<void> printReceipt({
//     required String ipAddress,
//     required List<Map<String, dynamic>> invoiceDataList,
//     required String receiptType,
//   }) async {
//     try {
//       final profile = await CapabilityProfile.load();
//       final printer = NetworkPrinter(PaperSize.mm80, profile);

//       print('Connecting to printer at $ipAddress...');
//       final PosPrintResult res = await _connectWithRetry(printer, ipAddress);
//       if (res != PosPrintResult.success) {
//         print('Failed to connect to the printer: $res');
//         return;
//       }
//       print('Connected to printer.');

//       printer.rawBytes(Uint8List.fromList([27, 64])); // ESC @

//       // Date and time
//       final now = DateTime.now();
//       final formattedDate = DateFormat('dd-MM-yyyy').format(now);
//       final formattedTime = DateFormat('HH:mm:ss').format(now);

//       // Iterate over the list of invoices
//       for (var invoiceData in invoiceDataList) {
//         // Header
//         printer.text('Pre Invoice',
//             styles: const PosStyles(
//                 align: PosAlign.center,
//                 bold: true,
//                 height: PosTextSize.size1,
//                 width: PosTextSize.size1));

//         printer.text('Date: $formattedDate  Time: $formattedTime');

//         printer.feed(1);

//         printer.text('------------------------------------------------');

//         // Item details header
//         printer.text(
//             '${_alignText("S.N", 4)} ${_alignText("Item", 20)} ${_alignText("Qty", 5)} ${_alignText("Price", 7)} ${_alignText("Total", 7)}',
//             styles: const PosStyles(align: PosAlign.left, bold: true));
//         printer.text('------------------------------------------------');

//         // Extract and print items
//         final String itemName =
//             invoiceData['itemData']?['itemName'] ?? 'Unknown Item';
//         final String varianceName =
//             invoiceData['varianceData']?['varianceName'] ?? 'Unknown Variance';
//         final double quantity = invoiceData['quantity']?.toDouble() ?? 0.0;
//         final double price =
//             invoiceData['varianceData']?['variance_Defaultprice']?.toDouble() ??
//                 0.0;
//         final double amount = price * quantity;

//         // Print the single item's details
//         printer.text(
//             '${_alignText("1", 4)} ${_alignText(itemName, 20)} ${_alignText(quantity.toStringAsFixed(1), 5)} ${_alignText(price.toStringAsFixed(2), 7)} ${_alignText(amount.toStringAsFixed(2), 7)}');

//         printer.text('------------------------------------------------');

//         // Totals
//         printer.text('Sub Total: ${amount.toStringAsFixed(2)}',
//             styles: const PosStyles(align: PosAlign.right));
//         printer.text('Discount: 0.00',
//             styles: const PosStyles(align: PosAlign.right));
//         printer.text('Grand Total: ${amount.toStringAsFixed(2)}',
//             styles: const PosStyles(
//                 align: PosAlign.right,
//                 bold: true,
//                 height: PosTextSize.size2,
//                 width: PosTextSize.size2));
//         printer.feed(2);

//         // Footer
//         printer.text('Thank you!',
//             styles: const PosStyles(align: PosAlign.center));
//         printer.text('---------------------------');
//         printer.feed(1);
//       }

//       printer.cut();
//       printer.disconnect();

//       print('Receipts printed successfully.');
//     } catch (e) {
//       print('Error during printing: $e');
//     }
//   }

//   static Future<PosPrintResult> _connectWithRetry(
//       NetworkPrinter printer, String ipAddress,
//       {int retries = 3}) async {
//     PosPrintResult res = PosPrintResult.timeout;

//     for (int attempt = 0; attempt < retries; attempt++) {
//       res = await printer.connect(ipAddress, port: 9100);
//       if (res == PosPrintResult.success) {
//         return res;
//       }
//       print('Retrying connection... ($attempt)');
//       await Future.delayed(Duration(seconds: 1));
//     }

//     return res;
//   }

//   static String _alignText(String text, int length) {
//     if (text.length > length) {
//       return text.substring(0, length);
//     }
//     return text.padRight(length);
//   }
// }

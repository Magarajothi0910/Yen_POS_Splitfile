import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class CreditSOPreInvoicePrinter {
  static Future<void> printReceipt({
    required String ipAddress,
    required Map<String, dynamic> invoiceData,
    required String receiptType,
  }) async {
    try {
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(PaperSize.mm80, profile);

      final PosPrintResult res = await _connectWithRetry(printer, ipAddress);
      if (res != PosPrintResult.success) {
        return;
      }

      printer.rawBytes(Uint8List.fromList([27, 64])); // ESC @

      // Date and time
      final now = DateTime.now();
      final formattedDate = DateFormat('dd-MM-yyyy').format(now);
      final formattedTime = DateFormat('HH:mm:ss').format(now);

      // Header
      printer.text('Pre Invoice',
          styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1));
      printer.text('Receipt Type: $receiptType',
          styles: const PosStyles(align: PosAlign.center));
      printer.text('Date: $formattedDate  Time: $formattedTime');
      printer.text(
          'Invoice #: ${invoiceData['invoiceNo'] ?? 'N/A'}   Branch: ${invoiceData['branchName'] ?? 'Unknown Branch'}');
      printer
          .text('Customer: ${invoiceData['customerPhoneNumber'] ?? 'Unknown'}');
      printer.feed(1);

      printer.text('------------------------------------------------');

      // Item details header
      printer.text(
          '${_alignText("S.N", 4)} ${_alignText("Item", 20)} ${_alignText("Qty", 5)} ${_alignText("Price", 7)} ${_alignText("Total", 7)}',
          styles: const PosStyles(align: PosAlign.left, bold: true));
      printer.text('------------------------------------------------');

      // Extract and print items
      final List<String> itemNames = List<String>.from(invoiceData['itemName']);
      final List<double> quantities = List<double>.from(
          invoiceData['qty'].map((e) => (e is int) ? e.toDouble() : e));
      final List<double> prices = List<double>.from(
          invoiceData['price'].map((e) => (e is int) ? e.toDouble() : e));
      final List<double> amounts = List<double>.from(
          invoiceData['amount'].map((e) => (e is int) ? e.toDouble() : e));

      for (int i = 0; i < itemNames.length; i++) {
        printer.text(
            '${_alignText("${i + 1}", 4)} ${_alignText(itemNames[i], 20)} ${_alignText(quantities[i].toString(), 5)} ${_alignText(prices[i].toStringAsFixed(2), 7)} ${_alignText(amounts[i].toStringAsFixed(2), 7)}');
      }

      printer.text('------------------------------------------------');

      // Totals
      printer.text(
          'Sub Total: ${invoiceData['totalAmount'].toStringAsFixed(2)}',
          styles: const PosStyles(align: PosAlign.right));
      printer.text(
          'Discount: ${invoiceData['discountAmount']?.toStringAsFixed(2) ?? '0.00'}',
          styles: const PosStyles(align: PosAlign.right));
      printer.text(
          'Grand Total: ${invoiceData['totalAmount'].toStringAsFixed(2)}',
          styles: const PosStyles(
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      printer.feed(2);

      // Footer
      printer.text('Thank you!',
          styles: const PosStyles(align: PosAlign.center));
      printer.cut();
      printer.disconnect();

    } catch (e) {
    }
  }

  static Future<PosPrintResult> _connectWithRetry(
      NetworkPrinter printer, String ipAddress,
      {int retries = 3}) async {
    PosPrintResult res = PosPrintResult.timeout;

    for (int attempt = 0; attempt < retries; attempt++) {
      res = await printer.connect(ipAddress, port: 9100);
      if (res == PosPrintResult.success) {
        return res;
      }
      await Future.delayed(Duration(seconds: 1));
    }

    return res;
  }

  static String _alignText(String text, int length) {
    if (text.length > length) {
      return text.substring(0, length);
    }
    return text.padRight(length);
  }
}

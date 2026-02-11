import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../printer_screen/provider/printer_config_provider.dart';
import '../controller/denomination_controler.dart';

class DenominationBill {
  static Future<void> printDenominationBill(BuildContext context) async {
    final denominationController = Get.find<DenominationController>();
    int totalCashFromDenominations =
        denominationController.totalCashFromDenominations;

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);
    final generator = Generator(PaperSize.mm80, profile);
    final printerProvider =
        Provider.of<PrinterProviderpos>(context, listen: false);
    String printerIp = printerProvider
        .getOverallPrinterIp()
        .toString(); // Default IP if none fetched
  
    final PosPrintResult res = await printer.connect(printerIp, port: 9100);

    if (res == PosPrintResult.success) {
      List<int> bytes = [];

      // Header: Shop Name
      bytes += generator.text('Best Mummy',
          styles: PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      bytes += generator.text('Sweets & Cakes',
          styles: PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2));

      bytes += generator.text('Denominations',
          styles: PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      bytes += generator.hr();

      // Denominations details without currency symbol
      bytes += generator.text('Denominations', styles: PosStyles(bold: true));
      denominationController.denominations.forEach((denomination, count) {
        int amount = denomination * count.value;
        bytes += generator.row([
          PosColumn(
              width: 8,
              text: '$denomination x ${count.value}',
              styles: const PosStyles(align: PosAlign.left)),
          PosColumn(
              width: 4,
              text: amount.toString(), // No currency symbol
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      });
      bytes += generator.hr();

      // Display total cash without currency symbol
      bytes += generator.text('Total Cash: $totalCashFromDenominations',
          styles: PosStyles(bold: true, align: PosAlign.right));
      bytes += generator.hr();

      // Send to printer
      printer.rawBytes(Uint8List.fromList(bytes));
      printer.cut();

      printer.disconnect();
    }
  }
}

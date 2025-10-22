
import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../printer_screen/provider/printer_config_provider.dart';

class DayEndPrintService {
  static Future<void> printDayEndBill(
    BuildContext context, {
    required String branchName,
    required String date,
    required String time,
    required String user,
    required List<Map<String, String>> shiftDetails,
    required String systemCash,
    required String manualCash,
    required String differences,
    required String cardSales,
    required String upiSales,
    required String swiggySales,
    required String zomatoSales,
    required String otherSales,
    required String totalSales,
    required String totalCash,
    required String totalCard,
    required String totalUPI,
    required String cashReturn,
    required String cashInHand,
    required String overallSales,
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);
    final generator = Generator(PaperSize.mm80, await CapabilityProfile.load());
    final printerProvider =
        Provider.of<PrinterProviderpos>(context, listen: false);

    String printerIp = printerProvider.getOverallPrinterIp() ?? '';
    final PosPrintResult res = await printer.connect(printerIp, port: 9100);

    if (res == PosPrintResult.success) {
      List<int> bytes = [];

      // Header: Shop Name
      bytes += generator.text('BestMummy\n Sweets & Cakes',
          styles: PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      bytes += generator.text('Day End',
          styles: PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      bytes += generator.hr();

      // Branch, Date, Time, User
      bytes += generator.text('Branch: $branchName');
      bytes += generator.text('Date: $date');
      bytes += generator.text('Time: $time');
      bytes += generator.text('User: $user');
      bytes += generator.hr();

      // Shift Details
      for (var shift in shiftDetails) {
        bytes += generator.text('Shift ${shift["Shift Number"]}',
            styles: PosStyles(bold: true));
        bytes += generator.row([
          PosColumn(
              width: 6,
              text: 'Opening Time: ${shift["Opening Time"]}',
              styles: const PosStyles(align: PosAlign.left)),
          PosColumn(
              width: 6,
              text: 'Closing Time: ${shift["Closing Time"]}',
              styles: const PosStyles(align: PosAlign.left)),
        ]);
        bytes += generator.row([
          PosColumn(
              width: 6,
              text: 'System Closing: ${shift["System Closing Balance"]}',
              styles: const PosStyles(align: PosAlign.left)),
          PosColumn(
              width: 6,
              text: 'Manual Closing: ${shift["Manual Closing Balance"]}',
              styles: const PosStyles(align: PosAlign.left)),
        ]);
        bytes += generator.row([
          PosColumn(
              width: 12,
              text: 'Difference: ${shift["Difference"]}',
              styles: const PosStyles(align: PosAlign.left)),
        ]);
        bytes += generator.hr();
      }

      // Sales summary
      bytes += generator.text('Sales Summary', styles: PosStyles(bold: true));
      bytes += generator.text('System Cash: $systemCash');
      bytes += generator.text('Manual Cash: $manualCash');
      bytes += generator.text('Differences: $differences');
      bytes += generator.text('Card Sales: $cardSales');
      bytes += generator.text('UPI Sales: $upiSales');
      bytes += generator.text('Swiggy Sales: $swiggySales');
      bytes += generator.text('Zomato Sales: $zomatoSales');
      bytes += generator.text('Other Sales: $otherSales');
      bytes += generator.text('Total Sales: $totalSales');
      bytes += generator.hr();

      // Final amounts
      bytes += generator.text('Final Amount', styles: PosStyles(bold: true));
      bytes += generator.text('Total Cash: $totalCash');
      bytes += generator.text('Total Card: $totalCard');
      bytes += generator.text('Total UPI: $totalUPI');
      bytes += generator.text('Cash Return: $cashReturn');
      bytes += generator.text('Cash in Hand: $cashInHand');
      bytes += generator.hr();

      // Overall sales
      bytes += generator.text('Overall Sales: $overallSales',
          styles: PosStyles(bold: true));

      // Send to printer
      printer.rawBytes(Uint8List.fromList(bytes));
      printer.cut();
      printer.disconnect();
    }
  }
}

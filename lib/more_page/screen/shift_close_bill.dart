// import 'dart:typed_data';

// import 'package:esc_pos_printer/esc_pos_printer.dart';
// import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.

// class PrintService {
//   // This function generates the bill and prints it
//   static Future<void> printBill() async {
//     print("sas");
//     final profile = await CapabilityProfile.load();
//     final printer = NetworkPrinter(PaperSize.mm80, profile);
//     final generator = Generator(PaperSize.mm80, await CapabilityProfile.load());
//     final PosPrintResult res =
//         await printer.connect('192.168.1.90', port: 9100);
//     if (res == PosPrintResult.success) {
//       // Bytes array to hold the print commands
//       List<int> bytes = [];

//       // Example values for sample data
//       String branchName = "Main Branch";
//       String ddata = "24/10/2024";
//       String tdata = "12:30 PM";
//       String deviceNumber = "00123";
//       String shiftNumber1 = "Shift 1";
//       String openingDate = "23-10-2024";
//       String currentDate2 = "24-10-2024";
//       String openingTime = "08:00 AM";
//       String cashSales = "5000";
//       String differencesCashString = "200";
//       String upiSales = "3000";
//       String differencesUpiString = "100";
//       String cardSales = "4000";
//       String differencesCardString = "150";
//       String deliveryPartnet = "1500";
//       String otherSales = "2000";
//       String systemclosingBalance = "16000";
//       String manualClosingBalance = "15500";
//       String closingAmount = "500";
//       String closingDifferentType = "Cash Short";

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: '.',
//             styles: const PosStyles(
//               align: PosAlign.center,
//               codeTable: 'CP1252',
//             )),
//       ]);

//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Best Mummy',
//             styles: const PosStyles(
//               align: PosAlign.center,
//               height: PosTextSize.size2,
//               width: PosTextSize.size2,
//               codeTable: 'CP1252',
//             )),
//       ]);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Sweets & Cakes',
//             styles:
//                 const PosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

//       // sum width total column must be 12

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Shift close',
//             styles: const PosStyles(
//               align: PosAlign.center,
//               codeTable: 'CP1252',
//               height: PosTextSize.size2,
//               width: PosTextSize.size2,
//             )),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Branch : $branchName',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 6,
//             text: 'Date : $ddata',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         PosColumn(
//             width: 6,
//             text: 'Time :$tdata ',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: '-------------------------------------------',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Device Number : $deviceNumber',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Shift Number : $shiftNumber1',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'OpeningDate : $openingDate',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'ClosingDate : $currentDate2',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'OpeningTime : $openingTime',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'ClosingTime : $tdata',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Sys Cash : $cashSales',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Difference : $differencesCashString',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);
//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Sys Upi : $upiSales',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Difference : $differencesUpiString',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Sys Card : $cardSales',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Difference : $differencesCardString',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Sys Delivery Partner Sales : $deliveryPartnet',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Sys Other Sales : $otherSales',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: '----------------------------------------',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Total System Closing Balance : $systemclosingBalance',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Total Manual Closing Balance : $manualClosingBalance',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Closing Difference : $closingAmount',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Difference Type : $closingDifferentType',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       printer
//           .rawBytes(Uint8List.fromList(bytes)); // Send the bytes to the printer

//       printer.cut();

//       // Add a delay to ensure the printer completes the print job
//       await Future.delayed(const Duration(seconds: 1));

//       printer
//           .disconnect(); // Disconnect the printer only after ensuring the print is complete
//     }
//   }
// }
import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../printer_screen/provider/printer_config_provider.dart';

class PrintService {
  static Future<void> printBill(
    BuildContext context, {
    required String branchName,
    required String date,
    required String time,
    required String user,
    required String shiftOpenTime,
    required String shiftCloseTime,
    required String systemOpenAmount,
    required String manualOpenAmount,
    required String shortage,
    required String deviceId,
    required String deviceName,
    required String systemCashSales,
    required String manualCashSales,
    required String cashSalesDifference,
    required String systemClosingBalance,
    required String manualClosingBalance,
    required String closingAmountDifference,
    required String closingShortageType,
    required String cashSales,
    required String cardSales,
    required String upiSales,
    required String zomatoSales,
    required String swiggySales,
    required String otherSales,
    required String totalSales,
    required String kotSales,
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);
    final generator = Generator(PaperSize.mm80, await CapabilityProfile.load());
    final printerProvider =
        Provider.of<PrinterProviderpos>(context, listen: false);
    double systemCash = double.tryParse(systemCashSales) ?? 0.0;
    double manualCash = double.tryParse(manualCashSales) ?? 0.0;

// Calculate the difference
    double cashDifference = systemCash - manualCash;
    String differenceMessage;
    if (cashDifference == 0) {
      differenceMessage = "No Difference";
    } else if (cashDifference > 0) {
      differenceMessage = "Shortage: ${cashDifference.toStringAsFixed(2)}";
    } else {
      differenceMessage = "Excess: ${(-cashDifference).toStringAsFixed(2)}";
    }
    String printerIp = printerProvider
        .getOverallPrinterIp()
        .toString(); // Default IP if none fetched
    final PosPrintResult res = await printer.connect(printerIp, port: 9100);

    if (res == PosPrintResult.success) {
      List<int> bytes = [];

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

      bytes += generator.feed(1);

      bytes += generator.text('Shift Close',
          styles: PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      bytes += generator.feed(1);
      bytes += generator.text('Branch: $branchName');

      bytes += generator.hr();

      // 2 by 2 layout for DeviceId/DeviceName and Date/Time
      bytes += generator.row([
        PosColumn(
            width: 6,
            text: 'DeviceId: $deviceId',
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            width: 6,
            text: 'DeviceName: $deviceName',
            styles: const PosStyles(align: PosAlign.left)),
      ]);

      bytes += generator.row([
        PosColumn(
            width: 6,
            text: 'Date: $date',
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            width: 6,
            text: 'Time: $time',
            styles: const PosStyles(align: PosAlign.left)),
      ]);

      bytes += generator.row([
        PosColumn(
            width: 6,
            text: 'Shift Open: $shiftOpenTime',
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            width: 6,
            text: 'Shift Close: $shiftCloseTime',
            styles: const PosStyles(align: PosAlign.left)),
      ]);

      bytes += generator.hr();

      // Opening Amount details
      bytes += generator.text('Opening Amount',
          styles: PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text('System Open Amount: $systemOpenAmount');
      bytes += generator.text('Manual Open Amount: $manualOpenAmount');
      bytes += generator.text('Difference: $shortage');
      bytes += generator.hr();

      // Sales details
      bytes += generator.text('Sales',
          styles: PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.feed(1);
      bytes +=
          generator.text('System Cash Sales: ${systemCash.toStringAsFixed(2)}');
      bytes +=
          generator.text('Manual Cash Sales: ${manualCash.toStringAsFixed(2)}');
      bytes += generator.text('Difference: $differenceMessage');
      bytes += generator.hr();

      // Overall Sales
      bytes += generator.text('Overall Sales',
          styles: PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text(
          'Cash Sales: ${cashSales.isNotEmpty == true ? cashSales : "0"}');
      bytes += generator.text(
          'Card Sales: ${cardSales.isNotEmpty == true ? cardSales : "0"}');
      bytes += generator
          .text('UPI Sales: ${upiSales.isNotEmpty == true ? upiSales : "0"}');
      bytes += generator.text(
          'Zomato Sales: ${zomatoSales.isNotEmpty == true ? zomatoSales : "0"}');
      bytes += generator.text(
          'Swiggy Sales: ${swiggySales.isNotEmpty == true ? swiggySales : "0"}');
      bytes += generator.text(
          'Other Sales: ${otherSales.isNotEmpty == true ? otherSales : "0"}');
      bytes += generator.text(
          'Total Sales: ${totalSales.isNotEmpty == true ? totalSales : "0"}');
      bytes += generator
          .text('KOT Sales: ${kotSales.isNotEmpty == true ? kotSales : "0"}');

      bytes += generator.hr();

      // Closing balance
      bytes += generator.text('Closing Amount',
          styles: PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.feed(1);
      bytes += generator.text('System Closing Balance: $systemClosingBalance');
      bytes += generator.text('Manual Closing Balance: $manualClosingBalance');
      bytes += generator.text('Closing Difference: $closingAmountDifference');
      bytes += generator.text('Difference Type: $closingShortageType');
      bytes += generator.hr();

      // Send to printer
      printer.rawBytes(Uint8List.fromList(bytes));
      printer.cut();

      printer.disconnect();
    }
  }
}

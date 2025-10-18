// import 'dart:typed_data';

// import 'package:esc_pos_printer/esc_pos_printer.dart';
// import 'package:esc_pos_utils/esc_pos_utils.dart'; // For printing utilities
// import 'package:intl/intl.dart'; // For date and time formatting
// import 'dart:async';

// class DayEndPrintService {
//   static Future<void> dayEndprintBill() async {
//     try {
//       final profile = await CapabilityProfile.load();
//       final printer = NetworkPrinter(PaperSize.mm80, profile);
//       final generator =
//           Generator(PaperSize.mm80, await CapabilityProfile.load());
//       final PosPrintResult res =
//           await printer.connect('192.168.1.90', port: 9100);
//       if (res == PosPrintResult.success) {
//         List<int> bytes = [];
//         String ddata = DateFormat("dd-MM-yyyy").format(DateTime.now());
//         String tdata = DateFormat("hh:mm:ss a").format(DateTime.now());

//         // Sample data for the branch and shifts
//         String branchName = "Main Branch";
//         var shifts = [
//           {
//             'deviceNumber': '001',
//             'shiftNumber': 'Shift 1',
//             'shiftOpeningDate': '23-10-2024',
//             'shiftClosingDate': '24-10-2024',
//             'shiftOpeningTime': '08:00 AM',
//             'shiftClosingTime': '06:00 PM',
//             'closingDifferenceAmount': '200',
//             'closingDifferenceType': 'Cash Short',
//             'cashSales': '5000',
//             'manualCashsales': '4800',
//             'upiSales': '3000',
//             'manualUpisales': '2900',
//             'cardSales': '2000',
//             'manualCardsales': '1950',
//             'deliveryPartner': '1500',
//             'otherSales': '1000',
//           },
//           {
//             'deviceNumber': '002',
//             'shiftNumber': 'Shift 2',
//             'shiftOpeningDate': '23-10-2024',
//             'shiftClosingDate': '24-10-2024',
//             'shiftOpeningTime': '06:00 PM',
//             'shiftClosingTime': '02:00 AM',
//             'closingDifferenceAmount': '100',
//             'closingDifferenceType': 'Cash Over',
//             'cashSales': '6000',
//             'manualCashsales': '6050',
//             'upiSales': '4000',
//             'manualUpisales': '4050',
//             'cardSales': '2500',
//             'manualCardsales': '2550',
//             'deliveryPartner': '1800',
//             'otherSales': '1200',
//           },
//         ];

//         // Looping through shifts
//         for (var shift in shifts) {
//           bytes += generator.setGlobalCodeTable('CP1252');

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Best Mummy',
//                 styles: const PosStyles(
//                   align: PosAlign.center,
//                   height: PosTextSize.size2,
//                   width: PosTextSize.size2,
//                   codeTable: 'CP1252',
//                 )),
//           ]);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Sweets & Cakes',
//                 styles: const PosStyles(
//                     align: PosAlign.center, codeTable: 'CP1252')),
//           ]);

//           bytes += generator.feed(1);

//           // Day End Close
//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Day End Close',
//                 styles: const PosStyles(
//                   align: PosAlign.center,
//                   codeTable: 'CP1252',
//                   height: PosTextSize.size2,
//                   width: PosTextSize.size2,
//                 )),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Branch : $branchName',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           // Date and Time
//           bytes += generator.row([
//             PosColumn(
//                 width: 6,
//                 text: 'Date : $ddata',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//             PosColumn(
//                 width: 6,
//                 text: 'Time : $tdata',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);

//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: '-------------------------------------------',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           // Shift-specific details
//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Device Number : ${shift['deviceNumber']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Shift Number : ${shift['shiftNumber']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'OpeningDate : ${shift['shiftOpeningDate']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'ClosingDate : ${shift['shiftClosingDate']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'OpeningTime : ${shift['shiftOpeningTime']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'ClosingTime : ${shift['shiftClosingTime']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           // Difference and Type
//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text:
//                     'Closing Difference : ${shift['closingDifferenceAmount']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Difference Type : ${shift['closingDifferenceType']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           // Cash Sales
//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Sys Cash Sales : ${shift['cashSales']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Manual Cash Sales : ${shift['manualCashsales']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           int cashDifference = int.parse(shift['cashSales']!) -
//               int.parse(shift['manualCashsales']!);
//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Difference : $cashDifference',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           // UPI Sales
//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Sys UPI Sales : ${shift['upiSales']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Manual Upi : ${shift['manualUpisales']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           int upiDifference = int.parse(shift['upiSales']!) -
//               int.parse(shift['manualUpisales']!);
//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Difference : $upiDifference',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           // Card Sales
//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Sys Card Sales : ${shift['cardSales']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Manual Card : ${shift['manualCardsales']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           int cardDifference = int.parse(shift['cardSales']!) -
//               int.parse(shift['manualCardsales']!);
//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Difference : $cardDifference',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           // Other Sales
//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text:
//                     'Sys Delivery Partner Sales : ${shift['deliveryPartner']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: 'Sys Other Sales : ${shift['otherSales']}',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);

//           bytes += generator.row([
//             PosColumn(
//                 width: 12,
//                 text: '----------------------------------------',
//                 styles:
//                     const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           ]);
//           bytes += generator.feed(1);
//         }

//         // Closing balance totals
//         bytes += generator.row([
//           PosColumn(
//               width: 12,
//               text: 'Total System Closing Balance : 16000',
//               styles:
//                   const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         ]);
//         bytes += generator.feed(1);

//         bytes += generator.row([
//           PosColumn(
//               width: 12,
//               text: 'Total Manual Closing Balance : 15500',
//               styles:
//                   const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         ]);
//         bytes += generator.feed(1);

//         bytes += generator.row([
//           PosColumn(
//               width: 12,
//               text: 'Difference : 500',
//               styles:
//                   const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         ]);
//         bytes += generator.feed(1);

//         bytes += generator.row([
//           PosColumn(
//               width: 12,
//               text: 'Difference Type : Cash Short',
//               styles:
//                   const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         ]);

//         bytes += generator.feed(1);

//         printer.rawBytes(
//             Uint8List.fromList(bytes)); // Send the bytes to the printer

//         printer.cut();

//         printer
//             .disconnect(); // Disconnect the printer only after ensuring the print is complete
//       }
//     } catch (e) {
//       print("Error while printing: $e");
//     }
//   }
// }
import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../printer_screen/provider/printer_config_provider.dart';

// class DayEndPrintService {
//   static Future<void> printDayEndBill(BuildContext context) async {
//     final profile = await CapabilityProfile.load();
//     final printer = NetworkPrinter(PaperSize.mm80, profile);
//     final generator = Generator(PaperSize.mm80, await CapabilityProfile.load());
//     final printerProvider =
//         Provider.of<PrinterProvider>(context, listen: false);

//     String printerIp = printerProvider
//         .getOverallPrinterIp()
//         .toString(); // Default IP if none fetched
//     print(printerIp);
//     final PosPrintResult res = await printer.connect(printerIp, port: 9100);

//     if (res == PosPrintResult.success) {
//       List<int> bytes = [];

//       // Example values for the "Day End" bill
//       String branchName = "Main Branch";
//       String date = "24/10/2024";
//       String time = "10:00 PM";
//       String user = "Admin";
//       String shift1User = "Admin1";
//       String shift1IP = "321";
//       String shift1OpenTime = "08:00 AM";
//       String shift1CloseTime = "04:00 PM";
//       String shift1OpenAmount = "1000";
//       String shift1CloseAmount = "1500";

//       String systemCash = "2000";
//       String manualCash = "1950";
//       String differences = "50";
//       String cardSales = "3000";
//       String upiSales = "1000";
//       String swiggySales = "800";
//       String zomatoSales = "700";
//       String otherSales = "500";
//       String totalSales = "8000";

//       String totalCash = "5000";
//       String totalCard = "2500";
//       String totalUPI = "1500";
//       String cashReturn = "500";
//       String cashInHand = "8500";
//       String overallSales = "16000";

//       // Header: Shop Name
//       bytes += generator.text('BestMummy\n Sweets & Cakes',
//           styles: PosStyles(
//               align: PosAlign.center,
//               height: PosTextSize.size2,
//               width: PosTextSize.size2));
//       bytes += generator.text('Day End',
//           styles: PosStyles(
//               align: PosAlign.center,
//               height: PosTextSize.size2,
//               width: PosTextSize.size2));
//       bytes += generator.hr();

//       // Branch, Date, Time, User
//       bytes += generator.text('Branch: $branchName');
//       bytes += generator.text('Date: $date');
//       bytes += generator.text('Time: $time');
//       bytes += generator.text('User: $user');
//       bytes += generator.hr();

//       // Shift 1 details
//       bytes += generator.text('Shift 1', styles: PosStyles(bold: true));
//       bytes += generator.row([
//         PosColumn(
//             width: 6,
//             text: 'Shift ID: $shift1IP',
//             styles: const PosStyles(align: PosAlign.left)),
//         PosColumn(
//             width: 6,
//             text: 'User: $shift1User',
//             styles: const PosStyles(align: PosAlign.left)),
//       ]);
//       bytes += generator.row([
//         PosColumn(
//             width: 6,
//             text: 'Opening Time: $shift1OpenTime',
//             styles: const PosStyles(align: PosAlign.left)),
//         PosColumn(
//             width: 6,
//             text: 'Closing Time: $shift1CloseTime',
//             styles: const PosStyles(align: PosAlign.left)),
//       ]);
//       bytes += generator.row([
//         PosColumn(
//             width: 6,
//             text: 'Opening Amount: $shift1OpenAmount',
//             styles: const PosStyles(align: PosAlign.left)),
//         PosColumn(
//             width: 6,
//             text: 'Closing Amount: $shift1CloseAmount',
//             styles: const PosStyles(align: PosAlign.left)),
//       ]);
//       bytes += generator.hr();

//       // Sales summary
//       bytes += generator.text('Sales Summary', styles: PosStyles(bold: true));
//       bytes += generator.text('System Cash: $systemCash');
//       bytes += generator.text('Manual Cash: $manualCash');
//       bytes += generator.text('Differences: $differences');
//       bytes += generator.text('Card Sales: $cardSales');
//       bytes += generator.text('UPI Sales: $upiSales');
//       bytes += generator.text('Swiggy Sales: $swiggySales');
//       bytes += generator.text('Zomato Sales: $zomatoSales');
//       bytes += generator.text('Other Sales: $otherSales');
//       bytes += generator.text('Total Sales: $totalSales');
//       bytes += generator.hr();

//       // Shift 2 details
//       bytes += generator.text('Shift 2', styles: PosStyles(bold: true));
//       bytes += generator.row([
//         PosColumn(
//             width: 6,
//             text: 'Shift ID: $shift1IP',
//             styles: const PosStyles(align: PosAlign.left)),
//         PosColumn(
//             width: 6,
//             text: 'User: $shift1User',
//             styles: const PosStyles(align: PosAlign.left)),
//       ]);
//       bytes += generator.row([
//         PosColumn(
//             width: 6,
//             text: 'Opening Time: $shift1OpenTime',
//             styles: const PosStyles(align: PosAlign.left)),
//         PosColumn(
//             width: 6,
//             text: 'Closing Time: $shift1CloseTime',
//             styles: const PosStyles(align: PosAlign.left)),
//       ]);
//       bytes += generator.row([
//         PosColumn(
//             width: 6,
//             text: 'Opening Amount: $shift1OpenAmount',
//             styles: const PosStyles(align: PosAlign.left)),
//         PosColumn(
//             width: 6,
//             text: 'Closing Amount: $shift1CloseAmount',
//             styles: const PosStyles(align: PosAlign.left)),
//       ]);
//       bytes += generator.hr();

//       // Sales summary
//       bytes += generator.text('Sales Summary', styles: PosStyles(bold: true));
//       bytes += generator.text('System Cash: $systemCash');
//       bytes += generator.text('Manual Cash: $manualCash');
//       bytes += generator.text('Differences: $differences');
//       bytes += generator.text('Card Sales: $cardSales');
//       bytes += generator.text('UPI Sales: $upiSales');
//       bytes += generator.text('Swiggy Sales: $swiggySales');
//       bytes += generator.text('Zomato Sales: $zomatoSales');
//       bytes += generator.text('Other Sales: $otherSales');
//       bytes += generator.text('Total Sales: $totalSales');

//       bytes += generator.hr();

//       // Final amounts
//       bytes += generator.text('Final Amount', styles: PosStyles(bold: true));
//       bytes += generator.text('Total Cash: $totalCash');
//       bytes += generator.text('Total Card: $totalCard');
//       bytes += generator.text('Total UPI: $totalUPI');
//       bytes += generator.text('Cash Return: $cashReturn');
//       bytes += generator.text('Cash in Hand: $cashInHand');
//       bytes += generator.hr();

//       // Overall sales
//       bytes += generator.text('Overall Sales: $overallSales',
//           styles: PosStyles(bold: true));

//       // Send to printer
//       printer.rawBytes(Uint8List.fromList(bytes));
//       printer.cut();
//       await Future.delayed(const Duration(seconds: 1));
//       printer.disconnect();
//     }
//   }
// }
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

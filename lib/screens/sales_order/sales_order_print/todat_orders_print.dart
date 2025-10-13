import 'dart:typed_data';

import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:flutter/material.dart';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/customposcolumn.dart';
import 'package:yenposapp/screens/sales_order/screens/model/sales_order_display_model.dart';
// import 'package:yenposapp/Global/customposcolumn.dart' show createPosColumn, createPosStyles;
import '../../../Global/scaffold_global.dart';
import '../../printer_screen/provider/printer_config_provider.dart';

class PrintUtility {
  static Future<void> printSalesOrders(
      BuildContext context, List<dynamic> salesOrders) async {
    // Get printer IP from provider
    final printerProvider =
        Provider.of<PrinterProviderpos>(context, listen: false);
    String? printerIp = printerProvider.getOverallPrinterIp();

    // Load the printer profile
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    // Try connecting to the printer
    final PosPrintResult res = await printer.connect(printerIp!, port: 9100);

    if (res != PosPrintResult.success) {
      GlobalScaffold.showMessage(
        message: "Unable to connect to printer at \$printerIp. Error: \$res",
        backgroundColor: Colors.red,
      );
      printer.disconnect();
      return;
    }

    // Start printing
    DateTime now = DateTime.now();
    String formattedDate = "${now.day}/${now.month}/${now.year}";

    // Title
    printer.setStyles(PosStyles(
      align: PosAlign.center,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
      bold: true,
    ));
    printer.text("Sales Orders");
    printer.hr();

    // Dynamic Table Header
    printer.setStyles(PosStyles(bold: true, align: PosAlign.left));
    printer.text("S.No  Order No        Amount    Number");
    printer.hr();

    // Dynamic Table Rows
    int index = 1;
    for (var order in salesOrders) {
      String orderNo = "N/A";
      String totalAmount = order.totalAmount.toStringAsFixed(2);
      String customerNumber = order.customerNumber ?? "N/A";
      String line =
          "${index.toString().padRight(5)} ${orderNo.padRight(15)} ${totalAmount.padRight(10)} ${customerNumber}";
      printer.text(line);
      index++;
    }

    // Summary and QR
    printer.hr();
    printer.setStyles(PosStyles(align: PosAlign.center));
    printer.qrcode(
        "Orders: ${salesOrders.length}, Total: ${_calculateTotal(salesOrders)}",
        size: QRSize.Size8,
        cor: QRCorrection.H);
    printer.text("Order Summary");
    printer.text("Total Orders: ${salesOrders.length}");
    printer.text("Total Amount: ${_calculateTotal(salesOrders)}");
    printer.text("Date: $formattedDate");

    // Footer
    printer.hr();
    printer.text("Thank you for your purchase!");
    printer.feed(2);
    printer.cut();
    printer.disconnect();
  }

  // Helper to calculate total
  static String _calculateTotal(List<dynamic> salesOrders) {
    double total = 0;
    for (var order in salesOrders) {
      total += order.totalAmount;
    }
    return total.toStringAsFixed(2);
  }

// List<dynamic> todaySalesOrders = getTodaySalesOrders(); // Fetch today's orders
// PrintUtility.printSalesOrders(context, todaySalesOrders);
  List<dynamic> getTodaySalesOrders(dynamic allSalesOrders) {
    DateTime today = DateTime.now();
    return allSalesOrders.where((order) {
      DateTime orderDate =
          DateTime.parse(order.date); // Ensure date format matches
      return orderDate.year == today.year &&
          orderDate.month == today.month &&
          orderDate.day == today.day;
    }).toList();
  }

  static Future<void> printReceiptDetails(
    BuildContext context,
    List<SalesOrderDisplay>
        salesOrder, // Ensure it's a list of SalesOrderDisplay
  ) async {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(now);
    String formattedTime =
        DateFormat('hh:mm a').format(now); // 12-hour format with AM/PM
    final printerProvider =
        Provider.of<PrinterProviderpos>(context, listen: false);
    // String printerIp = printerProvider.getOverallPrinterIp().toString();
    String printerIp = "192.168.1.87";

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final PosPrintResult res = await printer.connect(printerIp, port: 9100);

    if (res == PosPrintResult.success) {
      List<int> bytes;
      final generator = Generator(PaperSize.mm80, profile);
      bytes = []; // Reset bytes for each copy

      // Header
      bytes += generator.row([
        createPosColumn(
            width: 12,
            text: '                  BestMummy',
            styles: createPosStyles(
              align: PosAlign.center,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              codeTable: 'CP1252',
              bold: true,
            )),
      ]);
      //  bytes += generator.feed(1);

      bytes += generator.row([
        createPosColumn(
            width: 12,
            text: '                  Sweets & Cakes',
            styles: createPosStyles(
              align: PosAlign.center,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              codeTable: 'CP1252',
              bold: true,
            )),
      ]);
      bytes += generator.feed(2);

      // Print Branch and Date
      bytes += generator.row([
        createPosColumn(
            width: 6,
            text: 'Branch: Aranmanai',
            styles: createPosStyles(
                align: PosAlign.left, codeTable: 'CP1252', bold: false)),
        createPosColumn(
            width: 6,
            text: '       Date: $formattedDate',
            styles: createPosStyles(
                align: PosAlign.left, codeTable: 'CP1252', bold: false)),
      ]);

      bytes += generator.feed(1);

      for (int i = 0; i < salesOrder.length; i++) {
        SalesOrderDisplay orderItem =
            salesOrder[i]; // Access each object in the list

        bytes += generator.row([
          createPosColumn(
              width: 12,
              text: 'Sales Order No: ${orderItem.saleOrderNo}',
              styles: createPosStyles(
                align: PosAlign.center,
                codeTable: 'CP1252',
                height: PosTextSize.size2,
                width: PosTextSize.size1,
                bold: true,
              )),
        ]);

        bytes += generator.feed(1);

        // bytes += generator.feed(1);
        bytes += generator.row([
          createPosColumn(
              width: 3,
              text: 'S.NO ',
              styles: createPosStyles(
                  align: PosAlign.left, codeTable: 'CP1255', bold: true)),
          createPosColumn(
              width: 3,
              text: 'ITEM',
              styles: createPosStyles(
                  align: PosAlign.left, codeTable: 'CP1255', bold: true)),
          createPosColumn(
              width: 6,
              text: '                 AMOUNT',
              styles: createPosStyles(
                  align: PosAlign.left, codeTable: 'CP1255', bold: true)),
        ]);
        bytes += generator.text('--------------------------------------------');
        bytes += generator.feed(1);

        for (int j = 0; j < orderItem.varianceName.length; j++) {
          String varianceName = orderItem.varianceName[j]; // Item Name
          int quantity = orderItem.qty[j]; // Quantity
          double pricePerKg = orderItem.price[j]; // Price (per unit or per kg)
          String uom = orderItem.uom[j]; // UOM
          double taxRate = orderItem.tax[j]; // Tax
          double weight =
              orderItem.weight?[j] ?? 0; // Ensure weight available for Kg items
          double amount = orderItem.amount[j];
          double discountedAmount =
              amount - (orderItem.itemWiseDiscountAmount?[j] ?? 0);

          // --- Format Price Description ---
          String priceDescription = '';
          if (uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'kgs') {
            if (weight >= 1) {
              priceDescription =
                  '$quantity $uom (${weight.toStringAsFixed(2)} kg) × Rs.${pricePerKg.toStringAsFixed(0)}/kg';
            } else {
              // Convert to grams if < 1 kg
              priceDescription =
                  '$quantity × (${(weight * 1000).toStringAsFixed(0)} g) × Rs.${pricePerKg.toStringAsFixed(0)}/kg';
            }
          } else {
            // Pcs / Pkt / Others
            priceDescription =
                '${quantity.toStringAsFixed(0)} $uom × Rs.${pricePerKg.toStringAsFixed(0)}';
          }

          // --- Print Item Row ---
          bytes += generator.row([
            createPosColumn(
                width: 1,
                text: (j + 1).toString(), // Serial No
                styles: createPosStyles(align: PosAlign.left)),
            createPosColumn(
                width: 7,
                text: varianceName, // Item Name
                styles: createPosStyles(align: PosAlign.left)),
            createPosColumn(
                width: 4,
                text: ' ${amount.toStringAsFixed(2)}', // Amount
                styles: createPosStyles(align: PosAlign.right)),
          ]);

          // --- Print Description (Qty/UOM/Price/Tax) ---
          bytes += generator.row([
            createPosColumn(
                width: 10,
                text: '($priceDescription, Tax $taxRate%)',
                styles: createPosStyles(align: PosAlign.left)),
            createPosColumn(width: 2, text: ''),
          ]);

          bytes += generator.feed(1);
        } // ===== Total =====

        bytes += generator.row([
          createPosColumn(
              width: 12,
              text:
                  '                  Total Amount  =     ${orderItem.totalAmount}',
              styles: createPosStyles(
                align: PosAlign.center,
                codeTable: 'CP1252',
                width: PosTextSize.size1, // Bigger font
                height: PosTextSize.size2, // Bigger font
                bold: true,
              )),
        ]);

        // Add star divider to separate orders
        bytes += generator.feed(1);
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: '*****  *****',
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
              width: PosTextSize.size1,
              bold: true,
            ),
          ),
        ]);
        bytes += generator.feed(2); // extra spacing before next order
      }

      printer
          .rawBytes(Uint8List.fromList(bytes)); // Send the bytes to the printer
      printer.cut(); // Cut the paper after printing
      printer.disconnect();
    } else {}
  }

  static List<String> splitAddress(String address) {
    const int maxLineWidth = 18;
    List<String> lines = [];
    String remainingAddress = address ?? '';

    while (remainingAddress.length > maxLineWidth) {
      int lastIndex = remainingAddress.lastIndexOf(' ', maxLineWidth);
      if (lastIndex == -1) {
        lastIndex = maxLineWidth;
      }
      lines.add(remainingAddress.substring(0, lastIndex).trimRight());
      remainingAddress = remainingAddress.substring(lastIndex).trimLeft();
    }

    lines.add(remainingAddress);

    return lines;
  }

  static List<String> splitText(String text, int maxLineWidth) {
    List<String> lines = [];
    String remainingText = text ?? '';

    while (remainingText.length > maxLineWidth) {
      int lastIndex = remainingText.lastIndexOf(' ', maxLineWidth);
      if (lastIndex == -1) {
        // If no space is found, break at maxLineWidth
        lastIndex = maxLineWidth;
      }
      lines.add(remainingText.substring(0, lastIndex).trimRight());
      remainingText = remainingText.substring(lastIndex).trimLeft();
    }

    lines.add(remainingText);

    return lines;
  }
}

Future<void> printReceiptDetails(List<SalesOrderDisplay> salesOrders) async {
  final profile = await CapabilityProfile.load();
  final printer = NetworkPrinter(PaperSize.mm80, profile);

  const String printerIp =
      "192.168.1.87"; // Replace with your printer's actual IP
  final PosPrintResult connectResult =
      await printer.connect(printerIp, port: 9100);

  if (connectResult != PosPrintResult.success) {
    return;
  }

  printer.text('SALES RECEIPT',
      styles: PosStyles(
          align: PosAlign.center, height: PosTextSize.size2, bold: true));
  printer.text('  Date: ${DateTime.now().toString().split(' ')[0]}');
  printer.hr(); // Prints a horizontal line

  double grandTotal = 0;

  for (var order in salesOrders) {
    printer.text('Order ID: ${order.orderInvoiceNo}',
        styles: PosStyles(bold: true));
    printer.text('Customer: ${order.customerName}');
    printer.hr();

    printer.text('Item           Qty   Price   Total',
        styles: PosStyles(bold: true));
    double orderTotal = 0;

    grandTotal += orderTotal;
    printer.hr();
    printer.text('Order Total: \$${orderTotal.toStringAsFixed(2)}',
        styles: PosStyles(align: PosAlign.right, bold: true));
    printer.feed(1);
  }

  printer.hr();
  printer.text('Grand Total: \$${grandTotal.toStringAsFixed(2)}',
      styles: PosStyles(
          align: PosAlign.right, height: PosTextSize.size2, bold: true));

  printer.feed(2);
  printer.cut();
  printer.disconnect();
}

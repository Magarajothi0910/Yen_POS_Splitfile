import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import '../models/fetchBranch.dart';
import '../models/fetchDiningTax.dart';
import '../models/printer.dart';
import '../kotproviders/cart_page_provider.dart';
import '../kotproviders/printer_provider.dart';
import '../widgets/capitalizeWord.dart';
import '../widgets/custom_pos_column.dart';

double totalAmount = 0.0;

class ReceiptPrinter {
  final TextEditingController employeeNumberController;
  final String seathiveOrderId;

  final TextEditingController customerNumberController;
  final TextEditingController discountController;
  final TextEditingController customChargeController;
  final String selectedPaymentOptionValue;
  // final double totalAmount;
  final BuildContext context;
  final TextEditingController customAmountController;
  final String selectedPaymentOption;
  final List<Map<String, dynamic>> items; // Add items list
  final String branchName;
  final PrinterProvider printerProvider; // Add PrinterProvider

  ReceiptPrinter({
    required this.employeeNumberController,
    required this.seathiveOrderId, // Initialize printer provider

    required this.customerNumberController,
    required this.discountController,
    required this.customChargeController,
    required this.selectedPaymentOptionValue,
    // required this.totalAmount,
    required this.context,
    required this.customAmountController,
    required this.selectedPaymentOption,
    required this.items, // Initialize items list
    required this.branchName,
    required this.printerProvider,
  });

  Map<String, dynamic> groupItemsWithTotal(List<Map<String, dynamic>> items) {
    double localTotal = 0.0;
    Map<String, Map<String, dynamic>> grouped = {};

    for (var item in items) {
      List<String> itemNames = List<String>.from(item['itemName'] ?? []);
      List<String> varianceNames =
          List<String>.from(item['varianceName'] ?? []);
      List<double> quantities = List<double>.from(item['qty'] ?? []);
      List<double> prices = List<double>.from(item['price'] ?? []);
      List<double> weights = List<double>.from(item['weight'] ?? []);
      List<String> uoms = List<String>.from(item['uom'] ?? []);

      for (int i = 0; i < itemNames.length; i++) {
        if (quantities[i] > 0) {
          String key = '${itemNames[i]}-${varianceNames[i]}';
          double amount;
          if (uoms[i].toLowerCase() == 'kg' || uoms[i].toLowerCase() == 'kgs') {
            amount = prices[i] * quantities[i] * weights[i];
          } else {
            amount = prices[i] * quantities[i];
          }
          // Add amount every time
          localTotal += amount;

          if (grouped.containsKey(key)) {
            grouped[key]!['qty'] += quantities[i];
            grouped[key]!['amount'] += amount;
          } else {
            grouped[key] = {
              'itemName': itemNames[i],
              'varianceName': varianceNames[i],
              'qty': quantities[i],
              'price': prices[i],
              'amount': amount,
            };
          }
        }
      }
    }

    return {
      'groupedItems': grouped.values.toList(),
      'total': localTotal,
    };
  }

  Future<void> printReceiptDetails() async {
    String employeeNumber = employeeNumberController.text;
    String customerNumber = customerNumberController.text;
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

    String paymentAmount = selectedPaymentOption == 'Cash: Custom' &&
            customAmountController.text.isNotEmpty
        ? 'Rs ${customAmountController.text}'
        : 'Rs ${totalAmount.toStringAsFixed(0)}';

    final invoicePrinter = printerProvider.printers.firstWhere(
      (printer) => printer.type == 'Invoice',
      orElse: () => Printer(
        name: 'default_printer_name',
        ipAddress: 'default_ip',
        type: 'default_type',
      ),
    );

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);
    final PosPrintResult res =
        await printer.connect(invoicePrinter.ipAddress, port: 9100);

    if (res == PosPrintResult.success) {
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];
      bytes += generator.row([
        createPosColumn(
            width: 12,
            text: '',
            styles: createPosStyles(
              codeTable: 'CP1252',
            )),
      ]);
      bytes += generator.row([
        createPosColumn(
            width: 12,
            text: ' BestMummy ',
            styles: createPosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              codeTable: 'CP1252',
            )),
      ]);
      bytes += generator.row([
        createPosColumn(
            width: 12,
            text: ' Sweets & Cakes ',
            styles: createPosStyles(
              align: PosAlign.center,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              codeTable: 'CP1252',
            )),
      ]);
      bytes += generator.feed(1);
      bytes += generator.row([
        createPosColumn(
            width: 12,
            text: ' KOT INVOICE ',
            styles: createPosStyles(
                align: PosAlign.center,
                codeTable: 'CP1252',
                height: PosTextSize.size2,
                width: PosTextSize.size2)),
      ]);
      bytes += generator.feed(1);

      bytes += generator.row([
        createPosColumn(
            width: 5,
            text: 'Invoice No : 102',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
        createPosColumn(
            width: 7,
            text:
                'PreInv No : ${seathiveOrderId.substring(seathiveOrderId.length - 14)}',
            styles:
                createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
      ]);

      bytes += generator.feed(1);

      // Add formatted date and time
      bytes += generator.row([
        createPosColumn(
            width: 6,
            text: 'Date       : $formattedDate',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
        createPosColumn(
            width: 6,
            text: 'Time : $formattedTime',
            styles:
                createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
      ]);

      bytes += generator.feed(1);

// Print Sales Person and Customer Number on the same line
      bytes += generator.row([
        createPosColumn(
            width: 6,
            text: 'Branch     : $branchName',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
        createPosColumn(
            width: 6,
            text: 'Customer No: $customerNumber',
            styles:
                createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
      ]);
      bytes += generator.feed(1);

      bytes += generator.row([
        createPosColumn(
            width: 12,
            text: ' Sales Person : $employeeNumber',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
      ]);
      bytes += generator.feed(1);

      // Add headers for S.No, Item, Price, Qty, and Amount
      bytes += generator.row([
        createPosColumn(
            width: 1,
            text: 'S.No',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
        createPosColumn(
            width: 5,
            text: 'Item',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
        createPosColumn(
            width: 2,
            text: '',
            styles:
                createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
        createPosColumn(
            width: 1,
            text: '',
            styles:
                createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
        createPosColumn(
            width: 3,
            text: 'Amount',
            styles:
                createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
      ]);

      bytes += generator.hr();
      double taxPercentage = getTaxPercentage();

      Map<String, dynamic> result = groupItemsWithTotal(items);
      List<Map<String, dynamic>> groupedItems = result['groupedItems'];
      double finalTotal = result['total'];
      double itemTax = finalTotal * (taxPercentage / 100);
      double itemSGST = itemTax / 2;
      double itemCGST = itemTax / 2;
      int serialNumber = 1; // Initialize S.No
      for (var item in groupedItems) {
        if (item['qty'] > 0) {
          // Ensure only items with qty > 0 are printed

          bytes += generator.row([
            createPosColumn(
              width: 1,
              text: serialNumber.toString(),
              styles:
                  createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
            ),
            createPosColumn(
              width: 8,
              text: capitalizeWords(item['varianceName']),
              styles:
                  createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
            ),
            createPosColumn(
              width: 3,
              text: item['amount'].toStringAsFixed(2),
              styles:
                  createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
            ),
          ]);

          // Print additional details
          bytes += generator.row([
            createPosColumn(
              width: 1,
              text: '',
              styles:
                  createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
            ),
            createPosColumn(
              width: 8,
              text:
                  "(${item['qty'].toStringAsFixed(0)} x Rs ${item['price'].toStringAsFixed(0)} Tax: ${taxPercentage.toStringAsFixed(0)}%)",
              styles:
                  createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
            ),
            createPosColumn(
              width: 3,
              text: '',
              styles:
                  createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
            ),
          ]);
          bytes += generator.row([
            createPosColumn(
                width: 12,
                text: '',
                styles: createPosStyles(align: PosAlign.center)),
          ]);

          serialNumber++;
        }
      }


      bytes += generator.hr();
      bytes += generator.text(
        'Total: ${finalTotal.toStringAsFixed(0)}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      );
      bytes += generator.row([
        createPosColumn(
          text:
              'SGST (${taxPercentage / 2}%): Rs ${itemSGST.toStringAsFixed(2)}',
          width: 12,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        createPosColumn(
          text:
              'CGST (${taxPercentage / 2}%): Rs ${itemCGST.toStringAsFixed(2)}',
          width: 12,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        createPosColumn(
            width: 12,
            text: '----------------------------------------------',
            styles:
                createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
      ]);
      bytes += generator.feed(1);
      bytes += generator.row([
        createPosColumn(
            width: 12,
            text: ' TOTAL Rs ${finalTotal.toStringAsFixed(0)}',
            styles: createPosStyles(
                align: PosAlign.right,
                codeTable: 'CP1252',
                height: PosTextSize.size2,
                width: PosTextSize.size2)),
      ]);
      bytes += generator.feed(1);
      bytes += generator.text('Thank You! Visit Again!',
          styles: const PosStyles(align: PosAlign.center));
      // Inside _printReceiptDetails function
      bytes += generator.feed(1);
      Map<String, dynamic>? branchDetails = await getBranchDetails();

      // Extract branch details
      String branchAddress =
          branchDetails?['address'] ?? 'Address not available';
      String branchCity = branchDetails?['city'] ?? '';
      String branchState = branchDetails?['state'] ?? '';

      String branchPostalCode = branchDetails?['postalCode'] ?? '';
      String branchPhoneNumber =
          branchDetails?['phoneNumber'] ?? 'Phone not available';
      String fullAddress =
          "$branchAddress,$branchName,$branchCity   $branchState - $branchPostalCode";
      const int maxLineWidth = 18;
      List<String> addressLines = splitAddress(fullAddress);

      for (int i = 0; i < addressLines.length; i++) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: addressLines[i],
            styles: const PosStyles(
              align: PosAlign.center, // Center the text
              codeTable: 'CP1252',
            ),
          ),
        ]);
      }
      bytes += generator.row([
        createPosColumn(
            width: 12,
            text: 'Phone : $branchPhoneNumber',
            styles:
                const PosStyles(align: PosAlign.center, codeTable: 'CP1252')),
      ]);
      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'GST : 33AATFB12B1ZW',
          styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'FSSAI : 1242000',
          styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);

      printer
          .rawBytes(Uint8List.fromList(bytes)); // Send the bytes to the printer

      printer.cut();

      await Future.delayed(const Duration(seconds: 1));
      printer.disconnect();

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved successfully')));
    } else {
    }
  }
}

List<String> splitAddress(String address) {
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

// ignore_for_file: unused_local_variable

import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yenposapp/Global/Widget/customposcolumn.dart';

class SalesReturnBill {
  final BuildContext context;
  SalesReturnBill({required this.context});

  Future<void> printReceiptDetails({
    required List<Map<String, dynamic>> returnItems,
  }) async {
    // Static data setup
    String employeeNumber = 'EMP334416';
    String customerNumber = 'CUST78910';
    String formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    // Calculate the total return amount
    double totalReturnAmount = returnItems.fold(
      0,
      (sum, item) => sum + item['returnQty'] * item['pricePerUnit'],
    );

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final PosPrintResult res =
        await printer.connect('192.168.1.87', port: 9100);
    if (res == PosPrintResult.success) {
      try {
        for (int copy = 0; copy < 2; copy++) {
          String receiptTitle =
              copy == 0 ? 'Sales Return' : 'Sales Return\nCustomer Copy';

          List<int> bytes = [];
          final generator = Generator(PaperSize.mm80, profile);

          // Header
          bytes += generator.row([
            createPosColumn(
                width: 12,
                text: '',
                styles: createPosStyles(
                  align: PosAlign.center,
                  height: PosTextSize.size6,
                  width: PosTextSize.size6,
                  codeTable: 'CP1252',
                )),
          ]);
          bytes += generator.row([
            createPosColumn(
                width: 12,
                text: 'BestMummy',
                styles: createPosStyles(
                  align: PosAlign.center,
                  height: PosTextSize.size1,
                  width: PosTextSize.size1,
                  codeTable: 'CP1252',
                )),
          ]);
          bytes += generator.row([
            createPosColumn(
                width: 12,
                text: 'Sweets & Cakes',
                styles: createPosStyles(
                  align: PosAlign.center,
                  height: PosTextSize.size1,
                  width: PosTextSize.size1,
                  codeTable: 'CP1252',
                )),
          ]);
          bytes += generator.feed(1);

          // Header
          // Title and Customer Copy notice
          bytes += generator.text(receiptTitle,
              styles: PosStyles(
                align: PosAlign.center,
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
              linesAfter: 1);

          // if (isReturn) {
          //   bytes += generator.text('Customer Copy',
          //       styles: PosStyles(align: PosAlign.center), linesAfter: 1);
          // }

          // Date and Time
          bytes += generator.row([
            createPosColumn(
                width: 6,
                text: 'Date: $formattedDate',
                styles:
                    createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
            createPosColumn(
                width: 6,
                text: 'Time: $formattedTime',
                styles: createPosStyles(
                    align: PosAlign.right, codeTable: 'CP1252')),
          ]);
          bytes += generator.feed(1);

          // Sales Person and Customer Number
          bytes += generator.row([
            createPosColumn(
                width: 6,
                text: 'Sales Person: $employeeNumber',
                styles:
                    createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
            createPosColumn(
                width: 6,
                text: 'Customer No: $customerNumber',
                styles: createPosStyles(
                    align: PosAlign.right, codeTable: 'CP1252')),
          ]);
          bytes += generator.feed(1);
          bytes += generator.row([
            createPosColumn(
                width: 1,
                text: 'S.No',
                styles:
                    createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
            createPosColumn(
                width: 5,
                text: 'Item',
                styles:
                    createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
            createPosColumn(
                width: 2,
                text: '',
                styles: createPosStyles(
                    align: PosAlign.right, codeTable: 'CP1252')),
            createPosColumn(
                width: 1,
                text: '',
                styles: createPosStyles(
                    align: PosAlign.right, codeTable: 'CP1252')),
            createPosColumn(
                width: 3,
                text: 'Amount',
                styles: createPosStyles(
                    align: PosAlign.right, codeTable: 'CP1252')),
          ]);
          // Inside _printReceiptDetails function
          bytes += generator.feed(1);
          // Item List Example
          for (int i = 0; i < returnItems.length; i++) {
            final item = returnItems[i];
            bytes += generator.row([
              PosColumn(
                text: '${i + 1}. ${item["itemName"]} (${item["variance"]})',
                width: 6,
              ),
              PosColumn(
                text: '${item["returnQty"].toStringAsFixed(2)} ${item["uom"]}',
                width: 3,
                styles: PosStyles(align: PosAlign.right),
              ),
              PosColumn(
                text:
                    '${(item["returnQty"] * item["pricePerUnit"]).toStringAsFixed(2)}',
                width: 3,
                styles: PosStyles(align: PosAlign.right),
              ),
            ]);
          }

          bytes += generator.row([
            createPosColumn(
                width: 12,
                text: '----------------------------------------------',
                styles: createPosStyles(
                    align: PosAlign.center, codeTable: 'CP1252')),
          ]);
          // Total Amount
          bytes += generator.text(
              'Total Return Amount: ${totalReturnAmount.toStringAsFixed(2)}',
              styles: PosStyles(align: PosAlign.right, bold: true));
          bytes += generator.feed(1);
          bytes += generator.row([
            createPosColumn(
                width: 12,
                text: '----------------------------------------------',
                styles: createPosStyles(
                    align: PosAlign.center, codeTable: 'CP1252')),
          ]);
          // Footer
          bytes += generator.text('Thank You ! Visit Again !',
              styles: PosStyles(align: PosAlign.center, codeTable: 'CP1252'));
          bytes += generator.feed(1);

          const int maxLineWidth = 18;
          List<String> addressLines = splitAddress(
              "No.45, Raja Veethi, Aranmanai, Ramanathapuram, Tamil Nadu-623501");

          for (int i = 0; i < addressLines.length; i++) {
            bytes += generator.row([
              createPosColumn(
                width: 12,
                text: addressLines[i],
                styles: createPosStyles(
                  align: PosAlign.center, // Center the text
                  codeTable: 'CP1252',
                ),
              ),
            ]);
          }
          bytes += generator.row([
            createPosColumn(
                width: 12,
                text: 'Phone : 9342978427',
                styles: createPosStyles(
                    align: PosAlign.center, codeTable: 'CP1252')),
          ]);
          bytes += generator.row([
            createPosColumn(
              width: 6,
              text: 'GST : 33AATFB12B1ZW',
              styles:
                  createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
            ),
            createPosColumn(
              width: 6,
              text: 'FSSAI : 1242000',
              styles:
                  createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
            ),
          ]);

          bytes += generator.feed(1);
          printer.rawBytes(
              Uint8List.fromList(bytes)); // Send the bytes to the printer
          printer.cut();

          // Debug print statement
        }
      } finally {
        printer.disconnect(); // Ensure to disconnect after the job is done
      }
    } else {}
  }

  List<String> splitAddress(String address) {
    const int maxLineWidth = 18;
    List<String> lines = [];
    String remainingAddress = address;

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

  List<String> splitText(String text, int maxLineWidth) {
    List<String> lines = [];
    String remainingText = text;

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

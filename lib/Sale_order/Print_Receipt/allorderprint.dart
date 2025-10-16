import 'dart:math';
import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Global/Widget/customposcolumn.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;


class salesInvoiceReceiptPrinter {
  final TextEditingController employeeNameController;
  final TextEditingController customerNumberController;
  double discountController;
  String deliveryDateprint;
  String deliveryTimeprint;
  double customChargeController;
  String selectedPaymentOptionValue;
  double totalAmount;
  double advanceAmount;
  double balanceAmount;
  String customerType;
  // final BuildContext context;
  final TextEditingController customAmountController;
  String selectedPaymentOption;

  // final Function saveInvoiceToHiveAndPrint;
  salesInvoiceReceiptPrinter({
    required this.employeeNameController,
    required this.customerNumberController,
    required this.discountController,
    required this.deliveryDateprint,
    required this.deliveryTimeprint,
    required this.customChargeController,
    required this.selectedPaymentOptionValue,
    required this.totalAmount,
    required this.advanceAmount,
    required this.balanceAmount,
    // required this.context,
    required this.customerType,
    required this.customAmountController,
    required this.selectedPaymentOption,

    // required this.saveInvoiceToHiveAndPrint,
  });
  Future<void> printReceiptDetails() async {
    // var cartProvider = Provider.of<CartProvider>(context, listen: false);
    var cartItems = globals.invoiceItems ?? [];

    // String employeeName = employeeNameController.text ?? '';
    // String customerNumber = customerNumberController.text ?? '';
    String paymentAmount;
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(now);
    String formattedTime = DateFormat(
      'hh:mm a',
    ).format(now); // 12-hour format with AM/PM

    if (selectedPaymentOption == 'Cash: Custom' &&
        customAmountController.text.isNotEmpty) {
      paymentAmount =
          'Rs $customAmountController'; // Ensuring single currency symbol
    } else if (selectedPaymentOption.contains('')) {
      paymentAmount =
          'Rs ${selectedPaymentOption.split(': ').last.replaceAll('', '').trim()}';
    } else {
      paymentAmount = 'Rs ${totalAmount.toStringAsFixed(0) ?? '0'}';
    }

    String printerIp = '192.168.1.87';
    // printerProvider.getOverallPrinterIp().toString()

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final PosPrintResult res = await printer.connect(printerIp, port: 9100);

    if (res == PosPrintResult.success) {
      List<int> bytes;
      final generator = Generator(PaperSize.mm80, profile);

      // for (int copy = 0; copy < 2; copy++) {
      bytes = []; // Reset bytes for each copy

      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: '',
          styles: createPosStyles(
            align: PosAlign.center,
            height: PosTextSize.size6,
            width: PosTextSize.size6,
            codeTable: 'CP1252',
          ),
        ),
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
          ),
        ),
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
          ),
        ),
      ]);
      bytes += generator.feed(1);
      bytes += generator.feed(1);
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: 'sales Invoice',
          styles: createPosStyles(
            align: PosAlign.center,
            codeTable: 'CP1252',
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
      ]);
      bytes += generator.feed(1);

      // Add formatted date and time
      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'Date: $formattedDate',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'Time: $formattedTime',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);

      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'Branch : Aranmanai',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: customerType == 'SalesOrder'
              ? 'saleOrderNo:101'
              : 'creditBillNo:101',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);

      // Print Sales Person and Customer Number on the same line
      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'SalesPerson : ${employeeNameController.text}',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'C No: ${customerNumberController.text}',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);

      // Add headers for S.No, Item, Price, Qty, and Amount
      bytes += generator.row([
        createPosColumn(
          width: 1,
          text: 'S.No',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 5,
          text: 'Item',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 2,
          text: '',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 1,
          text: '',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 3,
          text: 'Amount',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);
      double totalSGST = 0.0;
      double totalCGST = 0.0;
      double taxVaule = 0.0;
      Map<double, double> sgstMap = {};
      Map<double, double> cgstMap = {};

      for (int i = 0; i < cartItems.length; i++) {
        final item = cartItems[i];
        // final item = cartItems[i];
        String varianceName = item.varianceName[i];
        int quantity = item.qty;
        double price = item.price;
        String uom = item.uom[i];
        double taxRate = item.tax;
        double weight = item.weight;
        double totalTax = totalAmount * (taxRate / 100); // Total tax amount
        double sgstAmount = totalTax / 2; // SGST amount
        double cgstAmount = totalTax / 2;
        // Calculate item amount
        sgstMap[taxRate / 2] = (sgstMap[taxRate / 2] ?? 0.0) + sgstAmount;
        cgstMap[taxRate / 2] = (cgstMap[taxRate / 2] ?? 0.0) + cgstAmount;
        double amount = price * quantity;

        List<String> varianceNameLines = splitText(varianceName ?? '', 15);

        // Main item name
        bytes += generator.row([
          createPosColumn(
            width: 1,
            text: (i + 1).toString(), // S.No
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 8,
            text: varianceNameLines[0], // First line of item name

            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 3,
            text:
                // "Rs ${cartProvider.calculateSubtotal().toStringAsFixed(0)}", // Price
                "Rs $amount",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);

        // If there are additional lines for the item name, print them below
        if (varianceNameLines.length > 1) {
          for (int j = 1; j < varianceNameLines.length; j++) {
            bytes += generator.row([
              createPosColumn(
                width: 1,
                text: '',
                styles: createPosStyles(align: PosAlign.left),
              ),
              createPosColumn(
                width: 8,
                text: varianceNameLines[j], // Additional line of item name
                // text: 'hii',
                styles: createPosStyles(
                  align: PosAlign.left,
                  codeTable: 'CP1252',
                ),
              ),
              createPosColumn(
                width: 3,
                text: '',
                styles: createPosStyles(align: PosAlign.right),
              ),
            ]);
          }
        }

        // Quantity and unit price (for kg, pcs, etc.)
        bytes += generator.row([
          createPosColumn(
            width: 1,
            text: '',
            styles: createPosStyles(align: PosAlign.left),
          ),
          createPosColumn(
            width: 8,
            text:
                "($quantity $uom x $price $taxRate%)", // Quantity and unit price

            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 3,
            text: "", // Total amount
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);

        // Add an empty row for spacing between items
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: '',
            styles: createPosStyles(align: PosAlign.center),
          ),
        ]);
      }

      // Adding totals and other details
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: '----------------------------------------------',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);
      // Display the discount amount and percentage
      if (discountController != 0) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Discount:  Rs ${discountController.toStringAsFixed(2)}",
            // "",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      }
      // Print Custom Charge
      if (customChargeController != 0) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text:
                "Custom Charge: Rs ${customChargeController.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      }

      // // Find the section where the payment details are printed and adjust it:

      if (advanceAmount != 0) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Advance Amount :Rs ${advanceAmount.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      }

      sgstMap.forEach((rate, amount) {
        bytes += generator.row([
          createPosColumn(
            text:
                "SGST (${rate.toStringAsFixed(1)}%): Rs ${amount.toStringAsFixed(2)}",
            width: 12, // Assuming a width of 12 for full row width
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      });
      cgstMap.forEach((rate, amount) {
        bytes += generator.row([
          createPosColumn(
            text:
                "CGST (${rate.toStringAsFixed(1)}%): Rs ${amount.toStringAsFixed(2)}",
            width: 12, // Full width
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      });

      bytes += generator.row([
        createPosColumn(
          width: 12,
          text:
              "$selectedPaymentOptionValue: ${totalAmount.toStringAsFixed(0)}",
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: "Total Amount :Rs ${totalAmount.toStringAsFixed(0)}",
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: '----------------------------------------------',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: ' TOTAL Rs ${totalAmount.toStringAsFixed(0)}',
          styles: createPosStyles(
            align: PosAlign.right,
            codeTable: 'CP1252',
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
      ]);
      bytes += generator.feed(1);
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: 'Thank You ! Visit Again !',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);

      // Inside _printReceiptDetails function
      bytes += generator.feed(1);

      const int maxLineWidth = 18;
      List<String> addressLines = splitAddress(
        "No.45, Raja Veethi, Aranmanai, Ramanathapuram, Tamil Nadu-623501",
      );

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
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);
      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'GST : 33AATFB12B1ZW',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'FSSAI : 1242000',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);
      bytes += generator.feed(2);
      bytes += generator.cut();
      printer.rawBytes(
        Uint8List.fromList(bytes),
      ); // Send the bytes to the printer

      printer.disconnect();
    } else {}

    // Navigator.of(context).pop();
    // cartProvider.clearCart();
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

  List<String> splitText(String text, int maxLineWidth) {
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

  String generateShortHiveInvoiceId() {
    final random = Random();
    final timestamp = DateTime.now()
        .millisecondsSinceEpoch
        .toString()
        .substring(6); // Shortened timestamp
    const characters =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123334419'; // Alphanumeric characters
    final randomId =
        List<int>.generate(6, (_) => random.nextInt(characters.length))
            .map((index) => characters[index])
            .join(); // Generate a 6-character random ID
    return '$timestamp-$randomId'; // Combines timestamp and random alphanumeric ID
  }
}

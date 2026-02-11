import 'dart:math';
import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Widget/customposcolumn.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/salesInvoicePayandPrint.dart';
import 'package:yen_pos/Sale_order/Provider/cart_page_provider.dart';
import 'dart:developer' as developer;

import '../../printer_screen/provider/printer_config_provider.dart';

class ReceiptPrinter {
  final String employeeNumberController;
  final TextEditingController customerNumberController;
  final TextEditingController discountController;
  final TextEditingController customChargeController;
  final String selectedPaymentOptionValue;
  final double totalAmount;
  final BuildContext context;
  final TextEditingController customAmountController;
  final String selectedPaymentOption;
  final Function saveInvoiceToHiveAndPrint;
  final double discountAmount; // Add discount amount
  final String invoiceNo;
  ReceiptPrinter({
    required this.employeeNumberController,
    required this.customerNumberController,
    required this.discountController,
    required this.customChargeController,
    required this.selectedPaymentOptionValue,
    required this.totalAmount,
    required this.context,
    required this.customAmountController,
    required this.selectedPaymentOption,
    required this.saveInvoiceToHiveAndPrint,
    required this.discountAmount, // Initialize discount amount
    required this.invoiceNo,
  });

  Future<void> printReceiptDetails() async {
    String employeeNumber = employeeNumberController;
    String customerNumber = customerNumberController.text;
    String paymentAmount;
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(now);
    String formattedTime = DateFormat(
      'hh:mm a',
    ).format(now); // 12-hour format with AM/PM

    if (selectedPaymentOption == 'Cash: Custom' &&
        customAmountController.text.isNotEmpty) {
      paymentAmount =
          'Rs ${customAmountController.text}'; // Ensuring single currency symbol
    } else if (selectedPaymentOption.contains('')) {
      paymentAmount =
          'Rs ${selectedPaymentOption.split(': ').last.replaceAll('', '').trim()}';
    } else {
      paymentAmount = 'Rs ${totalAmount.toStringAsFixed(0)}';
    }
    var invoiceNumberGenerator = InvoiceNumberGenerator();
    String newInvoiceNumber = await invoiceNumberGenerator
        .generateInvoiceNumber();
    var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
    var cartItems = cartProvider.currentSaleItems;
    double discountPercentage = cartProvider.discountPercentage;
    double customCharge = cartProvider.customCharge;
    double discountAmount =
        cartProvider.calculateTotal() * discountPercentage / 100;
    // Fetch the settings
    // ignore: unused_local_variable
    final settings = GlobalDataManager().billReceiptSettings;
    final printerProvider = Provider.of<PrinterProviderpos>(
      context,
      listen: false,
    );

    String printerIp = printerProvider.getOverallPrinterIp().toString();

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final PosPrintResult res = await printer.connect(printerIp, port: 9100);
    // Check if there are any hold bills in the cart
    bool hasHoldBills = cartProvider.currentSaleItems.any(
      (item) => item['status'] == 'hold',
    );

    if (hasHoldBills) {
      developer.log(
        'Yes, there are hold bills in the cart.',
        name: 'PrintReceiptLog',
      );
    } else {
      developer.log(
        'No hold bills found in the cart.',
        name: 'PrintReceiptLog',
      );
    }
    if (res == PosPrintResult.success) {
      List<int> bytes = [];
      final generator = Generator(PaperSize.mm80, profile);

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

      //cartProvider.calculateTotal().toStringAsFixed(2)}
      // Sales Invoice details
      // bytes += generator.row([
      //   createPosColumn(
      //       width: 12,
      //       text: 'Rs ${cartProvider.calculateTotal().toStringAsFixed(0)}',
      //       styles: createPosStyles(
      //         align: PosAlign.center,
      //         codeTable: 'CP1252',
      //         height: PosTextSize.size3,
      //         width: PosTextSize.size3,
      //       )),
      // ]);
      bytes += generator.feed(1);
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: 'Sales Invoice',
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
          width: 5,
          text: 'Branch:Aranmanai',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 7,
          text: 'BillNo:$newInvoiceNumber',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);

      //       const int maxLineWidth = 18;
      // // Process and print employee name
      //       List<String> employeeNameLines =
      //           splitText(employeeNumberController, maxLineWidth);
      //       for (int i = 0; i < employeeNameLines.length; i++) {
      //         bytes += generator.row([
      //           createPosColumn(
      //               width: 12, // Assuming 12 is the full width of your receipt paper
      //               text: i == 0
      //                   ? 'Sales Person : ${employeeNameLines[i]}'
      //                   : '              ${employeeNameLines[i]}',
      //               styles:
      //                   createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
      //         ]);
      //       }

      // // Continue with other receipt details
      //       bytes += generator.row([
      //         createPosColumn(
      //           width: 12,
      //           text: 'Customer No: $customerNumber',
      //           styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
      //         ),
      //       ]);
      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'Sales Person : $employeeNumberController',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'Customer No: $customerNumber',
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
          text: 'ITEM',
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
          text: 'AMOUNT',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);
      // ignore: unused_local_variable
      double totalSGST = 0.0;
      // ignore: unused_local_variable
      double totalCGST = 0.0;
      // ignore: unused_local_variable
      double taxVaule = 0.0;
      Map<double, double> sgstMap = {};
      Map<double, double> cgstMap = {};

      // Process each item
      for (var item in cartItems) {
        // Assuming tax is fetched as dynamic or int, ensure it's treated as double
        double taxRate = (item['itemData']['tax'] as num)
            .toDouble(); // num can be both int and double
        double itemTotal = cartProvider
            .calculateItemTotal(item)
            .toDouble(); // Ensure itemTotal is a double

        double itemTax = itemTotal * (taxRate / 100);
        double itemSGST = itemTax / 2;
        double itemCGST = itemSGST;

        // Update the maps with doubles
        sgstMap[taxRate / 2] = (sgstMap[taxRate / 2] ?? 0.0) + itemSGST;
        cgstMap[taxRate / 2] = (cgstMap[taxRate / 2] ?? 0.0) + itemCGST;
      }

      // Adding cart items with item name, quantity, and price in the desired format
      for (int i = 0; i < cartItems.length; i++) {
        final item = cartItems[i];

        final String itemName = item['itemData']['itemName'] ?? 'N/A';
        final String varianceName =
            item['varianceData']['varianceName'] ?? 'N/A';
        final double price =
            item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0;
        final double weight = (item['weight'] ?? 0.0).toDouble();
        final double qty = (item['quantity'] as num).toDouble();
        final double amount = cartProvider.calculateItemTotal(item);
        final double tax = (item['itemData']['tax'] as num).toDouble();
        final String uom = item['varianceData']['variance_Uom'] ?? 'N/A';
        String quantityDisplay = cartProvider.buildQuantityPriceDisplay(item);
        // Get the tax percentage for the item
        final double itemTotal = cartProvider.calculateItemTotal(item);
        double taxPercentage = (item['itemData']['tax'] as num).toDouble();
        // Calculate SGST and CGST
        double itemTax = itemTotal * (taxPercentage / 100);
        double itemSGST = itemTax / 2;
        double itemCGST = itemTax / 2;

        totalSGST = itemSGST;
        totalCGST = itemCGST;
        taxVaule = taxPercentage; // Sum up item total + taxes

        // Log the quantityDisplay to the console
        developer.log('Printing Receipt...');
        developer.log('HiveInvoiceId:');
        developer.log('Item: $itemName');
        developer.log('Variance: $varianceName');
        developer.log('Price: Rs ${price.toStringAsFixed(0)}');
        developer.log('Weight: $weight');
        developer.log('Quantity: $quantityDisplay');
        developer.log('Qty: $qty');
        developer.log('Amount: Rs ${amount.toStringAsFixed(0)}');
        developer.log('Tax: $tax%');
        developer.log('UOM: $uom');
        developer.log('users: ');
        developer.log('totalAmount: ');
        developer.log('totalAmount2: ');
        developer.log('totalAmount3: ');
        developer.log('status: Active ');
        developer.log('branchid:');
        developer.log('branchName:');
        developer.log('cash: ');
        developer.log('upi:');
        developer.log('card:');
        developer.log('others:');
        developer.log('invoiceDate:');
        developer.log('invoiceTime:');
        developer.log('invoiceNumber:');
        developer.log('branchid:');
        developer.log('branchName:');
        developer.log('shiftId:');
        developer.log('shiftNumber:');
        developer.log('deviceNumber:');
        developer.log('Employee Number: $employeeNumber');
        developer.log('Customer Number: $customerNumber');
        developer.log('Discount: ${discountController.text}%');
        developer.log('Custom Charge: Rs ${customChargeController.text}');
        developer.log('Selected Payment: $selectedPaymentOption');
        developer.log('Payment Amount: $paymentAmount');

        // Save the data to Hive

        // Open the Hive box
        // ignore: unused_local_variable
        var box = await Hive.openBox('invoiceBox');

        saveInvoiceToHiveAndPrint();

        List<String> itemNameLines = splitText(
          item['varianceData']['varianceName'] ?? '',
          15,
        );

        // Main item name
        bytes += generator.row([
          createPosColumn(
            width: 1,
            text: (i + 1).toString(), // S.No
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 8,
            text: itemNameLines[0], // First line of item name
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 3,
            text:
                "Rs ${cartProvider.calculateItemTotal(item).toStringAsFixed(0)}", // Price
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);

        // If there are additional lines for the item name, print them below
        if (itemNameLines.length > 1) {
          for (int j = 1; j < itemNameLines.length; j++) {
            bytes += generator.row([
              createPosColumn(
                width: 1,
                text: '',
                styles: createPosStyles(align: PosAlign.left),
              ),
              createPosColumn(
                width: 8,
                text: itemNameLines[j], // Additional line of item name
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
                "(${item['quantity']} ${item['varianceData']['variance_Uom']} x ${item['varianceData']['variance_Defaultprice']} tax ${item['itemData']['tax']}%)", // Quantity and unit price
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
      if (discountController.text == 0) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text:
                "Discount: $discountPercentage% (-Rs ${discountAmount.toStringAsFixed(0)})",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      }
      // Print Custom Charge
      if (customChargeController.text == 0) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Custom Charge: Rs ${customCharge.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      }

      // Find the section where the payment details are printed and adjust it:
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
          text:
              "Total : Rs ${cartProvider.calculateTotal().toStringAsFixed(0)}",
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);
      // Print SGST and CGST details
      // Right-aligning SGST and CGST using generator.row()
      // sgstMap.forEach((rate, amount) {
      //   bytes += generator.row([
      //     createPosColumn(
      //         text:
      //             "SGST (${rate.toStringAsFixed(1)}%): Rs ${amount.toStringAsFixed(2)}",
      //         width: 12, // Assuming a width of 12 for full row width
      //         styles: const PosStyles(align: PosAlign.right))
      //   ]);
      // });
      // cgstMap.forEach((rate, amount) {
      //   bytes += generator.row([
      //     createPosColumn(
      //         text:
      //             "CGST (${rate.toStringAsFixed(1)}%): Rs ${amount.toStringAsFixed(2)}",
      //         width: 12, // Full width
      //         styles: const PosStyles(align: PosAlign.right))
      //   ]);
      // });
      // Combine SGST and CGST details on a single line
      sgstMap.forEach((rate, sgstAmount) {
        double cgstAmount =
            cgstMap[rate] ?? 0.0; // Get the corresponding CGST amount
        bytes += generator.row([
          createPosColumn(
            text:
                "SGST (${rate.toStringAsFixed(1)}%): Rs ${sgstAmount.toStringAsFixed(2)}  CGST (${rate.toStringAsFixed(1)}%): Rs ${cgstAmount.toStringAsFixed(2)}",
            width: 12,
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      });

      // Add these lines where you're preparing the rest of the receipt details
      // Inside _printReceiptDetails function

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
          text: 'TOTAL Rs ${cartProvider.calculateTotal().toStringAsFixed(0)}',
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

      List<String> addressLines = splitAddress(
        "No.72, Salai Bazaar, Ramanathapuram,  Tamil Nadu-623501",
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
          text: 'Phone : 9500910118',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);
      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'GST : 33AATFB4124B1ZW',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'FSSAI : 12420017000428',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);

      printer.rawBytes(
        Uint8List.fromList(bytes),
      ); // Send the bytes to the printer

      printer.cut();

      // Add a delay to ensure the printer completes the print job

      printer
          .disconnect(); // Disconnect the printer only after ensuring the print is complete
    } else {
      saveInvoiceToHiveAndPrint();
    }

    Navigator.of(context).pop();
    cartProvider.clearItems();
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

  String generateShortHiveInvoiceId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(6); // Shortened timestamp
    const characters =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ0126565989'; // Alphanumeric characters
    final randomId =
        List<int>.generate(6, (_) => random.nextInt(characters.length))
            .map((index) => characters[index])
            .join(); // Generate a 6-character random ID
    return '$timestamp-$randomId'; // Combines timestamp and random alphanumeric ID
  }
}

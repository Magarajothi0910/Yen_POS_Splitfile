import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/pending_print.dart';

import 'dart:developer' as developer;

import '../../printer_screen/provider/printer_config_provider.dart';
import '../../regular_mode_page/provider/cart_page_provider.dart';
import '../salesInvoicePayandPrint.dart';
import 'custom_pos_column.dart';
import 'dart:async';

class ReceiptPrinter {
  final String employeeNumberController;
  final TextEditingController customerNumberController;
  final TextEditingController discountController;
  final TextEditingController customChargeController;
  final String selectedPaymentOptionValue;
  final double totalAmount;
  final BuildContext context;
  final String selectedPaymentOption;
  // final Function saveInvoiceToHiveAndPrint;
  final double discountAmount;
  final String invoiceNo;
  final double cashAmount;
  final double cardAmount;
  final double upiAmount;
  final String newInvoiceNumber;

  ReceiptPrinter({
    required this.employeeNumberController,
    required this.customerNumberController,
    required this.discountController,
    required this.customChargeController,
    required this.selectedPaymentOptionValue,
    required this.totalAmount,
    required this.context,
    required this.selectedPaymentOption,
    //required this.saveInvoiceToHiveAndPrint,
    required this.discountAmount,
    required this.invoiceNo,
    required this.cashAmount,
    required this.cardAmount,
    required this.upiAmount,
    required this.newInvoiceNumber,
  });

  Future<void> printReceiptDetails() async {
    String employeeNumber = employeeNumberController;
    String customerNumber = customerNumberController.text;

    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

    // var invoiceNumberGenerator = InvoiceNumberGenerator();
    // String newInvoiceNumber = await invoiceNumberGenerator.generateInvoiceNumber();
    var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
    var cartItems = cartProvider.currentSaleItems ?? [];
    double discountPercentage = cartProvider.discountPercentage;
    double customCharge = cartProvider.customCharge;

    final settings = GlobalDataManager().billReceiptSettings;
    final printerProvider = Provider.of<PrinterProviderpos>(
      context,
      listen: false,
    );

    String printerIp = printerProvider.getOverallPrinterIp().toString();

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final PosPrintResult res = await printer.connect(printerIp, port: 9100);
    bool hasHoldBills = cartItems.any((item) => item['status'] == 'hold');

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
          width: 2,
          text: '',
          styles: createPosStyles(align: PosAlign.left),
        ),
        createPosColumn(
          width: 8,
          text: 'Sales Invoice',
          styles: PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size1,
            width: PosTextSize.size2,
            bold: true,
            codeTable: 'CP1252',
          ),
        ),
        createPosColumn(
          width: 2,
          text: '',
          styles: createPosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.feed(1);

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
          text: 'Branch: Aranmanai',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 7,
          text: 'BillNo: $newInvoiceNumber',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);

      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'Sales Person: $employeeNumberController',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'Customer No: $customerNumber',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);
      bytes += generator.feed(1);
      bytes += generator.hr();

      bytes += generator.row([
        createPosColumn(
          width: 1,
          text: 'S.No',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 5,
          text: 'ITEM',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
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
      bytes += generator.hr();

      bytes += generator.feed(1);
      double originalSubTotal = 0.0;
      Map<double, double> itemTotalsMap = {};

      for (var item in cartItems) {
        double itemTotal = cartProvider.calculateItemTotal(item).toDouble();
        double taxRate = (item['itemData']['tax'] as num).toDouble();
        originalSubTotal += itemTotal;
        if (isGSTEnabled) {
          itemTotalsMap[taxRate] = (itemTotalsMap[taxRate] ?? 0.0) + itemTotal;
        }
      }

      double grossTotal = originalSubTotal;
      double discountPercentage =
          double.tryParse(discountController.text) ?? 0.0;
      double discountAmount = (grossTotal * (discountPercentage / 100))
          .toDouble();
      double discountedGrossTotal = grossTotal - discountAmount;

      Map<double, double> cgstMap = {};
      Map<double, double> sgstMap = {};
      Map<double, double> netMap = {};

      if (isGSTEnabled) {
        itemTotalsMap.forEach((taxRate, grossWithTax) {
          double proportion = grossWithTax / grossTotal;
          double discountedGrossForRate =
              grossWithTax - (discountAmount * proportion);

          double netForRate = discountedGrossForRate / (1 + (taxRate / 100));
          double taxForRate = discountedGrossForRate - netForRate;
          double cgstForRate = taxForRate / 2;
          double sgstForRate = taxForRate / 2;

          cgstMap[taxRate] = cgstForRate;
          sgstMap[taxRate] = sgstForRate;
          netMap[taxRate] = netForRate;
        });
      }

      double totalNetAmount = isGSTEnabled
          ? netMap.values.fold(0.0, (a, b) => a + b)
          : discountedGrossTotal;
      double totalCGST = cgstMap.values.fold(0.0, (a, b) => a + b);
      double totalSGST = sgstMap.values.fold(0.0, (a, b) => a + b);
      double discountedTotal = isGSTEnabled
          ? totalNetAmount + totalCGST + totalSGST
          : discountedGrossTotal;
      final custom = double.tryParse(customChargeController.text) ?? 0.0;
      double receivedAmount = cashAmount + cardAmount + upiAmount;
      double finalTotal = discountedTotal + custom;
      double changeAmount = receivedAmount - finalTotal;

      double total = discountedTotal + custom;

      for (int i = 0; i < cartItems.length; i++) {
        final item = cartItems[i];

        final String itemName = item['itemData']['itemName'] ?? 'N/A';
        final String varianceName =
            item['varianceData']['varianceName'] ?? 'N/A';
        final double price =
            item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0;
        final double weight = (item['weight'] ?? 0.0).toDouble();
        final double qty = (item['quantity'] as num).toDouble();
        final double orig_amount = cartProvider.calculateItemTotal(item);
        final double tax = (item['itemData']['tax'] as num).toDouble();
        final String uom = item['varianceData']['variance_Uom'] ?? 'N/A';
        String quantityDisplay = cartProvider.buildQuantityPriceDisplay(item);
        final double itemTotal = cartProvider.calculateItemTotal(item);

        double item_discount_amt = orig_amount * (discountPercentage / 100);
        double item_disc_amount = orig_amount - item_discount_amt;

        developer.log('Printing Receipt...');
        developer.log('HiveInvoiceIdInset: Id:');
        developer.log('Item: $itemName');
        developer.log('Variance: $varianceName');
        developer.log('Price: Rs ${price.toStringAsFixed(0)}');
        developer.log('Weight: $weight');
        developer.log('Quantity: $quantityDisplay');
        developer.log('Qty: $qty');
        developer.log('Amount: Rs ${orig_amount.toStringAsFixed(0)}');
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
        developer.log('Cash Amount: $cashAmount');
        developer.log('Card Amount: $cardAmount');
        developer.log('UPI Amount: $upiAmount');

        List<String> itemNameLines = splitText(
          item['varianceData']['varianceName'] ?? '',
          15,
        );

        bytes += generator.row([
          createPosColumn(
            width: 1,
            text: (i + 1).toString(),
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 11,
            text: itemNameLines[0],
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          // createPosColumn(
          //   width: 0,
          //   text: "",
          //   styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          // ),
        ]);

        if (itemNameLines.length > 1) {
          for (int j = 1; j < itemNameLines.length; j++) {
            bytes += generator.row([
              createPosColumn(
                width: 1,
                text: '',
                styles: createPosStyles(align: PosAlign.left),
              ),
              createPosColumn(
                width: 11,
                text: itemNameLines[j],
                styles: createPosStyles(
                  align: PosAlign.left,
                  codeTable: 'CP1252',
                ),
              ),
              // createPosColumn(
              //   width: 3,
              //   text: '',
              //   styles: createPosStyles(align: PosAlign.right),
              // ),
            ]);
          }
        }

        String priceDescription =
            "${item['quantity']} ${item['varianceData']['variance_Uom']} x ${item['varianceData']['variance_Defaultprice']}";
        if (isGSTEnabled) {
          priceDescription += " (Tax ${item['itemData']['tax']}%)";
        }

        if (discountPercentage > 0) {
          final imgBytes = await textWithStrikeImage(
            snoText: '         ',
            itemName: priceDescription,
            amountText: "Rs ${orig_amount.toStringAsFixed(2)}",
          );
          bytes += generator.image(imgBytes, align: PosAlign.left);

          bytes += generator.row([
            createPosColumn(
              width: 1,
              text: '',
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              width: 8,
              text:
                  "Disc Amt($discountPercentage%): Rs ${item_discount_amt.toStringAsFixed(2)}",
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              width: 3,
              text: "Rs ${item_disc_amount.toStringAsFixed(2)}",
              styles: createPosStyles(
                align: PosAlign.right,
                codeTable: 'CP1252',
              ),
            ),
          ]);
        } else {
          bytes += generator.row([
            createPosColumn(
              width: 1,
              text: '',
              styles: createPosStyles(align: PosAlign.left),
            ),
            createPosColumn(
              width: 8,
              text: priceDescription,
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              width: 3,
              text: "Rs ${orig_amount.toStringAsFixed(2)}",
              styles: createPosStyles(
                align: PosAlign.right,
                codeTable: 'CP1252',
              ),
            ),
          ]);
        }

        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: '',
            styles: createPosStyles(align: PosAlign.center),
          ),
        ]);
      }

      bytes += generator.hr();

      if (discountPercentage > 0) {
        final imgBytes = await textWithStrikeImage(
          snoText: '',
          itemName: 'Item Total',
          amountText: 'Rs ${grossTotal.toStringAsFixed(2)}',
        );
        bytes += generator.image(imgBytes, align: PosAlign.left);

        bytes += generator.row([
          createPosColumn(
            width: 1,
            text: '',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 8,
            text:
                "Disc Amt($discountPercentage%): Rs ${discountAmount.toStringAsFixed(2)}",
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 3,
            text: "Rs ${discountedTotal.toStringAsFixed(2)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      } else {
        bytes += generator.row([
          createPosColumn(
            width: 6,
            text: 'Item Total',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 6,
            text: 'Rs ${discountedTotal.toStringAsFixed(2)}',
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      }

      if (custom > 0) {
        bytes += generator.row([
          createPosColumn(
            width: 6,
            text: 'Custom Charge',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 6,
            text: 'Rs ${custom.toStringAsFixed(2)}',
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      }

      bytes += generator.hr();

      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: 'TOTAL Rs ${total.round().toString()}',
          styles: PosStyles(
            align: PosAlign.right,
            codeTable: 'CP1252',
            width: PosTextSize.size2,
            bold: true,
          ),
        ),
      ]);

      bytes += generator.feed(1);

      if (discountAmount > 0) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: '****************************************',
            styles: PosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
              width: PosTextSize.size1,
              bold: true,
            ),
          ),
        ]);
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: 'You Saved in this Purchase!',
            styles: PosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
              width: PosTextSize.size1,
              bold: true,
            ),
          ),
        ]);
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: 'RS ${discountAmount.toStringAsFixed(2)}',
            styles: PosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
              width: PosTextSize.size2,
              bold: true,
            ),
          ),
        ]);
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: '****************************************',
            styles: PosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
              width: PosTextSize.size1,
              bold: true,
            ),
          ),
        ]);
      }
      if (discountAmount < 0) {
        bytes += generator.hr();
      }

      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: "Payment Details",
          styles: PosStyles(
            bold: true,
            codeTable: 'CP1252',
            align: PosAlign.left,
          ),
        ),
      ]);
      bytes += generator.feed(1);

      if (cashAmount > 0) {
        bytes += generator.row([
          createPosColumn(
            width: 5,
            text: "Cash",
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 2,
            text: ":",
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
          createPosColumn(
            width: 5,
            text: "Rs ${cashAmount.toStringAsFixed(2)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      }
      if (cardAmount > 0) {
        bytes += generator.row([
          createPosColumn(
            width: 5,
            text: "Card",
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 2,
            text: ":",
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
          createPosColumn(
            width: 5,
            text: "Rs ${cardAmount.toStringAsFixed(2)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      }
      if (upiAmount > 0) {
        bytes += generator.row([
          createPosColumn(
            width: 5,
            text: "Upi",
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 2,
            text: ":",
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
          createPosColumn(
            width: 5,
            text: "Rs ${upiAmount.toStringAsFixed(2)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
      }

      bytes += generator.row([
        createPosColumn(
          width: 5,
          text: "Receive Amt",
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 2,
          text: ":",
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 5,
          text: "Rs ${receivedAmount.toStringAsFixed(2)}",
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.row([
        createPosColumn(
          width: 5,
          text: "Balance Amt",
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 2,
          text: ":",
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 5,
          text: "Rs ${changeAmount.toStringAsFixed(2)}",
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      if (isGSTEnabled) {
        bytes += generator.hr();

        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Invoice Breakup",
            styles: PosStyles(
              bold: true,
              codeTable: 'CP1252',
              align: PosAlign.left,
            ),
          ),
        ]);
        bytes += generator.feed(1);

        bytes += generator.row([
          createPosColumn(
            width: 5,
            text: "Net Amt",
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 2,
            text: ":",
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
          createPosColumn(
            width: 5,
            text: "${totalNetAmount.toStringAsFixed(2)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);

        sgstMap.forEach((rate, sgstAmount) {
          double cgstAmount = cgstMap[rate] ?? 0.0;
          final gst = cgstAmount + sgstAmount;
          bytes += generator.row([
            createPosColumn(
              text: "GST($rate%)}",
              width: 6,
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              text: "${gst.toStringAsFixed(2)}",
              width: 6,
              styles: createPosStyles(
                align: PosAlign.right,
                codeTable: 'CP1252',
              ),
            ),
          ]);
          bytes += generator.row([
            createPosColumn(
              text:
                  "SGST(${(rate / 2).toStringAsFixed(1)}%): ${sgstAmount.toStringAsFixed(2)}",
              width: 6,
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              text:
                  "CGST(${(rate / 2).toStringAsFixed(1)}%): ${cgstAmount.toStringAsFixed(2)}",
              width: 6,
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
          ]);
        });
      }
      bytes += generator.hr();
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: 'TOTAL Rs ${total.round().toStringAsFixed(2)}',
          styles: PosStyles(
            align: PosAlign.right,
            codeTable: 'CP1252',
            width: PosTextSize.size1,
          ),
        ),
      ]);

      bytes += generator.hr();

      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: 'Thank You ! Visit Again !',
          styles: PosStyles(
            align: PosAlign.center,
            codeTable: 'CP1252',
            bold: true,
          ),
        ),
      ]);

      bytes += generator.feed(1);

      List<String> addressLines = splitAddress(
        "No.72, Salai Bazaar, Ramanathapuram, Tamil Nadu-623501",
      );

      for (int i = 0; i < addressLines.length; i++) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: addressLines[i],
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
        ]);
      }
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: 'Phone: 9500910118',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);
      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'GST: 33AATFB4124B1ZW',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'FSSAI: 12420017000428',
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(2);

      printer.rawBytes(Uint8List.fromList(bytes));

      printer.cut();

      printer.disconnect();
      // Optional: Remove from pending if it was there (in case of retry)
      //final pendingBox = Hive.box<PendingPrintInvoice>('pending_prints');
      // final pendingBox = HiveService().pendingBox;
      // await pendingBox.delete(newInvoiceNumber); // Use the same key!
      developer.log(
        'Print successful for $newInvoiceNumber',
        name: 'PrintReceiptLog',
      );
    } else {
      developer.log('Printer connection failed: $res', name: 'PrintReceiptLog');
      // final pendingBox = Hive.box<PendingPrintInvoice>('pending_prints');
      //  final pendingBox = HiveService().pendingBox;

      //  final printData = {
      //     'employeeNumberController': employeeNumberController,
      //     'customerNumberController': customerNumberController.text,
      //     'discountController': discountController.text,
      //     'customChargeController': customChargeController.text,
      //     'selectedPaymentOptionValue': selectedPaymentOptionValue,
      //     'totalAmount': totalAmount,
      //     'selectedPaymentOption': selectedPaymentOption,
      //     'discountAmount': discountAmount,
      //     'invoiceNo': invoiceNo,
      //     'cashAmount': cashAmount,
      //     'cardAmount': cardAmount,
      //     'upiAmount': upiAmount,
      //     'newInvoiceNumber': newInvoiceNumber,

      //     // CRITICAL: Save cart + settings
      //     'cartItems': cartItems.map((e) => Map<String, dynamic>.from(e)).toList(),
      //     'discountPercentage': discountPercentage,
      //     'customCharge': customCharge,
      //     //'isGSTEnabled': GlobalDataManager().isGSTEnabled, // or your global flag
      //   };

      //   final pendingInvoice = PendingPrintInvoice(
      //     invoiceNo: newInvoiceNumber,
      //     timestamp: DateTime.now(),
      //     printData: printData,
      //   );

      //   await pendingBox.put(newInvoiceNumber, pendingInvoice);

      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text("Printer offline! Bill $newInvoiceNumber saved for reprint."),
      //       backgroundColor: Colors.orange[700],
      //       duration: Duration(seconds: 6),
      //     ),
      //   );

      printer.disconnect();
    }
  }

  Future<img.Image> textWithStrikeImage({
    required String snoText,
    required String itemName,
    required String amountText,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final textStyle = TextStyle(
      color: const ui.Color(0xFF000000),
      fontSize: 24,
    );

    final textPainter1 = TextPainter(
      text: TextSpan(text: "$snoText$itemName", style: textStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
      ellipsis: "...",
    );
    textPainter1.layout(maxWidth: 400);

    final textPainter2 = TextPainter(
      text: TextSpan(text: amountText, style: textStyle),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter2.layout();

    const fixedWidth = 560.0;

    final itemOffset = 0.0;
    final amountOffsetX = fixedWidth - textPainter2.width;

    final totalHeight =
        (textPainter1.height > textPainter2.height
                ? textPainter1.height
                : textPainter2.height)
            .ceil();

    textPainter1.paint(canvas, ui.Offset(itemOffset, 0));
    textPainter2.paint(canvas, ui.Offset(amountOffsetX, 0));

    final linePaint = ui.Paint()
      ..color = const ui.Color(0xFF000000)
      ..strokeWidth = 2;
    final lineY = textPainter2.height / 2;
    canvas.drawLine(
      ui.Offset(amountOffsetX, lineY),
      ui.Offset(amountOffsetX + textPainter2.width, lineY),
      linePaint,
    );

    final picture = recorder.endRecording();
    final imgUi = await picture.toImage(fixedWidth.ceil(), totalHeight);

    final byteData = await imgUi.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final imageObj = img.decodePng(pngBytes)!;

    final background = img.Image(imageObj.width, imageObj.height);
    img.fill(background, img.getColor(255, 255, 255, 255));
    img.copyInto(background, imageObj);

    return background;
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
        lastIndex = maxLineWidth;
      }
      lines.add(remainingText.substring(0, lastIndex).trimRight());
      remainingText = remainingText.substring(lastIndex).trimLeft();
    }

    lines.add(remainingText);

    return lines;
  }
}
// import 'dart:math';
// import 'dart:typed_data';
// import 'package:esc_pos_printer/esc_pos_printer.dart';
// import 'package:esc_pos_utils/esc_pos_utils.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:hive/hive.dart';
// import 'package:image/image.dart' as img;
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'dart:developer' as developer;
// import '../../../data/global_data_manager.dart';
// import '../../printer_screen/provider/printer_config_provider.dart';
// import '../../regular_mode_page/provider/cart_page_provider.dart';
// import '../salesInvoicePayandPrint.dart';
// import 'custom_pos_column.dart';

// class ReceiptPrinter {
//   final String employeeNumberController;
//   final TextEditingController customerNumberController;
//   final TextEditingController discountController;
//   final TextEditingController customChargeController;
//   final String selectedPaymentOptionValue;
//   final double totalAmount;
//   final BuildContext context;
//   final String selectedPaymentOption;
//   final Function saveInvoiceToHiveAndPrint;
//   final double discountAmount;
//   final String invoiceNo;
//   final double cashAmount;
//   final double cardAmount;
//   final double upiAmount;

//   ReceiptPrinter({
//     required this.employeeNumberController,
//     required this.customerNumberController,
//     required this.discountController,
//     required this.customChargeController,
//     required this.selectedPaymentOptionValue,
//     required this.totalAmount,
//     required this.context,
//     required this.selectedPaymentOption,
//     required this.saveInvoiceToHiveAndPrint,
//     required this.discountAmount,
//     required this.invoiceNo,
//     required this.cashAmount,
//     required this.cardAmount,
//     required this.upiAmount,
//   });

//   Future<void> printReceiptDetails() async {
//     String uniqueIdentifier = ''; // Will be set after saving to Hive

//     // Fetch the latest invoice data from Hive after saving
//     await saveInvoiceToHiveAndPrint();
//     var box = await Hive.openBox('invoiceBox');
//     var latestInvoice = box.values
//         .lastWhere((invoice) => invoice is Map<String, dynamic> && invoice['uniqueIdentifier'] != null, orElse: () => {});
//     if (latestInvoice.isEmpty) {
//       developer.log('No invoice data found in Hive', name: 'PrintReceiptLog');
//       return;
//     }
//     uniqueIdentifier = latestInvoice['uniqueIdentifier'];

//     String employeeNumber = latestInvoice['salesPerson'] ?? employeeNumberController;
//     String customerNumber = latestInvoice['customerPhoneNumber'] ?? customerNumberController.text;
//     double totalItemTotal = double.parse(latestInvoice['totalAmount']); // Item total from invoiceData
//     double netAmount = double.parse(latestInvoice['netAmount']);
//     double customCharge = latestInvoice['customCharge']?.toDouble() ?? 0.0;
//     double crossAmount = double.parse(latestInvoice['crossAmount']); // Total including custom charge
//     double cashAmount = latestInvoice['cash']?.toDouble() ?? 0.0;
//     double cardAmount = latestInvoice['card']?.toDouble() ?? 0.0;
//     double upiAmount = latestInvoice['upi']?.toDouble() ?? 0.0;

//     DateTime now = DateTime.now();
//     String formattedDate = DateFormat('dd-MM-yyyy').format(now);
//     String formattedTime = DateFormat('hh:mm a').format(now);
//     String newInvoiceNumber = latestInvoice['invoiceNo'] ?? await InvoiceNumberGenerator().generateInvoiceNumber();

//     var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
//     var cartItems = cartProvider.currentSaleItems;
//     double discountPercentage = cartProvider.discountPercentage;

//     final settings = GlobalDataManager().billReceiptSettings;
//     final printerProvider = Provider.of<PrinterProviderpos>(context, listen: false);
//     String printerIp = printerProvider.getOverallPrinterIp().toString();

//     final profile = await CapabilityProfile.load();
//     final printer = NetworkPrinter(PaperSize.mm80, profile);

//     final PosPrintResult res = await printer.connect("192.168.1.87", port: 9100);
//     bool hasHoldBills = cartProvider.currentSaleItems.any((item) => item['status'] == 'hold');

//     if (hasHoldBills) {
//       developer.log('Yes, there are hold bills in the cart.', name: 'PrintReceiptLog');
//     } else {
//       developer.log('No hold bills found in the cart.', name: 'PrintReceiptLog');
//     }

//     if (res == PosPrintResult.success) {
//       List<int> bytes = [];
//       final generator = Generator(PaperSize.mm80, profile);

//       bytes += generator.row([
//         createPosColumn(
//             width: 12,
//             text: '',
//             styles: createPosStyles(
//               align: PosAlign.center,
//               height: PosTextSize.size6,
//               width: PosTextSize.size6,
//               codeTable: 'CP1252',
//             )),
//       ]);
//       bytes += generator.row([
//         createPosColumn(
//             width: 12,
//             text: 'BestMummy',
//             styles: createPosStyles(
//               align: PosAlign.center,
//               height: PosTextSize.size1,
//               width: PosTextSize.size1,
//               codeTable: 'CP1252',
//             )),
//       ]);
//       bytes += generator.row([
//         createPosColumn(
//             width: 12,
//             text: 'Sweets & Cakes',
//             styles: createPosStyles(
//               align: PosAlign.center,
//               height: PosTextSize.size1,
//               width: PosTextSize.size1,
//               codeTable: 'CP1252',
//             )),
//       ]);
//       bytes += generator.feed(1);
//       bytes += generator.feed(1);
//       bytes += generator.row([
//         createPosColumn(
//             width: 12,
//             text: 'Sales Invoice',
//             styles: createPosStyles(
//               align: PosAlign.center,
//               codeTable: 'CP1252',
//               height: PosTextSize.size1,
//               width: PosTextSize.size1,
//             )),
//       ]);
//       bytes += generator.feed(1);
//       bytes += generator.row([
//         createPosColumn(
//             width: 6, text: 'Date: $formattedDate', styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         createPosColumn(
//             width: 6, text: 'Time: $formattedTime', styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);
//       bytes += generator.row([
//         createPosColumn(width: 5, text: 'Branch:Aranmanai', styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         createPosColumn(
//             width: 7, text: 'BillNo:$newInvoiceNumber', styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);
//       bytes += generator.row([
//         createPosColumn(
//             width: 6, text: 'Sales Person: $employeeNumber', styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         createPosColumn(
//             width: 6, text: 'Customer No: $customerNumber', styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);
//       bytes += generator.hr();
//       bytes += generator.row([
//         createPosColumn(width: 1, text: 'S.No', styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         createPosColumn(width: 5, text: 'ITEM', styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//         createPosColumn(width: 2, text: '', styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         createPosColumn(width: 1, text: '', styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         createPosColumn(width: 3, text: 'AMOUNT', styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.hr();
//       bytes += generator.feed(1);

//       double originalSubTotal = 0.0;
//       Map<double, double> itemTotalsMap = {};
//       for (var item in cartItems) {
//         double itemTotal = cartProvider.calculateItemTotal(item).toDouble();
//         double taxRate = (item['itemData']['tax'] as num).toDouble();
//         originalSubTotal += itemTotal;
//         itemTotalsMap[taxRate] = (itemTotalsMap[taxRate] ?? 0.0) + itemTotal;
//       }

//       for (int i = 0; i < cartItems.length; i++) {
//         final item = cartItems[i];
//         final String itemName = item['itemData']['itemName'] ?? 'N/A';
//         final String varianceName = item['varianceData']['varianceName'] ?? 'N/A';
//         final double price = item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0;
//         final double weight = (item['weight'] ?? 0.0).toDouble();
//         final double qty = (item['quantity'] as num).toDouble();
//         final double orig_amount = cartProvider.calculateItemTotal(item);
//         final double tax = (item['itemData']['tax'] as num).toDouble();
//         final String uom = item['varianceData']['variance_Uom'] ?? 'N/A';
//         String quantityDisplay = cartProvider.buildQuantityPriceDisplay(item);

//         double item_discount_amt = orig_amount * (discountPercentage / 100);
//         double item_disc_amount = orig_amount - item_discount_amt;

//         List<String> itemNameLines = splitText(varianceName, 15);

//         bytes += generator.row([
//           createPosColumn(width: 1, text: (i + 1).toString(), styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           createPosColumn(width: 8, text: itemNameLines[0], styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           createPosColumn(width: 3, text: "", styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);

//         if (itemNameLines.length > 1) {
//           for (int j = 1; j < itemNameLines.length; j++) {
//             bytes += generator.row([
//               createPosColumn(width: 1, text: '', styles: createPosStyles(align: PosAlign.left)),
//               createPosColumn(
//                   width: 8, text: itemNameLines[j], styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//               createPosColumn(width: 3, text: '', styles: createPosStyles(align: PosAlign.right)),
//             ]);
//           }
//         }

//         String amountStr =
//             discountPercentage > 0 ? "Rs ${orig_amount.toStringAsFixed(2)}" : "Rs ${orig_amount.toStringAsFixed(2)}";

//         if (discountPercentage > 0) {
//           bytes += generator.row([
//             createPosColumn(width: 1, text: '', styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//             createPosColumn(width: 8, text: '', styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//             createPosColumn(width: 3, text: '----------', styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//           ]);
//         }

//         bytes += generator.row([
//           createPosColumn(width: 1, text: '', styles: createPosStyles(align: PosAlign.left)),
//           createPosColumn(
//               width: 8,
//               text:
//                   "(${item['quantity']} ${item['varianceData']['variance_Uom']} x ${item['varianceData']['variance_Defaultprice']} tax ${item['itemData']['tax']}%)",
//               styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           createPosColumn(width: 3, text: amountStr, styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);

//         if (discountPercentage > 0) {
//           bytes += generator.row([
//             createPosColumn(width: 1, text: '', styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//             createPosColumn(
//                 width: 8,
//                 text: "Discount Amount(-) : Rs ${item_discount_amt.toStringAsFixed(2)}",
//                 styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//             createPosColumn(
//                 width: 3,
//                 text: "Rs ${item_disc_amount.toStringAsFixed(2)}",
//                 styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//           ]);
//         }

//         bytes += generator.row([
//           createPosColumn(width: 12, text: '', styles: createPosStyles(align: PosAlign.center)),
//         ]);
//       }

//       bytes += generator.hr();

//       bytes += generator.row([
//         createPosColumn(width: 6, text: 'Sub Total', styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         createPosColumn(
//             width: 6,
//             text: 'Rs ${totalItemTotal.toStringAsFixed(2)}',
//             styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);

//       if (discountPercentage > 0) {
//         double discountAmount = (totalItemTotal * (discountPercentage / 100)).toDouble();
//         bytes += generator.row([
//           createPosColumn(
//               width: 6,
//               text: 'Discount (${discountPercentage}%)',
//               styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           createPosColumn(
//               width: 6,
//               text: '- Rs ${discountAmount.toStringAsFixed(2)}',
//               styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);
//       }

//       bytes += generator.row([
//         createPosColumn(
//           width: 12,
//           text: 'Item Total Rs ${totalItemTotal.toStringAsFixed(2)}',
//           styles: PosStyles(
//             align: PosAlign.right,
//             codeTable: 'CP1252',
//             width: PosTextSize.size1,
//           ),
//         ),
//       ]);

//       bytes += generator.hr();

//       if (customCharge > 0) {
//         bytes += generator.row([
//           createPosColumn(width: 6, text: 'Custom Charge', styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           createPosColumn(
//               width: 6,
//               text: 'Rs ${customCharge.toStringAsFixed(2)}',
//               styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);
//       }

//       bytes += generator.row([
//         createPosColumn(
//           width: 12,
//           text: 'TOTAL Rs ${crossAmount.toStringAsFixed(2)}',
//           styles: PosStyles(
//             align: PosAlign.right,
//             codeTable: 'CP1252',
//             width: PosTextSize.size2,
//           ),
//         ),
//       ]);

//       bytes += generator.hr();

//       bytes += generator.row([
//         createPosColumn(
//           width: 12,
//           text: "Payment Details",
//           styles: PosStyles(
//             bold: true,
//             codeTable: 'CP1252',
//             align: PosAlign.left,
//           ),
//         ),
//       ]);
//       bytes += generator.feed(1);

//       if (cashAmount > 0) {
//         bytes += generator.row([
//           createPosColumn(width: 5, text: "Cash", styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           createPosColumn(width: 2, text: ":", styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//           createPosColumn(
//               width: 5,
//               text: "Rs ${cashAmount.toStringAsFixed(2)}",
//               styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);
//       }
//       if (cardAmount > 0) {
//         bytes += generator.row([
//           createPosColumn(width: 5, text: "Card", styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           createPosColumn(width: 2, text: ":", styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//           createPosColumn(
//               width: 5,
//               text: "Rs ${cardAmount.toStringAsFixed(2)}",
//               styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);
//       }
//       if (upiAmount > 0) {
//         bytes += generator.row([
//           createPosColumn(width: 5, text: "Upi", styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           createPosColumn(width: 2, text: ":", styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//           createPosColumn(
//               width: 5,
//               text: "Rs ${upiAmount.toStringAsFixed(2)}",
//               styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);
//       }

//       double receivedAmount = cashAmount + cardAmount + upiAmount;
//       double changeAmount = receivedAmount - crossAmount;

//       bytes += generator.row([
//         createPosColumn(width: 5, text: "Receive Amt", styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         createPosColumn(width: 2, text: ":", styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//         createPosColumn(
//             width: 5,
//             text: "Rs ${receivedAmount.toStringAsFixed(2)}",
//             styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.row([
//         createPosColumn(width: 5, text: "Balance Amt", styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         createPosColumn(width: 2, text: ":", styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//         createPosColumn(
//             width: 5,
//             text: "Rs ${changeAmount.toStringAsFixed(2)}",
//             styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.hr();

//       bytes += generator.row([
//         createPosColumn(
//           width: 12,
//           text: "Tax Details",
//           styles: PosStyles(
//             bold: true,
//             codeTable: 'CP1252',
//             align: PosAlign.left,
//           ),
//         ),
//       ]);
//       bytes += generator.feed(1);
//       bytes += generator.row([
//         createPosColumn(width: 5, text: "Net Amt", styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         createPosColumn(width: 2, text: ":", styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//         createPosColumn(
//             width: 5,
//             text: "${netAmount.toStringAsFixed(2)}",
//             styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);

//       Map<double, double> cgstMap = {};
//       Map<double, double> sgstMap = {};
//       Map<double, double> netMap = {};

//       itemTotalsMap.forEach((taxRate, grossWithTax) {
//         double proportion = grossWithTax / totalItemTotal;
//         double discountedGrossForRate = grossWithTax - (discountAmount * proportion);
//         double netForRate = discountedGrossForRate / (1 + (taxRate / 100));
//         double taxForRate = discountedGrossForRate - netForRate;
//         double cgstForRate = taxForRate / 2;
//         double sgstForRate = taxForRate / 2;

//         cgstMap[taxRate] = cgstForRate;
//         sgstMap[taxRate] = sgstForRate;
//         netMap[taxRate] = netForRate;
//       });

//       sgstMap.forEach((rate, sgstAmount) {
//         double cgstAmount = cgstMap[rate] ?? 0.0;
//         final gst = cgstAmount + sgstAmount;
//         bytes += generator.row([
//           createPosColumn(
//             text:
//                 "GST($rate%)-${gst.toStringAsFixed(2)} SGST(${(rate / 2).toStringAsFixed(1)}%)${sgstAmount.toStringAsFixed(2)} CGST(${(rate / 2).toStringAsFixed(1)}%)${cgstAmount.toStringAsFixed(2)}",
//             width: 12,
//             styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
//           ),
//         ]);
//       });

//       bytes += generator.row([
//         createPosColumn(
//             width: 12,
//             text: '----------------------------------------------',
//             styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.row([
//         createPosColumn(
//             width: 12, text: 'Thank You ! Visit Again !', styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       List<String> addressLines = splitAddress("No.72, Salai Bazaar, Ramanathapuram, Tamil Nadu-623501");
//       for (int i = 0; i < addressLines.length; i++) {
//         bytes += generator.row([
//           createPosColumn(
//             width: 12,
//             text: addressLines[i],
//             styles: createPosStyles(
//               align: PosAlign.center,
//               codeTable: 'CP1252',
//             ),
//           ),
//         ]);
//       }
//       bytes += generator.row([
//         createPosColumn(
//             width: 12, text: 'Phone: 9500910118', styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.row([
//         createPosColumn(
//           width: 6,
//           text: 'GST: 33AATFB4124B1ZW',
//           styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
//         ),
//         createPosColumn(
//           width: 6,
//           text: 'FSSAI: 12420017000428',
//           styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
//         ),
//       ]);

//       bytes += generator.feed(1);

//       printer.rawBytes(Uint8List.fromList(bytes));
//       printer.cut();
//       printer.disconnect();
//     } else {
//       developer.log('Printer connection failed', name: 'PrintReceiptLog');
//     }

//     Navigator.of(context).pop();
//     cartProvider.clearItems();
//   }

//   List<String> splitAddress(String address) {
//     const int maxLineWidth = 18;
//     List<String> lines = [];
//     String remainingAddress = address;

//     while (remainingAddress.length > maxLineWidth) {
//       int lastIndex = remainingAddress.lastIndexOf(' ', maxLineWidth);
//       if (lastIndex == -1) {
//         lastIndex = maxLineWidth;
//       }
//       lines.add(remainingAddress.substring(0, lastIndex).trimRight());
//       remainingAddress = remainingAddress.substring(lastIndex).trimLeft();
//     }

//     lines.add(remainingAddress);

//     return lines;
//   }

//   List<String> splitText(String text, int maxLineWidth) {
//     List<String> lines = [];
//     String remainingText = text;

//     while (remainingText.length > maxLineWidth) {
//       int lastIndex = remainingText.lastIndexOf(' ', maxLineWidth);
//       if (lastIndex == -1) {
//         lastIndex = maxLineWidth;
//       }
//       lines.add(remainingText.substring(0, lastIndex).trimRight());
//       remainingText = remainingText.substring(lastIndex).trimLeft();
//     }

//     lines.add(remainingText);

//     return lines;
//   }

//   String generateShortHiveInvoiceId() {
//     final random = Random();
//     final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
//     const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123454549';
//     final randomId = List<int>.generate(6, (_) => random.nextInt(characters.length)).map((index) => characters[index]).join();
//     return '$timestamp-$randomId';
//   }
// }


  // try {
      //   final box = Hive.box('logo');
      //   final Uint8List? imageBytes = box.get('BMlogo_bytes');
      //   final String? logoName = box.get('BMlogo_name');
      //   final String? logoPath = box.get('BMlogo_path');

      //   if (imageBytes != null) {
      //     print("✅ Loaded logo from Hive ($logoName) | Size: ${imageBytes.lengthInBytes} bytes");
      //     final img.Image? logo = img.decodeImage(imageBytes);

      //     if (logo != null) {
      //       print("🖼 Original Logo: ${logo.width}x${logo.height}");
      //       final img.Image whiteBg = img.Image(logo.width, logo.height);
      //       img.fill(whiteBg, img.getColor(255, 255, 255));
      //       img.copyInto(whiteBg, logo, blend: true);

      //       final img.Image gray = img.grayscale(whiteBg);
      //       img.Image binaryThreshold(img.Image src, int threshold) {
      //         final out = img.Image.from(src);
      //         for (int y = 0; y < out.height; y++) {
      //           for (int x = 0; x < out.width; x++) {
      //             final int p = out.getPixel(x, y);
      //             final int r = img.getRed(p);
      //             final int g = img.getGreen(p);
      //             final int b = img.getBlue(p);
      //             final int lum = ((r * 299 + g * 587 + b * 114) ~/ 1000);
      //             if (lum < threshold) {
      //               out.setPixelRgba(x, y, 0, 0, 0, 255);
      //             } else {
      //               out.setPixelRgba(x, y, 255, 255, 255, 255);
      //             }
      //           }
      //         }
      //         return out;
      //       }

      //       final img.Image thresholded = binaryThreshold(gray, 180);
      //       final img.Image resized = img.copyResize(thresholded, width: 250);
      //       final int remainder = resized.height % 8;
      //       img.Image aligned = resized;
      //       if (remainder != 0) {
      //         final int newHeight = resized.height + (8 - remainder);
      //         aligned = img.Image(resized.width, newHeight);
      //         img.fill(aligned, img.getColor(255, 255, 255));
      //         img.copyInto(aligned, resized, dstY: 0);
      //       }

      //       bytes += generator.image(aligned, align: PosAlign.center);
      //       print("🖨 Sent logo image to printer");
      //     }
      //   } else {
      //     print("⚠️ Logo not found in Hive!");
      //   }
      // } catch (e, st) {
      //   print('🛑 Logo Print Error: $e');
      //   print(st);
      // }
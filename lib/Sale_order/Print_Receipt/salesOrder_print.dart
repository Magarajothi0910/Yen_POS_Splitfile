import 'dart:math';
import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// import '../../../data/global_data_manager.dart';
// import '../../printer_screen/provider/printer_config_provider.dart';
// import '../../regular_mode_page/provider/cart_page_provider.dart';

import 'package:image/image.dart' as img;
import 'package:yenpos/Global/Widget/customposcolumn.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/printer_screen/provider/printer_config_provider.dart';

class salesOrderReceiptPrinter {
  final TextEditingController employeeNameController;
  final TextEditingController customerNumberController;
  double discountController;
  double discountAmountController;

  String deliveryDateprint;
  String deliveryTimeprint;
  String saleOrderNo;
  List<String>? advanceDateTime; // ✅ fixed
  double customChargeController;
  String selectedPaymentOptionValue;
  String chargeType;

  double totalAmount;
  double totalAmount2;
  double finalPrice;
  double discountAmount;

  List<double> advanceAmount;
  double balanceAmount;
  String customerType;
  String editAbout;
  // Inject PrinterProvider directly
  final PrinterProviderpos printerProvider;
  // final BuildContext context;
  final TextEditingController customAmountController;
  List<List<String>>? selectedPaymentOption;
  List<List<String>>? selectedPaymentOptionAmount;

  // final Function saveInvoiceToHiveAndPrint;
  salesOrderReceiptPrinter({
    required this.employeeNameController,
    required this.customerNumberController,
    required this.discountController,
    required this.deliveryDateprint,
    required this.discountAmountController,
    required this.deliveryTimeprint,
    required this.customChargeController,
    required this.chargeType,

    required this.totalAmount2,
    required this.finalPrice,
    required this.discountAmount,
    required this.advanceDateTime,
    required this.selectedPaymentOptionValue,
    required this.totalAmount,
    required this.advanceAmount,
    required this.saleOrderNo,
    required this.balanceAmount,
    required this.editAbout,
    required this.printerProvider, // ✅ inject dependency
    // required this.context,
    required this.customerType,
    required this.customAmountController,
    required this.selectedPaymentOption,
    required this.selectedPaymentOptionAmount,

    // required this.saveInvoiceToHiveAndPrint,
  });

  Future<void> patchprintReceiptDetails() async {
    String employeeName = employeeNameController.text;
    String customerNumber = customerNumberController.text;
    String paymentAmount;
    String salesOrderNumber = saleOrderNo;
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

    // Decide payment amount
    if (selectedPaymentOption == 'Cash: Custom' &&
        customAmountController.text.isNotEmpty) {
      paymentAmount = 'Rs ${customAmountController.text}';
    } else if (selectedPaymentOption!.contains(':')) {
      paymentAmount = 'Rs ${selectedPaymentOption!}';
    } else {
      paymentAmount = 'Rs ${totalAmount.toStringAsFixed(0)}';
    }
    // 🔹 Dynamically decide the receipt header based on editAbout
    String receiptTitle;

    switch (editAbout.trim().toLowerCase()) {
      case 'add advance':
        receiptTitle = 'Advance Added Receipt';
        break;
      case 'edit order':
        receiptTitle = 'Order Edited Receipt';
        break;
      case 'cancel order':
        receiptTitle = 'Order Cancelled Receipt';
        break;
      default:
        receiptTitle = 'Order Receipt';
    }
    String fullEmployeeName = employeeNameController.text.trim();
    String employeeDisplayName = fullEmployeeName.contains('-')
        ? fullEmployeeName.split('-').last.trim()
        : fullEmployeeName;
    var cartItems = globals.cartItems ?? [];
    // Convert delivery date to dd-MM-yyyy
    String formattedDeliveryDate = "";
    try {
      if (deliveryDateprint != null && deliveryDateprint.isNotEmpty) {
        DateTime d = DateTime.parse(deliveryDateprint);
        formattedDeliveryDate = DateFormat('dd-MM-yyyy').format(d);
      }
    } catch (e) {
      formattedDeliveryDate = deliveryDateprint; // fallback
    }

    // Step 5: Get printer IP directly from injected provider
    String printerIp = printerProvider.getOverallPrinterIp().toString();

    print("sale order patch print : $printerIp");
    final profile = await CapabilityProfile.load();

    final printer = NetworkPrinter(PaperSize.mm80, profile);

    // Connect to printer
    final PosPrintResult res = await printer.connect(printerIp, port: 9100);
    if (res == PosPrintResult.success) {
      List<int> bytes;
      final generator = Generator(PaperSize.mm80, profile);

      bytes = []; // Reset bytes for each copy
      bytes = []; // Reset bytes for each copy
      try {
        final box = Hive.box('logo');
        final Uint8List? imageBytes = box.get('BMlogo_bytes');
        final String? logoName = box.get('BMlogo_name');

        if (imageBytes != null) {
          final img.Image? logo = img.decodeImage(imageBytes);

          if (logo != null) {
            final img.Image whiteBg = img.Image(logo.width, logo.height);
            img.fill(whiteBg, img.getColor(255, 255, 255));
            img.copyInto(whiteBg, logo, blend: true);

            final img.Image gray = img.grayscale(whiteBg);
            img.Image binaryThreshold(img.Image src, int threshold) {
              final out = img.Image.from(src);
              for (int y = 0; y < out.height; y++) {
                for (int x = 0; x < out.width; x++) {
                  final int p = out.getPixel(x, y);
                  final int r = img.getRed(p);
                  final int g = img.getGreen(p);
                  final int b = img.getBlue(p);
                  final int lum = ((r * 299 + g * 587 + b * 114) ~/ 1000);
                  if (lum < threshold) {
                    out.setPixelRgba(x, y, 0, 0, 0, 255);
                  } else {
                    out.setPixelRgba(x, y, 255, 255, 255, 255);
                  }
                }
              }
              return out;
            }

            final img.Image thresholded = binaryThreshold(gray, 180);
            final img.Image resized = img.copyResize(thresholded, width: 250);
            final int remainder = resized.height % 8;
            img.Image aligned = resized;
            if (remainder != 0) {
              final int newHeight = resized.height + (8 - remainder);
              aligned = img.Image(resized.width, newHeight);
              img.fill(aligned, img.getColor(255, 255, 255));
              img.copyInto(aligned, resized, dstY: 0);
            }

            bytes += generator.image(aligned, align: PosAlign.center);
          }
        } else {}
      } catch (e, st) {}

      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: receiptTitle,
          styles: createPosStyles(
            align: PosAlign.center,
            codeTable: 'CP1252',
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true,
          ),
        ),
      ]);
      bytes += generator.feed(1);
      // Sale Order Number (just below, bold)
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: "Order No: $salesOrderNumber",
          styles: createPosStyles(
            align: PosAlign.center,
            codeTable: 'CP1252',
            height: PosTextSize.size1, // bigger for emphasis
            width: PosTextSize.size2,
            bold: true,
          ),
        ),
      ]);
      bytes += generator.feed(1);

      // Add formatted date and time
      bytes += generator.row([
        createPosColumn(width: 5, text: 'Date: $formattedDate'),
        createPosColumn(
          width: 7,
          text: 'Delivery Date: $formattedDeliveryDate',
          styles: createPosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.feed(1);
      bytes += generator.row([
        createPosColumn(width: 4, text: 'Time: $formattedTime'),
        createPosColumn(
          width: 8,
          text: 'Delivery Time: $deliveryTimeprint',
          styles: createPosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.feed(1);

      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'Branch : ${globals.branchName}',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'Customer No: $customerNumber',
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);

      // Print Sales Person and Customer Number on the same line
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: 'SalesPerson : $employeeDisplayName',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: '==============================================',
          styles: createPosStyles(align: PosAlign.center),
        ),
      ]);

      /// COLUMN HEADERS (Classic Box)
      bytes += generator.row([
        createPosColumn(width: 1, text: 'No'),
        createPosColumn(width: 7, text: 'Item'),
        createPosColumn(
          width: 2,
          text: 'Tax',
          styles: createPosStyles(align: PosAlign.center),
        ),
        createPosColumn(
          width: 2,
          text: 'Amt',
          styles: createPosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: '----------------------------------------------',
        ),
      ]);
      bytes += generator.feed(1);

      double taxVaule = 0.0;
      Map<double, double> sgstMap = {};
      Map<double, double> cgstMap = {};

      // Process each item
      for (var item in cartItems) {
        // Assuming tax is fetched as dynamic or int, ensure it's treated as double
        double taxRate = (item.tax as num)
            .toDouble(); // num can be both int and double
        double itemTotal = calculateSubtotal();
        //     .toDouble(); // Ensure itemTotal is a double

        double itemTax = itemTotal * (taxRate / 100);
        double itemSGST = itemTax / 2;
        double itemCGST = itemSGST;

        // Update the maps with doubles
        sgstMap[taxRate / 2] = (sgstMap[taxRate / 2] ?? 0.0) + itemSGST;
        cgstMap[taxRate / 2] = (cgstMap[taxRate / 2] ?? 0.0) + itemCGST;
      }
      for (int i = 0; i < cartItems.length; i++) {
        final item = cartItems[i];

        final double amount = item.uom == 'Kgs'
            ? (item.weight * item.quantity.value * item.pricePerKg).toDouble()
            : (item.quantity.value * item.pricePerKg).toDouble();
        final discountedAmount = amount - (item.itemWiseDiscountAmount ?? 0);
        double taxPercentage = (item.tax as num).toDouble();
        taxVaule = taxPercentage;
        String priceDescription = '';
        if (item.uom.toLowerCase() == 'kgs' || item.uom.toLowerCase() == 'kg') {
          // Weight-based pricing → show both quantity and weight
          priceDescription = item.weight >= 1
              ? '${item.quantity.value} ${item.uom} (${item.weight.toStringAsFixed(2)} kg) × Rs ${item.pricePerKg.toStringAsFixed(0)}/kg'
              : '${item.quantity.value} × (${(item.weight * 1000).toStringAsFixed(0)} g) × Rs ${item.pricePerKg.toStringAsFixed(0)}/kg';
        } else {
          // Pcs / Pkt or others
          priceDescription =
              '${item.quantity.value.toStringAsFixed(0)} ${item.uom} × Rs ${item.pricePerKg.toStringAsFixed(0)}';
        }
        bytes += generator.row([
          createPosColumn(
            width: 1,
            text: (i + 1).toString(),
            styles: createPosStyles(align: PosAlign.left),
          ),
          createPosColumn(
            width: 7,
            text: item.varianceName,
            styles: createPosStyles(align: PosAlign.left),
          ),
          createPosColumn(
            width: 1,
            text: '${item.tax}',
            styles: createPosStyles(align: PosAlign.center),
          ),

          createPosColumn(
            width: 3,
            text: (item.itemWiseDiscount > 0 || item.itemWiseDiscountAmount > 0)
                ? "" // hide amount if discount applied
                : amount.toStringAsFixed(2),
            styles: createPosStyles(align: PosAlign.right, bold: true),
          ),
        ]);

        // ---------------- Amount (strike-through if discount exists) ----------------
        if ((item.itemWiseDiscount ?? 0) > 0 ||
            (item.itemWiseDiscountAmount ?? 0) > 0) {
          // Strike-through original amount image
          final imgBytes = await textWithStrikeImage(
            snoText: '         ',
            itemName: priceDescription,
            amountText: amount.toStringAsFixed(2),
          );
          bytes += generator.image(imgBytes, align: PosAlign.left);
        } else {
          // No discount → just print normally
          bytes += generator.row([
            createPosColumn(width: 1, text: '', styles: createPosStyles()),
            createPosColumn(
              width: 8,
              text: priceDescription,
              styles: createPosStyles(align: PosAlign.left),
            ),
            createPosColumn(
              width: 3,
              text: "",
              styles: createPosStyles(align: PosAlign.right, bold: true),
            ),
          ]);
        }

        if (item.itemWiseDiscount > 0 || item.itemWiseDiscountAmount > 0) {
          bytes += generator.row([
            createPosColumn(
              width: 1,
              text: '',
              styles: createPosStyles(align: PosAlign.left),
            ),
            createPosColumn(
              width: 8,
              text:
                  "Discount Amount(-): Rs ${(item.itemWiseDiscountAmount).toStringAsFixed(0)}",
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              width: 3,
              text: discountedAmount.toStringAsFixed(2),
              styles: createPosStyles(align: PosAlign.right, bold: true),
            ),
          ]);
        }

        // ---------------- Empty row for spacing ----------------
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
          text: '==============================================',
          styles: createPosStyles(align: PosAlign.center),
        ),
      ]);
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: "Total: Rs ${totalAmount.toStringAsFixed(0)}",
          styles: createPosStyles(align: PosAlign.right),
        ),
      ]);

      // --- CUSTOM CHARGE (if any) ---
      if ((customChargeController ?? 0.0) != 0.0) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text:
                "Custom Charge (+): Rs ${customChargeController.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right),
          ),
        ]);

        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Total Amount: Rs ${totalAmount2.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right, bold: true),
          ),
        ]);
      }

      // --- DISCOUNT (if any) ---
      if ((discountController ?? 0) != 0) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text:
                "Discount (${discountController}%) (-): Rs ${discountAmount.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right),
          ),
        ]);

        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Order Amount: Rs ${finalPrice.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right, bold: true),
          ),
        ]);
      }
      // Print Custom Charge

      // 🔹 Advance Amount with Date & Time (Left) and Amount (Right)
      if (advanceAmount.isNotEmpty &&
          advanceDateTime != null &&
          advanceDateTime!.isNotEmpty) {
        for (int i = 0; i < advanceAmount.length; i++) {
          double advAmt = advanceAmount[i];
          String advDateTimeStr = (i < advanceDateTime!.length)
              ? advanceDateTime![i]
              : "";

          String advPaymentType = "";
          if (selectedPaymentOption != null &&
              selectedPaymentOption!.isNotEmpty &&
              i < selectedPaymentOption!.length) {
            advPaymentType = selectedPaymentOption![i].join(", ");
          }

          // Format date & time
          String formattedAdvDate = "";
          String formattedAdvTime = "";
          try {
            DateTime parsedDate = DateTime.parse(advDateTimeStr);
            formattedAdvDate = DateFormat("dd-MM-yyyy").format(parsedDate);
            formattedAdvTime = DateFormat("hh:mm a").format(parsedDate);
          } catch (e) {
            formattedAdvDate = advDateTimeStr;
          }

          // 🔹 Line 1: Date - Time (Left)  |  Advance n: Rs.xxx (Right)
          bytes += generator.row([
            createPosColumn(
              width: 6,
              text: "$formattedAdvDate - $formattedAdvTime",
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              width: 6,
              text: "Advance ${i + 1}: Rs.${advAmt.toStringAsFixed(0)}",
              styles: createPosStyles(
                align: PosAlign.right,
                codeTable: 'CP1252',
              ),
            ),
          ]);
        }
      }
      // 🔹 Balance Amount print
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: "Balance Amount : Rs ${balanceAmount.toStringAsFixed(0)}",
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

      // 🔹 Advance Amount with Date & Time (Left) and Amount (Right)
      if (advanceAmount.isNotEmpty &&
          advanceDateTime != null &&
          advanceDateTime!.isNotEmpty) {
        for (int i = 0; i < advanceAmount.length; i++) {
          double advAmt = advanceAmount[i];
          String advDateTimeStr = (i < advanceDateTime!.length)
              ? advanceDateTime![i]
              : "";

          String advPaymentType = "";
          if (selectedPaymentOption != null &&
              selectedPaymentOption!.isNotEmpty &&
              i < selectedPaymentOption!.length) {
            advPaymentType = selectedPaymentOption![i].join(", ");
          }

          // Format date & time
          String formattedAdvDate = "";
          String formattedAdvTime = "";
          try {
            DateTime parsedDate = DateTime.parse(advDateTimeStr);
            formattedAdvDate = DateFormat("dd-MM-yyyy").format(parsedDate);
            formattedAdvTime = DateFormat("hh:mm a").format(parsedDate);
          } catch (e) {
            formattedAdvDate = advDateTimeStr;
          }

          // 🔹 Line 2: Payment type (if available)
          if (advPaymentType.isNotEmpty) {
            bytes += generator.row([
              createPosColumn(
                width: 12,
                text: "Advance Payment (${i + 1}): $advPaymentType",
                styles: createPosStyles(
                  align: PosAlign.left,
                  codeTable: 'CP1252',
                ),
              ),
            ]);
          }
        }
      }
      // Inside _printReceiptDetails function
      bytes += generator.feed(1);

      List<String> addressLines = splitAddress(globals.branchAddress);

      // Print address lines
      for (var line in addressLines) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: line,
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
        ]);
      }

      // Print phone number
      if (globals.branchPhoneno.isNotEmpty) {
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: 'Phone : ${globals.branchPhoneno}',
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
        ]);
      }

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
      bytes += generator.feed(1);
      // Final footer message
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: "Thank You! Visit Again",
          styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
        ),
      ]);

      bytes += generator.feed(1);
      bytes += generator.qrcode(
        salesOrderNumber, // Data for QR
        size: QRSize.Size4, // Adjust size from Size1 to Size8
        align: PosAlign.center,
      );
      bytes += generator.feed(1);
      bytes += generator.cut();
      printer.rawBytes(
        Uint8List.fromList(bytes),
      ); // Send the bytes to the printer

      printer.disconnect();
    } else {}
    // Navigator.of(context).pop();
    // cartProvider.clearCart();
  }

  Future<void> printReceiptDetails() async {
    String employeeName = employeeNameController.text;
    String customerNumber = customerNumberController.text;
    String paymentAmount;
    String salesOrderNumber = saleOrderNo;
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

    // Decide payment amount
    if (selectedPaymentOption == 'Cash: Custom' &&
        customAmountController.text.isNotEmpty) {
      paymentAmount = 'Rs ${customAmountController.text}';
    } else if (selectedPaymentOption!.contains(':')) {
      paymentAmount = 'Rs ${selectedPaymentOption!}';
    } else {
      paymentAmount = 'Rs ${totalAmount.toStringAsFixed(0)}';
    }

    var cartItems = globals.cartItems;
    // Example: Before calling printReceiptDetails()
    await printerProvider.initializeHive(); // Make sure Hive is loaded
    // **Fetch printer IP from Hive directly**
    String? printerIp = printerProvider.getPrinterIpFromHive(type: 'Overall');
    final profile = await CapabilityProfile.load();

    final printer = NetworkPrinter(PaperSize.mm80, profile);
    print("sale order post print : $printerIp");

    // Connect to printer
    final PosPrintResult res = await printer.connect(printerIp!, port: 9100);
    if (res == PosPrintResult.success) {
      print('[ERROR] Failed to connect to printer.');

      List<int> bytes;
      final generator = Generator(PaperSize.mm80, profile);
      // Extract only the salesperson’s name (remove any code before " - ")
      String fullEmployeeName = employeeNameController.text.trim();
      String employeeDisplayName = fullEmployeeName.contains('-')
          ? fullEmployeeName.split('-').last.trim()
          : fullEmployeeName;
      String formattedDeliveryDate = "";
      try {
        if (deliveryDateprint != null && deliveryDateprint.isNotEmpty) {
          DateTime d = DateTime.parse(deliveryDateprint);
          formattedDeliveryDate = DateFormat('dd-MM-yyyy').format(d);
        }
      } catch (e) {
        formattedDeliveryDate = deliveryDateprint; // fallback
      }
      for (int copy = 0; copy < 2; copy++) {
        bytes = []; // Reset bytes for each copy
        try {
          final box = Hive.box('logo');
          final Uint8List? imageBytes = box.get('BMlogo_bytes');
          final String? logoName = box.get('BMlogo_name');

          if (imageBytes != null) {
            final img.Image? logo = img.decodeImage(imageBytes);

            if (logo != null) {
              final img.Image whiteBg = img.Image(logo.width, logo.height);
              img.fill(whiteBg, img.getColor(255, 255, 255));
              img.copyInto(whiteBg, logo, blend: true);

              final img.Image gray = img.grayscale(whiteBg);
              img.Image binaryThreshold(img.Image src, int threshold) {
                final out = img.Image.from(src);
                for (int y = 0; y < out.height; y++) {
                  for (int x = 0; x < out.width; x++) {
                    final int p = out.getPixel(x, y);
                    final int r = img.getRed(p);
                    final int g = img.getGreen(p);
                    final int b = img.getBlue(p);
                    final int lum = ((r * 299 + g * 587 + b * 114) ~/ 1000);
                    if (lum < threshold) {
                      out.setPixelRgba(x, y, 0, 0, 0, 255);
                    } else {
                      out.setPixelRgba(x, y, 255, 255, 255, 255);
                    }
                  }
                }
                return out;
              }

              final img.Image thresholded = binaryThreshold(gray, 180);
              final img.Image resized = img.copyResize(thresholded, width: 250);
              final int remainder = resized.height % 8;
              img.Image aligned = resized;
              if (remainder != 0) {
                final int newHeight = resized.height + (8 - remainder);
                aligned = img.Image(resized.width, newHeight);
                img.fill(aligned, img.getColor(255, 255, 255));
                img.copyInto(aligned, resized, dstY: 0);
              }

              bytes += generator.image(aligned, align: PosAlign.center);
            }
          } else {}
        } catch (e, st) {}

        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: (copy == 0 ? 'SALES ORDER RECEIPT' : 'SALES ORDER RECEIPT'),
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          ),
        ]);
        bytes += generator.feed(1);

        // Sale Order Number (just below, bold)
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Order No: $salesOrderNumber",
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
              height: PosTextSize.size1, // bigger for emphasis
              width: PosTextSize.size2,
              bold: true,
            ),
          ),
        ]);
        bytes += generator.feed(1);

        /// DATE & DELIVERY
        bytes += generator.row([
          createPosColumn(width: 5, text: 'Date: $formattedDate'),
          createPosColumn(
            width: 7,
            text: 'Delivery Date: $formattedDeliveryDate',
            styles: createPosStyles(align: PosAlign.right),
          ),
        ]);
        bytes += generator.feed(1);

        bytes += generator.row([
          createPosColumn(width: 4, text: 'Time: $formattedTime'),
          createPosColumn(
            width: 8,
            text: 'Delivery Time: $deliveryTimeprint',
            styles: createPosStyles(align: PosAlign.right),
          ),
        ]);

        bytes += generator.feed(1);

        // Branch & Customer Number
        bytes += generator.row([
          createPosColumn(
            width: 6,
            text: 'Branch: ${globals.branchName}',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 6,
            text: 'Customer No: $customerNumber',
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
        bytes += generator.feed(1);

        // Salesperson (full width)
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: 'Sales Person: $employeeDisplayName',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
        ]);

        bytes += generator.feed(1);

        /// TOP BORDER BOX
        // TOP SEPARATOR
        /// TOP BORDER BOX
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: '==============================================',
            styles: createPosStyles(align: PosAlign.center),
          ),
        ]);

        /// COLUMN HEADERS (Classic Box)
        bytes += generator.row([
          createPosColumn(width: 1, text: 'No'),
          createPosColumn(width: 7, text: 'Item'),
          createPosColumn(
            width: 2,
            text: 'Tax',
            styles: createPosStyles(align: PosAlign.center),
          ),
          createPosColumn(
            width: 2,
            text: 'Amt',
            styles: createPosStyles(align: PosAlign.right),
          ),
        ]);
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: '----------------------------------------------',
          ),
        ]);
        bytes += generator.feed(1);

        double taxVaule = 0.0;
        Map<double, double> sgstMap = {};
        Map<double, double> cgstMap = {};

        // Process each item
        for (var item in cartItems) {
          // Assuming tax is fetched as dynamic or int, ensure it's treated as double
          double taxRate = (item.tax as num)
              .toDouble(); // num can be both int and double
          double itemTotal = calculateSubtotal();
          //     .toDouble(); // Ensure itemTotal is a double

          double itemTax = itemTotal * (taxRate / 100);
          double itemSGST = itemTax / 2;
          double itemCGST = itemSGST;

          // Update the maps with doubles
          sgstMap[taxRate / 2] = (sgstMap[taxRate / 2] ?? 0.0) + itemSGST;
          cgstMap[taxRate / 2] = (cgstMap[taxRate / 2] ?? 0.0) + itemCGST;
        }
        for (int i = 0; i < cartItems.length; i++) {
          final item = cartItems[i];

          final double amount = item.uom == 'Kgs'
              ? (item.weight * item.quantity.value * item.pricePerKg).toDouble()
              : (item.quantity.value * item.pricePerKg).toDouble();
          final discountedAmount = amount - (item.itemWiseDiscountAmount ?? 0);
          double taxPercentage = (item.tax as num).toDouble();
          taxVaule = taxPercentage;
          String priceDescription = '';
          if (item.uom.toLowerCase() == 'kgs' ||
              item.uom.toLowerCase() == 'kg') {
            // Weight-based pricing → show both quantity and weight
            priceDescription = item.weight >= 1
                ? '${item.quantity.value} ${item.uom} (${item.weight.toStringAsFixed(2)} kg) × Rs ${item.pricePerKg.toStringAsFixed(0)}/kg'
                : '${item.quantity.value} × (${(item.weight * 1000).toStringAsFixed(0)} g) × Rs ${item.pricePerKg.toStringAsFixed(0)}/kg';
          } else {
            // Pcs / Pkt or others
            priceDescription =
                '${item.quantity.value.toStringAsFixed(0)} ${item.uom} × Rs ${item.pricePerKg.toStringAsFixed(0)}';
          }
          bytes += generator.row([
            createPosColumn(
              width: 1,
              text: (i + 1).toString(),
              styles: createPosStyles(align: PosAlign.left),
            ),
            createPosColumn(
              width: 7,
              text: item.varianceName,
              styles: createPosStyles(align: PosAlign.left),
            ),
            createPosColumn(
              width: 1,
              text: '${item.tax}',
              styles: createPosStyles(align: PosAlign.center),
            ),

            createPosColumn(
              width: 3,
              text:
                  (item.itemWiseDiscount > 0 || item.itemWiseDiscountAmount > 0)
                  ? "" // hide amount if discount applied
                  : amount.toStringAsFixed(2),
              styles: createPosStyles(align: PosAlign.right, bold: true),
            ),
          ]);

          // ---------------- Amount (strike-through if discount exists) ----------------
          if ((item.itemWiseDiscount ?? 0) > 0 ||
              (item.itemWiseDiscountAmount ?? 0) > 0) {
            // Strike-through original amount image
            final imgBytes = await textWithStrikeImage(
              snoText: '         ',
              itemName: priceDescription,
              amountText: amount.toStringAsFixed(2),
            );
            bytes += generator.image(imgBytes, align: PosAlign.left);
          } else {
            // No discount → just print normally
            bytes += generator.row([
              createPosColumn(width: 1, text: '', styles: createPosStyles()),
              createPosColumn(
                width: 8,
                text: priceDescription,
                styles: createPosStyles(align: PosAlign.left),
              ),
              createPosColumn(
                width: 3,
                text: "",
                styles: createPosStyles(align: PosAlign.right, bold: true),
              ),
            ]);
          }

          if (item.itemWiseDiscount > 0 || item.itemWiseDiscountAmount > 0) {
            bytes += generator.row([
              createPosColumn(
                width: 1,
                text: '',
                styles: createPosStyles(align: PosAlign.left),
              ),
              createPosColumn(
                width: 8,
                text:
                    "Discount Amount(-): Rs ${(item.itemWiseDiscountAmount).toStringAsFixed(0)}",
                styles: createPosStyles(
                  align: PosAlign.left,
                  codeTable: 'CP1252',
                ),
              ),
              createPosColumn(
                width: 3,
                text: discountedAmount.toStringAsFixed(2),
                styles: createPosStyles(align: PosAlign.right, bold: true),
              ),
            ]);
          }

          // ---------------- Empty row for spacing ----------------
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text: '',
              styles: createPosStyles(align: PosAlign.center),
            ),
          ]);
        }

        // FOOTER SEPARATOR
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: '==================================================',
            styles: createPosStyles(align: PosAlign.center),
          ),
        ]);
        // Helper function to format label and value neatly
        // Helper function
        // Helper function for fixed-width label and value
        String formatLabelValueFixed({
          required String label,
          required String value,
          int labelWidth = 24, // fixed width for label column
          int valueWidth = 8, // fixed width for value column
        }) {
          // Truncate label if too long
          String fixedLabel = label.length > labelWidth
              ? label.substring(0, labelWidth)
              : label.padRight(labelWidth);

          // Pad value on left to make it right-aligned
          String fixedValue = value.padLeft(valueWidth);

          return '$fixedLabel : $fixedValue';
        }

        // TOTALS SECTION (RIGHT-ALIGNED)
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: formatLabelValueFixed(
              label: 'Total',
              value: 'Rs ${totalAmount.toStringAsFixed(0)}',
            ),
            styles: createPosStyles(align: PosAlign.right),
          ),
        ]);

        if ((customChargeController ?? 0) != 0) {
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text: formatLabelValueFixed(
                label: '${chargeType.toString()} (+)',
                value: 'Rs ${customChargeController.toStringAsFixed(0)}',
              ),
              styles: createPosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text: formatLabelValueFixed(
                label: 'Total Amount',
                value: 'Rs ${totalAmount2.toStringAsFixed(0)}',
              ),
              styles: createPosStyles(align: PosAlign.right, bold: true),
            ),
          ]);
        }

        if ((discountController ?? 0) != 0) {
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text: formatLabelValueFixed(
                label: 'Discount (${discountController}%) (-)',
                value: 'Rs ${discountAmount.toStringAsFixed(0)}',
              ),
              styles: createPosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text: formatLabelValueFixed(
                label: 'Order Amount',
                value: 'Rs ${finalPrice.toStringAsFixed(0)}',
              ),
              styles: createPosStyles(align: PosAlign.right, bold: true),
            ),
          ]);
        }
        // --- ADVANCE (multiple if exists) ---
        if (advanceDateTime != null && advanceDateTime!.isNotEmpty) {
          for (int i = 0; i < advanceDateTime!.length; i++) {
            try {
              // ✅ Safely get advance amount — default to 0.0 if not available
              double advAmt = 0.0;
              if (advanceAmount.isNotEmpty) {
                if (i < advanceAmount.length) {
                  advAmt = advanceAmount[i];
                } else {
                  advAmt = advanceAmount.last; // or 0.0 if you prefer
                }
              }

              bytes += generator.row([
                createPosColumn(
                  width: 12,
                  text: formatLabelValueFixed(
                    label: 'Advance Amount (-)',
                    value: 'Rs ${advAmt.toStringAsFixed(0)}',
                  ),
                  styles: createPosStyles(align: PosAlign.right),
                ),
              ]);
            } catch (e) {
              // ✅ Still show advance amount even if date parsing fails
              double advAmt = (i < advanceAmount.length)
                  ? advanceAmount[i]
                  : (advanceAmount.isNotEmpty ? advanceAmount.last : 0.0);

              bytes += generator.row([
                createPosColumn(
                  width: 12,
                  text: formatLabelValueFixed(
                    label: 'Advance Amount (-)',
                    value: 'Rs ${advAmt.toStringAsFixed(0)}',
                  ),
                  styles: createPosStyles(align: PosAlign.right),
                ),
              ]);
            }
          }
        } else {
          // ✅ If no advanceDateTime at all, still show one line with 0
          double advAmt = (advanceAmount.isNotEmpty)
              ? advanceAmount.first
              : 0.0;
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text: formatLabelValueFixed(
                label: 'Advance Amount (-)',
                value: 'Rs ${advAmt.toStringAsFixed(0)}',
              ),
              styles: createPosStyles(align: PosAlign.right),
            ),
          ]);
        }

        // ADVANCE

        // BALANCE
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: formatLabelValueFixed(
              label: 'Balance Amount',
              value: 'Rs ${balanceAmount.toStringAsFixed(0)}',
            ),
            styles: createPosStyles(align: PosAlign.right, bold: true),
          ),
        ]);

        // FINAL FOOTER
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: '==================================================',
            styles: createPosStyles(align: PosAlign.center),
          ),
        ]);

        // Payment Types (build safely)
        String paymentTypes = '';
        if ((selectedPaymentOptionValue.isNotEmpty)) {
          // prefer the single-string value if provided
          paymentTypes = selectedPaymentOptionValue;
        } else if (selectedPaymentOption != null &&
            selectedPaymentOption!.isNotEmpty) {
          try {
            paymentTypes = selectedPaymentOption!.expand((e) => e).join(", ");
          } catch (e) {
            // fallback
            paymentTypes = selectedPaymentOption!
                .map((e) => e.join(","))
                .join(", ");
          }
        }

        if (paymentTypes.isNotEmpty) {
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text: "Payment Type: ${paymentTypes}",
              styles: createPosStyles(align: PosAlign.left),
            ),
          ]);
        }
        if (advanceDateTime != null && advanceDateTime!.isNotEmpty) {
          for (int i = 0; i < advanceDateTime!.length; i++) {
            final dateTimeStr = advanceDateTime![i];
            try {
              DateTime parsedDate = DateTime.parse(dateTimeStr);
              String advDate = DateFormat('dd-MM-yyyy').format(parsedDate);
              String advTime = DateFormat('hh:mm a').format(parsedDate);
              final advAmt = (i < advanceAmount.length)
                  ? advanceAmount[i]
                  : (advanceAmount.isNotEmpty ? advanceAmount[0] : 0.0);

              bytes += generator.row([
                createPosColumn(
                  width: 12,
                  text: "Advance Paid Date: $advDate - $advTime",
                  styles: createPosStyles(align: PosAlign.left),
                ),
              ]);
            } catch (e) {
              // ignore parse error
            }
          }
        }
        // Inside _printReceiptDetails function
        bytes += generator.feed(1);

        const int maxLineWidth = 18;
        List<String> addressLines = splitAddress(globals.branchAddress);

        // Print address lines
        for (var line in addressLines) {
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text: line,
              styles: createPosStyles(
                align: PosAlign.center,
                codeTable: 'CP1252',
              ),
            ),
          ]);
        }

        // Print phone number
        if (globals.branchPhoneno.isNotEmpty) {
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text: 'Phone : ${globals.branchPhoneno}',
              styles: createPosStyles(
                align: PosAlign.center,
                codeTable: 'CP1252',
              ),
            ),
          ]);
        }
        bytes += generator.row([
          createPosColumn(
            width: 6,
            text: 'GST : 33AATFB12B1ZW',
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
          createPosColumn(
            width: 6,
            text: 'FSSAI : 1242000',
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
        ]);
        bytes += generator.feed(1);
        // Final footer message
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Thank You! Visit Again",
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
        ]);

        bytes += generator.feed(1);
        bytes += generator.qrcode(
          salesOrderNumber, // Data for QR
          size: QRSize.Size4, // Adjust size from Size1 to Size8
          align: PosAlign.center,
        );
        bytes += generator.feed(1);
        bytes += generator.cut();
        printer.rawBytes(
          Uint8List.fromList(bytes),
        ); // Send the bytes to the printer
      }
      printer.disconnect();
    } else {}
    // Navigator.of(context).pop();
    // cartProvider.clearCart();
  }

  double calculateSubtotal() {
    double subtotal = 0.0;
    for (var item in globals.cartItems) {
      subtotal += item.quantity.value * item.pricePerKg;
    }
    return subtotal;
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

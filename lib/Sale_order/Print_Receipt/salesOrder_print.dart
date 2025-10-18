import 'dart:math';
import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// import '../../../data/global_data_manager.dart';
// import '../../printer_screen/provider/printer_config_provider.dart';
// import '../../regular_mode_page/provider/cart_page_provider.dart';

import 'package:image/image.dart' as img;
import 'package:yenposapp/Global/Widget/customposcolumn.dart';
import 'package:yenposapp/Global/globals_data.dart' as globals;

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
  double totalAmount;
  double totalAmount2;
  double finalPrice;
  double discountAmount;

  List<double> advanceAmount;
  double balanceAmount;
  String customerType;

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
    required this.totalAmount2,
    required this.finalPrice,
    required this.discountAmount,
    required this.advanceDateTime,
    required this.selectedPaymentOptionValue,
    required this.totalAmount,
    required this.advanceAmount,
    required this.saleOrderNo,
    required this.balanceAmount,

    // required this.context,
    required this.customerType,
    required this.customAmountController,
    required this.selectedPaymentOption,
    required this.selectedPaymentOptionAmount,

    // required this.saveInvoiceToHiveAndPrint,
  });
  // ✅ Correct (store patchId as String)
  final Map<String, bool> _printedOrders = {};

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

    // ✅ Check if this order was already printed
    if (_printedOrders[salesOrderNumber] == true) {
      return; // exit early, don't print again
    }

    // Mark this SaleOrder as printed
    _printedOrders[salesOrderNumber] = true;

    var cartItems = globals.cartItems ?? [];

    // Printer connection
    String printerIp = '192.168.1.87';

    final profile = await CapabilityProfile.load();

    final printer = NetworkPrinter(PaperSize.mm80, profile);

    // Connect to printer
    final PosPrintResult res = await printer.connect(printerIp, port: 9100);
    if (res == PosPrintResult.success) {
      List<int> bytes;
      final generator = Generator(PaperSize.mm80, profile);

      bytes = []; // Reset bytes for each copy

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

      // Sale Order Number (just below, bold)
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: "Order No: $salesOrderNumber",
          styles: createPosStyles(
            align: PosAlign.center,
            codeTable: 'CP1252',
            height: PosTextSize.size2, // bigger for emphasis
            width: PosTextSize.size2,
            bold: true,
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
          text: 'Dl Date: $deliveryDateprint',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'Dl Time:$deliveryTimeprint',
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
          text: 'C No: $customerNumber',
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

      double taxVaule = 0.0;
      Map<double, double> sgstMap = {};
      Map<double, double> cgstMap = {};

      // Process each item
      for (var item in cartItems) {
        // Assuming tax is fetched as dynamic or int, ensure it's treated as double
        double taxRate =
            (item.tax as num).toDouble(); // num can be both int and double
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
            ? (item.weight * item.quantity * item.pricePerKg).toDouble()
            : (item.quantity * item.pricePerKg).toDouble();

        final double discountedAmount =
            amount - ((item.itemWiseDiscountAmount ?? 0).toDouble());

        String priceDescription = '';
        if (item.uom.toLowerCase() == 'kgs' || item.uom.toLowerCase() == 'kg') {
          // Weight-based pricing → show both quantity and weight
          priceDescription = item.weight >= 1
              ? '${item.quantity} ${item.uom} (${item.weight.toStringAsFixed(2)} kg) × Rs.${item.pricePerKg.toStringAsFixed(0)}/kg'
              : '${item.quantity} × (${(item.weight * 1000).toStringAsFixed(0)} g) × Rs.${item.pricePerKg.toStringAsFixed(0)}/kg';
        } else {
          // Pcs / Pkt or others
          priceDescription =
              '${item.quantity.toStringAsFixed(0)} ${item.uom} × Rs.${item.pricePerKg.toStringAsFixed(0)}';
        }

        bytes += generator.row([
          createPosColumn(
            width: 1,
            text: (i + 1).toString(),
            styles: createPosStyles(align: PosAlign.left),
          ),
          createPosColumn(
            width: 10,
            text: item.varianceName,
            styles: createPosStyles(align: PosAlign.left),
          ),
          createPosColumn(
            width: 1,
            text: '',
            styles: createPosStyles(align: PosAlign.left),
          ),
        ]);

        // ---------------- Amount (strike-through if discount exists) ----------------
        if ((item.itemWiseDiscount ?? 0) > 0 ||
            (item.itemWiseDiscountAmount ?? 0) > 0) {
          // Strike-through original amount image
          final imgBytes = await textWithStrikeImage(
            snoText: '         ',
            itemName: "$priceDescription (Tax ${item.tax}%)",
            amountText: "Rs ${amount.toStringAsFixed(2)}",
          );
          bytes += generator.image(imgBytes, align: PosAlign.left);
        } else {
          // No discount → just print normally
          bytes += generator.row([
            createPosColumn(
              width: 1,
              text: '',
              styles: createPosStyles(),
            ),
            createPosColumn(
              width: 8,
              text: "$priceDescription (Tax ${item.tax}%)",
              styles: createPosStyles(align: PosAlign.left),
            ),
            createPosColumn(
              width: 3,
              text: "Rs ${amount.toStringAsFixed(2)}",
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
              text: "Discount Amount(-): Rs ${(item.itemWiseDiscountAmount)}",
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
                width: 3,
                text: "Rs ${discountedAmount}",
                styles: createPosStyles(align: PosAlign.right, bold: true)),
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
          text: '----------------------------------------------',
          styles: createPosStyles(
            align: PosAlign.center,
            codeTable: 'CP1252',
          ),
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
          String advDateTimeStr =
              (i < advanceDateTime!.length) ? advanceDateTime![i] : "";

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
              styles:
                  createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
            ),
            createPosColumn(
              width: 6,
              text: "Advance ${i + 1}: Rs.${advAmt.toStringAsFixed(0)}",
              styles:
                  createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
            ),
          ]);
        }
      }
// 🔹 Balance Amount print
      bytes += generator.row([
        createPosColumn(
          width: 12,
          text: "Balance Amount : Rs ${balanceAmount.toStringAsFixed(0)}",
          styles: createPosStyles(
            align: PosAlign.right,
            codeTable: 'CP1252',
          ),
        ),
      ]);

// 🔹 Separator
      bytes += generator.text(
        "---------------------------",
        styles: createPosStyles(align: PosAlign.center, codeTable: 'CP1252'),
      );

      // 🔹 Advance Amount with Date & Time (Left) and Amount (Right)
      if (advanceAmount.isNotEmpty &&
          advanceDateTime != null &&
          advanceDateTime!.isNotEmpty) {
        for (int i = 0; i < advanceAmount.length; i++) {
          double advAmt = advanceAmount[i];
          String advDateTimeStr =
              (i < advanceDateTime!.length) ? advanceDateTime![i] : "";

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
                styles:
                    createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
              ),
            ]);
          }
        }
      }
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
          styles: createPosStyles(
            align: PosAlign.center,
            codeTable: 'CP1252',
          ),
        ),
      ]);
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
      bytes += generator.feed(2);

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
      _printedOrders[salesOrderNumber] = false; // Reset after printing
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

    // Cart items
    var cartItems = globals.cartItems ?? [];

    // Printer connection
    String printerIp = '192.168.1.87';

    final profile = await CapabilityProfile.load();

    final printer = NetworkPrinter(PaperSize.mm80, profile);

    // Connect to printer
    final PosPrintResult res = await printer.connect(printerIp, port: 9100);
    if (res == PosPrintResult.success) {
      List<int> bytes;
      final generator = Generator(PaperSize.mm80, profile);

      for (int copy = 0; copy < 2; copy++) {
        bytes = []; // Reset bytes for each copy
        try {
          final ByteData data = await rootBundle.load('assets/bestmummy.png');
          final Uint8List imageBytes = data.buffer.asUint8List();
          final img.Image? logo = img.decodeImage(imageBytes);

          if (logo != null) {
            // 1) Ensure white background (remove alpha)
            final img.Image whiteBg = img.Image(logo.width, logo.height);
            img.fill(whiteBg, img.getColor(255, 255, 255));
            img.copyInto(whiteBg, logo, blend: true);

            // 2) Convert to grayscale
            final img.Image gray = img.grayscale(whiteBg);

            // 3) Manual binary threshold (works regardless of package version)
            img.Image binaryThreshold(img.Image src, int threshold) {
              final out = img.Image.from(src);
              for (int y = 0; y < out.height; y++) {
                for (int x = 0; x < out.width; x++) {
                  final int p = out.getPixel(x, y);
                  final int r = img.getRed(p);
                  final int g = img.getGreen(p);
                  final int b = img.getBlue(p);
                  // Luminance using Rec. 601 luma coefficients (more accurate for text/logo)
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

            final img.Image thresholded =
                binaryThreshold(gray, 180); // tweak 150-210 as needed

            // 4) Resize to printer width (250 px is okay for mm80)
            final img.Image resized = img.copyResize(thresholded,
                width: 250, interpolation: img.Interpolation.nearest);

            // 5) Ensure height is multiple of 8 (ESC/POS alignment)
            final int remainder = resized.height % 8;
            img.Image aligned = resized;
            if (remainder != 0) {
              final int newHeight = resized.height + (8 - remainder);
              aligned = img.Image(resized.width, newHeight);
              img.fill(aligned, img.getColor(255, 255, 255)); // white pad
              img.copyInto(aligned, resized, dstY: 0, blend: false);
            }

            // 6) Send to generator
            bytes += generator.image(aligned, align: PosAlign.center);
          }
        } catch (e) {
        }

        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: (copy == 0 ? 'Sales order' : 'Sales order'),
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          ),
        ]);
        // Sale Order Number (just below, bold)
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Order No: $salesOrderNumber",
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
              height: PosTextSize.size2, // bigger for emphasis
              width: PosTextSize.size2,
              bold: true,
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
            text: 'Dl Date: $deliveryDateprint',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 6,
            text: 'Dl Time:$deliveryTimeprint',
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
            text: 'C No: $customerNumber',
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);

        bytes += generator.feed(1);

        // Print Sales Person and Customer Number on the same line
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: 'SalesPerson : ${employeeNameController.text}',
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
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

        double taxVaule = 0.0;
        Map<double, double> sgstMap = {};
        Map<double, double> cgstMap = {};

        // Process each item
        for (var item in cartItems) {
          // Assuming tax is fetched as dynamic or int, ensure it's treated as double
          double taxRate =
              (item.tax as num).toDouble(); // num can be both int and double
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
              ? (item.weight * item.quantity * item.pricePerKg).toDouble()
              : (item.quantity * item.pricePerKg).toDouble();
          final discountedAmount = amount - (item.itemWiseDiscountAmount ?? 0);
          double taxPercentage = (item.tax as num).toDouble();
          taxVaule = taxPercentage;
          String priceDescription = '';
          if (item.uom.toLowerCase() == 'kgs' ||
              item.uom.toLowerCase() == 'kg') {
            // Weight-based pricing → show both quantity and weight
            priceDescription = item.weight >= 1
                ? '${item.quantity} ${item.uom} (${item.weight.toStringAsFixed(2)} kg) × Rs.${item.pricePerKg.toStringAsFixed(0)}/kg'
                : '${item.quantity} × (${(item.weight * 1000).toStringAsFixed(0)} g) × Rs.${item.pricePerKg.toStringAsFixed(0)}/kg';
          } else {
            // Pcs / Pkt or others
            priceDescription =
                '${item.quantity.toStringAsFixed(0)} ${item.uom} × Rs.${item.pricePerKg.toStringAsFixed(0)}';
          }
          // Split item name into lines of max 15 chars
          List<String> itemNameLines = splitText(item.varianceName ?? '', 15);

          // // Generate strike-through image for amount
          // final imgBytes =
          //     await textWithStrikeImage("Rs ${amount.toStringAsFixed(2)}");

          // ---------------- Main row with S.No, Item Name (first line), and Amount ----------------
          // Main row: S.No and item name
          bytes += generator.row([
            createPosColumn(
              width: 1,
              text: (i + 1).toString(),
              styles: createPosStyles(align: PosAlign.left),
            ),
            createPosColumn(
              width: 10,
              text: item.varianceName,
              styles: createPosStyles(align: PosAlign.left),
            ),
            createPosColumn(
              width: 1,
              text: '',
              styles: createPosStyles(align: PosAlign.left),
            ),
          ]);

          // ---------------- Amount (strike-through if discount exists) ----------------
          if ((item.itemWiseDiscount ?? 0) > 0 ||
              (item.itemWiseDiscountAmount ?? 0) > 0) {
            // Strike-through original amount image
            final imgBytes = await textWithStrikeImage(
              snoText: '         ',
              itemName: "$priceDescription (Tax ${item.tax}%)",
              amountText: "Rs ${amount.toStringAsFixed(2)}",
            );
            bytes += generator.image(imgBytes, align: PosAlign.left);
          } else {
            // No discount → just print normally
            bytes += generator.row([
              createPosColumn(
                width: 1,
                text: '',
                styles: createPosStyles(),
              ),
              createPosColumn(
                width: 8,
                text: "$priceDescription (Tax ${item.tax}%)",
                styles: createPosStyles(align: PosAlign.left),
              ),
              createPosColumn(
                width: 3,
                text: "Rs ${amount.toStringAsFixed(2)}",
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
                  text: "Rs ${discountedAmount.toStringAsFixed(2)}",
                  styles: createPosStyles(align: PosAlign.right, bold: true)),
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
            text: '----------------------------------------------',
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
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

// --- ADVANCE (multiple if exists) ---
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
                  text: "Advance Amount (-): Rs ${advAmt.toStringAsFixed(0)}",
                  styles: createPosStyles(align: PosAlign.right),
                ),
              ]);
            } catch (e) {
              // ignore parse error
            }
          }
        }

        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Balance Amount: Rs ${balanceAmount.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right, bold: true),
          ),
        ]);

        // Separator
        bytes += generator.row([
          createPosColumn(
              width: 12,
              text: '----------------------------------------------',
              styles: createPosStyles(align: PosAlign.center)),
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
            paymentTypes =
                selectedPaymentOption!.map((e) => e.join(",")).join(", ");
          }
        }

        if (paymentTypes.isNotEmpty) {
          bytes += generator.row([
            createPosColumn(
                width: 12,
                text: "Payment Type: ${paymentTypes}",
                styles: createPosStyles(align: PosAlign.left)),
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
                    text: "Advance Paid: $advDate - $advTime",
                    styles: createPosStyles(align: PosAlign.left)),
              ]);
            } catch (e) {
              // ignore parse error
            }
          }
        }
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
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
        ]);
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
        bytes += generator.feed(2);

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
      subtotal += item.quantity * item.pricePerKg;
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

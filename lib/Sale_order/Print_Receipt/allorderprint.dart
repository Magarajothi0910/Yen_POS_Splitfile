import 'dart:math';
import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Global/Widget/customposcolumn.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:image/image.dart' as img;
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/printer_screen/provider/printer_config_provider.dart';

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
  String invoiceNo;
  String saleOrderNo;
  String salesReturnNo;
  String salesType;

  // final BuildContext context;
  final TextEditingController customAmountController;
  String selectedPaymentOption;
  double cashAmount;
  double cardAmount;
  double upiAmount;
  // Inject PrinterProvider directly
  final PrinterProviderpos printerProvider;

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
    required this.cashAmount,
    required this.invoiceNo,
    required this.saleOrderNo,
    required this.salesReturnNo,
    required this.salesType,
    required this.cardAmount,
    required this.upiAmount,
    required this.printerProvider, // ✅ inject dependency
    // required this.saveInvoiceToHiveAndPrint,
  });
  Future<void> printReceiptDetails() async {
    // Step 1: Get cart items
    var cartItems = globals.invoiceItems ?? [];

    // Step 2: Current date and time
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

    // Step 3: Determine payment amount
    String paymentAmount;
    try {
      if (selectedPaymentOption == 'Cash: Custom' &&
          customAmountController.text.isNotEmpty) {
        paymentAmount = 'Rs ${customAmountController.text}';
      } else if (selectedPaymentOption.contains(':')) {
        paymentAmount =
            'Rs ${selectedPaymentOption.split(': ').last.replaceAll('', '').trim()}';
      } else {
        paymentAmount = 'Rs ${totalAmount.toStringAsFixed(0)}';
      }
    } catch (e) {
      paymentAmount = 'Rs 0';
    }

    // Step 4: Employee display name
    String fullEmployeeName = employeeNameController.text.trim();
    String employeeDisplayName = fullEmployeeName.contains('-')
        ? fullEmployeeName.split('-').last.trim()
        : fullEmployeeName;

    await printerProvider.initializeHive(); // Make sure Hive is loaded
    // **Fetch printer IP from Hive directly**
    String? printerIp = printerProvider.getPrinterIpFromHive(type: 'Overall');

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final PosPrintResult res = await printer.connect(printerIp!, port: 9100);

    if (res == PosPrintResult.success) {
      List<int> bytes = [];
      final generator = Generator(PaperSize.mm80, profile);

      try {
        final box = Hive.box('logo');
        final Uint8List? imageBytes = box.get('BMlogo_bytes');
        final String? logoName = box.get('BMlogo_name');
        final String? logoPath = box.get('BMlogo_path');

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
        }
      } catch (e, st) {}

      bytes += generator.row([
        createPosColumn(
          width: 2,
          text: '',
          styles: createPosStyles(align: PosAlign.left),
        ),
        if (salesType == 'salesReturn')
          createPosColumn(
            width: 8,
            text: 'Sales Return',
            styles: PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size1,
              width: PosTextSize.size2,
              bold: true,
              codeTable: 'CP1252',
            ),
          )
        else
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
          text: 'Branch: ${globals.branchName}',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        if (salesType != 'salesReturn')
          createPosColumn(
            width: 7,
            text: 'BillNo: $invoiceNo',
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          )
        else
          createPosColumn(
            width: 7,
            text: 'BillNo: $salesReturnNo',
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
      ]);

      bytes += generator.feed(1);

      bytes += generator.row([
        createPosColumn(
          width: 6,
          text: 'Sales Person: ${employeeDisplayName}',
          styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
        ),
        createPosColumn(
          width: 6,
          text: 'Cus.No: ${customerNumberController.text}',
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
        double itemTotal = item.amount;
        double taxRate = (item.tax).toDouble();

        originalSubTotal += itemTotal;

        if (isGSTEnabled) {
          itemTotalsMap[taxRate] = (itemTotalsMap[taxRate] ?? 0.0) + itemTotal;
        }
      }

      double grossTotal = originalSubTotal;

      double discountPercentage = discountController;
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


      final custom = customChargeController;

      double receivedAmount = cashAmount + cardAmount + upiAmount;
      double finalTotal = discountedTotal + custom;
      double changeAmount = receivedAmount - finalTotal;
      double total = discountedTotal + custom;


      // Print Cart Items
      for (int i = 0; i < cartItems.length; i++) {
        final item = cartItems[i];

        final String itemName = item.itemName ?? 'N/A';
        final String varianceName = item.varianceName ?? 'N/A';
        final double price = item.price ?? 0.0;
        final double weight = (item.weight ?? 0.0).toDouble();
        final double qty = (item.qty as num).toDouble();
        final double orig_amount = item.amount;
        final double tax = (item.tax).toDouble();
        final String uom = item.uom ?? 'N/A';

        double item_discount_amt = orig_amount * (discountPercentage / 100);
        double item_disc_amount = orig_amount - item_discount_amt;


        bytes += generator.row([
          createPosColumn(
            width: 1,
            text: (i + 1).toString(),
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
          createPosColumn(
            width: 11,
            text: varianceName,
            styles: createPosStyles(align: PosAlign.left, codeTable: 'CP1252'),
          ),
        ]);

        String priceDescription = '';
        if (item.uom.toLowerCase() == 'kgs' || item.uom.toLowerCase() == 'kg') {
          priceDescription = item.weight >= 1
              ? '${item.qty} ${item.uom} (${item.weight.toStringAsFixed(2)} kg) × Rs.${item.price.toStringAsFixed(0)}/kg'
              : '${item.qty}(${(item.weight * 1000).toStringAsFixed(0)} g) × Rs.${item.price.toStringAsFixed(0)}/kg';
        } else {
          priceDescription =
              '${item.qty.toStringAsFixed(0)} ${item.uom} × Rs.${item.price.toStringAsFixed(0)}';
        }
        if (isGSTEnabled) {
          priceDescription += "(Tax ${item.tax}%)";
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

      // ✅ ADVANCE PAYMENT DETAILS - MATCHED BY SALE ORDER NUMBER
      try {

        final saleOrdersBox = HiveManager.salesOrderBox;
        if (saleOrdersBox != null && saleOrdersBox.isNotEmpty) {
          Map<String, dynamic>? matchingSaleOrder;

          for (var saleOrder in saleOrdersBox.values) {
            final saleDataDynamic = (saleOrder as Map)['data'];
            if (saleDataDynamic != null) {
              // Safely convert dynamic map to Map<String, dynamic>
              final saleData = Map<String, dynamic>.from(saleDataDynamic);

              if (saleData.containsKey('saleOrderNo') &&
                  saleData['saleOrderNo'].toString().trim() ==
                      saleOrderNo.trim()) {
                matchingSaleOrder = saleData;
                break;
              }
            }
          }

          if (matchingSaleOrder != null) {
            final advanceAmounts =
                (matchingSaleOrder['advanceAmount'] as List<dynamic>?) ?? [];
            final advanceDates =
                (matchingSaleOrder['advanceDateTime'] as List<dynamic>?) ?? [];
            final advancePaymentTypes =
                (matchingSaleOrder['advancePaymentType'] as List<dynamic>?) ??
                [];
            final modeWiseAmounts =
                (matchingSaleOrder['modeWiseAmount'] as List<dynamic>?) ?? [];
            if (advanceAmounts.isNotEmpty) {
              bytes += generator.row([
                createPosColumn(
                  width: 12,
                  text: "Advance Details",
                  styles: PosStyles(
                    bold: true,
                    codeTable: 'CP1252',
                    align: PosAlign.left,
                  ),
                ),
              ]);
              bytes += generator.feed(1);
              for (int i = 0; i < advanceAmounts.length; i++) {
                final advAmount = (advanceAmounts[i] as num).toDouble();
                final advDateTimeStr = advanceDates[i].toString();
                final advDateTime = DateTime.tryParse(advDateTimeStr);

                final date = advDateTime != null
                    ? DateFormat('dd-MM-yyyy').format(advDateTime)
                    : advDateTimeStr;

                final time = advDateTime != null
                    ? DateFormat('hh:mm a').format(advDateTime)
                    : "";

                final paymentModes = advancePaymentTypes[i] as List<dynamic>;
                final modeList = paymentModes.join(", ");

                // ------------ ADVANCE TOTAL ------------
                double totalAdvance = 0.0;

                if (advanceAmounts.isNotEmpty) {
                  for (var amt in advanceAmounts) {
                    totalAdvance += (amt as num).toDouble();
                  }
                }

                // ------------ TODAY RECEIVED ------------
                double todayReceived = receivedAmount;

                // ------------ TOTAL RECEIVED OVERALL ------------
                double totalReceivedTillNow = totalAdvance + todayReceived;

                // ------------ TOTAL PAYABLE ------------
                double totalPayable = discountedTotal + custom;

                // ------------ BALANCE AMOUNT ------------
                double balanceAmount = totalPayable - totalReceivedTillNow;
                if (balanceAmount < 0) balanceAmount = 0;

                // UPDATE VARIABLE FOR PRINTING
                changeAmount = balanceAmount;
                // -----------------------------------
                // 🔹 LINE 1 → Advance 1 - Cash, Card
                // -----------------------------------
                bytes += generator.row([
                  createPosColumn(
                    width: 12,
                    text: "Advance ${i + 1} - $modeList",
                    styles: createPosStyles(
                      align: PosAlign.left,
                      codeTable: 'CP1252',
                    ),
                  ),
                ]);

                // -----------------------------------
                // 🔹 LINE 2 → Paid On: date | time     amount
                // -----------------------------------
                bytes += generator.row([
                  createPosColumn(
                    width: 8,
                    text: "Paid On: $date | $time",
                    styles: createPosStyles(
                      align: PosAlign.left,
                      codeTable: 'CP1252',
                    ),
                  ),
                  createPosColumn(
                    width: 4,
                    text: "Rs ${advAmount.toStringAsFixed(2)}",
                    styles: createPosStyles(
                      align: PosAlign.right,
                      codeTable: 'CP1252',
                    ),
                  ),
                ]);
              }
            } else {
            }
          } else {
          }
        } else {}
      } catch (e, st) {}

      // ======================== PAYMENT DETAILS SECTION ========================
      bytes += generator.hr();
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
            text: "UPI",
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
          text: "Rs ${receivedAmount.toStringAsFixed(0)}",
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
          text: "Rs ${changeAmount.toStringAsFixed(0)}",
          styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
        ),
      ]);

      // ======================== GST INVOICE BREAKUP SECTION ========================
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
            text: "Rs ${totalNetAmount.toStringAsFixed(2)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);

        sgstMap.forEach((rate, sgstAmount) {
          double cgstAmount = cgstMap[rate] ?? 0.0;
          final gst = cgstAmount + sgstAmount;

          bytes += generator.row([
            createPosColumn(
              text: "GST($rate%)",
              width: 6,
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              text: "Rs ${gst.toStringAsFixed(2)}",
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
                  "SGST(${(rate / 2).toStringAsFixed(1)}%): Rs ${sgstAmount.toStringAsFixed(2)}",
              width: 6,
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              text:
                  "CGST(${(rate / 2).toStringAsFixed(1)}%): Rs ${cgstAmount.toStringAsFixed(2)}",
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
            bold: true,
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

      List<String> addressLines = splitAddress(globals.branchAddress);

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

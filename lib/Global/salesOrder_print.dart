import 'dart:math';
import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// import '../../../data/global_data_manager.dart';
// import '../../printer_screen/provider/printer_config_provider.dart';
// import '../../regular_mode_page/provider/cart_page_provider.dart';
import '../Global/customposcolumn.dart';
import '../screens/printer_screen/provider/printer_config_provider.dart';
import '../screens/sales_order/sales_order_providers/cartProvider.dart';

import '../screens/sales_order/globals.dart' as globals;

class salesOrderReceiptPrinter {
  final TextEditingController employeeNameController;
  final TextEditingController customerNumberController;
  double discountController;
  double discountAmountController;

  String deliveryDateprint;
  String deliveryTimeprint;
  String saleOrderNo;

  double customChargeController;
  String selectedPaymentOptionValue;
  double totalAmount;
  double deductedAmount;

  List<double> advanceAmount;
  double balanceAmount;
  String customerType;
  String _lastPrintedOrderNo = '';
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
    required this.deductedAmount,
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
  Future<void> printReceiptDetails() async {
    print("===== START printReceiptDetails =====");

    String employeeName = employeeNameController.text;
    String customerNumber = customerNumberController.text;
    String paymentAmount;
    String salesOrderNumber = saleOrderNo;
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('dd-MM-yyyy').format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

    // Debug values
    print("employeeName: $employeeName (${employeeName.runtimeType})");
    print("customerNumber: $customerNumber (${customerNumber.runtimeType})");
    print("saleOrderNo: $salesOrderNumber (${salesOrderNumber.runtimeType})");
    print(
        "deliveryDateprint: $deliveryDateprint (${deliveryDateprint.runtimeType})");
    print(
        "deliveryTimeprint: $deliveryTimeprint (${deliveryTimeprint.runtimeType})");
    print("customerType: $customerType (${customerType.runtimeType})");
    print(
        "discountController: $discountController (${discountController.runtimeType})");
    print(
        "customChargeController: $customChargeController (${customChargeController.runtimeType})");
    print("totalAmount: $totalAmount (${totalAmount.runtimeType})");
    print("advanceAmount: $advanceAmount (${advanceAmount.runtimeType})");
    print("balanceAmount: $balanceAmount (${balanceAmount.runtimeType})");
    print(
        "selectedPaymentOption: $selectedPaymentOption (${selectedPaymentOption.runtimeType})");
    print(
        "selectedPaymentOptionValue: $selectedPaymentOptionValue (${selectedPaymentOptionValue.runtimeType})");
    print(
        "customAmountController.text: ${customAmountController.text} (${customAmountController.text.runtimeType})");
    print(
        "selectedPaymentOptionAmount.text: ${selectedPaymentOptionAmount} (${selectedPaymentOptionAmount.runtimeType})");
    print("Current Date: $formattedDate | Time: $formattedTime");

    // Decide payment amount
    if (selectedPaymentOption == 'Cash: Custom' &&
        customAmountController.text.isNotEmpty) {
      paymentAmount = 'Rs ${customAmountController.text}';
    } else if (selectedPaymentOption!.contains(':')) {
      paymentAmount = 'Rs ${selectedPaymentOption!}';
    } else {
      paymentAmount = 'Rs ${totalAmount.toStringAsFixed(0)}';
    }

    print(
        "paymentAmount (final): $paymentAmount (${paymentAmount.runtimeType})");

    // Cart items
    var cartItems = globals.cartItems ?? [];
    print("CartItems Count: ${cartItems.length}");
    for (int i = 0; i < cartItems.length; i++) {
      final item = cartItems[i];
      print("CartItem[$i] -> "
          "itemName=${item.itemName}, "
          "varianceName=${item.varianceName}, "
          "itemCode=${item.itemCode}, "
          "qty=${item.quantity}, "
          "tax=${item.tax}, "
          "uom=${item.uom}, "
          "pricePerKg=${item.pricePerKg}, "
          "weight=${item.weight}");
    }

    // Printer connection
    String printerIp = '192.168.1.87';
    print("Printer IP: $printerIp");

    final profile = await CapabilityProfile.load();
    print("CapabilityProfile loaded: $profile");

    final printer = NetworkPrinter(PaperSize.mm80, profile);
    print("NetworkPrinter initialized");

    final PosPrintResult res = await printer.connect(printerIp, port: 9100);
    print("Printer connect result: $res");

    if (res == PosPrintResult.success) {
      print("Printer connected successfully, preparing data...");
      List<int> bytes;
      final generator = Generator(PaperSize.mm80, profile);

      for (int copy = 0; copy < 2; copy++) {
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
        bytes += generator.feed(1);
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

        // Adding cart items with item name, quantity, and price in the desired format
        for (int i = 0; i < cartItems.length; i++) {
          final item = cartItems[i];

          // final double amount = item.uom == 'Kgs'
          //     ? 'Rs.${(item.weight * item.quantity * item.pricePerKg).toDouble()}/-'
          //     : 'Rs.${(item.quantity * item.pricePerKg).toDouble()}/-';

          final double amount = item.uom == 'Kgs'
              ? (item.weight * item.quantity * item.pricePerKg).toDouble()
              : (item.quantity * item.pricePerKg).toDouble();

          double taxPercentage = (item.tax as num).toDouble();

          taxVaule = taxPercentage;

          List<String> itemNameLines = splitText(item.varianceName ?? '', 15);

          // Main item name
          bytes += generator.row([
            createPosColumn(
              width: 1,
              text: (i + 1).toString(), // S.No
              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              width: 8,
              text: itemNameLines[0], // First line of item name

              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              width: 3,
              text:
                  // "Rs ${cartProvider.calculateSubtotal().toStringAsFixed(0)}", // Price
                  "Rs $amount",
              styles: createPosStyles(
                align: PosAlign.right,
                codeTable: 'CP1252',
              ),
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
                  "(${item.quantity} ${item.uom} x ${item.pricePerKg}) (tax ${item.tax}%)", // Quantity and unit price

              styles: createPosStyles(
                align: PosAlign.left,
                codeTable: 'CP1252',
              ),
            ),
            createPosColumn(
              width: 3,
              text: "", // Total amount
              styles: createPosStyles(
                align: PosAlign.right,
                codeTable: 'CP1252',
              ),
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
            styles: createPosStyles(
              align: PosAlign.center,
              codeTable: 'CP1252',
            ),
          ),
        ]);
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Order Amount :Rs ${totalAmount.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);
        if (discountController != 0) {
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text:
                  "Discount (${discountController}%): Rs ${discountAmountController.toStringAsFixed(2)}",
              styles: createPosStyles(
                align: PosAlign.right,
                codeTable: 'CP1252',
              ),
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
            text: "Total Amount :Rs ${deductedAmount.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);

        if (advanceAmount != 0) {
          // join all payment types into comma separated string
          String paymentTypes = "";
          if (selectedPaymentOption != null &&
              selectedPaymentOption!.isNotEmpty) {
            paymentTypes = selectedPaymentOption!
                .expand((e) => e) // flatten nested list
                .join(", "); // join with commas
          }

          // 🔹 Print Overall Advance Total
          bytes += generator.row([
            createPosColumn(
              width: 12,
              text: "Total Advance: Rs ${advanceAmount}",
              styles: createPosStyles(
                align: PosAlign.right,
                codeTable: 'CP1252',
                bold: true,
              ),
            ),
          ]);

          // 🔹 Print Payment Types
          if (paymentTypes.isNotEmpty) {
            bytes += generator.row([
              createPosColumn(
                width: 12,
                text: "Payment Type: $paymentTypes",
                styles: createPosStyles(
                  align: PosAlign.right,
                  codeTable: 'CP1252',
                ),
              ),
            ]);
          }
        }

        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: "Balance Amount :Rs ${balanceAmount.toStringAsFixed(0)}",
            styles: createPosStyles(align: PosAlign.right, codeTable: 'CP1252'),
          ),
        ]);

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
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'; // Alphanumeric characters
    final randomId =
        List<int>.generate(6, (_) => random.nextInt(characters.length))
            .map((index) => characters[index])
            .join(); // Generate a 6-character random ID
    return '$timestamp-$randomId'; // Combines timestamp and random alphanumeric ID
  }
}

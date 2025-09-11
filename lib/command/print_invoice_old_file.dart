//   void _printReceiptDetails() async {
//     String employeeNumber = _employeeNumberController.text ?? '';
//     String customerNumber = _customerNumberController.text ?? '';
//     String paymentAmount;
//     DateTime now = DateTime.now();
//     String formattedDate = DateFormat('dd-MM-yyyy').format(now);
//     String formattedTime =
//         DateFormat('hh:mm a').format(now); // 12-hour format with AM/PM

//     if (_selectedPaymentOption == 'Cash: Custom' &&
//         _customAmountController.text.isNotEmpty) {
//       paymentAmount = 'Rs ' +
//           _customAmountController.text; // Ensuring single currency symbol
//     } else if (_selectedPaymentOption != null &&
//         _selectedPaymentOption.contains('')) {
//       paymentAmount = 'Rs ' +
//           _selectedPaymentOption.split(': ').last.replaceAll('', '').trim();
//     } else {
//       paymentAmount = 'Rs ' + (widget.totalAmount?.toStringAsFixed(0) ?? '0');
//     }

//     var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
//     var cartItems = cartProvider.currentSaleItems ?? [];
//     double discountPercentage = cartProvider.discountPercentage;
//     double customCharge = cartProvider.customCharge;
//     double discountAmount =
//         cartProvider.calculateTotal() * discountPercentage / 100;
//     // Fetch the settings
//     final settings = GlobalDataManager().billReceiptSettings;

//     final profile = await CapabilityProfile.load();
//     final printer = NetworkPrinter(PaperSize.mm80, profile);

//     final PosPrintResult res =
//         await printer.connect('192.168.1.87', port: 9100);

//     if (res == PosPrintResult.success) {
//       List<int> bytes = [];
//       final generator = Generator(PaperSize.mm80, profile);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: '',
//             styles: const PosStyles(
//               align: PosAlign.center,
//               height: PosTextSize.size6,
//               width: PosTextSize.size6,
//               codeTable: 'CP1252',
//             )),
//       ]);
//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'BestMummy',
//             styles: const PosStyles(
//               align: PosAlign.center,
//               height: PosTextSize.size1,
//               width: PosTextSize.size1,
//               codeTable: 'CP1252',
//             )),
//       ]);
//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Sweets & Cakes',
//             styles: const PosStyles(
//               align: PosAlign.center,
//               height: PosTextSize.size1,
//               width: PosTextSize.size1,
//               codeTable: 'CP1252',
//             )),
//       ]);
//       bytes += generator.feed(1);

//       //cartProvider.calculateTotal().toStringAsFixed(2)}
//       // Sales Invoice details
//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Rs ${cartProvider.calculateTotal().toStringAsFixed(0)}',
//             styles: const PosStyles(
//               align: PosAlign.center,
//               codeTable: 'CP1252',
//               height: PosTextSize.size3,
//               width: PosTextSize.size3,
//             )),
//       ]);
//       bytes += generator.feed(1);
//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Sales Invoice',
//             styles: const PosStyles(
//               align: PosAlign.center,
//               codeTable: 'CP1252',
//               height: PosTextSize.size1,
//               width: PosTextSize.size1,
//             )),
//       ]);
//       bytes += generator.feed(1);

//       // Add formatted date and time
//       bytes += generator.row([
//         PosColumn(
//             width: 6,
//             text: 'Date: $formattedDate',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         PosColumn(
//             width: 6,
//             text: 'Time: $formattedTime',
//             styles:
//                 const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

//       bytes += generator.row([
//         PosColumn(
//             width: 6,
//             text: 'Branch : Aranmanai',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         PosColumn(
//             width: 6,
//             text: 'Bill No : 102',
//             styles:
//                 const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

// // Print Sales Person and Customer Number on the same line
//       bytes += generator.row([
//         PosColumn(
//             width: 6,
//             text: 'Sales Person : test',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         PosColumn(
//             width: 6,
//             text: 'Customer No: $customerNumber',
//             styles:
//                 const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);

//       // Add headers for S.No, Item, Price, Qty, and Amount
//       bytes += generator.row([
//         PosColumn(
//             width: 1,
//             text: 'S.No',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         PosColumn(
//             width: 5,
//             text: 'Item',
//             styles: const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//         PosColumn(
//             width: 2,
//             text: '',
//             styles:
//                 const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         PosColumn(
//             width: 1,
//             text: '',
//             styles:
//                 const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         PosColumn(
//             width: 3,
//             text: 'Amount',
//             styles:
//                 const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.feed(1);
//       double totalSGST = 0.0;
//       double totalCGST = 0.0;
//       double taxVaule = 0.0;
//       Map<double, double> sgstMap = {};
//       Map<double, double> cgstMap = {};

//       // Process each item
//       for (var item in cartItems) {
//         // Assuming tax is fetched as dynamic or int, ensure it's treated as double
//         double taxRate = (item['itemData']['tax'] as num)
//             .toDouble(); // num can be both int and double
//         double itemTotal = cartProvider
//             .calculateItemTotal(item)
//             .toDouble(); // Ensure itemTotal is a double

//         double itemTax = itemTotal * (taxRate / 100);
//         double itemSGST = itemTax / 2;
//         double itemCGST = itemSGST;

//         // Update the maps with doubles
//         sgstMap[taxRate / 2] = (sgstMap[taxRate / 2] ?? 0.0) + itemSGST;
//         cgstMap[taxRate / 2] = (cgstMap[taxRate / 2] ?? 0.0) + itemCGST;
//       }

//       // Adding cart items with item name, quantity, and price in the desired format
//       for (int i = 0; i < cartItems.length; i++) {
//         final item = cartItems[i];

//         final String itemName = item['itemData']['itemName'] ?? 'N/A';
//         final String varianceName =
//             item['varianceData']['varianceName'] ?? 'N/A';
//         final double price =
//             item['varianceData']['variance_Defaultprice']?.toDouble() ?? 0.0;
//         final double weight = (item['weight'] ?? 0.0).toDouble();
//         final double qty = (item['quantity'] as num)?.toDouble() ?? 0.0;
//         final double amount = cartProvider.calculateItemTotal(item);
//         final double tax = (item['itemData']['tax'] as num).toDouble();
//         final String uom = item['varianceData']['variance_Uom'] ?? 'N/A';
//         String quantityDisplay = cartProvider.buildQuantityPriceDisplay(item);
//         // Get the tax percentage for the item
//         final double itemTotal = cartProvider.calculateItemTotal(item);
//         double taxPercentage = (item['itemData']['tax'] as num).toDouble();
//         // Calculate SGST and CGST
//         double itemTax = itemTotal * (taxPercentage / 100);
//         double itemSGST = itemTax / 2;
//         double itemCGST = itemTax / 2;

//         totalSGST = itemSGST;
//         totalCGST = itemCGST;
//         taxVaule = taxPercentage; // Sum up item total + taxes

//         // Log the quantityDisplay to the console
//         developer.log('Printing Receipt...');
//         developer.log('HiveInvoiceId:');
//         developer.log('Item: $itemName');
//         developer.log('Variance: $varianceName');
//         developer.log('Price: Rs ${price.toStringAsFixed(0)}');
//         developer.log('Weight: $weight');
//         developer.log('Quantity: $quantityDisplay');
//         developer.log('Qty: $qty');
//         developer.log('Amount: Rs ${amount.toStringAsFixed(0)}');
//         developer.log('Tax: $tax%');
//         developer.log('UOM: $uom');
//         developer.log('users: ');
//         developer.log('totalAmount: ');
//         developer.log('totalAmount2: ');
//         developer.log('totalAmount3: ');
//         developer.log('status: Active ');
//         developer.log('branchid:');
//         developer.log('branchName:');
//         developer.log('cash: ');
//         developer.log('upi:');
//         developer.log('card:');
//         developer.log('others:');
//         developer.log('invoiceDate:');
//         developer.log('invoiceTime:');
//         developer.log('invoiceNumber:');
//         developer.log('branchid:');
//         developer.log('branchName:');
//         developer.log('shiftId:');
//         developer.log('shiftNumber:');
//         developer.log('deviceNumber:');
//         developer.log('Employee Number: $employeeNumber');
//         developer.log('Customer Number: $customerNumber');
//         developer.log('Discount: ${_discountController.text}%');
//         developer.log('Custom Charge: Rs ${_customChargeController.text}');
//         developer.log('Selected Payment: $_selectedPaymentOption');
//         developer.log('Payment Amount: $paymentAmount');

//         String hiveInvoiceId = generateShortHiveInvoiceId();
//         Map<String, dynamic> invoiceData = {
//           'HiveInvoiceId': hiveInvoiceId,
//           'employeeNumber': employeeNumber,
//           'customerNumber': customerNumber,
//           'discount': _discountController.text,
//           'customCharge': _customChargeController.text,
//           'totalAmount': widget.totalAmount,
//           'date': DateTime.now().toIso8601String(),
//           'paymentMethod': _selectedPaymentOption,
//           'paymentAmount': paymentAmount,
//         };

//         // Save the data to Hive

//         // Open the Hive box
//         var box = await Hive.openBox('invoiceBox');
//         await box.add(invoiceData); // Save invoice data to Hive

//         // Show a snackbar to confirm saving
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Invoice $hiveInvoiceId saved successfully')),
//         );
//         saveInvoiceToHiveAndPrint();
//         Navigator.of(context).pop();
//         cartProvider.clearItems();
//         // saveInvoiceToHiveAndPrint();
//         // if (kDebugMode) {
//         //   print("caststst $item");
//         // }
//         // Split item name if it exceeds the maximum width
//         List<String> itemNameLines =
//             splitText(item['varianceData']['varianceName'] ?? '', 15);

//         // Main item name
//         bytes += generator.row([
//           PosColumn(
//               width: 1,
//               text: (i + 1).toString(), // S.No
//               styles:
//                   const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           PosColumn(
//               width: 8,
//               text: itemNameLines[0], // First line of item name
//               styles:
//                   const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           PosColumn(
//               width: 3,
//               text:
//                   "Rs ${cartProvider.calculateItemTotal(item).toStringAsFixed(0)}", // Price
//               styles:
//                   const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);

//         // If there are additional lines for the item name, print them below
//         if (itemNameLines.length > 1) {
//           for (int j = 1; j < itemNameLines.length; j++) {
//             bytes += generator.row([
//               PosColumn(
//                   width: 1,
//                   text: '',
//                   styles: const PosStyles(align: PosAlign.left)),
//               PosColumn(
//                   width: 8,
//                   text: itemNameLines[j], // Additional line of item name
//                   styles: const PosStyles(
//                       align: PosAlign.left, codeTable: 'CP1252')),
//               PosColumn(
//                   width: 3,
//                   text: '',
//                   styles: const PosStyles(align: PosAlign.right)),
//             ]);
//           }
//         }

//         // Quantity and unit price (for kg, pcs, etc.)
//         bytes += generator.row([
//           PosColumn(
//               width: 1,
//               text: '',
//               styles: const PosStyles(align: PosAlign.left)),
//           PosColumn(
//               width: 8,
//               text:
//                   "(${item['quantity']} ${item['varianceData']['variance_Uom']} x ${item['varianceData']['variance_Defaultprice']} ${item['itemData']['tax']}%)", // Quantity and unit price
//               styles:
//                   const PosStyles(align: PosAlign.left, codeTable: 'CP1252')),
//           PosColumn(
//               width: 3,
//               text: "", // Total amount
//               styles:
//                   const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);

//         // Add an empty row for spacing between items
//         bytes += generator.row([
//           PosColumn(
//               width: 12,
//               text: '',
//               styles: const PosStyles(align: PosAlign.center)),
//         ]);
//       }

//       // Adding totals and other details
//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: '----------------------------------------------',
//             styles:
//                 const PosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//       ]);
//       // Display the discount amount and percentage
//       if (_discountController.text == 0) {
//         bytes += generator.row([
//           PosColumn(
//               width: 12,
//               text:
//                   "Discount: $discountPercentage% (-Rs ${discountAmount.toStringAsFixed(0)})",
//               styles:
//                   const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);
//       }
//       // Print Custom Charge
//       if (_customChargeController.text == 0) {
//         bytes += generator.row([
//           PosColumn(
//               width: 12,
//               text: "Custom Charge: Rs ${customCharge.toStringAsFixed(0)}",
//               styles:
//                   const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//         ]);
//       }

//       // Find the section where the payment details are printed and adjust it:
//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text:
//                 "$_selectedPaymentOptionVaule: ${widget.totalAmount.toStringAsFixed(0)}",
//             styles:
//                 const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text:
//                 "Total : Rs ${cartProvider.calculateTotal().toStringAsFixed(0)}",
//             styles:
//                 const PosStyles(align: PosAlign.right, codeTable: 'CP1252')),
//       ]);
//       // Print SGST and CGST details
//       // Right-aligning SGST and CGST using generator.row()
//       sgstMap.forEach((rate, amount) {
//         bytes += generator.row([
//           PosColumn(
//               text:
//                   "SGST (${rate.toStringAsFixed(1)}%): Rs ${amount.toStringAsFixed(2)}",
//               width: 12, // Assuming a width of 12 for full row width
//               styles: PosStyles(align: PosAlign.right))
//         ]);
//       });
//       cgstMap.forEach((rate, amount) {
//         bytes += generator.row([
//           PosColumn(
//               text:
//                   "CGST (${rate.toStringAsFixed(1)}%): Rs ${amount.toStringAsFixed(2)}",
//               width: 12, // Full width
//               styles: PosStyles(align: PosAlign.right))
//         ]);
//       });

//       // Add these lines where you're preparing the rest of the receipt details
//       // Inside _printReceiptDetails function

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: '----------------------------------------------',
//             styles:
//                 const PosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//       ]);

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Thank You ! Visit Again !',
//             styles:
//                 const PosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//       ]);

//       // Inside _printReceiptDetails function
//       bytes += generator.feed(1);

//       const int maxLineWidth = 18;
//       List<String> addressLines = splitAddress(
//           "No.45, Raja Veethi, Aranmanai, Ramanathapuram, Tamil Nadu-623501");

//       for (int i = 0; i < addressLines.length; i++) {
//         bytes += generator.row([
//           PosColumn(
//             width: 12,
//             text: addressLines[i],
//             styles: const PosStyles(
//               align: PosAlign.center, // Center the text
//               codeTable: 'CP1252',
//             ),
//           ),
//         ]);
//       }

//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'GST : 33AATFB12B1ZW',
//             styles:
//                 const PosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'FSSAI : 1242000',
//             styles:
//                 const PosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.row([
//         PosColumn(
//             width: 12,
//             text: 'Phone : 9342978427',
//             styles:
//                 const PosStyles(align: PosAlign.center, codeTable: 'CP1252')),
//       ]);
//       bytes += generator.feed(1);

//       bytes += generator.feed(1);

//       printer
//           .rawBytes(Uint8List.fromList(bytes)); // Send the bytes to the printer
//       printer.feed(2); // Ensure proper spacing at the end
//       printer.cut();

//       // Add a delay to ensure the printer completes the print job
//       // await Future.delayed(const Duration(seconds: 2));

//       printer
//           .disconnect(); // Disconnect the printer only after ensuring the print is complete
//     } else {
//       print('Could not connect to printer: ${res.msg}');
//     }
//   }

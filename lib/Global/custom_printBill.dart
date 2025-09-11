import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart'; // Import this for PaperSize, PosStyles, etc.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// import '../../../data/global_data_manager.dart';
import '../screens/invoice_pay_and_print_page.dart/widgets/custom_pos_column.dart';
import '../screens/regular_mode_page/provider/cart_page_provider.dart';

class ReceiptPrinterWidget extends StatelessWidget {
  final TextEditingController? employeeNumberController;
  final TextEditingController? customerNumberController;
  final TextEditingController? discountController;
  final TextEditingController? customChargeController;
  final String? selectedPaymentOptionValue;
  final double? totalAmount;
  final BuildContext context;
  final TextEditingController? customAmountController;
  final String? selectedPaymentOption;
  final Function? saveInvoiceToHiveAndPrint;

  // New fields for return data
  final List<String>? returnItemNames;
  final List<double>? returnQuantities;
  final List<double>? returnAmounts;

  ReceiptPrinterWidget({
    this.employeeNumberController,
    this.customerNumberController,
    this.discountController,
    this.customChargeController,
    this.selectedPaymentOptionValue,
    this.totalAmount,
    required this.context,
    this.customAmountController,
    this.selectedPaymentOption,
    this.saveInvoiceToHiveAndPrint,
    // Initialize return fields
    this.returnItemNames,
    this.returnQuantities,
    this.returnAmounts,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        await salesprintReceiptDetails();
      },
      child: const Text('Print Receipt'),
    );
  }

  Future<void> salesprintReceiptDetails() async {


    if (selectedPaymentOption == 'Cash: Custom' &&
        (customAmountController?.text.isNotEmpty ?? false)) {
// Ensuring single currency symbol
    } else if (selectedPaymentOption?.contains('') ?? false) {
    } else {}

    var cartProvider = Provider.of<CurrentSaleProvider>(context, listen: false);


    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final PosPrintResult res =
        await printer.connect('192.168.1.87', port: 9100);

    if (res == PosPrintResult.success) {
      List<int> bytes = [];
      final generator = Generator(PaperSize.mm80, profile);

      // Generate receipt header and print cart items
      bytes += _generateReceiptHeader(generator, cartProvider);

      // Now, add returned items to the receipt (if any)
      if (returnItemNames != null && returnItemNames!.isNotEmpty) {
        bytes += generator.feed(1);
        bytes += generator.row([
          createPosColumn(
            width: 12,
            text: 'Returned Items',
            styles: createPosStyles(align: PosAlign.center),
          ),
        ]);
        for (int i = 0; i < returnItemNames!.length; i++) {
          bytes += generator.row([
            createPosColumn(
              width: 6,
              text: returnItemNames![i],
              styles: createPosStyles(align: PosAlign.left),
            ),
            createPosColumn(
              width: 3,
              text: 'Qty: ${returnQuantities![i].toStringAsFixed(0)}',
              styles: createPosStyles(align: PosAlign.right),
            ),
            createPosColumn(
              width: 3,
              text: '${returnAmounts![i].toStringAsFixed(0)}',
              styles: createPosStyles(align: PosAlign.right),
            ),
          ]);
        }
      }

      // Print the rest of the receipt
      printer
          .rawBytes(Uint8List.fromList(bytes)); // Send the bytes to the printer
      printer.cut();

      printer.disconnect();
    } else {
    
    }

    Navigator.of(context).pop();
    cartProvider.clearItems();
  }

  List<int> _generateReceiptHeader(
      Generator generator, CurrentSaleProvider cartProvider) {
    List<int> bytes = [];
    // Header content like business name, date, time, etc.
    bytes += generator.row([
      createPosColumn(
          width: 12,
          text: 'BestMummy',
          styles: createPosStyles(
            align: PosAlign.center,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          )),
    ]);
    bytes += generator.row([
      createPosColumn(
          width: 6,
          text: 'Branch : Aranmanai',
          styles: createPosStyles(align: PosAlign.left)),
      createPosColumn(
          width: 6,
          text: 'Bill No : 102',
          styles: createPosStyles(align: PosAlign.right)),
    ]);

    return bytes;
  }
}

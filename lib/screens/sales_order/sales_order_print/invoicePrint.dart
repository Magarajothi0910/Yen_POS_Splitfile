import 'package:flutter/material.dart';

import '../../../Global/allorderprint.dart';
import '../globals.dart' as globals;
import '../screens/model/sales_invoicemodel.dart';

class SalesInvoiceReceiptPrinter with ChangeNotifier {
  Map<String, dynamic>? receiptData;
  late salesInvoiceReceiptPrinter receiptPrinter;

  SalesInvoiceReceiptPrinter() {
    receiptPrinter = salesInvoiceReceiptPrinter(
      employeeNameController: TextEditingController(),
      customerNumberController: TextEditingController(),
      discountController: 0.0,
      customChargeController: 0.0,
      selectedPaymentOptionValue: '',
      totalAmount: 0.0,
      advanceAmount: 0.0,
      balanceAmount: 0.0,
      customerType: '',
      deliveryDateprint: '',
      deliveryTimeprint: '',
      customAmountController: TextEditingController(),
      selectedPaymentOption: '',
    );
  }

  void updateReceiptData(Map<String, dynamic> orderData) {

    final data = orderData['data'] ?? {}; // Access the nested map safely

    receiptPrinter.employeeNameController.text = data['employeeName'] ?? '';
    receiptPrinter.customerNumberController.text = data['customerNumber'] ?? '';

    receiptPrinter.discountController = (data['discount'] ?? 0.0).toDouble();
    receiptPrinter.customChargeController =
        (data['customCharge'] ?? 0.0).toDouble();
    receiptPrinter.selectedPaymentOptionValue = data['paymentOption'] ?? '';
    receiptPrinter.totalAmount = (data['totalAmount'] ?? 0.0).toDouble();

    receiptPrinter.advanceAmount =
        (data['advanceAmount'] is List && data['advanceAmount'].isNotEmpty)
            ? (data['advanceAmount'][0] ?? 0.0).toDouble()
            : 0.0;

    receiptPrinter.balanceAmount = (data['balanceAmount'] ?? 0.0).toDouble();
    receiptPrinter.customerType = data['customerType'] ?? '';
    receiptPrinter.deliveryDateprint = data['deliveryDate'] ?? '';
    receiptPrinter.deliveryTimeprint = data['deliveryTime'] ?? '';
    receiptPrinter.customAmountController.text =
        data['customAmount']?.toString() ?? '';

    receiptPrinter.selectedPaymentOption =
        (data['advancePaymentType'] is List &&
                data['advancePaymentType'].isNotEmpty)
            ? data['advancePaymentType'][0] ?? ''
            : '';

    String advanceDateTime =
        (data['advanceDateTime'] is List && data['advanceDateTime'].isNotEmpty)
            ? data['advanceDateTime'][0].toString()
            : '';

    // Update cart items
    globals.invoiceItems = [];
    if (data.containsKey('varianceName') && data['varianceName'] is List) {
      for (int i = 0; i < data['varianceName'].length; i++) {
        globals.invoiceItems.add(
          SalesOrderItem(
            itemName: (data['itemName'].length > i ? data['itemName'][i] : ''),
            varianceName: data['varianceName'][i] ?? '',
            itemCode: (data['itemCode'].length > i ? data['itemCode'][i] : ''),
            qty: (data['qty'].length > i ? data['qty'][i] : 0).toInt(),
            tax: (data['tax'].length > i ? data['tax'][i] : 0).toInt(),
            uom: (data['uom'].length > i ? data['uom'][i] : ''),
            price: (data['price'].length > i ? data['price'][i] : 0).toDouble(),
            weight: (data['weight'].length > i ? data['weight'][i] : 0.0)
                .toDouble(),
            amount:
                (data['amount'].length > i ? data['amount'][i] : 0).toDouble(),
          ),
        );
      }
    }


    printReceipt();
    notifyListeners();
  }

  Future<void> printReceipt() async {
    try {
      // if (!context.mounted) {
      //   return;
      // }
      await receiptPrinter.printReceiptDetails();
    } catch (e) {
    }
  }
}

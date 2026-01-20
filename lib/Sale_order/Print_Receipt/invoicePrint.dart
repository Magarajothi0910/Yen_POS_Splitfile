

import 'package:flutter/material.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Sale_order/Models/sales_invoicemodel.dart';
import 'package:yenpos/Sale_order/Print_Receipt/allorderprint.dart';
import 'package:yenpos/printer_screen/provider/printer_config_provider.dart';

class SalesInvoiceReceiptPrinter with ChangeNotifier {
  Map<String, dynamic>? receiptData;
  late salesInvoiceReceiptPrinter receiptPrinter;
  final PrinterProviderpos printerProvider;

  SalesInvoiceReceiptPrinter({required this.printerProvider}) {
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
      cashAmount: 0.0,
      cardAmount: 0.0,
      upiAmount: 0.0,
      invoiceNo: '',
      saleOrderNo: "",
      printerProvider: printerProvider,
      salesReturnNo: '',
      salesType: '',
    );
  }

  num safeNum(value) {
    if (value == null) return 0;
    if (value is int || value is double) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  void updateReceiptData(Map<String, dynamic> orderData) {

    final data = orderData.containsKey('data') && orderData['data'] is Map
        ? orderData['data']
        : orderData;

    try {
      // 👤 Employee & Customer
      receiptPrinter.employeeNameController.text =
          data['salesPersonName']?.toString() ?? '';
      receiptPrinter.customerNumberController.text =
          data['customerPhoneNumber']?.toString() ?? '';


      // 💸 Discount & Custom Charge
      receiptPrinter.discountController =
          (data['discountPercentage'] ?? data['discountAmount'] ?? 0.0)
              .toDouble();
      receiptPrinter.customChargeController = () {
        final value = data['customCharge'];

        if (value is List && value.isNotEmpty) {
          return safeNum(value.first).toDouble();
        } else {
          return safeNum(value).toDouble();
        }
      }();


      // 💰 Payment
      receiptPrinter.selectedPaymentOptionValue =
          data['paymentOption']?.toString() ?? '';
      receiptPrinter.totalAmount = safeNum(data['totalAmount']).toDouble();
      receiptPrinter.cashAmount = safeNum(data['cash']).toDouble();
      receiptPrinter.cardAmount = safeNum(data['card']).toDouble();
      receiptPrinter.upiAmount = safeNum(data['upi']).toDouble();


      // 💰 Advance
      if (data['advanceAmount'] is List && data['advanceAmount'].isNotEmpty) {
        receiptPrinter.advanceAmount = safeNum(
          data['advanceAmount'][0],
        ).toDouble();
      } else {
        receiptPrinter.advanceAmount = safeNum(
          data['advanceAmount'],
        ).toDouble();
      }

      // 📄 Invoice Info
      receiptPrinter.balanceAmount = safeNum(data['balanceAmount']).toDouble();
      receiptPrinter.customerType = data['customerType']?.toString() ?? '';
      receiptPrinter.invoiceNo = data['invoiceNo']?.toString() ?? '';
      receiptPrinter.saleOrderNo = data['saleOrderNo']?.toString() ?? '';


      receiptPrinter.salesReturnNo = data['salesReturnNo']?.toString() ?? '';
      receiptPrinter.salesType = data['salesType']?.toString() ?? '';


      // 🚚 Delivery
      receiptPrinter.deliveryDateprint = data['deliveryDate']?.toString() ?? '';
      receiptPrinter.deliveryTimeprint = data['deliveryTime']?.toString() ?? '';
      receiptPrinter.customAmountController.text =
          data['customAmount']?.toString() ?? '';


      // 🏦 Advance Payment Type
      if (data['advancePaymentType'] is List &&
          data['advancePaymentType'].isNotEmpty) {
        receiptPrinter.selectedPaymentOption =
            data['advancePaymentType'][0]?.toString() ?? '';
      } else {
        receiptPrinter.selectedPaymentOption =
            data['advancePaymentType']?.toString() ?? '';
      }


      // 📦 Items
      globals.invoiceItems = [];

      if (data.containsKey('varianceName') && data['varianceName'] is List) {
        int totalItems = data['varianceName'].length;

        for (int i = 0; i < totalItems; i++) {
          try {
            final item = SalesOrderItem(
              itemName:
                  (data['itemName'] is List && data['itemName'].length > i)
                  ? data['itemName'][i]
                  : '',
              varianceName: data['varianceName'][i] ?? '',
              itemCode:
                  (data['itemCode'] is List && data['itemCode'].length > i)
                  ? data['itemCode'][i]
                  : '',
              qty: safeNum(
                (data['qty'] is List && data['qty'].length > i)
                    ? data['qty'][i]
                    : 0,
              ).toInt(),
              tax: safeNum(
                (data['tax'] is List && data['tax'].length > i)
                    ? data['tax'][i]
                    : 0,
              ).toDouble(),
              uom: (data['uom'] is List && data['uom'].length > i)
                  ? data['uom'][i]
                  : '',
              price: safeNum(
                (data['price'] is List && data['price'].length > i)
                    ? data['price'][i]
                    : 0,
              ).toDouble(),
              weight: safeNum(
                (data['weight'] is List && data['weight'].length > i)
                    ? data['weight'][i]
                    : 0,
              ).toDouble(),
              amount: safeNum(
                (data['amount'] is List && data['amount'].length > i)
                    ? data['amount'][i]
                    : 0,
              ).toDouble(),
            );

            globals.invoiceItems.add(item);

          } catch (itemErr, st) {}
        }
      } else {}

      // 🖨️ Print
      printReceipt();

      notifyListeners();
    } catch (e, st) {}
  }

  Future<void> printReceipt() async {
    try {
      await receiptPrinter.printReceiptDetails();
    } catch (e, st) {}
  }
}

import 'package:flutter/material.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Sale_order/Models/sales_invoicemodel.dart';
import 'package:yenpos/Sale_order/Print_Receipt/allorderprint.dart';

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
      cashAmount: 0.0,
      cardAmount: 0.0,
      upiAmount: 0.0,
      invoiceNo: '',
    );
  }
  num safeNum(value) {
    if (value == null) return 0;
    if (value is int || value is double) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  void updateReceiptData(Map<String, dynamic> orderData) {
    debugPrint(
      "🟦 [updateReceiptData] Called with orderData: ${orderData.keys.toList()}",
    );

    // ✅ FIX: Handle both nested and top-level data structures
    final data = orderData.containsKey('data') && orderData['data'] is Map
        ? orderData['data']
        : orderData;

    debugPrint("📦 Extracted data keys: ${data.keys.toList()}");

    try {
      // 🔹 Employee & Customer Info
      receiptPrinter.employeeNameController.text =
          data['salesPersonName']?.toString() ?? '';
      receiptPrinter.customerNumberController.text =
          data['customerPhoneNumber']?.toString() ?? '';
      debugPrint(
        "👤 Employee: ${receiptPrinter.employeeNameController.text}, "
        "Customer: ${receiptPrinter.customerNumberController.text}",
      );

      // 🔹 Discount & Custom Charge
      receiptPrinter.discountController =
          (data['discountPercentage'] ?? data['discountAmount'] ?? 0.0)
              .toDouble();
      receiptPrinter.customChargeController = (data['customCharge'] ?? 0.0)
          .toDouble();
      debugPrint(
        "💸 Discount: ${receiptPrinter.discountController}, "
        "CustomCharge: ${receiptPrinter.customChargeController}",
      );

      // 🔹 Payment & Amounts
      receiptPrinter.selectedPaymentOptionValue =
          data['paymentOption']?.toString() ?? '';
      receiptPrinter.totalAmount = (data['totalAmount'] ?? 0.0).toDouble();
      receiptPrinter.cashAmount = (data['cash'] ?? 0.0).toDouble();
      receiptPrinter.cardAmount = (data['card'] ?? 0.0).toDouble();
      receiptPrinter.upiAmount = (data['upi'] ?? 0.0).toDouble();

      debugPrint(
        "💰 Payment Option: ${receiptPrinter.selectedPaymentOptionValue}",
      );
      debugPrint(
        "💵 Cash: ${receiptPrinter.cashAmount}, "
        "💳 Card: ${receiptPrinter.cardAmount}, 🆙 UPI: ${receiptPrinter.upiAmount}",
      );
      debugPrint("📊 Total Amount: ${receiptPrinter.totalAmount}");

      // 🔹 Advance Amount
      if (data['advanceAmount'] is List && data['advanceAmount'].isNotEmpty) {
        receiptPrinter.advanceAmount = (data['advanceAmount'][0] ?? 0.0)
            .toDouble();
      } else {
        receiptPrinter.advanceAmount = (data['advanceAmount'] ?? 0.0)
            .toDouble();
      }
      debugPrint("💎 Advance Amount: ${receiptPrinter.advanceAmount}");

      // 🔹 Balance & Other Info
      receiptPrinter.balanceAmount = (data['balanceAmount'] ?? 0.0).toDouble();
      receiptPrinter.customerType = data['customerType']?.toString() ?? '';
      receiptPrinter.invoiceNo = data['invoiceNo']?.toString() ?? '';

      debugPrint(
        "📄 Invoice No: ${receiptPrinter.invoiceNo}, "
        "Balance: ${receiptPrinter.balanceAmount}, "
        "Type: ${receiptPrinter.customerType}",
      );

      // 🔹 Delivery Info
      receiptPrinter.deliveryDateprint = data['deliveryDate']?.toString() ?? '';
      receiptPrinter.deliveryTimeprint = data['deliveryTime']?.toString() ?? '';
      receiptPrinter.customAmountController.text =
          data['customAmount']?.toString() ?? '';

      debugPrint(
        "🚚 Delivery Date: ${receiptPrinter.deliveryDateprint}, "
        "Time: ${receiptPrinter.deliveryTimeprint}",
      );
      debugPrint(
        "💰 Custom Amount: ${receiptPrinter.customAmountController.text}",
      );

      // 🔹 Advance Payment Type
      if (data['advancePaymentType'] is List &&
          data['advancePaymentType'].isNotEmpty) {
        receiptPrinter.selectedPaymentOption =
            data['advancePaymentType'][0]?.toString() ?? '';
      } else {
        receiptPrinter.selectedPaymentOption =
            data['advancePaymentType']?.toString() ?? '';
      }
      debugPrint(
        "🏦 Advance Payment Type: ${receiptPrinter.selectedPaymentOption}",
      );

      // 🔹 Advance DateTime
      String advanceDateTime = '';
      if (data['advanceDateTime'] is List &&
          data['advanceDateTime'].isNotEmpty) {
        advanceDateTime = data['advanceDateTime'][0].toString();
      } else if (data['advanceDateTime'] != null) {
        advanceDateTime = data['advanceDateTime'].toString();
      }
      debugPrint("🕒 Advance DateTime: $advanceDateTime");

      // 🔹 Load Items into Globals
      globals.invoiceItems = [];
      debugPrint("🧾 Starting to load invoice items...");

      if (data.containsKey('varianceName') && data['varianceName'] is List) {
        int totalItems = data['varianceName'].length;
        debugPrint("📋 Found $totalItems items in order data");

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
            debugPrint(
              "✅ Added item ${i + 1}: ${item.itemName} | Qty: ${item.qty}, Price: ${item.price}, Amount: ${item.amount}",
            );
          } catch (itemErr) {
            debugPrint("❌ Error adding item at index $i → $itemErr");
          }
        }
      } else {
        debugPrint("⚠️ No valid 'varianceName' list found in data");
      }

      debugPrint(
        "✅ Total items loaded into globals.invoiceItems: ${globals.invoiceItems.length}",
      );

      // 🔹 Print Receipt
      debugPrint("🖨️ Initiating printReceipt()...");
      printReceipt();

      // 🔹 Notify Listeners
      debugPrint("📢 Notifying listeners...");
      notifyListeners();

      debugPrint("🎉 [updateReceiptData] Completed Successfully!");
    } catch (e, st) {
      debugPrint("🚨 [updateReceiptData] ERROR: $e");
      debugPrint("📜 Stack Trace: $st");
    }
  }

  Future<void> printReceipt() async {
    try {
      debugPrint("🖨️ [printReceipt] Printing started...");
      await receiptPrinter.printReceiptDetails();

      debugPrint("✅ [printReceipt] Printing completed and connection closed.");
    } catch (e, st) {
      debugPrint("🚨 [printReceipt] ERROR: $e");
      debugPrint("📜 Stack Trace: $st");
    }
  }
}

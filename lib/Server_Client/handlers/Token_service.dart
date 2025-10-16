import 'dart:math';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';


Future<String> generatehiveInvoiceId(String branchName) async {
  print("🚀 [generatehiveInvoiceId] Called with branchName: $branchName");

  final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
  final currentDate1 = DateFormat('ddMMyy').format(DateTime.now());
  print(
      "📅 [generatehiveInvoiceId] currentDate: $currentDate | currentDate1: $currentDate1");

  var invoiceBox = await Hive.openBox('invoices');
  print("📂 [generatehiveInvoiceId] Opened Hive box: invoices");

  String lastInvoiceDate = invoiceBox.get('lastInvoiceDate', defaultValue: "");
  int invoiceCounter = invoiceBox.get('invoiceCounter', defaultValue: 0);
  print(
      "📊 [generatehiveInvoiceId] lastInvoiceDate: $lastInvoiceDate | invoiceCounter: $invoiceCounter");

  // Reset or increment counter
  if (lastInvoiceDate != currentDate || invoiceCounter == 0) {
    invoiceCounter = 1;
    print("🔄 [generatehiveInvoiceId] Reset invoice counter to 1");
  } else {
    invoiceCounter++;
    print(
        "➕ [generatehiveInvoiceId] Incremented invoice counter to $invoiceCounter");
  }

  String hiveInvoiceId =
      'BM/${branchName}${currentDate1}KOTINVOICE${invoiceCounter.toString().padLeft(3, '0')}';
  print("✅ [generatehiveInvoiceId] Generated hiveInvoiceId: $hiveInvoiceId");

  // Save back to Hive
  await invoiceBox.put('invoiceCounter', invoiceCounter);
  await invoiceBox.put('lastInvoiceDate', currentDate);
  print(
      "💾 [generatehiveInvoiceId] Saved invoiceCounter and lastInvoiceDate to Hive");

  return hiveInvoiceId;
}

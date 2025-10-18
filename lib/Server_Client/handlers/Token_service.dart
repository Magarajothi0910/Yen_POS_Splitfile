import 'dart:math';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';


Future<String> generatehiveInvoiceId(String branchName) async {

  final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
  final currentDate1 = DateFormat('ddMMyy').format(DateTime.now());

  var invoiceBox = await Hive.openBox('invoices');

  String lastInvoiceDate = invoiceBox.get('lastInvoiceDate', defaultValue: "");
  int invoiceCounter = invoiceBox.get('invoiceCounter', defaultValue: 0);

  // Reset or increment counter
  if (lastInvoiceDate != currentDate || invoiceCounter == 0) {
    invoiceCounter = 1;
  } else {
    invoiceCounter++;
  }

  String hiveInvoiceId =
      'BM/${branchName}${currentDate1}KOTINVOICE${invoiceCounter.toString().padLeft(3, '0')}';

  // Save back to Hive
  await invoiceBox.put('invoiceCounter', invoiceCounter);
  await invoiceBox.put('lastInvoiceDate', currentDate);

  return hiveInvoiceId;
}

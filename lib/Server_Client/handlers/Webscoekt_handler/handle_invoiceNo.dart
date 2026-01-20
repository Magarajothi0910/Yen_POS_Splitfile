import 'package:hive/hive.dart';

Future<void> handleInvoiceNo(Map<String, dynamic> jsonData) async {
  final invoiceNoKey = jsonData['invNoKeys'];
  final invoiceNoValue = jsonData['invNoValues'];
  final invoiceNo = await Hive.openBox('invoiceNo');
  if (invoiceNo.values.contains(invoiceNoValue)) {
  } else {
    invoiceNo.put(invoiceNoKey, invoiceNoValue);
  }
}

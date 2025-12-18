// // models/pending_print_invoice.dart
// import 'package:hive/hive.dart';

// part 'pending_print.g.dart';

// @HiveType(typeId: 11)  // ← MUST BE 11 (same as adapter below)
// class PendingPrintInvoice extends HiveObject {
//   @HiveField(0)
//   final String invoiceNo;

//   @HiveField(1)
//   final DateTime timestamp;

//   @HiveField(2)
//   final Map<String, dynamic> printData;

//   PendingPrintInvoice({
//     required this.invoiceNo,
//     required this.timestamp,
//     required this.printData,
//   });
// }
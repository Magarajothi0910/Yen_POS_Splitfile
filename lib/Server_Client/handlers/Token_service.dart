// import 'package:hive/hive.dart';
// import 'package:intl/intl.dart';

// final String _prefix = "33BM";

// Future<String> generateInvoiceId(String aliasName) async {
//   // Open Hive box
//   var invoiceBox = await Hive.openBox('invoices');

//   // Get current date formats
//   final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
//   final serverDate = DateTime.now(); // Replace with server date if needed

//   // Handle invoice counter
//   int invoiceCounter = invoiceBox.get('invoiceCounter', defaultValue: 0);
//   String lastInvoiceDate = invoiceBox.get('lastInvoiceDate', defaultValue: "");

//   if (lastInvoiceDate != currentDate || invoiceCounter == 0) {
//     invoiceCounter = 1; // reset counter for new day
//   } else {
//     invoiceCounter++;
//   }

//   // Compute financial year code
//   int fyStartYear = serverDate.year;
//   if (serverDate.month < 4) fyStartYear -= 1; // Jan–Mar belong to previous FY
//   String fyCode =
//       '${fyStartYear.toString().substring(2)}${(fyStartYear + 1).toString().substring(2)}';

//   // Get next invoice sequence for financial year
//   int currentCount = invoiceBox.get(fyCode, defaultValue: 0);
//   int nextCount = currentCount + 1;
//   await invoiceBox.put(fyCode, nextCount);

//   // Generate final invoice ID
//   String countStr = nextCount.toString().padLeft(6, '0');
//   String invoiceId = '$_prefix$aliasName$fyCode-$countStr';

//   // Save counter and last invoice date
//   await invoiceBox.put('invoiceCounter', invoiceCounter);
//   await invoiceBox.put('lastInvoiceDate', currentDate);

//   return invoiceId;
// }

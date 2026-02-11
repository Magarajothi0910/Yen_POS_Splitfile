import 'dart:math';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

int tokenCounter = 1;
String lastTokenDate = "";
Map<String, String> seathiveOrderIds = {};

int generateTokenNumber() {
  final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
  if (lastTokenDate != currentDate) {
    tokenCounter = 1; // Reset the token counter for a new day
    lastTokenDate = currentDate;
    saveTokenCounterToHive(tokenCounter, lastTokenDate);
  }
  print('Generating token number: $tokenCounter for date: $currentDate');
  int tokenNumber = tokenCounter;
  tokenCounter++;
  saveTokenCounterToHive(tokenCounter, lastTokenDate);
  return tokenNumber;
}

Future<void> saveTokenCounterToHive(int token, String date) async {
  var tokenBox = await Hive.openBox('tokenBox');
  await tokenBox.put('tokenCounter', token);
  await tokenBox.put('lastTokenDate', date);
  print('Token counter and date saved to Hive: $token, $date');
}

Future<int> getTokenCounterFromHive() async {
  var tokenBox = await Hive.openBox('tokenBox');
  int token = tokenBox.get('tokenCounter', defaultValue: 1);
  lastTokenDate = tokenBox.get('lastTokenDate', defaultValue: "");
  final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
  if (lastTokenDate != currentDate) {
    token = 1; // Reset the counter if the date has changed
    lastTokenDate = currentDate;
  }

  print('Token counter retrieved from Hive: $token');
  return token;
}

Future<void> initTokenCounter() async {
  var tokenBox = await Hive.openBox('tokenBox');
  tokenCounter = tokenBox.get('tokenCounter', defaultValue: 1);
  lastTokenDate = tokenBox.get('lastTokenDate', defaultValue: "");

  final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
  if (lastTokenDate != currentDate) {
    tokenCounter = 1;
    lastTokenDate = currentDate;
    await saveTokenCounterToHive(tokenCounter, lastTokenDate);
  }
}

String generatePreInvoiceId(String branchName) {
  final random = Random().nextInt(1000);
  return 'BM$branchName KOTORDER$random';
}

String generateSeathiveOrderId(String branchName, String seat) {
  final random = Random().nextInt(1000);
  final now = DateTime.now();
  final formattedDate = DateFormat('yyMMdd').format(now); // Format: YYYYMMDD
  final formattedTime = DateFormat('HHmm').format(now); // Format: HHMMSS

  return '$branchName-$seat-ORD$formattedDate$formattedTime-$random';
}

// Future<String> generatehiveOrderId(String branchName) async {
//   final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
//   final currentDate1 = DateFormat('ddMMyy').format(DateTime.now());

//   var orderBox = await Hive.openBox('orderBox');
//   String lastOrderDate = orderBox.get('lastOrderDate', defaultValue: "");
//   int orderCounter = orderBox.get('orderCounter', defaultValue: 0);

//   // If the date has changed or the counter is 0, reset the counter.
//   if (lastOrderDate != currentDate || orderCounter == 0) {
//     orderCounter = 1;
//   } else {
//     orderCounter++;
//   }

//   // Log details for debugging purposes.
//   print('Generating hiveOrderId with:');
//   print('Branch Name: $branchName');
//   print('Current Date: $currentDate');
//   print('Order Counter: $orderCounter');

//   // Ensure branchName is a valid string and concatenate it to form the hiveOrderId.
//   if (branchName is String) {
//     String hiveOrderId =
//         '${branchName}${currentDate1}KOTORDER${orderCounter.toString().padLeft(3, '0')}';
//     print('Generated hiveOrderId: $hiveOrderId');

//     // Save the new counter and date to Hive.
//     await orderBox.put('orderCounter', orderCounter);
//     await orderBox.put('lastOrderDate', currentDate);

//     return hiveOrderId;
//   } else {
//     throw Exception('Invalid branchName: $branchName');
//   }
// }

// Future<String> generatehiveInvoiceId(String branchName) async {
//   final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
//   final currentDate1 = DateFormat('ddMMyy').format(DateTime.now());

//   var invoiceBox = await Hive.openBox('invoiceBox');
//   String lastInvoiceDate = invoiceBox.get('lastInvoiceDate', defaultValue: "");
//   int invoiceCounter = invoiceBox.get('invoiceCounter', defaultValue: 0);

//   // Reset the counter if the date has changed or the counter is 0.
//   if (lastInvoiceDate != currentDate || invoiceCounter == 0) {
//     invoiceCounter = 1;
//   } else {
//     invoiceCounter++;
//   }

//   // Log details for debugging purposes.
//   print('Generating hiveInvoiceId with:');
//   print('Branch Name: $branchName');
//   print('Current Date: $currentDate');
//   print('Invoice Counter: $invoiceCounter');

//   // Ensure branchName is valid and generate the hiveInvoiceId.
//   if (branchName is String) {
//     String hiveInvoiceId =
//         'BM/${branchName}${currentDate1}KOTINVOICE${invoiceCounter.toString().padLeft(3, '0')}';
//     print('Generated hiveInvoiceId: $hiveInvoiceId');
// //EXAMPLE:BM/AR/deviceNo/orderType/year/0001
//     // Save the updated counter and date to Hive.
//     await invoiceBox.put('invoiceCounter', invoiceCounter);
//     await invoiceBox.put('lastInvoiceDate', currentDate);

//     return hiveInvoiceId;
//   } else {
//     throw Exception('Invalid branchName: $branchName');
//   }
// }

Future<String> generatehiveOrderId(String branchName) async {
  final now = DateTime.now();

  final currentDate = DateFormat('dd-MM-yyyy').format(now);
  final datePart = DateFormat('ddMMyy').format(now);
  final timePart = DateFormat('HHmmss').format(now); // hour minute second
  final milliPart = now.millisecondsSinceEpoch % 1000; // last 3 digits

  var orderBox = await Hive.openBox('orderBox');
  String lastOrderDate = orderBox.get('lastOrderDate', defaultValue: "");
  int orderCounter = orderBox.get('orderCounter', defaultValue: 0);

  // Reset counter daily
  if (lastOrderDate != currentDate || orderCounter == 0) {
    orderCounter = 1;
  } else {
    orderCounter++;
  }

  String hiveOrderId =
      '$branchName$datePart$timePart${milliPart.toString().padLeft(3, '0')}KOTORDER${orderCounter.toString().padLeft(3, '0')}';

  print('Generated hiveOrderId: $hiveOrderId');

  await orderBox.put('orderCounter', orderCounter);
  await orderBox.put('lastOrderDate', currentDate);

  return hiveOrderId;
}

Future<String> generatehiveInvoiceId(String branchName) async {
  final now = DateTime.now();

  final currentDate = DateFormat('dd-MM-yyyy').format(now);
  final datePart = DateFormat('ddMMyy').format(now);
  final timePart = DateFormat('HHmmss').format(now); // hour minute second
  final milliPart = now.millisecondsSinceEpoch % 1000; // last 3 digits

  var invoiceBox = await Hive.openBox('invoiceBox');
  String lastInvoiceDate = invoiceBox.get('lastInvoiceDate', defaultValue: "");
  int invoiceCounter = invoiceBox.get('invoiceCounter', defaultValue: 0);

  // Reset counter daily
  if (lastInvoiceDate != currentDate || invoiceCounter == 0) {
    invoiceCounter = 1;
  } else {
    invoiceCounter++;
  }

  String hiveInvoiceId =
      'BM/$branchName$datePart$timePart${milliPart.toString().padLeft(3, '0')}KOTINVOICE${invoiceCounter.toString().padLeft(3, '0')}';

  print('Generated hiveInvoiceId: $hiveInvoiceId');

  await invoiceBox.put('invoiceCounter', invoiceCounter);
  await invoiceBox.put('lastInvoiceDate', currentDate);

  return hiveInvoiceId;
}

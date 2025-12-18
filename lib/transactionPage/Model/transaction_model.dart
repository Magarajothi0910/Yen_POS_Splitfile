// // import 'dart:convert';

// // class Transaction {
// //   final String invoiceId;
// //   final List<String> varianceitemCode;
// //   final List<String> itemName;
// //   final List<String> varianceName;
// //   final List<int> price;
// //   final List<int> sellingPrice;
// //   final List<int> sellingAmount;
// //   final List<double> weight;
// //   final List<double> qty;
// //   final List<double> amount;
// //   final List<double> tax;
// //   final List<String> uom;

// //   // 💰 Financial fields
// //   final double totalAmount;
// //   final double netAmount;
// //   final double grossAmount; // ✅ renamed from crossAmount
// //   final double customCharge;
// //   final double? discountAmount;
// //   final double discountPercentage;

// //   // 🧾 GST details
// //   final List<String>? gst;
// //   final List<double>? gstValue;

// //   // 📦 Order info
// //   final String status;
// //   final String salesType;
// //   final String customerPhoneNumber;

// //   // 👨‍💼 Staff and branch info
// //   final String? salesPersonId;
// //   final String salesPersonName;
// //   final String branchId;
// //   final String branchName;
// //   final String aliasName;

// //   // 💳 Payment info
// //   final String? paymentType;
// //   final double cash;
// //   final double? card;
// //   final double? upi;
// //   final double? others;

// //   // 🕓 Metadata
// //   final DateTime? invoiceDateTime;
// //   final int? shiftNumber;
// //   final String shiftId;
// //   final String invoiceNo;
// //   final int? deviceNumber;
// //   final String? deviceCode;
// //   final List<String>? kotaddOns;
// //   final String? createdById;
// //   final String? createdByName;
// //   final DateTime? syncDateTime;

// //   Transaction({
// //     required this.invoiceId,
// //     required this.varianceitemCode,
// //     required this.itemName,
// //     required this.varianceName,
// //     required this.price,
// //     required this.sellingPrice,
// //     required this.sellingAmount,
// //     required this.weight,
// //     required this.qty,
// //     required this.amount,
// //     required this.tax,
// //     required this.uom,
// //     required this.totalAmount,
// //     required this.netAmount,
// //     required this.grossAmount,
// //     required this.status,
// //     required this.salesType,
// //     required this.customerPhoneNumber,
// //     this.salesPersonId,
// //     required this.salesPersonName,
// //     required this.branchId,
// //     required this.branchName,
// //     required this.aliasName,
// //     this.paymentType,
// //     required this.cash,
// //     this.card,
// //     this.upi,
// //     this.others,
// //     this.invoiceDateTime,
// //     this.shiftNumber,
// //     required this.shiftId,
// //     required this.invoiceNo,
// //     this.deviceNumber,
// //     required this.customCharge,
// //     this.discountAmount,
// //     required this.discountPercentage,
// //     this.deviceCode,
// //     this.kotaddOns,
// //     this.createdById,
// //     this.createdByName,
// //     this.syncDateTime,
// //     this.gst,
// //     this.gstValue,
// //   });

// //   factory Transaction.fromMap(Map<String, dynamic> map) {
// //     DateTime? parseDate(dynamic value) {
// //       if (value == null) return null;
// //       try {
// //         return DateTime.parse(value.toString());
// //       } catch (_) {
// //         return null;
// //       }
// //     }

// //     List<T> parseList<T>(dynamic input, T Function(dynamic) parser) {
// //       if (input == null) return [];
// //       if (input is List) return input.map(parser).toList();
// //       return [parser(input)];
// //     }

// //     return Transaction(
// //       invoiceId: map['invoiceId']?.toString() ?? '',
// //       varianceitemCode: parseList<String>(
// //         map['varianceitemCode'],
// //         (v) => v.toString(),
// //       ),
// //       itemName: parseList<String>(map['itemName'], (v) => v.toString()),
// //       varianceName: parseList<String>(map['varianceName'], (v) => v.toString()),
// //       price: parseList<int>(
// //         map['price'],
// //         (v) => int.tryParse(v.toString()) ?? 0,
// //       ),
// //       sellingPrice: parseList<int>(
// //         map['sellingPrice'],
// //         (v) => int.tryParse(v.toString()) ?? 0,
// //       ),
// //       sellingAmount: parseList<int>(
// //         map['sellingAmount'],
// //         (v) => int.tryParse(v.toString()) ?? 0,
// //       ),
// //       weight: parseList<double>(
// //         map['weight'],
// //         (v) => double.tryParse(v.toString()) ?? 0,
// //       ),
// //       qty: parseList<double>(
// //         map['qty'],
// //         (v) => double.tryParse(v.toString()) ?? 0,
// //       ),
// //       amount: parseList<double>(
// //         map['amount'],
// //         (v) => double.tryParse(v.toString()) ?? 0,
// //       ),
// //       tax: parseList<double>(
// //         map['tax'],
// //         (v) => double.tryParse(v.toString()) ?? 0,
// //       ),
// //       uom: parseList<String>(map['uom'], (v) => v.toString()),

// //       totalAmount: double.tryParse(map['totalAmount']?.toString() ?? '0') ?? 0,
// //       netAmount: double.tryParse(map['netAmount']?.toString() ?? '0') ?? 0,
// //       grossAmount: double.tryParse(map['grossAmount']?.toString() ?? '0') ?? 0,
// //       customCharge:
// //           double.tryParse(map['customCharge']?.toString() ?? '0') ?? 0,
// //       discountAmount: map['discountAmount'] != null
// //           ? double.tryParse(map['discountAmount'].toString())
// //           : null,
// //       discountPercentage:
// //           double.tryParse(map['discountPercentage']?.toString() ?? '0') ?? 0,

// //       gst: parseList<String>(map['gst'], (v) => v.toString()),
// //       gstValue: parseList<double>(
// //         map['gstValue'],
// //         (v) => double.tryParse(v.toString()) ?? 0,
// //       ),

// //       status: map['status']?.toString() ?? '',
// //       salesType: map['salesType']?.toString() ?? '',
// //       customerPhoneNumber: map['customerPhoneNumber']?.toString() ?? '',

// //       salesPersonId: map['salesPersonId']?.toString(),
// //       salesPersonName: map['salesPersonName']?.toString() ?? '',
// //       branchId: map['branchId']?.toString() ?? '',
// //       branchName: map['branchName']?.toString() ?? '',
// //       aliasName: map['aliasName']?.toString() ?? '',

// //       paymentType: map['paymentType']?.toString(),
// //       cash: double.tryParse(map['cash']?.toString() ?? '0') ?? 0,
// //       card: map['card'] != null
// //           ? double.tryParse(map['card'].toString())
// //           : null,
// //       upi: map['upi'] != null ? double.tryParse(map['upi'].toString()) : null,
// //       others: map['others'] != null
// //           ? double.tryParse(map['others'].toString())
// //           : null,

// //       invoiceDateTime: parseDate(map['invoiceDateTime']),
// //       shiftNumber: map['shiftNumber'] is int
// //           ? map['shiftNumber']
// //           : int.tryParse(map['shiftNumber']?.toString() ?? '0'),
// //       shiftId: map['shiftId']?.toString() ?? '',
// //       invoiceNo: map['invoiceNo']?.toString() ?? '',
// //       deviceNumber: map['deviceNumber'] is int
// //           ? map['deviceNumber']
// //           : int.tryParse(map['deviceNumber']?.toString() ?? '0'),
// //       deviceCode: map['deviceCode']?.toString(),
// //       kotaddOns: parseList<String>(map['kotaddOns'], (v) => v.toString()),
// //       createdById: map['createdById']?.toString(),
// //       createdByName: map['createdByName']?.toString(),
// //       syncDateTime: parseDate(map['syncDateTime']),
// //     );
// //   }

// //   Map<String, dynamic> toMap() {
// //     return {
// //       "invoiceId": invoiceId,
// //       "varianceitemCode": varianceitemCode,
// //       "itemName": itemName,
// //       "varianceName": varianceName,
// //       "price": price,
// //       "sellingPrice": sellingPrice,
// //       "sellingAmount": sellingAmount,
// //       "weight": weight,
// //       "qty": qty,
// //       "amount": amount,
// //       "tax": tax,
// //       "uom": uom,
// //       "totalAmount": totalAmount,
// //       "netAmount": netAmount,
// //       "grossAmount": grossAmount,
// //       "customCharge": customCharge,
// //       "discountAmount": discountAmount,
// //       "discountPercentage": discountPercentage,
// //       "gst": gst,
// //       "gstValue": gstValue,
// //       "status": status,
// //       "salesType": salesType,
// //       "customerPhoneNumber": customerPhoneNumber,
// //       "salesPersonId": salesPersonId,
// //       "salesPersonName": salesPersonName,
// //       "branchId": branchId,
// //       "branchName": branchName,
// //       "aliasName": aliasName,
// //       "paymentType": paymentType,
// //       "cash": cash,
// //       "card": card,
// //       "upi": upi,
// //       "others": others,
// //       "invoiceDateTime": invoiceDateTime?.toIso8601String(),
// //       "shiftNumber": shiftNumber,
// //       "shiftId": shiftId,
// //       "invoiceNo": invoiceNo,
// //       "deviceNumber": deviceNumber,
// //       "deviceCode": deviceCode,
// //       "kotaddOns": kotaddOns,
// //       "createdById": createdById,
// //       "createdByName": createdByName,
// //       "syncDateTime": syncDateTime?.toIso8601String(),
// //     };
// //   }

// //   @override
// //   String toString() => jsonEncode(toMap());
// // }

// import 'dart:convert';

// class Transaction {
//   final String invoiceId;
//   final List<String> varianceitemCode;
//   final List<String> itemName;
//   final List<String> varianceName;
//   final List<int> price;
//   final List<double> sellingPrice;
//   final List<double> sellingAmount;
//   final List<double> weight;
//   final List<double> qty;
//   final List<double> amount;
//   final List<double> tax;
//   final List<String> uom;

//   // 💰 Financial fields
//   final double totalAmount;
//   final double netAmount;
//   final double grossAmount;
//   final double customCharge;
//   final double? discountAmount;
//   final double discountPercentage;

//   // 🧾 GST details
//   final List<String>? gst;
//   final List<double>? gstValue;

//   // 📦 Order info
//   final String status;
//   final String salesType;
//   final String customerPhoneNumber;

//   // 👨‍💼 Staff and branch info
//   final String? salesPersonId;
//   final String salesPersonName;
//   final String branchId;
//   final String branchName;
//   final String aliasName;

//   // 💳 Payment info
//   final String? paymentType;
//   final double cash;
//   final double? card;
//   final double? upi;
//   final double? others;

//   // 🕓 Metadata
//   final DateTime? invoiceDateTime;
//   final int? shiftNumber;
//   final String shiftId;
//   final String invoiceNo;
//   final int? deviceNumber;
//   final String? deviceCode;
//   final List<String>? kotaddOns;
//   final String? createdById;
//   final String? createdByName;
//   final DateTime? syncDateTime;

//   Transaction({
//     required this.invoiceId,
//     required this.varianceitemCode,
//     required this.itemName,
//     required this.varianceName,
//     required this.price,
//     required this.sellingPrice,
//     required this.sellingAmount,
//     required this.weight,
//     required this.qty,
//     required this.amount,
//     required this.tax,
//     required this.uom,
//     required this.totalAmount,
//     required this.netAmount,
//     required this.grossAmount,
//     required this.status,
//     required this.salesType,
//     required this.customerPhoneNumber,
//     this.salesPersonId,
//     required this.salesPersonName,
//     required this.branchId,
//     required this.branchName,
//     required this.aliasName,
//     this.paymentType,
//     required this.cash,
//     this.card,
//     this.upi,
//     this.others,
//     this.invoiceDateTime,
//     this.shiftNumber,
//     required this.shiftId,
//     required this.invoiceNo,
//     this.deviceNumber,
//     required this.customCharge,
//     this.discountAmount,
//     required this.discountPercentage,
//     this.deviceCode,
//     this.kotaddOns,
//     this.createdById,
//     this.createdByName,
//     this.syncDateTime,
//     this.gst,
//     this.gstValue,
//   });

//   factory Transaction.fromMap(Map<String, dynamic> map) {
//     DateTime? parseDate(dynamic value) {
//       if (value == null) return null;
//       try {
//         return DateTime.parse(value.toString());
//       } catch (_) {
//         return null;
//       }
//     }

//     List<T> parseList<T>(dynamic input, T Function(dynamic) parser) {
//       if (input == null) return [];
//       if (input is List) return input.map(parser).toList();
//       return [parser(input)];
//     }

//     // Create safe lists with consistent lengths
//     final varianceitemCode = parseList<String>(map['varianceitemCode'], (v) => v.toString());
//     final itemName = parseList<String>(map['itemName'], (v) => v.toString());
//     final varianceName = parseList<String>(map['varianceName'], (v) => v.toString());
//     final price = parseList<int>(map['price'], (v) => int.tryParse(v.toString()) ?? 0);
//        final sellingPrice = parseList<double>(map['sellingPrice'], (v) => double.tryParse(v.toString()) ?? 0.0);  // Changed to double
//     final sellingAmount = parseList<double>(map['sellingAmount'], (v) => double.tryParse(v.toString()) ?? 0.0); // Changed to double
//     final weight = parseList<double>(map['weight'], (v) => double.tryParse(v.toString()) ?? 0);
//     final qty = parseList<double>(map['qty'], (v) => double.tryParse(v.toString()) ?? 0);
//     final amount = parseList<double>(map['amount'], (v) => double.tryParse(v.toString()) ?? 0);
//     final tax = parseList<double>(map['tax'], (v) => double.tryParse(v.toString()) ?? 0);
//     final uom = parseList<String>(map['uom'], (v) => v.toString());

//     // Determine the max length to ensure all lists have same number of items
//     final itemCount = [
//       varianceitemCode.length,
//       itemName.length,
//       varianceName.length,
//       price.length,
//       sellingPrice.length,
//       sellingAmount.length,
//       weight.length,
//       qty.length,
//       amount.length,
//       tax.length,
//       uom.length
//     ].reduce((a, b) => a > b ? a : b);

//     // Function to pad lists with empty values if needed
//     List<T> padList<T>(List<T> list, int targetLength, T defaultValue) {
//       if (list.length >= targetLength) return list;
//       return [...list, ...List.filled(targetLength - list.length, defaultValue)];
//     }

//     return Transaction(
//       invoiceId: map['invoiceId']?.toString() ?? '',
//       varianceitemCode: padList(varianceitemCode, itemCount, ''),
//       itemName: padList(itemName, itemCount, ''),
//       varianceName: padList(varianceName, itemCount, ''),
//       price: padList(price, itemCount, 0),
//       sellingPrice: padList(sellingPrice, itemCount, 0),
//       sellingAmount: padList(sellingAmount, itemCount, 0),
//       weight: padList(weight, itemCount, 0.0),
//       qty: padList(qty, itemCount, 0.0),
//       amount: padList(amount, itemCount, 0.0),
//       tax: padList(tax, itemCount, 0.0),
//       uom: padList(uom, itemCount, ''),

//       totalAmount: double.tryParse(map['totalAmount']?.toString() ?? '0') ?? 0,
//       netAmount: double.tryParse(map['netAmount']?.toString() ?? '0') ?? 0,
//       grossAmount: double.tryParse(map['grossAmount']?.toString() ?? '0') ?? 0,
//       customCharge: double.tryParse(map['customCharge']?.toString() ?? '0') ?? 0,
//       discountAmount: map['discountAmount'] != null
//           ? double.tryParse(map['discountAmount'].toString())
//           : null,
//       discountPercentage: double.tryParse(map['discountPercentage']?.toString() ?? '0') ?? 0,

//       gst: parseList<String>(map['gst'], (v) => v.toString()),
//       gstValue: parseList<double>(map['gstValue'], (v) => double.tryParse(v.toString()) ?? 0),

//       status: map['status']?.toString() ?? '',
//       salesType: map['salesType']?.toString() ?? '',
//       customerPhoneNumber: map['customerPhoneNumber']?.toString() ?? '',

//       salesPersonId: map['salesPersonId']?.toString(),
//       salesPersonName: map['salesPersonName']?.toString() ?? '',
//       branchId: map['branchId']?.toString() ?? '',
//       branchName: map['branchName']?.toString() ?? '',
//       aliasName: map['aliasName']?.toString() ?? '',

//       paymentType: map['paymentType']?.toString(),
//       cash: double.tryParse(map['cash']?.toString() ?? '0') ?? 0,
//       card: map['card'] != null ? double.tryParse(map['card'].toString()) : null,
//       upi: map['upi'] != null ? double.tryParse(map['upi'].toString()) : null,
//       others: map['others'] != null ? double.tryParse(map['others'].toString()) : null,

//       invoiceDateTime: parseDate(map['invoiceDateTime']),
//       shiftNumber: map['shiftNumber'] is int
//           ? map['shiftNumber']
//           : int.tryParse(map['shiftNumber']?.toString() ?? '0'),
//       shiftId: map['shiftId']?.toString() ?? '',
//       invoiceNo: map['invoiceNo']?.toString() ?? '',
//       deviceNumber: map['deviceNumber'] is int
//           ? map['deviceNumber']
//           : int.tryParse(map['deviceNumber']?.toString() ?? '0'),
//       deviceCode: map['deviceCode']?.toString(),
//       kotaddOns: parseList<String>(map['kotaddOns'], (v) => v.toString()),
//       createdById: map['createdById']?.toString(),
//       createdByName: map['createdByName']?.toString(),
//       syncDateTime: parseDate(map['syncDateTime']),
//     );
//   }

//   // Helper method to get item data as a list of maps for easier handling
//   List<Map<String, dynamic>> getItems() {
//     final List<Map<String, dynamic>> items = [];

//     for (int i = 0; i < itemName.length; i++) {
//       items.add({
//         'varianceitemCode': i < varianceitemCode.length ? varianceitemCode[i] : '',
//         'itemName': i < itemName.length ? itemName[i] : '',
//         'varianceName': i < varianceName.length ? varianceName[i] : '',
//         'price': i < price.length ? price[i] : 0,
//         'sellingPrice': i < sellingPrice.length ? sellingPrice[i] : 0,
//         'sellingAmount': i < sellingAmount.length ? sellingAmount[i] : 0,
//         'weight': i < weight.length ? weight[i] : 0.0,
//         'qty': i < qty.length ? qty[i] : 0.0,
//         'amount': i < amount.length ? amount[i] : 0.0,
//         'tax': i < tax.length ? tax[i] : 0.0,
//         'uom': i < uom.length ? uom[i] : '',
//       });
//     }

//     return items;
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       "invoiceId": invoiceId,
//       "varianceitemCode": varianceitemCode,
//       "itemName": itemName,
//       "varianceName": varianceName,
//       "price": price,
//       "sellingPrice": sellingPrice,
//       "sellingAmount": sellingAmount,
//       "weight": weight,
//       "qty": qty,
//       "amount": amount,
//       "tax": tax,
//       "uom": uom,
//       "totalAmount": totalAmount,
//       "netAmount": netAmount,
//       "grossAmount": grossAmount,
//       "customCharge": customCharge,
//       "discountAmount": discountAmount,
//       "discountPercentage": discountPercentage,
//       "gst": gst,
//       "gstValue": gstValue,
//       "status": status,
//       "salesType": salesType,
//       "customerPhoneNumber": customerPhoneNumber,
//       "salesPersonId": salesPersonId,
//       "salesPersonName": salesPersonName,
//       "branchId": branchId,
//       "branchName": branchName,
//       "aliasName": aliasName,
//       "paymentType": paymentType,
//       "cash": cash,
//       "card": card,
//       "upi": upi,
//       "others": others,
//       "invoiceDateTime": invoiceDateTime?.toIso8601String(),
//       "shiftNumber": shiftNumber,
//       "shiftId": shiftId,
//       "invoiceNo": invoiceNo,
//       "deviceNumber": deviceNumber,
//       "deviceCode": deviceCode,
//       "kotaddOns": kotaddOns,
//       "createdById": createdById,
//       "createdByName": createdByName,
//       "syncDateTime": syncDateTime?.toIso8601String(),
//     };
//   }

//   @override
//   String toString() => jsonEncode(toMap());
// }

import 'dart:convert';

class Transaction {
  final String transactionId;
  final String transactionType; // 'sale' or 'return'
  final List<String> varianceitemCode;
  final List<String> itemName;
  final List<String> varianceName;
  final List<int> price;
  final List<double> sellingPrice;
  final List<double> sellingAmount;
  final List<double> weight;
  final List<double> qty;
  final List<double> amount;
  final List<double> tax;
  final List<String> uom;

  // 💰 Financial fields
  final double totalAmount;
  final double netAmount;
  final double grossAmount;
  final double customCharge;
  final double? discountAmount;
  final double discountPercentage;

  // 🧾 GST details
  final List<String>? gst;
  final List<double>? gstValue;

  // 📦 Order info
  final String status;
  final String salesType;
  final String customerPhoneNumber;

  // 👨‍💼 Staff and branch info
  final String? salesPersonId;
  final String salesPersonName;
  final String branchId;
  final String branchName;
  final String aliasName;

  // 💳 Payment info
  final String? paymentType;
  final double cash;
  final double? card;
  final double? upi;
  final double? others;

  // 🕓 Metadata
  final DateTime? invoiceDateTime;
  final DateTime? returnDateTime;
  final int? shiftNumber;
  final String shiftId;
  final String invoiceNo;
  final String? salesReturnNo;
  final int? deviceNumber;
  final String? deviceCode;
  final List<String>? kotaddOns;
  final String? createdById;
  final String? createdByName;
  final DateTime? syncDateTime;

  Transaction({
    required this.transactionId,
    this.transactionType = 'sale',
    required this.varianceitemCode,
    required this.itemName,
    required this.varianceName,
    required this.price,
    required this.sellingPrice,
    required this.sellingAmount,
    required this.weight,
    required this.qty,
    required this.amount,
    required this.tax,
    required this.uom,
    required this.totalAmount,
    required this.netAmount,
    required this.grossAmount,
    required this.status,
    required this.salesType,
    required this.customerPhoneNumber,
    this.salesPersonId,
    required this.salesPersonName,
    required this.branchId,
    required this.branchName,
    required this.aliasName,
    this.paymentType,
    required this.cash,
    this.card,
    this.upi,
    this.others,
    this.invoiceDateTime,
    this.returnDateTime,
    this.shiftNumber,
    required this.shiftId,
    required this.invoiceNo,
    this.salesReturnNo,
    this.deviceNumber,
    required this.customCharge,
    this.discountAmount,
    required this.discountPercentage,
    this.deviceCode,
    this.kotaddOns,
    this.createdById,
    this.createdByName,
    this.syncDateTime,
    this.gst,
    this.gstValue,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    List<T> parseList<T>(dynamic input, T Function(dynamic) parser) {
      if (input == null) return [];
      if (input is List) return input.map(parser).toList();
      return [parser(input)];
    }

    // Create safe lists with consistent lengths
    final varianceitemCode = parseList<String>(
      map['varianceitemCode'],
      (v) => v.toString(),
    );
    final itemName = parseList<String>(map['itemName'], (v) => v.toString());
    final varianceName = parseList<String>(
      map['varianceName'],
      (v) => v.toString(),
    );
    final price = parseList<int>(
      map['price'],
      (v) => int.tryParse(v.toString()) ?? 0,
    );
    final sellingPrice = parseList<double>(
      map['sellingPrice'],
      (v) => double.tryParse(v.toString()) ?? 0.0,
    );
    final sellingAmount = parseList<double>(
      map['sellingAmount'],
      (v) => double.tryParse(v.toString()) ?? 0.0,
    );
    final weight = parseList<double>(
      map['weight'],
      (v) => double.tryParse(v.toString()) ?? 0.0,
    );
    final qty = parseList<double>(
      map['qty'],
      (v) => double.tryParse(v.toString()) ?? 0.0,
    );
    final amount = parseList<double>(
      map['amount'],
      (v) => double.tryParse(v.toString()) ?? 0.0,
    );
    final tax = parseList<double>(
      map['tax'],
      (v) => double.tryParse(v.toString()) ?? 0.0,
    );
    final uom = parseList<String>(map['uom'], (v) => v.toString());

    // Determine the max length to ensure all lists have same number of items
    final itemCount = [
      varianceitemCode.length,
      itemName.length,
      varianceName.length,
      price.length,
      sellingPrice.length,
      sellingAmount.length,
      weight.length,
      qty.length,
      amount.length,
      tax.length,
      uom.length,
    ].reduce((a, b) => a > b ? a : b);

    // Function to pad lists with empty values if needed
    List<T> padList<T>(List<T> list, int targetLength, T defaultValue) {
      if (list.length >= targetLength) return list;
      return [
        ...list,
        ...List.filled(targetLength - list.length, defaultValue),
      ];
    }

    return Transaction(
      transactionId:
          map['transactionId']?.toString() ??
          map['invoiceId']?.toString() ??
          '',
      transactionType: map['transactionType']?.toString() ?? 'sale',
      varianceitemCode: padList(varianceitemCode, itemCount, ''),
      itemName: padList(itemName, itemCount, ''),
      varianceName: padList(varianceName, itemCount, ''),
      price: padList(price, itemCount, 0),
      sellingPrice: padList(sellingPrice, itemCount, 0.0),
      sellingAmount: padList(sellingAmount, itemCount, 0.0),
      weight: padList(weight, itemCount, 0.0),
      qty: padList(qty, itemCount, 0.0),
      amount: padList(amount, itemCount, 0.0),
      tax: padList(tax, itemCount, 0.0),
      uom: padList(uom, itemCount, ''),

      totalAmount: double.tryParse(map['totalAmount']?.toString() ?? '0') ?? 0,
      netAmount: double.tryParse(map['netAmount']?.toString() ?? '0') ?? 0,
      grossAmount: double.tryParse(map['grossAmount']?.toString() ?? '0') ?? 0,
      customCharge:
          double.tryParse(map['customCharge']?.toString() ?? '0') ?? 0,
      discountAmount: map['discountAmount'] != null
          ? double.tryParse(map['discountAmount'].toString())
          : null,
      discountPercentage:
          double.tryParse(map['discountPercentage']?.toString() ?? '0') ?? 0,

      gst: parseList<String>(map['gst'], (v) => v.toString()),
      gstValue: parseList<double>(
        map['gstValue'],
        (v) => double.tryParse(v.toString()) ?? 0,
      ),

      status: map['status']?.toString() ?? '',
      salesType: map['salesType']?.toString() ?? '',
      customerPhoneNumber: map['customerPhoneNumber']?.toString() ?? '',

      salesPersonId: map['salesPersonId']?.toString(),
      salesPersonName: map['salesPersonName']?.toString() ?? '',
      branchId: map['branchId']?.toString() ?? '',
      branchName: map['branchName']?.toString() ?? '',
      aliasName: map['aliasName']?.toString() ?? '',

      paymentType: map['paymentType']?.toString(),
      cash: double.tryParse(map['cash']?.toString() ?? '0') ?? 0,
      card: map['card'] != null
          ? double.tryParse(map['card'].toString())
          : null,
      upi: map['upi'] != null ? double.tryParse(map['upi'].toString()) : null,
      others: map['others'] != null
          ? double.tryParse(map['others'].toString())
          : null,

      invoiceDateTime: parseDate(map['invoiceDateTime']),
      returnDateTime: parseDate(map['returnDateTime']),
      shiftNumber: map['shiftNumber'] is int
          ? map['shiftNumber']
          : int.tryParse(map['shiftNumber']?.toString() ?? '0'),
      shiftId: map['shiftId']?.toString() ?? '',
      invoiceNo: map['invoiceNo']?.toString() ?? '',
      salesReturnNo: map['salesReturnNo']?.toString(),
      deviceNumber: map['deviceNumber'] is int
          ? map['deviceNumber']
          : int.tryParse(map['deviceNumber']?.toString() ?? '0'),
      deviceCode: map['deviceCode']?.toString(),
      kotaddOns: parseList<String>(map['kotaddOns'], (v) => v.toString()),
      createdById: map['createdById']?.toString(),
      createdByName: map['createdByName']?.toString(),
      syncDateTime: parseDate(map['syncDateTime']),
    );
  }

  // Helper method to get item data as a list of maps for easier handling
 List<Map<String, dynamic>> getItems() {
  final List<Map<String, dynamic>> items = [];

  for (int i = 0; i < itemName.length; i++) {
    final double qtyVal = i < qty.length ? qty[i] : 1.0;
    final double sellingPriceVal = i < sellingPrice.length ? sellingPrice[i] : 0.0;
    final double taxRate = i < tax.length ? tax[i] : 0.0;

    // CRITICAL FIX: If price is 0 or missing, reconstruct from sellingPrice + tax
    int originalMrp = i < price.length ? price[i] : 0;
    if (originalMrp <= 0 && sellingPriceVal > 0) {
      // Reverse calculate MRP from selling price (after discount)
      // sellingPrice = MRP × (100 - discount%) / 100
      final discountPct = discountPercentage ?? 0.0;
      if (discountPct > 0) {
        originalMrp = (sellingPriceVal * 100 / (100 - discountPct)).round();
      } else {
        originalMrp = sellingPriceVal.round(); // No discount? MRP = selling price
      }
    }

    final double originalAmount = originalMrp * qtyVal;
    final double paidAmount = sellingPriceVal * qtyVal;

    items.add({
      'varianceitemCode': i < varianceitemCode.length ? varianceitemCode[i] : '',
      'itemName': i < itemName.length ? itemName[i] : '',
      'varianceName': i < varianceName.length ? varianceName[i] : '',
      'price': originalMrp,                    // Now 100 (reconstructed!)
      'sellingPrice': sellingPriceVal,         // 95
      'sellingAmount': paidAmount,             // 95
      'weight': i < weight.length ? weight[i] : 0.0,
      'qty': qtyVal,
      'amount': originalAmount,                // Now 100 (fixed!)
      'tax': taxRate,
      'uom': i < uom.length ? uom[i] : 'Pcs',
      'hsnCode': 21069099,                     // Default HSN for mixtures/sweets
    });
  }
  return items;
}

  // Create a return transaction from this sale
  Transaction createReturnTransaction({
    required List<Map<String, dynamic>> returnedItems,
    required String salesReturnNo,
  }) {
    // Extract lists from returned items
    List<String> returnVarianceItemCodes = [];
    List<String> returnItemNames = [];
    List<String> returnVarianceNames = [];
    List<int> returnPrices = [];
    List<double> returnSellingPrices = [];
    List<double> returnSellingAmounts = [];
    List<double> returnWeights = [];
    List<double> returnQtys = [];
    List<double> returnAmounts = [];
    List<double> returnTaxes = [];
    List<String> returnUoms = [];
    List<String> returnGst = [];
    List<double> returnGstValues = [];

    double returnTotalAmount = 0;
    double returnNetAmount = 0;
    double returnGrossAmount = 0;
    double returnGstTotal = 0;

    for (var item in returnedItems) {
      returnVarianceItemCodes.add(item['varianceitemCode']);
      returnItemNames.add(item['itemName']);
      returnVarianceNames.add(item['varianceName']);
      returnPrices.add(item['price']);
      returnSellingPrices.add(item['sellingPrice']);
      returnSellingAmounts.add(item['sellingAmount']);
      returnWeights.add(item['weight']);
      returnQtys.add(item['qty']);
      returnAmounts.add(item['amount']);
      returnTaxes.add(item['tax']);
      returnUoms.add(item['uom']);

      // Calculate GST
      double gstValue = item['amount'] * (item['tax'] / (100 + item['tax']));
      returnGstValues.add(gstValue);
      returnGst.add(item['tax'].toString());

      returnTotalAmount += item['amount'];
      returnGstTotal += gstValue;
    }

    returnNetAmount = returnTotalAmount - returnGstTotal;
    returnGrossAmount = returnTotalAmount;

    return Transaction(
      transactionId: transactionId,
      transactionType: 'return',
      varianceitemCode: returnVarianceItemCodes,
      itemName: returnItemNames,
      varianceName: returnVarianceNames,
      price: returnPrices,
      sellingPrice: returnSellingPrices,
      sellingAmount: returnSellingAmounts,
      weight: returnWeights,
      qty: returnQtys,
      amount: returnAmounts,
      tax: returnTaxes,
      uom: returnUoms,
      totalAmount: returnTotalAmount,
      netAmount: returnNetAmount,
      grossAmount: returnGrossAmount,
      customCharge: 0,
      discountAmount: discountAmount,
      discountPercentage: discountPercentage,
      gst: returnGst,
      gstValue: returnGstValues,
      status: 'active',
      salesType: salesType,
      customerPhoneNumber: customerPhoneNumber,
      salesPersonId: salesPersonId,
      salesPersonName: salesPersonName,
      branchId: branchId,
      branchName: branchName,
      aliasName: aliasName,
      paymentType: paymentType,
      cash: cash,
      card: card,
      upi: upi,
      others: others,
      invoiceDateTime: invoiceDateTime,
      returnDateTime: DateTime.now(),
      shiftNumber: shiftNumber,
      shiftId: shiftId,
      invoiceNo: invoiceNo,
      salesReturnNo: salesReturnNo,
      deviceNumber: deviceNumber,
      deviceCode: deviceCode,
      kotaddOns: kotaddOns,
      createdById: createdById,
      createdByName: createdByName,
      syncDateTime: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "transactionId": transactionId,
      "transactionType": transactionType,
      "invoiceId": transactionType == 'sale' ? transactionId : null,
      "salesReturnId": transactionType == 'return' ? transactionId : null,
      "varianceitemCode": varianceitemCode,
      "itemName": itemName,
      "varianceName": varianceName,
      "price": price,
      "sellingPrice": sellingPrice,
      "sellingAmount": sellingAmount,
      "weight": weight,
      "qty": qty,
      "amount": amount,
      "tax": tax,
      "uom": uom,
      "totalAmount": totalAmount,
      "netAmount": netAmount,
      "grossAmount": grossAmount,
      "customCharge": customCharge,
      "discountAmount": discountAmount,
      "discountPercentage": discountPercentage,
      "gst": gst,
      "gstValue": gstValue,
      "status": status,
      "salesType": salesType,
      "customerPhoneNumber": customerPhoneNumber,
      "salesPersonId": salesPersonId,
      "salesPersonName": salesPersonName,
      "branchId": branchId,
      "branchName": branchName,
      "aliasName": aliasName,
      "paymentType": paymentType,
      "cash": cash,
      "card": card,
      "upi": upi,
      "others": others,
      "invoiceDateTime": invoiceDateTime?.toIso8601String(),
      "returnDateTime": returnDateTime?.toIso8601String(),
      "shiftNumber": shiftNumber,
      "shiftId": shiftId,
      "invoiceNo": invoiceNo,
      "salesReturnNo": salesReturnNo,
      "deviceNumber": deviceNumber,
      "deviceCode": deviceCode,
      "kotaddOns": kotaddOns,
      "createdById": createdById,
      "createdByName": createdByName,
      "syncDateTime": syncDateTime?.toIso8601String(),
    };
  }

  @override
  String toString() => jsonEncode(toMap());
}

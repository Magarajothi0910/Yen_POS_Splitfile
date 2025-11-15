import 'dart:convert';

class Transaction {
  final String invoiceId;
  final List<String> varianceitemCode;
  final List<String> itemName;
  final List<String> varianceName;
  final List<int> price;
  final List<int> sellingPrice;
  final List<int> sellingAmount;
  final List<double> weight;
  final List<double> qty;
  final List<double> amount;
  final List<double> tax;
  final List<String> uom;

  // 💰 Financial fields
  final double totalAmount;
  final double netAmount;
  final double grossAmount; // ✅ renamed from crossAmount
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
  final int? shiftNumber;
  final String shiftId;
  final String invoiceNo;
  final int? deviceNumber;
  final String? deviceCode;
  final List<String>? kotaddOns;
  final String? createdById;
  final String? createdByName;
  final DateTime? syncDateTime;

  Transaction({
    required this.invoiceId,
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
    this.shiftNumber,
    required this.shiftId,
    required this.invoiceNo,
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

    return Transaction(
      invoiceId: map['invoiceId']?.toString() ?? '',
      varianceitemCode: parseList<String>(
        map['varianceitemCode'],
        (v) => v.toString(),
      ),
      itemName: parseList<String>(map['itemName'], (v) => v.toString()),
      varianceName: parseList<String>(map['varianceName'], (v) => v.toString()),
      price: parseList<int>(
        map['price'],
        (v) => int.tryParse(v.toString()) ?? 0,
      ),
      sellingPrice: parseList<int>(
        map['sellingPrice'],
        (v) => int.tryParse(v.toString()) ?? 0,
      ),
      sellingAmount: parseList<int>(
        map['sellingAmount'],
        (v) => int.tryParse(v.toString()) ?? 0,
      ),
      weight: parseList<double>(
        map['weight'],
        (v) => double.tryParse(v.toString()) ?? 0,
      ),
      qty: parseList<double>(
        map['qty'],
        (v) => double.tryParse(v.toString()) ?? 0,
      ),
      amount: parseList<double>(
        map['amount'],
        (v) => double.tryParse(v.toString()) ?? 0,
      ),
      tax: parseList<double>(
        map['tax'],
        (v) => double.tryParse(v.toString()) ?? 0,
      ),
      uom: parseList<String>(map['uom'], (v) => v.toString()),

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
      shiftNumber: map['shiftNumber'] is int
          ? map['shiftNumber']
          : int.tryParse(map['shiftNumber']?.toString() ?? '0'),
      shiftId: map['shiftId']?.toString() ?? '',
      invoiceNo: map['invoiceNo']?.toString() ?? '',
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

  Map<String, dynamic> toMap() {
    return {
      "invoiceId": invoiceId,
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
      "shiftNumber": shiftNumber,
      "shiftId": shiftId,
      "invoiceNo": invoiceNo,
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

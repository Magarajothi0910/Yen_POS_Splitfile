// import 'package:isar/isar.dart';
// import 'dart:convert';

// part 'sales_order.g.dart';

// @Collection()
// class SalesOrder {
//   Id id = Isar.autoIncrement; // Auto-increment ID

//   // Basic order info
//   late String saleOrderNo;
//   late String branchName;
//   late String aliasName;
//   late double totalAmount;
//   late double finalPrice;
//   late double balanceAmount;
//   late String orderDate; // ISO string
//   late String deliveryDate; // ISO string
//   String? audioPath;
//   List<String>? imagePaths;

//   // Cart details
//   List<String>? itemName;
//   List<String>? varianceName;
//   List<int>? qty;
//   List<String>? uom;
//   List<double>? amount;
//   List<int>? sellingPrice;
//   List<double>? sellingAmount;
//   List<String>? isBoxItem;
//   List<double>? itemWiseDiscount;
//   List<double>? itemWiseDiscountAmount;

//   // Payments
//   List<double>? advanceAmount;

//   /// Nested lists are NOT supported by Isar
//   /// Convert to JSON string for storage
//   String? advancePaymentTypeJson; // stores List<List<String>>
//   String? modeWiseAmountJson; // stores List<List<double>>
//   String? advanceDateTimeJson; // stores List<String>

//   // Metadata
//   String? customerName;
//   String? customerNumber;
//   String? deliveryType;
//   String? address;
//   String? landmark;
//   String? remark;
//   String? orderType;
//   String? event;
//   double? discount;
//   double? discountAmount;
//   double? totalCustomCharge;

//   // Optional fields
//   String? companyName;
//   String? companyAddress;
//   String? companyGST;
//   String? status;

//   // Helper methods to encode/decode nested lists
//   void setAdvancePaymentType(List<List<String>> data) {
//     advancePaymentTypeJson = jsonEncode(data);
//   }

//   List<List<String>> getAdvancePaymentType() {
//     if (advancePaymentTypeJson == null) return [];
//     return (jsonDecode(advancePaymentTypeJson!) as List)
//         .map((e) => List<String>.from(e))
//         .toList();
//   }

//   void setModeWiseAmount(List<List<double>> data) {
//     modeWiseAmountJson = jsonEncode(data);
//   }

//   List<List<double>> getModeWiseAmount() {
//     if (modeWiseAmountJson == null) return [];
//     return (jsonDecode(modeWiseAmountJson!) as List)
//         .map((e) => List<double>.from(e))
//         .toList();
//   }

//   void setAdvanceDateTime(List<String> data) {
//     advanceDateTimeJson = jsonEncode(data);
//   }

//   List<String> getAdvanceDateTime() {
//     if (advanceDateTimeJson == null) return [];
//     return (jsonDecode(advanceDateTimeJson!) as List)
//         .map((e) => e.toString())
//         .toList();
//   }
// }

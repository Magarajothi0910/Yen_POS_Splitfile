// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'sales_invoicemodel.dart';

class ModifyOrder {
  final String previousId; // Matches with salesOrderId
  final String saleOrderNo; // Matches with saleOrderNo
  // final List<String> itemName;
  final List<String> varianceName;
  final List<double> qty;
  final List<String> uom;
  final List<double> price;
  final List<double> amount;
  List<double>? weight;
  List<String>? isBoxItem;
  ModifyOrder({
    required this.previousId,
    required this.varianceName,
    required this.saleOrderNo,
    // required this.itemName,
    required this.qty,
    required this.uom,
    required this.price,
    required this.amount,
    this.weight,
    this.isBoxItem,
  });

  factory ModifyOrder.fromJson(Map<String, dynamic> json) {
    return ModifyOrder(
      previousId: json['previousOrderId'] ?? '',
      saleOrderNo: json['saleOrderNo'] ?? '',
      // itemName: (json['itemName'] as List<dynamic>?)
      //         ?.map((item) => item.toString())
      //         .toList() ??
      //     [],
      varianceName:
          (json['varianceName'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          [],
      qty:
          (json['qty'] as List<dynamic>?)
              ?.map((qty) => (qty as num?)?.toDouble() ?? 0.0)
              .toList() ??
          [],
      uom:
          (json['uom'] as List<dynamic>?)
              ?.map((uom) => uom.toString())
              .toList() ??
          [],
      price:
          (json['price'] as List<dynamic>?)
              ?.map((price) => (price as num?)?.toDouble() ?? 0.0)
              .toList() ??
          [],
      amount:
          (json['amount'] as List<dynamic>?)
              ?.map((amt) => (amt as num?)?.toDouble() ?? 0.0)
              .toList() ??
          [],
      weight:
          (json['weight'] as List<dynamic>?)
              ?.map((weight) => (weight as num?)?.toDouble() ?? 0.0)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'previousOrderId': previousId,
      'saleOrderNo': saleOrderNo,
      'varianceName': varianceName,
      'qty': qty,
      'uom': uom,
      'price': price,
      'amount': amount,
      'weight': weight,
    };
  }
}

class ToApprove {
  final String previousId; // Matches with salesOrderId
  final String saleOrderNo; // Matches with saleOrderNo
  // final List<String> itemName;
  final List<String> varianceName;
  final List<double> qty;
  final List<String> uom;
  final List<double> price;
  final List<double> amount;
  List<double>? weight;
  List<String>? isBoxItem;
  ToApprove({
    required this.previousId,
    required this.varianceName,
    required this.saleOrderNo,
    // required this.itemName,
    required this.qty,
    required this.uom,
    required this.price,
    required this.amount,
    this.weight,
    this.isBoxItem,
  });

  factory ToApprove.fromJson(Map<String, dynamic> json) {
    return ToApprove(
      previousId: json['previousOrderId'] ?? '',
      saleOrderNo: json['saleOrderNo'] ?? '',
      // itemName: (json['itemName'] as List<dynamic>?)
      //         ?.map((item) => item.toString())
      //         .toList() ??
      //     [],
      varianceName:
          (json['varianceName'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          [],
      qty:
          (json['qty'] as List<dynamic>?)
              ?.map((qty) => (qty as num?)?.toDouble() ?? 0.0)
              .toList() ??
          [],
      uom:
          (json['uom'] as List<dynamic>?)
              ?.map((uom) => uom.toString())
              .toList() ??
          [],
      price:
          (json['price'] as List<dynamic>?)
              ?.map((price) => (price as num?)?.toDouble() ?? 0.0)
              .toList() ??
          [],
      amount:
          (json['amount'] as List<dynamic>?)
              ?.map((amt) => (amt as num?)?.toDouble() ?? 0.0)
              .toList() ??
          [],
      weight:
          (json['weight'] as List<dynamic>?)
              ?.map((weight) => (weight as num?)?.toDouble() ?? 0.0)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'previousOrderId': previousId,
      'saleOrderNo': saleOrderNo,
      'varianceName': varianceName,
      'qty': qty,
      'uom': uom,
      'price': price,
      'amount': amount,
      'weight': weight,
    };
  }
}

class SalesOrderDisplay {
  final String salesOrderId;
  final List<String> itemName;
  final List<String> varianceName;
  final List<int> qty;
  final List<double> price;
  final List<int> sellingPrice;
  final List<double> sellingAmount;

  final List<String> itemCode;
  final List<double> weight;
  final List<double> amount;
  final List<double> tax;
  final List<String> uom;
  double totalAmount;
  final double? totalAmount2;
  final double netPrice;
  final String orderInvoiceNo;
  final String invoiceNo;

  final String branchId;
  final String branchName;
  final String aliasName;

  final String invoiceDate;
  final double cash;
  final double card;
  final double upi;
  final String deliveryPartners;
  final double otherPayments;
  final String deliveryPartnerName;
  final List<String> shiftId;
  final String shiftName;
  final String user;
  String deliveryDate;
  final String deliveryTime;
  final String event;
  final String customerNumber;
  final String customerName;
  final String deliveryType;
  final String address;
  final String landmark;
  final int discount;
  final double discountAmount;
  final String remark;
  final List<double> customCharge;
  List<double>? advanceAmount;
  List<String> advanceDateTime;
  List<List<String>>? advancePaymentType;
  List<List<double>>? modeWiseAmount;
  String? orderType;
  final String paymentType;
  final double finalPrice;
  final double balanceAmount;
  final String saleOrderNo;
  final String orderDate;
  final String orderTime;
  final List<String> customChargeType;
  double? totalCustomCharge;

  final String employeeName;
  final String status;
  final String cancelOrderRemark;
  String? audioUrl;
  String? eventDate;
  List<String>? isBoxItem;
  List<double>? itemWiseDiscount;
  List<double>? itemWiseDiscountAmount;
  int? boxQty;
  List<bool>? isItemReduced;
  final String? hiveId;
  final List<ModifyOrder>? modifiedOrders;
  final List<ToApprove>? toApprove;
  String? image1;
  String? image2;
  String? audio;
  List<String>? imagePaths;

  SalesOrderDisplay({
    required this.salesOrderId,
    required this.itemName,
    required this.varianceName,
    required this.qty,
    required this.price,
    required this.itemCode,
    required this.sellingPrice,
    required this.sellingAmount,

    required this.weight,
    required this.amount,
    required this.tax,
    required this.uom,
    required this.totalAmount,
    required this.totalAmount2,
    required this.netPrice,
    required this.orderInvoiceNo,
    required this.invoiceNo,
    required this.branchId,
    required this.branchName,
    required this.aliasName,
    required this.invoiceDate,
    required this.customChargeType,
    required this.cash,
    required this.card,
    required this.upi,
    required this.deliveryPartners,
    required this.otherPayments,
    required this.deliveryPartnerName,
    required this.shiftId,
    required this.shiftName,
    required this.user,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.event,
    required this.customerNumber,
    required this.customerName,
    required this.deliveryType,
    required this.address,
    required this.totalCustomCharge,
    required this.landmark,
    required this.discount,
    required this.discountAmount,
    required this.remark,
    required this.customCharge,
    this.advanceAmount,
    this.modeWiseAmount,
    required this.advanceDateTime,
    required this.advancePaymentType,
    required this.paymentType,
    required this.finalPrice,
    required this.balanceAmount,
    required this.saleOrderNo,
    required this.orderDate,
    required this.orderTime,
    required this.employeeName,
    required this.status,
    required this.cancelOrderRemark,
    this.audioUrl,
    this.isItemReduced,
    this.modifiedOrders,
    this.isBoxItem,
    this.itemWiseDiscount,
    this.itemWiseDiscountAmount,
    this.boxQty,
    this.toApprove,
    this.eventDate,
    this.image1,
    this.image2,
    this.audio,
    this.hiveId,
    this.orderType,
    this.imagePaths,
  });

  String get formattedDeliveryDate {
    try {
      DateTime parsedDate = DateTime.parse(deliveryDate);
      return DateFormat("dd-MM-yyyy").format(parsedDate);
    } catch (e) {
      return deliveryDate; // Return original string if parsing fails
    }
  }

  //create a tojson method
  Map<String, dynamic> toJson() {
    return {
      'salesOrderId': salesOrderId ?? "",
      'itemName': itemName,
      'varianceName': varianceName,
      'qty': qty,
      'price': price,
      'itemCode': itemCode,
      'weight': weight,
      'amount': amount,
      'tax': tax,
      'uom': uom,
      'sellingPrice': sellingPrice,
      'sellingAmount': sellingAmount,
      'totalCustomCharge': totalCustomCharge,
      'totalAmount': totalAmount,
      'totalAmount2': totalAmount2,
      'netPrice': netPrice,
      'orderInvoiceNo': orderInvoiceNo,
      'invoiceNo': invoiceNo,
      'branchId': branchId,
      'branchName': branchName,
      'aliasName': aliasName,
      'invoiceDate': invoiceDate,
      'cash': cash,
      'card': card,
      'upi': upi,
      "customChargeType": customChargeType,
      'deliveryPartners': deliveryPartners,
      'otherPayments': otherPayments,
      'deliveryPartnerName': deliveryPartnerName,
      'shiftId': shiftId,
      'shiftName': shiftName,
      'user': user,
      'deliveryDate': deliveryDate,
      'deliveryTime': deliveryTime,
      'event': event,
      'customerNumber': customerNumber,
      'customerName': customerName,
      'deliveryType': deliveryType,
      'address': address,
      'landmark': landmark,
      'discount': discount,
      'discountAmount': discountAmount,
      'remark': remark,
      'customCharge': customCharge,
      'advanceAmount': advanceAmount,
      'advanceDateTime': advanceDateTime,
      'advancePaymentType': advancePaymentType,
      'paymentType': paymentType,
      'finalPrice': finalPrice,
      'balanceAmount': balanceAmount,
      'saleOrderNo': saleOrderNo,
      'orderDate': orderDate,
      'orderTime': orderTime,
      'employeeName': employeeName,
      'status': status,
      'cancelOrderRemark': cancelOrderRemark,
      'audioUrl': audioUrl,
      'eventDate': eventDate,
      'orderType': orderType,
      'itemWiseDiscount': itemWiseDiscount,
      'itemWiseDiscountAmount': itemWiseDiscountAmount,
      'isItemReduced': isItemReduced,
      'boxQty': boxQty,
      'modifiedOrders': modifiedOrders?.map((x) => x.toJson()).toList(),
      //  'toApprove': toApprove?.map((x) => x.toJson()).toList(),
      'toApprove': toApprove,
      'isBoxItem': isBoxItem,
      'imagePaths': imagePaths,
      'image1': image1,
      'image2': image2,
      'audio': audio,
    };
  }

  factory SalesOrderDisplay.fromJson(Map<String, dynamic> json) {
    return SalesOrderDisplay(
      salesOrderId: json['salesOrderId'] ?? '',
      itemName:
          (json['itemName'] as List?)?.map((e) => e.toString()).toList() ?? [],
      imagePaths:
          (json['imagePaths'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      varianceName:
          (json['varianceName'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      qty:
          (json['qty'] as List?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .toList() ??
          [],
      sellingPrice:
          (json['sellingPrice'] as List?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .toList() ??
          [],
      sellingAmount:
          (json['sellingAmount'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      price:
          (json['price'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      itemCode:
          (json['itemCode'] as List?)?.map((e) => e.toString()).toList() ?? [],
      weight:
          (json['weight'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      amount:
          (json['amount'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      tax:
          (json['tax'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          [],
      uom: (json['uom'] as List?)?.map((e) => e.toString()).toList() ?? [],
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount2: (json['totalAmount2'] as num?)?.toDouble(),
      netPrice: (json['netPrice'] as num?)?.toDouble() ?? 0.0,
      orderInvoiceNo: json['orderInvoiceNo'] ?? '',
      invoiceNo: json['invoiceNo'] ?? '',
      branchId: json['branchId'] ?? '',
      branchName: json['branchName'] ?? '',
      aliasName: json['aliasName'] ?? '',
      invoiceDate: json['invoiceDate'] ?? '',
      cash: (json['cash'] as num?)?.toDouble() ?? 0.0,
      card: (json['card'] as num?)?.toDouble() ?? 0.0,
      upi: (json['upi'] as num?)?.toDouble() ?? 0.0,
      deliveryPartners: json['deliveryPartners'] ?? '',
      otherPayments: (json['otherPayments'] as num?)?.toDouble() ?? 0.0,
      deliveryPartnerName: json['deliveryPartnerName'] ?? '',

      shiftId:
          (json['shiftId'] as List?)?.map((e) => e.toString()).toList() ?? [],
      shiftName: json['shiftName'] ?? '',
      user: json['user'] ?? '',
      deliveryDate: json['deliveryDate'] ?? '',
      customChargeType:
          (json['customChargeType'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],

      deliveryTime: json['deliveryTime'] ?? '',
      event: json['event'] ?? '',
      customerNumber: json['customerNumber'] ?? '',
      customerName: json['customerName'] ?? '',
      deliveryType: json['deliveryType'] ?? '',
      address: json['address'] ?? '',
      landmark: json['landmark'] ?? '',
      discount: (json['discount'] as num?)?.toInt() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      remark: json['remark'] ?? '',
      customCharge:
          (json['customCharge'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      totalCustomCharge: (json['totalCustomCharge'] as num?)?.toDouble() ?? 0.0,
      advanceAmount:
          (json['advanceAmount'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      advanceDateTime: List<String>.from(json['advanceDateTime'] ?? []),
      advancePaymentType: json['advancePaymentType'] != null
          ? List<List<String>>.from(
              json['advancePaymentType'].map(
                (x) => List<String>.from(x.map((y) => y.toString())),
              ),
            )
          : null,
      modeWiseAmount: json['modeWiseAmount'] != null
          ? List<List<double>>.from(
              json['modeWiseAmount'].map(
                (x) => List<double>.from(x.map((y) => (y as num).toDouble())),
              ),
            )
          : null,
      paymentType: json['paymentType'] ?? '',
      finalPrice: (json['finalPrice'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0.0,
      saleOrderNo: json['saleOrderNo'] ?? '',
      orderDate: json['orderDate'] ?? '',
      orderTime: json['orderTime'] ?? '',
      employeeName: json['employeeName'] ?? '',
      status: json['status'] ?? '',
      cancelOrderRemark: json['cancelOrderRemark'] ?? '',
      audioUrl: json['audioUrl'],
      eventDate: json['eventDate'],
      orderType: json['orderType'],
      modifiedOrders: (json['modifiedOrders'] as List?)
          ?.map((x) => ModifyOrder.fromJson(x))
          .toList(),
      toApprove: (json['toApprove'] as List?)
          ?.map((x) => ToApprove.fromJson(x))
          .toList(),
      isItemReduced: (json['isItemReduced'] as List?)
          ?.map((e) => e == true)
          .toList(),
      isBoxItem: (json['isBoxItem'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      itemWiseDiscount: (json['itemWiseDiscount'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      itemWiseDiscountAmount: (json['itemWiseDiscountAmount'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      boxQty: json['boxQty'] ?? 0,
      image1: json['image1'],
      image2: json['image2'],
      audio: json['audio'],
      hiveId: json['hiveId'],
    );
  }
  factory SalesOrderDisplay.fromMap(Map<String, dynamic> map) {
    // Determine which part of the map to use
    final orderMap = map.containsKey('data') && map['data'] is Map
        ? Map<String, dynamic>.from(map['data'])
        : map;

    // Helper to parse list fields safely
    List<T> parseList<T>(
      dynamic input,
      T Function(dynamic) parser,
      T defaultValue,
    ) {
      if (input == null) {
        return [defaultValue];
      }
      if (input is List) {
        final result = input.map((v) {
          final parsed = parser(v);

          return parsed ?? defaultValue;
        }).toList();
        return result;
      }
      try {
        final result = [parser(input) ?? defaultValue];

        return result;
      } catch (e) {
        return [defaultValue];
      }
    }

    // Media files extraction
    String image1 = orderMap['imagePath1'] ?? 'No image1 available';
    String image2 = orderMap['imagePath2'] ?? 'No image2 available';
    String audio = orderMap['audioPath'] ?? 'No audio available';

    // Return the populated SalesOrderDisplay object
    final order = SalesOrderDisplay(
      hiveId: orderMap['hiveId']?.toString() ?? '',
      salesOrderId: orderMap['salesOrderId']?.toString() ?? '',
      imagePaths: parseList<String>(
        orderMap['imagePaths'],
        (v) => v.toString(),
        'N/A',
      ),
      itemName: parseList<String>(
        orderMap['itemName'],
        (v) => v.toString(),
        'N/A',
      ),
      varianceName: parseList<String>(
        orderMap['varianceName'],
        (v) => v.toString(),
        'N/A',
      ),
      qty: parseList<int>(
        orderMap['qty'],
        (v) => int.tryParse(v.toString()) ?? 0,
        0,
      ),
      sellingPrice: parseList<int>(
        orderMap['sellingPrice'],
        (v) => int.tryParse(v.toString()) ?? 0,
        0,
      ),
      sellingAmount: parseList<double>(
        orderMap['sellingAmount'],
        (v) => double.tryParse(v.toString()) ?? 0.0,
        0.0,
      ),
      itemWiseDiscount: parseList<double>(
        orderMap['itemWiseDiscount'],
        (v) => double.tryParse(v.toString()) ?? 0.0,
        0.0,
      ),
      itemWiseDiscountAmount: parseList<double>(
        orderMap['itemWiseDiscountAmount'],
        (v) => double.tryParse(v.toString()) ?? 0.0,
        0.0,
      ),
      price: parseList<double>(
        orderMap['price'],
        (v) => double.tryParse(v.toString()) ?? 0.0,
        0.0,
      ),
      itemCode: parseList<String>(
        orderMap['itemCode'],
        (v) => v.toString(),
        'N/A',
      ),
      weight: parseList<double>(
        orderMap['weight'],
        (v) => double.tryParse(v.toString()) ?? 0.0,
        0.0,
      ),
      amount: parseList<double>(
        orderMap['amount'],
        (v) => double.tryParse(v.toString()) ?? 0.0,
        0.0,
      ),
      totalAmount: (orderMap['totalAmount']?.toDouble() ?? 0.0),
      totalAmount2: (orderMap['totalAmount2']?.toDouble()),
      netPrice: (orderMap['netPrice']?.toDouble() ?? 0.0),
      orderInvoiceNo: orderMap['orderInvoiceNo'] ?? '',
      invoiceNo: orderMap['invoiceNo'] ?? '',
      branchId: orderMap['branchId'] ?? '',
      branchName: orderMap['branchName'] ?? '',
      aliasName: orderMap['aliasName'] ?? '',
      customChargeType: parseList<String>(
        orderMap['customChargeType'],
        (v) => v.toString(),
        'N/A',
      ),
      invoiceDate: orderMap['invoiceDate'] ?? '',
      cash: (orderMap['cash']?.toDouble() ?? 0.0),
      card: (orderMap['card']?.toDouble() ?? 0.0),
      upi: (orderMap['upi']?.toDouble() ?? 0.0),
      deliveryPartners: orderMap['deliveryPartners'] ?? '',
      otherPayments: (orderMap['otherPayments']?.toDouble() ?? 0.0),
      deliveryPartnerName: orderMap['deliveryPartnerName'] ?? '',
      shiftId:
          (orderMap['shiftId'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      shiftName: orderMap['shiftName'] ?? '',
      user: orderMap['user'] ?? '',
      deliveryDate: orderMap['deliveryDate'] ?? '',
      deliveryTime: orderMap['deliveryTime'] ?? '',
      event: orderMap['event'] ?? '',
      customerNumber: orderMap['customerNumber'] ?? '',
      customerName: orderMap['customerName'] ?? '',
      deliveryType: orderMap['deliveryType'] ?? '',
      address: orderMap['address'] ?? '',
      landmark: orderMap['landmark'] ?? '',
      discount: orderMap['discount'] != null
          ? (orderMap['discount'] as num).toInt()
          : 0,
      discountAmount: (orderMap['discountAmount']?.toDouble() ?? 0.0),
      remark: orderMap['remark'] ?? '',
      customCharge: parseList<double>(
        orderMap['customCharge'],
        (v) => double.tryParse(v.toString()) ?? 0.0,
        0.0,
      ),
      tax:
          (orderMap['tax'] as List<dynamic>?)
              ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
              .toList() ??
          [],
      uom: List<String>.from(orderMap['uom'] ?? []),
      advanceAmount: parseList<double>(
        orderMap['advanceAmount'],
        (v) => double.tryParse(v.toString()) ?? 0.0,
        0.0,
      ),

      advanceDateTime: List<String>.from(orderMap['advanceDateTime'] ?? []),
      advancePaymentType: orderMap['advancePaymentType'] != null
          ? List<List<String>>.from(
              orderMap['advancePaymentType'].map(
                (x) => List<String>.from(x.map((y) => y.toString())),
              ),
            )
          : null,
      modeWiseAmount: orderMap['modeWiseAmount'] != null
          ? List<List<double>>.from(
              orderMap['modeWiseAmount'].map(
                (x) => List<double>.from(x.map((y) => (y as num).toDouble())),
              ),
            )
          : null,
      paymentType: orderMap['paymentType'] ?? '',
      finalPrice: (orderMap['finalPrice']?.toDouble() ?? 0.0),
      balanceAmount: (orderMap['balanceAmount']?.toDouble() ?? 0.0),
      saleOrderNo: orderMap['saleOrderNo'] ?? '',
      orderDate: orderMap['orderDate'] ?? '',
      orderTime: orderMap['orderTime'] ?? '',
      employeeName: orderMap['employeeName'] ?? '',
      status: orderMap['status'] ?? '',
      cancelOrderRemark: orderMap['cancelOrderRemark'] ?? '',
      eventDate: orderMap['eventDate'] ?? '',
      orderType: orderMap['orderType'] ?? '',
      modifiedOrders: null,
      toApprove: null,
      audioUrl: orderMap['audioUrl'],
      image1: image1,
      image2: image2,
      audio: audio,
      isItemReduced: null,
      isBoxItem: parseList<String>(
        orderMap['isBoxItem'],
        (v) => v.toString(),
        'N/A',
      ),
      totalCustomCharge: (orderMap['totalCustomCharge']?.toDouble() ?? 0.0),
    );

    return order;
  }
  SalesOrderDisplay copyWith({
    List<ModifyOrder>? modifiedOrders,
    List<ToApprove>? toApprove,
  }) {
    return SalesOrderDisplay(
      salesOrderId: salesOrderId,
      itemName: itemName,
      varianceName: varianceName,
      qty: qty,
      price: price,
      sellingPrice: sellingPrice,
      sellingAmount: sellingAmount,

      itemCode: itemCode,
      weight: weight,
      amount: amount,
      tax: tax,
      uom: uom,
      totalAmount: totalAmount,
      totalAmount2: totalAmount2,
      netPrice: netPrice,
      orderInvoiceNo: orderInvoiceNo,
      invoiceNo: invoiceNo,
      branchId: branchId,
      branchName: branchName,
      aliasName: aliasName,
      invoiceDate: invoiceDate,
      cash: cash,
      customChargeType: customChargeType,
      card: card,
      upi: upi,
      deliveryPartners: deliveryPartners,
      otherPayments: otherPayments,
      deliveryPartnerName: deliveryPartnerName,
      shiftId: shiftId,
      shiftName: shiftName,
      user: user,
      deliveryDate: deliveryDate,
      deliveryTime: deliveryTime,
      event: event,
      customerNumber: customerNumber,
      customerName: customerName,
      deliveryType: deliveryType,
      address: address,
      landmark: landmark,
      discount: discount,
      discountAmount: discountAmount,
      remark: remark,
      customCharge: customCharge,
      advanceAmount: advanceAmount,
      advanceDateTime: advanceDateTime,
      advancePaymentType: advancePaymentType,
      modeWiseAmount: modeWiseAmount,
      paymentType: paymentType,
      finalPrice: finalPrice,
      balanceAmount: balanceAmount,
      saleOrderNo: saleOrderNo,
      orderDate: orderDate,
      orderTime: orderTime,
      employeeName: employeeName,
      status: status,
      cancelOrderRemark: cancelOrderRemark,
      audioUrl: audioUrl,
      isItemReduced: isItemReduced,
      orderType: orderType,
      image1: image1,
      image2: image2,
      audio: audio,
      modifiedOrders: modifiedOrders ?? this.modifiedOrders,
      toApprove: toApprove ?? this.toApprove,
      // isBoxItem: isBoxItem ?? this.isBoxItem,
      isBoxItem: this.isBoxItem ?? [],
      totalCustomCharge: totalCustomCharge,
      imagePaths: imagePaths,
    );
  }

  SalesOrderDisplay copytoapprove({List<ToApprove>? toApprove}) {
    return SalesOrderDisplay(
      salesOrderId: salesOrderId,
      itemName: itemName,
      varianceName: varianceName,
      qty: qty,
      price: price,
      itemCode: itemCode,
      sellingPrice: sellingPrice,
      sellingAmount: sellingAmount,
      weight: weight,
      amount: amount,
      tax: tax,
      uom: uom,
      totalAmount: totalAmount,
      totalAmount2: totalAmount2,
      netPrice: netPrice,
      orderInvoiceNo: orderInvoiceNo,
      invoiceNo: invoiceNo,
      branchId: branchId,
      customChargeType: customChargeType,
      branchName: branchName,
      aliasName: aliasName,
      invoiceDate: invoiceDate,
      cash: cash,
      card: card,
      upi: upi,
      deliveryPartners: deliveryPartners,
      otherPayments: otherPayments,
      deliveryPartnerName: deliveryPartnerName,
      shiftId: shiftId,
      shiftName: shiftName,
      user: user,
      deliveryDate: deliveryDate,
      deliveryTime: deliveryTime,
      event: event,
      customerNumber: customerNumber,
      customerName: customerName,
      deliveryType: deliveryType,
      address: address,
      landmark: landmark,
      discount: discount,
      discountAmount: discountAmount,
      remark: remark,
      customCharge: customCharge,
      advanceAmount: advanceAmount,
      advanceDateTime: advanceDateTime,
      modeWiseAmount: modeWiseAmount,
      advancePaymentType: advancePaymentType,
      paymentType: paymentType,
      finalPrice: finalPrice,
      balanceAmount: balanceAmount,
      saleOrderNo: saleOrderNo,
      orderDate: orderDate,
      orderTime: orderTime,
      employeeName: employeeName,
      status: status,
      cancelOrderRemark: cancelOrderRemark,
      audioUrl: audioUrl,
      isItemReduced: isItemReduced,
      orderType: orderType,
      image1: image1,
      image2: image2,
      audio: audio,
      isBoxItem: this.isBoxItem ?? [],
      toApprove: toApprove ?? this.toApprove,
      totalCustomCharge: totalCustomCharge,
      imagePaths: imagePaths,
    );
  }

  Iterable<SalesOrderItem> get items sync* {
    final length = varianceName.length;
    for (int i = 0; i < length; i++) {
      yield SalesOrderItem(
        varianceName: i < varianceName.length ? varianceName[i] : '',
        itemName: i < itemName.length ? itemName[i] : '',
        qty: i < qty.length ? qty[i] : 0,
        price: i < price.length ? price[i] : 0.0,
        itemCode: i < itemCode.length ? itemCode[i] : '',
        weight: i < weight.length ? weight[i] : 0.0,
        amount: i < amount.length ? amount[i] : 0.0,
        tax: i < tax.length ? tax[i] : 0.0,
        uom: i < uom.length ? uom[i] : '',
      );
    }
  }
}

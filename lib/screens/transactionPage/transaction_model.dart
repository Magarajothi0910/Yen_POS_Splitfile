import 'dart:convert';
import 'package:flutter/material.dart';

class Transaction {
  final String holdId;
  final String date;
  final double total;
  final String status;
  final String hiveInvoiceId;
  final List<String> itemName;
  final List<String> varianceName;
  final List<int> price;
  final List<double> weight;
  final List<double> qty;
  final List<double> amount;
  final List<double> tax;
  final List<String> uom;
  final String employeeName;
  final String customerPhoneNumber;
  final double discountPercentage;
  final double customCharge;
  final double totalAmount;
  final double totalAmount2;
  final String invoiceDate;
  final String branchId;
  final String salesType;
  final String branchName;
  final String paymentType;
  final String invoiceTime;
  final String invoiceNo;
  final String sync;
  final String uniqueIdentifier;

  Transaction({
    required this.holdId,
    required this.date,
    required this.total,
    required this.status,
    required this.hiveInvoiceId,
    required this.itemName,
    required this.varianceName,
    required this.price,
    required this.weight,
    required this.qty,
    required this.amount,
    required this.tax,
    required this.uom,
    required this.employeeName,
    required this.customerPhoneNumber,
    required this.discountPercentage,
    required this.customCharge,
    required this.totalAmount,
    required this.totalAmount2,
    required this.invoiceDate,
    required this.branchId,
    required this.salesType,
    required this.branchName,
    required this.paymentType,
    required this.invoiceTime,
    required this.invoiceNo,
    required this.sync,
    required this.uniqueIdentifier,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    final orderMap = map.containsKey('data') && map['data'] is Map
        ? Map<String, dynamic>.from(map['data'])
        : map;

    // Helper to parse list fields safely
    List<T> parseList<T>(
        dynamic input, T Function(dynamic) parser, T defaultValue) {
      if (input == null) return <T>[];
      if (input is List) {
        return input.map((v) {
          try {
            return parser(v);
          } catch (_) {
            return defaultValue;
          }
        }).toList();
      }
      try {
        return [parser(input)];
      } catch (e) {
        debugPrint('❌ Failed to parse input: $input, error: $e');
        return <T>[];
      }
    }

    return Transaction(
      itemName:
          parseList<String>(orderMap['itemName'], (v) => v.toString(), 'N/A'),
      varianceName: parseList<String>(
          orderMap['varianceName'], (v) => v.toString(), 'N/A'),
      qty: parseList<double>(
          orderMap['qty'], (v) => double.tryParse(v.toString()) ?? 0.0, 0.0),
      price: parseList<int>(
          orderMap['price'], (v) => int.tryParse(v.toString()) ?? 0, 0),
      weight: parseList<double>(
          orderMap['weight'], (v) => double.tryParse(v.toString()) ?? 0.0, 0.0),
      amount: parseList<double>(
          orderMap['amount'], (v) => double.tryParse(v.toString()) ?? 0.0, 0.0),
      tax: (orderMap['tax'] as List<dynamic>?)
              ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
              .toList() ??
          [],
      uom: (orderMap['uom'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      totalAmount:
          double.tryParse(orderMap['totalAmount']?.toString() ?? '0') ?? 0.0,
      totalAmount2:
          double.tryParse(orderMap['totalAmount2']?.toString() ?? '0') ?? 0.0,
      customCharge:
          double.tryParse(orderMap['customCharge']?.toString() ?? '0') ?? 0.0,
      discountPercentage:
          double.tryParse(orderMap['discountPercentage']?.toString() ?? '0') ??
              0.0,
      total: double.tryParse(orderMap['total']?.toString() ?? '0') ?? 0.0,
      branchId: orderMap['branchId']?.toString() ?? '',
      branchName: orderMap['branchName']?.toString() ?? '',
      invoiceDate: orderMap['invoiceDate']?.toString() ?? '',
      paymentType: orderMap['paymentType']?.toString() ?? '',
      employeeName: orderMap['employeeName']?.toString() ?? '',
      status: orderMap['status']?.toString() ?? '',
      holdId: orderMap['holdId']?.toString() ?? '',
      date: orderMap['date']?.toString() ?? '',
      hiveInvoiceId: orderMap['hiveInvoiceId']?.toString() ?? '',
      customerPhoneNumber: orderMap['customerPhoneNumber']?.toString() ?? '',
      salesType: orderMap['salesType']?.toString() ?? '',
      invoiceTime: orderMap['invoiceTime']?.toString() ?? '',
      invoiceNo: orderMap['invoiceNo']?.toString() ?? '',
      sync: orderMap['sync']?.toString() ?? '',
      uniqueIdentifier: orderMap['uniqueIdentifier']?.toString() ?? '',
    );
  }
}

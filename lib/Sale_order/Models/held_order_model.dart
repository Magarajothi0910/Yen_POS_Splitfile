import 'package:yen_pos/Sale_order/Models/approval_order_model.dart';

class ApprovalDetail {
  final String approvalStatus;
  final String summary;
  final String? approvalDate;
  final String? approvedBy;
  final String? approvalType;
  final List<double>? previousDiscount;
  final List<double>? previousDiscountAmount;

  ApprovalDetail({
    required this.approvalStatus,
    required this.summary,
    this.approvalDate,
    this.approvedBy,
    this.previousDiscount,
    this.previousDiscountAmount,
    this.approvalType,
  });

  factory ApprovalDetail.fromMap(Map<String, dynamic> map) {
    return ApprovalDetail(
      approvalStatus: map['approvalStatus'] ?? '',
      approvalType: map['approvalType'] ?? '',
      summary: map['summary'] ?? '',
      approvalDate: map['approvalDate'] ?? 'N/A',
      approvedBy: map['approvedBy'] ?? 'N/A',
      previousDiscount: map['previousDiscount'] != null
          ? List<double>.from(map['previousDiscount'].map((x) => x.toDouble()))
          : [],
      previousDiscountAmount: map['previousDiscountAmount'] != null
          ? List<double>.from(
              map['previousDiscountAmount'].map((x) => x.toDouble()),
            )
          : [],
    );
  }
}

class HeldOrder {
  String salesOrderId;
  List<String> itemName;
  List<String> varianceName;
  List<double> weight;
  List<int> qty;
  List<int> price;
  String? branchName;
  String? aliasName;
  List<double> sellingAmount;
  List<int> sellingPrice;

  final String? audioPath;
  List<String> itemCode;
  List<int> tax;
  List<String> uom;
  List<double> amount;
  String? deliveryDate;
  String? deliveryTime;
  String event;
  String? branchId;

  String customerNumber;
  String customerName;
  String deliveryType;
  String address;
  String landmark;
  double discount;
  double discountAmount;
  String? remark;
  List<double>? customCharge;
  List<String>? imagePaths;
  double? totalCustomCharge;
  double totalAmount;
  double? totalAmount2;
  double? cash;
  double? card;
  double? upi;
  List<String>? customChargeType;
  double finalPrice;
  double? balanceAmount;
  String saleOrderNo;
  String? orderDate;
  String? holdOrderId;
  String? orderTime;
  String employeeName;
  String status;
  List<String>? shiftId;
  String? companyName;
  String? companyAddress;
  String? companyGST;
  List<String>? advanceDateTime;
  String? orderType;
  String? eventDate;
  List<String>? isBoxItem;
  List<double>? itemWiseDiscount;
  List<double>? itemWiseDiscountAmount;
  int? boxQty; // ✅ single int now
  List<ApprovalOrderDetail>? approvalDetails;
  String? approvalOrderId;

  HeldOrder({
    required this.salesOrderId,
    required this.itemName,
    required this.itemCode,
    required this.varianceName,
    this.branchName,
    this.aliasName,
    this.branchId,
    this.itemWiseDiscount,
    this.itemWiseDiscountAmount,
    required this.customChargeType,
    required this.weight,
    required this.amount,
    required this.tax,
    this.totalAmount2,
    required this.sellingPrice,
    required this.sellingAmount,
    required this.uom,
    required this.qty,
    required this.price,
    required this.totalAmount,
    required this.holdOrderId,
    this.deliveryDate,
    this.deliveryTime,
    required this.event,
    this.shiftId,
    this.boxQty,
    this.cash,
    this.card,
    this.upi,
    this.imagePaths,

    required this.customerNumber,
    required this.customerName,
    required this.deliveryType,
    required this.address,
    required this.landmark,
    required this.discount,
    required this.discountAmount,
    this.remark,
    this.customCharge,
    required this.finalPrice,
    this.balanceAmount,
    required this.saleOrderNo,
    this.orderDate,
    this.orderTime,
    required this.employeeName,
    required this.status,
    this.companyGST,
    this.companyAddress,
    this.companyName,
    this.advanceDateTime,
    this.orderType,
    this.isBoxItem,
    this.approvalDetails,
    this.approvalOrderId,
    this.eventDate,

    this.totalCustomCharge,
    this.audioPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'salesOrderId': salesOrderId,
      'itemName': itemName,
      'varianceName': varianceName,
      'itemCode': itemCode,
      'qty': qty,
      'tax': tax,
      'uom': uom,
      'amount': amount,
      'branchId': branchId,
      'customChargeType': customChargeType,
      'branchName': branchName,
      'price': price,
      'weight': weight,
      'sellingPrice': sellingPrice,
      'sellingAmount': sellingAmount,
      'totalCustomCharge': totalCustomCharge,
      'totalAmount2': totalAmount2,
      'deliveryDate': deliveryDate,
      'deliveryTime': deliveryTime,
      'totalAmount': totalAmount,
      'event': event,
      'customerNumber': customerNumber,
      'customerName': customerName,
      'deliveryType': deliveryType,
      "shiftId": shiftId ?? "",
      "aliasName": aliasName,
      'address': address,
      'landmark': landmark,
      'discount': discount,
      'discountAmount': discountAmount,
      'remark': remark,
      'customCharge': customCharge,
      'finalPrice': finalPrice,
      'balanceAmount': balanceAmount,
      'saleOrderNo': saleOrderNo,
      'orderDate': orderDate,
      'orderTime': orderTime,
      'employeeName': employeeName,
      'status': status,
      'cash': cash,
      'card': card,
      'upi': upi,
      "imagePaths": imagePaths,
      'holdOrderId': holdOrderId,
      'advanceDateTime': advanceDateTime,
      'companyGST': companyGST,
      'companyAddress': companyAddress,
      'companyName': companyName,
      'orderType': orderType,
      'eventDate': eventDate,
      'isBoxItem': isBoxItem,
      'itemWiseDiscount': itemWiseDiscount,
      'itemWiseDiscountAmount': itemWiseDiscountAmount,
      'boxQty': boxQty,
      'approvalDetails': approvalDetails?.map((x) => x.toJson()).toList(),
      'approvalOrderId': approvalOrderId,

      'audioPath': audioPath,
    };
  }

  factory HeldOrder.fromMap(Map<String, dynamic> map) {
    return HeldOrder(
      salesOrderId: map['salesOrderId']?.toString() ?? '',
      itemName: List<String>.from(map['itemName'] ?? []),
      varianceName: List<String>.from(map['varianceName'] ?? []),
      itemCode: List<String>.from(map['itemCode'] ?? []),
      uom: List<String>.from(map['uom'] ?? []),
      weight: map['weight'] != null
          ? List<double>.from(
              (map['weight'] as List).map((e) => (e as num).toDouble()),
            )
          : [],
      amount: map['amount'] != null
          ? List<double>.from(
              (map['amount'] as List).map((e) => (e as num).toDouble()),
            )
          : [],
      sellingAmount: map['sellingAmount'] != null
          ? List<double>.from(
              (map['sellingAmount'] as List).map((e) => (e as num).toDouble()),
            )
          : [],
      sellingPrice: List<int>.from(map['sellingPrice'] ?? []),
      tax: List<int>.from(map['tax'] ?? []),
      qty: List<int>.from(map['qty'] ?? []),
      customChargeType: List<String>.from(map['customChargeType'] ?? []),
      customCharge: map['customCharge'] != null
          ? List<double>.from(
              (map['customCharge'] as List).map((e) => (e as num).toDouble()),
            )
          : [],
      price: List<int>.from(map['price'] ?? []),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      totalAmount2: map['totalAmount2'] != null
          ? (map['totalAmount2'] as num).toDouble()
          : null,
      cash: map['cash'] != null ? (map['cash'] as num).toDouble() : null,
      card: map['card'] != null ? (map['card'] as num).toDouble() : null,
      upi: map['upi'] != null ? (map['upi'] as num).toDouble() : null,
      finalPrice: (map['finalPrice'] ?? 0).toDouble(),
      balanceAmount: map['balanceAmount'] != null
          ? (map['balanceAmount'] as num).toDouble()
          : null,
      deliveryDate: map['deliveryDate']?.toString(),
      deliveryTime: map['deliveryTime']?.toString(),
      event: map['event']?.toString() ?? '',
      branchName: map['branchName']?.toString(),
      aliasName: map['aliasName']?.toString(),
      branchId: map['branchId']?.toString(),
      holdOrderId: map['holdOrderId']?.toString(),
      customerNumber: map['customerNumber']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      deliveryType: map['deliveryType']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      landmark: map['landmark']?.toString() ?? '',
      discount: (map['discount'] ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      remark: map['remark']?.toString(),
      totalCustomCharge: map['totalCustomCharge'] != null
          ? (map['totalCustomCharge'] as num).toDouble()
          : null,
      saleOrderNo: map['saleOrderNo']?.toString() ?? '',
      orderDate: map['orderDate']?.toString(),
      orderTime: map['orderTime']?.toString(),
      employeeName: map['employeeName']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      shiftId: List<String>.from(map['shiftId'] ?? []),

      companyName: map['companyName']?.toString(),
      companyAddress: map['companyAddress']?.toString(),
      companyGST: map['companyGST']?.toString(),
      advanceDateTime: map['advanceDateTime'] != null
          ? List<String>.from(map['advanceDateTime'])
          : null,
      orderType: map['orderType']?.toString(),
      eventDate: map['eventDate']?.toString(),
      isBoxItem: map['isBoxItem'] != null
          ? List<String>.from(map['isBoxItem'])
          : null,
      itemWiseDiscount: map['itemWiseDiscount'] != null
          ? List<double>.from(
              (map['itemWiseDiscount'] as List).map(
                (e) => (e as num).toDouble(),
              ),
            )
          : null,
      itemWiseDiscountAmount: map['itemWiseDiscountAmount'] != null
          ? List<double>.from(
              (map['itemWiseDiscountAmount'] as List).map(
                (e) => (e as num).toDouble(),
              ),
            )
          : null,
      boxQty: map['boxQty'] != null
          ? (map['boxQty'] as num).toInt()
          : null, // ✅ fixed
      approvalDetails: map['approvalDetails'] != null
          ? List<ApprovalOrderDetail>.from(
              (map['approvalDetails'] as List).map(
                (x) => ApprovalOrderDetail.fromMap(x),
              ),
            )
          : null,
      approvalOrderId: map['approvalOrderId']?.toString(),

      audioPath: map['audioPath']?.toString(),
      imagePaths: map['imagePaths'] != null
          ? List<String>.from(map['imagePaths'].map((x) => x.toString()))
          : null,
    );
  }

  factory HeldOrder.fromJson(Map<String, dynamic> json) {
    return HeldOrder.fromMap(json);
  }
}

class CreditOrder {
  String creditBillId;
  List<String> itemName;
  List<String>? varianceName;
  List<double> price;
  List<double> weight;
  List<double> qty;
  List<double> amount;
  List<double> tax;
  List<String> uom;
  String? deliveryDate;
  String? deliveryTime;
  double? totalAmount;
  double? totalAmount2;
  double? totalAmount3;
  String? status;
  String? branch;
  String? branchId;
  double? discountPercentage;
  double? discountAmount;
  String? employeeName;
  String phoneNumber; // Ensure this is treated as a String
  double? customCharge;
  double? netPrice;
  String? date;
  String? time;
  String? paymentType;
  String? deliveryType;
  String? salesType;
  String? salesReturn;
  String? customerName;
  String? customerNumber2;
  String? customerAddress;
  String? creditBillNo;
  double? balanceAmount;

  CreditOrder({
    required this.creditBillId,
    required this.itemName,
    this.varianceName,
    required this.price,
    this.deliveryDate,
    this.deliveryTime,
    required this.weight,
    required this.qty,
    required this.amount,
    required this.tax,
    required this.uom,
    this.totalAmount,
    this.totalAmount2,
    this.totalAmount3,
    this.status,
    this.branch,
    this.branchId,
    this.discountPercentage,
    this.discountAmount,
    this.employeeName,
    required this.phoneNumber,
    this.customCharge,
    this.netPrice,
    this.date,
    this.time,
    this.paymentType,
    this.deliveryType,
    this.salesType,
    this.salesReturn,
    this.customerName,
    this.customerNumber2,
    this.customerAddress,
    this.creditBillNo,
    this.balanceAmount,
  });

  // Convert an instance to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'creditBillId': creditBillId,
      'itemName': itemName,
      'varianceName': varianceName,
      'price': price,
      'weight': weight,
      'qty': qty,
      'amount': amount,
      'tax': tax,
      'uom': uom,
      'deliveryDate': deliveryDate,
      'deliveryTime': deliveryTime,
      'totalAmount': totalAmount,
      'totalAmount2': totalAmount2,
      'totalAmount3': totalAmount3,
      'status': status,
      'branch': branch,
      'branchId': branchId,
      'discountPercentage': discountPercentage,
      'discountAmount': discountAmount,
      'employeeName': employeeName,
      'phoneNumber': phoneNumber, // Ensure phone number is sent as string
      'customCharge': customCharge,
      'netPrice': netPrice,
      'date': date,
      'time': time,
      'paymentType': paymentType,
      'deliveryType': deliveryType,
      'salesType': salesType,
      'salesReturn': salesReturn,
      'customerName': customerName,
      'customerNumber2': customerNumber2,
      'customerAddress': customerAddress,
      'creditBillNo': creditBillNo,
      'balanceAmount': balanceAmount,
    };
  }

  // Create an instance from a JSON object
  factory CreditOrder.fromJson(Map<String, dynamic> json) {
    return CreditOrder(
      creditBillId: json['creditBillId'] ?? '',
      itemName: List<String>.from(json['itemName'] ?? []),
      varianceName: json['varianceName'] != null
          ? List<String>.from(json['varianceName'])
          : null,
      price: List<double>.from(json['price'] ?? []),
      weight: List<double>.from(json['weight'] ?? []),
      qty: List<double>.from(json['qty'] ?? []),
      amount: List<double>.from(json['amount'] ?? []),
      tax: List<double>.from(json['tax'] ?? []),
      uom: List<String>.from(json['uom'] ?? []),
      totalAmount: json['totalAmount']?.toDouble(),
      totalAmount2: json['totalAmount2']?.toDouble(),
      totalAmount3: json['totalAmount3']?.toDouble(),
      status: json['status'] ?? '',
      branch: json['branch'] ?? '',
      branchId: json['branchId'] ?? '',
      discountPercentage: json['discountPercentage']?.toDouble(),
      discountAmount: json['discountAmount']?.toDouble(),
      employeeName: json['employeeName'] ?? '',
      phoneNumber:
          json['phoneNumber']?.toString() ??
          '', // Ensure this is converted to String
      customCharge: json['customCharge']?.toDouble(),
      netPrice: json['netPrice']?.toDouble(),
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      deliveryDate: json['deliveryDate'] ?? '',
      deliveryTime: json['deliveryTime'] ?? '',
      paymentType: json['paymentType'] ?? '',
      deliveryType: json['deliveryType'] ?? '',
      salesType: json['salesType'] ?? '',
      salesReturn: json['salesReturn'] ?? '',
      customerName: json['customerName'] ?? '',
      customerNumber2: json['customerNumber2'] ?? '',
      customerAddress: json['customerAddress'] ?? '',
      creditBillNo: json['creditBillNo'] ?? '',
      balanceAmount: json['balanceAmount'],
    );
  }
}

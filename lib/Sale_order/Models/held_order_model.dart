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
          ? List<double>.from(
              map['previousDiscount'].map((x) => x.toDouble()),
            )
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
  String holdOrderId;

  List<String> itemName;
  List<String> varianceName;
  List<double> weight;
  List<int> qty;
  List<int> price;
  List<String> itemCode;
  List<int> tax;
  List<String> uom;
  List<double> amount;
  String? deliveryDate;
  String? deliveryTime;
  String? event;
  String? customerNumber;
  String? customerName;
  String? deliveryType;
  String? address;
  String? eventDate;
  String? landmark;
  List<double>? itemWiseDiscount;
  List<double>? itemWiseDiscountAmount;
  String saleOrderNo;
  String orderDate;
  String orderTime;
  String employeeName;
  String status;
  String? remarks;
  List<ApprovalDetail>? approvalDetails;

  HeldOrder({
    required this.salesOrderId,
    required this.itemName,
    required this.varianceName,
    required this.itemCode,
    required this.weight,
    required this.amount,
    required this.tax,
    required this.uom,
    required this.qty,
    required this.price,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.event,
    required this.customerNumber,
    required this.customerName,
    required this.deliveryType,
    required this.address,
    required this.landmark,
    required this.saleOrderNo,
    required this.orderDate,
    required this.orderTime,
    required this.holdOrderId,
    required this.employeeName,
    required this.status,
    required this.itemWiseDiscount,
    required this.itemWiseDiscountAmount,
    required this.eventDate,
    required this.remarks,
    this.approvalDetails,
  });

  // Convert an instance to a JSON object
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
      'price': price,
      'weight': weight,
      'deliveryDate': deliveryDate,
      'deliveryTime': deliveryTime,
      'event': event,
      'customerNumber': customerNumber,
      'customerName': customerName,
      'deliveryType': deliveryType,
      'address': address,
      'landmark': landmark,
      'saleOrderNo': saleOrderNo,
      'orderDate': orderDate,
      'orderTime': orderTime,
      'itemWiseDiscount': itemWiseDiscount,
      'itemWiseDiscountAmount': itemWiseDiscountAmount,
      'employeeName': employeeName,
      'status': status,
      "eventDate": eventDate,
      'remarks': remarks,
      'holdOrderId': holdOrderId,
    };
  }

  factory HeldOrder.fromMap(Map<String, dynamic> map) {
    // Debugging

    return HeldOrder(
      salesOrderId: (map['salesOrderId'] ?? '').toString(),
      itemName: List<String>.from(map['itemName'] ?? []),
      varianceName: List<String>.from(map['varianceName'] ?? []),
      weight: List<double>.from(
        (map['weight'] ?? []).map((e) => (e as num).toDouble()),
      ),
      qty: List<int>.from(
        (map['qty'] ?? []).map((e) => (e as num).toInt()),
      ),
      price: List<int>.from(
        (map['price'] ?? []).map((e) => (e as num).toInt()),
      ),
      itemCode: List<String>.from(map['itemCode'] ?? []),
      tax: List<int>.from(
        (map['tax'] ?? []).map((e) => (e as num).toInt()),
      ),
      uom: List<String>.from(map['uom'] ?? []),
      amount: List<double>.from(
        (map['amount'] ?? []).map((e) => (e as num).toDouble()),
      ),
      deliveryDate: map['deliveryDate']?.toString() ?? '',
      deliveryTime: map['deliveryTime']?.toString() ?? '',
      event: map['event']?.toString() ?? '',
      customerNumber: map['customerNumber']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      deliveryType: map['deliveryType']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      landmark: map['landmark']?.toString() ?? '',
      saleOrderNo: map['saleOrderNo']?.toString() ?? '',
      orderDate: map['orderDate']?.toString() ?? '',
      orderTime: map['orderTime']?.toString() ?? '',
      employeeName: map['employeeName']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      eventDate: map['eventDate']?.toString() ?? '',
      remarks: map['remarks']?.toString() ?? '',
      holdOrderId: map['holdOrderId']?.toString() ?? '',
      itemWiseDiscount: (map['itemWiseDiscount'] != null)
          ? List<double>.from(
              (map['itemWiseDiscount'] as List)
                  .map((e) => (e as num).toDouble()),
            )
          : [],
      itemWiseDiscountAmount: (map['itemWiseDiscountAmount'] != null)
          ? List<double>.from(
              (map['itemWiseDiscountAmount'] as List)
                  .map((e) => (e as num).toDouble()),
            )
          : [],
      approvalDetails: (map['approvalDetails'] is List)
          ? (map['approvalDetails'] as List)
              .map((e) {
                if (e is Map) {
                  return ApprovalDetail.fromMap(Map<String, dynamic>.from(e));
                }
                return null;
              })
              .whereType<ApprovalDetail>()
              .toList()
          : [],
    );
  }

  factory HeldOrder.fromJson(Map<String, dynamic> json) {
    return HeldOrder(
      salesOrderId: json['salesOrderId'] ?? '',
      itemName: List<String>.from(json['itemName'] ?? []),
      varianceName: List<String>.from(json['varianceName'] ?? []),
      itemCode: List<String>.from(json['itemCode'] ?? []),
      qty: List<int>.from(json['qty'] ?? []),
      tax: List<int>.from(json['tax'] ?? []),
      uom: List<String>.from(json['uom'] ?? []),
      amount: List<double>.from(
        (json['amount'] ?? []).map((e) => (e as num).toDouble()),
      ),
      price: List<int>.from(json['price'] ?? []),
      weight: List<double>.from(
        (json['weight'] ?? []).map((e) => (e as num).toDouble()),
      ),
      deliveryDate: json['deliveryDate'] ?? '',
      deliveryTime: json['deliveryTime'] ?? '',
      event: json['event'] ?? '',
      holdOrderId: json['holdOrderId'],
      customerNumber: json['customerNumber'] ?? '',
      customerName: json['customerName'] ?? '',
      deliveryType: json['deliveryType'] ?? '',
      address: json['address'] ?? '',
      landmark: json['landmark'] ?? '',
      saleOrderNo: json['saleOrderNo'] ?? '',
      orderDate: json['orderDate'] ?? '',
      orderTime: json['orderTime'] ?? '',
      employeeName: json['employeeName'] ?? '',
      eventDate: json['eventDate'] ?? '',
      remarks: json['remarks'] ?? '',
      status: json['status'] ?? '',
      itemWiseDiscount: (json['itemWiseDiscount'] != null)
          ? List<double>.from(
              (json['itemWiseDiscount'] as List)
                  .map((e) => (e as num).toDouble()),
            )
          : [],
      itemWiseDiscountAmount: (json['itemWiseDiscountAmount'] != null)
          ? List<double>.from(
              (json['itemWiseDiscountAmount'] as List)
                  .map((e) => (e as num).toDouble()),
            )
          : [],
      approvalDetails: List<ApprovalDetail>.from(
        json['approvalDetails']?.map((x) => ApprovalDetail.fromMap(x)) ?? [],
      ),
    );
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
      phoneNumber: json['phoneNumber']?.toString() ??
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

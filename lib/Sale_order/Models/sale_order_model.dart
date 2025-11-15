import 'approval_order_model.dart';

class SalesOrder {
  List<String> itemName;
  List<String> varianceName;
  List<double> weight;
  List<int> qty;
  List<int> price;
  String? branchName;
  String? aliasName;

  final String? imagePath1;
  final String? imagePath2;
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
  String remark;
  double? customCharge;
  String? customChargeType;

  List<double> advanceAmount;
  double totalAmount;
  double? totalAmount2;
  double? cash;
  double? card;
  double? upi;
  List<List<String>>? advancePaymentType;
  List<List<double>>? modeWiseAmount;
  double finalPrice;
  double balanceAmount;
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
  List<String>? advanceDateTime; // ✅ fixed
  String? orderType;
  String? eventDate;
  List<String>? isBoxItem;
  List<double>? itemWiseDiscount;
  List<double>? itemWiseDiscountAmount;
  int? boxQty;
  List<ApprovalOrderDetail>? approvalDetails;
  String? approvalOrderId;

  SalesOrder({
    required this.itemName,
    required this.itemCode,
    required this.varianceName,
    this.branchName,
    this.aliasName,
    this.branchId,
    this.itemWiseDiscount,
    this.itemWiseDiscountAmount,
    required this.weight,
    required this.amount,
    required this.tax,
    required this.customChargeType,
    this.totalAmount2,
    required this.uom,
    required this.qty,
    required this.price,
    required this.totalAmount,
    required this.holdOrderId,
    this.deliveryDate,
    this.deliveryTime,
    required this.event,
    required this.shiftId,
    this.boxQty,
    this.cash,
    this.card,
    this.upi,
    required this.customerNumber,
    required this.customerName,
    required this.deliveryType,
    required this.address,
    required this.landmark,
    required this.discount,
    required this.discountAmount,
    required this.remark,
    this.customCharge,
    required this.advanceAmount,
    this.advancePaymentType,
    this.modeWiseAmount,
    required this.finalPrice,
    required this.balanceAmount,
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
    this.imagePath1,
    this.imagePath2,
    this.audioPath,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    return SalesOrder(
      itemName: List<String>.from(
        json['itemName']?.map((x) => x.toString()) ?? [],
      ),
      varianceName: List<String>.from(
        json['varianceName']?.map((x) => x.toString()) ?? [],
      ),
      itemCode: List<String>.from(
        json['itemCode']?.map((x) => x.toString()) ?? [],
      ),
      qty: List<int>.from(json['qty'] ?? []),
      tax: List<int>.from(json['tax'] ?? []),
      uom: List<String>.from(json['uom']?.map((x) => x.toString()) ?? []),
      amount: List<double>.from(
        json['amount']?.map((x) => (x as num).toDouble()) ?? [],
      ),
      weight: List<double>.from(
        json['weight']?.map((x) => (x as num).toDouble()) ?? [],
      ),
      price: List<int>.from(json['price'] ?? []),
      totalAmount2: (json['totalAmount2'] as num?)?.toDouble(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryDate: json['deliveryDate']?.toString(),
      deliveryTime: json['deliveryTime']?.toString(),
      branchId: json['branchId']?.toString(),
      holdOrderId: json['holdOrderId']?.toString(),
      branchName: json['branchName']?.toString(),
      customChargeType: json["customChargeType"]?.toString(),
      aliasName: json['aliasName']?.toString(),
      shiftId: json['shiftId'] != null
          ? List<String>.from(json['shiftId'].map((x) => x.toString()))
          : null,

      event: json['event']?.toString() ?? '',
      customerNumber: json['customerNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      deliveryType: json['deliveryType']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      landmark: json['landmark']?.toString() ?? '',
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      remark: json['remark']?.toString() ?? '',
      boxQty: json['boxQty'] ?? 0,
      customCharge: (json['customCharge'] as num?)?.toDouble() ?? 0.0,
      advanceAmount: List<double>.from(
        json['advanceAmount']?.map((x) => (x as num).toDouble()) ?? [],
      ),
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
      finalPrice: (json['finalPrice'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0.0,
      saleOrderNo: json['saleOrderNo']?.toString() ?? '',
      orderDate: json['orderDate']?.toString(),
      orderTime: json['orderTime']?.toString(),
      employeeName: json['employeeName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      cash: (json['cash'] as num?)?.toDouble(),
      card: (json['card'] as num?)?.toDouble(),
      upi: (json['upi'] as num?)?.toDouble(),
      advanceDateTime: List<String>.from(json['advanceDateTime'] ?? []),
      companyGST: json['companyGST']?.toString(),
      companyAddress: json['companyAddress']?.toString(),
      companyName: json['companyName']?.toString(),
      orderType: json['orderType']?.toString(),
      eventDate: json['eventDate']?.toString(),
      isBoxItem: json['isBoxItem'] != null
          ? List<String>.from(json['isBoxItem'].map((x) => x.toString()))
          : null,
      approvalOrderId: json['approvalOrderId']?.toString(),
      approvalDetails: json['approvalDetails'] != null
          ? List<ApprovalOrderDetail>.from(
              json['approvalDetails'].map(
                (x) => ApprovalOrderDetail.fromJson(x),
              ),
            )
          : null,
      imagePath1: json['imagePath1']?.toString(),
      imagePath2: json['imagePath2']?.toString(),
      audioPath: json['audioPath']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'varianceName': varianceName,
      'itemCode': itemCode,
      'qty': qty,
      'tax': tax,
      'uom': uom,
      'amount': amount,
      'branchId': branchId,
      'branchName': branchName,
      'price': price,
      'weight': weight,
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
      "customChargeType": customChargeType,
      'discount': discount,
      'discountAmount': discountAmount,
      'remark': remark,
      'customCharge': customCharge,
      'advanceAmount': advanceAmount,
      'advancePaymentType': advancePaymentType,
      'modeWiseAmount': modeWiseAmount,
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
      'imagePath1': imagePath1,
      'imagePath2': imagePath2,
      'audioPath': audioPath,
    };
  }
}

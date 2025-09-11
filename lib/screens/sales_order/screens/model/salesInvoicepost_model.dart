class SalesInvoicePost {
  // Defining the properties of the class
  List<String>? itemName;
  List<String>? varianceName;
  List<double>? price;
  List<double>? weight;
  List<int>? qty;
  List<double>? amount;
  List<double>? tax;
  List<String>? uom;
  double? totalAmount;
  double? totalAmount2;
  double? totalAmount3;
  String? status;
  String? salesType;
  String? customerPhoneNumber;
  String? employeeName;
  String? branchId;
  String? branchName;
  String? paymentType;
  int? cash;
  int? card;
  int? upi;
  String? others;
  String? invoiceDate;
  String? invoiceTime;
  int? shiftNumber;
  int? shiftId;
  dynamic invoiceNo;
  int? deviceNumber;
  int? customCharge;
  double? discountAmount;
  int? discountPercentage;
  List<String>? user;
  String? deviceCode;

  // Constructor to initialize the class
  SalesInvoicePost({
    this.itemName,
    this.varianceName,
    this.price,
    this.weight,
    this.qty,
    this.amount,
    this.tax,
    this.uom,
    this.totalAmount,
    this.totalAmount2,
    this.totalAmount3,
    this.status,
    this.salesType,
    this.customerPhoneNumber = "No Number",
    this.employeeName,
    this.branchId,
    this.branchName,
    this.paymentType,
    this.cash,
    this.card,
    this.upi,
    this.others,
    this.invoiceDate,
    this.invoiceTime,
    this.shiftNumber,
    this.shiftId,
    this.invoiceNo,
    this.deviceNumber,
    this.customCharge,
    this.discountAmount,
    this.discountPercentage,
    this.user,
    this.deviceCode,
  });

  // Method to convert the SalesInvoicePost object to JSON format
  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'varianceName': varianceName,
      'price': price,
      'weight': weight,
      'qty': qty,
      'amount': amount,
      'tax': tax,
      'uom': uom,
      'totalAmount': totalAmount,
      'totalAmount2': totalAmount2,
      'totalAmount3': totalAmount3,
      'status': status,
      'salesType': salesType,
      'customerPhoneNumber': customerPhoneNumber,
      'employeeName': employeeName,
      'branchId': branchId,
      'branchName': branchName,
      'paymentType': paymentType,
      'cash': cash,
      'card': card,
      'upi': upi,
      'others': others,
      'invoiceDate': invoiceDate,
      'invoiceTime': invoiceTime,
      'shiftNumber': shiftNumber,
      'shiftId': shiftId,
      'invoiceNo': invoiceNo,
      'deviceNumber': deviceNumber,
      'customCharge': customCharge,
      'discountAmount': discountAmount,
      'discountPercentage': discountPercentage,
      'user': user,
      'deviceCode': deviceCode,
    };
  }

  // Method to create an object from a JSON map
  factory SalesInvoicePost.fromJson(Map<String, dynamic> json) {
    return SalesInvoicePost(
      itemName: List<String>.from(json['itemName'] ?? []),
      varianceName: List<String>.from(json['varianceName'] ?? []),
      price: List<double>.from(json['price'] ?? []),
      weight: List<double>.from(json['weight'] ?? []),
      qty: List<int>.from(json['qty'] ?? []),
      amount: List<double>.from(json['amount'] ?? []),
      tax: List<double>.from(json['tax'] ?? []),
      uom: List<String>.from(json['uom'] ?? []),
      totalAmount: json['totalAmount']?.toDouble(),
      totalAmount2: json['totalAmount2']?.toDouble(),
      totalAmount3: json['totalAmount3']?.toDouble(),
      status: json['status'],
      salesType: json['salesType'],
      customerPhoneNumber: json['customerPhoneNumber'] ?? "No Number",
      employeeName: json['employeeName'],
      branchId: json['branchId'],
      branchName: json['branchName'],
      paymentType: json['paymentType'],
      cash: json['cash'],
      card: json['card'],
      upi: json['upi'],
      others: json['others'],
      invoiceDate: json['invoiceDate'],
      invoiceTime: json['invoiceTime'],
      shiftNumber: json['shiftNumber'],
      shiftId: json['shiftId'],
      invoiceNo: json['invoiceNo'],
      deviceNumber: json['deviceNumber'],
      customCharge: json['customCharge'],
      discountAmount: json['discountAmount']?.toDouble(),
      discountPercentage: json['discountPercentage'],
      user: List<String>.from(json['user'] ?? []),
      deviceCode: json['deviceCode'],
    );
  }
}

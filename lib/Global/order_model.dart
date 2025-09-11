class OrderData {
  String deliveryDate;
  String deliveryTime;
  String event;
  String deliveryType;
  String? landmark;
  String? address;
  String customerName;
  String customerMobile;
  String employeeName;

  OrderData({
    required this.deliveryDate,
    required this.deliveryTime,
    required this.event,
    required this.deliveryType,
    this.landmark,
    this.address,
    required this.customerName,
    required this.customerMobile,
    required this.employeeName,
  });
}

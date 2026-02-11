class Shift {
  final String shiftId;
  final int shiftNumber;
  final String shiftOpeningDate;
  final String shiftOpeningTime;
  final String shiftClosingDate;
  final String shiftClosingTime;
  final double systemOpeningBalance;
  final double manualOpeningBalance;
  final double? systemClosingBalance;
  final String manualClosingBalance;
  final double openingDifferenceAmount;
  final String openingDifferenceType;
  final double closingDifferenceAmount;
  final String closingDifferenceType;
  final double cashSales;
  final double cardSales;
  final double upiSales;
  final String deliveryPartnerSales;
  final String otherSales;
  final String salesReturn;
  final String dayEndStatus;
  final String status;

  // Add other fields as needed...

  Shift({
    required this.shiftId,
    required this.shiftNumber,
    required this.shiftOpeningDate,
    required this.shiftOpeningTime,
    required this.shiftClosingDate,
    required this.shiftClosingTime,
    required this.systemOpeningBalance,
    required this.manualOpeningBalance,
    this.systemClosingBalance,
    required this.manualClosingBalance,
    required this.openingDifferenceAmount,
    required this.openingDifferenceType,
    required this.closingDifferenceAmount,
    required this.closingDifferenceType,
    required this.cashSales,
    required this.cardSales,
    required this.upiSales,
    required this.deliveryPartnerSales,
    required this.otherSales,
    required this.salesReturn,
    required this.dayEndStatus,
    required this.status,
  });

  // Factory method to create an instance from JSON
  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      shiftId: json['shiftId'],
      shiftNumber: json['shiftNumber'],
      shiftOpeningDate: json['shiftOpeningDate'],
      shiftOpeningTime: json['shiftOpeningTime'],
      shiftClosingDate: json['shiftClosingDate'],
      shiftClosingTime: json['shiftClosingTime'],
      systemOpeningBalance: json['systemOpeningBalance'].toDouble(),
      manualOpeningBalance: json['manualOpeningBalance'].toDouble(),
      systemClosingBalance: json['systemClosingBalance']?.toDouble(),
      manualClosingBalance: json['manualClosingBalance'],
      openingDifferenceAmount: json['openingDifferenceAmount'].toDouble(),
      openingDifferenceType: json['openingDifferenceType'],
      closingDifferenceAmount: json['closingDifferenceAmount'].toDouble(),
      closingDifferenceType: json['closingDifferenceType'],
      cashSales: json['cashSales'].toDouble(),
      cardSales: json['cardSales'].toDouble(),
      upiSales: json['upiSales'].toDouble(),
      deliveryPartnerSales: json['deliveryPartnerSales'] ?? "",
      otherSales: json['otherSales'] ?? "",
      salesReturn: json['salesReturn'] ?? "",
      dayEndStatus: json['dayEndStatus'],
      status: json['status'],
    );
  }
}

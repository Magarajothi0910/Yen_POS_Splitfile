class DayEnd {
  final String dayEndId;
  final DateTime dayOpeningDate;
  final String dayOpeningTime;
  final DateTime dayClosingDate;
  final String dayClosingTime;
  final double systemCashSales;
  final double systemCardSales;
  final double systemUpiSales;
  final double systemDeliveryPartnerSales;
  final double systemOtherSales;
  final double salesReturn;
  final String status;
  final String branchId;
  final String branchName;
  final String deviceId;
  final String deviceNumber;
  final double manualCashSales;
  final double manualUpiSales;
  final double manualCardSales;
  final double manualDeliverypartnerSales;
  final double manualOtherSales;

  DayEnd({
    required this.dayEndId,
    required this.dayOpeningDate,
    required this.dayOpeningTime,
    required this.dayClosingDate,
    required this.dayClosingTime,
    required this.systemCashSales,
    required this.systemCardSales,
    required this.systemUpiSales,
    required this.systemDeliveryPartnerSales,
    required this.systemOtherSales,
    required this.salesReturn,
    required this.status,
    required this.branchId,
    required this.branchName,
    required this.deviceId,
    required this.deviceNumber,
    required this.manualCashSales,
    required this.manualUpiSales,
    required this.manualCardSales,
    required this.manualDeliverypartnerSales,
    required this.manualOtherSales,
  });

  /// ✅ From JSON
  factory DayEnd.fromJson(Map<String, dynamic> json) {
    return DayEnd(
      dayEndId: json['dayEndId'] ?? '',
      dayOpeningDate: DateTime.parse(json['dayOpeningDate']),
      dayOpeningTime: json['dayOpeningTime'] ?? '',
      dayClosingDate: DateTime.parse(json['dayClosingDate']),
      dayClosingTime: json['dayClosingTime'] ?? '',
      systemCashSales: (json['systemCashSales'] ?? 0).toDouble(),
      systemCardSales: (json['systemCardSales'] ?? 0).toDouble(),
      systemUpiSales: (json['systemUpiSales'] ?? 0).toDouble(),
      systemDeliveryPartnerSales:
          (json['systemDeliveryPartnerSales'] ?? 0).toDouble(),
      systemOtherSales: (json['systemOtherSales'] ?? 0).toDouble(),
      salesReturn: (json['salesReturn'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      branchId: json['branchId'] ?? '',
      branchName: json['branchName'] ?? '',
      deviceId: json['deviceId'] ?? '',
      deviceNumber: json['deviceNumber'] ?? '',
      manualCashSales: (json['manualCashSales'] ?? 0).toDouble(),
      manualUpiSales: (json['manualUpiSales'] ?? 0).toDouble(),
      manualCardSales: (json['manualCardSales'] ?? 0).toDouble(),
      manualDeliverypartnerSales:
          (json['manualDeliverypartnerSales'] ?? 0).toDouble(),
      manualOtherSales: (json['manualOtherSales'] ?? 0).toDouble(),
    );
  }

  /// ✅ To JSON
  Map<String, dynamic> toJson() {
    return {
      'dayEndId': dayEndId,
      'dayOpeningDate': dayOpeningDate.toIso8601String(),
      'dayOpeningTime': dayOpeningTime,
      'dayClosingDate': dayClosingDate.toIso8601String(),
      'dayClosingTime': dayClosingTime,
      'systemCashSales': systemCashSales,
      'systemCardSales': systemCardSales,
      'systemUpiSales': systemUpiSales,
      'systemDeliveryPartnerSales': systemDeliveryPartnerSales,
      'systemOtherSales': systemOtherSales,
      'salesReturn': salesReturn,
      'status': status,
      'branchId': branchId,
      'branchName': branchName,
      'deviceId': deviceId,
      'deviceNumber': deviceNumber,
      'manualCashSales': manualCashSales,
      'manualUpiSales': manualUpiSales,
      'manualCardSales': manualCardSales,
      'manualDeliverypartnerSales': manualDeliverypartnerSales,
      'manualOtherSales': manualOtherSales,
    };
  }
}

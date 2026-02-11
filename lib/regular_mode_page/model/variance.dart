// ignore_for_file: public_member_api_docs, sort_constructors_first
class Variance {
  final String varianceName;
  final double varianceDefaultPrice;
  bool isAvailable;

  Variance({
    required this.varianceName,
    required this.varianceDefaultPrice,
    required this.isAvailable,
  });

  factory Variance.fromJson(Map<String, dynamic> json) {
    return Variance(
      varianceName: json['varianceName'] as String,
      varianceDefaultPrice: (json['varianceDefaultPrice'] as num).toDouble(),
      isAvailable: true,
    );
  }
}

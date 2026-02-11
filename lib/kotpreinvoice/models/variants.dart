class variant {
  final String variantId;
  final String variantName;
  final List<String> variantItems;
  final String status;
  final String randomId;

  variant({
    required this.variantId,
    required this.variantName,
    required this.variantItems,
    required this.status,
    required this.randomId,
  });

  factory variant.fromJson(Map<String, dynamic> json) {
    return variant(
      variantId: json['variantId'] as String,
      variantName: json['variant'] as String,
      variantItems: List<String>.from(json['variantItems'] ?? []),
      status: json['status'] as String,
      randomId: json['randomId'] as String,
    );
  }
}

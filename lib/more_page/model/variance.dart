class Variance {
  final String name;

  Variance({required this.name});

  factory Variance.fromJson(Map<String, dynamic> json) {
    return Variance(
      name: json['varianceName'] ?? 'Unknown',
    );
  }
}

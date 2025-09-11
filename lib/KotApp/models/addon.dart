class AddOn {
  final String addOnId;
  final String addOnName;
  final List<String> addOnItems;
  final int? value; // int? means this field can be null
  final String status;
  final String randomId;

  AddOn({
    required this.addOnId,
    required this.addOnName,
    required this.addOnItems,
    required this.value,
    required this.status,
    required this.randomId,
  });

  factory AddOn.fromJson(Map<String, dynamic> json) {
    return AddOn(
      addOnId: json['addOnId'] as String,
      addOnName: json['addOn'] as String,
      addOnItems: List<String>.from(json['addOnItems'] ?? []),
      value: json['value'], // Safe conversion
      status: json['status'] as String,
      randomId: json['randomId'] as String,
    );
  }
}

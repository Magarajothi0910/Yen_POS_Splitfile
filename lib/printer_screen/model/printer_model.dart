class Printer {
  String name;
  String ipAddress;
  String type;
  List<String> items;
  bool status; // Status field for soft delete

  Printer({
    required this.name,
    required this.ipAddress,
    required this.type,
    required this.items,
    this.status = true, // Default status is true (active)
  });

  // Make sure to include the status field in toJson
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ipAddress': ipAddress,
      'type': type,
      'items': items,
      'status': status,
    };
  }

  // Make sure to include status in fromJson or a similar factory method
  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      name: json['name'],
      ipAddress: json['ipAddress'],
      type: json['type'],
      items: List<String>.from(json['items']),
      status:
          json['status'] ?? true, // Default to true if status is not present
    );
  }
}

class Printer {
  final String name;
  final String ipAddress;
  final String type;
  List<String> items; // Stores item names instead of IDs

  late Map<String, String> itemIpMap;

  Printer({
    required this.name,
    required this.ipAddress,
    required this.type,
    List<String>? items, // Pass item names directly
  }) : items = items ?? [] {
    itemIpMap = {};
    for (var item in this.items) {
      itemIpMap[item] = ipAddress;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ipAddress': ipAddress,
      'type': type,
      'items': items,
    };
  }

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      name: json['name'],
      ipAddress: json['ipAddress'],
      type: json['type'],
      items: List<String>.from(json['items'] ?? []),
    );
  }
}

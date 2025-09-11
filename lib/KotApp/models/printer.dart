// class Printer {
//   final String name;
//   final String ipAddress;
//   final String type;
//   final List<String> items;
//   late Map<String, String>
//       itemIpMap; // Map to store item to IP address mappings

//   Printer({
//     required this.name,
//     required this.ipAddress,
//     required this.type,
//     required this.items,
//   }) {
//     // Initialize the itemIpMap when creating a new Printer instance
//     itemIpMap = {}; // Initialize as an empty map
//     for (var item in items) {
//       itemIpMap[item] = ipAddress; // Map each item to the printer's IP address
//     }
//   }

//   // Add toJson and fromJson methods for serialization
//   Map<String, dynamic> toJson() {
//     return {
//       'name': name,
//       'ipAddress': ipAddress,
//       'type': type,
//       'items': items,
//     };
//   }

//   factory Printer.fromJson(Map<String, dynamic> json) {
//     return Printer(
//       name: json['name'],
//       ipAddress: json['ipAddress'],
//       type: json['type'],
//       items: List<String>.from(json['items']),
//     );
//   }
// }

// void notifyListeners() {
//   // Placeholder function to simulate notifying listeners
//   print("Listeners notified");
// }

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

class Product {
  final String id;
  final String name;
  final String variance_Uom;
  final double weight;
  final int price; // Price as int
  final String varianceName;
  final String varianceitemCode;

  final int tax; // Tax as int
  final String category;
  final int localHiveStock; // ✅ Add this field

  Product({
    required this.id,
    required this.name,
    required this.varianceitemCode,
    required this.variance_Uom,
    required this.weight,
    required this.price,
    required this.tax,
    required this.varianceName,
    required this.category,
    required this.localHiveStock, // ✅ Include in constructor
  });

  // Factory constructor to create a Product from JSON
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['itemId'] ?? '',
      name: json['itemName'] ?? '',
      varianceitemCode: json['varianceitemCode'] ?? '',
      variance_Uom: json['variance_Uom'] ?? '',
      weight: _toDouble(json['weight']),
      price: _toInt(json['defaultprice']),
      tax: _toInt(json['tax']),
      varianceName: json['varianceName'] ?? '',
      category: json['category'] ?? '',
      localHiveStock: json['localHiveStock'] ?? 0, // ✅ Pull from json
    );
  }

  // Convert Product instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'varianceitemCode': varianceitemCode,
      'variance_Uom': variance_Uom,
      'weight': weight,
      'price': price,
      'tax': tax,
      'varianceName': varianceName,
      'category': category,
    };
  }

  // Helper to safely convert dynamic to double
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper to safely convert dynamic to int
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

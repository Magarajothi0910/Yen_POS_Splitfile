class Product {
  final String id;
  final String name;
  final String item_Uom;
  final double weight;
  final int price; // Change price to int
  final String varianceName;

  Product({
    required this.id,
    required this.name,
    required this.item_Uom,
    required this.weight,
    required this.price, // Change price to int
    required this.varianceName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['itemId'] ?? '',
      name: json['itemName'] ?? '',
      item_Uom: json['item_Uom'] ?? '',
      weight: _toDouble(json['weight']),
      price: _toInt(json['defaultprice']), // Change _toDouble to _toInt
      varianceName: json['varianceName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price, // Change price to int
      'item_Uom': item_Uom,
      'weight': weight,
      'varianceName': varianceName,
    };
  }

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is int) {
      return value;
    }
    return 0;
  }
}

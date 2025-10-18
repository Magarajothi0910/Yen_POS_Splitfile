class modifyCartItem {
  final String itemName;
  final String variancename;
  final String itemCode;
  final int pricePerKg;
  final int tax;
  final String uom; // Add the uom field
  int quantity;
  double weight;

  modifyCartItem({
    required this.itemName,
    required this.variancename,
    required this.pricePerKg,
    required this.tax,
    required this.itemCode,
    required this.uom, // Initialize uom
    required this.quantity,
    required this.weight,
  });
}

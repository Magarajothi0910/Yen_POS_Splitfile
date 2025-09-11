class SalesOrderItem {
  final String varianceName;
  final String itemName;
  final int qty;
  final double price;
  final String itemCode;
  final double weight;
  final double amount;
  final double tax;
  final String uom;
  SalesOrderItem({
    required this.varianceName,
    required this.itemName,
    required this.qty,
    required this.price,
    required this.itemCode,
    required this.weight,
    required this.amount,
    required this.tax,
    required this.uom,
  });
}

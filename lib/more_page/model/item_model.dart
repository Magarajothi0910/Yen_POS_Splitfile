class Item {
  final String name;
  final String uom;
  double qty;
  String price;
  String selfLife; // Change from int to double
  Item({required this.name, required this.uom, this.qty = 0.0,required this.price,required this.selfLife});
}

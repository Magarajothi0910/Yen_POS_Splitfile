import 'package:flutter/foundation.dart';

import '../../models/product.dart';

Future<List<Product>> _parseProductsInBackground(
    Map<String, dynamic> data) async {
  return compute(_parseProducts, data);
}

List<Product> _parseProducts(Map<String, dynamic> data) {
  // Perform parsing logic here
  return data.entries.expand((entry) {
    // Parse item and variance logic here
    return <Product>[]; // Return parsed products
  }).toList();
}

import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import 'package:yenpos/Global/globals_data.dart';

Future<void> sendDecreaseStockUpdateGlobally({
  required BuildContext context,
  required WebSocketChannel channel,
  required List<String> varianceNames,
  required List<String> varianceItemCodes,
  required List<int> quantities,
}) async {
  final productProvider = Provider.of<ProductProvider>(context, listen: false);

  List<String> itemCodes = [];
  List<String> names = [];

  for (String name in varianceNames) {
    final product = productProvider.products.firstWhere(
      (product) => product.varianceName == name,
      orElse: () => Product(
        varianceName: name,
        varianceitemCode: '',
        id: '',
        name: '',
        variance_Uom: '',
        weight: 0.0,
        price: 0,
        tax: 0,
        category: '',
        localHiveStock: 0,
      ),
    );
    itemCodes.add(product.varianceitemCode);
    names.add(product.varianceName);
  }

  final stockUpdatePayload = {
    'type': 'decreaseStockUpdateFromKot',
    'branchAlias': aliasname,
    'varianceitemCodes': itemCodes,
    'varianceNames': names,
    'stockUpdates': quantities,
  };

  final jsonData = jsonEncode(stockUpdatePayload);
  try {
    channel.sink.add(jsonData);
    // Close the channel safely after sending
    channel.sink.close();
  } catch (e) {
    debugPrint("Error sending stock update or closing channel: $e");
  }
}

// extra_table_utils.dart
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';

Future<void> syncMissingExtraTablesFromOrders(BuildContext context,
    ValueNotifier<Map<String, List<String>>> extraTablesNotifier) async {
  final orderProvider = Provider.of<OrderProvider>(context, listen: false);
  final box = Hive.box('extra_tables');
  final updatedExtras =
      Map<String, List<String>>.from(extraTablesNotifier.value);

  for (var order in orderProvider.orders) {
    final table = order['table']?.toString() ?? '';
    final match = RegExp(r'(.+?)\(([A-Z])\)$').firstMatch(table);
    if (match != null) {
      final mainTable = match.group(1)!;
      final extraSeat = match.group(2)!;
      final formatted = "$mainTable($extraSeat)";

      updatedExtras.putIfAbsent(mainTable, () => []);
      if (!updatedExtras[mainTable]!.contains(formatted)) {
        updatedExtras[mainTable]!.add(formatted);
      }
    }
  }

  extraTablesNotifier.value = updatedExtras;
  extraTablesNotifier.notifyListeners();
  updatedExtras.forEach((key, value) => box.put(key, value));
}

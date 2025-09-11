// lib/services/stock_utils.dart

import 'package:hive_flutter/hive_flutter.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../screens/kot_screen/global/globals.dart';
import '../kotservices/sendDataToClients.dart'; // for broadcast

/// Apply a list of {varianceitemCode, quantityDelta} updates into
/// branchwise_items.localStock, save & broadcast.
Future<void> applyLocalStockDelta(
  List<Map<String, dynamic>> updates,
  Set<WebSocketChannel> clients,
) async {

  final box = await Hive.openBox('branchwise_items');
  final raw = box.get('data') as Map<String, dynamic>;
  final alias = aliasname; // e.g. "AR"
  final items = Map<String, dynamic>.from(raw['data']);

  for (var u in updates) {


    final code = u['varianceitemCode'] as String;
    final delta = (u['quantityDelta'] as num).toDouble();

    items.forEach((itemKey, rawItem) {
      final itemMap = Map<String, dynamic>.from(rawItem);
      final variances = Map<String, dynamic>.from(itemMap['variance'] ?? {});

      variances.forEach((varKey, rawVar) {
        final varMap = Map<String, dynamic>.from(rawVar);
        if (varMap['varianceitemCode'] != code) return;

        final branchwise =
            Map<String, dynamic>.from(varMap['branchwise'] ?? {});
        if (!branchwise.containsKey(alias)) return;

        final entry = Map<String, dynamic>.from(branchwise[alias]);
        final physKey = 'physicalStock\_$alias';
        final phys = (entry[physKey] as num? ?? 0).toDouble();
        final current = (entry['localStock'] as num?)?.toDouble() ?? phys;

        entry['localStock'] = (current + delta).clamp(0, double.infinity);
        branchwise[alias] = entry;
        varMap['branchwise'] = branchwise;
        variances[varKey] = varMap;
      });

      itemMap['variance'] = variances;
      items[itemKey] = itemMap;
    });
  }

  await box.put('data', {
    'categories': raw['categories'],
    'data': items,
  });

  sendDataToClients({
    'action': 'branchwiseItems',
    'data': {
      'categories': raw['categories'],
      'data': items,
    }
  }, clients);
}

import 'package:hive/hive.dart';

/// Adjusts the “systemStock” for a given variance in the Hive-stored
/// branchwiseItems_<branchAlias> map by Δ (delta). Creates the key if missing.
Future<void> adjustSystemStock({
  required String branchAlias,
  required String varianceItemCode,
  required int delta,
}) async {

  final key = 'branchwiseItems_$branchAlias';
  final lazyBox = await Hive.openLazyBox('branchwise_items');

  // Retrieve the snapshot (may be null on first run)
  final snapshot = await lazyBox.get(key) as Map<dynamic, dynamic>?;
  if (snapshot == null) {
    throw Exception('No branchwise data for $branchAlias');
  }

  // Convert nested dynamic maps into String→dynamic maps
  Map<String, dynamic> data =
      (snapshot['data'] as Map).map((k, v) => MapEntry(k.toString(), v));

  var updated = false;

  outer:
  for (final itemEntry in data.entries) {
    final variances = (itemEntry.value['variance'] as Map)
        .map((k, v) => MapEntry(k.toString(), v as Map));

    for (final vEntry in variances.entries) {
      final code = vEntry.value['varianceitemCode'] as String?;
      if (code != varianceItemCode) continue;

      // Find or initialize the branchwise map
      final branchwise = (vEntry.value['branchwise'] as Map<dynamic, dynamic>)
          .map((k, v) => MapEntry(k.toString(), v as Map));
      final branchData = branchwise[branchAlias] ?? {};

      final stockKey = 'localHiveStock_$branchAlias';
      final current = int.tryParse(branchData[stockKey]?.toString() ?? '') ?? 0;
      final next = (current + delta).clamp(0, 1 << 31);

      branchData[stockKey] = next;
      branchwise[branchAlias] = branchData;
      vEntry.value['branchwise'] = branchwise;

      updated = true;
      break outer;
    }
  }

  if (!updated) {
    throw Exception('Variance code $varianceItemCode not found.');
  }

  // Write back the modified snapshot
  snapshot['data'] = data;
  await lazyBox.put(key, snapshot);
}

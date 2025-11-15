import 'package:hive_flutter/hive_flutter.dart';

Map<String, dynamic>? _cachedBranchwiseItems;

Future<Map<String, dynamic>> getBranchwiseItemsFromLazyBox() async {
  print("➡️ getBranchwiseItemsFromLazyBox() called");

  // Return cached if available
  if (_cachedBranchwiseItems != null) {
    print("🧠 Returning cached branchwiseItems");
    return _cachedBranchwiseItems!;
  }

  // Open box if not already open
  if (!Hive.isBoxOpen('branchwise_items')) {
    print("📦 Box not open yet, opening now...");
    await Hive.openBox('branchwise_items');
  }

  final box = Hive.box('branchwise_items');
  final wrapper = box.get('data');

  print("📦 Raw wrapper from box: $wrapper");

  // Validate wrapper
  if (wrapper == null) {
    print("❌ No 'data' key found in box");
    return {};
  }
  if (wrapper is! Map) {
    print("❌ 'data' in box is not a Map");
    return {};
  }

  final innerData = wrapper['data'];
  if (innerData == null || innerData is! Map) {
    print("❌ Inner 'data' is missing or not a Map");
    return {};
  }

  // Cache and return
  _cachedBranchwiseItems = Map<String, dynamic>.from(innerData);
  print("✅ Cached and returning branchwiseItems: ${_cachedBranchwiseItems!.length} items");

  return _cachedBranchwiseItems!;
}

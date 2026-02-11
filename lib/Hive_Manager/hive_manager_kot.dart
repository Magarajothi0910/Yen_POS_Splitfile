import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveManagerKot {
  // Singleton implementation
  static final HiveManagerKot _instance = HiveManagerKot._internal();
  factory HiveManagerKot() => _instance;
  HiveManagerKot._internal();

  // Box members that will be shared across your app.
  late Box ordersBox;
  late Box invoicesBox;
  late Box holdOrdersBox;
  late Box cancelledOrderBox;


  /// Call this method during app initialization (for example, in main())
  Future<void> init() async {
    // Initialize Hive (if not done already in main)
    await Hive.initFlutter();
    invoicesBox = await Hive.openBox('invoicesKOT');

    // Open all the boxes you need only once
    ordersBox = await Hive.openBox('orders');
    holdOrdersBox = await Hive.openBox('holdOrdersKOT'); // New line for serverBox
    cancelledOrderBox =
        await Hive.openBox('cancelledOrderBox'); // New line for serverBox
  }

  /// When appropriate (typically at app shutdown), close all boxes.
  Future<void> closeBoxes() async {
    await ordersBox.close();
    await invoicesBox.close();
    await holdOrdersBox.close();

  }
}

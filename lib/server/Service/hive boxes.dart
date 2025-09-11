// import 'package:hive/hive.dart';
// import 'package:hive_flutter/hive_flutter.dart';

// class HiveManager {
//   // Singleton implementation
//   static final HiveManager _instance = HiveManager._internal();
//   factory HiveManager() => _instance;
//   HiveManager._internal();

//   // Box members that will be shared across your app.
//   late Box ordersBox;
//   static late Box invoiceBox;
//   late Box holdOrdersBox;
//   late Box userBox;
//   late Box serverBox;
//   late Box canceled_orderBox;
//   late Box configBox;

//   /// Call this method during app initialization (for example, in main())
//   Future<void> init() async {
//     // Initialize Hive (if not done already in main)
//     await Hive.initFlutter();
//     invoiceBox = await Hive.openBox('invoices');

//     // Open all the boxes you need only once
//     ordersBox = await Hive.openBox('orders');
//     holdOrdersBox = await Hive.openBox('holdOrders');
//     userBox = await Hive.openBox('userBox');
//     serverBox = await Hive.openBox('serverBox'); // New line for serverBox
//     canceled_orderBox =
//         await Hive.openBox('canceled_orderBox'); // New line for serverBox
//     configBox = await Hive.openBox('config');
//   }

//   /// When appropriate (typically at app shutdown), close all boxes.
//   Future<void> closeBoxes() async {
//     await ordersBox.close();
//     await invoiceBox.close();
//     await holdOrdersBox.close();
//     await userBox.close();
//     await configBox.close();
//   }
// }

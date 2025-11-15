// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:hive_flutter/hive_flutter.dart';

// class preInvocieandCancelOrderProvider with ChangeNotifier {
//   Box? canceledOrdersBox;
//   Box? preinvoices;

//   Future<void> initializeHive() async {
//     Hive.initFlutter();
//     canceledOrdersBox = await Hive.openBox('canceledOrdersBox');
//     preinvoices = await Hive.openBox('preinvoices');
//   }

//   Future<void> addCanceledOrder(Map<String, dynamic> order) async {
//     await canceledOrdersBox?.add(order);
//     notifyListeners();
//   }

//   List<dynamic> getCanceledOrders() {
//     return canceledOrdersBox?.values.toList() ?? [];
//   }

//   Future<void> addPreInvoice(Map<String, dynamic> preInvoice) async {
//     await preinvoices?.add(preInvoice);
//     notifyListeners();z
//   }

//   List<dynamic> getPreInvoices() {
//     return preinvoices?.values.toList() ?? [];
//   }
// }

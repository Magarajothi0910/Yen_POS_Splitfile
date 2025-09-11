import 'package:hive/hive.dart';

@HiveType(typeId: 0)
// class OrderModel extends HiveObject {
//   @HiveField(0)
//   late int table;

//   @HiveField(1)
//   late String seat;

//   // Add more fields as necessary

//   OrderModel(this.table, this.seat);
// }
// lib/modelss/printer.dart
class OrderModel {
  int table;
  String seat;
  List<Map<String, dynamic>> items;

  OrderModel({
    required this.table,
    required this.seat,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'table': table,
      'seat': seat,
      'items': items,
    };
  }
}

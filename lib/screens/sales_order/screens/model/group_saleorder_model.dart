import 'sales_order_model.dart';

class GroupedSalesOrder {
  final String date;
  final List<SalesOrderDisplay> orders;

  GroupedSalesOrder({
    required this.date,
    required this.orders,
  });
}

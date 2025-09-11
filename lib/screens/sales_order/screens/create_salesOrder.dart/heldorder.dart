import '../../../../Global/order_model.dart';

class HeldOrdersManager {
  static final List<OrderData> heldOrders = [];

  static void addOrder(OrderData order) {
    heldOrders.add(order);
  }

  static List<OrderData> getOrders() {
    return heldOrders;
  }

  static void clearOrders() {
    heldOrders.clear();
  }
}

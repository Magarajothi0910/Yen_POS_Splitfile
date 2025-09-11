import 'package:hive/hive.dart';

Future<void> patchOrderInHiveIndexWise(
  String hiveOrderId,
  int updatedIndex,
  double updatedQty,
  double updatedCancelledQty,
  double totalAmount,
  bool partiallycancelled,
) async {
  var orderBox = await Hive.openBox('ordersBox');

  for (int i = 0; i < orderBox.length; i++) {
    var orderData = orderBox.getAt(i);
    if (orderData['hiveOrderId'] == hiveOrderId) {
      List<double> quantities = (orderData['quantities'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      List<double> cancelledQty = (orderData['cancelledQty'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      quantities[updatedIndex] = updatedQty;
      cancelledQty[updatedIndex] = updatedCancelledQty;

      orderData['quantities'] = quantities;
      orderData['cancelledQty'] = cancelledQty;
      orderData['totalAmount'] = totalAmount;
      orderData['partiallycancelled'] = partiallycancelled;

      await orderBox.putAt(i, orderData);
      break;
    }
  }
}

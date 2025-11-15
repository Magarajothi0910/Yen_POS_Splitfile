// Method to reverse the cancellation in the local Hive database
import 'package:hive_flutter/hive_flutter.dart';

Future<void> reverseCancellationInHiveByIndex(
  String hiveOrderId,
  int index,
  double updatedQty,
  double updatedCancelledQty,
  double totalAmount,
  bool partiallycancelled,
) async {
  var orderBox = Hive.box('ordersBox');

  for (int i = 0; i < orderBox.length; i++) {
    var orderData = orderBox.getAt(i);

    if (orderData['hiveOrderId'] == hiveOrderId) {
      List<double> quantities = (orderData['quantities'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      List<double> cancelledQty = (orderData['cancelledQty'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      quantities[index] = updatedQty;
      cancelledQty[index] = updatedCancelledQty;

      orderData['quantities'] = quantities;
      orderData['cancelledQty'] = cancelledQty;
      orderData['totalAmount'] = totalAmount;
      orderData['partiallycancelled'] = partiallycancelled;

      await orderBox.putAt(i, orderData);
      print("✅ Updated Hive for index $index in order: $hiveOrderId");
      break;
    }
  }
}

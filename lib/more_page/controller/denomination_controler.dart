import 'package:get/get.dart';

class DenominationController extends GetxController {
  var denominations = {
    500: 0.obs,
    200: 0.obs,
    100: 0.obs,
    50: 0.obs,
    20: 0.obs,
    10: 0.obs,
    5: 0.obs,
    2: 0.obs,
    1: 0.obs,
  };

  // Calculate the total from denominations
  int get totalCashFromDenominations => denominations.entries
      .map((e) => e.key * e.value.value)
      .reduce((sum, amount) => sum + amount);

  // Update a specific denomination count
  void updateDenomination(int denomination, int count) {
    denominations[denomination]?.value = count;
  }
}

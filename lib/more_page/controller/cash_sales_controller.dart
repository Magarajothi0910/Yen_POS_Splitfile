import 'package:get/get.dart';

class CashSalesController extends GetxController {
  var physicalCashSales = 0.obs; // Reactive integer

  void updateCashSales(int newTotal) {
    physicalCashSales.value = newTotal; // Update the value
  }
}

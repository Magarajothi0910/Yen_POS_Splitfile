// providers/table_notifier_provider.dart
import 'package:flutter/foundation.dart';

class TableNotifierProvider with ChangeNotifier {
  ValueNotifier<Map<String, dynamic>> productCardDataNotifier = 
      ValueNotifier<Map<String, dynamic>>({});
  ValueNotifier<bool> showProductCardNotifier = ValueNotifier(false);

  void showProductCard(Map<String, dynamic> data) {
    productCardDataNotifier.value = data;
    showProductCardNotifier.value = true;
    notifyListeners();
  }

  void hideProductCard() {
    showProductCardNotifier.value = false;
    productCardDataNotifier.value = {};
    notifyListeners();
  }

  @override
  void dispose() {
    productCardDataNotifier.dispose();
    showProductCardNotifier.dispose();
    super.dispose();
  }
}
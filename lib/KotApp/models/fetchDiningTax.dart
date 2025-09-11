import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';

Future<void> fetchAndStoreTaxDetails() async {
  try {
    final response =
        await http.get(Uri.parse('https://yenerp.com/fastapi/details/'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      double diningTax = double.parse(
          data.firstWhere((item) => item['details'] == 'diningTax')['value']);

      // Store in Hive
      var box = Hive.box('settings');
      box.put('diningTax', diningTax);
    } else {
    }
  } catch (e) {
  }
}

double getTaxPercentage() {
  if (!Hive.isBoxOpen('settings')) {
    throw HiveError('Hive box "settings" is not open');
  }
  var box = Hive.box('settings');
  return box.get('diningTax', defaultValue: 5.0); // Default to 5% if not set
}

double calculateTax(double itemTotal) {
  double taxPercentage = getTaxPercentage();
  double itemTax = itemTotal * (taxPercentage / 100);
  double itemSGST = itemTax / 2;
  double itemCGST = itemTax / 2;

  return itemTax;
}

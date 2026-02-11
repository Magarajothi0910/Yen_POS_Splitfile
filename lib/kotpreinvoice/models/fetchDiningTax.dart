import 'package:hive/hive.dart';
import 'package:dio/dio.dart';

Future<void> fetchAndStoreTaxDetails() async {
  final dio = Dio();

  try {
    final response = await dio.get('https://yenerp.com/masteradminapi/details/');
    if (response.statusCode == 200) {
      List<dynamic> data = response.data;
      double diningTax = double.parse(data.firstWhere((item) => item['details'] == 'diningTax')['value']);

      // Store in Hive
      var box = Hive.box('settings');
      box.put('diningTax', diningTax);
    } else {
      print('Failed to fetch data: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching data: $e');
  } finally {
    dio.close();
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

  print('Total Tax: $itemTax, SGST: $itemSGST, CGST: $itemCGST');
  return itemTax;
}

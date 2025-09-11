// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:hive/hive.dart';

// // Global Variables
// String globalDiscountName = "";
// String globalDiscountPercentage = "";

// class DiscountService {
//   static const String apiUrl = "https://yenerp.com/fastapi/discounts/";

//   // Fetch API and store in Hive & Global Variable
//   static Future<void> fetchAndStoreDiscounts() async {
//     try {
//       final response = await http.get(Uri.parse(apiUrl));

//       if (response.statusCode == 200) {
//         List<dynamic> data = json.decode(response.body);

//         if (data.isNotEmpty) {
//           var item = data.first; // Get first item
//           globalDiscountName = item['discountName'];
//           globalDiscountPercentage = item['discountPercentage'];

//           var discountBox = Hive.box('discountBox');
//           discountBox.put('discountName', globalDiscountName);
//           discountBox.put('discountPercentage', globalDiscountPercentage);
//         }
//       } else {
//         print("Failed to fetch data: ${response.statusCode}");
//       }
//     } catch (e) {
//       print("Error: $e");
//     }
//   }

//   // Retrieve stored values from Hive (if needed)
//   static void loadFromHive() {
//     var discountBox = Hive.box('discountBox');
//     globalDiscountName = discountBox.get('discountName', defaultValue: "");
//     globalDiscountPercentage =
//         discountBox.get('discountPercentage', defaultValue: "");
//   }
// }

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';

// Global Variable for Discount Percentage (as number)
double globalDiscountPercentage = 6.0;

// class DiscountService {
//   static const String apiUrl = "https://yenerp.com/fastapi/discounts/";

//   DiscountService() {
//     print("Initializing DiscountService...");
//     fetchAndStoreDiscounts();
//   }

//   // Fetch API and store only number in Hive
//   static Future<void> fetchAndStoreDiscounts() async {
//     print("Fetching data from API: $apiUrl");

//     try {
//       final response = await http.get(Uri.parse(apiUrl));
//       print("API Response Status Code: ${response.statusCode}");

//       if (response.statusCode == 200) {
//         List<dynamic> data = json.decode(response.body);
//         print("API Response Data: $data");

//         if (data.isNotEmpty) {
//           var item = data.first; // Get first item
//           print("First Item: $item");

//           String percentageStr = item['discountPercentage'].replaceAll('%', '');
//           print("Extracted Percentage String (without %): $percentageStr");

//           globalDiscountPercentage = double.tryParse(percentageStr) ?? 0.0;
//           print("Converted Discount Percentage: $globalDiscountPercentage");

//           var discountBox = Hive.box('discountBox');
//           discountBox.put('discountPercentage', globalDiscountPercentage);
//           print(
//               "Stored Discount Percentage in Hive: $globalDiscountPercentage");
//         } else {
//           print("No data found in API response.");
//         }
//       } else {
//         print("Failed to fetch data: ${response.statusCode}");
//       }
//     } catch (e) {
//       print("Error occurred while fetching data: $e");
//     }
//   }

//   // Retrieve stored number from Hive
//   static void loadFromHive() {
//     print("Loading discount percentage from Hive...");
//     var discountBox = Hive.box('discountBox');

//     globalDiscountPercentage =
//         discountBox.get('discountPercentage', defaultValue: 0.0);
//     print("Retrieved Discount Percentage from Hive: $globalDiscountPercentage");
//   }
// }

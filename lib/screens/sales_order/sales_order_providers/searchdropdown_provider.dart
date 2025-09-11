// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter/material.dart';

// class SaleOrderProvider with ChangeNotifier {
//   SaleOrderProvider() {
//     fetchVariances();
//   }
//   final http.Client _httpClient = http.Client(); // Use an HTTP client
//   List<Map<String, dynamic>> get variances => _variances;

//   List<Map<String, dynamic>> _variances = [];

//   TextEditingController searchController = TextEditingController();

//   Map<String, dynamic>? selectedItem; // Store the selected item
//   List<Map<String, dynamic>> filteredItems =
//       []; // For filtering items in the search

//   @override
//   void dispose() {
//     searchController.dispose();

//     _httpClient.close(); // Close the HTTP client when the provider is disposed
//     super.dispose(); // Call the superclass's dispose method
//   }

//   void clearControllers() {
//     searchController.clear();
//   }

//   Future<void> fetchVariances() async {
//     const url = 'http://$ipAddress/fastapi/branchwiseitems/';
//     try {
//       final response = await http.get(Uri.parse(url));
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         List<Map<String, dynamic>> fetchedVariances = [];

//         // Print the response to check the structure of the fetched data
//         print('Fetched data: $data');

//         data['data'].forEach((key, value) {
//           value['variance'].forEach((varianceKey, varianceValue) {
//             fetchedVariances.add({
//               'varianceName': varianceValue['varianceName'],
//               'variancePrice': varianceValue['variance_Defaultprice'],
//               'varianceUom': varianceValue['variance_Uom']
//             });
//           });
//         });

//         _variances = fetchedVariances;
//         notifyListeners(); // Notify listeners to rebuild UI after fetching
//       } else {
//         print('Failed to load variances');
//       }
//     } catch (e) {
//       print('Error fetching variances: $e');
//     }
//   }
// }

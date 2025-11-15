// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';

// import 'package:yenpos/Global/globals_data.dart';

// final now = DateTime.now();

// final currenDate = DateFormat('dd-MM-yyyy').format(now);

// class ApiService {
//   final String baseUrl =
//       'https://yenerp.com/fastapi/kottablesstatus/by-branch/$branchName/$currenDate';

//   Future<Map<String, dynamic>> fetchTableStatus() async {
//     final client = http.Client();

//     final response = await client.get(Uri.parse(baseUrl));

//     if (response.statusCode == 200) {
//       try {
//         final Map<String, dynamic> data = json.decode(response.body);
//         return data;
//       } catch (e) {
//         throw Exception('Failed to parse response: $e');
//       } finally {
//         client.close();
//       }
//     } else {
//       throw Exception('Check Server Ip..');
//     }
//   }
// }

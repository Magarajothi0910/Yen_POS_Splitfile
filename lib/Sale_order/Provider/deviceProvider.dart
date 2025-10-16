// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class DeviceProvider with ChangeNotifier {
//   Map<String, dynamic>? deviceData;

//   Future<void> fetchDeviceData(String deviceCode) async {
//     const url = 'https://yenerp.com/fastapi/devicecode/';
//     try {
//       final response = await http.get(Uri.parse(url));
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final List<dynamic> devices = data;
//         final device = devices.firstWhere(
//           (device) => device['deviceCode'] == deviceCode,
//           orElse: () => null,
//         );

//         if (device != null && device['status'] == '1') {
//           deviceData = device;
//           notifyListeners();
//         } else {
//           deviceData = null;
//           notifyListeners();
//         }
//       } else {
//         deviceData = null;
//         notifyListeners();
//       }
//     } catch (error) {
//       deviceData = null;
//       notifyListeners();
//     }
//   }

//   Future<void> storeDeviceData(
//       String deviceCode, String branchName, String deviceCodeId) async {
//     var box = await Hive.openBox('deviceData');
//     await box.put('deviceCode', deviceCode);
//     await box.put('branchName', branchName);
//     await box.put('deviceCodeId', deviceCodeId);
//     notifyListeners();
//   }

//   Future<void> patchDeviceStatus(String deviceCodeId) async {
//     final url = 'https://yenerp.com/fastapi/devicecode/$deviceCodeId';
//     try {
//       final response = await http.patch(
//         Uri.parse(url),
//         headers: {"Content-Type": "application/json"},
//         body: json.encode({"status": "0"}),
//       );
//       if (response.statusCode == 200) {
//         deviceData?['status'] = '0';
//         notifyListeners();
//       } else {}
//     } catch (error) {}
//   }
// }

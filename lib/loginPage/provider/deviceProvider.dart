// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class DeviceProvider with ChangeNotifier {
//   String _deviceCode = '';
//   String _branchName = '';
//   String _deviceCodeId = '';
//   String get deviceCode => _deviceCode;
//   String get branchName => _branchName;
//   Map<String, dynamic>? deviceData;

//   void setDeviceData(Map<String, dynamic> data) {
//     deviceData = data;
//     notifyListeners();
//   }

//   void clearDeviceData() {
//     deviceData = null;
//     notifyListeners();
//   }

//   Future<void> fetchAndStoreDeviceData(String deviceCode) async {
//     const String url = 'https://yenerp.com/fastapi/devicecode';

//     try {
//       final response = await http.get(Uri.parse(url));
//       if (response.statusCode == 200) {
//         final List<dynamic> devices = json.decode(response.body);
//         final device = devices.firstWhere(
//           (device) =>
//               device['deviceCode'] == deviceCode && device['status'] == 'active',
//           orElse: () => null,
//         );

//         if (device != null) {
//           _deviceCodeId = device['deviceCodeId'];
//           // Store device data in Hive and patch status
//           await storeDeviceData(
//             device['deviceCode'],
//             device['branchName'],
//             _deviceCodeId,
//           );
//         } else {
//           // Handle device not found or incorrect status scenario
//         }
//       } else {}
//     } catch (error) {}
//   }

//   Future<void> storeDeviceData(
//     String deviceCode,
//     String branchName,
//     String deviceCodeId,
//   ) async {
//     try {
//       // Open the Hive box (a storage container for key-value pairs)
//       var box = await Hive.openBox('deviceData');

//       // Check if the status is 0 in the incoming device data
//       if (box.get('status') == '0') {
//         // Notify user with a message that the device code is expired
//         // You can integrate a Flutter widget like a snackbar, dialog, etc., to inform the user
//         return;
//       }

//       // Save the deviceCode, branchName, and deviceCodeId in Hive
//       await box.put('deviceCode', deviceCode);
//       await box.put('aliasName', branchName);
//       await box.put('deviceCodeId', deviceCodeId);
//       await box.put('status', 'active'); // Assuming you're storing the status

//       // Update the state
//       _deviceCode = deviceCode;
//       _branchName = branchName;
//       _deviceCodeId = deviceCodeId;

//       // Notify listeners about the changes
//       notifyListeners();

//       // Patch the device status as 0
//       //await patchDeviceStatus(deviceCodeId);
//     } catch (e) {}
//   }

//   Future<void> checkDeviceStatusBeforeSubmission() async {
//     try {
//       var box = await Hive.openBox('deviceData');
//       final String status = box.get('status', defaultValue: '');

//       if (status == '0') {
//         // You can show a message to the user here using a dialog or snackbar
//         return;
//       }

//       // Proceed with submission if the status is not 0
//     } catch (e) {}
//   }

//   Future<void> patchDeviceStatus(String deviceCodeId) async {
//     final String url = 'https://yenerp.com/fastapi/devicecode/$deviceCodeId';
//     final Map<String, dynamic> patchData = {
//       //'status': 'active', // Set the status to 0
//     };

//     try {
//       final response = await http.patch(
//         Uri.parse(url),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(patchData),
//       );

//       if (response.statusCode == 200) {
//       } else {}
//     } catch (e) {}
//   }

//   // Load device data from Hive
//   Future<void> loadDeviceData() async {
//     try {
//       var box = await Hive.openBox('deviceData');
//       _deviceCode = box.get('deviceCode', defaultValue: '');
//       _branchName = box.get('branchName', defaultValue: '');
//       _deviceCodeId = box.get('deviceCodeId', defaultValue: '');

//       // Notify listeners about the changes
//       notifyListeners();
//     } catch (e) {}
//   }
// }

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeviceProvider with ChangeNotifier {
  String _deviceCode = '';
  String _branchName = '';
  String _deviceCodeId = '';
  String _tillId = '';
  String _deviceName = '';

  String get deviceCode => _deviceCode;
  String get branchName => _branchName;

  Map<String, dynamic>? deviceData;

  void setDeviceData(Map<String, dynamic> data) {
    debugPrint("🟢 setDeviceData called: $data");
    deviceData = data;
    notifyListeners();
  }

  void clearDeviceData() {
    debugPrint("🟡 clearDeviceData called");
    deviceData = null;
    notifyListeners();
  }

  /// ---------------- FETCH DEVICE DATA ----------------
  // Future<void> fetchAndStoreDeviceData(String deviceCode) async {
  //   const String url = 'https://yenerp.com/fastapi/devicecode';

  //   debugPrint("🔵 fetchAndStoreDeviceData START");
  //   debugPrint("➡️ Device Code Entered: $deviceCode");
  //   debugPrint("➡️ API URL: $url");

  //   try {
  //     final response = await http.get(Uri.parse(url));

  //     debugPrint("⬅️ API Status Code: ${response.statusCode}");
  //     debugPrint("⬅️ API Response Body: ${response.body}");

  //     if (response.statusCode == 200) {
  //       final List<dynamic> devices = json.decode(response.body);

  //       debugPrint("📦 Total devices received: ${devices.length}");

  //       final device = devices.firstWhere(
  //         (device) =>
  //             device['deviceCode'] == deviceCode &&
  //             device['status'] == 'active',
  //         orElse: () => null,
  //       );

  //       if (device != null) {
  //         debugPrint("✅ Matching active device found: $device");

  //         _deviceCodeId = device['deviceCodeId'];

  //         await storeDeviceData(
  //           device['deviceCode'],
  //           device['branchName'],
  //           _deviceCodeId,
  //           _tillId,
  //           _deviceName,
  //           device['isDineIn'],
  //         );
  //       } else {
  //         debugPrint("❌ No active device found for this deviceCode");
  //       }
  //     } else {
  //       debugPrint("❌ API failed with status: ${response.statusCode}");
  //     }
  //   } catch (error) {
  //     debugPrint("🔥 Error in fetchAndStoreDeviceData: $error");
  //   }
  // }

  /// ---------------- STORE DEVICE DATA ----------------
  Future<void> storeDeviceData(
    String deviceCode,
    String branchName,
    String deviceCodeId,
    String tillId,
    String deviceName,
    bool isDineIn,
  ) async {
    debugPrint("🟣 storeDeviceData START");
    debugPrint("➡️ deviceCode: $deviceCode");
    debugPrint("➡️ branchName: $branchName");
    debugPrint("➡️ deviceCodeId: $deviceCodeId");

    try {
      var box = await Hive.openBox('deviceData');
      debugPrint("📦 Hive box 'deviceData' opened");

      final existingStatus = box.get('status');
      debugPrint("ℹ️ Existing status in Hive: $existingStatus");

      if (existingStatus == '0') {
        debugPrint("⛔ Device is expired (status = 0). Stopping process.");
        return;
      }

      await box.put('deviceCode', deviceCode);
      await box.put('locationId', branchName);
      await box.put('deviceCodeId', deviceCodeId);
      await box.put('tillId', tillId);
      await box.put('deviceName', deviceName);
      await box.put('isDineIn', isDineIn);
      await box.put('status', 'active');

      debugPrint("✅ Device data stored in Hive successfully");

      _deviceCode = deviceCode;
      _branchName = branchName;
      _deviceCodeId = deviceCodeId;
      _tillId = tillId;
      _deviceName = deviceName;

      notifyListeners();
      debugPrint("🔔 notifyListeners() called");

      // await patchDeviceStatus(deviceCodeId);
    } catch (e) {
      debugPrint("🔥 Error in storeDeviceData: $e");
    }
  }

  /// ---------------- CHECK STATUS BEFORE SUBMIT ----------------
  Future<void> checkDeviceStatusBeforeSubmission() async {
    debugPrint("🟠 checkDeviceStatusBeforeSubmission START");

    try {
      var box = await Hive.openBox('deviceData');
      final String status = box.get('status', defaultValue: '');

      debugPrint("ℹ️ Device status from Hive: $status");

      if (status == '0') {
        debugPrint("⛔ Submission blocked: Device expired");
        return;
      }

      debugPrint("✅ Device is valid. Submission allowed.");
    } catch (e) {
      debugPrint("🔥 Error in checkDeviceStatusBeforeSubmission: $e");
    }
  }

  /// ---------------- PATCH DEVICE STATUS ----------------
  Future<void> patchDeviceStatus(String deviceCodeId) async {
    final String url = 'https://yenerp.com/fastapi/devicecode/$deviceCodeId';

    debugPrint("🟤 patchDeviceStatus START");
    debugPrint("➡️ PATCH URL: $url");

    final Map<String, dynamic> patchData = {
      // 'status': '0',
    };

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(patchData),
      );

      debugPrint("⬅️ PATCH Status Code: ${response.statusCode}");
      debugPrint("⬅️ PATCH Response Body: ${response.body}");

      if (response.statusCode == 200) {
        debugPrint("✅ Device status patched successfully");
      } else {
        debugPrint("❌ Failed to patch device status");
      }
    } catch (e) {
      debugPrint("🔥 Error in patchDeviceStatus: $e");
    }
  }

  /// ---------------- LOAD DEVICE DATA ----------------
  Future<void> loadDeviceData() async {
    debugPrint("🟢 loadDeviceData START");

    try {
      var box = await Hive.openBox('deviceData');

      _deviceCode = box.get('deviceCode', defaultValue: '');
      _branchName = box.get('branchName', defaultValue: '');
      _deviceCodeId = box.get('deviceCodeId', defaultValue: '');

      debugPrint("📦 Loaded from Hive:");
      debugPrint("➡️ deviceCode: $_deviceCode");
      debugPrint("➡️ branchName: $_branchName");
      debugPrint("➡️ deviceCodeId: $_deviceCodeId");

      notifyListeners();
      debugPrint("🔔 notifyListeners() called");
    } catch (e) {
      debugPrint("🔥 Error in loadDeviceData: $e");
    }
  }
}

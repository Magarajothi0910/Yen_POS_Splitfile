import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeviceProvider with ChangeNotifier {
  String _deviceCode = '';
  String _branchName = '';
  String _deviceCodeId = '';

  String get deviceCode => _deviceCode;
  String get branchName => _branchName;

  Map<String, dynamic>? deviceData;

  /* -------------------- STATE HELPERS -------------------- */

  void setDeviceData(Map<String, dynamic> data) {
    debugPrint("🧠 setDeviceData() called");
    debugPrint("📦 Device Data: $data");

    deviceData = data;
    notifyListeners();
  }

  void clearDeviceData() {
    debugPrint("🧹 clearDeviceData() called");

    deviceData = null;
    notifyListeners();
  }

  /* -------------------- FETCH & STORE -------------------- */

  Future<void> fetchAndStoreDeviceData(String deviceCode) async {
    const String url = 'https://yenerp.com/nextjstestapi/devicecode/';

    debugPrint("🔍 fetchAndStoreDeviceData() called");
    debugPrint("📨 Input Device Code: $deviceCode");
    debugPrint("🌐 API URL: $url");

    try {
      debugPrint("⏳ Sending GET request...");
      final response = await http.get(Uri.parse(url));

      debugPrint("📡 Response received");
      debugPrint("📊 Status Code: ${response.statusCode}");
      debugPrint("📄 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        debugPrint("✅ API call successful");

        final List<dynamic> devices = json.decode(response.body);
        debugPrint("📦 Total devices received: ${devices.length}");

        debugPrint("🔎 Searching for active device...");
        final device = devices.firstWhere(
          (device) =>
              device['deviceCode'] == deviceCode &&
              device['dcStatus'] == 'active',
          orElse: () => null,
        );

        if (device != null) {
          debugPrint("✅ Active device found");
          debugPrint("🧾 Device Data: $device");

          _deviceCodeId = device['deviceCodeId'];
          debugPrint("🆔 Device Code ID: $_deviceCodeId");

          await storeDeviceData(
            device['deviceCode'],
            device['branchName'],
            _deviceCodeId,
          );
        } else {
          debugPrint("❌ Device not found or not active");
        }
      } else {
        debugPrint("❌ API failed with status: ${response.statusCode}");
      }
    } catch (error, stackTrace) {
      debugPrint("🚨 Error in fetchAndStoreDeviceData()");
      debugPrint("Error: $error");
      debugPrint("StackTrace: $stackTrace");
    }

    debugPrint("🏁 fetchAndStoreDeviceData() completed");
  }

  /* -------------------- HIVE STORAGE -------------------- */

  Future<void> storeDeviceData(
    String deviceCode,
    String branchName,
    String deviceCodeId,
  ) async {
    debugPrint("💾 storeDeviceData() called");
    debugPrint("📨 DeviceCode: $deviceCode");
    debugPrint("🏢 BranchName: $branchName");
    debugPrint("🆔 DeviceCodeId: $deviceCodeId");

    try {
      debugPrint("📦 Opening Hive box: deviceData");
      var box = await Hive.openBox('deviceData');

      final existingStatus = box.get('dcStatus');
      debugPrint("🔐 Existing dcStatus in Hive: $existingStatus");

      if (existingStatus == '0') {
        debugPrint("⚠️ Device already expired. Aborting store.");
        return;
      }

      debugPrint("✍️ Saving data to Hive...");
      await box.put('deviceCode', deviceCode);
      await box.put('BranchName', branchName);
      await box.put('deviceCodeId', deviceCodeId);
      await box.put('dcStatus', 'active');

      debugPrint("✅ Data saved to Hive");

      _deviceCode = deviceCode;
      _branchName = branchName;
      _deviceCodeId = deviceCodeId;
      print("box value: ${box.values}");
      notifyListeners();
      debugPrint("🔔 Provider listeners notified");

      debugPrint("📡 Patching device status to 0");
      await patchDeviceStatus(deviceCodeId);
    } catch (e, stackTrace) {
      debugPrint("🚨 Error in storeDeviceData()");
      debugPrint("Error: $e");
      debugPrint("StackTrace: $stackTrace");
    }

    debugPrint("🏁 storeDeviceData() completed");
  }

  /* -------------------- STATUS CHECK -------------------- */

  Future<void> checkDeviceStatusBeforeSubmission() async {
    debugPrint("🔍 checkDeviceStatusBeforeSubmission() called");

    try {
      var box = await Hive.openBox('deviceData');
      final String status = box.get('dcStatus', defaultValue: '');

      debugPrint("🔐 Current dcStatus: $status");

      if (status == '0') {
        debugPrint("⛔ Submission blocked. Device expired.");
        return;
      }

      debugPrint("✅ Device status valid. Proceeding...");
    } catch (e, stackTrace) {
      debugPrint("🚨 Error checking device status");
      debugPrint("Error: $e");
      debugPrint("StackTrace: $stackTrace");
    }
  }

  /* -------------------- PATCH STATUS -------------------- */

  Future<void> patchDeviceStatus(String deviceCodeId) async {
    final String url =
        'https://yenerp.com/nextjstestapi/devicecode/$deviceCodeId';

    final Map<String, dynamic> patchData = {'dcStatus': '0'};

    debugPrint("📡 patchDeviceStatus() called");
    debugPrint("🌐 PATCH URL: $url");
    debugPrint("📤 Patch Data: $patchData");

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(patchData),
      );

      debugPrint("📊 PATCH Status Code: ${response.statusCode}");
      debugPrint("📄 PATCH Response Body: ${response.body}");

      if (response.statusCode == 200) {
        debugPrint("✅ Device status patched successfully");
      } else {
        debugPrint("❌ Failed to patch device status");
      }
    } catch (e, stackTrace) {
      debugPrint("🚨 Error in patchDeviceStatus()");
      debugPrint("Error: $e");
      debugPrint("StackTrace: $stackTrace");
    }
  }

  /* -------------------- LOAD FROM HIVE -------------------- */

  Future<void> loadDeviceData() async {
    debugPrint("📥 loadDeviceData() called");

    try {
      var box = await Hive.openBox('deviceData');

      _deviceCode = box.get('deviceCode', defaultValue: '');
      _branchName = box.get('branchName', defaultValue: '');
      _deviceCodeId = box.get('deviceCodeId', defaultValue: '');

      debugPrint("📦 Loaded from Hive:");
      debugPrint("DeviceCode: $_deviceCode");
      debugPrint("BranchName: $_branchName");
      debugPrint("DeviceCodeId: $_deviceCodeId");

      notifyListeners();
      debugPrint("🔔 Provider listeners notified");
    } catch (e, stackTrace) {
      debugPrint("🚨 Error loading device data");
      debugPrint("Error: $e");
      debugPrint("StackTrace: $stackTrace");
    }

    debugPrint("🏁 loadDeviceData() completed");
  }
}

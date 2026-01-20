import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeviceProvider with ChangeNotifier {
  String _deviceCode = '';
  String _aliasName = '';
  String _deviceCodeId = '';

  String get deviceCode => _deviceCode;
  String get aliasName => _aliasName;

  // 🔹 STORE DEVICE DATA
  Future<void> storeDeviceData(
    String deviceCode,
    String aliasName,
    String deviceCodeId,
  ) async {
    try {
      final box = await Hive.openBox('deviceData');

      await box.put('deviceCode', deviceCode);
      await box.put('aliasName', aliasName); // ✅ CONSISTENT KEY
      await box.put('deviceCodeId', deviceCodeId);
      await box.put('dcStatus', 'active');

      _deviceCode = deviceCode;
      _aliasName = aliasName;
      _deviceCodeId = deviceCodeId;

      notifyListeners();

      await patchDeviceStatus(deviceCodeId);
    } catch (e) {
     
    }
  }

  // 🔹 PATCH STATUS (ONE-TIME ACTIVATION)
  Future<void> patchDeviceStatus(String id) async {
    final url = 'https://yenerp.com/nextjstestapi/devicecode/$id';

    await http.patch(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'dcStatus': 'deactivated'}),
    );
  }

  // 🔹 LOAD FROM HIVE (OPTIONAL)
  Future<void> loadDeviceData() async {
    final box = await Hive.openBox('deviceData');
    _deviceCode = box.get('deviceCode', defaultValue: '');
    _aliasName = box.get('aliasName', defaultValue: '');
    _deviceCodeId = box.get('deviceCodeId', defaultValue: '');
    notifyListeners();
  }
}

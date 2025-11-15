import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class DeviceProviderDine extends ChangeNotifier {
  Map<String, dynamic>? deviceData;

  Future<void> fetchDeviceData(String deviceCode) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    const url = 'https://yenerp.com/fastapi/devicecode/';

    try {
      print("📡 Fetching device data from: $url");
      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is List) {
          final device = data.firstWhere(
            (device) => device['deviceCode'] == deviceCode,
            orElse: () => null,
          );

          if (device != null && device['status'] == '1') {
            deviceData = device;
            print("✅ Device found and active: $device");
          } else {
            deviceData = null;
            print("⚠️ Device not found or inactive for code: $deviceCode");
          }
        } else {
          print(
            "❌ Invalid data format: expected a List but got ${data.runtimeType}",
          );
          deviceData = null;
        }
      } else {
        print("❌ Failed to fetch devices. HTTP ${response.statusCode}");
        deviceData = null;
      }
    } on DioException catch (dioError) {
      if (dioError.type == DioExceptionType.connectionTimeout ||
          dioError.type == DioExceptionType.receiveTimeout ||
          dioError.type == DioExceptionType.sendTimeout) {
        print("⏰ Request to $url timed out.");
      } else {
        print("🌐 Dio error during fetchDeviceData: ${dioError.message}");
      }

      if (dioError.response != null) {
        print("↪️ Response data: ${dioError.response?.data}");
        print("↪️ Status code: ${dioError.response?.statusCode}");
      }
      deviceData = null;
    } catch (error, stackTrace) {
      print("💥 Unexpected error in fetchDeviceData: $error");
      print(stackTrace);
      deviceData = null;
    } finally {
      dio.close();
      notifyListeners();
    }
  }

  Future<void> storeDeviceData(
    String deviceCode,
    String aliasname,
    String deviceCodeId,
  ) async {
    try {
      var box = Hive.box('deviceData');
      await box.put('deviceCode', deviceCode);
      await box.put('aliasname', aliasname);
      await box.put('deviceCodeId', deviceCodeId);
      print("💾 Device data stored locally in Hive.");
    } on HiveError catch (e) {
      print("❌ Hive error while storing device data: $e");
    } catch (e) {
      print("💥 Unexpected error while storing device data: $e");
    } finally {
      notifyListeners();
    }
  }

  Future<void> patchDeviceStatus(String deviceCodeId) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    final url = 'https://yenerp.com/fastapi/devicecode/$deviceCodeId';

    try {
      print("🛠️ Patching device status to 0 for ID: $deviceCodeId");
      final response = await dio.patch(
        url,
        data: json.encode({"status": "0"}),
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      if (response.statusCode == 200) {
        deviceData?['status'] = '0';
        print(
          "✅ Device status successfully updated to 0 for ID: $deviceCodeId",
        );
      } else {
        print("⚠️ Failed to update device status. HTTP ${response.statusCode}");
      }
    } on DioException catch (dioError) {
      if (dioError.type == DioExceptionType.connectionTimeout ||
          dioError.type == DioExceptionType.receiveTimeout ||
          dioError.type == DioExceptionType.sendTimeout) {
        print("⏰ Timeout occurred while updating device status.");
      } else {
        print("🌐 Dio error during patchDeviceStatus: ${dioError.message}");
      }

      if (dioError.response != null) {
        print("↪️ Response data: ${dioError.response?.data}");
        print("↪️ Status code: ${dioError.response?.statusCode}");
      }
    } catch (error, stackTrace) {
      print("💥 Unexpected error in patchDeviceStatus: $error");
      print(stackTrace);
    } finally {
      dio.close();
      notifyListeners();
    }
  }
}

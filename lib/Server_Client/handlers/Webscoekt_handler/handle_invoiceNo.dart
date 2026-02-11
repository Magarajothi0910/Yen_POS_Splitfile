import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yen_pos/Global/Provider/deviceService.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';

Future<void> handleInvoiceNo(Map<String, dynamic> jsonData) async {
  final invoiceNoKey = jsonData['invNoKeys'];
  final invoiceNoValue = jsonData['invNoValues'];
  final invoiceNo = await Hive.openBox('invoiceNo');
  if (invoiceNo.values.contains(invoiceNoValue)) {
    print(
      "⚠️ InvoiceNoKey already exists in Hive for invoiceNoValue: $invoiceNoValue",
    );
  } else {
    invoiceNo.put(invoiceNoKey, invoiceNoValue);
    print(
      "⚠️ InvoiceNoKey not exists in Hive for invoiceNoValue: $invoiceNoValue",
    );
  }
}

Future<void> handleKOT(Map<String, dynamic> jsonData) async {
  final rawDeviceId = jsonData['deviceCodeId'];
  debugPrint("Handling KOT update...1 $jsonData");

  if (rawDeviceId == deviceCodeId) {
    isDineInEnabled.value = true;
    debugPrint(
      "KOT Enabled for deviceId: $deviceId - Status: $isDineInEnabled",
    );
  } else {
    isDineInEnabled.value = false;
    debugPrint(
      "KOT Disabled for deviceId: $deviceId - Status: $isDineInEnabled",
    );
  }
}

Future<void> handleDineIn(Map<String, dynamic> jsonData) async {
  debugPrint("Handling DineInStatus update...1 $jsonData");
  final rawDeviceId = jsonData['deviceCodeId'];
  final rawLocationId = jsonData['locationId'];

  debugPrint("Handling DineInStatus update...2");

  final success = await updateDineInStatus(
    deviceCodeId: rawDeviceId,
    locationId: rawLocationId,
  );
  debugPrint("Handling DineInStatus update...3");

  if (success) {
    debugPrint("Handling DineInStatus update...4");
    sendDataToClients({
      'action': 'DineInStatus',
      'deviceCodeId': rawDeviceId,
    }, clients);
    debugPrint("Handling DineInStatus update...5");
  }
}

final Dio _dio = Dio(
  BaseOptions(
    // baseUrl: "https://yenerp.com/nextjstestapi/devicecode/",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    headers: {"Content-Type": "application/json"},
  ),
);

Future<bool> updateDineInStatus({
  required String deviceCodeId,
  required String locationId,
}) async {
  debugPrint("🟢 updateDineInStatus START");
  debugPrint("➡️ deviceCodeId: $deviceCodeId");
  debugPrint("➡️ locationId: $locationId");

  try {
    debugPrint("🌐 Sending PATCH request...");
    debugPrint("📍 Endpoint: deviceCodes/device/dine-in");
    debugPrint(
      "📦 Payload: { deviceCodeId: $deviceCodeId, locationId: $locationId }",
    );

    final response = await _dio.patch(
      "https://yenerp.com/fluttertestapi/devicecode/device/dine-in",
      data: {"deviceCodeId": deviceCodeId, "locationId": locationId},
    );

    debugPrint("⬅️ Response received");
    debugPrint("✅ Status Code: ${response.statusCode}");
    debugPrint("📨 Response Data: ${response.data}");

    final success = response.statusCode == 200;
    debugPrint(
      success
          ? "🎉 Dine-in status updated successfully"
          : "⚠️ Dine-in update failed with status ${response.statusCode}",
    );

    debugPrint("🔴 updateDineInStatus END");
    return success;
  } on DioException catch (e) {
    debugPrint("🔥 DioException caught");

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        debugPrint("⏱ Connection timeout");
        break;
      case DioExceptionType.receiveTimeout:
        debugPrint("📥 Receive timeout");
        break;
      case DioExceptionType.sendTimeout:
        debugPrint("📤 Send timeout");
        break;
      case DioExceptionType.badResponse:
        debugPrint("❌ Bad response");
        debugPrint("📨 Status Code: ${e.response?.statusCode}");
        debugPrint("📦 Error Data: ${e.response?.data}");
        break;
      default:
        debugPrint("❌ Dio error: ${e.message}");
    }

    debugPrint("🔴 updateDineInStatus END (FAILED)");
    return false;
  } catch (e, stackTrace) {
    debugPrint("🔥 Unexpected error in updateDineInStatus");
    debugPrint("❌ Error: $e");
    debugPrint("📌 StackTrace: $stackTrace");

    debugPrint("🔴 updateDineInStatus END (FAILED)");
    return false;
  }
}

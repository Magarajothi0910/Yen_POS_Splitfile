// import 'package:dio/dio.dart';

// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';


//    final Dio _dio = Dio(
//     BaseOptions(
//       baseUrl: "http://192.168.1.144:8888/fluttertestapi/",
//       connectTimeout: const Duration(seconds: 10),
//       receiveTimeout: const Duration(seconds: 10),
//       sendTimeout: const Duration(seconds: 10),
//       headers: {
//         "Content-Type": "application/json",
//       },
//     ),
//    );



// class DeviceService {
//   static Future<bool> updateDineInStatus({
//     required String deviceCodeId,
//     required String aliasName,
//   }) async {
//     debugPrint("🟢 updateDineInStatus START");
//     debugPrint("➡️ deviceCodeId: $deviceCodeId");
//     debugPrint("➡️ aliasName: $aliasName");

//     try {
//       debugPrint("🌐 Sending PATCH request...");
//       debugPrint("📍 Endpoint: deviceCodes/device/dine-in");
//       debugPrint("📦 Payload: { deviceCodeId: $deviceCodeId, aliasName: $aliasName }");

//       final response = await _dio.patch(
//         "deviceCodes/device/dine-in",
//         data: {
//           "deviceCodeId": deviceCodeId,
//           "aliasName": aliasName,
//         },
//       );

//       debugPrint("⬅️ Response received");
//       debugPrint("✅ Status Code: ${response.statusCode}");
//       debugPrint("📨 Response Data: ${response.data}");

//       final success = response.statusCode == 200;
//       debugPrint(success
//           ? "🎉 Dine-in status updated successfully"
//           : "⚠️ Dine-in update failed with status ${response.statusCode}");

//       debugPrint("🔴 updateDineInStatus END");
//       return success;

//     } on DioException catch (e) {
//       debugPrint("🔥 DioException caught");

//       switch (e.type) {
//         case DioExceptionType.connectionTimeout:
//           debugPrint("⏱ Connection timeout");
//           break;
//         case DioExceptionType.receiveTimeout:
//           debugPrint("📥 Receive timeout");
//           break;
//         case DioExceptionType.sendTimeout:
//           debugPrint("📤 Send timeout");
//           break;
//         case DioExceptionType.badResponse:
//           debugPrint("❌ Bad response");
//           debugPrint("📨 Status Code: ${e.response?.statusCode}");
//           debugPrint("📦 Error Data: ${e.response?.data}");
//           break;
//         default:
//           debugPrint("❌ Dio error: ${e.message}");
//       }

//       debugPrint("🔴 updateDineInStatus END (FAILED)");
//       return false;

//     } catch (e, stackTrace) {
//       debugPrint("🔥 Unexpected error in updateDineInStatus");
//       debugPrint("❌ Error: $e");
//       debugPrint("📌 StackTrace: $stackTrace");

//       debugPrint("🔴 updateDineInStatus END (FAILED)");
//       return false;
//     }
//   }
// }


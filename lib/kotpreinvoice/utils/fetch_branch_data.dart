import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

Future<void> fetchAndStoreBranchDetails() async {
  final deviceBox = Hive.box('deviceData');
  final branchBox = Hive.box('branchData');

  try {
    // 🔹 Get aliasName from Hive
    final String? storedAlias = deviceBox.get('aliasName');

    if (storedAlias == null || storedAlias.isEmpty) {
      debugPrint("❌ aliasName not found in deviceData");
      return;
    }

    // 🔹 Dio instance
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://yenerp.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    // 🔹 API call
    final Response response = await dio.get('/masteradminapi/locations/');

    if (response.statusCode != 200 || response.data == null) {
      debugPrint("❌ API failed: ${response.statusCode}");
      return;
    }

    final List<dynamic> branches = response.data;

    // 🔹 Find matching branch by aliasName
    final Map<String, dynamic> matchedBranch = branches.cast<Map<String, dynamic>>().firstWhere(
          (branch) => branch['aliasName']?.toString().toLowerCase() == storedAlias.toLowerCase(),
          orElse: () => {},
        );

    if (matchedBranch.isEmpty) {
      debugPrint("❌ No branch found for aliasName: $storedAlias");
      return;
    }

    // 🔹 Store full branch details in Hive
    await branchBox.put('branchDetails', matchedBranch);

    debugPrint("✅ Branch details stored successfully");
  } on DioException catch (e) {
    debugPrint("❌ Dio error: ${e.message}");
  } catch (e) {
    debugPrint("❌ Unexpected error: $e");
  }
}

Future<Map<String, dynamic>?> getBranchDetails() async {
  try {
    final box = Hive.isBoxOpen('branchData') ? Hive.box('branchData') : await Hive.openBox('branchData');

    return box.get('branchDetails'); // ✅ correct key
  } catch (e) {
    debugPrint("Error retrieving branch details: $e");
    return null;
  }
}

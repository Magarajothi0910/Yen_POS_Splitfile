import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:yen_pos/Global/globals_data.dart';

const String apiUrl = "https://yenerp.com/masteradminapi/branches/";
Future<void> fetchAndStoreBranchData() async {
  final dio = Dio();

  try {
    // 🧠 Read aliasName from Hive
    var deviceBox = Hive.box('deviceData');
    String? storedAlias = deviceBox.get('aliasName');
    if (storedAlias == null || storedAlias.isEmpty) {
      print("❌ aliasName not found in Hive.");
      return;
    }

    // 🌐 Call API
    final response = await dio.get(apiUrl).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      List<dynamic> branchData = response.data;
      // 🔍 Match by aliasName
      Map<String, dynamic>? matchedBranch = branchData.firstWhere(
        (branch) => branch['aliasName'] == storedAlias,
        orElse: () => null,
      );

      if (matchedBranch != null) {
        // 🎯 Assign to global
        branchName = matchedBranch['branchName'];
        locationId = matchedBranch['locationId'];
        aliasname = matchedBranch['aliasName'];

        // 💾 Store in Hive
        var branchBox = Hive.box('branchData');
        await branchBox.put('matchedBranch', matchedBranch);
      } else {
        print("❌ No branch found for aliasName: $storedAlias");
      }
    } else {
      print("❌ API call failed with status: ${response.statusCode}");
    }
  } on TimeoutException catch (_) {
    print("❌ Timeout while fetching branch data.");
  } catch (e) {
    print("❌ Exception: $e");
  } finally {
    dio.close();
  }
}

Future<Map<String, dynamic>?> getBranchDetails() async {
  try {
    final box = Hive.box('branchData');
    final matchedBranch = box.get('matchedBranch');

    return matchedBranch;
  } catch (e) {
    print("Error retrieving branch details: $e");
    return null;
  }
}

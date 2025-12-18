import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:yenpos/Global/globals_data.dart';

const String apiUrl = "https://yenerp.com/nextjstestapi/locations/";

Future<void> fetchAndStoreBranchData() async {
  try {
    // Ensure Hive box is open
    var box = await Hive.openBox('branchData');

    // Fetch data from API
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final List<dynamic> branchData = jsonDecode(response.body);

      // Safely cast to List<Map<String, dynamic>>
      final List<Map<String, dynamic>> branches = branchData
          .cast<Map<String, dynamic>>();

      // Find branch matching global branchName
      Map<String, dynamic>? matchedBranch;
      for (final branch in branches) {
        if (branch['branchName'] == branchName) {
          matchedBranch = branch;
          break;
        }
      }

      if (matchedBranch != null) {
        // Assign fetched data to global variables
        branchName = matchedBranch['branchName'] ?? branchName;
        branchId = matchedBranch['branchId'] ?? branchId;
        aliasname = matchedBranch['aliasName'] ?? aliasname;

        // Store the matched branch data in Hive
        await box.put('matchedBranch', matchedBranch);
      } else {}
    } else {}
  } catch (e, stack) {}
}

Future<Map<String, dynamic>?> getBranchDetails() async {
  try {
    var box = await Hive.openBox('branchData');
    final data = box.get('matchedBranch');
    if (data is Map<String, dynamic>) {
      return data;
    } else {
      return null;
    }
  } catch (e, stack) {
    return null;
  }
}

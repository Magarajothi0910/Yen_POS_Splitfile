import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import '../../screens/kot_screen/global/globals.dart';
import 'globals.dart';

const String apiUrl = "https://yenerp.com/masterapi/branches/";
Future<void> fetchAndStoreBranchData() async {
  try {
    // Fetch data from API
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      // Parse the JSON response
      List<dynamic> branchData = jsonDecode(response.body);

      // Filter branch data that matches globals.branchName
      Map<String, dynamic>? matchedBranch = branchData.firstWhere(
        (branch) => branch['branchName'] == branchName,
        orElse: () => null,
      );

      if (matchedBranch != null) {
        // Assign fetched data to global variables
        branchName = matchedBranch['branchName'];
        branchId = matchedBranch['branchId'];
        aliasname = matchedBranch['aliasName'];

        // Store the matched branch data in Hive
        var box = Hive.box('branchData');
        await box.put('matchedBranch', matchedBranch);
      } else {}
    } else {}
  } catch (e) {}
}

Future<Map<String, dynamic>?> getBranchDetails() async {
  try {
    var box = Hive.box('branchData');
    Map<String, dynamic>? matchedBranch = box.get('matchedBranch');
    return matchedBranch;
  } catch (e) {
    return null;
  }
}

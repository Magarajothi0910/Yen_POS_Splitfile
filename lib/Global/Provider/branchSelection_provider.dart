import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:yenpos/Global/Model/branch_model.dart';
import '../globals_data.dart' as global;


class BranchProvider with ChangeNotifier {
  BranchProvider() {
    fetchAndStoreBranch();
  }
  String branchNameToCheck = global.branchName; // Branch name to check
  final String apiUrl = 'https://yenerp.com/fastapi/branches/';
  bool _isLoading = false;
  Branch? _matchedBranch;

  bool get isLoading => _isLoading;
  Branch? get matchedBranch => _matchedBranch;

  // Fetch branches and check for a specific branch
  Future<void> fetchAndStoreBranch() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        List<dynamic>? data = json.decode(response.body) as List<dynamic>?;

        if (data != null) {
          // Find the branch with the specific name
          final branchData = data.firstWhere(
            (item) => item['branchName'] == branchNameToCheck,
            orElse: () => null,
          );

          if (branchData != null) {
            _matchedBranch = Branch.fromJson(branchData);

            // Store the branch in Hive
            final box = await Hive.openBox('branchesBox');
            box.put(
              branchNameToCheck,
              _matchedBranch!.toMap(),
            );
          } else {}
        } else {}
      } else {
        throw Exception('Failed to fetch branches');
      }
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Retrieve stored branch from Hive
  Branch? getStoredBranch(String branchName) {
    final box = Hive.box('branchesBox');
    final storedData = box.get(branchName);

    if (storedData != null) {
      return Branch.fromMap(Map<String, dynamic>.from(storedData));
    }
    return null; // Return null if no data is found
  }
}

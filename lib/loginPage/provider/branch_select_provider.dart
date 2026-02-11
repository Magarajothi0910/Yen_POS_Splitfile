import 'package:flutter/material.dart';

class BranchFilterProvider extends ChangeNotifier {
  final List<String> branchNames;
  List<String> filteredBranches;
  final TextEditingController searchController = TextEditingController();

  BranchFilterProvider(this.branchNames)
      : filteredBranches = List.from(branchNames);

  void filterBranches(String enteredKeyword) {
    if (enteredKeyword.isEmpty) {
      filteredBranches = List.from(branchNames);
    } else {
      filteredBranches = branchNames
          .where((branch) =>
              branch.toLowerCase().contains(enteredKeyword.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }
}

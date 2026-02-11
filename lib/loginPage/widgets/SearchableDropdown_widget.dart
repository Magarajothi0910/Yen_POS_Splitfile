import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/branch_select_provider.dart';

class SearchableDropdown extends StatelessWidget {
  final ValueChanged<String> onSelect;

  const SearchableDropdown(
      {super.key, required this.onSelect, required List<String> branchNames});

  @override
  Widget build(BuildContext context) {
    // Get the device's screen width and height
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Access the filtered branches from the provider
    final branchProvider = Provider.of<BranchFilterProvider>(context);
    final List<String> filteredBranches = branchProvider.filteredBranches;

    return SingleChildScrollView(
      child: SizedBox(
        // Use a percentage of the screen's width for responsiveness
        width: screenWidth * 0.3, // 80% of the screen width
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: branchProvider.searchController,
                onChanged: branchProvider.filterBranches,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  suffixIcon: Icon(Icons.search),
                ),
              ),
            ),
            // Constrain the ListView with a fixed height using a percentage of the screen height
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.5), // 50% of the screen height
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredBranches.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(filteredBranches[index]),
                    onTap: () {
                      onSelect(filteredBranches[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

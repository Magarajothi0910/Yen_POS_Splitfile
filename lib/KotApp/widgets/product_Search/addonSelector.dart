import 'package:flutter/material.dart';

class AddOnsSelector extends StatefulWidget {
  final List<Map<String, String>>
      addons; // Example format: [{'addOn': 'Cheese'}, {'addOn': 'Sauce'}]
  final Map<String, bool> selectedAddOns; // Tracks selected add-ons

  const AddOnsSelector(
      {super.key, required this.addons, required this.selectedAddOns});

  @override
  _AddOnsSelectorState createState() => _AddOnsSelectorState();
}

class _AddOnsSelectorState extends State<AddOnsSelector> {
  TextEditingController searchController = TextEditingController();
  List<Map<String, String>> filteredAddons = [];

  @override
  void initState() {
    super.initState();
    // Initially, show all add-ons
    filteredAddons = widget.addons;
  }

  // Update the filtered list based on search input
  void filterAddOns(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredAddons = widget.addons;
      } else {
        filteredAddons = widget.addons
            .where((addOn) =>
                addOn['addOn']!.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search TextField
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
          child: TextField(
            controller: searchController,
            onChanged: filterAddOns, // Trigger filtering
            decoration: InputDecoration(
              labelText: 'Search Add-ons',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ),

        // Display filtered checkboxes
        Expanded(
          child: ListView.builder(
            itemCount: filteredAddons.length,
            itemBuilder: (context, index) {
              final addOn = filteredAddons[index];
              final addOnName = addOn['addOn']!;
              final isSelected = widget.selectedAddOns[addOnName] ?? false;

              return CheckboxListTile(
                title: Text(
                  addOnName,
                  style: const TextStyle(fontSize: 14),
                ),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    widget.selectedAddOns[addOnName] = value ?? false;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

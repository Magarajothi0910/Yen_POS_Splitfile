import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddOnsSelectorState extends ChangeNotifier {
  List<Map<String, String>> _filteredAddons = [];

  List<Map<String, String>> get filteredAddons => _filteredAddons;

  // 🔔 Initialize filtered add-ons
  void initializeFilteredAddons(List<Map<String, String>> addons) {
    _filteredAddons = addons;
    debugPrint("🔍 Initialized filtered add-ons: ${_filteredAddons.length} items");
    notifyListeners();
  }

  // 🔔 Update filtered add-ons based on search query
  void filterAddOns(String query, List<Map<String, String>> addons) {
    if (query.isEmpty) {
      _filteredAddons = addons;
    } else {
      _filteredAddons = addons
          .where((addOn) =>
              addOn['addOn']!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    debugPrint("🔍 Filtered add-ons: ${_filteredAddons.length} items for query '$query'");
    notifyListeners();
  }

  // 🔔 Update selected add-ons
  void updateSelectedAddOn(String addOnName, bool value, Map<String, bool> selectedAddOns) {
    selectedAddOns[addOnName] = value;
    debugPrint("✅ Updated selected add-on: $addOnName = $value");
    notifyListeners();
  }
}

class AddOnsSelector extends StatefulWidget {
  final List<Map<String, String>> addons;
  final Map<String, bool> selectedAddOns;

  const AddOnsSelector({
    super.key,
    required this.addons,
    required this.selectedAddOns,
  });

  @override
  _AddOnsSelectorState createState() => _AddOnsSelectorState();
}

class _AddOnsSelectorState extends State<AddOnsSelector> {
  late AddOnsSelectorState state;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    state = AddOnsSelectorState(); // 🔔 Initialize ChangeNotifier
    state.initializeFilteredAddons(widget.addons); // Initialize filtered add-ons
  }

  @override
  void dispose() {
    searchController.dispose(); // 🧹 Dispose controller
    state.dispose(); // 🧹 Dispose ChangeNotifier
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Column(
        children: [
          // Search TextField
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
            child: TextField(
              controller: searchController,
              onChanged: (query) => state.filterAddOns(query, widget.addons),
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
            child: Consumer<AddOnsSelectorState>(
              builder: (context, state, _) {
                return ListView.builder(
                  itemCount: state.filteredAddons.length,
                  itemBuilder: (context, index) {
                    final addOn = state.filteredAddons[index];
                    final addOnName = addOn['addOn']!;
                    final isSelected = widget.selectedAddOns[addOnName] ?? false;

                    return CheckboxListTile(
                      title: Text(
                        addOnName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: isSelected,
                      onChanged: (value) {
                        state.updateSelectedAddOn(addOnName, value ?? false, widget.selectedAddOns);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
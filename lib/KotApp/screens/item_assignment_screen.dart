// lib/screens/item_assignment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../kotservices/kotwebsocketService.dart';
import '../kotproviders/printer_provider.dart';
import '../kotproviders/product_provider.dart';
import '../widgets/bottomNav.dart';
import '../widgets/globalAppbar.dart';
import '../widgets/settingsScreen.dart';

class ItemAssignmentScreen extends StatefulWidget {
  final int printerIndex;

  const ItemAssignmentScreen({super.key, required this.printerIndex});

  @override
  _ItemAssignmentScreenState createState() => _ItemAssignmentScreenState();
}

class _ItemAssignmentScreenState extends State<ItemAssignmentScreen> {
  final _searchController = TextEditingController();
  final List<String> _selectedCategories = [];
  final Map<String, List<String>> _selectedItemsByCategory = {};
  List<String> _selectedItems = []; // Track individually selected items

  @override
  void initState() {
    super.initState();
    final printerProvider =
        Provider.of<PrinterProvider>(context, listen: false);
    final printer = printerProvider.printers[widget.printerIndex];

    _selectedItems = List<String>.from(printer.items);
    for (var item in printer.items) {
      final category = _getCategoryForItem(item);
      if (category != null) {
        _selectedItemsByCategory.putIfAbsent(category, () => []).add(item);
      }
    }
  }

  String? _getCategoryForItem(String itemId) {
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final product = productProvider.products.firstWhere(
      (product) => product.varianceName == itemId,
    );
    return product.category;
  }

  @override
  Widget build(BuildContext context) {
    final printerProvider = Provider.of<PrinterProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final webSocketService =
        Provider.of<WebSocketServicekot>(context, listen: false);
    final printer = printerProvider.printers[widget.printerIndex];

    final categories = productProvider.products
        .map((product) => product.category)
        .toSet()
        .toList();

    final searchText = _searchController.text.toLowerCase();

    return Scaffold(
      appBar: GlobalAppBar(
        title: 'Assign Items to ${printer.name}',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Items or Categories',
                border: OutlineInputBorder(
                  // Adds a border around the TextField
                  borderRadius: BorderRadius.circular(
                      8.0), // Optional: Add rounded corners
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final products = productProvider.products
                    .where((product) => product.category == category)
                    .toList();

                final isCategorySelected =
                    _selectedItemsByCategory.containsKey(category);
                final categoryMatchesSearch =
                    category.toLowerCase().contains(searchText);

                // Filter products based on search query
                final filteredProducts = products
                    .where((product) =>
                        product.varianceName
                            .toLowerCase()
                            .contains(searchText) ||
                        categoryMatchesSearch)
                    .toList();

                if (filteredProducts.isEmpty && !categoryMatchesSearch) {
                  return Container(); // Hide categories and items that don't match search
                }
                // Get all assigned items across all printers
                final allAssignedItems = printerProvider.printers
                    .where((p) =>
                        p.name != printer.name) // Exclude the current printer
                    .expand((p) => p.items)
                    .toList();
                final categoryIsAssigned = products.every((product) =>
                    allAssignedItems.contains(product.varianceName) &&
                    !printer.items.contains(product.varianceName));

                return Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor:
                        Colors.transparent, // Makes dividers transparent
                  ),
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Category-level checkbox with disabled tick
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Checkbox(
                              value: _selectedItemsByCategory[category]
                                      ?.isNotEmpty ??
                                  false,
                              onChanged: categoryIsAssigned
                                  ? null // Disable the checkbox if the category is assigned
                                  : (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          final categoryItems = products
                                              .map((product) =>
                                                  product.varianceName)
                                              .toList();
                                          _selectedItemsByCategory[category] =
                                              categoryItems;
                                          _selectedItems.addAll(categoryItems);
                                        } else {
                                          final categoryItems =
                                              _selectedItemsByCategory[
                                                      category] ??
                                                  [];
                                          _selectedItems.removeWhere((item) =>
                                              categoryItems.contains(item));
                                          _selectedItemsByCategory
                                              .remove(category);
                                        }
                                      });
                                    },
                              activeColor: categoryIsAssigned
                                  ? Colors.grey.shade300
                                  : Theme.of(context).primaryColor,
                              checkColor: categoryIsAssigned
                                  ? Colors.black
                                  : Colors.white,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            if (categoryIsAssigned)
                              const Icon(
                                Icons.check,
                                color: Colors.grey, // Tick color
                                size: 18, // Adjust size for better fit
                              ),
                          ],
                        ),
                        const SizedBox(
                            width: 8), // Spacing between checkbox and text
                        Expanded(
                          child: Text(
                            category,
                            style: TextStyle(
                              color: categoryIsAssigned
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      SizedBox(
                        height:
                            400, // Set a reasonable height for the scrollable items
                        child: SingleChildScrollView(
                          child: Column(
                            children: filteredProducts.map((product) {
                              final itemId = product.varianceName.toString();
                              final isAssigned =
                                  allAssignedItems.contains(itemId) &&
                                      !printer.items.contains(itemId);
                              final isSelected =
                                  _selectedItems.contains(itemId);

                              return ListTile(
                                leading: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: isAssigned
                                          ? null
                                          : (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedItems.add(
                                                      product.varianceName);
                                                  _selectedItemsByCategory
                                                      .putIfAbsent(
                                                          category, () => []);
                                                  if (!_selectedItemsByCategory[
                                                          category]!
                                                      .contains(product
                                                          .varianceName)) {
                                                    _selectedItemsByCategory[
                                                            category]!
                                                        .add(product
                                                            .varianceName);
                                                  }
                                                } else {
                                                  _selectedItems.remove(
                                                      product.varianceName);
                                                  _selectedItemsByCategory[
                                                          category]
                                                      ?.remove(
                                                          product.varianceName);
                                                  if (_selectedItemsByCategory[
                                                              category]
                                                          ?.isEmpty ??
                                                      true) {
                                                    _selectedItemsByCategory
                                                        .remove(category);
                                                  }
                                                }
                                              });
                                            },
                                      activeColor: isAssigned
                                          ? Colors.grey.shade300
                                          : Theme.of(context).primaryColor,
                                      checkColor: isAssigned
                                          ? Colors.black
                                          : Colors.white,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    if (isAssigned)
                                      const Icon(
                                        Icons.check,
                                        color: Colors
                                            .grey, // Tick color for disabled checkbox
                                        size: 18, // Adjust size for better fit
                                      ),
                                  ],
                                ),
                                title: GestureDetector(
                                  onTap: isAssigned
                                      ? null
                                      : () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedItems
                                                  .remove(product.varianceName);
                                              _selectedItemsByCategory[category]
                                                  ?.remove(
                                                      product.varianceName);
                                              if (_selectedItemsByCategory[
                                                          category]
                                                      ?.isEmpty ??
                                                  true) {
                                                _selectedItemsByCategory
                                                    .remove(category);
                                              }
                                            } else {
                                              _selectedItems
                                                  .add(product.varianceName);
                                              _selectedItemsByCategory
                                                  .putIfAbsent(
                                                      category, () => []);
                                              if (!_selectedItemsByCategory[
                                                      category]!
                                                  .contains(
                                                      product.varianceName)) {
                                                _selectedItemsByCategory[
                                                        category]!
                                                    .add(product.varianceName);
                                              }
                                            }
                                          });
                                        },
                                  child: Text(
                                    product.varianceName,
                                    style: TextStyle(
                                      color: isAssigned
                                          ? Colors.grey
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                                enabled: !isAssigned || isSelected,
                                onTap: isAssigned
                                    ? null
                                    : () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedItems
                                                .remove(product.varianceName);
                                            _selectedItemsByCategory[category]
                                                ?.remove(product.varianceName);
                                            if (_selectedItemsByCategory[
                                                        category]
                                                    ?.isEmpty ??
                                                true) {
                                              _selectedItemsByCategory
                                                  .remove(category);
                                            }
                                          } else {
                                            _selectedItems
                                                .add(product.varianceName);
                                            _selectedItemsByCategory
                                                .putIfAbsent(
                                                    category, () => []);
                                            if (!_selectedItemsByCategory[
                                                    category]!
                                                .contains(
                                                    product.varianceName)) {
                                              _selectedItemsByCategory[
                                                      category]!
                                                  .add(product.varianceName);
                                            }
                                          }
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const settingsScreen(),
                    ),
                    (Route<dynamic> route) =>
                        false, // Removes all previous routes
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: () {
                  final selectedItems = List<String>.from(_selectedItems);

                  printer.items = selectedItems;

                  printerProvider.updatePrinter(printer);
                  webSocketService.sendAssignedItems(printer);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Assign Items'),
              ),
            ],
          ),
        ],
      ),
      //  bottomNavigationBar: const GlobalBottomNav(noSelection: true),
    );
  }
}

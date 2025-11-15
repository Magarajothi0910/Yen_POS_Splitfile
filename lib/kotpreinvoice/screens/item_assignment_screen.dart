import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Server_Client/websocketService.dart';
import '../../kotpreinvoice/providers/bottomNavprovider.dart';
import '../services/websocketService.dart';
import '../providers/printer_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/bottomNav.dart';
import '../components/globalAppbar.dart';
import '../widgets/settingsScreen.dart';

// ChangeNotifier class to manage the state
class ItemAssignmentState extends ChangeNotifier {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, List<String>> _selectedItemsByCategory = {};
  List<String> _selectedItems = [];

  TextEditingController get searchController => _searchController;
  Map<String, List<String>> get selectedItemsByCategory => _selectedItemsByCategory;
  List<String> get selectedItems => _selectedItems;

  ItemAssignmentState(BuildContext context, int printerIndex) {
    try {
      final printerProvider = Provider.of<PrinterProviderDine>(context, listen: false);
      final printer = printerProvider.printers[printerIndex];
      _selectedItems = List<String>.from(printer.items);

      for (var item in printer.items) {
        final category = _getCategoryForItem(context, item);
        if (category != null) {
          _selectedItemsByCategory.putIfAbsent(category, () => []).add(item);
        }
      }

      _searchController.addListener(notifyListeners);
      print("🟢 ItemAssignmentState initialized with ${_selectedItems.length} items.");
    } catch (e, stack) {
      print("❌ Error initializing ItemAssignmentState: $e");
      print("📜 StackTrace: $stack");
    }
  }

  String? _getCategoryForItem(BuildContext context, String itemId) {
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final product = productProvider.products.firstWhere(
        (product) => product.varianceName == itemId,
        orElse: () {
          print("⚠️ Product not found for itemId: $itemId");
          return null as dynamic;
        },
      );
      return product?.category;
    } catch (e) {
      print("❌ Error in _getCategoryForItem for itemId=$itemId: $e");
      return null;
    }
  }

  void toggleCategorySelection(String category, List<String> categoryItems, bool? value) {
    try {
      if (value == true) {
        _selectedItemsByCategory[category] = categoryItems;
        _selectedItems.addAll(categoryItems);
        print("✅ Category '$category' selected with ${categoryItems.length} items.");
      } else {
        final categoryItems = _selectedItemsByCategory[category] ?? [];
        _selectedItems.removeWhere((item) => categoryItems.contains(item));
        _selectedItemsByCategory.remove(category);
        print("🗑️ Category '$category' deselected.");
      }
      notifyListeners();
    } catch (e) {
      print("❌ Error in toggleCategorySelection for category=$category: $e");
    }
  }

  void toggleItemSelection(String category, String itemId, bool? value) {
    try {
      if (value == true) {
        _selectedItems.add(itemId);
        _selectedItemsByCategory.putIfAbsent(category, () => []);
        if (!_selectedItemsByCategory[category]!.contains(itemId)) {
          _selectedItemsByCategory[category]!.add(itemId);
        }
        print("✅ Item '$itemId' added to category '$category'.");
      } else {
        _selectedItems.remove(itemId);
        _selectedItemsByCategory[category]?.remove(itemId);
        if (_selectedItemsByCategory[category]?.isEmpty ?? true) {
          _selectedItemsByCategory.remove(category);
        }
        print("🗑️ Item '$itemId' removed from category '$category'.");
      }
      notifyListeners();
    } catch (e) {
      print("❌ Error in toggleItemSelection for itemId=$itemId: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    print("🛑 ItemAssignmentState disposed.");
    super.dispose();
  }
}

class ItemAssignmentScreen extends StatelessWidget {
  final int printerIndex;

  const ItemAssignmentScreen({super.key, required this.printerIndex});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ItemAssignmentState(context, printerIndex),
      child: Consumer<ItemAssignmentState>(
        builder: (context, state, _) {
          try {
            final printerProvider = Provider.of<PrinterProviderDine>(context);
            final productProvider = Provider.of<ProductProvider>(context);
            final webSocketService = Provider.of<WebSocketService>(context, listen: false);
            final printer = printerProvider.printers[printerIndex];
            final categories = productProvider.products.map((product) => product.category).toSet().toList();
            final searchText = state.searchController.text.toLowerCase();

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: GlobalAppBar(
                title: 'Assign Items to ${printer.name}',
              ),
              body: Column(
                children: [
                  // 🔎 Search bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: state.searchController,
                      decoration: InputDecoration(
                        labelText: 'Search Items or Categories',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                  // 📋 Categories + items
                  Expanded(
                    child: ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        try {
                          final category = categories[index];
                          final products = productProvider.products.where((product) => product.category == category).toList();
                          final isCategorySelected = state.selectedItemsByCategory.containsKey(category);
                          final categoryMatchesSearch = category.toLowerCase().contains(searchText);
                          final filteredProducts = products.where((product) => product.varianceName.toLowerCase().contains(searchText) || categoryMatchesSearch).toList();
                          final allAssignedItems = printerProvider.printers.where((p) => p.name != printer.name).expand((p) => p.items).toList();
                          final categoryIsAssigned = products.every((product) => allAssignedItems.contains(product.varianceName) && !printer.items.contains(product.varianceName));

                          if (filteredProducts.isEmpty && !categoryMatchesSearch) {
                            return Container();
                          }

                          return Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Checkbox(
                                        value: state.selectedItemsByCategory[category]?.isNotEmpty ?? false,
                                        onChanged: categoryIsAssigned
                                            ? null
                                            : (bool? value) {
                                                state.toggleCategorySelection(category, products.map((product) => product.varianceName).toList(), value);
                                              },
                                        activeColor: categoryIsAssigned ? Colors.grey.shade300 : Colors.blue,
                                        checkColor: categoryIsAssigned ? Colors.black : Colors.white,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      if (categoryIsAssigned)
                                        const Icon(
                                          Icons.check,
                                          color: Colors.grey,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        color: categoryIsAssigned ? Colors.grey : Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                SizedBox(
                                  height: 400,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: filteredProducts.map((product) {
                                        final itemId = product.varianceName.toString();
                                        final isAssigned = allAssignedItems.contains(itemId) && !printer.items.contains(itemId);
                                        final isSelected = state.selectedItems.contains(itemId);

                                        return ListTile(
                                          leading: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Checkbox(
                                                value: isSelected,
                                                onChanged: isAssigned
                                                    ? null
                                                    : (bool? value) {
                                                        state.toggleItemSelection(category, product.varianceName, value);
                                                      },
                                                activeColor: isAssigned ? Colors.grey.shade300 : Colors.blue.shade300,
                                                checkColor: isAssigned ? Colors.black : Colors.white,
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              if (isAssigned)
                                                const Icon(
                                                  Icons.check,
                                                  color: Colors.grey,
                                                  size: 18,
                                                ),
                                            ],
                                          ),
                                          title: GestureDetector(
                                            onTap: isAssigned
                                                ? null
                                                : () {
                                                    state.toggleItemSelection(category, product.varianceName, !isSelected);
                                                  },
                                            child: Text(
                                              product.varianceName,
                                              style: TextStyle(
                                                color: isAssigned ? Colors.grey : Colors.black,
                                              ),
                                            ),
                                          ),
                                          enabled: !isAssigned || isSelected,
                                          onTap: isAssigned
                                              ? null
                                              : () {
                                                  state.toggleItemSelection(category, product.varianceName, !isSelected);
                                                },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } catch (e) {
                          print("❌ Error while rendering category $index: $e");
                          return const SizedBox();
                        }
                      },
                    ),
                  ),
                  // 🔘 Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          try {
                            Provider.of<BottomNavProviderKOT>(context, listen: false).updateIndex(3);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const settingsScreen(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                            print("🔙 Back button clicked.");
                          } catch (e) {
                            print("❌ Error navigating back: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text('Back'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          try {
                            final selectedItems = List<String>.from(state.selectedItems);
                            printer.items = selectedItems;

                            // FIXED: Pass both printerIndex and printer to the update method
                            printerProvider.updatePrinter(printerIndex, printer);
                            print("🖨️ Printer updated at index $printerIndex: ${printer.name} with ${selectedItems.length} items.");

                            webSocketService.sendPrinterDetails(printer);
                            print("📡 Printer details sent via WebSocket.");
                            Navigator.pop(context);
                          } catch (e) {
                            print("❌ Error while assigning items to printer: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text('Assign Items'),
                      ),
                    ],
                  ),
                ],
              ),
              bottomNavigationBar: const GlobalBottomNav(noSelection: true),
            );
          } catch (e, stack) {
            print("❌ Fatal error in ItemAssignmentScreen: $e");
            print("📜 StackTrace: $stack");
            return const Center(child: Text("Something went wrong ⚠️"));
          }
        },
      ),
    );
  }
}

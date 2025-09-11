// lib/screens/item_assignment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../printer_screen/provider/printer_config_provider.dart';

class ItemAssignmentScreen extends StatefulWidget {
  final int printerIndex;

  const ItemAssignmentScreen({super.key, required this.printerIndex});

  @override
  _ItemAssignmentScreenState createState() => _ItemAssignmentScreenState();
}

class _ItemAssignmentScreenState extends State<ItemAssignmentScreen> {
  final _searchController = TextEditingController();
  final List<String> _selectedItems = []; // Ensure this is List<String>

  @override
  Widget build(BuildContext context) {
    final printerProvider = Provider.of<PrinterProviderpos>(context);
    // final _productProvider = Provider.of<ProductProvider>(context);

    final printer = printerProvider.printers[widget.printerIndex];
    //  final products = _productProvider.products;

    // Get all assigned items across all printers
    // ignore: unused_local_variable
    final allAssignedItems = printerProvider.printers
        .where((p) => p.name != printer.name) // Exclude the current printer
        .expand((p) => p.items)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Items to ${printer.name}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'Search Items'),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          // Expanded(
          //   child: ListView.builder(
          //     itemCount: products.length,
          //     itemBuilder: (context, index) {
          //       final product = products[index];
          //       final itemId =
          //           product.varianceName.toString(); // Ensure this is a String
          //       if (_searchController.text.isEmpty ||
          //           product.varianceName
          //               .toLowerCase()
          //               .contains(_searchController.text.toLowerCase())) {
          //         final isAssigned = allAssignedItems.contains(itemId) &&
          //             !printer.items.contains(itemId);
          //         final isSelected = _selectedItems.contains(itemId) ||
          //             printer.items.contains(itemId);
          //         return ListTile(
          //           title: Text(product.varianceName),
          //           trailing: Checkbox(
          //             value: isSelected,
          //             onChanged: isAssigned
          //                 ? null
          //                 : (bool? value) {
          //                     setState(() {
          //                       if (value == true) {
          //                         _selectedItems.add(itemId);
          //                       } else {
          //                         _selectedItems.remove(itemId);
          //                       }
          //                     });
          //                   },
          //           ),
          //           enabled: !isAssigned || isSelected,
          //         );
          //       }
          //       return Container();
          //     },
          //   ),
          // ),
          ElevatedButton(
            onPressed: () {
              printer.items.addAll(_selectedItems);
              printerProvider
                  .updatePrinter(printer); // Pass only the printer object

              Navigator.pop(context);
            },
            child: const Text('Assign Items'),
          ),
        ],
      ),
    );
  }
}

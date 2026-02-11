import 'package:flutter/material.dart';

class AddNewItemCard extends StatelessWidget {
  final Function(String itemName, double grams)
      onAddItem; // Callback to add a new item

  const AddNewItemCard({Key? key, required this.onAddItem}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController itemNameController = TextEditingController();
    final TextEditingController gramsController = TextEditingController();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Item name input
            TextField(
              controller: itemNameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Grams input

            TextField(
              controller: gramsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Grams',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Add button
            ElevatedButton(
              onPressed: () {
                final itemName = itemNameController.text;
                final grams = double.tryParse(gramsController.text) ?? 0.0;

                if (itemName.isNotEmpty && grams > 0) {
                  onAddItem(itemName, grams);
                } else {
                  // Show an error message if the inputs are invalid
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please provide valid item details."),
                    ),
                  );
                }
              },
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }
}

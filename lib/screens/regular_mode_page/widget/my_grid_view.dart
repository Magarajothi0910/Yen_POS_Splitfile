import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/global_data_manager.dart';
import '../model/variance.dart';
import '../provider/cart_page_provider.dart';
import 'custom_reusable_widget/gridItem_widget.dart';
import 'item_card.dart';
import 'variance_dialog.dart';

class MyGridView extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const MyGridView({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridViewUI(
      items: items,
      itemBuilder: (context, item) => ItemCard(item: item),
      onTap: (item) {
        List<Variance> variances = item['variances']
            .map<Variance>((v) => Variance.fromJson(v))
            .toList();

        if (variances.isNotEmpty) {
          showVarianceDialog(context, variances, item['name']);
        }
      },
    );
  }
}

class MyCakesGridView extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const MyCakesGridView({Key? key, required this.items}) : super(key: key);

  /// Flatten the items → one entry per variance
  List<Map<String, dynamic>> flattenItems() {
    List<Map<String, dynamic>> flattened = [];
    for (var item in items) {
      final variances = item['variances'] as List<dynamic>? ?? [];
      for (var variance in variances) {
        Map<String, dynamic> varianceMap =
            (variance as Map<dynamic, dynamic>).cast<String, dynamic>();

        flattened.add({
          'itemName': item['name'],
          'category': item['category'],
          'variance': varianceMap,
        });
      }
    }
    return flattened;
  }

  @override
  Widget build(BuildContext context) {
    final flattenedItems = flattenItems();
    return GridCakeViewUI(
      items: flattenedItems,
      itemBuilder: (context, item) => ItemCakeCard(item: item),
      onTap: (item) async {
        final String itemName = item['itemName'] as String;
        final Map<String, dynamic> variance =
            item['variance'] as Map<String, dynamic>;
        final String varianceName = variance['varianceName'] as String? ?? '';

        // ✅ Null safe globalData fetch
        final branchwiseItems = GlobalDataManager().branchwiseItems;
        if (branchwiseItems == null || branchwiseItems['data'] == null) {
          debugPrint("⚠️ branchwiseItems or data is null");
          return;
        }

        final globalData = branchwiseItems['data'] as Map<String, dynamic>;
        if (!globalData.containsKey(itemName)) {
          debugPrint("⚠️ $itemName not found in globalData");
          return;
        }

        final Map<String, dynamic> itemData = globalData[itemName]['item'];
        final Map<String, dynamic> varianceData =
            globalData[itemName]['variance'][varianceName];

        // ✅ Dialog with scrollable content
        showDialog(
          context: context,
          builder: (BuildContext context) {
            TextEditingController productIdController = TextEditingController();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              backgroundColor: Colors.white,
              title: Text(
                "Enter Product Code",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: productIdController,
                      decoration: InputDecoration(
                        labelText: "Product Code",
                        labelStyle: TextStyle(color: Colors.blueGrey),
                        prefixIcon:
                            Icon(Icons.qr_code, color: Colors.blueAccent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.blueAccent, width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    String productId = productIdController.text.trim();
                    if (productId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Product Code is required."),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    Map<String, dynamic> newItem = {
                      'itemData': itemData,
                      'varianceData': varianceData,
                      'quantity': 1,
                      'productId': productId,
                      "from": "birthdaycakes",
                    };

                    Provider.of<CurrentSaleProvider>(context, listen: false)
                        .addItemToCart(newItem);
                    Provider.of<CurrentSaleProvider>(context, listen: false)
                        .loadCartItems();

                    Navigator.of(context).pop();
                  },
                  label: Text("Add to Cart"),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yen_pos/Global/global_data_manager.dart';

import 'custom_reusable_widget/gridItem_widget.dart';
import 'custom_reusable_widget/item_card_widget.dart';
import 'custom_reusable_widget/reusesable_variance_dialoge.dart';
import 'dart:developer' as developer;

class MixedboxPageWidget extends StatefulWidget {
  const MixedboxPageWidget({super.key});

  @override
  _MixedboxPageWidgetState createState() => _MixedboxPageWidgetState();
}

class _MixedboxPageWidgetState extends State<MixedboxPageWidget> {
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    var lazyBox = await Hive.openLazyBox('mixboxData');
    await itemProvider.fetchAndSaveMixboxData(lazyBox);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ItemProvider>(
      builder: (context, itemProvider, child) {
        final mixboxData = GlobalDataManager().mixboxData;

        // Log the mixboxData for debugging purposes
        developer.log(
          'Mixbox Data: ${mixboxData.toString()}',
          name: 'MixedboxPageWidget',
        );

        // Or use print statement if developer.log is not preferred
        // print('Mixbox Data: $mixboxData');

        if (mixboxData == null || mixboxData.isEmpty) {
          return const Center(
            child: Text(
              'No Mixbox data found.',
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        final castedMixboxData = (mixboxData as List)
            .cast<Map<String, dynamic>>();

        return Scaffold(
          backgroundColor: Colors.white,
          body: GridViewUI(
            items: castedMixboxData,
            itemBuilder: (context, mixbox) {
              return ItemCardUI(
                itemName: mixbox['mixboxName'],
                isFavorite: false,
                onFavoriteToggle: () {},
              );
            },
            onTap: (mixbox) {
              _showVarianceDialog(context, mixbox);
            },
          ),
        );
      },
    );
  }

  void _showVarianceDialog(BuildContext context, Map<String, dynamic> mixbox) {
    // Extract items and their details from the selected mixbox.
    List<dynamic> items = mixbox['items'] ?? [];

    // Convert the items to variance-like data for display.
    List<Variance> itemVariances = items.map((item) {
      String itemName = item['item_name'] ?? 'Unknown Item';
      double grams = item['grams']?.toDouble() ?? 0.0;
      return Variance(
        varianceName: itemName,
        varianceDefaultPrice: grams, // Using grams as the price for display.
      );
    }).toList();
    // Log each item in the mixbox

    // for (var item in items) {
    //   String itemName = item['item_name'] ?? 'Unknown Item';
    //   String uom = item['uom'] ?? 'Unknown UOM';
    //   double grams = item['grams']?.toDouble() ?? 0.0;

    //   developer.log('Item Name: $itemName', name: 'VarianceDialog');
    //   developer.log('UOM: $uom', name: 'VarianceDialog');
    //   developer.log('Grams: $grams', name: 'VarianceDialog');

    //   // Alternatively, print statements if preferred
    //   print('Mixbox Name: ${mixbox['mixboxName']}');
    //   print('Total Grams: ${mixbox['totalGrams']}');
    //   print('Item Name: $itemName');
    //   print('UOM: $uom');
    //   print('Grams: $grams');
    // }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReusableVarianceDialog(
          itemName: mixbox['mixboxName'],
          variances: itemVariances,
          mixbox: mixbox, // Pass the mixbox data here
          onAdd: (selectedVariance, quantity) {
            // ItemProvider().PrintVarianceName();

            // Handle the selected variance and quantity.
            // print("Selected Item: ${selectedVariance.varianceName}");
            // print("Grams: ${selectedVariance.varianceDefaultPrice}");
            // print("Quantity: $quantity");
          },
        );
      },
    );
  }
}

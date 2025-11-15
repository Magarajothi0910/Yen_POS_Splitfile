// common_quantity_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/regular_mode_page/provider/quantity_provider.dart';

/// Shows a quantity dialog that works everywhere:
///  • Adding from SearchDropdown
///  • Adding from VarianceDialog
///  • Updating a cart item
void showCommonQuantityDialog({
  required BuildContext context,
  required String itemName,
  required String varianceName,
  required double price,
  required Function(double) onAddToCart,
  double initialQuantity = 1.0,
  double? systemStockOverride, // optional pre-fetched stock
}) {
  // Reset the provider to the initial value
  final qtyProvider = Provider.of<QuantityProvider>(context, listen: false);
  qtyProvider.setQuantity(initialQuantity.toInt());

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        backgroundColor: CustomColors.whiteColor,
        title: Text("$varianceName - ₹${price.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Poppins',fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),

            // ---------- QUANTITY ROW ----------
            Consumer<QuantityProvider>(
              builder: (ctx, provider, _) {
                final currentQty = provider.quantity;
                final controller = TextEditingController(text: currentQty.toString());

                // Keep controller in sync with provider
                controller.text = currentQty.toString();
                controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ----- DECREMENT -----
                    IconButton(
                      iconSize: 40,
                      onPressed: provider.decrement,
                      icon: const Icon(Icons.remove_circle, color: CustomColors.blueColor),
                    ),
                    const SizedBox(width: 10),

                    // ----- TEXT FIELD -----
                    Material(
                      elevation: 4,
                      shadowColor: CustomColors.black,
                      color: Colors.white,
                      child: SizedBox(
                        width: 60,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Poppins',fontSize: 22, fontWeight: FontWeight.bold),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                          onChanged: (value) {
                            if (value.isEmpty) {
                              return;
                            }
                            final int? parsed = int.tryParse(value);
                            if (parsed != null && parsed > 0) {
                              provider.setQuantity(parsed);
                            }
                          },
                          onTap: () {
                            controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // ----- INCREMENT -----
                    IconButton(
                      iconSize: 40,
                      onPressed: provider.increment,
                      icon: const Icon(Icons.add_circle, color: CustomColors.blueColor),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          // ---------- CANCEL ----------
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: CustomColors.grey.withOpacity(0.1),
              foregroundColor: CustomColors.black.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Cancel", style: TextStyle(fontFamily: 'Poppins',fontSize: 16)),
          ),

          // ---------- ADD TO CART ----------
          Consumer<QuantityProvider>(
            builder: (ctx, provider, _) {
              return TextButton(
                onPressed: () async {
                  final selectedQty = provider.quantity.toDouble();

                  // ---- VALIDATE MINIMUM ----
                  if (selectedQty <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid quantity (minimum 1).'),
                        backgroundColor: CustomColors.redColor,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // ---- STOCK VALIDATION ----
                  double systemStock = systemStockOverride ?? 0.0;
                  if (systemStock <= 0) {
                    final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map<dynamic, dynamic>?;
                    final itemData = branchwiseItems?[itemName];
                    final varianceData = itemData?['variance']?[varianceName];
                    systemStock = (varianceData?['branchwise']?[aliasname]?['systemStock_$aliasname'] as num?)?.toDouble() ?? 0.0;
                  }

                  if (selectedQty > systemStock) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text("Selected quantity ($selectedQty) exceeds available stock ($systemStock)."),
                        backgroundColor: CustomColors.redColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // ---- SUCCESS ----
                  Navigator.of(dialogContext).pop();
                  onAddToCart(selectedQty);
                },
                style: TextButton.styleFrom(
                  backgroundColor: CustomColors.blueColor.withOpacity(0.1),
                  foregroundColor: CustomColors.blueColor,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Add to Cart', style: TextStyle(fontFamily: 'Poppins',fontSize: 16)),
              );
            },
          ),
        ],
      );
    },
  );
}

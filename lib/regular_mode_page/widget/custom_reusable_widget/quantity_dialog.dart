// common_quantity_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/regular_mode_page/provider/quantity_provider.dart';
import 'package:yenpos/regular_mode_page/widget/custom_reusable_widget/scafflodMesseger.dart';


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

  debugPrint("🔹 showCommonQuantityDialog called");
  debugPrint("   Item Name      : $itemName");
  debugPrint("   Variance Name  : $varianceName");
  debugPrint("   Price          : ₹$price");
  debugPrint("   Initial Qty    : $initialQuantity");
  debugPrint("   systemStockOverride: $systemStockOverride");

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        backgroundColor: CustomColors.whiteColor,
        title: Text(
          "$varianceName - ₹${price.toStringAsFixed(2)}",
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),

            // ---------- QUANTITY ROW ----------
            Consumer<QuantityProvider>(
              builder: (ctx, provider, _) {
                final currentQty = provider.quantity;
                final controller = TextEditingController(
                  text: currentQty.toString(),
                );

                // Keep controller in sync with provider
                controller.text = currentQty.toString();
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ----- DECREMENT -----
                    IconButton(
                      iconSize: 40,
                      onPressed: provider.decrement,
                      icon: const Icon(
                        Icons.remove_circle,
                        color: CustomColors.blueColor,
                      ),
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
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          onChanged: (value) {
                            debugPrint("📝 Quantity TextField changed to: '$value'");
                            if (value.isEmpty) {
                              return;
                            }
                            final int? parsed = int.tryParse(value);
                            if (parsed != null && parsed > 0) {
                              provider.setQuantity(parsed);
                              debugPrint("   → Provider updated to: $parsed");
                            } else {
                              debugPrint("   → Invalid input, ignored");
                            }
                          },
                          onTap: () {
                            controller.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: controller.text.length,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // ----- INCREMENT -----
                    IconButton(
                      iconSize: 40,
                      onPressed: provider.increment,
                      icon: const Icon(
                        Icons.add_circle,
                        color: CustomColors.blueColor,
                      ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              debugPrint("❌ Cancel button pressed");
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              "Cancel",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: CustomColors.black.withOpacity(0.7),
              ),
            ),
          ),

          // ---------- ADD TO CART ----------
          Consumer<QuantityProvider>(
            builder: (ctx, provider, _) {
              return TextButton(
                onPressed: () async {
                  debugPrint("✅ Add to Cart button pressed");

                  final selectedQty = provider.quantity.toDouble();
                  debugPrint("   Selected Quantity: $selectedQty");

                  // ---- VALIDATE MINIMUM ----
                  if (selectedQty <= 0) {
                    debugPrint("   → Validation failed: quantity <= 0");
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter a valid quantity (minimum 1).',
                        ),
                        backgroundColor: CustomColors.redColor,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  // ---- STOCK VALIDATION ----
                  double systemStock = systemStockOverride ?? 0.0;
                  debugPrint("   systemStockOverride provided: $systemStockOverride");
                  debugPrint("   Initial systemStock value: $systemStock");

                  if (systemStock <= 0) {
                    debugPrint("   → Fetching stock from Hive...");
                    try {
                      final lazyBox = await Hive.openBox('items');
                      final storedData = await lazyBox.get(
                        'branchwiseItems_$aliasname',
                      );

                      debugPrint("   Hive key used: branchwiseItems_$aliasname");
                      debugPrint("   Stored data found: ${storedData != null}");

                      final branchwiseItems =
                          storedData?['data'] as Map<dynamic, dynamic>?;

                      debugPrint("   branchwiseItems['data'] keys: ${branchwiseItems?.keys.join(', ')}");

                      final itemData = branchwiseItems?[itemName];
                      debugPrint("   Lookup itemName: '$itemName' → Found: ${itemData != null}");

                      if (itemData != null) {
                        final varianceMap = itemData['variance'] as Map?;
                        debugPrint("   Variance map keys: ${varianceMap?.keys.join(', ')}");

                        final varianceData = varianceMap?[varianceName];
                        debugPrint("   Lookup varianceName: '$varianceName' → Found: ${varianceData != null}");

                        if (varianceData != null) {
                          final branchStock = varianceData['branchwise']?[aliasname]?['systemStock_$aliasname'];
                          systemStock = (branchStock as num?)?.toDouble() ?? 0.0;
                          debugPrint("   → Fetched systemStock: $systemStock");
                        } else {
                          debugPrint("   → varianceData not found for '$varianceName'");
                        }
                      } else {
                        debugPrint("   → itemData not found for '$itemName'");
                      }
                    } catch (e) {
                      debugPrint("   → Error fetching stock from Hive: $e");
                    }
                  }

                  debugPrint("   Final systemStock used for validation: $systemStock");
                  debugPrint("   Comparing: selectedQty ($selectedQty) > systemStock ($systemStock)? ${selectedQty > systemStock}");

                  if (selectedQty > systemStock) {
                    debugPrint("   → Stock validation FAILED");
                    Navigator.of(dialogContext).pop();
                    showAutoDismissMessage(
                      context,
                      "Selected quantity ($selectedQty) exceeds available stock ($systemStock)",
                      backgroundColor: const Color.fromARGB(255, 231, 63, 61),
                    );
                    return;
                  }

                  debugPrint("   → Stock validation PASSED");
                  debugPrint("   → Closing dialog and calling onAddToCart($selectedQty)");

                  // ---- SUCCESS ----
                  Navigator.of(dialogContext).pop();
                  onAddToCart(selectedQty);
                },
                style: TextButton.styleFrom(
                  backgroundColor: CustomColors.blueColor.withOpacity(0.1),
                  foregroundColor: CustomColors.blueColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Add to Cart',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                ),
              );
            },
          ),
        ],
      );
    },
  );
}
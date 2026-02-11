// lib/Sale_order/Widgets/sales_order_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yen_pos/Sale_order/Provider/cartProvider.dart';
import 'package:yen_pos/Sale_order/Provider/saleorder_ui_provider.dart';

import 'package:yen_pos/Sale_order/Widgets/numeric_Calculator.dart';

class SalesOrderWidgets {
  /// Build navigation button
  static Widget buildNavButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      child: Text(label),
    );
  }

  /// Build create order button
  static Widget buildCreateOrderButton(
    CartSelectionProvider selectionProvider,
  ) {
    return ElevatedButton(
      onPressed: () {
        // selectionProvider.toggleCheckBoxVisibility();
      },
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        elevation: 2,
      ),
      child: Text('Create Order'),
    );
  }

  /// Build toggle button label

  /// Build all box quantity field
  static Widget buildAllBoxQtyField(
    BuildContext context,
    SalesOrderUIProvider uiProvider,
    Function(String) onChanged,
  ) {
    return SizedBox(
      width: 90,
      child: TextField(
        readOnly: true,
        showCursor: true,
        controller: uiProvider.allBoxQtyController,
        decoration: InputDecoration(
          labelText: 'Box Qty',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.blue.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          labelStyle: TextStyle(color: Colors.blue.shade700),
        ),
        onTap: () {
          ActiveField.activate(
            context: context,
            ctrl: uiProvider.allBoxQtyController,
            node: uiProvider.allBoxQtyFocus,
            numeric: true,
            fieldType: "boxQty",
          );
        },
        keyboardType: TextInputType.number,
        onChanged: onChanged,
      ),
    );
  }

  /// Build bulk discount field
  static Widget buildBulkDiscountField(
    BuildContext context,
    SalesOrderUIProvider uiProvider,
    Function(String) onChanged,
  ) {
    return SizedBox(
      width: 90,
      child: TextField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Discount',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.blue.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          labelStyle: TextStyle(color: Colors.blue.shade700, fontSize: 11),
          suffixIcon: Icon(Icons.percent, size: 17),
        ),
        controller: uiProvider.bulkDiscountController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d{0,2})?$')),
        ],
        onTap: () {
          ActiveField.activate(
            context: context,
            ctrl: uiProvider.bulkDiscountController,
            node: FocusNode(),
            numeric: true,
            fieldType: "discount",
          );
        },
        onChanged: onChanged,
      ),
    );
  }

  /// Build quantity button (+ or -)
  static Widget buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.blue),
        iconSize: 16,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  /// Get item price description
  static String getItemPriceDescription(dynamic item) {
    String priceDescription;
    if (item.uom == 'Kgs' || item.uom == 'Kg') {
      priceDescription = item.weight >= 1
          ? '${item.weight} kg × Rs.${item.pricePerKg}/kg'
          : '${(item.weight * 1000)} grams × Rs.${item.pricePerKg}/kg';
    } else {
      priceDescription =
          '${item.quantity.value} ${item.uom} × Rs.${item.pricePerKg}/${item.uom}';
    }

    if (item.itemWiseDiscount != null && item.itemWiseDiscount != 0) {
      priceDescription +=
          '\nDiscount: ${item.itemWiseDiscount}% (Rs.${item.itemWiseDiscountAmount})';
    }

    return priceDescription;
  }

  /// Build clear cart confirmation dialog
  static Future<void> showClearCartConfirmationDialog(
    BuildContext context,
    VoidCallback onClear,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(minHeight: 180, maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Clear Cart',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Are you sure you want to clear the cart? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        onClear();
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

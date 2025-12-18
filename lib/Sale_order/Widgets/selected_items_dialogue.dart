import 'package:flutter/material.dart';

class SelectedItemsDialog extends StatelessWidget {
  final Map<String, bool> itemSelectionState;
  final List<dynamic> cartItems;

  const SelectedItemsDialog({
    super.key,
    required this.itemSelectionState,
    required this.cartItems,
  });

  @override
  Widget build(BuildContext context) {
    final selectedItems = cartItems
        .where((item) => itemSelectionState[item.varianceName] == true)
        .toList();

    double normalTotal = 0.0;
    double discountedTotal = 0.0;

    // Calculate totals
    for (var item in selectedItems) {
      final itemTotal = _calculateItemTotal(item);
      normalTotal += itemTotal;

      final discountAmount = item.itemWiseDiscount != null
          ? itemTotal * (item.itemWiseDiscount / 100)
          : 0.0;
      discountedTotal += (itemTotal - discountAmount);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          minWidth: 280,
          maxWidth: 420,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.98), Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              blurRadius: 25,
              spreadRadius: 2,
              color: Colors.black.withOpacity(0.25),
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.indigo.shade600,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: Colors.white,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Selected Items Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Items List
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: selectedItems.map((item) {
                    final itemTotal = _calculateItemTotal(item);
                    final discountAmount = item.itemWiseDiscount != null
                        ? itemTotal * (item.itemWiseDiscount / 100)
                        : 0.0;
                    final discounted = itemTotal - discountAmount;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.indigo.shade100,
                            child: Text(
                              item.varianceName != null &&
                                      item.varianceName.isNotEmpty
                                  ? item.varianceName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.varianceName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Builder(
                                  builder: (_) {
                                    String priceDescription;
                                    if (item.uom == 'Kg' || item.uom == 'Kgs') {
                                      final weight = item.weight ?? 0;
                                      if (weight >= 1) {
                                        priceDescription =
                                            '${weight.toStringAsFixed(2)} kg × Rs.${item.pricePerKg.toStringAsFixed(0)}/kg';
                                      } else {
                                        priceDescription =
                                            '${(weight * 1000).toStringAsFixed(0)} grams × Rs.${item.pricePerKg.toStringAsFixed(0)}/kg';
                                      }
                                    } else {
                                      priceDescription =
                                          '${item.quantity.value} ${item.uom} × Rs.${item.pricePerKg.toStringAsFixed(0)}/${item.uom}';
                                    }

                                    return Text(
                                      priceDescription,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    );
                                  },
                                ),
                                if (item.itemWiseDiscount != null &&
                                    item.itemWiseDiscount != 0)
                                  Text(
                                    'Discount: ${item.itemWiseDiscount.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${itemTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (discountAmount > 0)
                                Text(
                                  '-₹${discountAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (discountAmount > 0)
                                Text(
                                  '₹${discounted.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade300, thickness: 1.2),

            // Totals
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  _buildTotalRow(
                    'Normal Total:',
                    normalTotal,
                    badgeColor: Colors.grey.shade700,
                  ),
                  const SizedBox(height: 6),
                  _buildTotalRow(
                    'Discounted Total:',
                    discountedTotal,
                    badgeColor: Colors.green.shade700,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Close Button
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Done"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to calculate item total based on UOM
  double _calculateItemTotal(dynamic item) {
    if (item.finalPrice != null) {
      return item.finalPrice!;
    } else {
      final uom = item.uom.toString().toLowerCase();
      if (uom == 'kg' || uom == 'kgs') {
        return (item.weight ?? 1) * item.quantity.value * item.pricePerKg;
      } else {
        return item.quantity.value.toDouble() * item.pricePerKg;
      }
    }
  }

  Widget _buildTotalRow(
    String label,
    double value, {
    required Color badgeColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: badgeColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

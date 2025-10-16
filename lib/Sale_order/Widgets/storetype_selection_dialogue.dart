import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:yenpos/Sale_order/Widgets/store_type_button.dart';


class StoreTypeSelectionDialog extends StatelessWidget {
  final void Function(String) onStoreTypeSelected;

  const StoreTypeSelectionDialog({
    super.key,
    required this.onStoreTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: Colors.grey[50], // Soft off-white background
      elevation: 4,
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      content: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                'Choose Your Store Type',
                style: tt.headlineSmall!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: StoreTypeButton(
                      icon: Icons.storefront_rounded,
                      label: 'In‑house',
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF26A69A),
                          Color(0xFF4DD0E1)
                        ], // Teal to Cyan
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onPressed: () {
                        onStoreTypeSelected('Inhouse');
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StoreTypeButton(
                      icon: Icons.local_shipping_rounded,
                      label: 'Warehouse',
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFF57C00),
                          Color(0xFFFFCA28)
                        ], // Orange to Amber
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onPressed: () {
                        onStoreTypeSelected('Warehouse');
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: tt.labelLarge!.copyWith(
                  color: Colors.teal[700], // Muted teal for cancel
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

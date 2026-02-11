import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StoreTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onPressed;

  const StoreTypeButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: Colors.white, // White icons for contrast
            ).animate().shake(
                  duration: 600.ms,
                  hz: 2,
                  delay: 200.ms,
                ),
            const SizedBox(height: 8),
            Text(
              label,
              style: tt.bodyLarge!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ).animate().scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1, 1),
            duration: 400.ms,
            curve: Curves.easeOutBack,
          ),
    );
  }
}

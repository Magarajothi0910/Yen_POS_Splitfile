import 'package:flutter/material.dart';
import 'package:yenpos/Global/Widget/scaffold_global.dart';

// ignore: must_be_immutable
class WeightSelector extends StatefulWidget {
  final String? varianceName;
  final Function(double) onValueSelected; // receives kg

  const WeightSelector({
    super.key,
    this.varianceName,
    required this.onValueSelected,
  });

  @override
  State<WeightSelector> createState() => _WeightSelectorState();
}

class _WeightSelectorState extends State<WeightSelector> {
  double? _selectedGrams;

  final List<double> quickValues = [20, 30, 50, 100, 150, 200, 250 , 500];

  void _selectWeight(double grams) {
    setState(() {
      _selectedGrams = grams;
    });
  }

  void _handleAddToCart() {
    if (_selectedGrams == null || _selectedGrams == 0) {
      GlobalScaffold.showMessage(
        message: 'Please select a weight',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final double kg = _selectedGrams! / 1000;
    widget.onValueSelected(kg);

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Variance name
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                widget.varianceName ?? 'Select Weight',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),

            // Display (old style look)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _selectedGrams == null
                    ? '0'
                    : '${_selectedGrams!.toStringAsFixed(0)}g',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // Quick buttons - old school grid style
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: quickValues.map((grams) {
                final isSelected = _selectedGrams == grams;

                return SizedBox(
                  width: 85,
                  child: ElevatedButton(
                    onPressed: () => _selectWeight(grams),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.green : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      elevation: isSelected ? 4 : 2,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '${grams.toStringAsFixed(0)}g',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Add to Cart button - classic style
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleAddToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Add to Cart',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
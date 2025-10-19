import 'package:flutter/material.dart';
import 'package:yenpos/Global/Widget/scaffold_global.dart';

// ignore: must_be_immutable
class NumericCalculator extends StatefulWidget {
  String? varianceName; // Add the varianceName parameter

  final Function(double) onValueSelected;

  NumericCalculator({
    super.key,
    this.varianceName,
    required this.onValueSelected,
  });

  @override
  _NumericCalculatorState createState() => _NumericCalculatorState();
}

class _NumericCalculatorState extends State<NumericCalculator> {
  String _display = '0'; // Treat the display as a String

  void _appendToDisplay(String value) {
    setState(() {
      if (value == '.') {
        // Allow adding decimal only if it doesn't exist yet
        if (!_display.contains('.')) {
          _display += value;
        }
      } else {
        if (_display.contains('.')) {
          // If there's a decimal, allow only 3 digits after it
          int decimalIndex = _display.indexOf('.');
          String decimalPart = _display.substring(decimalIndex + 1);
          if (decimalPart.length < 3) {
            _display += value;
          }
        } else {
          // If no decimal yet, append normally
          if (_display == '0') {
            _display = value;
          } else {
            _display += value;
          }
        }
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_display.length > 1) {
        _display = _display.substring(0, _display.length - 1);
      } else {
        _display = '0';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20), // Padding to avoid overflow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          15.0,
        ), // Rounded corners for the dialog
      ),
      child: Container(
        width: 250, // Smaller width for a more compact size
        padding: const EdgeInsets.all(16), // Padding inside the dialog
        constraints: const BoxConstraints(
          maxHeight: 500,
        ), // Set a max height to prevent overflow
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display the variance name
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                widget.varianceName
                    .toString(), // Display the variance name here
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),

            // Display the current input value with a controlled text size
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _display,
                style: const TextStyle(
                  fontSize: 28,
                ), // Slightly smaller font size for the display
                textAlign: TextAlign.center, // Center the text
              ),
            ),
            const SizedBox(height: 10),

            // Using a Column to arrange the buttons in rows
            Column(
              children: [
                // First row: 1, 2, 3
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButton('1'),
                    _buildButton('2'),
                    _buildButton('3'),
                  ],
                ),
                const SizedBox(height: 8),

                // Second row: 4, 5, 6
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButton('4'),
                    _buildButton('5'),
                    _buildButton('6'),
                  ],
                ),
                const SizedBox(height: 8),

                // Third row: 7, 8, 9
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButton('7'),
                    _buildButton('8'),
                    _buildButton('9'),
                  ],
                ),
                const SizedBox(height: 8),

                // Fourth row: ., 0, backspace
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButton('.'),
                    _buildButton('0'),
                    _buildButton('⌫', onPressed: _backspace),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Center the "Add to Cart" button and apply padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    // Parse the display value to a double. If parsing fails, default to 0.0.
                    double value = double.tryParse(_display) ?? 0.0;
                    // Call the callback provided by the parent widget.

                    if (value == 0.0) {
                      GlobalScaffold.showMessage(
                        message: 'Please enter a value greater than zero',
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      );
                      return;
                    }

                    widget.onValueSelected(value);
                    // Close the dialog.
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.blue, // Set the button color to blue
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        20.0,
                      ), // Rounded button
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: 25.0,
                    ), // Adjust padding for "Add to Cart" button
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, {VoidCallback? onPressed}) {
    return ElevatedButton(
      onPressed: onPressed ?? () => _appendToDisplay(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue, // Set button color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // Rounded buttons
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 16.0,
        ), // Adjust padding for smaller buttons
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}

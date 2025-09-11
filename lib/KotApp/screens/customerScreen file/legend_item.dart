import 'package:flutter/material.dart';

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData? icon; // Optional icon

  const LegendItem(
      {super.key, required this.color, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min, // Avoids extra spacing
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
                color: Colors.black26,
                width: 0.5), // Optional border for better visibility
          ),
        ),
        const SizedBox(width: 8),
        if (icon != null) ...[
          Icon(icon, size: 20, color: Colors.black54), // Icon if provided
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// Example Usage
Widget buildLegend() {
  return const Wrap(
    alignment: WrapAlignment.spaceEvenly,
    children: [
      Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LegendItem(
                color: Color(0xFFA5D6A7),
                label: 'Available  Seat   ',
              ),
              LegendItem(
                color: Color.fromARGB(255, 143, 183, 216),
                label: ' Preinvoiced Seat',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget buildLegend1() {
  return const Wrap(
    alignment: WrapAlignment.spaceEvenly,
    children: [
      Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LegendItem(
                color: Color.fromARGB(255, 241, 90, 70),
                label: 'Running Seat      ',
              ),
              // SizedBox(width: 68),
              LegendItem(
                color: Color.fromARGB(255, 216, 197, 143),
                label: 'Hold Seat             ',
              ),
            ],
          )
        ],
      ),
    ],
  );
}

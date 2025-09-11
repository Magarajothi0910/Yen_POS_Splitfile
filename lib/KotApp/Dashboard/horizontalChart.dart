// import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DashboardWidget extends StatelessWidget {
  final Map<String, double> data;

  DashboardWidget({super.key, required Map<String, int> data})
      : data = data.map((key, value) => MapEntry(key, value.toDouble()));

  @override
  Widget build(BuildContext context) {
    // Calculate max value
    double maxValue = data.values.reduce((a, b) => a > b ? a : b);

    // Dynamically calculate interval based on maxValue
    double interval;
    if (maxValue <= 10) {
      interval = 1; // Small values use interval of 1
    } else if (maxValue <= 50) {
      interval = 5; // Moderate values use interval of 5
    } else if (maxValue <= 100) {
      interval = 10; // Larger values use interval of 10
    } else {
      interval =
          (maxValue / 10).ceilToDouble(); // Very large values scale dynamically
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 5,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
          borderRadius: BorderRadius.circular(12),
        ),
        child: data.isEmpty
            ? const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : const Column(
                children: [
                  SizedBox(height: 16),
                ],
              ),
      ),
    );
  }
}

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
                  // Expanded(
                  //   child: BarChart(
                  //     BarChartData(
                  //       alignment: BarChartAlignment.spaceAround,
                  //       barGroups: data.entries.map((e) {
                  //         int index = data.keys.toList().indexOf(e.key);
                  //         return BarChartGroupData(
                  //           x: index,
                  //           barRods: [
                  //             BarChartRodData(
                  //               toY: e.value,
                  //               gradient: const LinearGradient(
                  //                 colors: [
                  //                   Colors.blueAccent,
                  //                   Colors.greenAccent
                  //                 ],
                  //               ),
                  //               width: 16,
                  //               borderRadius: BorderRadius.circular(4),
                  //             ),
                  //           ],
                  //         );
                  //       }).toList(),
                  //       titlesData: FlTitlesData(
                  //         leftTitles: AxisTitles(
                  //           sideTitles: SideTitles(
                  //             showTitles: true,
                  //             reservedSize: 40,
                  //             interval: interval, // Use dynamic interval
                  //             getTitlesWidget: (value, meta) {
                  //               // Display only intervals and max value
                  //               if (value % interval == 0 ||
                  //                   value == maxValue) {
                  //                 return Padding(
                  //                   padding: const EdgeInsets.only(
                  //                       left: 8.0), // Add left padding
                  //                   child: Text(value.toInt().toString()),
                  //                 );
                  //               }
                  //               return const SizedBox.shrink();
                  //             },
                  //           ),
                  //         ),
                  //         bottomTitles: AxisTitles(
                  //           sideTitles: SideTitles(
                  //             showTitles: true,
                  //             getTitlesWidget: (value, meta) {
                  //               if (value.toInt() < data.keys.length) {
                  //                 return Text(
                  //                     data.keys.elementAt(value.toInt()));
                  //               }
                  //               return const Text('');
                  //             },
                  //             reservedSize: 40,
                  //           ),
                  //         ),
                  //         topTitles: const AxisTitles(
                  //           sideTitles: SideTitles(showTitles: false),
                  //         ),
                  //         rightTitles: const AxisTitles(
                  //           sideTitles: SideTitles(showTitles: false),
                  //         ),
                  //       ),
                  //       gridData: const FlGridData(
                  //         show: true,
                  //         // drawVerticalLine: true,
                  //         // drawHorizontalLine: true,

                  //         // horizontalInterval: interval, // Use dynamic interval
                  //         // getDrawingHorizontalLine: (value) => FlLine(
                  //         //   color: Colors.grey.shade300,
                  //         //   strokeWidth: 0.10,
                  //         // ),
                  //       ),
                  //       borderData: FlBorderData(
                  //         show: true,
                  //         border: Border.all(
                  //           color: Colors.grey.shade300,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';

class TableStatusChart extends StatelessWidget {
  final int fullyBooked;
  final int partiallyBooked;
  final int available;

  const TableStatusChart({super.key, 
    required this.fullyBooked,
    required this.partiallyBooked,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, double> dataMap = {
      "Fully Booked": fullyBooked.toDouble(),
      "Partially Booked": partiallyBooked.toDouble(),
      "Available": available.toDouble(),
    };

    return Padding(
      padding: const EdgeInsets.all(10.0),
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
        child: PieChart(
          dataMap: dataMap,
          chartType: ChartType.disc,
          chartValuesOptions:
              const ChartValuesOptions(showChartValuesInPercentage: true),
          legendOptions: const LegendOptions(showLegends: true),
        ),
      ),
    );
  }
}

// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';

// class SalesTrendsChart extends StatelessWidget {
//   final Map<String, double> salesTrends;

//   SalesTrendsChart({required Map<String, int> salesTrends})
//       : salesTrends =
//             salesTrends.map((key, value) => MapEntry(key, value.toDouble()));

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.5),
//               spreadRadius: 3,
//               blurRadius: 5,
//               offset: Offset(0, 3),
//             ),
//           ],
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Column(
//           children: [
//             const Padding(
//               padding: EdgeInsets.all(8.0),
//               child: Text(
//                 'Sales Trends',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.blueAccent,
//                 ),
//               ),
//             ),
//             SizedBox(
//               height: 300,
//               child: PieChart(
//                 PieChartData(
//                   sections: salesTrends.entries
//                       .map(
//                         (e) => PieChartSectionData(
//                           color: Colors.primaries[
//                               salesTrends.keys.toList().indexOf(e.key) %
//                                   Colors.primaries.length],
//                           value: e.value,
//                           title: '${e.key}\n${e.value.toInt()}%',
//                           radius: 80,
//                           titleStyle: const TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                       )
//                       .toList(),
//                   sectionsSpace: 2,
//                   centerSpaceRadius: 40,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:server/models/globals.dart';
// import '../components/circularLoadingindicator.dart';
// import '../components/globalAppbar.dart';
// import '../widgets/bottomNav.dart';
// import 'chart_widget.dart';
// import 'horizontalChart.dart';
// import 'kottablestatusApi.dart';
// import 'ordersApi.dart';

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   _DashboardScreenState createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   late Future<Map<String, dynamic>> dashboardData;
//   OrderApiService ordersapiService = OrderApiService();
//   ApiService apiService = ApiService();

//   @override
//   void initState() {
//     super.initState();
//     dashboardData = fetchDashboardData(); // Combined API call
//   }

//   Future<Map<String, dynamic>> fetchDashboardData() async {
//     final tableStatus = await apiService.fetchTableStatus();
//     final orderCounts = await ordersapiService.fetchOrderCounts();
//     return {
//       'tableStatus': tableStatus,
//       'orderCounts': orderCounts,
//     };
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: GlobalAppBar(
//         title: 'DashBoard',
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () {
//               setState(() {
//                 dashboardData = fetchDashboardData();
//               });
//             },
//           ),
//         ],
//       ),
//       body: OrientationBuilder(
//         builder: (context, orientation) {
//           return FutureBuilder<Map<String, dynamic>>(
//             future: dashboardData, // Single FutureBuilder
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return Center(child: CircularLoadingIndicator());
//               } else if (snapshot.hasError) {
//                 return Center(child: Text('Error: ${snapshot.error}'));
//               } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                 return const Center(child: Text('No data available'));
//               } else {
//                 var tableStatus =
//                     snapshot.data!['tableStatus'] as Map<String, dynamic>;
//                 var orderCounts =
//                     snapshot.data!['orderCounts'] as Map<String, int>;

//                 int fullyBooked = tableStatus['fullyBookedSeatCount'] ?? 0;
//                 int partiallyBooked =
//                     tableStatus['partiallyBookedSeatCount'] ?? 0;
//                 int available = tableStatus['availableSeatCount'] ?? 0;

//                 bool isPortrait = orientation == Orientation.portrait;

//                 return SingleChildScrollView(
//                   child: Column(
//                     children: [
//                       Text("Serverip $serverip $appType"),
//                       const Padding(
//                         padding: EdgeInsets.only(top: 8.0, bottom: 10.0),
//                         child: Text(
//                           'Real-Time Table Overview',
//                           style: TextStyle(
//                             fontSize: 20,
//                           ),
//                         ),
//                       ),
//                       SizedBox(
//                         height: isPortrait ? 300 : 200,
//                         child: TableStatusChart(
//                           fullyBooked: fullyBooked,
//                           partiallyBooked: partiallyBooked,
//                           available: available,
//                         ),
//                       ),
//                       // const Padding(
//                       //   padding: EdgeInsets.all(10.0),
//                       //   child: Row(
//                       //     mainAxisAlignment: MainAxisAlignment.start,
//                       //     children: [
//                       //       Text(
//                       //         '    Order Summary',
//                       //         style: TextStyle(
//                       //           fontSize: 20,
//                       //         ),
//                       //       ),
//                       //     ],
//                       //   ),
//                       // ),
//                       // SizedBox(
//                       //   height: isPortrait ? 300 : 200,
//                       //   child: DashboardWidget(data: orderCounts),
//                       // ),
//                     ],
//                   ),
//                 );
//               }
//             },
//           );
//         },
//       ),
//       bottomNavigationBar: const GlobalBottomNav(),
//     );
//   }
// }

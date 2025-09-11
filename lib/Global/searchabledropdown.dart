// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../screens/take_away_orders/take_away_providers/salesOrder_provider.dart';

// class SalesOrderScreen extends StatefulWidget {
//   const SalesOrderScreen({super.key});

//   @override
//   _SalesOrderScreenState createState() => _SalesOrderScreenState();
// }

// class _SalesOrderScreenState extends State<SalesOrderScreen> {
//   @override
//   Widget build(BuildContext context) {
//     final salesOrderProvider = Provider.of<SaleOrderProvider>(context);

//     return Scaffold(
//         backgroundColor: Colors.white,
//         resizeToAvoidBottomInset: false,
//         appBar: AppBar(
//           title: Text("Search Dropdown"),
//         ),
//         body: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Item Search Bar
//                 TextField(
//                   controller: salesOrderProvider.searchController,
//                   decoration: InputDecoration(
//                     labelText: 'Search Item',
//                     border: const OutlineInputBorder(),
//                     prefixIcon: const Icon(Icons.search),
//                     suffixIcon: IconButton(
//                       icon: const Icon(Icons.clear),
//                       onPressed: () {
//                         setState(() {
//                           salesOrderProvider.searchController.clear();
//                           salesOrderProvider.filteredItems = [];
//                         });
//                       },
//                     ),
//                   ),
//                   onChanged: (value) {
//                     setState(() {
//                       if (value.isEmpty) {
//                         salesOrderProvider.filteredItems = [];
//                       } else {
//                         // Filter based on varianceName (String) inside each map
//                         // salesOrderProvider.filteredItems =
//                         //     salesOrderProvider.variances.where((item) {
//                         //   return item['varianceName']
//                         //       .toLowerCase()
//                         //       .contains(value.toLowerCase());
//                         // }).toList();
//                       }
//                     });
//                   },
//                 ),

//                 const SizedBox(height: 16.0),

//                 salesOrderProvider.filteredItems.isNotEmpty
//                     ? Expanded(
//                         child: ListView.builder(
//                           itemCount: salesOrderProvider.filteredItems.length,
//                           itemBuilder: (context, index) {
//                             final selectedItem =
//                                 salesOrderProvider.filteredItems[index];

//                             return ListTile(
//                               title: Text(selectedItem['varianceName']),
//                               onTap: () {},
//                             );
//                           },
//                         ),
//                       )
//                     : Container(),

//                 const Text(
//                   'Cart Details',
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
//                 ),
//                 const SizedBox(height: 16.0),

//                 // Display selected item (if any)
//                 if (salesOrderProvider.selectedItem != null)
//                   Text(
//                     'Selected Item: ${salesOrderProvider.selectedItem!['varianceName']}',
//                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
//                   ),
//               ],
//             )));
//   }
// }

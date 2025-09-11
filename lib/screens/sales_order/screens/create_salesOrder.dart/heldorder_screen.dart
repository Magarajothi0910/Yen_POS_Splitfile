// import 'package:flutter/material.dart';
// import 'package:yenposapp/Global/custom_button_reuse.dart';
// import 'package:yenposapp/providers/customerScreen_provider.dart';

// class HeldOrdersScreen extends StatefulWidget {
//   @override
//   _HeldOrdersScreenState createState() => _HeldOrdersScreenState();
// }

// class _HeldOrdersScreenState extends State<HeldOrdersScreen> {
//   bool showHeldOrders = false; // State variable to toggle ListView
//   List<Order> heldOrders = []; // Example list of held orders

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Held Orders'),
//       ),
//       body: Column(
//         children: [
//           CustomButton(
//             text: 'Held Orders',
//             onPressed: () {
//               setState(() {
//                 showHeldOrders = !showHeldOrders; // Toggle visibility
//               });
//             },
//           ),
//           if (showHeldOrders)
//             heldOrders.isNotEmpty
//                 ? SizedBox(
//                     height: 200,
//                     child: ListView.builder(
//                       itemCount: heldOrders.length,
//                       itemBuilder: (context, index) {
//                         final order = heldOrders[index];
//                         return ListTile(
//                           title: Text('Customer: ${order.customerName}'),
//                           subtitle: Text(
//                               'Delivery Date: ${order.deliveryDate}\nDelivery Time: ${order.deliveryTime}\nEvent: ${order.event}'),
//                           trailing: IconButton(
//                             icon: const Icon(Icons.delete),
//                             onPressed: () {
//                               setState(() {
//                                 heldOrders.removeAt(index);
//                               });
//                             },
//                           ),
//                           onTap: () {
//                             // Use this to restore data to the form
//                             final provider = customerScreenProvider;
//                             provider.dateController.text = order.deliveryDate;
//                             provider.timeController.text = order.deliveryTime;
//                             provider.setSelectedEvent(order.event);
//                             provider
//                                 .setSelectedDeliveryType(order.deliveryType);
//                             provider.landmarkController.text =
//                                 order.landmark ?? '';
//                             provider.addressController.text =
//                                 order.address ?? '';
//                             provider.customerNameController.text =
//                                 order.customerName;
//                             provider.mobileNoController.text =
//                                 order.customerMobile;
//                             provider.searchController.text = order.employeeName;

//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                 content: Text('Order data restored to form'),
//                               ),
//                             );
//                           },
//                         );
//                       },
//                     ),
//                   )
//                 : const Text('No held orders available'),
//         ],
//       ),
//     );
//   }
// }

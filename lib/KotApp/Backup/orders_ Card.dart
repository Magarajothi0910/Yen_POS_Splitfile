// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import '../../servicess/CancellationHandler.dart';
// import '../../servicess/preInvociePrint_services.dart';
// import '../../modelss/globals.dart';
// import '../../modelss/printer.dart';
// import '../../providers/bottomNavprovider.dart';
// import '../../providers/order_provider.dart';
// import '../../providers/printer_provider.dart';
// import '../../providers/product_provider.dart';
// import '../../screens/order_summary_screen.dart';
// import '../capitalizeWord.dart';

// class OrderSummaryCard extends StatefulWidget {
//   final String tableNumber;
//   final String seat;
//   final List<Map<String, dynamic>> seatOrders;
//   final double seatTotal;
//   final String waiter;
//   final String loggedInUserName;

//   const OrderSummaryCard({
//     Key? key,
//     required this.tableNumber,
//     required this.seat,
//     required this.seatOrders,
//     required this.seatTotal,
//     required this.waiter,
//     required this.loggedInUserName,
//   }) : super(key: key);

//   @override
//   _OrderSummaryCardState createState() => _OrderSummaryCardState();
// }

// class _OrderSummaryCardState extends State<OrderSummaryCard> {
//   late WebSocketChannel channel;
//   Map<int, String?> selectedVariants = {};

//   @override
//   void initState() {
//     super.initState();

//     // Initialize the WebSocket channel
//     channel = WebSocketChannel.connect(
//       Uri.parse('ws://$serverip:$port'),
//     );

//     // Optionally listen to incoming messages
//     channel.stream.listen((message) {
//       print("Received from server: $message");
//     });
//   }

//   @override
//   void dispose() {
//     // Close the WebSocket connection when the widget is disposed
//     channel.sink.close();
//     super.dispose();
//   }

//   Future<void> sendMessage(Map<String, dynamic> configDetails) async {
//     try {
//       final jsonData = jsonEncode(configDetails);
//       channel.sink.add(jsonData);
//       print("Message sent: $jsonData");
//     } catch (error) {
//       print("Error while sending message: $error");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final orderProvider = Provider.of<OrderProvider>(context, listen: false);
//     final printerProvider = Provider.of<PrinterProvider>(context);
//     Future<void> patchStatusConfirm(String tableNumber, String seat,
//         List<Map<String, dynamic>> seatOrders) async {
//       for (var order in seatOrders) {
//         orderProvider.patchOrderStatusBySeathiveOrderId(
//             order['seathiveOrderId'], "confirm");
//         print(
//             "patchOrderStatusBySeathiveOrderId  ${order['seathiveOrderId']}${order['status']}");
//       }
//     }

//     return Card(
//       margin: const EdgeInsets.all(10.0),
//       // color: const Color(0xFFF4FDFF),
//       color: Colors.white,
//       child: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const SizedBox(height: 5),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: widget.seatOrders.map((order) {
//                 int orderIndex = widget.seatOrders.indexOf(order) + 1;

//                 return Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Order $orderIndex: TknNo ${order['tokenNo']}',
//                       style: const TextStyle(
//                           fontSize: 15, fontWeight: FontWeight.bold),
//                     ),
//                     const Divider(),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 8.0),
//                       child: Column(
//                         children: [
//                           // Header Row
//                           Padding(
//                             padding: const EdgeInsets.symmetric(vertical: 4.0),
//                             child: Row(
//                               children: [
//                                 const Expanded(
//                                   flex: 4,
//                                   child: Text(
//                                     'Item',
//                                     style:
//                                         TextStyle(fontWeight: FontWeight.bold),
//                                   ),
//                                 ),
//                                 const Expanded(
//                                   flex: 2,
//                                   child: Text(
//                                     ' Qty',
//                                     style:
//                                         TextStyle(fontWeight: FontWeight.bold),
//                                   ),
//                                 ),
//                                 if (order['weights'] != null &&
//                                     (order['weights'] as List<double>)
//                                             .reduce((a, b) => a + b) >
//                                         0.0)
//                                   const Expanded(
//                                     flex: 2,
//                                     child: Text(
//                                       '  Wt',
//                                       style: TextStyle(
//                                           fontWeight: FontWeight.bold),
//                                     ),
//                                   ),
//                                 const Expanded(
//                                   flex: 3,
//                                   child: Text(
//                                     '    Price',
//                                     style:
//                                         TextStyle(fontWeight: FontWeight.bold),
//                                   ),
//                                 ),
//                                 const Expanded(
//                                   flex: 2,
//                                   child: Text(
//                                     'Amt',
//                                     style:
//                                         TextStyle(fontWeight: FontWeight.bold),
//                                   ),
//                                 ),
//                                 const Expanded(
//                                   flex: 3,
//                                   child: Text(
//                                     'Action   ',
//                                     style:
//                                         TextStyle(fontWeight: FontWeight.bold),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           const Divider(),
//                           // Data Rows
//                           ...List.generate(order['varianceNames'].length, (i) {
//                             final String varianceNames =
//                                 order['varianceNames'][i];
//                             final double price = order['prices'][i];
//                             final double quantity = order['quantities'][i];
//                             final double amounts = order['amounts'][i];
//                             final double weight = order['weights'][i] ?? 0.0;
//                             final Map<String, dynamic> config =
//                                 order['config'][i];
//                             print("Config length: ${config.length}");
//                             final int configQtyLength =
//                                 order['config']?[i]?['configQty']?.length ?? 0;
//                             final int addOnLength =
//                                 order['config']?[i]?['addOn']?.length ?? 0;
//                             final int addOnPriceLength =
//                                 order['config']?[i]?['addOn']?.length ?? 0;
//                             final int varianceLength =
//                                 order['config']?[i]?['variance']?.length ?? 0;

//                             print("ConfigQty length: $configQtyLength");
//                             print("AddOn length: $addOnLength");
//                             print("AddOnPrice length: $addOnPriceLength");
//                             print("Variance length: $varianceLength");

//                             Map<String, dynamic> groupedConfig = {};
//                             for (int j = 0; j < config['addOn'].length; j++) {
//                               bool hasConfig = (config['addOn'] != null &&
//                                       j < config['addOn'].length &&
//                                       config['addOn'][j].isNotEmpty) ||
//                                   (config['variance'] != null &&
//                                       j < config['variance'].length &&
//                                       config['variance'][j].isNotEmpty &&
//                                       config['variance'][j] !=
//                                           'Default'.toLowerCase()) ||
//                                   (config['type'] != null &&
//                                       j < config['type'].length &&
//                                       config['type'][j].isNotEmpty) ||
//                                   (config['remark'] != null &&
//                                       j < config['remark'].length &&
//                                       config['remark'][j].isNotEmpty);

//                               if (hasConfig) {
//                                 final key =
//                                     '${j < config['addOn'].length ? config['addOn'][j] : ''}|${j < config['addOnPrice'].length ? config['addOnPrice'][j] : ''}|${j < config['variance'].length ? config['variance'][j] : ''}|${j < config['type'].length ? config['type'][j] : ''}|${j < config['remark'].length ? config['remark'][j] : ''}|${j < config['configQty'].length ? config['configQty'][j] : ''}';

//                                 groupedConfig[key] =
//                                     groupedConfig.containsKey(key)
//                                         ? groupedConfig[key] + 1
//                                         : 1;
//                               }
//                             }

//                             List<String> selectedAddOns = [];

//                             final productProvider =
//                                 Provider.of<ProductProvider>(context);
//                             final addOns = productProvider.addons ??
//                                 []; // Null safety check
//                             print("AddonsDD $addOns");
//                             // Filter add-ons that contain the current variance name
//                             final filteredAddOns = addOns.where((addon) {
//                               final items = addon['addOnItems'] ??
//                                   []; // Null safety check
//                               return items.contains(varianceNames);
//                             }).toList();

//                             List<String> allAddOns = filteredAddOns
//                                 .map((e) => e['addOn'].toString())
//                                 .toList();
//                             Map<int, int> reducedQuantities =
//                                 {}; // Key: item index, Value: sum of reduced quantities

//                             print("allAddOns   $allAddOns");
//                             return Padding(
//                               padding: const EdgeInsets.all(1.0),
//                               child: Column(
//                                 children: [
//                                   Row(
//                                     children: [
//                                       Expanded(
//                                         flex: 4,
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               '${capitalizeWords(order['varianceNames'][i])} ',
//                                               style: (order['quantities'][i]) ==
//                                                       0
//                                                   ? const TextStyle(
//                                                       fontSize:
//                                                           10, // Set font size to 10
//                                                       decoration: TextDecoration
//                                                           .lineThrough,
//                                                       color: Colors.red,
//                                                     )
//                                                   : const TextStyle(
//                                                       fontSize:
//                                                           12, // Set font size to 10
//                                                     ),
//                                             ),
//                                             if (order['cancelledQty'] != null &&
//                                                 order['cancelledQty'][i] > 0)
//                                               Text(
//                                                 'Canceled Qty: ${order['cancelledQty'][i]}',
//                                                 style: const TextStyle(
//                                                   fontSize:
//                                                       12, // Set font size to 10
//                                                   decoration: TextDecoration
//                                                       .lineThrough,
//                                                   color: Colors.red,
//                                                 ),
//                                               ),
//                                           ],
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: Text(
//                                           '${quantity.toInt()}',
//                                           style: quantity == 0
//                                               ? const TextStyle(
//                                                   decoration: TextDecoration
//                                                       .lineThrough,
//                                                   color: Colors.red,
//                                                 )
//                                               : const TextStyle(
//                                                   fontSize:
//                                                       12, // Set font size to 10
//                                                 ),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: weight > 0
//                                             ? Text(
//                                                 weight.toStringAsFixed(2),
//                                                 style: quantity == 0
//                                                     ? const TextStyle(
//                                                         decoration:
//                                                             TextDecoration
//                                                                 .lineThrough,
//                                                         color: Colors.red,
//                                                       )
//                                                     : const TextStyle(
//                                                         fontSize:
//                                                             12, // Set font size to 12
//                                                       ),
//                                               )
//                                             : const Text(
//                                                 "", // Display an empty text widget as a placeholder
//                                                 style: TextStyle(
//                                                   fontSize:
//                                                       12, // Set font size to 12
//                                                 ),
//                                               ),
//                                       ),
//                                       Expanded(
//                                         flex: 3,
//                                         child: Text(
//                                           '₹${price.toInt()}',
//                                           style: quantity == 0
//                                               ? const TextStyle(
//                                                   decoration: TextDecoration
//                                                       .lineThrough,
//                                                   color: Colors.red,
//                                                 )
//                                               : const TextStyle(
//                                                   fontSize:
//                                                       12, // Set font size to 10
//                                                 ),
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 2,
//                                         child: Text(
//                                           '₹${amounts.toInt()}',
//                                           style: quantity == 0
//                                               ? const TextStyle(
//                                                   decoration: TextDecoration
//                                                       .lineThrough,
//                                                   color: Colors.red,
//                                                 )
//                                               : const TextStyle(
//                                                   fontSize:
//                                                       12, // Set font size to 10
//                                                 ),
//                                         ),
//                                       ),
//                                       // SizedBox(
//                                       //   width: 30,
//                                       //   child: IconButton(
//                                       //     icon: const Icon(Icons.edit),
//                                       //     onPressed: order['isCanceled'] == true
//                                       //         ? null
//                                       //         : () async {
//                                       //             List<Map<String, dynamic>>
//                                       //                 config = List<
//                                       //                         Map<String,
//                                       //                             dynamic>>.from(
//                                       //                     order['config']);
//                                       //             List<double> quantities =
//                                       //                 List<double>.from(
//                                       //                     order['quantities']);

//                                       //             await showDialog(
//                                       //               context: context,
//                                       //               builder: (context) =>
//                                       //                   AlertDialog(
//                                       //                 title: Center(
//                                       //                   child: Text(
//                                       //                     "Edit  ${order['varianceNames'][i]}",
//                                       //                     style:
//                                       //                         const TextStyle(
//                                       //                             fontSize: 15),
//                                       //                   ),
//                                       //                 ),
//                                       //                 content: ConstrainedBox(
//                                       //                   constraints:
//                                       //                       BoxConstraints(
//                                       //                     maxHeight:
//                                       //                         MediaQuery.of(
//                                       //                                     context)
//                                       //                                 .size
//                                       //                                 .height *
//                                       //                             0.7,
//                                       //                   ),
//                                       //                   child: Scrollbar(
//                                       //                     thumbVisibility: true,
//                                       //                     child:
//                                       //                         SingleChildScrollView(
//                                       //                       child: Column(
//                                       //                         mainAxisSize:
//                                       //                             MainAxisSize
//                                       //                                 .min,
//                                       //                         children: List.generate(
//                                       //                             config[i][
//                                       //                                     'configQty']
//                                       //                                 .length,
//                                       //                             (index) {
//                                       //                           // selectedVariant = (config[i]['variance'] !=
//                                       //                           //             null &&
//                                       //                           //         config[i]['variance'].length >
//                                       //                           //             index)
//                                       //                           //     ? config[i][
//                                       //                           //             'variance']
//                                       //                           //         [index]
//                                       //                           //     : ''; // Provide a default empty value to avoid errors

//                                       //                           List<
//                                       //                               String> addons = (config[i]['addOn'] !=
//                                       //                                       null &&
//                                       //                                   config[i]['addOn'].length >
//                                       //                                       index)
//                                       //                               ? List<
//                                       //                                   String>.from(config[i]
//                                       //                                       [
//                                       //                                       'addOn']
//                                       //                                   [index])
//                                       //                               : [];

//                                       //                           String type = (config[i]['type'] !=
//                                       //                                       null &&
//                                       //                                   config[i]['type'].length >
//                                       //                                       index)
//                                       //                               ? config[i][
//                                       //                                       'type']
//                                       //                                   [index]
//                                       //                               : '';

//                                       //                           String remark = (config[i]['remark'] !=
//                                       //                                       null &&
//                                       //                                   config[i]['remark'].length >
//                                       //                                       index)
//                                       //                               ? config[i][
//                                       //                                       'remark']
//                                       //                                   [index]
//                                       //                               : '';
//                                       //                           List<String>
//                                       //                               availableVariants =
//                                       //                               productProvider.getVariantsForItem(
//                                       //                                   order['varianceNames']
//                                       //                                       [
//                                       //                                       i]);
//                                       //                           // Controllers and notifiers
//                                       //                           TextEditingController
//                                       //                               remarkController =
//                                       //                               TextEditingController(
//                                       //                                   text:
//                                       //                                       remark);
//                                       //                           ValueNotifier<
//                                       //                                   bool>
//                                       //                               isParcelNotifier =
//                                       //                               ValueNotifier<
//                                       //                                       bool>(
//                                       //                                   type ==
//                                       //                                       "Parcel");
//                                       //                           ValueNotifier<
//                                       //                                   bool>
//                                       //                               toggleRemarkNotifier =
//                                       //                               ValueNotifier<
//                                       //                                       bool>(
//                                       //                                   remark
//                                       //                                       .isNotEmpty);
//                                       //                           print(
//                                       //                               "configQty length: ${config[i]['configQty']?.length ?? 0}");
//                                       //                           print(
//                                       //                               "addOn length: ${config[i]['addOn']?.length ?? 0}");
//                                       //                           print(
//                                       //                               "variance length: ${config[i]['variance']?.length ?? 0}");
//                                       //                           print(
//                                       //                               "type length: ${config[i]['type']?.length ?? 0}");
//                                       //                           print(
//                                       //                               "remark length: ${config[i]['remark']?.length ?? 0}");

//                                       //                           return Padding(
//                                       //                             padding: const EdgeInsets
//                                       //                                 .symmetric(
//                                       //                                 vertical:
//                                       //                                     5.0),
//                                       //                             child: Column(
//                                       //                               crossAxisAlignment:
//                                       //                                   CrossAxisAlignment
//                                       //                                       .start,
//                                       //                               children: [
//                                       //                                 Row(
//                                       //                                   mainAxisAlignment:
//                                       //                                       MainAxisAlignment.start,
//                                       //                                   children: [
//                                       //                                     Flexible(
//                                       //                                       child:
//                                       //                                           Text(
//                                       //                                         '${index + 1}. ${capitalizeWords(order['varianceNames'][i])}',
//                                       //                                         style: TextStyle(
//                                       //                                           fontSize: 14,
//                                       //                                           fontWeight: FontWeight.bold,
//                                       //                                           decoration: config[i]['configQty'][index] == 0 ? TextDecoration.lineThrough : null,
//                                       //                                         ),
//                                       //                                         overflow: TextOverflow.ellipsis,
//                                       //                                       ),
//                                       //                                     ),
//                                       //                                     StatefulBuilder(
//                                       //                                       builder:
//                                       //                                           (context, setStateInner) {
//                                       //                                         return IconButton(
//                                       //                                           icon: Icon(Icons.remove_circle, color: Colors.red),
//                                       //                                           onPressed: () {
//                                       //                                             setStateInner(() {
//                                       //                                               if (quantities[i] > 0 && config[i]['configQty'][index] > 0) {
//                                       //                                                 quantities[i] -= 1;
//                                       //                                                 config[i]['configQty'][index] -= 1;
//                                       //                                               }
//                                       //                                             });
//                                       //                                           },
//                                       //                                         );
//                                       //                                       },
//                                       //                                     ),

//                                       //                                     // IconButton(
//                                       //                                     //   icon:
//                                       //                                     //       const Icon(Icons.refresh, color: Colors.blue),
//                                       //                                     //   onPressed:
//                                       //                                     //       () {},
//                                       //                                     // ),
//                                       //                                   ],
//                                       //                                 ),
//                                       //                                 const SizedBox(
//                                       //                                     height:
//                                       //                                         5),
//                                       //                                 Row(
//                                       //                                   children: [
//                                       //                                     if (allAddOns
//                                       //                                         .isNotEmpty)
//                                       //                                       SizedBox(
//                                       //                                         width: 120,
//                                       //                                         height: 50,
//                                       //                                         child: StatefulBuilder(
//                                       //                                           builder: (context, setStateInner) {
//                                       //                                             return DropdownButtonFormField<String>(
//                                       //                                               isExpanded: true,
//                                       //                                               decoration: const InputDecoration(
//                                       //                                                 contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                                       //                                                 hintStyle: TextStyle(fontSize: 12),
//                                       //                                                 border: OutlineInputBorder(
//                                       //                                                   borderRadius: BorderRadius.all(Radius.circular(8.0)),
//                                       //                                                   borderSide: BorderSide(color: Colors.grey, width: 1.0),
//                                       //                                                 ),
//                                       //                                                 enabledBorder: OutlineInputBorder(
//                                       //                                                   borderRadius: BorderRadius.all(Radius.circular(8.0)),
//                                       //                                                   borderSide: BorderSide(color: Colors.grey, width: 1.0),
//                                       //                                                 ),
//                                       //                                                 focusedBorder: OutlineInputBorder(
//                                       //                                                   borderRadius: BorderRadius.all(Radius.circular(8.0)),
//                                       //                                                   borderSide: BorderSide(color: Colors.teal, width: 1.5),
//                                       //                                                 ),
//                                       //                                               ),
//                                       //                                               hint: Text(
//                                       //                                                 addons.isEmpty ? 'Select Add-ons' : addons.join(", "),
//                                       //                                                 overflow: TextOverflow.ellipsis,
//                                       //                                                 style: const TextStyle(fontSize: 12),
//                                       //                                               ),
//                                       //                                               onChanged: (_) {}, // No need to change value directly
//                                       //                                               items: allAddOns.map((String addOn) {
//                                       //                                                 return DropdownMenuItem<String>(
//                                       //                                                   value: addOn,
//                                       //                                                   child: StatefulBuilder(
//                                       //                                                     builder: (context, setStateCheckbox) {
//                                       //                                                       bool isSelected = addons.contains(addOn);

//                                       //                                                       return GestureDetector(
//                                       //                                                         onTap: () {
//                                       //                                                           setStateInner(() {
//                                       //                                                             if (isSelected) {
//                                       //                                                               addons.remove(addOn);
//                                       //                                                             } else {
//                                       //                                                               addons.add(addOn);
//                                       //                                                             }
//                                       //                                                             config[i]['addOn'][index] = List.from(addons);
//                                       //                                                             print("Updated Add-ons: ${addons}");
//                                       //                                                           });
//                                       //                                                           setStateCheckbox(() {}); // Force rebuild of checkbox state
//                                       //                                                         },
//                                       //                                                         child: Row(
//                                       //                                                           children: [
//                                       //                                                             Expanded(
//                                       //                                                               child: Text(
//                                       //                                                                 addOn,
//                                       //                                                                 style: const TextStyle(fontSize: 12),
//                                       //                                                                 overflow: TextOverflow.ellipsis,
//                                       //                                                               ),
//                                       //                                                             ),
//                                       //                                                             Checkbox(
//                                       //                                                               value: isSelected,
//                                       //                                                               onChanged: (bool? selected) {
//                                       //                                                                 setStateInner(() {
//                                       //                                                                   if (selected == true) {
//                                       //                                                                     addons.add(addOn);
//                                       //                                                                   } else {
//                                       //                                                                     addons.remove(addOn);
//                                       //                                                                   }
//                                       //                                                                   config[i]['addOn'][index] = List.from(addons);
//                                       //                                                                   print("Updated Add-ons: ${addons}");
//                                       //                                                                 });
//                                       //                                                                 setStateCheckbox(() {}); // Refresh UI
//                                       //                                                               },
//                                       //                                                               activeColor: Colors.teal,
//                                       //                                                             ),
//                                       //                                                           ],
//                                       //                                                         ),
//                                       //                                                       );
//                                       //                                                     },
//                                       //                                                   ),
//                                       //                                                 );
//                                       //                                               }).toList(),
//                                       //                                             );
//                                       //                                           },
//                                       //                                         ),
//                                       //                                       ),
//                                       //                                     if (config[i]['variance']
//                                       //                                         .where((v) => v.toString().trim().isNotEmpty && v.toLowerCase() != "default")
//                                       //                                         .isNotEmpty)
//                                       //                                       Consumer<ProductProvider>(
//                                       //                                         builder: (context, productProvider, child) {
//                                       //                                           int orderIndex = i; // The current row index

//                                       //                                           // Get the available variants for the current item and add "Default" option
//                                       //                                           List<String> availableVariants = [
//                                       //                                             'Default',
//                                       //                                             ...productProvider.getVariantsForItem(order['varianceNames'][orderIndex])
//                                       //                                           ];

//                                       //                                           return StatefulBuilder(
//                                       //                                             builder: (context, setInnerState) {
//                                       //                                               return SizedBox(
//                                       //                                                 width: MediaQuery.of(context).size.width * 0.3, // Adjust width dynamically
//                                       //                                                 child: DropdownButton<String>(
//                                       //                                                   isExpanded: true,
//                                       //                                                   value: selectedVariants[orderIndex] ?? 'Default',
//                                       //                                                   items: availableVariants.map((variant) {
//                                       //                                                     return DropdownMenuItem<String>(
//                                       //                                                       value: variant,
//                                       //                                                       child: Text(variant),
//                                       //                                                     );
//                                       //                                                   }).toList(),
//                                       //                                                   onChanged: (value) {
//                                       //                                                     setInnerState(() {
//                                       //                                                       selectedVariants[orderIndex] = value;
//                                       //                                                     });

//                                       //                                                     config[orderIndex]['variance'][index] = value == "Default" ? "" : value;
//                                       //                                                   },
//                                       //                                                 ),
//                                       //                                               );
//                                       //                                             },
//                                       //                                           );
//                                       //                                         },
//                                       //                                       ),
//                                       //                                     ValueListenableBuilder<
//                                       //                                         bool>(
//                                       //                                       valueListenable:
//                                       //                                           isParcelNotifier,
//                                       //                                       builder: (context,
//                                       //                                           isParcel,
//                                       //                                           child) {
//                                       //                                         return Column(
//                                       //                                           children: [
//                                       //                                             Row(
//                                       //                                               children: [
//                                       //                                                 Checkbox(
//                                       //                                                   value: isParcel,
//                                       //                                                   onChanged: (value) {
//                                       //                                                     isParcelNotifier.value = value!;
//                                       //                                                     config[i]['type'][index] = value ? "Parcel" : "";
//                                       //                                                   },
//                                       //                                                   activeColor: Colors.teal,
//                                       //                                                   checkColor: Colors.white,
//                                       //                                                 ),
//                                       //                                               ],
//                                       //                                             ),
//                                       //                                             const Text(
//                                       //                                               "Parcel",
//                                       //                                               style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
//                                       //                                             ),
//                                       //                                           ],
//                                       //                                         );
//                                       //                                       },
//                                       //                                     ),
//                                       //                                     ValueListenableBuilder<
//                                       //                                         bool>(
//                                       //                                       valueListenable:
//                                       //                                           toggleRemarkNotifier,
//                                       //                                       builder: (context,
//                                       //                                           toggleRemark,
//                                       //                                           child) {
//                                       //                                         return Column(
//                                       //                                           children: [
//                                       //                                             Row(
//                                       //                                               children: [
//                                       //                                                 Switch(
//                                       //                                                   value: toggleRemark,
//                                       //                                                   onChanged: (value) {
//                                       //                                                     toggleRemarkNotifier.value = value;
//                                       //                                                     if (!value) {
//                                       //                                                       remarkController.clear();
//                                       //                                                       config[i]['remark'][index] = "";
//                                       //                                                     }
//                                       //                                                   },
//                                       //                                                   activeColor: Colors.teal,
//                                       //                                                 ),
//                                       //                                               ],
//                                       //                                             ),
//                                       //                                             const Text(
//                                       //                                               "Remark: ",
//                                       //                                               style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
//                                       //                                             ),
//                                       //                                           ],
//                                       //                                         );
//                                       //                                       },
//                                       //                                     ),
//                                       //                                   ],
//                                       //                                 ),
//                                       //                                 ValueListenableBuilder<
//                                       //                                     bool>(
//                                       //                                   valueListenable:
//                                       //                                       toggleRemarkNotifier,
//                                       //                                   builder: (context,
//                                       //                                       toggleRemark,
//                                       //                                       child) {
//                                       //                                     return toggleRemark
//                                       //                                         ? TextField(
//                                       //                                             controller: remarkController,
//                                       //                                             decoration: const InputDecoration(
//                                       //                                               labelText: 'Remark',
//                                       //                                               border: OutlineInputBorder(),
//                                       //                                             ),
//                                       //                                             onChanged: (value) {
//                                       //                                               config[i]['remark'][index] = value;
//                                       //                                             },
//                                       //                                           )
//                                       //                                         : const SizedBox();
//                                       //                                   },
//                                       //                                 ),
//                                       //                               ],
//                                       //                             ),
//                                       //                           );
//                                       //                         }),
//                                       //                       ),
//                                       //                     ),
//                                       //                   ),
//                                       //                 ),
//                                       //                 actions: [
//                                       //                   ElevatedButton(
//                                       //                     style: ElevatedButton
//                                       //                         .styleFrom(
//                                       //                       backgroundColor:
//                                       //                           Colors.red,
//                                       //                       foregroundColor:
//                                       //                           Colors.white,
//                                       //                     ),
//                                       //                     child: const Text(
//                                       //                         'Cancel'),
//                                       //                     onPressed: () {
//                                       //                       Navigator.of(
//                                       //                               context)
//                                       //                           .pop();
//                                       //                     },
//                                       //                   ),
//                                       //                   ElevatedButton(
//                                       //                     style: ElevatedButton
//                                       //                         .styleFrom(
//                                       //                       backgroundColor:
//                                       //                           Colors.green,
//                                       //                       foregroundColor:
//                                       //                           Colors.white,
//                                       //                     ),
//                                       //                     child:
//                                       //                         const Text('OK'),
//                                       //                     onPressed: () async {
//                                       //                       try {
//                                       //                         // Update config and quantities
//                                       //                         order['config'] =
//                                       //                             config;
//                                       //                         order['quantities'] =
//                                       //                             quantities;

//                                       //                         // Check for partially cancelled items
//                                       //                         bool
//                                       //                             isPartiallyCancelled =
//                                       //                             config.any(
//                                       //                                 (item) {
//                                       //                           return item[
//                                       //                                   'configQty']
//                                       //                               .any((qty) =>
//                                       //                                   qty ==
//                                       //                                   0);
//                                       //                         });
//                                       //                         order['partiallyCancelled'] =
//                                       //                             isPartiallyCancelled
//                                       //                                 ? "Yes"
//                                       //                                 : "No";

//                                       //                         // Update the amounts for all items
//                                       //                         for (int i = 0;
//                                       //                             i <
//                                       //                                 quantities
//                                       //                                     .length;
//                                       //                             i++) {
//                                       //                           order['amounts']
//                                       //                                   [i] =
//                                       //                               quantities[
//                                       //                                       i] *
//                                       //                                   order['prices']
//                                       //                                       [i];
//                                       //                         }

//                                       //                         // Prepare the payload
//                                       //                         Map<String,
//                                       //                                 dynamic>
//                                       //                             configDetails =
//                                       //                             {
//                                       //                           'action':
//                                       //                               "updateConfigDetails",
//                                       //                           'seathiveOrderId':
//                                       //                               order[
//                                       //                                   'seathiveOrderId'],
//                                       //                           'config':
//                                       //                               config,
//                                       //                           'quantities':
//                                       //                               quantities,
//                                       //                           'cancelledQty':
//                                       //                               order[
//                                       //                                   'cancelledQty'],
//                                       //                           'amounts': order[
//                                       //                               'amounts'],
//                                       //                           'partiallyCancelled':
//                                       //                               order[
//                                       //                                   'partiallyCancelled'],
//                                       //                         };

//                                       //                         // Add the status only if all quantities are 0.0
//                                       //                         if (quantities
//                                       //                             .every((qty) =>
//                                       //                                 qty ==
//                                       //                                 0.0)) {
//                                       //                           configDetails[
//                                       //                                   'status'] =
//                                       //                               'cancelled';
//                                       //                         }

//                                       //                         // Log the payload for debugging
//                                       //                         print(
//                                       //                             "Payload to send: $configDetails");
//                                       //                         PrinterProvider
//                                       //                             printerProvider =
//                                       //                             Provider.of<
//                                       //                                     PrinterProvider>(
//                                       //                                 context,
//                                       //                                 listen:
//                                       //                                     false);

//                                       //                         // Generate the detailed receipt with printer IPs
//                                       //                         printFormattedReceipt(
//                                       //                             order,
//                                       //                             printerProvider);

//                                       //                         // Send the payload
//                                       //                         await sendMessage(
//                                       //                             configDetails);

//                                       //                         // Close the dialog
//                                       //                         // ignore: use_build_context_synchronously
//                                       //                         Navigator.of(
//                                       //                                 context)
//                                       //                             .pop();
//                                       //                       } catch (error) {
//                                       //                         // Handle any errors
//                                       //                         print(
//                                       //                             "An error occurred: $error");
//                                       //                       }
//                                       //                     },
//                                       //                   ),
//                                       //                 ],
//                                       //               ),
//                                       //             );
//                                       //           },
//                                       //   ),
//                                       // ),
//                                       const SizedBox(
//                                         width: 15,
//                                       ),
//                                       IconButton(
//                                         icon: const Icon(Icons.cancel),
//                                         onPressed: () async {
//                                           await CancellationHandler
//                                               .handleCancelItem(
//                                                   context,
//                                                   order,
//                                                   i,
//                                                   widget.tableNumber,
//                                                   widget.seat,
//                                                   widget.waiter,
//                                                   widget.loggedInUserName);
//                                           print("cancellation items: $order");
//                                         },
//                                       ),
//                                     ],
//                                   ),
//                                   Column(
//                                     children:
//                                         groupedConfig.entries.map((entry) {
//                                       final parts = entry.key.split('|');
//                                       print("print parts: $parts");
//                                       final isStriked = parts[5] ==
//                                           '0'; // Check if quantity is 0
//                                       print("groupconfig details");
//                                       print(
//                                           "${parts[0]} ${parts[1]} ${parts[2]} ${parts[3]} ${parts[4]}");
//                                       return Column(
//                                         children: [
//                                           Row(
//                                             // mainAxisAlignment:
//                                             //     MainAxisAlignment.spaceBetween,
//                                             children: [
//                                               SizedBox(
//                                                 width: 60,
//                                                 child: Column(
//                                                   children: [
//                                                     Text(
//                                                         capitalizeWords(
//                                                             varianceNames),
//                                                         style: TextStyle(
//                                                           fontSize: 12,
//                                                           color: Colors.grey,
//                                                           decoration: isStriked
//                                                               ? TextDecoration
//                                                                   .lineThrough
//                                                               : null,
//                                                         )),
//                                                   ],
//                                                 ),
//                                               ),
//                                               SizedBox(
//                                                 width: 20,
//                                                 child: Column(
//                                                   children: [
//                                                     if (parts[5].isNotEmpty)
//                                                       Text(parts[5],
//                                                           style: TextStyle(
//                                                             fontSize: 12,
//                                                             color: Colors.grey,
//                                                             decoration: isStriked
//                                                                 ? TextDecoration
//                                                                     .lineThrough
//                                                                 : null,
//                                                           )),
//                                                   ],
//                                                 ),
//                                               ),
//                                               const SizedBox(
//                                                 width: 20,
//                                               ),
//                                               SizedBox(
//                                                 width: 150,
//                                                 child: Column(
//                                                   crossAxisAlignment:
//                                                       CrossAxisAlignment.start,
//                                                   children: [
//                                                     if (parts[0].isNotEmpty &&
//                                                         parts[0] != '[]') ...[
//                                                       const Text(
//                                                         'Add-on:',
//                                                         style: TextStyle(
//                                                             fontSize: 12,
//                                                             color: Colors.grey),
//                                                       ),
//                                                       // Display each add-on vertically
//                                                       ...parts[0]
//                                                           .replaceAll('[', '')
//                                                           .replaceAll(']', '')
//                                                           .toLowerCase()
//                                                           .split(',')
//                                                           .map((addon) => Text(
//                                                                 addon
//                                                                     .trim(), // Display each addon on a new line
//                                                                 style:
//                                                                     TextStyle(
//                                                                   fontSize: 12,
//                                                                   color: Colors
//                                                                       .grey,
//                                                                   decoration: isStriked
//                                                                       ? TextDecoration
//                                                                           .lineThrough
//                                                                       : null,
//                                                                 ),
//                                                               ))
//                                                           .toList(),
//                                                     ],
//                                                     if (parts[2].isNotEmpty &&
//                                                         parts[2] != 'Default')
//                                                       Text(
//                                                           'Variants: ${parts[2]}',
//                                                           style: TextStyle(
//                                                             fontSize: 12,
//                                                             color: Colors.grey,
//                                                             decoration: isStriked
//                                                                 ? TextDecoration
//                                                                     .lineThrough
//                                                                 : null,
//                                                           )),
//                                                     if (parts[3].isNotEmpty)
//                                                       Text('Type: ${parts[3]}',
//                                                           style: TextStyle(
//                                                             fontSize: 12,
//                                                             color: Colors.grey,
//                                                             decoration: isStriked
//                                                                 ? TextDecoration
//                                                                     .lineThrough
//                                                                 : null,
//                                                           )),
//                                                     if (parts[4].isNotEmpty)
//                                                       Text(
//                                                           'Remarks: ${parts[4]}',
//                                                           style: TextStyle(
//                                                             fontSize: 12,
//                                                             color: Colors.grey,
//                                                             decoration: isStriked
//                                                                 ? TextDecoration
//                                                                     .lineThrough
//                                                                 : null,
//                                                           )),
//                                                   ],
//                                                 ),
//                                               ),
//                                               SizedBox(
//                                                 width: 50,
//                                                 child: Column(
//                                                   children: [
//                                                     if (parts[1].isNotEmpty &&
//                                                         parts[1] != '[]') ...[
//                                                       const Text(
//                                                         'Price:',
//                                                         style: TextStyle(
//                                                             fontSize: 12,
//                                                             color: Colors.grey),
//                                                       ),
//                                                       // Display each add-on vertically
//                                                       ...parts[1]
//                                                           .replaceAll('[', '')
//                                                           .replaceAll(']', '')
//                                                           .toLowerCase()
//                                                           .split(',')
//                                                           .map((addonPrice) =>
//                                                               Text(
//                                                                 addonPrice
//                                                                     .trim(), // Display each addon on a new line
//                                                                 style:
//                                                                     TextStyle(
//                                                                   fontSize: 12,
//                                                                   color: Colors
//                                                                       .grey,
//                                                                   decoration: isStriked
//                                                                       ? TextDecoration
//                                                                           .lineThrough
//                                                                       : null,
//                                                                 ),
//                                                               ))
//                                                           .toList(),
//                                                     ],
//                                                   ],
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                           const Divider(), // Add a horizontal line after each Row
//                                         ],
//                                       );
//                                     }).toList(),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           }),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                   ],
//                 );
//               }).toList(),
//             ),
//             const SizedBox(height: 5),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.redAccent,
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 20, vertical: 15),
//                   ),
//                   child: const Text(
//                     "Cancel Order",
//                     style: TextStyle(
//                         color: Colors.white, fontWeight: FontWeight.bold),
//                   ),
//                   onPressed: () async {
//                     await CancellationHandler.handleCancelAll(
//                         context, widget.seatOrders);
//                   },
//                 ),
//                 ElevatedButton(
//                   onPressed: () async {
//                     bool confirm = await showDialog(
//                       context: context,
//                       builder: (BuildContext context) {
//                         return AlertDialog(
//                           shape: const RoundedRectangleBorder(
//                             borderRadius:
//                                 BorderRadius.all(Radius.circular(15.0)),
//                           ),
//                           title: const Text(
//                             'Confirmation ',
//                             style: TextStyle(
//                                 fontSize: 24, fontWeight: FontWeight.bold),
//                           ),
//                           content: Text(
//                             'Are you sure? you want to generate the Pre invoice for\n ${widget.tableNumber} - ${widget.seat}?',
//                             style: const TextStyle(
//                                 fontSize: 15, color: Colors.black87),
//                           ),
//                           actions: <Widget>[
//                             ElevatedButton(
//                               onPressed: () {
//                                 Navigator.of(context).pop(false);
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor:
//                                     const Color.fromARGB(255, 239, 72, 72),
//                               ),
//                               child: const Text(
//                                 'Cancel',
//                                 style: TextStyle(
//                                     fontSize: 16, color: Colors.black),
//                               ),
//                             ),
//                             ElevatedButton(
//                               onPressed: () {
//                                 Navigator.of(context).pop(true);
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color(0xFFA5D6A7),
//                               ),
//                               child: const Text(
//                                 'Confirm',
//                                 style: TextStyle(
//                                     fontSize: 16, color: Colors.black),
//                               ),
//                             ),
//                           ],
//                         );
//                       },
//                     );
//                     if (confirm == true) {
//                       final preInvoicePrinter =
//                           printerProvider.printers.firstWhere(
//                         (printer) => printer.type == 'PreInvoice',
//                         orElse: () {
//                           return Printer(
//                             name: 'default_printer_name',
//                             ipAddress: 'default_ip',
//                             type: 'default_type',
//                           );
//                         },
//                       );

//                       await PreInvoicePrinter.printReceipt(
//                         ipAddress: preInvoicePrinter.ipAddress,
//                         tableNumber: widget.tableNumber,
//                         seat: widget.seat,
//                         total: widget.seatTotal,
//                         seatOrders: widget.seatOrders,
//                         userName: widget.loggedInUserName,
//                         waiter: widget.waiter,
//                         receiptType: 'PreInvoice',
//                       );

//                       final String hiveOrderId = widget.seatOrders.isNotEmpty
//                           ? widget.seatOrders.first['hiveOrderId']
//                           : '';

//                       await patchStatusConfirm(
//                           widget.tableNumber, widget.seat, widget.seatOrders);

//                       orderProvider.notifyListeners();
//                       Provider.of<BottomNavProvider>(context, listen: false)
//                           .updateIndex(0);

//                       // ignore: use_build_context_synchronously
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                             builder: (context) => const OrderSummaryScreen()),
//                       );
//                     }
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFFA5D6A7),
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 20, vertical: 15),
//                   ),
//                   child: const Text(
//                     'Generate preInvoice',
//                     style: TextStyle(color: Colors.black),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

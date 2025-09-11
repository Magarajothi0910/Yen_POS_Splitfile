// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:yenposapp/Global/customAll_keyboard.dart';
// import 'package:yenposapp/screens/sales_order/globals.dart';
// import '../../../kot_screen/global/globals.dart';
// import '../create_salesOrder.dart/bank_search_dropdown.dart';
// import '../model/sales_order_model.dart';
// import 'services/get_sales_order_service.dart';

// void showPaymentDialog(BuildContext context, SalesOrderDisplay salesOrder) {
//   final GlobalKey keyboardKey = GlobalKey();
//   final WebSocketChannel _channel = WebSocketChannel.connect(
//     Uri.parse(
//       'ws://$serverip:$port',
//     ), // Make sure serverip and port are defined
//   );

//   // Add a listener for WebSocket messages if needed
//   _channel.stream.listen(
//     (data) {},
//     onError: (error) {
//       // print('WebSocket error: $error');
//     },
//   );

//   final apiSalesprovider = Provider.of<ApiServiceSalesOrderProvider>(
//     context,
//     listen: false,
//   );
//   List<double> totalAmount = List.from(salesOrder.advanceAmount ?? []);
//   TextEditingController advanceController = TextEditingController();
//   int selectedPaymentMethod = 0; // 0 = Cash, 1 = Card, 2 = UPI
//   double totalAdvanceAmount = salesOrder.advanceAmount!.fold(
//     0.0,
//     (sum, value) => sum + value,
//   );
//   final total = salesOrder.totalAmount - totalAdvanceAmount;
//   List<String> selectedPaymentsMethod = ["Cash"]; // Default payment method
//   FocusNode advanceAmountFocus = FocusNode();
//   Widget buildStyledFormField({
//     required TextEditingController controller,
//     required String labelText,
//     required IconData icon,
//     String? hintText,
//     TextInputType keyboardType = TextInputType.text,
//     String? prefixText,
//     bool readOnly = false,
//     VoidCallback? onTap,
//     FocusNode? focusNode,
//   }) {
//     return TextFormField(
//       controller: controller,
//       focusNode: focusNode,
//       readOnly: readOnly,
//       keyboardType: keyboardType,
//       style: const TextStyle(
//         fontSize: 15,
//         color: Colors.black87, // ✅ Professional readable text
//       ),
//       onTap: onTap,
//       decoration: InputDecoration(
//         prefixText: prefixText,
//         labelText: labelText,
//         hintText: hintText,
//         hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
//         filled: true,
//         fillColor: Colors.white, // ✅ Clean white background
//         prefixIcon: Icon(icon, color: Colors.grey.shade700), // ✅ Subtle icon
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: BorderSide(color: Colors.grey.shade300),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: BorderSide(
//               color: Colors.blue, width: 1.5), // ✅ Only blue on focus
//         ),
//         contentPadding:
//             const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
//       ),
//     );
//   }

//   int _sendInvoiceCallCount = 0;

//   Future<void> sendInvoiceDataToServer(Map<String, dynamic> invoiceData) async {
//     _sendInvoiceCallCount++;

//     try {
//       final jsonData = jsonEncode(invoiceData);
//       _channel.sink.add(jsonData);
//     } catch (e) {}
//   }

//   List<TextEditingController> controllers = [];
//   // Cheque-specific controllers
//   TextEditingController chequeNumberController = TextEditingController();
//   TextEditingController chequeAmountController = TextEditingController();
//   TextEditingController chequeNameController = TextEditingController();
//   TextEditingController chequeBankController = TextEditingController();
//   TextEditingController chequeDateController = TextEditingController();

//   //focus nodes for cheque fields if needed
//   FocusNode chequeNumberFocus = FocusNode();
//   FocusNode chequeAmountFocus = FocusNode();
//   FocusNode chequeNameFocus = FocusNode();
//   FocusNode remarkFocus = FocusNode();

//   Widget buildChequeDetails() {
//     return Padding(
//       padding: const EdgeInsets.all(15),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Expanded(
//                 child: buildStyledFormField(
//                   controller: chequeNumberController,
//                   focusNode: chequeNumberFocus,
//                   labelText: 'Cheque Number',
//                   icon: Icons.numbers,
//                   hintText: 'Enter cheque number',
//                   keyboardType: TextInputType.number,
//                   readOnly: true, // 👈 prevents system keyboard
//                   onTap: () {
//                     ActiveField.activate(
//                         ctrl: chequeNumberController,
//                         numeric: false,
//                         node: chequeNumberFocus);
//                   },
//                 ),
//               ),
//               SizedBox(width: 10),
//               Expanded(
//                 child: buildStyledFormField(
//                   controller: chequeAmountController,
//                   focusNode: chequeAmountFocus,
//                   labelText: 'Cheque Amount',
//                   icon: Icons.currency_rupee,
//                   hintText: 'Enter amount',
//                   keyboardType: TextInputType.number,
//                   prefixText: '₹ ',
//                   readOnly: true, // 👈 only custom keyboard allowed
//                   onTap: () {
//                     ActiveField.activate(
//                         ctrl: chequeAmountController,
//                         numeric: true,
//                         node: chequeAmountFocus);
//                   },
//                 ),
//               ),
//               SizedBox(width: 10),
//               Expanded(
//                 child: buildStyledFormField(
//                   controller: chequeDateController,
//                   labelText: 'Cheque Date',
//                   icon: Icons.calendar_today,
//                   hintText: 'Select date',
//                   readOnly: true,
//                   onTap: () async {
//                     final DateTime? picked = await showDatePicker(
//                       context: context,
//                       initialDate: DateTime.now(),
//                       firstDate: DateTime(2000),
//                       lastDate: DateTime(2100),
//                       builder: (context, child) {
//                         return Theme(
//                           data: Theme.of(context).copyWith(
//                             colorScheme: const ColorScheme.light(
//                               primary: Colors.blueAccent,
//                               onPrimary: Colors.white,
//                               onSurface: Colors.black,
//                             ),
//                           ),
//                           child: child!,
//                         );
//                       },
//                     );
//                     if (picked != null) {
//                       // Format into dd-MM-yyyy
//                       chequeDateController.text =
//                           DateFormat('dd-MM-yyyy').format(picked);
//                     }
//                   },
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           Row(
//             children: [
//               Expanded(
//                 child: buildStyledFormField(
//                   controller: chequeNameController,
//                   focusNode: chequeNameFocus,
//                   labelText: 'Cheque Holder Name',
//                   icon: Icons.person,
//                   hintText: 'Enter name on cheque',
//                   readOnly: true, // 👈 disable default keyboard
//                   onTap: () {
//                     ActiveField.activate(
//                         ctrl: chequeNameController,
//                         numeric: false,
//                         node: chequeNameFocus);
//                   },
//                 ),
//               ),
//               const SizedBox(width: 15),
//               Expanded(
//                   child: BankSearchDropdown(
//                 keyboardKey: keyboardKey,
//               )), // Dummy dropdown
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   showDialog(
//     barrierDismissible: false,
//     context: context,
//     builder: (BuildContext context) {
//       controllers = [
//         advanceController,
//         chequeNumberController,
//         chequeAmountController,
//         chequeNameController,
//         chequeBankController,
//         chequeDateController,
//       ];
//       return Dialog(
//         backgroundColor: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         child: Container(
//           width: 700,
//           padding: EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(20),
//             color: Colors.white,
//           ),
//           child: StatefulBuilder(
//             builder: (BuildContext context, StateSetter setState) {
//               return Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Title
//                   Text(
//                     'Advance Payment',
//                     style: TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   SizedBox(height: 10),

//                   // Total Advance Amount Display
//                   Text(
//                     'Total Advance Amount: ₹${totalAmount.fold(0.0, (sum, item) => sum + item)}',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.blueAccent,
//                     ),
//                   ),
//                   Divider(),

//                   // Payment Method Selection
//                   Text(
//                     'Select Payment Method',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 8),

//                   DropdownButtonFormField<String>(
//                     value: selectedPaymentsMethod,
//                     decoration: InputDecoration(
//                       labelText: 'Payment Method',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey.shade100,
//                     ),
//                     items: <String>['Cash', 'Card', 'UPI', 'Cheque', 'Others']
//                         .map<DropdownMenuItem<String>>((String value) {
//                       return DropdownMenuItem<String>(
//                         value: value,
//                         child: Row(
//                           children: [
//                             Icon(
//                               value == 'Cash'
//                                   ? Icons.money
//                                   : value == 'Card'
//                                       ? Icons.credit_card
//                                       : value == 'UPI'
//                                           ? Icons.phone_android
//                                           : value == 'Cheque'
//                                               ? Icons.account_balance_wallet
//                                               : Icons.more_horiz,
//                               color: Colors.blueAccent,
//                             ),
//                             const SizedBox(width: 10),
//                             Text(value),
//                           ],
//                         ),
//                       );
//                     }).toList(),
//                     onChanged: (String? newValue) {
//                       if (newValue != null) {
//                         setState(() {
//                           selectedPaymentsMethod = newValue;
//                         });
//                       }
//                     },
//                   ),
//                   SizedBox(height: 10),

//                   // Cheque Details Input (Visible only if 'Cheque' is selected)
//                   if (selectedPaymentsMethod == 'Cheque') buildChequeDetails(),

//                   // Advance Amount Input
//                   if (selectedPaymentsMethod != 'Cheque')
//                     TextField(
//                       controller: advanceController,
//                       focusNode: advanceAmountFocus,
//                       readOnly: true, // prevents default keyboard
//                       keyboardType: TextInputType.number,
//                       decoration: InputDecoration(
//                         labelText: 'Enter Advance Amount',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       onTap: () {
//                         ActiveField.activate(
//                           ctrl: advanceController,
//                           node: advanceAmountFocus,
//                           numeric: true,
//                         );
//                       },
//                       onChanged: (value) {
//                         final entered = double.tryParse(value) ?? 0.0;

//                         if (entered > total) {
//                           // clear invalid value
//                           advanceController.clear();

//                           // show error popup
//                           Future.delayed(Duration.zero, () {
//                             showDialog(
//                               context: context,
//                               builder: (BuildContext context) {
//                                 return AlertDialog(
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(16),
//                                   ),
//                                   title: Row(
//                                     children: const [
//                                       Icon(Icons.warning, color: Colors.red),
//                                       SizedBox(width: 8),
//                                       Text("Invalid Advance Amount"),
//                                     ],
//                                   ),
//                                   content: Text(
//                                     "Advance amount (₹$entered) cannot exceed total order amount (₹$total).",
//                                     style: const TextStyle(fontSize: 16),
//                                   ),
//                                   actions: [
//                                     TextButton(
//                                       child: const Text("OK",
//                                           style: TextStyle(
//                                               color: Colors.blueAccent)),
//                                       onPressed: () {
//                                         Navigator.of(context).pop();
//                                       },
//                                     ),
//                                   ],
//                                 );
//                               },
//                             );
//                           });
//                         } else {}
//                       },
//                     ),
//                   SizedBox(height: 20),
//                   Center(
//                     child: FractionallySizedBox(
//                       widthFactor:
//                           0.85, // 85% width for better balance on all screens
//                       child: SizedBox(
//                         height:
//                             180, // Slightly increased height for better key spacing
//                         child: ValueListenableBuilder<TextEditingController?>(
//                           valueListenable: ActiveField.controller,
//                           builder: (context, ctrl, _) {
//                             return Column(
//                               children: [
//                                 const SizedBox(height: 8),
//                                 Expanded(
//                                     child: CustomKeyboardWidgetAll2(
//                                         controller:
//                                             ctrl ?? TextEditingController())),
//                               ],
//                             );
//                           },
//                         ),
//                       ),
//                     ),
//                   ),
//                   // Submit Button
//                   Align(
//                     alignment: Alignment.center,
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         ElevatedButton(
//                           onPressed: () async {
//                             double advanceAmount =
//                                 double.tryParse(advanceController.text) ?? 0.0;

//                             if (advanceAmount > total) {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: Text(
//                                     'Advance amount cannot exceed the total amount!',
//                                     style: TextStyle(color: Colors.red),
//                                   ),
//                                 ),
//                               );
//                               return;
//                             }

//                             if (advanceAmount > 0) {
//                               setState(() {
//                                 totalAmount.add(advanceAmount);
//                               });
//                               String currentDateTime =
//                                   DateTime.now().toIso8601String();
//                               salesOrder.advanceDateTime ??= [];
//                               salesOrder.advancePaymentType ??= [];

//                               // add values
//                               salesOrder.advanceDateTime.add(currentDateTime);
//                               salesOrder.advancePaymentType
//                                   .add(selectedPaymentsMethod);

//                               Map<String, dynamic> requestBody = {
//                                 "advanceAmount": totalAmount,
//                                 "advanceDateTime": salesOrder.advanceDateTime,
//                                 "advancePaymentType":
//                                     salesOrder.advancePaymentType,
//                               };

//                               try {
//                                 String jsonadvanceSalesOrder = jsonEncode({
//                                   "data": requestBody,
//                                   "saleOrderNo": salesOrder.saleOrderNo,
//                                   "type": "patchSaleOrder",
//                                   "sync": "No",
//                                   "edit": "No",
//                                 });

//                                 await sendInvoiceDataToServer(
//                                     jsonDecode(jsonadvanceSalesOrder));

//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(
//                                     content: Text(
//                                       'Advance payment details submitted successfully!',
//                                       style: TextStyle(color: Colors.white),
//                                     ),
//                                     backgroundColor: Colors.green,
//                                     duration: Duration(seconds: 2),
//                                   ),
//                                 );
//                                 Navigator.pop(context);
//                               } catch (e) {
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(content: Text('Error: $e')),
//                                 );
//                               }
//                             } else {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: Text(
//                                       'Please enter a valid advance amount'),
//                                 ),
//                               );
//                             }
//                           },
//                           style: ElevatedButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(8.0),
//                             ),
//                             backgroundColor: Colors.blueAccent,
//                             foregroundColor: Colors.white,
//                             elevation: 2,
//                           ),
//                           child: Text(
//                             'Submit',
//                             style: TextStyle(fontSize: 16, color: Colors.white),
//                           ),
//                         ),
//                         SizedBox(width: 16),
//                         ElevatedButton(
//                           onPressed: () {
//                             // Clear the controller and optionally any state
//                             advanceController.clear();
//                             Navigator.pop(context);
//                           },
//                           style: ElevatedButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(8.0),
//                             ),
//                             backgroundColor: Colors.red,
//                             foregroundColor: Colors.white,
//                             elevation: 2,
//                           ),
//                           child: Text(
//                             'Cancel',
//                             style: TextStyle(fontSize: 16, color: Colors.white),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               );
//             },
//           ),
//         ),
//       );
//     },
//   );
// }

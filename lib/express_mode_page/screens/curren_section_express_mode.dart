import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/custom_button_reuse.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/Global/Widget/custom_sized_box.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';

import '../../invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
// import '../../printer_screen/provider/printer_config_provider.dart';
import '../../regular_mode_page/provider/cart_page_provider.dart';
import '../../regular_mode_page/widget/viewBillScreen.dart';

class CurrentSaleSectionExpressMode extends StatelessWidget {
  const CurrentSaleSectionExpressMode({super.key});

  // void viewBills(BuildContext context) async {

  //   // Open the Hive box
  //   var box = await Hive.openBox('holdinvoiceBox');

  //   if (box.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: const Text(
  //           'No saved bills!',
  //           style: TextStyle(fontWeight: FontWeight.bold),
  //         ),
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 2),
  //         behavior: SnackBarBehavior.floating,
  //         margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //       ),
  //     );
  //     return;
  //   }

  //   // Filter bills with status "hold"
  //   List<Map<String, dynamic>> holdBills = box.values
  //       .where((bill) =>
  //           (bill as Map)['status'] == 'hold' && (bill)['items'].isNotEmpty)
  //       .map((bill) => Map<String, dynamic>.from(bill as Map))
  //       .toList();

  //   developer.log('Hold Bills: ${holdBills.toString()}', name: 'viewBills');

  //   if (holdBills.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: const Text(
  //           'No hold bills with items found!',
  //           style: TextStyle(fontWeight: FontWeight.bold),
  //         ),
  //         backgroundColor: Colors.orange,
  //         duration: const Duration(seconds: 2),
  //         behavior: SnackBarBehavior.floating,
  //         margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //       ),
  //     );
  //     return;
  //   }

  //   // Display the filtered hold bills in a dialog
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Saved Bills'),
  //         content: SizedBox(
  //           width: 400,
  //           height: 300,
  //           child: ListView.builder(
  //             itemCount: holdBills.length,
  //             itemBuilder: (context, index) {
  //               final bill = holdBills[index];
  //               String holdBillId = bill['holdId']; // Get the hold bill ID

  //               // Parse the date from the 'date' field and format it
  //               DateTime billDate = DateTime.parse(bill['date']);
  //               String formattedDate = DateFormat('dd-MM-yy').format(billDate);
  //               String formattedTime = DateFormat('hh:mm').format(billDate);

  //               return ListTile(
  //                 title: Text('${index + 1} - Total: ₹${bill['total']}'),
  //                 subtitle: Text('Date: $formattedDate - Time: $formattedTime'),
  //                 onTap: () async {
  //                   var saleProvider = Provider.of<CurrentSaleProvider>(context,
  //                       listen: false);

  //                   // Properly cast the list of items to List<Map<String, dynamic>>
  //                   List<Map<String, dynamic>> items =
  //                       (bill['items'] as List<dynamic>)
  //                           .map((item) => Map<String, dynamic>.from(item))
  //                           .toList();

  //                   if (items.isNotEmpty) {
  //                     saleProvider.loadItemsFromBill(items);

  //                     // // Update the bill status to 'active' in Hive
  //                     // bill['status'] = 'active'; // Change status to active
  //                     // await box.putAt(
  //                     //     index, bill); // Save the updated bill back

  //                     // Pop the dialog
  //                     Navigator.of(context).pop();
  //                   } else {
  //                     // Show a message if the selected bill has no items
  //                     ScaffoldMessenger.of(context).showSnackBar(
  //                       SnackBar(
  //                         content: const Text(
  //                           'This bill has no items!',
  //                           style: TextStyle(fontWeight: FontWeight.bold),
  //                         ),
  //                         backgroundColor: Colors.red,
  //                         duration: const Duration(seconds: 2),
  //                         behavior: SnackBarBehavior.floating,
  //                         margin: const EdgeInsets.only(
  //                             left: 20, bottom: 20, right: 20),
  //                         shape: RoundedRectangleBorder(
  //                           borderRadius: BorderRadius.circular(10),
  //                         ),
  //                       ),
  //                     );
  //                   }
  //                 },
  //               );
  //             },
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //             child: const Text('Close'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrentSaleProvider>(
      builder: (context, saleProvider, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
                            child: CustomButton(
                              text: 'TakeAway',
                              onPressed: () {
                                saleProvider.selectOption('TakeAway');
                              },
                              backgroundColor:
                                  saleProvider.selectedOption == 'TakeAway' ? CustomColors.blueColor : CustomColors.white70Color,
                              textColor:
                                  saleProvider.selectedOption == 'TakeAway' ? CustomColors.whiteColor : CustomColors.blueColor,
                            ),
                          ),
                          const CustomSizedBox(
                            width: 10,
                          ),
                          Center(
                            child: CustomButton(
                              text: 'Online',
                              onPressed: () {
                               
                                saleProvider.selectOption('Online');
                              },
                              backgroundColor:
                                  saleProvider.selectedOption == 'Online' ? CustomColors.blueColor : CustomColors.white70Color,
                              textColor:
                                  saleProvider.selectedOption == 'Online' ? CustomColors.whiteColor : CustomColors.blueColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: CustomColors.whiteColor,
                    onSelected: (value) {
                      if (value == 'clear') {
                        saleProvider.clearItems();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        const PopupMenuItem<String>(
                          value: 'clear',
                          child: Text('Clear Items'),
                        ),
                      ];
                    },
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
            ),
            Expanded(
              child: saleProvider.saleStatus != 'hold' && saleProvider.currentSaleItems.isNotEmpty
                  ? ListView.builder(
                      itemCount: saleProvider.currentSaleItems.length,
                      itemBuilder: (context, index) {
                        final item = saleProvider.currentSaleItems[index];
                        return Dismissible(
                          key: Key(item['itemData']['itemName'] + item['varianceData']['varianceName']),
                          direction: DismissDirection.startToEnd,
                          onDismissed: (direction) {
                            saleProvider.removeItem(index);
                          },
                          background: Container(
                            color: CustomColors.redColor,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete, color: CustomColors.whiteColor),
                          ),
                          child: ListTile(
                            // onTap: () {
                            //   // Check if the item and its 'varianceData' key exist
                            //   if (item.containsKey('varianceData') &&
                            //       item['varianceData'] != null &&
                            //       item['varianceData']['variance_Uom'] !=
                            //           null) {
                            //     // Check if the `variance_Uom` is "kg" or "kgs"
                            //     if (item['varianceData']['variance_Uom'] ==
                            //         'Kgs') {
                            //       // Show the weight dialog
                            //       showDialog(
                            //         context: context,
                            //         builder: (context) {
                            //           return AlertDialog(
                            //             shape: const RoundedRectangleBorder(
                            //                 borderRadius: BorderRadius.zero),
                            //             backgroundColor: Colors.white,
                            //             title: Text(
                            //               'Edit ${item['varianceData']['varianceName']}',
                            //               style: const TextStyle(
                            //                   fontSize: 18.0,
                            //                   fontWeight: FontWeight.bold),
                            //             ),
                            //             content: Consumer<BluetoothProvider2>(
                            //               builder: (context, bluetoothProvider2,
                            //                   child) {
                            //                 double weight =
                            //                     bluetoothProvider2.weight;

                            //                 return Column(
                            //                   mainAxisSize: MainAxisSize.min,
                            //                   children: [
                            //                     Text(
                            //                       "Weight: ${weight.toStringAsFixed(2)} kg",
                            //                       style: const TextStyle(
                            //                           fontSize: 24),
                            //                     ),
                            //                   ],
                            //                 );
                            //               },
                            //             ),
                            //             actions: [
                            //               TextButton(
                            //                 onPressed: () {
                            //                   Navigator.of(context).pop();
                            //                 },
                            //                 child: const Text('Cancel'),
                            //               ),
                            //               TextButton(
                            //                 onPressed: () {
                            //                   // Get the current weight from the BluetoothProvider2
                            //                   double weight = Provider.of<
                            //                               BluetoothProvider2>(
                            //                           context,
                            //                           listen: false)
                            //                       .weight;

                            //                   // Update the saleProvider with the current weight value
                            //                   saleProvider.updateItemQuantity(
                            //                       index, weight);

                            //                   Navigator.of(context).pop();
                            //                 },
                            //                 style: ButtonStyle(
                            //                   shape: WidgetStateProperty.all(
                            //                       RoundedRectangleBorder(
                            //                           borderRadius:
                            //                               BorderRadius.zero)),
                            //                   backgroundColor:
                            //                       WidgetStateProperty.all(
                            //                           Colors.blue),
                            //                 ),
                            //                 child: const Text(
                            //                   'Update',
                            //                   style: TextStyle(
                            //                       color: Colors.white),
                            //                 ),
                            //               ),
                            //             ],
                            //           );
                            //         },
                            //       );
                            //     } else {
                            //       print(
                            //           "Skipping weight dialog because variance_Uom is not 'kg' or 'kgs'");
                            //     }
                            //   } else {
                            //     print(
                            //         "Item or varianceData is null, skipping weight dialog.");
                            //   }
                            // },
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomText(
                                      text: '${item['varianceData']['varianceName']}',
                                      style: const TextStyle(color: CustomColors.blueColor, fontWeight: FontWeight.bold),
                                    ),
                                    CustomText(text: saleProvider.buildQuantityPriceDisplay(item)),
                                  ],
                                ),
                                CustomText(
                                  text: '₹ ${saleProvider.calculateItemTotal(item).toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Container(),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.start,
                  //   children: [
                  //     const CustomText(text: 'Discount'),
                  //     const Spacer(), // This will take all available horizontal space
                  //     Container(
                  //       width: 50, // Adjust the width as needed
                  //       height: 40, // Adjust the height as needed
                  //       child: TextField(
                  //         onChanged: (value) {
                  //           // Update discount percentage
                  //           saleProvider.discountPercentage =
                  //               double.tryParse(value) ?? 0.0;
                  //         },
                  //         decoration: const InputDecoration(
                  //           border: OutlineInputBorder(),
                  //           contentPadding: EdgeInsets.symmetric(
                  //               vertical: 8,
                  //               horizontal:
                  //                   10), // Adjust padding inside the text field
                  //           isDense:
                  //               true, // Reduces extra space inside the text field to make it more compact
                  //         ),
                  //         textAlign: TextAlign
                  //             .right, // Aligns the input text to the right

                  //         keyboardType: TextInputType
                  //             .number, // Ensures that only numbers can be inputted
                  //       ),
                  //     ),
                  //     const CustomText(text: '%'),
                  //   ],
                  // ),
                  const CustomSizedBox(height: 16),
                  Center(
                    child: CustomButton(
                      text: 'Charge ₹ ${saleProvider.calculateTotal().toStringAsFixed(0)}',
                      onPressed: () {
                        double totalAmount = saleProvider.calculateTotal();
                        if (totalAmount != 0) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return Dialog(
                                child: CustomSizedBox(
                                  width: MediaQuery.of(context).size.width * 0.5,
                                  child: SalesInvoicePayAndPrint(
                                    totalAmount: totalAmount,
                                    holdBillId: saleProvider.holdBillId ?? '', // Fallback to empty string if null
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                      backgroundColor: CustomColors.primaryColor,
                      textColor: CustomColors.whiteColor,
                      padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 22),
                    ),
                  ),
                  const CustomSizedBox(height: 10),

                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     const ViewSavedBillsWidget(),
                  //     const CustomSizedBox(width: 5),
                  //     Center(
                  //       child: CustomButton(
                  //         text: 'Save Bill',
                  //         onPressed: () {
                  //           Provider.of<CurrentSaleProvider>(context,
                  //                   listen: false)
                  //               .saveBill(context);
                  //         },
                  //         backgroundColor: CustomColors.white70Color,
                  //         textColor: CustomColors.blueColor,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'ViewBills',
                          onPressed: () {
                            ViewSavedBillsWidget().viewBills(context);
                          },
                          backgroundColor: CustomColors.white70Color,
                          textColor: CustomColors.blueColor,
                        ),
                      ),
                      const CustomSizedBox(width: 2),
                      Center(
                        child: CustomButton(
                          text: 'SaveBill',
                          onPressed: () {
                            Provider.of<CurrentSaleProvider>(context, listen: false).saveBill(context);
                          },
                          backgroundColor: CustomColors.white70Color,
                          textColor: CustomColors.blueColor,
                        ),
                      ),
                      const CustomSizedBox(width: 2),
                      // Center(
                      //   child: CustomButton(
                      //     text: 'PreInvo',
                      //     onPressed: () async {
                      //       final saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
                      //       final currentItems = saleProvider.currentSaleItems;

                      //       if (currentItems.isNotEmpty) {
                      //         // Log the current items to the console
                      //         for (var item in currentItems) {
                      //           // Print each item in the cart
                      //         }
                      //         // final printerProvider =
                      //         //     Provider.of<PrinterProvider>(context,
                      //         //         listen: false);

                      //         // String printerIp = printerProvider
                      //         //     .getOverallPrinterIp()
                      //         //     .toString();
                      //         // Prepare the items for printing
                      //         // await SIPreInvoicePrinter.printReceipt(
                      //         //   ipAddress:
                      //         //       printerIp, // Replace with the actual printer IP
                      //         //   invoiceDataList:
                      //         //       currentItems, // Pass current cart items
                      //         //   receiptType: "Pre-Invoice",
                      //         // );

                      //         saleProvider.clearItems();
                      //       } else {}
                      //     },
                      //     backgroundColor: CustomColors.white70Color,
                      //     textColor: CustomColors.blueColor,
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

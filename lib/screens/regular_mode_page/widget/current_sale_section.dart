import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../Global/custom_button_reuse.dart';
import '../../../Global/custom_colors.dart';
import '../../../Global/custom_sized_box.dart';
import '../../../Global/custom_textWidgets.dart';
import '../../invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
import '../../more_page/providers/bt_provide2.dart';
import '../../printer_screen/provider/printer_config_provider.dart';
import '../provider/cart_page_provider.dart';
import '../split_bill_screen.dart';
import 'viewBillScreen.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';

class CurrentSaleSection extends StatelessWidget {
  const CurrentSaleSection({super.key});

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
                                  saleProvider.selectedOption == 'TakeAway'
                                      ? CustomColors.blueColor
                                      : CustomColors.white70Color,
                              textColor:
                                  saleProvider.selectedOption == 'TakeAway'
                                      ? CustomColors.whiteColor
                                      : CustomColors.blueColor,
                            ),
                          ),
                          const CustomSizedBox(
                            width: 10,
                          ),
                          Center(
                            child: CustomButton(
                              text: 'Online',
                              onPressed: () {
                                // final itemProvider = Provider.of<ItemProvider>(
                                //     context,
                                //     listen: false);
                                // final result =
                                //     itemProvider.checkVarianceItemCode("FG011");
                                // print("Result:");
                                // print(result);
                                // Navigator.push(
                                //   context,
                                //   MaterialPageRoute(
                                //       builder: (context) =>
                                //           const ViewInvoiceBoxScreen()),
                                // );
                                saleProvider.selectOption('Online');
                              },
                              backgroundColor:
                                  saleProvider.selectedOption == 'Online'
                                      ? CustomColors.blueColor
                                      : CustomColors.white70Color,
                              textColor: saleProvider.selectedOption == 'Online'
                                  ? CustomColors.whiteColor
                                  : CustomColors.blueColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: CustomColors
                        .whiteColor, // Assuming CustomColors.whiteColor is defined in your theme
                    onSelected: (value) {
                      final salesProvider = Provider.of<CurrentSaleProvider>(
                          context,
                          listen: false);
                      if (value == 'Split') {
                        // ignore: unnecessary_null_comparison
                        if (salesProvider.currentSaleItems == null ||
                            salesProvider.currentSaleItems.isEmpty ||
                            salesProvider.currentSaleItems.length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No items to split! Maximum 2 or more items required',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.only(
                                  left: 20, bottom: 20, right: 680),
                            ),
                          );
                          return;
                        }

                        // ✅ Print `currentSaleItems` in console before opening dialog
                        for (var item in salesProvider.currentSaleItems) {}
                        showDialog(
                          context: context,
                          builder: (context) => SplitBillDialog(
                            initialItems: salesProvider
                                .currentSaleItems, // Send original items
                          ),
                        );
                      }
                      if (value == 'Merge') {
                        // ignore: unnecessary_null_comparison
                        if (salesProvider.currentSaleItems == null ||
                            salesProvider.currentSaleItems.isEmpty ||
                            salesProvider.currentSaleItems.length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No items to Merge! Maximum 2 or more items required',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.only(
                                  left: 20, bottom: 20, right: 680),
                            ),
                          );
                          return;
                        }
                        _promptForMergeTitle(context, salesProvider);
                      }
                      if (value == 'Clear') {
                        salesProvider.clearItems();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return {'Split', 'Merge', 'Clear'}.map((String choice) {
                        return PopupMenuItem<String>(
                          value: choice,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                choice == 'Split'
                                    ? Icons.call_split
                                    : choice == 'Merge'
                                        ? Icons.merge_type
                                        : Icons.clear_all,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              SizedBox(width: 8),
                              Text(
                                choice,
                                style: TextStyle(
                                    fontSize: 16), // Increased font size
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  )
                ],
              ),
            ),
            Expanded(
              child: saleProvider.saleStatus != 'hold' &&
                      saleProvider.currentSaleItems.isNotEmpty
                  ? ListView.builder(
                      itemCount: saleProvider.currentSaleItems.length,
                      itemBuilder: (context, index) {
                        final item = saleProvider.currentSaleItems[index];
                        return SwipeActionCell(
                          backgroundColor: Colors.white,
                          trailingActions: [
                            SwipeAction(
                              performsFirstActionWithFullSwipe: true,
                              onTap: (CompletionHandler handler) async {
                                // Delete the item from the current sale
                                saleProvider.removeItem(index);
                                // handler(true);
                              },
                              color: Colors.red,
                              content: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                          ],
                          key: Key('${saleProvider.currentSaleItems[index]}'),
                          child: ListTile(
                            onTap: () {
                              // Check if the item and its 'varianceData' key exist
                              if (item.containsKey('varianceData') &&
                                  item['varianceData'] != null &&
                                  item['varianceData']['variance_Uom'] !=
                                      null) {
                                String? uom =
                                    item['varianceData']['variance_Uom'];
                                // Check if the `variance_Uom` is "kg" or "kgs"
                                if (item['varianceData']['variance_Uom'] ==
                                    'Kgs') {
                                  // Show the weight dialog
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.zero),
                                        backgroundColor: Colors.white,
                                        title: Text(
                                          'Edit ${item['varianceData']['varianceName']}',
                                          style: const TextStyle(
                                              fontSize: 18.0,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        content: Consumer<BluetoothProvider2>(
                                          builder: (context, bluetoothProvider2,
                                              child) {
                                            double weight =
                                                bluetoothProvider2.weight;

                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "Weight: ${weight.toStringAsFixed(2)} kg",
                                                  style: const TextStyle(
                                                      fontSize: 24),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              // Get the current weight from the BluetoothProvider2
                                              double weight = Provider.of<
                                                          BluetoothProvider2>(
                                                      context,
                                                      listen: false)
                                                  .weight;

                                              // Update the saleProvider with the current weight value
                                              saleProvider.updateItemQuantity(
                                                  index, weight);

                                              Navigator.of(context).pop();
                                            },
                                            style: ButtonStyle(
                                              shape: WidgetStateProperty.all(
                                                  RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.zero)),
                                              backgroundColor:
                                                  WidgetStateProperty.all(
                                                      Colors.blue),
                                            ),
                                            child: const Text(
                                              'Update',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else if (uom == 'Pcs' || uom == 'Pkt') {
                                  // Show the quantity dialog for "Pcs" or "Pkt"
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      // Fallback value for current quantity
                                      int currentQty = int.tryParse(
                                              item['quantity']?.toString() ??
                                                  item['varianceData']
                                                          ['quantity']
                                                      ?.toString() ??
                                                  '0') ??
                                          0;

                                      // Controller for text input
                                      TextEditingController qtyController =
                                          TextEditingController(
                                              text: currentQty.toString());

                                      return StatefulBuilder(
                                        builder: (context, setState) {
                                          return AlertDialog(
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(
                                                      12.0)), // Slight rounding
                                            ),
                                            backgroundColor: Colors.white,
                                            title: Text(
                                              'Edit ${item['varianceData']['varianceName']}',
                                              style: const TextStyle(
                                                fontSize: 18.0,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  "Quantity",
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                const SizedBox(height: 15),

                                                // Quantity Counter with Plus and Minus buttons
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.remove,
                                                          size: 28,
                                                          color: Colors.black),
                                                      onPressed: () {
                                                        if (currentQty > 1) {
                                                          setState(() {
                                                            currentQty--; // Decrement quantity
                                                            qtyController.text =
                                                                currentQty
                                                                    .toString();
                                                          });
                                                        }
                                                      },
                                                    ),
                                                    SizedBox(
                                                      width: 100,
                                                      child: TextField(
                                                        controller:
                                                            qtyController,
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                            fontSize: 18),
                                                        decoration:
                                                            InputDecoration(
                                                          contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 8),
                                                          border:
                                                              OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8.0),
                                                            borderSide:
                                                                const BorderSide(
                                                                    color: Colors
                                                                        .grey),
                                                          ),
                                                        ),
                                                        onChanged: (value) {
                                                          int updatedQty =
                                                              int.tryParse(
                                                                      value) ??
                                                                  1;
                                                          setState(() {
                                                            currentQty =
                                                                updatedQty; // Update quantity
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.add,
                                                          size: 28,
                                                          color: Colors.black),
                                                      onPressed: () {
                                                        setState(() {
                                                          currentQty++; // Increment quantity
                                                          qtyController.text =
                                                              currentQty
                                                                  .toString();
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .pop(); // Close dialog without changes
                                                },
                                                child: const Text('Cancel',
                                                    style: TextStyle(
                                                        color: Colors.grey)),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  int updatedQty = int.tryParse(
                                                          qtyController.text) ??
                                                      0;

                                                  // Update quantity in provider
                                                  saleProvider
                                                      .updateItemQuantity(
                                                          index, updatedQty);

                                                  Navigator.of(context)
                                                      .pop(); // Close dialog after update
                                                },
                                                style: ButtonStyle(
                                                  shape: WidgetStateProperty.all(
                                                      RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0))),
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                          Colors.blue),
                                                ),
                                                child: const Text(
                                                  'Update',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                }
                              } else {}
                            },
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomText(
                                      text:
                                          '${item['varianceData']['varianceName']}',
                                      style: const TextStyle(
                                          color: CustomColors.blueColor,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    CustomText(
                                        text: saleProvider
                                            .buildQuantityPriceDisplay(item)),
                                  ],
                                ),
                                CustomText(
                                  text:
                                      '₹ ${saleProvider.calculateItemTotal(item).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
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
                      text:
                          'Charge ₹ ${saleProvider.calculateTotal().toStringAsFixed(0)}',
                      onPressed: () {
                        double totalAmount = saleProvider.calculateTotal();
                        if (totalAmount != 0) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return Dialog(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: CustomSizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.5,
                                    child: SalesInvoicePayAndPrint(
                                      totalAmount: totalAmount,
                                      holdBillId: saleProvider.holdBillId ??
                                          '', // Fallback to empty string if null
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                      backgroundColor: CustomColors.primaryColor,
                      textColor: CustomColors.whiteColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 100, vertical: 22),
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
                      ViewSavedBillsWidget(),
                      const CustomSizedBox(width: 2),
                      // ... Inside the CurrentSaleSection's build method ...

                      Center(
                        child: CustomButton(
                          text: 'SaveBill',
                          onPressed: () {
                            // Check if current sale items are empty
                            if (saleProvider.currentSaleItems.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No items to save!',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.only(
                                      left: 20, bottom: 20, right: 680),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                              return;
                            }
                            promptForSaveBillsTitle(context, saleProvider);
                          },
                          backgroundColor: CustomColors.white70Color,
                          textColor: CustomColors.blueColor,
                        ),
                      ),
                      const CustomSizedBox(width: 2),
                      Center(
                        child: CustomButton(
                          text: 'PreInvo',
                          onPressed: () async {
                            final saleProvider =
                                Provider.of<CurrentSaleProvider>(context,
                                    listen: false);
                            final currentItems = saleProvider.currentSaleItems;

                            if (currentItems.isNotEmpty) {
                              // Log the current items to the console
                              for (var item in currentItems) {
                                // Print each item in the cart
                              }
                              final printerProvider =
                                  Provider.of<PrinterProviderpos>(context,
                                      listen: false);

                              // ignore: unused_local_variable
                              String printerIp = printerProvider
                                  .getOverallPrinterIp()
                                  .toString();
                              // Prepare the items for printing
                              // await SIPreInvoicePrinter.printReceipt(
                              //   ipAddress:
                              //       printerIp, // Replace with the actual printer IP
                              //   invoiceDataList:
                              //       currentItems, // Pass current cart items
                              //   receiptType: "Pre-Invoice",
                              // );

                              saleProvider.clearItems();
                            } else {}
                          },
                          backgroundColor: CustomColors.white70Color,
                          textColor: CustomColors.blueColor,
                        ),
                      ),
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

  Widget _buildHeader(String title) {
    return Expanded(
      child: Text(
        title,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _viewBills(BuildContext context) async {
    var box = await Hive.openBox('cartBox');

    List<Map<String, dynamic>> holdBills = box.values
        .where((bill) => bill is Map && bill['status'] == 'hold')
        .map((bill) => Map<String, dynamic>.from(bill as Map))
        .toList();

    if (holdBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved bills available!'),
          backgroundColor: Colors.red,
          margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        Set<int> selectedBills = {}; // Store selected bill indices
        List<String> selectedTicketNumbers = []; // Store selected ticket names

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Merge With..",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: selectedBills.isNotEmpty
                      ? () async {
                          // Merge selected bills
                          await _mergeSelectedBills(
                            context,
                            selectedBills.toList(),
                            box,
                            selectedTicketNumbers,
                          );
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: Text(
                    "CONTINUE",
                    style: TextStyle(
                      color:
                          selectedBills.isNotEmpty ? Colors.blue : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  color: Colors.blue,
                  child: Row(
                    children: [
                      SizedBox(width: 40),
                      _buildHeader("NAME"),
                      _buildHeader("AMOUNT"),
                      _buildHeader("TIME"),
                      _buildHeader("EMPLOYEE"),
                    ],
                  ),
                ),
                SizedBox(
                  width: 400,
                  height: 300,
                  child: ListView.builder(
                    itemCount: holdBills.length,
                    itemBuilder: (context, index) {
                      final bill = holdBills[index];
                      DateTime date = DateTime.parse(bill['date']);
                      String formattedDate =
                          DateFormat('dd-MM-yyyy hh:mm a').format(date);
                      double amount = bill['total'] ?? 0.0;

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Colors.grey[800]!)),
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: selectedBills.contains(index),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedBills.add(index);
                                  // Collect selected ticket numbers
                                  final selectedBill = holdBills[index];
                                  String ticketNumber =
                                      selectedBill['ticketName'] ?? "Unknown";
                                  selectedTicketNumbers.add(ticketNumber);
                                } else {
                                  selectedBills.remove(index);
                                  final selectedBill = holdBills[index];
                                  String ticketNumber =
                                      selectedBill['ticketName'] ?? "Unknown";
                                  selectedTicketNumbers.remove(ticketNumber);
                                }
                              });
                            },
                            activeColor: Colors.blue,
                          ),
                          title: Text(
                            bill['ticketName'],
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                          subtitle: Text(
                            formattedDate,
                            style: TextStyle(color: Colors.black, fontSize: 14),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "₹${amount.toStringAsFixed(2)}",
                                style: TextStyle(
                                    color: Colors.black, fontSize: 16),
                              ),
                              SizedBox(width: 10),
                              IconButton(
                                icon:
                                    Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  await box.deleteAt(index);
                                  setState(() {
                                    holdBills.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  /// Function to merge selected bills and save them to Hive
  Future<void> _mergeSelectedBills(
      BuildContext context,
      List<int> selectedBillIndices,
      Box box,
      List<String> selectedTicketNumbers) async {
    if (selectedBillIndices.isEmpty) {
      // Step 1
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No bills selected to merge!'),
          backgroundColor: Colors.red,
          margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Step 2: Initialize mergedBill map
    Map<String, dynamic> mergedBill = {
      'holdId':
          DateTime.now().millisecondsSinceEpoch.toString(), // Unique hold ID
      'items': [],
      'total': 0.0,
      'date': DateTime.now().toIso8601String(),
      'status': 'hold',
      'ticketName': selectedTicketNumbers.join(" + "), // Merged ticket name
    };

    double totalAmount = 0.0;

    // Step 3: Aggregate selected bills
    for (int index in selectedBillIndices) {
      Map<String, dynamic> bill = box.getAt(index);
      totalAmount += double.parse(bill['total'].toString());
      mergedBill['items'].addAll(bill['items']);
    }
    mergedBill['total'] = totalAmount;

    // Step 4: Save merged bill to Hive
    await box.add(mergedBill);

    // Step 5: Prepare data for API posting
    // ignore: unused_local_variable
    Map<String, dynamic> apiData = {
      'holdId': mergedBill['holdId'],
      'date': mergedBill['date'],
      'items': mergedBill['items'].map((item) {
        return {
          'itemCode': item['itemCode'],
          'itemName': item['itemName'],
          'qty': item['qty'],
          'price': item['price'],
          'category': item['category'],
        };
      }).toList(),
      'total': mergedBill['total'].toString(),
      'status': 'hold',
      'ticketName': mergedBill['ticketName'],
    };

    // Step 6: Optionally clear selected data from Hive
    for (int index in selectedBillIndices) {
      await box.deleteAt(index); // Remove selected bills
    }

    // Optional API Post (Commented Out for now)
    // try {
    //   final response = await http.post(
    //     Uri.parse('https://yenerp.com/fastapi/holds/'),
    //     headers: {'Content-Type': 'application/json'},
    //     body: jsonEncode(apiData),
    //   );
    //   if (response.statusCode == 200 || response.statusCode == 201) {
    //     print('Merged bill saved and posted successfully!');
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //           content: Text('Merged bill saved and posted successfully!'),
    //           backgroundColor: Colors.green),
    //     );
    //   } else {
    //     print('Failed to post merged data to server');
    //   }
    // } catch (e) {
    //   print('Error posting data to server: $e');
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('Error posting data to server: $e'),
    //       backgroundColor: Colors.red,
    //       margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
    //       behavior: SnackBarBehavior.floating,
    //     ),
    //   );
    // }
  }

  void _promptForMergeTitle(
      BuildContext context, CurrentSaleProvider saleProvider) {
    String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    TextEditingController titleController =
        TextEditingController(text: "Ticket - $formattedTime");

    // Step 1

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Enter Ticket Title for Merge",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: TextField(
              controller: titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Enter merged ticket name",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Step 2
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                // Step 3
                String baseName = titleController.text.trim();
                if (baseName.isEmpty) return;

                List<List<Map<String, dynamic>>> tickets = [
                  saleProvider.currentSaleItems,
                ];

                List<String> ticketTitles = [baseName];

                // Save merged ticket
                await saleProvider.saveBillsplitBill(
                    context, tickets, ticketTitles);

                saleProvider.clearItems();

                Navigator.pop(context);
                _viewBills(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "OK",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void promptForSaveBillsTitle(
      BuildContext context, CurrentSaleProvider saleProvider) {
    String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    TextEditingController titleController =
        TextEditingController(text: "Ticket - $formattedTime");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Enter Ticket Title for Save Ticket",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: TextField(
              controller: titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Enter  ticket name",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                String baseName = titleController.text.trim();
                if (baseName.isEmpty) return;

                // Include the current sale items in the merge
                List<List<Map<String, dynamic>>> tickets = [
                  saleProvider
                      .currentSaleItems, // Include the current sale items
                ];

                // Get selected bills from the current context
                List<String> ticketTitles = [baseName]; // Use the entered title

                // Save the merged ticket
                await saleProvider.saveBillsplitBill(
                    context, tickets, ticketTitles);

                // Optionally clear the items after saving the ticket
                saleProvider.clearItems();

                // Close the dialog
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "OK",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Provider/current_datetime.dart';
import 'package:yenpos/Global/Widget/custom_button_reuse.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/Global/Widget/custom_sized_box.dart';
import 'package:yenpos/Global/Widget/custom_textWidgets.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';

import 'package:yenpos/Sale_order/Widgets/numeric_Calculator.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
import 'package:yenpos/more_page/widgets/other.dart';
import 'package:yenpos/regular_mode_page/widget/custom_reusable_widget/quantity_dialog.dart';
import 'package:yenpos/regular_mode_page/widget/custom_reusable_widget/ticket_generator.dart';
import 'package:yenpos/regular_mode_page/widget/emp_search.dart';
import 'package:yenpos/regular_mode_page/widget/search_drop_filed.dart';

import '../../more_page/providers/bt_provide2.dart';
import '../../printer_screen/provider/printer_config_provider.dart';
import '../provider/cart_page_provider.dart';
import '../split_bill_screen.dart';
import 'viewBillScreen.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';

class CurrentSaleSection extends StatelessWidget {
  CurrentSaleSection({super.key});

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
                              backgroundColor: saleProvider.selectedOption == 'TakeAway'
                                  ? CustomColors.blueColor
                                  : CustomColors.white70Color,
                              textColor: saleProvider.selectedOption == 'TakeAway'
                                  ? CustomColors.whiteColor
                                  : CustomColors.blueColor,
                            ),
                          ),
                          const CustomSizedBox(width: 10),
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
                              backgroundColor: saleProvider.selectedOption == 'Online'
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
                    color: CustomColors.whiteColor, // Assuming CustomColors.whiteColor is defined in your theme
                    onSelected: (value) {
                      final salesProvider = Provider.of<CurrentSaleProvider>(context, listen: false);
                      if (value == 'Split') {
                        // ignore: unnecessary_null_comparison
                        if (salesProvider.currentSaleItems == null ||
                            salesProvider.currentSaleItems.isEmpty ||
                            salesProvider.currentSaleItems.length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No items to split! Maximum 2 or more items required',
                                style: TextStyle(fontFamily: "Poppins",fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
                            ),
                          );
                          return;
                        }

                        // ✅ Print `currentSaleItems` in console before opening dialog
                        for (var item in salesProvider.currentSaleItems) {}
                        showDialog(
                          context: context,
                          builder: (context) => SplitBillDialog(
                            initialItems: salesProvider.currentSaleItems, // Send original items
                          ),
                        );
                      }
                      if (value == 'Merge') {
                        // ignore: unnecessary_null_comparison
                        // if (salesProvider.currentSaleItems == null ||
                        //     salesProvider.currentSaleItems.isEmpty ||
                        //     salesProvider.currentSaleItems.length < 1) {
                        //   ScaffoldMessenger.of(context).showSnackBar(
                        //     SnackBar(
                        //       content: Text(
                        //         'No items to Merge! Maximum 1 or more items required',
                        //         style: TextStyle(fontWeight: FontWeight.bold),
                        //       ),
                        //       backgroundColor: Colors.red,
                        //       duration: Duration(seconds: 2),
                        //       behavior: SnackBarBehavior.floating,
                        //       margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
                        //     ),
                        //   );
                        //   return;
                        // }
                        // _viewBills(context);
                        ViewSavedBillsWidget().viewBills(context);
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
                                style: TextStyle(fontFamily: "Poppins",fontSize: 16), // Increased font size
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(children: [Expanded(child: EmployeeSearch())]),
            ),

            Expanded(
              child: saleProvider.saleStatus != 'hold' && saleProvider.currentSaleItems.isNotEmpty
                  ? ListView.builder(
                      itemCount: saleProvider.currentSaleItems.length,
                      itemBuilder: (context, index) {
                        final item = saleProvider.currentSaleItems[index];
                        print('DEBUG: CurrentSaleSection - Item $index: $item');
                        print('DEBUG: CurrentSaleSection - Display: ${saleProvider.buildQuantityPriceDisplay(item)}');

                        // Fetch system stock for the item
                        double systemStock = 0.0;
                        final branchwiseItems = GlobalDataManager().branchwiseItems['data'] as Map<dynamic, dynamic>?;
                        final itemName = item['itemName']?.toString() ?? 'Unknown Item';
                        final varianceName = item['varianceData']['varianceName']?.toString() ?? '';
                        if (branchwiseItems != null && itemName != 'Unknown Item' && branchwiseItems.containsKey(itemName)) {
                          final itemData = branchwiseItems[itemName] as Map<dynamic, dynamic>?;
                          final varianceMap = itemData?['variance'] as Map<dynamic, dynamic>?;
                          if (varianceMap != null) {
                            final varianceData = varianceMap.values.firstWhere(
                              (v) => (v as Map<dynamic, dynamic>)['varianceName']?.toString() == varianceName,
                              orElse: () => null,
                            );
                            if (varianceData != null) {
                              systemStock =
                                  (varianceData['branchwise']?['${aliasname}']?['systemStock_${aliasname}'] as num?)
                                      ?.toDouble() ??
                                  0.0;
                            }
                          }
                        }
                        print('DEBUG: CurrentSaleSection - System Stock for $varianceName: $systemStock');

                        return SwipeActionCell(
                          backgroundColor: Colors.white,
                          trailingActions: [
                            SwipeAction(
                              performsFirstActionWithFullSwipe: true,
                              onTap: (CompletionHandler handler) async {
                                saleProvider.removeItem(index);
                                await handler(true);
                              },
                              color: Colors.red,
                              content: const Icon(Icons.delete, color: Colors.white),
                            ),
                          ],
                          key: Key('${saleProvider.currentSaleItems[index]}'),
                          child: ListTile(
                            onTap: () {
                              final item = saleProvider.currentSaleItems[index];
                              final String itemName = item['itemName']?.toString() ?? 'Unknown Item';
                              final String varianceName = item['varianceData']['varianceName']?.toString() ?? '';
                              final double price = (item['varianceData']['variance_Defaultprice'] as num?)?.toDouble() ?? 0.0;
                              final double currentQty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                              print(
                                'DEBUG: Tapped Item - Weight: ${item['weight']}, Quantity: ${item['quantity']}, UOM: ${item['varianceData']['variance_Uom']}',
                              );
                              print('DEBUG: Full Item: $item');

                              // if (item.containsKey('varianceData') &&
                              //     item['varianceData'] != null &&
                              //     item['varianceData']['variance_Uom'] != null) {
                              //   String? uom = item['varianceData']['variance_Uom'];
                              print('DEBUG: CurrentSaleSection - Tapped item UOM: ');
                              //if (uom == 'Kgs' || uom == 'Kg') {
                              if (item['varianceData']['variance_Uom']?.toString().toLowerCase() == 'kgs') {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) {
                                    return NumericCalculator(
                                      varianceName: item['varianceData']['varianceName'],
                                      onValueSelected: (weight) {
                                        print('DEBUG: CurrentSaleSection - Updating weight for index $index: $weight');
                                        if (weight <= 0) {
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            const SnackBar(
                                              content: Text("Invalid weight. Please enter a valid weight."),
                                              backgroundColor: Colors.red,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                          return;
                                        }
                                        if (weight > systemStock) {
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "Selected weight (${weight.toStringAsFixed(3)} kg) exceeds available stock (${systemStock.toStringAsFixed(3)} kg).",
                                              ),
                                              backgroundColor: Colors.red,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                          return;
                                        }
                                        saleProvider.updateItemQuantity(index, weight);
                                      },
                                    );
                                  },
                                );
                              } else {
                                showCommonQuantityDialog(
                                  context: context,
                                  itemName: itemName,
                                  varianceName: varianceName,
                                  price: price,
                                  initialQuantity: currentQty,
                                  onAddToCart: (newQty) {
                                    saleProvider.updateItemQuantity(index, newQty);
                                  },
                                );
                              }
                            },
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomText(
                                      text: '${item['varianceData']['varianceName']}',
                                      style: TextStyle(
                                        fontFamily: "Poppins",
                                        color: CustomColors.black.withOpacity(0.7),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    CustomText(
                                      text: saleProvider.buildQuantityPriceDisplay(item),
                                      style: TextStyle(fontFamily: "Poppins", fontSize: 14),
                                    ),
                                  ],
                                ),
                                CustomText(
                                  text: '₹${saleProvider.calculateItemTotal(item).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontFamily: "Poppins",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: CustomColors.black.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 100, color: CustomColors.black.withOpacity(0.1)),
                          Text('No items in cart',style: TextStyle(fontFamily: "Poppins",),),
                        ],
                      ),
                    ),
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
                      text: 'Charge ₹ ${saleProvider.calculateTotal().round().toString()}',
                      onPressed: () {
                        CurrentDatetimeService().fetchCurrentDateTime();
                        debugPrint("currentDate:${currentDate.value}");
                        debugPrint("currentTime:${currentTime.value}");
                        double totalAmount = saleProvider.calculateTotal();
                        if (totalAmount != 0) {
                          debugPrint('entered');
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (BuildContext context) {
                              debugPrint('entered');
                              return Dialog(
                                alignment: Alignment.centerLeft,
                                backgroundColor: CustomColors.whiteColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Builder(
                                    builder: (context) {
                                      return CustomSizedBox(
                                        width: MediaQuery.of(context).size.width * 0.5,
                                        child: SalesInvoicePayAndPrint(
                                          totalAmount: totalAmount,
                                          holdBillId: saleProvider.holdBillId ?? '',
                                          onDismiss: () {
                                            debugPrint('entered3');
                                            // Reset discount and custom charge when dialog is dismissed
                                            saleProvider.discountPercentage = 0.0;
                                            saleProvider.customCharge = 0.0;
                                            saleProvider.calculateTotal();
                                            
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ).then((_) {
                            // This runs when the dialog is dismissed
                            saleProvider.discountPercentage = 0.0;
                            saleProvider.customCharge = 0.0;
                            saleProvider.calculateTotal();
                          });
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
                      //Expanded(child: ViewSavedBillsWidget()),
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

                      // ... Inside the CurrentSaleSection's build method ...
                      Expanded(
                        child: CustomButton(
                          text: 'SaveBill',
                          onPressed: () {
                            // Check if current sale items are empty
                            if (saleProvider.currentSaleItems.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('No items to save!', style: TextStyle(fontFamily: "Poppins",fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      //         final printerProvider = Provider.of<PrinterProviderpos>(context, listen: false);

                      //         // ignore: unused_local_variable
                      //         String printerIp = printerProvider.getOverallPrinterIp().toString();
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

  Widget _buildHeader(String title) {
    return Expanded(
      child: Text(
        title,
        style: TextStyle(fontFamily: "Poppins",color: Colors.white, fontWeight: FontWeight.bold),
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

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Merge With..",
                    style: TextStyle(fontFamily: "Poppins",color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: selectedBills.isNotEmpty
                        ? () async {
                            // Merge selected bills
                            await _mergeSelectedBills(context, selectedBills.toList(), box, selectedTicketNumbers);
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: Text(
                      "CONTINUE",
                      style: TextStyle(
                        fontFamily: "Poppins",
                        color: selectedBills.isNotEmpty ? CustomColors.blueColor : Colors.grey,
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
                    color: CustomColors.blueColor,
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
                        String formattedDate = DateFormat('dd-MM-yyyy hh:mm a').format(date);
                        double amount = bill['total'] ?? 0.0;

                        return Container(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
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
                                    String ticketNumber = selectedBill['ticketName'] ?? "Unknown";
                                    selectedTicketNumbers.add(ticketNumber);
                                  } else {
                                    selectedBills.remove(index);
                                    final selectedBill = holdBills[index];
                                    String ticketNumber = selectedBill['ticketName'] ?? "Unknown";
                                    selectedTicketNumbers.remove(ticketNumber);
                                  }
                                });
                              },
                              activeColor: CustomColors.blueColor,
                            ),
                            title: Text(bill['ticketName'], style: TextStyle(fontFamily: "Poppins",color: Colors.black, fontSize: 16)),
                            subtitle: Text(formattedDate, style: TextStyle(fontFamily: "Poppins",color: Colors.black, fontSize: 14)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("₹${amount.toStringAsFixed(2)}", style: TextStyle(fontFamily: "Poppins",color: Colors.black, fontSize: 16)),
                                SizedBox(width: 10),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.redAccent),
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
          },
        );
      },
    );
  }

  /// Function to merge selected bills and save them to Hive
  Future<void> _mergeSelectedBills(
    BuildContext context,
    List<int> selectedBillIndices,
    Box box,
    List<String> selectedTicketNumbers,
  ) async {
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
      'holdId': DateTime.now().millisecondsSinceEpoch.toString(), // Unique hold ID
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
    selectedBillIndices.sort((a, b) => b.compareTo(a)); // Sort descending to avoid index shifting
    for (int index in selectedBillIndices) {
      await box.deleteAt(index); // Remove selected bills
    }

    // Optional API Post (Commented Out for now)
    // try {
    //   final response = await http.post(
    //     Uri.parse('http://192.168.1.114:8888/fastapi/holds/'),
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

  void _promptForMergeTitle(BuildContext context, CurrentSaleProvider saleProvider) async {
    var box = await Hive.openBox('cartBox');
    List<Map<String, dynamic>> allBills = [];
    for (int i = 0; i < box.length; i++) {
      var bill = box.getAt(i);
      if (bill is Map && bill['status'] == 'hold') {
        allBills.add({...Map<String, dynamic>.from(bill), '_originalIndex': i});
      }
    }

    String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
    TextEditingController titleController = TextEditingController(text: "Merged Ticket - $formattedTime");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        Set<int> selectedBills = {}; // Track selected bill indices

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Select Bills to Merge", style: TextStyle(fontFamily: "Poppins",fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: selectedBills.isNotEmpty
                        ? () async {
                            String ticketName = titleController.text.trim();
                            if (ticketName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid ticket name!'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
                                ),
                              );
                              return;
                            }

                            try {
                              // Collect selected bills and current sale items
                              List<Map<String, dynamic>> allItems = [...saleProvider.currentSaleItems];
                              double totalAmount = saleProvider.calculateTotal();
                              List<String> ticketNames = [ticketName];

                              for (int index in selectedBills) {
                                final bill = allBills[index];
                                allItems.addAll((bill['items'] as List).map((item) => Map<String, dynamic>.from(item)));
                                totalAmount += (bill['total'] ?? 0.0).toDouble();
                                ticketNames.add(bill['ticketName'] ?? 'Unnamed Ticket');
                              }

                              // Create merged bill
                              Map<String, dynamic> mergedBill = {
                                'holdId': DateTime.now().millisecondsSinceEpoch.toString(),
                                'items': allItems,
                                'total': totalAmount,
                                'date': DateTime.now().toIso8601String(),
                                'status': 'hold',
                                'ticketName': ticketNames.join(" + "),
                                'isMerged': true,
                              };

                              // Save merged bill
                              await box.add(mergedBill);

                              // Delete selected bills
                              selectedBills.toList()
                                ..sort((a, b) => b.compareTo(a))
                                ..forEach((index) async {
                                  await box.deleteAt(allBills[index]['_originalIndex']);
                                });

                              // Clear current sale items
                              saleProvider.clearItems();

                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Merged ${selectedBills.length + 1} bills successfully!'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
                                ),
                              );

                              Navigator.pop(context);
                              _viewBills(context);
                            } catch (e) {
                              print('Error merging bills: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error merging bills: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
                                ),
                              );
                            }
                          }
                        : null,
                    child: Text(
                      "Merge",
                      style: TextStyle(fontFamily: "Poppins",
                        color: selectedBills.isNotEmpty ? CustomColors.blueColor : Colors.grey,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: "Enter merged ticket name",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: CustomColors.blueColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: CustomColors.blueColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: CustomColors.blueColor,
                    child: Row(
                      children: [const SizedBox(width: 40), _buildHeader("SELECT"), _buildHeader("NAME"), _buildHeader("AMOUNT")],
                    ),
                  ),
                  SizedBox(
                    width: 400,
                    height: 300,
                    child: ListView.builder(
                      itemCount: allBills.length,
                      itemBuilder: (context, index) {
                        final bill = allBills[index];
                        DateTime date = DateTime.parse(bill['date']);
                        String formattedDate = DateFormat('dd-MM-yyyy hh:mm a').format(date);
                        double amount = bill['total'] ?? 0.0;

                        return ListTile(
                          leading: Checkbox(
                            value: selectedBills.contains(index),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedBills.add(index);
                                } else {
                                  selectedBills.remove(index);
                                }
                              });
                            },
                            activeColor: CustomColors.blueColor,
                          ),
                          title: Text(
                            bill['ticketName'] ?? 'Unnamed Ticket',
                            style: const TextStyle(fontFamily: "Poppins",color: CustomColors.black, fontSize: 16),
                          ),
                          subtitle: Text(formattedDate, style: const TextStyle(fontFamily: "Poppins",color: CustomColors.black, fontSize: 14)),
                          trailing: Text(
                            "₹${amount.toStringAsFixed(2)}",
                            style: const TextStyle(fontFamily: "Poppins",color: CustomColors.black, fontSize: 16),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: CustomColors.blueColor,
                    foregroundColor: CustomColors.whiteColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  //   void promptForSaveBillsTitle(BuildContext context, CurrentSaleProvider saleProvider) {
  //     String formattedTime = DateFormat('hh:mm a').format(DateTime.now());
  //     TextEditingController titleController = TextEditingController(text: "Ticket - $formattedTime");

  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (BuildContext context) {
  //         return AlertDialog(
  //           backgroundColor: CustomColors.whiteColor,
  //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //           title: Text("Enter Ticket Title for Save Ticket", style: TextStyle(fontWeight: FontWeight.bold)),
  //           content: Padding(
  //             padding: const EdgeInsets.symmetric(vertical: 10),
  //             child: TextField(
  //               controller: titleController,
  //               autofocus: true,
  //               decoration: InputDecoration(
  //                 hintText: "Enter  ticket name",
  //                 border: OutlineInputBorder(
  //                   borderRadius: BorderRadius.circular(8),
  //                   borderSide: BorderSide(color: CustomColors.blueColor),
  //                 ),
  //                 focusedBorder: OutlineInputBorder(
  //                   borderRadius: BorderRadius.circular(8),
  //                   borderSide: BorderSide(color: CustomColors.blueColor, width: 2),
  //                 ),
  //                 contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
  //               ),
  //             ),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.pop(context);
  //               },
  //               style: TextButton.styleFrom(
  //                 backgroundColor: CustomColors.blueColor,
  //                 foregroundColor: CustomColors.whiteColor,
  //                 padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //               ),
  //               child: Text("Cancel"),
  //             ),
  //             TextButton(
  //               onPressed: () async {
  //                 String baseName = titleController.text.trim();
  //                 if (baseName.isEmpty) return;

  //                 // Include the current sale items in the merge
  //                 List<List<Map<String, dynamic>>> tickets = [
  //                   saleProvider.currentSaleItems, // Include the current sale items
  //                 ];

  //                 // Get selected bills from the current context
  //                 List<String> ticketTitles = [baseName]; // Use the entered title

  //                 // Save the merged ticket
  //                 await saleProvider.saveBillsplitBill(context, tickets, ticketTitles);

  //                 // Optionally clear the items after saving the ticket
  //                 saleProvider.clearItems();

  //                 // Close the dialog
  //                 Navigator.pop(context);
  //               },
  //               style: TextButton.styleFrom(
  //                 backgroundColor: CustomColors.blueColor,
  //                 foregroundColor: CustomColors.whiteColor,
  //                 padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //               ),
  //               child: Text("OK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //   }
  // }

  void promptForSaveBillsTitle(BuildContext context, CurrentSaleProvider saleProvider) async {
    final ticketTitle = await TicketSequenceGenerator.generate();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: CustomColors.whiteColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text("Save Bill as: $ticketTitle", style: TextStyle(fontFamily: "Poppins",fontWeight: FontWeight.bold)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "This bill will be saved as '$ticketTitle'. The ticket name is auto-generated and cannot be edited.",
              style: TextStyle(fontFamily: "Poppins",fontSize: 16),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: CustomColors.blueColor,
                foregroundColor: CustomColors.whiteColor,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                // Save the current bill with the auto-generated title
                await saleProvider.saveBillWithTitle(context, ticketTitle);

                // Clear items after saving
                saleProvider.clearItems();

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Bill saved successfully as $ticketTitle!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: CustomColors.blueColor,
                foregroundColor: CustomColors.whiteColor,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text("Save Bill", style: TextStyle(fontFamily: "Poppins",fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

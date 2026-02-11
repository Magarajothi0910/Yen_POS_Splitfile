// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:yen_pos/Global/Widget/custom_colors.dart';

// import '../provider/cart_page_provider.dart';
// import '../split_bill_screen.dart';

// class ViewSavedBillsWidget {
//   // const ViewSavedBillsWidget({super.key});

//   void viewBills(BuildContext context) async {
//     var box = await Hive.openBox('cartBox');

//     // Get all bills and store their original indices
//     List<Map<String, dynamic>> allBills = [];
//     for (int i = 0; i < box.length; i++) {
//       var bill = box.getAt(i);
//       if (bill is Map && bill['status'] == 'hold') {
//         allBills.add({
//           ...Map<String, dynamic>.from(bill),
//           '_originalIndex': i, // Store original index for deletion
//         });
//       }
//     }

//     if (allBills.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No saved bills available!'),
//           backgroundColor: CustomColors.redColor,
//           margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }

//     showDialog(
//       context: context,
//       builder: (context) {
//         Set<int> selectedBills = {}; // To track selected bills by their index in allBills

//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               backgroundColor: CustomColors.whiteColor,
//               title: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     "Saved Bills",
//                     style: TextStyle(color: CustomColors.black, fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   Spacer(),
//                   // Split button - enabled if exactly one checkbox is selected
//                   IconButton(
//                     onPressed: selectedBills.isNotEmpty && selectedBills.length == 1
//                         ? () {
//                             final selectedIndex = selectedBills.first;
//                             final bill = allBills[selectedIndex];

//                             List<Map<String, dynamic>> items = (bill['items'] as List)
//                                 .map((item) => Map<String, dynamic>.from(item))
//                                 .toList();

//                             Navigator.of(context).pop(); // Close the saved bills dialog first

//                             showDialog(
//                               context: context,
//                               builder: (context) => SplitBillDialog(initialItems: items),
//                             );
//                           }
//                         : null,
//                     icon: Icon(Icons.call_split),
//                     tooltip: 'Split Bill',
//                   ),
//                   // Merge button - enabled only if two or more checkboxes are selected
//                   IconButton(
//                     onPressed: selectedBills.length >= 2
//                         ? () {
//                             _mergeBills(context, selectedBills.toList(), box, allBills);
//                           }
//                         : null,
//                     icon: Icon(Icons.merge),
//                     tooltip: 'Merge Bills',
//                   ),
//                 ],
//               ),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Container(
//                     padding: EdgeInsets.symmetric(vertical: 10),
//                     color: CustomColors.blueColor,
//                     child: Row(
//                       children: [
//                         _buildHeader("SELECT"),
//                         _buildHeader("NAME"),
//                         _buildHeader("AMOUNT"),
//                         // _buildHeader("TIME"),
//                       ],
//                     ),
//                   ),
//                   SizedBox(
//                     width: 600,
//                     height: 300,
//                     child: ListView.builder(
//                       itemCount: allBills.length,
//                       itemBuilder: (context, index) {
//                         final bill = allBills[index];
//                         DateTime date = DateTime.parse(bill['date']);
//                         String formattedDate = DateFormat('dd-MM-yyyy hh:mm a').format(date);
//                         double amount = bill['total'] ?? 0.0;
//                         String ticketName = bill['ticketName'] ?? 'Unnamed Ticket';

//                         return Container(
//                           decoration: BoxDecoration(
//                             border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
//                           ),
//                           child: ListTile(
//                             leading: Checkbox(
//                               value: selectedBills.contains(index),
//                               onChanged: (value) {
//                                 setState(() {
//                                   if (value == true) {
//                                     selectedBills.add(index);
//                                   } else {
//                                     selectedBills.remove(index);
//                                   }
//                                 });
//                               },
//                               activeColor: CustomColors.blueColor,
//                             ),
//                             onTap: () {
//                               var saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);

//                               List<Map<String, dynamic>> items = (bill['items'] as List)
//                                   .map((item) => Map<String, dynamic>.from(item))
//                                   .toList();

//                               saleProvider.loadItemsFromBill(items, merge: false, holdId: bill['holdId']?.toString());

//                               Navigator.of(context).pop(); // Close dialog
//                             },
//                             title: Text(ticketName, style: TextStyle(fontWeight: FontWeight.bold)),
//                             subtitle: Text(formattedDate, style: TextStyle(color: CustomColors.grey, fontSize: 12)),
//                             trailing: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Text(
//                                   "₹${amount.toStringAsFixed(2)}",
//                                   style: TextStyle(color: CustomColors.blueColor, fontSize: 16, fontWeight: FontWeight.bold),
//                                 ),
//                                 SizedBox(width: 10),
//                                 IconButton(
//                                   icon: Icon(Icons.delete, color: CustomColors.redColor, size: 20),
//                                   onPressed: () async {
//                                     bool shouldDelete =
//                                         await showDialog<bool>(
//                                           context: context,
//                                           builder: (BuildContext context) {
//                                             return AlertDialog(
//                                               backgroundColor: CustomColors.whiteColor,
//                                               title: Text("Delete Bill?"),
//                                               content: Text("Are you sure you want to delete '$ticketName'?"),
//                                               actions: [
//                                                 TextButton(
//                                                   onPressed: () => Navigator.of(context).pop(false),
//                                                   child: Text("Cancel", style: TextStyle(color: CustomColors.grey)),
//                                                 ),
//                                                 TextButton(
//                                                   onPressed: () => Navigator.of(context).pop(true),
//                                                   child: Text("Delete", style: TextStyle(color: CustomColors.redColor)),
//                                                 ),
//                                               ],
//                                             );
//                                           },
//                                         ) ??
//                                         false;

//                                     if (shouldDelete) {
//                                       // Delete using original index stored in the bill
//                                       int originalIndex = bill['_originalIndex'];
//                                       await box.deleteAt(originalIndex);

//                                       // Update the UI by refreshing the list
//                                       setState(() {
//                                         allBills.removeAt(index);
//                                         selectedBills.remove(index);
//                                       });

//                                       // ScaffoldMessenger.of(context).showSnackBar(
//                                       //   SnackBar(
//                                       //     content: Text('Bill deleted successfully!'),
//                                       //     backgroundColor: Colors.green,
//                                       //     duration: const Duration(seconds: 1),
//                                       //   ),
//                                       // );
//                                     }
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                   if (selectedBills.isNotEmpty) ...[
//                     SizedBox(height: 10),
//                     Text(
//                       '${selectedBills.length} bill(s) selected',
//                       style: TextStyle(fontWeight: FontWeight.bold, color: CustomColors.blueColor),
//                     ),
//                   ],
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   void _mergeBills(BuildContext context, List<int> selectedIndices, Box box, List<Map<String, dynamic>> allBills) async {
//     if (selectedIndices.isEmpty || selectedIndices.length < 2) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select at least 2 bills to merge!'), backgroundColor: CustomColors.redColor),
//       );
//       return;
//     }

//     // Show confirmation dialog
//     bool shouldMerge =
//         await showDialog<bool>(
//           context: context,
//           builder: (BuildContext context) {
//             return AlertDialog(
//               backgroundColor: CustomColors.whiteColor,
//               title: Text("Merge Bills?"),
//               content: Text("Are you sure you want to merge ${selectedIndices.length} bills?"),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(false),
//                   child: Text("Cancel", style: TextStyle(color: CustomColors.grey)),
//                 ),
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop(true);
//                   },
//                   child: Text("Merge", style: TextStyle(color: CustomColors.blueColor)),
//                 ),
//               ],
//             );
//           },
//         ) ??
//         false;

//     if (!shouldMerge) return;

//     try {
//       // Step 1: Collect selected bills data
//       List<Map<String, dynamic>> selectedBillsData = [];
//       List<String> ticketNames = [];
//       double totalAmount = 0.0;
//       List<Map<String, dynamic>> allItems = [];

//       for (int index in selectedIndices) {
//         final bill = allBills[index];
//         selectedBillsData.add(bill);
//         ticketNames.add(bill['ticketName'] ?? 'Unnamed Ticket');
//         totalAmount += (bill['total'] ?? 0.0).toDouble();

//         // Add all items from this bill
//         if (bill['items'] is List) {
//           List<Map<String, dynamic>> items = (bill['items'] as List).map((item) => Map<String, dynamic>.from(item)).toList();
//           allItems.addAll(items);
//         }
//       }

//       // Step 2: Create merged bill
//       Map<String, dynamic> mergedBill = {
//         'holdId': DateTime.now().millisecondsSinceEpoch.toString(),
//         'items': allItems,
//         'total': totalAmount,
//         'date': DateTime.now().toIso8601String(),
//         'status': 'hold',
//         'ticketName': ticketNames.join(" + "),
//         'isMerged': true, // Mark as merged for identification
//       };

//       // Step 3: Save merged bill
//       await box.add(mergedBill);

//       // Step 4: Delete original bills (in reverse order to maintain correct indices)
//       selectedIndices.sort((a, b) => b.compareTo(a)); // Sort descending
//       for (int index in selectedIndices) {
//         final bill = allBills[index];
//         int originalIndex = bill['_originalIndex'];
//         await box.deleteAt(originalIndex);
//       }

//       // Step 5: Load merged items into cart
//       _loadMergedItemsToCart(context, allItems, mergedBill['holdId']);

//       // Step 6: Show success message and close dialog
//       // ScaffoldMessenger.of(context).showSnackBar(
//       //   SnackBar(
//       //     content: Text('${selectedIndices.length} bills merged successfully! Items loaded to cart.'),
//       //     backgroundColor: Colors.green,
//       //     duration: Duration(seconds: 2),
//       //   ),
//       // );

//       Navigator.of(context).pop(); // Close the dialog
//     } catch (e) {
//       print('Error merging bills: $e');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error merging bills: $e'), backgroundColor: CustomColors.redColor));
//     }
//   }

//   void _loadMergedItemsToCart(BuildContext context, List<Map<String, dynamic>> items, String holdId) {
//     try {
//       var saleProvider = Provider.of<CurrentSaleProvider>(context, listen: false);

//       // Load the merged items into the cart
//       saleProvider.loadItemsFromBill(
//         items,
//         merge: true, // Set merge to true to indicate this is a merged bill
//         holdId: holdId,
//       );

//       // Optional: Show a confirmation that items are loaded
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('${items.length} items loaded to cart'),
//             backgroundColor: CustomColors.blueColor,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       });
//     } catch (e) {
//       print('Error loading merged items to cart: $e');
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Error loading items to cart: $e'), backgroundColor: CustomColors.redColor));
//       });
//     }
//   }

//   Widget _buildHeader(String title) {
//     return Expanded(
//       child: Text(
//         title,
//         style: TextStyle(color: CustomColors.whiteColor, fontWeight: FontWeight.bold),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }

//   // @override
//   // Widget build(BuildContext context) {
//   //   return CustomButton(
//   //     text: 'ViewBills',
//   //     onPressed: () => _viewBills(context),
//   //     backgroundColor: Colors.white70,
//   //     textColor: Colors.blue,
//   //   );
//   // }
// }

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Widget/custom_colors.dart';
import 'package:yen_pos/more_page/widgets/other.dart';
import 'package:yen_pos/regular_mode_page/widget/custom_reusable_widget/ticket_generator.dart';

import '../provider/cart_page_provider.dart';
import '../split_bill_screen.dart';

class ViewSavedBillsWidget {
  void viewBills(BuildContext context) async {
    var box = await Hive.openBox('cartBox');

    List<Map<String, dynamic>> allBills = [];
    for (int i = 0; i < box.length; i++) {
      var bill = box.getAt(i);
      if (bill is Map && bill['status'] == 'hold') {
        allBills.add({
          ...Map<String, dynamic>.from(bill),
          '_originalIndex': i,
          '_hiveKey': i, // Store the actual Hive key
        });
      }
    }

    if (allBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved bills available!'),
          backgroundColor: CustomColors.redColor,
          margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        Set<int> selectedBills = {};

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: CustomColors.whiteColor,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Saved Bills",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: CustomColors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  // Split button
                  IconButton(
                    onPressed:
                        selectedBills.isNotEmpty && selectedBills.length == 1
                        ? () {
                            final selectedIndex = selectedBills.first;
                            final bill = allBills[selectedIndex];

                            List<Map<String, dynamic>> items =
                                (bill['items'] as List)
                                    .map(
                                      (item) => Map<String, dynamic>.from(item),
                                    )
                                    .toList();

                            Navigator.of(context).pop();

                            showDialog(
                              context: context,
                              builder: (context) =>
                                  SplitBillDialog(initialItems: items),
                            );
                          }
                        : null,
                    icon: Icon(Icons.call_split),
                    tooltip: 'Split Bill',
                  ),
                  // Merge button
                  IconButton(
                    onPressed: selectedBills.length >= 2
                        ? () {
                            _mergeBills(
                              context,
                              selectedBills.toList(),
                              box,
                              allBills,
                              setState,
                            );
                          }
                        : null,
                    icon: Icon(Icons.merge),
                    tooltip: 'Merge Bills',
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
                        _buildHeader("SELECT"),
                        _buildHeader("NAME"),
                        _buildHeader("AMOUNT"),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 600,
                    height: 300,
                    child: allBills.isEmpty
                        ? Center(
                            child: Text(
                              'No saved bills available',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                color: CustomColors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: allBills.length,
                            itemBuilder: (context, index) {
                              final bill = allBills[index];
                              DateTime date = DateTime.parse(bill['date']);
                              String formattedDate = DateFormat(
                                'dd-MM-yyyy hh:mm a',
                              ).format(date);
                              double amount = bill['total'] ?? 0.0;
                              String ticketName =
                                  bill['ticketName'] ?? 'Unnamed Ticket';

                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                ),
                                child: ListTile(
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
                                  onTap: () async {
                                    // Load bill to cart and remove from saved bills
                                    await _loadBillAndRemove(
                                      context,
                                      bill,
                                      box,
                                      allBills,
                                      index,
                                      setState,
                                    );
                                  },
                                  title: Text(
                                    ticketName,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: CustomColors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "₹${amount.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: CustomColors.blueColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: CustomColors.redColor,
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          await _deleteBill(
                                            context,
                                            bill,
                                            box,
                                            allBills,
                                            index,
                                            setState,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (selectedBills.isNotEmpty) ...[
                    SizedBox(height: 10),
                    Text(
                      '${selectedBills.length} bill(s) selected',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: CustomColors.blueColor,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    "Close",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: CustomColors.blueColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // New method: Load bill to cart and remove from saved bills
  // Future<void> _loadBillAndRemove(
  //   BuildContext context,
  //   Map<String, dynamic> bill,
  //   Box box,
  //   List<Map<String, dynamic>> allBills,
  //   int index,
  //   Function(void Function()) setState,
  // ) async {
  //   try {
  //     var saleProvider = Provider.of<CurrentSaleProvider>(
  //       context,
  //       listen: false,
  //     );

  //     List<Map<String, dynamic>> items = (bill['items'] as List)
  //         .map((item) => normalizeItem(Map<String, dynamic>.from(item)))
  //         .toList();

  //     // Clear cart and load selected bill
  //     saleProvider.clearItems();
  //     saleProvider.loadItemsFromBill(
  //       items,
  //       merge: false,
  //       holdId: bill['holdId']?.toString(),
  //     );

  //     // Remove the bill from Hive storage
  //     int hiveKey = bill['_hiveKey'];
  //     await box.deleteAt(hiveKey);

  //     // Update the UI
  //     setState(() {
  //       allBills.removeAt(index);
  //     });

  //     // Close the dialog
  //     Navigator.of(context).pop();

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Bill loaded to cart and removed from saved bills!'),
  //         backgroundColor: Colors.green,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //   } catch (e) {
  //     print('Error loading and removing bill: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error loading bill: $e'),
  //         backgroundColor: Colors.red,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //   }
  // }

  Future<void> _loadBillAndRemove(
    BuildContext context,
    Map<String, dynamic> bill,
    Box box,
    List<Map<String, dynamic>> allBills,
    int index,
    Function(void Function()) setState,
  ) async {
    try {
      var saleProvider = Provider.of<CurrentSaleProvider>(
        context,
        listen: false,
      );

      // Clear current cart first
      saleProvider.clearItems();

      // Normalize and load items
      List<Map<String, dynamic>> items = (bill['items'] as List).map((item) {
        Map<String, dynamic> normalized = normalizeItem(
          Map<String, dynamic>.from(item),
        );

        // DEBUG: Print the normalized item structure
        print('🚀 Loading item to cart:');
        print('  - itemName: ${normalized['itemName']}');
        print('  - itemData: ${normalized['itemData']}');
        print('  - varianceData: ${normalized['varianceData']}');
        print('  - quantity: ${normalized['quantity']}');
        print('  - weight: ${normalized['weight']}');

        return normalized;
      }).toList();

      // Load items to cart
      saleProvider.loadItemsFromBill(
        items,
        merge: false,
        holdId: bill['holdId']?.toString(),
      );

      // Remove from saved bills
      int hiveKey = bill['_hiveKey'];
      await box.deleteAt(hiveKey);

      // Update UI
      setState(() {
        allBills.removeAt(index);
      });

      // Close dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill loaded to cart!'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      print('❌ Error loading bill: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading bill: $e'),
          backgroundColor: Colors.red,
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  // Updated delete bill method
  Future<void> _deleteBill(
    BuildContext context,
    Map<String, dynamic> bill,
    Box box,
    List<Map<String, dynamic>> allBills,
    int index,
    Function(void Function()) setState,
  ) async {
    bool shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: CustomColors.whiteColor,
              title: Text("Delete Bill?"),
              content: Text(
                "Are you sure you want to delete '${bill['ticketName']}'?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: CustomColors.grey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    "Delete",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: CustomColors.redColor,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldDelete) {
      try {
        int originalIndex = bill['_originalIndex'];
        await box.deleteAt(originalIndex);

        setState(() {
          allBills.removeAt(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      } catch (e) {
        print('Error deleting bill: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting bill: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Updated merge bills method
  void _mergeBills(
    BuildContext context,
    List<int> selectedIndices,
    Box box,
    List<Map<String, dynamic>> allBills,
    Function(void Function()) setState,
  ) async {
    if (selectedIndices.isEmpty || selectedIndices.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 2 bills to merge!'),
          backgroundColor: CustomColors.redColor,
        ),
      );
      return;
    }

    bool shouldMerge =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: CustomColors.whiteColor,
              title: Text("Merge Bills?"),
              content: Text(
                "How do you want to merge ${selectedIndices.length} bills?\n\n"
                "• Quantity items (pieces) will be combined\n"
                "• Weight items (kg) will be kept separate",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: CustomColors.grey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    "Smart Merge",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: CustomColors.blueColor,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldMerge) return;

    try {
      // Smart merge: combine quantity items, keep weight items separate
      List<Map<String, dynamic>> mergedItems = [];
      List<String> ticketNames = [];
      double totalAmount = 0.0;

      // Track quantity items to combine
      Map<String, Map<String, dynamic>> quantityItemsMap = {};

      // Track weight items to keep separate
      List<Map<String, dynamic>> weightItems = [];

      for (int index in selectedIndices) {
        final bill = allBills[index];
        ticketNames.add(bill['ticketName'] ?? 'Unnamed Ticket');

        if (bill['items'] is List) {
          List<Map<String, dynamic>> items = (bill['items'] as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

          for (var item in items) {
            final String uom =
                (item['varianceData']?['variance_Uom']
                    ?.toString()
                    .toLowerCase() ??
                '');
            final bool isWeightItem =
                uom.contains('kg') || uom.contains('kgs') || uom.contains('gm');

            if (isWeightItem) {
              // Weight items - keep separate with unique ID
              weightItems.add(_createUniqueItem(item));
            } else {
              // Quantity items - combine
              final String itemKey = _getQuantityItemKey(item);

              if (quantityItemsMap.containsKey(itemKey)) {
                // Combine quantities for same item
                final existingItem = quantityItemsMap[itemKey]!;
                final double currentQty = (existingItem['quantity'] as num)
                    .toDouble();
                final double newQty = (item['quantity'] as num).toDouble();
                existingItem['quantity'] = currentQty + newQty;
              } else {
                // New quantity item
                quantityItemsMap[itemKey] = _createUniqueItem(item);
              }
            }
          }

          totalAmount += (bill['total'] ?? 0.0).toDouble();
        }
      }

      // Add all combined quantity items
      mergedItems.addAll(quantityItemsMap.values);

      // Add all weight items as separate entries
      mergedItems.addAll(weightItems);

      final mergedTitle = await TicketSequenceGenerator.generate();

      // Create merged bill
      Map<String, dynamic> mergedBill = {
        'holdId': DateTime.now().millisecondsSinceEpoch.toString(),
        'items': mergedItems,
        'total': totalAmount,
        'date': DateTime.now().toIso8601String(),
        'status': 'hold',
        'ticketName': mergedTitle,
        'isMerged': true,
        'originalTickets': ticketNames,
        'mergeType': 'smart',
      };

      // Save merged bill
      await box.add(mergedBill);

      // Delete original bills from Hive and update UI
      selectedIndices.sort((a, b) => b.compareTo(a));
      for (int index in selectedIndices) {
        final bill = allBills[index];
        int originalIndex = bill['_originalIndex'];
        await box.deleteAt(originalIndex);
      }

      // Update the UI by removing merged bills
      setState(() {
        for (int index
            in selectedIndices.toList()..sort((a, b) => b.compareTo(a))) {
          allBills.removeAt(index);
        }
      });

      // Load merged items into cart
      _loadMergedItemsToCart(context, mergedItems, mergedBill['holdId']);

      // Don't close the dialog automatically, let user see the updated list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully merged ${selectedIndices.length} bills!\n'
            '• ${quantityItemsMap.length} quantity items combined\n'
            '• ${weightItems.length} weight items kept separate',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('Error merging bills: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error merging bills: $e'),
          backgroundColor: CustomColors.redColor,
        ),
      );
    }
  }

  String _getQuantityItemKey(Map<String, dynamic> item) {
    final String itemCode = item['itemCode']?.toString() ?? '';
    final String varianceName =
        item['varianceData']?['varianceName']?.toString() ?? '';
    return '$itemCode-$varianceName';
  }

  Map<String, dynamic> _createUniqueItem(Map<String, dynamic> item) {
    return {
      ...item,
      'varianceData': Map<String, dynamic>.from(item['varianceData'] ?? {}),
      'uniqueId':
          '${DateTime.now().millisecondsSinceEpoch}-${item['itemCode']}-${UniqueKey().toString()}',
    };
  }

  // Map<String, dynamic> normalizeItem(Map<String, dynamic> item) {
  //   final variance = item['varianceData'] ?? {};

  //   return {
  //     "itemCode": item["itemCode"],
  //     "itemName":
  //         item["itemName"] ??
  //         variance["itemName"] ??
  //         variance["varianceName"] ??
  //         "Unknown",
  //     "varianceData": variance,
  //     "quantity": item["quantity"] ?? 0,
  //     "price": item["price"] ?? item["sellingPrice"] ?? 0,
  //     "sellingPrice": item["sellingPrice"] ?? item["price"] ?? 0,
  //     "total": item["total"] ?? 0,
  //     // Add all other fields your cart/print expects
  //   };
  // }

  Map<String, dynamic> normalizeItem(Map<String, dynamic> item) {
    // Extract all possible sources of item name
    final variance = item['varianceData'] ?? {};
    final itemData = item['itemData'] ?? {};

    // Get UOM
    final String uom =
        (variance['variance_Uom']?.toString() ??
                itemData['item_Uom']?.toString() ??
                'pcs')
            .toLowerCase();
    final bool isKgItem =
        uom.contains('kg') || uom.contains('kgs') || uom.contains('gm');

    // FIXED: Extract itemName - check multiple sources
    String itemName =
        item['itemName'] ??
        itemData['itemName'] ??
        variance['itemName'] ??
        variance['varianceName'] ??
        item['varianceData']?['varianceName'] ?? // Add this
        'Unknown Item';

    // FIXED: Extract itemCode - check multiple sources
    String itemCode =
        item['itemCode'] ??
        itemData['itemCode'] ??
        variance['varianceitemCode'] ??
        variance['itemCode'] ??
        item['varianceData']?['varianceitemCode'] ?? // Add this
        '';

    // Extract tax
    double tax =
        (variance['tax']?.toDouble() ??
        variance['variancetax']?.toDouble() ??
        itemData['tax']?.toDouble() ??
        variance['varianceTax']?.toDouble() ??
        5.0);

    // FIXED: Build proper itemData structure
    Map<String, dynamic> finalItemData = {
      "itemId": itemData['itemId'] ?? itemCode,
      "itemName": itemName,
      "itemCode": itemCode,
      "tax": tax,
      "item_Uom": uom,
      "category": itemData['category'] ?? variance['category'] ?? 'General',
    };

    // FIXED: Build proper varianceData structure
    Map<String, dynamic> finalVarianceData = {
      ...variance,
      "varianceName": variance['varianceName'] ?? itemName,
      "variance_Defaultprice":
          (variance['variance_Defaultprice'] as num?)?.toDouble() ??
          (item['price'] as num?)?.toDouble() ??
          (item['varianceData']?['variance_Defaultprice'] as num?)
              ?.toDouble() ??
          0.0,
      "variance_Uom": uom,
      "varianceitemCode": itemCode,
      "variancetax": tax,
    };

    // Extract quantity and weight
    double quantity = 1.0;
    double weight = 0.0;

    if (isKgItem) {
      quantity = 1.0; // KG items always have quantity = 1
      weight = (item["weight"] ?? item["qty"] ?? 0.0).toDouble();
    } else {
      quantity = (item["quantity"] ?? item["qty"] ?? 1.0).toDouble();
      weight = 0.0;
    }

    // FIXED: Return complete item structure
    Map<String, dynamic> result = {
      // Core identification
      "itemName": itemName,
      "itemCode": itemCode,

      // Required structures for cart
      "itemData": finalItemData,
      "varianceData": finalVarianceData,

      // Quantity/Weight
      "quantity": quantity,
      "weight": weight,

      // Pricing
      "price":
          (item['price'] ??
                  variance['variance_Defaultprice'] ??
                  finalVarianceData['variance_Defaultprice'] ??
                  0.0)
              .toDouble(),

      "total":
          (item['total'] ??
                  item['totalPrice'] ??
                  (quantity *
                          (finalVarianceData['variance_Defaultprice'] as num?)!
                              .toDouble() ??
                      0.0))
              .toDouble(),

      "totalPrice":
          (item['totalPrice'] ??
                  item['total'] ??
                  (quantity *
                          (finalVarianceData['variance_Defaultprice'] as num?)!
                              .toDouble() ??
                      0.0))
              .toDouble(),

      // Unique identifier
      "id": item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),

      // Add cartKey for merging
      "cartKey": "${itemCode}_${finalVarianceData['varianceName']}",
    };

    // Debug output
    print('✅ Normalized item:');
    print('  itemName: ${result['itemName']}');
    print('  itemCode: ${result['itemCode']}');
    print('  varianceName: ${result['varianceData']?['varianceName']}');

    return result;
  }

  void _loadMergedItemsToCart(
    BuildContext context,
    List<Map<String, dynamic>> items,
    String holdId,
  ) {
    try {
      var saleProvider = Provider.of<CurrentSaleProvider>(
        context,
        listen: false,
      );

      final normalized = items
          .map((e) => normalizeItem(Map<String, dynamic>.from(e)))
          .toList();

      saleProvider.clearItems();
      saleProvider.loadItemsFromBill(normalized, merge: true, holdId: holdId);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${normalized.length} items loaded (KG weights preserved)',
            ),
            backgroundColor: CustomColors.blueColor,
            duration: Duration(seconds: 3),
          ),
        );
      });
    } catch (e) {
      print('Error loading merged items: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: CustomColors.redColor,
          ),
        );
      });
    }
  }

  Widget _buildHeader(String title) {
    return Expanded(
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Poppins',
          color: CustomColors.whiteColor,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

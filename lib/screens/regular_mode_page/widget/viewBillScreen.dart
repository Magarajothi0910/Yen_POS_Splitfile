import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../Global/custom_button_reuse.dart';
import '../provider/cart_page_provider.dart';

import '../split_bill_screen.dart';

class ViewSavedBillsWidget extends StatelessWidget {
  const ViewSavedBillsWidget({super.key});

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
        Set<int> selectedBills = {}; // To track selected bills

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Saved Bills",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                Spacer(),
                // Split button - enabled if at least one checkbox is selected
                IconButton(
                  onPressed: selectedBills.isNotEmpty &&
                          selectedBills.length == 1
                      ? () {
                          final bill = holdBills[selectedBills.first];

                          List<Map<String, dynamic>> items = (bill['items']
                                  as List)
                              .map((item) => Map<String, dynamic>.from(item))
                              .toList();
                          showDialog(
                            context: context,
                            builder: (context) => SplitBillDialog(
                              initialItems: items, // Send original items
                            ),
                          );
                        }
                      : null, // Disable if no checkbox is selected
                  icon: Icon(Icons.call_split),
                ),
                // Merge button - enabled only if two or more checkboxes are selected
                IconButton(
                  onPressed: selectedBills.length >= 2
                      ? () {
                          _mergeBills(context, selectedBills.toList(), box);
                        }
                      : null, // Disable if less than 2 checkboxes are selected
                  icon: Icon(Icons.merge),
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
                  width: 600,
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
                                } else {
                                  selectedBills.remove(index);
                                }
                              });
                            },
                            activeColor: Colors.blue,
                          ),
                          onTap: () {
                            var saleProvider = Provider.of<CurrentSaleProvider>(
                                context,
                                listen: false);

                            List<Map<String, dynamic>> items = (bill['items']
                                    as List)
                                .map((item) => Map<String, dynamic>.from(item))
                                .toList();

                            saleProvider.loadItemsFromBill(
                              items,
                              merge: false,
                              holdId: bill['ticketName'].toString(),
                            );

                            Navigator.of(context).pop(); // Close dialog
                          },
                          title: Text('${bill['ticketName']}'),
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
                                  // Show confirmation dialog
                                  bool shouldDelete = await showDialog<bool>(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text(
                                                "Are you sure you want to delete this bill?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop(
                                                      false); // User cancels
                                                },
                                                child: const Text("Cancel"),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop(
                                                      true); // User confirms
                                                },
                                                child: const Text("Delete",
                                                    style: TextStyle(
                                                        color: Colors.red)),
                                              ),
                                            ],
                                          );
                                        },
                                      ) ??
                                      false; // Default to false if user dismisses the dialog

                                  // If confirmed, delete the bill from Hive
                                  if (shouldDelete) {
                                    await box.deleteAt(index);
                                    setState(() {
                                      holdBills.removeAt(index);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Bill deleted successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
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

  void _mergeBills(
      BuildContext context, List<int> selectedBillIndices, Box box) async {
    // Step 1: Check if no bills are selected
    if (selectedBillIndices.isEmpty) {
      // Log the empty selection
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bills selected to merge!'),
          backgroundColor: Colors.red,
          margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Step 2: Initialize the merged bill map
    Map<String, dynamic> mergedBill = {
      'holdId':
          DateTime.now().millisecondsSinceEpoch.toString(), // Unique hold ID
      'items': [],
      'total': 0.0,
      'date': DateTime.now().toIso8601String(),
      'status': 'hold',
      'ticketName': selectedBillIndices
          .map((index) => "Ticket ${index + 1}")
          .join(" + "), // Merged ticket name
    };

    double totalAmount = 0.0;

    // Step 3: Aggregate selected bills
    for (int index in selectedBillIndices) {
      Map<String, dynamic> bill = box.getAt(index);

      // Ensure 'items' is a list and process correctly
      // ignore: unused_local_variable
      List<dynamic> itemsList = bill['items'] as List<dynamic>;

      totalAmount += double.parse(bill['total'].toString());
      mergedBill['items'].addAll(bill['items']);
    }
    mergedBill['total'] = totalAmount;

    // Step 4: Save the merged bill to Hive
    await box.add(mergedBill);

    // Step 5: Prepare data for API posting (optional)
    // ignore: unused_local_variable
    Map<String, dynamic> apiData = {
      'holdId': mergedBill['holdId'],
      'date': mergedBill['date'],
      'items': mergedBill['items'],
      'total': mergedBill['total'].toString(),
      'status': 'hold',
      'ticketName': mergedBill['ticketName'],
    };

    // Step 6: Optionally clear the selected data from Hive
    for (int index in selectedBillIndices) {
      await box.deleteAt(index); // Remove selected bills
    }

    // Step 7: Log and show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bills merged successfully!'),
        backgroundColor: Colors.green,
        margin: EdgeInsets.only(left: 20, bottom: 20, right: 680),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Optionally post merged data to API (uncomment if needed)
    // try {
    //   final response = await http.post(
    //     Uri.parse('http://192.168.1.130:8888/fastapi/holds/'),
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

    Navigator.pop(context); // Close the dialog after the operation
  }

  Widget _buildHeader(String title) {
    return Expanded(
      child: Text(
        title,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: 'ViewBills',
      onPressed: () => _viewBills(context),
      backgroundColor: Colors.white70,
      textColor: Colors.blue,
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';

// import '../../../Global/custom_button_reuse.dart';
// import '../provider/cart_page_provider.dart';

// class ViewSavedBillsWidget extends StatelessWidget {
//   const ViewSavedBillsWidget({super.key});

//   void _viewBills(BuildContext context) async {
//     var box = await Hive.openBox('holdinvoiceBox');
//     if (box.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text(
//             'No saved bills!',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 2),
//           behavior: SnackBarBehavior.floating,
//           margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//       return;
//     }

//     List<Map<String, dynamic>> holdBills = box.values
//         .where((bill) =>
//             (bill as Map)['status'] == 'hold' && (bill)['items'].isNotEmpty)
//         .map((bill) => Map<String, dynamic>.from(bill as Map))
//         .toList();

//     if (holdBills.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text(
//             'No hold bills with items found!',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           backgroundColor: Colors.orange,
//           duration: const Duration(seconds: 2),
//           behavior: SnackBarBehavior.floating,
//           margin: const EdgeInsets.only(left: 20, bottom: 20, right: 680),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//       return;
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text(
//             'Saved Bills',
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               color: Colors.blueAccent,
//             ),
//           ),
//           content: SizedBox(
//             width: 400,
//             height: 350,
//             child: ListView.builder(
//               itemCount: holdBills.length,
//               itemBuilder: (context, index) {
//                 final bill = holdBills[index];
//                 DateTime billDate = DateTime.parse(bill['date']);
//                 String formattedDate = DateFormat('dd-MM-yy').format(billDate);
//                 String formattedTime = DateFormat('hh:mm').format(billDate);

//                 return Card(
//                   elevation: 2,
//                   margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: ListTile(
//                     leading: Icon(
//                       Icons.receipt_long,
//                       color: Colors.blueAccent,
//                     ),
//                     title: Text(
//                       'Bill #${index + 1}',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const SizedBox(height: 4),
//                         Row(
//                           children: [
//                             const Icon(Icons.date_range, size: 16, color: Colors.grey),
//                             const SizedBox(width: 4),
//                             Text('Date: $formattedDate'),
//                           ],
//                         ),
//                         Row(
//                           children: [
//                             const Icon(Icons.access_time, size: 16, color: Colors.grey),
//                             const SizedBox(width: 4),
//                             Text('Time: $formattedTime'),
//                           ],
//                         ),
//                         Row(
//                           children: [
//                             const Icon(Icons.attach_money, size: 16, color: Colors.grey),
//                             const SizedBox(width: 4),
//                             Text('Total: ₹${bill['total']}'),
//                           ],
//                         ),
//                       ],
//                     ),
//                     trailing: IconButton(
//                       icon: const Icon(Icons.arrow_forward_ios, color: Colors.blueAccent),
//                       onPressed: () {
//                         var saleProvider = Provider.of<CurrentSaleProvider>(
//                           context,
//                           listen: false,
//                         );
//                         saleProvider.loadItemsFromBill(bill['items']);
//                         print('Selected Bill: $bill');
//                         Navigator.of(context).pop();
//                       },
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text(
//                 'Close',
//                 style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: CustomButton(
//         text: 'View Saved Bills',
//         onPressed: () => _viewBills(context),
//         backgroundColor: Colors.blueAccent,
//         textColor: Colors.white,
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Import the package
import 'package:yenposapp/screens/sales_order/globals.dart';

import '../../Global/custom_sized_box.dart';
import 'provider/cart_page_provider.dart';

class SplitBillDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initialItems;

  const SplitBillDialog({Key? key, required this.initialItems})
      : super(key: key);

  @override
  _SplitBillDialogState createState() => _SplitBillDialogState();
}

class _SplitBillDialogState extends State<SplitBillDialog> {
  List<List<Map<String, dynamic>>> tickets = [];
  List<Set<int>> selectedItems = [];
  List<String> ticketTitles = [];

  TextEditingController titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _promptForTicketTitle();
  }

  void _promptForTicketTitle() {
    String formattedTime =
        DateFormat('hh:mm a').format(DateTime.now()); // Format time
    TextEditingController titleController = TextEditingController(
        text: "Ticket - $formattedTime"); // Initialize with time

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              "Enter Ticket Title",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Enter ticket name",
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
                  child: Text("Cancel")),
              TextButton(
                onPressed: () {
                  String baseName = titleController.text.trim();
                  if (baseName.isEmpty) return;

                  setState(() {
                    ticketTitles.add("$baseName - 1");
                    ticketTitles.add("$baseName - 2");

                    tickets.add(List.from(widget.initialItems));
                    selectedItems.add({});

                    tickets.add([]);
                    selectedItems.add({});
                  });

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
    });
  }

  double calculateTotal(List<Map<String, dynamic>> items) {
    return items.fold(
      0.0,
      (sum, item) {
        double price = (item['varianceData']?['variance_Defaultprice'] ?? 0.0)
            .toDouble(); // Ensure variance_Defaultprice is not null
        int quantity =
            (item['quantity'] ?? 0).toInt(); // Ensure quantity is not null
        return sum + (price * quantity);
      },
    );
  }

  void moveSelectedItems(int fromIndex, int toIndex) {
    setState(() {
      if (fromIndex == toIndex) return;

      final selectedIndexes = selectedItems[fromIndex].toList()
        ..sort((a, b) => b.compareTo(a));

      final selectedItemsList =
          selectedIndexes.map((index) => tickets[fromIndex][index]).toList();

      tickets[toIndex].addAll(selectedItemsList);

      tickets[fromIndex] = tickets[fromIndex]
          .asMap()
          .entries
          .where((entry) => !selectedIndexes.contains(entry.key))
          .map((entry) => entry.value)
          .toList();

      selectedItems[fromIndex].clear();
    });
  }

  void addNewTicket() {
    setState(() {
      if (ticketTitles.isNotEmpty) {
        // Extract the base name by removing the last number
        String baseName = ticketTitles[0]
            .substring(0, ticketTitles[0].lastIndexOf('-'))
            .trim();

        // Determine the next ticket number
        int nextTicketNumber = ticketTitles.length + 1;

        // Generate the new ticket name
        String newTicketTitle = "$baseName - $nextTicketNumber";

        // Add new ticket panel
        tickets.add([]);
        selectedItems.add({});
        ticketTitles.add(newTicketTitle);

      }
    });
  }

  void deleteTicket(int index) {
    if (tickets.length <= 1) {
      // Ensure at least one ticket remains
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("At least one ticket must remain.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Confirm Deletion",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to delete '${ticketTitles[index]}'?",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  // Move items back to the first ticket if possible
                  if (index != 0) {
                    tickets[0]
                        .addAll(tickets[index]); // Move items to first ticket
                  } else if (tickets.length > 1) {
                    tickets[1]
                        .addAll(tickets[index]); // Move to next ticket if first
                  }


                  // Remove the deleted ticket
                  tickets.removeAt(index);
                  selectedItems.removeAt(index);
                  ticketTitles.removeAt(index);
                });

                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Delete",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 1,
        height: MediaQuery.of(context).size.height * 1,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: addNewTicket,
                    child: Text(
                      "Add Ticket",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  CustomSizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Provider.of<CurrentSaleProvider>(context, listen: false)
                          .saveBillsplitBill(context, tickets, ticketTitles);
                      cartItems.clear();
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Save Ticket",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  CustomSizedBox(width: 20),
                  IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.close)),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tickets.length,
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    return Row(
                      children: [
                        TicketPanel(
                          ticketTitles: ticketTitles,
                          title: ticketTitles[index],
                          items: tickets[index],
                          selectedItems: selectedItems[index],
                          onMoveSelected: (toIndex) {
                            moveSelectedItems(index, toIndex);
                          },
                          buttonText: 'MOVE',
                          isButtonEnabled: selectedItems[index].isNotEmpty,
                          totalAmount: calculateTotal(tickets[index]),
                          ticketCount: tickets.length,
                          currentTicketIndex: index,
                          onItemSelected: (itemIndex, isSelected) {
                            setState(() {
                              if (isSelected) {
                                selectedItems[index].add(itemIndex);
                              } else {
                                selectedItems[index].remove(itemIndex);
                              }
                            });
                          },
                          onDelete: () => deleteTicket(index),
                        ),
                        CustomSizedBox(width: 10),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TicketPanel extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final Set<int> selectedItems;
  final Function(int) onMoveSelected;
  final String buttonText;
  final double totalAmount;
  final bool isButtonEnabled;
  final Function(int, bool) onItemSelected;
  final int ticketCount;
  final int currentTicketIndex;
  final VoidCallback onDelete; // Add this to handle delete
  final List<String> ticketTitles;
  const TicketPanel({
    Key? key,
    required this.title,
    required this.items,
    required this.selectedItems,
    required this.onMoveSelected,
    required this.buttonText,
    required this.totalAmount,
    required this.isButtonEnabled,
    required this.onItemSelected,
    required this.ticketCount,
    required this.currentTicketIndex,
    required this.onDelete, // Include in constructor
    required this.ticketTitles,
  }) : super(key: key);

  @override
  _TicketPanelState createState() => _TicketPanelState();
}

class _TicketPanelState extends State<TicketPanel> {
  int? selectedTicket; // Track selected ticket

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_rounded, color: Colors.red),
                onPressed:
                    widget.onDelete, // Call delete function passed from parent
              ),
            ],
          ),
          Divider(color: Colors.grey.shade300),

          // Items List
          Expanded(
            child: ListView.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                var item = widget.items[index];
                return Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(vertical: 5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(10),
                    tileColor: Colors.grey.shade100,
                    title: Text(
                      '${item['varianceData']?['varianceName'] ?? "Unknown"} x ${item['quantity']}',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '₹${(item['varianceData']?['variance_Defaultprice'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.blue),
                    ),
                    trailing: Checkbox(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      value: widget.selectedItems.contains(index),
                      onChanged: (value) {
                        widget.onItemSelected(index, value ?? false);
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // Total Price Section
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.blue.shade50,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                      child: Text(
                    'Total',
                    style: TextStyle(
                        color: Colors.black87, fontWeight: FontWeight.bold),
                  )),
                  Text(
                    '₹${widget.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: Colors.black87, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 15),

          // Move Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.isButtonEnabled ? Colors.blue : Colors.grey,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: widget.isButtonEnabled
                    ? () {
                        _showMoveTicketDialog(
                            context); // Show the move ticket pop-up
                      }
                    : null,
                child: Text(
                  widget.buttonText,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              // CustomButton(
              //     text: "Pay",
              //     onPressed: () {
              //       double totalAmount = 12;
              //       if (totalAmount != 0) {
              //         showDialog(
              //           context: context,
              //           builder: (BuildContext context) {
              //             return Dialog(
              //               child: CustomSizedBox(
              //                 width: MediaQuery.of(context).size.width * 0.5,
              //                 child: SalesInvoicePayAndPrint(
              //                   totalAmount: totalAmount,
              //                   holdBillId: '',
              //                 ),
              //               ),
              //             );
              //           },
              //         );
              //       }
              //     }),
            ],
          ),

          SizedBox(height: 10),

          // Move Dropdown
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 20),
          //   child: DropdownButtonFormField<int>(
          //     value: selectedTicket,
          //     hint: Text('Move to Ticket'),
          //     decoration: InputDecoration(
          //       border: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(8),
          //         borderSide: BorderSide(color: Colors.blue.shade300),
          //       ),
          //       filled: true,
          //       fillColor: Colors.grey.shade100,
          //     ),
          //     onChanged: (value) {
          //       setState(() {
          //         selectedTicket = value;
          //       });
          //     },
          //     items: List.generate(widget.ticketCount, (index) {
          //       if (index != widget.currentTicketIndex) {
          //         return DropdownMenuItem(
          //           value: index,
          //           child: Text(widget.title), // Show actual ticket name
          //         );
          //       }
          //       return null;
          //     }).whereType<DropdownMenuItem<int>>().toList(),
          //   ),
          // ),

          SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showMoveTicketDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Softer corners
          ),
          title: Text(
            "Move to Ticket",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.blueAccent,
            ),
          ),
          content: Container(
            width: 300,
            constraints: BoxConstraints(
              maxHeight: 300, // Prevents content overflow
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "Select a ticket to move the selected items.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),
                  Divider(color: Colors.grey.shade300), // Light separator

                  // Scrollable ticket selection
                  Column(
                    children: List.generate(widget.ticketCount, (index) {
                      if (index != widget.currentTicketIndex) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Close pop-up
                            widget.onMoveSelected(index); // Move items
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 6),
                            padding: EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blueAccent),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  widget.ticketTitles[index], // Ticket name
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios,
                                    size: 16, color: Colors.blueAccent),
                              ],
                            ),
                          ),
                        );
                      }
                      return SizedBox(); // Skip the current ticket
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Center(
                  child: Text(
                    "Cancel",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

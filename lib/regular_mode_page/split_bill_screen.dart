import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Widget/custom_colors.dart';
import 'package:yenpos/Global/Widget/custom_sized_box.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/more_page/widgets/other.dart';
import 'package:yenpos/regular_mode_page/widget/custom_reusable_widget/ticket_generator.dart';

import 'provider/cart_page_provider.dart';

class SplitBillDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initialItems;

  const SplitBillDialog({Key? key, required this.initialItems}) : super(key: key);

  @override
  _SplitBillDialogState createState() => _SplitBillDialogState();
}

class _SplitBillDialogState extends State<SplitBillDialog> {
  List<List<Map<String, dynamic>>> tickets = [];
  List<String> ticketTitles = [];

  @override
  void initState() {
    super.initState();
    _initializeTickets();
  }

  void _initializeTickets() async {
    final baseTitle = await TicketSequenceGenerator.generate();
    setState(() {
      ticketTitles.add("$baseTitle - 1");
      ticketTitles.add("$baseTitle - 2");
      tickets.add(List.from(widget.initialItems));
      tickets.add([]);
    });
  }

  double calculateTotal(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, item) {
      double price = (item['varianceData']?['variance_Defaultprice'] ?? 0.0).toDouble();
      double quantity = (item['quantity'] ?? 0).toDouble();
      return sum + (price * quantity);
    });
  }

  void moveItem(int fromTicketIndex, int itemIndex, int toTicketIndex) {
    if (fromTicketIndex == toTicketIndex) return;

    final item = tickets[fromTicketIndex][itemIndex];
    int qtyToMove = item['quantity'].toInt();

    // Check if it's a weight item
    final String uom = (item['varianceData']?['variance_Uom']?.toString().toLowerCase() ?? '');
    final bool isWeightItem = uom.contains('kg') || uom.contains('kgs') || uom.contains('gm');

    // Only ask for quantity separation for NON-weight items with quantity > 1
    if (!isWeightItem && qtyToMove > 1) {
      showDialog(
        context: context,
        builder: (context) {
          TextEditingController qtyController = TextEditingController(text: qtyToMove.toString());
          return AlertDialog(
            backgroundColor: CustomColors.whiteColor,
            title: Text('Split Quantity for ${item['varianceData']['varianceName']}'),
            content: TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'Quantity to move (1 to $qtyToMove)', border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins',color: CustomColors.grey)),
              ),
              TextButton(
                onPressed: () {
                  int? newQty = int.tryParse(qtyController.text);
                  if (newQty != null && newQty > 0 && newQty <= qtyToMove) {
                    setState(() {
                      // Create a deep copy of the item
                      final movedItem = _deepCopyItem(item);
                      movedItem['quantity'] = newQty;

                      tickets[toTicketIndex].add(movedItem);

                      // Update the original item's quantity
                      item['quantity'] = item['quantity'] - newQty;
                      if (item['quantity'] <= 0) {
                        tickets[fromTicketIndex].removeAt(itemIndex);
                      }
                    });
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid integer quantity!'),
                        backgroundColor: CustomColors.redColor,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('OK', style: TextStyle(fontFamily: 'Poppins',color: CustomColors.blueColor)),
              ),
            ],
          );
        },
      );
    } else {
      // For weight items OR quantity items with quantity = 1, move the entire item
      setState(() {
        tickets[toTicketIndex].add(item);
        tickets[fromTicketIndex].removeAt(itemIndex);
      });
    }
  }

  Map<String, dynamic> _deepCopyItem(Map<String, dynamic> item) {
    return {
      ...item,
      'varianceData': Map<String, dynamic>.from(item['varianceData'] ?? {}),
      'uniqueId': '${DateTime.now().millisecondsSinceEpoch}-${item['itemCode']}',
    };
  }

  void addNewTicket() async {
    final baseTitle = await TicketSequenceGenerator.generate();
    setState(() {
      String baseName = baseTitle.split(' - ')[0];
      int nextTicketNumber = ticketTitles.length + 1;
      String newTicketTitle = "$baseName - $nextTicketNumber";
      tickets.add([]);
      ticketTitles.add(newTicketTitle);
    });
  }

  void deleteTicket(int index) {
    if (tickets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("At least one ticket must remain.")));
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: CustomColors.whiteColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Confirm Deletion", style: TextStyle(fontFamily: 'Poppins',fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to delete '${ticketTitles[index]}'?", style: const TextStyle(fontFamily: 'Poppins',fontSize: 16)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () {
                setState(() {
                  // Move items to first ticket before deletion
                  if (index != 0) {
                    tickets[0].addAll(tickets[index]);
                  } else if (tickets.length > 1) {
                    tickets[1].addAll(tickets[index]);
                  }
                  tickets.removeAt(index);
                  ticketTitles.removeAt(index);
                });
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: CustomColors.redColor,
                foregroundColor: CustomColors.whiteColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Delete", style: TextStyle(fontFamily: 'Poppins',fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CustomColors.whiteColor,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomColors.blueColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: addNewTicket,
                    child: const Text("Add Ticket", style: TextStyle(fontFamily: 'Poppins',color: CustomColors.whiteColor, fontSize: 16)),
                  ),
                  const CustomSizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomColors.blueColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      // Remove empty tickets before saving
                      List<List<Map<String, dynamic>>> nonEmptyTickets = [];
                      List<String> nonEmptyTicketTitles = [];

                      for (int i = 0; i < tickets.length; i++) {
                        if (tickets[i].isNotEmpty) {
                          nonEmptyTickets.add(tickets[i]);
                          nonEmptyTicketTitles.add(ticketTitles[i]);
                        }
                      }

                      if (nonEmptyTickets.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('At least one ticket must have items!'),
                            backgroundColor: CustomColors.redColor,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      Provider.of<CurrentSaleProvider>(
                        context,
                        listen: false,
                      ).saveBillsplitBill(context, nonEmptyTickets, nonEmptyTicketTitles);

                      Navigator.pop(context);
                    },
                    child: const Text("Save Tickets", style: TextStyle(fontFamily: 'Poppins',color: CustomColors.whiteColor, fontSize: 16)),
                  ),
                  const CustomSizedBox(width: 20),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    return Row(
                      children: [
                        TicketPanel(
                          title: ticketTitles[index],
                          items: tickets[index],
                          ticketCount: tickets.length,
                          currentTicketIndex: index,
                          ticketTitles: ticketTitles,
                          onItemDropped: (data) {
                            moveItem(data['fromTicketIndex'], data['index'], index);
                          },
                          onDelete: () => deleteTicket(index),
                        ),
                        const CustomSizedBox(width: 10),
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

class TicketPanel extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final int ticketCount;
  final int currentTicketIndex;
  final List<String> ticketTitles;
  final Function(Map<String, dynamic>) onItemDropped;
  final VoidCallback onDelete;

  const TicketPanel({
    Key? key,
    required this.title,
    required this.items,
    required this.ticketCount,
    required this.currentTicketIndex,
    required this.ticketTitles,
    required this.onItemDropped,
    required this.onDelete,
  }) : super(key: key);

  double calculateTotal(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, item) {
      double price = (item['varianceData']?['variance_Defaultprice'] ?? 0.0).toDouble();
      double quantity = (item['quantity'] ?? 0).toDouble();
      return sum + (price * quantity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<Map<String, dynamic>>(
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 320,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: CustomColors.whiteColor,
            border: Border.all(
              color: candidateData.isNotEmpty ? CustomColors.blueColor : CustomColors.grey,
              width: candidateData.isNotEmpty ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        title,
                        style: const TextStyle(fontFamily: 'Poppins',color: CustomColors.black, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (ticketCount > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: CustomColors.redColor),
                      onPressed: onDelete,
                    ),
                ],
              ),
              const Divider(color: CustomColors.grey),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text("No items in this ticket"))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          var item = items[index];

                          // Check if it's a weight item
                          final String uom = (item['varianceData']?['variance_Uom']?.toString().toLowerCase() ?? '');
                          final bool isWeightItem = uom.contains('kg') || uom.contains('kgs') || uom.contains('gm');

                          // Determine display text based on item type
                          String displayText;
                          if (isWeightItem) {
                            double weight = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                            displayText = '${item['varianceData']?['varianceName'] ?? "Unknown"} ${weight.toStringAsFixed(3)} kg';
                          } else {
                            int quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                            displayText = '${item['varianceData']?['varianceName'] ?? "Unknown"} x $quantity';
                          }

                          return Draggable<Map<String, dynamic>>(
                            data: {'item': item, 'index': index, 'fromTicketIndex': currentTicketIndex},
                            feedback: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 300,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: CustomColors.blueColor, borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  displayText,
                                  style: const TextStyle(fontFamily: 'Poppins',color: Colors.black87, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(opacity: 0.3, child: buildItemTile(item, isWeightItem)),
                            child: buildItemTile(item, isWeightItem),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: CustomColors.blueColor),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(fontFamily: 'Poppins',color: CustomColors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '₹${calculateTotal(items).toStringAsFixed(2)}',
                        style: const TextStyle(fontFamily: 'Poppins',color: CustomColors.black, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
      onWillAccept: (data) => data != null && data['fromTicketIndex'] != currentTicketIndex,
      onAccept: (data) {
        onItemDropped(data);
      },
    );
  }

  Widget buildItemTile(Map<String, dynamic> item, bool isWeightItem) {
    // Determine display text based on item type
    String displayText;
    if (isWeightItem) {
      double weight = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      displayText = '${item['varianceData']?['varianceName'] ?? "Unknown"} ${weight.toStringAsFixed(3)} kg';
    } else {
      int quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      displayText = '${item['varianceData']?['varianceName'] ?? "Unknown"} x $quantity';
    }

    return Card(
      elevation: 2,
      color: CustomColors.blueColor,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        title: Text(
          displayText,
          style: const TextStyle(fontFamily: 'Poppins',color: CustomColors.whiteColor, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '₹${(item['varianceData']?['variance_Defaultprice'] ?? 0).toStringAsFixed(2)}',
          style: const TextStyle(fontFamily: 'Poppins',color: CustomColors.whiteColor),
        ),
      ),
    );
  }
}

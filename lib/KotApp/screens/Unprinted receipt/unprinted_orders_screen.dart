import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'provider/unprinted_orders_provider.dart';

class UnprintedOrdersScreen extends StatefulWidget {
  const UnprintedOrdersScreen({super.key});

  @override
  State<UnprintedOrdersScreen> createState() => _UnprintedOrdersScreenState();
}

class _UnprintedOrdersScreenState extends State<UnprintedOrdersScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      Provider.of<UnprintedOrdersProvider>(context, listen: false)
          .fetchUnprintedOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RePrint Orders"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<UnprintedOrdersProvider>(context, listen: false)
                  .fetchUnprintedOrders();
            },
          ),
        ],
      ),
      body: Consumer<UnprintedOrdersProvider>(
        builder: (context, provider, child) {
          if (provider.unprintedOrders.isEmpty) {
            return const Center(
              child: Text(
                "No pending print orders",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.unprintedOrders.length,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            itemBuilder: (context, index) {
              final order = provider.unprintedOrders[index];
              return GestureDetector(
                onTap: () => _showOrderDetails(context, order),
                child: Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        /// **Left Column: Table & Waiter**
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${order["tableNumber"]}",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Seat: ${order["seat"]}",
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              "Waiter: ${order["waiter"]}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),

                        /// **Right Column: Total & Reprint Button**
                        Column(
                          children: [
                            Text(
                              "₹${order["total"].toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 5),
                            ElevatedButton.icon(
                              onPressed: () => provider.retryPrint(
                                  context, order), // Print Action
                              icon: const Icon(Icons.print),
                              label: const Text(""),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// **🟢 Show Order Details in a Bottom Sheet**
  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// **Header: Table & Token**
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    " ${order["tableNumber"]}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Token: ${order["tokenNumber"]}",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Divider(),

              /// **Order Details (Grid Layout)**
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 3,
                children: [
                  _orderDetail("Date", order["date"]),
                  _orderDetail("Time", order["time"]),
                  _orderDetail("Seat", order["seat"]),
                  _orderDetail("Waiter", order["waiter"]),
                  _orderDetail("User", order["userName"]),
                  _orderDetail(
                      "Total", "₹${order["total"].toStringAsFixed(2)}"),
                  _orderDetail("Order Type", order["orderType"]),
                  _orderDetail("IP Address", order["ipAddress"]),
                ],
              ),

              const SizedBox(height: 10),

              /// **Items Ordered**
              const Text(
                "Items Ordered:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              ..._buildOrderItems(order["seatOrders"]),

              const SizedBox(height: 20),

              /// **Action Buttons**
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text("Close"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.red, // Optional: Change button color to red
                      foregroundColor: Colors.white, // Text/Icon color
                    ),
                  ),
                  // ElevatedButton.icon(
                  //   onPressed: () {
                  //     Provider.of<UnprintedOrdersProvider>(context,
                  //             listen: false)
                  //         .retryPrint(context, order);
                  //     Navigator.pop(context);
                  //   },
                  //   icon: const Icon(Icons.print),
                  //   label: const Text("Reprint"),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: Colors.blue,
                  //     foregroundColor: Colors.white,
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// **Helper Function to Display Order Details**
  Widget _orderDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// **Helper Function to Display Ordered Items**
  List<Widget> _buildOrderItems(List<dynamic> items) {
    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "• ${item["itemName"]} (Qty: ${item["quantity"]})",
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (item["weight"] != null && item["weight"] > 0)
              Text(
                "Wt: ${item["weight"]}g",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
          ],
        ),
      );
    }).toList();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'provider/unprinted_orders_provider.dart';

// 🔔 ChangeNotifier to manage UnprintedOrdersScreen state
class UnprintedOrdersScreenState extends ChangeNotifier {
  final Map<String, bool> _isPrintButtonPressed = {};

  // 🔔 Get the print button state for an order
  bool isPrintButtonPressed(String orderId) {
    return _isPrintButtonPressed[orderId] ?? false;
  }

  // 🔔 Update print button state
  void setPrintButtonPressed(String orderId, bool isPressed) {
    _isPrintButtonPressed[orderId] = isPressed;
    debugPrint("🖨️ Print button state for $orderId: $isPressed");
    notifyListeners();
  }

  // 🔔 Clear all print button states
  void clearPrintButtonStates() {
    _isPrintButtonPressed.clear();
    debugPrint("🧹 Cleared all print button states");
    notifyListeners();
  }
}

class UnprintedOrdersScreen extends StatefulWidget {
  const UnprintedOrdersScreen({super.key});

  @override
  State<UnprintedOrdersScreen> createState() => _UnprintedOrdersScreenState();
}

class _UnprintedOrdersScreenState extends State<UnprintedOrdersScreen> {
  late UnprintedOrdersScreenState state;

  @override
  void initState() {
    super.initState();
    state = UnprintedOrdersScreenState(); // 🔔 Initialize ChangeNotifier
    Future.delayed(Duration.zero, () {
      _fetchOrders();
    });
  }

  @override
  void dispose() {
    state.dispose(); // 🧹 Dispose ChangeNotifier
    super.dispose();
  }

  // Fetch orders and reset button states
  void _fetchOrders() {
    Provider.of<UnprintedOrdersProvider>(context, listen: false).fetchUnprintedOrders().then((_) {
      // Reset button states after fetching new orders
      state.clearPrintButtonStates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text("RePrint Orders"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchOrders,
            ),
          ],
        ),
        body: Consumer2<UnprintedOrdersProvider, UnprintedOrdersScreenState>(
          builder: (context, provider, state, child) {
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
                final orderId = order["hiveOrderId"]?.toString() ?? index.toString();
                debugPrint("Order $index: $order");
                return GestureDetector(
                  onTap: () => _showOrderDetails(context, order),
                  child: Card(
                    color: Colors.white,
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left Column: Table & Waiter (Constrained width)
                          Flexible(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${order["tableNumber"] ?? 'N/A'}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  "Seat: ${order["seat"] ?? 'N/A'}",
                                  style: const TextStyle(fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  "₹${(order["total"] as num?)?.toStringAsFixed(2) ?? '0.00'}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  "Waiter: ${order["waiter"] ?? 'Unknown'}",
                                  style: const TextStyle(fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          // Right Column: Print Button (Compact)
                          Flexible(
                            flex: 1,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: state.isPrintButtonPressed(orderId)
                                      ? null
                                      : () {
                                          state.setPrintButtonPressed(orderId, true);
                                          provider.retryPrint(context, order).then((_) {
                                            state.setPrintButtonPressed(orderId, false);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("Order ${order["hiveOrderId"] ?? index} printed successfully"),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }).catchError((e) {
                                            debugPrint("Error printing order $orderId: $e");
                                            state.setPrintButtonPressed(orderId, false);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("Failed to print order: $e"),
                                                duration: const Duration(seconds: 3),
                                              ),
                                            );
                                          });
                                        },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    backgroundColor: Colors.blue[500],
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(60, 40),
                                    disabledBackgroundColor: Colors.grey[400],
                                    disabledForegroundColor: Colors.white,
                                  ),
                                  child: state.isPrintButtonPressed(orderId)
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.print, size: 20),
                                ),
                              ],
                            ),
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
      ),
    );
  }

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
              // Header: Table & Token
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${order["tableNumber"] ?? 'N/A'}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "Token: ${order["tokenNumber"] ?? 'N/A'}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const Divider(),

              // Order Details (Grid Layout)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _orderDetail("Date", order["date"] ?? 'N/A'),
                  _orderDetail("Time", order["time"] ?? 'N/A'),
                  _orderDetail("Seat", order["seat"] ?? 'N/A'),
                  _orderDetail("Waiter", order["waiter"] ?? 'Unknown'),
                  _orderDetail("User", order["userName"] ?? 'N/A'),
                  _orderDetail(
                    "Total",
                    "₹${(order["total"] as num?)?.toStringAsFixed(2) ?? '0.00'}",
                  ),
                  _orderDetail("Order Type", order["orderType"] ?? 'N/A'),
                  _orderDetail("IP Address", order["ipAddress"] ?? 'N/A'),
                ],
              ),

              const SizedBox(height: 10),

              // Items Ordered
              const Text(
                "Items Ordered:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              ..._buildOrderItems(order["seatOrders"] ?? []),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    label: const Text("Close"),
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

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
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOrderItems(List<dynamic> items) {
    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "• ${item["itemName"] ?? 'Unknown'} (Qty: ${item["quantity"] ?? 0})",
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (item["weight"] != null && (item["weight"] as num) > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  "Wt: ${item["weight"]}g",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }
}

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Models/held_order_model.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Widgets/restore_order_date.dart';

// ✅ Extract latest approvalStatus safely
String approvalStatus = '';

void showDiscountStatus(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildApproveOrdersHeader(),
                Expanded(
                  child: _buildApproveOrdersList(
                    context, // pass safe parent context
                    scrollController,
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

Widget _buildApproveOrdersHeader() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: Colors.blue.shade600,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      children: [
        const Center(
          child: Text(
            "Approval Orders Status",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    ),
  );
}

Map<String, dynamic> convertToMapStringDynamic(Map<dynamic, dynamic> map) {
  final result = <String, dynamic>{};
  map.forEach((key, value) {
    final newKey = key.toString(); // ensure key is String
    if (value is Map) {
      result[newKey] = convertToMapStringDynamic(
        Map<dynamic, dynamic>.from(value),
      );
    } else if (value is List) {
      result[newKey] = value.map((e) {
        if (e is Map) {
          return convertToMapStringDynamic(Map<dynamic, dynamic>.from(e));
        } else {
          return e;
        }
      }).toList();
    } else {
      result[newKey] = value;
    }
  });
  return result;
}

Future<List<HeldOrder>> getSavedApprovalOrder() async {
  var approvalOrderBox = HiveManager.salesApprovalOrder;

  if (approvalOrderBox.isEmpty) {
    return [];
  }

  final List<HeldOrder> approvalOrders = approvalOrderBox.values.map((order) {
    // Convert Hive map to Map<String, dynamic> safely
    final orderMap = convertToMapStringDynamic(
      Map<dynamic, dynamic>.from(order),
    );

    // Flatten 'data' map
    final dataMap = convertToMapStringDynamic(
      Map<dynamic, dynamic>.from(orderMap['data'] ?? {}),
    );
    final combinedMap = {...orderMap, ...dataMap};
    combinedMap.remove('data');

    final heldOrder = HeldOrder.fromMap(combinedMap);

    return heldOrder;
  }).toList();

  return approvalOrders;
}

Widget _buildApproveOrdersList(
  BuildContext context,
  ScrollController scrollController,
) {
  return FutureBuilder<List<HeldOrder>>(
    future: getSavedApprovalOrder(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        return Center(
          child: Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const Center(
          child: Text(
            'No approve orders available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        );
      }

      final orders = snapshot.data!;

      return ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildApproveOrderListItem(context, orders[index]);
        },
      );
    },
  );
}

Widget _buildApproveOrderListItem(BuildContext context, HeldOrder order) {
  String status = 'Unknown';

  if (order.approvalDetails != null && order.approvalDetails!.isNotEmpty) {
    try {
      final lastDetailWithStatus = order.approvalDetails!.lastWhere(
        (d) => d.approvalStatus != null && d.approvalStatus!.isNotEmpty,
        orElse: () => order.approvalDetails!.last,
      );
      status = lastDetailWithStatus.approvalStatus ?? 'Unknown';
    } catch (e, stackTrace) {
      status = 'Unknown';
    }
  }

  // Check if order is approved
  final bool isApproved = status.toLowerCase() == 'approved';
  print("status for approval: $status");
  print("isApproved: $isApproved");
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
    child: Card(
      color: isApproved
          ? Colors.grey.shade200.withOpacity(0.6) // Lighter color for approved
          : Colors.white.withOpacity(0.8),
      elevation: isApproved ? 2 : 6,
      shadowColor: Colors.black.withOpacity(isApproved ? 0.04 : 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (!isApproved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order cannot be restored because it is "$status".',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }

          // ✅ Approved → allow restore
          final customerProvider = Provider.of<CustomerScreenProvider>(
            context,
            listen: false,
          );
          final cartProvider = Provider.of<CartProvider>(
            context,
            listen: false,
          );
          final selectionProvider = Provider.of<CartSelectionProvider>(
            context,
            listen: false,
          );

          _restoreOrderData(
            context,
            order,
            customerProvider: customerProvider,
            cartProvider: cartProvider,
            selectionProvider: selectionProvider,
          );
        }, // ❌ Disable tap for all non-approved statuses
        splashColor: isApproved
            ? Colors.transparent
            : Colors.blue.withOpacity(0.05),
        highlightColor: isApproved
            ? Colors.transparent
            : Colors.blueAccent.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: isApproved
                  ? [
                      Colors.grey.shade100.withOpacity(0.8),
                      Colors.grey.shade200.withOpacity(0.3),
                    ]
                  : [
                      Colors.white.withOpacity(0.95),
                      Colors.blueGrey.withOpacity(0.02),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: isApproved ? Colors.grey : Colors.black87,
                        letterSpacing: 0.3,
                        decoration: isApproved
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(status, isApproved: isApproved),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 2,
                width: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isApproved
                        ? [Colors.grey, Colors.grey.shade400]
                        : [Colors.blueAccent, Colors.lightBlueAccent],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.calendar_month_rounded,
                "Delivery Date: ${order.deliveryDate ?? '--'}",
                iconColor: isApproved ? Colors.grey : Colors.deepPurpleAccent,
                isApproved: isApproved,
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                Icons.access_time_filled_rounded,
                "Delivery Time: ${order.deliveryTime ?? '--'}",
                iconColor: isApproved ? Colors.grey : Colors.orangeAccent,
                isApproved: isApproved,
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                Icons.verified_rounded,
                "Approval Status: $status",
                iconColor: isApproved ? Colors.grey : Colors.green,
                isApproved: isApproved,
              ),
              // Show a disabled message for approved orders
              if (isApproved)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Approved orders cannot be restored',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _restoreOrderData(
  BuildContext context,
  HeldOrder order, {
  required CustomerScreenProvider customerProvider,
  required CartProvider cartProvider,
  required CartSelectionProvider selectionProvider,
}) {
  try {
    // Close the bottom sheet
    Navigator.of(context).pop();
    print("ontap:");
    // Call restore function with providers
    restoreHeldOrderData(
      context: context,
      order: order,
      customerProvider: customerProvider,
      cartProvider: cartProvider,
      selectionProvider: selectionProvider,
    );
  } catch (e) {
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error restoring order: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

Widget _buildStatusChip(String status, {bool isApproved = false}) {
  Color bgColor;
  switch (status.toLowerCase()) {
    case 'approved':
      bgColor = Colors.green;
      break;
    case 'pending':
      bgColor = Colors.orange;
      break;
    case 'rejected':
      bgColor = Colors.redAccent;
      break;
    default:
      bgColor = Colors.grey;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          bgColor.withOpacity(isApproved ? 0.5 : 0.9),
          bgColor.withOpacity(isApproved ? 0.3 : 0.7),
        ],
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: isApproved
          ? []
          : [
              BoxShadow(
                color: bgColor.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
    ),
    child: Row(
      children: [
        Icon(Icons.circle, size: 8, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          status,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

Widget _buildInfoRow(
  IconData icon,
  String text, {
  Color iconColor = Colors.blueGrey,
  bool isApproved = false,
}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(isApproved ? 0.06 : 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isApproved ? Colors.grey : Colors.black87,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            decoration: isApproved
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Models/held_order_model.dart';
import 'package:yenpos/Sale_order/Widgets/restore_order_date.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';

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
  print("🔹 Fetching saved approval orders from Hive...");

  var approvalOrderBox = HiveManager.salesApprovalOrder;
  print("📦 Total items in Hive box: ${approvalOrderBox.length}");

  if (approvalOrderBox.isEmpty) {
    print("⚠️ No approval orders found. Returning empty list.");
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

    print("➡️ Flattened order map for HeldOrder: $combinedMap");

    final heldOrder = HeldOrder.fromMap(combinedMap);
    print("✅ Converted HeldOrder: $heldOrder");

    return heldOrder;
  }).toList();

  print("📊 Total approval orders fetched: ${approvalOrders.length}");
  return approvalOrders;
}

Widget _buildApproveOrdersList(
  BuildContext context,
  ScrollController scrollController,
) {
  print("🔹 Building Approve Orders List widget...");

  return FutureBuilder<List<HeldOrder>>(
    future: getSavedApprovalOrder(),
    builder: (context, snapshot) {
      print("🔹 FutureBuilder snapshot state: ${snapshot.connectionState}");

      if (snapshot.connectionState == ConnectionState.waiting) {
        print("⏳ Waiting for approval orders...");
        return const Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        print("❌ Error while fetching approval orders: ${snapshot.error}");
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
        print("⚠️ No approval orders available.");
        return const Center(
          child: Text(
            'No approve orders available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        );
      }

      final orders = snapshot.data!;
      print(
        "✅ Approval orders fetched successfully. Total orders: ${orders.length}",
      );
      for (int i = 0; i < orders.length; i++) {
        print("📄 Order $i: ${orders[i]}");
      }

      return ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          print("🔹 Building list item for order at index: $index");
          return _buildApproveOrderListItem(context, orders[index]);
        },
      );
    },
  );
}

Widget _buildApproveOrderListItem(BuildContext context, HeldOrder order) {
  if (order.approvalDetails != null && order.approvalDetails!.isNotEmpty) {
    try {
      // Get the latest detail that has a non-null, non-empty approvalStatus
      final lastDetailWithStatus = order.approvalDetails!.lastWhere(
        (d) => d.approvalStatus != null && d.approvalStatus!.isNotEmpty,
        orElse: () => order.approvalDetails!.last,
      );

      approvalStatus = lastDetailWithStatus.approvalStatus ?? 'Unknown';
    } catch (e, stackTrace) {
      approvalStatus = 'Unknown';
    }
  } else {}

  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
    child: Card(
      color: Colors.white.withOpacity(0.8),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // onTap: () {
        //   restoreHeldOrderData(context, order);
        // },
        splashColor: Colors.blue.withOpacity(0.05),
        highlightColor: Colors.blueAccent.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 2,
                width: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Colors.lightBlueAccent],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.calendar_month_rounded,
                "Delivery Date: ${order.deliveryDate ?? '--'}",
                iconColor: Colors.deepPurpleAccent,
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                Icons.access_time_filled_rounded,
                "Delivery Time: ${order.deliveryTime ?? '--'}",
                iconColor: Colors.orangeAccent,
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                Icons.verified_rounded,
                "Approval Status: $approvalStatus",
                iconColor: Colors.green,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildStatusChip(String? status) {
  Color bgColor;
  switch (status?.toLowerCase()) {
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
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 4,
    ), // smaller chip
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [bgColor.withOpacity(0.9), bgColor.withOpacity(0.7)],
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: bgColor.withOpacity(0.3),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(Icons.circle, size: 8, color: Colors.white), // smaller dot
        const SizedBox(width: 4),
        Text(
          status ?? 'Unknown',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12, // reduced from 14
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
}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(4), // reduced from 6
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: iconColor), // smaller icon
      ),
      const SizedBox(width: 8), // reduced from 12
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13, // reduced from 15
            color: Colors.black87,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    ],
  );
}

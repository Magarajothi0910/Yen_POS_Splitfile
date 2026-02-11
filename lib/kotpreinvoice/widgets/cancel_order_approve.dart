import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/kotpreinvoice/components/flushbar.dart';
import 'package:yen_pos/main.dart';

Future<void> sendApprove(
  BuildContext context,
  List<dynamic> ordersForSeat,
  String tableNumber,
  String seat,
  String remark,
) async {
  final TextEditingController remarkController = TextEditingController(
    text: remark == "" ? "" : remark,
  );

  // remarkController.text = remark;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: const [
          Icon(Icons.approval, color: Colors.orange),
          SizedBox(width: 8),
          Text('Approval Required'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Do you want to approve canceling this order?',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: remarkController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Remark',
              hintText: 'Enter remark',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: remarkController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => remarkController.clear(),
                    )
                  : null,
            ),
            onChanged: (_) {
              // rebuild suffix icon
              (ctx as Element).markNeedsBuild();
            },
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(ctx).pop(false),
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Send Approve'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            if (remarkController.text.trim().isEmpty) {
              showCustomFlushbar(
                context,
                "Please enter a remark before approving.",
                type: FlushbarType.warning,
              );
              return;
            }
            Navigator.of(ctx).pop(true);
          },
        ),
      ],
    ),
  );

  if (result == true) {
    final approvePayload = {
      'type': 'approveCancelOrder',
      'cancelType': 'orderCancel',
      'status': 'pending',
      'tableNumber': tableNumber,
      'seat': seat,
      'remark': remarkController.text.trim(),
      'orders': ordersForSeat,
    };
    sendataToServer(approvePayload);
  } else {}
}

Future<void> handleApproveCancelOrder(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {
    debugPrint("handleApproveCancelOrder data :: $data");
    // final packageInfo = await PackageInfo.fromPlatform();

    final approveTable = data['tableNumber'];
    final approveSeat = data['seat'];
    final approveStatus = data['status'];
    final approveOrders = data['orders'];
    final approveRemark = data['remark'];
    final approveCancelType = data['cancelType'];
    final seathiveOrderId = data['orders'][0]['seathiveOrderId'];

    final key = '${approveTable}_${approveSeat}_$seathiveOrderId';

    final HiveData = {
      'cancelType': approveCancelType,
      'tableNumber': approveTable,
      'seat': approveSeat,
      'status': approveStatus,
      'remark': approveRemark,
      'seathiveOrderId': seathiveOrderId,
    };
    final box = await Hive.openBox('approvelOrdersKOT');
    await box.put(key, HiveData);

    final approvalData = {
      'action': 'approveCancelOrder',
      'cancelType': approveCancelType,
      'status': 'pending',
      'tableNumber': approveTable,
      'seat': approveSeat,
      'remark': approveRemark,
      'orders': data['orders'],
    };
    if (appType == "server") sendDataToClients(approvalData, clients);
  } catch (e) {
    debugPrint("handleApproveCancelOrder :: $e");
  }
}

// void showApproveDialog({
//   required String table,
//   required String seat,
//   required String status,
//   required List<dynamic> orders,
// }) {
//   final context = global.navigatorKey.currentContext;
//   if (context == null) return;

//   final order = orders.first; // assuming single order per request

//   showDialog(
//     context: context,
//     barrierDismissible: true,
//     builder: (_) => AlertDialog(
//       title: Row(
//         children: const [
//           Icon(Icons.info, color: Colors.blue),
//           SizedBox(width: 8),
//           Text('Cancel Order Approval'),
//         ],
//       ),
//       content: SizedBox(
//         width: MediaQuery.of(context).size.width * 0.5,
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // 🔹 Info text
//               Text(
//                 'Cancel order approval request for Table $table, Seat $seat.',
//                 style: const TextStyle(fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 12),

//               const Divider(),

//               // 🔹 Order details header
//               Text(
//                 'Order Details - $status',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),

//               // 🔹 Item list
//               ListView.builder(
//                 shrinkWrap: true,
//                 physics: const NeverScrollableScrollPhysics(),
//                 itemCount: order['itemNames'].length,
//                 itemBuilder: (context, index) {
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             order['itemNames'][index],
//                             style: const TextStyle(fontWeight: FontWeight.w500),
//                           ),
//                         ),
//                         Text('x${order['quantities'][index]}'),
//                         const SizedBox(width: 10),
//                         Text(
//                           '₹${order['amounts'][index]}',
//                           style: const TextStyle(fontWeight: FontWeight.w600),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),

//               const Divider(),

//               // 🔹 Total amount
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: Text(
//                   'Total: ₹${order['totalAmount']}',
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () {
//             Navigator.of(context).pop();
//             sendataToServer({
//               'type': 'cancelOrderApprovalResponse',
//               'status': 'declined',
//               'tableNumber': table,
//               'seat': seat,
//               'orders': orders,
//             });
//           },
//           child: const Text('Decline', style: TextStyle(color: Colors.red)),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             Navigator.of(context).pop();
//             sendataToServer({
//               'type': 'cancelOrderApprovalResponse',
//               'status': 'approved',
//               'tableNumber': table,
//               'seat': seat,
//               'orders': orders,
//             });
//           },
//           child: const Text('Approve'),
//         ),
//       ],
//     ),
//   );
// }

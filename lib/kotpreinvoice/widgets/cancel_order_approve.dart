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
  String cancelType,
) async {
  debugPrint("orderCancel type is $ordersForSeat ");
  final TextEditingController remarkController = TextEditingController(
    text: remark == "" ? "" : remark,
  );

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
      'cancelType': cancelType == 'orderCancel'
          ? 'orderCancel'
          : cancelType == 'itemCancel'
          ? 'itemCancel'
          : '',
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
    final String approveCancelType = data['cancelType'];
    final seathiveOrderId = data['orders'][0]['seathiveOrderId'];

    if (approveCancelType == 'orderCancel') {
      final key = '${approveTable}_${approveSeat}_$seathiveOrderId';

      final HiveData = {
        'cancelType': approveCancelType,
        'tableNumber': approveTable,
        'seat': approveSeat,
        'status': approveStatus,
        'remark': approveRemark,
        'seathiveOrderId': seathiveOrderId,
      };

      debugPrint("hive data is $HiveData");
      final box = await Hive.openBox('approvelOrdersKOT');
      await box.put(key, HiveData);
    }

    if (approveCancelType == 'itemCancel') {
      final varianceitemCode = data['orders'][0]['varianceitemCodes'];

      final key =
          '${approveTable}_${approveSeat}_${seathiveOrderId}_$varianceitemCode';

      final HiveData = {
        'cancelType': approveCancelType,
        'tableNumber': approveTable,
        'seat': approveSeat,
        'status': approveStatus,
        'remark': approveRemark,
        'seathiveOrderId': seathiveOrderId,
        'varianceitemCode': varianceitemCode,
      };
      final box = await Hive.openBox('approvelOrdersKOT');
      await box.put(key, HiveData);
    }

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

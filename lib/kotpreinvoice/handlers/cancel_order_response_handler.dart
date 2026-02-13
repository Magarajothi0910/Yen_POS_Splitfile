import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';

Future<void> handleCancelOrderApprovalResponse(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {
    //
    debugPrint("handleCancelOrderApprovalResponse data :: $data");

    final approveResponseTable = data['tableNumber'];
    final approveResponseSeat = data['seat'];
    final approveResponseStatus = data['status'];
    final approveResponseRemark = data['remark'];
    final approveResponseCancelType = data['cancelType'];
    final approveResponseSeathiveOrderId = data['orders'][0]['seathiveOrderId'];

    final approveResponse = {
      'action': 'cancelOrderApprovalResponse',
      'tableNumber': approveResponseTable,
      'seat': approveResponseSeat,
      'status': approveResponseStatus,
      'cancelType': approveResponseCancelType,
      'remark': approveResponseRemark,
      'orders': data['orders'],
    };

    if (approveResponseCancelType == "orderCancel") {
      final key =
          '${approveResponseTable}_${approveResponseSeat}_$approveResponseSeathiveOrderId';
      final hiveData = {
        'tableNumber': approveResponseTable,
        'seat': approveResponseSeat,
        'status': approveResponseStatus,
        'seathiveOrderId': approveResponseSeathiveOrderId,
        'remark': approveResponseRemark,
        'cancelType': approveResponseCancelType,
      };
      final box = await Hive.openBox('approvelOrdersKOT');
      await box.put(key, hiveData);
      debugPrint("Cancel order approval response for :  $approveResponse");
    }

    if (approveResponseCancelType == 'itemCancel') {
      final varianceitemCode = data['orders'][0]['varianceitemCodes'];

      debugPrint("varianceitemCode $varianceitemCode");

      final key =
          '${approveResponseTable}_${approveResponseSeat}_${approveResponseSeathiveOrderId}_$varianceitemCode';
      final hiveData = {
        'tableNumber': approveResponseTable,
        'seat': approveResponseSeat,
        'status': approveResponseStatus,
        'seathiveOrderId': approveResponseSeathiveOrderId,
        'remark': approveResponseRemark,
        'cancelType': approveResponseCancelType,
        'orders': data['orders'][0],
      };
      final box = await Hive.openBox('approvelOrdersKOT');
      await box.put(key, hiveData);
      debugPrint("Cancel order approval response for :  $approveResponse");
    }

    if (appType == "server") sendDataToClients(approveResponse, clients);
  } catch (e) {
    debugPrint("cancelOrderApprovalResponse :: $e");
  }
}

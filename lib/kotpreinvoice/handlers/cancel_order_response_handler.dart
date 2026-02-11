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
    final approveResponseSeathiveOrderId = data['orders'][0]['seathiveOrderId'];

    //  [{tableNumber: Table 1, seat: A, status: pending, seathiveOrderId: Kenikarai-Table 1-ORD2602041718-335}]
    // [Table 1_A_Kenikarai-Table 1-ORD2602041718-335]

    final approveResponse = {
      'action': 'cancelOrderApprovalResponse',
      'tableNumber': approveResponseTable,
      'seat': approveResponseSeat,
      'status': approveResponseStatus,
      'orders': data['orders'],
    };

    final key =
        '${approveResponseTable}_${approveResponseSeat}_$approveResponseSeathiveOrderId';
    final hiveData = {
      'tableNumber': approveResponseTable,
      'seat': approveResponseSeat,
      'status': approveResponseStatus,
      'seathiveOrderId': approveResponseSeathiveOrderId,
    };
    final box = await Hive.openBox('approvelOrdersKOT');
    await box.put(key, hiveData);
    debugPrint("Cancel order approval response for :  $approveResponse");
    if (appType == "server") sendDataToClients(approveResponse, clients);
  } catch (e) {
    debugPrint("cancelOrderApprovalResponse :: $e");
  }
}

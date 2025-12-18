import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';

handleHandShake(
  Map<String, dynamic> data,
) async {
  print('Client HandShake : $data');
  final d = {'type': 'handshake','message': 'From Client'};
  //sendDataToClients(d, clients);
 // sendataToServer(d);
}
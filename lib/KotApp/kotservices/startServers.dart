import 'dart:convert';
import 'dart:io';

import 'package:udp/udp.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../screens/kot_screen/global/globals.dart';
import '../models/globals.dart';
import 'Token_service.dart';

Future<void> startUdpResponder(String ip, int udpPort) async {
  final udp = await UDP.bind(Endpoint.any(port: const Port(33441)));

  udp.asStream().listen((datagram) {
    if (datagram == null) return;

    final message = utf8.decode(datagram.data);

    if (message == 'WHO_IS_SERVER') {
      final response = utf8.encode('SERVER:$ip:$port');
      udp.send(
          response,
          Endpoint.unicast(
            datagram.address,
            port: Port(datagram.port),
          ));
    }
  });
}

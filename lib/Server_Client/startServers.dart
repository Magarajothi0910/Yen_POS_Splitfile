import 'dart:convert';

import 'package:udp/udp.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;

Future<void> startUdpResponder(String ip, int udpPort) async {
  final udp = await UDP.bind(Endpoint.any(port: const Port(56789)));

  udp.asStream().listen((datagram) {
    if (datagram == null) return;

    final message = utf8.decode(datagram.data);

    if (message == 'WHO_IS_SERVER') {
      final response = utf8.encode(
        'SERVER:${globals.serverip}:${globals.port}',
      );
      udp.send(
        response,
        Endpoint.unicast(datagram.address, port: Port(datagram.port)),
      );
    }
  });
}

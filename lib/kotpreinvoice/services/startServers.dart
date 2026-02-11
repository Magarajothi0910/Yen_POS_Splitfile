import 'dart:async';
import 'dart:convert';
import 'package:udp/udp.dart';

import 'package:yen_pos/Global/globals_data.dart';

Future<void> startUdpResponder(String ip, int udpPort) async {
  // Bind UDP socket
  final udp = await UDP.bind(Endpoint.any(port: Port(udpPort)));
  print('Server discovery started on $ip:$udpPort');

  // 1. Respond to WHO_IS_SERVER
  udp.asStream().listen((datagram) {
    if (datagram == null) return;
    final message = utf8.decode(datagram.data);
    print('Received: $message');

    if (message == 'WHO_IS_SERVER') {
      udp.send(
        utf8.encode('SERVER:$ip:$port'),
        Endpoint.unicast(datagram.address, port: Port(udpPort)),
      );
      print('Responded to ${datagram.address.address}');
    }
  });

  // 2. Periodic broadcast (every 5 seconds)
  Timer.periodic(const Duration(seconds: 5), (_) {
    udp.send(
      utf8.encode('SERVER:$ip:$port'),
      Endpoint.broadcast(port: Port(udpPort)),
    );
    print('Broadcasted: SERVER:$ip:$port');
  });
}

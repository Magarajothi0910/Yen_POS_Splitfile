// mdns_service.dart
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:udp/udp.dart';

class MdnsService {
  final int udpPort;
  BonsoirBroadcast? _broadcast;
  UDP? _udpSocket;

  MdnsService({this.udpPort = 9999});

  Future<String?> getLocalIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return null;
  }

  Future<void> startBroadcast() async {
    final ip = await getLocalIp();
    if (ip == null) {
      return;
    }

    // Start UDP socket to listen for discovery
    _udpSocket = await UDP.bind(Endpoint.any(port: Port(udpPort)));

    // mDNS broadcast
    final service = BonsoirService(
      name: "MyServer-UDP-Host",
      type: "_myservice._udp",
      port: udpPort,
      attributes: {
        "host": ip,
        "port": udpPort.toString(),
      },
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();

  }

  Future<void> stop() async {
    await _broadcast?.stop();
    _broadcast = null;
    _udpSocket?.close();
    _udpSocket = null;
  }
}

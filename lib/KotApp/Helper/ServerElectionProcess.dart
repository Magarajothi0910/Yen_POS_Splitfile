import 'package:uuid/uuid.dart';
import 'package:udp/udp.dart';
import 'dart:convert';
import 'package:system_info2/system_info2.dart'; // Add this!

class ServerElectionManager {
  late UDP _udp;
  int _myRank = 0;
  final String _myDeviceId = const Uuid().v4(); // Unique device ID
  bool _shouldBecomeServer = true;
  final int electionPort = 33441;
  final Duration electionTimeout = const Duration(seconds: 3);

  DateTime appStartTime = DateTime.now(); // For uptime

  Future<void> startElection(Function onBecomeServer) async {
    _udp = await UDP.bind(Endpoint.any());

    _myRank = await calculateMyRank();

    final message = 'SERVER_ELECTION:$_myRank:$_myDeviceId';
    _udp.send(
        utf8.encode(message), Endpoint.broadcast(port: Port(electionPort)));

    _listenForElectionMessages();

    await Future.delayed(electionTimeout);

    if (_shouldBecomeServer) {
      await onBecomeServer(); // <-- This will trigger your server start
    } else {}

    _udp.close();
  }

  void _listenForElectionMessages() {
    _udp.asStream().listen((datagram) {
      if (datagram == null) return;

      final message = utf8.decode(datagram.data);
      if (message.startsWith('SERVER_ELECTION:')) {
        final parts = message.split(':');
        final int receivedRank = int.tryParse(parts[1]) ?? 0;
        final String deviceId = parts[2];

        if (receivedRank > _myRank) {
          _shouldBecomeServer = false;
        } else if (receivedRank == _myRank) {
          if (deviceId.compareTo(_myDeviceId) < 0) {
            _shouldBecomeServer = false;
          }
        }
      }
    });
  }

  Future<int> calculateMyRank() async {
    int ramMB = SysInfo.getTotalPhysicalMemory() ~/ (1024 * 1024); // RAM in MB

    int uptimeMinutes = DateTime.now().difference(appStartTime).inMinutes;

    return ramMB + uptimeMinutes;
  }
}

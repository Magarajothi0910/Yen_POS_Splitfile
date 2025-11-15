import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:yenpos/Global/globals_data.dart';

Future<bool> isServerReachable(String ip, int port) async {
  try {
    final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 800));
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> validateStoredServerIp() async {
  final configBox = Hive.box('configBox');
  final serverBox = Hive.box('serverBox');

  final ip = serverBox.get('serverIp') ?? '';
 // final port = int.tryParse(serverBox.get('serverPort') ?? '8090') ?? 8090;
 

  if (ip.isEmpty) return false;

  final isAlive = await isServerReachable(ip, port);
  if (!isAlive) {
    print("❌ Stored server $ip:$port is NOT alive. Promoting self as server.");
    await configBox.put('appType', 'server');
    return false;
  }

  print("✅ Server $ip:$port is alive. This device will act as client.");
  await configBox.put('appType', 'client');
  return true;
}

Future<String?> getLocalIp() async {
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback && addr.address.startsWith('192.')) {
        return addr.address;
      }
    }
  }
  return null;
}

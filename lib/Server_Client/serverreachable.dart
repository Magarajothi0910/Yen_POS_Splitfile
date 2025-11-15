import 'dart:io';

/// 🌍 Check if server is reachable
Future<bool> isServerReachable(String ip, int port) async {
  print("📡 Checking if server $ip:$port is reachable...");
  try {
    final socket = await Socket.connect(
      ip,
      port,
      timeout: const Duration(seconds: 2),
    );
    print("✅ Connection established to $ip:$port");
    socket.destroy();
    return true;
  } catch (e) {
    print("❌ Failed to connect to $ip:$port — $e");
    return false;
  }
}

Future<String?> getLocalIp() async {
  print("🌐 Searching for local IP...");
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
        final ip = addr.address;
        if (ip.startsWith('192.') ||
            ip.startsWith('10.') ||
            ip.startsWith('172.')) {
          print("✅ Local IP found: $ip");
          return ip;
        }
      }
    }
  }
  print("⚠️ No private local IP found");
  return null;
}

// void startCallback() {
//   FlutterForegroundTask.setTaskHandler(MyForegroundTaskHandler());
// }

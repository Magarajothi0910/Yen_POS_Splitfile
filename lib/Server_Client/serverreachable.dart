import 'dart:io';

/// 🌍 Check if server is reachable
Future<bool> isServerReachable(String ip, int port) async {
  try {
    final socket = await Socket.connect(
      ip,
      port,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
    return true;
  } catch (e) {
    return false;
  }
}

/// 💻 Get local LAN/WiFi IP
Future<String?> getLocalIp() async {
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
        final ip = addr.address;

        // Accept all private IP ranges
        if (ip.startsWith('10.') ||
            ip.startsWith('172.') && _isValid172Range(ip) ||
            ip.startsWith('192.168.')) {
          return ip;
        }
      }
    }
  }
  return null;
}

/// 🔍 Check if IP is in 172.16.x.x – 172.31.x.x range
bool _isValid172Range(String ip) {
  try {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    final second = int.parse(parts[1]);
    return second >= 16 && second <= 31;
  } catch (_) {
    return false;
  }
}

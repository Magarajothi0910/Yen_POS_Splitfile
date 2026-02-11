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
  final interfaces = await NetworkInterface.list();
 
  String? mobileIp;
 
  for (final interface in interfaces) {
    final name = interface.name.toLowerCase();
 
    for (final addr in interface.addresses) {
      if (addr.type != InternetAddressType.IPv4 || addr.isLoopback) continue;
 
      // ✅ Prefer Wi-Fi
      if (name.contains('wlan') ||
          name.contains('wifi') ||
          name.contains('en')) {
        return addr.address;
      }
 
      // ⚠️ Store mobile as fallback
      if (name.contains('rmnet') ||
          name.contains('ccmni') ||
          name.contains('pdp')) {
        mobileIp ??= addr.address;
      }
    }
  }
 
  // 📌 Return mobile IP if Wi-Fi not found
  return mobileIp;
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

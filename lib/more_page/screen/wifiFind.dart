import 'package:network_info_plus/network_info_plus.dart';
import 'package:dart_ping/dart_ping.dart';

/// Scans the local network (assumes a /24 subnet) using ICMP ping.
/// Returns a list of IP addresses that respond.
Future<List<String>> scanLocalNetwork() async {
  final info = NetworkInfo();
  final myIp = await info.getWifiIP(); // e.g. "192.168.1.100"
  if (myIp == null) return [];

  // Compute the subnet using the first three segments.
  final segments = myIp.split('.');
  if (segments.length != 4) return [];
  final subnet = '${segments[0]}.${segments[1]}.${segments[2]}.';

  List<String> activeIPs = [];
  // Create a list of futures to ping IP addresses concurrently.
  List<Future<void>> pingFutures = [];

  // Scan addresses from .1 to .254
  for (int i = 1; i < 255; i++) {
    final ipToScan = '$subnet$i';
    // Optional: You might want to skip your own IP.
    if (ipToScan == myIp) continue;

    // Create a future for each ping.
    final pingFuture = _pingIP(ipToScan).then((isActive) {
      if (isActive) activeIPs.add(ipToScan);
    });
    pingFutures.add(pingFuture);
  }

  // Wait for all pings to complete.
  await Future.wait(pingFutures);
  return activeIPs;
}

/// Helper function that pings a given IP once with a timeout.
/// Returns true if a reply was received.
Future<bool> _pingIP(String ip) async {
  final ping = Ping(ip, count: 1, timeout: 2);
  try {
    // Use the stream from dart_ping and check if any response was received.
    await for (final PingData data in ping.stream) {
      if (data.response != null) {
        return true;
      }
    }
  } catch (e) {
    // In case of error, return false.
    return false;
  }
  return false;
}

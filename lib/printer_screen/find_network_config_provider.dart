// import 'package:network_info_plus/network_info_plus.dart';
// import 'package:ping_discover_network_plus/ping_discover_network_plus.dart';

// class NetworkPrinterScanner {
//   static Future<List<String>> discoverPrinters(int port) async {
//     final info = NetworkInfo();
//     final String? ip = await info.getWifiIP();
//     final String? subnet = ip?.substring(0, ip.lastIndexOf('.'));

//     if (subnet == null) {
//       throw Exception('Could not determine subnet');
//     }

//     print('Subnet: $subnet'); // Debug: Log the subnet being scanned

//     final stream = NetworkAnalyzer.i.discover(subnet, port);

//     final List<String> printers = [];
//     await for (var device in stream) {
//       print(
//           'Pinged IP: ${device.ip}, Exists: ${device.exists}'); // Debug: Log each IP checked
//       if (device.exists) {
//         printers.add(device.ip);
//       }
//     }

//     return printers;
//   }
// }

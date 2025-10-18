import 'dart:io';

Future<bool> isServerReachable(String ip, int port) async {
  try {
    final socket =
        await Socket.connect(ip, port, timeout: Duration(seconds: 2));
    socket.destroy(); // Close connection
    return true;
  } catch (e) {
   
    return false;
  }
}

Future<String?> getLocalIp() async {
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4 &&
          !addr.isLoopback &&
          addr.address.startsWith('192.')) {
        return addr.address;
      }
    }
  }
  return null;
}


// void startCallback() {
//   FlutterForegroundTask.setTaskHandler(MyForegroundTaskHandler());
// }

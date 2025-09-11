import 'package:permission_handler/permission_handler.dart';

Future<void> requestBluetoothPermissions() async {
  var statuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();

  if (statuses[Permission.bluetoothScan]!.isGranted &&
      statuses[Permission.bluetoothConnect]!.isGranted) {
  } else {
  }
}

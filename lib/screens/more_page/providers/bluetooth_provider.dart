// import 'dart:convert';
// import 'package:flutter/material.dart';

// import 'package:flutter_blue/flutter_blue.dart' as bl;
// import 'package:permission_handler/permission_handler.dart';

// class BluetoothProvider with ChangeNotifier {
//   bl.FlutterBlue flutterBlue = bl.FlutterBlue.instance;
//   List<bl.BluetoothDevice> devicesList = [];
//   bl.BluetoothDevice? connectedDevice;
//   bl.BluetoothCharacteristic? characteristic;
//   bool isConnecting = false;
//   String qrData = "";

//   BluetoothProvider() {
//     requestPermissions();
//   }

//   Future<void> requestPermissions() async {
//     var status = await [
//       Permission.bluetooth,
//       Permission.bluetoothScan,
//       Permission.bluetoothConnect,
//       Permission.locationWhenInUse,
//     ].request();

//     if (status[Permission.bluetoothScan]!.isGranted &&
//         status[Permission.bluetoothConnect]!.isGranted &&
//         status[Permission.locationWhenInUse]!.isGranted) {
//       startScan();
//     } else {
//       print('Permissions not granted');
//     }
//   }

//   void startScan() {
//     flutterBlue.startScan(timeout: const Duration(seconds: 5));

//     flutterBlue.scanResults.listen((results) {
//       for (bl.ScanResult r in results) {
//         if (!devicesList.contains(r.device)) {
//           devicesList.add(r.device);
//           notifyListeners();
//         }
//       }
//     });

//     flutterBlue.stopScan();
//   }

//   Future<void> connectToDevice(bl.BluetoothDevice device) async {
//     isConnecting = true;
//     notifyListeners();

//     try {
//       await device.connect();
//       connectedDevice = device;

//       List<bl.BluetoothService> services = await device.discoverServices();
//       for (bl.BluetoothService service in services) {
//         for (bl.BluetoothCharacteristic c in service.characteristics) {
//           if (c.properties.write) {
//             characteristic = c;
//             break;
//           }
//         }
//         if (characteristic != null) break;
//       }

//       isConnecting = false;
//       notifyListeners();

//       if (characteristic == null) {
//         print('No writable characteristic found.');
//       } else {
//         print('Connected to ${connectedDevice!.name}');
//       }
//     } catch (e) {
//       isConnecting = false;
//       print('Error connecting to device: $e');
//       notifyListeners();
//     }
//   }

//   Future<void> getWeightFromScale() async {
//     if (connectedDevice != null && characteristic != null) {
//       try {
//         // Reading the value from the characteristic
//         List<int> weightData = await characteristic!.read();

//         // Assuming the data is in a format that can be parsed to get the weight
//         String weight = utf8.decode(weightData);

//         print('Weight from scale: $weight');

//         // Optionally, you can set the weight in the state for the UI to display
//         // notifyListeners();
//       } catch (e) {
//         print('Error reading weight from scale: $e');
//       }
//     } else {
//       print('No device connected or no readable characteristic available.');
//     }
//   }
// }

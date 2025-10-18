import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothProvider2 with ChangeNotifier {
  // BluetoothConnection? connection;
  double _weight = 0.0;
  bool isConnected = false;
  String buffer = '';
  String wsName = '';
  StreamSubscription? _connectionSubscription;

  double get weight => _weight;

  // Future<void> connectToDevice(
  //     BluetoothDevice device, BuildContext context) async {
  //   try {
  //     // Check if Bluetooth is enabled
  //     bool? isBluetoothEnabled =
  //         await FlutterBluetoothSerial.instance.isEnabled;
  //     if (isBluetoothEnabled != true) {
  //       // Show a dialog prompting to enable Bluetooth
  //       await showDialog(
  //         context: context,
  //         builder: (context) => AlertDialog(
  //           title: Text("Bluetooth Disabled"),
  //           content: Text("Please enable Bluetooth to connect to the device."),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.of(context).pop(),
  //               child: Text("OK"),
  //             ),
  //           ],
  //         ),
  //       );
  //       return; // Exit if Bluetooth is not enabled
  //     }

  //     connection = await BluetoothConnection.toAddress(device.address);
  //     isConnected = true;
  //     notifyListeners();

  //     wsName = device.name!;

  //     // Show connection success message
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Connected to ${device.name} successfully")),
  //     );

  //     // Listen to the input stream and handle it via StreamSubscription
  //     _connectionSubscription = connection!.input!.listen((data) {
  //       String rawData = String.fromCharCodes(data);
  //       buffer += rawData;

  //       double? parsedWeight = parseWeight(buffer);
  //       if (parsedWeight != null && parsedWeight != 0.0) {
  //         _weight = parsedWeight;
  //         buffer = ''; // Clear the buffer after valid weight
  //         notifyListeners();
  //       }
  //     });

  //     _connectionSubscription!.onDone(() {
  //       disconnect();
  //     });

  //     _connectionSubscription!.onError((error) {
  //       print("Stream error: $error");
  //       disconnect();
  //     });
  //   } catch (e) {
  //     print("Error: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Connection failed to ${device.name}")),
  //     );
  //     disconnect();
  //   }
  // }

  // void disconnect() {
  //   _connectionSubscription?.cancel();
  //   connection?.close();
  //   connection = null;
  //   isConnected = false;
  //   notifyListeners();
  // }

  double? parseWeight(String data) {
    RegExp exp = RegExp(r'(\d{1,3}\.\d{3})');
    Iterable<Match> matches = exp.allMatches(data);

    if (matches.isNotEmpty) {
      try {
        String latestMatch = matches.last.group(0) ?? '0.000';
        return double.parse(latestMatch);
      } catch (e) {
      }
    }
    return null;
  }
}

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';


import '../providers/bt_provide2.dart';


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';

class ConnectWeighingScale extends StatefulWidget {
  const ConnectWeighingScale({super.key});
  @override
  _ConnectWeighingScaleState createState() => _ConnectWeighingScaleState();
}

class _ConnectWeighingScaleState extends State<ConnectWeighingScale> {
  BluetoothDevice? selectedDevice;

  @override
  Widget build(BuildContext context) {
    final bluetoothProvider2 = Provider.of<BluetoothProvider2>(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Connect Weighing Scale",
          style: TextStyle(fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  shadowColor: Colors.blue.shade200,
                  elevation: 10,
                ),
                onPressed: () async {
                  BluetoothDevice? device = await _showPairedDevicesDialogSafe(context);
                  if (device != null) {
                    selectedDevice = device;
                    context.read<BluetoothProvider2>().connectToDevice(device, context);
                  }
                },
                child: Text("Connect to Weighing Scale"),
              ),
              const SizedBox(height: 20),
              if (bluetoothProvider2.wsName.isNotEmpty)
                Text(
                  "Connected to ${bluetoothProvider2.wsName}",
                  style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 18,
                    color: Colors.blue.shade800,
                  ),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  /// A wrapper that ensures permissions then returns bonded devices list
  Future<List<BluetoothDevice>> _getBondedDevicesWithPermission() async {
    if (Platform.isAndroid) {
      // On Android 12+ (SDK ≥ 31), request BLUETOOTH_CONNECT, BLUETOOTH_SCAN
      if (await Permission.bluetoothConnect.isDenied || await Permission.bluetoothScan.isDenied) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
        ].request();
        bool grantedConnect = statuses[Permission.bluetoothConnect]?.isGranted == true;
        bool grantedScan = statuses[Permission.bluetoothScan]?.isGranted == true;
        if (!grantedConnect || !grantedScan) {
          throw Exception("Bluetooth permissions not granted");
        }
      }
    }
    // Now safe to call
    return await FlutterBluetoothSerial.instance.getBondedDevices();
  }

  Future<BluetoothDevice?> _showPairedDevicesDialogSafe(BuildContext context) async {
    List<BluetoothDevice> devices;
    try {
      devices = await _getBondedDevicesWithPermission();
    } catch (e) {
      // Show a message to user
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bluetooth permission not granted.")));
      return null;
    }

    return showDialog<BluetoothDevice>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("Select Bluetooth Device"),
          content: SingleChildScrollView(
            child: Column(
              children: devices
                  .map((device) => ListTile(
                        title: Text(device.name ?? ""),
                        leading: Icon(
                          Icons.bluetooth,
                          size: 20,
                        ),
                        onTap: () => Navigator.of(context).pop(device),
                        // trailing: Icon( 
                        //   Icons.bluetooth,
                        //   size: 20,
                        // ),
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

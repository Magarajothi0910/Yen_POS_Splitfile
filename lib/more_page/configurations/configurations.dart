import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothDevicesScreen extends StatefulWidget {
  const BluetoothDevicesScreen({super.key});

  @override
  _BluetoothDevicesScreenState createState() => _BluetoothDevicesScreenState();
}

class _BluetoothDevicesScreenState extends State<BluetoothDevicesScreen> {
  List<BluetoothDiscoveryResult> devicesList = [];
  BluetoothConnection? connection;
  bool isConnecting = false;
  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();
    startDiscovery();
  }

  void startDiscovery() {
    setState(() {
      devicesList.clear();
      isConnecting = true;
    });
    FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      setState(() {
        final existingIndex = devicesList.indexWhere(
            (element) => element.device.address == r.device.address);
        if (existingIndex >= 0) {
          devicesList[existingIndex] = r;
        } else {
          devicesList.add(r);
        }
      });
    }).onDone(() {
      setState(() {
        isConnecting = false;
      });
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      connection = await BluetoothConnection.toAddress(device.address);
      print('Connected to the device');

      connection!.input!.listen((data) {
        // Handle data received
      }).onDone(() {
        print('Connection done');
        disconnectFromDevice();
      });
    } catch (e) {
      print('Failed to connect');
      print(e);
    }
  }

  void disconnectFromDevice() {
    if (connection != null) {
      connection!.dispose();
      connection = null;
      print('Device disconnected');
    }
  }

  @override
  void dispose() {
    // Avoid memory leaks and disconnect if needed
    FlutterBluetoothSerial.instance.cancelDiscovery();
    connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Bluetooth Devices'),
        actions: [
          isConnecting
              ? const CircularProgressIndicator()
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: startDiscovery,
                ),
        ],
      ),
      body: ListView.builder(
        itemCount: devicesList.length,
        itemBuilder: (context, index) {
          BluetoothDiscoveryResult result = devicesList[index];
          return ListTile(
            title: Text(result.device.name ?? "Unknown Device"),
            subtitle: Text(result.device.address),
            onTap: () => connectToDevice(result.device),
            trailing: const Icon(Icons.link),
          );
        },
      ),
    );
  }
}

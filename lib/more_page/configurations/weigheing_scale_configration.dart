import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../providers/bt_provide2.dart';

// class ConnectWeighingScale extends StatefulWidget {
//   const ConnectWeighingScale({super.key});

//   @override
//   _ConnectWeighingScaleState createState() => _ConnectWeighingScaleState();
// }

// class _ConnectWeighingScaleState extends State<ConnectWeighingScale> {
//   BluetoothDevice? selectedDevice;

//   String weight2 = "";

//   @override
//   Widget build(BuildContext context) {
//     final bluetoothProvider = Provider.of<BluetoothProvider>(context);

//     final bluetoothProvider2 = Provider.of<BluetoothProvider2>(context);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         automaticallyImplyLeading: false,
//         title: const Text("Connect Weighing Scale"),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             ElevatedButton(
//               onPressed: () async {
//                 // Show paired devices dialog
//                 BluetoothDevice? device =
//                     await showPairedDevicesDialog(context);
//                 if (device != null) {
//                   selectedDevice = device;
//                   context
//                       .read<BluetoothProvider2>()
//                       .connectToDevice(device, context);
//                 }
//               },
//               child: const Text("Connect to Weighing Scale"),
//             ),
//             const SizedBox(height: 20),

//             // Weight Bar
//             // Consumer<BluetoothProvider2>(
//             //   builder: (context, bluetoothProvider2, child) {
//             //     weight2 = bluetoothProvider2.weight;

//             //     return Text(
//             //       "Weight: ${bluetoothProvider2.weight} kg",
//             //       style: const TextStyle(fontSize: 24),
//             //     );
//             //   },
//             // ),
//             const SizedBox(
//               height: 20,
//             ),
//             if (bluetoothProvider2.wsName != "")
//               Text("Connected to ${bluetoothProvider2.wsName}"),

//             // ElevatedButton(
//             //   onPressed: () async {
//             //     bluetoothProvider.printItemQR2(globals.itemName, weight2,globals.uom);
//             //   },
//             //   child: const Text("Print"),
//             // ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<BluetoothDevice?> showPairedDevicesDialog(BuildContext context) async {
//     List<BluetoothDevice> devices =
//         await FlutterBluetoothSerial.instance.getBondedDevices();

//     return showDialog<BluetoothDevice>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text("Select Bluetooth Device"),
//           content: SingleChildScrollView(
//             child: Column(
//               children: devices
//                   .map((device) => ListTile(
//                         title: Text(device.name ?? ""),
//                         onTap: () {
//                           Navigator.of(context).pop(device);
//                         },
//                       ))
//                   .toList(),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

class ConnectWeighingScale extends StatefulWidget {
  const ConnectWeighingScale({super.key});

  @override
  _ConnectWeighingScaleState createState() => _ConnectWeighingScaleState();
}

class _ConnectWeighingScaleState extends State<ConnectWeighingScale> {
  // BluetoothDevice? selectedDevice;

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
          style: TextStyle(
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
                  // BluetoothDevice? device =
                  //     await showPairedDevicesDialog(context);
                  // if (device != null) {
                  //   selectedDevice = device;
                  //   context
                  //       .read<BluetoothProvider2>()
                  //       .connectToDevice(device, context);
                  // }
                },
                child: Text("Connect to Weighing Scale"),
              ),
              const SizedBox(height: 20),
              if (bluetoothProvider2.wsName.isNotEmpty)
                Text(
                  "Connected to ${bluetoothProvider2.wsName}",
                  style: TextStyle(
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

  // Future<BluetoothDevice?> showPairedDevicesDialog(BuildContext context) async {
  //   List<BluetoothDevice> devices =
  //       await FlutterBluetoothSerial.instance.getBondedDevices();

  //   return showDialog<BluetoothDevice>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text("Select Bluetooth Device"),
  //         content: SingleChildScrollView(
  //           child: Column(
  //             children: devices
  //                 .map((device) => ListTile(
  //                       title: Text(device.name ?? ""),
  //                       onTap: () => Navigator.of(context).pop(device),
  //                     ))
  //                 .toList(),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }
}

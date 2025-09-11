import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../../server/Screen/serverScreen.dart';
import '../kotservices/kotwebsocketService.dart';

class ServerIPScreen extends StatefulWidget {
  const ServerIPScreen({Key? key}) : super(key: key);

  @override
  _ServerIPScreenState createState() => _ServerIPScreenState();
}

class _ServerIPScreenState extends State<ServerIPScreen> {
  late Box serverIpBox;

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    serverIpBox = await Hive.openBox('settings');
    setState(() {}); // Refresh UI after box initialization
  }

  void _addOrEditServerIP() {
    final TextEditingController controller = TextEditingController(
      text: serverIpBox.get('serverip', defaultValue: ''),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Server IP'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Server IP',
              labelStyle: TextStyle(
                color: Colors
                    .grey, // Color of the label when the TextField is not focused
              ),
              floatingLabelStyle: TextStyle(
                color: Colors.black,
              ),
              hintText: 'e.g., 192.168.1.1',
              border: OutlineInputBorder(), // Default border
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color:
                      Colors.grey, // Border color when TextField is not focused
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.grey,
                  width: 2.0,
                ),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 14, color: Colors.black),
              ),
            ),
            // ElevatedButton(
            //   onPressed: () async {
            //     final enteredIp = controller.text.trim();
            //     if (enteredIp.isNotEmpty && _validateIpAddress(enteredIp)) {
            //       // Replace the existing server IP
            //       serverIpBox.put('serverip', enteredIp);
            //       setState(() {}); // Refresh the UI
            //       Navigator.of(context).pop();
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(content: Text('Server IP updated!')),
            //       );
            //       bool isServerOnline =
            //           await _checkServerAvailability(serverip);

            //       Provider.of<OrderProvider>(context, listen: false)
            //           .requestDataFromServer();
            //     } else {
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(content: Text('Invalid IP address!')),
            //       );
            //     }
            //   },
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: const Color(0xFFA5D6A7),
            //     padding:
            //         const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            //   ),
            //   child: const Text(
            //     'Save',
            //     style: TextStyle(fontSize: 14, color: Colors.black),
            //   ),
            // ),

            ElevatedButton(
              // onPressed: () async {
              //   final enteredIp = controller.text.trim();

              //   if (enteredIp.isNotEmpty && _validateIpAddress(enteredIp)) {
              //     // Replace the existing server IP

              //     // Check if the server is online
              //     bool isServerOnline =
              //         await _checkServerAvailability(enteredIp);
              //     setState(() {}); // Refresh the UI
              //     if (!isServerOnline) {
              //       ScaffoldMessenger.of(context).showSnackBar(
              //         const SnackBar(
              //           content: Text(
              //               "Server is offline. Please check the IP and try again."),
              //         ),
              //       );
              //       return;
              //     }

              //     // Proceed with WebSocket communication
              //     try {
              //       Provider.of<OrderProvider>(context, listen: false)
              //           .requestDataFromServer();
              //       await serverIpBox.put('serverip', enteredIp);
              //       Navigator.of(context).pop();

              //       ScaffoldMessenger.of(context).showSnackBar(
              //         const SnackBar(content: Text('Server IP updated!')),
              //       );

              //       // Navigate to LoginScreen only if the server is online
              //       Navigator.pushAndRemoveUntil(
              //         context,
              //         MaterialPageRoute(
              //             builder: (context) => const LoginScreen()),
              //         (Route<dynamic> route) => false,
              //       );
              //     } catch (e) {
              //       ScaffoldMessenger.of(context).showSnackBar(
              //         const SnackBar(
              //             content: Text(
              //                 "Failed to connect to the server. Please check the IP address.")),
              //       );
              //     }
              //   } else {
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       const SnackBar(content: Text('Invalid IP address!')),
              //     );
              //   }
              // },
              onPressed: () async {
                final enteredIp = controller.text.trim();

                if (enteredIp.isNotEmpty && _validateIpAddress(enteredIp)) {
                  // bool isServerOnline =
                  //     await _checkServerAvailability(enteredIp);
                  // setState(() {}); // Refresh the UI

                  //  if (!isServerOnline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Server is offline. Please check the IP and try again."),
                    ),
                  );
                  //   return;
                  // }

                  try {
                    await serverIpBox.put('serverip', enteredIp);

                    // ✅ NEW: Restart WebSocket Connection with new IP
                    WebSocketServicekot webSocketService =
                        Provider.of<WebSocketServicekot>(context,
                            listen: false);
                    webSocketService.reconnectWithNewIP(enteredIp);

                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Server IP updated!')),
                    );

                    // ✅ Navigate to LoginScreen only if the server is online
                    // ignore: use_build_context_synchronously
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "Failed to connect to the server. Please check the IP address."),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid IP address!')),
                  );
                }
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA5D6A7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 14, color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _validateIpAddress(String ip) {
    final RegExp ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$',
    );
    return ipRegex.hasMatch(ip);
  }

  // Future<bool> _checkServerAvailability(String serverIp) async {
  //   try {
  //     final WebSocketChannel channel = IOWebSocketChannel.connect(
  //         'ws://$serverIp:$port'); // Replace PORT with your WebSocket server port

  //     channel.sink
  //         .add(jsonEncode({'action': 'heartbeat'})); // Send a heartbeat message
  //     final response = await channel.stream.first.timeout(
  //       const Duration(seconds: 3),
  //       onTimeout: () {
  //         channel.sink.close();
  //         return null;
  //       },
  //     );

  //     if (response != null) {
  //       final data = jsonDecode(response);
  //       if (data['action'] == 'heartbeatAck') {
  //         channel.sink.close();
  //         return true; // Server is online
  //       }
  //     }
  //     channel.sink.close();
  //     return false;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final currentIp = serverIpBox.get('serverip', defaultValue: 'Not Set');

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Column(
            //mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Current Server IP:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                currentIp,
                style: const TextStyle(fontSize: 16, color: Colors.blue),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _addOrEditServerIP,
                icon: const Icon(
                  Icons.edit,
                  color: Colors.black,
                ),
                label: const Text(
                  'Edit Server IP',
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA5D6A7),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

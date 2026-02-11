import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;

import 'wifiFind.dart';

class WifiDevicesScreen extends StatefulWidget {
  const WifiDevicesScreen({Key? key}) : super(key: key);

  @override
  _WifiDevicesScreenState createState() => _WifiDevicesScreenState();
}

class _WifiDevicesScreenState extends State<WifiDevicesScreen> {
  // The list of scanned device IPs.
  List<String> deviceIPs = [];
  bool scanning = false;

  // Your WebSocket channel (nullable).
  WebSocketChannel? _channel;

  // A map to remember which IPs should be highlighted in green.
  // If isSameMap[ip] == true, we highlight that IP in green.
  Map<String, bool> isSameMap = {};

  @override
  void initState() {
    super.initState();
    _initWebSocket();
    _scanNetwork();
  }

  // Initialize the WebSocket channel and listen for messages.
  void _initWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://${globals.serverip}:${globals.port}'),
    );
    // Listen for messages from the server.
    _channel?.stream.listen(
      (data) {
        _handleIncomingMessage(data);
      },
      onError: (error) {
        // print('WebSocket error: $error');
      },
    );
  }

  // Parse the incoming JSON, look for "deviceIpGenerated"
  void _handleIncomingMessage(dynamic rawData) {
    try {
      final jsonData = jsonDecode(rawData);

      // If the action is "deviceIpGenerated", check isSame and highlight the IP if needed.
      if (jsonData['action'] == 'deviceIpGenerated') {
        final ip = jsonData['data']?['ip'];
        final bool isSame = jsonData['isSame'] ?? false;

        if (ip is String && isSame) {
          // Mark this IP as highlighted.
          setState(() {
            isSameMap[ip] = true;
          });
        }
        // Optionally, if isSame == false, you could remove highlighting:
        // else if (ip is String) {
        //   setState(() {
        //     isSameMap.remove(ip); // or set to false
        //   });
        // }
      }
    } catch (e) {}
  }

  // Send data to the server. If _channel is null, print an error.
  Future<void> sendIpServer(Map<String, dynamic> dataToSend) async {
    try {
      final jsonData = jsonEncode(dataToSend);
      if (_channel != null) {
        _channel!.sink.add(jsonData);
      } else {}
    } catch (e) {}
  }

  // Scan local network for IP addresses.
  Future<void> _scanNetwork() async {
    setState(() {
      scanning = true;
    });
    final ips = await scanLocalNetwork(); // from your wifiFind.dart
    setState(() {
      deviceIPs = ips;
      scanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connected Devices')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: scanning
            ? const Center(child: CircularProgressIndicator())
            : deviceIPs.isEmpty
            ? const Center(child: Text("No devices found"))
            : ListView.builder(
                itemCount: deviceIPs.length,
                itemBuilder: (context, index) {
                  final ip = deviceIPs[index];
                  // Check if this IP should be highlighted in green
                  final bool highlight = isSameMap[ip] == true;

                  return ListTile(
                    leading: Icon(
                      Icons.devices,
                      color: highlight ? Colors.green : Colors.grey,
                    ),
                    title: Text(
                      ip,
                      style: TextStyle(
                        color: highlight ? Colors.green : Colors.black,
                        fontWeight: highlight
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      // Send the selected IP to the server with type 'sentIp'.
                      sendIpServer({
                        'type': 'sentIp',
                        'ip': ip,
                        'deviceName': globals.deviceName,
                      });
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanNetwork,
        tooltip: 'Rescan',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

// server_app.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:udp/udp.dart';

void main() => runApp(ServerApp());

class ServerApp extends StatefulWidget {
  @override
  _ServerAppState createState() => _ServerAppState();
}

class _ServerAppState extends State<ServerApp> {
  final int udpPort = 9999;
  String? _deviceIp;
  String _status = "Initializing...";
  UDP? _receiver;
  BonsoirBroadcast? _broadcast;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    const String serviceType = "_myservice._udp";

    // Clean up old broadcast/receiver
    await _broadcast?.stop();
    _broadcast = null;
    _receiver?.close();
    _receiver = null;

    String? ip = await _getLocalIp();
    if (ip == null) {
      setState(() => _status = "❌ Could not determine IP");
      return;
    }

    setState(() {
      _deviceIp = ip;
      _status = "✅ Listening on $ip:$udpPort";
    });

    // Start UDP server
    _receiver = await UDP.bind(Endpoint.any(port: Port(udpPort)));
    _receiver?.asStream().listen((datagram) {
      if (datagram != null) {
        String msg = utf8.decode(datagram.data);
        setState(() {
          _status = "📩 Received: $msg from ${datagram.address.address}";
        });
      }
    });

    // Advertise service
    final service = BonsoirService(
      name: "MyServer-UDP-Host", // use fixed name
      type: serviceType,
      port: udpPort,
      attributes: {
        "host": ip,
        "port": udpPort.toString(),
      },
    );

    _broadcast = BonsoirBroadcast(service: service);
    await Future.delayed(Duration(milliseconds: 500)); // optional settle time
    await _broadcast!.ready;
    await _broadcast!.start();

  }

  Future<String?> _getLocalIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    _broadcast?.stop();
    _receiver?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("🔵 Server")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("IP: ${_deviceIp ?? '...'}", style: TextStyle(fontSize: 20)),
              SizedBox(height: 10),
              Text(_status, textAlign: TextAlign.center),
              Text(
                  "⏳ Server running... ${DateTime.now().toLocal().toIso8601String().substring(11, 19)}",
                  style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

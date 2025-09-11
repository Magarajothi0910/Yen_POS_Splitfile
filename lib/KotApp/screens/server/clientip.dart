import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);
  await Hive.openBox('serverBox');

  runApp(ClientApp());
}

class ClientApp extends StatefulWidget {
  @override
  _ClientAppState createState() => _ClientAppState();
}

class _ClientAppState extends State<ClientApp> {
  String serverIp = "Searching...";
  String serverPort = "Unknown";
  bool _found = false;
  BonsoirDiscovery? _discovery;
  late Box box;

  @override
  void initState() {
    super.initState();
    _startDiscovery();

    box = Hive.box('serverBox');
    _loadFromHive();
  }

  void _loadFromHive() {
    final storedIp = box.get('serverIp');
    final storedPort = box.get('serverPort');

    if (storedIp != null && storedPort != null) {
      setState(() {
        serverIp = storedIp;
        serverPort = storedPort;
      });
    }
  }

  Future<void> _saveToHive(String ip, String port) async {
    await box.put('serverIp', ip);
    await box.put('serverPort', port);
  }

  Future<void> _startDiscovery() async {
    await _discovery?.stop(); // Clean up previous discovery
    _discovery = BonsoirDiscovery(type: "_myservice._udp");

    await _discovery!.ready;
    await _discovery!.start();

    _discovery!.eventStream!.listen((event) async {
      if (_found) return;

      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        final BonsoirService service = event.service!;

        if (service.name != "MyServer-UDP-Host") return;

        // Wait for attributes to populate
        for (int i = 0; i < 5; i++) {
          await Future.delayed(Duration(seconds: 1));
          final ip = service.attributes?["host"];
          final port = service.attributes?["port"];

          if (ip != null && port != null) {
            setState(() {
              serverIp = ip;
              serverPort = port;
              _found = true;
            });
            await _saveToHive(ip, port);
            await _discovery?.stop();
            break;
          }
        }
      }
    });
  }

  Future<void> _restartDiscovery() async {
    await _discovery?.stop();
    setState(() {
      serverIp = "Retrying...";
      serverPort = "Unknown";
      _found = false;
    });
    await Future.delayed(Duration(seconds: 1));
    _startDiscovery();
  }

  @override
  void dispose() {
    _discovery?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("🟢 Client"),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _restartDiscovery,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startDiscovery,
                child: Text("Discover the Server IP"),
              ),
              SizedBox(height: 20),
              Text("Server IP: $serverIp", style: TextStyle(fontSize: 20)),
              SizedBox(height: 10),
              Text("Server Port: $serverPort", style: TextStyle(fontSize: 20)),
              SizedBox(height: 20),
              if (!_found) CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

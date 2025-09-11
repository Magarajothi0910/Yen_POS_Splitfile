import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import './../screens/kot_screen/global/globals.dart' as globals;

// Adjust the import based on your project structure
class GlobalSOWebSocketService {
  static final GlobalSOWebSocketService _instance =
      GlobalSOWebSocketService._internal();
  factory GlobalSOWebSocketService() => _instance;
  GlobalSOWebSocketService._internal();

  WebSocketChannel? _channel;
  final String _serverIp = '${globals.serverip}'; // Replace with actual IP
  final String _port = '${globals.port}'; // Replace with actual port

  void initialize() {
    if (_channel == null) {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$_serverIp:$_port'));
      _channel!.stream.listen(
        (data) => print('Received data: $data'),
        onError: (error) => print('WebSocket error: $error'),
        onDone: () => print('WebSocket connection closed'),
      );
    }
  }

  Future<void> sendData(Map<String, dynamic> data) async {
    try {
      if (_channel != null) {
        final jsonData = jsonEncode(data);
        _channel!.sink.add(jsonData);
       
      } else {
        
      }
    } catch (e) {
   
    }
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;

  }
}

import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef DataCallback = void Function(Map<String, dynamic> data);
final Set<WebSocketChannel> activeChannels = {};

void handleWebSocket(WebSocketChannel channel, Function(Map<String, dynamic>) onData) {
  if (activeChannels.contains(channel)) {
    print("⚠️ This WebSocketChannel is already being listened to.");
    return;
  }

  activeChannels.add(channel);

  channel.stream.listen(
    (message) {
      try {
        if (message is String && message.trim().isNotEmpty) {
          final fixedMessage = message.replaceAll("'", '"');
          final data = jsonDecode(fixedMessage);
          onData(data);
        }
      } catch (e) {
        print('❌ Error decoding WebSocket message: $e');
      }
    },
    onDone: () {
      print('🛑 WebSocket disconnected.');
      activeChannels.remove(channel);
    },
    onError: (error) {
      print('❌ WebSocket error: $error');
      activeChannels.remove(channel);
    },
    cancelOnError: true,
  );
}

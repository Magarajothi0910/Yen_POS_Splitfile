import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class NotificationWebSocketService {
  WebSocketChannel? channel;

  /// Connect to FastAPI WebSocket
  void connect(String url) {
    if (channel != null) return;

    try {
      debugPrint('🌐 Connecting to WebSocket $url ...');
      channel = WebSocketChannel.connect(Uri.parse(url));
      debugPrint('✅ WebSocket connected!');
    } catch (e) {
      debugPrint('❌ WebSocket connection failed: $e');
    }
  }

  void send(String message) {
    if (channel != null) {
      channel!.sink.add(message);
      debugPrint('📤 Sent: $message');
    } else {
      debugPrint('⚠️ Cannot send, WebSocket not connected');
    }
  }

  void disconnect() {
    if (channel != null) {
      debugPrint('🔌 Disconnecting WebSocket...');
      channel!.sink.close();
      channel = null;
    }
  }
}

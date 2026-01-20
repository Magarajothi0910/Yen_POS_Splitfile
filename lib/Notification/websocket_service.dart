import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class NotificationWebSocketService {
  final Map<String, WebSocketChannel> _channels = {};

  /// Connect using key = url
  WebSocketChannel connect(String url) {
    _logHeader("CONNECT REQUEST");

    if (_channels.containsKey(url)) {
      return _channels[url]!;
    }

    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));

      _channels[url] = channel;

      _logFooter("CONNECT COMPLETE");
      return channel;
    } catch (e) {
      _logFooter("CONNECT FAILED");
      rethrow;
    }
  }

  /// Disconnect a single WebSocket
  void disconnect(String url) {
    _logHeader("DISCONNECT REQUEST");

    if (_channels.containsKey(url)) {
      _channels[url]!.sink.close();

      _channels.remove(url);

 
    } else {}

    _logFooter("DISCONNECT COMPLETE");
  }

  /// Disconnect all WebSockets
  void disconnectAll() {
    _logHeader("DISCONNECT ALL REQUEST");

    if (_channels.isEmpty) {
      _logFooter("DISCONNECT ALL COMPLETE");
      return;
    }

    for (var entry in _channels.entries) {
      entry.value.sink.close();
    }

    _channels.clear();

    _logFooter("DISCONNECT ALL COMPLETE");
  }

  // ----------------- Utility Logging Helpers -----------------

  void _logHeader(String title) {}

  void _logFooter(String title) {}
}

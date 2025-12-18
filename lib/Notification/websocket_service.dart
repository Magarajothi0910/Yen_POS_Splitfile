import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class NotificationWebSocketService {
  final Map<String, WebSocketChannel> _channels = {};

  /// Connect using key = url
  WebSocketChannel connect(String url) {
    _logHeader("CONNECT REQUEST");

    debugPrint("🔑 WS Key (URL): $url");
    debugPrint("📊 Active connections count: ${_channels.length}");

    if (_channels.containsKey(url)) {
      debugPrint("⚠️ [SKIP] WebSocket already connected → $url");
      return _channels[url]!;
    }

    try {
      debugPrint("🌐 [CONNECTING] Creating WebSocketChannel...");
      final channel = WebSocketChannel.connect(Uri.parse(url));

      _channels[url] = channel;

      debugPrint("✨ [SUCCESS] WebSocket CONNECTED → $url");
      debugPrint(
        "📊 Active connections count (after connect): ${_channels.length}",
      );

      _logFooter("CONNECT COMPLETE");
      return channel;
    } catch (e) {
      debugPrint("❌ [ERROR] WebSocket connection FAILED → $url");
      debugPrint("💥 Exception Details: $e");

      _logFooter("CONNECT FAILED");
      rethrow;
    }
  }

  /// Disconnect a single WebSocket
  void disconnect(String url) {
    _logHeader("DISCONNECT REQUEST");

    debugPrint("🔑 WS Key (URL): $url");

    if (_channels.containsKey(url)) {
      debugPrint("🔌 [DISCONNECTING] Closing WebSocket → $url");
      _channels[url]!.sink.close();

      _channels.remove(url);

      debugPrint("✅ [SUCCESS] WebSocket disconnected → $url");
      debugPrint(
        "📊 Active connections count (after disconnect): ${_channels.length}",
      );
    } else {
      debugPrint("⚠️ [SKIP] Cannot disconnect — WS NOT FOUND → $url");
    }

    _logFooter("DISCONNECT COMPLETE");
  }

  /// Disconnect all WebSockets
  void disconnectAll() {
    _logHeader("DISCONNECT ALL REQUEST");

    debugPrint("📊 Total active connections: ${_channels.length}");

    if (_channels.isEmpty) {
      debugPrint("⚠️ No WebSockets to disconnect.");
      _logFooter("DISCONNECT ALL COMPLETE");
      return;
    }

    debugPrint("🔌 [DISCONNECTING] Closing ALL WebSocket connections...");

    for (var entry in _channels.entries) {
      debugPrint("   ❎ Closing: ${entry.key}");
      entry.value.sink.close();
    }

    _channels.clear();

    debugPrint("🛑 All WebSocket channels CLOSED");
    debugPrint("📊 Active connections count now: ${_channels.length}");

    _logFooter("DISCONNECT ALL COMPLETE");
  }

  // ----------------- Utility Logging Helpers -----------------

  void _logHeader(String title) {
    debugPrint("──────────────────────────────────────────────");
    debugPrint("🟦 [$title] — ${DateTime.now()}");
  }

  void _logFooter(String title) {
    debugPrint("🟩 [$title FINISHED] — ${DateTime.now()}");
    debugPrint("──────────────────────────────────────────────\n");
  }
}

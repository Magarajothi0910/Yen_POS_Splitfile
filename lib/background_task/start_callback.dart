import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:udp/udp.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/handlers/websocket_handler.dart' hide wsClients;
import 'package:yenpos/Server_Client/hive_service.dart';
import 'package:yenpos/Server_Client/serverreachable.dart';
import 'package:yenpos/Server_Client/websocketService.dart';

class ServerTaskHandler extends TaskHandler {
  HttpServer? _wsServer;
  UDP? _udpSender;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  late Box configBox;
  late Box serverBox;

  // ✅ Maintain connected WebSocket clients
  final Set<WebSocketChannel> clients = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {

    WebSocketService.instance.connect();
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocDir.path);
      await initHiveInBackground();
      configBox = await Hive.openBox('configBox');
      serverBox = await Hive.openBox('serverBox');
    } catch (e) {
      await configBox.put('lastError', 'Failed to initialize Hive: $e');
      return;
    }

    while (_retryCount < _maxRetries) {
      try {
        final appType = configBox.get('appType') ?? '';
        if (appType != 'server') {
          return;
        }

        final ip = await getLocalIp();
        if (ip == null) {
          _retryCount++;
          await Future.delayed(Duration(seconds: 5));
          continue;
        }

        serverip = ip;
        await serverBox.put('serverIp', ip);
        await serverBox.put('serverPort', port);

        // Close any existing server
        await _wsServer?.close(force: true);
        _wsServer = null;

        // ✅ Bind server (shared allows reuse for background tasks)
        _wsServer = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);


        // ✅ Handle new WebSocket connections
        _wsServer!
            .transform(WebSocketTransformer())
            .listen(
              (WebSocket socket) {
                final channel = IOWebSocketChannel(socket); // ✅ FIXED HERE
                clients.add(channel);


                // ✅ Central handler
                handleWebSocket(channel, clients, (data) {
                  receivedData.add(data);
                });

                socket.done
                    .then((_) {
                      clients.remove(channel);
                    })
                    .catchError((error) {
                      clients.remove(channel);
                    });
              },
              onError: (e) {
              },
            );

        // ✅ Start UDP responder
        await startUdpResponder();

        _retryCount = 0;
        break;
      } catch (e, st) {
        _retryCount++;
        await Future.delayed(Duration(seconds: 5 * _retryCount));
      }
    }

    if (_retryCount >= _maxRetries) {
      await configBox.put('lastError', 'Max retries exceeded for server start');
    }
  }

  Future<void> startUdpResponder() async {
    try {
      // Close existing UDP instance
      _udpSender?.close();
      _udpSender = await UDP.bind(Endpoint.any(port:  Port(udpPort)));


      _udpSender!.asStream().listen(
        (datagram) async {
          if (datagram != null) {
            final message = utf8.decode(datagram.data).trim();
            if (message == 'WHO_IS_SERVER') {
              final ip = serverip;
              final response = 'SERVER:$ip:8686';

              await _udpSender!.send(utf8.encode(response), Endpoint.broadcast(port:  Port(udpPort)));
            }
          }
        },
        onError: (e) async {
          await configBox.put('lastError', 'UDP listener error: $e');
        },
      );
    } catch (e) {
      await configBox.put('lastError', 'Failed to start UDP responder: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {

    // Restart WebSocket if stopped
    if (_wsServer == null) {
      await onStart(timestamp, TaskStarter.system);
    } else {
      final ip = await getLocalIp();
      if (ip != serverip) {
        await _wsServer?.close(force: true);
        _wsServer = null;
        _udpSender?.close();
        _udpSender = null;
        await onStart(timestamp, TaskStarter.system);
      }
    }

    // Restart UDP responder if closed
    if (_udpSender == null) {
      await startUdpResponder();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _wsServer?.close(force: true);
    _udpSender?.close();
    await Hive.close();
    _wsServer = null;
    _udpSender = null;
  }
}

// ✅ Background entry point
@pragma('vm:entry-point')
void startCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(ServerTaskHandler());
}

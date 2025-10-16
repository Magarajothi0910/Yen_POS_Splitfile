// lib/background/server_task_handler.dart
import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/websocketService.dart';

class ServerTaskHandler extends TaskHandler {
  HttpServer? _wsServer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // init Hive, DI, etc. here if you need
    WebSocketService(
      CustomerScreenProvider(),
      SalesInvoiceReceiptPrinter(),
    ).connect();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // heartbeat / metrics / reconnects
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _wsServer?.close();
    // Optional: schedule a WorkManager/AlarmManager ping to restart.
  }
}
// lib/background/start_callback.dart

@pragma('vm:entry-point') // very important
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ServerTaskHandler());
}

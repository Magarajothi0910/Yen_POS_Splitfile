// handlers/table_handler.dart
import 'package:web_socket_channel/web_socket_channel.dart';

import '../kotservices/sendDataToClients.dart';
import '../kotservices/sync_service.dart';

final SyncServiceKot _syncService = SyncServiceKot();

Future<void> handleSeatTapped(
    Map<String, dynamic> data, Set<WebSocketChannel> clients) async {

  sendDataToClients(data, clients);

}

Future<void> handleSeatReturned(
    Map<String, dynamic> data, Set<WebSocketChannel> clients) async {
  sendDataToClients(data, clients);
}

Future<void> handleKotTableStatusUpdate(Map<String, dynamic> data) async {
  await _syncService.saveTableStatusToHive(data);
  await _syncService.upsertKotTableStatus(data);
}

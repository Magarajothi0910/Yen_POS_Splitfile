import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';

import '../services/sendDataToClients.dart';
import '../services/sync_service.dart';

final SyncServiceKot _SyncServiceKot = SyncServiceKot();

Future<void> handleSeatTapped(
  Map<String, dynamic> data,
  //Set<WebSocketChannel> clients
) async {
  sendDataToClients(data, clients);
}

Future<void> handleSeatReturned(
  Map<String, dynamic> data,
  //Set<WebSocketChannel> clients
) async {
  sendDataToClients(data, clients);
}

Future<void> handleKotTableStatusUpdate(Map<String, dynamic> data) async {
  await _SyncServiceKot.saveTableStatusToHive(data);
  await _SyncServiceKot.upsertKotTableStatus(data);
}

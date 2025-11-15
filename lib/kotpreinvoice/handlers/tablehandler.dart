import '../services/sendDataToClients.dart';
import '../services/sync_service.dart';

final SyncServiceKot _SyncServiceKot = SyncServiceKot();

Future<void> handleSeatTapped(
  Map<String, dynamic> data,
  //Set<WebSocketChannel> clients
) async {
  sendDataToClientsKOT(data);
}

Future<void> handleSeatReturned(
  Map<String, dynamic> data,
  //Set<WebSocketChannel> clients
) async {
  sendDataToClientsKOT(data);
}

Future<void> handleKotTableStatusUpdate(Map<String, dynamic> data) async {
  await _SyncServiceKot.saveTableStatusToHive(data);
  await _SyncServiceKot.upsertKotTableStatus(data);
}

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';

Future<void> handleRemoveHoldOrdersKOT(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {
    debugPrint("handleRemoveHoldOrdersKOT data ::$data");

    final dataKey = data['data'];

    final holdOrdersBox = await Hive.openBox('holdOrdersKOT');

    if (holdOrdersBox.containsKey(dataKey)) {
      holdOrdersBox.delete(dataKey);
      debugPrint('🗑️ Removed hold order for this key $dataKey');
      // notifyListeners();
    } else {
      debugPrint('⚠️ No hold order to remove for $dataKey');
    }

    final removeHoldOrderData = {
      'action': 'removeHoldOrdersKOT',
      'data': dataKey,
    };

    if (appType == "server") {
      debugPrint("appType $appType");

      sendDataToClients(removeHoldOrderData, clients);
      debugPrint("remove hold order send to clients");
    }
  } catch (e) {
    debugPrint("handleAddHoldOrdersKOT :: $e");
  }
}

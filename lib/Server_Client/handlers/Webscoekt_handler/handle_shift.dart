import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';

Future<void> handleShiftOpen(Map<String, dynamic> jsonData) async {
  final shiftID = jsonData['shiftId'];
  // if (shiftIdKOT.contains(shiftID)) {
  //   print("⚠️ ShiftID already exists in Hive for shiftID: $shiftID");
  // } else {
  shiftIdKOT = shiftID;
  print("⚠️ ShiftID not exists for shiftID: $shiftIdKOT");
  sendDataToClients({'action': 'shiftIds', 'shiftIds': shiftIdKOT}, clients);
  // }
}

Future<void> handleShiftClose(Map<String, dynamic> jsonData) async {
  final shiftID = jsonData['shiftId'];
  // if (shiftIdList.contains(shiftID)) {
  //   print(
  //     "⚠️ ShiftID already exists in Hive for shiftID: $shiftID",
  //   );
  // } else {
  shiftIdKOT = '';
  sendDataToClients({'action': 'shiftIds', 'shiftIds': shiftIdKOT}, clients);

  print("ShiftID removed shiftID: $shiftIdKOT");
  //  }
}

Future<void> handleIp(Map<String, dynamic> jsonData) async {
  locSubnetIp.value = jsonData['ip'];
  print("locSubnetIp: ${locSubnetIp.value}");
}

Future<void> handleDineInShift() async {
  if (isDineInEnabled.value == true) {
    sendataToServer({'type': 'shiftCreated', 'shiftId': shiftId});
  }
}

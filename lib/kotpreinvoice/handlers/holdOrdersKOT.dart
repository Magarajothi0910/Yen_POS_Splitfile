import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';

Future<void> handleAddHoldOrdersKOT(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {
    debugPrint("handleAddHoldOrdersKOT data ::$data");

    final holdOrder = data['data'];

    final holdOrdersBox = await Hive.openBox('holdOrdersKOT');

    final key = '${holdOrder['table']}_${holdOrder['seat']}';

    holdOrdersBox.put(key, holdOrder);

    final HoldOrderData = {'action': 'addHoldOrdersKOT', 'data': holdOrder};

    if (appType == "server") {
      debugPrint("appType $appType");

      sendDataToClients(HoldOrderData, clients);
      debugPrint("hold order send to clients");

    }
  } catch (e) {
    debugPrint("handleAddHoldOrdersKOT :: $e");
  }
}

// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:yenpos/Global/globals_data.dart';
// import 'package:yenpos/Server_Client/sendDataToClients.dart';
// // import 'path/to/debouncer.dart'; // Adjust path
// import 'dart:async';

// // Static map: one Debouncer per table_seat key
// final Map<String, Debouncer> _holdOrderDebouncers = {};

// Future<void> handleAddHoldOrdersKOT(
//   Map<String, dynamic> data,
//   Set<WebSocketChannel> clients,
// ) async {
//   try {
//     debugPrint("handleAddHoldOrdersKOT data ::$data");

//     final holdOrder = data['data'];
//     final table = holdOrder['table'] as String;
//     final seat = holdOrder['seat'] as String;
//     final key = '${table}_$seat';

//     // Get or create debouncer for this specific table+seat
//     final debouncer = _holdOrderDebouncers.putIfAbsent(
//       key,
//       () => Debouncer(
//         delay: const Duration(milliseconds: 500),
//       ), // Adjust delay as needed
//     );

//     // Debounce: only save & broadcast the LAST version after no more additions for 500ms
//     debouncer.debounce(() async {
//       final holdOrdersBox = await Hive.openBox('holdOrdersKOT');

//       // Save the latest holdOrder (which now includes all items like paal bun, butter bun, etc.)
//       holdOrdersBox.put(key, holdOrder);

//       final holdOrderData = {'action': 'addHoldOrdersKOT', 'data': holdOrder};

//       if (appType == "server") {
//         debugPrint(
//           "appType $appType - Broadcasting debounced hold order for $key",
//         );
//         sendDataToClients(holdOrderData, clients);
//       }
//     });
//   } catch (e) {
//     debugPrint("handleAddHoldOrdersKOT error :: $e");
//   }
// }

// class Debouncer {
//   final Duration delay;
//   Timer? _timer;

//   Debouncer({required this.delay});

//   void debounce(VoidCallback action) {
//     _timer?.cancel();
//     _timer = Timer(delay, action);
//   }

//   void dispose() {
//     _timer?.cancel();
//   }
// }

// // services/order_patch_service.dart

// import 'dart:convert';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

// import '../models/hive boxes.dart';

// class OrderPatchService {
//   static Future<void> patchOrderCancellation({
//     required String seathiveOrderId,
//     required String remark,
//     required WebSocketChannel channel,
//     List<Map<String, dynamic>>? inMemoryOrders,
//   }) async {
//     // Define the new cancellation status.
//     const String newStatus = 'cancelled';

//     print('inMemoryOrders : $inMemoryOrders');

//     // *** Local Update: Update the Hive storage without modifying preinvoiceTime ***
//     final ordersBox = Hive.box('ordersBox'); // Ensure the box is open

//     List<Map<String , dynamic>> matchingOrders = [];

//     final dynamic data = ordersBox.get('data');
//     if (data != null && data is List) {

//       // If orders are stored as a list under the key 'data', update that list.
//       for (var order in data) {
//         if (order is Map<String, dynamic> &&
//             order['seathiveOrderId'] == seathiveOrderId) {
//           order['status'] = newStatus;
//           order['orderRemark'] = remark;
//           // Omit updating preinvoiceTime for cancellation
//           order['edit'] = "Yes";
//           order['sync'] = "No";
//           order['statusEdited'] = "true";
//         }
//       }

//       await ordersBox.put('data', data);
//     } else {
//       // Otherwise, iterate through separate Hive keys.
//       for (var key in ordersBox.keys) {
//         var order = ordersBox.get(key);
//         if (order is Map<String, dynamic> &&
//             order['seathiveOrderId'] == seathiveOrderId) {
//           order['status'] = newStatus;
//           order['orderRemark'] = remark;
//           order['edit'] = "Yes";
//           order['sync'] = "No";
//           order['statusEdited'] = "true";
//           await ordersBox.put(key, order);
//         }
//       }
//     }

//     // *** In-Memory Update (Optional) ***
//     if (inMemoryOrders != null) {
//       for (var order in inMemoryOrders) {
//         if (order['seathiveOrderId'] == seathiveOrderId) {
//           order['status'] = newStatus;
//           order['orderRemark'] = remark;
//           order['edit'] = "Yes";
//           order['sync'] = "No";
//           order['statusEdited'] = "true";
//         }
//       }
//     }

//     // *** Prepare and send the patch object via WebSocket ***
//     final Map<String, dynamic> patchData = {
//       'action': 'FullCancelOrderPatch',
//       'data': inMemoryOrders,
//       'seathiveOrderId': seathiveOrderId,
//       'status': newStatus,
//       'orderRemark': remark,
//       // Notice no preinvoiceTime is being sent.
//       'statusEdited': "true",
//       'edit': "Yes",
//       'sync': "No",
//     };

//     try {
//       channel.sink.add(jsonEncode(patchData));
//       print("Patch sent to server: $patchData");
//     } catch (e) {
//       print("Error sending patch: $e");
//     }
//   }
// }

// services/order_patch_service.dart

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';

class OrderPatchService {
  static Future<void> patchOrderCancellation({
    required String seathiveOrderId,
    required String remark,
    required WebSocketChannel channel,
    List<Map<String, dynamic>>? inMemoryOrders,
  }) async {
    const String newStatus = 'cancelled';

    final Box ordersBox = Hive.box('ordersBox');

    /// ==============================
    /// 1️⃣ Update Hive (Local Storage)
    /// ==============================
    final dynamic hiveData = ordersBox.get('data');

    if (hiveData != null && hiveData is List) {
      for (final order in hiveData) {
        if (order is Map<String, dynamic> &&
            order['seathiveOrderId'] == seathiveOrderId) {
          order['status'] = newStatus;
          order['orderRemark'] = remark;
          order['edit'] = "Yes";
          order['sync'] = "No";
          order['statusEdited'] = "true";
        }
      }
      await ordersBox.put('data', hiveData);
    } else {
      for (final key in ordersBox.keys) {
        final order = ordersBox.get(key);
        if (order is Map<String, dynamic> &&
            order['seathiveOrderId'] == seathiveOrderId) {
          order['status'] = newStatus;
          order['orderRemark'] = remark;
          order['edit'] = "Yes";
          order['sync'] = "No";
          order['statusEdited'] = "true";
          await ordersBox.put(key, order);
        }
      }
    }

    /// ==================================
    /// 2️⃣ Update In-Memory Orders (Optional)
    /// ==================================
    if (inMemoryOrders != null) {
      for (final order in inMemoryOrders) {
        if (order['seathiveOrderId'] == seathiveOrderId) {
          order['status'] = newStatus;
          order['orderRemark'] = remark;
          order['edit'] = "Yes";
          order['sync'] = "No";
          order['statusEdited'] = "true";
        }
      }
    }

    /// =====================================
    /// 3️⃣ Prepare PATCH Payload (Filtered)
    /// =====================================
    final List<Map<String, dynamic>> patchedOrders = (inMemoryOrders ?? [])
        .where((order) => order['seathiveOrderId'] == seathiveOrderId)
        .map((order) => Map<String, dynamic>.from(order))
        .toList();

    /// ==========================
    /// 4️⃣ WebSocket PATCH Object
    /// ==========================
    final Map<String, dynamic> patchData = {
      'action': 'FullCancelOrderPatch',
      'seathiveOrderId': seathiveOrderId,
      'status': newStatus,
      'orderRemark': remark,
      'statusEdited': "true",
      'edit': "Yes",
      'sync': "No",
      'data': patchedOrders, // ✅ only matching orders
    };

    /// ======================
    /// 5️⃣ Send via WebSocket
    /// ======================
    try {
      sendataToServer(patchData);
      print('[PATCH] Sent: $patchData');
    } catch (e) {
      print('[PATCH] WebSocket Error: $e');
    }
  }
}

// lib/handlers/order_cancel_patch_receiver.dart

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

// /// Applies an 'orderCancelled' patch payload from the server
// /// into both in‑memory state and your Hive “data” box.
// Future<void> applyOrderCancelPatch({
//   required Box orderBox,
//   required List<Map<String, dynamic>> inMemoryOrders,
//   required Map<String, dynamic> data,
// }) async {
//   final hiveOrderId = data['hiveOrderId'] as String;

//   /// Utility to parse either a List or a JSON‐string into List<double>
//   List<double> _parseDoubleList(dynamic raw) {
//     if (raw is String) {
//       // sometimes comes through as a JSON‐encoded string
//       final decoded = jsonDecode(raw);
//       if (decoded is List) {
//         return decoded.map((e) => (e as num).toDouble()).toList();
//       }
//     } else if (raw is List) {
//       return raw.map((e) => (e as num).toDouble()).toList();
//     }
//     return <double>[];
//   }

//   final cancelledQty = _parseDoubleList(data['cancelledQty']);
//   final quantities = _parseDoubleList(data['quantities']);
//   final totalAmount = (data['totalAmount'] as num).toDouble();
//   final partiallyCancelled = data['partiallycancelled'];

//   // itemRemark may be a list of strings or a single string
//   List<String> itemRemark;
//   final rawRemark = data['itemRemark'];
//   if (rawRemark is String) {
//     itemRemark = [rawRemark];
//   } else if (rawRemark is List) {
//     itemRemark = rawRemark.map((e) => e.toString()).toList();
//   } else {
//     itemRemark = <String>[];
//   }

//   // 1) Update in‑memory
//   for (var order in inMemoryOrders) {
//     if (order['hiveOrderId'] == hiveOrderId) {
//       order['cancelledQty'] = cancelledQty;
//       order['quantities'] = quantities;
//       order['totalAmount'] = totalAmount;
//       order['itemRemark'] = itemRemark;
//       order['partiallyCancelled'] = partiallyCancelled;
//       break;
//     }
//   }

//   // 2) Update the Hive‐stored list under key 'data'
//   final raw = await orderBox.get('data') as List<dynamic>? ?? [];
//   final disk = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

//   for (var ord in disk) {
//     if (ord['hiveOrderId'] == hiveOrderId) {
//       ord['cancelledQty'] = cancelledQty;
//       ord['quantities'] = quantities;
//       ord['totalAmount'] = totalAmount;
//       ord['itemRemark'] = itemRemark;
//       ord['partiallyCancelled'] = partiallyCancelled;
//       break;
//     }
//   }

//   await orderBox.put('data', disk);
//   print("✅ Client patched order $hiveOrderId in Hive & memory");
// }
Future<void> applyOrderCancelPatch({
  required Box orderBox,
  required List<Map<String, dynamic>> inMemoryOrders,
  required Map<String, dynamic> data,
}) async {
  final hiveOrderId = data['hiveOrderId'] as String;

  List<double> _parseDoubleList(dynamic raw) {
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
    } else if (raw is List) {
      return raw.map((e) => (e as num).toDouble()).toList();
    }
    return <double>[];
  }

  final cancelledQty = _parseDoubleList(data['cancelledQty']);
  final quantities = _parseDoubleList(data['quantities']);
  final totalAmount = (data['totalAmount'] as num).toDouble();
  final partiallyCancelled = data['partiallycancelled'];

  List<String> itemRemark;
  final rawRemark = data['itemRemark'];
  if (rawRemark is String) {
    itemRemark = [rawRemark];
  } else if (rawRemark is List) {
    itemRemark = rawRemark.map((e) => e.toString()).toList();
  } else {
    itemRemark = <String>[];
  }

  final status = data['status']; // ✅ NEW: read status if available

  // 1) Update in-memory list
  for (var order in inMemoryOrders) {
    if (order['hiveOrderId'] == hiveOrderId) {
      order['cancelledQty'] = cancelledQty;
      order['quantities'] = quantities;
      order['totalAmount'] = totalAmount;
      order['itemRemark'] = itemRemark;
      order['partiallyCancelled'] = partiallyCancelled;
      if (status != null) {
        order['status'] = status; // ✅ Set status in memory
      }
      break;
    }
  }

  // 2) Update Hive-stored list under key 'data'
  final raw = await orderBox.get('data') as List<dynamic>? ?? [];
  final disk = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  for (var ord in disk) {
    if (ord['hiveOrderId'] == hiveOrderId) {
      ord['cancelledQty'] = cancelledQty;
      ord['quantities'] = quantities;
      ord['totalAmount'] = totalAmount;
      ord['itemRemark'] = itemRemark;
      ord['partiallyCancelled'] = partiallyCancelled;
      if (status != null) {
        ord['status'] = status; // ✅ Set status in Hive
      }
      break;
    }
  }

  await orderBox.put('data', disk);
  
}

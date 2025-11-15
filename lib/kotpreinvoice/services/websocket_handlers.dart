// import 'dart:convert';
// import 'dart:io';
// import 'package:provider/provider.dart';
// import '../../main.dart';
// import '../providers/printer_provider.dart';
// import '../providers/upi_provider.dart';
// import '../services/Token_service.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:flutter/material.dart';

// import '../handlers/FullCancelOrder_Handler.dart';
// import '../handlers/ItemWiseCancel.dart';
// import '../handlers/handleseatTransfer.dart';
// import '../handlers/invoice handler.dart';
// import '../handlers/orderhandlers.dart';
// import '../handlers/reverseOrder_handler.dart';
// import 'package:yenpos/Global/globals_data.dart';
// import '../../kotpreinvoice/Repository/itemRepo.dart';
// import '../../kotpreinvoice/Repository/patchSeatOrderStatus.dart';
// import '../services/sendDataToClients.dart';

// typedef DataHandler = void Function(Map<String, dynamic>);

// /// Handles WebSocket connection for one client
// void handleWebSocket(WebSocket socket, DataHandler onDataReceived) {
//   final channel = IOWebSocketChannel(socket);
//   clients.add(channel);
//   debugPrint("🔗 New WebSocket client connected from $socket. Total: ${clients.length}");

//   // ---------- ACTION HANDLERS ----------
//   final actionHandlers = <String, DataHandler>{
//     'ping': (data) {
//       // Ignore protocol ping; WebSocket handles pong automatically
//       debugPrint("📡 Ignored protocol ping.");
//     },
//     'heartbeat': (data) {
//       // Custom heartbeat: Send ack to confirm
//       channel.sink.add(jsonEncode({'action': 'heartbeat_ack'}));
//       debugPrint("📡 Heartbeat received; ack sent.");
//     },
//     'hello': (data) {
//       channel.sink.add(jsonEncode({'action': 'response', 'message': '👋 Hello Client, message received!'}));
//     },
//     'requestBranchwiseItemsForClient': (data) async {
//       try {
//         final branchwiseItems = await getBranchwiseItemsFromLazyBox();
//         if (branchwiseItems.isNotEmpty) {
//           channel.sink.add(jsonEncode({
//             'action': 'branchwiseItems',
//             'data': branchwiseItems,
//           }));
//           debugPrint("📦 Sent branchwise items to client");
//         }
//       } catch (e, st) {
//         debugPrint("❌ Error sending branchwise items: $e\n$st");
//       }
//     },
//     'requestAllData': (data) async {
//       try {
//         final context = MyApp.navigatorKey.currentContext;
//         if (context != null) {
//           final upiProvider = Provider.of<UpiProviderDine>(context, listen: false);
//           final upiState = upiProvider.isUpiEnabled;

//           debugPrint("💡 Preparing to send all data with UPI state: $upiState");

//           await sendAllDataToClient(channel, isUpiEnabled: upiState);

//           debugPrint("📡 Sent full data snapshot to client (UPI state: $upiState)");
//         } else {
//           debugPrint("⚠️ Could not update UPI state — no active context available");
//         }
//       } catch (e, st) {
//         debugPrint("❌ Error sending all data: $e\n$st");
//       }
//     },
//     'seat_tapped': (data) {
//       sendDataToClientsKOT(data);
//       onDataReceived(data);
//       debugPrint("🪑 Seat tapped → broadcasted");
//     },
//     'seat_returned': (data) {
//       sendDataToClientsKOT(data);
//       onDataReceived(data);
//       debugPrint("↩️ Seat returned → broadcasted");
//     },
//     'patchOrderStatusBySeathiveOrderId': (data) async {
//       try {
//         final seathiveOrderId = data['seathiveOrderId']?.toString() ?? '';
//         final newStatus = data['status']?.toString() ?? '';
//         final preinvoiceTime = data['preinvoiceTime']?.toString() ?? '';
//         final orderRemark = data['orderRemark']?.toString() ?? '';

//         await handlePatchOrderStatusBySeathiveOrderId(
//           receivedData: receivedData,
//           seathiveOrderId: seathiveOrderId,
//           newStatus: newStatus,
//           orderRemark: orderRemark,
//           preinvoiceTime: preinvoiceTime,
//         );
//         debugPrint("✅ Patched order status for seatHiveOrderId=$seathiveOrderId");
//       } catch (e, st) {
//         debugPrint("❌ Error patching order status: $e\n$st");
//       }
//     },
//     'seat_transfer': (data) async {
//       try {
//         debugPrint("🔄 Handling seat transfer: $data");
//         await handleSeatTransfer(data: data, receivedData: receivedData);
//         debugPrint("✅ Seat transfer complete");
//       } catch (e, st) {
//         debugPrint("❌ Error transferring seat: $e\n$st");
//       }
//     },
//     'newClientConnected': (data) async {
//       try {
//         final deviceCode = data['deviceCode']?.toString();
//         if (deviceCode != null) {
//           // Deduplicate: Close old channel for this deviceCode
//           if (deviceClientMap.containsKey(deviceCode)) {
//             final oldChannel = deviceClientMap[deviceCode];
//             clients.remove(oldChannel);
//             oldChannel?.sink.close();
//             debugPrint("🔌 Removed old connection for deviceCode: $deviceCode");
//           }
//           // Associate new channel with deviceCode
//           deviceClientMap[deviceCode] = channel;
//           debugPrint("🔗 Associated deviceCode: $deviceCode with channel");
//         }
//         await handleNewClientConnected(data, channel);
//         debugPrint("👥 New client handshake complete for deviceCode: $deviceCode");
//       } catch (e, st) {
//         debugPrint("❌ Error handling new client: $e\n$st");
//       }
//     },
//     'FullCancelOrderPatch': (data) async {
//       try {
//         await OrderPatchHandler.handleFullCancelOrderPatch(data);
//         debugPrint("🗑️ Full order cancel patch applied");
//       } catch (e, st) {
//         debugPrint("❌ Error full cancel order patch: $e\n$st");
//       }
//     },
//     'cancelOrderItem': (data) async {
//       try {
//         await CancelOrderPatchHandler.patchCancelOrderItem(data);
//         debugPrint("❌ Cancelled order item");
//       } catch (e, st) {
//         debugPrint("❌ Error cancelling order item: $e\n$st");
//       }
//     },
//     'reverseCancelOrderItem': (data) async {
//       try {
//         final hiveOrderId = data['hiveOrderId'];
//         final int updatedIndex = data['updatedIndex'];
//         final double updatedQty = (data['updatedQuantity'] as num).toDouble();
//         final double updatedCancelledQty = (data['updatedCancelledQty'] as num).toDouble();
//         final double totalAmount = (data['totalAmount'] as num).toDouble();
//         final bool partiallycancelled = data['partiallycancelled'] == true;

//         await patchOrderInHiveIndexWise(
//           hiveOrderId,
//           updatedIndex,
//           updatedQty,
//           updatedCancelledQty,
//           totalAmount,
//           partiallycancelled,
//         );

//         sendDataToClientsKOT({
//           'action': 'reverseCancelOrderItem',
//           'hiveOrderId': hiveOrderId,
//           'updatedIndex': updatedIndex,
//           'updatedQuantity': updatedQty,
//           'updatedCancelledQty': updatedCancelledQty,
//           'totalAmount': totalAmount,
//           'partiallycancelled': partiallycancelled,
//         });
//         debugPrint("↩️ Reversed cancelled item for order=$hiveOrderId");
//       } catch (e, st) {
//         debugPrint("❌ Error reversing cancel order item: $e\n$st");
//       }
//     },
//   };

//   // ---------- TYPE HANDLERS ----------
//   final typeHandlers = <String, Future<void> Function(Map<String, dynamic>)>{
//     'order': handleOrder,
//     'invoice': handleInvoice,
//     'posInvoice': handleInvoice,
//   };

//   // ---------- MESSAGE LISTENER ----------
//   channel.stream.listen(
//     (message) async {
//       try {
//         if (message is! String || message.trim().isEmpty) {
//           debugPrint("📡 Ignored non-string/binary message.");
//           return;
//         }

//         // Ensure valid JSON
//         final String fixedMessage = message.replaceAll("'", '"');
//         final data = jsonDecode(fixedMessage);

//         if (data is! Map<String, dynamic>) {
//           debugPrint("⚠️ Ignored non-map data: $data");
//           return;
//         }

//         if (data.containsKey('action') && actionHandlers.containsKey(data['action'])) {
//           actionHandlers[data['action']]!(data);
//         } else if (data.containsKey('type') && typeHandlers.containsKey(data['type'])) {
//           typeHandlers[data['type']]!(data);
//         } else {
//           debugPrint("⚠️ Unhandled message: $data");
//         }
//       } catch (e, st) {
//         debugPrint('❌ Error decoding WebSocket message: $e\n$st');
//       }
//     },
//     onDone: () {
//       // Cleanup: Remove from clients and deviceClientMap
//       clients.remove(channel);
//       deviceClientMap.removeWhere((key, value) => value == channel);
//       channel.sink.close();
//       debugPrint("🔌 Client disconnected. Total: ${clients.length}");
//     },
//     onError: (error, stackTrace) {
//       // Cleanup: Remove from clients and deviceClientMap
//       clients.remove(channel);
//       deviceClientMap.removeWhere((key, value) => value == channel);
//       channel.sink.close();
//       debugPrint("💥 WebSocket error: $error\n$stackTrace");
//     },
//     cancelOnError: true,
//   );
// }

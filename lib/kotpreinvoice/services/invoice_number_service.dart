// import 'dart:convert';
// import 'dart:async';
// import 'dart:io';
// import 'package:uuid/uuid.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:yenpos/kotpreinvoice/services/preInvociePrint_services.dart';

// Future<void> requestAndPrintPreInvoice({
//   required WebSocketChannel channel,
//   required String ipAddress,
//   required String tableNumber,
//   required String seat,
//   required String areaName,
//   required List<Map<String, dynamic>> seatOrders,
//   required String userName,
//   required String waiter,
//   required String seathiveOrderId,
// }) async {
//   final String requestId = const Uuid().v4(); // Unique per client
//   print(
//     '🧾 [Invoice] Requesting pre-invoice for $tableNumber-$seat | Request ID: $requestId',
//   );

//   final request = {
//     'action': 'get_invoice_number',
//     'requestId': requestId,
//     'tableNumber': tableNumber,
//     'seat': seat,
//     'areaName': areaName,
//   };

//   try {
//     // ✅ 1️⃣ Send request to server
//     print('📤 [WebSocket] Sending invoice number request: $request');
//     channel.sink.add(jsonEncode(request));

//     // ✅ 2️⃣ Wait for server response
//     final completer = Completer<String>();
//     late StreamSubscription subscription;

//     subscription = channel.stream.listen(
//       (data) async {
//         try {
//           print('📩 [WebSocket] Received data: $data');
//           final jsonData = jsonDecode(data);

//           // ✅ Match correct response using requestId
//           if (jsonData['action'] == 'invoice_number_response' &&
//               jsonData['requestId'] == requestId) {
//             final String invoiceNo = jsonData['invoiceNo'] ?? '';
//             print(
//               '✅ [Invoice] Received invoice number: $invoiceNo for request: $requestId',
//             );

//             // ✅ 3️⃣ Send updated order data back to server
//             final updatePayload = {
//               'action': 'update_orders_with_invoice',
//               'invoiceNo': invoiceNo,
//               'seathiveOrderId': seathiveOrderId,
//             };
//             print('📤 [WebSocket] Sending update payload: $updatePayload');
//             channel.sink.add(jsonEncode(updatePayload));

//             // ✅ 4️⃣ Print pre-invoice
//             try {
//               print(
//                 '🖨️ [Printer] Printing pre-invoice for table: $tableNumber, seat: $seat',
//               );
//               await InvoicePrinter.printReceipt(
//                 ipAddress: ipAddress,
//                 tableNumber: tableNumber,
//                 seat: seat,
//                 areaName: areaName,
//                 seatOrders: seatOrders,
//                 userName: userName,
//                 waiter: waiter,
//                 invoiceNo: invoiceNo,
//               );
//               print('✅ [Printer] Pre-invoice printed successfully.');
//             } catch (printerError) {
//               print(
//                 '🧨 [Printer Error] Failed to print invoice: $printerError',
//               );
//             }

//             completer.complete(invoiceNo);
//             await subscription.cancel();
//           }
//         } catch (e, stack) {
//           print('⚠️ [WebSocket Error] Failed to parse or handle message: $e');
//           print('📜 Stack Trace: $stack');
//         }
//       },
//       onError: (error) async {
//         print('🚨 [WebSocket Error] Stream error: $error');
//         if (!completer.isCompleted) completer.completeError(error);
//         await subscription.cancel();
//       },
//       onDone: () async {
//         print('🔚 [WebSocket] Connection closed by server.');
//         if (!completer.isCompleted)
//           completer.completeError(Exception('Connection closed.'));
//       },
//       cancelOnError: true,
//     );

//     // ✅ 5️⃣ Timeout handling
//     await completer.future.timeout(
//       const Duration(seconds: 5),
//       onTimeout: () async {
//         print('⏰ [Timeout] No invoice number received within 5 seconds.');
//         await subscription.cancel();
//         throw Exception('Timeout waiting for invoice number from server.');
//       },
//     );
//   } on TimeoutException catch (e) {
//     print('⏱️ [TimeoutException] $e');
//     rethrow;
//   } on WebSocketChannelException catch (e) {
//     print('🧨 [WebSocketChannelException] WebSocket failure: $e');
//     rethrow;
//   } on SocketException catch (e) {
//     print('📴 [SocketException] No internet or server unreachable: $e');
//     rethrow;
//   } catch (e, stack) {
//     print('💥 [Unexpected Error] $e');
//     print('📜 Stack Trace: $stack');
//     rethrow;
//   } finally {
//     print(
//       '🧹 [Cleanup] requestAndPrintPreInvoice completed for $tableNumber-$seat',
//     );
//   }
// }

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:server/services/send_data_to_server.dart';
import 'package:yenpos/Sale_order/Widgets/Send_data_to_server.dart';

// Future<void> sendPreInvoiceToServer({
//   required BuildContext context,
//   required String tableNumber,
//   required String seat,
//   required String areaName,
//   required List<Map<String, dynamic>> seatOrders,
//   required String ipAddress,
//   required String userName,
//   required String waiter,
//   required String seathiveOrderId,
// }) async {
//   print('🧾 [PreInvoice] Sending pre-invoice request to server…');

//   final payload = {
//     'action': 'handle_invoice_request',
//     'tableNumber': tableNumber,
//     'seat': seat,
//     'areaName': areaName,
//     'userName': userName,
//     'ipAddress': ipAddress,
//     'waiter': waiter,
//     'orders': seatOrders,
//     'seathiveOrderId': seathiveOrderId,
//   };

//   try {
//     print('📤 [WebSocket] Sending pre-invoice payload: $payload');
//     sendataToServer(payload);
//     print('✅ [PreInvoice] Payload sent successfully. Server will generate invoice & print.');
//   } catch (e, stack) {
//     print('❌ [PreInvoice Error] Failed to send pre-invoice: $e');
//     print(stack);
//     rethrow;
//   }
// }

Future<void> sendPreInvoiceToServer({
  required BuildContext context,
  required String tableNumber,
  required String seat,
  required String areaName,
  required List<Map<String, dynamic>> seatOrders,
  required String ipAddress,
  required String userName,
  required String waiter,
  required String seathiveOrderId,
}) async {
  print('🧾 [PreInvoice] Sending pre-invoice request to server…');
  final String currentTime = DateFormat("hh:mm:ss a").format(DateTime.now());
  final payload = {
    'action': 'handle_invoice_request',
    'tableNumber': tableNumber,
    'seat': seat,
    'areaName': areaName,
    'userName': userName,
    'ipAddress': ipAddress,
    'waiter': waiter,
    'orders': seatOrders,
    'preinvoiceTime': currentTime,
    'seathiveOrderId': seathiveOrderId,
  };

  try {
    print('📤 [WebSocket] Sending pre-invoice payload: $payload');
    sendataToServer(payload);
    print(
      '✅ [PreInvoice] Payload sent successfully. Server will generate invoice & print.',
    );
  } catch (e, stack) {
    print('❌ [PreInvoice Error] Failed to send pre-invoice: $e');
    print(stack);
    rethrow;
  }
}

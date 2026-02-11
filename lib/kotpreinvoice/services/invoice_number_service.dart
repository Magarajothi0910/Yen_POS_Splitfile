import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';

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

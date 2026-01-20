import 'package:flutter/material.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';

Future<void> handlePatchSalesApprovalOrder(
  Map<String, dynamic> jsonData,
  CustomerScreenProvider customerProvider,
) async {

  // Extract Sale Order Number
  final soNo = jsonData['saleOrderNo']?.toString() ?? '';

  if (soNo.isEmpty) {
    return;
  }

  try {
    await handlePatchSaleApprovalOrderMessage(jsonData);

    final orders = await getSavedApprovalOrder();

    if (orders.isEmpty) {
      return;
    }


    final matchedOrder = orders.firstWhere(
      (order) =>
          (order['data']?['saleOrderNo']?.toString() == soNo) ||
          (order['saleOrderNo']?.toString() == soNo),
      orElse: () => {},
    );


    if (matchedOrder.isEmpty) {
      return;
    }


  } catch (e, st) {
  }
}

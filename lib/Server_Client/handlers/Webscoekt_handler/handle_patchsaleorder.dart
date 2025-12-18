import 'package:flutter/material.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';

Future<void> handlePatchSalesOrder(
  Map<String, dynamic> jsonData,
  CustomerScreenProvider customerProvider,
) async {
  // Extract Sale Order Number
  final soNo = jsonData['saleOrderNo']?.toString() ?? '';
  if (soNo.isEmpty) {
    return;
  }

  try {
    // Step 1️⃣ Handle patch data update
    await handlePatchSaleOrderMessage(jsonData);

    // Step 2️⃣ Get updated sales orders
    final orders = await getSavedSalesOrders();

    if (orders.isEmpty) {
      return;
    }

    // Step 3️⃣ Find the matching patched order
    final matchedOrder = orders.firstWhere(
      (order) =>
          (order['data']?['saleOrderNo']?.toString() == soNo) ||
          (order['saleOrderNo']?.toString() == soNo),
      orElse: () => {},
    );

    if (matchedOrder.isEmpty) {
      return;
    }
    // Step 4️⃣ Send the matched order to provider for printing
    customerProvider.updatePatchReceiptData(matchedOrder);
  } catch (e, st) {}
}

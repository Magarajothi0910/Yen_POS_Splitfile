import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';

final Set<String> _processedOrders = {};
final Set<String> _activeOrders = {};

Future<void> handleModifyOrder(
  Map<String, dynamic> jsonData,
  CustomerScreenProvider customerProvider,
) async {
  Map<String, dynamic>? orderData;

  try {
    final salesOrder = jsonData['modifyOrder'];
    if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
      return;
    }

    orderData = salesOrder['data'] ?? {};
    if (orderData is! Map<String, dynamic>) {
      return;
    }

    final saleOrderNo = orderData['saleOrderNo']?.toString();

    if (saleOrderNo == null || saleOrderNo.isEmpty) {
      return;
    }

    if (_activeOrders.contains(saleOrderNo)) {
      return;
    }

    if (_processedOrders.contains(saleOrderNo)) {
      return;
    }

    _activeOrders.add(saleOrderNo);

    // Extract audio and image paths
    final audioPath = salesOrder["data"]?['audioPath'] ?? '';
    final image1Path = salesOrder["data"]?['imagePath1'] ?? '';
    final image2Path = salesOrder["data"]?['imagePath2'] ?? '';

    orderData['type'] = 'salesOrder';
    orderData['audioPath'] = audioPath;
    orderData['imagePath1'] = image1Path;
    orderData['imagePath2'] = image2Path;

    final salesOrderBox = HiveManager.modifyOrderBox;
    if (salesOrderBox.containsKey(saleOrderNo)) {
      _processedOrders.add(saleOrderNo);
      _activeOrders.remove(saleOrderNo);
      return;
    }

    await salesOrderBox.put(saleOrderNo, orderData);
    _processedOrders.add(saleOrderNo);

    final orders = await getSavedSalesOrders();
    if (orders.isEmpty) {
      return;
    }

    // Step 3: Get the most recent order
    final lastOrder = orders.last;
      } catch (e, st) {
    if (orderData != null && orderData['saleOrderNo'] != null) {
      _processedOrders.remove(orderData['saleOrderNo']);
      _activeOrders.remove(orderData['saleOrderNo']);
    }
  } finally {
    if (orderData != null && orderData['saleOrderNo'] != null) {
      _activeOrders.remove(orderData['saleOrderNo']);
    }
  }
}

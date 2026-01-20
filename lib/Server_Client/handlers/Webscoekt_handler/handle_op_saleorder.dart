import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';

Future<void> handleOpenSalesOrder(
  Map<String, dynamic> jsonData,
  CustomerScreenProvider customerProvider,
) async {
  Map<String, dynamic>? orderData;


  try {

    final salesOrder = jsonData['opSalesOrder'];
    if (salesOrder == null) {
      return;
    }
    if (salesOrder is! Map<String, dynamic>) {
      return;
    }


    orderData = salesOrder['data'] ?? {};
    if (orderData is! Map<String, dynamic>) {
      return;
    }


    /// SALE ORDER NO
    final saleOrderNo = orderData['saleOrderNo']?.toString();
    if (saleOrderNo == null || saleOrderNo.isEmpty) {
      return;
    }


    final audioPath = salesOrder["data"]?['audioPath'] ?? '';
    final image1Path = salesOrder["data"]?['imagePath1'] ?? '';
    final image2Path = salesOrder["data"]?['imagePath2'] ?? '';


    orderData['type'] = 'opSalesOrder';
    orderData['audioPath'] = audioPath;
    orderData['imagePath1'] = image1Path;
    orderData['imagePath2'] = image2Path;

    final salesOrderBox = HiveManager.salesOrderBox;

    if (salesOrderBox.containsKey(saleOrderNo)) {
      return;
    }

    await salesOrderBox.put(saleOrderNo, orderData);


    final orders = await getSavedSalesOrders();


    if (orders.isEmpty) {
      return;
    }

    final lastOrder = orders.last;

  

  } catch (e, st) {
  } finally {
  }
}

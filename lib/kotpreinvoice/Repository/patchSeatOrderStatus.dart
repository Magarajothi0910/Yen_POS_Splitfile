// ignore: file_names, depend_on_referenced_packages
import 'package:hive/hive.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/kotpreinvoice/handlers/handleseatTransfer.dart';
import 'package:yenpos/kotpreinvoice/services/hive_service.dart';

import '../services/sendDataToClients.dart';
import '../services/sync_service.dart';

Future<void> handlePatchOrderStatusBySeathiveOrderId({
  required List<Map<String, dynamic>> receivedData,
  //required Set<WebSocketChannel> clients,
  required String seathiveOrderId,
  required String newStatus,
  required String orderRemark,
  required String preinvoiceTime,
}) async {
  print("🔧 handlePatchOrderStatusBySeathiveOrderId $seathiveOrderId");

  bool dataUpdated = false;

  for (var order in receivedData) {
    if (order['seathiveOrderId'] == seathiveOrderId) {
      order['status'] = newStatus;
      order['orderRemark'] = orderRemark;
      order['preinvoiceTime'] = preinvoiceTime;
      order['edit'] = "Yes";
      order['statusEdited'] = "true";
      dataUpdated = true;
      print("✅ Updated in receivedData");
    }
  }

  if (!dataUpdated) {
    final orderBox = await Hive.box('ordersBox');
    for (var key in orderBox.keys) {
      var orderData = orderBox.get(key);
      if (orderData is Map && orderData['seathiveOrderId'] == seathiveOrderId) {
        orderData['status'] = newStatus;
        orderData['orderRemark'] = orderRemark;
        orderData['preinvoiceTime'] = preinvoiceTime;
        orderData['edit'] = "Yes";
        orderData['statusEdited'] = "true";
        await orderBox.put(key, orderData);
        dataUpdated = true;
        print("✅ Updated order in Hive for key: $key");
      }
    }
  }


  if (dataUpdated) {
    sendDataToClients({
      'action': 'updateOrderStatus',
      'seathiveOrderId': seathiveOrderId,
      'status': newStatus,
      'orderRemark': orderRemark,
      'preinvoiceTime': preinvoiceTime,
      'statusEdited': "true",
      'edit': "Yes",
    }, clients);

    print("Preinvoice new status: $newStatus");
    await SyncServiceKot().patchEditedOrders();

    // loadOrdersFromHiveUtility();
  } else {
    print("❌ No matching orders found with seathiveOrderId: $seathiveOrderId");
  }
}

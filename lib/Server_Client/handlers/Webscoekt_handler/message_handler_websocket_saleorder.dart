import 'package:hive/hive.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Server_Client/handlers/webscoket_messgae_handler.dart';

final Set<String> _processedOrders = {};
final Set<String> _activeOrders = {};

// Future<void> handleSalesOrder(
//   Map<String, dynamic> jsonData,
//   CustomerScreenProvider customerProvider,
// ) async {
//   print('🎯 === STARTING SALES ORDER PROCESSING ===');

//   Map<String, dynamic>? orderData;

//   try {
//     print('📦 1. Extracting sales order from JSON data...');
//     final salesOrder = jsonData['salesOrder'];
//     if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
//       print('❌ ERROR: No salesOrder found in JSON data or invalid format');
//       return;
//     }

//     print('📋 2. Getting order data from salesOrder...');
//     orderData = salesOrder['data'] ?? {};
//     if (orderData is! Map<String, dynamic>) {
//       print('❌ ERROR: Order data is not in Map format');
//       return;
//     }

//     print('🔢 3. Extracting sale order number...');
//     final saleOrderNo = orderData['saleOrderNo']?.toString();

//     if (saleOrderNo == null || saleOrderNo.isEmpty) {
//       print('❌ ERROR: Sale order number is null or empty');
//       return;
//     }

//     print('📝 Processing order #$saleOrderNo');

//     if (_activeOrders.contains(saleOrderNo)) {
//       print('⏸️ ORDER #$saleOrderNo: Already being processed, skipping...');
//       return;
//     }

//     if (_processedOrders.contains(saleOrderNo)) {
//       print(
//         '✅ ORDER #$saleOrderNo: Already processed successfully, skipping...',
//       );
//       return;
//     }

//     print('🔒 4. Adding order #$saleOrderNo to active orders list');
//     _activeOrders.add(saleOrderNo);

//     // Extract audio and image paths
//     print('🎵 5. Extracting audio and image paths...');
//     final audioPath = salesOrder["data"]?['audioPath'] ?? '';
//     final imagePath = salesOrder["data"]?['imagePaths'] ?? '';

//     print('   Audio path: ${audioPath.isNotEmpty ? "✅ Found" : "❌ Not found"}');
//     print('   Image path: ${imagePath.isNotEmpty ? "✅ Found" : "❌ Not found"}');

//     // Add metadata to order data
//     print('🏷️ 6. Adding metadata to order data...');
//     orderData['type'] = 'salesOrder';
//     orderData['audioPath'] = audioPath;
//     orderData['imagePaths'] = imagePath;

//     print('📦 7. Accessing Hive database...');
//     final salesOrderBox2 = HiveManager.salesOrderBox;

//     if (salesOrderBox2.containsKey(saleOrderNo)) {
//       print(
//         '⚠️ ORDER #$saleOrderNo: Already exists in Hive database, skipping...',
//       );
//       _processedOrders.add(saleOrderNo);
//       _activeOrders.remove(saleOrderNo);
//       print('🗑️ Removed order #$saleOrderNo from active orders');
//       return;
//     }

//     print('💾 8. Saving order #$saleOrderNo to Hive database...');
//     await salesOrderBox2.put(saleOrderNo, orderData);
//     print('✅ ORDER #$saleOrderNo: Successfully saved to Hive');

//     _processedOrders.add(saleOrderNo);
//     print('📋 Added order #$saleOrderNo to processed orders list');

//     print('📊 9. Retrieving all saved sales orders...');
//     final orders = await getSavedSalesOrders();
//     if (orders.isEmpty) {
//       print('ℹ️ No saved orders found in database');
//       return;
//     }

//     print('📈 Total orders in database: ${orders.length}');

//     // Step 3: Get the most recent order
//     print('🆕 10. Getting most recent order...');
//     final lastOrder = orders.last;
//     print('✅ Most recent order retrieved: #${lastOrder['saleOrderNo']}');

//     // Step 4: Update receipt data in provider
//     print('🔄 11. Updating receipt data in customer provider...');
//     customerProvider.updateReceiptData(orderData);
//     print('✅ Receipt data updated successfully');

//     print('🎉 === ORDER #$saleOrderNo PROCESSED SUCCESSFULLY ===');
//   } catch (e, st) {
//     print('🔥 === CRITICAL ERROR PROCESSING ORDER ===');
//     print('❌ ERROR: $e');
//     print('📝 STACK TRACE: $st');

//     if (orderData != null && orderData['saleOrderNo'] != null) {
//       final failedOrderNo = orderData['saleOrderNo'];
//       print(
//         '🔄 Cleaning up failed order #$failedOrderNo from tracking lists...',
//       );
//       _processedOrders.remove(failedOrderNo);
//       _activeOrders.remove(failedOrderNo);
//       print('✅ Cleanup completed for order #$failedOrderNo');
//     }
//   } finally {
//     if (orderData != null && orderData['saleOrderNo'] != null) {
//       final orderNo = orderData['saleOrderNo'];
//       if (_activeOrders.contains(orderNo)) {
//         print('🧹 Finally block: Removing order #$orderNo from active orders');
//         _activeOrders.remove(orderNo);
//       }
//     }

//     print('📊 === CURRENT STATUS ===');
//     print('   Active orders: ${_activeOrders.length}');
//     print('   Processed orders: ${_processedOrders.length}');
//     print('📌 === PROCESSING COMPLETE ===\n');
//   }
// }

Future<void> handleSalesOrder(
  Map<String, dynamic> jsonData,
  CustomerScreenProvider customerProvider,
) async {
  Map<String, dynamic>? orderData;

  try {
    final salesOrder = jsonData['salesOrder'];
    if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
      return;
    }

    orderData = salesOrder['data'] ?? {};
    if (orderData is! Map<String, dynamic>) {
      return;
    }

    final saleOrderNo = orderData['saleOrderNo']?.toString();

    _activeOrders.add(saleOrderNo!);

    // Extract audio and image paths
    final audioPath = salesOrder["data"]?['audioPath'] ?? '';
    final imagePath = salesOrder["data"]?['imagePaths'] ?? '';

    // Add metadata to order data
    orderData['type'] = 'salesOrder';
    orderData['audioPath'] = audioPath;
    orderData['imagePaths'] = imagePath;

    final salesOrderBox2 = HiveManager.salesOrderBox;

    if (salesOrderBox2.containsKey(saleOrderNo)) {
      _processedOrders.add(saleOrderNo);
      _activeOrders.remove(saleOrderNo);
      return;
    }

    await salesOrderBox2.put(saleOrderNo, orderData);

    _processedOrders.add(saleOrderNo);

    final orders = await getSavedSalesOrders();
    if (orders.isEmpty) {
      return;
    }

    // Step 4: Update receipt data in provider
    // customerProvider.updateReceiptData(orderData);
  } catch (e, st) {
    if (orderData != null && orderData['saleOrderNo'] != null) {
      final failedOrderNo = orderData['saleOrderNo'];
      _processedOrders.remove(failedOrderNo);
      _activeOrders.remove(failedOrderNo);
    }
  } finally {
    if (orderData != null && orderData['saleOrderNo'] != null) {
      final orderNo = orderData['saleOrderNo'];
      if (_activeOrders.contains(orderNo)) {
        _activeOrders.remove(orderNo);
      }
    }
  }
}

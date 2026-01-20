import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';

Future<void> handleCustomerNumber(
  Map<String, dynamic> jsonData,
  CustomerScreenProvider customerProvider,
) async {
  try {
    await saveAddNewCustomerToHive(jsonData['salesOrderAddCustomer']);
    final addnewCustomer = await getAddnewCustomer();
   
  } catch (e, st) {
  } finally {}
}

import 'package:hive/hive.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Server_Client/handlers/webscoket_messgae_handler.dart';

Future<void> handleCustomerNumber(
  Map<String, dynamic> jsonData,
  CustomerScreenProvider customerProvider,
) async {
  try {
    await saveAddNewCustomerToHive(jsonData['salesOrderAddCustomer']);
    final addnewCustomer = await getAddnewCustomer();
    print("📦 Customers in Hive after adding: $addnewCustomer");
  } catch (e, st) {
  } finally {}
}

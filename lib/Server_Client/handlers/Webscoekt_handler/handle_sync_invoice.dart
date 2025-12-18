import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';

Future<void> handleSyncInvoice(Map<String, dynamic> data) async {
  try {
    final key = data['invoiceHiveKey'];

    if (key == null) {
      print("syncInvoice → Missing invoiceHiveKey");
      return;
    }

    print("syncInvoice → Updating Hive for key: $key");

    final box = await HiveManager.invoiceBox;

    if (!box.containsKey(key)) {
      print("syncInvoice → No invoice found in Hive for key: $key");
      return;
    }

    final invoice = Map<String, dynamic>.from(box.get(key));

    invoice['sync'] = 'Yes';

    await box.put(key, invoice);

    print("syncInvoice → Hive updated successfully (sync = Yes) for $key");
  } catch (e, st) {
    print("syncInvoice handler error: $e\n$st");
  }
}

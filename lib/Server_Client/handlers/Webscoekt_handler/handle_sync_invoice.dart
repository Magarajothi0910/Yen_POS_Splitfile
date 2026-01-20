import 'package:hive/hive.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';

Future<void> handleSyncInvoice(Map<String, dynamic> data) async {
  try {
    final key = data['invoiceHiveKey'];

    if (key == null) {
      return;
    }


    final box = await HiveManager.invoiceBox;

    if (!box.containsKey(key)) {
      return;
    }

    final invoice = Map<String, dynamic>.from(box.get(key));

    invoice['sync'] = 'Yes';

    await box.put(key, invoice);

  } catch (e, st) {
  }
}

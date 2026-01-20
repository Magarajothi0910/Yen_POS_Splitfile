
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import '../../hive_service.dart';

Future<void> handleInvoice(
  Map<String, dynamic> jsonData,
  SalesInvoiceReceiptPrinter printer,
) async {
  try {

    // Step 1: Extract invoice
    final invoice = jsonData['invoice'];

    if (invoice == null) {
      return;
    }

    // Step 2: Extract sales order from invoice
    final salesOrder = invoice['salesOrderId'];
    if (salesOrder == null) {
      return;
    }

    // Step 3: Get order invoice number
    final orderInvoiceNo = salesOrder['invoiceNo']?.toString();
    if (orderInvoiceNo == null || orderInvoiceNo.isEmpty) {
      return;
    }

    // Step 4: Check if invoice already exists in Hive
    final box = await HiveManager.invoiceBox;
    if (box.containsKey(orderInvoiceNo)) {
      return;
    }


    // Step 5: Save invoice to Hive
    try {
      await savePosInvoiceToHive(invoice);

      // Step 6: Update printer with receipt data
      //printer.updateReceiptData(salesOrder);
    } catch (e, st) {
    }

  } catch (e, st) {
  }
}

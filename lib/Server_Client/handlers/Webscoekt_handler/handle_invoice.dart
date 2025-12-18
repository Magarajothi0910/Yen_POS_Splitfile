import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';

Future<void> handleInvoice(
  Map<String, dynamic> jsonData,
  SalesInvoiceReceiptPrinter printer,
) async {
  print("🚀 [handleInvoice] Function called");

  // Step 1: Extract invoice
  final invoice = jsonData['invoice'];
  print("json data:$jsonData ");
  if (invoice == null) {
    print("❌ [handleInvoice] No 'invoice' field found in JSON data");
    return;
  }
  print("📥 [handleInvoice] Invoice data found");

  // Step 2: Extract sales order from invoice
  final salesOrder = invoice['salesOrderId'];
  if (salesOrder == null) {
    print("❌ [handleInvoice] No 'salesOrderId' found in invoice");
    return;
  }
  print(
    "🧾 [handleInvoice] Sales order extracted: ${salesOrder['invoiceNo'] ?? 'Unknown InvoiceNo'}",
  );

  // Step 3: Get order invoice number correctly
  final orderInvoiceNo = salesOrder['invoiceNo']?.toString();
  if (orderInvoiceNo == null || orderInvoiceNo.isEmpty) {
    print("❌ [handleInvoice] Invalid or empty 'invoiceNo' in sales order");
    return;
  }
  print("🔢 [handleInvoice] Order Invoice No: $orderInvoiceNo");

  // // Step 4: Check if invoice already exists in Hive
  // final box = HiveManager.invoiceBox;
  // if (box.containsKey(orderInvoiceNo)) {
  //   print(
  //     "⚠️ [handleInvoice] Invoice already exists in Hive: $orderInvoiceNo → Skipping save",
  //   );
  //   return;
  // }
  // print("✅ [handleInvoice] Invoice does not exist in Hive. Proceeding to save");

  // Step 5: Save invoice to Hive
  try {
    await saveInvoiceToHive(invoice);
    print(
      "💾 [handleInvoice] Invoice saved successfully in Hive: $orderInvoiceNo",
    );

    // Step 6: Update printer with receipt data
    printer.updateReceiptData(salesOrder);
    print(
      "🖨️ [handleInvoice] Receipt printer updated for Invoice No: $orderInvoiceNo",
    );
  } catch (e, st) {
    print(
      "🔥 [handleInvoice] Exception while saving invoice or updating printer: $e",
    );
    print("📄 StackTrace: $st");
  }

  print(
    "🏁 [handleInvoice] Function execution completed for Invoice No: $orderInvoiceNo",
  );
}

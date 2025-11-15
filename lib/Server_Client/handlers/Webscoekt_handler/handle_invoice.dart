import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Server_Client/handlers/webscoket_messgae_handler.dart';

Future<void> handleInvoice(
  Map<String, dynamic> jsonData,
  SalesInvoiceReceiptPrinter printer,
) async {
  print("🟢 [handleInvoice] STARTED");
  print("🟢 Incoming JSON data: $jsonData");

  // Step 1: Extract invoice
  final invoice = jsonData['invoice'];
  if (invoice == null) {
    print("⚠️ No invoice found in JSON data");
    return;
  }
  print("🟢 Invoice extracted: $invoice");

  // Step 2: Extract sales order from invoice
  final salesOrder = invoice['salesOrderId'];
  if (salesOrder == null) {
    print("⚠️ No salesOrderId found in invoice");
    return;
  }
  print("🟢 Sales Order extracted: $salesOrder");

  // Step 3: Get order invoice number
  final orderInvoiceNo = salesOrder['invoiceNo']?.toString();
  if (orderInvoiceNo == null || orderInvoiceNo.isEmpty) {
    print("⚠️ Invalid or missing orderInvoiceNo in sales order");
    return;
  }
  print("🟢 Order Invoice No: $orderInvoiceNo");

  // Step 4: Check if invoice already exists in Hive
  final box = await HiveManager.invoiceBox;
  if (box.containsKey(orderInvoiceNo)) {
    print(
      "⚠️ Invoice already exists in Hive for orderInvoiceNo: $orderInvoiceNo",
    );
    return;
  }
  print("🟢 Invoice not found in Hive, ready to save");

  // Step 5: Save invoice to Hive
  try {
    print("🟢 Saving invoice to Hive...");
    await saveInvoiceToHive(invoice);
    print("✅ Invoice saved to Hive successfully");

    // Step 6: Update printer with receipt data
    print("🟢 Updating printer with sales order data...");
    printer.updateReceiptData(salesOrder);
    print("✅ Receipt printed for invoice $orderInvoiceNo");
  } catch (e, st) {
    print("❌ Error occurred while saving invoice or printing: $e");
    print("❌ StackTrace: $st");
  }

  print("🟢 [handleInvoice] FINISHED for orderInvoiceNo: $orderInvoiceNo");
}

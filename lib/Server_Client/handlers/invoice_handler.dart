import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Server_Client/handlers/Token_service.dart';
import 'package:yenpos/Server_Client/hive_service.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart';
import 'package:yenpos/Server_Client/sync_service.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/services/invoice_service.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/invoiceNumberGenerator.dart';
import 'package:yenpos/printer_screen/provider/printer_config_provider.dart';

final SyncService _syncService = SyncService();
final InvoiceService _invoiceService = InvoiceService();

/// Helper: Returns how much stock to deduct based on UOM
double getStockDeductionAmount({
  required String uom,
  required double weight,
  required double qty,
}) {
  final lower = uom.toLowerCase().trim();
  if (lower == 'kgs' ||
      lower == 'kg' ||
      lower == 'kilogram' ||
      lower == 'kilograms') {
    return weight; // Use actual weight sold
  } else if (lower == 'grams' || lower == 'g') {
    return weight / 1000.0; // Convert grams → kg
  } else {
    return qty; // Pcs, Box, etc.
  }
}

SalesInvoiceReceiptPrinter printer = SalesInvoiceReceiptPrinter(
  printerProvider: PrinterProviderpos(),
);
Future<void> handleInvoice(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {
    print("handleInvoice called with data: ${jsonEncode(data)}");

    final salesOrderRaw = data['salesOrderId'];
    if (salesOrderRaw is! Map<String, dynamic>) {
      print("Invalid salesOrderId format");
      return;
    }

    print("salesOrderRaw extracted successfully.");

    final branchName = salesOrderRaw['branchName']?.toString();
    final aliasName = salesOrderRaw['aliasName']?.toString() ?? 'AR';
    final status = salesOrderRaw['status'] ?? 'Unknown';

    print(
      "Invoice details — Branch: $branchName | Alias: $aliasName | Status: $status",
    );

    // Generate Hive Invoice ID
    if (branchName != null) {
      final invoiceNumberGenerator = InvoiceNumberGenerator.instance;
      //String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();
      final hiveInvoiceId = await invoiceNumberGenerator
          .generateInvoiceNumber();
      salesOrderRaw['invoiceNo'] = hiveInvoiceId;
      print("Generated Hive Invoice ID: $hiveInvoiceId");
    }

    // Save invoice locally
    print("Saving invoice to local Hive...");
    await savePosInvoiceToHive(data);
    print("Invoice saved locally.");
    printer.updateReceiptData(salesOrderRaw);
    print("Invoice Printed");

    // STOCK DECREASE — FIXED FOR WEIGHTED ITEMS (Kgs)
    try {
      print("Processing stock decrease...");

      // Extract lists safely
      final List<dynamic> varianceCodesRaw =
          salesOrderRaw['varianceitemCode'] is List
          ? List.from(salesOrderRaw['varianceitemCode'])
          : [salesOrderRaw['varianceitemCode']];

      final List<dynamic> varianceNamesRaw =
          salesOrderRaw['varianceName'] is List
          ? List.from(salesOrderRaw['varianceName'])
          : [salesOrderRaw['varianceName']];

      final List<dynamic> qtyRaw = salesOrderRaw['qty'] is List
          ? List.from(salesOrderRaw['qty'])
          : [salesOrderRaw['qty']];

      final List<dynamic> weightRaw = salesOrderRaw['weight'] is List
          ? List.from(salesOrderRaw['weight'])
          : [salesOrderRaw['weight'] ?? 0.0];

      final List<dynamic> uomRaw = salesOrderRaw['uom'] is List
          ? List.from(salesOrderRaw['uom'])
          : [salesOrderRaw['uom'] ?? 'Pcs'];

      final int maxItems = [
        varianceCodesRaw.length,
        varianceNamesRaw.length,
        qtyRaw.length,
        weightRaw.length,
        uomRaw.length,
      ].reduce((a, b) => a > b ? a : b);

      List<String> varianceCodes = [];
      List<String> varianceNames = [];
      List<double> deductionAmounts = [];

      for (int i = 0; i < maxItems; i++) {
        final code = (i < varianceCodesRaw.length)
            ? varianceCodesRaw[i]?.toString().trim()
            : null;
        final name = (i < varianceNamesRaw.length)
            ? varianceNamesRaw[i]?.toString().trim()
            : null;
        final qtyVal = (i < qtyRaw.length) ? qtyRaw[i] : 1.0;
        final weightVal = (i < weightRaw.length) ? weightRaw[i] : 0.0;
        final uomVal = (i < uomRaw.length)
            ? uomRaw[i]?.toString() ?? 'Pcs'
            : 'Pcs';

        if (code == null || code.isEmpty || name == null || name.isEmpty) {
          print("Skipping invalid item at index $i");
          continue;
        }

        double qty = 0.0;
        if (qtyVal is num)
          qty = qtyVal.toDouble();
        else if (qtyVal is String)
          qty = double.tryParse(qtyVal) ?? 0.0;

        double weight = 0.0;
        if (weightVal is num)
          weight = weightVal.toDouble();
        else if (weightVal is String)
          weight = double.tryParse(weightVal) ?? 0.0;

        final deduction = getStockDeductionAmount(
          uom: uomVal,
          weight: weight,
          qty: qty,
        );

        if (deduction <= 0) {
          print("Zero deduction for $name → skipped");
          continue;
        }

        varianceCodes.add(code);
        varianceNames.add(name);
        deductionAmounts.add(deduction);

        print(
          "Will decrease: $name ($code) by $deduction $uomVal ${weight > 0 ? '(weight: $weight kg)' : '(qty: $qty)'}",
        );
      }

      if (varianceCodes.isNotEmpty) {
        print("Decreasing stock for ${varianceCodes.length} items...");
        await decreaseLocalHiveStock(
          clients: clients,
          branchAlias: aliasName,
          varianceCodes: varianceCodes,
          varianceNames: varianceNames,
          stockDeductionAmounts: deductionAmounts, // Now double!
          uoms: uomRaw.map((e) => e.toString()).toList(),
        );
        print("Stock successfully decreased (weighted items supported)");
      } else {
        print("No valid items to decrease stock");
      }
    } catch (e, st) {
      print("Error in stock decrease: $e\n$st");
    }

    // Notify all clients
    final clientData = {'action': 'invoiceGenerated', 'invoice': data};
    sendDataToClients(clientData, clients);
    print("WebSocket clients notified about invoice generation.");

    // Sync to server
    print("Sending invoice data to API...");
    bool success = await _syncService.postInvoiceOrder({
      "data": [salesOrderRaw],
    });

    if (success) {
      print("Invoice successfully synced with API.");

      // ✅ Update sync status in Hive
      try {
        final box = await Hive.openBox('invoices');
        final hiveKey =
            salesOrderRaw['invoiceNo']; // same key you saved earlier

        if (box.containsKey(hiveKey)) {
          final existing = Map<String, dynamic>.from(box.get(hiveKey));
          existing['sync'] = 'Yes'; // <-- Update status
          await box.put(hiveKey, existing);

          print("Hive updated → sync = Yes for invoice: $hiveKey");

          final sync = {'action': 'syncInvoice', 'invoiceHiveKey': hiveKey};

          sendDataToClients(sync, clients);
          debugPrint("Sent syncInvoice message to clients for key: $hiveKey");
        } else {
          print("Invoice not found in Hive to update sync status");
        }
      } catch (e) {
        print("Error updating sync=Yes in Hive: $e");
      }

      print("Invoice successfully Printed.");
    } else {
      print("Invoice sync failed, will retry later.");
    }
  } catch (e, stacktrace) {
    print("Exception in handleInvoice: $e\n$stacktrace");
  }
}

Future<void> handleSaleOrderInvoice(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {
    print("========================================================");
    print("🔔 handleSaleOrderInvoice() CALLED");
    print("📦 Incoming Raw Data: ${jsonEncode(data)}");
    print("========================================================");

    // ------------------------------------------------------------
    // Extract salesOrderId
    // ------------------------------------------------------------
    final salesOrderRaw = data['salesOrderId'];
    print("📌 Extracted 'salesOrderId': ${jsonEncode(salesOrderRaw)}");

    if (salesOrderRaw is! Map<String, dynamic>) {
      print("❌ ERROR: Expected 'salesOrderId' to be Map<String,dynamic>");
      print("--------------------------------------------------------");
      return;
    }
    print("✅ salesOrderRaw is valid map.");
    print("--------------------------------------------------------");

    // Extract basic details
    final branchName = salesOrderRaw['branchName']?.toString();
    final aliasName = salesOrderRaw['aliasName']?.toString() ?? 'AR';
    final status = salesOrderRaw['status'] ?? 'Unknown';

    print("🏪 Branch Name: $branchName");
    print("🔖 Alias Name: $aliasName");
    print("📌 Status: $status");
    print("--------------------------------------------------------");

    // ------------------------------------------------------------
    // Generate Hive invoice number
    // ------------------------------------------------------------
    if (branchName != null) {
      print("🧮 Generating Hive Invoice No...");
      final invoiceNumberGenerator = InvoiceNumberGenerator.instance;

      final hiveInvoiceId = await invoiceNumberGenerator
          .generateInvoiceNumber();

      salesOrderRaw['invoiceNo'] = hiveInvoiceId;

      print("🆕 GENERATED Hive Invoice ID: $hiveInvoiceId");
      print("--------------------------------------------------------");
    }

    // ------------------------------------------------------------
    // Save invoice to Hive
    // ------------------------------------------------------------
    print("💾 Saving invoice locally to Hive...");
    await savePosInvoiceToHive(data);
    print("✅ Invoice saved to Hive successfully.");
    print("--------------------------------------------------------");

    // ------------------------------------------------------------
    // STOCK DECREASE SECTION
    // ------------------------------------------------------------
    print("📉 Starting STOCK DECREASE process...");

    try {
      print("📥 Extracting item arrays from salesOrderRaw...");

      print("➡ varianceitemCode: ${salesOrderRaw['itemCode']}");
      print("➡ varianceName: ${salesOrderRaw['varianceName']}");
      print("➡ qty: ${salesOrderRaw['qty']}");
      print("➡ weight: ${salesOrderRaw['weight']}");
      print("➡ uom: ${salesOrderRaw['uom']}");

      final List<dynamic> varianceCodesRaw = salesOrderRaw['itemCode'] is List
          ? List.from(salesOrderRaw['itemCode'])
          : [salesOrderRaw['varianceitemCode']];

      final List<dynamic> varianceNamesRaw =
          salesOrderRaw['varianceName'] is List
          ? List.from(salesOrderRaw['varianceName'])
          : [salesOrderRaw['varianceName']];

      final List<dynamic> qtyRaw = salesOrderRaw['qty'] is List
          ? List.from(salesOrderRaw['qty'])
          : [salesOrderRaw['qty']];

      final List<dynamic> weightRaw = salesOrderRaw['weight'] is List
          ? List.from(salesOrderRaw['weight'])
          : [salesOrderRaw['weight'] ?? 0.0];

      final List<dynamic> uomRaw = salesOrderRaw['uom'] is List
          ? List.from(salesOrderRaw['uom'])
          : [salesOrderRaw['uom'] ?? 'Pcs'];

      print("📊 Parsed lists:");
      print("   📌 varianceCodesRaw: $varianceCodesRaw");
      print("   📌 varianceNamesRaw: $varianceNamesRaw");
      print("   📌 qtyRaw: $qtyRaw");
      print("   📌 weightRaw: $weightRaw");
      print("   📌 uomRaw: $uomRaw");
      print("--------------------------------------------------------");

      final int maxItems = [
        varianceCodesRaw.length,
        varianceNamesRaw.length,
        qtyRaw.length,
        weightRaw.length,
        uomRaw.length,
      ].reduce((a, b) => a > b ? a : b);

      print("🧮 Total items to process: $maxItems");
      print("--------------------------------------------------------");

      List<String> varianceCodes = [];
      List<String> varianceNames = [];
      List<double> deductionAmounts = [];

      for (int i = 0; i < maxItems; i++) {
        print("--------------------------------------------------------");
        print("🔍 PROCESSING ITEM INDEX: $i");

        final code = i < varianceCodesRaw.length
            ? varianceCodesRaw[i]?.toString().trim()
            : null;

        final name = i < varianceNamesRaw.length
            ? varianceNamesRaw[i]?.toString().trim()
            : null;

        final qtyVal = i < qtyRaw.length ? qtyRaw[i] : 1.0;
        final weightVal = i < weightRaw.length ? weightRaw[i] : 0.0;
        final uomVal = i < uomRaw.length
            ? uomRaw[i]?.toString() ?? 'Pcs'
            : 'Pcs';

        print("   ➡ Item Code: $code");
        print("   ➡ Item Name: $name");
        print("   ➡ Qty Raw: $qtyVal");
        print("   ➡ Weight Raw: $weightVal");
        print("   ➡ UOM: $uomVal");

        if (code == null || code.isEmpty || name == null || name.isEmpty) {
          print("   ❌ INVALID ITEM — Skipping");
          continue;
        }

        double qty = qtyVal is num
            ? qtyVal.toDouble()
            : double.tryParse(qtyVal) ?? 0.0;
        double weight = weightVal is num
            ? weightVal.toDouble()
            : double.tryParse(weightVal) ?? 0.0;

        print("   🔢 Parsed Qty: $qty");
        print("   ⚖ Parsed Weight: $weight");

        final deduction = getStockDeductionAmount(
          uom: uomVal,
          weight: weight,
          qty: qty,
        );

        print("   📉 Calculated Deduction: $deduction");

        if (deduction <= 0) {
          print("   ⚠ Zero deduction. Skipping...");
          continue;
        }

        varianceCodes.add(code);
        varianceNames.add(name);
        deductionAmounts.add(deduction);

        print("   ✅ Added for stock decrease → $name ($code)");
      }

      print("--------------------------------------------------------");
      print("📦 FINAL STOCK DECREASE DATA:");
      print("   Codes: $varianceCodes");
      print("   Names: $varianceNames");
      print("   Deductions: $deductionAmounts");
      print("--------------------------------------------------------");

      if (varianceCodes.isNotEmpty) {
        print("🚀 Sending to decreaseLocalHiveSaleorderStock...");
        await decreaseLocalHiveSaleorderStock(
          clients: clients,
          branchAlias: aliasName,
          varianceCodes: varianceCodes,
          varianceNames: varianceNames,
          stockDeductionAmounts: deductionAmounts,
          uoms: uomRaw.map((e) => e.toString()).toList(),
        );
        print("✅ STOCK successfully decreased!");
      } else {
        print("⚠ No valid items to decrease stock.");
      }
    } catch (e, st) {
      print("❌ STOCK PROCESSING ERROR: $e");
      print("$st");
    }

    print("--------------------------------------------------------");

    // ------------------------------------------------------------
    // Notify clients
    // ------------------------------------------------------------
    print("📢 Notifying WebSocket Clients...");
    print("Invoice data: $data");
    final clientData = {'action': 'invoiceGenerated', 'invoice': data};
    sendDataToClients(clientData, clients);
    print("✅ Clients notified.");
    print("--------------------------------------------------------");

    // ------------------------------------------------------------
    // SYNC TO API
    // ------------------------------------------------------------
    print("🌐 Syncing invoice to API...");
    bool success = await _syncService.postInvoiceOrder(salesOrderRaw);

    if (success) {
      print("✅ API SYNC SUCCESS!");
    } else {
      print("❌ API SYNC FAILED — Will Retry Later");
    }

    print("========================================================");
  } catch (e, stacktrace) {
    print("❌ FATAL ERROR IN handleSaleOrderInvoice: $e");
    print(stacktrace);
    print("========================================================");
  }
}

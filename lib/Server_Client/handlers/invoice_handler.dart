

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/globals_data.dart';
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

    final salesOrderRaw = data['salesOrderId'];
    if (salesOrderRaw is! Map<String, dynamic>) {
      return;
    }


    final branchName = salesOrderRaw['branchName']?.toString();
    final aliasName = salesOrderRaw['aliasName']?.toString() ?? 'AR';
    final status = salesOrderRaw['status'] ?? 'Unknown';


    // Generate Hive Invoice ID
    if (branchName != null) {
      final invoiceNumberGenerator = InvoiceNumberGenerator.instance;
      //String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();
      final hiveInvoiceId = await invoiceNumberGenerator
          .generateInvoiceNumber();
      salesOrderRaw['invoiceNo'] = hiveInvoiceId;
    }
    final invoiceNo = Hive.box('invoiceNo');
    final invNoKeys = invoiceNo.keys.last;
    final invNoValues = invoiceNo.values.last;

    // Save invoice locally
    await savePosInvoiceToHive(data);
    printer.updateReceiptData(salesOrderRaw);

    // STOCK DECREASE — FIXED FOR WEIGHTED ITEMS (Kgs)
    try {

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
          continue;
        }

        varianceCodes.add(code);
        varianceNames.add(name);
        deductionAmounts.add(deduction);

      }

      if (varianceCodes.isNotEmpty) {
        await decreaseLocalHiveStock(
          clients: clients,
          branchAlias: aliasName,
          varianceCodes: varianceCodes,
          varianceNames: varianceNames,
          stockDeductionAmounts: deductionAmounts, // Now double!
          uoms: uomRaw.map((e) => e.toString()).toList(),
        );
      } else {
      }
    } catch (e, st) {
    }

    // Notify all clients
    final clientData = {'action': 'invoiceGenerated', 'invoice': data};
    final invNo = {
      'action': "invoiceNoGenerated",
      'invNoKeys': invNoKeys,
      'invNoValues': invNoValues,
    };
    sendDataToClients(clientData, clients);
    sendDataToClients(invNo, clients);

    // Sync to server

    bool success = await _syncService.postInvoiceOrder({
      "data": [salesOrderRaw],
    });

    if (success) {
      if (isWhatsAppEnabled) {
        await sendBillToCustomer(salesOrderRaw['invoiceNo'], salesOrderRaw);
      }
      String billNumber = salesOrderRaw['invoiceNo'];
      String phoneNumber = salesOrderRaw['customerPhone'] ?? '';
      String totalAmount = salesOrderRaw['grossAmount'].toString();

      // Send SMS
      if (isSMSEnabled) {
        String smsApiUrl =
            'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK&senderid=BMUMMY&templateid=1707167058380400950&number=$phoneNumber&message=WELCOME TO BESTMUMMY BILL NO:$billNumber BILL AMOUNT: $totalAmount VISIT OUR 45 THANK YOU FOR VISITING AGAIN';

        var smsResponse = await http.get(Uri.parse(smsApiUrl));
        if (smsResponse.statusCode == 200) {
        } else {
        }
      }

      // ✅ Update sync status in Hive
      try {
        final box = await Hive.openBox('invoices');
        final hiveKey =
            salesOrderRaw['invoiceNo']; // same key you saved earlier

        if (box.containsKey(hiveKey)) {
          final existing = Map<String, dynamic>.from(box.get(hiveKey));
          existing['sync'] = 'Yes'; // <-- Update status
          await box.put(hiveKey, existing);


          final sync = {'action': 'syncInvoice', 'invoiceHiveKey': hiveKey};

          sendDataToClients(sync, clients);
        } else {
        }
      } catch (e) {
      }

    } else {
    }
  } catch (e, stacktrace) {
  }
}

Future<void> sendBillToCustomer(
  String invoiceNo,
  Map<String, dynamic> invoiceData,
) async {
  final response = await http.post(
    Uri.parse('https://yenerp.com/fluttertestapi/invoices/api/send-bill'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({'invoiceNo': invoiceNo, 'invoiceData': invoiceData}),
  );
  if (response.statusCode == 200) {
    final result = json.decode(response.body);
  } else {
  }
}

Future<void> handleSaleOrderInvoice(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  try {

    // ------------------------------------------------------------
    // Extract salesOrderId
    // ------------------------------------------------------------
    final salesOrderRaw = data['salesOrderId'];

    if (salesOrderRaw is! Map<String, dynamic>) {
      return;
    }

    // Extract basic details
    final branchName = salesOrderRaw['branchName']?.toString();
    final aliasName = salesOrderRaw['aliasName']?.toString() ?? 'AR';
    final status = salesOrderRaw['status'] ?? 'Unknown';


    // ------------------------------------------------------------
    // Generate Hive invoice number
    // ------------------------------------------------------------
    if (branchName != null) {
      final invoiceNumberGenerator = InvoiceNumberGenerator.instance;

      final hiveInvoiceId = await invoiceNumberGenerator
          .generateInvoiceNumber();

      salesOrderRaw['invoiceNo'] = hiveInvoiceId;

    }
    final invoiceNo = Hive.box('invoiceNo');
    final invNoKeys = invoiceNo.keys.last;
    final invNoValues = invoiceNo.values.last;

    // ------------------------------------------------------------
    // Save invoice to Hive
    // ------------------------------------------------------------
    await savePosInvoiceToHive(data);

    // ------------------------------------------------------------
    // STOCK DECREASE SECTION
    // ------------------------------------------------------------

    try {


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


        if (code == null || code.isEmpty || name == null || name.isEmpty) {
          continue;
        }

        double qty = qtyVal is num
            ? qtyVal.toDouble()
            : double.tryParse(qtyVal) ?? 0.0;
        double weight = weightVal is num
            ? weightVal.toDouble()
            : double.tryParse(weightVal) ?? 0.0;


        final deduction = getStockDeductionAmount(
          uom: uomVal,
          weight: weight,
          qty: qty,
        );


        if (deduction <= 0) {
          continue;
        }

        varianceCodes.add(code);
        varianceNames.add(name);
        deductionAmounts.add(deduction);

      }


      if (varianceCodes.isNotEmpty) {
        await decreaseLocalHiveSaleorderStock(
          clients: clients,
          branchAlias: aliasName,
          varianceCodes: varianceCodes,
          varianceNames: varianceNames,
          stockDeductionAmounts: deductionAmounts,
          uoms: uomRaw.map((e) => e.toString()).toList(),
        );
      } else {
      }
    } catch (e, st) {
    }


    // ------------------------------------------------------------
    // Notify clients
    // ------------------------------------------------------------
    final clientData = {'action': 'invoiceGenerated', 'invoice': data};
    final invNo = {
      'action': "invoiceNoGenerated",
      'invNoKeys': invNoKeys,
      'invNoValues': invNoValues,
    };
    sendDataToClients(clientData, clients);
    sendDataToClients(invNo, clients);

    // ------------------------------------------------------------
    // SYNC TO API
    // ------------------------------------------------------------
    bool success = await _syncService.postInvoiceOrder(salesOrderRaw);

    if (success) {
    } else {
    }

  } catch (e, stacktrace) {
  }
}

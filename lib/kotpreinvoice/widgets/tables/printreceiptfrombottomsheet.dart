// print_receipt_service.dart
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/globals_data.dart';

import '../../models/printer.dart';
import '../../providers/order_provider.dart';
import '../../providers/printer_provider.dart';
import '../../services/preInvociePrint_services.dart';

class PrintReceiptService {
  static Future<void> generatePreInvoice({
    required BuildContext context,
    required OrderProvider orderProvider,
    required String tableNumber,
    required String seat,
    required List<dynamic> seatOrders,
    required String areaName,
  }) async {
    final printerProvider = Provider.of<PrinterProviderDine>(
      context,
      listen: false,
    );
    final preInvoicePrinter = printerProvider.printers.firstWhere(
      (printer) => printer.type == 'PreInvoice',
      orElse: () => Printer(
        name: 'default_printer',
        ipAddress: '192.168.1.100',
        type: 'PreInvoice',
      ),
    );

    await _patchStatusConfirm(orderProvider, seatOrders, tableNumber, seat);
    orderProvider.notifyListeners();

    await InvoicePrinter.printReceipt(
      ipAddress: preInvoicePrinter.ipAddress,
      tableNumber: tableNumber,
      seat: seat,
      seatOrders: seatOrders,
      userName: userName,
      waiter: seatOrders.isNotEmpty ? seatOrders.first['waiter'] : '',
      areaName: areaName,
      invoiceNo: '',
    );
  }

  static Future<void> _patchStatusConfirm(
    OrderProvider orderProvider,
    List<dynamic> seatOrders,
    String tableNumber,
    String seat,
  ) async {
    for (var order in seatOrders) {
      if (order.containsKey('seathiveOrderId') &&
          order['seathiveOrderId'] != null) {
        await orderProvider.patchOrderStatusBySeathiveOrderId(
          order['seathiveOrderId'],
          "confirm",
          tableNumber,
          seat,
        );
      }
    }
  }
}

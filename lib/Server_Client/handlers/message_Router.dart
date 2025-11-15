import 'dart:convert';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_holdorder_websocket.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_invoice.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_op_saleorder.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_patchsaleorder.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/handle_salesapproval.dart';
import 'package:yenpos/Server_Client/handlers/Webscoekt_handler/message_handler_websocket_saleorder.dart';

import 'package:yenpos/Server_Client/websocketService.dart';

class MessageRouter {
  static Future<void> handle(
    String rawMessage,
    CustomerScreenProvider provider,
    SalesInvoiceReceiptPrinter printer,
    WebSocketService ws,
  ) async {
    final data = jsonDecode(rawMessage);
    final action = data['action'];

    switch (action) {
      case 'salesOrderGenerated':
        await handleSalesOrder(data, provider);
        break;
      case 'holdOrderGenerated':
        await handleHoldOrder(data);
        break;
      case 'invoiceGenerated':
        await handleInvoice(data, printer);
        break;
      case 'patchsaleorderGenerated':
        await handlePatchSalesOrder(data, provider);
        break;
      case 'salesApprovalOrderGenerated':
        await handleApprovalOrder(data);
        break;
      case 'salesOrder_updated':
        await handlePatchSalesOrder(data, provider);
        break;
      case 'OpSalesOrderGenerated':
        await handleOpenSalesOrder(data, provider);
        break;
      default:
        print('[WS] Unknown action: $action');
        break;
    }
  }
}

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Server_Client/handlers/invoice_handler.dart';
import 'package:yenpos/Server_Client/handlers/saleorder_handlemessage.dart';
import 'package:yenpos/Server_Client/hive_service.dart';
import 'package:yenpos/Server_Client/salesreturn_handler.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/invoiceNumberGenerator.dart';
import 'package:yenpos/kotpreinvoice/Repository/itemRepo.dart';
import 'package:yenpos/kotpreinvoice/Repository/patchSeatOrderStatus.dart';
import 'package:yenpos/kotpreinvoice/handlers/FullCancelOrder_Handler.dart';
import 'package:yenpos/kotpreinvoice/handlers/ItemWiseCancel.dart';
import 'package:yenpos/kotpreinvoice/handlers/handleRemoveHoldOrdersKOT.dart';
import 'package:yenpos/kotpreinvoice/handlers/handleseatTransfer.dart';
import 'package:yenpos/kotpreinvoice/handlers/holdOrdersKOT.dart';
import 'package:yenpos/kotpreinvoice/handlers/invoice%20handler.dart';
import 'package:yenpos/kotpreinvoice/handlers/orderhandlers.dart';
import 'package:yenpos/kotpreinvoice/handlers/reverseOrder_handler.dart';
import 'package:yenpos/kotpreinvoice/handlers/updateTopPriorityHandlers.dart';
import 'package:yenpos/kotpreinvoice/providers/upi_provider.dart';
import 'package:yenpos/kotpreinvoice/services/hive_service.dart'
    hide loadInvoicesFromHive, savePrinterDetailsToHive;
import 'package:yenpos/kotpreinvoice/services/preInvociePrint_services.dart';
import 'package:yenpos/kotpreinvoice/services/sendDataToClients.dart'
    hide handleNewClientConnected;
import 'package:yenpos/kotpreinvoice/services/sync_service.dart';
import 'package:yenpos/main.dart';

typedef DataHandler = void Function(Map<String, dynamic>);
// ✅ Centralized WebSocket handler (no duplicate stream listens)
void handleWebSocket(
  WebSocketChannel channel,
  Set<WebSocketChannel> clients,
  DataHandler onDataReceived,
) {
  clients.add(channel);

  // Action Handlers
  final Map<String, Future<void> Function(Map<String, dynamic>)>
  actionHandlers = {
    'hello': (data) async {
      channel.sink.add(
        jsonEncode({
          'action': 'response',
          'message': 'Hello Client, message received!',
        }),
      );
    },

    'requestBranchwiseItems': (data) async {
      try {
        // final savedData = GlobalDataManager().branchwiseItems;
        final lazyBox = await Hive.openBox('items');
        final savedData = await lazyBox.get('branchwiseItems_$aliasname');
        if (savedData == null) {
          channel.sink.add(
            jsonEncode({
              'action': 'branchwiseItemsError',
              'message': 'No branchwise items data available.',
            }),
          );
          return;
        }
        channel.sink.add(
          jsonEncode({'action': 'branchwiseItems', 'data': savedData}),
        );
      } catch (e, st) {
        developer.log("Error sending branchwise items: $e", stackTrace: st);
        channel.sink.add(
          jsonEncode({
            'action': 'branchwiseItemsError',
            'message': 'Failed to send branchwise items.',
          }),
        );
      }
    },

    'heartbeat': (data) async {
      channel.sink.add(jsonEncode({'action': 'heartbeatAck'}));
    },

    'newClientConnected': (data) async {
      await handleNewClientConnected(data, channel);
    },

    'updatePrinterItems': (data) async {
      try {
        final printer = data['printer'];
        final printerName = printer['name'];
        final updatedItems = printer['items'];

        bool printerFound = false;
        for (var entry in receivedData) {
          if (entry['action'] == 'printerDetails' &&
              entry['name'] == printerName) {
            entry['items'] = updatedItems;
            printerFound = true;
            break;
          }
        }

        if (!printerFound) {
          receivedData.add({
            'action': 'printerDetails',
            'name': printerName,
            'ipAddress': printer['ipAddress'],
            'type': printer['type'],
            'items': updatedItems,
            'orderSource': printer['orderSource'],
          });
        }

        await savePrinterDetailsToHive({
          'action': 'printerDetails',
          'name': printerName,
          'ipAddress': printer['ipAddress'],
          'type': printer['type'],
          'items': updatedItems,
          'orderSource': printer['orderSource'],
        });

        sendDataToClients({
          'action': 'updatePrinterItems',
          'printer': {
            'name': printerName,
            'ipAddress': printer['ipAddress'],
            'type': printer['type'],
            'items': updatedItems,
          },
        }, clients);
      } catch (e, st) {
        developer.log("updatePrinterItems error: $e", stackTrace: st);
      }
    },

    'printerDetails': (data) async {
      await savePrinterDetailsToHive(data);
      receivedData.add(data);
      sendDataToClients(data, clients);
    },

    //KOT
    'requestBranchwiseItemsForClient': (data) async {
      try {
        final branchwiseItems = await getBranchwiseItemsFromLazyBox();
        if (branchwiseItems.isNotEmpty) {
          channel.sink.add(
            jsonEncode({'action': 'branchwiseItems', 'data': branchwiseItems}),
          );
        }
      } catch (e, st) {}
    },

    'handle_invoice_request': (data) async {
      try {
        final tableNumber = data['tableNumber'];
        final seat = data['seat'];
        final areaName = data['areaName'];
        final userName = data['userName'];
        final ipAddress = data['ipAddress'];
        final waiter = data['waiter'];
        final preinvoiceTime = data['preinvoiceTime'];
        final List orders = data['orders'] ?? [];
        final String? seathiveOrderId = data['seathiveOrderId'];

        if (seathiveOrderId == null) {
          return;
        }

        // 1️⃣ Generate Invoice Number
        final generator = InvoiceNumberGenerator.instance;
        final invoiceNo = await generator.generateInvoiceNumber();

        final invoiceNoBox = Hive.box('invoiceNo');
        final invNoKeys = invoiceNoBox.keys.last;
        final invNoValues = invoiceNoBox.values.last;

        // 2️⃣ Update Orders in Hive

        final ordersBox = Hive.isBoxOpen('ordersBox')
            ? Hive.box('ordersBox')
            : await Hive.openBox('ordersBox');

        bool found = false;

        for (final key in ordersBox.keys) {
          final order = ordersBox.get(key);

          if (order is Map) {
            if (order['seathiveOrderId'] == seathiveOrderId) {
              found = true;

              final updatedOrder = Map<String, dynamic>.from(order)
                ..['invoiceNo'] = invoiceNo
                ..['status'] = 'confirm'
                ..['preinvoiceTime'] = preinvoiceTime
                ..['edit'] = "Yes"
                ..['statusEdited'] = "true";

              await ordersBox.put(key, updatedOrder);

              final updatedorder = ordersBox.get(key);
            }
          } else {}
        }

        // final updatedOrderData = ordersBox.get(key);

        if (!found) {}

        // 3️⃣ Print Invoice on SERVER
        try {
          await InvoicePrinter.printReceipt(
            tableNumber: tableNumber,
            ipAddress: ipAddress,
            seat: seat,
            areaName: areaName,
            seatOrders: orders,
            waiter: waiter,
            userName: userName,
            invoiceNo: invoiceNo,
          );
        } catch (e) {}

        final updatePayload = {
          'action': 'sync_invoice_update',
          'seathiveOrderId': seathiveOrderId,
          'invoiceNo': invoiceNo,
          'preinvoiceTime': preinvoiceTime,
        };
        final invNo = {
          'action': "invoiceNoGenerated",
          'invNoKeys': invNoKeys,
          'invNoValues': invNoValues,
        };

        sendDataToClients(updatePayload, clients);
        sendDataToClients(invNo, clients);

        SyncServiceKot().patchEditedOrders();
      } catch (e) {}
    },
    'requestAllData': (data) async {
      final orders = await loadOrdersFromHiveUtility();
      final invoices = await loadInvoicesFromHiveKOT();
      final printerDetails = await loadPrintersFromHive();

      final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

      final filteredOrders = orders.where((order) {
        try {
          final orderDate = DateFormat('dd-MM-yyyy').parse(order['date']);
          return DateFormat('dd-MM-yyyy').format(orderDate) == currentDate;
        } catch (_) {
          return false;
        }
      }).toList();

      final filteredInvoices = invoices.where((invoice) {
        try {
          final invoiceDate = DateFormat(
            'dd-MM-yyyy',
          ).parse(invoice['invoiceDate']);
          return DateFormat('dd-MM-yyyy').format(invoiceDate) == currentDate;
        } catch (_) {
          return false;
        }
      }).toList();

      final Map<String, Map<String, dynamic>> uniqueInvoices = {};
      for (var invoice in filteredInvoices) {
        final id = invoice['hiveInvoiceId']?.toString();
        if (id != null) uniqueInvoices[id] = invoice;
      }
      final dedupedInvoices = uniqueInvoices.values.toList();
      final allDataMessage = {
        'action': 'allDataResponse',
        'orders': filteredOrders,
        'invoicesKOT': dedupedInvoices,
        'KOTprinters': printerDetails,
        'tables': tables,
      };
      sendDataToClients(allDataMessage, clients);
    },
    'seat_tapped': (data) async {
      sendDataToClients(data, clients);
      onDataReceived(data);
    },
    'seat_returned': (data) async {
      sendDataToClients(data, clients);
      onDataReceived(data);
    },
    'patchOrderStatusBySeathiveOrderId': (data) async {
      try {
        final seathiveOrderId = data['seathiveOrderId']?.toString() ?? '';
        final newStatus = data['status']?.toString() ?? '';
        final preinvoiceTime = data['preinvoiceTime']?.toString() ?? '';
        final orderRemark = data['orderRemark']?.toString() ?? '';

        await handlePatchOrderStatusBySeathiveOrderId(
          receivedData: receivedData,
          seathiveOrderId: seathiveOrderId,
          newStatus: newStatus,
          orderRemark: orderRemark,
          preinvoiceTime: preinvoiceTime,
        );
      } catch (e, st) {}
    },
    'seat_transfer': (data) async {
      try {
        await handleSeatTransfer(
          data: data, //receivedData: receivedData
        );
      } catch (e, st) {}
    },

    'FullCancelOrderPatch': (data) async {
      try {
        await OrderPatchHandler.handleFullCancelOrderPatch(data);
      } catch (e, st) {}
    },
    'cancelOrderItem': (data) async {
      try {
        await CancelOrderPatchHandler.patchCancelOrderItem(data);
      } catch (e, st) {}
    },

    'FullInvoiceOrderPatch': (data) async {
      try {
        await OrderPatchHandler.handleFullInvoiceOrderPatch(data);
      } catch (e, st) {}
    },
    'get_invoice_number': (data) async {
      try {
        final generator = InvoiceNumberGenerator.instance;
        final invoiceNo = await generator.generateInvoiceNumber();

        final response = {
          'action': 'invoice_number_response',
          'requestId': data['requestId'], // echo back for client-side match
          'invoiceNo': invoiceNo,
        };

        sendDataToClients(response, clients);
      } catch (e, st) {}
    },
    'update_orders_with_invoice': (data) async {
      final String? seathiveOrderId = data['seathiveOrderId'];
      final String? invoiceNo = data['invoiceNo'];

      if (seathiveOrderId == null || invoiceNo == null) {
        return;
      }

      try {
        final ordersBox = await Hive.openBox('ordersBox');

        // Iterate all orders and update invoiceNo where seathiveOrderId matches
        for (final key in ordersBox.keys) {
          final order = ordersBox.get(key);
          if (order is Map && order['seathiveOrderId'] == seathiveOrderId) {
            final updatedOrder = Map<String, dynamic>.from(order)
              ..['invoiceNo'] = invoiceNo;
            await ordersBox.put(key, updatedOrder);
          }
        }

        final updatePayload = {
          'action': 'sync_invoice_update',
          'seathiveOrderId': seathiveOrderId,
          'invoiceNo': invoiceNo,
        };

        sendDataToClients(updatePayload, clients);
      } catch (e) {}
    },
    'reverseCancelOrderItem': (data) async {
      try {
        final hiveOrderId = data['hiveOrderId'];
        final int updatedIndex = data['updatedIndex'];
        final double updatedQty = (data['updatedQuantity'] as num).toDouble();
        final double updatedCancelledQty = (data['updatedCancelledQty'] as num)
            .toDouble();
        final double totalAmount = (data['totalAmount'] as num).toDouble();
        final bool partiallycancelled = data['partiallycancelled'] == true;
        final String ipAddress = data['ipAddress'];

        await patchOrderInHiveIndexWise(
          hiveOrderId,
          updatedIndex,
          updatedQty,
          updatedCancelledQty,
          totalAmount,
          partiallycancelled,
          ipAddress,
        );

        sendDataToClients({
          'action': 'reverseCancelOrderItem',
          'hiveOrderId': hiveOrderId,
          'updatedIndex': updatedIndex,
          'updatedQuantity': updatedQty,
          'updatedCancelledQty': updatedCancelledQty,
          'totalAmount': totalAmount,
          'partiallycancelled': partiallycancelled,
        }, clients);
      } catch (e, st) {}
    },
    'clientDeviceData': (data) async {
      try {
        final deviceData = data['data'] as Map<String, dynamic>?;

        if (deviceData == null) {
          return;
        }

        // Add IP to data for storage and uniqueness
        final String? clientIp = deviceData['clientIp'] as String?;
        deviceData['lastUpdated'] = DateTime.now().toIso8601String();

        final box = Hive.isBoxOpen('connectedDevices')
            ? Hive.box('connectedDevices')
            : await Hive.openBox('connectedDevices');

        // Enforce: Only one device per IP (latest wins)
        final existingKeys = box.keys.where(
          (key) => (box.get(key) as Map?)?['clientIp'] == clientIp,
        );

        for (final key in existingKeys) {
          await box.delete(key);
        }

        // Store with unique key (use IP or deviceCode + timestamp)
        final uniqueKey = 'device_$clientIp';
        await box.put(uniqueKey, deviceData);

        // === Recalculate Top 5 Priorities ===
        await updateTopPrioritiesAndBroadcast();
      } catch (e, st) {}
    },
  };

  // Type Handlers
  final Map<String, Future<void> Function(Map<String, dynamic>)> typeHandlers =
      {
        'handshake': (data) async => handleHandShake(data, clients),
        'updateDispatch': (data) => handleUpdateDispatch(
          clients: clients,
          branchAlias: aliasname,
          message: data,
        ),
        'decreaseDispatch': (data) => handleDecreaseDispatch(
          clients: clients,
          branchAlias: aliasname,
          message: data,
        ),
        'order': handleOrder,
        'salesReturn': (data) async => handleSalesReturn(data, clients),
        'invoiceKOT': handleInvoiceKOT,
        'state_update': (data) async => sendDataToClients(data, clients),
        'show_upi_qr': (data) async => sendDataToClients(data, clients),
        'upi_payment_success': (data) async => sendDataToClients(data, clients),
        'start_card_payment': (data) async => sendDataToClients(data, clients),
        'card_payment_success': (data) async =>
            sendDataToClients(data, clients),
        'card_payment_error': (data) async => sendDataToClients(data, clients),
        'serverAliveResponse': (data) async => sendDataToClients(data, clients),
        'invoice': (data) async => handleInvoice(data, clients),
        'opSalesOrder': (data) async => handleOpenSaleOrder(data),
        'posInvoice': (data) async => handleSaleOrderInvoice(data, clients),
        'salesOrder': (data) async => handleSaleOrder(data),

        'patchSaleOrder': (data) async => handlePatchSaleOrder(data),
        'salesOrder_created_confirm': (data) async =>
            handleApprovedSaleOrder(data),

        'addHoldOrdersKOT': (data) async =>
            handleAddHoldOrdersKOT(data, clients),
        'removeHoldOrdersKOT': (data) async =>
            handleRemoveHoldOrdersKOT(data, clients),

        'patchHoldOrder': (data) async => handlePatchHoldOrder(data),
        'postToApprove': (data) async => handleToApproveOrder(data),
        'modifySaleOrder': (data) async => handleModifyOrder(data),
        'cancelOrder': (data) async => handlePatchSaleOrder(data),
        'salesOrder_updated': (data) async =>
            handlePatchwebsocketSaleOrder(data),
        'dispatch_received': (data) async =>
            handlePatchwebsocketSaleOrder(data),
        'received': (data) async => handlePatchwebsocketSaleOrder(data),
        'patchInvoiceSaleOrder': (data) async =>
            handleInvoicePatchSaleOrder(data),
        'approval_updated': (data) async => handlePatchApprovalSaleOrder(data),
        'opApprovalOrder': (data) async => handleSalesApprovalOrder(data),

        'holdOrder': (data) async => handleHoldOrder(data),
        'salesApprovalOrder': (data) async => handleSalesApprovalOrder(data),
        'newCustomer': (data) async => handleSalesOrderAddCustomer(data),
        'serverAliveRequest': (data) async {
          final payload = {
            'action': 'serverAliveResponse',
            'message': 'Server is alive and running!',
          };
          channel.sink.add(jsonEncode(payload));
        },
        'sentIp': (data) async {
          final info = NetworkInfo();
          final myIp = await info.getWifiIP();
          bool isSame = (data['ip'] == myIp);
          sendDataToClients({
            'action': 'deviceIpGenerated',
            'data': data,
            'deviceIp': myIp,
            'isSame': isSame,
          }, clients);
        },
      };

  // ✅ Single Stream Listen — Avoids “Stream already listened to” error
  channel.stream.listen(
    (message) async {
      try {
        if (message is String && message.trim().isNotEmpty) {
          Map<String, dynamic> data;
          try {
            data = jsonDecode(message);
          } catch (_) {
            data = jsonDecode(message.replaceAll("'", '"'));
          }
          if (data.containsKey('action') && data['action'] == 'heartbeat') {
            channel.sink.add(jsonEncode({'action': 'heartbeatAck'}));
            return;
          }

          if (data.containsKey('action') &&
              actionHandlers.containsKey(data['action'])) {
            await actionHandlers[data['action']]!(data);
            onDataReceived(data);
            return;
          }

          if (data.containsKey('type') &&
              typeHandlers.containsKey(data['type'])) {
            await typeHandlers[data['type']]!(data);
            onDataReceived(data);
            return;
          }
        }
      } catch (e, st) {
        developer.log("Error processing WebSocket message: $e", stackTrace: st);
      }
    },
    onDone: () {
      clients.remove(channel);
    },
    onError: (error) {
      clients.remove(channel);
    },
    cancelOnError: true,
  );
}

handleHandShake(
  Map<String, dynamic> data,
  Set<WebSocketChannel> clients,
) async {
  final d = {'action': 'handshake', 'message': 'From server'};
  sendDataToClients(d, clients);
}

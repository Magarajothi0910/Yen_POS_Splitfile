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
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_invoiceNo.dart';
import 'package:yen_pos/Server_Client/handlers/Webscoekt_handler/handle_shift.dart';
import 'package:yen_pos/Server_Client/handlers/invoice_handler.dart';
import 'package:yen_pos/Server_Client/handlers/saleorder_handlemessage.dart';
import 'package:yen_pos/Server_Client/hive_service.dart';
import 'package:yen_pos/Server_Client/salesreturn_handler.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/Server_Client/stockupdateService.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/invoiceNumberGenerator.dart';
import 'package:yen_pos/kotpreinvoice/Repository/itemRepo.dart';
import 'package:yen_pos/kotpreinvoice/Repository/patchSeatOrderStatus.dart';
import 'package:yen_pos/kotpreinvoice/handlers/FullCancelOrder_Handler.dart';
import 'package:yen_pos/kotpreinvoice/handlers/ItemWiseCancel.dart';
import 'package:yen_pos/kotpreinvoice/handlers/cancel_order_response_handler.dart';
import 'package:yen_pos/kotpreinvoice/handlers/handleRemoveHoldOrdersKOT.dart';
import 'package:yen_pos/kotpreinvoice/handlers/handleseatTransfer.dart';
import 'package:yen_pos/kotpreinvoice/handlers/holdOrdersKOT.dart';
import 'package:yen_pos/kotpreinvoice/handlers/invoice%20handler.dart';
import 'package:yen_pos/kotpreinvoice/handlers/orderhandlers.dart';
import 'package:yen_pos/kotpreinvoice/handlers/reverseOrder_handler.dart';
import 'package:yen_pos/kotpreinvoice/handlers/updateTopPriorityHandlers.dart';
import 'package:yen_pos/kotpreinvoice/providers/upi_provider.dart';
import 'package:yen_pos/kotpreinvoice/services/hive_service.dart'
    hide loadInvoicesFromHive, savePrinterDetailsToHive;
import 'package:yen_pos/kotpreinvoice/services/preInvociePrint_services.dart';
import 'package:yen_pos/kotpreinvoice/services/sendDataToClients.dart'
    hide handleNewClientConnected;
import 'package:yen_pos/kotpreinvoice/services/sync_service.dart';
import 'package:yen_pos/kotpreinvoice/widgets/cancel_order_approve.dart';
import 'package:yen_pos/main.dart';

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
        final savedData = await lazyBox.get('branchwiseItems_$locationId');
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
      debugPrint('requestBranchwiseItemsForClient sent to client $data');
      try {
        final branchwiseItems = await getBranchwiseItemsFromLazyBox();
        if (branchwiseItems.isNotEmpty) {
          channel.sink.add(
            jsonEncode({'action': 'branchwiseItems', 'data': branchwiseItems}),
          );
          debugPrint(
            'requestBranchwiseItemsForClient sent to client $branchwiseItems',
          );
        }
        debugPrint(
          'requestBranchwiseItemsForClient sent to client $branchwiseItems',
        );
      } catch (e, st) {
        debugPrint('requestBranchwiseItemsForClient sent to client $e');
      }
    },
    // 'requestAllData': (data) async {
    //   try {
    //     final context = MyApp.navigatorKey.currentContext;
    //     if (context != null) {
    //       final upiProvider = Provider.of<UpiProviderDine>(
    //         context,
    //         listen: false,
    //       );
    //       final upiState = upiProvider.isUpiEnabled;

    //       await sendAllDataToClient(channel, isUpiEnabled: upiState);

    //       debugPrint(
    //         "📡 Sent full data snapshot to client (UPI state: $upiState)",
    //       );
    //     } else {
    //       debugPrint(
    //         "⚠️ Could not update UPI state — no active context available",
    //       );
    //     }
    //   } catch (e, st) {}
    // },
    'handle_invoice_request': (data) async {
      try {
        print("🧾 [Server] Received pre-invoice request: $data");

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
          print("❌ Missing seathiveOrderId");
          return;
        }

        // 1️⃣ Generate Invoice Number
        final generator = InvoiceNumberGenerator.instance;
        final invoiceNo = await generator.generateInvoiceNumber();
        print("🧾 Generated Invoice Number: $invoiceNo");

        final invoiceNoBox = Hive.box('invoiceNo');
        final invNoKeys = invoiceNoBox.keys.last;
        final invNoValues = invoiceNoBox.values.last;
        print('InvoiceNo Generated $invNoKeys - $invNoValues');

        // 2️⃣ Update Orders in Hive

        final ordersBox = Hive.isBoxOpen('ordersBox')
            ? Hive.box('ordersBox')
            : await Hive.openBox('ordersBox');

        print('📦 Total orders in Hive: ${ordersBox.length}');
        print('🔍 Looking for order with seathiveOrderId: $seathiveOrderId');

        bool found = false;

        for (final key in ordersBox.keys) {
          final order = ordersBox.get(key);

          print('➡️ Checking order key: $key');

          if (order is Map) {
            print('📄 Order data: $order');

            if (order['seathiveOrderId'] == seathiveOrderId) {
              found = true;
              print('🟢 MATCH FOUND for seathiveOrderId: $seathiveOrderId');

              final updatedOrder = Map<String, dynamic>.from(order)
                ..['invoiceNo'] = invoiceNo
                ..['status'] = 'confirm'
                ..['preinvoiceTime'] = preinvoiceTime
                ..['edit'] = "Yes"
                ..['statusEdited'] = "true";

              print('✏️ Updating order with:');
              print('   • invoiceNo: $invoiceNo');
              print('   • status: confirm');
              print('   • preinvoiceTime: $preinvoiceTime');

              await ordersBox.put(key, updatedOrder);
              debugPrint("updatedOrderData $updatedOrder");

              final updatedorder = ordersBox.get(key);
              print('Key: $key');
              print('Order: $updatedorder');
            }
          } else {
            print('⚠️ Skipped non-map entry at key: $key');
          }
        }

        // final updatedOrderData = ordersBox.get(key);

        if (!found) {
          print(
            '❌ No matching order found for seathiveOrderId: $seathiveOrderId',
          );
        }

        print("✅ Orders updated with invoice number.");

        // 3️⃣ Print Invoice on SERVER
        try {
          print("🖨️ Printing invoice on server...");

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

          print("🖨️ Print completed.");
        } catch (e) {
          print("❌ Printer Error: $e");
        }

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

        print('📡 Broadcasted invoice update to all clients.');

        SyncServiceKot().patchEditedOrders();
      } catch (e) {
        print('❌ Failed to update orders with invoice: $e');
      }
    },
    'requestDineInShiftId': (data) async {
      debugPrint("requestDineInShiftId - ${shiftId.value}");
      sendDataToClients({
        'action': 'shiftIds',
        'shiftIds': shiftId.value,
      }, clients);
    },

    'requestAllData': (data) async {
      final orders = await loadOrdersFromHiveUtility();
      final invoices = await loadInvoicesFromHiveKOT();
      final printerDetails = await loadPrintersFromHive();
      final invoice = await loadInvoicesFromHive();

      print("📦 Loaded orders, invoices, printer details, and UPI state");

      final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

      final filteredOrders = orders.where((order) {
        try {
          final orderDate = DateFormat('dd-MM-yyyy').parse(order['date']);
          return DateFormat('dd-MM-yyyy').format(orderDate) == currentDate;
        } catch (_) {
          return false;
        }
      }).toList();
      debugPrint("Filtered Orders: $filteredOrders");

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
        'shiftIds': shiftIdKOT,
        'invoices': invoice,
      };
      debugPrint("📦 Loaded orders, invoices, printer details, and UPI state");
      sendDataToClients(allDataMessage, clients);
      debugPrint("📦 Loaded orders, invoices, printer details, and UPI state");
    },

    // 'requestAllData': (data) async {
    //   final orders = await loadOrdersFromHiveUtility();
    //   final invoicesKOT = await loadInvoicesFromHiveKOT();
    //   final printerDetails = await loadPrintersFromHive();
    //   final invoices = await loadInvoicesFromHive();

    //   debugPrint('✅ _saveToHiveBoxOrders: ${orders.length} records to Hive');

    //   orders.asMap().forEach((index, order) {
    //     debugPrint('📦 Order [$index]: ${order}');
    //   });
    //   final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

    //   final filteredOrders = orders.where((order) {
    //     try {
    //       final orderDate = DateFormat('dd-MM-yyyy').parse(order['date']);
    //       return DateFormat('dd-MM-yyyy').format(orderDate) == currentDate;
    //     } catch (_) {
    //       return false;
    //     }
    //   }).toList();

    //   final filteredInvoicesKOT = invoicesKOT.where((invoice) {
    //     try {
    //       final invoiceDate = DateFormat(
    //         'dd-MM-yyyy',
    //       ).parse(invoice['invoiceDate']);
    //       return DateFormat('dd-MM-yyyy').format(invoiceDate) == currentDate;
    //     } catch (_) {
    //       return false;
    //     }
    //   }).toList();

    //   final Map<String, Map<String, dynamic>> uniqueInvoicesKOT = {};
    //   for (var invoice in filteredInvoicesKOT) {
    //     final id = invoice['hiveInvoiceId']?.toString();
    //     if (id != null) uniqueInvoicesKOT[id] = invoice;
    //   }
    //   final dedupedInvoicesKOT = uniqueInvoicesKOT.values.toList();

    //   final allDataMessage = {
    //     'action': 'allDataResponse',
    //     'orders': filteredOrders,
    //     'invoicesKOT': dedupedInvoicesKOT,
    //     'KOTprinters': printerDetails,
    //     'tables': tables,
    //     'shiftIds': shiftIdKOT,
    //     'invoices': invoices,
    //   };
    //   sendDataToClients(allDataMessage, clients);
    // },
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
        debugPrint(
          "✅ Patched order status for seatHiveOrderId=$seathiveOrderId",
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
    // 'newClientConnected': (data) async {
    //   try {
    //     final deviceCode = data['deviceCode']?.toString();
    //     if (deviceCode != null) {
    //       // Deduplicate: Close old channel for this deviceCode
    //       if (deviceClientMap.containsKey(deviceCode)) {
    //         final oldChannel = deviceClientMap[deviceCode];
    //         clients.remove(oldChannel);
    //         oldChannel?.sink.close();
    //         print("🔌 Removed old connection for deviceCode: $deviceCode");
    //       }
    //       // Associate new channel with deviceCode
    //       deviceClientMap[deviceCode] = channel;
    //       print("🔗 Associated deviceCode: $deviceCode with channel");
    //     }
    //     //await handleNewClientConnected(data, channel);
    //     print("👥 New client handshake complete for deviceCode: $deviceCode");
    //   } catch (e, st) {
    //     print("❌ Error handling new client: $e\n$st");
    //   }
    // },
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
        debugPrint("data of the reverseCancelOrder Item is $data");
        final hiveOrderId = data['hiveOrderId'];
        final int updatedIndex = data['updatedIndex'];
        final double updatedQty = (data['updatedQuantity'] as num).toDouble();
        final double revertedQty = (data['revertedQty'] as num).toDouble();
        final double updatedCancelledQty = (data['updatedCancelledQty'] as num)
            .toDouble();
        final double totalAmount = (data['totalAmount'] as num).toDouble();
        final double updatedAmount = (data['updatedAmount'] as num).toDouble();
        final bool partiallycancelled = data['partiallycancelled'] == true;
        final String ipAddress = data['ipAddress'];

        await patchOrderInHiveIndexWise(
          hiveOrderId,
          updatedIndex,
          updatedQty,
          revertedQty,
          updatedCancelledQty,
          updatedAmount,
          totalAmount,
          partiallycancelled,
          ipAddress,
          data,
        );
      } catch (e, st) {}
    },
    'clientDeviceData': (data) async {
      try {
        debugPrint('🟢 clientDeviceData RECEIVED');

        final deviceData = data['data'] as Map<String, dynamic>?;

        if (deviceData == null) {
          debugPrint('⚠️ Invalid device data (null)');
          return;
        }

        final String? clientIp = deviceData['clientIp'] as String?;
        if (clientIp == null || clientIp.isEmpty) {
          debugPrint('⚠️ Missing client IP in deviceData');
          return;
        }

        final String deviceType = deviceData['deviceType'] ?? 'client';

        debugPrint(
          '📥 Device data from $clientIp '
          '(type=$deviceType, model=${deviceData['model']})',
        );

        deviceData['lastUpdated'] = DateTime.now().toIso8601String();

        final box = Hive.isBoxOpen('connectedDevices')
            ? Hive.box('connectedDevices')
            : await Hive.openBox('connectedDevices');

        // 🔍 Find existing device by IP (DO NOT trust key order)
        final existingKey = box.keys.firstWhere(
          (k) => box.get(k)?['clientIp'] == clientIp,
          orElse: () => null,
        );

        bool isNewDevice = false;

        if (existingKey != null) {
          debugPrint(
            '♻️ Existing device found (key=$existingKey) — updating IN PLACE',
          );

          final oldData = Map<String, dynamic>.from(box.get(existingKey));

          // 🔒 Preserve orderIndex ALWAYS
          deviceData['orderIndex'] = oldData['orderIndex'];

          await box.put(existingKey, {...oldData, ...deviceData});
        } else {
          // 🆕 New device joins
          isNewDevice = true;

          if (deviceType == 'client') {
            // 🔑 Assign orderIndex ONLY ON FIRST JOIN
            final maxOrder = box.values
                .where((v) => v is Map && v['deviceType'] == 'client')
                .map((v) => v['orderIndex'] ?? 0)
                .fold<int>(0, (a, b) => a > b ? a : b);

            deviceData['orderIndex'] = maxOrder + 1;

            debugPrint(
              '🆕 New client assigned orderIndex=${deviceData['orderIndex']}',
            );
          }

          final key = deviceType == 'server' ? 'server' : 'device_$clientIp';

          debugPrint('🆕 Inserting new device with key=$key');

          await box.put(key, deviceData);
        }

        activeClientIps.add(clientIp);

        debugPrint(
          '💾 Device stored successfully: $clientIp '
          '(newDevice=$isNewDevice, orderIndex=${deviceData['orderIndex']})',
        );

        // 🔥 Recalculate priority ONLY when it makes sense
        // if (isNewDevice && deviceType == 'client') {
        //   debugPrint(
        //     '📡 Triggering updateTopPrioritiesAndBroadcast() (new client joined)',
        //   );
        await updateTopPrioritiesAndBroadcast();
        // } else {
        //   debugPrint('⏭️ Skipping priority update (heartbeat / server update)');
        // }

        // 🔍 Debug: show final stored order
        debugPrint('🔍 connectedDevices FINAL STATE:');
        for (final k in box.keys) {
          final v = box.get(k);
          if (v is Map) {
            debugPrint(
              '   $k → ${v['clientIp']} '
              '(type=${v['deviceType']}, orderIndex=${v['orderIndex']})',
            );
          }
        }
      } catch (e, st) {
        debugPrint('❌ Error in clientDeviceData: $e');
        debugPrint(st.toString());
      }
    },
    'reorderClient': (data) async => handleClientReorder(data),
    'clientDisconnected': (data) async {
      try {
        final clientIp = data['clientIp']?.toString();

        if (clientIp == null) {
          debugPrint("⚠️ clientDisconnected missing client IP");
          return;
        }

        final box = Hive.isBoxOpen('connectedDevices')
            ? Hive.box('connectedDevices')
            : await Hive.openBox('connectedDevices');

        final keysToDelete = box.keys
            .where((key) => (box.get(key) as Map?)?['clientIp'] == clientIp)
            .toList();

        for (final key in keysToDelete) {
          await box.delete(key);
          debugPrint("🗑️ Removed disconnected device data for IP: $clientIp");
        }

        // === Recalculate Top 5 Priorities ===
        await updateTopPrioritiesAndBroadcast();
      } catch (e, st) {
        debugPrint("❌ Error handling clientDisconnected: $e\n$st");
      }
    },
  };

  // Type Handlers
  final Map<String, Future<void> Function(Map<String, dynamic>)> typeHandlers =
      {
        'approveCancelOrder': (data) async =>
            handleApproveCancelOrder(data, clients),
        'cancelOrderApprovalResponse': (data) async =>
            handleCancelOrderApprovalResponse(data, clients),
        'shiftCreated': (data) async {
          handleShiftOpen(data);
        },
        'shiftClosed': (data) async {
          handleShiftClose(data);
        },
        'DineInStatus': (data) async {
          handleDineIn(data);
        },
        'handshake': (data) async => handleHandShake(data, clients),
        'updateDispatch': (data) => handleUpdateDispatch(
          clients: clients,
          locationId: locationId,
          message: data,
        ),
        'decreaseDispatch': (data) => handleDecreaseDispatch(
          clients: clients,
          locationId: locationId,
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
        'posInvoice': (data) async => handleInvoice(data, clients),
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
      print("WS : $message");
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
            print("WS : $data");
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
  print('Server HandShake : $data');
  final d = {'action': 'handshake', 'message': 'From server'};
  sendDataToClients(d, clients);
}

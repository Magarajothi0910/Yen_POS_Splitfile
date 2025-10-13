import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:udp/udp.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenposapp/screens/choose_mode/choose_mode_screen.dart';

import '../../screens/kot_screen/global/globals.dart' as globals;

class ServerScreen extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _ServerScreenState createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  final List<Map<String, dynamic>> _receivedData = [];
  List<Map<String, dynamic>> _invoiceData = []; // List to store invoice data
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Set<WebSocketChannel> clients = {};
  List<Map<String, dynamic>> orders = [];
  final GlobalKey keyboardKey = GlobalKey();
  Timer? _syncTimer;
  Timer? _patchCheckTimer;
  List<String> logs = [];
  String serverPort = "Unknown";
  late Box box;
  bool serverFound = false;
  String status = 'Searching for server...';
  @override
  initState() {
    super.initState();

    checkIfServerWasPreviouslyStored();

    //_patchCheckTimer = Timer.periodic(Duration(minutes: 5), (timer) {
    //   _syncService.patchEditedOrders();
    // });
  }

  Future<void> checkIfServerWasPreviouslyStored() async {
    final serverBox = await Hive.openBox('serverBox');
    final savedIp = serverBox.get('serverIp', defaultValue: '');
    final savedPort = serverBox.get('serverPort', defaultValue: '');

    if (savedIp.isNotEmpty && savedPort.isNotEmpty) {
      final localIp = await getLocalIp();
      globals.serverip = savedIp;
      globals.port = savedPort;

      if (localIp == savedIp) {
        // We are the server — start services again
        await startUdpResponder(savedIp, globals.udpPort);
        startServer(clients, onDataReceived);
      }

      setState(() {
        serverFound = true;
      });
      // print("Using previously stored server IP: $golserverip:$serverPort");
    } else {
      setState(() {
        serverFound = false;
      });
    }
    // startServerInBackground();
  }

  Future<void> _initializeServer() async {
    final ip = await getLocalIp();
    if (ip != null) {
      // Store in Hive
      final serverBox = await Hive.openBox('serverBox');
      await serverBox.put('serverIp', ip);
      await serverBox.put('serverPort', globals.port);

      // Set global values
      globals.serverip = ip;
      serverFound = true;

      await startUdpResponder(
          ip, globals.udpPort); // Respond to client discovery
      startServer(clients, onDataReceived); // Start WebSocket server
    } else {}
  }

  void dispose() {
    // Close all Hive boxes
    // HiveManager().closeAllBoxes();
    _syncTimer?.cancel();

    super.dispose();
  }

  void discoverServer() async {
    final udp = await UDP.bind(Endpoint.any());

    // Send WHO_IS_SERVER to broadcast
    udp.send(
      utf8.encode('WHO_IS_SERVER'),
      Endpoint.broadcast(port: const Port(33441)),
    );

    final serverBox = await Hive.openBox('serverBox');

    // Wait max 2 seconds for response
    udp.asStream(timeout: const Duration(seconds: 2)).listen((datagram) async {
      if (datagram != null) {
        final message = utf8.decode(datagram.data);
        if (message.startsWith('SERVER:')) {
          final parts = message.split(':');
          final ip = parts[1];
          final port = parts[2];

          // Save to Hive
          await serverBox.put('serverIp', ip);
          await serverBox.put('serverPort', port);

          // Assign to global variable
          globals.serverip = ip;

          setState(() {
            status = 'Server found at $ip:$port';
            serverFound = true;
          });

          udp.close();
        }
      }
    }, onDone: () async {
      if (!serverFound) {
        final fallbackIp = serverBox.get('serverIp', defaultValue: '');
        final fallbackPort = serverBox.get('serverPort', defaultValue: '');

        if (fallbackIp.isNotEmpty) {
          globals.serverip = fallbackIp; // fallback to stored IP
          serverPort = fallbackPort;
          setState(() {
            status = 'Using saved server: ${globals.serverip}:$serverPort';
            serverFound = true;
          });
        } else {
          setState(() {
            status = 'No server found';
          });
        }
      }
    });
  }

  Future<void> _loadInvoices() async {
    // final invoiceBox = await HiveManager().invoicesBox;
    // final List<Map<String, dynamic>> invoices = [];
    // print("invoices   $invoices");
    // for (int i = 0; i < invoiceBox.length; i++) {
    //   var invoice = invoiceBox.getAt(i);

    //   if (invoice is String) {
    //     try {
    //       invoice = jsonDecode(invoice);
    //     } catch (e) {
    //       print("Error decoding invoice at index $i: $e");
    //       continue;
    //     }
    //   }

    //   if (invoice is Map<String, dynamic>) {
    //     invoices.add(invoice);
    //   }
    // }

    // setState(() {
    //   _invoiceData = invoices;
    // });
  }

  Future<String?> getLocalIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 &&
            !addr.isLoopback &&
            addr.address.startsWith('192.')) {
          return addr.address;
        }
      }
    }
    return null;
  }

  Future<void> startUdpResponder(String ip, int udpPort) async {
    final udp = await UDP.bind(Endpoint.any(port: const Port(33441)));

    udp.asStream().listen((datagram) {
      if (datagram == null) return;

      final message = utf8.decode(datagram.data);

      if (message == 'WHO_IS_SERVER') {
        final response = utf8.encode('SERVER:$ip:${globals.port}');
        udp.send(
            response,
            Endpoint.unicast(
              datagram.address,
              port: Port(datagram.port),
            ));
      }
    });
  }

  void startServer(Set<WebSocketChannel> clients,
      Function(Map<String, dynamic>) onDataReceived) async {
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 8383);

      // tokenCounter = await getTokenCounterFromHive();

      server.transform(WebSocketTransformer()).listen((WebSocket socket) {
        handleWebSocket(socket, clients, onDataReceived);
      });
    } catch (e) {}
  }

  Map<String, String> seathiveOrderIds = {};

  Future<void> handleOrder(Map<String, dynamic> data) async {
    dynamic branchName = data['branchName'];

    final seat = data['seat'];
    data['deviceId'] =
        data['deviceId']?.toString() ?? ''; // Default to empty string if null
    // Handle `seathiveOrderId` logic
    if (data['seathiveOrderId'] == null || data['seathiveOrderId'].isEmpty) {
      //  data['seathiveOrderId'] = generateSeathiveOrderId(branchName, seat);
    } else {
      // Log that an existing ID was provided and reused
    }

    // // Generate hiveOrderId if required fields are present
    // final date = data['date'];
    // final time = data['time'];
    // if (branchName != null && date != null && time != null) {
    //   data['hiveOrderId'] = await generatehiveOrderId(branchName);
    // }

    // // Assign a token number if not already provided
    // data['tokenNo'] = generateTokenNumber();

    // // Send the updated data to all connected clients
    // sendDataToClients(data, clients);
    // print("type order:$data");
    // // Save the order locally in Hive for offline support
    // await _syncService.saveOrderToHive(data);

    // Optionally, sync unsynced orders
    // await _syncService.syncUnsyncedOrders();
  }

  void handleInvoice(Map<String, dynamic> data) async {
    // Define branchName, defaulting to "BM" if not provided
    final branchName = data['branchName'];
    final date = data['invoiceDate'];
    final time = data['invoiceTime'];
    // if (branchName != null && date != null && time != null) {
    //   data['hiveInvoiceId'] = await generatehiveInvoiceId(branchName);
    // }
    // sendDataToClients({
    //   'action': 'invoiceGenerated',
    //   'invoice': data,
    // }, clients);
    // if (data['type'] == 'posInvoice') {
    //   // Save POS invoice in `posInvoiceBox`
    //   print("savePosInvoiceToHive 1");
    //   await savePosInvoiceToHive(data);
    //   print("savePosInvoiceToHive 2");
    // } else {
    //   // Save regular invoice in `invoices` box
    //   await saveInvoiceToHive(data);
    // }
    // await _syncService.saveInvoiceToHive(data);

    // Clear the pre-invoice and invoice on all clients
  }

  void handleWebSocket(WebSocket socket, Set<WebSocketChannel> clients,
      Function(Map<String, dynamic>) onDataReceived) {
    final channel = IOWebSocketChannel(socket);
    clients.add(channel);

    channel.stream.listen((message) async {
      try {
        if (message is String && message.trim().isNotEmpty) {
          String fixedMessage = message.replaceAll("'", '"');
          var data = jsonDecode(fixedMessage);

          if (data['action'] == 'hello') {
            channel.sink.add(jsonEncode({
              'action': 'response',
              'message': 'Hello Client, message received!'
            }));
            return;
          }
          if (data.containsKey('action') && data['action'] == 'heartbeat') {
            channel.sink.add(jsonEncode({'action': 'heartbeatAck'}));
            return;
          }
          if (data['action'] == 'requestAllData') {
            // Send all stored data (orders, invoices, printer details) to the client
            await sendAllDataToClient(channel);
          }
          // if (data['action'] == 'newClientConnected') {
          //   await handleNewClientConnected(data, channel);
          // } else if (data['type'] == 'order') {
          //   print("received order from client: ${data['type']}");
          //   handleOrder(data);
          // } else if (data['type'] == 'invoice' ||
          //     data['type'] == 'posInvoice') {
          //   print("data['type']1.....${data['type']}");
          //   handleInvoice(data);
          //   print("data['type']2");
          // } else if (data['status'] == 'kotTableStatusUpdated') {
          //   await _syncService.saveTableStatusToHive(data);
          //   await _syncService.upsertKotTableStatus(data);
          // }
          if (data['action'] == 'updatePrinterItems' &&
              data.containsKey('printer')) {
            final printer = data['printer'];
            final printerName = printer['name'];
            final updatedItems = printer['items'];

            // Find and update the specific printer details in _receivedData
            bool printerFound = false;
            for (var entry in _receivedData) {
              if (entry['action'] == 'printerDetails' &&
                  entry['name'] == printerName) {
                entry['items'] =
                    updatedItems; // Update the items for the matched printer
                printerFound = true;
                break;
              }
            }

            // If printer entry wasn't found, add it to _receivedData
            if (!printerFound) {
              _receivedData.add({
                'action': 'printerDetails',
                'name': printerName,
                'ipAddress': printer['ipAddress'],
                'type': printer['type'],
                'items': updatedItems,
                'orderSource': printer['orderSource'],
              });
            } else {}

            // Save the updated printer details to Hive
            // await savePrinterDetailsToHive({
            //   'action': 'printerDetails',
            //   'name': printerName,
            //   'ipAddress': printer['ipAddress'],
            //   'type': printer['type'],
            //   'items': updatedItems,
            //   'orderSource': printer['orderSource'],
            // });

            // Broadcast the updated printer details to all clients
            // sendDataToClients({
            //   'action': 'updatePrinterItems',
            //   'printer': {
            //     'name': printerName,
            //     'ipAddress': printer['ipAddress'],
            //     'type': printer['type'],
            //     'items': updatedItems,
            //   }
            // }, clients);
          } else if (data['action'] == 'printerDetails') {
            // Save printer details in Hive and add it to _receivedData
            // await savePrinterDetailsToHive(data);
            _receivedData.add(data);

            // Broadcast the printer details to all clients
            // sendDataToClients(data, clients);
          }
          onDataReceived(data);
        }
      } catch (e) {}
    }, onDone: () {
      clients.remove(channel);
    }, onError: (error) {
      clients.remove(channel);
    });
  }

  Future<void> sendAllDataToClient(WebSocketChannel channel) async {
    // // Fetch all orders, invoices, and printer details
    // final orders = await loadOrdersFromHive();
    // final invoices = await loadInvoicesFromHive();
    // final preInvoices = await loadPreInvoicesFromHive();
    // var printerBox = await Hive.openBox('printerData');
    // final printerDetails = printerBox.values.toList();

    // // Get the current date in dd-MM-yyyy format
    // final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    // print("currentDate for all data $currentDate");

    // // Filter data by the current date
    // final filteredOrders = orders.where((order) {
    //   try {
    //     final orderDate = DateFormat('dd-MM-yyyy').parse(order['date']);
    //     return DateFormat('dd-MM-yyyy').format(orderDate) == currentDate;
    //   } catch (e) {
    //     print("Error parsing order date: ${order['date']} - $e");
    //     return false;
    //   }
    // }).toList();

    // final filteredInvoices = invoices.where((invoice) {
    //   try {
    //     final invoiceDate =
    //         DateFormat('dd-MM-yyyy').parse(invoice['invoiceDate']);
    //     return DateFormat('dd-MM-yyyy').format(invoiceDate) == currentDate;
    //   } catch (e) {
    //     print("Error parsing invoice date: ${invoice['invoiceDate']} - $e");
    //     return false;
    //   }
    // }).toList();

    // final allDataMessage = jsonEncode({
    //   'action': 'allDataResponse',
    //   'orders': filteredOrders,
    //   'invoices': filteredInvoices,
    //   // 'preInvoices': filteredPreInvoices,
    //   'printerDetails': printerDetails,
    // });

    // print(filteredOrders);

    // channel.sink.add(allDataMessage);
  }

  Future<void> onDataReceived(Map<String, dynamic> data) async {
    //if (!mounted) return;

    if (data != null) {
      //for (var order in _receivedData) {}
      if (data['action'] == 'seat_tapped') {
        // sendDataToClients(data, clients);
      } else if (data['action'] == 'seat_returned') {
        //   sendDataToClients(data, clients);
      } else if (data['action'] == 'seat_transfer') {
        await handleSeatTransfer(data);
      } else if (data['action'] == 'patchOrderCancelQuantity' &&
          data.containsKey('hiveOrderId')) {
        final String hiveOrderId = data['hiveOrderId'];
        final List<double> updatedQuantities =
            (data['quantities'] as List<dynamic>?)
                    ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                    .toList() ??
                [];

        final List<double> updatedCancelledQty =
            (data['cancelledQty'] as List<dynamic>?)
                    ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                    .toList() ??
                [];

        final List<double> amounts = (data['amounts'] as List<dynamic>?)
                ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
                .toList() ??
            [];

        double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

        String partiallyCancelled = data['partiallyCancelled'] ?? "No";

        List<String> itemRemark = (data['itemRemark'] as List<dynamic>?)
                ?.map((e) => e?.toString() ?? "")
                .toList() ??
            [];

        bool dataUpdated = false;
        for (var order in _receivedData) {
          if (order['hiveOrderId'] == hiveOrderId) {
            order['quantities'] = updatedQuantities;
            order['cancelledQty'] = updatedCancelledQty;
            order['amounts'] = amounts;
            order['totalAmount'] = totalAmount;
            order['partiallyCancelled'] = partiallyCancelled;
            order['itemRemark'] = itemRemark;

            // order['addOns'] = addOns; // Update add-ons data

            order['edit'] = "Yes";
            order['fieldsEdited'] = "true";
            dataUpdated = true;
            break;
          }
        }

        if (dataUpdated) {
          // Update in Hive
          var orderBox = await Hive.openBox('ordersBox');
          for (int i = 0; i < orderBox.length; i++) {
            var orderData = orderBox.getAt(i);
            if (orderData is String) {
              orderData = jsonDecode(orderData) as Map<String, dynamic>;
            }

            if (orderData['hiveOrderId'] == hiveOrderId) {
              orderData['quantities'] = updatedQuantities;
              orderData['cancelledQty'] = updatedCancelledQty;
              orderData['amounts'] = amounts;
              orderData['totalAmount'] = totalAmount;
              orderData['partiallyCancelled'] = partiallyCancelled;
              orderData['itemRemark'] = itemRemark;

              //orderData['addOns'] = addOns; // Store add-ons in Hive

              orderData['edit'] = "Yes";
              orderData['fieldsEdited'] = "true";

              orderBox.putAt(i, orderData);

              // **Use the `_syncService` instance to patch fields in the server**
              // bool patched =
              //     await _syncService.patchFieldsByHiveOrderId(hiveOrderId, {
              //   'quantities': updatedQuantities,
              //   'cancelledQty': updatedCancelledQty,
              //   'amounts': amounts,
              //   'totalAmount': totalAmount,
              //   'partiallyCancelled': partiallyCancelled,
              //   'itemRemark': itemRemark,

              //   //'addOns': addOns, // Sync add-ons data
              // });

              // if (patched) {
              //   orderData['edit'] = "No";
              //   orderData['fieldsEdited'] = "false";
              //   await orderBox.putAt(i, orderData);
              // } else {
              //   print(
              //       "Failed to patch quantities and cancelledQty for $hiveOrderId");
              // }
            }
          }

          // Broadcast the updated order to clients
          // sendDataToClients({
          //   'action': 'orderUpdated',
          //   'hiveOrderId': hiveOrderId,
          //   'quantities': updatedQuantities,
          //   'cancelledQty': updatedCancelledQty,
          //   'amounts': amounts,
          //   'totalAmount': totalAmount,
          //   // 'addOns': addOns, // Include add-ons in the broadcast
          //   'partiallyCancelled': partiallyCancelled,
          //   'itemRemark': itemRemark,

          //   'fieldsEdited': "true",
          //   'edit': "Yes",
          // }, clients);
        } else {}
      } else if (data['action'] == 'patchOrderStatusBySeathiveOrderId') {
        final seathiveOrderId = data['seathiveOrderId']?.toString() ?? '';
        final newStatus = data['status']?.toString() ?? '';
        final preinvoiceTime = data['preinvoiceTime']?.toString() ?? '';

        final orderRemark = data['orderRemark']?.toString() ?? '';

        handlePatchOrderStatusBySeathiveOrderId(
            seathiveOrderId, newStatus, orderRemark, preinvoiceTime);
      } else if (data['action'] == 'patchCancelOrderStatusBySeathiveOrderId') {
        final hiveOrderId = data['hiveOrderId']?.toString() ?? '';
        final newStatus = data['status']?.toString() ?? '';

        final orderRemark = data['orderRemark']?.toString() ?? '';

        handlePatchCancelOrderStatusBySeathiveOrderId(
            hiveOrderId, newStatus, orderRemark);
      } else if (data['action'] == 'updateConfigDetails') {
        final seathiveOrderId = data['seathiveOrderId'];
        final updatedConfig = data['config'];
        final updatedQuantities = (data['quantities'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [];
        final cancelledQty = (data['cancelledQty'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [];
        final amounts = (data['amounts'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [];
        final partiallyCancelled = data['partiallyCancelled'] ?? "No";
        final status = data[
            'status']; // Optional field, only present if all quantities are 0.0

        bool orderUpdated = false;

        // Update in-memory data (_receivedData)
        for (var order in _receivedData) {
          if (order['seathiveOrderId'] == seathiveOrderId) {
            order['config'] = updatedConfig;
            order['quantities'] = updatedQuantities;
            order['cancelledQty'] = cancelledQty;
            order['amounts'] = amounts;
            order['partiallyCancelled'] = partiallyCancelled;
            if (status != null) {
              order['status'] = status;
            }
            order['edit'] = "Yes"; // Mark as edited
            orderUpdated = true;
            break;
          }
        }

        if (orderUpdated) {
          // Update Hive data
          var orderBox = await Hive.openBox('ordersBox');
          for (int i = 0; i < orderBox.length; i++) {
            var orderData = orderBox.getAt(i);

            if (orderData is String) {
              orderData = jsonDecode(orderData) as Map<String, dynamic>;
            }

            if (orderData['seathiveOrderId'] == seathiveOrderId) {
              orderData['config'] = updatedConfig;
              orderData['quantities'] = updatedQuantities;
              orderData['cancelledQty'] = cancelledQty;
              orderData['amounts'] = amounts;
              orderData['partiallyCancelled'] = partiallyCancelled;
              if (status != null) {
                orderData['status'] = status;
              }
              orderData['edit'] = "Yes";

              await orderBox.putAt(i, orderData);
              break;
            }
          }

          // Broadcast updated order details to all connected clients
          // sendDataToClients({
          //   'action': 'configDetailsUpdated',
          //   'seathiveOrderId': seathiveOrderId,
          //   'config': updatedConfig,
          //   'quantities': updatedQuantities,
          //   'cancelledQty': cancelledQty,
          //   'amounts': amounts,
          //   'partiallyCancelled': partiallyCancelled,
          //   'status': status,
          //   'edit': "Yes",
          // }, clients);
        } else {}
      }

      setState(() {
        _receivedData.add(data);
      });
      // sendDataToClients(data, clients);

      if (data['action'] == 'updatePrinterItems') {
        // Broadcast the updated printer data to all clients
        // sendDataToClients({
        //   'action': 'updatePrinterItems',
        //   'printer': data['printer'],
        // }, clients);
      }
      if (data['action'] == 'removePrinter') {
        // handleRemovePrinter(data, clients);
      }
    } else {}
  }

  Future<void> handleSeatTransfer(Map<String, dynamic> data) async {
    final currentTable = data['currentTable'];
    final currentSeat = data['currentSeat'];
    final targetTable = data['targetTable'];
    final targetSeat = data['targetSeat'];
    final seathiveOrderId = data['seathiveOrderId'];

    bool orderUpdated = false;

    // First, update the in-memory data (_receivedData)
    for (var order in _receivedData) {
      if (order['seathiveOrderId'] == seathiveOrderId &&
          order['table'] == currentTable &&
          order['seat'] == currentSeat) {
        order['table'] = targetTable;
        order['seat'] = targetSeat;

        order['edit'] = "Yes"; // Mark as edited
        order['seat_transfer'] = true; // Custom flag for seat transfer
        orderUpdated = true;
        break;
      }
    }

    if (orderUpdated) {
      // Update the order in Hive
      var orderBox = await Hive.openBox('ordersBox');
      for (int i = 0; i < orderBox.length; i++) {
        var orderData = orderBox.getAt(i);

        // Decode stored data if it's a string
        if (orderData is String) {
          orderData = jsonDecode(orderData) as Map<String, dynamic>;
        }

        if (orderData['seathiveOrderId'] == seathiveOrderId &&
            orderData['table'] == currentTable &&
            orderData['seat'] == currentSeat) {
          // Update the order with the new table and seat
          orderData['table'] = targetTable;
          orderData['seat'] = targetSeat;

          orderData['edit'] = "Yes";
          orderData['seat_transfer'] = true;

          await orderBox.putAt(i, orderData);
          break;
        }
      }

      // Broadcast the seat transfer to all connected clients
      // sendDataToClients({
      //   'action': 'seat_transfer',
      //   'currentTable': currentTable,
      //   'currentSeat': currentSeat,
      //   'targetTable': targetTable,
      //   'targetSeat': targetSeat,
      //   'seathiveOrderId': seathiveOrderId,
      // }, clients);
      // bool patchSuccess = await _syncService.patchOrderTableAndSeat(
      //   seathiveOrderId,
      //   targetTable,
      //   targetSeat,
      // );

      // if (patchSuccess) {
      //   print("true..........");

      //   print(
      //       "Seat transfer successfully patched on server for $seathiveOrderId");
      // } else {
      //   print("Failed to patch seat transfer on server for $seathiveOrderId");
      // }
    } else {}
  }

  void handlePatchOrderStatusBySeathiveOrderId(String seathiveOrderId,
      String newStatus, String orderRemark, String preinvoiceTime) async {
    // First, update in _receivedData
    bool dataUpdated = false;
    for (var order in _receivedData) {
      if (order['seathiveOrderId'] == seathiveOrderId) {
        order['status'] = newStatus; // Update the status
        order['orderRemark'] = orderRemark; // Update the status

        order['preinvoiceTime'] = preinvoiceTime;

        order['edit'] = "Yes"; // Set edit to Yes
        dataUpdated = true; // Set flag to indicate that an update was made
      }
    }

    // If data was updated in _receivedData, proceed to update in Hive
    if (dataUpdated) {
      var orderBox =
          await Hive.openBox('ordersBox'); // Ensure the box name is correct

      // Iterate over all stored orders and update matching ones
      for (int i = 0; i < orderBox.length; i++) {
        var orderData = orderBox.getAt(i);

        // If the stored data is a string, decode it into a map
        if (orderData is String) {
          orderData = jsonDecode(orderData) as Map<String, dynamic>;
        }

        if (orderData['seathiveOrderId'] == seathiveOrderId) {
          // Update the fields
          orderData['status'] = newStatus;
          orderData['orderRemark'] = orderRemark; // Update the status
          orderData['preinvoiceTime'] = preinvoiceTime; // Update the status

          orderData['edit'] = "Yes";
          orderData['statusEdited'] = "true";

          // Save the updated order back to Hive
          await orderBox.putAt(i, orderData);
        }
      }

      // Send data to all connected clients after the update
      // sendDataToClients({
      //   'action': 'updateOrderStatus',
      //   'hiveOrderId': seathiveOrderId,
      //   'status': newStatus,
      //   'orderRemark': orderRemark,
      //   "preinvoiceTime": preinvoiceTime,
      //   'statusEdited': "true",
      //   'edit': "Yes",
      // }, clients);
      // await _syncService.patchEditedOrders();
    } else {}
  }

  void handlePatchCancelOrderStatusBySeathiveOrderId(
      String hiveOrderId, String newStatus, String orderRemark) async {
    // First, update in _receivedData
    bool dataUpdated = false;
    for (var order in _receivedData) {
      if (order['hiveOrderId'] == hiveOrderId) {
        order['status'] = newStatus; // Update the status
        order['orderRemark'] = orderRemark; // Update the status

        order['edit'] = "Yes"; // Set edit to Yes
        dataUpdated = true; // Set flag to indicate that an update was made
      }
    }

    // If data was updated in _receivedData, proceed to update in Hive
    if (dataUpdated) {
      var orderBox =
          await Hive.openBox('ordersBox'); // Ensure the box name is correct

      // Iterate over all stored orders and update matching ones
      for (int i = 0; i < orderBox.length; i++) {
        var orderData = orderBox.getAt(i);

        // If the stored data is a string, decode it into a map
        if (orderData is String) {
          orderData = jsonDecode(orderData) as Map<String, dynamic>;
        }

        if (orderData['hiveOrderId'] == hiveOrderId) {
          // Update the fields
          orderData['status'] = newStatus;
          orderData['orderRemark'] = orderRemark; // Update the status

          orderData['edit'] = "Yes";
          orderData['statusEdited'] = "true";

          // Save the updated order back to Hive
          await orderBox.putAt(i, orderData);
        }
      }

      // Send data to all connected clients after the update
      // sendDataToClients({
      //   'action': 'updateCancelOrderStatus',
      //   'hiveOrderId': hiveOrderId,
      //   'status': newStatus,
      //   'orderRemark': orderRemark,
      //   'statusEdited': "true",
      //   'edit': "Yes",
      // }, clients);
      // await _syncService.patchEditedOrders();
    } else {}
  }

  Future<void> loginUser() async {
    // final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    // loginProvider.setUserNameError(null);
    // loginProvider.setPasswordError(null);

    // userName = _userNameController.text.trim();
    // final password = _passwordController.text.trim();

    // if (userName.isEmpty) {
    //   loginProvider.setUserNameError('Please enter a username');
    // }
    // if (password.isEmpty) {
    //   loginProvider.setPasswordError('Please enter a password');
    // }
    if (serverFound) {
      final isAlive = await isServerReachable(globals.serverip, 8383);
      if (isAlive) {
        proceedToDashboard();
      } else {
        await discoverServerAndHandle();
      }
    } else {
      await discoverServerAndHandle();
    }

    // Provider.of<OrderProvider>(context, listen: false).requestDataFromServer();
    // Navigator.pushAndRemoveUntil(
    //   context,
    //   MaterialPageRoute(builder: (context) => const DashboardScreen()),
    //   (Route<dynamic> route) => false, // Removes all previous routes
    // );
    // if (loginProvider.userNameError == null &&
    //     loginProvider.passwordError == null) {
    //   bool isValid =
    //       await loginProvider.validateCredentials(userName, password);

    //   if (isValid) {
    //     var box = await Hive.openBox('deviceData');
    //     String deviceCode = box.get('deviceCode') ?? '';

    //     Provider.of<WebSocketService>(context, listen: false)
    //         .sendDeviceCodeToServer(deviceCode);
    //     Provider.of<OrderProvider>(context, listen: false)
    //         .requestDataFromServer();

    //     // ignore: use_build_context_synchronously
    //     Navigator.pushAndRemoveUntil(
    //       context,
    //       MaterialPageRoute(builder: (context) => const TableScreen()),
    //       (Route<dynamic> route) => false, // Removes all previous routes
    //     );
    //   } else {
    //     loginProvider.setUserNameError('Invalid username or password');
    //     loginProvider.setPasswordError('Invalid username or password');
    //   }
    // }
  }

  Future<void> discoverServerAndHandle() async {
    final udp = await UDP.bind(Endpoint.any());

    udp.send(
      utf8.encode('WHO_IS_SERVER'),
      Endpoint.broadcast(port: const Port(33441)),
    );

    final serverBox = await Hive.openBox('serverBox');

    bool found = false;

    await for (final datagram
        in udp.asStream(timeout: const Duration(seconds: 2))) {
      if (datagram != null) {
        final message = utf8.decode(datagram.data);
        if (message.startsWith('SERVER:')) {
          final parts = message.split(':');
          final ip = parts[1];
          final port = parts[2];

          await serverBox.put('serverIp', ip);
          await serverBox.put('serverPort', port);
          globals.serverip = ip;

          setState(() {
            serverFound = true;
          });

          found = true;
          udp.close();
          proceedToDashboard();

          break;
        }
      }
    }

    if (!found) {
      udp.close();
      // No server found, show dialog
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No Server Found'),
          content: const Text(
              'No server was detected on the network.Server is not running make any device as server?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // dismiss only
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // close dialog

                final ip = await getLocalIp();
                if (ip != null) {
                  final box = await Hive.openBox('serverBox');
                  await box.put('serverIp', ip);
                  await box.put('serverPort', globals.port);

                  globals.serverip = ip;
                  setState(() {
                    serverFound = true;
                  });

                  await startUdpResponder(ip, globals.udpPort);
                  startServer(clients, onDataReceived);

                  proceedToDashboard();
                }
              },
              child: const Text('Make This Device Server'),
            ),
          ],
        ),
      );
    }
  }

  void proceedToDashboard() {
    // Provider.of<OrderProvider>(context, listen: false).requestDataFromServer();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (context) => ChooseModePage(
                keyboardKey: keyboardKey,
              )),
      (Route<dynamic> route) => false,
    );
  }

  // void startServerInBackground() async {
  //   bool isRunning = await FlutterForegroundTask.isRunningService;
  //   if (!isRunning) {
  //     FlutterForegroundTask.startService(
  //       notificationTitle: 'Server Running',
  //       notificationText: 'Listening for clients...',
  //       // callback: startCallback,
  //     );
  //   }
  // }

  // void startCallback() {
  //   FlutterForegroundTask.setTaskHandler(MyForegroundTaskHandler());
  // }

  @override
  Widget build(BuildContext context) {
    // final loginProvider = Provider.of<LoginProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Image.asset(
                      'assets/bestmummy.png',
                      height: 150,
                      width: 150,
                    ),
                    Image.asset(
                      'assets/kotLogin.png',
                      height: 280,
                      width: 280,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        controller: _userNameController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFE0F7FA),
                          labelText: 'Username',
                          // errorText: loginProvider.userNameError,
                          labelStyle: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF00695C),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.account_circle,
                            color: Color(0xFF00695C),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFE0F7FA),
                          labelText: 'Password',
                          // errorText: loginProvider.passwordError,
                          labelStyle: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF00695C),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.vpn_key,
                            color: Color(0xFF00695C),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 20,
                          ),
                        ),
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          //                      Navigator.pushAndRemoveUntil(
                          //   context,
                          //   MaterialPageRoute(builder: (context) => TableScreen()),
                          //   (Route<dynamic> route) => false, // Removes all previous routes
                          // );
                          loginUser();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0F7FA),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'LogIn',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF00695C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> isServerReachable(String ip, int port) async {
    try {
      final socket =
          await Socket.connect(ip, port, timeout: Duration(seconds: 2));
      socket.destroy(); // Close connection
      return true;
    } catch (e) {
      return false;
    }
  }
}

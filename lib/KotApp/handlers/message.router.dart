// import 'package:web_socket_channel/web_socket_channel.dart';

// import '../services/hive_service.dart';
// import '../services/sendDataToClients.dart';
// import 'printerhandler.dart';
// import 'seathandler.dart';
// import 'tablehandler.dart';

// Future<void> routeMessage(
//   Map<String, dynamic> data,
//   Set<WebSocketChannel> clients,
//   Function(Map<String, dynamic>) onDataReceived,
//   List<Map<String, dynamic>> receivedData,
// ) async {
//   switch (data['action']) {
//     case 'seat_tapped':
//       await handleSeatTapped(data, clients);
//       break;
//     case 'seat_returned':
//       await handleSeatReturned(data, clients);
//       break;
//     case 'seat_transfer':
//       await handleSeatTransfer(data, clients, receivedData);
//       break;
//     case 'updatePrinterItems':
//       await handlePrinterDetails(data, clients);
//       break;
//     case 'printerDetails':
//       await savePrinterDetailsToHive(data);
//       receivedData.add(data);
//       sendDataToClients(data, clients);
//       break;
//     // case 'patchOrderCancelQuantity':
//     //   await handlePatchOrderCancelQuantity(data, clients, receivedData);
//     //   break;
//     // case 'patchOrderStatusBySeathiveOrderId':
//     //   await handlePatchOrderStatus(data, clients, receivedData);
//     //   break;
//     // case 'patchCancelOrderStatusBySeathiveOrderId':
//     //   await handlePatchCancelOrder(data, clients, receivedData);
//     //   break;
//     // case 'updateConfigDetails':
//     //   await handleUpdateConfig(data, clients, receivedData);
//     //   break;
//     // case 'removePrinter':
//     //   await handleRemovePrinter(data, clients);
//     //   break;
//     case 'requestAllData':
//       await sendAllDataToClient(data['channel']);
//       break;
//     case 'newClientConnected':
//       await handleNewClientConnected(data, data['channel']);
//       break;
//     default:
//       // Optional: log unhandled actions
//       print("Unhandled action: ${data['action']}");
//       break;
//   }

//   // Also run this after everything
//   onDataReceived(data);
// }

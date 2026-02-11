// // lib/services/table_actions_service.dart

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
// import 'package:yen_pos/Server_Client/sendDataToClients.dart';
// import 'package:yen_pos/Server_Client/websocketService.dart';
// import 'package:yen_pos/kotpreinvoice/providers/cartprovider.dart';
// import 'package:yen_pos/kotpreinvoice/providers/hold_order.dart';
// import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';
// import 'package:yen_pos/kotpreinvoice/services/websocketService.dart';
// import 'package:yen_pos/Global/globals_data.dart' as globals;
// import '../components/flushbar.dart';
// import '../services/sendDataToClients.dart';

// class TableActionsService {
//   static Future<void> sendSeatActionToServer({
//     required BuildContext context,
//     required String tableNumber,
//     required String seat,
//     required String areaName,
//     required ValueNotifier<Map<String, dynamic>> productCardDataNotifier,
//     required ValueNotifier<bool> showProductCardNotifier,
//   }) async {
//     try {
//       final orderProvider = Provider.of<OrderProvider>(context, listen: false);
//       final holdOrderProvider = Provider.of<HoldOrderProvider>(
//         context,
//         listen: false,
//       );
//       final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);

//       debugPrint(
//         "🟢 Preparing to send seat action: Table=$tableNumber, Seat=$seat, Area=$areaName",
//       );

//       List<Map<String, dynamic>> ordersForSeat = [];

//       try {
//         ordersForSeat = orderProvider
//             .getActiveOrdersForSeat(tableNumber, seat)
//             .where(
//               (order) => order['table'] == tableNumber && order['seat'] == seat,
//             )
//             .toList();
//       } catch (e, stack) {
//         debugPrint("🚨 Error fetching active orders: $e\n$stack");
//       }

//       String seathiveOrderId = '';
//       try {
//         final activeOrder = ordersForSeat.isNotEmpty
//             ? ordersForSeat.firstWhere(
//                 (order) => order['status'] == 'active',
//                 orElse: () => <String, dynamic>{},
//               )
//             : <String, dynamic>{};

//         if (activeOrder.isNotEmpty) {
//           seathiveOrderId = activeOrder['seathiveOrderId'] ?? '';
//         } else {
//           debugPrint("⚠️ No active order found for this seat.");
//         }
//       } catch (e, stack) {
//         debugPrint("🚨 Error determining active order: $e\n$stack");
//       }

//       // Update the productCardViewList data
//       cartProvider.currentTableNumber.value = tableNumber;
//       cartProvider.currentSeat.value = seat;
//       cartProvider.currentAreaName.value = areaName;
//       cartProvider.currentSeathiveOrderId.value = seathiveOrderId;

//       final webSocketService = Provider.of<WebSocketService>(
//         context,
//         listen: false,
//       );
//       final data = {
//         'action': 'seat_tapped',
//         'table': tableNumber,
//         'seat': seat,
//         'seathiveOrderId': seathiveOrderId,
//       };

//       try {
//         if (globals.appType == 'server') {
//           debugPrint("🌐 Running on server, sending data to clients: $data");
//           sendDataToClients(data, globals.clients);
//         } else {
//           if (webSocketService.isConnected &&
//               webSocketService.channel != null) {
//             debugPrint("🌐 WebSocket connected, sending data...");
//             try {
//               sendataToServer(data);
//               debugPrint("✅ Data sent to server: $data");
//             } catch (e, stack) {
//               debugPrint("❌ WebSocket send error: $e\n$stack");
//               WidgetsBinding.instance.addPostFrameCallback((_) {
//                 if (context.mounted) {
//                   showCustomFlushbar(
//                     context,
//                     "WebSocket send error: $e",
//                     type: FlushbarType.error,
//                   );
//                 }
//               });
//             }
//           } else {
//             debugPrint("⚠️ WebSocket not ready. Attempting reconnect...");
//             try {
//               webSocketService.reconnect();
//             } catch (e) {
//               debugPrint("🚨 Error while reconnecting WebSocket: $e");
//             }
//             if (context.mounted) {
//               WidgetsBinding.instance.addPostFrameCallback((_) {
//                 showCustomFlushbar(
//                   context,
//                   "WebSocket not ready. Reconnecting...",
//                   type: FlushbarType.warning,
//                 );
//               });
//             }
//             return;
//           }
//         }
//       } catch (e, stack) {
//         debugPrint("🚨 Error in WebSocket handling: $e\n$stack");
//       }

//       try {
//         debugPrint("🛒 Loading hold order into cart...");
//         cartProvider.clearCart();
//         final holdOrder = holdOrderProvider.loadHoldOrder(tableNumber, seat);
//         if (holdOrder != null) {
//           holdOrder.forEach((key, value) {
//             cartProvider.cart[key] = value;
//           });
//           debugPrint("✅ Hold order loaded for table $tableNumber seat $seat");
//         } else {
//           debugPrint(
//             "ℹ️ No hold order found for table $tableNumber seat $seat",
//           );
//         }
//       } catch (e, stack) {
//         debugPrint("🚨 Error loading hold order: $e\n$stack");
//       }

//       // Show ProductCardScreen as overlay on left side
//       if (context.mounted) {
//         Future.delayed(const Duration(milliseconds: 100), () {
//           try {
//             final navigationAreaName = areaName.isNotEmpty
//                 ? areaName
//                 : _getAreaNameForTable(context, _extractMainTable(tableNumber));

//             if (navigationAreaName.isEmpty) {
//               debugPrint(
//                 "❌ No area found for table $tableNumber, cannot navigate",
//               );
//               if (context.mounted) {
//                 WidgetsBinding.instance.addPostFrameCallback((_) {
//                   showCustomFlushbar(
//                     context,
//                     "No area found for table $tableNumber",
//                     type: FlushbarType.error,
//                   );
//                 });
//               }
//               return;
//             }

//             // Set the data for ProductCardScreen and show it as overlay
//             productCardDataNotifier.value = {
//               'tableNumber': tableNumber,
//               'areaName': navigationAreaName,
//               'seat': seat,
//               'seathiveOrderId': seathiveOrderId,
//             };
//             showProductCardNotifier.value = true;

//             debugPrint(
//               "➡️ Showing ProductCardScreen as overlay for Table=$tableNumber, Seat=$seat, Area=$navigationAreaName",
//             );
//           } catch (e, stack) {
//             debugPrint("🚨 Error showing ProductCardScreen: $e\n$stack");
//           }
//         });
//       }
//     } catch (e, stack) {
//       debugPrint("💥 Fatal error in sendSeatActionToServer: $e\n$stack");
//       if (context.mounted) {
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           showCustomFlushbar(
//             context,
//             "Failed to send seat action: $e",
//             type: FlushbarType.error,
//           );
//         });
//       }
//     }
//   }

//   // Helper methods
//   static String _extractMainTable(String tableNumber) {
//     final match = RegExp(r'^(.*?)(?:\([A-Z]\))?$').firstMatch(tableNumber);
//     return match?.group(1) ?? tableNumber;
//   }

//   static String _getAreaNameForTable(BuildContext context, String tableNumber) {
//     try {
//       // You'll need to pass globals.tables or access them differently
//       // For now, return empty string and handle in the calling code
//       return '';
//     } catch (e, stack) {
//       debugPrint(
//         '❌ Error in _getAreaNameForTable for $tableNumber: $e\n$stack',
//       );
//       return '';
//     }
//   }
// }

// lib/services/table_actions_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/Server_Client/websocketService.dart';
import 'package:yen_pos/kotpreinvoice/providers/cartprovider.dart';
import 'package:yen_pos/kotpreinvoice/providers/hold_order.dart';
import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import '../components/flushbar.dart';
import '../services/sendDataToClients.dart';

class TableActionsService {
  static Future<void> sendSeatActionToServer({
    required BuildContext context,
    required String tableNumber,
    required String seat,
    required String areaName,
    required ValueNotifier<Map<String, dynamic>> productCardDataNotifier,
    required ValueNotifier<bool> showProductCardNotifier,
  }) async {
    // Early mounted check
    if (!context.mounted) return;

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final holdOrderProvider = Provider.of<HoldOrderProvider>(
        context,
        listen: false,
      );
      final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);

      debugPrint(
        "🟢 Preparing to send seat action: Table=$tableNumber, Seat=$seat, Area=$areaName",
      );

      List<Map<String, dynamic>> ordersForSeat = [];
      // try {
      //   ordersForSeat = orderProvider
      //       .getActiveOrdersForSeat(tableNumber, seat)
      //       .where(
      //         (order) => order['table'] == tableNumber && order['seat'] == seat,
      //       )
      //       .toList();
      // } catch (e, stack) {
      //   debugPrint("🚨 Error fetching active orders: $e\n$stack");
      // }

      String seathiveOrderId = '';
      try {
        final activeOrder = ordersForSeat.isNotEmpty
            ? ordersForSeat.firstWhere(
                (order) => order['status'] == 'active',
                orElse: () => <String, dynamic>{},
              )
            : <String, dynamic>{};
        if (activeOrder.isNotEmpty) {
          seathiveOrderId = activeOrder['seathiveOrderId'] ?? '';
        }
      } catch (e, stack) {
        debugPrint("🚨 Error determining active order: $e\n$stack");
      }

      // Update cart provider state
      cartProvider.currentTableNumber.value = tableNumber;
      cartProvider.currentSeat.value = seat;
      cartProvider.currentAreaName.value = areaName;
      cartProvider.currentSeathiveOrderId.value = seathiveOrderId;

      final webSocketService = Provider.of<WebSocketService>(
        context,
        listen: false,
      );

      final data = {
        'action': 'seat_tapped',
        'table': tableNumber,
        'seat': seat,
        'seathiveOrderId': seathiveOrderId,
      };

      try {
        if (globals.appType == 'server') {
          debugPrint("🌐 Running on server, sending data to clients: $data");
          sendDataToClients(data, globals.clients);
        } else {
          if (webSocketService.isConnected &&
              webSocketService.channel != null) {
            debugPrint("🌐 WebSocket connected, sending data...");
            sendataToServer(data);
            debugPrint("✅ Data sent to server: $data");
          } else {
            debugPrint("⚠️ WebSocket not ready. Attempting reconnect...");
            webSocketService.reconnect();

            if (context.mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  showCustomFlushbar(
                    context,
                    "WebSocket not ready. Reconnecting...",
                    type: FlushbarType.warning,
                  );
                }
              });
            }
            return;
          }
        }
      } catch (e, stack) {
        debugPrint("🚨 Error in WebSocket handling: $e\n$stack");
        if (context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              showCustomFlushbar(
                context,
                "WebSocket send error: $e",
                type: FlushbarType.error,
              );
            }
          });
        }
      }

      // Load hold order
      try {
        debugPrint("🛒 Loading hold order into cart...");
        cartProvider.clearCart();
        final holdOrder = holdOrderProvider.loadHoldOrder(tableNumber, seat);
        if (holdOrder != null) {
          holdOrder.forEach((key, value) {
            cartProvider.cart[key] = value;
          });
          debugPrint("✅ Hold order loaded for table $tableNumber seat $seat");
        } else {
          debugPrint(
            "ℹ️ No hold order found for table $tableNumber seat $seat",
          );
        }
      } catch (e, stack) {
        debugPrint("🚨 Error loading hold order: $e\n$stack");
      }

      // Show overlay – delayed to ensure UI is ready
      if (context.mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!context.mounted) return;

          final navigationAreaName = areaName.isNotEmpty
              ? areaName
              : _getAreaNameForTable(context, _extractMainTable(tableNumber));

          if (navigationAreaName.isEmpty) {
            debugPrint("❌ No area found for table $tableNumber");
            if (context.mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  showCustomFlushbar(
                    context,
                    "No area found for table $tableNumber",
                    type: FlushbarType.error,
                  );
                }
              });
            }
            return;
          }

          productCardDataNotifier.value = {
            'tableNumber': tableNumber,
            'areaName': navigationAreaName,
            'seat': seat,
            'seathiveOrderId': seathiveOrderId,
          };
          showProductCardNotifier.value = true;

          debugPrint(
            "➡️ Showing ProductCardScreen overlay for Table=$tableNumber, Seat=$seat, Area=$navigationAreaName",
          );
        });
      }
    } catch (e, stack) {
      debugPrint("💥 Fatal error in sendSeatActionToServer: $e\n$stack");
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showCustomFlushbar(
              context,
              "Failed to send seat action: $e",
              type: FlushbarType.error,
            );
          }
        });
      }
    }
  }

  static String _extractMainTable(String tableNumber) {
    final match = RegExp(r'^(.*?)(?:\([A-Z]\))?$').firstMatch(tableNumber);
    return match?.group(1) ?? tableNumber;
  }

  static String _getAreaNameForTable(BuildContext context, String tableNumber) {
    try {
      // Implement proper logic if needed, currently returns empty
      return '';
    } catch (e, stack) {
      debugPrint('❌ Error in _getAreaNameForTable: $e\n$stack');
      return '';
    }
  }
}

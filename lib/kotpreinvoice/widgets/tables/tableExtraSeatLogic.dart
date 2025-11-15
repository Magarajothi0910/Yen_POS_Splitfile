import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../components/flushbar.dart';
import '../../providers/order_provider.dart';
import '../../screens/customerScreen file/seat_transfer.dart';
import '../../screens/products_card_screen.dart';

// tableExtraLogic.dart

void addExtraTableToTable({
  required BuildContext context,
  required String mainTableNumber,
  required ValueNotifier<Map<String, List<String>>> extraTablesNotifier,
  required OrderProvider orderProvider,
}) {
  // 1️⃣ Prevent adding to another extra table (e.g., Table 1(B) → invalid)
  if (mainTableNumber.contains(RegExp(r'\([A-Z]\)$'))) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCustomFlushbar(
        context,
        "Can't add extra tables to another extra table.",
        type: FlushbarType.warning,
      );
    });

    return;
  }

  final currentExtras = extraTablesNotifier.value[mainTableNumber] ?? [];
  final allUsedSeats = <String>{};

  // 2️⃣ Collect all used seats from extraTablesNotifier first
  for (var extraTable in currentExtras) {
    final match = RegExp(r'\((\w)\)$').firstMatch(extraTable);
    final seat = match?.group(1);
    if (seat != null) allUsedSeats.add(seat);
  }

  // 3️⃣ Collect all used seats from orders (active or confirm)
  for (var order in orderProvider.orders) {
    final orderTable = order['table'].toString();
    if (orderTable.startsWith(mainTableNumber)) {
      final match = RegExp(r'\((\w)\)$').firstMatch(orderTable);
      final seat = match?.group(1);
      if (seat != null && (order['status'] == 'active' || order['status'] == 'confirm')) {
        allUsedSeats.add(seat);
      }
    }
  }

  const maxExtras = 3;
  if (allUsedSeats.length >= maxExtras) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCustomFlushbar(
        context,
        "Maximum $maxExtras extra seats allowed per table.",
        type: FlushbarType.warning,
      );
    });

    return;
  }

  // 4️⃣ Pick first available seat B, C, D

  String? nextAvailableSeat;
  for (int i = 1; i <= maxExtras; i++) {
    final char = String.fromCharCode(65 + i); // B, C, D
    if (!allUsedSeats.contains(char)) {
      nextAvailableSeat = char;
      break;
    }
  }

  if (nextAvailableSeat == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCustomFlushbar(
        context,
        "No available extra seats.",
        type: FlushbarType.warning,
      );
    });

    return;
  }

  final newTableNumber = "$mainTableNumber($nextAvailableSeat)";
  final updatedList = [...currentExtras, newTableNumber];

  extraTablesNotifier.value[mainTableNumber] = updatedList;
  extraTablesNotifier.notifyListeners();

  Hive.box('extra_tables').put(mainTableNumber, updatedList);

  final resolvedAreaName = getAreaNameForTable(mainTableNumber);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ProductCardScreen(
        tableNumber: newTableNumber,
        seat: nextAvailableSeat ?? '',
        areaName: resolvedAreaName,
        seathiveOrderId: '',
      ),
    ),
  );
}

// String getDisplaySeatName(String tableNumber, OrderProvider orderProvider) {
//   final mainTable = extractMainTable(tableNumber);

//   // If it is extra table like Table 1(C), don't remap
//   if (tableNumber != mainTable) return tableNumber;

//   // Check if mainTable(A) has a confirm order
//   final hasConfirmA = orderProvider.orders.any((order) =>
//       order['table'] == mainTable &&
//       order['seat'] == 'A' &&
//       order['status'] == 'confirm');

//   // If yes and you're tapping mainTable, display as Table 1(A) no matter where it's actually stored
//   if (hasConfirmA) {
//     return mainTable;
//   } else {
//     return tableNumber;
//   }
// }

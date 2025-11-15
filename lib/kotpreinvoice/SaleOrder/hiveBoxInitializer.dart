// lib/utils/hive_initializer.dart

import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxManager {
  late Box saleOrderBox;
  late Box holdOrderBox;

  Future<void> openRequiredBoxes() async {
    await Hive.openBox('invoices');
    await Hive.openBox('posInvoiceBox');
    await Hive.openBox('salesOrders');
    saleOrderBox = await Hive.openBox('saleOrderBox');
    holdOrderBox = await Hive.openBox('holdOrders');
    await Hive.openBox('salesApprovalOrder');
    await Hive.openBox('saleOrderModifyOrders');
  }

  Box getSaleOrderBox() => saleOrderBox;
  Box getHoldOrderBox() => holdOrderBox;
}

// hive_manager.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/pending_print.dart';

class HiveManager {
  static final HiveManager _instance = HiveManager._internal();
  static Box? _salesOrderBox;
  static Box? _invoiceBox;
  static Box? _salesOrderNumberBox;
  static Box? _modifyOrderBox;
  static Box? _toApproveOrderBox;
  static Box? _holdOrderBox;
  static Box? _salesApprovalOrder;
  static Box? _saleOrderModifyOrders;
  static Box? _events;
  static Box? _deliveryTypes;
  static Box? _customCharges;
  static Box? _customers;
  static Box? _branches;

  late Box? userBox;
  late Box? serverBox;
  late Box configBox;
  factory HiveManager() => _instance;

  HiveManager._internal();

  static Future<void> initialize() async {
    await Hive.initFlutter();

    _salesOrderBox = await Hive.openBox('saleOrderBox');
    _invoiceBox = await Hive.openBox('invoices');
    _modifyOrderBox = await Hive.openBox('modifyOrderBox');

    _events = await Hive.openBox('events');
    _deliveryTypes = await Hive.openBox('deliveryTypes');
    _customCharges = await Hive.openBox('charges');
    _customers = await Hive.openBox('customerBox');
    _branches = await Hive.openBox('branches');

    _toApproveOrderBox = await Hive.openBox('toApproveOrderBox');
    _holdOrderBox = await Hive.openBox('holdOrders');
    _salesOrderNumberBox = await Hive.openBox('salesOrderNumberBox');
    _salesApprovalOrder = await Hive.openBox('salesApprovalOrder');
    _saleOrderModifyOrders = await Hive.openBox('saleOrderModifyOrders');

    // Boxes from init()
  }

  Future<void> init() async {
    await Hive.initFlutter(); // Initialize Hive

    userBox = await Hive.openBox('userBox');
    serverBox = await Hive.openBox('serverBox'); // New line for serverBox
    configBox = await Hive.openBox('configBox');

    _events = await Hive.openBox('events');
    _deliveryTypes = await Hive.openBox('deliveryTypes');
    _customCharges = await Hive.openBox('charges');
  }

  static Box get salesOrderBox {
    if (_salesOrderBox == null) {
      throw Exception(
        'Saleorder Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _salesOrderBox!;
  }

  static Box get invoiceBox {
    if (_invoiceBox == null) {
      throw Exception(
        'Invoice Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _invoiceBox!;
  }

  static Box get modifyOrderBox {
    if (_modifyOrderBox == null) {
      throw Exception(
        'Modify order Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _modifyOrderBox!;
  }

  static Box get toApproveOrderBox {
    if (_toApproveOrderBox == null) {
      throw Exception(
        'To Approval Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _toApproveOrderBox!;
  }

  static Box get holdOrderBox {
    if (_holdOrderBox == null) {
      throw Exception(
        'Hold order Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _holdOrderBox!;
  }

  static Box get salesOrderNumberBox {
    if (_salesOrderNumberBox == null) {
      throw Exception(
        'Sale order Number Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _salesOrderNumberBox!;
  }

  static Box get salesApprovalOrder {
    if (_salesApprovalOrder == null) {
      throw Exception(
        'Sales approval Order Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _salesApprovalOrder!;
  }

  static Box get saleOrderModifyOrders {
    if (_saleOrderModifyOrders == null) {
      throw Exception(
        ' Sale order Modify Order Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _saleOrderModifyOrders!;
  }

  static Box get events {
    if (_events == null) {
      throw Exception(
        'Event Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _events!;
  }

  static Box get deliveryTypes {
    if (_deliveryTypes == null) {
      throw Exception(
        'Delivery Types Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _deliveryTypes!;
  }

  static Box get customCharges {
    if (_customCharges == null) {
      throw Exception(
        'Custom Charge Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _customCharges!;
  }

  static Box get customers {
    if (_customers == null) {
      throw Exception(
        'customer Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _customers!;
  }

  static Box get branches {
    if (_branches == null) {
      throw Exception(
        'customer Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _branches!;
  }
}

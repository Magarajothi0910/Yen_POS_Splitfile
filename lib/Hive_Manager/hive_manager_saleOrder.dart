// hive_manager.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveManager {
  static final HiveManager _instance = HiveManager._internal();
  static Box? _salesOrderBox;
  static Box? _invoiceBox;
  static Box? _salesOrderNumberBox;
  static Box? _modifyOrderBox;
  static Box? _toApproveOrderBox;
  static Box? _holdOrderBox;
  late Box? userBox;
  late Box? serverBox;
  late Box configBox;
  factory HiveManager() => _instance;

  HiveManager._internal();

  static Future<void> initialize() async {
    await Hive.initFlutter(); // Initialize Hive
    _salesOrderBox = await Hive.openBox('saleOrderBox');
    _invoiceBox = await Hive.openBox('invoices');
    _modifyOrderBox = await Hive.openBox('modifyOrderBox');
    _toApproveOrderBox = await Hive.openBox('toApproveOrderBox');

    _holdOrderBox = await Hive.openBox('holdOrders');
    _salesOrderNumberBox = await Hive.openBox('salesOrderNumberBox');
  }

  Future<void> init() async {
    await Hive.initFlutter(); // Initialize Hive

    userBox = await Hive.openBox('userBox');
    serverBox = await Hive.openBox('serverBox'); // New line for serverBox
    configBox = await Hive.openBox('config');
  }

  static Box get salesOrderBox {
    if (_salesOrderBox == null) {
      throw Exception(
        'Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _salesOrderBox!;
  }

  static Box get invoiceBox {
    if (_invoiceBox == null) {
      throw Exception(
        'Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _invoiceBox!;
  }

  static Box get modifyOrderBox {
    if (_modifyOrderBox == null) {
      throw Exception(
        'Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _modifyOrderBox!;
  }

  static Box get toApproveOrderBox {
    if (_toApproveOrderBox == null) {
      throw Exception(
        'Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _toApproveOrderBox!;
  }

  static Box get holdOrderBox {
    if (_holdOrderBox == null) {
      throw Exception(
        'Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _holdOrderBox!;
  }

  static Box get salesOrderNumberBox {
    if (_salesOrderNumberBox == null) {
      throw Exception(
        'Hive not initialized! Call HiveManager.initialize() first',
      );
    }
    return _salesOrderNumberBox!;
  }
}

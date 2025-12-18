import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncServiceKot {
  // final String apiUrl = 'https://yenerp.com/fastapi/orders/';
  final String apiUrl = 'https://yenerp.com/fastapi/orders/';
  final String invoiceApiUrl = 'https://yenerp.com/fluttertestapi/invoices/';
  final String kotTableStatusUrl = 'https://yenerp.com/fastapi/kottablesstatus';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
    ),
  )..interceptors.add(LogInterceptor(responseBody: true, requestBody: true));

  bool _isSyncingOrders = false;
  bool _isSyncingInvoices = false;

  bool isOnline = false;
  List<Function> syncQueue = [];

  Future<void> processSyncQueue() async {
    print("🔄 Processing sync queue... Queue length: ${syncQueue.length}");
    while (syncQueue.isNotEmpty && isOnline) {
      var task = syncQueue.removeAt(0);
      try {
        await task();
        print("✅ Task executed successfully from queue");
      } catch (e) {
        print("❌ Error executing queued sync task: $e");
        // Additional error handling: Log the error and potentially requeue or notify user
        if (e.toString().contains('Timeout')) {
          print(
            "⏳ Task failed due to timeout. Consider increasing retry attempts.",
          );
        } else if (e.toString().contains('Network')) {
          print(
            "🌐 Network-related failure in queued task. Will retry when online.",
          );
        }
      }
    }
  }

  void queueSync(Function syncTask) {
    print("📥 Adding task to sync queue...");
    syncQueue.add(() async {
      try {
        await syncTask();
        print("✅ Queued task executed successfully");
      } catch (e) {
        print("❌ Retry task failed: $e");
        // Enhanced error handling: Provide more context based on error type
        if (e is DioException) {
          _handleDioException(e, "Queued task");
        }
      }
    });

    if (isOnline && !_isSyncingOrders && !_isSyncingInvoices) {
      Future.microtask(() async {
        await processSyncQueue();
      });
    }
  }

  SyncServiceKot() {
    print("🔧 SyncServiceKot initialized...");
    try {
      _monitorConnectivity();
      Timer.periodic(const Duration(minutes: 10), (timer) {
        if (isOnline) {
          print("⏳ Scheduled sync triggered...");
          syncUnsyncedOrders();
          syncUnsyncedInvoices();
        } else {
          print("⚠️ Skipping scheduled sync, offline.");
        }
      });
    } catch (e) {
      print("❌ Error during SyncServiceKot initialization: $e");
    }
  }

  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      try {
        final ConnectivityResult result = results.isNotEmpty
            ? results.first
            : ConnectivityResult.none;
        isOnline = result != ConnectivityResult.none;
        print('🌐 Connectivity changed: isOnline=$isOnline, result=$result');
        if (isOnline) {
          processSyncQueue();
        }
      } catch (e) {
        print("❌ Error monitoring connectivity: $e");
        // Additional handling: Perhaps trigger a manual check or alert
        print("🔍 Attempting manual connectivity check...");
        _checkConnectivityManually();
      }
    });
  }

  Future<void> _checkConnectivityManually() async {
    try {
      var connectivity = await Connectivity().checkConnectivity();
      isOnline = connectivity != ConnectivityResult.none;
      print('🔍 Manual connectivity check: isOnline=$isOnline');
      if (isOnline) {
        processSyncQueue();
      }
    } catch (e) {
      print("❌ Manual connectivity check failed: $e");
    }
  }

  Future<void> saveOrderToHive(Map<String, dynamic> order) async {
    try {
      print("💾 Saving order to Hive...");
      var orderBox = Hive.box('ordersBox');
      order['sync'] = 'No';
      order['edit'] = 'No';
      await orderBox.add(order);
      print("✅ Order saved locally. Triggering sync...");
      await syncUnsyncedOrders();
    } catch (e) {
      print("❌ Error saving order to Hive: $e");
      // Additional error handling: Re-throw or log for debugging
      if (e.toString().contains('Box')) {
        print(
          "🔒 Hive box not initialized properly. Ensure Hive.init() was called.",
        );
      }
      rethrow; // Allow caller to handle if needed
    }
  }

  Future<void> saveKotInvoiceToHive(Map<String, dynamic> invoice) async {
    try {
      print("💾 Saving invoice to Hive...");
      var invoiceBox = Hive.box('invoicesKOT');
      invoice['sync'] = 'No';
      invoice['edit'] = 'No';
      await invoiceBox.add(invoice);
      print("✅ Invoice saved locally. Triggering sync...");
      await syncUnsyncedInvoices();
    } catch (e) {
      print("❌ Error saving invoice to Hive: $e");
      if (e.toString().contains('Box')) {
        print(
          "🔒 Hive box 'invoices' not initialized. Check Hive registration.",
        );
      }
      rethrow;
    }
  }

  Future<void> syncUnsyncedOrders() async {
    print("🔄 Syncing unsynced orders...");
    if (_isSyncingOrders) {
      print("⚠️ Orders are already syncing. Skipping.");
      return;
    }
    _isSyncingOrders = true;

    try {
      var orderBox = Hive.box('ordersBox');
      final keys = orderBox.keys.toList();

      for (var key in keys) {
        try {
          var orderData = orderBox.get(key);
          if (orderData is String) {
            orderData = jsonDecode(orderData) as Map<String, dynamic>;
          }

          print("📦 Order data (key=$key): $orderData");

          final status = orderData["status"];
          print("Order Status: $status");

          if (orderData is Map<String, dynamic> && orderData['sync'] == 'No') {
            print("📤 Posting unsynced order...");
            bool success = await postOrder(orderData);

            if (success) {
              orderData['sync'] = 'Yes';
              await orderBox.put(key, orderData);
              print("✅ Synced and updated order at key $key");
            } else {
              print("⚠️ Queuing failed order for retry...");
              queueSync(() => postOrder(orderData));
            }
          }
        } catch (e) {
          print("❌ Error syncing individual order (key=$key): $e");
          // Handle specific errors
          if (e.toString().contains('JSON')) {
            print(
              "📄 Invalid JSON in order data. Corrupted entry at key $key.",
            );
          }
        }
      }
    } catch (e) {
      print("❌ Error during order sync: $e");
      if (e.toString().contains('Box')) {
        print("🔒 Hive ordersBox access issue during sync.");
      }
    } finally {
      _isSyncingOrders = false;
    }

    await patchEditedOrders();
  }

  Future<void> patchEditedOrders() async {
    print("🔧 Checking for edited orders...");
    try {
      var orderBox = Hive.box('ordersBox');
      for (int i = 0; i < orderBox.length; i++) {
        try {
          var orderData = orderBox.getAt(i);
          if (orderData is String) {
            orderData = jsonDecode(orderData) as Map<String, dynamic>;
          }

          if (orderData is Map<String, dynamic> &&
              orderData['sync'] == 'Yes' &&
              orderData['edit'] == 'Yes') {
            print("📝 Found edited order at index $i: $orderData");

            if (orderData['fieldsEdited'] == 'true') {
              final hiveOrderId = orderData['hiveOrderId'].toString();
              bool patchedFields = await patchFieldsByHiveOrderId(
                hiveOrderId,
                orderData,
              );
              if (patchedFields) {
                orderData['edit'] = 'No';
                orderData['fieldsEdited'] = 'false';
                await orderBox.putAt(i, orderData);
                print("✅ Fields patched for order $hiveOrderId");
              } else {
                print(
                  "⚠️ Queuing failed field patch for order $hiveOrderId...",
                );
                queueSync(
                  () => patchFieldsByHiveOrderId(hiveOrderId, orderData),
                );
              }
            }

            if (orderData['statusEdited'] == 'true' &&
                orderData.containsKey('seathiveOrderId')) {
              final seathiveOrderId = orderData['seathiveOrderId'].toString();
              final status = orderData['status'];
              bool patchedStatus = await patchOrderStatusWithRetry(
                seathiveOrderId,
                status,
              );
              if (patchedStatus) {
                orderData['edit'] = 'No';
                orderData['statusEdited'] = 'false';
                await orderBox.putAt(i, orderData);
                print("✅ Status patched for order $seathiveOrderId");
              } else {
                print(
                  "⚠️ Queuing failed status patch for order $seathiveOrderId...",
                );
                queueSync(
                  () => patchOrderStatusBySeathiveOrderId(
                    seathiveOrderId,
                    status,
                  ),
                );
              }
            }
          }
        } catch (e) {
          print("❌ Error patching edited order at index $i: $e");
          if (e.toString().contains('JSON')) {
            print("📄 JSON decode error for order at index $i. Skipping.");
          }
        }
      }
    } catch (e) {
      print("❌ Error in patchEditedOrders: $e");
      if (e.toString().contains('length')) {
        print("🔒 Hive box length access issue. Possible corruption.");
      }
    }
  }

  Future<bool> patchOrderStatusWithRetry(
    String seathiveOrderId,
    String status, {
    int retries = 3,
  }) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      print(
        "🔄 Attempting to patch status (attempt ${attempt + 1}/$retries) for order $seathiveOrderId...",
      );
      bool success = await patchOrderStatusBySeathiveOrderId(
        seathiveOrderId,
        status,
      );
      if (success) {
        print("✅ Order status patched on attempt ${attempt + 1}");
        return true;
      }
      if (attempt < retries - 1) {
        print("⚠️ Failed attempt ${attempt + 1}, retrying in 2 seconds...");
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    print(
      "❌ All retry attempts failed for status patch on order $seathiveOrderId",
    );
    return false;
  }

  Future<bool> patchOrderStatusBySeathiveOrderId(
    String seathiveOrderId,
    String status,
  ) async {
    try {
      print("📤 Patching order status for $seathiveOrderId -> $status");
      final response = await _dio.patch(
        '${apiUrl}patch-status/$seathiveOrderId?status=$status',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        print("✅ Order status patched successfully for $seathiveOrderId");
        return true;
      }
      print(
        "❌ Failed to patch order status: HTTP ${response.statusCode} - Server rejected the status update request",
      );
      return false;
    } on DioException catch (e) {
      _handleDioException(e, "patching order status for $seathiveOrderId");
      return false;
    } catch (e) {
      print(
        "❌ Unexpected error patching order status for $seathiveOrderId: $e",
      );
      return false;
    }
  }

  Future<bool> patchFieldsByHiveOrderId(
    String hiveOrderId,
    Map<String, dynamic> fields,
  ) async {
    try {
      print("📤 Patching fields for order $hiveOrderId...");
      Map<String, dynamic> patchData = {'hiveOrderId': hiveOrderId};

      if (fields.containsKey('quantities'))
        patchData['quantities'] = fields['quantities'];
      if (fields.containsKey('cancelledQty'))
        patchData['cancelledQty'] = fields['cancelledQty'];
      if (fields.containsKey('amounts'))
        patchData['amounts'] = fields['amounts'];
      if (fields.containsKey('totalAmount'))
        patchData['totalAmount'] = fields['totalAmount'];

      final response = await _dio.patch(
        '${apiUrl}patch-fields/$hiveOrderId',
        data: jsonEncode(patchData),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        print("✅ Fields patched successfully for $hiveOrderId");
        return true;
      }
      print(
        "❌ Failed to patch fields: HTTP ${response.statusCode} - Server rejected the fields update request",
      );
      return false;
    } on DioException catch (e) {
      _handleDioException(e, "patching fields for $hiveOrderId");
      return false;
    } catch (e) {
      print("❌ Unexpected error patching fields for $hiveOrderId: $e");
      return false;
    }
  }

  void _handleDioException(DioException e, String context) {
    print("🔄 Dio error in $context:");
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        print(
          "⏳ Connection timeout: The server took too long to respond. Check your internet connection.",
        );
        break;
      case DioExceptionType.sendTimeout:
        print(
          "⏳ Send timeout: Data upload timed out. Try reducing payload size or check network stability.",
        );
        break;
      case DioExceptionType.receiveTimeout:
        print(
          "⏳ Receive timeout: Server response delayed. The request might be processed but not returned in time.",
        );
        break;
      case DioExceptionType.badResponse:
        print(
          "⚠️ Bad response: Server returned an error (HTTP ${e.response?.statusCode}). This could be a validation issue or server-side problem.",
        );
        break;
      case DioExceptionType.cancel:
        print("⏹️ Request cancelled: The operation was intentionally stopped.");
        break;
      case DioExceptionType.connectionError:
        print(
          "🌐 Connection error: Unable to establish connection to the server. Verify URL and network.",
        );
        break;
      default:
        print(
          "❌ Unknown Dio error: ${e.message}. This might be an unhandled network issue.",
        );
    }
  }

  Future<bool> postOrder(Map<String, dynamic> order) async {
    print("📤 Entered postOrder...");
    try {
      print("➡️ API URL: $apiUrl");
      print("📝 Sending order: ${jsonEncode(order)}");

      final response = await _dio.post(
        apiUrl,
        data: jsonEncode(order),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print("📡 Response: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Order posted successfully");
        return true;
      }
      print(
        "❌ Failed to post order. Status: HTTP ${response.statusCode} - Order creation rejected by server",
      );
      return false;
    } on DioException catch (e) {
      _handleDioException(e, "posting order");
      return false;
    } catch (e) {
      print("❌ Unexpected error posting order: $e");
      return false;
    }
  }

  Future<bool> patchOrderTableAndSeat(
    String seathiveOrderId,
    int table,
    String seat,
  ) async {
    try {
      Map<String, dynamic> patchData = {'table': table, 'seat': seat};

      final response = await _dio.patch(
        '${apiUrl}patch-table-seat/$seathiveOrderId?table=$table&seat=$seat',
        data: jsonEncode(patchData),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        print("✅ Table and seat patched successfully for $seathiveOrderId");
        return true;
      }
      print(
        "❌ Failed to patch table and seat: HTTP ${response.statusCode} - Update rejected by server",
      );
      return false;
    } on DioException catch (e) {
      _handleDioException(e, "patching table and seat for $seathiveOrderId");
      return false;
    } catch (e) {
      print(
        "❌ Unexpected error patching table and seat for $seathiveOrderId: $e",
      );
      return false;
    }
  }

  // Future<void> syncUnsyncedInvoices() async {
  //   print("🔄 Syncing unsynced invoices...");
  //   if (_isSyncingInvoices) {
  //     print("⚠️ Invoices are already syncing. Skipping.");
  //     return;
  //   }
  //   _isSyncingInvoices = true;
  //   print("Starting invoice sync...");
  //   try {
  //     var invoiceBox = Hive.box('invoicesKOT');
  //     for (int i = 0; i < invoiceBox.length; i++) {
  //       print("📋 Processing invoice at index $i");
  //       if (invoiceBox.getAt(i) == null) {
  //         print("⚠️ Skipping null invoice at index $i");
  //         continue;
  //       }
  //       var invoiceData = invoiceBox.getAt(i);

  //       if (invoiceData is String) {
  //         try {
  //           invoiceData = jsonDecode(invoiceData) as Map<String, dynamic>;
  //         } catch (jsonError) {
  //           print("❌ JSON decode error for invoice at index $i: $jsonError");
  //           continue;
  //         }
  //       }

  //       if (invoiceData is Map<String, dynamic> &&
  //           invoiceData['sync'] == 'No') {
  //         print(
  //           "📤 Posting unsynced invoice with ID: ${invoiceData['invoiceId'] ?? 'No ID'}",
  //         );
  //         print("📤 Posting unsynced invoice: $invoiceData");
  //         bool success = await postInvoice(invoiceData);
  //         if (success) {
  //           final updatedInvoice = Map<String, dynamic>.from(invoiceData);
  //           updatedInvoice['sync'] = 'Yes';
  //           // Store back as the original format (assuming it was String, but handle both)
  //           if (invoiceBox.getAt(i) is String) {
  //             await invoiceBox.putAt(i, jsonEncode(updatedInvoice));
  //           } else {
  //             await invoiceBox.putAt(i, updatedInvoice);
  //           }
  //           print("✅ Updated invoice at index $i with sync=Yes");
  //         } else {
  //           print("⚠️ Queuing failed invoice for retry at index $i");
  //           queueSync(() => postInvoice(invoiceData));
  //         }
  //       } else if (invoiceData is! Map<String, dynamic>) {
  //         print(
  //           "⚠️ Invalid invoice data type at index $i: ${invoiceData.runtimeType}",
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     print("❌ Error during invoice sync: $e");
  //     if (e.toString().contains('Box')) {
  //       print("🔒 Hive invoices box access issue.");
  //     }
  //   } finally {
  //     _isSyncingInvoices = false;
  //   }
  // }
  Future<void> syncUnsyncedInvoices() async {
    print("🔄 Syncing unsynced invoices...");

    if (_isSyncingInvoices) {
      print("⚠️ Invoices are already syncing. Skipping.");
      return;
    }
    _isSyncingInvoices = true;

    try {
      print("📦 Opening Hive box invoicesKOT...");
      final invoiceBox = Hive.box('invoicesKOT');

      print("📊 Total invoices: ${invoiceBox.length}");

      for (int i = 0; i < invoiceBox.length; i++) {
        print("\n📋 Processing invoice index $i");

        var rawData = invoiceBox.getAt(i);

        if (rawData == null) {
          print("⚠️ Skipping NULL invoice at index $i");
          continue;
        }

        Map<String, dynamic>? invoiceData;

        // 🔹 Parse JSON if saved as String
        if (rawData is String) {
          try {
            invoiceData = jsonDecode(rawData) as Map<String, dynamic>;
          } catch (e) {
            print("❌ JSON decode failed at index $i -> $e");
            continue;
          }
        }
        // 🔹 If already Map
        else if (rawData is Map) {
          invoiceData = Map<String, dynamic>.from(rawData);
        } else {
          print("⚠️ Invalid data type at index $i: ${rawData.runtimeType}");
          continue;
        }

        // 🔹 Check sync flag
        if (invoiceData['sync'] != 'No') {
          print("⏭️ Invoice already synced. Skipping index $i");
          continue;
        }

        final invoiceId = invoiceData['invoiceId'] ?? "NO-ID";
        print("📤 Posting unsynced invoice → ID: $invoiceId");

        // 🔹 Attempt to sync
        final success = await postInvoice(invoiceData);

        if (success) {
          print("✅ Successfully synced invoice ID: $invoiceId");

          invoiceData['sync'] = 'Yes';

          // Save back as same format it was stored
          if (rawData is String) {
            await invoiceBox.putAt(i, jsonEncode(invoiceData));
          } else {
            await invoiceBox.putAt(i, invoiceData);
          }

          print("💾 Updated invoice at index $i → sync=Yes");
        } else {
          print("⚠️ Sync failed. Adding invoice to retry queue: $invoiceId");
          queueSync(() => postInvoice(invoiceData!));
        }
      }
    } catch (e) {
      print("❌ ERROR during invoice sync: $e");

      if (e.toString().contains('Box')) {
        print("🔒 Hive box access issue for invoicesKOT.");
      }
    } finally {
      _isSyncingInvoices = false;
      print("\n✅ Finished invoice sync process.");
    }
  }

  Future<bool> postInvoice(Map<String, dynamic> invoice) async {
    try {
      print("📝 Sending invoice: ${jsonEncode(invoice)}");

      final response = await _dio.post(
        invoiceApiUrl,
        data: jsonEncode(invoice),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ Invoice posted successfully");
        return true;
      }
      print(
        "❌ Failed to post invoice: HTTP ${response.statusCode} - Invoice creation rejected by server",
      );
      return false;
    } on DioException catch (e) {
      _handleDioException(e, "posting invoice");
      return false;
    } catch (e) {
      print("❌ Unexpected error posting invoice: $e");
      // Handle parsing errors
      if (e.toString().contains('FormatException')) {
        print(
          "📊 Number parsing failed for payment fields. Check invoice data types.",
        );
      }
      return false;
    }
  }

  Future<void> saveTableStatusToHive(Map<String, dynamic> data) async {
    try {
      var box = Hive.box('tableStatus');
      await box.put('kotTableStatus', data);
      print("✅ Table status saved to Hive");
    } catch (e) {
      print("❌ Error saving table status to Hive: $e");
      if (e.toString().contains('Box')) {
        print("🔒 Hive tableStatus box not initialized.");
      }
    }
  }

  Future<void> upsertKotTableStatus(Map<String, dynamic> data) async {
    try {
      print("📤 Upserting KOT table status...");
      final response = await _dio.post(
        '$kotTableStatusUrl/upsert',
        data: jsonEncode(data),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Table status upserted successfully");
      } else {
        print(
          "❌ Failed to upsert table status: HTTP ${response.statusCode} - Upsert operation rejected",
        );
      }
    } on DioException catch (e) {
      _handleDioException(e, "upserting KOT table status");
    } catch (e) {
      print("❌ Unexpected error upserting table status: $e");
    }
  }

  Future<void> debugConnection() async {
    print("🔍 Testing server connectivity...");
    try {
      final response = await _dio.get(apiUrl);
      print("✅ Server reachable: HTTP ${response.statusCode}");
    } on DioException catch (e) {
      _handleDioException(e, "debug connection test");
    } catch (e) {
      print("❌ Unexpected debug error: $e");
    }
  }
}

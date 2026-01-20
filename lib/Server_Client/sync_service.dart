import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:yenpos/Server_Client/widget/dio_timeout.dart';
import 'package:yenpos/main.dart';

class SyncService {
  // ====== API URLs ======
  final String apiUrl = 'https://yenerp.com/orders/';
  final String invoiceApiUrl = 'https://yenerp.com/fluttertestapi/invoices/';
  final String modifyApiUrl = 'https://yenerp.com/fluttertestapi/modify/';
  final String holdOrderApi = "https://yenerp.com/fluttertestapi/salesorders/";
  final String salesApprovalOrders =
      "https://yenerp.com/fluttertestapi/approvals/";
  static const String salesOrderApi =
      "https://yenerp.com/fluttertestapi/salesorders/";
  final navigatorState = MyApp.navigatorKey.currentState;
  // ====== Hive Box Names ======
  static const String salesOrdersBoxName = 'saleOrderBox';
  static const _offlineBoxName = 'pendingInvoices';
  static final DioClient _dioClient = DioClient();

  bool _isSyncing = false;
  bool isOnline = false;
  bool _isSync = false;

  final List<Function> syncQueue = [];

  // ====== Constructor ======
  // ====== Constructor ======
  SyncService() {
    // Start real internet monitor
    _startInternetMonitor();

    if (appType != 'server') {
      return;
    }

    // Only keep WiFi network change detection
    Connectivity().checkConnectivity().then((result) {
      isOnline = result != ConnectivityResult.none;

      if (isOnline) {
        if (appType != 'server') {
          return;
        }
        if (_isSyncing) {
          return;
        }
        // _syncAllPendingData();
      } else {}
    });
  }

  /// REAL INTERNET CHECK LOOP ONLY
  void _startInternetMonitor() {
    Timer.periodic(const Duration(seconds: 4), (_) async {
      bool previous = isOnline;
      bool current = await _checkRealInternet();

      if (current != previous) {
        isOnline = current;

        if (isOnline) {
          if (appType != 'server') {
            return;
          }
          if (_isSyncing) {
            return;
          }
          if (!_isSync) {
            _syncAllPendingData();
            _isSync = true;
          }
          _isSync = false;
        } else {
          _isSync = false;
        }
      }
    });
  }

  /// Only track WiFi on/off — NOT internet state
  void monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork =
          results.isNotEmpty && results.first != ConnectivityResult.none;

      if (!hasNetwork) {
        isOnline = false;
      } else {}
    });
  }

  /// Google 204 Real Internet Test
  Future<bool> _checkRealInternet() async {
    try {
      final response = await HttpClient()
          .getUrl(Uri.parse("https://clients3.google.com/generate_204"))
          .timeout(const Duration(seconds: 3));

      final result = await response.close();
      return result.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// Process all queued sync tasks when online
  Future<void> processSyncQueue() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;

    while (syncQueue.isNotEmpty && isOnline) {
      final task = syncQueue.removeAt(0);
      try {
        await task();
      } catch (e, stack) {}
    }

    _isSyncing = false;
  }

  bool _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      debugPrint("⏱ Timeout Error");
    } else if (e.type == DioExceptionType.connectionError) {
      debugPrint("🌐 No Internet");
    } else {
      debugPrint("❌ API Error: ${e.message}");
    }
    return false;
  }

  /// Add a task to the queue
  void queueSync(Function syncTask) {
    syncQueue.add(syncTask);

    if (isOnline) {
      processSyncQueue();
    } else {}
  }

  // Async sync handler outside listen()
  Future<void> _syncAllPendingData() async {
    if (!_isSyncing && isOnline) {
      await processSyncQueue();
      await syncUnsyncedSaleOrders();
      await syncUnsyncedInvoices();
      await syncUnsyncedHoldOrders();
      await syncPendingPatches();

      _isSync = false;
    }
  }

  Future<void> processPrintQueue(String printerIp) async {
    final box = await Hive.openBox<Uint8List>('print_queue');
    if (box.isEmpty) return;

    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);

    final res = await printer.connect(printerIp, port: 9100);
    if (res == PosPrintResult.success) {
      for (int i = 0; i < box.length; i++) {
        final bytes = box.getAt(i);
        if (bytes != null) {
          printer.rawBytes(bytes);
        }
      }
      await box.clear(); // clear queue after successful print
      printer.disconnect();
    } else {
      // Printer still offline, keep queue
    }
  }

  Future<void> saveKotInvoiceToHive(Map<String, dynamic> invoice) async {
    // Step 1: Open Hive box
    final invoiceBox = await Hive.openBox('invoices');

    // Step 2: Add sync/edit flags
    invoice['sync'] = 'No';
    invoice['edit'] = 'No';

    // Step 3: Handle invoiceDate
    if (invoice['invoiceDate'] is DateTime) {
      final originalDate = invoice['invoiceDate'];
      final formattedDate = DateFormat('dd-MM-yyyy').format(originalDate);
      invoice['invoiceDate'] = formattedDate;
    } else if (invoice['invoiceDate'] == null ||
        invoice['invoiceDate'] is! String) {
      final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      invoice['invoiceDate'] = today;
    } else {}

    // Step 4: Save to Hive
    final key = await invoiceBox.add(invoice);

    // Step 5: Verify saved data
    final savedInvoice = invoiceBox.get(key);

    // Step 6: Sync unsynced invoices
    await syncUnsyncedInvoices();
  }

  Future<void> savePosInvoiceToHive(Map<String, dynamic> invoice) async {
    var invoiceBox = await Hive.openBox('invoices');

    invoice['sync'] = 'No';
    invoice['edit'] = 'No'; // Initialize edit field

    await invoiceBox.add(invoice);

    // // Check connectivity and try to sync after saving locally
    // await syncUnsyncedInvoices();
  }

  Future<void> saveHoldToHive(
    Map<String, dynamic> data,
    Box holdOrderBox,
  ) async {
    var holdOrderBox = await Hive.openBox('holdOrders');

    data['sync'] = 'No';
    data['edit'] = 'No'; // Initialize edit field

    // Check connectivity and try to sync after saving locally
    await syncUnsyncedHoldOrders();
  }

  Future<void> saveInvoiceToHive(Map<String, dynamic> invoice) async {
    var invoiceBox = await Hive.openBox('invoicesBox');
    invoice['sync'] = 'No';
    invoice['edit'] = 'No'; // Initialize edit field as "No" for new invoices
    await invoiceBox.add(invoice);

    // Check connectivity and try to sync after saving locally
    await syncUnsyncedInvoices();
  }

  Future<void> saveholdOrderToHive(Map<String, dynamic> order) async {
    var holdOrderBox = await Hive.openBox('holdOrders');
    order['sync'] = 'No';
    order['edit'] = 'No'; // Initialize edit field as "No" for new orders
    await holdOrderBox.add(order);
  }

  Future<void> saveSalesApprovalOrderToHive(Map<String, dynamic> order) async {
    var salesApprovalOrderBox = await Hive.openBox('salesApprovalOrder');
    order['sync'] = 'No';
    order['edit'] = 'No'; // Initialize edit field as "No" for new orders
    await salesApprovalOrderBox.add(order);
  }

  Future<void> syncUnsyncedSaleOrders() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;

    var orderBox = HiveManager.salesOrderBox;

    // Keep track of saleOrderNos that are already posted in this run
    Set<String> postedOrders = {};

    for (int i = 0; i < orderBox.length; i++) {
      dynamic orderData = orderBox.getAt(i);

      // Print type and raw value from Hive

      // Decode if stored as JSON String
      if (orderData is String) {
        try {
          orderData = jsonDecode(orderData);
        } catch (e) {
          continue;
        }
      }

      // Ensure orderData is Map<String, dynamic>
      if (orderData is Map) {
        try {
          orderData = Map<String, dynamic>.from(orderData);
        } catch (e) {
          continue;
        }
      } else {
        continue;
      }

      // Skip already synced orders
      if (orderData['sync'] != 'No') {
        continue;
      }

      // Extract saleOrderNo from nested data map
      String? saleOrderNo;
      Map<String, dynamic>? innerData;
      try {
        if (orderData['data'] != null && orderData['data'] is Map) {
          innerData = Map<String, dynamic>.from(orderData['data']);
          saleOrderNo = innerData['saleOrderNo']?.toString().trim();
        }
      } catch (e) {
        continue;
      }

      if (saleOrderNo == null || saleOrderNo.isEmpty) {
        continue;
      }

      if (postedOrders.contains(saleOrderNo)) {
        continue;
      }

      bool posted = false;
      try {
        // Post the inner data map
        posted = await postSalesOrder(innerData ?? {});
      } catch (e, st) {
        continue;
      }

      if (posted) {
        // Mark sync in both top-level and inner data
        orderData['sync'] = 'Yes';
        if (innerData != null) {
          innerData['sync'] = 'Yes';
          orderData['data'] = innerData;
        }

        try {
          await HiveManager.salesOrderBox.put(saleOrderNo, orderData);
          postedOrders.add(saleOrderNo);
        } catch (e) {}
      } else {}
    }

    _isSyncing = false;
  }

  Future<bool> postHoldOrder(Map<String, dynamic> order) async {
    try {
      if (!isOnline) {
        queueSync(() => postHoldOrder(order));
        return false;
      }

      const String holdOrderApi = "/fluttertestapi/holdorders/";
      final response = await _dioClient.postRequest(
        path: holdOrderApi,
        data: order,
      );

      return response != null &&
          (response.statusCode == 201 || response.statusCode == 200);
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }
      final navigatorState = MyApp.navigatorKey.currentState;
      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> savePosSaleorderToHive(Map<String, dynamic> invoice) async {
    try {
      var invoiceBox = HiveManager.salesOrderBox;

      invoice['sync'] = 'No';
      invoice['edit'] = 'No';

      await invoiceBox.add(invoice);
    } catch (e, st) {}
  }

  String convertToIsoDate(String inputDate) {
    // input: DD-MM-YYYY
    try {
      final parts = inputDate.split('-');
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final date = DateTime(year, month, day);

      // Return only Date (YYYY-MM-DD)
      return date.toIso8601String().split('T')[0];
    } catch (e) {
      return inputDate; // fallback
    }
  }

  Future<bool> postSalesOrder(Map<String, dynamic> salesOrder) async {
    try {
      // Date conversions
      if (salesOrder["deliveryDate"] != null &&
          salesOrder["deliveryDate"].toString().isNotEmpty) {
        salesOrder["deliveryDate"] = convertToIsoDate(
          salesOrder["deliveryDate"],
        );
      }

      if (salesOrder["eventDate"] != null &&
          salesOrder["eventDate"].toString().isNotEmpty) {
        salesOrder["eventDate"] = convertToIsoDate(salesOrder["eventDate"]);
      }

      // Extract optional file paths
      final String? audioPath = salesOrder['audioPath'];
      final List<String> imagePaths = List<String>.from(
        salesOrder['imagePaths'] ?? [],
      );
      final String customerNumber = salesOrder['customerNumber'];
      final String saleOrderNo = salesOrder['saleOrderNo'];
      final double finalPrice = salesOrder['finalPrice'];

      // POST Sales Order API
      const String salesOrderApi = "/fluttertestapi/salesorders/";
      final response = await _dioClient.postRequest(
        path: salesOrderApi,
        data: salesOrder,
      );

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        final responseData = jsonDecode(response.data);
        final String salesOrderId = responseData['_id'];

        // Audio upload
        if (audioPath != null && audioPath.isNotEmpty) {
          await handleAudioOrder(null, salesOrderId, audioPath);
        }

        // Image upload
        if (imagePaths.isNotEmpty) {
          await handleImageUpload(salesOrderId, imagePaths);
        }

        // SMS & WhatsApp
        if (RegExp(r'^\d{10}$').hasMatch(customerNumber)) {
          String totalAmount = finalPrice.toStringAsFixed(0);

          if (globals.isSOSMSEnabled) {
            String smsApiUrl =
                'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK'
                '&senderid=BMUMMY'
                '&templateid=1707167058380400950'
                '&number=$customerNumber'
                '&message=WELCOME TO BESTMUMMY BILL NO:$saleOrderNo '
                'BILL AMOUNT:$totalAmount THANK YOU FOR VISITING AGAIN';

            await _dioClient.dio.get(smsApiUrl);
          }

          if (globals.isSOWhatsAppEnabled) {
            await sendBillToCustomer(saleOrderNo, salesOrder);
          }
        }

        return true;
      }
      return false;
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }
      final navigatorState = MyApp.navigatorKey.currentState;
      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> sendBillToCustomer(
    String invoiceNo,
    Map<String, dynamic> invoiceData,
  ) async {
    try {
      const String apiPath = '/fluttertestapi/salesorders/api/send-bill';
      final response = await _dioClient.postRequest(
        path: apiPath,
        data: {'invoiceNo': invoiceNo, 'invoiceData': invoiceData},
      );

      if (response != null && response.statusCode == 200) {
        final result = jsonDecode(response.data);
        // Handle successful response
      }
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _postImages(String salesOrderId, List<String> imagePaths) async {
    try {
      var uri = Uri.parse(
        "https://yenerp.com/fluttertestapi/imageOrder/upload_photo",
      );

      var request = http.MultipartRequest('POST', uri);
      request.fields['custom_id'] = salesOrderId;

      for (var path in imagePaths) {
        if (path.isNotEmpty) {
          File imageFile = File(path);
          var imageBytes = await imageFile.readAsBytes();
          var imageMimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

          request.files.add(
            http.MultipartFile.fromBytes(
              'files',
              imageBytes,
              filename: imageFile.path.split('/').last,
              contentType: MediaType.parse(imageMimeType),
            ),
          );
        }
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var responseData = jsonDecode(responseBody);
        if (responseData['uploaded_photos'] != null) {
          for (var photo in responseData['uploaded_photos']) {}
        }
      } else {}
    } catch (e, st) {}
  }

  /// 🔹 WRAPPER FOR IMAGE UPLOAD HANDLING
  Future<void> handleImageUpload(
    String salesOrderId,
    List<String> imagePaths,
  ) async {
    if (imagePaths.isNotEmpty) {
      await _postImages(salesOrderId, imagePaths);
    } else {}
  }

  /// 🔹 HANDLE AUDIO ORDER (NEW UPLOAD OR UPDATE)
  Future<void> handleAudioOrder(
    String? audioOrderId,
    String salesOrderId,
    String? path,
  ) async {
    if (path == null || path.isEmpty) {
      return;
    }

    if (audioOrderId != null) {
      await updateCustomId(audioOrderId, salesOrderId);
    } else {
      await _postAudioFile(salesOrderId, path);
    }
  }

  /// 🔹 UPDATE AUDIO CUSTOM ID
  Future<void> updateCustomId(
    String currentCustomId,
    String newCustomId,
  ) async {
    final url = Uri.parse(
      'https://yenerp.com/fluttertestapi/audios/$currentCustomId/audio',
    );

    try {
      final response = await http.patch(
        url,
        body: {'new_custom_id': newCustomId},
      );

      if (response.statusCode == 200) {
      } else {}
    } catch (e, st) {}
  }

  /// 🔹 UPDATE IMAGE CUSTOM ID (BATCH UPDATE)
  Future<void> updateImageId(String currentCustomId, String newCustomId) async {
    final url = Uri.parse(
      "https://yenerp.com/fluttertestapi/imageOrder/media/batch_update",
    );

    try {
      final body = {
        'current_custom_id': currentCustomId,
        'new_custom_id': newCustomId,
      };

      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
      } else {}
    } catch (e, st) {}
  }

  /// 🔹 POST AUDIO FILE
  Future<void> _postAudioFile(String customId, String filePath) async {
    final uri = Uri.parse(
      'https://yenerp.com/fluttertestapi/audios/upload_audio',
    );

    try {
      String fileExtension = filePath.split('.').last.toLowerCase();
      String contentType = 'audio/$fileExtension';

      final request = http.MultipartRequest('POST', uri);

      var file = await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType.parse(contentType),
      );

      request.files.add(file);

      if (customId.isNotEmpty) {
        request.fields['custom_id'] = customId;
      }

      final response = await request.send();

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
      } else {}
    } catch (e, st) {}
  }

  Future<bool> postInvoiceOrder(Map<String, dynamic> salesOrder) async {
    try {
      // Validate data
      if (!salesOrder.containsKey("data") ||
          salesOrder["data"] == null ||
          salesOrder["data"].isEmpty) {
        return false;
      }

      final Map<String, dynamic> payload = salesOrder["data"][0];
      const String salesOrderApi = "/fluttertestapi/invoices/";

      final response = await _dioClient.postRequest(
        path: salesOrderApi,
        data: payload,
      );

      return response != null &&
          (response.statusCode == 201 || response.statusCode == 200);
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> postModifyOrder(Map<String, dynamic> salesOrder) async {
    try {
      // Date conversions
      if (salesOrder["deliveryDate"] != null &&
          salesOrder["deliveryDate"] != "") {
        salesOrder["deliveryDate"] = convertToIsoDate(
          salesOrder["deliveryDate"],
        );
      }

      if (salesOrder["eventDate"] != null && salesOrder["eventDate"] != "") {
        salesOrder["eventDate"] = convertToIsoDate(salesOrder["eventDate"]);
      }

      const String salesOrderApi = "/fluttertestapi/modifyOrders/";
      final response = await _dioClient.postRequest(
        path: salesOrderApi,
        data: salesOrder,
      );

      return response != null &&
          (response.statusCode == 201 || response.statusCode == 200);
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> postAddNewCustomerOrder({
    required String name,
    required String mobile,
  }) async {
    try {
      if (!isOnline) {
        queueSync(() => postAddNewCustomerOrder(name: name, mobile: mobile));
        return false;
      }

      const String endpoint = '/fluttertestapi/customers/';
      final body = {'customerName': name, 'customerPhoneNumber': mobile};

      final response = await _dioClient.postRequest(path: endpoint, data: body);

      return response != null &&
          (response.statusCode == 200 || response.statusCode == 201);
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> postSalesApprovalOrder(Map<String, dynamic> order) async {
    try {
      if (!isOnline) {
        queueSync(() => postSalesApprovalOrder(order));
        return false;
      }

      const String salesApprovalOrders = "/fluttertestapi/salesapprovals/";
      final response = await _dioClient.postRequest(
        path: salesApprovalOrders,
        data: order,
      );

      return response != null &&
          (response.statusCode == 201 || response.statusCode == 200);
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> postToApproveOrder(Map<String, dynamic> salesOrder) async {
    try {
      if (!isOnline) {
        queueSync(() => postToApproveOrder(salesOrder));
        return false;
      }

      const String salesOrderApi = "/fluttertestapi/heldorders/";
      final response = await _dioClient.postRequest(
        path: salesOrderApi,
        data: salesOrder,
      );

      return response != null &&
          (response.statusCode == 201 || response.statusCode == 200);
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> postToHoldOrder(Map<String, dynamic> salesOrder) async {
    try {
      if (!isOnline) {
        queueSync(() => postToHoldOrder(salesOrder));
        return false;
      }

      const String salesOrderApi = "/fluttertestapi/heldorders/";
      final response = await _dioClient.postRequest(
        path: salesOrderApi,
        data: salesOrder,
      );

      return response != null &&
          (response.statusCode == 201 || response.statusCode == 200);
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> patchToHoldOrder(
    String holdOrderId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final patchBody = payload['data'] ?? {};
      final String apiPath =
          "/fluttertestapi/heldorders/holdOrder/$holdOrderId";

      final response = await _dioClient.patchRequest(
        path: apiPath,
        data: patchBody,
      );

      return response != null &&
          (response.statusCode == 200 || response.statusCode == 201);
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> postDiscountOrder(Map<String, dynamic> salesOrder) async {
    try {
      // Date conversions
      if (salesOrder.containsKey("deliveryDate") &&
          salesOrder["deliveryDate"] != null &&
          salesOrder["deliveryDate"].toString().isNotEmpty) {
        salesOrder["deliveryDate"] = convertToIsoDate(
          salesOrder["deliveryDate"],
        );
      }

      if (salesOrder.containsKey("eventDate") &&
          salesOrder["eventDate"] != null &&
          salesOrder["eventDate"].toString().isNotEmpty) {
        salesOrder["eventDate"] = convertToIsoDate(salesOrder["eventDate"]);
      }

      const String salesOrderApi = "/fluttertestapi/heldorders/";
      final response = await _dioClient.postRequest(
        path: salesOrderApi,
        data: salesOrder,
      );

      return response != null &&
          (response.statusCode == 200 || response.statusCode == 201);
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> syncPendingPatches() async {
    if (!isOnline) return;

    final box = await Hive.openBox('pendingPatches');
    final patches = box.values.toList();

    for (var patch in patches) {
      try {
        final response = await _dioClient.patchRequest(
          path: "/fluttertestapi/salesorders/${patch['salesOrderId']}/",
          data: patch['data'],
        );

        if (response != null && response.statusCode == 200) {
          await box.delete(patch['salesOrderId']);
        }
      } on DioException catch (e) {
        String errorMessage = 'An error occurred';

        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            errorMessage = 'Request timeout. Please try again.';
            break;
          case DioExceptionType.badResponse:
            errorMessage = 'Server error: ${e.response?.statusCode}';
            break;
          case DioExceptionType.connectionError:
            errorMessage = 'No internet connection';
            break;
          case DioExceptionType.cancel:
            errorMessage = 'Request cancelled';
            break;
          default:
            errorMessage = e.message ?? 'An error occurred';
        }

        if (navigatorState!.context.mounted) {
          ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  // Implement retry logic
                },
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> syncUnsyncedInvoices() async {
    if (_isSyncing) {
      debugPrint("Invoice sync already running – skipping duplicate call");
      return;
    }

    _isSyncing = true;
    debugPrint("STARTING INVOICE SYNC CYCLE");
    debugPrint("Total invoices in Hive: ${HiveManager.invoiceBox.length}");

    try {
      final box = HiveManager.invoiceBox;
      final keysToSync = <dynamic>[];

      debugPrint("Scanning all keys in invoice box...");
      for (final key in box.keys) {
        debugPrint("   → Checking key: $key");

        final data = box.get(key);
        if (data == null) continue;

        Map<String, dynamic> invoiceMap;

        // Hive usually returns Map<dynamic, dynamic>
        if (data is Map) {
          // Convert ANY Map to Map<String, dynamic>
          invoiceMap = data.map((k, v) => MapEntry(k.toString(), v));
          debugPrint(
            "     Converted Map<dynamic, dynamic> → Map<String, dynamic>",
          );
        }
        // Fallback: if someone saved as JSON string
        else if (data is String) {
          try {
            invoiceMap = jsonDecode(data) as Map<String, dynamic>;
            debugPrint("     Decoded from JSON string");
          } catch (e) {
            debugPrint("     Invalid JSON string: $e");
            continue;
          }
        } else {
          debugPrint("     Unexpected type ${data.runtimeType} → skipping");
          continue;
        }

        final syncStatus = invoiceMap['sync']?.toString() ?? 'No';
        final invoiceNo = invoiceMap['invoiceNo'] ?? 'unknown';

        debugPrint("     InvoiceNo: $invoiceNo | sync: '$syncStatus'");

        if (syncStatus == 'No') {
          keysToSync.add(key);
          debugPrint("     Added to sync queue");
        }
      }

      debugPrint("Found ${keysToSync.length} unsynced invoices to sync");

      // ———————— ACTUAL SYNC LOOP ————————
      for (final key in keysToSync) {
        if (!isOnline) {
          debugPrint("Device offline – stopping sync");
          break;
        }

        final raw = box.get(key);
        if (raw == null) continue;

        late Map<String, dynamic> invoice;

        if (raw is Map) {
          invoice = raw.map((k, v) => MapEntry(k.toString(), v));
        } else if (raw is String) {
          invoice = jsonDecode(raw) as Map<String, dynamic>;
        } else {
          continue;
        }

        final invoiceNo = invoice['invoiceNo'] ?? 'unknown';
        debugPrint("Syncing → $invoiceNo");

        final success = await postInvoice(invoice);

        if (success) {
          invoice['sync'] = 'Yes';
          await box.put(key, invoice);
          debugPrint("SUCCESS → $invoiceNo marked as synced");
          final sync = {'action': 'syncInvoice', 'invoiceHiveKey': key};

          sendDataToClients(sync, clients);
          debugPrint("Sent syncInvoice message to clients for key: $key");
        } else {
          debugPrint("FAILED → $invoiceNo (will retry later)");
        }
      }
    } catch (e, st) {
      debugPrint("EXCEPTION: $e\n$st");
    } finally {
      _isSyncing = false;
      debugPrint("INVOICE SYNC CYCLE FINISHED");
    }
  }

  Future<void> syncUnsyncedHoldOrders() async {
    // Prevent multiple syncs at the same time
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;

    try {
      // -------------------- Step 1: Open Hive Box --------------------
      final Box holdOrderBox = await Hive.openBox('holdOrderBox');

      int syncedCount = 0;
      int failedCount = 0;

      // -------------------- Step 2: Loop through all entries --------------------
      for (int i = 0; i < holdOrderBox.length; i++) {
        dynamic holdOrderData = holdOrderBox.getAt(i);

        // Decode JSON string if necessary
        if (holdOrderData is String) {
          try {
            holdOrderData = jsonDecode(holdOrderData);
          } catch (e) {
            continue;
          }
        }

        // Validate data type
        if (holdOrderData is! Map<String, dynamic>) {
          continue;
        }

        // Check sync status
        if (holdOrderData['sync'] == 'Yes') {
          continue;
        }

        // Handle nested data if needed
        final dataToSend = holdOrderData['data'] ?? holdOrderData;

        // -------------------- Step 3: Sync with API --------------------
        try {
          bool success = await postToHoldOrder({
            "data": [dataToSend],
          });

          if (success) {
            holdOrderData['sync'] = 'Yes';

            // Replace the existing record
            await holdOrderBox.putAt(i, holdOrderData);
            syncedCount++;
          } else {
            failedCount++;
            break; // Stop sync if API fails
          }
        } catch (e, st) {
          failedCount++;
        }
      }
    } catch (e, st) {
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> postInvoice(Map<String, dynamic> invoice) async {
    try {
      // Convert payment values safely
      invoice['cash'] = int.tryParse(invoice['cash']?.toString() ?? '') ?? 0;
      invoice['card'] = int.tryParse(invoice['card']?.toString() ?? '') ?? 0;
      invoice['upi'] = int.tryParse(invoice['upi']?.toString() ?? '') ?? 0;

      // Using DioClient for the API call
      final response = await DioClient().postRequest(
        path: invoiceApiUrl, // Make sure this is just the path, not full URL
        data: invoice,
      );

      return response != null &&
          (response.statusCode == 201 || response.statusCode == 200);
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    } catch (e) {
      // Handle any other exceptions
      print('Unexpected error: $e');
      return false;
    }
  }

  Future<bool> patchSalesOrder(
    String saleOrderNo,
    Map<String, dynamic> fullOrderData, {
    String? audioPath,
    List<String>? imagePaths,
  }) async {
    try {
      final Map<String, dynamic> finalPayload = Map<String, dynamic>.from(
        fullOrderData['data'] ?? {},
      );

      // Fix advancePaymentType
      if (finalPayload['advancePaymentType'] != null) {
        finalPayload['advancePaymentType'] =
            (finalPayload['advancePaymentType'] as List)
                .map((x) => (x as List).map((y) => y.toString()).toList())
                .toList();
      }

      // Fix modeWiseAmount
      if (finalPayload['modeWiseAmount'] != null) {
        finalPayload['modeWiseAmount'] =
            (finalPayload['modeWiseAmount'] as List)
                .map(
                  (x) => (x as List).map((y) => (y as num).toDouble()).toList(),
                )
                .toList();
      }

      // Fix advanceAmount
      if (finalPayload['advanceAmount'] != null) {
        finalPayload['advanceAmount'] = (finalPayload['advanceAmount'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
      }

      // Fix customChargeType
      if (finalPayload['customChargeType'] != null) {
        if (finalPayload['customChargeType'] is List) {
          finalPayload['customChargeType'] =
              (finalPayload['customChargeType'] as List)
                  .map((item) => item.toString())
                  .toList();
        } else if (finalPayload['customChargeType'] is String) {
          finalPayload['customChargeType'] = [finalPayload['customChargeType']];
        } else {
          finalPayload['customChargeType'] = [];
        }
      } else {
        finalPayload['customChargeType'] = [];
      }

      // Fix customCharge
      if (finalPayload['customCharge'] != null) {
        if (finalPayload['customCharge'] is List) {
          finalPayload['customCharge'] = (finalPayload['customCharge'] as List)
              .map((item) => item is num ? item.toDouble() : 0.0)
              .toList();
        } else if (finalPayload['customCharge'] is num) {
          finalPayload['customCharge'] = [
            finalPayload['customCharge'].toDouble(),
          ];
        } else {
          finalPayload['customCharge'] = [];
        }
      } else {
        finalPayload['customCharge'] = [];
      }

      // Ensure both lists have same length
      if (finalPayload['customChargeType'].length !=
          finalPayload['customCharge'].length) {
        int minLength =
            finalPayload['customChargeType'].length <
                finalPayload['customCharge'].length
            ? finalPayload['customChargeType'].length
            : finalPayload['customCharge'].length;

        if (minLength > 0) {
          finalPayload['customChargeType'] = finalPayload['customChargeType']
              .sublist(0, minLength);
          finalPayload['customCharge'] = finalPayload['customCharge'].sublist(
            0,
            minLength,
          );
        }
      }

      // Construct URL
      final String apiPath =
          '/fluttertestapi/salesorders/by-saleorderno/$saleOrderNo';

      final response = await _dioClient.patchRequest(
        path: apiPath,
        data: finalPayload,
      );

      if (response != null && response.statusCode == 200) {
        // ✅ AFTER SUCCESSFUL PATCH, UPLOAD MEDIA FILES
        await _uploadMediaFilesAfterPatch(saleOrderNo, audioPath, imagePaths);
        return true;
      }
      return false;
    } on DioException catch (e) {
      String errorMessage = 'An error occurred';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Request timeout. Please try again.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
          break;
        case DioExceptionType.connectionError:
          errorMessage = 'No internet connection';
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request cancelled';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (navigatorState!.context.mounted) {
        ScaffoldMessenger.of(navigatorState!.context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                // Implement retry logic
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _uploadMediaFilesAfterPatch(
    String salesOrderId,
    String? audioPath,
    List<String>? imagePaths,
  ) async {
    // 1. Upload Audio
    if (audioPath != null && audioPath.isNotEmpty) {
      try {
        await _postAudioFile(salesOrderId, audioPath);
      } catch (e) {}
    } else {}

    // 2. Upload Images
    if (imagePaths != null && imagePaths.isNotEmpty) {
      int successCount = 0;
      int failedCount = 0;

      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        if (imagePath.isNotEmpty) {
          try {
            await _postImageFile(salesOrderId, imagePath);
            successCount++;
          } catch (e) {
            failedCount++;
          }
        }
      }
    } else {}
  }

  Future<void> _postImageFile(String salesOrderId, String imagePath) async {
    final url = Uri.parse('https://yenerp.com/fluttertestapi/images/upload');

    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['custom_id'] = salesOrderId;

      // Add image file
      final imageFile = await http.MultipartFile.fromPath(
        'image_file',
        imagePath,
      );
      request.files.add(imageFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
      } else {
        throw Exception(
          'Image upload failed with status ${response.statusCode}',
        );
      }
    } catch (e, st) {
      rethrow;
    }
  }

  Future fetchSalesOrderFromApi(saleOrderNo) async {}
}

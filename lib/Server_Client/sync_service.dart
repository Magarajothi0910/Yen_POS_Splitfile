import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import 'package:yen_pos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';
import 'package:yen_pos/Server_Client/stockupdateService.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import 'package:yen_pos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Server_Client/stockupdateService.dart';
import 'package:mime/mime.dart';

import 'package:http_parser/http_parser.dart';

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

  // ====== Hive Box Names ======
  static const String salesOrdersBoxName = 'saleOrderBox';
  static const _offlineBoxName = 'pendingInvoices';

  bool _isSyncing = false;
  bool isOnline = false;
  bool _isSync = false;

  final List<Function> syncQueue = [];

  // ====== Constructor ======
  // ====== Constructor ======
  SyncService() {
    _log("🚀 SyncService initialized", "INIT");

    // Start real internet monitor
    _startInternetMonitor();

    if (appType != 'server') {
      return;
    }

    // Only keep WiFi network change detection
    Connectivity().checkConnectivity().then((result) {
      isOnline = result != ConnectivityResult.none;
      _log(
        "Initial connectivity: ${isOnline ? "✅ ONLINE" : "❌ OFFLINE"}",
        "NET",
      );

      if (isOnline) {
        _log("🌐 Device online — starting sync cycle...", "SYNC");

        if (appType != 'server') {
          return;
        }
        if (_isSyncing) {
          _log("⛔ Internet restored — sync already active, skipping", "NET");
          return;
        }
        // _syncAllPendingData();
      } else {
        _log("📴 Device offline — waiting for connection", "NET");
      }
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
          _log("🌐 Internet restored — syncing pending data", "NET");
          if (appType != 'server') {
            return;
          }
          if (_isSyncing) {
            _log("⛔ Internet restored — sync already active, skipping", "NET");
            return;
          }
          if (!_isSync) {
            _syncAllPendingData();
            _isSync = true;
          }
          _isSync = false;
        } else {
          _log("🔴 Internet lost (no internet access)", "NET");
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
        _log("📴 WiFi/Network disconnected — pausing sync", "NET");
      } else {
        _log("📡 WiFi connected — waiting for internet...", "NET");
        // Do NOT sync here — wait for _startInternetMonitor() to detect real internet
      }
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
      _log("⚠️ Already syncing, skipping duplicate trigger", "SYNC");
      return;
    }

    _isSyncing = true;
    _log("🔄 Processing sync queue (${syncQueue.length} tasks)...", "SYNC");

    while (syncQueue.isNotEmpty && isOnline) {
      final task = syncQueue.removeAt(0);
      try {
        _log("➡️ Running sync task (${syncQueue.length} remaining)...", "TASK");
        await task();
        _log("✅ Task completed successfully", "TASK");
      } catch (e, stack) {
        _log("❌ Error in sync task: $e\n$stack", "ERROR");
      }
    }

    _isSyncing = false;
    _log("✅ All queued tasks processed", "SYNC");
  }

  /// Add a task to the queue
  void queueSync(Function syncTask) {
    _log("🧩 New task added to sync queue", "QUEUE");
    syncQueue.add(syncTask);

    if (isOnline) {
      _log("🌐 Online — starting queue processing immediately", "QUEUE");
      processSyncQueue();
    } else {
      _log("📴 Offline — queued task will run later", "QUEUE");
    }
  }

  // Async sync handler outside listen()
  Future<void> _syncAllPendingData() async {
    if (!_isSyncing && isOnline) {
      _log("🌐 Starting full sync cycle", "SYNC");

      await processSyncQueue();
      await syncUnsyncedSaleOrders();
      await syncUnsyncedInvoices();
      await syncUnsyncedHoldOrders();
      await syncPendingPatches();

      _log("✅ Full sync cycle completed", "SYNC");
      _isSync = false;
    }
  }

  // ===== Helper: Logging with tag =====
  void _log(String message, String tag) {
    final now = DateTime.now().toIso8601String();
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
      final response = await http.post(
        Uri.parse(holdOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(order),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
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
    print("postSalesOrder function started");

    const String salesOrderApi =
        "https://yenerp.com/fluttertestapi/salesorders/";
    print("salesOrderApi constant declared: $salesOrderApi");

    try {
      print("try block started");

      /* -----------------------------------------------------------
     * 🔥 DATE CONVERSION
     * ---------------------------------------------------------*/
      print("Starting date conversion");

      if (salesOrder["deliveryDate"] != null &&
          salesOrder["deliveryDate"].toString().isNotEmpty) {
        print(
          "deliveryDate exists and is not empty: ${salesOrder["deliveryDate"]}",
        );

        salesOrder["deliveryDate"] = convertToIsoDate(
          salesOrder["deliveryDate"],
        );
        print("Converted deliveryDate to ISO: ${salesOrder["deliveryDate"]}");
      } else {
        print("deliveryDate is null or empty");
      }

      if (salesOrder["eventDate"] != null &&
          salesOrder["eventDate"].toString().isNotEmpty) {
        print("eventDate exists and is not empty: ${salesOrder["eventDate"]}");

        salesOrder["eventDate"] = convertToIsoDate(salesOrder["eventDate"]);
        print("Converted eventDate to ISO: ${salesOrder["eventDate"]}");
      } else {
        print("eventDate is null or empty");
      }

      /* -----------------------------------------------------------
     * 📁 EXTRACT OPTIONAL FILE PATHS
     * ---------------------------------------------------------*/
      print("Starting extraction of optional file paths");

      final String? audioPath = salesOrder['audioPath'];
      print("Extracted audioPath: $audioPath");

      final List<String> imagePaths = List<String>.from(
        salesOrder['imagePaths'] ?? [],
      );
      print("Extracted imagePaths: $imagePaths, length: ${imagePaths.length}");

      final String customerNumber = salesOrder['customerNumber'];
      print("Extracted customerNumber: $customerNumber");

      final String saleOrderNo = salesOrder['saleOrderNo'];
      print("Extracted saleOrderNo: $saleOrderNo");

      final double finalPrice = salesOrder['finalPrice'];
      print("Extracted finalPrice: $finalPrice");

      /* -----------------------------------------------------------
     * 🌐 POST SALES ORDER API
     * ---------------------------------------------------------*/
      print("Starting POST sales order API call");
      print("URL: $salesOrderApi");
      print("Request body to be sent: ${jsonEncode(salesOrder)}");

      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );
      print("API call completed, status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("API call successful (status 200 or 201)");

        final responseData = jsonDecode(response.body);
        print("Response data decoded: $responseData");

        final String salesOrderId = responseData['_id'];
        print("Extracted salesOrderId: $salesOrderId");

        /* -----------------------------------------------------------
       * 🎙️ AUDIO UPLOAD
       * ---------------------------------------------------------*/
        print("Starting audio upload check");

        if (audioPath != null && audioPath.isNotEmpty) {
          print("audioPath exists and is not empty, calling handleAudioOrder");
          print("audioPath: $audioPath, salesOrderId: $salesOrderId");

          await handleAudioOrder(null, salesOrderId, audioPath);
          print("handleAudioOrder completed");
        } else {
          print("audioPath is null or empty, skipping audio upload");
        }

        /* -----------------------------------------------------------
       * 🖼️ IMAGE UPLOAD
       * ---------------------------------------------------------*/
        print("Starting image upload check");

        if (imagePaths.isNotEmpty) {
          print("imagePaths is not empty, calling handleImageUpload");
          print("Number of images to upload: ${imagePaths.length}");

          await handleImageUpload(salesOrderId, imagePaths);
          print("handleImageUpload completed");
        } else {
          print("imagePaths is empty, skipping image upload");
        }

        /* -----------------------------------------------------------
       * 📲 SMS & WHATSAPP
       * ---------------------------------------------------------*/
        print("Starting SMS & WhatsApp notifications");

        if (RegExp(r'^\d{10}$').hasMatch(customerNumber)) {
          print("customerNumber is a valid 10-digit number: $customerNumber");

          String totalAmount = finalPrice.toStringAsFixed(0);
          print("Formatted totalAmount: $totalAmount");

          if (globals.isSOSMSEnabled) {
            print("SMS is enabled (globals.isSOSMSEnabled: true)");

            String smsApiUrl =
                'https://mailcon.in/vb/apikey.php?apikey=w31prN4CCtJg7XvK'
                '&senderid=BMUMMY'
                '&templateid=1707167058380400950'
                '&number=$customerNumber'
                '&message=WELCOME TO BESTMUMMY BILL NO:$saleOrderNo '
                'BILL AMOUNT:$totalAmount THANK YOU FOR VISITING AGAIN';

            print("SMS API URL constructed: $smsApiUrl");

            var smsResponse = await http.get(Uri.parse(smsApiUrl));
            print("SMS API call completed, status: ${smsResponse.statusCode}");
          } else {
            print("SMS is disabled (globals.isSOSMSEnabled: false)");
          }

          if (globals.isSOWhatsAppEnabled) {
            print("WhatsApp is enabled (globals.isSOWhatsAppEnabled: true)");

            await sendBillToCustomer(saleOrderNo, salesOrder);
            print("sendBillToCustomer completed");
          } else {
            print("WhatsApp is disabled (globals.isSOWhatsAppEnabled: false)");
          }
        } else {
          print(
            "customerNumber is not a valid 10-digit number: $customerNumber",
          );
          print("Skipping SMS & WhatsApp notifications");
        }

        print("Returning true (success)");
        return true;
      } else {
        print("API call failed with status code: ${response.statusCode}");
        print("Returning false (failure)");
        return false;
      }
    } catch (e, st) {
      print("Exception caught in postSalesOrder");
      print("Error: $e");
      print("Stack trace: $st");
      print("Returning false due to exception");
      return false;
    }
  }

  Future<void> sendBillToCustomer(
    String invoiceNo,
    Map<String, dynamic> invoiceData,
  ) async {
    final response = await http.post(
      Uri.parse('https://yenerp.com/fluttertestapi/salesorders/api/send-bill'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'invoiceNo': invoiceNo, 'invoiceData': invoiceData}),
    );
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
    } else {}
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
    const String salesOrderApi = "https://yenerp.com/fluttertestapi/invoices/";

    print("📤 postInvoiceOrder() CALLED");
    print("➡️ API URL: $salesOrderApi");

    try {
      // 🔹 Validate data
      if (!salesOrder.containsKey("data") ||
          salesOrder["data"] == null ||
          salesOrder["data"].isEmpty) {
        print("❌ ERROR: salesOrder['data'] is null or empty");
        return false;
      }

      final Map<String, dynamic> payload = salesOrder["data"][0];

      print("📦 PAYLOAD TO SEND:");
      print(const JsonEncoder.withIndent('  ').convert(payload));

      // 🔹 Send request
      print("🚀 Sending POST request...");
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // 🔹 Response info
      print("📥 RESPONSE RECEIVED");
      print("🔢 Status Code: ${response.statusCode}");
      print("📄 Response Body: ${response.body}");

      // 🔹 Success handling
      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ Invoice posted successfully");
        // syncUnsyncedInvoices();
        return true;
      } else {
        print("❌ Failed to post invoice");
        return false;
      }
    } catch (e, stackTrace) {
      print("🔥 EXCEPTION OCCURRED");
      print("❗ Error: $e");
      print("📌 StackTrace:");
      print(stackTrace);
      return false;
    }
  }

  Future<bool> postModifyOrder(Map<String, dynamic> salesOrder) async {
    final String salesOrderApi =
        "https://yenerp.com/fluttertestapi/modifyOrders/";
    if (salesOrder["deliveryDate"] != null &&
        salesOrder["deliveryDate"] != "") {
      salesOrder["deliveryDate"] = convertToIsoDate(salesOrder["deliveryDate"]);
    }

    if (salesOrder["eventDate"] != null && salesOrder["eventDate"] != "") {
      salesOrder["eventDate"] = convertToIsoDate(salesOrder["eventDate"]);
    }

    try {
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e, stacktrace) {
      return false;
    }
  }

  Future<bool> postAddNewCustomerOrder({
    required String name,
    required String mobile,
  }) async {
    const String endpoint = 'https://yenerp.com/fluttertestapi/customers/';

    final body = {'customerName': name, 'customerPhoneNumber': mobile};

    try {
      // ────────────────────────────────
      // Check Online Status
      // ────────────────────────────────
      if (!isOnline) {
        queueSync(() => postAddNewCustomerOrder(name: name, mobile: mobile));

        return false;
      }

      // ────────────────────────────────
      // API POST Request
      // ────────────────────────────────
      final res = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      // ────────────────────────────────
      // Check Response
      // ────────────────────────────────
      final bool success = res.statusCode == 200 || res.statusCode == 201;

      if (success) {
      } else {}

      return success;
    } catch (e, stacktrace) {
      return false;
    }
  }

  Future<bool> postSalesApprovalOrder(Map<String, dynamic> order) async {
    try {
      if (!isOnline) {
        queueSync(() => postSalesApprovalOrder(order));
        return false;
      }
      final response = await http.post(
        Uri.parse(salesApprovalOrders),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(order),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> postToApproveOrder(Map<String, dynamic> salesOrder) async {
    final String salesOrderApi =
        "https://yenerp.com/fluttertestapi/heldorders/";
    // Print the payload and URL for debugging

    try {
      if (!isOnline) {
        queueSync(() => postToApproveOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      // Debug response details

      if (response.statusCode == 201 || response.statusCode == 200) {
        // patchSaleOrder(salesOrder, response.body);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> postToHoldOrder(Map<String, dynamic> salesOrder) async {
    final String salesOrderApi =
        "https://yenerp.com/fluttertestapi/heldorders/";

    try {
      // 🧩 Step 1: Check internet connectivity
      if (!isOnline) {
        queueSync(() => postToHoldOrder(salesOrder));
        return false;
      }

      // 📨 Step 2: Send POST request
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      // 🧮 Step 3: Check response code
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e, st) {
      return false;
    }
  }

  Future<bool> patchToHoldOrder(
    String holdOrderId,
    Map<String, dynamic> payload,
  ) async {
    final String baseUrl =
        "https://yenerp.com/fluttertestapi/heldorders/holdOrder/";

    try {
      // Extract real payload
      final patchBody = payload['data'] ?? {};

      final String finalUrl = "$baseUrl$holdOrderId";

      final response = await http.patch(
        Uri.parse(finalUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(patchBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e, st) {
      return false;
    }
  }

  Future<bool> postDiscountOrder(Map<String, dynamic> salesOrder) async {
    final String salesOrderApi =
        "https://yenerp.com/fluttertestapi/heldorders/";

    try {
      // -------------------------------------------------
      // BEFORE DATE CONVERSION
      // -------------------------------------------------

      // -------------------------------------------------
      // DELIVERY DATE CONVERSION
      // -------------------------------------------------
      if (salesOrder.containsKey("deliveryDate")) {
        if (salesOrder["deliveryDate"] != null &&
            salesOrder["deliveryDate"].toString().isNotEmpty) {
          salesOrder["deliveryDate"] = convertToIsoDate(
            salesOrder["deliveryDate"],
          );
        } else {}
      } else {}

      // -------------------------------------------------
      // EVENT DATE CONVERSION
      // -------------------------------------------------
      if (salesOrder.containsKey("eventDate")) {
        if (salesOrder["eventDate"] != null &&
            salesOrder["eventDate"].toString().isNotEmpty) {
          salesOrder["eventDate"] = convertToIsoDate(salesOrder["eventDate"]);
        } else {}
      } else {}

      // -------------------------------------------------
      // FINAL PAYLOAD BEFORE API CALL
      // -------------------------------------------------

      // -------------------------------------------------
      // HTTP POST REQUEST
      // -------------------------------------------------
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      // -------------------------------------------------
      // RESPONSE DETAILS
      // -------------------------------------------------

      // -------------------------------------------------
      // SUCCESS / FAILURE HANDLING
      // -------------------------------------------------
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e, stackTrace) {
      // -------------------------------------------------
      // EXCEPTION HANDLING
      // -------------------------------------------------
      return false;
    }
  }

  Future<void> syncPendingPatches() async {
    if (!isOnline) return;

    final box = await Hive.openBox('pendingPatches');
    final patches = box.values.toList();

    for (var patch in patches) {
      try {
        final response = await http.patch(
          Uri.parse(
            "https://yenerp.com/fluttertestapi/salesorders/${patch['salesOrderId']}/",
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(patch['data']),
        );

        if (response.statusCode == 200) {
          await box.delete(patch['salesOrderId']);
        }
      } catch (e) {}
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
    debugPrint("unknown invoice ");
    try {
      // Convert payment values safely
      invoice['cash'] = int.tryParse(invoice['cash']?.toString() ?? '') ?? 0;
      invoice['card'] = int.tryParse(invoice['card']?.toString() ?? '') ?? 0;
      invoice['upi'] = int.tryParse(invoice['upi']?.toString() ?? '') ?? 0;

      final response = await http.post(
        Uri.parse(invoiceApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(invoice),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /* ───────── Helper: append unsent invoice to Hive list ───────── */
  Future<void> _stashOffline(Map<String, dynamic> inv) async {
    final box = await Hive.openBox<List>(_offlineBoxName);
    final pending = List<Map<String, dynamic>>.from(box.get('list') ?? []);
    pending.add(inv);
    await box.put('list', pending);
  }

  Future<bool> patchSalesOrder(
    String saleOrderNo,
    Map<String, dynamic> fullOrderData, {
    String? audioPath,
    List<String>? imagePaths,
  }) async {
    print("☁️ Preparing to PATCH sale order to server...");
    print("📋 Server target order: $saleOrderNo");

    final Map<String, dynamic> finalPayload = Map<String, dynamic>.from(
      fullOrderData['data'] ?? {},
    );

    print("📦 Payload before type fixes: ${finalPayload.length} fields");

    // Fix advancePaymentType
    if (finalPayload['advancePaymentType'] != null) {
      print("🛠️ Fixing advancePaymentType format...");
      finalPayload['advancePaymentType'] =
          (finalPayload['advancePaymentType'] as List)
              .map((x) => (x as List).map((y) => y.toString()).toList())
              .toList();
      print("✅ advancePaymentType format fixed");
    }

    // Fix modeWiseAmount
    if (finalPayload['modeWiseAmount'] != null) {
      print("🛠️ Fixing modeWiseAmount format...");
      finalPayload['modeWiseAmount'] = (finalPayload['modeWiseAmount'] as List)
          .map((x) => (x as List).map((y) => (y as num).toDouble()).toList())
          .toList();
      print("✅ modeWiseAmount format fixed");
    }

    // Fix advanceAmount
    if (finalPayload['advanceAmount'] != null) {
      print("🛠️ Fixing advanceAmount format...");
      finalPayload['advanceAmount'] = (finalPayload['advanceAmount'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      print("✅ advanceAmount format fixed");
    }

    // Fix customChargeType - SERVER EXPECTS LIST
    if (finalPayload['customChargeType'] != null) {
      print("🛠️ Fixing customChargeType format...");
      if (finalPayload['customChargeType'] is List) {
        // Already a list - convert all items to string
        finalPayload['customChargeType'] =
            (finalPayload['customChargeType'] as List)
                .map((item) => item.toString())
                .toList();
        print(
          "✅ customChargeType is already a list, converted items to string",
        );
      } else if (finalPayload['customChargeType'] is String) {
        // Convert single string to list with one item
        finalPayload['customChargeType'] = [finalPayload['customChargeType']];
        print("✅ Converted string to list with one item");
      } else {
        // Empty or null - set to empty list
        finalPayload['customChargeType'] = [];
        print("⚠️ customChargeType was empty/null, set to empty list");
      }
    } else {
      // Field doesn't exist or is null - set to empty list
      finalPayload['customChargeType'] = [];
      print("⚠️ customChargeType was null, set to empty list");
    }

    // Fix customCharge - SERVER EXPECTS LIST
    if (finalPayload['customCharge'] != null) {
      print("🛠️ Fixing customCharge format...");
      if (finalPayload['customCharge'] is List) {
        // Already a list - convert all items to double
        finalPayload['customCharge'] = (finalPayload['customCharge'] as List)
            .map((item) => item is num ? item.toDouble() : 0.0)
            .toList();
        print("✅ customCharge is already a list, converted items to double");
      } else if (finalPayload['customCharge'] is num) {
        // Convert single number to list with one item
        finalPayload['customCharge'] = [
          finalPayload['customCharge'].toDouble(),
        ];
        print("✅ Converted single number to list with one item");
      } else {
        // Empty or null - set to empty list
        finalPayload['customCharge'] = [];
        print("⚠️ customCharge was empty/null, set to empty list");
      }
    } else {
      // Field doesn't exist or is null - set to empty list
      finalPayload['customCharge'] = [];
      print("⚠️ customCharge was null, set to empty list");
    }

    // Log the fixed values for debugging
    print("📊 Fixed customChargeType: ${finalPayload['customChargeType']}");
    print("📊 Fixed customCharge: ${finalPayload['customCharge']}");

    // Ensure both lists have same length
    if (finalPayload['customChargeType'].length !=
        finalPayload['customCharge'].length) {
      print(
        "⚠️ WARNING: customChargeType and customCharge lists have different lengths!",
      );
      print(
        "   customChargeType length: ${finalPayload['customChargeType'].length}",
      );
      print("   customCharge length: ${finalPayload['customCharge'].length}");

      // Trim the longer list to match the shorter one
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
        print("✅ Trimmed lists to match length: $minLength");
      }
    }

    print("📦 Payload after type fixes ready for transmission");
    print("📋 Final payload structure:");
    finalPayload.forEach((key, value) {
      print("   • $key: ${value.runtimeType} = $value");
    });

    // Construct URL
    final url = Uri.parse(
      'https://yenerp.com/fluttertestapi/salesorders/by-saleorderno/$saleOrderNo',
    );
    print("🌐 Server URL: $url");

    bool patchSuccess = false;

    try {
      print("📤 Sending PATCH request to server...");
      print("📄 Payload being sent (all fields):");
      finalPayload.forEach((key, value) {
        print("   • $key: $value (${value.runtimeType})");
      });

      // Convert to JSON and print for debugging
      final jsonPayload = jsonEncode(finalPayload);
      print("📄 JSON Payload to send:");
      print(jsonPayload);

      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonPayload,
      );

      print("📥 Server response received");
      print("   Status Code: ${response.statusCode}");
      print("   Response body: ${response.body}");

      if (response.statusCode == 200) {
        print("✅ Server PATCH successful for order: $saleOrderNo");
        patchSuccess = true;

        // ✅ AFTER SUCCESSFUL PATCH, UPLOAD MEDIA FILES
        await _uploadMediaFilesAfterPatch(saleOrderNo, audioPath, imagePaths);
      } else {
        print("❌ Server PATCH failed with status: ${response.statusCode}");

        // Parse and display error details
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['detail'] is List) {
            print("📋 Error details:");
            for (var error in errorData['detail']) {
              print("   • ${error['loc']}: ${error['msg']}");
            }
          }
        } catch (_) {
          print("   Raw response: ${response.body}");
        }
        patchSuccess = false;
      }
    } catch (e, st) {
      print("🚨 NETWORK ERROR during server PATCH:");
      print("   Exception: $e");
      print("   Stack trace: $st");
      patchSuccess = false;
    } finally {
      print("🏁 Server PATCH operation completed for: $saleOrderNo");
      return patchSuccess;
    }
  }

  Future<void> _uploadMediaFilesAfterPatch(
    String salesOrderId,
    String? audioPath,
    List<String>? imagePaths,
  ) async {
    print("🎵 Starting media upload for order: $salesOrderId");

    // 1. Upload Audio
    if (audioPath != null && audioPath.isNotEmpty) {
      print("🔊 Uploading audio file: $audioPath");
      try {
        await _postAudioFile(salesOrderId, audioPath);
        print("✅ Audio uploaded successfully");
      } catch (e) {
        print("❌ Audio upload failed: $e");
      }
    } else {
      print("🔇 No audio file to upload");
    }

    // 2. Upload Images
    if (imagePaths != null && imagePaths.isNotEmpty) {
      print("🖼️ Uploading ${imagePaths.length} image(s)");
      int successCount = 0;
      int failedCount = 0;

      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        if (imagePath.isNotEmpty) {
          print("  📸 Uploading image ${i + 1}: $imagePath");
          try {
            await _postImageFile(salesOrderId, imagePath);
            successCount++;
            print("  ✅ Image ${i + 1} uploaded");
          } catch (e) {
            failedCount++;
            print("  ❌ Image ${i + 1} upload failed: $e");
          }
        }
      }
      print(
        "📊 Image upload summary: $successCount successful, $failedCount failed",
      );
    } else {
      print("🖼️ No images to upload");
    }

    print("🎬 Media upload completed for order: $salesOrderId");
  }

  Future<void> _postImageFile(String salesOrderId, String imagePath) async {
    print("🖼️ Starting image upload for order: $salesOrderId");

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

      print("📤 Sending image file to server...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("📥 Image upload response: ${response.statusCode}");

      if (response.statusCode == 200) {
        print("🖼️ Image uploaded successfully to server");
        final responseData = jsonDecode(response.body);
        print("📝 Image upload response: $responseData");
      } else {
        print("❌ Image upload failed with status: ${response.statusCode}");
        print("   Error response: ${response.body}");
        throw Exception(
          'Image upload failed with status ${response.statusCode}',
        );
      }
    } catch (e, st) {
      print("🚨 Error during image upload:");
      print("   Exception: $e");
      print("   Stack trace: $st");
      rethrow;
    }
  }

  Future fetchSalesOrderFromApi(saleOrderNo) async {}
}

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
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart';
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

  final List<Function> syncQueue = [];

  // ====== Constructor ======
  SyncService() {
    _log("🚀 SyncService initialized", "INIT");

    monitorConnectivity();

    Connectivity().checkConnectivity().then((result) {
      isOnline = result != ConnectivityResult.none;
      _log(
        "Initial connectivity: ${isOnline ? "✅ ONLINE" : "❌ OFFLINE"}",
        "NET",
      );

      if (isOnline) {
        _log("🌐 Device online — starting sync cycle...", "SYNC");
        processSyncQueue();
        syncUnsyncedSaleOrders();
        syncUnsyncedInvoices();
        syncUnsyncedHoldOrders();
        syncPendingPatches();
      } else {
        _log("📴 Device offline — will wait for reconnection", "NET");
      }
    });
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

  /// Monitor network connectivity
  void monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final ConnectivityResult result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;

      final wasOnline = isOnline;
      isOnline = result != ConnectivityResult.none;

      if (isOnline && !wasOnline) {
        _log("📶 Network reconnected — syncing pending tasks", "NET");

        // Trigger async sync handler
        _syncAllPendingData();
      } else if (!isOnline && wasOnline) {
        _log("🔌 Network disconnected — pausing sync operations", "NET");
      }
    });
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
    }
  }

  // ===== Helper: Logging with tag =====
  void _log(String message, String tag) {
    final now = DateTime.now().toIso8601String();
    print("[$now] [$tag] $message");
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
      print('[SYNC] Already syncing. Exiting.');
      return;
    }

    _isSyncing = true;
    print('[SYNC] Starting unsynced sales orders sync...');

    var orderBox = HiveManager.salesOrderBox;
    print('[SYNC] Total orders in Hive: ${orderBox.length}');

    // Keep track of saleOrderNos that are already posted in this run
    Set<String> postedOrders = {};

    for (int i = 0; i < orderBox.length; i++) {
      dynamic orderData = orderBox.getAt(i);
      print('\n[SYNC] Processing order index: $i');

      // Print type and raw value from Hive
      print('[SYNC] Hive raw value type: ${orderData.runtimeType}');
      print('[SYNC] Hive raw value: $orderData');

      // Decode if stored as JSON String
      if (orderData is String) {
        try {
          orderData = jsonDecode(orderData);
          print('[SYNC] Order data decoded from string: $orderData');
          print('[SYNC] Decoded type: ${orderData.runtimeType}');
        } catch (e) {
          print('[SYNC][ERROR] Failed to decode order at index $i: $e');
          continue;
        }
      }

      // Ensure orderData is Map<String, dynamic>
      if (orderData is Map) {
        try {
          orderData = Map<String, dynamic>.from(orderData);
          print('[SYNC] Converted orderData to Map<String, dynamic>');
          print('[SYNC] Order keys: ${orderData.keys.toList()}');
        } catch (e) {
          print(
            '[SYNC][WARN] Failed to convert orderData to Map<String, dynamic> at index $i: $e',
          );
          continue;
        }
      } else {
        print('[SYNC][WARN] Order data is not a Map after decoding, skipping.');
        continue;
      }

      // Skip already synced orders
      if (orderData['sync'] != 'No') {
        print(
          '[SYNC] Order already synced: ${orderData['data']?['saleOrderNo'] ?? 'Unknown'}',
        );
        continue;
      }

      // Extract saleOrderNo from nested data map
      String? saleOrderNo;
      Map<String, dynamic>? innerData;
      try {
        if (orderData['data'] != null && orderData['data'] is Map) {
          innerData = Map<String, dynamic>.from(orderData['data']);
          saleOrderNo = innerData['saleOrderNo']?.toString().trim();
          print('[SYNC] Extracted saleOrderNo from data: "$saleOrderNo"');
        }
      } catch (e) {
        print(
          '[SYNC][ERROR] Failed to extract saleOrderNo from nested data at index $i: $e',
        );
        continue;
      }

      if (saleOrderNo == null || saleOrderNo.isEmpty) {
        print(
          '[SYNC][WARN] Missing or empty saleOrderNo for order at index $i, skipping.',
        );
        continue;
      }

      if (postedOrders.contains(saleOrderNo)) {
        print(
          '[SYNC] SaleOrderNo $saleOrderNo already posted in this run, skipping.',
        );
        continue;
      }

      print('[SYNC] Posting SaleOrderNo: $saleOrderNo');

      bool posted = false;
      try {
        // Post the inner data map
        posted = await postSalesOrder(innerData ?? {});
        print('[SYNC] SaleOrderNo $saleOrderNo post result: $posted');
      } catch (e, st) {
        print('[SYNC][ERROR] Failed to post SaleOrderNo $saleOrderNo: $e');
        print(st);
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
          print('[SYNC] SaleOrderNo $saleOrderNo marked as synced in Hive.');
          postedOrders.add(saleOrderNo);
        } catch (e) {
          print(
            '[SYNC][ERROR] Failed to update Hive for SaleOrderNo $saleOrderNo: $e',
          );
        }
      } else {
        print(
          '[SYNC][WARN] SaleOrderNo $saleOrderNo not posted. Will retry later.',
        );
      }
    }

    print('[SYNC] Unsynced sales orders sync completed.');
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
      print("❌ Date conversion failed: $inputDate");
      return inputDate; // fallback
    }
  }

  Future<bool> postSalesOrder(Map<String, dynamic> salesOrder) async {
    print("post time sale order: $salesOrder");
    const String salesOrderApi =
        "http://192.168.29.78:8888/fluttertestapi/salesorders/";
    // 🔥 Convert dates to ISO before encoding
    if (salesOrder["deliveryDate"] != null &&
        salesOrder["deliveryDate"] != "") {
      salesOrder["deliveryDate"] = convertToIsoDate(salesOrder["deliveryDate"]);
    }

    if (salesOrder["eventDate"] != null && salesOrder["eventDate"] != "") {
      salesOrder["eventDate"] = convertToIsoDate(salesOrder["eventDate"]);
    }

    print("➡️ Final request map: $salesOrder");
    try {
      // ✅ Extract paths safely
      final String? audioPath = salesOrder['audioPath'];
      final String? imagePath1 = salesOrder['imagePath1'];
      final String? imagePath2 = salesOrder['imagePath2'];

      // ✅ Post the sales order
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );
      print("status code : ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // ✅ Extract only the _id from response
        final String salesOrderId = responseData['_id'];
        print("✅ Sales Order ID: $salesOrderId");

        // Upload audio if available
        if (audioPath != null && audioPath.isNotEmpty) {
          await handleAudioOrder(null, salesOrderId, audioPath);
        }

        // Convert paths to File before uploading
        File? img1 = (imagePath1 != null && imagePath1.isNotEmpty)
            ? File(imagePath1)
            : null;
        File? img2 = (imagePath2 != null && imagePath2.isNotEmpty)
            ? File(imagePath2)
            : null;

        // Upload images if available
        if (img1 != null || img2 != null) {
          await handleImageUpload(salesOrderId, img1, img2);
        }

        return true;
      } else {
        print("❌ Sales order post failed. Status: ${response.statusCode}");
        return false;
      }
    } catch (e, st) {
      print("⚠️ Error in postSalesOrder: $e\n$st");
      return false;
    }
  }

  Future<void> _postImages(
    String salesOrderId,
    File? pickedImage1,
    File? pickedImage2,
  ) async {
    print("\n🟦 [IMAGE UPLOAD] --- START ---");
    print("📦 Sales Order ID: $salesOrderId");

    try {
      var uri = Uri.parse(
        "https://yenerp.com/fluttertestapi/imageOrder/upload_photo",
      );
      print("🌐 Upload Endpoint: $uri");

      var request = http.MultipartRequest('POST', uri);
      request.fields['custom_id'] = salesOrderId;
      print("🧾 Added field -> custom_id: $salesOrderId");

      // -------------------- IMAGE 1 --------------------
      if (pickedImage1 != null) {
        print("\n🖼️ Preparing Image 1: ${pickedImage1.path}");
        var image1Bytes = await pickedImage1.readAsBytes();
        var image1MimeType = lookupMimeType(pickedImage1.path) ?? 'image/jpeg';
        print("📄 Detected MIME Type (Image 1): $image1MimeType");
        print("📦 Image 1 Size: ${image1Bytes.lengthInBytes} bytes");

        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            image1Bytes,
            filename: pickedImage1.path.split('/').last,
            contentType: MediaType.parse(image1MimeType),
          ),
        );
        print("✅ Image 1 added to request");
      } else {
        print("⚠️ No Image 1 selected");
      }

      // -------------------- IMAGE 2 --------------------
      if (pickedImage2 != null) {
        print("\n🖼️ Preparing Image 2: ${pickedImage2.path}");
        var image2Bytes = await pickedImage2.readAsBytes();
        var image2MimeType = lookupMimeType(pickedImage2.path) ?? 'image/jpeg';
        print("📄 Detected MIME Type (Image 2): $image2MimeType");
        print("📦 Image 2 Size: ${image2Bytes.lengthInBytes} bytes");

        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            image2Bytes,
            filename: pickedImage2.path.split('/').last,
            contentType: MediaType.parse(image2MimeType),
          ),
        );
        print("✅ Image 2 added to request");
      } else {
        print("⚠️ No Image 2 selected");
      }

      // -------------------- SEND REQUEST --------------------
      print("\n🚀 Sending image upload request...");
      var response = await request.send();
      print("📡 Response Status Code: ${response.statusCode}");

      var responseBody = await response.stream.bytesToString();
      print("📩 Raw Server Response: $responseBody");

      if (response.statusCode == 200) {
        var responseData = jsonDecode(responseBody);
        print("✅ Upload Success: ${responseData}");

        if (responseData['uploaded_photos'] != null) {
          print("🖼️ Uploaded Photos:");
          for (var photo in responseData['uploaded_photos']) {
            print("   → ${photo['photo_url']}");
          }
        }
      } else {
        print("❌ Image upload failed: ${response.statusCode}");
        print("🔍 Headers: ${response.headers}");
      }
    } catch (e, st) {
      print("💥 Error while posting images: $e");
      print("🔍 Stacktrace:\n$st");
    }

    print("🟩 [IMAGE UPLOAD] --- END ---\n");
  }

  /// 🔹 WRAPPER FOR IMAGE UPLOAD HANDLING
  Future<void> handleImageUpload(
    String salesOrderId,
    File? img1,
    File? img2,
  ) async {
    print("\n🟦 [HANDLE IMAGE UPLOAD]");
    print("📦 SalesOrderID: $salesOrderId");
    print("🖼️ Image1: ${img1?.path}");
    print("🖼️ Image2: ${img2?.path}");

    if (img1 != null || img2 != null) {
      await _postImages(salesOrderId, img1, img2);
    } else {
      print("⚠️ No images selected. Skipping upload.");
    }
  }

  /// 🔹 HANDLE AUDIO ORDER (NEW UPLOAD OR UPDATE)
  Future<void> handleAudioOrder(
    String? audioOrderId,
    String salesOrderId,
    String? path,
  ) async {
    print("\n🟦 [HANDLE AUDIO ORDER]");
    print("🎧 Audio Path: $path");
    print("🆔 Audio Order ID: $audioOrderId");
    print("🧾 Sales Order ID: $salesOrderId");

    if (path == null || path.isEmpty) {
      print("⚠️ No audio file path found, skipping upload.");
      return;
    }

    if (audioOrderId != null) {
      print("🔄 Updating existing audio custom ID...");
      await updateCustomId(audioOrderId, salesOrderId);
    } else {
      print("🆕 Uploading new audio file...");
      await _postAudioFile(salesOrderId, path);
    }
  }

  /// 🔹 UPDATE AUDIO CUSTOM ID
  Future<void> updateCustomId(
    String currentCustomId,
    String newCustomId,
  ) async {
    print("\n🟦 [UPDATE AUDIO CUSTOM ID]");
    print("🆔 Current ID: $currentCustomId");
    print("🆕 New ID: $newCustomId");

    final url = Uri.parse(
      'https://yenerp.com/fluttertestapi/audios/$currentCustomId/audio',
    );

    try {
      final response = await http.patch(
        url,
        body: {'new_custom_id': newCustomId},
      );
      print("📡 PATCH Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        print("✅ Custom ID updated successfully!");
      } else {
        print("❌ Failed to update Custom ID: ${response.statusCode}");
        print("🧾 Response: ${response.body}");
      }
    } catch (e, st) {
      print("💥 Error while updating audio custom ID: $e");
      print("🔍 Stacktrace:\n$st");
    }
  }

  /// 🔹 UPDATE IMAGE CUSTOM ID (BATCH UPDATE)
  Future<void> updateImageId(String currentCustomId, String newCustomId) async {
    print("\n🟦 [UPDATE IMAGE CUSTOM ID]");
    print("🆔 Current ID: $currentCustomId");
    print("🆕 New ID: $newCustomId");

    final url = Uri.parse(
      "https://yenerp.com/fluttertestapi/imageOrder/media/batch_update",
    );

    try {
      final body = {
        'current_custom_id': currentCustomId,
        'new_custom_id': newCustomId,
      };
      print("📦 Request Body: $body");

      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      print("📡 Response Code: ${response.statusCode}");
      print("📩 Raw Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("✅ Batch update successful: $data");
      } else {
        print("❌ Failed to update image custom ID: ${response.statusCode}");
      }
    } catch (e, st) {
      print("💥 Error while updating image ID: $e");
      print("🔍 Stacktrace:\n$st");
    }
  }

  /// 🔹 POST AUDIO FILE
  Future<void> _postAudioFile(String customId, String filePath) async {
    print("\n🟦 [AUDIO UPLOAD] --- START ---");
    print("📦 custom_id: $customId");
    print("🎧 File Path: $filePath");

    final uri = Uri.parse(
      'https://yenerp.com/fluttertestapi/audios/upload_audio',
    );
    print("🌐 Upload Endpoint: $uri");

    try {
      String fileExtension = filePath.split('.').last.toLowerCase();
      String contentType = 'audio/$fileExtension';
      print("📄 MIME Type: $contentType");

      final request = http.MultipartRequest('POST', uri);

      var file = await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType.parse(contentType),
      );

      request.files.add(file);
      print("✅ Audio file added: ${file.filename}");

      if (customId.isNotEmpty) {
        request.fields['custom_id'] = customId;
        print("🧾 Added form field -> custom_id: $customId");
      }

      print("🚀 Sending audio upload request...");
      final response = await request.send();

      final responseBody = await response.stream.bytesToString();
      print("📡 Response Code: ${response.statusCode}");
      print("📩 Raw Response: $responseBody");

      if (response.statusCode == 200) {
        print("✅ Audio uploaded successfully!");
      } else {
        print("❌ Audio upload failed: ${response.statusCode}");
      }
    } catch (e, st) {
      print("💥 Error while uploading audio: $e");
      print("🔍 Stacktrace:\n$st");
    }

    print("🟩 [AUDIO UPLOAD] --- END ---\n");
  }

  Future<bool> postInvoiceOrder(Map<String, dynamic> salesOrder) async {
    const String salesOrderApi = "https://yenerp.com/fluttertestapi/invoices/";

    try {
      print("🔄 Posting Invoice Order...");
      print("📌 API URL: $salesOrderApi");
      print("📝 Request Body: ${jsonEncode(salesOrder)}");

      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      print("📥 Response Status: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ Invoice posted successfully!");
        return true;
      } else {
        print("❌ Failed to post invoice! Status: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("🔥 Error posting invoice: $e");
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

    print("➡️ Final request map: $salesOrder");
    print("📤 Preparing to send POST request to: $salesOrderApi");
    print("📦 Payload: ${jsonEncode(salesOrder)}");

    try {
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      print("📥 Response received!");
      print("🔹 Status Code: ${response.statusCode}");
      print("🔹 Response Body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ Order modification successful.");
        return true;
      } else {
        print("❌ Order modification failed.");
        return false;
      }
    } catch (e, stacktrace) {
      print("⚠️ Exception occurred while sending request:");
      print("Error: $e");
      print("Stacktrace: $stacktrace");
      return false;
    }
  }

  Future<bool> postAddNewCustomerOrder({
    required String name,
    required String mobile,
  }) async {
    const String endpoint = 'https://yenerp.com/fluttertestapi/customers/';

    print("==============================================");
    print("🔵 postAddNewCustomerOrder() CALLED");
    print("Endpoint → $endpoint");
    print("Input Data:");
    print("  → Name      : $name");
    print("  → Mobile    : $mobile");

    print("==============================================");

    final body = {'customerName': name, 'customerPhoneNumber': mobile};

    print("📦 Request Body: $body");

    try {
      // ────────────────────────────────
      // Check Online Status
      // ────────────────────────────────
      print("Checking internet connectivity...");
      if (!isOnline) {
        print("⚠ NO INTERNET → Adding to Queue for later sync.");

        queueSync(() => postAddNewCustomerOrder(name: name, mobile: mobile));

        print("✔ Task queued successfully.");
        return false;
      }

      print("✔ Internet Available → Sending API request...");

      // ────────────────────────────────
      // API POST Request
      // ────────────────────────────────
      print("📡 Sending POST request...");
      final res = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print("📥 Response Received");
      print("Status Code: ${res.statusCode}");
      print("Response Body: ${res.body}");

      // ────────────────────────────────
      // Check Response
      // ────────────────────────────────
      final bool success = res.statusCode == 200 || res.statusCode == 201;

      if (success) {
        print("✔ Customer successfully added to server.");
      } else {
        print("❌ Failed to add customer. Server returned: ${res.statusCode}");
      }

      print("==============================================");
      print("🔵 postAddNewCustomerOrder() COMPLETED");
      print("==============================================");

      return success;
    } catch (e, stacktrace) {
      print("❌ EXCEPTION in postAddNewCustomerOrder()");
      print("Error: $e");
      print("Stacktrace: $stacktrace");
      print("==============================================");
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

    print("🔵 postToHoldOrder() CALLED");
    print("🌍 URL: $salesOrderApi");
    print("📦 Payload: ${jsonEncode(salesOrder)}");

    try {
      // 🧩 Step 1: Check internet connectivity
      print("🔍 Checking internet connection...");
      if (!isOnline) {
        print("⚠️ Offline detected! Adding request to queue...");
        queueSync(() => postToHoldOrder(salesOrder));
        return false;
      }
      print("✅ Online. Proceeding with POST request.");

      // 📨 Step 2: Send POST request
      print("📡 Sending POST request to server...");
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      print("📥 SERVER RESPONSE RECEIVED");
      print("🔢 Status Code: ${response.statusCode}");
      print("📄 Response Body: ${response.body}");

      // 🧮 Step 3: Check response code
      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ Hold Order posted successfully!");
        return true;
      } else {
        print("❌ Server returned FAILURE status: ${response.statusCode}");
        return false;
      }
    } catch (e, st) {
      print("❌ EXCEPTION in postToHoldOrder(): $e");
      print("📍 STACKTRACE: $st");
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
      print("------------------------------------------------------");
      print("🔵 PATCH → Update Hold Order");
      print("📌 Hold Order ID : $holdOrderId");

      // Extract real payload
      final patchBody = payload['data'] ?? {};

      print("📤 Final Payload Sent to API :");
      print(jsonEncode(patchBody));
      print("------------------------------------------------------");

      final String finalUrl = "$baseUrl$holdOrderId";

      print("🌐 URL Called : $finalUrl");

      final response = await http.patch(
        Uri.parse(finalUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(patchBody),
      );

      print("------------------------------------------------------");
      print("🔵 API Response Details");
      print("📡 Status Code : ${response.statusCode}");
      print("📥 Response Body : ${response.body}");
      print("------------------------------------------------------");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ PATCH Success: Hold order updated.");
        return true;
      } else {
        print("❌ PATCH Failed: Server returned error");
        return false;
      }
    } catch (e, st) {
      print("------------------------------------------------------");
      print("❗ ERROR in patchToHoldOrder()");
      print("📌 Exception : $e");
      print("📌 Stacktrace : $st");
      print("------------------------------------------------------");
      return false;
    }
  }

  Future<bool> postDiscountOrder(Map<String, dynamic> salesOrder) async {
    final String salesOrderApi =
        "https://yenerp.com/fluttertestapi/heldorders/";

    print("🔗 API URL: $salesOrderApi");

    try {
      // -------------------------
      // Convert dates to ISO format
      // -------------------------
      if (salesOrder["deliveryDate"] != null &&
          salesOrder["deliveryDate"] != "") {
        print("⏳ Converting deliveryDate: ${salesOrder["deliveryDate"]}");
        salesOrder["deliveryDate"] = convertToIsoDate(
          salesOrder["deliveryDate"],
        );
        print("✅ Converted deliveryDate to ISO: ${salesOrder["deliveryDate"]}");
      } else {
        print("ℹ️ deliveryDate is null or empty");
      }

      if (salesOrder["eventDate"] != null && salesOrder["eventDate"] != "") {
        print("⏳ Converting eventDate: ${salesOrder["eventDate"]}");
        salesOrder["eventDate"] = convertToIsoDate(salesOrder["eventDate"]);
        print("✅ Converted eventDate to ISO: ${salesOrder["eventDate"]}");
      } else {
        print("ℹ️ eventDate is null or empty");
      }

      // -------------------------
      // Print full payload
      // -------------------------
      print("📦 Payload to be sent:");
      print(jsonEncode(salesOrder));

      // -------------------------
      // Send POST request
      // -------------------------
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      // -------------------------
      // Print response details
      // -------------------------
      print("📤 Response status code: ${response.statusCode}");
      print("📤 Response body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ Sales order posted successfully");
        // patchSaleOrder(salesOrder, response.body); // optional further processing
        return true;
      } else {
        print("❌ Failed to post sales order");
        return false;
      }
    } catch (e) {
      print("⚠️ Exception occurred while posting sales order: $e");
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
      return;
    }
    _isSyncing = true;

    try {
      var invoiceBox = await Hive.openBox('invoices');

      for (int i = 0; i < invoiceBox.length; i++) {
        var invoiceData = invoiceBox.getAt(i);

        // Decode if string
        if (invoiceData is String) {
          invoiceData = jsonDecode(invoiceData);
        }

        if (invoiceData is Map<String, dynamic> &&
            invoiceData['sync'] == 'No') {
          // 🩹 FIX: If the actual data is inside 'salesOrderId', extract it
          if (invoiceData.containsKey('salesOrderId') &&
              invoiceData['salesOrderId'] is Map<String, dynamic>) {
            invoiceData = invoiceData['salesOrderId'];
          }

          bool success = await postInvoice(invoiceData);
          if (success) {
            invoiceData['sync'] = 'Yes';
            // await invoiceBox.putAt(i, invoiceData);
          } else {
            break;
          }
        } else {}
      }
    } catch (e, st) {
    } finally {
      _isSyncing = false;
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
    Map<String, dynamic> fullOrderData,
  ) async {
    print('🔹 Starting patchSalesOrder for SaleOrderNo: $saleOrderNo');

    final Map<String, dynamic> finalPayload = Map<String, dynamic>.from(
      fullOrderData['data'] ?? {},
    );
    print('📦 Initial payload extracted from fullOrderData: $finalPayload');

    // Fix advancePaymentType
    if (finalPayload['advancePaymentType'] != null) {
      print('🔄 Converting advancePaymentType...');
      finalPayload['advancePaymentType'] =
          (finalPayload['advancePaymentType'] as List)
              .map((x) => (x as List).map((y) => y.toString()).toList())
              .toList();
      print(
        '✅ advancePaymentType after conversion: ${finalPayload['advancePaymentType']}',
      );
    } else {
      print('ℹ️ No advancePaymentType found.');
    }

    // Fix modeWiseAmount
    if (finalPayload['modeWiseAmount'] != null) {
      print('🔄 Converting modeWiseAmount...');
      finalPayload['modeWiseAmount'] = (finalPayload['modeWiseAmount'] as List)
          .map((x) => (x as List).map((y) => (y as num).toDouble()).toList())
          .toList();
      print(
        '✅ modeWiseAmount after conversion: ${finalPayload['modeWiseAmount']}',
      );
    } else {
      print('ℹ️ No modeWiseAmount found.');
    }

    // Fix advanceAmount
    if (finalPayload['advanceAmount'] != null) {
      print('🔄 Converting advanceAmount...');
      finalPayload['advanceAmount'] = (finalPayload['advanceAmount'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      print(
        '✅ advanceAmount after conversion: ${finalPayload['advanceAmount']}',
      );
    } else {
      print('ℹ️ No advanceAmount found.');
    }

    // Construct URL
    final url = Uri.parse(
      'https://yenerp.com/fluttertestapi/salesorders/by-saleorderno/$saleOrderNo',
    );
    print('🌐 PATCH URL: $url');

    try {
      print('⏳ Sending PATCH request...');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(finalPayload),
      );

      print('📬 Response status code: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ PATCH successful!');
        return true;
      } else {
        print('❌ PATCH failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e, st) {
      print('⚠️ Exception occurred during PATCH: $e');
      print('📌 Stack trace: $st');
      return false;
    } finally {
      print('🔚 patchSalesOrder completed for SaleOrderNo: $saleOrderNo');
    }
  }

  Future fetchSalesOrderFromApi(saleOrderNo) async {}
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/Model/branch_model.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart' as webSocketglobals;
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Server_Client/websocketService.dart';

import '../../Global/Provider/branchSelection_provider.dart';

import 'package:http_parser/http_parser.dart';
import '../../../Global/globals_data.dart' as globalbranch;

import 'customerScreen_provider.dart';

class EditCustomerScreenProvider with ChangeNotifier {
  EditCustomerScreenProvider() {
    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
    isModifyMode.addListener(_onModifyModeChanged);
    _initWebSocket();
  }
  List<Map<String, String>> suggestions = [];
  bool isFormValid = true;
  TextEditingController customerNameController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  TextEditingController timeController = TextEditingController();
  TextEditingController mobileNoController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController landmarkController = TextEditingController();
  TextEditingController companyNameController = TextEditingController();
  TextEditingController companyAddressController = TextEditingController();
  TextEditingController companygstNumberController = TextEditingController();
  TextEditingController advanceAmountController = TextEditingController();
  TextEditingController birthdaydateController = TextEditingController();
  String? selectedOrderType;
  BranchProvider branchProvider = BranchProvider();
  Branch? storedBranch;
  Timer? _debounce;
  String? _selectedEvent;
  String? get selectedEvent => _selectedEvent;
  String recordedFilePath = '';
  String? audioPlayerId;
  String? photoScreenId;
  String? previousAudioId;
  String? previousImageId;

  File? pickedImage1;
  File? pickedImage2;
  // Global ScaffoldMessengerKey to safely show SnackBars without relying on context
  final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  Map<String, dynamic>? here;
  String selectedPaymentMethod = 'Cash';
  int? selectedTransactionIndex;
  // bool isModifyMode = false;
  late WebSocketChannel _channel;
  final ValueNotifier<bool> isModifyMode = ValueNotifier<bool>(false);
  void _initWebSocket() {
    // Replace these with your actual server IP and port defined in globals.
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://${webSocketglobals.serverip}:${webSocketglobals.port}'),
    );
    // Listen for messages from the server.
    _channel.stream.listen(
      (data) {
        // print('Received dataCustomerProvider: $data');
        // WebSocketService();
        WebSocketService(
          CustomerScreenProvider(),
          SalesInvoiceReceiptPrinter(),
        ).handleMessage(data);
      },
      onError: (error) {
        // print('WebSocket error: $error');
      },
    );
  }

  void setSelectedOrderType(String? newValue) {
    selectedOrderType = newValue;
    notifyListeners(); // Notify listeners to update the UI
  }

  void _onModifyModeChanged() {
    if (!isModifyMode.value) {
      // Clear changes when exiting modify mode
      quantityChanges.clear();
      increasedItems.clear();
      decreasedItems.clear();
      notifyListeners();
    }
  }

  void setModifyMode(bool value) {
    if (isModifyMode != value) {
      isModifyMode.value = value;
      quantityChanges.clear();
      increasedItems.clear();
      decreasedItems.clear();
      notifyListeners();
    }
  }

  void resetSelection() {
    selectedTransactionIndex = null;
    isModifyMode.value = false;
    quantityChanges.clear();
    increasedItems.clear();
    decreasedItems.clear();
    notifyListeners();
  }

  // Map<int, double> quantityChanges = {};
  Map<int, double> quantityChanges = {};
  List<Map<String, dynamic>> increasedItems = [];
  List<Map<String, dynamic>> decreasedItems = [];

  void addItemToOrder(Map<String, dynamic> item, double weightOrQuantity) {
    // Determine if the item is measured in kilograms
    bool isKgUnit =
        item['varianceUom']?.toLowerCase() == 'kg' ||
        item['varianceUom']?.toLowerCase() == 'kgs';

    // Check if the item already exists in the list
    int existingIndex = increasedItems.indexWhere(
      (element) => element['varianceName'] == item['varianceName'],
    );

    if (existingIndex != -1) {
      // Update quantity or weight based on unit
      if (isKgUnit) {
        double prevWeight = increasedItems[existingIndex]['weight'];
        increasedItems[existingIndex]['weight'] += weightOrQuantity;
      } else {
        double prevQuantity = increasedItems[existingIndex]['quantity'];
        increasedItems[existingIndex]['quantity'] += weightOrQuantity;
      }

      // Update amount
      double unitPrice = increasedItems[existingIndex]['price'];
      double updatedAmount =
          unitPrice *
          (isKgUnit
              ? increasedItems[existingIndex]['weight']
              : increasedItems[existingIndex]['quantity']);
      increasedItems[existingIndex]['amount'] = updatedAmount;
    } else {
      // Construct new item entry
      Map<String, dynamic> newItem = {
        'varianceName': item['varianceName'],
        'itemName': item['itemName'],
        'quantity': isKgUnit ? 1.0 : weightOrQuantity,
        'weight': isKgUnit ? weightOrQuantity : 0,
        'uom': item['varianceUom'],
        'price': item['variancePrice'],
        'tax': item['variancetax'] ?? 0,
        'itemCode': item['varianceitemCode'],
        'amount': item['variancePrice'] * weightOrQuantity,
      };

      increasedItems.add(newItem);
    }

    // Notify listeners of the change
    notifyListeners();

    for (int i = 0; i < increasedItems.length; i++) {}
  }

  void handleTransactionSelection(int newIndex) {
    if (selectedTransactionIndex != newIndex) {
      resetSelection();
      selectedTransactionIndex = newIndex;
      notifyListeners();
    }
  }

  void updateWeight(Map<String, dynamic> item, double newWeight) {
    item['weight'] = newWeight;
    notifyListeners();
  }

  void increaseQuantity(Map<String, dynamic> item) {
    item['quantity'] += 1;
    notifyListeners();
  }

  // Decrease quantity (but not below 1)
  void decreaseQuantity(Map<String, dynamic> item) {
    if (item['quantity'] > 1) {
      item['quantity'] -= 1;
      notifyListeners();
    }
  }

  void updateQuantityWithWeight(
    SalesOrderDisplay salesOrder,
    int index,
    double newWeight,
  ) {
    // setState(() {
    double difference = newWeight - salesOrder.weight[index];
    quantityChanges[index] = difference;

    Map<String, dynamic> item = {
      'varianceName': salesOrder.varianceName[index],
      'itemName': salesOrder.itemName[index],
      'quantity': difference.abs(),
      'weight': newWeight,
      'uom': salesOrder.uom[index],
      'price': salesOrder.price[index],
      'amount': difference.abs() * salesOrder.price[index],
    };

    if (difference > 0) {
      increasedItems.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
      increasedItems.add(item);
      decreasedItems.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
    } else if (difference < 0) {
      decreasedItems.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
      decreasedItems.add(item);
      increasedItems.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
    }
    notifyListeners();
    // });
  }

  double calculateModifiedTotal(SalesOrderDisplay salesOrder) {
    double originalTotal = salesOrder.totalAmount;

    // Calculate total for increased items
    double increasedTotal = increasedItems.fold(0.0, (sum, item) {
      return sum + (item['amount'] ?? 0.0);
    });

    // Calculate total for decreased items
    double decreasedTotal = decreasedItems.fold(0.0, (sum, item) {
      return sum + (item['amount'] ?? 0.0);
    });

    // Final total: original + increased - decreased
    double modifiedTotal = originalTotal + increasedTotal - decreasedTotal;
    notifyListeners();
    return modifiedTotal;
  }

  void updateQuantity(SalesOrderDisplay salesOrder, int index, double newQty) {
    // setState(() {
    double difference = newQty - salesOrder.qty[index];
    quantityChanges[index] = difference;

    Map<String, dynamic> item = {
      'varianceName': salesOrder.varianceName[index],
      'itemName': salesOrder.itemName[index],
      'quantity': difference.abs(),
      'uom': salesOrder.uom[index],
      'price': salesOrder.price[index],
      'amount': difference.abs() * salesOrder.price[index],
    };

    if (difference > 0) {
      increasedItems.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
      increasedItems.add(item);
      decreasedItems.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
    } else if (difference < 0) {
      decreasedItems.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
      decreasedItems.add(item);
      increasedItems.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
    }
    notifyListeners();
    // });
  }

  @override
  void dispose() {
    dateController.dispose();
    timeController.dispose();
    mobileNoController.dispose();
    customerNameController.dispose();
    addressController.dispose();
    landmarkController.dispose();
    searchController.dispose();
    // advanceAmountController.dispose(); // Dispose all controllers
    super.dispose();
  }

  void handleRecordingComplete(String path) {
    // setState(() {
    recordedFilePath = path;
    notifyListeners();
    // });
  }

  void removeAddedItem(Map<String, dynamic> item) {
    increasedItems.removeWhere(
      (element) => element['varianceName'] == item['varianceName'],
    );
    notifyListeners();
  }

  void onImagesSelected(File? image1, File? image2) async {
    if (image1 != null && image2 != null) {
      final box = Hive.box('imagesBox');
      await box.put('image1', image1.path);
      await box.put('image2', image2.path);

      pickedImage1 = image1;
      pickedImage2 = image2;
      notifyListeners();
    }
  }

  void fetchCompanySuggestionsDebounced(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      fetchCompanySuggestions(query);
    });
  }

  Future<void> batchUpdateCustomId(
    String currentCustomId,
    String newCustomId,
  ) async {
    final url = Uri.parse("http://$ipAddress/imageOrder/media/batch_update");

    try {
      // Prepare the request body
      final body = {
        'current_custom_id': currentCustomId,
        'new_custom_id': newCustomId,
      };

      // Send the PATCH request
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        // Parse the response if needed
        final data = json.decode(response.body);
      } else {}
    } catch (e) {}
  }

  Future<void> sendPaymentDataToServer(Map<String, dynamic> paymentData) async {
    try {
      final jsonData = jsonEncode(paymentData);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  Future<bool> addCompany(String name, String address, String gst) async {
    try {
      final response = await http.post(
        Uri.parse('http://$ipAddress/companies/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'companyName': name,
          'companyAddress': address,
          'companyGST': gst,
          'status': '1',
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  void showAdvancePaymentPopup(
    BuildContext context,
    SalesOrderDisplay salesorder,
    List<Map<String, dynamic>> increasedItems,
    List<Map<String, dynamic>> decreasedItems,
    String? path,
    ApiServiceSalesOrderProvider apiprovider,
    File? img1,
    File? img2,
    double modifiedTotal,
    bool isModifyMode,
  ) {
    final dialogContext = context; // Save context safely

    advanceAmountController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Order'),
          content: const Text('Are you sure you want to complete the order?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog first

                double totalAdvance = 0; // Replace with actual calculation
                double totalAmount = modifiedTotal;
                double balanceAmount = totalAmount - totalAdvance;

                try {
                  await saveModifiedOrder(
                    salesorder,
                    increasedItems,
                    decreasedItems,
                    path,
                    img1,
                    img2,
                    totalAmount,
                    totalAdvance,
                    balanceAmount,
                    dialogContext, // Use saved context
                    isModifyMode,
                  );
                } catch (e, stack) {
                  rootScaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text('Error occurred: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateCustomId(
    String currentCustomId,
    String newCustomId,
  ) async {
    // Define the API endpoint
    final Uri url = Uri.parse(
      'http://$ipAddress/audioOrder/media/$currentCustomId/audio',
    );

    try {
      // Make the PATCH request
      final http.Response response = await http.patch(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'new_custom_id': newCustomId},
      );

      // Handle the response
      if (response.statusCode == 200) {
      } else {
        // Decode the server response for detailed error messages
        final String errorMessage = utf8.decode(response.bodyBytes);
      }
    } catch (e) {
      // Handle exceptions like network issues
    }
  }

  int _sendInvoiceCallCount = 0;
  // 🔹 Global Counters & Trackers
  int serverSendCount = 0;
  int clientSendCount = 0;
  int clientReceiveCount = 0;

  final Map<String, int> serverSendTracker = {};
  final Map<String, int> clientSendTracker = {};
  final Map<String, int> clientReceiveTracker = {};

  /// -------------------- SERVER SIDE -------------------- ///

  Future<void> sendModifyDataToServer(Map<String, dynamic> invoiceData) async {
    try {
      final jsonData = jsonEncode(invoiceData);
      final soNo =
          invoiceData['saleOrderNo'] ??
          invoiceData['salesOrderId'] ??
          'UNKNOWN';

      // 🔹 Count increment
      serverSendCount++;
      serverSendTracker[soNo] = (serverSendTracker[soNo] ?? 0) + 1;

      // 🔹 Block duplicates
      if (serverSendTracker[soNo]! > 1) {
        return;
      }

      debugPrint(
        "📤 [Server] Sending ModifyData ($soNo) → Count: ${serverSendTracker[soNo]}",
      );
      _channel.sink.add(jsonData);
      // ✅ Reset tracker after success
      serverSendTracker[soNo] = 0;
    } catch (e) {
    }
  }

  Future<void> _sendPatchedDataToServer(
    Map<String, dynamic> invoiceData,
  ) async {
    try {
      final jsonData = jsonEncode(invoiceData);
      final soNo = invoiceData['saleOrderNo'] ?? 'UNKNOWN';

      // 🔹 Count increment
      serverSendCount++;
      serverSendTracker[soNo] = (serverSendTracker[soNo] ?? 0) + 1;

      // 🔹 Block duplicates
      if (serverSendTracker[soNo]! > 1) {
        return;
      }

      debugPrint(
        "📤 [Server] Sending PatchedData ($soNo) → Count: ${serverSendTracker[soNo]}",
      );
      _channel.sink.add(jsonData);
      // ✅ Reset tracker after success
      serverSendTracker[soNo] = 0;
    } catch (e) {
    }
  }

  Future<void> saveModifiedOrder(
    SalesOrderDisplay originalOrder,
    List<Map<String, dynamic>> increasedItems,
    List<Map<String, dynamic>> decreasedItems,
    String? audioPath,
    File? newImage1,
    File? newImage2,
    double totalAmount,
    double totalAdvance,
    double balanceAmount,
    BuildContext context,
    bool isModified,
  ) async {
    try {

      final jsonSalesOrder = jsonEncode({
        "data": originalOrder.toJson(),
        "deviceName": globals.deviceName,
        "type": "modifySaleOrder",
        "salesOrderId": originalOrder.salesOrderId,
        "sync": "No",
        "edit": "No",
      });

      final modifiedOrderData = _mergeOrderModifications(
        originalOrder,
        increasedItems,
        decreasedItems,
        totalAmount,
        totalAdvance,
        balanceAmount,
        audioPath: audioPath,
        imagePath1: newImage1?.path ?? originalOrder.image1,
        imagePath2: newImage2?.path ?? originalOrder.image2,
      );

      final jsonModifiedSalesOrder = jsonEncode({
        "data": modifiedOrderData,
        "deviceName": globals.deviceName,
        "type": "patchSaleOrder",
        "saleOrderNo": originalOrder.saleOrderNo,
        "sync": "No",
        "edit": "Yes",
      });

      // Send original and modified order
      await sendModifyDataToServer(jsonDecode(jsonSalesOrder));
      await _sendPatchedDataToServer(jsonDecode(jsonModifiedSalesOrder));

      // Show success SnackBar safely
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Order modification completed successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear temporary lists
      increasedItems.clear();
      decreasedItems.clear();
      serverSendTracker.clear();
      clientSendTracker.clear();
      clientReceiveTracker.clear();
      serverSendCount = 0;
      clientSendCount = 0;
      clientReceiveCount = 0;
      webSocketglobals.quantityChangesNotifier.value =
          {}; // clear changes after save
    } catch (e, stackTrace) {

      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ----------------------------- _mergeOrderModifications -----------------------------
  Map<String, dynamic> _mergeOrderModifications(
    SalesOrderDisplay originalOrder,
    List<Map<String, dynamic>> increasedItems,
    List<Map<String, dynamic>> decreasedItems,
    double totalAmount,
    double totalAdvance,
    double balanceAmount, {
    String? audioPath,
    String? imagePath1,
    String? imagePath2,
  }) {
    // --- Start with original order values ---
    List<String> mergedItemNames = (originalOrder.itemName ?? [])
        .map((e) => e.trim())
        .toList();
    List<String> mergedVarianceNames = (originalOrder.varianceName ?? [])
        .map((e) => e.trim())
        .toList();
    List<num> mergedQty = (originalOrder.qty ?? [])
        .map((q) => q is int ? q.toDouble() : q)
        .toList();
    List<String> mergedUom = (originalOrder.uom ?? []).toList();
    List<num> mergedWeight = (originalOrder.weight ?? [])
        .map((w) => w is int ? w.toDouble() : w)
        .toList();
    List<num> mergedAmount = (originalOrder.amount ?? [])
        .map((a) => a is int ? a.toDouble() : a)
        .toList();
    List<num> mergedPrice = (originalOrder.price ?? [])
        .map((p) => p is int ? p.toDouble() : p)
        .toList();

    // --- Merge increased items ---
    for (var item in increasedItems) {
      int existingIndex = mergedVarianceNames.indexWhere(
        (name) => name.toLowerCase() == item['varianceName'].toLowerCase(),
      );

      if (existingIndex != -1) {
        mergedQty[existingIndex] += (item['quantity'] is int
            ? item['quantity'].toDouble()
            : item['quantity']);
        mergedAmount[existingIndex] += (item['amount'] is int
            ? item['amount'].toDouble()
            : item['amount']);
        if (item['uom'].toLowerCase() == 'kg' ||
            item['uom'].toLowerCase() == 'kgs') {
          mergedWeight[existingIndex] += (item['weight'] is int
              ? item['weight'].toDouble()
              : item['weight']);
        }
        if (mergedItemNames[existingIndex] == "Unknown Item") {
          mergedItemNames[existingIndex] = item['itemName'].isEmpty
              ? item['varianceName']
              : item['itemName'];
        }
      } else {
        mergedVarianceNames.add(item['varianceName']);
        mergedItemNames.add(
          item['itemName'].isEmpty ? item['varianceName'] : item['itemName'],
        );
        mergedQty.add(
          item['quantity'] is int
              ? item['quantity'].toDouble()
              : item['quantity'],
        );
        mergedUom.add(item['uom']);
        mergedWeight.add(
          item['weight'] is int ? item['weight'].toDouble() : item['weight'],
        );
        mergedAmount.add(
          item['amount'] is int ? item['amount'].toDouble() : item['amount'],
        );
        mergedPrice.add(
          item['price'] is int ? item['price'].toDouble() : item['price'],
        );
      }
    }

    // --- Merge decreased items ---
    for (var item in decreasedItems) {
      int existingIndex = mergedVarianceNames.indexOf(item['varianceName']);
      if (existingIndex != -1) {
        num newQuantity = mergedQty[existingIndex];
        num newAmount = mergedAmount[existingIndex];
        num newWeight = mergedWeight[existingIndex];

        if (mergedUom[existingIndex].toLowerCase() == 'kg' ||
            mergedUom[existingIndex].toLowerCase() == 'kgs') {
          newWeight -= item['weight'];
          newAmount -= item['amount'];
        } else {
          newQuantity -= item['quantity'];
          newAmount -= item['amount'];
        }

        if (newQuantity > 0 && newWeight >= 0) {
          mergedQty[existingIndex] = newQuantity;
          mergedAmount[existingIndex] = newAmount;
          mergedWeight[existingIndex] = newWeight;
        } else {
          mergedItemNames.removeAt(existingIndex);
          mergedVarianceNames.removeAt(existingIndex);
          mergedQty.removeAt(existingIndex);
          mergedUom.removeAt(existingIndex);
          mergedWeight.removeAt(existingIndex);
          mergedAmount.removeAt(existingIndex);
          mergedPrice.removeAt(existingIndex);
        }
      }
    }

    // --- Build final modified order including audio and image paths ---
    Map<String, dynamic> modifiedOrderData = {
      'previousOrderId': originalOrder.salesOrderId,
      'itemName': mergedItemNames,
      'varianceName': mergedVarianceNames,
      'qty': mergedQty,
      'uom': mergedUom,
      'weight': mergedWeight,
      'amount': mergedAmount,
      'price': mergedPrice,
      'saleOrderNo': originalOrder.saleOrderNo,
      'customerName': originalOrder.customerName,
      'customerNumber': originalOrder.customerNumber,
      'deliveryDate': originalOrder.deliveryDate,
      'deliveryTime': originalOrder.deliveryTime,
      'event': originalOrder.event,
      'deliveryType': originalOrder.deliveryType,
      'address': originalOrder.address,
      'landmark': originalOrder.landmark,
      'totalAmount': totalAmount,
      'advanceAmount': originalOrder.advanceAmount ?? [],
      'balanceAmount': balanceAmount,
      'status': 'toApprove Orders',
      'approvalType': 'ModifyOrder',
      'audioPath': audioPath ?? originalOrder.audio,
      'imagePath1': imagePath1 ?? originalOrder.image1,
      'imagePath2': imagePath2 ?? originalOrder.image2,
    };

    return modifiedOrderData;
  }

  Timer? _debounceTimer; // Timer for debouncing

  Future<void> fetchSuggestions(String query) async {
    // Cancel previous timer if a new request comes in before delay
    _debounceTimer?.cancel();

    // Start a new timer (300ms delay before fetching)
    _debounceTimer = Timer(Duration(milliseconds: 300), () async {
      if (query.isEmpty) {
        suggestions = [];
        notifyListeners();
        return;
      }

      final url = Uri.parse('http://$ipAddress/customer/');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final List customers = json.decode(response.body);

          // Filter customers based on query
          suggestions = customers
              .where(
                (customer) => customer['customerPhoneNumber']
                    .toString()
                    .startsWith(query),
              )
              .map(
                (customer) => {
                  'mobile': customer['customerPhoneNumber'].toString(),
                  'name': customer['customerName'].toString(),
                },
              )
              .toList();

          notifyListeners();
        } else {
          throw Exception('Failed to load customers');
        }
      } catch (e) {
        suggestions = [];
        notifyListeners();
      }
    });
  }

  Future<void> sendToApproval(
    SalesOrderDisplay originalOrder,
    List<Map<String, dynamic>> increasedItems,
    List<Map<String, dynamic>> decreasedItems,
    String? audioPath,
    File? newImage1,
    File? newImage2,
    double totalAmount,
    double totalAdvance,
    double balanceAmount,
    BuildContext context,
  ) async {
    try {
      List<double> advanceAmountList = [totalAdvance];

      List<String> mergedItemNames = (originalOrder.itemName ?? [])
          .map((item) => item.isEmpty ? "Unknown Item" : item)
          .toList();
      List<String> mergedVarianceNames = (originalOrder.varianceName ?? [])
          .map((name) => name.trim())
          .toList();
      List<num> mergedQty = (originalOrder.qty ?? [])
          .map((q) => q is int ? q.toDouble() : q)
          .toList();
      List<String> mergedUom = (originalOrder.uom ?? []).toList();
      List<num> mergedWeight = (originalOrder.weight ?? [])
          .map((w) => w is int ? w.toDouble() : w)
          .toList();
      List<num> mergedAmount = (originalOrder.amount ?? [])
          .map((a) => a is int ? a.toDouble() : a)
          .toList();
      List<num> mergedPrice = (originalOrder.price ?? [])
          .map((p) => p is int ? p.toDouble() : p)
          .toList();

      // Validate initial data
      if (mergedVarianceNames.isEmpty) {}

      // Process increased items
      for (var item in increasedItems) {
        int existingIndex = mergedVarianceNames.indexWhere(
          (name) => name.toLowerCase() == item['varianceName'].toLowerCase(),
        );
        if (existingIndex != -1) {
          mergedQty[existingIndex] =
              (mergedQty[existingIndex] is int
                  ? mergedQty[existingIndex].toDouble()
                  : mergedQty[existingIndex]) +
              (item['quantity'] is int
                  ? item['quantity'].toDouble()
                  : item['quantity']);
          mergedAmount[existingIndex] =
              (mergedAmount[existingIndex] is int
                  ? mergedAmount[existingIndex].toDouble()
                  : mergedAmount[existingIndex]) +
              (item['amount'] is int
                  ? item['amount'].toDouble()
                  : item['amount']);
          if (item['uom'].toLowerCase() == 'kg' ||
              item['uom'].toLowerCase() == 'kgs') {
            mergedWeight[existingIndex] =
                (mergedWeight[existingIndex] is int
                    ? mergedWeight[existingIndex].toDouble()
                    : mergedWeight[existingIndex]) +
                (item['weight'] is int
                    ? item['weight'].toDouble()
                    : item['weight']);
          }
          // Update itemName if empty
          if (mergedItemNames[existingIndex] == "Unknown Item") {
            mergedItemNames[existingIndex] = item['itemName'].isEmpty
                ? item['varianceName']
                : item['itemName'];
          }
        } else {
          mergedVarianceNames.add(item['varianceName']);
          mergedItemNames.add(
            item['itemName'].isEmpty ? item['varianceName'] : item['itemName'],
          );
          mergedQty.add(
            item['quantity'] is int
                ? item['quantity'].toDouble()
                : item['quantity'],
          );
          mergedUom.add(item['uom']);
          mergedWeight.add(
            item['weight'] is int ? item['weight'].toDouble() : item['weight'],
          );
          mergedAmount.add(
            item['amount'] is int ? item['amount'].toDouble() : item['amount'],
          );
          mergedPrice.add(
            item['price'] is int ? item['price'].toDouble() : item['price'],
          );
        }
      }

      for (var item in decreasedItems) {
        int existingIndex = mergedVarianceNames.indexOf(item['varianceName']);

        if (existingIndex != -1) {
          // Get the current values
          num newQuantity = mergedQty[existingIndex];
          num newAmount = mergedAmount[existingIndex];
          num newWeight = mergedWeight[existingIndex];

          // Check the unit of measure (UOM)
          if (mergedUom[existingIndex].toLowerCase() == 'kg' ||
              mergedUom[existingIndex].toLowerCase() == 'kgs') {
            // If the UOM is kg, reduce the weight and amount, but don't change quantity
            double reducedWeight =
                item['weight']; // Reduced weight from the item
            newWeight -= reducedWeight; // Subtract the reduced weight
            newAmount -= item['amount']; // Subtract the amount
          } else {
            // For other units like Pcs or Pkt, reduce qty and amount
            newQuantity -= item['quantity'];
            newAmount -= item['amount'];
          }

          // Update the values if still valid
          if (newQuantity > 0 && newWeight >= 0) {
            mergedQty[existingIndex] = newQuantity;
            mergedAmount[existingIndex] = newAmount;
            mergedWeight[existingIndex] = newWeight;
          } else {
            // Remove the item if quantity or weight is zero or less
            mergedItemNames.removeAt(existingIndex);
            mergedVarianceNames.removeAt(existingIndex);
            mergedQty.removeAt(existingIndex);
            mergedUom.removeAt(existingIndex);
            mergedWeight.removeAt(existingIndex);
            mergedAmount.removeAt(existingIndex);
            mergedPrice.removeAt(existingIndex);
          }
        } else {}
      }

      Map<String, dynamic> modifiedOrderData = {
        'previousOrderId': originalOrder.salesOrderId,
        'itemName': mergedItemNames,
        'varianceName': mergedVarianceNames,
        'qty': mergedQty,
        'uom': mergedUom,
        'weight': mergedWeight,
        'amount': mergedAmount,
        'price': mergedPrice,
        'saleOrderNo': originalOrder.saleOrderNo,
        'customerName': customerNameController.text,
        'customerNumber': mobileNoController.text,
        'deliveryDate': dateController.text,
        'deliveryTime': timeController.text,
        'event': selectedEvent,
        'deliveryType': selectedDeliveryType,
        'address': addressController.text,
        'landmark': landmarkController.text,
        'totalAmount': totalAmount,
        'advanceAmount': advanceAmountList,
        'balanceAmount': balanceAmount,
        'status': 'toApprove Orders',
        'approvalType': 'ModifyOrder',
      };

      // Print the final payload

      String jsonModifiedSalesOrder = jsonEncode({
        "data": modifiedOrderData,
        "deviceName": globals.deviceName,
        "type": "postToApprove",
        'salesOrderId': originalOrder.saleOrderNo,
        'sync': "No",
        'edit': 'No',
      });

      final approvalDetails = {"approvalType": "ModifyOrder", "summary": "no"};
      Map<String, dynamic> patchData = {
        "status": "toApprove Orders",
        "approvalDetails": [approvalDetails],
      };
      String serverPatchData = jsonEncode({
        "data": patchData,
        "deviceName": globals.deviceName,
        "type": "patchSaleOrder",
        'salesOrderId': originalOrder.saleOrderNo,
        'sync': "No",
        'edit': 'Yes',
        'waitingForApprovalResult': 'Yes',
        "saleOrderNo": originalOrder.saleOrderNo,
      });

      await _sendPostToapproveDataToServer(jsonDecode(jsonModifiedSalesOrder));
      await _sendPatchForSaleOrderDataToServer(jsonDecode(serverPatchData));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendPostToapproveDataToServer(
    Map<String, dynamic> invoiceData,
  ) async {
    try {
      final jsonData = jsonEncode(invoiceData);
      _channel.sink.add(jsonData);
    } catch (e) {}
  }

  int _sendCount = 0; // Add this as a member variable of your class

  Future<void> _sendPatchForSaleOrderDataToServer(
    Map<String, dynamic> patchData,
  ) async {
    try {
      final jsonData = jsonEncode(patchData);
      _channel.sink.add(jsonData);
      _sendCount++; // Increment the counter
    } catch (e) {}
  }

  Future<void> handleAudioOrder(
    String? audioOrderId,
    String salesOrderId,
    String? path,
  ) async {
    if (path == null || path.isEmpty) {
      return;
    }
    if (audioOrderId != null) {
      // await updateCustomId(audioOrderId, salesOrderId);
    } else {
      await _postAudioFile(salesOrderId, path);
    }
  }

  Future<void> handleImageUpload(
    String salesOrderId,
    File? img1,
    File? img2,
  ) async {
    if (img1 != null || img2 != null) {
      await _postImages(salesOrderId, img1, img2);
    }
  }

  Future<void> _postImages(
    String salesOrderId,
    File? pickedImage1,
    File? pickedImage2,
  ) async {
    try {
      var uri = Uri.parse(
        "http://$ipAddress/imageOrder/upload_photo",
      ); // Change to your FastAPI endpoint
      var request = http.MultipartRequest('POST', uri);

      // Attach the salesOrderId to the request
      request.fields['custom_id'] = salesOrderId;

      // Check and add image1 if it's picked
      if (pickedImage1 != null) {
        var image1Bytes = await pickedImage1.readAsBytes();
        var image1MimeType =
            lookupMimeType(pickedImage1.path) ??
            'image/jpeg'; // Default to 'image/jpeg' if MIME type is not found

        // Add image1 as a multipart file
        request.files.add(
          http.MultipartFile.fromBytes(
            'files', // The field name expected by FastAPI
            image1Bytes,
            filename: pickedImage1.path
                .split('/')
                .last, // Extract the filename from the path
            contentType: MediaType.parse(
              image1MimeType,
            ), // Use the correct MIME type
          ),
        );
      }

      // Check and add image2 if it's picked
      if (pickedImage2 != null) {
        var image2Bytes = await pickedImage2.readAsBytes();
        var image2MimeType =
            lookupMimeType(pickedImage2.path) ??
            'image/jpeg'; // Default to 'image/jpeg' if MIME type is not found

        // Add image2 as a multipart file
        request.files.add(
          http.MultipartFile.fromBytes(
            'files', // The field name expected by FastAPI
            image2Bytes,
            filename: pickedImage2.path
                .split('/')
                .last, // Extract the filename from the path
            contentType: MediaType.parse(
              image2MimeType,
            ), // Use the correct MIME type
          ),
        );
      }

      // Send the request and await the response
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var responseData = jsonDecode(responseBody);

        // Process the response to get the uploaded image URLs
        var uploadedPhotos = responseData['uploaded_photos'];
        for (var photo in uploadedPhotos) {}
      } else {}
    } catch (e) {}
  }

  Future<void> _postAudioFile(String customId, String filePath) async {
    // final uri = Uri.parse('https://yenerp.com/fastapi/audios/upload_audio');
    final uri = Uri.parse('http://$ipAddress/audioOrder/upload_audio');

    try {
      // Determine the content type based on the file extension (simplified example)
      String fileExtension = filePath.split('.').last.toLowerCase();
      String contentType = 'audio/$fileExtension';

      // Create a new MultipartRequest
      final request = http.MultipartRequest('POST', uri);

      // Add the audio file with dynamic content type
      var file = await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType.parse(contentType),
      );
      request.files.add(file);

      // Debug: Check what is being added to the request

      // Pass customId in the form fields
      if (customId.isNotEmpty) {
        request.fields['custom_id'] = customId;
      }

      // Debug: Check the request before sending it

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream
          .bytesToString(); // Read response body

      // Debug: Check the server's response
      if (response.statusCode == 200) {
      } else {}
    } catch (e) {
      // Optionally, handle error more gracefully (e.g., display a user-friendly message)
    }
  }

  // Helper function to calculate new total

  Future<void> fetchCompanySuggestions(String query) async {
    if (query.isEmpty) {
      suggestions = [];
      notifyListeners();
      return;
    }

    final url = Uri.parse('http://$ipAddress/companies/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List customers = json.decode(response.body);

        suggestions = customers
            .where(
              (customer) =>
                  customer['companyName'].toString().startsWith(query),
            ) // Filter by company name prefix
            .map(
              (customer) => {
                'name': customer['companyName'].toString(),
                'address': customer['companyAddress'].toString(),
                'gst': customer['companyGST'].toString(),
              },
            )
            .toList();
        notifyListeners();
      } else {
        throw Exception('Failed to load companies');
      }
    } catch (e) {
      suggestions = [];
      notifyListeners();
    }
  }

  void setSelectedEvent(String? event) {
    _selectedEvent = event;
    notifyListeners();
  }

  void setSelectedDeliveryType(String? newValue) {
    selectedDeliveryType = newValue;
    notifyListeners();
  }

  String? selectedDeliveryType;
  Future<bool> addCustomer(String mobile, String name) async {
    try {
      final response = await http.post(
        Uri.parse('http://$ipAddress/customer/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customerPhoneNumber': mobile,
          'customerName': name,
          'status': '1',
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding customer: $e');
      return false;
    }
  }

  void onSuggestionSelected(Map<String, String> suggestion) {
    mobileNoController.text = suggestion['mobile']!;
    customerNameController.text = suggestion['name']!;
    suggestions = []; // Clear suggestions after selection
    notifyListeners();
  }

  Future<List<Map<String, String>>> fetchCustomerList() async {
    try {
      final response = await http.get(
        // Uri.parse('https://yenerp.com/fastapi/customers/'),
        Uri.parse('http://$ipAddress/customer/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> customerData = json.decode(response.body);
        return customerData.map((data) {
          return {
            'customerName': data['customerName'] as String,
            'customerPhoneNumber': data['customerPhoneNumber'] as String,
          };
        }).toList();
      } else {
        throw Exception('Failed to load customers');
      }
    } catch (e) {
      throw Exception('Error fetching customers: $e');
    }
  }

  Widget buildCustomerInputFields(BuildContext context, bool enable) {
    Future<void> fetchSuggestions(String query) async {
      if (query.isEmpty) {
        suggestions = [];
        notifyListeners();
        return;
      }

      final url = Uri.parse('http://$ipAddress/customer/');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final List customers = json.decode(response.body);
          suggestions = customers
              .where(
                (customer) => customer['customerPhoneNumber']
                    .toString()
                    .startsWith(query),
              ) // Filter by mobile number prefix
              .map(
                (customer) => {
                  'mobile': customer['customerPhoneNumber'].toString(),
                  'name': customer['customerName'].toString(),
                },
              )
              .toList();
          notifyListeners();
        } else {
          throw Exception('Failed to load customers');
        }
      } catch (e) {
        suggestions = [];
        notifyListeners();
      }
    }

    return Column(
      children: [
        Row(
          children: [
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: TextFormField(
                controller: mobileNoController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Search Mobile Number',
                  labelStyle: TextStyle(fontSize: 10),
                  enabled: enable,
                  isDense: true, // Makes the field more compact
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ), // Same padding as above
                ),
                onChanged: (value) {
                  // Clear customer name when mobile number changes
                  customerNameController.clear();
                  fetchSuggestions(value);
                },
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Customer Mobile No is required';
                  }
                  return null;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: TextFormField(
                enabled: false,
                controller: customerNameController,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(24),
                  FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9 ]*$')),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Customer Name',
                  labelStyle: TextStyle(fontSize: 10),
                  isDense: true, // Makes the field more compact
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ), // Same padding as above
                ),
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Customer Name is required';
                  }
                  return null;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
          ],
        ),
        const SizedBox(height: 8.0),

        // Only show suggestions container when mobile number is not empty AND customer name is empty
        if (mobileNoController.text.isNotEmpty &&
            customerNameController.text.isEmpty)
          Container(
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListView.builder(
              itemCount: suggestions.isEmpty ? 1 : suggestions.length + 1,
              itemBuilder: (context, index) {
                // Show suggestions if available
                if (suggestions.isNotEmpty &&
                    index < suggestions.length &&
                    enable) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    title: Text(suggestion['mobile'] ?? 'Unknown Mobile'),
                    subtitle: Text(suggestion['name'] ?? 'Unknown Name'),
                    onTap: () {
                      onSuggestionSelected(suggestion);
                      // Set focus to next field or clear focus
                      FocusScope.of(context).unfocus();
                    },
                  );
                }

                // Show "Add Customer Details" as the last item
                return ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ), // Reduced padding
                  title: const Text('Add Customer Details'),
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        final TextEditingController mobileController =
                            TextEditingController(
                              text: mobileNoController.text,
                            );
                        final TextEditingController nameController =
                            TextEditingController();
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          title: const Row(
                            children: [
                              Icon(Icons.person_add, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Add Customer',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: mobileController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Mobile Number',
                                    prefixText: '+91 ',
                                    prefixStyle: const TextStyle(
                                      color: Colors.black,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: nameController,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(24),
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^[a-zA-Z ]*$'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Customer Name',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final String mobile = mobileController.text
                                    .trim();
                                final String name = nameController.text.trim();

                                if (mobile.length == 10 &&
                                    RegExp(r'^\d+$').hasMatch(mobile) &&
                                    name.isNotEmpty) {
                                  final response = await addCustomer(
                                    mobile,
                                    name,
                                  );
                                  if (response) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Customer "$name" added successfully!',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    await fetchSuggestions(mobile);
                                    Navigator.pop(context);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to add customer. Please try again.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter a valid mobile number and name.',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Submit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget buildCompanyInputFields(BuildContext context) {
    return Column(
      children: [
        // Company-specific fields
        Row(
          children: [
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: TextFormField(
                controller: companyNameController,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9 ]*$')),
                  LengthLimitingTextInputFormatter(50),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Company Name',
                  // prefixIcon: Icon(Icons.search),
                  isDense: true, // Makes the field more compact
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                onChanged: (value) {
                  fetchCompanySuggestionsDebounced(value);
                },
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Company Name is required';
                  }
                  return null;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
          ],
        ),

        if (companyNameController.text.isNotEmpty &&
            companyAddressController.text.isEmpty)
          Container(
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListView.builder(
              itemCount: suggestions.isEmpty ? 1 : suggestions.length + 1,
              itemBuilder: (context, index) {
                // Show suggestions if available
                if (suggestions.isNotEmpty && index < suggestions.length) {
                  final company = suggestions[index];
                  return ListTile(
                    title: Text(company['name'] ?? ""),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(company['address'] ?? ""),
                        Text('GST: ${company['gst']}'),
                      ],
                    ),
                    onTap: () {
                      companyNameController.text = company['name'] ?? "";
                      companyAddressController.text = company['address'] ?? "";
                      companygstNumberController.text = company['gst'] ?? "";
                      suggestions.clear();
                      // FocusScope.of(context).unfocus();
                      notifyListeners();
                    },
                  );
                }
                // Show "Add Customer Details" as the last item
                return ListTile(
                  leading: const Icon(Icons.add, color: Colors.green),
                  title: const Text('Add Company Details'),
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        final TextEditingController nameController =
                            TextEditingController();
                        final TextEditingController addressController =
                            TextEditingController();
                        final TextEditingController gstController =
                            TextEditingController();

                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          title: const Row(
                            children: [
                              Icon(Icons.business, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Add Company',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Company Name',
                                    border: OutlineInputBorder(),
                                    isDense:
                                        true, // Makes the field more compact
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Company Address',
                                    border: OutlineInputBorder(),
                                    isDense:
                                        true, // Makes the field more compact
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: gstController,
                                  decoration: const InputDecoration(
                                    labelText: 'Company GST',
                                    border: OutlineInputBorder(),
                                    isDense:
                                        true, // Makes the field more compact
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final String name = nameController.text.trim();
                                final String address = addressController.text
                                    .trim();
                                final String gst = gstController.text.trim();

                                if (name.isNotEmpty &&
                                    address.isNotEmpty &&
                                    gst.isNotEmpty) {
                                  final response = await addCompany(
                                    name,
                                    address,
                                    gst,
                                  );

                                  if (response) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Company "$name" added successfully!',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    fetchCompanySuggestionsDebounced('');
                                    Navigator.pop(context);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to add company. Please try again.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please fill in all fields correctly.',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Submit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

        const SizedBox(height: 10),
        Row(
          children: [
            const Padding(padding: EdgeInsets.all(5)),
            Expanded(
              child: TextFormField(
                enabled: false,
                controller: companyAddressController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Company Address',
                  isDense: true, // Makes the field more compact
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Company Address is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10), // Spacing between the two fields
            Expanded(
              child: TextFormField(
                enabled: false,
                controller: companygstNumberController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Company GST',
                  isDense: true, // Makes the field more compact
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                validator: (value) {
                  if (isFormValid && (value == null || value.isEmpty)) {
                    return 'Company GST is required';
                  }
                  return null;
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(5)),
          ],
        ),
      ],
    );
  }

  String? selectedFilter = 'All Order';

  void setFilter(String? value) {
    selectedFilter = value;
    notifyListeners();
  }

  Map<String, Map<int, double>> modifiedQuantities = {};
  Map<String, Map<int, double>> modifiedAmounts = {};

  // New methods to support item-by-item editing

  // Track which items are currently being edited
  Set<String> itemsInEditMode = {};

  // Toggle edit mode for a specific item
  void toggleItemEditMode(SalesOrderDisplay salesOrder, int index) {
    String itemKey = '${salesOrder.varianceName[index]}_$index';
    if (itemsInEditMode.contains(itemKey)) {
      itemsInEditMode.remove(itemKey);
    } else {
      itemsInEditMode.add(itemKey);
    }
    notifyListeners();
  }

  // Check if an item is in edit mode
  bool isItemInEditMode(SalesOrderDisplay salesOrder, int index) {
    String itemKey = '${salesOrder.varianceName[index]}_$index';
    return itemsInEditMode.contains(itemKey);
  }

  // Get the unique key for an order item
  String _getOrderItemKey(SalesOrderDisplay salesOrder) {
    return salesOrder.salesOrderId ?? '';
  }

  // Check if an item has been modified
  bool isItemModified(SalesOrderDisplay salesOrder, int index) {
    String orderKey = _getOrderItemKey(salesOrder);

    return modifiedQuantities.containsKey(orderKey) &&
        modifiedQuantities[orderKey]!.containsKey(index) &&
        modifiedQuantities[orderKey]![index] != salesOrder.qty[index];
  }

  // Get modified quantity for an item
  num getModifiedQuantity(SalesOrderDisplay salesOrder, int index) {
    String orderKey = _getOrderItemKey(salesOrder);

    if (modifiedQuantities.containsKey(orderKey) &&
        modifiedQuantities[orderKey]!.containsKey(index)) {
      return modifiedQuantities[orderKey]![index]!;
    }

    return salesOrder.qty[index];
  }

  // Get modified amount for an item
  double getModifiedAmount(SalesOrderDisplay salesOrder, int index) {
    String orderKey = _getOrderItemKey(salesOrder);

    if (modifiedAmounts.containsKey(orderKey) &&
        modifiedAmounts[orderKey]!.containsKey(index)) {
      return modifiedAmounts[orderKey]![index]!;
    }

    return salesOrder.amount[index];
  }

  // Increase item quantity
  void increaseItemQuantity(SalesOrderDisplay salesOrder, int index) {
    String orderKey = _getOrderItemKey(salesOrder);

    // Initialize maps if needed
    if (!modifiedQuantities.containsKey(orderKey)) {
      modifiedQuantities[orderKey] = {};
      modifiedAmounts[orderKey] = {};
    }

    // Get current quantity (either modified or original)
    double currentQty = getModifiedQuantity(salesOrder, index) as double;
    bool isKg =
        salesOrder.uom[index].toLowerCase() == 'kg' ||
        salesOrder.uom[index].toLowerCase() == 'kgs';

    // Increment by 0.1 for kg, 1 for other units
    double newQty = isKg ? currentQty + 0.1 : currentQty + 1;

    // Update quantity and calculate new amount
    modifiedQuantities[orderKey]![index] = newQty;
    modifiedAmounts[orderKey]![index] = newQty * salesOrder.price[index];

    // Update increased/decreased items for summary
    _updateModifiedItemsList(salesOrder, index, newQty);

    notifyListeners();
  }

  // Decrease item quantity
  void decreaseItemQuantity(SalesOrderDisplay salesOrder, int index) {
    String orderKey = _getOrderItemKey(salesOrder);

    // Initialize maps if needed
    if (!modifiedQuantities.containsKey(orderKey)) {
      modifiedQuantities[orderKey] = {};
      modifiedAmounts[orderKey] = {};
    }

    // Get current quantity (either modified or original)
    double currentQty = getModifiedQuantity(salesOrder, index) as double;
    bool isKg =
        salesOrder.uom[index].toLowerCase() == 'kg' ||
        salesOrder.uom[index].toLowerCase() == 'kgs';

    // Only decrease if quantity is greater than minimum
    if ((isKg && currentQty > 0.1) || (!isKg && currentQty > 1)) {
      // Decrement by 0.1 for kg, 1 for other units
      double newQty = isKg ? currentQty - 0.1 : currentQty - 1;

      // Update quantity and calculate new amount
      modifiedQuantities[orderKey]![index] = newQty;
      modifiedAmounts[orderKey]![index] = newQty * salesOrder.price[index];

      // Update increased/decreased items for summary
      _updateModifiedItemsList(salesOrder, index, newQty);

      notifyListeners();
    }
  }

  // Reset item quantity to original
  void resetItemQuantity(SalesOrderDisplay salesOrder, int index) {
    String orderKey = _getOrderItemKey(salesOrder);

    if (modifiedQuantities.containsKey(orderKey) &&
        modifiedQuantities[orderKey]!.containsKey(index)) {
      modifiedQuantities[orderKey]!.remove(index);
      modifiedAmounts[orderKey]!.remove(index);

      // Remove from increased/decreased items
      _removeFromModifiedLists(salesOrder, index);

      notifyListeners();
    }
  }

  // Helper to update the increased/decreased items lists
  void _updateModifiedItemsList(
    SalesOrderDisplay salesOrder,
    int index,
    double newQty,
  ) {
    String itemName = salesOrder.varianceName[index];
    int originalQty = salesOrder.qty[index];
    double unitPrice = salesOrder.price[index];
    String uom = salesOrder.uom[index];

    // Calculate weight for Kg items
    double? weight;
    if (uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'kgs') {
      weight = salesOrder.weight != null && salesOrder.weight!.length > index
          ? salesOrder.weight![index]
          : null;
    }

    // Create the item info map
    Map<String, dynamic> itemInfo = {
      'varianceName': itemName,
      'originalQuantity': originalQty,
      'quantity': newQty,
      'uom': uom,
      'price': unitPrice,
      'amount': newQty * unitPrice,
      'originalAmount': originalQty * unitPrice,
    };

    if (weight != null) {
      itemInfo['weight'] = weight;
    }

    // Remove from both lists first
    _removeFromModifiedLists(salesOrder, index);

    // Add to appropriate list
    if (newQty > originalQty) {
      increasedItems.add(itemInfo);
    } else if (newQty < originalQty) {
      decreasedItems.add(itemInfo);
    }
  }

  // Helper to remove item from increased/decreased lists
  void _removeFromModifiedLists(SalesOrderDisplay salesOrder, int index) {
    String itemName = salesOrder.varianceName[index];

    increasedItems.removeWhere(
      (item) =>
          item['varianceName'] == itemName &&
          item['originalQuantity'] == salesOrder.qty[index],
    );

    decreasedItems.removeWhere(
      (item) =>
          item['varianceName'] == itemName &&
          item['originalQuantity'] == salesOrder.qty[index],
    );
  }

  void addToIncreasedItems(SalesOrderDisplay order, int index, double newQty) {
    final item = _createItemMap(order, index, newQty);

    // Remove from decreased if exists
    decreasedItems.removeWhere(
      (i) =>
          i['varianceName'] == item['varianceName'] &&
          i['salesOrderId'] == item['salesOrderId'],
    );

    increasedItems.add(item);
    notifyListeners();
  }

  void addToDecreasedItems(SalesOrderDisplay order, int index, double newQty) {
    final item = _createItemMap(order, index, newQty);

    // Remove from increased if exists
    increasedItems.removeWhere(
      (i) =>
          i['varianceName'] == item['varianceName'] &&
          i['salesOrderId'] == item['salesOrderId'],
    );

    decreasedItems.add(item);
    notifyListeners();
  }

  Map<String, dynamic> _createItemMap(
    SalesOrderDisplay order,
    int index,
    double newQty,
  ) {
    return {
      'salesOrderId': order.salesOrderId,
      'varianceName': order.varianceName[index],
      'originalQty': order.qty[index],
      'newQty': newQty,
      'price': order.price[index],
      'uom': order.uom[index],
      'amount': (newQty - order.qty[index]) * order.price[index],
    };
  }

  void updateIncreasedItems(SalesOrderDisplay order, int index, double newQty) {
    final itemIndex = increasedItems.indexWhere(
      (i) =>
          i['varianceName'] == order.varianceName[index] &&
          i['salesOrderId'] == order.salesOrderId,
    );

    if (itemIndex != -1) {
      increasedItems[itemIndex]['newQty'] = newQty;
      increasedItems[itemIndex]['amount'] =
          (newQty - order.qty[index]) * order.price[index];
      notifyListeners();
    }
  }

  void updateDecreasedItems(SalesOrderDisplay order, int index, double newQty) {
    final itemIndex = decreasedItems.indexWhere(
      (i) =>
          i['varianceName'] == order.varianceName[index] &&
          i['salesOrderId'] == order.salesOrderId,
    );

    if (itemIndex != -1) {
      decreasedItems[itemIndex]['newQty'] = newQty;
      decreasedItems[itemIndex]['amount'] =
          (order.qty[index] - newQty) * order.price[index];
      notifyListeners();
    }
  }

  void updateItemInOrder(
    Map<String, dynamic> item,
    double difference,
    int originalIndex,
  ) {
    bool isKgUnit =
        item['varianceUom']?.toLowerCase() == 'kg' ||
        item['varianceUom']?.toLowerCase() == 'kgs';

    // Convert existingQuantity to double to avoid int type issues
    double currentValue = isKgUnit
        ? (item['existingWeight'] ?? 0.0)
        : (item['existingQuantity'] is int
              ? (item['existingQuantity'] as int).toDouble()
              : (item['existingQuantity'] ?? 0.0));

    // Find if the item is in increased or decreased lists
    int increasedIndex = increasedItems.indexWhere(
      (element) => element['varianceName'] == item['varianceName'],
    );
    int decreasedIndex = decreasedItems.indexWhere(
      (element) => element['varianceName'] == item['varianceName'],
    );

    // Calculate current modification value
    double modificationValue = 0.0;
    if (increasedIndex != -1) {
      var value = isKgUnit
          ? increasedItems[increasedIndex]['weight']
          : increasedItems[increasedIndex]['quantity'];
      modificationValue = value is int ? value.toDouble() : (value ?? 0.0);
    } else if (decreasedIndex != -1) {
      var value = isKgUnit
          ? decreasedItems[decreasedIndex]['weight']
          : decreasedItems[decreasedIndex]['quantity'];
      modificationValue = -(value is int ? value.toDouble() : (value ?? 0.0));
    }

    // Calculate new quantity to check if it goes below 0
    double newQuantity = currentValue + modificationValue + difference;
    if (newQuantity < 0) {
      return; // Skip update if quantity would go negative
    }

    // Calculate new modification value
    double newModificationValue = modificationValue + difference;

    // Update or move the modification
    if (increasedIndex != -1 && newModificationValue > 0) {
      // Update existing increased item
      var existingItem = increasedItems[increasedIndex];
      existingItem[isKgUnit ? 'weight' : 'quantity'] = isKgUnit
          ? newModificationValue
          : newModificationValue;
      existingItem['amount'] = item['variancePrice'] * newModificationValue;
    } else if (decreasedIndex != -1 && newModificationValue < 0) {
      // Update existing decreased item
      var existingItem = decreasedItems[decreasedIndex];
      existingItem[isKgUnit ? 'weight' : 'quantity'] = isKgUnit
          ? -newModificationValue
          : -newModificationValue;
      existingItem['amount'] = item['variancePrice'] * (-newModificationValue);
    } else {
      // Remove existing entries to handle transitions or new modifications
      if (increasedIndex != -1) {
        increasedItems.removeAt(increasedIndex);
      }
      if (decreasedIndex != -1) {
        decreasedItems.removeAt(decreasedIndex);
      }

      // Add new modification if non-zero
      if (newModificationValue > 0) {
        // Add to increasedItems
        increasedItems.add({
          'varianceName': item['varianceName'],
          'itemName': item['itemName'],
          'quantity': isKgUnit ? 1.0 : newModificationValue,
          'weight': isKgUnit ? newModificationValue : 0.0,
          'uom': item['varianceUom'],
          'price': item['variancePrice'],
          'tax': item['variancetax'] ?? 0,
          'itemCode': item['varianceitemCode'],
          'amount': item['variancePrice'] * newModificationValue,
          'originalQuantity': item['existingQuantity'],
          'originalWeight': item['existingWeight'],
          'originalAmount': item['existingAmount'],
        });
      } else if (newModificationValue < 0) {
        // Add to decreasedItems
        decreasedItems.add({
          'varianceName': item['varianceName'],
          'itemName': item['itemName'],
          'quantity': isKgUnit ? 1.0 : -newModificationValue,
          'weight': isKgUnit ? -newModificationValue : 0.0,
          'uom': item['varianceUom'],
          'price': item['variancePrice'],
          'tax': item['variancetax'] ?? 0,
          'itemCode': item['varianceitemCode'],
          'amount': item['variancePrice'] * (-newModificationValue),
          'originalQuantity': item['existingQuantity'],
          'originalWeight': item['existingWeight'],
          'originalAmount': item['existingAmount'],
        });
      }
    }

    // Cleanup zero values
    increasedItems.removeWhere(
      (item) => (isKgUnit ? item['weight'] : item['quantity']) <= 0,
    );
    decreasedItems.removeWhere(
      (item) => (isKgUnit ? item['weight'] : item['quantity']) <= 0,
    );

    // Recalculate totals and notify listeners
    _recalculateOrderTotals();
    notifyListeners();
  }

  // Helper method to recalculate order totals
  void _recalculateOrderTotals() {
    // Implement total calculations based on your business logic
    // This might include subtotals, taxes, etc.
  }
}

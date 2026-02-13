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
import 'package:yen_pos/Global/Model/branch_model.dart';
import 'package:yen_pos/Global/Provider/connectivity_internet.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart' as webSocketglobals;
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Models/sales_order_display_model.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yen_pos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Server_Client/handlers/saleorder_handlemessage.dart';
import 'package:yen_pos/Server_Client/websocketService.dart';

import '../../Global/Provider/branchSelection_provider.dart';

import 'package:http_parser/http_parser.dart';
import '../../../Global/globals_data.dart' as globalbranch;

import 'customerScreen_provider.dart';

class EditCustomerScreenProvider with ChangeNotifier {
  EditCustomerScreenProvider() {
    storedBranch = branchProvider.getStoredBranch(globalbranch.branchName);
    isModifyMode.addListener(_onModifyModeChanged);
    globals.quantityChangesNotifier = ValueNotifier<Map<int, double>>({});
  }
  // Before
  ValueNotifier<Map<String, double>> addedItemsQtyNotifier =
      ValueNotifier<Map<String, double>>({});
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
  TextEditingController customChargeController = TextEditingController();
  final FocusNode customChargeFocus = FocusNode(); // 👈 new
  TextEditingController companygstNumberController = TextEditingController();
  TextEditingController advanceAmountController = TextEditingController();
  TextEditingController birthdaydateController = TextEditingController();
  String? selectedOrderType;
  BranchProvider branchProvider = BranchProvider();
  Branch? storedBranch;
  Timer? _debounce;
  String? selectedEvent;
  // 🔹 New field to store ISO format internally
  String? selectedDeliveryDateIso;
  String recordedFilePath = '';
  String? audioPlayerId;
  String? photoScreenId;
  String? previousAudioId;
  String? previousImageId;
  String? selectedChargeType;
  File? pickedImage1;
  File? pickedImage2;
  ValueNotifier<double> customCharge = ValueNotifier<double>(0);
  Map<String, TextEditingController?> customChargeControllers = {};

  /// 📸 Multiple picked images
  List<File> pickedImages = [];

  /// Update images from ImagePickerWidget
  void setPickedImages(List<File> images) {
    pickedImages = images;
    notifyListeners();
  }

  // Custom charges management

  Map<String, double> customChargeValues =
      {}; // Only store charges with values > 0

  List<String> customChargeTypes = [];

  // Custom charges management

  List<double> customChargeAmounts = [];

  // Add method to set custom charges - Using Map approach
  void setCustomCharges(Map<String, double> charges) {
    // Clear existing charges
    customChargeValues.clear();
    customChargeTypes.clear();
    customChargeAmounts.clear();

    // Add only charges with values > 0
    charges.forEach((type, value) {
      if (value > 0) {
        // For Map approach
        customChargeValues[type] = value;

        // For List approach (optional, if you need both)
        customChargeTypes.add(type);
        customChargeAmounts.add(value);
      }
    });

    // Calculate total
    customCharge.value = customChargeValues.values.fold(
      0.0,
      (sum, value) => sum + value,
    );

    notifyListeners();
  }

  // Helper method to get charges in list format for API
  List<String> getCustomChargeTypes() {
    return customChargeValues.keys.toList();
  }

  List<double> getCustomChargeAmounts() {
    return customChargeValues.values.toList();
  }

  // Alternative: If you want to keep only Map and convert when needed
  Map<String, double> getCustomCharges() {
    return Map.from(customChargeValues);
  }

  // Clear all custom charges
  void clearCustomCharges() {
    customChargeValues.clear();
    customChargeTypes.clear();
    customChargeAmounts.clear();
    customCharge.value = 0;

    // Clear all controllers
    customChargeControllers.forEach((key, controller) {
      controller?.clear();
    });

    notifyListeners();
  }

  // Add individual charge
  void addCustomCharge(String type, double value) {
    if (value > 0) {
      customChargeValues[type] = value;
      customCharge.value = customCharge.value + value;
      notifyListeners();
    }
  }

  // Remove individual charge
  void removeCustomCharge(String type) {
    if (customChargeValues.containsKey(type)) {
      double removedValue = customChargeValues[type]!;
      customChargeValues.remove(type);
      customCharge.value = customCharge.value - removedValue;
      notifyListeners();
    }
  }

  // Global ScaffoldMessengerKey to safely show SnackBars without relying on context
  final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  Map<String, dynamic>? here;
  String selectedPaymentMethod = 'Cash';
  int? selectedTransactionIndex;
  ValueNotifier<double> modifiedTotal = ValueNotifier<double>(0.0);
  ValueNotifier<bool> isModifyMode = ValueNotifier<bool>(false);

  void setSelectedOrderType(String? newValue) {
    selectedOrderType = newValue;
    notifyListeners(); // Notify listeners to update the UI
  }

  List<String> getEventList() {
    final eventsBox = HiveManager.events;
    final storedEvents = eventsBox.get('events', defaultValue: []);

    // Extract event names correctly
    if (storedEvents is List) {
      return storedEvents.map<String>((e) {
        if (e is Map && e.containsKey('eventname')) {
          return e['eventname'].toString(); // 👈 correct key
        }
        return e.toString();
      }).toList();
    }

    return [];
  }

  List<String> getDeliveryTypesList() {
    final eventsBox = HiveManager.events;
    final storedEvents = eventsBox.get('deliveryTypes', defaultValue: []);

    // Extract event names correctly
    if (storedEvents is List) {
      return storedEvents.map<String>((e) {
        if (e is Map && e.containsKey('deliveryType')) {
          return e['deliveryType'].toString(); // 👈 correct key
        }
        return e.toString();
      }).toList();
    }

    return [];
  }

  void _onModifyModeChanged() {
    if (!isModifyMode.value) {
      // Clear changes when exiting modify mode
      quantityChanges.clear();
      increasedItems.value.clear();
      decreasedItems.value.clear();
      notifyListeners();
    }
  }

  double modifiedCustomCharge = 0.0;

  void setCustomCharge(double charge) {
    modifiedCustomCharge = charge;
    notifyListeners(); // This triggers rebuild of summary
  }

  // Optional: override to use modified value during edit
  double get effectiveCustomCharge {
    return isModifyMode.value
        ? modifiedCustomCharge
        : (originalOrder?.totalCustomCharge ?? 0.0);
  }

  SalesOrderDisplay? originalOrder;

  void setModifyMode(bool value) {
    if (isModifyMode != value) {
      isModifyMode.value = value;
      quantityChanges.clear();
      increasedItems.value.clear();
      decreasedItems.value.clear();
      notifyListeners();
    }
  }

  void resetSelection() {
    selectedTransactionIndex = null;
    isModifyMode.value = false;
    quantityChanges.clear();
    increasedItems.value.clear();
    decreasedItems.value.clear();
    notifyListeners();
  }

  List<String> getChargesList() {
    final eventsBox = HiveManager.customCharges;
    final storedEvents = eventsBox.get('charges', defaultValue: []);

    // Extract event names correctly
    if (storedEvents is List) {
      return storedEvents.map<String>((e) {
        if (e is Map && e.containsKey('chargeType')) {
          return e['chargeType'].toString(); // 👈 correct key
        }
        return e.toString();
      }).toList();
    }

    return [];
  }

  // Map<int, double> quantityChanges = {};
  Map<int, double> quantityChanges = {};
  ValueNotifier<List<Map<String, dynamic>>> increasedItems = ValueNotifier([]);
  ValueNotifier<List<Map<String, dynamic>>> decreasedItems = ValueNotifier([]);
  void addItemToOrder(Map<String, dynamic> item, double weightOrQuantity) {
    // 🔹 Ensure all important fields have defaults
    final itemName = (item['itemName'] ?? 'Unknown Item').toString();
    final varianceName = (item['varianceName'] ?? 'Unknown Variance')
        .toString();
    final uom = (item['varianceUOM'] ?? 'PCS').toString();
    final price = (item['variancePrice'] ?? 0.0).toDouble();
    final tax = (item['varianceTax'] ?? 0.0).toDouble();
    final itemCode = (item['itemCode'] ?? '').toString();

    bool isKgUnit = uom.toLowerCase() == 'kg' || uom.toLowerCase() == 'kgs';

    print('================ ADD ITEM TO ORDER =================');
    print('Item Name      : $itemName');
    print('Variance Name  : $varianceName');
    print('UOM            : $uom');
    print('Price          : $price');
    print('Tax            : $tax');
    print('Item Code      : $itemCode');
    print('Weight/Quantity: $weightOrQuantity');
    print('Is KG Unit     : $isKgUnit');
    print('---------------------------------------------------');

    // Use a copy of current list
    List<Map<String, dynamic>> updatedItems = List.from(increasedItems.value);

    int existingIndex = updatedItems.indexWhere(
      (element) => (element['varianceName'] ?? '') == varianceName,
    );

    if (existingIndex != -1) {
      print('🔹 ITEM EXISTS IN ORDER. UPDATING EXISTING ENTRY');

      if (isKgUnit) {
        updatedItems[existingIndex]['weight'] =
            (updatedItems[existingIndex]['weight'] ?? 0.0) + weightOrQuantity;
        print(
          'Updated weight : ${updatedItems[existingIndex]['weight']} (added $weightOrQuantity)',
        );
      } else {
        updatedItems[existingIndex]['quantity'] =
            (updatedItems[existingIndex]['quantity'] ?? 0.0) + weightOrQuantity;
        print(
          'Updated quantity : ${updatedItems[existingIndex]['quantity']} (added $weightOrQuantity)',
        );
      }

      updatedItems[existingIndex]['amount'] =
          (updatedItems[existingIndex]['price'] ?? 0.0) *
          (isKgUnit
              ? updatedItems[existingIndex]['weight']
              : updatedItems[existingIndex]['quantity']);

      print('Updated amount : ${updatedItems[existingIndex]['amount']}');
    } else {
      print('🔹 NEW ITEM. ADDING TO ORDER');

      Map<String, dynamic> newItem = {
        'varianceName': varianceName,
        'itemName': itemName,
        'quantity': isKgUnit ? 1.0 : weightOrQuantity,
        'weight': isKgUnit ? weightOrQuantity : 0.0,
        'uom': uom,
        'price': price,
        'tax': tax,
        'itemCode': itemCode,
        'amount': price * (isKgUnit ? weightOrQuantity : weightOrQuantity),
      };

      print('New item details: $newItem');

      updatedItems.add(newItem);
    }

    // ✅ Re-assign a NEW list to trigger ValueListenableBuilder
    increasedItems.value = List.from(updatedItems);

    print('✅ ORDER ITEMS AFTER ADDITION:');
    for (var i = 0; i < updatedItems.length; i++) {
      print(
        '${i + 1}. ${updatedItems[i]['itemName']} - ${updatedItems[i]['varianceName']} | Qty: ${updatedItems[i]['quantity']} | Weight: ${updatedItems[i]['weight']} | Amount: ${updatedItems[i]['amount']} | Tax: ${updatedItems[i]['tax']} | Code: ${updatedItems[i]['itemCode']}',
      );
    }
    print('=====================================================');
  }

  void handleTransactionSelection(int newIndex) {
    if (selectedTransactionIndex != newIndex) {
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
      increasedItems.value.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
      increasedItems.value.add(item);
      decreasedItems.value.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
    } else if (difference < 0) {
      decreasedItems.value.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
      decreasedItems.value.add(item);
      increasedItems.value.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
    }
    notifyListeners();
    // });
  }

  double calculateModifiedTotal(SalesOrderDisplay salesOrder) {
    double originalTotal = salesOrder.totalAmount ?? 0.0;

    double increasedTotal = increasedItems.value.fold(
      0.0,
      (sum, item) => sum + ((item['amount'] ?? 0.0) as num),
    );

    double decreasedTotal = decreasedItems.value.fold(
      0.0,
      (sum, item) => sum + ((item['amount'] ?? 0.0) as num),
    );

    return originalTotal + increasedTotal - decreasedTotal;
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
      increasedItems.value.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
      increasedItems.value.add(item);
      decreasedItems.value.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
    } else if (difference < 0) {
      decreasedItems.value.removeWhere(
        (item) => item['varianceName'] == salesOrder.varianceName[index],
      );
      decreasedItems.value.add(item);
      increasedItems.value.removeWhere(
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
    // Create a new list without the removed item
    final updatedList = List<Map<String, dynamic>>.from(increasedItems.value)
      ..removeWhere(
        (element) => element['varianceName'] == item['varianceName'],
      );

    // Assign new list to trigger ValueListenableBuilder
    increasedItems.value = updatedList;
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
    List<File> pickedImages,
    double modifiedTotal,
    bool isModifyMode,
    double totalAdvanceAmount,
  ) {
    double orderAmount = modifiedTotal;
    double discount = 0;
    double customCharge =
        modifiedCustomCharge; // Get custom charge from provider
    double deductedAmount = salesorder.discountAmount ?? 0;

    // ✅ Calculate total amount including custom charge
    double itemTotal = modifiedTotal;
    double customChargeTotal = customCharge;
    double totalAmount2 = itemTotal + customChargeTotal;
    double finalPrice = itemTotal + customChargeTotal - deductedAmount;
    double balanceAmount = finalPrice - totalAdvanceAmount;

    // Clear or set advanceAmountController
    if (!isModifyMode) {
      advanceAmountController.clear();
    } else if (salesorder.advanceAmount != null &&
        salesorder.advanceAmount!.isNotEmpty) {
      advanceAmountController.text = salesorder.advanceAmount!.first.toString();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            width: 400, // Fixed width for premium look

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Premium Header with Gradient
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromARGB(255, 68, 121, 221), // Deep blue
                        Color.fromARGB(255, 58, 115, 212), // Royal blue
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm Order',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Review your order details',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Section
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Main Message
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF475569),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Please verify all details before confirming',
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Order Details Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Item Total
                              _buildDetailRow(
                                label: 'Item Total',
                                value: '₹$itemTotal',
                                icon: Icons.shopping_bag_outlined,
                                isHighlighted: false,
                              ),

                              if (customCharge > 0) ...[
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  label: 'Custom Charge',
                                  value: '₹$customCharge',
                                  icon: Icons.build_outlined,
                                  valueColor: const Color(0xFF059669),
                                ),
                              ],

                              if (deductedAmount > 0) ...[
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  label: 'Discount',
                                  value: '- ₹$deductedAmount',
                                  icon: Icons.discount_outlined,
                                  valueColor: const Color(0xFFDC2626),
                                ),
                              ],

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                  color: Color(0xFFE2E8F0),
                                  height: 1,
                                  thickness: 1,
                                ),
                              ),

                              // Final Price
                              _buildDetailRow(
                                label: 'Final Price',
                                value: '₹$finalPrice',
                                icon: Icons.price_check_rounded,
                                isBold: true,
                                valueColor: const Color(0xFF1E3C72),
                              ),

                              const SizedBox(height: 16),

                              // Additional Details Container
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    _buildCompactRow(
                                      label: 'Advance Paid',
                                      value: '₹$totalAdvanceAmount',
                                      icon: Icons.payments_outlined,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildCompactRow(
                                      label: 'Balance Due',
                                      value: '₹$balanceAmount',
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      isBold: true,
                                      valueColor: balanceAmount > 0
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF059669),
                                    ),
                                    if (pickedImages.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      _buildCompactRow(
                                        label: 'Images Attached',
                                        value: '${pickedImages.length}',
                                        icon: Icons.image_outlined,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons with Premium Styling
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await saveModifiedOrder(
                                salesorder,
                                increasedItems,
                                decreasedItems,
                                path,
                                pickedImages,
                                itemTotal,
                                totalAdvanceAmount,
                                balanceAmount,
                                context,
                                isModifyMode,
                              );
                            } catch (e, stack) {}
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3C72),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } // Helper widgets for consistent styling

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    bool isBold = false,
    bool isHighlighted = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9).withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF475569),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactRow({
    required String label,
    required String value,
    required IconData icon,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF475569),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  int _sendInvoiceCallCount = 0;
  // 🔹 Global Counters & Trackers
  int serverSendCount = 0;
  int clientSendCount = 0;
  int clientReceiveCount = 0;

  final Map<String, int> serverSendTracker = {};
  final Map<String, int> clientSendTracker = {};
  final Map<String, int> clientReceiveTracker = {};

  void exitModifyMode() {
    isModifyMode.value = false;
    globals.quantityChangesNotifier.value = {};
    globals.quantityChangesNotifier.value.clear();

    notifyListeners();
  }

  Future<void> saveModifiedOrder(
    SalesOrderDisplay originalOrder,
    List<Map<String, dynamic>> increasedItems,
    List<Map<String, dynamic>> decreasedItems,
    String? audioPath,
    List<File> newImages,
    double itemTotal,
    double totalAdvance,
    double balanceAmount,
    BuildContext context,
    bool isModified,
  ) async {
    try {
      // STEP 1: Calculate modified item total
      double modifiedItemTotal = calculateModifiedItemTotal(
        originalOrder,
        increasedItems,
        decreasedItems,
      );

      // STEP 2: Custom charges
      final editProvider = context.read<EditCustomerScreenProvider>();
      final Map<String, double> currentCharges =
          editProvider.customChargeValues;

      List<String> customChargeTypes = [];
      List<double> customChargeValues = [];

      currentCharges.forEach((type, value) {
        if (value > 0) {
          customChargeTypes.add(type);
          customChargeValues.add(value);
        }
      });

      double customChargeTotal = customChargeValues.fold(0, (a, b) => a + b);

      double deductedAmount = originalOrder.discountAmount ?? 0;

      double totalAmount2 = modifiedItemTotal + customChargeTotal;
      double finalPrice =
          modifiedItemTotal + customChargeTotal - deductedAmount;
      double computedBalanceAmount = finalPrice - totalAdvance;

      // STEP 3: Original order (for history)
      final jsonSalesOrder = jsonEncode({
        "data": originalOrder.toJson(),
        "deviceName": globals.deviceName,
        "type": "modifySaleOrder",
        "salesOrderId": originalOrder.salesOrderId,
        "sync": "No",
        "edit": "No",
      });

      // STEP 4: Modified order data
      final modifiedOrderData = _mergeOrderModifications(
        originalOrder,
        increasedItems,
        decreasedItems,
        modifiedItemTotal,
        totalAdvance,
        computedBalanceAmount,
        audioPath ?? originalOrder.audio,
        newImages,
        dateController.text,
        timeController.text,
        customerNameController.text,
        mobileNoController.text,
        addressController.text,
        searchController.text,
        customChargeTypes,
        customChargeValues,
        deductedAmount,
        customChargeTotal,
        totalAmount2,
        finalPrice,
      );

      // 🔥 STEP 5: Decide editAbout dynamically
      final editAboutLabel = getEditAboutLabel(
        originalOrder: originalOrder,
        modifiedData: modifiedOrderData,
        increasedItems: increasedItems,
        decreasedItems: decreasedItems,
      );

      // STEP 6: Patch sale order payload
      final jsonModifiedSalesOrder = jsonEncode({
        "data": modifiedOrderData,
        "deviceName": globals.deviceName,
        "type": "patchSaleOrder",
        "saleOrderNo": originalOrder.saleOrderNo,
        "sync": "No",
        "editAbout": editAboutLabel, // ✅ DYNAMIC
        "edit": "Yes",
      });

      // STEP 7: Connectivity handling
      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );

      if (connectivityProvider.isConnected) {
        await sendataToServer(jsonDecode(jsonSalesOrder));
        await sendataToServer(jsonDecode(jsonModifiedSalesOrder));
      } else {
        handleModifyOrder(jsonDecode(jsonSalesOrder));
        handlePatchSaleOrder(jsonDecode(jsonModifiedSalesOrder));
      }

      // STEP 8: Success message
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order modification completed successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        });
      }

      // STEP 9: Cleanup
      increasedItems.clear();
      decreasedItems.clear();
      globals.quantityChangesNotifier.value = {};
      serverSendTracker.clear();
      clientSendTracker.clear();
      clientReceiveTracker.clear();

      exitModifyMode();
      notifyListeners();
    } catch (e, stackTrace) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  String getEditAboutLabel({
    required SalesOrderDisplay originalOrder,
    required Map<String, dynamic> modifiedData,
    required List<Map<String, dynamic>> increasedItems,
    required List<Map<String, dynamic>> decreasedItems,
  }) {
    // 1️⃣ Order changes
    bool isOrderChanged =
        increasedItems.isNotEmpty || decreasedItems.isNotEmpty;

    // 2️⃣ Customer changes (SAFE CHECK)
    bool isCustomerChanged = false;

    if (modifiedData.containsKey('customerName') &&
        modifiedData['customerName'] != null &&
        modifiedData['customerName'].toString().trim().isNotEmpty &&
        modifiedData['customerName'] != originalOrder.customerName) {
      isCustomerChanged = true;
    }

    if (modifiedData.containsKey('customerNumber') &&
        modifiedData['customerNumber'] != null &&
        modifiedData['customerNumber'].toString().trim().isNotEmpty &&
        modifiedData['customerNumber'] != originalOrder.customerNumber) {
      isCustomerChanged = true;
    }

    if (modifiedData.containsKey('address') &&
        modifiedData['address'] != null &&
        modifiedData['address'].toString().trim().isNotEmpty &&
        modifiedData['address'] != originalOrder.address) {
      isCustomerChanged = true;
    }

    // 3️⃣ Decide label
    if (isOrderChanged && isCustomerChanged) {
      return "Order & Customer Details Updated";
    } else if (isOrderChanged) {
      return "Order Updated";
    } else if (isCustomerChanged) {
      return "Customer Details Updated";
    } else {
      return "Order Updated"; // fallback
    }
  }

  // Helper function to calculate modified item total
  double calculateModifiedItemTotal(
    SalesOrderDisplay originalOrder,
    List<Map<String, dynamic>> increasedItems,
    List<Map<String, dynamic>> decreasedItems,
  ) {
    // Start with original item total
    double originalItemTotal = originalOrder.amount.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );
    double itemTotal = originalItemTotal;

    // Add increased items
    for (var item in increasedItems) {
      double itemAmount = calculateItemAmount(item);
      itemTotal += itemAmount;
    }

    // Subtract decreased items
    for (var item in decreasedItems) {
      double itemAmount = calculateItemAmount(item);
      itemTotal -= itemAmount;
    }

    return itemTotal;
  }

  // Helper: Calculate item amount with detailed logs
  double calculateItemAmount(Map<String, dynamic> item) {
    final uom = item['uom']?.toString().toLowerCase() ?? '';
    final bool isKgUnit = uom == 'kg' || uom == 'kgs';
    final double itemWeight = (item['weight'] ?? 0).toDouble();
    final double itemQty = (item['quantity'] ?? 0).toDouble();
    final double pricePerUnit = (item['price'] ?? 0).toDouble();

    double calculatedAmount = isKgUnit
        ? itemQty * itemWeight * pricePerUnit
        : itemQty * pricePerUnit;

    return calculatedAmount;
  }

  // Merge modifications with complete calculation logic
  Map<String, dynamic> _mergeOrderModifications(
    SalesOrderDisplay originalOrder,
    List<Map<String, dynamic>> increasedItems,
    List<Map<String, dynamic>> decreasedItems,
    double itemTotal,
    double totalAdvance,
    double balanceAmount,
    String? audioPath,
    List<File> newImages,
    String? newDeliveryDate,
    String? newDeliveryTime,
    String? customerName,
    String? customerMobile,
    String? customerAddress,
    String? employeeName,
    List<String> newCustomChargeTypes,
    List<double> newCustomChargeValues,
    double deductedAmount,
    double customChargeTotal,
    double totalAmount2,
    double finalPrice,
  ) {
    /// ---------------------------
    /// 1️⃣ Clone original order lists
    /// ---------------------------
    List<String> varianceNames = [...originalOrder.varianceName];
    List<String> itemNames = [...originalOrder.itemName];
    List<String> itemCodes = [...originalOrder.itemCode];
    List<int> qty = originalOrder.qty.map((e) => e.toInt()).toList();
    List<String> uom = [...originalOrder.uom];
    List<double> weights = originalOrder.weight
        .map((e) => e.toDouble())
        .toList();

    List<num> price = [...originalOrder.price];
    List<num> sellingPrice = [...originalOrder.sellingPrice];
    List<num> amount = [...originalOrder.amount];
    List<num> sellingAmount = [...originalOrder.sellingAmount];
    List<num> tax = [...originalOrder.tax];

    /// ---------------------------
    /// 2️⃣ Handle INCREASED items
    /// ---------------------------
    for (var item in increasedItems) {
      int index = varianceNames.indexOf(item['varianceName']);

      double addQty = (item['quantity'] ?? 0).toDouble();
      double addWeight = (item['weight'] ?? 0).toDouble();
      double unitPrice = (item['price'] ?? 0).toDouble();
      double sellPrice = (item['sellingPrice'] ?? unitPrice).toDouble();

      bool isKg = item['uom']?.toString().toLowerCase() == 'kg';
      double addAmount = isKg
          ? addQty * addWeight * sellPrice
          : addQty * sellPrice;

      if (index != -1) {
        /// Existing item → update
        qty[index] += addQty.toInt();
        amount[index] += addAmount;
        sellingAmount[index] += addAmount;
      } else {
        /// New item → ADD ALL REQUIRED FIELDS ✅
        varianceNames.add(item['varianceName']);
        itemNames.add(item['itemName']);
        itemCodes.add(item['itemCode']);
        qty.add(addQty.toInt());
        uom.add(item['uom']);
        weights.add(addWeight);
        price.add(unitPrice);
        sellingPrice.add(sellPrice);
        amount.add(addAmount);
        sellingAmount.add(addAmount);
        tax.add(item['tax']);
      }
    }

    /// ---------------------------
    /// 3️⃣ Handle DECREASED items
    /// ---------------------------
    for (var item in decreasedItems) {
      int index = varianceNames.indexOf(item['varianceName']);
      if (index == -1) continue;

      double subQty = (item['quantity'] ?? 0).toDouble();
      double subWeight = (item['weight'] ?? 0).toDouble();
      double sellPrice = (item['sellingPrice'] ?? price[index]).toDouble();

      bool isKg = item['uom']?.toString().toLowerCase() == 'kg';
      double subAmount = isKg
          ? subQty * subWeight * sellPrice
          : subQty * sellPrice;

      qty[index] -= subQty.toInt();
      amount[index] -= subAmount;
      sellingAmount[index] -= subAmount;

      /// If qty becomes zero → REMOVE item fully
      if (qty[index] <= 0) {
        varianceNames.removeAt(index);
        itemNames.removeAt(index);
        itemCodes.removeAt(index);
        qty.removeAt(index);
        uom.removeAt(index);
        weights.removeAt(index);
        price.removeAt(index);
        sellingPrice.removeAt(index);
        amount.removeAt(index);
        sellingAmount.removeAt(index);
        tax.removeAt(index);
      }
    }

    /// ---------------------------
    /// 4️⃣ Recalculate totals
    /// ---------------------------
    double recalculatedItemTotal = sellingAmount.fold(
      0,
      (sum, e) => sum + e.toDouble(),
    );

    /// ---------------------------
    /// 5️⃣ Prepare image paths
    /// ---------------------------
    List<String> imagePaths = [];
    if (newImages.isNotEmpty) {
      imagePaths = newImages.map((e) => e.path).toList();
    } else if (originalOrder.imagePaths != null) {
      imagePaths = List<String>.from(originalOrder.imagePaths!);
    }

    /// ---------------------------
    /// 6️⃣ Final payload
    /// ---------------------------
    return {
      'varianceName': varianceNames,
      'itemName': itemNames,
      'itemCode': itemCodes,
      'qty': qty,
      'uom': uom,
      'weight': weights,
      'price': price,
      'sellingPrice': sellingPrice,
      'amount': amount,
      'sellingAmount': sellingAmount,
      'tax': tax,

      'totalAmount': recalculatedItemTotal,
      'totalCustomCharge': customChargeTotal,
      'totalAmount2': totalAmount2,
      'finalPrice': finalPrice,
      'advanceAmount': [totalAdvance],
      'balanceAmount': balanceAmount,

      'customerName': customerName ?? originalOrder.customerName,
      'customerNumber': customerMobile ?? originalOrder.customerNumber,
      'customerAddress': customerAddress ?? originalOrder.address,

      'customChargeType': newCustomChargeTypes,
      'customCharge': newCustomChargeValues,

      'branchId': originalOrder.branchId,
      'branchName': originalOrder.branchName,
      'shiftId': originalOrder.shiftId,
      'aliasName': originalOrder.aliasName,

      'audioPath': audioPath ?? '',
      'imagePaths': imagePaths,

      'status': decreasedItems.isNotEmpty
          ? 'Pending Approval'
          : 'Confirm Order',
    };
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
      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );
      if (connectivityProvider.isConnected) {
        await sendataToServer(jsonDecode(jsonModifiedSalesOrder));
        await sendataToServer(jsonDecode(serverPatchData));
      } else {
        handleToApproveOrder(jsonDecode(jsonModifiedSalesOrder));
        handlePatchSaleOrder(jsonDecode(serverPatchData));
      }
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

  void setSelectedEvent(String? event) {
    selectedEvent = event;
    notifyListeners();
  }

  void setSelectedDeliveryType(String? newValue) {
    selectedDeliveryType = newValue;
    notifyListeners();
  }

  void setSelectedCustomChargeType(String? newValue) {
    selectedChargeType = newValue;
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
      increasedItems.value.add(itemInfo);
    } else if (newQty < originalQty) {
      decreasedItems.value.add(itemInfo);
    }
  }

  // Helper to remove item from increased/decreased lists
  void _removeFromModifiedLists(SalesOrderDisplay salesOrder, int index) {
    String itemName = salesOrder.varianceName[index];

    increasedItems.value.removeWhere(
      (item) =>
          item['varianceName'] == itemName &&
          item['originalQuantity'] == salesOrder.qty[index],
    );

    decreasedItems.value.removeWhere(
      (item) =>
          item['varianceName'] == itemName &&
          item['originalQuantity'] == salesOrder.qty[index],
    );
  }

  void addToIncreasedItems(SalesOrderDisplay order, int index, double newQty) {
    final item = _createItemMap(order, index, newQty);

    // Remove from decreased if exists
    decreasedItems.value.removeWhere(
      (i) =>
          i['varianceName'] == item['varianceName'] &&
          i['salesOrderId'] == item['salesOrderId'],
    );

    increasedItems.value.add(item);
    notifyListeners();
  }

  void addToDecreasedItems(SalesOrderDisplay order, int index, double newQty) {
    final item = _createItemMap(order, index, newQty);

    // Remove from increased if exists
    increasedItems.value.removeWhere(
      (i) =>
          i['varianceName'] == item['varianceName'] &&
          i['salesOrderId'] == item['salesOrderId'],
    );

    decreasedItems.value.add(item);
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
    final itemIndex = increasedItems.value.indexWhere(
      (i) =>
          i['varianceName'] == order.varianceName[index] &&
          i['salesOrderId'] == order.salesOrderId,
    );

    if (itemIndex != -1) {
      increasedItems.value[itemIndex]['newQty'] = newQty;
      increasedItems.value[itemIndex]['amount'] =
          (newQty - order.qty[index]) * order.price[index];
      notifyListeners();
    }
  }

  void updateDecreasedItems(SalesOrderDisplay order, int index, double newQty) {
    final itemIndex = decreasedItems.value.indexWhere(
      (i) =>
          i['varianceName'] == order.varianceName[index] &&
          i['salesOrderId'] == order.salesOrderId,
    );

    if (itemIndex != -1) {
      decreasedItems.value[itemIndex]['newQty'] = newQty;
      decreasedItems.value[itemIndex]['amount'] =
          (order.qty[index] - newQty) * order.price[index];
      notifyListeners();
    }
  }

  void updateItemInOrder(
    SalesOrderDisplay salesOrder, // ✅ Add this
    Map<String, dynamic> item,
    double difference,
    int originalIndex,
  ) {
    // --- Identify unit type ---
    bool isKgUnit =
        (item['varianceUom']?.toString().toLowerCase() == 'kg' ||
        item['varianceUom']?.toString().toLowerCase() == 'kgs');

    // --- Normalize existingQuantity ---
    double currentQuantity = (item['existingQuantity'] ?? 0.0).toDouble();

    // --- Normalize existingWeight ---
    double itemWeightRaw = (item['existingWeight'] ?? 0.0).toDouble();
    String weightUnit = (item['existingWeightUnit'] ?? '')
        .toString()
        .toLowerCase();
    double itemWeightKg = itemWeightRaw;

    if (weightUnit == 'g' || weightUnit == 'gram' || weightUnit == 'grams') {
      itemWeightKg = itemWeightRaw / 1000.0;
    }

    // --- Calculate unit price ---
    double pricePerKg = (item['variancePrice'] ?? 0.0).toDouble();
    double unitPrice = isKgUnit ? pricePerKg * itemWeightKg : pricePerKg;

    double calculateAmountForQty(double qty) => qty * unitPrice;

    // --- Check if item already exists ---
    int increasedIndex = increasedItems.value.indexWhere(
      (e) => e['varianceName'] == item['varianceName'],
    );
    int decreasedIndex = decreasedItems.value.indexWhere(
      (e) => e['varianceName'] == item['varianceName'],
    );

    // --- Existing modification value ---
    double modificationValue = 0.0;
    if (increasedIndex != -1) {
      modificationValue =
          (increasedItems.value[increasedIndex]['quantity'] ?? 0.0);
    } else if (decreasedIndex != -1) {
      modificationValue =
          -(decreasedItems.value[decreasedIndex]['quantity'] ?? 0.0);
    }

    // --- Compute new quantities ---
    double newQuantity = currentQuantity + modificationValue + difference;
    if (newQuantity < 0) return;

    double newModificationValue = newQuantity - currentQuantity;

    // --- Copy lists to trigger ValueNotifier ---
    List<Map<String, dynamic>> newIncreasedItems = List.from(
      increasedItems.value,
    );
    List<Map<String, dynamic>> newDecreasedItems = List.from(
      decreasedItems.value,
    );

    // --- Update existing or add new entries ---
    if (increasedIndex != -1 && newModificationValue > 0) {
      newIncreasedItems[increasedIndex]['quantity'] = newModificationValue;
      newIncreasedItems[increasedIndex]['amount'] = calculateAmountForQty(
        newModificationValue,
      );
    } else if (decreasedIndex != -1 && newModificationValue < 0) {
      newDecreasedItems[decreasedIndex]['quantity'] = -newModificationValue;
      newDecreasedItems[decreasedIndex]['amount'] = calculateAmountForQty(
        -newModificationValue,
      );
    } else {
      if (increasedIndex != -1) newIncreasedItems.removeAt(increasedIndex);
      if (decreasedIndex != -1) newDecreasedItems.removeAt(decreasedIndex);

      if (newModificationValue > 0) {
        newIncreasedItems.add({
          'varianceName': item['varianceName'],
          'itemName': item['itemName'],
          'weight': itemWeightKg * newModificationValue,
          'quantity': newModificationValue,
          'uom': item['varianceUom'],
          'price': item['variancePrice'],
          'tax': item['variancetax'] ?? 0,
          'itemCode': item['varianceitemCode'],
          'amount': calculateAmountForQty(newModificationValue),
          'originalQuantity': item['existingQuantity'],
          'originalAmount': item['existingAmount'],
        });
      } else if (newModificationValue < 0) {
        newDecreasedItems.add({
          'varianceName': item['varianceName'],
          'itemName': item['itemName'],
          'weight': itemWeightKg * (-newModificationValue),
          'quantity': -newModificationValue,
          'uom': item['varianceUom'],
          'price': item['variancePrice'],
          'tax': item['variancetax'] ?? 0,
          'itemCode': item['varianceitemCode'],
          'amount': calculateAmountForQty(-newModificationValue),
          'originalQuantity': item['existingQuantity'],
          'originalAmount': item['existingAmount'],
        });
      }
    }

    // --- Remove zero-quantity entries ---
    newIncreasedItems.removeWhere((e) => (e['quantity'] ?? 0) <= 0);
    newDecreasedItems.removeWhere((e) => (e['quantity'] ?? 0) <= 0);

    // --- Assign new lists to ValueNotifiers ---
    increasedItems.value = newIncreasedItems;
    decreasedItems.value = newDecreasedItems;

    // --- Recalculate modified total ---
    modifiedTotal.value = calculateModifiedTotal(salesOrder);
  }
}

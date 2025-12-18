import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Provider/bottomNavprovider.dart';
import 'package:yenpos/Global/Provider/employee_provider.dart';
import 'package:yenpos/Mode_page/bottomNavigation_Regular_Page/bottom_navigation_bar_regular_mode.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/kotpreinvoice/components/globalAppbar.dart';
import 'package:yenpos/kotpreinvoice/providers/order_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/pax_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/timerProvider.dart';
import 'package:yenpos/kotpreinvoice/providers/upi_provider.dart';
import 'package:yenpos/kotpreinvoice/screens/cancelOrderScreen.dart';
import 'package:yenpos/kotpreinvoice/screens/preInvoiceTAb.dart';
import 'package:yenpos/kotpreinvoice/widgets/holdOrder.dart';
import 'package:yenpos/kotpreinvoice/widgets/salesInvoicePayandPrint.dart';
import 'package:yenpos/more_page/more_page.dart';
import 'package:yenpos/more_page/widgets/configuration.dart';
import 'package:yenpos/printer_screen/kotPrint.dart';
import 'package:yenpos/regular_mode_page/widget/emp_search.dart';
import '../../kotpreinvoice/providers/bottomNavprovider.dart';
import '../services/stockUpdateService.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../providers/cartprovider.dart';
import '../providers/printer_provider.dart';
import '../providers/product_provider.dart';
import '../components/flushbar.dart';
import '../models/fetchDiningTax.dart';
import 'package:yenpos/Global/globals_data.dart';
import '../providers/hold_order.dart';
import '../providers/order_type_provider.dart';
import '../providers/search_provider.dart';
import '../providers/submissionProvider.dart';
import '../components/capitalizeWord.dart';
import '../widgets/customerNoPopup.dart';
import '../widgets/product_Search/pax_dropdown.dart';
import '../widgets/settingsScreen.dart';
import 'products_card_screen.dart';
import 'table_screen.dart';

// 🔔 ChangeNotifier to manage dialog state
class CartItemDialogState extends ChangeNotifier {
  List<String> type;
  List<List<String>> addons;
  List<List<int>> addonQuantities;
  List<String> variants;
  List<bool> toggleRemarks;
  List<String> remarks;
  List<int> configQty;
  TextEditingController remarkController;
  FocusNode focusNode;

  CartItemDialogState({
    required this.type,
    required this.addons,
    required this.addonQuantities,
    required this.variants,
    required this.toggleRemarks,
    required this.remarks,
    required this.configQty,
    required this.remarkController,
    required this.focusNode,
  });

  void updateType(int index, bool isParcel) {
    if (index < type.length) {
      type[index] = isParcel ? "Parcel" : "";
      notifyListeners();
    }
  }

  void updateAddOn(int index, String addOnName, bool add, int quantity) {
    if (index < addons.length) {
      if (add) {
        if (!addons[index].contains(addOnName)) {
          addons[index].add(addOnName);
          addonQuantities[index].add(quantity);
        }
      } else {
        final addOnIndex = addons[index].indexOf(addOnName);
        if (addOnIndex != -1) {
          addons[index].removeAt(addOnIndex);
          addonQuantities[index].removeAt(addOnIndex);
        }
      }
      notifyListeners();
    }
  }

  void updateAddOnQuantity(int itemIndex, int addOnIndex, int newQuantity) {
    if (itemIndex < addonQuantities.length &&
        addOnIndex < addonQuantities[itemIndex].length) {
      addonQuantities[itemIndex][addOnIndex] = newQuantity;
      notifyListeners();
    }
  }

  void updateVariant(int index, String variant) {
    if (index < variants.length) {
      variants[index] = variant;
      notifyListeners();
    }
  }

  void updateToggleRemark(int index, bool value) {
    if (index < toggleRemarks.length) {
      toggleRemarks[index] = value;
      notifyListeners();
    }
  }

  void updateRemark(int index, String remark) {
    if (index < remarks.length) {
      remarks[index] = remark;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    remarkController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

// ignore: camel_case_types
class productCardViewList extends StatefulWidget {
  final String tableNumber;
  final String seat;
  final String areaName;
  final String? seathiveOrderId;

  const productCardViewList({
    super.key,
    required this.tableNumber,
    required this.seat,
    required this.areaName,
    required this.seathiveOrderId,
  });

  @override
  _productCardViewListState createState() => _productCardViewListState();
}

// ignore: camel_case_types
class _productCardViewListState extends State<productCardViewList> {
  TextEditingController mobileController = TextEditingController();
  String customerPhoneNumber = "";
  late WebSocketChannel channel;
  String? storedDeviceId;
  // List isOpenList = [1 , 2 , 3];

  Future<void> loadDeviceCode() async {
    var box = Hive.box('deviceData');
    setState(() {
      storedDeviceId = box.get('deviceCode');
    });
  }

  Future<void> sendDataToServer(Map<String, dynamic> data) async {
    final jsonData = jsonEncode(data);
    try {
      channel.sink.add(jsonData);
      debugPrint("📤 Sending data to server: $jsonData");
    } catch (e) {
      debugPrint('❌ Error sending data to server: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending data: $e')));
      }
    }
  }

  // Define lists to store values
  List<String> itemNames = [];
  List<String> varianceNames = [];
  List<String> varianceItemCodes = [];
  List<double> prices = [];
  List<double> weights = [];
  List<int> quantities = [];
  List<double> amounts = [];
  List<double> taxes = [];
  List<String> uoms = [];
  List<Map<String, dynamic>> parcelItems = [];
  List<String> itemRemark = [];
  String? orderRemark = "";
  String? partiallyCancelled = "";
  List<Map<String, dynamic>> addOnsList = [];

  Future<void> _processOrder(String phoneNumber) async {
    // Helper function to safely parse numbers to double
    double parseDouble(dynamic value, {double fallback = 0.0}) {
      if (value == null) return fallback;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      debugPrint(
        "⚠️ Unable to parse value to double: $value (type: ${value.runtimeType})",
      );
      return fallback;
    }

    try {
      final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      final orderTypeProvider = Provider.of<OrderTypeProviderDine>(
        context,
        listen: false,
      );
      final employeeProvider = Provider.of<EmployeeProvider>(
        context,
        listen: false,
      );
      final paxProvider = Provider.of<PaxProviderDine>(
        context,
        listen: false,
      ); // Added PaxProvider
      final salesState = Provider.of<SalesInvoiceState>(context, listen: false);
      final employeeName = salesState.selectedEmployeeFirstName ?? "";

      final now = DateTime.now();
      final formattedDate = DateFormat('dd-MM-yyyy').format(now);
      final formattedTime = DateFormat('hh:mm:ss a').format(now);

      double totalAddonsAmount = 0.0;
      double diningTaxPercentage = getTaxPercentage();
      List<Map<String, dynamic>> configs = [];
      Map<String, double> varianceWeights = {};

      // Clear previous data
      itemNames.clear();
      varianceNames.clear();
      varianceItemCodes.clear();
      prices.clear();
      weights.clear();
      quantities.clear();
      amounts.clear();
      taxes.clear();
      uoms.clear();
      parcelItems.clear();
      itemRemark.clear();
      addOnsList.clear();

      debugPrint(
        "🛒 Processing cart with ${cartProvider.cart.length} items...",
      );

      for (var entry in cartProvider.cart.entries) {
        try {
          final product = productProvider.products.firstWhere(
            (p) => p.varianceName == entry.key,
            orElse: () {
              debugPrint(
                "❌ Product not found for variance ${entry.key}, skipping...",
              );
              throw Exception("Product not found for variance ${entry.key}");
            },
          );

          itemNames.add(product.name);
          varianceNames.add(product.varianceName);
          varianceItemCodes.add(product.varianceitemCode);

          // Safe price parsing
          double price = parseDouble(product.price);
          prices.add(price);

          // Quantity parsing
          int quantity = 0;
          var rawQty = entry.value['qty'] ?? 0;
          if (rawQty is String) {
            quantity = int.tryParse(rawQty) ?? 0;
          } else if (rawQty is int) {
            quantity = rawQty;
          } else {
            debugPrint(
              "⚠️ Unexpected quantity type: ${rawQty.runtimeType}, defaulted to 0",
            );
          }
          quantities.add(quantity);

          String uom = product.variance_Uom;
          uoms.add(uom);

          // Safe weight parsing
          double weight = parseDouble(entry.value['weight']);
          if (uom.toLowerCase() == 'Kgs') weight /= 1000;
          weights.add(weight);

          double itemTotal = (uom.toLowerCase() == 'Kgs')
              ? price * quantity * weight
              : price * quantity;

          taxes.add(diningTaxPercentage);
          varianceWeights[product.varianceName] = weight;

          // Add-ons, quantities, variants, type, remarks, configQty
          List<List<String>> addons = List.generate(
            quantity,
            (i) => (entry.value['addons']?.length ?? 0) > i
                ? entry.value['addons'][i]
                : [],
          );

          List<List<int>> addonQuantities = List.generate(
            quantity,
            (i) => (entry.value['addonQuantities']?.length ?? 0) > i
                ? entry.value['addonQuantities'][i]
                : [],
          );

          List<String> variants = List.generate(
            quantity,
            (i) => (entry.value['variants']?.length ?? 0) > i
                ? entry.value['variants'][i]
                : "",
          );

          List<String> type = List.generate(
            quantity,
            (i) => (entry.value['type']?.length ?? 0) > i
                ? entry.value['type'][i]
                : "",
          );

          List<String> remarks = List.generate(
            quantity,
            (i) => (entry.value['remarks']?.length ?? 0) > i
                ? entry.value['remarks'][i]
                : "",
          );

          List<int> configQty = List.generate(
            quantity,
            (i) => (entry.value['configQty']?.length ?? 0) > i
                ? entry.value['configQty'][i]
                : 1,
          );

          // Calculate add-on prices safely
          List<List<double>> addOnPrices = List.generate(quantity, (i) {
            List<double> pricesForItem = [];
            for (int j = 0; j < addons[i].length; j++) {
              final addOnName = addons[i][j];
              final addOnQty = (addonQuantities[i].length > j)
                  ? addonQuantities[i][j]
                  : 1;
              final addOnData = productProvider.addons.firstWhere(
                (a) => a['addOn'].toString() == addOnName,
                orElse: () => {'value': 0},
              );
              final priceForAddon = parseDouble(addOnData['value']) * addOnQty;
              pricesForItem.add(priceForAddon);
              totalAddonsAmount += priceForAddon;
              debugPrint("➕ Add-on: $addOnName x $addOnQty = ₹$priceForAddon");
            }
            return pricesForItem;
          });

          // Add add-on prices to item total
          itemTotal += addOnPrices.fold(
            0,
            (sum, list) => sum + list.fold(0, (s, p) => s + p),
          );
          amounts.add(itemTotal);

          debugPrint(
            "🧾 Item processed: ${product.name} | Qty: $quantity | ItemTotal: ₹$itemTotal",
          );

          // Build config
          Map<String, dynamic> config = {
            "varianceName": product.varianceName,
            "weight": weight,
            "configQty": configQty,
            "addOn": addons.isEmpty ? [[]] : addons,
            "addOnQuantities": addonQuantities.isEmpty ? [[]] : addonQuantities,
            "variance": variants.contains('Default') ? [""] : variants,
            "type": type.isEmpty ? [""] : type,
            "remark": remarks.isEmpty ? [""] : remarks,
            "addOnPrice": addOnPrices.isEmpty ? [[]] : addOnPrices,
          };
          configs.add(config);
        } catch (e, st) {
          debugPrint("⚠️ Error processing cart entry ${entry.key}: $e\n$st");
        }
      }

      final double totalAmount = amounts.fold(0.0, (sum, item) => sum + item);
      debugPrint("💰 Total order amount including addons: ₹$totalAmount");

      // Get pax from PaxProvider
      String paxValue = paxProvider.selectedPax;
      if (paxValue.isEmpty) {
        debugPrint("⚠️ Pax value is empty, defaulting to '1'");
        paxValue = "1";
      }

      final order = {
        'type': 'order',
        'date': formattedDate,
        'time': formattedTime,
        'preinvoiceTime': '',
        'branchName': aliasname,
        'table': widget.tableNumber,
        'seat': widget.seat,
        'areaName': widget.areaName,
        'deviceId': storedDeviceId,
        'itemNames': itemNames.isNotEmpty ? itemNames : [''],
        'varianceNames': varianceNames.isNotEmpty ? varianceNames : [''],
        'varianceItemCodes': varianceItemCodes.isNotEmpty
            ? varianceItemCodes
            : [''],
        'prices': prices.isNotEmpty ? prices : [0.0],
        'weights': weights.isNotEmpty ? weights : [0.0],
        'quantities': quantities.isNotEmpty ? quantities : [0],
        'cancelledQty': List.filled(itemNames.length, 0),
        'amounts': amounts.isNotEmpty ? amounts : [0.0],
        'taxes': taxes.isNotEmpty ? taxes : [0.0],
        'uoms': uoms.isNotEmpty ? uoms : [''],
        'pax': paxValue, // Use PaxProvider.selectedPax
        'status': 'active',
        'waiter': createdBy.isNotEmpty ? createdBy : employeeName,
        'orderType': orderTypeProvider.orderType,
        'totalAmount': totalAmount,
        'seathiveOrderId': widget.seathiveOrderId ?? '',
        'itemRemark': itemRemark.isNotEmpty ? itemRemark : [''],
        'orderRemark': orderRemark ?? '',
        'partiallyCancelled': partiallyCancelled ?? '',
        'config': configs.isNotEmpty ? configs : [{}],
        'customerPhoneNumber': phoneNumber.isNotEmpty ? phoneNumber : '',
        'sync': 'No',
        'edit': 'No',
        'statusEdited': 'false',
        'fieldsEdited': 'false',
        'userName': userName,
      };

      debugPrint("📤 Sending order data to server: ${jsonEncode(order)}");

      try {
        await sendDataToServer(order);
        debugPrint("✅ Order sent successfully!");

        // 🧮 Decrease stock after order success
        await decreaseLocalHiveStock(
          branchAlias: aliasname,
          varianceCodes: List<String>.from(varianceItemCodes),
          varianceNames: List<String>.from(varianceNames),
          stockUpdates: List<int>.from(quantities),
        );

        // final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        // orderProvider.processOrderData(order);

        debugPrint("📦 Local stock decreased successfully after order.");
      } catch (e, st) {
        debugPrint("❌ Failed to send order: $e\n$st");
        throw e; // Re-throw to handle in submitOrder
      }

      Navigator.pop(context);
      cartProvider.clearCart();
      debugPrint("🧹 Cart cleared and order processed successfully!");
    } catch (e, st) {
      debugPrint("🔥 Fatal error in _processOrder: $e\n$st");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Something went wrong during order processing!"),
          ),
        );
      }
      throw e; // Re-throw to handle in submitOrder
    }
  }

  List<Map<String, dynamic>> _getItemsFromConfirmedOrders() {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      // Find confirmed orders for this table and seat
      final confirmedOrders = orderProvider.orders
          .where(
            (order) =>
                order['table'] == widget.tableNumber &&
                order['seat'] == widget.seat &&
                order['status'] == 'confirm',
          )
          .toList();

      if (confirmedOrders.isEmpty) {
        debugPrint(
          '⚠️ No confirmed orders found for table ${widget.tableNumber} seat ${widget.seat}',
        );
        return [];
      }

      // Convert confirmed orders to the format expected by SalesInvoicePayAndPrint
      final List<Map<String, dynamic>> items = [];

      for (final order in confirmedOrders) {
        print("order is ......... $order");
        try {
          final computedAmounts = List.generate(
            (order['prices'] as List?)?.length ?? 0,
            (i) =>
                ((order['prices']?[i] ?? 0.0) as num).toDouble() *
                ((order['quantities']?[i] ?? 0.0) as num).toDouble(),
          );

          final mappedOrder = <String, dynamic>{
            'itemName': order['itemNames'] ?? [],
            'varianceitemCode': order['varianceItemCodes'] ?? [],
            'varianceName': order['varianceNames'] ?? [],
            'qty': order['quantities'] ?? [],
            'weight': order['weights'] ?? [],
            'tax': order['taxes'] ?? [],
            'uom': order['uoms'] ?? [],
            'table': order['table'] ?? '',
            'seat': order['seat'] ?? '',
            'hiveOrderId': order['hiveOrderId'] ?? '',
            'waiter': order['waiter'] ?? '',
            'price': order['prices'] ?? [],
            'amount': computedAmounts,
            'seathiveOrderId': order['seathiveOrderId'] ?? '',
          };

          items.add(mappedOrder);
          debugPrint(
            '✅ Added order to invoice items: ${mappedOrder['itemName']}',
          );
        } catch (e, st) {
          debugPrint('⚠️ Error mapping order for invoice: $e\n$st');
        }
      }

      debugPrint('📦 Prepared ${items.length} confirmed orders for invoice');
      return items;
    } catch (e, stack) {
      debugPrint('❌ Error getting items from confirmed orders: $e\n$stack');
      return [];
    }
  }

  // Add this method inside your _productCardViewListState class

  @override
  void initState() {
    super.initState();
    print("🚀 initState() called – starting WebSocket connection setup...");

    try {
      print("🌐 Attempting to connect WebSocket to ws://$serverip:$port");
      channel = IOWebSocketChannel.connect('ws://$serverip:$port');
      print("✅ WebSocket connected successfully to ws://$serverip:$port");
    } catch (e) {
      print("❌ WebSocket connection failed: $e");
    }

    print("📱 Loading device code...");
    loadDeviceCode();
    print("✅ Device code load initiated.");
  }

  @override
  void dispose() {
    mobileController.dispose();
    channel.sink.close();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProviderKOT>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final printerProvider = Provider.of<PrinterProviderDine>(context);
    final employeeProvider = Provider.of<EmployeeProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final ValueNotifier<Map<String, dynamic>>? productCardDataNotifier;
    final ValueNotifier<bool>? showProductCardNotifier;

    void submitOrder(String phoneNumber) {
      try {
        final holdOrderProvider = Provider.of<HoldOrderProvider>(
          context,
          listen: false,
        );
        final submissionProvider = Provider.of<SubmissionProviderDine>(
          context,
          listen: false,
        );

        if (cartProvider.cart.isEmpty) {
          try {
            showCustomFlushbar(
              context,
              'Please add items to the cart!',
              type: FlushbarType.warning,
            );
            print("⚠️ Cart is empty → Flushbar shown");
          } catch (e, st) {
            print("❌ Error showing flushbar: $e\n$st");
          }

          return;
        }

        try {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: const Text(
                  "Confirm Submission",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Text(
                  "Are you sure you want to submit the order for ${widget.tableNumber}?",
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Cancel"),
                    onPressed: () {
                      try {
                        Navigator.of(context).pop();
                        print("❎ Submission cancelled by user");
                      } catch (e, st) {
                        print("❌ Error closing Cancel dialog: $e\n$st");
                      }
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      backgroundColor: const Color(0xFFA5D6A7),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      submissionProvider.startSubmitting();
                      print("🟢 Started order submission");

                      try {
                        await _processOrder(phoneNumber);
                        print("✅ Order processed successfully");

                        final timerProvider = Provider.of<TimerProvider>(
                          context,
                          listen: false,
                        );
                        timerProvider.startTimer(
                          widget.tableNumber,
                          widget.seat,
                        );
                        print(
                          '⏰ Timer started for table: ${widget.tableNumber}, seat: ${widget.seat} (order placed)',
                        );
                      } catch (e, st) {
                        print("❌ Error processing order: $e\n$st");
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Error processing order!"),
                            ),
                          );
                        }
                        return;
                      } finally {
                        submissionProvider
                            .stopSubmitting(); // ✅ Reset submitting state
                      }

                      if (!context.mounted) return;

                      try {
                        Provider.of<BottomNavProvider>(
                          context,
                          listen: false,
                        ).updateIndex(2);
                        print("📤 Navigated to TableScreen");
                      } catch (e, st) {
                        print("❌ Error navigating to TableScreen: $e\n$st");
                      }

                      try {
                        holdOrderProvider.removeHoldOrder(
                          widget.tableNumber,
                          widget.seat,
                        );
                        print(
                          "🗑️ Removed hold order for table ${widget.tableNumber}, seat ${widget.seat}",
                        );
                      } catch (e, st) {
                        print("❌ Error removing hold order: $e\n$st");
                      }

                      try {
                        Provider.of<SearchProviderDine>(
                          context,
                          listen: false,
                        ).clearSearchQuery();
                        print("🔍 Cleared search query");
                      } catch (e, st) {
                        print("❌ Error clearing search query: $e\n$st");
                      }

                      try {
                        Provider.of<PaxProviderDine>(
                          context,
                          listen: false,
                        ).resetPax();
                        print("👥 Reset Pax count");
                      } catch (e, st) {
                        print("❌ Error resetting pax: $e\n$st");
                      }
                      final eventProvider = Provider.of<ProductEventProvider>(
                        context,
                        listen: false,
                      );
                      debugPrint('🚀 Submitting order...');
                      debugPrint('....Order is submitted....');

                      eventProvider.addEvent(
                        ProductEvent(
                          action: 'close_overlay',
                          tableNumber: widget.tableNumber,
                          seat: widget.seat,
                          areaName: widget.areaName,
                        ),
                      );
                      cartProvider.clearTableSeat();
                      ValueListenableBuilder4(
                        valueListenable1: cartProvider.currentTableNumber,
                        valueListenable2: cartProvider.currentSeat,
                        valueListenable3: cartProvider.currentAreaName,
                        valueListenable4: cartProvider.currentSeathiveOrderId,
                        builder:
                            (
                              context,
                              tableNum,
                              seatVal,
                              areaNameVal,
                              seathiveId,
                              _,
                            ) {
                              return RepaintBoundary(
                                child: productCardViewList(
                                  tableNumber: tableNum,
                                  seat: seatVal,
                                  areaName: areaNameVal,
                                  seathiveOrderId: seathiveId,
                                ),
                              );
                            },
                      );

                      cartProvider.clearCart();
                      final orderProvider = Provider.of<OrderProvider>(
                        context,
                        listen: false,
                      );
                      orderProvider.chargeSubmit = true;
                    },
                    child: const Text("Confirm"),
                  ),
                ],
              );
            },
          );
        } catch (e, st) {
          print("❌ Error showing submission dialog: $e\n$st");
        }
      } catch (e, st) {
        print("🔥 Fatal error in submitOrder method: $e\n$st");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Something went wrong!")),
          );
        }
      }
    }

    void handleSubmit(BuildContext context, cartProvider, printerProvider) {
      try {
        List<String> missingItemIps = [];
        bool hasOverallPrinter = false;

        try {
          hasOverallPrinter = printerProvider.getOverallPrinterIp() != null;
          print(
            "🖨️ Overall printer status: ${hasOverallPrinter ? 'Configured' : 'Not Configured'}",
          );
        } catch (e, st) {
          print("❌ Error checking overall printer IP: $e\n$st");
        }

        try {
          cartProvider.cart.forEach((productId, cartItem) {
            final itemName = productId;
            try {
              final ip = printerProvider.getPrinterIpForItem(itemName);
              if (ip == null) {
                missingItemIps.add(itemName);
                print("⚠️ Missing printer IP for item: $itemName");
              }
            } catch (e, st) {
              print("❌ Error getting printer IP for $itemName: $e\n$st");
              missingItemIps.add(itemName);
            }
          });
        } catch (e, st) {
          print("❌ Error iterating over cart items: $e\n$st");
        }

        final salesState = Provider.of<SalesInvoiceState>(
          context,
          listen: false,
        );
        final employeeName = salesState.selectedEmployeeFirstName ?? "";


        if (employeeName.isEmpty) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Please select a Sales Person"),
                duration: Duration(seconds: 2),
              ),
            );

          } catch (e) {
            debugPrint("Error is $e");
          }
        }

        if (!hasOverallPrinter || missingItemIps.isNotEmpty) {
          try {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Missing Printer Configuration'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasOverallPrinter || missingItemIps.isNotEmpty)
                      const Text(
                        'Please set an overall and itemwise printer IP address.',
                      ),
                    if (missingItemIps.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Missing IP for the following items:'),
                            ...missingItemIps
                                .map((item) => Text('- $item'))
                                .toList(),
                          ],
                        ),
                      ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('OK'),
                    onPressed: () {
                      try {
                        Navigator.of(context).pop();
                        print("✅ Closed missing printer dialog");
                      } catch (e, st) {
                        print("❌ Error closing dialog: $e\n$st");
                      }
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      backgroundColor: Colors.green[200],
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Set IP'),
                    onPressed: () {
                      try {
                        Provider.of<BottomNavProvider>(
                          context,
                          listen: false,
                        ).updateIndex(5);

                        Navigator.of(context).pop();
                      } catch (e, st) {
                        print(e);
                      }
                    },
                  ),
                ],
              ),
            );
          } catch (e, st) {
            print("❌ Error showing missing printer dialog: $e\n$st");
          }
        } else {
          try {
            print(
              "📤 Submitting Order with Phone Number: $customerPhoneNumber",
            );
            submitOrder(customerPhoneNumber);
          } catch (e, st) {
            print("❌ Error during order submission: $e\n$st");
          }
        }
      } catch (e, st) {
        print("🔥 Fatal error in handleSubmit: $e\n$st");
      }
    }

    Widget _buildBottomButtons({
      required bool isLockedTableView,
      required CartProviderKOT cartProvider,
      required OrderProvider orderProvider,
      required PrinterProviderDine printerProvider,
    }) {
      if (isLockedTableView) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(
                  builder: (context) {
                    double totalAmount = 0.0;

                    // Calculate total amount from confirmed orders
                    final confirmedOrders = orderProvider.orders
                        .where(
                          (order) =>
                              order['table'] == widget.tableNumber &&
                              order['seat'] == widget.seat &&
                              order['status'] == 'confirm',
                        )
                        .toList();

                    if (confirmedOrders.isNotEmpty) {
                      for (final order in confirmedOrders) {
                        totalAmount += (order['totalAmount'] ?? 0.0).toDouble();
                      }
                    }

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElevatedButton(
                          onPressed: () {
                            try {
                              final upiProvider = Provider.of<UpiProviderDine>(
                                context,
                                listen: false,
                              );

                              if (upiProvider.isUpiEnabled) {
                                // Get the items from confirmed orders
                                final items = _getItemsFromConfirmedOrders();

                                if (items.isEmpty) {
                                  showCustomFlushbar(
                                    context,
                                    'No confirmed orders found for this table',
                                    type: FlushbarType.warning,
                                  );
                                  return;
                                }

                                // Open SalesInvoicePayAndPrint as dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    alignment: Alignment.centerLeft,
                                    backgroundColor: Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width *
                                            0.5,
                                        child: SalesInvoicePayAndPrint(
                                          totalAmount: totalAmount,
                                          items: items,
                                          branchName: branchName,
                                          deviceCode: storedDeviceId ?? '',
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                debugPrint('⚠️ UPI is disabled.');
                                if (context.mounted) {
                                  showCustomFlushbar(
                                    context,
                                    'Please enable UPI to proceed.',
                                    type: FlushbarType.error,
                                  );
                                }
                              }
                            } catch (e, stack) {
                              debugPrint(
                                '❌ Error during charge navigation: $e',
                              );
                              debugPrint('🧱 Stack trace: $stack');
                              if (context.mounted) {
                                showCustomFlushbar(
                                  context,
                                  'Failed to open invoice: $e',
                                  type: FlushbarType.error,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 95,
                              vertical: 20,
                            ),
                          ),
                          child: Text(
                            'Charge ₹${totalAmount.round()}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: AbsorbPointer(
                    absorbing: true,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 10),
                      child: HoldOrdersDropdown(),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10, right: 10),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            insetPadding: const EdgeInsets.all(30),
                            child: SizedBox(
                              width: 700,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          "Cancelled Orders",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    child: SizedBox(
                                      height: 600,
                                      child: const CanceledOrdersScreen(),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[300],
                                            foregroundColor: Colors.black,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text("Close"),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        "Cancel Orders",
                        style: TextStyle(
                          fontSize: 15,
                          letterSpacing: 0.5,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      } else {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(
                  builder: (context) {
                    final productProvider = Provider.of<ProductProvider>(
                      context,
                    );
                    double totalAmount = 0.0;

                    try {
                      cartProvider.cart.forEach((productId, cartItem) {
                        final product = productProvider.products.firstWhere(
                          (product) => product.varianceName == productId,
                        );

                        final int quantity = (cartItem['qty'] ?? 1);
                        final double weight = (cartItem['weight'] ?? 0.0)
                            .toDouble();
                        final double price = (product.price).toDouble();
                        final String uom = (product.variance_Uom).toString();

                        final bool isWeight = uom == "Kgs";

                        // ✅ Base product total
                        double baseAmount = isWeight
                            ? (price * (weight / 1000.0)) * quantity
                            : price * quantity;

                        // ✅ Add-ons total
                        double addonsTotal = 0.0;
                        final selectedAddOns = cartItem['selectedAddOns'];
                        if (selectedAddOns != null && selectedAddOns is Map) {
                          selectedAddOns.forEach((name, data) {
                            final int addOnQty = (data['qty'] ?? 1);
                            final double addOnValue = (data['value'] ?? 0)
                                .toDouble();
                            final double addOnTotal = addOnQty * addOnValue;
                            addonsTotal += addOnTotal;
                          });
                        }

                        // ✅ Add product + addons
                        totalAmount += baseAmount + addonsTotal;
                      });
                    } catch (e, stack) {
                      debugPrint('❌ Error calculating total: $e');
                      debugPrint('🧱 Stack trace: $stack');
                    }

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ElevatedButton(
                          onPressed: () {
                            try {
                              handleSubmit(
                                context,
                                cartProvider,
                                printerProvider,
                              );

                              print("✅ Sent close overlay event");
                            } catch (e, stack) {
                              debugPrint('❌ Error during submit: $e');
                              debugPrint('🧱 Stack trace: $stack');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 95,
                              vertical: 20,
                            ),
                          ),
                          child: Text(
                            'Submit ₹${totalAmount.round()}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            Row(
              children: [
                // if()
                Expanded(
                  child: AbsorbPointer(
                    absorbing: cartProvider.cart.isNotEmpty,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 10),
                      child: HoldOrdersDropdown(),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10, right: 10),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            insetPadding: const EdgeInsets.all(30),
                            child: SizedBox(
                              width: 700,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          "Cancelled Orders",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    child: SizedBox(
                                      height: 600,
                                      child: const CanceledOrdersScreen(),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[300],
                                            foregroundColor: Colors.black,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text("Close"),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        "Cancel Orders",
                        style: TextStyle(
                          fontSize: 15,
                          letterSpacing: 0.5,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }
    }

    final isLockedTableView =
        orderProvider.chargeSubmit &&
        cartProvider.cart.isNotEmpty &&
        widget.tableNumber.isNotEmpty;

    List<Map<String, dynamic>> previousOrders = orderProvider.orders.where((
      order,
    ) {
      return order['table'] == widget.tableNumber &&
          order['seat'] == widget.seat &&
          order['status'] == "active";
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   backgroundColor: Colors.white,
      //   surfaceTintColor: Colors.white,
      //   title: Row(
      //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //     children: [
      //       Row(
      //         children: [
      //           if (widget.tableNumber.isNotEmpty && widget.seat.isNotEmpty)
      //             Consumer<CartProviderKOT>(
      //               builder: (context, value, child) {
      //                 return Text(
      //                   '${widget.tableNumber}- Seat ${widget.seat}',
      //                   style: const TextStyle(
      //                     fontWeight: FontWeight.bold,
      //                     fontSize: 16,
      //                     color: Colors.black,
      //                   ),
      //                 );
      //               },
      //             ),

      //           const SizedBox(width: 10),
      //           GestureDetector(
      //             onTap: () {
      //               showInitialPopup(
      //                 context,
      //                 widget.tableNumber,
      //                 widget.seat,
      //                 (String phoneNumber) {
      //                   setState(() {
      //                     customerPhoneNumber = phoneNumber;
      //                   });
      //                 },
      //                 initialPhoneNumber: customerPhoneNumber,
      //               );
      //             },
      //             child: Stack(
      //               alignment: Alignment.bottomRight,
      //               children: [
      //                 Icon(
      //                   Icons.account_circle_rounded,
      //                   size: 30,
      //                   color: Colors.blue[100],
      //                 ),
      //                 Positioned(
      //                   bottom: 0,
      //                   right: 0,
      //                   child: Container(
      //                     padding: const EdgeInsets.all(2),
      //                     decoration: const BoxDecoration(
      //                       color: Colors.blue,
      //                       shape: BoxShape.circle,
      //                     ),
      //                     child: const Icon(
      //                       Icons.phone,
      //                       size: 12,
      //                       color: Colors.white,
      //                     ),
      //                   ),
      //                 ),
      //               ],
      //             ),
      //           ),
      //         ],
      //       ),
      //       Padding(
      //         padding: const EdgeInsets.only(top: 15),
      //         child: ElevatedButton(
      //           onPressed: () {
      //             try {
      //               // Method 1: Use a callback system through providers
      //               final eventProvider = Provider.of<ProductEventProvider>(
      //                 context,
      //                 listen: false,
      //               );
      //               final cartProvider = Provider.of<CartProviderKOT>(
      //                 context,
      //                 listen: false,
      //               );

      //               // Send event to close product card overlay

      //               eventProvider.addEvent(
      //                 ProductEvent(
      //                   action: 'close_overlay',
      //                   tableNumber: widget.tableNumber,
      //                   seat: widget.seat,
      //                   areaName: widget.areaName,
      //                 ),
      //               );
      //               cartProvider.clearTableSeat();
      //               ValueListenableBuilder4(
      //                 valueListenable1: cartProvider.currentTableNumber,
      //                 valueListenable2: cartProvider.currentSeat,
      //                 valueListenable3: cartProvider.currentAreaName,
      //                 valueListenable4: cartProvider.currentSeathiveOrderId,
      //                 builder:
      //                     (
      //                       context,
      //                       tableNum,
      //                       seatVal,
      //                       areaNameVal,
      //                       seathiveId,
      //                       _,
      //                     ) {
      //                       return RepaintBoundary(
      //                         child: productCardViewList(
      //                           tableNumber: tableNum,
      //                           seat: seatVal,
      //                           areaName: areaNameVal,
      //                           seathiveOrderId: seathiveId,
      //                         ),
      //                       );
      //                     },
      //               );

      //               cartProvider.clearCart();
      //               final orderProvider = Provider.of<OrderProvider>(
      //                 context,
      //                 listen: false,
      //               );
      //               orderProvider.chargeSubmit = true;

      //               print("✅ Sent close overlay event");
      //             } catch (e) {
      //               print("❌ Error in button: $e");
      //             }
      //           },
      //           style: ElevatedButton.styleFrom(
      //             shape: RoundedRectangleBorder(
      //               borderRadius: BorderRadius.zero,
      //             ),
      //             backgroundColor: Colors.blue,
      //             foregroundColor: Colors.white,
      //             padding: EdgeInsets.symmetric(horizontal: 35, vertical: 15),
      //           ),
      //           child: const Text("New Orders", style: TextStyle(fontSize: 18)),
      //         ),
      //       ),
      //     ],
      //   ),
      //   actions: [
      //     Padding(
      //       padding: const EdgeInsets.all(8.0),
      //       //   child: ElevatedButton(
      //       //     onPressed: () {
      //       //       Navigator.push(
      //       //         context,
      //       //         MaterialPageRoute(
      //       //           builder: (context) => ProductCardScreen(
      //       //             tableNumber: widget.tableNumber,
      //       //             seat: widget.seat,
      //       //             areaName: widget.areaName,
      //       //             seathiveOrderId: '',
      //       //           ),
      //       //         ),
      //       //       );
      //       //     },
      //       //     style: ElevatedButton.styleFrom(
      //       //       elevation: 2,
      //       //       shape: RoundedRectangleBorder(
      //       //         borderRadius: BorderRadius.circular(12),
      //       //       ),
      //       //       padding: const EdgeInsets.symmetric(
      //       //         horizontal: 16,
      //       //         vertical: 10,
      //       //       ),
      //       //       backgroundColor: Colors.blue[100],
      //       //     ),
      //       //     child: const Text(
      //       //       'Add Item',
      //       //       style: TextStyle(
      //       //         fontSize: 16,
      //       //         color: Colors.blue,
      //       //         fontWeight: FontWeight.bold,
      //       //       ),
      //       //     ),
      //       //   ),
      //     ),
      //   ],
      // ),
      body: ClipRect(
        child: Stack(
          children: [
            // Main scrollable content
            Column(
              children: [
                // Show empty cart message when cart is empty
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: buildPaxDropdown(context),
                        height: 56,
                      ),
                      const SizedBox(width: 10),
                      EmployeeSearch(),
                    ],
                  ),
                ),

                if (cartProvider.cart.isEmpty && previousOrders.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Please add items to the cart.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Show cart items and header when cart has items
                if (!isLockedTableView &&
                    cartProvider.currentTableNumber.value.isNotEmpty &&
                    previousOrders.isNotEmpty) ...[
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text(
                        "Previous Orders",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blueAccent,
                        ),
                      ),
                      children: [
                        Container(
                          constraints: const BoxConstraints(
                            maxHeight: 300, // max height = 300, min = content
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            radius: const Radius.circular(10),
                            thickness: 6,
                            child: ListView.builder(
                              shrinkWrap:
                                  true, // 🔥 important (prevents infinite height)
                              itemCount: previousOrders.length,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              itemBuilder: (context, orderIndex) {
                                var order = previousOrders[orderIndex];
                                var id = order['hiveOrderId'] as String;
                                var orderId = id.substring(id.length - 2);

                                List<dynamic> itemNames =
                                    order['varianceNames'] ?? [];
                                List<dynamic> quantities =
                                    order['quantities'] ?? [];

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  color: Colors.white,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    title: Text(
                                      "Order ID: $orderId",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: List.generate(
                                        itemNames.length,
                                        (index) {
                                          final itemName = itemNames[index]
                                              .toString();
                                          final quantity =
                                              (index < quantities.length)
                                              ? quantities[index].toString()
                                              : '0';

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                              horizontal: 4,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    itemName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  quantity,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: Colors
                                                        .blueAccent
                                                        .shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (cartProvider.cart.isNotEmpty) ...[
                  Expanded(
                    child: Consumer<CartProviderKOT>(
                      builder: (context, cartProvider, child) {
                        final cartEntries = cartProvider.cart.entries
                            .toList()
                            .reversed
                            .toList();

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: cartEntries.length,
                          itemBuilder: (context, index) {
                            final entry = cartEntries[index];
                            final productId = entry.key;
                            final cartItem = entry.value;

                            final product = productProvider.products.firstWhere(
                              (product) => product.varianceName == productId,
                            );
                            final quantity = cartItem['qty'];
                            final hasAddOns = productProvider.hasAddOns(
                              product.varianceName,
                            );
                            final hasVariants = productProvider.hasVariants(
                              product.varianceName,
                            );
                            final weight = cartItem['weight'];

                            final isWeight =
                                product.variance_Uom.toLowerCase() == "kg" ||
                                product.variance_Uom.toLowerCase() == "Kgs";

                            // Initialize addons list
                            List<List<String>> addons = List.generate(
                              quantity,
                              (i) => List.from(
                                cartProvider.cart[productId]['addons'] !=
                                            null &&
                                        cartProvider
                                                .cart[productId]['addons']
                                                .length >
                                            i
                                    ? cartProvider.cart[productId]['addons'][i]
                                    : [],
                              ),
                            );

                            // Initialize addon quantities
                            List<List<int>> addonQuantities = List.generate(
                              quantity,
                              (i) => List.from(
                                cartProvider.cart[productId]['addonQuantities'] !=
                                            null &&
                                        cartProvider
                                                .cart[productId]['addonQuantities']
                                                .length >
                                            i
                                    ? cartProvider
                                          .cart[productId]['addonQuantities'][i]
                                    : [],
                              ),
                            );

                            // Initialize variants
                            List<String> variants = List.generate(
                              quantity,
                              (i) =>
                                  cartProvider.cart[productId]['variants'] !=
                                          null &&
                                      cartProvider
                                              .cart[productId]['variants']
                                              .length >
                                          i
                                  ? cartProvider.cart[productId]['variants'][i]
                                  : "Default",
                            );

                            // Initialize parcel/type
                            List<String> type = List.generate(
                              quantity,
                              (i) =>
                                  cartProvider.cart[productId]['type'] !=
                                          null &&
                                      cartProvider
                                              .cart[productId]['type']
                                              .length >
                                          i
                                  ? cartProvider.cart[productId]['type'][i]
                                  : "",
                            );

                            // Initialize configQty
                            List<int> configQty = List.generate(
                              quantity,
                              (i) =>
                                  cartProvider.cart[productId]['configQty'] !=
                                          null &&
                                      cartProvider
                                              .cart[productId]['configQty']
                                              .length >
                                          i
                                  ? cartProvider.cart[productId]['configQty'][i]
                                  : 1,
                            );

                            cartProvider.syncConfigWithQuantity(
                              productId,
                              quantity,
                            );

                            // Initialize toggle remarks
                            List<bool> toggleRemarks = cartProvider
                                .getToggleRemarks(productId, quantity);

                            // Initialize remark controllers
                            List<TextEditingController> remarkControllers =
                                List.generate(
                                  quantity,
                                  (i) => TextEditingController(
                                    text: cartProvider.getRemarks(
                                      productId,
                                      quantity,
                                    )[i],
                                  ),
                                );

                            // Initialize dialog state
                            final dialogState = CartItemDialogState(
                              type: type,
                              addons: addons,
                              addonQuantities: addonQuantities,
                              variants: variants,
                              toggleRemarks: toggleRemarks,
                              remarks: remarkControllers
                                  .map((c) => c.text)
                                  .toList(),
                              configQty: configQty,
                              remarkController: TextEditingController(
                                text: toggleRemarks.indexWhere((r) => r) != -1
                                    ? cartProvider.getRemarks(
                                        productId,
                                        quantity,
                                      )[toggleRemarks.indexWhere((r) => r)]
                                    : '',
                              ),
                              focusNode: FocusNode(),
                            );

                            return Dismissible(
                              key: Key(productId),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) {
                                cartProvider.removeFromCart(
                                  context,
                                  productId,
                                  widget.tableNumber,
                                  widget.seat,
                                );
                              },
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              child: ListTile(
                                title: GestureDetector(
                                  onTap: () {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          cartProvider.syncConfigWithQuantity(
                                            productId,
                                            quantity,
                                          );
                                        });

                                    showDialog(
                                      context: context,
                                      builder: (context) => ChangeNotifierProvider.value(
                                        value: dialogState,
                                        child: AlertDialog(
                                          backgroundColor: Colors.white,
                                          title: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                product.varianceName,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxHeight:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.7,
                                              maxWidth:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width *
                                                  0.8,
                                            ),
                                            child: Scrollbar(
                                              thumbVisibility: true,
                                              child: SingleChildScrollView(
                                                child: Consumer<CartItemDialogState>(
                                                  builder: (context, dialogState, _) {
                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        ...List.generate(quantity, (
                                                          i,
                                                        ) {
                                                          String itemName =
                                                              '  ${i + 1} .   ${product.varianceName} ';
                                                          String? selectedAddOn;

                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 4.0,
                                                                ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                // Item Name and Pax
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Flexible(
                                                                      child: Text(
                                                                        itemName,
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                // Add-ons
                                                                if (hasAddOns)
                                                                  Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Padding(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              4.0,
                                                                        ),
                                                                        child: Row(
                                                                          children: [
                                                                            Flexible(
                                                                              child:
                                                                                  DropdownButtonFormField<
                                                                                    String
                                                                                  >(
                                                                                    decoration: const InputDecoration(
                                                                                      contentPadding: EdgeInsets.symmetric(
                                                                                        horizontal: 8,
                                                                                        vertical: 10,
                                                                                      ),
                                                                                      border: OutlineInputBorder(
                                                                                        borderRadius: BorderRadius.all(
                                                                                          Radius.circular(
                                                                                            8.0,
                                                                                          ),
                                                                                        ),
                                                                                        borderSide: BorderSide(
                                                                                          color: Colors.grey,
                                                                                          width: 1.0,
                                                                                        ),
                                                                                      ),
                                                                                      enabledBorder: OutlineInputBorder(
                                                                                        borderRadius: BorderRadius.all(
                                                                                          Radius.circular(
                                                                                            8.0,
                                                                                          ),
                                                                                        ),
                                                                                        borderSide: BorderSide(
                                                                                          color: Colors.grey,
                                                                                          width: 1.0,
                                                                                        ),
                                                                                      ),
                                                                                      focusedBorder: OutlineInputBorder(
                                                                                        borderRadius: BorderRadius.all(
                                                                                          Radius.circular(
                                                                                            8.0,
                                                                                          ),
                                                                                        ),
                                                                                        borderSide: BorderSide(
                                                                                          color: Colors.blue,
                                                                                          width: 1.5,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                    isExpanded: true,
                                                                                    hint: Text(
                                                                                      dialogState.addons[i].isEmpty
                                                                                          ? 'Select Add-ons'
                                                                                          : "${dialogState.addons[i].length} selected",
                                                                                      style: const TextStyle(
                                                                                        fontSize: 12,
                                                                                        color: Colors.blue,
                                                                                      ),
                                                                                    ),
                                                                                    items: [
                                                                                      // Default "Select Add-ons" option
                                                                                      const DropdownMenuItem(
                                                                                        value: null,
                                                                                        child: Text(
                                                                                          "Select Add-ons",
                                                                                          style: TextStyle(
                                                                                            fontSize: 12,
                                                                                          ),
                                                                                          overflow: TextOverflow.ellipsis,
                                                                                        ),
                                                                                      ),
                                                                                      // Filtered add-ons based on product.varianceName
                                                                                      ...productProvider.addons
                                                                                          .where(
                                                                                            (
                                                                                              addOn,
                                                                                            ) {
                                                                                              var items = addOn['addOnItems'];
                                                                                              if (items
                                                                                                  is List) {
                                                                                                return items
                                                                                                    .map(
                                                                                                      (
                                                                                                        e,
                                                                                                      ) => e.toString().trim().toLowerCase(),
                                                                                                    )
                                                                                                    .contains(
                                                                                                      product.varianceName.trim().toLowerCase(),
                                                                                                    );
                                                                                              }
                                                                                              return items.toString().trim().toLowerCase() ==
                                                                                                  product.varianceName.trim().toLowerCase();
                                                                                            },
                                                                                          )
                                                                                          .map(
                                                                                            (
                                                                                              addOn,
                                                                                            ) => DropdownMenuItem(
                                                                                              value: addOn['addOn'].toString(),
                                                                                              child: Text(
                                                                                                "${addOn['addOn']} (₹${addOn['value']})",
                                                                                                style: const TextStyle(
                                                                                                  fontSize: 12,
                                                                                                ),
                                                                                                overflow: TextOverflow.ellipsis,
                                                                                              ),
                                                                                            ),
                                                                                          )
                                                                                          .toList(),
                                                                                    ],
                                                                                    value: selectedAddOn,
                                                                                    onChanged:
                                                                                        (
                                                                                          value,
                                                                                        ) {
                                                                                          if (value !=
                                                                                                  null &&
                                                                                              !dialogState.addons[i].contains(
                                                                                                value,
                                                                                              )) {
                                                                                            dialogState.updateAddOn(
                                                                                              i,
                                                                                              value,
                                                                                              true,
                                                                                              1,
                                                                                            );
                                                                                            cartProvider.updateCart(
                                                                                              productId,
                                                                                              dialogState.addons,
                                                                                              dialogState.addonQuantities,
                                                                                              dialogState.variants,
                                                                                              dialogState.type,
                                                                                              dialogState.remarks,
                                                                                              dialogState.toggleRemarks,
                                                                                            );
                                                                                          }
                                                                                        },
                                                                                  ),
                                                                            ),
                                                                            const SizedBox(
                                                                              width: 8,
                                                                            ),
                                                                            Column(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Checkbox(
                                                                                  value:
                                                                                      context
                                                                                          .watch<
                                                                                            CartItemDialogState
                                                                                          >()
                                                                                          .type[i] ==
                                                                                      "Parcel",
                                                                                  onChanged:
                                                                                      (
                                                                                        value,
                                                                                      ) {
                                                                                        if (value ==
                                                                                            null)
                                                                                          return;

                                                                                        final state = context
                                                                                            .read<
                                                                                              CartItemDialogState
                                                                                            >(); // <--- important

                                                                                        state.updateType(
                                                                                          i,
                                                                                          value,
                                                                                        );

                                                                                        cartProvider.updateCart(
                                                                                          productId,
                                                                                          state.addons,
                                                                                          state.addonQuantities,
                                                                                          state.variants,
                                                                                          state.type,
                                                                                          state.remarks,
                                                                                          state.toggleRemarks,
                                                                                        );
                                                                                      },
                                                                                  activeColor: Colors.blue,
                                                                                  checkColor: Colors.white,
                                                                                  side: const BorderSide(
                                                                                    color: Colors.blue,
                                                                                    width: 1.5,
                                                                                  ),
                                                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                                ),
                                                                                const Text(
                                                                                  "Parcel",
                                                                                  style: TextStyle(
                                                                                    fontSize: 10,
                                                                                    fontWeight: FontWeight.bold,
                                                                                    color: Colors.blue,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            const SizedBox(
                                                                              width: 8,
                                                                            ),
                                                                            Column(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Switch(
                                                                                  value: dialogState.toggleRemarks[i],
                                                                                  onChanged:
                                                                                      (
                                                                                        value,
                                                                                      ) {
                                                                                        dialogState.updateToggleRemark(
                                                                                          i,
                                                                                          value,
                                                                                        );
                                                                                        cartProvider.updateCart(
                                                                                          productId,
                                                                                          dialogState.addons,
                                                                                          dialogState.addonQuantities,
                                                                                          dialogState.variants,
                                                                                          dialogState.type,
                                                                                          dialogState.remarks,
                                                                                          dialogState.toggleRemarks,
                                                                                        );
                                                                                      },
                                                                                  activeColor: Colors.blue,
                                                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                                ),
                                                                                const Text(
                                                                                  "Remark",
                                                                                  style: TextStyle(
                                                                                    fontSize: 10,
                                                                                    fontWeight: FontWeight.bold,
                                                                                    color: Colors.blue,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                      // Display selected add-ons with quantities
                                                                      ...dialogState.addons[i].asMap().entries.map((
                                                                        entry,
                                                                      ) {
                                                                        final addOnIndex =
                                                                            entry.key;
                                                                        final addOnName =
                                                                            entry.value;
                                                                        final addOnValue = productProvider.addons.firstWhere(
                                                                          (
                                                                            addOn,
                                                                          ) =>
                                                                              addOn['addOn'].toString() ==
                                                                              addOnName,
                                                                        )['value'];

                                                                        return Padding(
                                                                          padding: const EdgeInsets.symmetric(
                                                                            vertical:
                                                                                2.0,
                                                                          ),
                                                                          child: Row(
                                                                            children: [
                                                                              Expanded(
                                                                                child: Text(
                                                                                  "$addOnName (₹$addOnValue)",
                                                                                  style: const TextStyle(
                                                                                    fontSize: 12,
                                                                                  ),
                                                                                  overflow: TextOverflow.ellipsis,
                                                                                ),
                                                                              ),
                                                                              Row(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                children: [
                                                                                  IconButton(
                                                                                    icon: const Icon(
                                                                                      Icons.remove,
                                                                                      size: 18,
                                                                                      color: Colors.redAccent,
                                                                                    ),
                                                                                    onPressed: () {
                                                                                      if (dialogState.addonQuantities[i][addOnIndex] >
                                                                                          1) {
                                                                                        dialogState.updateAddOnQuantity(
                                                                                          i,
                                                                                          addOnIndex,
                                                                                          dialogState.addonQuantities[i][addOnIndex] -
                                                                                              1,
                                                                                        );
                                                                                      } else {
                                                                                        dialogState.updateAddOn(
                                                                                          i,
                                                                                          addOnName,
                                                                                          false,
                                                                                          0,
                                                                                        );
                                                                                      }
                                                                                      cartProvider.updateCart(
                                                                                        productId,
                                                                                        dialogState.addons,
                                                                                        dialogState.addonQuantities,
                                                                                        dialogState.variants,
                                                                                        dialogState.type,
                                                                                        dialogState.remarks,
                                                                                        dialogState.toggleRemarks,
                                                                                      );
                                                                                    },
                                                                                    padding: EdgeInsets.zero,
                                                                                    constraints: const BoxConstraints(),
                                                                                  ),
                                                                                  SizedBox(
                                                                                    width: 30,
                                                                                    child: Text(
                                                                                      "${dialogState.addonQuantities[i][addOnIndex]}",
                                                                                      textAlign: TextAlign.center,
                                                                                      style: const TextStyle(
                                                                                        fontSize: 12,
                                                                                        fontWeight: FontWeight.bold,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  IconButton(
                                                                                    icon: const Icon(
                                                                                      Icons.add,
                                                                                      size: 18,
                                                                                      color: Colors.blue,
                                                                                    ),
                                                                                    onPressed: () {
                                                                                      dialogState.updateAddOnQuantity(
                                                                                        i,
                                                                                        addOnIndex,
                                                                                        dialogState.addonQuantities[i][addOnIndex] +
                                                                                            1,
                                                                                      );
                                                                                      cartProvider.updateCart(
                                                                                        productId,
                                                                                        dialogState.addons,
                                                                                        dialogState.addonQuantities,
                                                                                        dialogState.variants,
                                                                                        dialogState.type,
                                                                                        dialogState.remarks,
                                                                                        dialogState.toggleRemarks,
                                                                                      );
                                                                                    },
                                                                                    padding: EdgeInsets.zero,
                                                                                    constraints: const BoxConstraints(),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        );
                                                                      }).toList(),
                                                                    ],
                                                                  ),
                                                                if (hasVariants)
                                                                  Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Flexible(
                                                                        child: DropdownButtonFormField(
                                                                          decoration: const InputDecoration(
                                                                            hintText:
                                                                                'Select variant',
                                                                            border:
                                                                                OutlineInputBorder(),
                                                                            contentPadding: EdgeInsets.symmetric(
                                                                              horizontal: 8,
                                                                              vertical: 10,
                                                                            ),
                                                                          ),
                                                                          items: [
                                                                            const DropdownMenuItem(
                                                                              value: "Default",
                                                                              child: Text(
                                                                                "Default",
                                                                                style: TextStyle(
                                                                                  fontSize: 12,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            ...productProvider.variants
                                                                                .map(
                                                                                  (
                                                                                    v,
                                                                                  ) => DropdownMenuItem(
                                                                                    value: v['variant'],
                                                                                    child: Text(
                                                                                      v['variant'],
                                                                                      style: const TextStyle(
                                                                                        fontSize: 12,
                                                                                      ),
                                                                                      overflow: TextOverflow.ellipsis,
                                                                                    ),
                                                                                  ),
                                                                                )
                                                                                .toList(),
                                                                          ],
                                                                          onChanged:
                                                                              (
                                                                                value,
                                                                              ) {
                                                                                dialogState.updateVariant(
                                                                                  i,
                                                                                  value.toString(),
                                                                                );
                                                                                cartProvider.updateCart(
                                                                                  productId,
                                                                                  dialogState.addons,
                                                                                  dialogState.addonQuantities,
                                                                                  dialogState.variants,
                                                                                  dialogState.type,
                                                                                  dialogState.remarks,
                                                                                  dialogState.toggleRemarks,
                                                                                );
                                                                              },
                                                                          value:
                                                                              dialogState.variants[i],
                                                                          isExpanded:
                                                                              true,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Checkbox(
                                                                            value:
                                                                                dialogState.type[i] ==
                                                                                "Parcel",
                                                                            onChanged:
                                                                                (
                                                                                  value,
                                                                                ) {
                                                                                  if (value ==
                                                                                      null)
                                                                                    return;

                                                                                  final state = context
                                                                                      .read<
                                                                                        CartItemDialogState
                                                                                      >(); // <--- important
                                                                                  cartProvider.updateCart(
                                                                                    productId,
                                                                                    dialogState.addons,
                                                                                    dialogState.addonQuantities,
                                                                                    dialogState.variants,
                                                                                    dialogState.type,
                                                                                    dialogState.remarks,
                                                                                    dialogState.toggleRemarks,
                                                                                  );
                                                                                },
                                                                            activeColor:
                                                                                Colors.blue,
                                                                            checkColor:
                                                                                Colors.white,
                                                                            side: const BorderSide(
                                                                              color: Colors.blue,
                                                                              width: 1.5,
                                                                            ),
                                                                            materialTapTargetSize:
                                                                                MaterialTapTargetSize.shrinkWrap,
                                                                          ),
                                                                          const Text(
                                                                            "Parcel",
                                                                            style: TextStyle(
                                                                              fontSize: 10,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Colors.blue,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Switch(
                                                                            value:
                                                                                dialogState.toggleRemarks[i],
                                                                            onChanged:
                                                                                (
                                                                                  value,
                                                                                ) {
                                                                                  dialogState.updateToggleRemark(
                                                                                    i,
                                                                                    value,
                                                                                  );
                                                                                  cartProvider.updateCart(
                                                                                    productId,
                                                                                    dialogState.addons,
                                                                                    dialogState.addonQuantities,
                                                                                    dialogState.variants,
                                                                                    dialogState.type,
                                                                                    dialogState.remarks,
                                                                                    dialogState.toggleRemarks,
                                                                                  );
                                                                                },
                                                                            activeColor:
                                                                                Colors.blue,
                                                                            materialTapTargetSize:
                                                                                MaterialTapTargetSize.shrinkWrap,
                                                                          ),
                                                                          const Text(
                                                                            "Remark",
                                                                            style: TextStyle(
                                                                              fontSize: 10,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Colors.blue,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  ),
                                                                // Non-add-on/non-variant items
                                                                if (!hasAddOns &&
                                                                    !hasVariants)
                                                                  Padding(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      vertical:
                                                                          4.0,
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            Checkbox(
                                                                              value:
                                                                                  dialogState.type[i] ==
                                                                                  "Parcel",
                                                                              onChanged:
                                                                                  (
                                                                                    value,
                                                                                  ) {
                                                                                    if (value ==
                                                                                        null)
                                                                                      return;

                                                                                    final state = context
                                                                                        .read<
                                                                                          CartItemDialogState
                                                                                        >(); // <--- important
                                                                                    state.updateType(
                                                                                      i,
                                                                                      value,
                                                                                    );
                                                                                    cartProvider.updateCart(
                                                                                      productId,
                                                                                      dialogState.addons,
                                                                                      dialogState.addonQuantities,
                                                                                      dialogState.variants,
                                                                                      dialogState.type,
                                                                                      dialogState.remarks,
                                                                                      dialogState.toggleRemarks,
                                                                                    );
                                                                                  },
                                                                              activeColor: Colors.blue,
                                                                              checkColor: Colors.white,
                                                                              side: const BorderSide(
                                                                                color: Colors.blue,
                                                                                width: 1.5,
                                                                              ),
                                                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                            ),
                                                                            const Text(
                                                                              "Parcel",
                                                                              style: TextStyle(
                                                                                fontSize: 10,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: Colors.blue,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            Switch(
                                                                              value: dialogState.toggleRemarks[i],
                                                                              onChanged:
                                                                                  (
                                                                                    value,
                                                                                  ) {
                                                                                    dialogState.updateToggleRemark(
                                                                                      i,
                                                                                      value,
                                                                                    );
                                                                                    cartProvider.updateCart(
                                                                                      productId,
                                                                                      dialogState.addons,
                                                                                      dialogState.addonQuantities,
                                                                                      dialogState.variants,
                                                                                      dialogState.type,
                                                                                      dialogState.remarks,
                                                                                      dialogState.toggleRemarks,
                                                                                    );
                                                                                  },
                                                                              activeColor: Colors.blue,
                                                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                            ),
                                                                            const Text(
                                                                              "Remark",
                                                                              style: TextStyle(
                                                                                fontSize: 10,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: Colors.blue,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          );
                                                        }),
                                                        // Single remark TextField
                                                        if (dialogState
                                                            .toggleRemarks
                                                            .any((r) => r))
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 8.0,
                                                                ),
                                                            child: TextField(
                                                              controller:
                                                                  dialogState
                                                                      .remarkController,
                                                              focusNode:
                                                                  dialogState
                                                                      .focusNode,
                                                              decoration: const InputDecoration(
                                                                hintText:
                                                                    'Enter remark',
                                                                border:
                                                                    OutlineInputBorder(),
                                                                contentPadding:
                                                                    EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          10,
                                                                    ),
                                                              ),
                                                              onChanged: (value) {
                                                                final remarkIndex =
                                                                    dialogState
                                                                        .toggleRemarks
                                                                        .indexWhere(
                                                                          (r) =>
                                                                              r,
                                                                        );
                                                                if (remarkIndex !=
                                                                    -1) {
                                                                  dialogState
                                                                      .updateRemark(
                                                                        remarkIndex,
                                                                        value,
                                                                      );
                                                                  cartProvider.updateCart(
                                                                    productId,
                                                                    dialogState
                                                                        .addons,
                                                                    dialogState
                                                                        .addonQuantities,
                                                                    dialogState
                                                                        .variants,
                                                                    dialogState
                                                                        .type,
                                                                    dialogState
                                                                        .remarks,
                                                                    dialogState
                                                                        .toggleRemarks,
                                                                  );
                                                                }
                                                              },
                                                            ),
                                                          ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                elevation: 2,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10,
                                                    ),
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Cancel'),
                                              onPressed: () {
                                                // dialogState.dispose();
                                                Navigator.of(context).pop();
                                                print(
                                                  "❎ Cancelled dialog for $productId",
                                                );
                                              },
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                elevation: 2,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10,
                                                    ),
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('OK'),
                                              onPressed: () {
                                                cartProvider.updateCart(
                                                  productId,
                                                  dialogState.addons,
                                                  dialogState.addonQuantities,
                                                  dialogState.variants,
                                                  dialogState.type,
                                                  dialogState.remarks,
                                                  dialogState.toggleRemarks,
                                                );
                                                print(
                                                  "💾 Saved Config for $productId: ${{'configQty': dialogState.configQty, 'addOn': dialogState.addons, 'addOnQuantities': dialogState.addonQuantities, 'variance': dialogState.variants, 'type': dialogState.type, 'remarks': dialogState.remarks, 'toggleRemarks': dialogState.toggleRemarks}}",
                                                );
                                                dialogState.dispose();
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "${capitalizeWords(product.varianceName)} \n ₹${product.price} ${isWeight ? '/ ${weight}g' : ''}",
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black12),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.remove,
                                          color: Colors.red[600],
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          cartProvider.removeItemFromCart(
                                            context,
                                            product.varianceName,
                                            widget.tableNumber,
                                            widget.seat,
                                          );
                                          cartProvider.syncConfigWithQuantity(
                                            productId,
                                            quantity - 1,
                                          );
                                          print(
                                            "🗑️ Removed item $productId, new quantity: ${quantity - 1}",
                                          );
                                        },
                                      ),
                                      Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$quantity',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.add,
                                          color: Colors.green[600],
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          cartProvider.addToCart(
                                            product.varianceName,
                                          );
                                          cartProvider.syncConfigWithQuantity(
                                            productId,
                                            quantity + 1,
                                          );
                                          print(
                                            "➕ Added item $productId, new quantity: ${quantity + 1}",
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                // Add bottom padding to prevent content from being hidden behind fixed buttons
                if (cartProvider.cart.isNotEmpty || isLockedTableView)
                  const SizedBox(
                    height: 150,
                  ), // Adjust this height based on your button height
              ],
            ),

            // Fixed buttons at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.white,
                child: _buildBottomButtons(
                  isLockedTableView: isLockedTableView,
                  cartProvider: cartProvider,
                  orderProvider: orderProvider,
                  printerProvider: printerProvider,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

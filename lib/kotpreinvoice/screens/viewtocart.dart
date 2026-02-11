import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Provider/bottomNavprovider.dart';
import 'package:yen_pos/Global/Provider/employee_provider.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Mode_page/Regular_mode/Provider/regular_mode_screen_provider.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/customer_search.dart';
import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/pax_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/upi_provider.dart';
import 'package:yen_pos/kotpreinvoice/screens/cancelOrderScreen.dart';
import 'package:yen_pos/kotpreinvoice/services/format_weight.dart';
import 'package:yen_pos/kotpreinvoice/utils/custom_snackbar.dart';
import 'package:yen_pos/kotpreinvoice/widgets/employee_search.dart';
import 'package:yen_pos/kotpreinvoice/widgets/holdOrder.dart';
import 'package:yen_pos/kotpreinvoice/widgets/salesInvoicePayandPrint.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../providers/cartprovider.dart';
import '../providers/printer_provider.dart';
import '../providers/product_provider.dart';
import '../components/flushbar.dart';
import '../models/fetchDiningTax.dart';

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
  List<bool> toggleRemark;
  List<String> remark;
  List<int> configQty;
  List<TextEditingController> remarkControllers; // List of controllers
  List<FocusNode> focusNodes;

  CartItemDialogState({
    required this.type,
    required this.addons,
    required this.addonQuantities,
    required this.variants,
    required this.toggleRemark, // Single boolean
    required this.remark, // Si
    required this.configQty,
    required this.remarkControllers,
    required this.focusNodes,
  });

  bool get allParcelSelected => type.every((t) => t == "Parcel");

  void updateAllParcel(bool value) {
    for (int i = 0; i < type.length; i++) {
      type[i] = value ? "Parcel" : "Dine In";
    }
    notifyListeners();
  }

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
      debugPrint("Updating variant at index $index to $variant");
      variants[index] = variant;
      notifyListeners();
    }
  }

  void updateToggleRemark(int index, bool value) {
    if (index < toggleRemark.length) {
      toggleRemark[index] = value;
      if (!value) {
        remark[index] = "";
        remarkControllers[index].clear();
      }
      notifyListeners();
    }
  }

  void updateRemark(int index, String remarkText) {
    if (index < remark.length) {
      remark[index] = remarkText;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (var controller in remarkControllers) {
      controller.dispose();
    }
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
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

  final TextEditingController _customerNumberController =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();
  String customerPhoneNumber = "";
  late WebSocketChannel channel;
  String? storedDeviceId;

  int paxValue = 1;

  Future<void> loadDeviceCode() async {
    var box = Hive.box('deviceData');
    setState(() {
      storedDeviceId = box.get('deviceCode');
    });
  }

  // Future<sen(Map<String, dynamic> data) async {
  //   final jsonData = jsonEncode(data);
  //   try {
  //     channel.sink.add(jsonData);
  //     debugPrint("📤 Sending data to server: $jsonData");
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(SnackBar(content: Text('Error sending data: $e')));
  //     }
  //   }
  // }

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

      return fallback;
    }

    FocusManager.instance.primaryFocus?.unfocus();

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

      final now = DateTime.now();
      final formattedDate = DateFormat('dd-MM-yyyy').format(now);
      final formattedTime = DateFormat('hh:mm:ss a').format(now);

      // double totalAddonsAmount = 0.0;
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

      debugPrint("cartProvider.cart.entries is ${cartProvider.cart.entries}");

      for (var entry in cartProvider.cart.entries) {
        debugPrint("order are of $entry");
        final productId = entry.key;
        final productWithSplit = productId.toString().contains('-')
            ? productId.toString().split('-')
            : [productId];

        final productName = productWithSplit[0];

        try {
          final product = productProvider.products.firstWhere(
            (p) => p.varianceName == productName,
            orElse: () {
              debugPrint("❌ Product not found: ${productName}");
              throw Exception("Product not found: ${productName}");
            },
          );

          itemNames.add(product.name);
          varianceNames.add(product.varianceName);
          varianceItemCodes.add(product.varianceitemCode);

          // ── Quantity & Weight parsing ───────────────────────────────────────
          int quantity = 0;
          final rawQty = entry.value['qty'] ?? 1;
          if (rawQty is String) {
            quantity = int.tryParse(rawQty) ?? 1;
          } else if (rawQty is num) {
            quantity = rawQty.toInt();
          }
          quantity = quantity.clamp(1, 999); // safety
          quantities.add(quantity);

          double weightKg = parseDouble(entry.value['weight'] ?? 0.0);
          weights.add(weightKg);

          String uom = (product.variance_Uom ?? 'Pcs').trim().toLowerCase();
          uoms.add(uom);

          // ── Determine what to multiply the base price with ───────────────────
          bool isByWeight =
              uom == 'kgs' || uom == 'Kgs' || uom == "kg" || uom == "Kg";

          double multiplier;

          if (isByWeight) {
            multiplier = weightKg; // price × kg
            // If you ever allow multiple separate weighed portions → multiplier = weightKg * quantity;
            // But 99% of cases → just weightKg
          } else {
            multiplier = quantity.toDouble(); // price × pcs
          }

          // Base price calculation
          double unitPrice = parseDouble(product.price);
          double baseItemPrice = unitPrice * multiplier;

          prices.add(unitPrice);

          // ── Add-ons calculation ──────────────────────────────────────────────
          double addOnsTotalThisItem = 0.0;

          final List<List<String>> addons = List.generate(quantity, (i) {
            final list = entry.value['addons'] as List?;
            return i < (list?.length ?? 0)
                ? List<String>.from(list![i])
                : <String>[];
          });

          final List<List<int>> addonQuantities = List.generate(quantity, (i) {
            final list = entry.value['addonQuantities'] as List?;
            return i < (list?.length ?? 0)
                ? List<int>.from(
                    list![i].map((e) => (e is num ? e.toInt() : 1)),
                  )
                : <int>[];
          });
          final List<String> type = entry.value['type'] is List
              ? List<String>.from(entry.value['type'])
              : <String>[];
          final List<String> variance = entry.value['variants'] is List
              ? (entry.value['variants'] as List)
                    .map((e) => e == 'Default' ? '' : e.toString())
                    .toList()
              : <String>[];
          final List<String> remark = entry.value['remark'] is List
              ? List<String>.from(entry.value['remark'])
              : <String>[];

          debugPrint("remark are $remark");

          final List<List<double>> addOnPrices = List.generate(quantity, (i) {
            final pricesForPortion = <double>[];
            for (int j = 0; j < addons[i].length; j++) {
              final name = addons[i][j];
              final qty = j < addonQuantities[i].length
                  ? addonQuantities[i][j]
                  : 1;

              final addon = productProvider.addons.firstWhere(
                (a) => a['addOn'].toString() == name,
                orElse: () => {'value': '0'},
              );

              final addonPrice = parseDouble(addon['value']) * qty;
              pricesForPortion.add(addonPrice);
              addOnsTotalThisItem += addonPrice;
            }
            return pricesForPortion;
          });

          // totalAddonsAmount += addOnsTotalThisItem;

          // Final item total
          double itemTotal = baseItemPrice + addOnsTotalThisItem;
          amounts.add(itemTotal);

          // Taxes (if applied per item)
          taxes.add(diningTaxPercentage);

          varianceWeights[product.varianceName] = weightKg;

          // Config (mostly same)
          final config = {
            "varianceName": product.varianceName,
            "weight": weightKg,
            "configQty": List.generate(
              quantity,
              (i) => 1,
            ), // usually 1 per portion
            "addOn": addons,
            "addOnQuantities": addonQuantities,
            "addOnPrice": addOnPrices,
            "variance": variance,
            "type": type,
            "remark": remark,
          };

          debugPrint("config data is $config");
          configs.add(config);
        } catch (e, stack) {
          debugPrint("Error processing ${entry.key}: $e\n$stack");
        }
      }

      final double totalAmount = amounts.fold(0.0, (sum, item) => sum + item);

      // Get pax from PaxProvider
      String paxValue = paxProvider.selectedPax;
      if (paxValue.isEmpty) {
        paxValue = "1";
      }

      final order = {
        'type': 'order',
        'date': formattedDate,
        'time': formattedTime,
        'preinvoiceTime': '',
        'branchName': branchName,
        'aliasName': aliasname,
        "locationId": locationId,
        'table': widget.tableNumber,
        'seat': widget.seat,
        'areaName': widget.areaName,
        'deviceId': storedDeviceId,
        'itemNames': itemNames.isNotEmpty ? itemNames : [''],
        'varianceNames': varianceNames.isNotEmpty ? varianceNames : [''],
        'varianceitemCodes': varianceItemCodes.isNotEmpty
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
        'waiter': createdBy,
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

      print("order placed and createdBy : $createdBy");

      try {
        sendataToServer(order);
      } catch (e, st) {
        debugPrint("❌ Failed to send order: $e\n$st");
        throw e; // Re-throw to handle in submitOrder
      }

      Navigator.pop(context);
      cartProvider.clearCart();
      final prov = Provider.of<SalesInvoiceState>(context, listen: false);

      prov.employee.clear();

      createdBy = "";
      FocusManager.instance.primaryFocus?.unfocus();
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

  int getSeatsForTable(String tableNumber) {
    try {
      for (final area in tables) {
        final List<Map<String, dynamic>> tables =
            area['tables'] as List<Map<String, dynamic>>;

        for (final table in tables) {
          if (table['tableNumber'].toString() == tableNumber) {
            final seats = table['seats'];
            if (seats is int && seats > 0) {
              return seats;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting seats for table $tableNumber: $e');
    }

    // 🔐 Safe fallback
    return 1;
  }

  List<Map<String, dynamic>> _getItemsFromConfirmedOrders() {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final confirmedOrders = orderProvider.orders
          .where(
            (order) =>
                order['table'] == widget.tableNumber &&
                order['seat'] == widget.seat &&
                order['status'] == 'confirm',
          )
          .toList();

      if (confirmedOrders.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> items = [];

      for (final order in confirmedOrders) {
        try {
          final List<double> prices = (order['prices'] as List? ?? [])
              .map((e) => (e as num).toDouble())
              .toList();

          final List<double> quantities = (order['quantities'] as List? ?? [])
              .map((e) => (e as num).toDouble())
              .toList();

          final List<Map<String, dynamic>> configs =
              ((order['config'] as List?) ?? [])
                  .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e as Map),
                  )
                  .toList();

          final List<double> computedAmounts = List.generate(prices.length, (
            i,
          ) {
            final double price = prices[i];
            final double qty = (i < quantities.length) ? quantities[i] : 0.0;

            final double weight = (i < configs.length)
                ? ((configs[i]['weight'] ?? 0.0) as num).toDouble()
                : 0.0;

            // ✅ WEIGHT PRODUCT
            if (weight > 0) {
              final amount = price * qty * weight;
              return amount;
            }

            // ✅ PCS PRODUCT
            final amount = price * qty;
            return amount;
          });

          final mappedOrder = <String, dynamic>{
            'itemName': order['itemNames'] ?? [],
            'varianceitemCode': order['varianceitemCodes'] ?? [],
            'varianceName': order['varianceNames'] ?? [],
            'qty': quantities,
            'weight': order['weights'] ?? [],
            'tax': order['taxes'] ?? [],
            'uom': order['uoms'] ?? [],
            'table': order['table'] ?? '',
            'seat': order['seat'] ?? '',
            'hiveOrderId': order['hiveOrderId'] ?? '',
            'waiter': order['waiter'] ?? '',
            'price': prices,
            'amount': computedAmounts,
            'seathiveOrderId': order['seathiveOrderId'] ?? '',
            'invoiceNo': order['invoiceNo'],
          };

          items.add(mappedOrder);
        } catch (e, st) {
          debugPrint("❌ Error mapping order for invoice: $e");
          debugPrint("📌 StackTrace: $st");
        }
      }

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

    loadDeviceCode();
    print("✅ Device code load initiated.");
  }

  @override
  void dispose() {
    mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProviderKOT>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final printerProvider = Provider.of<PrinterProviderDine>(context);
    final employeeProvider = Provider.of<EmployeeProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final ValueNotifier<Map<String, dynamic>>? productCardDataNotifier;
    final ValueNotifier<bool>? showProductCardNotifier;
    final globalManager = Provider.of<GlobalDataManager>(context);
    // final paxProvider = Provider.of<PaxProviderDine>(context);

    final regularModeProvider = Provider.of<RegularModeProvider>(
      context,
      listen: false,
    );

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
                        // Provider.of<PaxProviderDine>(
                        //   context,
                        //   listen: false,
                        // ).resetPax();
                        print("👥 Reset Pax count");
                      } catch (e, st) {
                        print("❌ Error resetting pax: $e\n$st");
                      }
                      final eventProvider = Provider.of<ProductEventProvider>(
                        context,
                        listen: false,
                      );

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
        List<Map<String, dynamic>> stockCheckList =
            []; // Collect stock data for dialog

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
            print("cartItem qty: ${cartItem}");
            print("product Id is: $productId");

            final productWithSplit = productId.toString().contains('-')
                ? productId.toString().split('-')
                : [productId];

            final String productName = productWithSplit[0];

            final varianceData = regularModeProvider.getVarianceDetails(
              productName,
            );

            final isInCart = cartProvider.cart.containsKey(productId.trim());
            final int quantity = isInCart
                ? (cartProvider.cart[productId]?['qty'] ?? 0) as int
                : 0;

            final double liveStock = globalManager.getSystemStock(
              locationId,
              productName,
            );

            double displayStock = liveStock >= 0
                ? liveStock
                : (varianceData['branchwise']?[locationId]?['systemStock']
                              as num?)
                          ?.toDouble() ??
                      0.0;

            print("displayStock for $productName: $displayStock");

            // NEW: Stock check with full details
            final bool isKg =
                false; // Change if you have UOM logic here (e.g., from varianceData)
            final double requiredQty = quantity
                .toDouble(); // qty is int, but we use double for consistency

            final bool sufficient = requiredQty <= displayStock + 0.001;

            stockCheckList.add({
              'item': productName, // Use real item name if available
              'required': requiredQty,
              'available': displayStock,
              'uom': isKg ? 'kg' : 'pcs',
              'status': sufficient ? 'OK' : 'Insufficient',
              'isKg': isKg,
            });
          });
        } catch (e, st) {
          print("❌ Error iterating over cart items: $e\n$st");
        }

        final salesState = Provider.of<SalesInvoiceState>(
          context,
          listen: false,
        );
        final prov = Provider.of<SalesInvoiceState>(context, listen: false);

        final employeeName = prov.employee.text;
        createdBy = employeeName;

        // 1. Check Sales Person
        if (createdBy.isEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Sales Person Required'),
              content: const Text(
                'Please select a Sales Person before submitting the order.',
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.black,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
          return;
        }
        // 2. Check Printer Configuration
        else if (!hasOverallPrinter || missingItemIps.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Missing Printer Configuration'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.black,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[200],
                    foregroundColor: Colors.black,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Set IP'),
                  onPressed: () {
                    Provider.of<BottomNavProvider>(
                      context,
                      listen: false,
                    ).updateIndex(5);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
          return;
        }
        // 3. Check stock before proceeding
        final insufficientItems = stockCheckList
            .where((row) => row['status'] == 'Insufficient')
            .toList();

        if (insufficientItems.isNotEmpty) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Dialog(
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 30,
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                constraints: const BoxConstraints(maxHeight: 700),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.grey.shade50],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header - Red Alert
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Insufficient Stock",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "The following items exceed available stock. Please adjust quantities.",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),

                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      "Item",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        "Required",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        "Available",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        "Shortage",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemCount: insufficientItems.length,
                                itemBuilder: (context, i) {
                                  final row = insufficientItems[i];
                                  final double shortage =
                                      (row['required'] as double) -
                                      (row['available'] as double);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.shade500,
                                        width: 1.8,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Text(
                                            row['item'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: Colors.red.shade600,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Text(
                                              "${row['required'].toStringAsFixed(row['isKg'] ? 3 : 0)} ${row['uom']}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Text(
                                              "${row['available'].toStringAsFixed(row['isKg'] ? 3 : 0)} ${row['uom']}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade500,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                "-${shortage.toStringAsFixed(row['isKg'] ? 3 : 0)}",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade500,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Close & Adjust Quantities",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          return; // Stop submission
        }
        // 4. Everything valid → Submit Order
        else {
          print("📤 Submitting Order with Phone Number: $customerPhoneNumber");
          submitOrder(customerPhoneNumber);
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
                            if (true) {
                              try {
                                final upiProvider =
                                    Provider.of<UpiProviderDine>(
                                      context,
                                      listen: false,
                                    );

                                // if (upiProvider.isUpiEnabled) {
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

                                          customerName:
                                              _customerNumberController.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              } catch (e, stack) {
                                if (context.mounted) {
                                  showCustomFlushbar(
                                    context,
                                    'Failed to open invoice: $e',
                                    type: FlushbarType.error,
                                  );
                                }
                              }
                            }
                            //   else {
                            //     CustomSnackBar.show(
                            //       context,
                            //       'Dine is not Enabled',
                            //       type: SnackType.error,
                            //     );
                            //   }
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
                        final String normalizedProductId =
                            productId.contains('-')
                            ? productId.split('-')[0]
                            : productId;

                        final product = productProvider.products.firstWhere(
                          (product) =>
                              product.varianceName == normalizedProductId,
                          orElse: () => throw Exception(
                            'Product not found: $normalizedProductId',
                          ),
                        );

                        final int quantity = (cartItem['qty'] ?? 1);
                        final double weight = (cartItem['weight'] ?? 0.0)
                            .toDouble();

                        final double price = (product.price).toDouble();
                        final String uom = (product.variance_Uom).toString();

                        final bool isWeight = uom == "Kgs";

                        // ✅ Base product total
                        double baseAmount =
                            (isWeight ? price * weight : price * quantity)
                                .round()
                                .toDouble();

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
                              Hive.box("holdOrdersKOT").values.forEach((
                                holdOrder,
                              ) {
                                debugPrint(
                                  "Hold Order Data: ${holdOrder.toString()}",
                                );
                              });
                              debugPrint(
                                "cartProvider.cart : ${cartProvider.cart.toString()}",
                              );
                              handleSubmit(
                                context,
                                cartProvider,
                                printerProvider,
                              );

                              FocusScope.of(context).unfocus();
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
    // paxProvider.setSelectedPax('1');
    paxValue = getSeatsForTable(widget.tableNumber);

    if (previousOrders.isNotEmpty) {
      final firstPreviousOrder = previousOrders.first;
      // paxProvider.setSelectedPax(firstPreviousOrder['pax']);

      final waiterName = firstPreviousOrder['waiter'] ?? '';

      if (waiterName.isNotEmpty) {
        // Update the provider directly
        final prov = Provider.of<SalesInvoiceState>(context, listen: false);

        prov.employee.text =
            waiterName; // waiterName only not employee number or id

        // Also update the display text
        prov.employee.value = TextEditingValue(text: waiterName);

        // Optional: update global if needed elsewhere
        createdBy = waiterName;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,

      body: ClipRect(
        child: Stack(
          children: [
            // Main scrollable content
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.tableNumber.isNotEmpty &&
                          widget.seat.isNotEmpty) ...[
                        Consumer<CartProviderKOT>(
                          builder: (context, value, child) {
                            return Text(
                              '${widget.tableNumber}- Seat ${widget.seat}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            );
                          },
                        ),

                        SizedBox(
                          width: 100,
                          child: buildPaxDropdown(context, maxPax: paxValue),
                          height: 56,
                        ),
                      ],
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: EmployeeSearchKOT(
                          isEnabled: isLockedTableView || createdBy.isNotEmpty,
                        ),
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        flex: 2,
                        child: CustomerSearchDropdown(
                          readOnly: false,
                          showTopProducts: false,
                          customerNumberController: _customerNumberController,
                          focusNode: _focusNode,
                        ),
                      ),
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
                                List<dynamic> weights = order['weights'] ?? [];

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
                                      children: List.generate(itemNames.length, (
                                        index,
                                      ) {
                                        final itemName = itemNames[index]
                                            .toString();
                                        final weight = weights[index]
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
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: weight == "0.0"
                                                    ? Text(
                                                        itemName,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      )
                                                    : Text(
                                                        "$itemName / $weight kgs",
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                      }),
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

                            final String normalizedProductId =
                                productId.contains('-')
                                ? productId.split('-')[0]
                                : productId;

                            final product = productProvider.products.firstWhere(
                              (product) =>
                                  product.varianceName.trim().toUpperCase() ==
                                  normalizedProductId.trim().toUpperCase(),
                            );

                            final quantity = cartItem['qty'];
                            final hasAddOns = productProvider.hasAddOns(
                              product.varianceName,
                            );
                            final hasVariants = productProvider.hasVariants(
                              product.varianceName,
                            );

                            final double weight = cartItem['weight'];
                            final isWeight =
                                product.variance_Uom.toLowerCase() == "kg" ||
                                product.variance_Uom.toLowerCase() == "kgs";

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
                                  : 'Default',
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

                            final globalManager =
                                Provider.of<GlobalDataManager>(context);
                            final provider = Provider.of<RegularModeProvider>(
                              context,
                              listen: false,
                            );
                            final varianceData = provider.getVarianceDetails(
                              product.varianceName,
                            );

                            final double liveStock = globalManager
                                .getSystemStock(
                                  locationId,
                                  product.varianceName,
                                );

                            double displayStock = liveStock >= 0
                                ? liveStock
                                : (varianceData['branchwise']?[locationId]?['systemStock']
                                              as num?)
                                          ?.toDouble() ??
                                      0.0;

                            cartProvider.syncConfigWithQuantity(
                              productId,
                              quantity,
                            );

                            // Inside the ListTile builder where you create CartItemDialogState:

                            final dialogState = CartItemDialogState(
                              type: type,
                              addons: addons,
                              addonQuantities: addonQuantities,
                              variants: variants,
                              toggleRemark: List.generate(
                                quantity,
                                (i) => cartProvider.getToggleRemarkForItem(
                                  productId,
                                  i,
                                ),
                              ), // Get toggle for each item
                              remark: List.generate(
                                quantity,
                                (i) =>
                                    cartProvider.getRemarkForItem(productId, i),
                              ), // Get remark for each item
                              configQty: configQty,
                              remarkControllers: List.generate(
                                quantity,
                                (i) => TextEditingController(
                                  text: cartProvider.getRemarkForItem(
                                    productId,
                                    i,
                                  ),
                                ),
                              ),
                              focusNodes: List.generate(
                                quantity,
                                (i) => FocusNode(),
                              ),
                            );
                            return AbsorbPointer(
                              absorbing: isLockedTableView,
                              child: Dismissible(
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
                                            title: Consumer<CartItemDialogState>(
                                              builder: (context, dialogState, _) {
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Global Parcel Checkbox Row
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            product
                                                                .varianceName,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ),
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Checkbox(
                                                              value: dialogState
                                                                  .allParcelSelected,
                                                              onChanged: (value) {
                                                                if (value ==
                                                                    null)
                                                                  return;
                                                                dialogState
                                                                    .updateAllParcel(
                                                                      value,
                                                                    );
                                                                cartProvider.updateCartWithPerItemRemarks(
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
                                                                      .remark,
                                                                  dialogState
                                                                      .toggleRemark,
                                                                );
                                                              },
                                                              activeColor:
                                                                  Colors.blue,
                                                              checkColor:
                                                                  Colors.white,
                                                              side:
                                                                  const BorderSide(
                                                                    color: Colors
                                                                        .blue,
                                                                    width: 1.0,
                                                                  ),
                                                              materialTapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                            const Text(
                                                              "Parcel All",
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                            content: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxHeight:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.height *
                                                    0.3,
                                                maxWidth:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.width *
                                                    0.2,
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
                                                            final itemIndex = i;
                                                            final itemName =
                                                                '${i + 1}. ${product.varianceName}';

                                                            // Optional summary when collapsed
                                                            // String? summary;
                                                            // if (dialogState
                                                            //     .addons[itemIndex]
                                                            //     .isNotEmpty) {
                                                            //   summary =
                                                            //       "${dialogState.addons[itemIndex].length} add-on(s)";
                                                            // }
                                                            // if (dialogState
                                                            //         .variants[itemIndex] !=
                                                            //     "Default") {
                                                            //   summary =
                                                            //       (summary !=
                                                            //               null
                                                            //           ? "$summary • "
                                                            //           : "") +
                                                            //       dialogState
                                                            //           .variants[itemIndex];
                                                            // }
                                                            // if (dialogState
                                                            //         .type[itemIndex] ==
                                                            //     "Parcel") {
                                                            //   summary =
                                                            //       (summary !=
                                                            //               null
                                                            //           ? "$summary • "
                                                            //           : "") +
                                                            //       "Parcel";
                                                            // }
                                                            // if (dialogState
                                                            //         .toggleRemark &&
                                                            //     dialogState
                                                            //         .remark
                                                            //         .trim()
                                                            //         .isNotEmpty) {
                                                            //   summary =
                                                            //       (summary !=
                                                            //               null
                                                            //           ? "$summary • "
                                                            //           : "") +
                                                            //       "Remark";
                                                            // }
                                                            // String? summary;
                                                            // if (dialogState
                                                            //     .addons[itemIndex]
                                                            //     .isNotEmpty) {
                                                            //   summary =
                                                            //       "${dialogState.addons[itemIndex].length} add-on(s)";
                                                            // }
                                                            // if (dialogState
                                                            //         .variants[itemIndex] !=
                                                            //     "Default") {
                                                            //   summary =
                                                            //       (summary !=
                                                            //               null
                                                            //           ? "$summary • "
                                                            //           : "") +
                                                            //       dialogState
                                                            //           .variants[itemIndex];
                                                            // }
                                                            // if (dialogState
                                                            //         .type[itemIndex] ==
                                                            //     "Parcel") {
                                                            //   summary =
                                                            //       (summary !=
                                                            //               null
                                                            //           ? "$summary • "
                                                            //           : "") +
                                                            //       "Parcel";
                                                            // }
                                                            // if (dialogState
                                                            //         .toggleRemark[itemIndex] &&
                                                            //     dialogState
                                                            //         .remark[itemIndex]
                                                            //         .trim()
                                                            //         .isNotEmpty) {
                                                            //   summary =
                                                            //       (summary !=
                                                            //               null
                                                            //           ? "$summary • "
                                                            //           : "") +
                                                            //       "Remark";
                                                            // }
                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        4.0,
                                                                  ),
                                                              child: ExpansionTile(
                                                                // Header (always visible)
                                                                title: Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: Text(
                                                                        itemName,
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              13,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),

                                                                tilePadding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                childrenPadding:
                                                                    const EdgeInsets.fromLTRB(
                                                                      16,
                                                                      4,
                                                                      16,
                                                                      12,
                                                                    ),

                                                                // Collapsible content
                                                                children: [
                                                                  // ── Add-ons Section ──
                                                                  if (hasAddOns) ...[
                                                                    Padding(
                                                                      padding: const EdgeInsets.only(
                                                                        bottom:
                                                                            12,
                                                                      ),
                                                                      child: DropdownButtonFormField<String>(
                                                                        decoration: InputDecoration(
                                                                          contentPadding: const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                12,
                                                                            vertical:
                                                                                10,
                                                                          ),
                                                                          border: OutlineInputBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                          enabledBorder: OutlineInputBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                          focusedBorder: OutlineInputBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                            borderSide: const BorderSide(
                                                                              color: Colors.blue,
                                                                              width: 1.5,
                                                                            ),
                                                                          ),
                                                                          labelText:
                                                                              "Add-ons",
                                                                          labelStyle: const TextStyle(
                                                                            fontSize:
                                                                                13,
                                                                          ),
                                                                        ),
                                                                        isExpanded:
                                                                            true,
                                                                        hint: Text(
                                                                          dialogState.addons[itemIndex].isEmpty
                                                                              ? 'Select add-on'
                                                                              : "${dialogState.addons[itemIndex].length} selected",
                                                                          style: const TextStyle(
                                                                            fontSize:
                                                                                13,
                                                                            color:
                                                                                Colors.blue,
                                                                          ),
                                                                        ),
                                                                        items: [
                                                                          const DropdownMenuItem<
                                                                            String
                                                                          >(
                                                                            value:
                                                                                null,
                                                                            child: Text(
                                                                              "Select add-on...",
                                                                            ),
                                                                          ),
                                                                          ...productProvider
                                                                              .addons
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
                                                                                ) =>
                                                                                    DropdownMenuItem<
                                                                                      String
                                                                                    >(
                                                                                      value: addOn['addOn'].toString(),
                                                                                      child: Text(
                                                                                        "${addOn['addOn']} (₹${addOn['value']})",
                                                                                        overflow: TextOverflow.ellipsis,
                                                                                      ),
                                                                                    ),
                                                                              )
                                                                              .toList(),
                                                                        ],
                                                                        value:
                                                                            null, // always null → acts as "add" selector
                                                                        onChanged: (value) {
                                                                          if (value !=
                                                                                  null &&
                                                                              !dialogState.addons[itemIndex].contains(
                                                                                value,
                                                                              )) {
                                                                            dialogState.updateAddOn(
                                                                              itemIndex,
                                                                              value,
                                                                              true,
                                                                              1,
                                                                            );
                                                                            cartProvider.updateCartWithPerItemRemarks(
                                                                              productId,
                                                                              dialogState.addons,
                                                                              dialogState.addonQuantities,
                                                                              dialogState.variants,
                                                                              dialogState.type,
                                                                              dialogState.remark,
                                                                              dialogState.toggleRemark,
                                                                            );
                                                                          }
                                                                        },
                                                                      ),
                                                                    ),

                                                                    // Selected add-ons with quantity
                                                                    ...dialogState.addons[itemIndex].asMap().entries.map((
                                                                      entry,
                                                                    ) {
                                                                      final addOnIndex =
                                                                          entry
                                                                              .key;
                                                                      final addOnName =
                                                                          entry
                                                                              .value;
                                                                      final addOn = productProvider.addons.firstWhere(
                                                                        (a) =>
                                                                            a['addOn'].toString() ==
                                                                            addOnName,
                                                                        orElse: () => {
                                                                          'value':
                                                                              '0',
                                                                        },
                                                                      );
                                                                      final price =
                                                                          addOn['value'] ??
                                                                          '0';

                                                                      return Padding(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              4,
                                                                        ),
                                                                        child: Row(
                                                                          children: [
                                                                            Expanded(
                                                                              child: Text(
                                                                                "$addOnName (₹$price)",
                                                                                style: const TextStyle(
                                                                                  fontSize: 13,
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
                                                                                  padding: EdgeInsets.zero,
                                                                                  constraints: const BoxConstraints(),
                                                                                  onPressed: () {
                                                                                    if (dialogState.addonQuantities[itemIndex][addOnIndex] >
                                                                                        1) {
                                                                                      dialogState.updateAddOnQuantity(
                                                                                        itemIndex,
                                                                                        addOnIndex,
                                                                                        dialogState.addonQuantities[itemIndex][addOnIndex] -
                                                                                            1,
                                                                                      );
                                                                                    } else {
                                                                                      dialogState.updateAddOn(
                                                                                        itemIndex,
                                                                                        addOnName,
                                                                                        false,
                                                                                        0,
                                                                                      );
                                                                                    }
                                                                                    cartProvider.updateCartWithPerItemRemarks(
                                                                                      productId,
                                                                                      dialogState.addons,
                                                                                      dialogState.addonQuantities,
                                                                                      dialogState.variants,
                                                                                      dialogState.type,
                                                                                      dialogState.remark,
                                                                                      dialogState.toggleRemark,
                                                                                    );
                                                                                  },
                                                                                ),
                                                                                SizedBox(
                                                                                  width: 32,
                                                                                  child: Text(
                                                                                    "${dialogState.addonQuantities[itemIndex][addOnIndex]}",
                                                                                    textAlign: TextAlign.center,
                                                                                    style: const TextStyle(
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
                                                                                  padding: EdgeInsets.zero,
                                                                                  constraints: const BoxConstraints(),
                                                                                  onPressed: () {
                                                                                    dialogState.updateAddOnQuantity(
                                                                                      itemIndex,
                                                                                      addOnIndex,
                                                                                      dialogState.addonQuantities[itemIndex][addOnIndex] +
                                                                                          1,
                                                                                    );
                                                                                    cartProvider.updateCartWithPerItemRemarks(
                                                                                      productId,
                                                                                      dialogState.addons,
                                                                                      dialogState.addonQuantities,
                                                                                      dialogState.variants,
                                                                                      dialogState.type,
                                                                                      dialogState.remark,
                                                                                      dialogState.toggleRemark,
                                                                                    );
                                                                                  },
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      );
                                                                    }).toList(),
                                                                  ],

                                                                  // ── Variant Section ──
                                                                  if (hasVariants)
                                                                    Padding(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        vertical:
                                                                            12,
                                                                      ),
                                                                      child: DropdownButtonFormField<String>(
                                                                        decoration: InputDecoration(
                                                                          labelText:
                                                                              "Variant",
                                                                          border: OutlineInputBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                          ),
                                                                          contentPadding: const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                12,
                                                                            vertical:
                                                                                10,
                                                                          ),
                                                                        ),
                                                                        isExpanded:
                                                                            true,
                                                                        value: dialogState
                                                                            .variants[itemIndex],
                                                                        items: [
                                                                          const DropdownMenuItem(
                                                                            value:
                                                                                "Default",
                                                                            child: Text(
                                                                              "Default",
                                                                            ),
                                                                          ),
                                                                          ...productProvider.variants.map(
                                                                            (
                                                                              v,
                                                                            ) => DropdownMenuItem(
                                                                              value: v['variant'].toString(),
                                                                              child: Text(
                                                                                v['variant'].toString(),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                        onChanged: (value) {
                                                                          if (value !=
                                                                              null) {
                                                                            dialogState.updateVariant(
                                                                              itemIndex,
                                                                              value,
                                                                            );
                                                                            cartProvider.updateCartWithPerItemRemarks(
                                                                              productId,
                                                                              dialogState.addons,
                                                                              dialogState.addonQuantities,
                                                                              dialogState.variants,
                                                                              dialogState.type,
                                                                              dialogState.remark,
                                                                              dialogState.toggleRemark,
                                                                            );
                                                                          }
                                                                        },
                                                                      ),
                                                                    ),

                                                                  // ── Parcel Checkbox ──
                                                                  Padding(
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              8,
                                                                        ),
                                                                    child: Row(
                                                                      children: [
                                                                        Checkbox(
                                                                          value:
                                                                              dialogState.type[itemIndex] ==
                                                                              "Parcel",
                                                                          onChanged:
                                                                              (
                                                                                value,
                                                                              ) {
                                                                                if (value ==
                                                                                    null)
                                                                                  return;
                                                                                dialogState.updateType(
                                                                                  itemIndex,
                                                                                  value,
                                                                                );
                                                                                cartProvider.updateCartWithPerItemRemarks(
                                                                                  productId,
                                                                                  dialogState.addons,
                                                                                  dialogState.addonQuantities,
                                                                                  dialogState.variants,
                                                                                  dialogState.type,
                                                                                  dialogState.remark,
                                                                                  dialogState.toggleRemark,
                                                                                );
                                                                              },
                                                                          activeColor:
                                                                              Colors.blue,
                                                                          materialTapTargetSize:
                                                                              MaterialTapTargetSize.shrinkWrap,
                                                                        ),
                                                                        const Text(
                                                                          "Parcel this item",
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                13,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            color:
                                                                                Colors.blue,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),

                                                                  // ── Remark Section ──
                                                                  Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Row(
                                                                        children: [
                                                                          Switch(
                                                                            value:
                                                                                dialogState.toggleRemark[itemIndex],
                                                                            onChanged:
                                                                                (
                                                                                  value,
                                                                                ) {
                                                                                  dialogState.updateToggleRemark(
                                                                                    itemIndex,
                                                                                    value,
                                                                                  );
                                                                                  cartProvider.updateCartWithPerItemRemarks(
                                                                                    productId,
                                                                                    dialogState.addons,
                                                                                    dialogState.addonQuantities,
                                                                                    dialogState.variants,
                                                                                    dialogState.type,
                                                                                    dialogState.remark,
                                                                                    dialogState.toggleRemark,
                                                                                  );
                                                                                },
                                                                            activeColor:
                                                                                Colors.blue,
                                                                          ),
                                                                          Text(
                                                                            "Add remark",
                                                                            style: TextStyle(
                                                                              fontSize: 13,
                                                                              fontWeight: FontWeight.w500,
                                                                              color: Colors.blue,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      if (dialogState
                                                                          .toggleRemark[itemIndex])
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(
                                                                            top:
                                                                                8,
                                                                          ),
                                                                          child: TextField(
                                                                            controller:
                                                                                dialogState.remarkControllers[itemIndex],
                                                                            focusNode:
                                                                                dialogState.focusNodes[itemIndex],
                                                                            decoration: InputDecoration(
                                                                              hintText: 'Special instructions for item ${itemIndex + 1}...',
                                                                              border: OutlineInputBorder(),
                                                                              contentPadding: EdgeInsets.symmetric(
                                                                                horizontal: 12,
                                                                                vertical: 10,
                                                                              ),
                                                                            ),
                                                                            maxLines:
                                                                                2,
                                                                            onChanged:
                                                                                (
                                                                                  value,
                                                                                ) {
                                                                                  dialogState.updateRemark(
                                                                                    itemIndex,
                                                                                    value,
                                                                                  );
                                                                                  cartProvider.updateCartWithPerItemRemarks(
                                                                                    productId,
                                                                                    dialogState.addons,
                                                                                    dialogState.addonQuantities,
                                                                                    dialogState.variants,
                                                                                    dialogState.type,
                                                                                    dialogState.remark,
                                                                                    dialogState.toggleRemark,
                                                                                  );
                                                                                },
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }),
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
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text('Cancel'),
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text('OK'),
                                                onPressed: () {
                                                  debugPrint(
                                                    "variants are :: $variants",
                                                  );
                                                  cartProvider
                                                      .updateCartWithPerItemRemarks(
                                                        productId,
                                                        dialogState.addons,
                                                        dialogState
                                                            .addonQuantities,
                                                        dialogState.variants,
                                                        dialogState.type,
                                                        dialogState.remark,
                                                        dialogState
                                                            .toggleRemark,
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

                                    child: isWeight
                                        ? Text(
                                            "${capitalizeWords(product.varianceName)} \n ${formatWeight(weight)} kg x ₹${product.price}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          )
                                        : Text(
                                            "${capitalizeWords(product.varianceName)} \n ₹${product.price}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                  ),

                                  trailing: isWeight
                                      ? Text(
                                          "₹${(weight * product.price).toStringAsFixed(2)}",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.black12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                                  cartProvider
                                                      .removeItemFromCart(
                                                        context,
                                                        product.varianceName,
                                                        widget.tableNumber,
                                                        widget.seat,
                                                      );
                                                  cartProvider
                                                      .syncConfigWithQuantity(
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
                                                  print(
                                                    "quantity $quantity , displayStock : $displayStock ",
                                                  );
                                                  if (quantity < displayStock) {
                                                    cartProvider.addToCart(
                                                      product.varianceName,
                                                    );
                                                    cartProvider
                                                        .syncConfigWithQuantity(
                                                          productId,
                                                          quantity + 1,
                                                        );
                                                    print(
                                                      "➕ Added item $productId, new quantity: ${quantity + 1}",
                                                    );
                                                  } else {
                                                    print(
                                                      "view to crt added product : error",
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
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

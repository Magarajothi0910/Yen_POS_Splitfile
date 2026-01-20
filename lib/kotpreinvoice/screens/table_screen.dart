import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Hive_Manager/hive_manager_kot.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Server_Client/websocketService.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
import 'package:yenpos/kotpreinvoice/components/time_formater.dart';
import 'package:yenpos/kotpreinvoice/providers/search_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/timerProvider.dart';
import 'package:yenpos/kotpreinvoice/screens/preInvoiceTAb.dart';
// import 'package:yenpos/kotpreinvoice/providers/timerProvider.dart';
import 'package:yenpos/kotpreinvoice/screens/viewtocart.dart';
import 'package:yenpos/kotpreinvoice/services/autosaveholdorder.dart';
import 'package:yenpos/kotpreinvoice/utils/custom_snackbar.dart';
import 'package:yenpos/kotpreinvoice/widgets/bottomNav.dart';
import 'package:yenpos/kotpreinvoice/widgets/product_Search/idle_keyboard_hide.dart';
import '../components/flushbar.dart';
import '../services/hive_service.dart';
import '../services/sendDataToClients.dart';
import 'package:web_socket_channel/io.dart';
import '../handlers/syncMissingExtraTablesFromOrders.dart';
import '../providers/cartprovider.dart';
import '../providers/hold_order.dart';
import 'package:yenpos/kotpreinvoice/providers/order_provider.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import '../providers/product_provider.dart';
import '../services/websocketService.dart';
import '../widgets/tables/tableCustomerActions.dart';
import '../widgets/tables/tableExtraSeatLogic.dart';
import 'products_card_screen.dart';
import '../../kotpreinvoice/components/globalAppbar.dart';
import 'package:flutter/foundation.dart';
import '../services/table_actions_service.dart';

class PreInvoiceState extends ChangeNotifier {
  String? _storedDeviceCode;
  String? _errorMessage;
  Timer? _timer;

  String? get storedDeviceCode => _storedDeviceCode;
  String? get errorMessage => _errorMessage;

  PreInvoiceState() {
    debugPrint('🟢 PreInvoiceState initialized');
    _initState();
  }

  // 🔹 Initialize data safely
  Future<void> _initState() async {
    try {
      await loadDeviceCode();
      startTimer();
    } catch (e, stack) {
      _errorMessage = 'Initialization failed: $e';
      debugPrint('❌ Error during initialization: $e');
      debugPrint(stack.toString());
      notifyListeners();
    }
  }

  // 📡 Load device code from Hive with error handling
  Future<void> loadDeviceCode() async {
    debugPrint('📥 Loading device code from Hive...');
    try {
      final box = await Hive.openBox('deviceData');
      final code = box.get('deviceCode', defaultValue: 'UnknownDevice');
      _storedDeviceCode = code?.toString();
      debugPrint('✅ Device code loaded: $_storedDeviceCode');
    } on HiveError catch (hiveError) {
      _errorMessage = 'Hive error: ${hiveError.message}';
      debugPrint('🚨 HiveError: ${hiveError.message}');
    } catch (e, stack) {
      _errorMessage = 'Failed to load device code: $e';
      debugPrint('❌ Exception while loading device code: $e');
      debugPrint(stack.toString());
    }
    notifyListeners();
  }

  // ⏲️ Start periodic timer to update UI
  void startTimer() {
    try {
      _timer?.cancel(); // Cancel previous timer if any
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        // debugPrint(
        //   '⏱️ Timer tick: ${DateTime.now()} | Device: $_storedDeviceCode',
        // );
        notifyListeners();
      });
      debugPrint('✅ Timer started successfully');
    } catch (e, stack) {
      _errorMessage = 'Failed to start timer: $e';
      debugPrint('❌ Error starting timer: $e');
      debugPrint(stack.toString());
      notifyListeners();
    }
  }

  // 🧹 Clean up resources safely
  @override
  void dispose() {
    debugPrint('🧹 Disposing PreInvoiceState...');
    try {
      _timer?.cancel();
      debugPrint('🛑 Timer cancelled successfully');
    } catch (e, stack) {
      debugPrint('⚠️ Error cancelling timer: $e');
      debugPrint(stack.toString());
    }
    super.dispose();
  }
}

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  _TableScreenState createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  var tableNumber = '';
  var seat = '';
  late Box _tableBox;
  late Box invoice;

  late Box ordersBox;

  late WebSocketChannel channel;
  Timer? _refreshTimer;
  Timer? _debounceTimer;

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> areaKeys = {};
  double areaBlockHeight = 300;
  ValueNotifier<Map<String, List<String>>> extraTablesNotifier =
      ValueNotifier<Map<String, List<String>>>({});
  final ValueNotifier<String?> selectedAreaNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(true);
  bool _isProviderInitialized = false;

  late OrderProvider _orderProv;
  late ProductProvider _productProv;
  late CartProviderKOT _cartProv;
  late SalesInvoiceState _salesProv;
  late ProductEventProvider _productEvent;

  // New state variables for the split layout
  final ValueNotifier<String?> selectedTableNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> selectedAreaForTableNotifier =
      ValueNotifier<String?>(null);

  // New state variable to control ProductCardScreen visibility
  final ValueNotifier<bool> showProductCardNotifier = ValueNotifier(false);
  final ValueNotifier<Map<String, dynamic>> productCardDataNotifier =
      ValueNotifier<Map<String, dynamic>>({});

  final ValueNotifier<bool> showOnlyPreInvoiceNotifier = ValueNotifier(false);
  final ValueNotifier<String> currentFilterNotifier = ValueNotifier<String>(
    'all',
  );

  // Timer? _timer;

  @override
  void initState() {
    super.initState();

    // final Box ordersBox = Hive.box('ordersBox');

    final Box ordersBox = Hive.box('ordersBox');

    // ordersBox.toMap().forEach((orderKey, orderValue) {
    //   debugPrint('================ ORDER $orderKey ================');
    //   debugPrint(const JsonEncoder.withIndent('  ').convert(orderValue));
    // });

    // final Box invoiceBox = HiveManagerKot().invoicesBox;

    // if (globals.tables.isEmpty) {
    //   debugPrint('❌ Error: globals.tables is empty');
    // } else {
    //   for (var area in globals.tables) {
    //     final areaName = area['areaName'].toString();
    //     areaKeys[areaName] = GlobalKey();
    //     final tables = area['tables'] as List<Map<String, dynamic>>?;

    //     if (tables == null || tables.isEmpty) {
    //     } else {}
    //   }
    // }
    // showProductCardNotifier.addListener(() {});

    // productCardDataNotifier.addListener(() {});

    _orderProv = Provider.of<OrderProvider>(context, listen: false);
    _cartProv = Provider.of<CartProviderKOT>(context, listen: false);
    _productProv = Provider.of<ProductProvider>(context, listen: false);
    _salesProv = Provider.of<SalesInvoiceState>(context, listen: false);
    _productEvent = Provider.of<ProductEventProvider>(context, listen: false);
    // orderProvider.loadOrdersFromHive();
    // productProvider.loadProductsFromHive();

    // if (isBranchItems) {
    //   debugPrint("loadProductsFromHive before : $isBranchItems");
    //   isBranchItems = false;
    //   debugPrint("loadProductsFromHive after : $isBranchItems");
    // }

    _salesProv.employee.text = '';
    createdBy = '';

    _cartProv.clearCart();
    _cartProv.clearTableSeat();

    debugPrint("CART DATA IS CLEARED !!! ");
    _orderProv.chargeSubmit = true;

    initializeProvider();
    // _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final eventProvider = Provider.of<ProductEventProvider>(
          context,
          listen: false,
        );
        eventProvider.addListener(_handleProductEvents);
      }
    });
    // _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    //   if (mounted) setState(() {}); // ← this forces rebuild of everything
    // });
  }

  void _onScroll() {
    if (!mounted) return;
    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      try {
        String? mostVisibleArea;
        double closestPosition = double.infinity;
        final scrollPosition = _scrollController.position.pixels;
        final screenHeight = MediaQuery.of(context).size.height;
        debugPrint(
          '🔍 Detecting visible area at scroll position: $scrollPosition (screen height: $screenHeight)',
        );

        debugPrint(
          '📋 Checking visibility for ${globals.tables.length} areas:',
        );
        for (var area in globals.tables) {
          final areaName = area['areaName'].toString();
          final key = areaKeys[areaName];

          if (key?.currentContext == null) {
            debugPrint(
              '⚠️ Area $areaName context not available (index: ${globals.tables.indexOf(area)})',
            );
            continue;
          }

          final RenderBox? box =
              key!.currentContext!.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) {
            debugPrint('⚠️ RenderBox not available for $areaName');
            continue;
          }

          final position = box.localToGlobal(
            Offset.zero,
            ancestor: context.findRenderObject(),
          );
          final areaHeight = box.size.height;
          final visibleHeight = (screenHeight - position.dy).clamp(
            0.0,
            areaHeight,
          );
          final isVisible =
              position.dy >= -areaHeight && position.dy <= screenHeight;

          if (isVisible && visibleHeight > 50) {
            if (position.dy >= 0 && position.dy < closestPosition) {
              closestPosition = position.dy;
              mostVisibleArea = areaName;
            }
          }
        }

        if (mostVisibleArea != null &&
            mostVisibleArea != selectedAreaNotifier.value) {
          selectedAreaNotifier.value = mostVisibleArea;
        } else if (mostVisibleArea == null) {
          debugPrint('ℹ️ No visible area detected');
        }
      } catch (e, stack) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Check again
              showCustomFlushbar(
                context,
                'Error detecting visible area',
                type: FlushbarType.error,
              );
            }
          });
        }
      }
    });
  }

  void _handleProductEvents() {
    if (!mounted) return; // ← Critical
    final eventProvider = Provider.of<ProductEventProvider>(
      context,
      listen: false,
    );
    final events = eventProvider.events;

    if (events.isNotEmpty) {
      final lastEvent = events.last;

      if (lastEvent.action == 'close_overlay') {
        // Close the product card overlay
        showProductCardNotifier.value = false;
        productCardDataNotifier.value = {};

        // Clear the event
        eventProvider.clearEvents();

        print("✅ Closed product card overlay via New Orders button");
      } else if (lastEvent.action == 'show_overlay') {
        // Check if this is a hold order
        final isHoldOrder = lastEvent.productData?['isHoldOrder'] == true;

        // Show overlay for hold order
        showProductCardNotifier.value = true;
        productCardDataNotifier.value = {
          'tableNumber': lastEvent.tableNumber,
          'areaName': lastEvent.areaName,
          'seat': lastEvent.seat,
          'seathiveOrderId': '',
          'isHoldOrder': isHoldOrder,
        };

        if (isHoldOrder) {
          debugPrint(
            "🎯 Showing overlay for HOLD order: ${lastEvent.tableNumber}",
          );

          // For hold orders, also update cart provider if needed
          final cartProvider = Provider.of<CartProviderKOT>(
            context,
            listen: false,
          );
          cartProvider.currentTableNumber.value = lastEvent.tableNumber;
          cartProvider.currentSeat.value = lastEvent.seat;
          cartProvider.currentAreaName.value = lastEvent.areaName;
        } else {
          debugPrint(
            "🎯 Showing overlay for regular order: ${lastEvent.tableNumber}",
          );
        }

        eventProvider.clearEvents();
      }
    }
  }

  void _checkInitialVisibleArea() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      debugPrint('🔄 Checking initial visible area');
      try {
        final screenHeight = MediaQuery.of(context).size.height;
        String? mostVisibleArea;
        double closestPosition = double.infinity;

        for (var area in globals.tables) {
          final areaName = area['areaName'].toString();
          final key = areaKeys[areaName];

          if (key?.currentContext == null) {
            debugPrint(
              '⚠️ Area $areaName context not available (index: ${globals.tables.indexOf(area)})',
            );
            continue;
          }

          final RenderBox? box =
              key!.currentContext!.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) {
            debugPrint('⚠️ RenderBox not available for $areaName');
            continue;
          }

          final position = box.localToGlobal(
            Offset.zero,
            ancestor: context.findRenderObject(),
          );
          final areaHeight = box.size.height;
          final visibleHeight = (screenHeight - position.dy).clamp(
            0.0,
            areaHeight,
          );
          final isVisible =
              position.dy >= -areaHeight && position.dy <= screenHeight;

          if (isVisible && visibleHeight > 50) {
            if (position.dy >= 0 && position.dy < closestPosition) {
              closestPosition = position.dy;
              mostVisibleArea = areaName;
            }
          }
        }

        if (mostVisibleArea != null) {
          selectedAreaNotifier.value = mostVisibleArea;
        } else {
          debugPrint('⚠️ No visible area detected initially, defaulting to AC');
          selectedAreaNotifier.value = globals.tables.isNotEmpty
              ? globals.tables[0]['areaName'].toString()
              : null;
        }
      } catch (e, stack) {
        debugPrint('❌ Error in initial visibility check: $e\n$stack');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCustomFlushbar(
              context,
              'Error setting initial area',
              type: FlushbarType.error,
            );
            debugPrint("❌ Error setting initial area → Flushbar shown");
          });
        }
      }
    } else {
      debugPrint('⚠️ ScrollController not attached, defaulting to AC');
      selectedAreaNotifier.value = globals.tables.isNotEmpty
          ? globals.tables[0]['areaName'].toString()
          : null;
    }
  }

  Future<void> initializeProvider() async {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      await orderProvider.loadOrdersFromHive();

      // orderProvider.loadOrdersFromHive();

      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );

      await productProvider.loadProductsFromHive();

      areaNames = globals.tables.map((e) => e['areaName'].toString()).toList();

      _tableBox = Hive.box('branchwise_tables');
      final dynamic data = _tableBox.get('data');

      final box = Hive.box('extra_tables');
      extraTablesNotifier.value = box.toMap().map(
        (key, value) => MapEntry(key.toString(), List<String>.from(value)),
      );
      debugPrint('📦 Extra tables loaded: ${extraTablesNotifier.value}');

      // await initWebSocketAndData();
      if (mounted) {
        debugPrint('🔄 Syncing missing extra tables...');
        await syncMissingExtraTablesFromOrders(context, extraTablesNotifier);
        debugPrint('✅ Synced extra tables');
        cleanupEmptyExtraTables();
        debugPrint('🧹 Cleaned up empty extra tables');
      }
    } catch (e, stack) {
      debugPrint('❌ Error initializing providers: $e\n$stack');
      if (mounted) {
        CustomSnackBar.show(
          context,
          'Failed to load tables. Please try again.',
          type: SnackType.error,
        );
      }
    } finally {
      if (mounted) {
        debugPrint('ℹ️ Setting isLoading to false');
        isLoadingNotifier.value = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _checkInitialVisibleArea();
          }
        });
      }
    }
  }

  Future<void> initWebSocketAndData() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    try {
      // 🧠 If this device is the server, only request data from server
      // if (appType == 'server') {
      //   debugPrint('🖥️ Running as SERVER — requesting data only...');
      //   await orderProvider.requestDataFromServer();
      //   return; // ✅ Stop here, don't connect to WebSocket
      // }

      // // 📡 For clients, initialize Hive and connect to WebSocket
      // if (serverip.isNotEmpty && channel == null) {
      //   debugPrint('📶 Connecting to server at ws://$serverip:$port ...');
      //   channel = IOWebSocketChannel.connect('ws://$serverip:$port');
      //   await orderProvider.initializeHive();
      //   await orderProvider.requestDataFromServer();
      // }
      // await orderProvider.requestDataFromServer();
    } catch (e) {
      debugPrint('❌ Error initializing WebSocket and data: $e');
    }
  }

  void cleanupEmptyExtraTables() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final box = Hive.box('extra_tables');
    final updatedExtras = Map<String, List<String>>.from(
      extraTablesNotifier.value,
    );

    updatedExtras.forEach((mainTable, extras) {
      final remaining = extras.where((extraTable) {
        // Extract seat from extraTable like "Table1(B)" → "B"
        final seatMatch = RegExp(r'\(([A-Z])\)$').firstMatch(extraTable);
        final seat =
            seatMatch?.group(1) ??
            'A'; // fallback to 'A' if no match (shouldn't happen for extras)

        // Now check total price for this specific seat on the extra table
        final totalForSeat = orderProvider.getTableTotalPrice(extraTable, seat);

        return totalForSeat > 0;
      }).toList();

      if (remaining.length != extras.length) {
        box.put(mainTable, remaining);
        updatedExtras[mainTable] = remaining;
      }
    });

    extraTablesNotifier.value = updatedExtras;
    extraTablesNotifier.notifyListeners();
  }

  @override
  void dispose() {
    debugPrint("dispose for table screen");
    _salesProv.employee.text = '';
    createdBy = '';
    debugPrint("dispose for table screen 01 ");

    // ← Critical: Remove listener before disposing controller
    _scrollController.removeListener(_onScroll);
    debugPrint("dispose for table screen 02 ");

    _refreshTimer?.cancel();
    debugPrint("dispose for table screen 03 ");

    _debounceTimer?.cancel();

    Hive.box('extra_tables').compact();
    extraTablesNotifier.dispose();
    isLoadingNotifier.dispose();
    selectedTableNotifier.dispose();

    selectedAreaForTableNotifier.dispose();
    showProductCardNotifier.dispose();
    productCardDataNotifier.dispose();
    _scrollController.dispose();
    debugPrint("dispose for table screen 05 ");

    _productEvent.removeListener(_handleProductEvents);
    debugPrint("dispose for table screen 06 ");

    // final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);
    // _cartProv.currentTableNumber.dispose();
    // _cartProv.currentSeat.dispose();
    // _cartProv.currentAreaName.dispose();
    // _cartProv.currentSeathiveOrderId.dispose();
    _cartProv.currentTableNumber.value = '';
    _cartProv.currentSeat.value = '';
    _cartProv.currentAreaName.value = '';
    _cartProv.currentSeathiveOrderId.value = '';

    debugPrint("dispose for table screen 07 ");

    super.dispose(); // Only once!
  }

  bool _hasHoldOrder(String tableNumber, String seat) {
    try {
      final holdOrderProvider = Provider.of<HoldOrderProvider>(
        context,
        listen: false,
      );

      // Use the proper method to check for hold orders
      final hasOrder = holdOrderProvider.hasHoldOrder(tableNumber, seat);

      return hasOrder;
    } catch (e) {
      debugPrint('❌ Error checking hold order for $tableNumber: $e');
      return false;
    }
  }

  void _loadConfirmedOrdersToCart(
    String tableNumber,
    String seat,
    String areaName,
  ) {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final cartProvider = Provider.of<CartProviderKOT>(context, listen: false);
      final prov = Provider.of<SalesInvoiceState>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );

      // Clear current cart first
      cartProvider.clearCart();

      // Find confirmed orders for this table and seat
      final confirmedOrders = orderProvider.orders
          .where(
            (order) =>
                order['table'] == tableNumber &&
                order['seat'] == seat &&
                order['status'] == 'confirm',
          )
          .toList();

      debugPrint('confirmedOrders is $confirmedOrders');

      if (confirmedOrders.isEmpty) {
        debugPrint('⚠️ No confirmed orders found for $tableNumber seat $seat');
        return;
      }

      // Get seathiveOrderId from first order
      final firstOrder = confirmedOrders.first;
      final seathiveOrderId = firstOrder['seathiveOrderId']?.toString() ?? '';

      if (confirmedOrders.isNotEmpty) {
        prov.employee.text = firstOrder['waiter'];
        createdBy = firstOrder['waiter'];
      }

      // Load items into cart
      for (final order in confirmedOrders) {
        debugPrint("order ${order['weights']}");
        final varianceNames = List<String>.from(order['varianceNames'] ?? []);
        final weights = List<double>.from(order['weights'] ?? []);
        final status = order['status']?.toString() ?? '';
        print("weights is ${weights}");
        // print("status is ${status}");
        final quantities =
            (order['quantities'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [];
        for (int i = 0; i < varianceNames.length; i++) {
          final varianceName = varianceNames[i];
          final quantity = quantities[i];
          final weight = weights[i];

          // Add items to cart
          for (int j = 0; j < quantity; j++) {
            cartProvider.addToCart(varianceName, weight: weight);
          }
        }
      }

      // Update cart provider with table info
      cartProvider.currentTableNumber.value = tableNumber;
      cartProvider.currentSeat.value = seat;
      cartProvider.currentAreaName.value = areaName;
      cartProvider.currentSeathiveOrderId.value = seathiveOrderId;

      // Set chargeSubmit to true to show Charge button
      orderProvider.chargeSubmit = true;

      debugPrint(
        '✅ Loaded ${confirmedOrders.length} confirmed orders into cart',
      );
    } catch (e, stack) {
      debugPrint('❌ Error loading confirmed orders: $e\n$stack');
    }
  }

  // void _handleTableLongPress(String currentTable, String localAreaName) {
  //   debugPrint('👇 Long press on table: $currentTable');
  //   try {
  //     final seatMatch = RegExp(r'\((\w)\)$').firstMatch(currentTable);
  //     final orderProvider = Provider.of<OrderProvider>(context, listen: false);

  //     if (seatMatch == null) {
  //       seat = 'A';
  //     } else {
  //       seat = seatMatch.group(1)!;
  //     }
  //     final resolvedSeat = seatMatch != null ? seatMatch.group(1)! : 'A';
  //     final runningOrders = orderProvider.getRunningOrdersForSeat(
  //       currentTable,
  //       resolvedSeat,
  //     );
  //     final double tableTotal = orderProvider.getTableTotalPrice(currentTable);

  //     if (tableTotal > 0) {
  //       debugPrint(
  //         '🛠️ Showing customer actions for $currentTable, seat $resolvedSeat',
  //       );
  //       showTableActionsDialog(
  //         context: context,
  //         orderProvider: orderProvider,
  //         tableNumber: currentTable,
  //         seatOrders: runningOrders,
  //         areaName: localAreaName,
  //         selectedSeat: resolvedSeat,
  //         addExtraSeat: () {
  //           debugPrint('➕ Adding extra table to $currentTable');
  //           try {
  //             addExtraTableToTable(
  //               context: context,
  //               mainTableNumber: currentTable,
  //               extraTablesNotifier: extraTablesNotifier,
  //               orderProvider: orderProvider,
  //             );
  //             debugPrint('✅ Extra table added to $currentTable');
  //           } catch (e, stack) {
  //             debugPrint('❌ Error adding extra table: $e\n$stack');
  //             if (mounted) {
  //               WidgetsBinding.instance.addPostFrameCallback((_) {
  //                 showCustomFlushbar(
  //                   context,
  //                   'Failed to add extra table',
  //                   type: FlushbarType.error,
  //                 );
  //               });
  //             }
  //           }
  //         },
  //       );
  //     } else {
  //       debugPrint('$currentTable (seat $seat) is not occupied or confirmed.');
  //     }
  //   } catch (e, stack) {
  //     debugPrint('❌ Error handling long press on $currentTable: $e\n$stack');
  //     if (mounted) {
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         showCustomFlushbar(
  //           context,
  //           "❌ Error processing table action",
  //           type: FlushbarType.error,
  //         );
  //       });
  //     }
  //   }
  // }

  Future<void> scrollToArea(String areaName) async {
    debugPrint('📜 Scrolling to area: $areaName');
    try {
      if (_debounceTimer?.isActive ?? false) return;
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {});

      selectedAreaNotifier.value = areaName;

      final key = areaKeys[areaName];
      if (key == null || key.currentContext == null) return;

      final areaIndex = globals.tables.indexWhere(
        (area) => area['areaName'].toString() == areaName,
      );
      if (areaIndex == -1) return;

      double estimatedOffset = 0;
      for (int i = 0; i < areaIndex; i++) {
        final prevAreaName = globals.tables[i]['areaName'].toString();
        final prevKey = areaKeys[prevAreaName];
        if (prevKey?.currentContext != null) {
          final box = prevKey!.currentContext!.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            estimatedOffset += box.size.height;
          }
        }
      }
      estimatedOffset = estimatedOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );

      await _scrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.linear,
      );

      if (key.currentContext != null) {
        await Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.0,
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Error scrolling to area $areaName: $e\n$stack');
    }
  }

  Widget buildLegendIndicatorWithCount(
    String label,
    int count,
    VoidCallback onTap, {
    Color? indicatorColor,
  }) {
    return ValueListenableBuilder<String>(
      valueListenable: currentFilterNotifier,
      builder: (context, currentFilter, _) {
        final isSelected = currentFilter == label.toLowerCase();

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Material(
            elevation: 4.0,
            shadowColor: Colors.black,
            color: isSelected ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Show circle ONLY if indicatorColor is provided
                  if (indicatorColor != null) ...[
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        shape: BoxShape.circle,
                        border: label == 'Available'
                            ? Border.all(
                                color: Colors.grey.shade300,
                                width: 1.5, // adjust thickness if needed
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(width: 4),
                  ],

                  Text(
                    "$label ($count)",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // UPDATED: Method to get table color based on status
  Color getTableColor(String tableNumber, double tableTotal, String seat) {
    // Check if table has hold order first
    // if (_hasHoldOrder(tableNumber, seat)) {
    //   return const Color(0xFFFFF9C4); // Light yellow for hold orders
    // }
    // Then check if table has active orders
    return tableTotal > 0 ? const Color(0xFFE0F2F1) : Colors.white;
  }

  // UPDATED: Method to get table border color based on status
  Color getTableBorderColor(
    String tableNumber,
    double tableTotal,
    String seat,
  ) {
    // Only default table coloring here
    return tableTotal > 0 ? Colors.teal : Colors.grey.shade300;
  }

  String getAreaNameForTable(String tableNumber) {
    try {
      for (var area in globals.tables) {
        final tables = area['tables'] as List<Map<String, dynamic>>?;
        if (tables != null &&
            tables.any(
              (table) => table['tableNumber'].toString() == tableNumber,
            )) {
          return area['areaName'].toString();
        }
      }
      return '';
    } catch (e, stack) {
      debugPrint('❌ Error in getAreaNameForTable for $tableNumber: $e\n$stack');
      return '';
    }
  }

  String extractMainTable(String tableNumber) {
    final match = RegExp(r'^(.*?)(?:\([A-Z]\))?$').firstMatch(tableNumber);
    return match?.group(1) ?? tableNumber;
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final cartProvider = Provider.of<CartProviderKOT>(context);
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Increased table size
    const double cardWidth = 120;
    const double cardHeight = 120;
    final int columns = 8;

    return ValueListenableBuilder<bool>(
      valueListenable: isLoadingNotifier,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: showProductCardNotifier,
          builder: (context, showProductCard, _) {
            return SafeArea(
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                body: GestureDetector(
                  child: Stack(
                    children: [
                      Consumer<CartProviderKOT>(
                        builder: (context, provider, child) {
                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            child: Column(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      // Left side - Tables Grid (67% of screen)
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxHeight: screenHeight,
                                          ),
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: Stack(
                                                  children: [
                                                    _buildTableGrid(
                                                      // orderProvider,
                                                      screenHeight,
                                                      cardWidth,
                                                      cardHeight,
                                                      columns,
                                                    ),
                                                    if (showProductCard)
                                                      _buildProductCardScreenOverlay(),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const VerticalDivider(width: 1),
                                      // Right side - Product Card View (33% of screen)
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxHeight: screenHeight,
                                          ),
                                          // UPDATED: Use ValueListenableBuilder to pass dynamic data
                                          child: ValueListenableBuilder4(
                                            valueListenable1:
                                                cartProvider.currentTableNumber,
                                            valueListenable2:
                                                cartProvider.currentSeat,
                                            valueListenable3:
                                                cartProvider.currentAreaName,
                                            valueListenable4: cartProvider
                                                .currentSeathiveOrderId,
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
                                                      seathiveOrderId:
                                                          seathiveId,
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
                            ),
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
    );
  }

  // UPDATED: Method to build the table grid with hold order support
  Widget _buildTableGrid(
    // OrderProvider orderProvider,
    double screenHeight,
    double cardWidth,
    double cardHeight,
    int columns,
  ) {
    // CHANGED: Use Consumer to listen for OrderProvider changes
    return Consumer3<HoldOrderProvider, OrderProvider, PreInvoiceState>(
      builder: (context, holdOrderProvider, orderProvider, preInvoiceState, child) {
        final categoryProvider = Provider.of<CategoryProvider>(context);
        final productProvider = Provider.of<ProductProvider>(context);
        final timerProvider = Provider.of<TimerProvider>(context);

        final Set<String> subcategories = productProvider.products
            .map((p) => p.category)
            .where((category) => category != null && category.isNotEmpty)
            .toSet();
        final extraTables = extraTablesNotifier.value;
        final allTables = globals.tables.expand((area) {
          final mainTables = area['tables'] as List<Map<String, dynamic>>?;
          final areaName = area['areaName'].toString();
          if (mainTables == null || mainTables.isEmpty) {
            return <String>[];
          }
          return mainTables.expand((table) {
            final tableNumber = table['tableNumber'].toString();
            final extras = extraTables[tableNumber] ?? [];
            return [tableNumber, ...extras];
          });
        }).toList();

        // UPDATED: Count tables with hold orders
        final Map<String, int> tableCounts = allTables.fold(
          {'occupied': 0, 'available': 0, 'hold': 0},
          (counts, tableNumber) {
            final total = orderProvider.getActiveTableCount(tableNumber);
            final seatMatch = RegExp(r'\((\w)\)$').firstMatch(tableNumber);
            final seat = seatMatch != null ? seatMatch.group(1)! : 'A';

            if (_hasHoldOrder(tableNumber, seat)) {
              counts['hold'] = counts['hold']! + 1;
            } else if (total > 0) {
              counts['occupied'] = counts['occupied']! + 1;
            } else {
              counts['available'] = counts['available']! + 1;
            }
            return counts;
          },
        );

        final int allCount = allTables.length;
        final int holdCount = tableCounts['hold']!;
        final int confirmCount = orderProvider.getLockedTableSeatCount(
          allTables,
        );
        final int occupiedCount = tableCounts['occupied']!;
        final int availableCount =
            allCount - (holdCount + confirmCount + occupiedCount);

        TextEditingController _searchController = TextEditingController();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && selectedAreaNotifier.value == null) {
            _checkInitialVisibleArea();
          }
        });

        return Column(
          children: [
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 0, top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ChoiceChip(
                                label: const Text('Favorites'),
                                backgroundColor: Colors.white,
                                selectedColor: Colors.grey,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color:
                                      categoryProvider.selectedCategory ==
                                          'Favorites'
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                                showCheckmark: false,
                                side: BorderSide.none,
                                selected:
                                    categoryProvider.selectedCategory ==
                                    'Favorites',
                                onSelected: (selected) {
                                  if (selected) {
                                    categoryProvider.selectCategory(
                                      'Favorites',
                                    );
                                  }
                                },
                              ),

                              ...subcategories.map(
                                (sub) => Padding(
                                  padding: const EdgeInsets.only(right: 0),
                                  child: ChoiceChip(
                                    label: Text(sub),
                                    backgroundColor: Colors.white,
                                    selectedColor: Colors.grey,
                                    showCheckmark: false,
                                    side: BorderSide.none,
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color:
                                          categoryProvider.selectedCategory ==
                                              sub
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                    selected:
                                        categoryProvider.selectedCategory ==
                                        sub,
                                    onSelected: (selected) {
                                      if (selected) {
                                        categoryProvider.selectCategory(sub);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// 🔥 Fade Overlay
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.0)),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  buildLegendIndicatorWithCount(
                    "All",
                    allCount,
                    () => currentFilterNotifier.value = 'all',
                  ),

                  buildLegendIndicatorWithCount(
                    "Occupied",
                    occupiedCount,
                    () => currentFilterNotifier.value = 'occupied',
                    indicatorColor: Colors.teal.shade500,
                  ),

                  buildLegendIndicatorWithCount(
                    "Available",
                    availableCount,
                    () => currentFilterNotifier.value = 'available',
                    indicatorColor: Colors.white,
                  ),

                  buildLegendIndicatorWithCount(
                    "Hold",
                    holdCount,
                    () => currentFilterNotifier.value = 'hold',
                    indicatorColor: Colors.orange,
                  ),

                  buildLegendIndicatorWithCount(
                    "PreInvoiced",
                    confirmCount,
                    () => currentFilterNotifier.value = 'preinvoiced',
                    indicatorColor: Colors.red,
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable: currentFilterNotifier,
                  builder: (context, currentFilter, _) {
                    return ListView.builder(
                      controller: _scrollController,
                      cacheExtent: 10000,
                      itemCount: globals.tables.length,
                      itemBuilder: (context, areaIndex) {
                        final area = globals.tables[areaIndex];
                        final localAreaName = area['areaName'].toString();
                        final tables =
                            area['tables'] as List<Map<String, dynamic>>?;

                        if (tables == null || tables.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              key: areaKeys[localAreaName],
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  '$localAreaName (No tables)',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        // FILTER TABLES WITHIN THIS AREA BASED ON LEGEND
                        final filteredTables = tables.where((table) {
                          final tableNumber = table['tableNumber'].toString();

                          final seatMatch = RegExp(
                            r'\((\w)\)$',
                          ).firstMatch(tableNumber);
                          final seat = seatMatch != null
                              ? seatMatch.group(1)!
                              : 'A';
                          final hasHold = _hasHoldOrder(tableNumber, seat);
                          final isConfirmed = orderProvider.orders.any(
                            (order) =>
                                order['table'] == tableNumber &&
                                order['status'] == 'confirm',
                          );
                          final total = orderProvider.getTableTotalPrice(
                            tableNumber,
                            seat,
                          );

                          switch (currentFilter) {
                            case 'occupied':
                              return total > 0 && !hasHold && !isConfirmed;
                            case 'available':
                              return total == 0 && !hasHold && !isConfirmed;
                            case 'hold':
                              return hasHold;
                            case 'preinvoiced':
                              return isConfirmed;
                            case 'all':
                            default:
                              return true;
                          }
                        }).toList();

                        // If no tables in this area after filtering, don't show the area
                        if (filteredTables.isEmpty) {
                          return const SizedBox.shrink(
                            // child: Text("${currentFilter} no table found"),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            key: areaKeys[localAreaName],
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localAreaName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  ValueListenableBuilder<
                                    Map<String, List<String>>
                                  >(
                                    valueListenable: extraTablesNotifier,
                                    builder: (context, extraTables, _) {
                                      return GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: columns,
                                              childAspectRatio:
                                                  cardWidth / cardHeight,
                                              mainAxisSpacing: 8,
                                              crossAxisSpacing: 8,
                                            ),
                                        itemCount: () {
                                          int count = 0;
                                          for (var table in filteredTables) {
                                            count++;
                                            count +=
                                                extraTables[table['tableNumber']]
                                                    ?.length ??
                                                0;
                                          }
                                          return count;
                                        }(),
                                        itemBuilder: (context, index) {
                                          List<Map<String, dynamic>>
                                          combinedTables = [];
                                          for (var table in filteredTables) {
                                            final tableNumber =
                                                table['tableNumber'].toString();
                                            combinedTables.add({
                                              'tableNumber': tableNumber,
                                              'isExtra': false,
                                            });
                                            final extras =
                                                extraTables[tableNumber] ?? [];
                                            for (var extra in extras) {
                                              combinedTables.add({
                                                'tableNumber': extra,
                                                'isExtra': true,
                                              });
                                            }
                                          }

                                          final currentTable =
                                              combinedTables[index]['tableNumber'];
                                          final allOrders =
                                              orderProvider.orders;
                                          final seatMatch = RegExp(
                                            r'\((\w)\)$',
                                          ).firstMatch(currentTable);
                                          final seatToCheck = seatMatch != null
                                              ? seatMatch.group(1)!
                                              : 'A';

                                          final double tableTotal =
                                              orderProvider.getTableTotalPrice(
                                                currentTable,
                                                seatToCheck,
                                              ); // FIXED: Real-time seat locking check
                                          final isSeatLocked = allOrders.any(
                                            (order) =>
                                                order['table'] ==
                                                    currentTable &&
                                                order['seat'] == seatToCheck &&
                                                order['status'] == 'confirm',
                                          );
                                          final invoice = allOrders
                                              .where(
                                                (order) =>
                                                    order['table'] ==
                                                        currentTable &&
                                                    order['seat'] ==
                                                        seatToCheck &&
                                                    order['status'] ==
                                                        'confirm',
                                              )
                                              .toList();

                                          // if (invoice.isNotEmpty) {
                                          //   // debugPrint(
                                          //   //   "invoice preinvoiceTime: ${invoice.first['preinvoiceTime']}",
                                          //   // );
                                          // } else {
                                          //   // debugPrint(
                                          //   //   "No confirmed invoice found for this table and seat",
                                          //   // );
                                          // }
                                          final preinvoiceTime =
                                              invoice.isNotEmpty
                                              ? invoice.first['preinvoiceTime']
                                              : '';

                                          int elapsedSeconds =
                                              preinvoiceTime.isNotEmpty
                                              ? calculateElapsedTime(
                                                  preinvoiceTime,
                                                )
                                              : 0;
                                          String formattedElapsedTime =
                                              formatElapsedTime(elapsedSeconds);
                                          Color cardColor = getCardColor(
                                            elapsedSeconds,
                                          );

                                          final isOrdered = allOrders.any(
                                            (order) =>
                                                order['table'] ==
                                                    currentTable &&
                                                order['seat'] == seatToCheck &&
                                                order['status'] == 'active',
                                          );

                                          // UPDATED: Check if table has hold order
                                          final hasHold = _hasHoldOrder(
                                            currentTable,
                                            seatToCheck,
                                          );

                                          return GestureDetector(
                                            onLongPress: () async {
                                              debugPrint(
                                                '👇 Long press on table: $currentTable',
                                              );
                                              try {
                                                if (seatMatch == null) {
                                                  seat = 'A';
                                                } else {
                                                  seat = seatMatch.group(1)!;
                                                }

                                                final resolvedSeat =
                                                    seatMatch != null
                                                    ? seatMatch.group(1)!
                                                    : 'A';
                                                final runningOrders =
                                                    orderProvider
                                                        .getRunningOrdersForSeat(
                                                          currentTable,
                                                          resolvedSeat,
                                                        );

                                                if (tableTotal > 0) {
                                                  debugPrint(
                                                    '🛠️ Showing customer actions for $currentTable, seat $resolvedSeat',
                                                  );

                                                  showTableActionsDialog(
                                                    // channel: activeChannel,
                                                    context: context,
                                                    orderProvider:
                                                        orderProvider,
                                                    tableNumber: currentTable,
                                                    seatOrders: runningOrders,
                                                    areaName: localAreaName,
                                                    selectedSeat: seatToCheck,
                                                    addExtraSeat: () {
                                                      debugPrint(
                                                        '➕ Adding extra table to $currentTable',
                                                      );
                                                      try {
                                                        addExtraTableToTable(
                                                          context: context,
                                                          mainTableNumber:
                                                              currentTable,
                                                          extraTablesNotifier:
                                                              extraTablesNotifier,
                                                          orderProvider:
                                                              orderProvider,
                                                        );
                                                        debugPrint(
                                                          '✅ Extra table added to $currentTable',
                                                        );
                                                      } catch (e, stack) {
                                                        debugPrint(
                                                          '❌ Error adding extra table: $e\n$stack',
                                                        );
                                                        if (mounted) {
                                                          WidgetsBinding
                                                              .instance
                                                              .addPostFrameCallback((
                                                                _,
                                                              ) {
                                                                showCustomFlushbar(
                                                                  context,
                                                                  'Failed to add extra table',
                                                                  type:
                                                                      FlushbarType
                                                                          .error,
                                                                );
                                                              });
                                                        }
                                                      }
                                                    },
                                                  );
                                                } else {
                                                  debugPrint(
                                                    '$currentTable (seat $seat) is not occupied or confirmed.',
                                                  );
                                                }
                                              } catch (e, stack) {
                                                debugPrint(
                                                  '❌ Error handling long press on $currentTable: $e\n$stack',
                                                );
                                                if (mounted) {
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback((
                                                        _,
                                                      ) {
                                                        showCustomFlushbar(
                                                          context,
                                                          "Error processing table action",
                                                          type: FlushbarType
                                                              .error,
                                                        );
                                                      });
                                                }
                                              }
                                            },
                                            behavior:
                                                HitTestBehavior.translucent,
                                            onTapUp: (details) async {
                                              if (!_scrollController
                                                  .position
                                                  .isScrollingNotifier
                                                  .value) {
                                                debugPrint(
                                                  '👆 Tap on table is: $currentTable',
                                                );

                                                final prov =
                                                    Provider.of<
                                                      SalesInvoiceState
                                                    >(context, listen: false);

                                                prov.updateMultiple(
                                                  selectedEmployeeFirstName:
                                                      "", // or extract if available
                                                  selectedEmployeeNumber:
                                                      "", // or extract if available
                                                );

                                                prov.employee.text = '';

                                                // Optional: update global if needed elsewhere
                                                createdBy = '';
                                                try {
                                                  final seatMatch = RegExp(
                                                    r'\((\w)\)$',
                                                  ).firstMatch(currentTable);
                                                  final seatToSend =
                                                      seatMatch != null
                                                      ? seatMatch.group(1)!
                                                      : 'A';
                                                  final resolvedAreaName =
                                                      getAreaNameForTable(
                                                        extractMainTable(
                                                          currentTable,
                                                        ),
                                                      );

                                                  print(
                                                    "seatToSend is ... $seatToSend",
                                                  );

                                                  final allOrders =
                                                      orderProvider.orders;

                                                  final isSeatConfirmed =
                                                      allOrders.any(
                                                        (order) =>
                                                            order['table'] ==
                                                                currentTable &&
                                                            order['seat'] ==
                                                                seatToSend &&
                                                            order['status'] ==
                                                                'confirm',
                                                      );

                                                  if (isSeatConfirmed) {
                                                    debugPrint(
                                                      '🔒 Table $currentTable is pre-invoiced - loading orders for view',
                                                    );

                                                    // Load confirmed orders into cart
                                                    _loadConfirmedOrdersToCart(
                                                      currentTable,
                                                      seatToSend,
                                                      resolvedAreaName,
                                                    );
                                                    return;
                                                  }

                                                  debugPrint(
                                                    '📲 Sending seat action for Table=$currentTable, Seat=$seatToSend, Area=$resolvedAreaName',
                                                  );

                                                  // Use the service
                                                  TableActionsService.sendSeatActionToServer(
                                                    context: context,
                                                    tableNumber: currentTable,
                                                    seat: seatToSend,
                                                    areaName: resolvedAreaName,
                                                    productCardDataNotifier:
                                                        productCardDataNotifier,
                                                    showProductCardNotifier:
                                                        showProductCardNotifier,
                                                  );
                                                } catch (e, stack) {
                                                  debugPrint(
                                                    '❌ Error handling tap on $currentTable: $e\n$stack',
                                                  );
                                                  if (mounted) {
                                                    WidgetsBinding.instance
                                                        .addPostFrameCallback((
                                                          _,
                                                        ) {
                                                          showCustomFlushbar(
                                                            context,
                                                            'Error processing table tap',
                                                            type: FlushbarType
                                                                .error,
                                                          );
                                                        });
                                                  }
                                                }
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                1.0,
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  // UPDATED: Use new color method that considers hold orders
                                                  // color: getTableColor(
                                                  //   currentTable,
                                                  //   tableTotal,
                                                  //   seatToCheck,
                                                  // ),
                                                  color: isSeatLocked
                                                      ? cardColor
                                                      : isOrdered
                                                      ? timerProvider
                                                            .getOrderTimeColor(
                                                              currentTable,
                                                              seatToCheck,
                                                            )
                                                      : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        15.0,
                                                      ),
                                                  // UPDATED: Use new border color method that considers hold orders
                                                  border: Border.all(
                                                    color: isSeatLocked
                                                        ? Colors.red
                                                        : hasHold ||
                                                              _hasHoldOrder(
                                                                currentTable,
                                                                seatToCheck,
                                                              ) // Prioritize hold for color
                                                        ? Colors.orange
                                                        : isOrdered
                                                        ? const Color.fromARGB(
                                                            153,
                                                            43,
                                                            185,
                                                            171,
                                                          )
                                                        : tableTotal > 0
                                                        ? Colors.teal
                                                        : Colors.grey.shade300,
                                                    width: hasHold
                                                        ? 2
                                                        : isOrdered
                                                        ? 2
                                                        : tableTotal > 0
                                                        ? 1 // or whatever you want for normal active tables without "ordered" flag
                                                        : 0,
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Color(0xFFE0F2F1),
                                                      blurRadius: 4,
                                                      offset: Offset(2, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Stack(
                                                  children: [
                                                    Center(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            currentTable,
                                                            style: TextStyle(
                                                              fontSize: 15,
                                                              color:
                                                                  Colors.black,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          Text(
                                                            '₹${tableTotal.toStringAsFixed(2)}',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  const Color.fromARGB(
                                                                    255,
                                                                    0,
                                                                    0,
                                                                    0,
                                                                  ),
                                                            ),
                                                          ),
                                                          Consumer<
                                                            PreInvoiceState
                                                          >(
                                                            builder:
                                                                (
                                                                  context,
                                                                  preInvoiceState,
                                                                  child,
                                                                ) {
                                                                  if (isSeatLocked) {
                                                                    return Text(
                                                                      formattedElapsedTime
                                                                              .isNotEmpty
                                                                          ? formattedElapsedTime
                                                                          : '',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .black,
                                                                      ),
                                                                    );
                                                                  }
                                                                  return const SizedBox.shrink();
                                                                },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    // FIXED: Real-time lock icon update
                                                    if (isSeatLocked)
                                                      const Positioned(
                                                        top: 2,
                                                        right: 2,
                                                        child: Icon(
                                                          Icons.lock,
                                                          size: 18,
                                                          color: Colors.red,
                                                        ),
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
            ),
          ],
        );
      },
    );
  }

  // // NEW: Method to build the ProductCardScreen as overlay on left side
  Widget _buildProductCardScreenOverlay() {
    final data = productCardDataNotifier.value;
    if (data.isEmpty) return const SizedBox();

    return Container(
      width: MediaQuery.of(context).size.width * 0.67,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ProductCardScreen(
              tableNumber: data['tableNumber'],
              areaName: data['areaName'],
              seat: data['seat'],
              seathiveOrderId: data['seathiveOrderId'],
              onClose: () {
                // Refresh data when ProductCardScreen closes
                final orderProvider = Provider.of<OrderProvider>(
                  context,
                  listen: false,
                );
                showProductCardNotifier.value = false;
                productCardDataNotifier.value = {};
                if (globals.appType != 'server') {
                  orderProvider.requestDataFromServer();
                } else {
                  orderProvider.loadOrdersFromHive();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for combining multiple ValueNotifiers
class ValueListenableBuilder4<A, B, C, D> extends StatelessWidget {
  final ValueListenable<A> valueListenable1;
  final ValueListenable<B> valueListenable2;
  final ValueListenable<C> valueListenable3;
  final ValueListenable<D> valueListenable4;
  final Widget Function(
    BuildContext context,
    A value1,
    B value2,
    C value3,
    D value4,
    Widget? child,
  )
  builder;
  final Widget? child;

  const ValueListenableBuilder4({
    Key? key,
    required this.valueListenable1,
    required this.valueListenable2,
    required this.valueListenable3,
    required this.valueListenable4,
    required this.builder,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: valueListenable1,
      builder: (context, value1, child) {
        return ValueListenableBuilder<B>(
          valueListenable: valueListenable2,
          builder: (context, value2, child) {
            return ValueListenableBuilder<C>(
              valueListenable: valueListenable3,
              builder: (context, value3, child) {
                return ValueListenableBuilder<D>(
                  valueListenable: valueListenable4,
                  builder: (context, value4, child) {
                    return builder(
                      context,
                      value1,
                      value2,
                      value3,
                      value4,
                      child,
                    );
                  },
                  child: child,
                );
              },
              child: child,
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }
}

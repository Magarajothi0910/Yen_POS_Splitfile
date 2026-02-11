import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Audio Player/audio_provider.dart';
import 'package:yen_pos/Global/Provider/bottomNavprovider.dart';
import 'package:yen_pos/Global/Provider/branchSelection_provider.dart';
import 'package:yen_pos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yen_pos/Global/Provider/connectivity_internet.dart';
import 'package:yen_pos/Global/Provider/current_datetime.dart';
import 'package:yen_pos/Global/Provider/employee_provider.dart';
import 'package:yen_pos/Global/Provider/logo_provider.dart';
import 'package:yen_pos/Global/Widget/app_theme.dart';
import 'package:yen_pos/Global/Widget/circular_process_Indicator.dart';
import 'package:yen_pos/Global/Widget/scaffold_global.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Hive_Manager/hiveProvider.dart';
import 'package:yen_pos/Hive_Manager/hive_service.dart';
import 'package:yen_pos/Notification/websocket_service.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yen_pos/Sale_order/Provider/bank_search_provider.dart';
import 'package:yen_pos/Sale_order/Provider/customer_search_provider.dart';
import 'package:yen_pos/Sale_order/Provider/editcustomerscreenProvider.dart';
import 'package:yen_pos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yen_pos/Sale_order/Provider/modifyOrderProvider.dart';
import 'package:yen_pos/Sale_order/Provider/photoProvider.dart';
import 'package:yen_pos/Sale_order/Provider/regularmode_provider_saleorder.dart';
import 'package:yen_pos/Sale_order/Provider/saveAudioandImageFile.dart';
import 'package:yen_pos/Sale_order/Widgets/advance_amount_payment_keybaord.dart';
import 'package:yen_pos/Sale_order/Widgets/customAll_keyboard.dart';
import 'package:yen_pos/Sale_order/Widgets/custom_qty_keyboard.dart';
import 'package:yen_pos/Global/Provider/printer_provider.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_kot.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Mode_page/Regular_mode/Provider/regular_mode_screen_provider.dart';
import 'package:yen_pos/Sale_order/Models/fetchBranch.dart';
import 'package:yen_pos/Sale_order/Provider/cartProvider.dart';
import 'package:yen_pos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Sale_order/Provider/detailsProvider.dart';
import 'package:yen_pos/Sale_order/Provider/salesOrder_provider.dart';
import 'package:yen_pos/Sale_order/Widgets/customcharge_keybaord.dart';
import 'package:yen_pos/Sale_order/Widgets/paymentDetail_keybaord.dart';
import 'package:yen_pos/Sale_order/Widgets/search_drop_filed.dart';
import 'package:yen_pos/Server_Client/websocketService.dart';
import 'package:yen_pos/Server_Client/wifi_change_manager.dart';
import 'package:yen_pos/background_task/flutter_foreground_task.dart';
import 'package:yen_pos/birthday_cakes_screen/provider/birthdayCake_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/CustomerTopProductsProvider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/options_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/services/clear_invoice.dart';
import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/pending_print.dart';
import 'package:yen_pos/kotpreinvoice/providers/bottomNavprovider.dart';
import 'package:yen_pos/kotpreinvoice/providers/cartprovider.dart';
import 'package:yen_pos/kotpreinvoice/providers/hold_order.dart';
import 'package:yen_pos/kotpreinvoice/providers/install_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/order_type_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/pax_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/printer_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/product_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/search_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/submissionProvider.dart';
import 'package:yen_pos/kotpreinvoice/providers/upi_provider.dart';
import 'package:yen_pos/kotpreinvoice/screens/Unprinted%20receipt/provider/unprinted_orders_provider.dart';
import 'package:yen_pos/kotpreinvoice/screens/products_card_screen.dart';
import 'package:yen_pos/kotpreinvoice/screens/table_screen.dart';
import 'package:yen_pos/loginPage/installationpage.dart';
import 'package:yen_pos/loginPage/provider/deviceProvider.dart';
import 'package:yen_pos/loginPage/provider/loginPageProvider.dart';
import 'package:yen_pos/more_page/controller/denomination_controler.dart';
import 'package:yen_pos/more_page/providers/bt_provide2.dart';
import 'package:yen_pos/more_page/providers/cash_management_provider.dart';
import 'package:yen_pos/more_page/providers/customer_provider.dart';
import 'package:yen_pos/printer_screen/provider/printer_config_provider.dart';
import 'package:yen_pos/regular_mode_page/provider/cart_page_provider.dart';
import 'package:yen_pos/regular_mode_page/provider/favorite_page_provider.dart';
import 'package:yen_pos/regular_mode_page/provider/quantity_provider.dart';
import 'package:yen_pos/regular_mode_page/provider/stock_provider.dart';
import 'package:yen_pos/transactionPage/Provider/transactionProvider.dart';

final wsservice = NotificationWebSocketService();
Future<void> ensureLocationPermission() async {
  if (await Permission.locationWhenInUse.isDenied) {
    await Permission.locationWhenInUse.request();
  }

  if (await Permission.locationWhenInUse.isPermanentlyDenied) {
    openAppSettings();
  }
}

void main() async {
  // ← MUST be the very first call in main() for any platform plugin usage
  WidgetsFlutterBinding.ensureInitialized();
  await ensureLocationPermission();

  // Now it's safe to use permission_handler and other platform channels
  await _requestAllPermissions();

  ensureStoragePermission();
  // Initialize Hive (path setup + adapters if any)
  await Hive.initFlutter();

  // Optional: Custom Hive managers (keep if they do important setup)
  await HiveManager().init();
  await HiveManager.initialize(); // if this does extra work beyond init()
  await HiveManagerKot().init();

  // Open all required Hive boxes
  await Future.wait([
    Hive.openBox<Uint8List>('itemImages'),
    Hive.openBox('serverData'),
    Hive.openBox('branchesBox'),
    Hive.openBox<String>('audioFiles'),
    Hive.openBox('serverBox'),
    Hive.openBox('configBox'),
    Hive.openBox('printers'),
    Hive.openBox('tokenBox'),
    Hive.openBox('branchwise_items'),
    Hive.openBox('quickAccessBox'),
    Hive.openBox('KOTprinters'),
    Hive.openBox('imagesBox'),
    Hive.openBox('salesOrders'),
    Hive.openBox('saleOrderBox'),
    Hive.openBox('deviceCode'),
    Hive.openBox('invoices'),
    Hive.openBox('salesOrderNumberBox'),
    Hive.openBox('cartBox'),
    Hive.openBox('discounts'),
    Hive.openBox('advancePercent'),
    Hive.openBox('employeeBox'),
    Hive.openBox('openOrderBox'),
    Hive.openBox('opensaleOrders'),
    Hive.openBox('userBox'),
    Hive.openBox('holdOrders'),
    Hive.openBox('pendingPrintOrders'),
    Hive.openBox('deviceData'),
    Hive.openBox('branchData'),
    Hive.openBox('customerBox'),
    Hive.openBox('logo'),
    Hive.openBox('invoicesKOT'),
    Hive.openBox('printerData'),
    Hive.openBox('branches'),
    Hive.openBox('holdOrdersKOT'),
    Hive.openBox('cancelledOrderBox'),
    Hive.openBox('pendingPrintOrdersKOT'),
    Hive.openBox('tokenCounter'),
    Hive.openBox('branchwise_tables'),
    Hive.openBox('addons'),
    Hive.openBox('variants'),
    Hive.openBox('localStockBox'),
    Hive.openBox('ordersBox'),
    Hive.openBox('settings'),
    Hive.openBox('tableStatus'),
    Hive.openBox('extra_tables'),
    Hive.openBox('qr'),
    Hive.openBox('orderType'),
    Hive.openBox('approvelOrdersKOT'),
  ]);

  await CurrentDatetimeService().fetchCurrentDateTime();

  final invoiceBox = await Hive.openBox('invoices');
  await cleanOldInvoices(invoiceBox);

  final invoiceKOTBox = await Hive.openBox('invoicesKOT');
  await cleanOldInvoices(invoiceKOTBox);

  // Initialize providers that need Hive early
  final orderProvider = OrderProvider()..initializeHive();
  final printerProvider = PrinterProviderDine();
  final orderTypeProvider = OrderTypeProviderDine();
  final loginProvider = LoginProvider();
  final upiProvider = UpiProviderDine();
  final customerProvider = CustomerScreenProvider(
    printerProvider: PrinterProviderpos(),
  );
  final receiptPrinter = SalesInvoiceReceiptPrinter(
    printerProvider: PrinterProviderpos(),
  );

  // Initialize WebSocketService with required dependencies
  WebSocketService.init(
    orderProvider: orderProvider,
    printerProvider: printerProvider,
    orderTypeProvider: orderTypeProvider,
    loginProvider: loginProvider,
    upiProvider: upiProvider,
    customerProvider: customerProvider,
    receiptPrinter: receiptPrinter,
  );

  // Foreground task initialization
  await ForegroundHelper.init();

  // Fetch logo and branch data (non-critical if fails)
  await fetchAndStoreLogo();
  try {
    await fetchAndStoreBranchData();
  } catch (e) {
    debugPrint('Branch data fetch error: $e');
  }

  // Connect notification WebSocket
  wsservice.connect("wss://yenerp.com/fluttertestapi/salesorders/ws");

  // Put persistent controllers (GetX)
  Get.put(DenominationController());

  // Finally, run the app
  runApp(const MyApp());
}

Future<void> _requestAllPermissions() async {
  if (Platform.isAndroid) {
    // Request storage permission for file access
    var storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      await Permission.storage.request();
    }

    // Request microphone permission for audio recording
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      await Permission.microphone.request();
    }

    // Request camera permission for taking photos
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      await Permission.camera.request();
    }

    // Request location permission (if needed for your app)
    // var locationStatus = await Permission.location.status;
    // if (!locationStatus.isGranted) {
    //   await Permission.location.request();
    // }

    // For Android 13+ (API 33+), request media permissions
    if (await Permission.manageExternalStorage.isGranted) {
      // Already granted
    } else {
      await Permission.manageExternalStorage.request();
    }
  }

  // For iOS, request relevant permissions
  if (Platform.isIOS) {
    // Request photos permission for iOS
    var photosStatus = await Permission.photos.status;
    if (!photosStatus.isGranted) {
      await Permission.photos.request();
    }

    // Request microphone for iOS
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      await Permission.microphone.request();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final boxUrls = {
      'customerBox': 'https://yenerp.com/fluttertestapi/customers/',
      'banksBox': 'https://yenerp.com/masterapi/bankmasters/',
    };

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GlobalDataManager()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => QuantityProvider()),
        ChangeNotifierProvider(create: (_) => RegularModeProvider()),
        ChangeNotifierProvider(create: (_) => CurrentSaleProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(create: (_) => CartSelectionProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothProvider2()),
        ChangeNotifierProvider(create: (_) => DetailsProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SaleOrderProvider()),
        ChangeNotifierProvider(create: (_) => CashManagementProvider()),
        ChangeNotifierProvider(create: (_) => PreInvoiceState()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(
          create: (_) => PrinterProviderpos()..initializeHive,
        ),
        ChangeNotifierProvider(
          create: (_) =>
              CustomerScreenProvider(printerProvider: PrinterProviderpos()),
        ),
        ChangeNotifierProvider(create: (_) => KeyboardProvider()),
        ChangeNotifierProvider(create: (_) => QtyKeyboardProvider()),
        ChangeNotifierProvider(create: (_) => CurrentDatetimeService()),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider()..getInvoicesFromHive(),
        ),
        ChangeNotifierProvider(create: (_) => BirthdayCakesProvider()),
        ChangeNotifierProvider(create: (_) => PaymentDetailKeyboardProvider()),
        ChangeNotifierProvider(create: (_) => AdvanceAmountKeyboard()),
        ChangeNotifierProvider(create: (_) => RazorpayQRProvider()),
        ChangeNotifierProvider(create: (_) => OptionsProvider()),
        ChangeNotifierProvider(create: (_) => SalesInvoiceState()),
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ChangeNotifierProvider<WebSocketService>.value(
          value: WebSocketService.instance,
        ),
        ChangeNotifierProvider(
          create: (context) => ApiServiceSalesOrderProvider()
            ..fetchOrdersFromHive()
            ..setupHiveListener(),
        ),
        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => BranchProvider()),
        ChangeNotifierProvider(create: (_) => ModifyCartProvider()),
        ChangeNotifierProvider(create: (_) => EditCustomerScreenProvider()),
        ChangeNotifierProvider(create: (_) => HiveProvider(boxUrls)),
        ChangeNotifierProvider(
          create: (_) =>
              SalesInvoiceReceiptPrinter(printerProvider: PrinterProviderpos()),
        ),
        ChangeNotifierProvider(create: (_) => SaleOrderRegularModeProvider()),
        ChangeNotifierProvider(
          create: (context) => BankSearchProvider(
            Provider.of<HiveProvider>(context, listen: false),
            boxName: 'banksBox',
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => CustomerSearchProvider(
            Provider.of<HiveProvider>(context, listen: false),
            boxName: 'customerBox',
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PrinterProvider()..initializeHive(),
        ),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => EmployeeProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavProvider()),
        ChangeNotifierProvider(create: (_) => CustomerTopProductsProvider()),

        //KOT
        ChangeNotifierProvider(create: (_) => UpiProviderDine()),
        ChangeNotifierProvider(create: (_) => ProductEventProvider()),
        ChangeNotifierProvider(
          create: (_) => PrinterProviderDine()..printerInitializeHive(),
        ),
        ChangeNotifierProvider(create: (_) => BottomNavProviderKOT()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => SearchProviderDine()),
        ChangeNotifierProvider(create: (_) => InstallProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProviderpos()),

        ChangeNotifierProvider(create: (_) => CartProviderKOT()),
        ChangeNotifierProvider(create: (_) => OrderTypeProviderDine()),
        ChangeNotifierProvider(create: (_) => QuickAccessProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => SubmissionProviderDine()),
        ChangeNotifierProvider(create: (_) => PaxProviderDine()),
        ChangeNotifierProvider(create: (_) => HoldOrderProvider()),
        ChangeNotifierProvider(create: (_) => CustomchargeKeyboardProvider()),

        ChangeNotifierProvider(
          create: (_) => ProductProvider()..initializeHive(),
        ),
        ChangeNotifierProxyProvider<ProductProvider, OrderProvider>(
          create: (_) {
            final orderProvider = OrderProvider();
            orderProvider.initializeHive();
            return orderProvider;
          },
          update: (ctx, prodProv, orderProv) {
            return orderProv!..setProductProvider(prodProv);
          },
        ),
        // WebSocketService (depends on multiple providers)
        ChangeNotifierProvider<WebSocketService>.value(
          value: WebSocketService.instance,
        ),
        ChangeNotifierProvider(
          create: (context) => UnprintedOrdersProvider(
            printerProvider: Provider.of<PrinterProviderDine>(
              context,
              listen: false,
            ),
          ),
        ),
      ],
      builder: (context, child) {
        return WillPopScope(
          onWillPop: () async {
            final shiftOpen = globals.shiftId.value.isNotEmpty;
            return !shiftOpen; // block back if shift open
          },
          child: GetMaterialApp(
            navigatorKey: globals.navigatorKey,
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: GlobalScaffold.scaffoldMessengerKey,
            home: const HiveInitializer(),
          ),
        );
      },
    );
  }
}

class HiveInitializer extends StatefulWidget {
  const HiveInitializer({super.key});

  @override
  State<HiveInitializer> createState() => _HiveInitializerState();
}

class _HiveInitializerState extends State<HiveInitializer>
    with SingleTickerProviderStateMixin {
  late Future<void> _initFuture;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  final ValueNotifier<String> _loadingMessage = ValueNotifier<String>(
    "Starting...",
  );

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeHiveData();

    // Animation for smooth progress bar
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    WifiChangeManager.instance.init(
      mode: globals.appType == 'server' ? AppMode.server : AppMode.client,
      navigatorKey: globals.navigatorKey,
    );
  }

  Future<void> _initializeHiveData() async {
    final tasks = [
      _fetchEmployees,
      _fetchBranchData,
      _fetchSalesOrders,
      _fetchOtherData,
      _fetchEventData,
      _fetchDeliveryTypeData,
      _fetchCustomChargeData,
      _fetchAddons,
      _fetchVariants,
      _fetchQr,
    ];

    for (int i = 0; i < tasks.length; i++) {
      try {
        // Update loading message before the fetch
        switch (i) {
          case 0:
            _loadingMessage.value = "Counting employees... 🧑‍💼";
            break;
          case 1:
            _loadingMessage.value = "Fetching branches... 🌳";
            break;
          case 2:
            _loadingMessage.value = "Collecting sales orders... 🧾";
            break;
          case 3:
            _loadingMessage.value = "Organizing other  data... 📦";
            break;
          case 4:
            _loadingMessage.value = "Loading events... 🎉";
            break;
          case 5:
            _loadingMessage.value = "Checking delivery types... 🚚";
            break;
          case 6:
            _loadingMessage.value = "Adding custom charges... 💰";
            break;
          default:
            _loadingMessage.value = "Almost there... 🚀";
        }

        await tasks[i]();

        // Update progress
        double newValue = ((i + 1) / tasks.length) * 100;
        _animation = Tween<double>(begin: _progress.value, end: newValue)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOut,
              ),
            );
        _animationController.forward(from: 0);
        _progress.value = newValue;
      } catch (e) {
        _loadingMessage.value = "Oops! Something went wrong 😓";
      }
    }
  }

  Future<void> _fetchEmployees() async {
    final itemProv = Provider.of<ItemProvider>(context, listen: false);
    await itemProv.fetchAndSaveEmployees();
    await itemProv.fetchAndSaveOrderType();
  }

  Future<void> _fetchBranchData() async {
    final itemProv = Provider.of<ItemProvider>(context, listen: false);
    await itemProv.fetchAndStoreBranches();
  }

  Future<void> _fetchSalesOrders() async {
    final itemProv = Provider.of<ItemProvider>(context, listen: false);
    await itemProv.fetchAndSaveSalesOrders();
  }

  Future<void> _fetchOtherData() async {
    final itemProv = Provider.of<ItemProvider>(context, listen: false);
    await itemProv.fetchDataIfNeeded(branchAlias: globals.locationId);
  }

  Future<void> _fetchEventData() async {
    final itemProv = Provider.of<ItemProvider>(context, listen: false);
    await itemProv.fetchAndStoreEvents();
  }

  Future<void> _fetchDeliveryTypeData() async {
    final itemProv = Provider.of<ItemProvider>(context, listen: false);
    await itemProv.fetchAndStoreDeliveryType();
  }

  Future<void> _fetchCustomChargeData() async {
    final itemProv = Provider.of<ItemProvider>(context, listen: false);
    await itemProv.fetchAndStoreCustomCharges;
  }

  Future<void> _fetchAddons() async {
    final productProv = Provider.of<ProductProvider>(context, listen: false);
    await productProv.fetchAddOnsAndSaveInHive();
  }

  Future<void> _fetchVariants() async {
    final productProv = Provider.of<ProductProvider>(context, listen: false);
    await productProv.fetchVariantsAndSaveInHive();
  }

  Future<void> _fetchQr() async {
    const String apiUrl = 'https://yenerp.com/fluttertestapi/qr/';
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final List<dynamic> qrData = json.decode(response.body);
      final box = await Hive.openBox('qr');

      // Store as Map for O(1) lookup
      final Map<String, dynamic> qrMap = {
        for (var e in qrData) e['qrNo'].toString(): e,
      };

      await box.put('qrMap', qrMap);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progress.dispose();
    _loadingMessage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const ConnectivityWrapper();
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                "⚠️ Initialization Failed: ${snapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          );
        } else {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Modern Linear Progress Bar
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            offset: Offset(0, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: ValueListenableBuilder<double>(
                        valueListenable: _progress,
                        builder: (context, value, _) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            width:
                                MediaQuery.of(context).size.width *
                                0.8 *
                                (value / 100),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Percentage Text
                    ValueListenableBuilder<double>(
                      valueListenable: _progress,
                      builder: (context, value, _) {
                        return Text(
                          "${value.toInt()}%",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Fun message
                    ValueListenableBuilder<String>(
                      valueListenable: _loadingMessage,
                      builder: (context, msg, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            msg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Subtle info
                    const Text(
                      "Preparing your POS...",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

class ConnectivityWrapper extends StatefulWidget {
  const ConnectivityWrapper({super.key});

  @override
  _ConnectivityWrapperState createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectivityProvider = Provider.of<ConnectivityProvider>(
        context,
        listen: false,
      );
      final webSocketService = Provider.of<WebSocketService>(
        context,
        listen: false,
      );

      if (!connectivityProvider.isConnected) {
        _showNoInternetDialog(context, connectivityProvider);
      }

      connectivityProvider.addListener(() {
        if (connectivityProvider.isConnected) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
          webSocketService.reconnect();
        } else {
          _showNoInternetDialog(context, connectivityProvider);
        }
      });
    });
  }

  void _showNoInternetDialog(
    BuildContext context,
    ConnectivityProvider connectivityProvider,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(''),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                'No Network Connection!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('Please check your network connection.'),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Try Again'),
              onPressed: () async {
                await connectivityProvider.checkConnection();
                if (connectivityProvider.isConnected) {
                  final webSocketService = Provider.of<WebSocketService>(
                    context,
                    listen: false,
                  );
                  webSocketService.reconnect();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const InstallPOSApp();
  }
}

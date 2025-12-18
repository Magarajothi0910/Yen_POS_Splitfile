import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Audio Player/audio_provider.dart';
import 'package:yenpos/Global/Provider/bottomNavprovider.dart';
import 'package:yenpos/Global/Provider/branchSelection_provider.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Global/Provider/connectivity_internet.dart';
import 'package:yenpos/Global/Provider/current_datetime.dart';
import 'package:yenpos/Global/Provider/employee_provider.dart';
import 'package:yenpos/Global/Provider/logo_provider.dart';
import 'package:yenpos/Global/Widget/app_theme.dart';
import 'package:yenpos/Global/Widget/circular_process_Indicator.dart';
import 'package:yenpos/Global/Widget/scaffold_global.dart';
import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Hive_Manager/hiveProvider.dart';
import 'package:yenpos/Hive_Manager/hive_service.dart';
import 'package:yenpos/Notification/websocket_service.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Sale_order/Provider/bank_search_provider.dart';
import 'package:yenpos/Sale_order/Provider/customer_search_provider.dart';
import 'package:yenpos/Sale_order/Provider/editcustomerscreenProvider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Provider/modifyOrderProvider.dart';
import 'package:yenpos/Sale_order/Provider/photoProvider.dart';
import 'package:yenpos/Sale_order/Provider/regularmode_provider_saleorder.dart';
import 'package:yenpos/Sale_order/Widgets/advance_amount_payment_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/customAll_keyboard.dart';
import 'package:yenpos/Sale_order/Widgets/custom_qty_keyboard.dart';
import 'package:yenpos/Global/Provider/printer_provider.dart';
import 'package:yenpos/Hive_Manager/hive_manager_kot.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Mode_page/Regular_mode/Provider/regular_mode_screen_provider.dart';
import 'package:yenpos/Sale_order/Models/fetchBranch.dart';
import 'package:yenpos/Sale_order/Provider/cartProvider.dart';
import 'package:yenpos/Sale_order/Provider/cart_selection_provider.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Sale_order/Provider/detailsProvider.dart';
import 'package:yenpos/Sale_order/Provider/salesOrder_provider.dart';
import 'package:yenpos/Sale_order/Widgets/customcharge_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/paymentDetail_keybaord.dart';
import 'package:yenpos/Sale_order/Widgets/search_drop_filed.dart';
import 'package:yenpos/Server_Client/websocketService.dart';
import 'package:yenpos/background_task/flutter_foreground_task.dart';
import 'package:yenpos/birthday_cakes_screen/provider/birthdayCake_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/CustomerTopProductsProvider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/options_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/payment_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/provider/razorpay_provider.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/salesInvoicePayandPrint.dart';
import 'package:yenpos/invoice_pay_and_print_page.dart/widgets/pending_print.dart';
import 'package:yenpos/kotpreinvoice/providers/bottomNavprovider.dart';
import 'package:yenpos/kotpreinvoice/providers/cartprovider.dart';
import 'package:yenpos/kotpreinvoice/providers/hold_order.dart';
import 'package:yenpos/kotpreinvoice/providers/install_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/order_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/order_type_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/pax_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/printer_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/product_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/search_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/submissionProvider.dart';
import 'package:yenpos/kotpreinvoice/providers/timerProvider.dart';
import 'package:yenpos/kotpreinvoice/providers/upi_provider.dart';
import 'package:yenpos/kotpreinvoice/screens/Unprinted%20receipt/provider/unprinted_orders_provider.dart';
import 'package:yenpos/kotpreinvoice/screens/products_card_screen.dart';
import 'package:yenpos/loginPage/installationpage.dart';
import 'package:yenpos/loginPage/provider/deviceProvider.dart';
import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
import 'package:yenpos/more_page/controller/denomination_controler.dart';
import 'package:yenpos/more_page/providers/bt_provide2.dart';
import 'package:yenpos/printer_screen/provider/printer_config_provider.dart';
import 'package:yenpos/regular_mode_page/provider/cart_page_provider.dart';
import 'package:yenpos/regular_mode_page/provider/favorite_page_provider.dart';
import 'package:yenpos/regular_mode_page/provider/quantity_provider.dart';
import 'package:yenpos/regular_mode_page/provider/stock_provider.dart';
import 'package:yenpos/transactionPage/Provider/transactionProvider.dart';

final wsservice = NotificationWebSocketService();
void main() async {
  //   FlutterError.onError = (FlutterErrorDetails details) {
  //   FlutterError.dumpErrorToConsole(details);
  //   print("🔥 STACKTRACE BELOW:");
  //   print(details.stack);
  // };

  WidgetsFlutterBinding.ensureInitialized();
  await HiveManager().init();
  //await HiveService().init();
  await Hive.initFlutter();
  // Hive.registerAdapter(PendingPrintInvoiceAdapter());
  // await Hive.openBox<PendingPrintInvoice>('pending_prints');
  await Hive.openBox('branchesBox');
  await Hive.openBox<String>('audioFiles');
  await Hive.openBox('serverBox');
  await Hive.openBox('configBox');
  //await Hive.openBox('items');

  //KOT
  await Hive.openBox('printers');
  await Hive.openBox('tokenBox');
  await Hive.openBox('branchwise_items');
  await Hive.openBox('quickAccessBox');
  await Hive.openBox('KOTprinters');

  // final customerProvider = CustomerScreenProvider();
  // final printer = SalesInvoiceReceiptPrinter();

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

  // === NOW initialize WebSocketService ===
  WebSocketService.init(
    orderProvider: orderProvider,
    printerProvider: printerProvider,
    orderTypeProvider: orderTypeProvider,
    loginProvider: loginProvider,
    upiProvider: upiProvider,
    customerProvider: customerProvider,
    receiptPrinter: receiptPrinter,
  );

  //WebSocketService.init(customerProvider, printer, orderProvider: null, printerProvider: null, orderTypeProvider: null, loginProvider: null, upiProvider: null, customerProvider: null, receiptPrinter: null);
  await ForegroundHelper.init();

  final appDir = await getApplicationDocumentsDirectory();
  Hive.init(appDir.path);

  await Future.wait([
    Hive.openBox('imagesBox'),
    Hive.openBox('salesOrders'),
    Hive.openBox('saleOrderBox'),
    Hive.openBox('deviceCode'),
    Hive.openBox('invoices'),
    Hive.openBox('salesOrderNumberBox'),
    Hive.openBox('cartBox'),
    Hive.openBox('serverBox'),
    Hive.openBox('printers'),
    Hive.openBox('configBox'),
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

    //KOT
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
  ]);

  Get.put(DenominationController());

  await HiveManager.initialize();
  await HiveManager().init();
  await HiveManagerKot().init();

  await fetchAndStoreLogo();
  wsservice.connect("wss://yenerp.com/fluttertestapi/salesorders/ws");
  try {
    await fetchAndStoreBranchData();
  } catch (e) {
    debugPrint('Branch data fetch error: $e');
  }

  // ✅ Initialize Foreground only after bindings & Hive ready

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
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
        ChangeNotifierProvider(create: (_) => PrinterProviderpos()),
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
        ChangeNotifierProvider(create: (_) => TimerProvider()),

        ChangeNotifierProvider(create: (_) => ProductEventProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProviderDine()),
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
        return GetMaterialApp(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: GlobalScaffold.scaffoldMessengerKey,
          home: const HiveInitializer(),
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
    await itemProv.fetchDataIfNeeded(branchAlias: globals.aliasname);
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

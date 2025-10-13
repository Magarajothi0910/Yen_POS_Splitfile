import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/advance-dialog.dart';
import 'package:yenposapp/Global/advance_amount_payment_keybaord.dart';
import 'package:yenposapp/Global/customAll_keyboard.dart';
import 'package:yenposapp/Global/custom_qty_keyboard.dart';
import 'package:yenposapp/Global/paymentDetail_keybaord.dart';
import 'package:yenposapp/KotApp/models/hive%20boxes.dart';
import 'package:yenposapp/screens/printer_screen/provider/printer_config_provider.dart';

import 'package:yenposapp/services/hive_manager.dart';
import 'Global/Audio Player/audio_provider.dart';
import 'Global/branchSelection.dart';
import 'Global/scaffold_global.dart';
import 'KotApp/kotproviders/bottomNavprovider.dart';
import 'KotApp/kotproviders/cartprovider.dart';
import 'KotApp/kotproviders/deviceProvider.dart';
import 'KotApp/kotproviders/employee_provider.dart';
import 'KotApp/kotproviders/hold_order.dart';
import 'KotApp/kotproviders/login_provider.dart';
import 'KotApp/kotproviders/order_provider.dart';
import 'KotApp/kotproviders/order_type_provider.dart';
import 'KotApp/kotproviders/pax_provider.dart';
import 'KotApp/kotproviders/printer_provider.dart';
import 'KotApp/kotproviders/product_provider.dart';
import 'KotApp/kotproviders/search_provider.dart';
import 'KotApp/kotproviders/submissionProvider.dart';
import 'screens/transactionPage/transactionProvider.dart';
import 'KotApp/kotservices/kotwebsocketService.dart';
import 'KotApp/models/fetchBranch.dart';
import 'KotApp/screens/Unprinted receipt/provider/unprinted_orders_provider.dart';
import 'background_Task/flutter_foreground_task.dart';
import 'connectivity/connectivity_internet.dart';
import 'hiveGlobal/hiveProvider.dart';
import 'screens/more_page/controller/denomination_controler.dart';
import 'screens/more_page/providers/bt_provide2.dart';
import 'screens/regular_mode_page/provider/cart_page_provider.dart';
import 'screens/regular_mode_page/provider/favorite_page_provider.dart';
import 'screens/regular_mode_page/provider/quantity_provider.dart';
import 'screens/regular_mode_page/provider/regular_mode_screen_provider.dart';
import 'screens/sales_order/sales_order_print/invoicePrint.dart';
import 'screens/sales_order/sales_order_providers/bank_search_provider.dart';
import 'screens/sales_order/sales_order_providers/cart_selection_provider.dart';
import 'screens/sales_order/screens/all_orders_page/services/get_sales_order_service.dart';
import 'screens/sales_order/sales_order_providers/cartProvider.dart';
import 'screens/sales_order/sales_order_providers/customerScreen_provider.dart';
import 'screens/sales_order/sales_order_providers/customer_search_provider.dart';
import 'screens/sales_order/sales_order_providers/detailsProvider.dart';
import 'screens/sales_order/sales_order_providers/editcustomerscreenProvider.dart';
import 'screens/sales_order/sales_order_providers/modifyOrderProvider.dart';
import 'screens/sales_order/sales_order_providers/photoProvider.dart';
import 'screens/sales_order/sales_order_providers/salesOrder_provider.dart';
import 'server/Screen/login_provider_kot.dart';
import 'server/Screen/serverScreen.dart';
import 'services/branchwise_item_fetch.dart';
import 'services/websocketService.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveManager().init();
  await Hive.initFlutter();
  await Hive.openBox('branchesBox');
  await Hive.openBox<String>('audioFiles');
  final cartProvider = CartProvider();
  await cartProvider.init();

  await ForegroundHelper.init(); // ✅ just await it, don’t assign/use
  final appDir = await getApplicationDocumentsDirectory();
  Hive.init(appDir.path);
  await Hive.openBox('imagesBox');
  await Hive.openBox('salesOrders');
  await Hive.openBox('invoices');
  await Hive.openBox('imagesBox');
  await Hive.openBox('salesOrders');
  await Hive.openBox('salesOrderNumberBox');

  await Hive.openBox('openOrderBox');
  await Hive.openBox('opensaleOrders');
  await Hive.openBox('userBox');
  await Hive.openBox('holdOrders');
  await Hive.openBox('pendingPrintOrders');
  await Hive.openBox('deviceData');
  await Hive.openBox('branchData');
  await Hive.openBox('tableStatus');
  await Hive.openBox('openOrderBox');
  await Hive.openBox('opensaleOrders');
  await Hive.openBox('imagesBox');
  await Hive.openBox('salesOrders');
  await Hive.openBox('invoices');
  await Hive.openBox('imagesBox');
  await Hive.openBox('salesOrders');
  await Hive.openBox('openOrderBox');
  await Hive.openBox('opensaleOrders');
  await Hive.openBox('customerBox');
  Get.put(DenominationController());
  await HiveManager.initialize();
  await HiveManager().init();
  await HiveManagerKot().init();

  await Future.wait([
    Hive.openBox('invoices'),
    Future.value(HiveManagerKot().ordersBox),
    Hive.openBox('userBox'),
    Hive.openBox('holdOrders'),
    Hive.openBox('pendingPrintOrders'),
    Hive.openBox('deviceData'),
    Hive.openBox('branchData'),
    Hive.openBox('tableStatus'),
    Hive.openBox('openOrderBox'),
    Hive.openBox('opensaleOrders'),
    Hive.openBox('imagesBox'),
    Hive.openBox('salesOrders'),
    Hive.openBox('invoices'),
    Hive.openBox('imagesBox'),
    Hive.openBox("salesOrderNumberBox"),
    Hive.openBox('salesOrders'),
    Hive.openBox('openOrderBox'),
    Hive.openBox('opensaleOrders'),
    Hive.openBox('customerBox'),
  ]);

  try {
    await fetchAndStoreBranchData();
  } catch (e) {
    print("Error occurred while fetching or storing data: $e");
  }

  // final serverScreen = ServerScreen();
  // await serverScreen.init();
  // debugPrintRebuildDirtyWidgets = true;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // final ServerScreen serverScreen;

  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final boxUrls = {
      'customerBox': 'https://yenerp.com/fastapi/customers/',
      'banksBox': 'https://yenerp.com/masterapi/bankmasters/',
    };
    return MultiProvider(
      providers: [
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
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ChangeNotifierProvider(create: (_) => DetailsProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SaleOrderProvider()),
        ChangeNotifierProvider(create: (_) => CustomerScreenProvider()),
        ChangeNotifierProvider(create: (_) => KeyboardProvider()),
        ChangeNotifierProvider(create: (_) => QtyKeyboardProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProviderpos()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),

        ChangeNotifierProvider(create: (_) => PaymentDetailKeyboardProvider()),
        ChangeNotifierProvider(create: (_) => AdvanceAmountKeyboard()),

        ChangeNotifierProvider(
          create: (_) => WebSocketService(
            CustomerScreenProvider(),
            SalesInvoiceReceiptPrinter(),
          ),
        ),
        ChangeNotifierProvider(
            create: (context) => ApiServiceSalesOrderProvider(
                  webSocketService: Provider.of<WebSocketService>(
                    context,
                    listen: false,
                  ),
                )
                  ..fetchOrdersFromHive()
                  ..setupHiveListener()),

        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => BranchProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => ModifyCartProvider()),
        ChangeNotifierProvider(create: (_) => EditCustomerScreenProvider()),
        ChangeNotifierProvider(create: (_) => LoginProviderKot()),
        ChangeNotifierProvider(create: (_) => HiveProvider(boxUrls)),
        ChangeNotifierProvider(create: (_) => SalesInvoiceReceiptPrinter()),

        ChangeNotifierProvider(
          create: (context) => BankSearchProvider(
            Provider.of<HiveProvider>(context, listen: false),
            boxName: 'banksBox', // Provide the required boxName here
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => CustomerSearchProvider(
            Provider.of<HiveProvider>(context, listen: false),
            boxName: 'customerBox', // Provide the required boxName here
          ),
        ),

        //KOT

        ChangeNotifierProvider(
            create: (_) => PrinterProvider()..initializeHive()),

        // ChangeNotifierProvider(
        //     create: (context) => OrderProvider()
        //       ..initializePrinterProvider(context.read<PrinterProvider>())),
        ChangeNotifierProvider(
            create: (_) => ProductProvider()..initializeHive()),
// after you create your ProductProvider…
        ChangeNotifierProxyProvider<ProductProvider, OrderProvider>(
          create: (_) => OrderProvider(),
          update: (ctx, prodProv, orderProv) =>
              orderProv!..setProductProvider(prodProv),
        ),

        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CartProviderkot()),
        ChangeNotifierProvider(create: (_) => OrderTypeProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        //  ChangeNotifierProvider(create: (_) => CurrentSaleProvider()),
        ChangeNotifierProvider(create: (_) => EmployeeProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavProvider()),
        ChangeNotifierProvider(create: (_) => SubmissionProvider()),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(),
        ),

        ChangeNotifierProvider(create: (_) => PaxProvider()),
        ChangeNotifierProxyProvider2<OrderProvider, PrinterProvider,
            WebSocketServicekot>(
          create: (context) => WebSocketServicekot(
            context.read<OrderProvider>(),
            context.read<PrinterProvider>(),
            context.read<OrderTypeProvider>(),
            context.read<LoginProvider>(),
          ),
          update: (context, orderProvider, printerProvider, webSocketService) =>
              webSocketService!..updateOrderProviderkot(orderProvider),
        ),
        ChangeNotifierProvider(create: (_) => HoldOrderProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(
          create: (context) => UnprintedOrdersProvider(
            printerProvider:
                Provider.of<PrinterProvider>(context, listen: false),
          ),
        ),
      ],
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<ItemProvider>(context, listen: false)
              .fetchAndSaveEmployees();
          Provider.of<ItemProvider>(context, listen: false)
              .fetchDataIfNeeded(branchAlias: 'AR');
          Provider.of<ItemProvider>(context, listen: false)
              .fetchAndSaveSalesOrders();
        });

        return GetMaterialApp(
          showPerformanceOverlay: false,
          scaffoldMessengerKey: GlobalScaffold.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          home: LoginScreen(),
        );
      },
    );
  }
}

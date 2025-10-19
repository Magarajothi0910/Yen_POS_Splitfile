import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Audio%20Player/audio_provider.dart';
import 'package:yenpos/Global/Provider/bottomNavprovider.dart';
import 'package:yenpos/Global/Provider/branchSelection_provider.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Global/Provider/connectivity_internet.dart';
import 'package:yenpos/Global/Provider/employee_provider.dart';
import 'package:yenpos/Global/Provider/logo_provider.dart';
import 'package:yenpos/Global/Widget/scaffold_global.dart';

import 'package:yenpos/Hive_Manager/hiveProvider.dart';
import 'package:yenpos/Mode_page/choose_mode_screen.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Sale_order/Provider/bank_search_provider.dart';
import 'package:yenpos/Sale_order/Provider/customer_search_provider.dart';
import 'package:yenpos/Sale_order/Provider/deviceProvider.dart';
import 'package:yenpos/Sale_order/Provider/editcustomerscreenProvider.dart';
import 'package:yenpos/Sale_order/Provider/get_sales_order_service.dart';
import 'package:yenpos/Sale_order/Provider/modifyOrderProvider.dart';
import 'package:yenpos/Sale_order/Provider/photoProvider.dart';
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
import 'package:yenpos/Sale_order/Widgets/paymentDetail_keybaord.dart';
import 'package:yenpos/Server_Client/serverScreen.dart';
import 'package:yenpos/Server_Client/websocketService.dart';
import 'package:yenpos/background_task/flutter_foreground_task.dart';
import 'package:yenpos/loginPage/installationpage.dart';
import 'package:yenpos/loginPage/provider/deviceProvider.dart';

import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
import 'package:yenpos/more_page/controller/denomination_controler.dart';
import 'package:yenpos/more_page/providers/bt_provide2.dart';
import 'package:yenpos/shift_managment_page/openshift/open_shift.dart';
import 'package:yenpos/transactionPage/Provider/transactionProvider.dart';

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
  await Hive.openBox('cartBox');
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
  await Hive.openBox('logo');
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
    Hive.openBox('cartBox'),
    Hive.openBox('imagesBox'),
    Hive.openBox('salesOrders'),
    Hive.openBox('invoices'),
    Hive.openBox('imagesBox'),
    Hive.openBox("salesOrderNumberBox"),
    Hive.openBox('salesOrders'),
    Hive.openBox('openOrderBox'),
    Hive.openBox('opensaleOrders'),

    Hive.openBox('logo'),
    Hive.openBox('customerBox'),
  ]);

  await fetchAndStoreLogo();

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

  const MyApp({super.key});

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

        ChangeNotifierProvider(create: (_) => RegularModeProvider()),

        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(create: (_) => CartSelectionProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothProvider2()),

        ChangeNotifierProvider(create: (_) => DetailsProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SaleOrderProvider()),
        ChangeNotifierProvider(create: (_) => CustomerScreenProvider()),
        ChangeNotifierProvider(create: (_) => KeyboardProvider()),
        ChangeNotifierProvider(create: (_) => QtyKeyboardProvider()),
        // ChangeNotifierProvider(create: (_) => PrinterProviderpos()),
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
          create: (context) =>
              ApiServiceSalesOrderProvider(
                  webSocketService: Provider.of<WebSocketService>(
                    context,
                    listen: false,
                  ),
                )
                ..fetchOrdersFromHive()
                ..setupHiveListener(),
        ),

        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => BranchProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => ModifyCartProvider()),
        ChangeNotifierProvider(create: (_) => EditCustomerScreenProvider()),

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
          create: (_) => PrinterProvider()..initializeHive(),
        ),

        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),

        ChangeNotifierProvider(create: (_) => LoginProvider()),

        ChangeNotifierProvider(create: (_) => EmployeeProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavProvider()),

        ChangeNotifierProvider(create: (_) => TransactionProvider()),

        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<ItemProvider>(
            context,
            listen: false,
          ).fetchAndSaveEmployees();
          Provider.of<ItemProvider>(
            context,
            listen: false,
          ).fetchDataIfNeeded(branchAlias: '');
          Provider.of<ItemProvider>(
            context,
            listen: false,
          ).fetchAndSaveSalesOrders();
          Provider.of<ItemProvider>(
            context,
            listen: false,
          ).fetchAndStoreBranches();
        });

        return GetMaterialApp(
          showPerformanceOverlay: false,
          scaffoldMessengerKey: GlobalScaffold.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          // home: ChooseModePage(),
          home: InstallPOSApp(),
          // home: LoginScreen(),
        );
      },
    );
  }
}

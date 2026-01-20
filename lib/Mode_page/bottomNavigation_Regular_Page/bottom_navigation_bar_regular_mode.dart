
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:yenpos/Global/Provider/bottomNavprovider.dart';
import 'package:yenpos/Hive_Manager/hive_manager_kot.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Mode_page/bottomNavigation_Regular_Page/takeorderNavigator.dart';
import 'package:yenpos/birthday_cakes_screen/screen/birthday_cakes_screen.dart';
import 'package:yenpos/kotpreinvoice/screens/table_screen.dart';
import 'package:yenpos/kotpreinvoice/services/autosaveholdorder.dart';
import 'package:yenpos/more_page/more_page.dart';
import 'package:yenpos/regular_mode_page/regular_mode_screen.dart';
import 'package:yenpos/transactionPage/Screen/transaction_page.dart';

class BottomNavigationPageRegularModeScreen extends StatefulWidget {
  const BottomNavigationPageRegularModeScreen({super.key});

  @override
  State<BottomNavigationPageRegularModeScreen> createState() =>
      _BottomNavigationPageRegularModeScreenState();
}

class _BottomNavigationPageRegularModeScreenState
    extends State<BottomNavigationPageRegularModeScreen> {
  late Box _invoiceBox;
  bool _isHiveInitialized = false;

  final List<Widget> _pages = [
    const RegularModeScreen(),
    const BirthdayCakesScreen(),
    TableScreen(),
    TakeAwayOrdersNavigator(),
    TransactionPage(),
    MorePage(),
  ];

  @override
  void initState() {
    super.initState();
    Provider.of<BottomNavProvider>(context, listen: false).updateIndex(0);
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    await Hive.initFlutter();
    _invoiceBox = await Hive.openBox('invoices');
    setState(() => _isHiveInitialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomNav = context.watch<BottomNavProvider>();

    if (!_isHiveInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Scaffold(
        body: _pages[bottomNav.currentIndex],

        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black12)),
          ),

          child: ValueListenableBuilder(
            valueListenable: HiveManagerKot().invoicesBox.listenable(),
            builder: (context, kotBox, child) {
              return ValueListenableBuilder(
                valueListenable: HiveManager.invoiceBox.listenable(),
                builder: (context, box, widget) {
                  int transactionCountInvoices = box.values
                      .where(
                        (item) => item is Map && item['status'] == 'active',
                      )
                      .length;
                  int transactionCountKOT = kotBox.values.length;
                  int transactionCount =
                      transactionCountInvoices + transactionCountKOT;

                  return BottomNavigationBar(
                    currentIndex: bottomNav.currentIndex,

                    onTap: (index) {
                      bottomNav.updateIndex(index);

                      try {
                        AutoHoldOrderService.autoSaveHoldOrder(context);
                      } catch (e, stackTrace) {
                        debugPrint("Error: $e");
                        debugPrint("StackTrace: $stackTrace");
                      }
                    },

                    backgroundColor: Colors.white,
                    type: BottomNavigationBarType.fixed,

                    selectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),

                    items: [
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.grid_view),
                        label: 'Take Away',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.cake),
                        label: 'Birth Day Cakes',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.table_restaurant_outlined),
                        label: 'Dine in',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.chrome_reader_mode),
                        label: 'Order Management',
                      ),

                      /// Transaction Count Badge
                      BottomNavigationBarItem(
                        label: 'Transactions',
                        icon: Stack(
                          children: [
                            const Icon(Icons.sync),
                            if (transactionCount > 0)
                              Positioned(
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$transactionCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const BottomNavigationBarItem(
                        icon: Icon(Icons.more_horiz),
                        label: 'More',
                      ),
                    ],

                    selectedItemColor: Colors.blue,
                    unselectedItemColor: Colors.black,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

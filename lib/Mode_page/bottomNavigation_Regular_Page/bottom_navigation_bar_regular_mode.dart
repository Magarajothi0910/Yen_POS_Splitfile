// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:yen_pos/Mode_page/bottomNavigation_Regular_Page/takeorderNavigator.dart';
// import 'package:yen_pos/birthday_cakes_screen/screen/birthday_cakes_screen.dart';
// import 'package:yen_pos/kotpreinvoice/screens/products_card_screen.dart';
// import 'package:yen_pos/kotpreinvoice/screens/table_screen.dart';
// import 'package:yen_pos/more_page/more_page.dart';
// import 'package:yen_pos/regular_mode_page/regular_mode_screen.dart';
// import 'package:yen_pos/transactionPage/Screen/transaction_page.dart';

// class BottomNavigationPageRegularModeScreen extends StatefulWidget {
//   const BottomNavigationPageRegularModeScreen({super.key});

//   @override
//   // ignore: library_private_types_in_public_api
//   _BottomNavigationPageRegularModeScreenState createState() =>
//       _BottomNavigationPageRegularModeScreenState();
// }

// class _BottomNavigationPageRegularModeScreenState
//     extends State<BottomNavigationPageRegularModeScreen> {
//   int _currentIndex = 0;
//   late Box _invoiceBox;
//   bool _isHiveInitialized = false; // Loading state

//   late final List<Widget> _pages = [
//     const RegularModeScreen(),
//     const BirthdayCakesScreen(),
//     // const ProductCardScreen(
//     //   tableNumber: '',
//     //   seat: '',
//     //   seathiveOrderId: '', areaName: '',
//     // ),
//     TableScreen(),
//     // const CurrentOrdersPage(),
//     TakeAwayOrdersNavigator(),
//     TransactionPage(),
//     MorePage(),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _initializeHive();
//   }

//   Future<void> _initializeHive() async {
//     await Hive.initFlutter();
//     _invoiceBox = await Hive.openBox('invoices');
//     setState(() {
//       _isHiveInitialized = true; // Set loading state to complete
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!_isHiveInitialized) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return SafeArea(
//       child: Scaffold(
//         body: _pages[_currentIndex],
//         bottomNavigationBar: Container(
//           decoration: const BoxDecoration(
//             border: Border(top: BorderSide(color: Colors.black12)),
//           ),
//           child: ValueListenableBuilder(
//             valueListenable: _invoiceBox.listenable(),
//             builder: (context, box, widget) {
//                int transactionCount = box.values
//                   .where((item) => item is Map && item['status'] == 'active')
//                   .length; // Corrected access to the 'status' property

//               return BottomNavigationBar(
//                 currentIndex: _currentIndex,
//                 onTap: (index) {
//                   setState(() {
//                     _currentIndex = index;
//                   });
//                 },
//                 backgroundColor: Colors.white,
//                 type: BottomNavigationBarType.fixed,
//                 selectedLabelStyle: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                 ),
//                 unselectedLabelStyle: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                 ),
//                 items: [
//                   const BottomNavigationBarItem(
//                     icon: Icon(Icons.grid_view),
//                     label: 'Take Away',
//                   ),
//                   const BottomNavigationBarItem(
//                     icon: Icon(Icons.cake),
//                     label: 'Birth Day Cakes',
//                   ),
//                   const BottomNavigationBarItem(
//                     icon: Icon(Icons.table_restaurant_outlined),
//                     label: 'Dine in',
//                   ),
//                   const BottomNavigationBarItem(
//                     icon: Icon(Icons.chrome_reader_mode),
//                     label: 'Order Management',
//                   ),
//                   BottomNavigationBarItem(
//                     icon: Stack(
//                       children: [
//                         const Icon(Icons.sync),
//                         if (transactionCount > 0)
//                           Positioned(
//                             right: 0,
//                             child: Container(
//                               padding: const EdgeInsets.all(2),
//                               decoration: BoxDecoration(
//                                 color: Colors.red,
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               constraints: const BoxConstraints(
//                                 minWidth: 16,
//                                 minHeight: 16,
//                               ),
//                               child: Text(
//                                 '$transactionCount',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                     label: 'Transactions',
//                   ),
//                   const BottomNavigationBarItem(
//                     icon: Icon(Icons.more_horiz),
//                     label: 'More',
//                   ),
//                 ],
//                 selectedItemColor: Colors.blue,
//                 unselectedItemColor: Colors.black,
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:provider/provider.dart';
// import 'package:yen_pos/Global/Provider/bottomNavprovider.dart';
// import 'package:yen_pos/Hive_Manager/hive_manager_kot.dart';
// import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
// import 'package:yen_pos/Mode_page/bottomNavigation_Regular_Page/takeorderNavigator.dart';
// import 'package:yen_pos/birthday_cakes_screen/screen/birthday_cakes_screen.dart';
// import 'package:yen_pos/kotpreinvoice/screens/table_screen.dart';
// import 'package:yen_pos/kotpreinvoice/services/autosaveholdorder.dart';
// import 'package:yen_pos/more_page/more_page.dart';
// import 'package:yen_pos/regular_mode_page/regular_mode_screen.dart';
// import 'package:yen_pos/transactionPage/Screen/transaction_page.dart';

// class BottomNavigationPageRegularModeScreen extends StatefulWidget {
//   const BottomNavigationPageRegularModeScreen({super.key});

//   @override
//   State<BottomNavigationPageRegularModeScreen> createState() =>
//       _BottomNavigationPageRegularModeScreenState();
// }

// class _BottomNavigationPageRegularModeScreenState
//     extends State<BottomNavigationPageRegularModeScreen> {
//   late Box _invoiceBox;
//   bool _isHiveInitialized = false;

//   final List<Widget> _pages = [
//     const RegularModeScreen(),
//     const BirthdayCakesScreen(),
//     TableScreen(),
//     TakeAwayOrdersNavigator(),
//     TransactionPage(),
//     MorePage(),
//   ];

//   @override
//   void initState() {
//     super.initState();
//     Provider.of<BottomNavProvider>(context, listen: false).updateIndex(0);
//     _initializeHive();
//   }

//   Future<void> _initializeHive() async {
//     await Hive.initFlutter();
//     _invoiceBox = await Hive.openBox('invoices');
//     setState(() => _isHiveInitialized = true);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final bottomNav = context.watch<BottomNavProvider>();

//     if (!_isHiveInitialized) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return SafeArea(
//       child: Scaffold(
//         body: _pages[bottomNav.currentIndex],

//         bottomNavigationBar: Container(
//           decoration: const BoxDecoration(
//             border: Border(top: BorderSide(color: Colors.black12)),
//           ),

//           child: ValueListenableBuilder(
//             valueListenable: HiveManagerKot().invoicesBox.listenable(),
//             builder: (context, kotBox, child) {
//               return ValueListenableBuilder(
//                 valueListenable: HiveManager.invoiceBox.listenable(),
//                 builder: (context, box, widget) {
//                   int transactionCountInvoices = box.values
//                       .where(
//                         (item) => item is Map && item['status'] == 'active',
//                       )
//                       .length;
//                   int transactionCountKOT = kotBox.values.length;
//                   int transactionCount =
//                       transactionCountInvoices + transactionCountKOT;

//                   return BottomNavigationBar(
//                     currentIndex: bottomNav.currentIndex,

//                     onTap: (index) {
//                       bottomNav.updateIndex(index);

//                       try {
//                         AutoHoldOrderService.autoSaveHoldOrder(context);
//                       } catch (e, stackTrace) {
//                         debugPrint("Error: $e");
//                         debugPrint("StackTrace: $stackTrace");
//                       }
//                     },

//                     backgroundColor: Colors.white,
//                     type: BottomNavigationBarType.fixed,

//                     selectedLabelStyle: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     unselectedLabelStyle: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                     ),

//                     items: [
//                       const BottomNavigationBarItem(
//                         icon: Icon(Icons.grid_view),
//                         label: 'Take Away',
//                       ),
//                       const BottomNavigationBarItem(
//                         icon: Icon(Icons.cake),
//                         label: 'Birth Day Cakes',
//                       ),
//                       const BottomNavigationBarItem(
//                         icon: Icon(Icons.table_restaurant_outlined),
//                         label: 'Dine in',
//                       ),
//                       const BottomNavigationBarItem(
//                         icon: Icon(Icons.chrome_reader_mode),
//                         label: 'Order Management',
//                       ),

//                       /// Transaction Count Badge
//                       BottomNavigationBarItem(
//                         label: 'Transactions',
//                         icon: Stack(
//                           children: [
//                             const Icon(Icons.sync),
//                             if (transactionCount > 0)
//                               Positioned(
//                                 right: 0,
//                                 child: Container(
//                                   padding: const EdgeInsets.all(2),
//                                   decoration: BoxDecoration(
//                                     color: Colors.red,
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                   constraints: const BoxConstraints(
//                                     minWidth: 16,
//                                     minHeight: 16,
//                                   ),
//                                   child: Text(
//                                     '$transactionCount',
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),

//                       const BottomNavigationBarItem(
//                         icon: Icon(Icons.more_horiz),
//                         label: 'More',
//                       ),
//                     ],

//                     selectedItemColor: Colors.blue,
//                     unselectedItemColor: Colors.black,
//                   );
//                 },
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/Provider/bottomNavprovider.dart';
import 'package:yen_pos/Global/global_data_manager.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_kot.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Mode_page/bottomNavigation_Regular_Page/takeorderNavigator.dart';
import 'package:yen_pos/birthday_cakes_screen/screen/birthday_cakes_screen.dart';
import 'package:yen_pos/kotpreinvoice/screens/table_screen.dart';
import 'package:yen_pos/kotpreinvoice/services/autosaveholdorder.dart';
import 'package:yen_pos/kotpreinvoice/utils/custom_snackbar.dart';
import 'package:yen_pos/more_page/more_page.dart';
import 'package:yen_pos/regular_mode_page/regular_mode_screen.dart';
import 'package:yen_pos/transactionPage/Screen/transaction_page.dart';

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

  List _salesType = [];

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

    final GlobalData = Provider.of<GlobalDataManager>(context, listen: false);

    final salesTypes = GlobalData.branches;

    _salesType.clear();

    salesTypes.forEach((value) {
      if (value['locationId'] == locationId) {
        debugPrint(
          'salesType locationId is ${value['locationId']} -- aliasname is ${value['aliasName']}  → value: ${value['salesTypes']}',
        );
        _salesType.isEmpty ? _salesType.addAll(value['salesTypes']) : null;
      }
    });

    debugPrint("_salesType is $_salesType");

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
                      // debugPrint('transactionCountKOT $transactionCountKOT');
                      // if (index == 0 && !_salesType.contains('TakeAway')) {
                      //   CustomSnackBar.show(
                      //     context,
                      //     'This $aliasname branch does not support Take Away',
                      //     type: SnackType.error,
                      //   );
                      //   return;
                      // }
                      // if (index == 2 && !_salesType.contains('DineIn')) {
                      //   CustomSnackBar.show(
                      //     context,
                      //     'This $aliasname branch does not support DineIn',
                      //     type: SnackType.error,
                      //   );
                      //   return;
                      // }
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

import 'package:flutter/material.dart';
import 'package:yenpos/Sale_order/Screens/all_orders.dart';
import 'package:yenpos/Sale_order/Screens/current_orders.dart';



class TakeAwayOrdersNavigator extends StatelessWidget {

  const TakeAwayOrdersNavigator({super.key,});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (RouteSettings settings) {
        Widget page;

        // Default to Current Orders
        switch (settings.name) {
          case '/all-orders':
            page = AllOrdersPage(
        
            );
            break;
          case '/current-orders':
          default:
            page = CurrentOrdersPage(
     
            );
            break;
        }

        return MaterialPageRoute(
          builder: (context) => page,
          settings: settings,
        );
      },
    );
  }
}

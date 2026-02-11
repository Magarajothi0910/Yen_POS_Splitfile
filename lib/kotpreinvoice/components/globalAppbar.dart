import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';
import 'package:yen_pos/kotpreinvoice/screens/products_card_screen.dart';
import 'package:yen_pos/kotpreinvoice/services/hive_service.dart';
import 'package:yen_pos/kotpreinvoice/services/table_actions_service.dart';
import 'package:yen_pos/kotpreinvoice/widgets/holdOrder.dart';
import '../providers/hold_order.dart';
import '../providers/cartprovider.dart';
import '../screens/viewtocart.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double elevation;
  final ValueNotifier<Map<String, dynamic>>? productCardDataNotifier;
  final ValueNotifier<bool>? showProductCardNotifier;

  const GlobalAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.bottom,
    this.elevation = 6.0,
    this.productCardDataNotifier,
    this.showProductCardNotifier,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: elevation,
      iconTheme: const IconThemeData(color: Colors.black),
      actionsIconTheme: const IconThemeData(color: Colors.black),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                letterSpacing: 0.5,
                color: Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: HoldOrdersDropdown(
              productCardDataNotifier: productCardDataNotifier,
              showProductCardNotifier: showProductCardNotifier,
            ),
          ),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }
}

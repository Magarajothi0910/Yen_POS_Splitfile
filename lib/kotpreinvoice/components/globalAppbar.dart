import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hold_order.dart';
import '../providers/cartprovider.dart';
import '../screens/viewtocart.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double elevation;

  const GlobalAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.bottom,
    this.elevation = 6.0,
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
          IntrinsicWidth(child: HoldOrdersDropdown()),
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

// Separate stateful widget for the dropdown behavior
class HoldOrdersDropdown extends StatefulWidget {
  @override
  State<HoldOrdersDropdown> createState() => HoldOrdersDropdownState();
}

class HoldOrdersDropdownState extends State<HoldOrdersDropdown> {
  final GlobalKey _dropdownKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  void hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void showOverlay(
      BuildContext context, List<Map<String, dynamic>> holdOrders) {
    final renderBox =
        _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = renderBox?.size ?? Size.zero;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: () => hideOverlay(),
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height + 5,
            width: 160,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  itemCount: holdOrders.length,
                  itemBuilder: (context, index) {
                    final order = holdOrders[index];
                    final table = (order['table'] ?? '').toString();
                    final seat = (order['seat'] ?? '').toString();
                    final areaName = (order['areaName'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      title: Text('$table - Seat $seat', 
                      
                          style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        hideOverlay();
                        final holdOrder = Provider.of<HoldOrderProvider>(
                                context,
                                listen: false)
                            .loadHoldOrder(table, seat);
                        if (holdOrder != null) {
                          Provider.of<CartProviderKOT>(context, listen: false)
                              .loadCart(holdOrder);
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => productCardViewList(
                          //       tableNumber: table,
                          //       seat: seat,
                          //       areaName: areaName,
                          //       seathiveOrderId: "",
                          //     ),
                          //   ),
                          // );
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final holdOrderProvider =
        Provider.of<HoldOrderProvider>(context, listen: false);
    final holdOrders = holdOrderProvider.getAllHoldOrders();

    holdOrders.sort((a, b) {
      final numberRegex = RegExp(r'\d+');
      final int tableA =
          int.tryParse(numberRegex.firstMatch(a['table'])?.group(0) ?? '0') ??
              0;
      final int tableB =
          int.tryParse(numberRegex.firstMatch(b['table'])?.group(0) ?? '0') ??
              0;
      return tableA == tableB
          ? a['seat'].compareTo(b['seat'])
          : tableA.compareTo(tableB);
    });

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          key: _dropdownKey,
          onTap: () {
            if (_overlayEntry != null) {
              hideOverlay();
            } else {
              if (holdOrders.isNotEmpty) showOverlay(context, holdOrders);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: const Row(
              children: [
                Text(
                  "Hold Orders",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
        if (holdOrders.isNotEmpty)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(4.0),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: Text(
                '${holdOrders.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
